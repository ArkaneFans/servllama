import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_runner.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class _Protocol extends ChatProtocolClient {
  final inputs = <List<AiTurn>>[];
  final systems = <String>[];
  void Function()? onRequest;
  bool empty = false;
  Object? failure;

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
    inputs.add(List.of(turns));
    systems.add(system);
    onRequest?.call();
    if (failure != null) throw failure!;
    if (!empty) yield AiEvent(text: 'Reply ${inputs.length}');
    yield const AiEvent(stopReason: 'stop');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = Assistant(id: 'a', name: 'Author A', avatar: '🦙');
  const b = Assistant(id: 'b', name: 'Author B', avatar: '📚');
  const connection = AiConnection(
    id: 'c',
    name: 'C',
    protocol: AiProtocol.openai,
    baseUrl: 'https://example.org',
  );
  const authorA = MessageAuthor(assistantId: 'a', name: 'Author A');
  late AppDatabase db;
  late Directory directory;
  late ChatSessionRepository repository;
  late ChatConversationController conversation;
  late ChatSessionListController sessions;
  late ChatModelController models;
  late ChatRunner runner;
  late _Protocol protocol;
  late Assistant current;
  ChatRunConfig config(Assistant assistant) => ChatRunConfig(
    assistant: assistant,
    connection: connection,
    key: '',
    modelId: 'model',
    isLocal: false,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('servllama_identity_');
    db = AppDatabase.memory();
    AppDatabase.current = db;
    await db.setMetadata('legacyImportComplete', '1');
    repository = ChatSessionRepository(
      database: db,
      appSupportDirectory: directory,
    );
    final api = LlamaChatApiClient();
    sessions = ChatSessionListController(repository: repository);
    conversation = ChatConversationController(
      repository: repository,
      sessionList: sessions,
      messageWindowSize: 30,
    );
    models = ChatModelController(apiClient: api);
    protocol = _Protocol();
    current = a;
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
          ..configuration = () async => config(current);
  });
  tearDown(() async {
    runner.dispose();
    conversation.dispose();
    sessions.dispose();
    models.dispose();
    AppDatabase.current = null;
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'generation freezes author and keeps display data out of model inputs and avatar out of history',
    () async {
      protocol.onRequest = () => current = b;
      await runner.sendMessage('Hello');
      final m = conversation.visibleMessages.last;
      expect(m.author?.toJson(), authorA.toJson());
      expect((await repository.loadMessage(m.id))?.author?.assistantId, 'a');
      expect(
        (await repository.loadMessageVersion(
          m.versionIds.single,
        ))?.author?.assistantId,
        'a',
      );
      expect(protocol.systems, ['']);
      expect(protocol.inputs.single.single.text, 'Hello');
      expect(protocol.inputs.single.single.images, isEmpty);
      final run = (await db.query(
        'SELECT snapshot,checkpoint FROM generation_runs',
      )).single;
      final snapshot = jsonDecode(run.read<String>('snapshot')) as Map;
      expect(snapshot['assistant'], isNot(contains('avatar')));
      expect(snapshot, isNot(contains('profile')));
      expect(run.read<String>('checkpoint'), isNot(contains('🦙')));
      expect(run.read<String>('checkpoint'), isNot(contains('🌿')));
    },
  );

  test(
    'regeneration, edits and version switching retain the correct author',
    () async {
      await runner.sendMessage('Hello');
      final id = conversation.visibleMessages.last.id;
      current = b;
      await runner.regenerateFromMessage(id);
      expect(conversation.visibleMessages.last.author?.assistantId, 'b');
      expect(conversation.visibleMessages.last.versionIds, hasLength(2));
      await runner.selectMessageVersion(messageId: id, versionIndex: 0);
      expect(conversation.visibleMessages.last.content, 'Reply 1');
      expect(conversation.visibleMessages.last.author?.assistantId, 'a');
      await runner.selectMessageVersion(messageId: id, versionIndex: 1);
      await runner.editMessage(messageId: id, newContent: 'Edited reply');
      expect(conversation.visibleMessages.last.author?.assistantId, 'b');
      expect(conversation.visibleMessages.last.runId, isNull);
      expect(
        (await repository.loadMessageVersion(
          conversation.visibleMessages.last.versionIds.last,
        ))?.author?.assistantId,
        'b',
      );
      current = a;
      protocol.empty = true;
      await runner.regenerateFromMessage(id);
      expect(conversation.visibleMessages.last.content, 'Edited reply');
      expect(conversation.visibleMessages.last.author?.assistantId, 'b');
    },
  );

  test(
    'failed requests are still attributed to their frozen assistant',
    () async {
      protocol.failure = StateError('fixture');
      await runner.sendMessage('Hello');
      final m = conversation.visibleMessages.last;
      expect(m.content, contains('Request Failed'));
      expect(m.author?.assistantId, 'a');
      expect(
        (await repository.loadMessageVersion(
          m.versionIds.single,
        ))?.author?.assistantId,
        'a',
      );
    },
  );

  test('committed versions keep identity and are immutable', () async {
    await runner.sendMessage('Hello');
    final message = conversation.visibleMessages.last;
    final version = (await repository.loadMessageVersion(
      message.versionIds.single,
    ))!;
    await repository.saveMessageVersion(version);
    await expectLater(
      repository.saveMessageVersion(
        ChatMessageVersionRecord(
          id: version.id,
          messageId: message.id,
          runId: version.runId,
          author: const MessageAuthor(assistantId: 'changed', name: 'Changed'),
          content: version.content,
          createdAt: version.createdAt,
        ),
      ),
      throwsStateError,
    );
    expect(
      (await repository.loadMessageVersion(version.id))!.author?.toJson(),
      authorA.toJson(),
    );
  });

  test('display attribution and avatar do not change continuation context', () {
    final m = ChatMessageRecord(
      id: 'm',
      role: ChatRole.assistant,
      content: 'Reply',
      createdAt: DateTime(2026),
    );
    final key = ChatRunner.historyContextKey(config(a), [m]);
    expect(
      ChatRunner.historyContextKey(config(a.changed({'avatar': '📚'})), [
        m.copyWith(author: authorA),
      ]),
      key,
    );
  });
}
