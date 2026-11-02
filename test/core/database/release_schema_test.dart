import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  late AppDatabase db;
  late ChatRecordStore store;
  setUp(() {
    db = AppDatabase.memory();
    store = ChatRecordStore(db);
  });
  tearDown(() => db.close());

  Future<void> seed() => db.transaction(() async {
    final date = DateTime(2026);
    await store.saveSession(
      ChatSessionRecord(
        id: 'c',
        title: 'Chat',
        createdAt: date,
        updatedAt: date,
      ),
    );
    await store.saveMessage(
      ChatMessageRecord(
        id: 'm',
        sessionId: 'c',
        role: ChatRole.user,
        content: 'Body stored once',
        createdAt: date,
      ),
    );
  });

  test(
    'release schema is known to Drift and rejects dangling ownership',
    () async {
      expect(db.allTables.length, 17);
      expect(db.schemaVersion, 2);
      expect(
        (await db.query(
          'PRAGMA foreign_keys',
        )).single.read<int>('foreign_keys'),
        1,
      );
      await expectLater(
        db.execute("INSERT INTO messages VALUES('m','missing',0,'user')"),
        throwsA(anything),
      );
      await expectLater(
        db.execute(
          "INSERT INTO tool_invocations VALUES('t','missing','call','clock','succeeded','{}',0)",
        ),
        throwsA(anything),
      );
      expect(await db.query('SELECT id FROM messages'), isEmpty);
    },
  );

  test(
    'one selected revision and one content source; deleting conversation cascades',
    () async {
      await seed();
      await store.saveVersion(
        ChatMessageVersionRecord(
          id: 'v2',
          messageId: 'm',
          content: 'Another',
          createdAt: DateTime(2026),
        ),
      );
      await expectLater(
        db.execute("UPDATE message_revisions SET is_selected=1 WHERE id='v2'"),
        throwsA(anything),
      );
      final columns = (await db.query(
        'PRAGMA table_info(messages)',
      )).map((r) => r.read<String>('name'));
      expect(columns, isNot(contains('payload')));
      expect(columns, isNot(contains('version_ids')));
      await db.execute("DELETE FROM conversations WHERE id='c'");
      expect(await db.query('SELECT * FROM messages'), isEmpty);
      expect(await db.query('SELECT * FROM message_revisions'), isEmpty);
      expect(await db.query('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'begin failure rolls back run and draft; failed finalization retains a recoverable draft',
    () async {
      await seed();
      final runs = GenerationRunRepository(db);
      await db.execute(
        "CREATE TRIGGER reject_message BEFORE INSERT ON messages BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      Future<void> begin() => db.transaction(() async {
        await runs.begin('run', 'c', {'versionId': 'draft-v'});
        await store.saveMessage(
          ChatMessageRecord(
            id: 'answer',
            sessionId: 'c',
            role: ChatRole.assistant,
            content: '',
            createdAt: DateTime(2026),
            runId: 'run',
            versionIds: ['draft-v'],
          ),
        );
      });
      await expectLater(begin(), throwsA(anything));
      expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
      await db.execute('DROP TRIGGER reject_message');
      await begin();
      final draft = (await store.message(
        'answer',
      ))!.copyWith(content: 'Partial');
      await runs.checkpoint('run', draft, finalText: 'Partial');
      await db.execute(
        "CREATE TRIGGER reject_finish BEFORE UPDATE OF state ON generation_runs BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        db.transaction(() async {
          await db.execute(
            "UPDATE message_revisions SET is_draft=0 WHERE id='draft-v'",
          );
          await runs.finish('run', 'completed');
        }),
        throwsA(anything),
      );
      expect(
        (await db.query(
          "SELECT is_draft FROM message_revisions WHERE id='draft-v'",
        )).single.read<int>('is_draft'),
        1,
      );
      expect(await runs.latestState('c'), 'running');
      await db.execute('DROP TRIGGER reject_finish');
      await runs.recover();
      expect((await store.message('answer'))!.content, 'Partial');
      expect(await runs.latestState('c'), 'interrupted');
    },
  );

  test('list and reference queries use the intended indexes', () async {
    final plans = {
      'SELECT id FROM conversations ORDER BY updated_at DESC,id':
          'conversations_recent',
      "SELECT id FROM messages WHERE conversation_id='c' ORDER BY position":
          'sqlite_autoindex_messages_2',
      "SELECT id FROM message_revisions WHERE run_id='r'": 'revisions_run',
      "SELECT 1 FROM revision_attachments WHERE path='p'": 'attachments_path',
      'SELECT id FROM speech_jobs ORDER BY created_at DESC,id':
          'speech_jobs_recent',
      'SELECT id FROM download_tasks ORDER BY created_at DESC,id':
          'downloads_recent',
    };
    for (final entry in plans.entries) {
      final plan = (await db.query(
        'EXPLAIN QUERY PLAN ${entry.key}',
      )).map((r) => r.read<String>('detail')).join('\n');
      expect(plan, contains(entry.value));
      expect(plan, isNot(contains('TEMP B-TREE')));
    }
  });

  test('disk database uses WAL and the release filename', () async {
    await db.close();
    final root = await Directory.systemTemp.createTemp('servllama-release-db-');
    final disk = AppDatabase.at(root);
    try {
      expect(
        (await disk.query(
          'PRAGMA journal_mode',
        )).single.read<String>('journal_mode'),
        'wal',
      );
      expect(await File('${root.path}/data/servllama.sqlite').exists(), isTrue);
    } finally {
      await disk.close();
      await root.delete(recursive: true);
    }
  });
}
