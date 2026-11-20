import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import '../../support/stream_chunks.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_runner.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/presentation/chat_timeline_projection.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class _Protocol extends ChatProtocolClient {
  bool callTools = true;
  int? receivedMaxTokens;
  final reasoningLevels = <ReasoningLevel>[];
  Duration outputDelay = Duration.zero;
  Completer<void>? paused;
  List<StreamChunk> Function(List<AiTurn> turns, List<AiTool> tools)? responder;
  Stream<StreamChunk> Function(CancelToken token)? streamResponder;

  @override
  Stream<StreamChunk> complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    ReasoningLevel reasoningLevel = ReasoningLevel.auto,
    String? runId,
  }) async* {
    receivedMaxTokens = maxTokens;
    reasoningLevels.add(reasoningLevel);
    if (streamResponder case final respond?) {
      yield* respond(cancelToken);
      return;
    }
    if (paused != null) {
      paused!.complete();
      throw await cancelToken.whenCancel;
    }
    if (outputDelay > Duration.zero) {
      await Future<void>.delayed(outputDelay);
    }
    final responder = this.responder;
    if (responder != null) {
      for (final event in responder(turns, tools)) {
        yield event;
      }
      return;
    }
    if (callTools && tools.isNotEmpty && turns.last.role != 'tool') {
      yield* Stream.fromIterable(
        fixtureChunks(
          stopReason: 'tool_calls',
          calls: [
            AiToolCall(
              id: 'ask',
              name: 'ask_user',
              arguments: {'question': 'Continue?'},
            ),
          ],
        ),
      );
    } else {
      yield* Stream.fromIterable(fixtureChunks(text: 'Final answer'));
      yield* Stream.fromIterable(fixtureChunks(stopReason: 'stop'));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory directory;
  late ChatSessionRepository repository;
  late ChatConversationController conversation;
  late ChatSessionListController sessions;
  late ChatModelController models;
  late ChatRunner runner;
  late AgentToolService service;
  late _Protocol protocol;
  late AppLogger logger;
  late Assistant activeAssistant;
  const assistant = Assistant(id: 'a', name: 'Assistant', tools: ['ask_user']);
  const connection = AiConnection(
    id: 'c',
    name: 'Connection',
    protocol: AiProtocol.openai,
    baseUrl: 'https://example.org',
    models: ['model'],
    modelCapabilities: {'model': ModelCapabilities(supportsThinking: true)},
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tool-run-');
    db = AppDatabase.memory();
    AppDatabase.current = db;
    await db.setMetadata('legacyImportComplete', '1');
    final assistants = AssistantRepository(db);
    await assistants.saveAssistant(assistant);
    await assistants.saveConnection(connection);
    repository = ChatSessionRepository(
      database: db,
      appSupportDirectory: directory,
    );
    service = AgentToolService(AgentRepository(db), directory);
    AgentToolService.current = service;
    final api = LlamaChatApiClient();
    logger = AppLogger();
    activeAssistant = assistant;
    sessions = ChatSessionListController(repository: repository);
    conversation = ChatConversationController(
      repository: repository,
      sessionList: sessions,
      messageWindowSize: 30,
    );
    models = ChatModelController(apiClient: api);
    protocol = _Protocol();
    runner =
        ChatRunner(
            repository: repository,
            apiClient: api,
            sessionList: sessions,
            conversation: conversation,
            models: models,
            idGenerator: ChatIdGenerator(),
            defaultSessionTitle: 'New chat',
            logger: logger,
            protocolClient: protocol,
          )
          ..isRemote = true
          ..targetModel = const ChatModelOption(
            id: 'model',
            displayName: 'model',
            status: ChatModelStatus.loaded,
          )
          ..configuration = () async => ChatRunConfig(
            assistant: activeAssistant,
            connection: connection,
            key: '',
            modelId: 'model',
            isLocal: false,
          );
  });
  tearDown(() async {
    runner.dispose();
    conversation.dispose();
    sessions.dispose();
    models.dispose();
    service.dispose();
    AgentToolService.current = null;
    AppDatabase.current = null;
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> waitForApproval() async {
    for (var i = 0; i < 200 && service.pendingCount == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(service.pendingCount, 1);
  }

  test(
    'partial parameters are visible before execution and cancel as incomplete history',
    () async {
      final entered = Completer<void>();
      protocol.streamResponder = (token) async* {
        yield const ToolCallStart(
          id: 'series',
          callId: 'ask',
          toolName: 'ask_user',
        );
        yield const ToolCallDelta(
          id: 'series',
          inputDelta: '{"question":"private-preview',
        );
        entered.complete();
        throw await token.whenCancel;
      };
      final running = runner.sendMessage('Hello');
      await entered.future;
      final live = runner.streamingMessages
          .listenableFor(conversation.visibleMessages.last.id)!
          .value
          .message;
      expect(
        (live.parts.single as ToolPart).input,
        contains('private-preview'),
      );
      expect((live.parts.single as ToolPart).inputComplete, isFalse);
      expect(service.activeTools, isEmpty);
      expect(service.pendingCount, 0);
      runner.cancelStreaming();
      await running;
      final saved = (await repository.loadMessage(live.id))!;
      expect(saved.parts.single.id, 'series');
      expect((saved.parts.single as ToolPart).inputComplete, isFalse);
      expect(MessagePart.encode(saved.parts), contains('private-preview'));
      expect(
        await service.repository.forRun(saved.sessionId!, saved.runId!),
        everyElement(
          predicate<ToolActivity>(
            (a) => a.state == 'cancelled' && a.part.startedAt == null,
          ),
        ),
      );
    },
  );

  test(
    'validated individual call waits for whole round before approval',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      protocol.streamResponder = (token) async* {
        yield const ToolCallStart(
          id: 'series',
          callId: 'ask',
          toolName: 'ask_user',
        );
        yield const ToolCallDelta(
          id: 'series',
          inputDelta: '{"question":"Continue?"}',
        );
        yield const ToolCallEnd(
          id: 'series',
          call: AiToolCall(
            id: 'ask',
            name: 'ask_user',
            arguments: {'question': 'Continue?'},
          ),
        );
        entered.complete();
        await Future.any([release.future, token.whenCancel]);
        if (token.isCancelled) throw token.cancelError!;
        yield const Finish(stopReason: 'tool_calls');
      };
      final running = runner.sendMessage('Hello');
      await entered.future;
      expect(
        runner.streamingMessages
            .listenableFor(conversation.visibleMessages.last.id)!
            .value
            .message
            .parts
            .whereType<ToolPart>()
            .single
            .inputComplete,
        isTrue,
      );
      expect(service.activeTools, isEmpty);
      release.complete();
      await waitForApproval();
      expect(service.activeTools.single.callId, 'ask');
      runner.cancelStreaming();
      await running;
    },
  );

  test(
    'a failed later call or dropped round never executes earlier validated calls',
    () async {
      protocol.streamResponder = (_) async* {
        yield const ToolCallStart(
          id: 'series',
          callId: 'ask',
          toolName: 'ask_user',
        );
        yield const ToolCallEnd(
          id: 'series',
          call: AiToolCall(
            id: 'ask',
            name: 'ask_user',
            arguments: {'question': 'Continue?'},
          ),
        );
        yield const ToolCallStart(
          id: 'broken',
          callId: 'second',
          toolName: 'ask_user',
        );
        yield const ToolCallDelta(id: 'broken', inputDelta: '{"question":');
        throw const FormatException('Invalid tool arguments JSON');
      };
      await runner.sendMessage('Hello');
      expect(service.activeTools, isEmpty);
      expect(service.pendingCount, 0);
      final saved = (await repository.loadMessage(
        conversation.visibleMessages.last.id,
      ))!;
      expect(saved.parts.whereType<ToolPart>(), hasLength(2));
      expect(saved.parts.whereType<ToolPart>().last.inputComplete, isFalse);
      expect(
        await service.repository.forRun(saved.sessionId!, saved.runId!),
        everyElement(
          predicate<ToolActivity>(
            (a) => a.state == 'cancelled' && a.part.startedAt == null,
          ),
        ),
      );
    },
  );

  test(
    'reused vendor call IDs cannot attach a new node to an old receipt',
    () async {
      protocol.responder = (_, _) => fixtureChunks(
        calls: const [
          AiToolCall(
            id: 'ask',
            name: 'ask_user',
            arguments: {'question': 'Continue?'},
          ),
        ],
        stopReason: 'tool_calls',
      );
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      final run = service.activeRunId!;
      await service.decide('$run:ask', true, answer: 'Yes');
      await running;
      final saved = (await repository.loadMessage(
        conversation.visibleMessages.last.id,
      ))!;
      expect(saved.parts.whereType<ToolPart>(), hasLength(1));
      expect(
        await service.repository.forRun(saved.sessionId!, run),
        hasLength(1),
      );
    },
  );

  test(
    'ordered reasoning, tools and prose persist through reload, versions and edits',
    () async {
      protocol.responder = (turns, tools) => turns.last.role == 'tool'
          ? [
              ...fixtureChunks(reasoning: 'Second thought'),
              ...fixtureChunks(text: 'Answer'),
              ...fixtureChunks(stopReason: 'stop'),
            ]
          : [
              ...fixtureChunks(reasoning: 'First '),
              ...fixtureChunks(reasoning: 'thought'),
              ...fixtureChunks(text: 'Checking.'),
              ...fixtureChunks(
                stopReason: 'tool_calls',
                calls: [
                  AiToolCall(
                    id: 'ask',
                    name: 'ask_user',
                    arguments: {'question': 'Continue?'},
                  ),
                ],
              ),
            ];
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      final run = service.activeRunId!;
      final draft = conversation.visibleMessages.last;
      final live = runner.streamingMessages
          .listenableFor(draft.id)!
          .value
          .message;
      expect((live.parts.last as ToolPart).callId, 'ask');
      final checkpoint = (await repository.loadMessage(draft.id))!;
      expect((checkpoint.parts.last as ToolPart).callId, 'ask');
      expect(service.activeTools.single.payload['startedAt'], isNull);
      final approvedAt = DateTime.now().millisecondsSinceEpoch;
      await service.decide('$run:ask', true, answer: 'Yes');
      await running;
      final saved = (await repository.loadMessage(draft.id))!;
      final receipts = await service.repository.forRun(saved.sessionId!, run);
      final blocks = projectChatTimeline(saved);
      expect(
        blocks.map(
          (b) => b.text ?? b.steps.map((s) => s.part.kind.name).join(','),
        ),
        ['reasoning', 'Checking.', 'tool,reasoning', 'Answer'],
      );
      expect(blocks[2].steps.last.text, 'Second thought');
      expect(
        saved.parts.whereType<ReasoningPart>().every(
          (p) => p.finishedAt != null,
        ),
        isTrue,
      );
      expect(receipts.single.payload['durationMs'], isA<int>());
      expect(receipts.single.payload['startedAt'], isA<int>());
      expect(
        receipts.single.payload['startedAt'] as int,
        greaterThanOrEqualTo(approvedAt),
      );
      final serialized = MessagePart.encode(saved.parts);
      protocol.responder = (_, _) => [
        ...fixtureChunks(text: 'New answer'),
        ...fixtureChunks(stopReason: 'stop'),
      ];
      await runner.regenerateFromMessage(saved.id);
      expect(conversation.visibleMessages.last.parts, hasLength(1));
      await runner.selectMessageVersion(messageId: saved.id, versionIndex: 0);
      expect(
        MessagePart.encode(conversation.visibleMessages.last.parts),
        serialized,
      );
      await runner.editMessage(messageId: saved.id, newContent: 'Manual edit');
      final edited = (await repository.loadMessage(saved.id))!;
      expect(edited.parts.single, isA<TextPart>());
      expect(edited.runId, isNull);
      await runner.selectMessageVersion(messageId: saved.id, versionIndex: 0);
      expect(
        MessagePart.encode(conversation.visibleMessages.last.parts),
        serialized,
      );
    },
  );

  test(
    'cancellation closes reasoning and retains queued tool references without execution',
    () async {
      protocol.responder = (_, _) => [
        ...fixtureChunks(reasoning: 'Plan'),
        ...fixtureChunks(
          stopReason: 'tool_calls',
          calls: [
            AiToolCall(
              id: 'first',
              name: 'ask_user',
              arguments: {'question': 'First?'},
            ),
            AiToolCall(
              id: 'second',
              name: 'ask_user',
              arguments: {'question': 'Second?'},
            ),
          ],
        ),
      ];
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      runner.cancelStreaming();
      await running;
      final saved = (await repository.loadMessage(
        conversation.visibleMessages.last.id,
      ))!;
      expect(saved.reasoningContent, 'Plan');
      expect(saved.parts.map((p) => p.kind), [
        MessagePartKind.reasoning,
        MessagePartKind.tool,
        MessagePartKind.tool,
      ]);
      expect((saved.parts.first as ReasoningPart).finishedAt, isNotNull);
      final receipts = await service.repository.forRun(
        saved.sessionId!,
        saved.runId!,
      );
      expect(receipts, hasLength(2));
      expect(receipts.every((a) => a.state == 'cancelled'), isTrue);
      expect(receipts.last.part.startedAt, isNull);
      final steps = projectChatTimeline(saved).single.steps;
      expect(steps.last.invocation!.part.startedAt, isNull);
      expect(steps.last.invocation!.state, 'cancelled');
      expect((steps.last.part as ToolPart).callId, 'second');
    },
  );

  test(
    'thinking level stays frozen through tools and changes on the next run',
    () async {
      activeAssistant = assistant.changed({'reasoningLevel': 'high'});
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      final run = service.activeRunId!;
      activeAssistant = assistant.changed({'reasoningLevel': 'low'});
      await service.decide('$run:ask', true, answer: 'Yes');
      await running;
      expect(protocol.reasoningLevels, [
        ReasoningLevel.high,
        ReasoningLevel.high,
      ]);
      final row = (await db.query(
        'SELECT snapshot FROM generation_runs WHERE id=?',
        [run],
      )).single;
      expect(
        jsonDecode(row.read<String>('snapshot'))['assistant']['reasoningLevel'],
        'high',
      );
      protocol.callTools = false;
      await runner.sendMessage('Again');
      expect(protocol.reasoningLevels.last, ReasoningLevel.low);
    },
  );

  test(
    'cancelling before any text retains the tool-only reply and its revision',
    () async {
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      final run = service.activeRunId!;
      runner.cancelStreaming();
      await running;
      final reply = conversation.visibleMessages.last;
      expect(reply.role, ChatRole.assistant);
      expect(reply.content, isEmpty);
      expect(reply.runId, run);
      expect(reply.versionIds, hasLength(1));
      expect((await repository.loadMessage(reply.id))?.runId, run);
      expect(
        (await repository.loadMessageVersion(reply.versionIds.single))?.runId,
        run,
      );
      expect(
        (await service.repository.forRun(reply.sessionId!, run)).single.state,
        'cancelled',
      );
      expect(runner.isSending, isFalse);
    },
  );

  test(
    'cancelled tool regeneration keeps both versions and their separate runs',
    () async {
      protocol.callTools = false;
      await runner.sendMessage('Hello');
      final original = conversation.visibleMessages.last;
      protocol.callTools = true;
      final running = runner.regenerateFromMessage(original.id);
      await waitForApproval();
      final run = service.activeRunId!;
      runner.cancelStreaming();
      await running;
      final reply = conversation.visibleMessages.last;
      expect(reply.content, isEmpty);
      expect(reply.runId, run);
      expect(reply.versionIds, hasLength(2));
      await runner.selectMessageVersion(messageId: reply.id, versionIndex: 0);
      expect(conversation.visibleMessages.last.content, 'Final answer');
      expect(conversation.visibleMessages.last.runId, original.runId);
      await runner.selectMessageVersion(messageId: reply.id, versionIndex: 1);
      expect(conversation.visibleMessages.last.content, isEmpty);
      expect(conversation.visibleMessages.last.runId, run);
      expect(
        await service.repository.history(conversation.selectedSession!.id),
        hasLength(1),
      );
    },
  );

  test(
    'deleting the current tool version removes only its own receipts and can then remove all versions',
    () async {
      final first = runner.sendMessage('Hello');
      await waitForApproval();
      await service.decide('${service.activeRunId}:ask', true, answer: 'Yes');
      await first;
      final original = conversation.visibleMessages.last;
      final second = runner.regenerateFromMessage(original.id);
      await waitForApproval();
      final secondRun = service.activeRunId!;
      // Generation/approval owns the draft until it reaches a terminal state.
      await runner.deleteMessage(original.id);
      expect(await repository.loadMessage(original.id), isNotNull);
      runner.cancelStreaming();
      await second;
      final current = conversation.visibleMessages.last;
      await runner.deleteMessage(
        current.id,
        allVersions: false,
        expectedMessage: current,
      );
      final restored = conversation.visibleMessages.last;
      expect(restored.runId, original.runId);
      expect(restored.versionIds, original.versionIds);
      expect(
        (await service.repository.history(restored.sessionId!)).single.runId,
        original.runId,
      );
      expect(
        await db.query('SELECT * FROM generation_runs WHERE id=?', [secondRun]),
        isEmpty,
      );
      await runner.deleteMessage(restored.id, allVersions: false);
      expect(conversation.visibleMessages.map((m) => m.role), [ChatRole.user]);
      expect(
        (await repository.loadSessions()).single.messageIds,
        conversation.visibleMessages.map((m) => m.id),
      );
      expect(await service.repository.history(original.sessionId!), isEmpty);
      expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
    },
  );

  test(
    'regeneration starts a fresh tool run and preserves the previous run',
    () async {
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      final originalRun = service.activeRunId!;
      await service.decide('$originalRun:ask', true, answer: 'Yes');
      await running;
      final original = conversation.visibleMessages.last;

      final regenerating = runner.regenerateFromMessage(original.id);
      await waitForApproval();
      final regeneratedRun = service.activeRunId!;
      expect(regeneratedRun, isNot(originalRun));
      await service.decide('$regeneratedRun:ask', true, answer: 'Yes');
      await regenerating;

      final regenerated = conversation.visibleMessages.last;
      expect(regenerated.content.trim(), 'Final answer');
      expect(regenerated.runId, regeneratedRun);
      expect(
        await service.repository.forRun(regenerated.sessionId!, originalRun),
        hasLength(1),
      );
      expect(
        await service.repository.forRun(regenerated.sessionId!, regeneratedRun),
        hasLength(1),
      );
      expect(
        await service.repository.history(conversation.selectedSession!.id),
        hasLength(2),
      );
    },
  );

  test(
    'user regeneration truncates following messages and their runs',
    () async {
      final first = runner.sendMessage('First');
      await waitForApproval();
      final firstRun = service.activeRunId!;
      await service.decide('$firstRun:ask', true, answer: 'Yes');
      await first;

      protocol.callTools = false;
      await runner.sendMessage('Second');
      final user = conversation.visibleMessages.first;
      final removedRuns = conversation.visibleMessages
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.runId!)
          .toSet();
      expect(removedRuns, hasLength(2));

      await runner.regenerateFromMessage(user.id);

      final messages = conversation.visibleMessages;
      expect(messages, hasLength(2));
      expect(messages.first.id, user.id);
      expect(messages.last.role, ChatRole.assistant);
      expect(messages.last.runId, isNot(isIn(removedRuns)));
      expect(
        await service.repository.history(conversation.selectedSession!.id),
        isEmpty,
      );
      for (final runId in removedRuns) {
        expect(
          await db.query('SELECT id FROM generation_runs WHERE id=?', [runId]),
          isEmpty,
        );
      }
    },
  );

  test(
    'failed edit does not publish a new version or change the selected body',
    () async {
      protocol.callTools = false;
      await runner.sendMessage('Hello');
      final before = conversation.visibleMessages.last;
      await db.execute(
        "CREATE TRIGGER reject_edit BEFORE UPDATE ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        runner.editMessage(
          messageId: before.id,
          newContent: 'Uncommitted edit',
        ),
        throwsA(anything),
      );
      final saved = (await repository.loadMessage(before.id))!;
      expect(saved.versionIds, before.versionIds);
      expect(saved.content, before.content);
      expect(conversation.visibleMessages.last.content, before.content);
      expect(
        await db.query('SELECT id FROM message_revisions WHERE message_id=?', [
          before.id,
        ]),
        hasLength(1),
      );
    },
  );

  test(
    'failed generation start retains the user message but no Run or assistant draft',
    () async {
      protocol.callTools = false;
      await repository.warmUpMessageStore();
      await db.execute(
        "CREATE TRIGGER reject_draft BEFORE INSERT ON messages WHEN NEW.role='assistant' BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(runner.sendMessage('Keep question'), throwsA(anything));
      expect(runner.isSending, isFalse);
      expect(conversation.visibleMessages.single.content, 'Keep question');
      expect(await db.query('SELECT id FROM generation_runs'), isEmpty);
      expect(await db.query('SELECT id FROM message_revisions'), hasLength(1));
    },
  );

  test(
    'failed terminal commit is recovered once without duplicating a response',
    () async {
      protocol.callTools = false;
      await repository.warmUpMessageStore();
      await db.execute(
        "CREATE TRIGGER reject_finish BEFORE UPDATE OF state ON generation_runs WHEN NEW.state='completed' BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(runner.sendMessage('Hello'), throwsA(anything));
      expect(runner.isSending, isFalse);
      final id = conversation.visibleMessages.last.id;
      expect((await repository.loadMessage(id))!.content, 'Final answer');
      expect(
        (await db.query(
          'SELECT is_draft FROM message_revisions WHERE message_id=?',
          [id],
        )).single.read<int>('is_draft'),
        1,
      );
      await db.execute('DROP TRIGGER reject_finish');
      await GenerationRunRepository(db).recover();
      await GenerationRunRepository(db).recover();
      expect((await repository.loadMessage(id))!.content, 'Final answer');
      expect(
        await db.query('SELECT id FROM message_revisions WHERE message_id=?', [
          id,
        ]),
        hasLength(1),
      );
      expect(
        (await db.query(
          'SELECT state FROM generation_runs',
        )).single.read<String>('state'),
        'interrupted',
      );
    },
  );
}
