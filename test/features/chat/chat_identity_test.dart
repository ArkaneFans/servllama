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
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
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
    int maxTokens = 2048,
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

  test(
    'legacy Run identity is read without rewriting or breaking revision immutability',
    () async {
      final runs = GenerationRunRepository(db);
      final m = ChatMessageRecord(
        id: 'old',
        runId: 'old-run',
        role: ChatRole.assistant,
        content: 'Old answer',
        createdAt: DateTime(2026),
      );
      final v = ChatMessageVersionRecord(
        id: 'v-old',
        messageId: m.id,
        runId: m.runId,
        content: m.content,
        createdAt: m.createdAt,
      );
      await runs.begin('old-run', 'c', m.id, config(a).snapshot());
      await runs.finish('old-run', 'completed');
      await repository.saveMessage(m);
      final rawVersion = jsonEncode(encodeVersion(v));
      await db.execute(
        'INSERT INTO message_revisions(id,message_id,created_at,payload) VALUES(?,?,?,?)',
        [v.id, v.messageId, 0, rawVersion],
      );
      expect(
        (await repository.loadMessage(m.id))?.author?.toJson(),
        authorA.toJson(),
      );
      final loaded = (await repository.loadMessageVersion(v.id))!;
      expect(loaded.author?.toJson(), authorA.toJson());
      await repository.saveMessageVersion(loaded);
      await repository.saveMessageVersion(v);
      expect(
        (await db.query(
          'SELECT payload FROM message_revisions',
        )).single.read<String>('payload'),
        rawVersion,
      );
      await expectLater(
        repository.saveMessageVersion(
          ChatMessageVersionRecord(
            id: v.id,
            messageId: m.id,
            runId: m.runId,
            content: 'Different',
            createdAt: m.createdAt,
            author: loaded.author,
          ),
        ),
        throwsStateError,
      );
      await repository.saveMessage(m.copyWith(id: 'unknown', clearRunId: true));
      expect((await repository.loadMessage('unknown'))?.author, isNull);
    },
  );

  test(
    'recovery attributes an old partial checkpoint using its Run snapshot',
    () async {
      final runs = GenerationRunRepository(db);
      final m = ChatMessageRecord(
        id: 'm',
        runId: 'run',
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime(2026),
      );
      await repository.saveMessage(m);
      await runs.begin('run', 'c', m.id, {
        ...config(b).snapshot(),
        'versionId': 'v',
      });
      await runs.checkpoint('run', m.copyWith(content: 'Partial reply'));
      await runs.recover();
      await runs.recover();
      expect((await repository.loadMessage(m.id))?.author?.assistantId, 'b');
      expect(
        (await repository.loadMessageVersion('v'))?.author?.assistantId,
        'b',
      );
      expect(await db.query('SELECT id FROM message_revisions'), hasLength(1));
    },
  );

  test(
    'interruption before replacing the original restores its author and content',
    () async {
      final runs = GenerationRunRepository(db);
      final original = ChatMessageRecord(
        id: 'm',
        runId: 'old-run',
        role: ChatRole.assistant,
        content: 'Original',
        createdAt: DateTime(2026),
        author: authorA,
      );
      await repository.saveMessage(original);
      await runs.begin('new-run', 'c', original.id, {
        ...config(b).snapshot(),
        'versionId': 'new-v',
        'fallbackMessage': encodeMessage(original),
      });
      await runs.recover();
      final restored = (await repository.loadMessage(original.id))!;
      expect(restored.author?.toJson(), authorA.toJson());
      expect(restored.content, 'Original');
      expect(restored.runId, 'old-run');
      expect(await db.query('SELECT id FROM message_revisions'), isEmpty);
    },
  );

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
