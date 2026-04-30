import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatSessionRepository', () {
    late Directory appSupportDirectory;
    late ChatSessionRepository repository;

    setUp(() async {
      await Hive.close();
      appSupportDirectory = await Directory.systemTemp.createTemp(
        'servllama_chat_repo_',
      );
      repository = ChatSessionRepository(
        appSupportDirectory: appSupportDirectory,
        hive: Hive,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (await appSupportDirectory.exists()) {
        await appSupportDirectory.delete(recursive: true);
      }
    });

    test('persists sessions and sorts them by updatedAt descending', () async {
      final older = _session(
        id: 'older',
        title: '旧会话',
        updatedAt: DateTime(2026, 3, 25, 10),
      );
      final newer = _session(
        id: 'newer',
        title: '新会话',
        updatedAt: DateTime(2026, 3, 25, 11),
        messages: <ChatMessageRecord>[
          _message(
            id: 'm1',
            role: ChatRole.assistant,
            content: 'hello',
            modelName: 'model-a',
            reasoningContent: '先思考一下',
          ),
        ],
      );

      await repository.saveSession(older);
      await repository.saveSession(newer);

      final sessions = await repository.loadSessions();

      expect(sessions.map((session) => session.id).toList(), <String>[
        'newer',
        'older',
      ]);
      expect(sessions.first.messages.single.modelName, 'model-a');
      expect(sessions.first.messages.single.reasoningContent, '先思考一下');
    });

    test('deleteSession removes stored session', () async {
      await repository.saveSession(_session(id: 'one', title: '会话一'));
      await repository.saveSession(_session(id: 'two', title: '会话二'));

      await repository.deleteSession('one');

      final sessions = await repository.loadSessions();
      expect(sessions.map((session) => session.id), <String>['two']);
    });
  });
}

ChatSessionRecord _session({
  required String id,
  required String title,
  DateTime? updatedAt,
  List<ChatMessageRecord> messages = const <ChatMessageRecord>[],
}) {
  final createdAt = DateTime(2026, 3, 25, 9);
  return ChatSessionRecord(
    id: id,
    title: title,
    messages: messages,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
  );
}

ChatMessageRecord _message({
  required String id,
  required ChatRole role,
  required String content,
  String? modelName,
  String? reasoningContent,
}) {
  return ChatMessageRecord(
    id: id,
    role: role,
    content: content,
    createdAt: DateTime(2026, 3, 25, 9, 30),
    modelName: modelName,
    reasoningContent: reasoningContent,
  );
}
