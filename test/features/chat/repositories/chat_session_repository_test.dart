import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/repositories/chat_draft_repository.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ChatSessionRepository repository;
  late AppDatabase db;
  setUp(() async {
    await Hive.close();
    root = await Directory.systemTemp.createTemp('servllama_chat_repo_');
    repository = ChatSessionRepository(appSupportDirectory: root, hive: Hive);
    db = await repository.database;
  });
  tearDown(() async {
    await repository.close();
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<File> image(String name) async {
    final file = File('${root.path}/chat_attachments/$name');
    await file.parent.create(recursive: true);
    return file.writeAsString('fixture');
  }

  test(
    'failed conversation commit never leaves an orphan message or revision',
    () async {
      await db.execute(
        "CREATE TRIGGER reject_conversation BEFORE INSERT ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      final message = _message('m', sessionId: 'c');
      await expectLater(
        repository.commitSession(
          _session('c', messages: [message]),
          changedMessages: [message],
        ),
        throwsA(anything),
      );
      expect(await repository.loadSessions(), isEmpty);
      expect(await db.query('SELECT * FROM messages'), isEmpty);
      expect(await db.query('SELECT * FROM message_revisions'), isEmpty);
    },
  );

  test(
    'session ordering and message ordering are independent of version timestamps',
    () async {
      await repository.saveSession(_session('old'));
      await repository.saveSession(
        _session(
          'new',
          updated: DateTime(2026, 2),
          messages: [
            _message('m1', content: 'first', date: DateTime(2026, 3)),
            _message('m2', content: 'second', date: DateTime(2026, 1)),
          ],
        ),
      );
      final sessions = await repository.loadSessions();
      expect(sessions.map((s) => s.id), ['new', 'old']);
      expect(sessions.first.messageIds, ['m1', 'm2']);
      expect(
        (await repository.loadAllMessages(
          sessions.first,
        )).map((m) => m.content),
        ['first', 'second'],
      );
    },
  );

  test(
    'persists immutable versions and changes only the selected version',
    () async {
      await repository.saveSession(
        _session('c', messages: [_message('m', content: 'original')]),
      );
      final original = (await repository.loadMessage('m'))!;
      final version = ChatMessageVersionRecord(
        id: 'edit',
        messageId: 'm',
        content: 'edited',
        createdAt: DateTime(2026, 3),
        modelName: 'model-a',
        reasoningContent: 'reasoning',
      );
      await repository.saveMessageVersion(version);
      await repository.saveMessage(
        original
            .copyWith(versionIds: [...original.versionIds, version.id])
            .withVersion(version, 1),
      );
      final selected = (await repository.loadMessage('m'))!;
      expect(selected.versionIds, ['m:initial', 'edit']);
      expect(selected.content, 'edited');
      expect(selected.reasoningContent, 'reasoning');
      await repository.saveMessage(original);
      expect((await repository.loadMessage('m'))!.content, 'original');
      expect((await repository.loadMessage('m'))!.versionIds, [
        'm:initial',
        'edit',
      ]);
      await expectLater(
        repository.saveMessageVersion(
          ChatMessageVersionRecord(
            id: 'edit',
            messageId: 'm',
            content: 'overwrite',
            createdAt: version.createdAt,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'loads bounded recent, earlier and initial windows using stored positions',
    () async {
      await repository.saveSession(
        _session(
          'c',
          messages: [
            for (var i = 0; i < 35; i++) _message('m$i', content: 'message $i'),
          ],
        ),
      );
      final session = (await repository.loadSessions()).single;
      final recent = await repository.loadRecentMessages(session);
      expect(recent.first.id, 'm5');
      expect(recent.last.id, 'm34');
      expect(
        (await repository.loadMessagesBefore(
          session,
          beforeMessageId: recent.first.id,
        )).map((m) => m.id),
        ['m0', 'm1', 'm2', 'm3', 'm4'],
      );
      expect(
        (await repository.loadInitialMessages(
          session,
          textBudget: 1,
        )).map((m) => m.id),
        ['m33', 'm34'],
      );
      expect(await repository.loadMessage('missing'), isNull);
    },
  );

  test(
    'checkpoint changes a draft without rewriting the conversation header',
    () async {
      await repository.saveSession(_session('c'));
      final runs = GenerationRunRepository(db);
      final message = _message(
        'm',
        sessionId: 'c',
        content: '',
      ).copyWith(runId: 'r', versionIds: ['v']);
      await db.transaction(() async {
        await runs.begin('r', 'c', {'versionId': 'v'});
        await repository.commitSession(
          _session('c', messages: [message]),
          changedMessages: [message],
        );
      });
      final before = (await repository.loadSessions()).single;
      await runs.checkpoint('r', message.copyWith(content: 'partial'));
      expect((await repository.loadMessage('m'))!.content, 'partial');
      expect(
        (await repository.loadSessions()).single.updatedAt,
        before.updatedAt,
      );
      expect(
        (await db.query(
          'SELECT checkpoint FROM generation_runs',
        )).single.read<String>('checkpoint'),
        '{}',
      );
    },
  );

  test(
    'assistant deletion follows current ownership and preserves shared files and independent speech',
    () async {
      final assistants = AssistantRepository(db);
      await assistants.saveAssistant(const Assistant(id: 'a', name: 'A'));
      await assistants.saveAssistant(const Assistant(id: 'b', name: 'B'));
      final owned = await image('owned.png'),
          shared = await image('shared.png');
      final external = await File(
        '${root.path}/external.png',
      ).writeAsString('source');
      await repository.saveSession(
        _session(
          'a1',
          assistant: 'a',
          messages: [
            _message('m1', images: [shared.path, external.path]),
          ],
        ),
      );
      await repository.saveMessageVersion(
        ChatMessageVersionRecord(
          id: 'old-v',
          messageId: 'm1',
          content: 'old',
          createdAt: DateTime(2025),
          imageFilePaths: [owned.path],
        ),
      );
      await repository.saveSession(_session('a2', assistant: 'a'));
      final moved = _session(
        'moved',
        assistant: 'a',
        messages: [
          _message('m2', images: [shared.path]).copyWith(
            author: const MessageAuthor(assistantId: 'a', name: 'A'),
          ),
        ],
      );
      await repository.saveSession(moved);
      await repository.saveSession(
        moved.copyWith(assistantId: 'b', legacyMessages: []),
      );
      await repository.saveSession(_session('unassigned'));
      await db.execute(
        "INSERT INTO speech_jobs(id,state,asset_id,created_at,payload) VALUES('speech','completed','asset',0,'{}')",
      );
      await db.execute(
        "INSERT INTO voice_profiles VALUES('voice','Voice','asset','{}')",
      );
      final drafts = ChatDraftRepository(db);
      await drafts.saveChanges({
        'draft:a': 'A draft',
        'a1': 'A1 draft',
        'a2': 'A2 draft',
        'draft:b': 'B draft',
        'moved': 'Keep draft',
      });

      expect(await repository.deleteAssistantAndSessions('a'), {'a1', 'a2'});
      expect((await assistants.assistants()).single.id, 'b');
      expect(
        (await repository.loadSessions()).map((s) => s.id),
        unorderedEquals(['moved', 'unassigned']),
      );
      expect(await repository.loadMessage('m1'), isNull);
      expect(await repository.loadMessageVersion('old-v'), isNull);
      expect((await repository.loadMessage('m2'))!.author!.assistantId, 'a');
      expect(await owned.exists(), isFalse);
      expect(await shared.exists(), isTrue);
      expect(await external.exists(), isTrue);
      expect(await db.query('SELECT * FROM speech_jobs'), hasLength(1));
      expect(await db.query('SELECT * FROM voice_profiles'), hasLength(1));
      expect(await drafts.load(), {
        'draft:b': 'B draft',
        'moved': 'Keep draft',
      });
      await repository.deleteSession('moved');
      expect(await shared.exists(), isFalse);
      expect(await drafts.load(), {'draft:b': 'B draft'});
    },
  );

  for (final assistant in [false, true]) {
    test(
      'failed ${assistant ? 'assistant' : 'conversation'} deletion rolls back data and file intents',
      () async {
        final assistants = AssistantRepository(db);
        await assistants.saveAssistant(const Assistant(id: 'a', name: 'A'));
        await assistants.saveAssistant(const Assistant(id: 'b', name: 'B'));
        final attachment = await image('keep.png');
        await repository.saveSession(
          _session(
            'c',
            assistant: 'a',
            messages: [
              _message('m', images: [attachment.path]),
            ],
          ),
        );
        await ChatDraftRepository(db).saveChanges({'c': 'Unsent'});
        final table = assistant ? 'assistants' : 'conversations';
        await db.execute(
          "CREATE TRIGGER reject_delete BEFORE DELETE ON $table BEGIN SELECT RAISE(ABORT,'fixture'); END",
        );
        await expectLater(
          assistant
              ? repository.deleteAssistantAndSessions('a')
              : repository.deleteSession('c'),
          throwsA(anything),
        );
        expect(await repository.loadMessage('m'), isNotNull);
        expect(await repository.loadSessions(), hasLength(1));
        expect(await ChatDraftRepository(db).load(), {'c': 'Unsent'});
        expect(await db.query('SELECT * FROM pending_file_deletions'), isEmpty);
        expect(await attachment.exists(), isTrue);
      },
    );
  }

  test(
    'committed deletion remains successful and retries a failed cleanup acknowledgement on reopen',
    () async {
      final attachment = await image('retry.png');
      await repository.saveSession(
        _session(
          'c',
          messages: [
            _message('m', images: [attachment.path]),
          ],
        ),
      );
      await db.execute(
        "CREATE TRIGGER reject_cleanup BEFORE DELETE ON pending_file_deletions BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await repository.deleteSession('c');
      expect(await repository.loadSessions(), isEmpty);
      expect(
        await db.query('SELECT * FROM pending_file_deletions'),
        hasLength(1),
      );
      await db.execute('DROP TRIGGER reject_cleanup');
      await repository.close();
      repository = ChatSessionRepository(appSupportDirectory: root, hive: Hive);
      db = await repository.database;
      expect(await db.query('SELECT * FROM pending_file_deletions'), isEmpty);
      expect(await attachment.exists(), isFalse);
    },
  );

  test(
    'light app startup defers durable file cleanup without losing deletion intents',
    () async {
      final attachment = await image('deferred.png');
      await db.execute(
        'INSERT INTO pending_file_deletions(path, kind) VALUES (?, ?)',
        [attachment.path, 'chatAttachment'],
      );
      await repository.close();
      repository = ChatSessionRepository(
        appSupportDirectory: root,
        hive: Hive,
        retryCleanupOnOpen: false,
      );
      db = await repository.database;
      expect(
        await db.query('SELECT * FROM pending_file_deletions'),
        hasLength(1),
      );
      expect(await attachment.exists(), isTrue);
      await repository.cleanupFiles();
      expect(await db.query('SELECT * FROM pending_file_deletions'), isEmpty);
      expect(await attachment.exists(), isFalse);
    },
  );
}

ChatSessionRecord _session(
  String id, {
  String? assistant,
  DateTime? updated,
  List<ChatMessageRecord> messages = const [],
}) => ChatSessionRecord(
  id: id,
  title: id,
  assistantId: assistant,
  messages: messages,
  createdAt: DateTime(2026),
  updatedAt: updated ?? DateTime(2026),
);
ChatMessageRecord _message(
  String id, {
  String? sessionId,
  String content = 'message',
  DateTime? date,
  List<String> images = const [],
}) => ChatMessageRecord(
  id: id,
  sessionId: sessionId,
  role: ChatRole.user,
  content: content,
  createdAt: date ?? DateTime(2026),
  imageFilePaths: images,
);
