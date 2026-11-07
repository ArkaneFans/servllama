import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'dart:io';
import 'dart:async';

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
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class _Protocol extends ChatProtocolClient {
  bool callTools = true;
  bool cancelAfterTerminal = false, failAfterTerminal = false;
  int? receivedMaxTokens;
  Duration outputDelay = Duration.zero;
  Completer<void>? paused;
  List<AiEvent> Function(List<AiTurn> turns, List<AiTool> tools)? responder;

  @override
  Stream<AiEvent> complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    String? runId,
  }) async* {
    receivedMaxTokens = maxTokens;
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
      if (cancelAfterTerminal) cancelToken.cancel('fixture');
      if (failAfterTerminal) throw StateError('fixture failure');
      return;
    }
    if (callTools && tools.isNotEmpty && turns.last.role != 'tool') {
      yield const AiEvent(
        stopReason: 'tool_calls',
        calls: [
          AiToolCall(
            id: 'ask',
            name: 'ask_user',
            arguments: {'question': 'Continue?'},
          ),
        ],
      );
    } else {
      yield const AiEvent(text: 'Final answer');
      yield const AiEvent(stopReason: 'stop');
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

  test('assistant maxTokens is not sent to the provider', () async {
    activeAssistant = assistant.changed({'maxTokens': 1});
    protocol.responder = (_, _) => const [
      AiEvent(text: 'Partial answer'),
      AiEvent(stopReason: 'length'),
    ];

    await runner.sendMessage('Hello');

    expect(protocol.receivedMaxTokens, isNull);
    expect(runner.stopReason, isNull);
    expect(
      logger
          .entriesFor(LogChannel.client)
          .where(
            (entry) => entry.message.contains('client.run.budget_reached'),
          ),
      isEmpty,
    );
  });

  test('assistant turn and tool call fields do not cap the loop', () async {
    activeAssistant = assistant.changed({'maxTurns': 1, 'maxToolCalls': 0});
    final running = runner.sendMessage('Hello');
    await waitForApproval();
    final run = service.activeRunId!;
    await service.decide('$run:ask', true, answer: 'Yes');
    await running;

    final reply = conversation.visibleMessages.last;
    expect(reply.content.trim(), 'Final answer');
    expect(reply.runId, run);
    expect(
      await service.repository.forRun(reply.sessionId!, run),
      hasLength(1),
    );
    expect(runner.stopReason, isNull);
  });

  test('assistant contextChars does not restrict the request input', () async {
    activeAssistant = assistant.changed({
      'contextChars': 1000,
      'instructions': 'x' * 2000,
    });
    protocol.callTools = false;

    await runner.sendMessage('Hello');

    expect(conversation.visibleMessages.last.content.trim(), 'Final answer');
    expect(runner.stopReason, isNull);
  });

  test('assistant timeoutSeconds is not used as a run deadline', () async {
    activeAssistant = assistant.changed({'timeoutSeconds': 0});
    protocol
      ..callTools = false
      ..outputDelay = const Duration(milliseconds: 20);

    await runner.sendMessage('Hello');

    expect(conversation.visibleMessages.last.content.trim(), 'Final answer');
    expect(runner.stopReason, isNull);
  });

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
      expect(await db.query('SELECT id FROM tool_invocations'), hasLength(1));
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
    'user versions can be selected and deleted without changing later replies',
    () async {
      protocol.callTools = false;
      await runner.sendMessage('Original question');
      final user = conversation.visibleMessages.first;
      final answer = conversation.visibleMessages.last;
      await runner.editMessage(
        messageId: user.id,
        newContent: 'Edited question',
      );
      final edited = conversation.visibleMessages.first;
      expect(edited.versionCount, 2);
      await runner.selectMessageVersion(messageId: user.id, versionIndex: 0);
      expect(conversation.visibleMessages.first.content, 'Original question');
      await expectLater(
        runner.deleteMessage(
          user.id,
          allVersions: false,
          expectedMessage: edited,
        ),
        throwsStateError,
      );
      await runner.deleteMessage(user.id, allVersions: false);
      expect(conversation.visibleMessages.first.content, 'Edited question');
      expect(conversation.visibleMessages.first.versionCount, 1);
      expect(conversation.visibleMessages.last.id, answer.id);
      expect(conversation.visibleMessages.last.runId, answer.runId);
      await runner.deleteMessage(user.id);
      expect(conversation.visibleMessages.single.id, answer.id);
      expect(await db.query('SELECT * FROM generation_runs'), hasLength(1));
    },
  );

  test(
    'cancelling an empty regeneration cannot resurrect a deleted revision or leak its run',
    () async {
      protocol.callTools = false;
      await runner.sendMessage('Hello');
      final id = conversation.visibleMessages.last.id;
      await runner.regenerateFromMessage(id);
      await runner.regenerateFromMessage(id);
      final deletedVersion = conversation.visibleMessages.last.versionIds.last;
      await runner.deleteMessage(id, allVersions: false);
      final retained = conversation.visibleMessages.last;
      expect(retained.versionIds, hasLength(2));
      protocol.paused = Completer<void>();
      final running = runner.regenerateFromMessage(id);
      await protocol.paused!.future;
      runner.cancelStreaming();
      await running;
      expect(conversation.visibleMessages.last.versionIds, retained.versionIds);
      expect(conversation.visibleMessages.last.runId, retained.runId);
      expect(await repository.loadMessageVersion(deletedVersion), isNull);
      expect(await db.query('SELECT * FROM generation_runs'), hasLength(2));
      expect(await db.query('SELECT * FROM message_revisions'), hasLength(3));
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
      expect(await db.query('SELECT id FROM tool_invocations'), hasLength(2));
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
      expect(await db.query('SELECT id FROM tool_invocations'), isEmpty);
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
  const nativeMetrics = GenerationMetrics(
    promptTokens: 100,
    promptMilliseconds: 200,
    predictedTokens: 20,
    predictedMilliseconds: 1000,
    inputTokens: 120,
    outputTokens: 20,
    cachedInputTokens: 20,
  );

  test(
    'metrics commit with response identity, survive history and switch revisions',
    () async {
      protocol.responder = (_, _) => const [
        AiEvent(text: 'First'),
        AiEvent(stopReason: 'stop', generationMetrics: nativeMetrics),
      ];
      await runner.sendMessage('Hello');
      final first = conversation.visibleMessages.last;
      final metrics = first.generationMetrics!;
      expect(metrics.prefillTokensPerSecond, 500);
      expect(metrics.modelId, 'model');
      expect(metrics.connectionId, 'c');
      expect(metrics.contextKey, isNotEmpty);
      expect(
        (await repository.loadMessage(first.id))!.generationMetrics,
        metrics,
      );
      expect(
        (await repository.loadMessageVersion(
          first.versionIds.single,
        ))!.generationMetrics,
        metrics,
      );
      protocol.responder = (_, _) => const [
        AiEvent(text: 'Second'),
        AiEvent(stopReason: 'stop'),
      ];
      await runner.regenerateFromMessage(first.id);
      expect(conversation.visibleMessages.last.generationMetrics, isNull);
      await runner.selectMessageVersion(messageId: first.id, versionIndex: 0);
      expect(conversation.visibleMessages.last.generationMetrics, metrics);
      await runner.editMessage(
        messageId: first.id,
        newContent: 'Manually changed',
      );
      expect(conversation.visibleMessages.last.generationMetrics, isNull);
    },
  );

  for (final cancel in [false, true]) {
    test(
      '${cancel ? 'cancelled' : 'failed'} run discards even already-received stats',
      () async {
        protocol.responder = (_, _) => const [
          AiEvent(text: 'Partial'),
          AiEvent(stopReason: 'stop', generationMetrics: nativeMetrics),
        ];
        protocol.cancelAfterTerminal = cancel;
        protocol.failAfterTerminal = !cancel;
        await runner.sendMessage('Hello');
        final message = conversation.visibleMessages.last;
        expect(message.generationMetrics, isNull);
        expect(
          (await repository.loadMessage(message.id))!.generationMetrics,
          isNull,
        );
      },
    );
  }

  test(
    'tool round stats aggregate durations and preserve only final context occupancy',
    () async {
      protocol.responder = (turns, _) => turns.last.role == 'tool'
          ? const [
              AiEvent(text: 'Final'),
              AiEvent(
                stopReason: 'stop',
                generationMetrics: GenerationMetrics(
                  promptTokens: 50,
                  promptMilliseconds: 300,
                  predictedTokens: 10,
                  predictedMilliseconds: 1000,
                  inputTokens: 200,
                  outputTokens: 11,
                  decodeIsEstimated: true,
                ),
              ),
            ]
          : const [
              AiEvent(
                stopReason: 'tool_calls',
                generationMetrics: nativeMetrics,
                calls: [
                  AiToolCall(
                    id: 'ask',
                    name: 'ask_user',
                    arguments: {'question': 'Continue?'},
                  ),
                ],
              ),
            ];
      final pending = runner.sendMessage('Hello');
      await waitForApproval();
      await service.decide('${service.activeRunId!}:ask', true, answer: 'Yes');
      await pending;
      final metrics = conversation.visibleMessages.last.generationMetrics!;
      expect(metrics.prefillTokensPerSecond, 300);
      expect(metrics.decodeTokensPerSecond, 15);
      expect(metrics.decodeIsEstimated, isTrue);
      expect(metrics.inputTokens, 320);
      expect(metrics.outputTokens, 31);
      expect(metrics.cachedInputTokens, isNull);
      expect(metrics.contextTokens, 211);
      expect(
        (await repository.loadMessage(
          conversation.visibleMessages.last.id,
        ))!.generationMetrics,
        metrics,
      );
    },
  );
}
