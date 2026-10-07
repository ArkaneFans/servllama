import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
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
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class _Protocol extends ChatProtocolClient {
  bool callTools = true;
  Completer<void>? paused;
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
    int maxTokens = 2048,
    String? runId,
  }) async* {
    if (paused != null) {
      paused!.complete();
      throw await cancelToken.whenCancel;
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
            protocolClient: protocol,
          )
          ..isRemote = true
          ..targetModel = const ChatModelOption(
            id: 'model',
            displayName: 'model',
            status: ChatModelStatus.loaded,
          )
          ..configuration = () async => ChatRunConfig(
            assistant: assistant,
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
      final running = runner.regenerateFromMessage(
        original.id,
        executeTools: true,
      );
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
      final second = runner.regenerateFromMessage(
        original.id,
        executeTools: true,
      );
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
      expect(await db.query('SELECT * FROM message_revisions'), hasLength(2));
    },
  );

  test(
    'rephrasing reads saved receipts without executing or claiming new calls',
    () async {
      final running = runner.sendMessage('Hello');
      await waitForApproval();
      await service.decide('${service.activeRunId}:ask', true, answer: 'Yes');
      await running;
      final original = conversation.visibleMessages.last;
      await runner.regenerateFromMessage(original.id);
      final rephrased = conversation.visibleMessages.last;
      expect(rephrased.content, 'Final answer');
      expect(rephrased.runId, isNot(original.runId));
      expect(
        await service.repository.forRun(rephrased.sessionId!, rephrased.runId!),
        isEmpty,
      );
      expect(await db.query('SELECT id FROM tool_invocations'), hasLength(1));
    },
  );
}
