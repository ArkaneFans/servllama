import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/app/app_theme.dart';
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
import 'package:servllama/features/chat/models/chat_timeline.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_tool_activity.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import '../../support/mcp_tool_fixture.dart';
import '../../support/agent_database_fixture.dart';

class _FixtureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}

class _Repository extends AgentRepository {
  _Repository(super.db);
  @override
  Future<void> insert(ToolInvocation invocation) async {
    await seedAgentRun(
      db,
      invocation.runId,
      conversationId: invocation.conversationId,
    );
    await super.insert(invocation);
  }

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
    await seedAgentRun(db, 'run');
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

  Widget app(Widget child, {double scale = 1, ThemeData? theme}) =>
      ChangeNotifierProvider<AgentToolService>.value(
        value: service,
        child: MaterialApp(
          theme: theme,
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

  Widget chat(
    ChatMessageRecord m, {
    bool live = false,
    double scale = 1,
    ThemeData? theme,
    GlobalKey? capture,
  }) => app(
    RepaintBoundary(
      key: capture,
      child: ColoredBox(
        color: theme?.scaffoldBackgroundColor ?? Colors.white,
        child: ChatMessageList(
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
      ),
    ),
    scale: scale,
    theme: theme,
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
    'trajectory fits phone themes and large text while keeping detail controls usable',
    (tester) async {
      const previewFont = String.fromEnvironment('TIMELINE_PREVIEW_FONT');
      if (const bool.fromEnvironment('TIMELINE_PREVIEW') &&
          previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('TimelinePreview')
            ..addFont(
              File(
                previewFont,
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final start = DateTime.utc(2026);
      final builder = ChatTimelineBuilder();
      builder.append(reasoning: '先查看资料，再检查当前时间。', at: start);
      builder.finish(at: start.add(const Duration(seconds: 2)));
      builder.tool('search', 'web_search');
      builder.append(text: '已找到相关资料，我再核对一下。\n');
      builder.tool('clock', 'clock');
      builder.append(
        reasoning: '信息已核对，整理成简明结论。',
        at: start.add(const Duration(seconds: 3)),
      );
      builder.finish(at: start.add(const Duration(milliseconds: 4200)));
      builder.append(text: '这是最终回答。每一步的工具参数和结果都可以展开查看。');
      await repository.insert(
        receipt(
          'search',
          name: 'web_search',
          payload: {
            'arguments': {'query': '本地模型运行说明'},
            'result': '已找到 3 条参考资料。',
            'durationMs': 650,
          },
        ),
      );
      await repository.insert(
        receipt(
          'clock',
          name: 'clock',
          payload: {
            'arguments': {},
            'result': '2026-11-19 21:30',
            'durationMs': 10,
          },
        ),
      );
      final m = message.copyWith(
        content: '已找到相关资料，我再核对一下。\n这是最终回答。每一步的工具参数和结果都可以展开查看。',
        reasoningContent: '先查看资料，再检查当前时间。信息已核对，整理成简明结论。',
        timeline: builder.snapshot,
      );
      for (final (name, theme) in [
        ('light', AppTheme.light()),
        ('dark', AppTheme.dark()),
      ]) {
        final displayTheme = previewFont.isEmpty
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'TimelinePreview'),
              );
        final capture = GlobalKey();
        await tester.pumpWidget(chat(m, theme: displayTheme, capture: capture));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('tool_toggle_run:clock')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('TIMELINE_PREVIEW')) {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '.dart_tool/agent-timeline-$name.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
      }
      await tester.pumpWidget(chat(m, scale: 2, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('tool_toggle_run:clock')),
      );
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:clock')));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-19 21:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'timeline interleaves prose, folds old steps and keeps unresolved receipts visible',
    (tester) async {
      final builder = ChatTimelineBuilder()
        ..append(reasoning: 'Plan')
        ..append(text: 'Checking.');
      for (var i = 0; i < 5; i++) {
        builder.tool('t$i', 'clock');
        await repository.insert(receipt('t$i'));
      }
      builder.append(text: 'Final answer');
      final m = message.copyWith(
        content: 'Checking.Final answer',
        reasoningContent: 'Plan',
        timeline: builder.snapshot,
      );
      await tester.pumpWidget(chat(m));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run:t0')), findsNothing);
      expect(find.byKey(const ValueKey('run:t3')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Checking.')).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('run:t3'))).dy),
      );
      expect(
        tester.getTopLeft(find.text('Final answer')).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('run:t4'))).dy,
        ),
      );
      final toggle = find.byKey(const ValueKey('timeline_expand_run:2'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run:t0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:t0')));
      await tester.pumpAndSettle();
      expect(find.text('saved output'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await repository.transition('run:t1', 'succeeded', 'unknownOutcome', {
        'arguments': {},
        'error': 'Uncertain',
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(chat(m));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run:t1')), findsOneWidget);
      expect(find.text('No execution record found'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'streaming timeline updates bodies without reloading receipts; version changes reset the view',
    (tester) async {
      await open();
      final builder = ChatTimelineBuilder()
        ..tool('live', 'clock')
        ..append(text: 'Before');
      var m = message.copyWith(content: 'Before', timeline: builder.snapshot);
      streaming.update(m, isStreaming: true);
      await tester.pumpWidget(chat(m, live: true));
      await repository.insert(receipt('live', state: 'executing'));
      await service.refresh();
      await tester.pump();
      expect(find.byType(ToolInvocationCard), findsOneWidget);
      expect(
        tester
            .widget<ToolInvocationCard>(find.byType(ToolInvocationCard))
            .inTimeline,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('run:0')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final reads = repository.reads;
      builder.append(text: ' after');
      m = m.copyWith(content: 'Before after', timeline: builder.snapshot);
      streaming.update(m, isStreaming: true);
      await tester.pump();
      expect(find.text('Before after'), findsOneWidget);
      expect(repository.reads, reads);
      await session!.close();
      streaming.remove(m.id);
      await repository.insert(receipt('other', run: 'alternative'));
      final nextBuilder = ChatTimelineBuilder()
        ..tool('other', 'clock')
        ..append(text: 'Other answer');
      await tester.pumpWidget(
        chat(
          m.copyWith(
            runId: 'alternative',
            content: 'Other answer',
            timeline: nextBuilder.snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run:live')), findsNothing);
      expect(find.byKey(const ValueKey('alternative:other')), findsOneWidget);
      expect(find.text('Other answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'timeline retains its prose and retry when receipt loading fails',
    (tester) async {
      final b = ChatTimelineBuilder()
        ..tool('saved', 'clock')
        ..append(text: 'Readable answer');
      await repository.insert(receipt('saved'));
      repository.failNext = true;
      await tester.pumpWidget(
        chat(
          message.copyWith(content: 'Readable answer', timeline: b.snapshot),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Readable answer'), findsOneWidget);
      expect(find.text('Could not load tool activity.'), findsOneWidget);
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run:saved')), findsOneWidget);
      expect(find.text('Readable answer'), findsOneWidget);
      expect(find.text('Could not load tool activity.'), findsNothing);
    },
  );

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
      await tester.pumpWidget(
        chat(
          message.copyWith(
            content: '',
            timeline: const [
              ChatTimelinePart(
                kind: ChatTimelineKind.tool,
                callId: 'ask',
                toolName: 'ask_user',
              ),
            ],
          ),
          live: true,
        ),
      );
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
