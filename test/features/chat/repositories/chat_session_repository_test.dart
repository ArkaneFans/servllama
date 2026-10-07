import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
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
      await repository.close();
      await Hive.close();
      if (await appSupportDirectory.exists()) {
        await appSupportDirectory.delete(recursive: true);
      }
    });

    test(
      'a failed conversation commit never leaves an orphan user message',
      () async {
        final db = await repository.database;
        await db.execute(
          "CREATE TRIGGER reject_conversation BEFORE INSERT ON conversations BEGIN SELECT RAISE(ABORT,'fixture storage failure'); END",
        );
        final message = _message(
          id: 'm',
          role: ChatRole.user,
          content: 'keep my draft',
        );
        await expectLater(
          repository.commitSession(
            _session(id: 'c', title: 'test').copyWith(messageIds: ['m']),
            changedMessages: [message.copyWith(sessionId: 'c')],
          ),
          throwsA(anything),
        );
        expect(await repository.loadMessage('m'), isNull);
        expect(await repository.loadSessions(), isEmpty);
      },
    );

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

    test(
      'saveMessage persists a single message without touching the session',
      () async {
        await repository.saveSession(
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              _message(id: 'm1', role: ChatRole.user, content: '问题'),
              _message(id: 'm2', role: ChatRole.assistant, content: ''),
            ],
          ),
        );
        final saved = (await repository.loadSessions()).single;

        await repository.saveMessage(
          _message(id: 'm2', role: ChatRole.assistant, content: '部分回答'),
        );

        final messages = await repository.loadAllMessages(saved);
        expect(messages.map((message) => message.content), <String>[
          '问题',
          '部分回答',
        ]);
        // The session record itself is unchanged.
        final session = (await repository.loadSessions()).single;
        expect(session.messageIds, <String>['m1', 'm2']);
        expect(session.updatedAt, saved.updatedAt);
      },
    );

    test('loadMessage returns a stored message or null', () async {
      await repository.saveMessage(
        _message(id: 'm1', role: ChatRole.user, content: '问题'),
      );

      expect((await repository.loadMessage('m1'))?.content, '问题');
      expect(await repository.loadMessage('missing'), isNull);
    });

    test('deleteSession removes stored session', () async {
      await repository.saveSession(_session(id: 'one', title: '会话一'));
      await repository.saveSession(_session(id: 'two', title: '会话二'));

      await repository.deleteSession('one');

      final sessions = await repository.loadSessions();
      expect(sessions.map((session) => session.id), <String>['two']);
    });

    test(
      'assistant deletion cascades by current ownership and preserves shared resources',
      () async {
        final db = await repository.database;
        final assistants = AssistantRepository(db);
        await assistants.saveAssistant(const Assistant(id: 'a', name: 'A'));
        await assistants.saveAssistant(const Assistant(id: 'b', name: 'B'));
        final owned = File(
          '${appSupportDirectory.path}/chat_attachments/owned.txt',
        );
        final shared = File(
          '${appSupportDirectory.path}/chat_attachments/shared.txt',
        );
        final source = File('${appSupportDirectory.path}/source.txt');
        await owned.parent.create(recursive: true);
        for (final file in [owned, shared, source]) {
          await file.writeAsString('fixture');
        }
        await repository.saveMessageVersion(
          _version(
            id: 'v1',
            messageId: 'm1',
            content: 'A version',
            imageFilePaths: [owned.path],
          ),
        );
        await repository.saveSession(
          _session(
            id: 'a1',
            title: 'A1',
            messages: [
              _message(
                id: 'm1',
                role: ChatRole.assistant,
                content: 'A reply',
                imageFilePaths: [shared.path, source.path],
                versionIds: ['v1'],
              ),
            ],
          ).copyWith(assistantId: 'a'),
        );
        await repository.saveSession(
          _session(id: 'a2', title: 'A2').copyWith(assistantId: 'a'),
        );
        await repository.saveMessageVersion(
          _version(
            id: 'v2',
            messageId: 'm2',
            content: 'Retained version',
            imageFilePaths: [shared.path],
          ),
        );
        final moved = _session(
          id: 'moved',
          title: 'Moved',
          messages: [
            _message(
              id: 'm2',
              role: ChatRole.assistant,
              content: 'Prior A reply',
              versionIds: ['v2'],
            ).copyWith(runId: 'kept-run'),
          ],
        ).copyWith(assistantId: 'a');
        await repository.saveSession(moved);
        await repository.saveSession(moved.copyWith(assistantId: 'b'));
        await repository.saveSession(
          _session(
            id: 'orphan',
            title: 'Legacy',
          ).copyWith(assistantId: 'missing'),
        );
        final output = await _legacyWorkspaceFile(
          db,
          appSupportDirectory,
          'a1',
          'output.txt',
        );
        await db.execute(
          "INSERT INTO generation_runs VALUES('run','a1','m1','completed','{}','{}',0)",
        );
        await db.execute(
          "INSERT INTO generation_runs VALUES('kept-run','moved','m2','completed','{\"assistant\":{\"id\":\"a\",\"name\":\"A\"}}','{}',0)",
        );
        await db.execute(
          "INSERT INTO tool_invocations VALUES('receipt','run','call','a1','write_file','succeeded','{}',0)",
        );
        await db.execute(
          "INSERT INTO speech_jobs VALUES('speech','completed','asset',0,'{\"sourceConversationId\":\"a1\"}')",
        );
        await db.execute(
          "INSERT INTO voice_profiles VALUES('voice','Voice','asset','{}')",
        );
        await db.setMetadata(
          'chatDrafts',
          jsonEncode({
            'draft:a': 'A draft',
            'a1': 'A1 draft',
            'a2': 'A2 draft',
            'draft:b': 'B draft',
            'moved': 'Keep moved draft',
          }),
        );

        expect(await repository.deleteAssistantAndSessions('a'), {'a1', 'a2'});
        expect((await assistants.assistants()).single.id, 'b');
        expect(
          (await repository.loadSessions()).map((s) => s.id),
          unorderedEquals(['moved', 'orphan']),
        );
        expect(await repository.loadMessage('m1'), isNull);
        expect(await repository.loadMessageVersion('v1'), isNull);
        expect((await repository.loadMessage('m2'))!.author!.assistantId, 'a');
        expect(await repository.loadMessageVersion('v2'), isNotNull);
        expect(
          (await db.query(
            'SELECT id FROM generation_runs',
          )).single.read<String>('id'),
          'kept-run',
        );
        expect(await db.query('SELECT * FROM tool_invocations'), isEmpty);
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
        expect(await owned.exists(), isFalse);
        expect(await output.exists(), isFalse);
        expect(await shared.exists(), isTrue);
        expect(await source.exists(), isTrue);
        expect(await db.query('SELECT * FROM speech_jobs'), hasLength(1));
        expect(await db.query('SELECT * FROM voice_profiles'), hasLength(1));
        expect(jsonDecode((await db.metadata('chatDrafts'))!), {
          'draft:b': 'B draft',
          'moved': 'Keep moved draft',
        });
        await repository.deleteSession('moved');
        expect(await shared.exists(), isFalse);
        expect(jsonDecode((await db.metadata('chatDrafts'))!), {
          'draft:b': 'B draft',
        });
      },
    );

    test(
      'a failed assistant delete rolls back every conversation and persisted draft before touching files',
      () async {
        final db = await repository.database;
        final assistants = AssistantRepository(db);
        await assistants.saveAssistant(const Assistant(id: 'a', name: 'A'));
        await assistants.saveAssistant(const Assistant(id: 'b', name: 'B'));
        final attachment = File(
          '${appSupportDirectory.path}/chat_attachments/rollback.txt',
        );
        await attachment.parent.create(recursive: true);
        await attachment.writeAsString('Retain bytes');
        for (final id in ['a1', 'a2']) {
          await repository.saveSession(
            _session(
              id: id,
              title: id,
              messages: [
                _message(
                  id: 'm-$id',
                  role: ChatRole.user,
                  content: id,
                  imageFilePaths: [attachment.path],
                ),
              ],
            ).copyWith(assistantId: 'a'),
          );
        }
        final drafts = jsonEncode({'draft:a': 'Unsent', 'a1': 'Continue'});
        await db.setMetadata('chatDrafts', drafts);
        await db.execute(
          "CREATE TRIGGER reject_assistant BEFORE DELETE ON assistants BEGIN SELECT RAISE(ABORT,'fixture'); END",
        );
        await expectLater(
          repository.deleteAssistantAndSessions('a'),
          throwsA(anything),
        );
        expect(await assistants.assistants(), hasLength(2));
        expect(await repository.loadSessions(), hasLength(2));
        expect(await db.query('SELECT * FROM messages'), hasLength(2));
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
        expect(await db.metadata('chatDrafts'), drafts);
        expect(await attachment.readAsString(), 'Retain bytes');
      },
    );

    test(
      'committed assistant deletion succeeds if artifact cleanup needs a retry',
      () async {
        final db = await repository.database;
        final assistants = AssistantRepository(db);
        await assistants.saveAssistant(const Assistant(id: 'a', name: 'A'));
        await assistants.saveAssistant(const Assistant(id: 'b', name: 'B'));
        await repository.saveSession(
          _session(id: 'owned', title: 'Owned').copyWith(assistantId: 'a'),
        );
        await _legacyWorkspaceFile(
          db,
          appSupportDirectory,
          'owned',
          'output.txt',
        );
        await db.execute(
          "CREATE TRIGGER reject_cleanup BEFORE DELETE ON artifacts BEGIN SELECT RAISE(ABORT,'fixture'); END",
        );
        expect(await repository.deleteAssistantAndSessions('a'), {'owned'});
        expect((await assistants.assistants()).single.id, 'b');
        expect(await repository.loadSessions(), isEmpty);
        expect(
          (await db.query(
            'SELECT state FROM artifacts',
          )).single.read<String>('state'),
          'deleting',
        );
        await db.execute('DROP TRIGGER reject_cleanup');
        await repository.close();
        repository = ChatSessionRepository(
          appSupportDirectory: appSupportDirectory,
          hive: Hive,
        );
        await repository.warmUpMessageStore();
        expect(
          await (await repository.database).query('SELECT * FROM artifacts'),
          isEmpty,
        );
      },
    );

    test(
      'conversation deletion cleans Run receipts and files but retains speech results',
      () async {
        final db = await repository.database;
        final imported = File('${appSupportDirectory.path}/user-import.txt');
        await imported.writeAsString('user source');
        final shared = File(
          '${appSupportDirectory.path}/chat_attachments/shared.txt',
        );
        await shared.parent.create(recursive: true);
        await shared.writeAsString('shared image');
        await repository.saveSession(
          _session(
            id: 'one',
            title: 'one',
            messages: [
              _message(
                id: 'm1',
                role: ChatRole.user,
                content: 'test',
                imageFilePaths: [imported.path, shared.path],
              ),
            ],
          ),
        );
        await repository.saveSession(
          _session(
            id: 'two',
            title: 'two',
            messages: [
              _message(
                id: 'm2',
                role: ChatRole.user,
                content: 'keep',
                imageFilePaths: [shared.path],
              ),
            ],
          ),
        );
        final generated = await _legacyWorkspaceFile(
          db,
          appSupportDirectory,
          'one',
          'answer.txt',
        );
        await db.execute(
          "INSERT INTO generation_runs VALUES('run','one','m1','completed','{}','{}',0)",
        );
        await db.execute(
          "INSERT INTO tool_invocations VALUES('receipt','run','call','one','write_file','succeeded','{}',0)",
        );
        await db.execute(
          "INSERT INTO speech_jobs VALUES('speech','completed','asset',0,'{\"sourceConversationId\":\"one\"}')",
        );
        await repository.deleteSession('one');
        expect(await repository.loadMessage('m1'), isNull);
        expect(await repository.loadMessage('m2'), isNotNull);
        expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
        expect(await db.query('SELECT * FROM tool_invocations'), isEmpty);
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
        expect(await generated.exists(), isFalse);
        expect(await imported.readAsString(), 'user source');
        expect(await shared.exists(), isTrue);
        expect(
          (await db.query(
            'SELECT id FROM speech_jobs',
          )).single.read<String>('id'),
          'speech',
        );
      },
    );

    test(
      'failed conversation deletion rolls back before removing attachment bytes',
      () async {
        final attachment = File(
          '${appSupportDirectory.path}/chat_attachments/kept.txt',
        );
        await attachment.parent.create(recursive: true);
        await attachment.writeAsString('keep after rollback');
        await repository.saveMessageVersion(
          _version(
            id: 'v',
            messageId: 'm',
            content: 'saved',
            imageFilePaths: [attachment.path],
          ),
        );
        await repository.saveSession(
          _session(
            id: 'one',
            title: 'one',
            messages: [
              _message(
                id: 'm',
                role: ChatRole.assistant,
                content: 'saved',
                versionIds: ['v'],
              ),
            ],
          ),
        );
        final db = await repository.database;
        await db.execute(
          "CREATE TRIGGER reject_delete BEFORE DELETE ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
        );
        await expectLater(repository.deleteSession('one'), throwsA(anything));
        expect((await repository.loadSessions()).single.id, 'one');
        expect(await repository.loadMessage('m'), isNotNull);
        expect(await repository.loadMessageVersion('v'), isNotNull);
        expect(await attachment.readAsString(), 'keep after rollback');
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
      },
    );

    test(
      'startup retires registered legacy workspace files only within their exact owned directory',
      () async {
        final db = await repository.database;
        final output = await _legacyWorkspaceFile(
          db,
          appSupportDirectory,
          'deleted',
          'out.txt',
        );
        final unregistered = File('${output.parent.path}/unregistered.txt');
        await unregistered.writeAsString('not registered');
        final outside = File('${appSupportDirectory.path}/outside.txt');
        await outside.writeAsString('never delete');
        await db.execute(
          "INSERT INTO artifacts VALUES('invalid',?,'text/plain','conversation','deleted','',1,'deleting')",
          [outside.path],
        );
        await repository.close();
        repository = ChatSessionRepository(
          appSupportDirectory: appSupportDirectory,
          hive: Hive,
        );
        await repository.warmUpMessageStore();
        expect(await output.exists(), isFalse);
        expect(await outside.readAsString(), 'never delete');
        expect(await unregistered.readAsString(), 'not registered');
        expect(
          (await (await repository.database).query(
            'SELECT id FROM artifacts',
          )).single.read<String>('id'),
          'invalid',
        );
      },
    );

    test(
      'deleteSession removes message versions and version attachments',
      () async {
        final attachment = File(
          '${appSupportDirectory.path}\\chat_attachments\\version_image.txt',
        );
        await attachment.parent.create(recursive: true);
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

// Upgrade fixture for files created before the conversation workspace retired.
Future<File> _legacyWorkspaceFile(
  AppDatabase db,
  Directory root,
  String owner,
  String name,
) async {
  final file = File('${root.path}/workspaces/$owner/$name');
  await file.parent.create(recursive: true);
  await file.writeAsString('legacy output');
  await db.execute(
    "INSERT INTO artifacts VALUES(?,?,'text/plain','conversation',?,'',13,'ready')",
    ['$owner:$name', file.path, owner],
  );
  return file;
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
  List<String> imageFilePaths = const <String>[],
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
    imageFilePaths: imageFilePaths,
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
