import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/tool_invocation_card.dart';
import 'package:servllama/features/agent/widgets/web_search_receipt.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_message_sheets.dart';
import 'package:servllama/features/chat/widgets/chat_tool_activity.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import '../../support/mcp_tool_fixture.dart';

class _FixtureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}

class _Repository extends AgentRepository {
  _Repository(super.db);
  int reads = 0;
  bool failNext = false;
  Completer<List<ToolInvocation>>? delayed;

  @override
  Future<List<ToolInvocation>> forRun(String conversationId, String runId) {
    reads++;
    if (runId == 'delayed') return delayed!.future;
    if (failNext) {
      failNext = false;
      return Future.error(StateError('fixture'));
    }
    return super.forRun(conversationId, runId);
  }
}

ToolInvocation receipt(
  String call, {
  String run = 'run',
  String conversation = 'conversation',
  String name = 'clock',
  String state = 'succeeded',
  Map<String, dynamic> payload = const {
    'arguments': {},
    'result': 'saved output',
  },
}) => ToolInvocation(
  id: '$run:$call',
  runId: run,
  callId: call,
  conversationId: conversation,
  name: name,
  state: state,
  payload: payload,
);

void main() {
  late AppDatabase db;
  late Directory directory;
  late _Repository repository;
  late AgentToolService service;
  late StreamingChatMessageNotifier streaming;
  late ScrollController scroll;
  ToolSession? session;
  late CancelToken token;
  const assistant = Assistant(
    id: 'assistant',
    name: 'Assistant',
    tools: ['clock', 'ask_user'],
  );
  final message = ChatMessageRecord(
    id: 'reply',
    sessionId: 'conversation',
    runId: 'run',
    role: ChatRole.assistant,
    content: 'Final answer',
    createdAt: DateTime(2026, 9, 27, 12, 34),
    modelName: 'Actual model',
  );

  setUp(() async {
    db = AppDatabase.memory();
    directory = await Directory.systemTemp.createTemp('chat-tools-');
    repository = _Repository(db);
    service = AgentToolService(repository, directory);
    streaming = StreamingChatMessageNotifier();
    scroll = ScrollController();
    token = CancelToken();
    await AssistantRepository(db).saveAssistant(assistant);
  });
  tearDown(() async {
    await session?.close();
    session = null;
    service.dispose();
    streaming.dispose();
    scroll.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> open({Assistant selected = assistant}) async {
    session = await service.open(
      'run',
      'conversation',
      ChatRunConfig(
        assistant: selected,
        connection: const AiConnection(
          id: 'local',
          name: 'Local',
          protocol: AiProtocol.openai,
          baseUrl: 'http://127.0.0.1:9999/v1',
        ),
        key: '',
        modelId: 'model',
        isLocal: true,
      ),
      token,
    );
  }

  Widget app(Widget child, {double scale = 1}) =>
      ChangeNotifierProvider<AgentToolService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      );

  Widget chat(ChatMessageRecord m, {bool live = false, double scale = 1}) =>
      app(
        ChatMessageList(
          controller: scroll,
          streamingMessages: streaming,
          messages: [m],
          draftMessageId: live ? m.id : null,
          canManageMessages: !live,
          canRegenerateMessage: (_) => !live,
          onCopyMessage: (_) async {},
          onEditMessage: (_) async {},
          onDeleteMessage: (_) async {},
          onRegenerateMessage: (_) async {},
          onShowMessageActions: (_) async {},
          onSelectMessageVersion: (_, _) async {},
        ),
        scale: scale,
      );

  Future<Future<AiTurn> Function()> pending(
    WidgetTester tester,
    AiToolCall call,
  ) async {
    late Future<AiTurn> result;
    await tester.runAsync(() async {
      result = session!.invoke(call);
      for (var n = 0; n < 200 && service.pendingCount == 0; n++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(service.pendingCount, 1);
    });
    await tester.pump();
    return () => result;
  }

  testWidgets(
    'reply shows ordered receipts for its selected run and keeps footer last',
    (tester) async {
      await repository.insert(receipt('first'));
      await repository.insert(
        receipt(
          'second',
          name: 'read_file',
          payload: {
            'arguments': {'path': 'notes.txt'},
            'result': 'File contents',
          },
        ),
      );
      await repository.insert(
        receipt('other', run: 'alternative', name: 'list_files'),
      );
      await repository.insert(
        receipt('foreign', run: 'foreign', conversation: 'elsewhere'),
      );
      await tester.pumpWidget(chat(message));
      await tester.pumpAndSettle();
      expect(find.text('2 tool calls'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('run:first'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('run:second'))).dy,
        ),
      );
      expect(find.byKey(const ValueKey('alternative:other')), findsNothing);
      expect(
        tester.getTopLeft(find.text('Final answer')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(ChatToolActivity)).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text('Actual model')).dy,
        greaterThan(tester.getBottomLeft(find.text('Final answer')).dy),
      );

      final reads = repository.reads;
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:first')));
      await tester.pumpAndSettle();
      expect(find.text('saved output'), findsOneWidget);
      await tester.pumpWidget(chat(message.copyWith(content: 'Updated text')));
      await tester.pumpAndSettle();
      expect(repository.reads, reads);
      expect(await db.query('SELECT id FROM tool_invocations'), hasLength(4));

      await tester.pumpWidget(chat(message.copyWith(runId: 'alternative')));
      await tester.pumpAndSettle();
      expect(find.text('List conversation files'), findsOneWidget);
      expect(find.text('Current time'), findsNothing);
      await tester.pumpWidget(chat(message.copyWith(clearRunId: true)));
      await tester.pumpAndSettle();
      expect(find.byType(ToolInvocationCard), findsNothing);
    },
  );

  testWidgets(
    'live statuses update without token-triggered reads and survive session close',
    (tester) async {
      await open();
      final draft = message.copyWith(content: '');
      streaming.update(draft, isStreaming: true);
      await tester.pumpWidget(chat(draft, live: true));
      await repository.insert(receipt('live', state: 'executing'));
      await service.refresh();
      await tester.pump();
      expect(find.byTooltip('Executing'), findsOneWidget);
      expect(find.text('...'), findsNothing);
      final reads = repository.reads;
      for (var n = 0; n < 3; n++) {
        streaming.update(
          draft.copyWith(content: 'Streaming $n'),
          isStreaming: true,
        );
        await tester.pump();
      }
      expect(repository.reads, reads);
      await repository.transition('run:live', 'executing', 'succeeded', {
        'arguments': {},
        'result': 'saved output',
      });
      await service.refresh();
      await tester.pump();
      expect(find.byTooltip('Completed'), findsOneWidget);
      await session!.close();
      streaming.remove(message.id);
      await tester.pumpWidget(chat(draft));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Completed'), findsOneWidget);
      expect(find.text('Actual model'), findsOneWidget);
    },
  );

  testWidgets(
    'question is answered in chat and cannot be approved or replayed afterward',
    (tester) async {
      await open();
      await tester.pumpWidget(chat(message.copyWith(content: ''), live: true));
      final result = await pending(
        tester,
        const AiToolCall(
          id: 'ask',
          name: 'ask_user',
          arguments: {'question': 'Which format?'},
        ),
      );
      expect(find.text('Waiting for your answer'), findsOneWidget);
      final approve = find.byKey(const ValueKey('tool_approve_run:ask'));
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('tool_answer_run:ask')),
        'Markdown',
      );
      await tester.pump();
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      final answer = await tester.runAsync(result);
      expect(jsonDecode(answer!.text)['answer'], 'Markdown');
      await tester.pump();
      expect(find.text('Send answer'), findsNothing);
      expect(find.byTooltip('Completed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:ask')));
      await tester.pump();
      expect(find.textContaining('Markdown'), findsOneWidget);
      expect(await repository.history('conversation'), hasLength(1));
      expect(service.pendingCount, 0);
    },
  );

  testWidgets(
    'remote MCP approval executes once and exposes its saved result in the same card',
    (tester) async {
      final fixture = (await tester.runAsync(
        () => McpToolFixture.start({
          'content': [
            {'type': 'text', 'text': 'Approved output'},
          ],
        }),
      ))!;
      addTearDown(fixture.close);
      final remote = fixture.config;
      final name = AgentToolService.mcpToolName(remote.id, 'echo');
      final selected = assistant.changed({
        'tools': [name],
        'mcpServerIds': [remote.id],
      });
      await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          await AssistantRepository(db).saveAssistant(selected);
          await repository.saveServer(remote);
          await open(selected: selected);
        }, _FixtureHttpOverrides()),
      );
      await tester.pumpWidget(chat(message.copyWith(content: ''), live: true));
      final result = await pending(
        tester,
        AiToolCall(
          id: 'remote',
          name: name,
          arguments: const {'text': 'Approved output'},
        ),
      );
      expect(find.textContaining('Approved output'), findsNWidgets(2));
      expect(find.text('Fixture MCP'), findsOneWidget);
      final approve = find.byKey(const ValueKey('tool_approve_run:remote'));
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      expect((await tester.runAsync(result))!.isError, isFalse);
      expect(fixture.calls, 1);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:remote')));
      await tester.pump();
      expect(find.text('Allow once'), findsNothing);
      expect(find.byTooltip('Completed'), findsOneWidget);
      expect(await repository.history('conversation'), hasLength(1));
      await tester.runAsync(() => session!.close());
    },
  );

  testWidgets('truncated receipts explain the export limit', (tester) async {
    await tester.pumpWidget(
      app(
        ToolInvocationCard(
          invocation: receipt(
            'bounded',
            payload: const {
              'arguments': {},
              'result': 'Saved excerpt',
              'resultTruncated': true,
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tool_toggle_run:bounded')));
    await tester.pump();
    expect(
      find.text(
        'This result was truncated. Only the saved excerpt can be viewed or exported.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.download), findsNothing);
  });

  testWidgets(
    'both version deletion actions remain reachable with large text on a narrow screen',
    (tester) async {
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 260,
            height: 360,
            child: ChatMessageActionSheet(
              message: message.copyWith(
                versionIds: ['old', 'new'],
                currentVersionIndex: 1,
              ),
              canRegenerate: true,
            ),
          ),
          scale: 2,
        ),
      );
      final all = find.byKey(const Key('chat_message_action_delete_reply'));
      await tester.ensureVisible(all);
      await tester.pump();
      expect(find.text('Delete this version'), findsOneWidget);
      expect(find.text('Delete all versions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reject and cancellation remove inline decision controls', (
    tester,
  ) async {
    await open();
    await tester.pumpWidget(chat(message.copyWith(content: ''), live: true));
    final rejected = await pending(
      tester,
      const AiToolCall(
        id: 'reject',
        name: 'ask_user',
        arguments: {'question': 'Optional question'},
      ),
    );
    final reject = find.byKey(const ValueKey('tool_reject_run:reject'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    expect((await tester.runAsync(rejected))!.isError, isTrue);
    await tester.pump();
    expect(find.byTooltip('Rejected'), findsOneWidget);
    final cancelled = await pending(
      tester,
      const AiToolCall(
        id: 'cancel',
        name: 'ask_user',
        arguments: {'question': 'Cancel me'},
      ),
    );
    final expectation = expectLater(cancelled(), throwsA(isA<DioException>()));
    token.cancel();
    await tester.runAsync(() => expectation);
    await tester.pump();
    expect(find.byTooltip('Cancelled'), findsOneWidget);
    expect(find.text('Send answer'), findsNothing);
    expect(service.pendingCount, 0);
  });

  testWidgets(
    'search sources expand in the shared card and MCP names come from the receipt',
    (tester) async {
      await repository.insert(
        receipt(
          'search',
          name: 'web_search',
          payload: {
            'arguments': {'query': 'Flutter documentation'},
            'result': jsonEncode({
              'provider': 'bing',
              'items': [
                {
                  'title': 'Flutter docs',
                  'url': 'https://docs.flutter.dev',
                  'snippet': 'Saved source',
                },
              ],
            }),
          },
        ),
      );
      await repository.insert(
        receipt(
          'mcp',
          name: 'mcp_12345678_hash',
          state: 'failed',
          payload: {
            'arguments': {'query': 'notes'},
            'displayName': 'search_notes',
            'serverName': 'Notes server',
            'error': 'Saved failure',
          },
        ),
      );
      await tester.pumpWidget(chat(message));
      await tester.pumpAndSettle();
      expect(find.byType(WebSearchReceipt), findsNothing);
      expect(find.text('search_notes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:mcp')));
      await tester.pumpAndSettle();
      expect(find.text('Notes server'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:search')));
      await tester.pumpAndSettle();
      expect(find.byType(WebSearchReceipt), findsOneWidget);
      expect(find.text('Flutter docs'), findsOneWidget);
    },
  );

  testWidgets(
    'large text fits on a narrow screen and historical pending rows are read-only',
    (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final state in [
        'prepared',
        'approved',
        'pendingApproval',
        'executing',
        'succeeded',
        'failed',
        'rejected',
        'cancelled',
        'unknownOutcome',
      ]) {
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              child: SizedBox(
                width: 260,
                child: ToolInvocationCard(
                  key: ValueKey(state),
                  invocation: receipt(
                    state,
                    state: state,
                    name: 'long_remote_tool_name_that_wraps',
                    payload: {
                      'arguments': {'path': 'a/long/path/with/a/long-name.txt'},
                      'result': 'Saved output',
                    },
                  ),
                ),
              ),
            ),
            scale: 2,
          ),
        );
        await tester.tap(find.byKey(ValueKey('tool_toggle_run:$state')));
        await tester.pump();
        expect(find.text('Allow once'), findsNothing);
        expect(tester.takeException(), isNull, reason: state);
      }
    },
  );

  testWidgets(
    'late history responses cannot leak into another version; load failure can retry',
    (tester) async {
      repository.delayed = Completer<List<ToolInvocation>>();
      await tester.pumpWidget(chat(message.copyWith(runId: 'delayed')));
      await repository.insert(receipt('current'));
      await tester.pumpWidget(chat(message));
      await tester.pumpAndSettle();
      repository.delayed!.complete([
        receipt('old', run: 'delayed', name: 'read_file'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Read conversation files'), findsNothing);
      expect(find.text('Current time'), findsOneWidget);
      repository.failNext = true;
      await tester.pumpWidget(chat(message.copyWith(runId: 'retry')));
      await tester.pumpAndSettle();
      expect(find.text('Could not load tool activity.'), findsOneWidget);
      await repository.insert(receipt('retry', run: 'retry'));
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load tool activity.'), findsNothing);
      expect(find.text('Current time'), findsOneWidget);
    },
  );
}
