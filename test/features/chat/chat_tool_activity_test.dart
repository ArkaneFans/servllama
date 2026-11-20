import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/tool_part_card.dart';
import 'package:servllama/features/agent/widgets/web_search_receipt.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/services/stream_chunk_handler.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/text_sheen.dart';
import '../../support/agent_database_fixture.dart';
import '../../support/mcp_tool_fixture.dart';

class _Repository extends AgentRepository {
  _Repository(super.db);
  int reads = 0;
  Completer<List<ToolActivity>>? delayNext;
  @override
  Future<List<ToolActivity>> forRun(String conversationId, String runId) {
    reads++;
    if (delayNext case final delayed?) {
      delayNext = null;
      return delayed.future;
    }
    return super.forRun(conversationId, runId);
  }
}

class _DirectHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}

ToolPart tool(
  String id, {
  String name = 'clock',
  ToolState state = ToolState.succeeded,
  Map<String, dynamic> args = const {},
  String? result = 'saved output',
  Map<String, dynamic> metadata = const {},
}) => ToolPart(
  id: id,
  callId: id,
  name: name,
  input: jsonEncode(args),
  inputComplete: true,
  state: state,
  result: result,
  metadata: metadata,
);

void main() {
  late AppDatabase db;
  late Directory directory;
  late _Repository repository;
  late AgentToolService service;
  late StreamingChatMessageNotifier streaming;
  late ScrollController scroll;
  late ChatMessageRecord current;
  late CancelToken token;
  ToolSession? session;
  const assistant = Assistant(
    id: 'assistant',
    name: 'Assistant',
    tools: ['clock', 'ask_user'],
  );

  setUp(() async {
    db = AppDatabase.memory();
    directory = await Directory.systemTemp.createTemp('chat-parts-');
    repository = _Repository(db);
    service = AgentToolService(repository, directory);
    streaming = StreamingChatMessageNotifier();
    scroll = ScrollController();
    token = CancelToken();
    current = ChatMessageRecord(
      id: 'reply',
      sessionId: 'conversation',
      runId: 'run',
      versionIds: const ['run:fixture-version'],
      role: ChatRole.assistant,
      content: 'Final answer',
      createdAt: DateTime(2026),
      modelName: 'Actual model',
    );
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
      onPartChanged: (p) {
        final parts = current.parts.toList();
        final index = parts.indexWhere((old) => old.id == p.id);
        if (index < 0) {
          parts.add(p);
        } else {
          parts[index] = p;
        }
        current = current.copyWith(parts: List.unmodifiable(parts));
        streaming.update(current, isStreaming: true);
      },
    );
  }

  Widget chat(
    ChatMessageRecord m, {
    bool live = false,
    double scale = 1,
    ThemeData? theme,
  }) => ChangeNotifierProvider<AgentToolService>.value(
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
      home: Scaffold(
        body: ChatMessageList(
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

  test('late refresh cannot replace a newer saved tool state', () async {
    await open();
    current = current.copyWith(parts: const []);
    await repository.prepare('run', 'conversation', 'call', 'clock', {
      'arguments': {},
    });
    final older = await repository.forRun('conversation', 'run');
    final delayed = Completer<List<ToolActivity>>();
    repository.delayNext = delayed;
    final oldRefresh = service.refresh();
    await repository.transition('run:call', 'prepared', 'executing', {
      'arguments': {},
      'startedAt': 10,
    });
    await service.refresh();
    delayed.complete(older);
    await oldRefresh;
    expect(service.activeTools.single.state, 'executing');
    expect(
      current.parts.whereType<ToolPart>().single.state,
      ToolState.executing,
    );
  });

  testWidgets('saved parts render immediately in order without history reads', (
    tester,
  ) async {
    current = current.copyWith(
      parts: [
        tool('first'),
        tool('second', name: 'read_skill'),
        const TextPart('body', 'Final answer'),
      ],
    );
    await tester.pumpWidget(chat(current));
    await tester.pumpAndSettle();
    expect(repository.reads, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('first'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('second'))).dy),
    );
    expect(
      tester.getTopLeft(find.text('Actual model')).dy,
      greaterThan(tester.getBottomLeft(find.text('Final answer')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('tool_toggle_run:first')));
    await tester.pumpAndSettle();
    expect(find.text('saved output'), findsOneWidget);
    expect(repository.reads, 0);
    expect(find.text('No execution record found'), findsNothing);
  });

  testWidgets('partial input and result use the same expanded tool card', (
    tester,
  ) async {
    final h = StreamChunkHandler();
    h.handle(
      const ToolCallStart(id: 'series', callId: 'live', toolName: 'clock'),
    );
    h.handle(const ToolCallDelta(id: 'series', inputDelta: '{"zone":'));
    current = current.copyWith(parts: h.parts);
    streaming.update(current, isStreaming: true);
    streaming.update(current, isStreaming: true);
    await tester.pumpWidget(chat(current, live: true));
    await tester.pump();
    final before = tester.state(find.byType(ToolPartCard));
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tool_toggle_run:live')));
    await tester.pump();
    expect(find.text('{"zone":'), findsOneWidget);
    h.handle(const ToolCallDelta(id: 'series', inputDelta: '"UTC"}'));
    current = current.copyWith(parts: h.parts);
    streaming.update(current, isStreaming: true);
    await tester.pump();
    expect(find.text('{"zone":"UTC"}'), findsOneWidget);
    h.handle(
      const ToolCallEnd(
        id: 'series',
        call: AiToolCall(id: 'live', name: 'clock', arguments: {'zone': 'UTC'}),
      ),
    );
    h.updateTool(
      (h.parts.single as ToolPart).copyWith(
        state: ToolState.succeeded,
        result: 'Saved result',
      ),
    );
    current = current.copyWith(parts: h.parts);
    streaming.update(current, isStreaming: true);
    await tester.pump();
    expect(tester.state(find.byType(ToolPartCard)), same(before));
    expect(find.text('Saved result'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(repository.reads, 0);
  });

  testWidgets(
    'stopped incomplete input keeps its parameters and static title',
    (tester) async {
      final h = StreamChunkHandler();
      h.handle(const ToolCallStart(id: 'series', toolName: 'clock'));
      h.handle(const ToolCallDelta(id: 'series', inputDelta: '{"zone":'));
      current = current.copyWith(parts: h.parts);
      streaming.update(current, isStreaming: true);
      streaming.update(current, isStreaming: true);
      await tester.pumpWidget(chat(current, live: true));
      await tester.pump();
      expect(find.byType(ShaderMask), findsOneWidget);
      h.finish(stopped: true);
      current = current.copyWith(parts: h.parts);
      streaming.remove(current.id);
      await tester.pumpWidget(chat(current));
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
      expect(find.text('Tool call incomplete'), findsNothing);
      expect(find.text('Preparing tool call…'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:series')));
      await tester.pumpAndSettle();
      expect(find.text('{"zone":'), findsOneWidget);
      expect(tester.widget<TextSheen>(find.byType(TextSheen)).enabled, isFalse);
    },
  );

  testWidgets('version changes use selected parts with no stale tool joins', (
    tester,
  ) async {
    final original = current.copyWith(
      parts: [tool('first'), const TextPart('body', 'Original')],
    );
    await tester.pumpWidget(chat(original));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      chat(
        original.copyWith(
          parts: [
            tool('other', name: 'read_skill'),
            const TextPart('body2', 'Alternative'),
          ],
          currentVersionIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first')), findsNothing);
    expect(find.byKey(const ValueKey('other')), findsOneWidget);
    await tester.pumpWidget(
      chat(original.copyWith(content: 'Manual', clearRunId: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ToolPartCard), findsNothing);
    expect(find.text('Manual'), findsOneWidget);
    expect(repository.reads, 0);
  });

  testWidgets('inline answer is persisted to the part and cannot replay', (
    tester,
  ) async {
    await open();
    current = current.copyWith(parts: const []);
    streaming.update(current, isStreaming: true);
    await tester.pumpWidget(chat(current, live: true));
    final result = await pending(
      tester,
      const AiToolCall(
        id: 'ask',
        name: 'ask_user',
        arguments: {'question': 'Which format?'},
      ),
    );
    final approve = find.byKey(const ValueKey('tool_approve_run:ask'));
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('tool_answer_run:ask')),
      'Markdown',
    );
    await tester.pump();
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    expect(
      jsonDecode((await tester.runAsync(result))!.text)['answer'],
      'Markdown',
    );
    await tester.pump();
    expect(find.byTooltip('Completed'), findsOneWidget);
    expect(service.pendingCount, 0);
    final saved = (await repository.forRun('conversation', 'run')).single.part;
    expect(saved.result, contains('Markdown'));
    expect(saved.state, ToolState.succeeded);
    expect(find.text('Send answer'), findsNothing);
  });

  testWidgets('reject and cancel preserve the tool part and remove controls', (
    tester,
  ) async {
    await open();
    current = current.copyWith(parts: const []);
    streaming.update(current, isStreaming: true);
    await tester.pumpWidget(chat(current, live: true));
    final rejected = await pending(
      tester,
      const AiToolCall(
        id: 'reject',
        name: 'ask_user',
        arguments: {'question': 'Optional?'},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tool_reject_run:reject')));
    expect((await tester.runAsync(rejected))!.isError, isTrue);
    await tester.pump();
    expect(find.byTooltip('Rejected'), findsOneWidget);
    expect(
      (await repository.toolActivity('run:reject'))!.part.result,
      contains('declined'),
    );
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

  testWidgets('MCP approval executes once and updates the same part', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(
      () => McpToolFixture.start({
        'content': [
          {'type': 'text', 'text': 'Approved output'},
        ],
      }),
    ))!;
    addTearDown(fixture.close);
    final name = AgentToolService.mcpToolName(fixture.config.id, 'echo');
    final selected = assistant.changed({
      'tools': [name],
      'mcpServerIds': [fixture.config.id],
    });
    await tester.runAsync(
      () => HttpOverrides.runWithHttpOverrides(() async {
        await AssistantRepository(db).saveAssistant(selected);
        await repository.saveServer(fixture.config);
        await open(selected: selected);
      }, _DirectHttp()),
    );
    current = current.copyWith(parts: const []);
    streaming.update(current, isStreaming: true);
    await tester.pumpWidget(chat(current, live: true));
    final result = await pending(
      tester,
      AiToolCall(
        id: 'remote',
        name: name,
        arguments: const {'text': 'Approved output'},
      ),
    );
    expect(find.text('Fixture MCP'), findsOneWidget);
    final before = tester.state(find.byType(ToolPartCard));
    final approve = find.byKey(const ValueKey('tool_approve_run:remote'));
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    expect((await tester.runAsync(result))!.isError, isFalse);
    expect(fixture.calls, 1);
    await tester.pump();
    expect(tester.state(find.byType(ToolPartCard)), same(before));
    expect(find.byTooltip('Completed'), findsOneWidget);
    expect(
      (await repository.forRun('conversation', 'run')).single.part.result,
      contains('Approved output'),
    );
    await tester.runAsync(() => session!.close());
  });

  testWidgets(
    'phone themes and large text retain results, search and approval titles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      current = current.copyWith(
        parts: [
          ReasoningPart(
            'r',
            'Plan',
            startedAt: DateTime.utc(2026),
            finishedAt: DateTime.utc(2026).add(const Duration(seconds: 2)),
          ),
          tool(
            'search',
            name: 'web_search',
            args: {'query': 'Flutter'},
            result: jsonEncode({
              'provider': 'bing',
              'items': [
                {
                  'title': 'Flutter docs',
                  'url': 'https://docs.flutter.dev',
                  'snippet': 'Saved source',
                },
              ],
            }),
          ),
          const TextPart('body', 'Readable answer'),
          tool(
            'mcp',
            name: 'mcp_hash',
            state: ToolState.unknownOutcome,
            metadata: {
              'displayName': 'search_notes',
              'serverName': 'Notes server',
            },
          ),
        ],
      );
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(chat(current, theme: theme, scale: 1.5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('search_notes'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('tool_toggle_run:search')));
      await tester.pumpAndSettle();
      expect(find.byType(WebSearchReceipt), findsOneWidget);
      expect(find.text('Flutter docs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
