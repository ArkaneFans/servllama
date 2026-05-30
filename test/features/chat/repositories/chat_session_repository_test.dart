import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
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
      expect(sessions.first.messageIds, <String>['m1']);
      final messages = await repository.loadAllMessages(sessions.first);
      expect(messages.single.modelName, 'model-a');
      expect(messages.single.reasoningContent, '先思考一下');
    });

    test('persists message versions in a separate box', () async {
      final version = _version(
        id: 'v1',
        messageId: 'm1',
        content: '版本回答',
        modelName: 'model-a',
        reasoningContent: '版本推理',
      );
      await repository.saveMessageVersion(version);
      await repository.saveSession(
        _session(
          id: 's1',
          title: '会话',
          messages: <ChatMessageRecord>[
            _message(
              id: 'm1',
              role: ChatRole.assistant,
              content: '版本回答',
              modelName: 'model-a',
              reasoningContent: '版本推理',
              versionIds: const <String>['v1'],
              currentVersionIndex: 0,
            ),
          ],
        ),
      );

      final sessions = await repository.loadSessions();
      final loadedVersion = await repository.loadMessageVersion('v1');
      final messages = await repository.loadAllMessages(sessions.single);

      expect(sessions.single.messageIds, <String>['m1']);
      expect(messages.single.versionIds, <String>['v1']);
      expect(messages.single.currentVersionIndex, 0);
      expect(loadedVersion?.content, '版本回答');
      expect(loadedVersion?.reasoningContent, '版本推理');
    });

    test('loads recent and older message windows by messageIds', () async {
      final allMessages = List<ChatMessageRecord>.generate(
        35,
        (index) => _message(
          id: 'm$index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          content: 'message $index',
        ),
      );
      await repository.saveSession(
        _session(id: 's1', title: '会话', messages: allMessages),
      );

      final session = (await repository.loadSessions()).single;
      final recentMessages = await repository.loadRecentMessages(session);
      final olderMessages = await repository.loadMessagesBefore(
        session,
        beforeMessageId: recentMessages.first.id,
      );

      expect(recentMessages.first.id, 'm5');
      expect(recentMessages.last.id, 'm34');
      expect(olderMessages.map((message) => message.id), <String>[
        'm0',
        'm1',
        'm2',
        'm3',
        'm4',
      ]);
    });

    test('deleteSession removes stored session', () async {
      await repository.saveSession(_session(id: 'one', title: '会话一'));
      await repository.saveSession(_session(id: 'two', title: '会话二'));

      await repository.deleteSession('one');

      final sessions = await repository.loadSessions();
      expect(sessions.map((session) => session.id), <String>['two']);
    });

    test(
      'deleteSession removes message versions and version attachments',
      () async {
        final attachment = File(
          '${appSupportDirectory.path}\\version_image.txt',
        );
        await attachment.writeAsString('temp');
        await repository.saveMessageVersion(
          _version(
            id: 'v1',
            messageId: 'm1',
            content: '版本回答',
            imageFilePaths: <String>[attachment.path],
          ),
        );
        await repository.saveSession(
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              _message(
                id: 'm1',
                role: ChatRole.assistant,
                content: '版本回答',
                versionIds: const <String>['v1'],
              ),
            ],
          ),
        );

        await repository.deleteSession('s1');

        expect(await repository.loadMessageVersion('v1'), isNull);
        expect(await attachment.exists(), isFalse);
      },
    );
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
  List<String> versionIds = const <String>[],
  int currentVersionIndex = 0,
}) {
  return ChatMessageRecord(
    id: id,
    role: role,
    content: content,
    createdAt: DateTime(2026, 3, 25, 9, 30),
    modelName: modelName,
    reasoningContent: reasoningContent,
    versionIds: versionIds,
    currentVersionIndex: currentVersionIndex,
  );
}

ChatMessageVersionRecord _version({
  required String id,
  required String messageId,
  required String content,
  String? modelName,
  String? reasoningContent,
  List<String> imageFilePaths = const <String>[],
}) {
  return ChatMessageVersionRecord(
    id: id,
    messageId: messageId,
    content: content,
    createdAt: DateTime(2026, 3, 25, 9, 35),
    modelName: modelName,
    reasoningContent: reasoningContent,
    imageFilePaths: imageFilePaths,
  );
}
