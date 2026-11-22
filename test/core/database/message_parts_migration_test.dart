import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

/// Creates main's exported schema, without relying on the current table model.
class _MainDatabase extends AppDatabase {
  _MainDatabase(File file, {this.version = 2}) : super(NativeDatabase(file));
  final int version;
  @override
  int get schemaVersion => version;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final schema =
          jsonDecode(
                await File('test/fixtures/main_schema_v2.json').readAsString(),
              )
              as Map;
      for (final sql in schema['statements'] as List) {
        await customStatement(sql as String);
      }
      if (version == 1) {
        await customStatement('CREATE TABLE chat_drafts (id TEXT PRIMARY KEY)');
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}

void main() {
  late Directory root;
  late File file;
  late _MainDatabase previous;
  final opened = <AppDatabase>[];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('servllama-parts-upgrade-');
    file = File('${root.path}/servllama.sqlite');
    previous = _MainDatabase(file);
    opened.add(previous);
  });
  tearDown(() async {
    for (final db in opened.reversed) {
      await db.close();
    }
    opened.clear();
    await root.delete(recursive: true);
  });

  Future<AppDatabase> upgrade() async {
    await previous.close();
    final db = AppDatabase(NativeDatabase(file));
    opened.add(db);
    return db;
  }

  Future<void> seed({String state = 'completed'}) async {
    await previous.execute(
      "INSERT INTO assistants VALUES('a','Assistant',1,'{}')",
    );
    await previous.execute(
      "INSERT INTO conversations VALUES('c','Chat','a',0,1)",
    );
    await previous.execute(
      "INSERT INTO messages VALUES('m','c',0,'assistant')",
    );
    await previous.execute('INSERT INTO generation_runs VALUES(?,?,?,?,?,0)', [
      'r',
      'c',
      state,
      '{"versionId":"v","modelId":"model"}',
      '{"trace":[{"role":"assistant","providerParts":[{"thoughtSignature":"opaque"}]}],"finalTextStart":0}',
    ]);
    await previous.execute(
      'INSERT INTO message_revisions '
      '(id,message_id,position,run_id,is_draft,is_selected,created_at,content,reasoning_content,model_name,author) '
      'VALUES(?,?,0,?,?,1,0,?,?,?,?)',
      [
        'v',
        'm',
        'r',
        state == 'completed' ? 0 : 1,
        '原始正文 🦙\n\n第二段',
        '先核对资料。',
        'model',
        '{"assistantId":"a","name":"Assistant"}',
      ],
    );
    await previous.execute(
      "INSERT INTO revision_attachments VALUES('v',0,'/images/kept.png')",
    );
  }

  Future<void> tool(
    String id, {
    String state = 'succeeded',
    int createdAt = 0,
    Map<String, dynamic>? payload,
  }) => previous.execute('INSERT INTO tool_invocations VALUES(?,?,?,?,?,?,?)', [
    'r:$id',
    'r',
    id,
    'clock',
    state,
    jsonEncode(payload ?? {'arguments': {}, 'result': 'saved:$id'}),
    createdAt,
  ]);

  test('main upgrade preserves history, receipts, attachments and other data', () async {
    await seed();
    await previous.execute(
      "INSERT INTO message_revisions(id,message_id,position,run_id,is_selected,created_at,content) "
      "VALUES('edit','m',1,'r',0,1,'Edited body')",
    );
    await previous.execute(
      "UPDATE message_revisions SET is_selected=0 WHERE id='v'",
    );
    await previous.execute(
      "UPDATE message_revisions SET is_selected=1 WHERE id='edit'",
    );
    final payload = {
      'arguments': {'zone': 'Asia/Shanghai'},
      'argumentsHash': 'hash',
      'displayName': 'Saved clock',
      'result': '{"local":"12:00"}',
      'error': 'Saved diagnostic',
      'resultTruncated': true,
      'startedAt': 10,
      'finishedAt': 30,
      'durationMs': 20,
    };
    // Creation time first, with row order breaking equal timestamps as on main.
    await tool('later', createdAt: 100);
    await tool('earlier', payload: payload);
    await tool('tie');
    await previous.execute(
      "INSERT INTO ai_connections VALUES('p','Provider',1,'{\"apiKey\":\"fixture\"}')",
    );
    await previous.execute(
      "INSERT INTO skills VALUES('s','Skill','hash','{}')",
    );
    await previous.execute(
      "INSERT INTO mcp_servers VALUES('server','MCP',1,'{}')",
    );
    await previous.execute(
      "INSERT INTO model_assets VALUES('asset','llm','gguf','runtime','app','/models/model.gguf','Model','1','ready','{}')",
    );
    await previous.execute(
      "INSERT INTO speech_jobs VALUES('job','completed','asset',NULL,0,'{}')",
    );
    await previous.execute(
      "INSERT INTO voice_profiles VALUES('voice','Voice','asset','{}')",
    );
    await previous.execute(
      "INSERT INTO download_tasks VALUES('download',0,'{}')",
    );
    await previous.execute(
      "INSERT INTO pending_file_deletions VALUES('/images/queued.png','chatAttachment')",
    );
    await previous.setMetadata('legacy_marker', '1');
    final tables = [
      'assistants',
      'ai_connections',
      'skills',
      'mcp_servers',
      'conversations',
      'messages',
      'generation_runs',
      'revision_attachments',
      'model_assets',
      'speech_jobs',
      'voice_profiles',
      'download_tasks',
      'pending_file_deletions',
      'app_metadata',
    ];
    final unchanged = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      unchanged[table] = (await previous.query(
        'SELECT * FROM $table',
      )).map((r) => r.data).toList();
    }
    final db = await upgrade();
    await db.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    expect(
      (await db.query('PRAGMA user_version')).single.read<int>('user_version'),
      3,
    );
    for (final table in tables) {
      expect(
        (await db.query('SELECT * FROM $table')).map((r) => r.data).toList(),
        unchanged[table],
        reason: table,
      );
    }
    final store = ChatRecordStore(db);
    final original = (await store.version('v'))!;
    expect(original.content, '原始正文 🦙\n\n第二段');
    expect(original.reasoningContent, '先核对资料。');
    expect(original.parts.map((p) => p.kind), [
      MessagePartKind.reasoning,
      MessagePartKind.tool,
      MessagePartKind.tool,
      MessagePartKind.tool,
      MessagePartKind.text,
    ]);
    expect(original.parts.whereType<ToolPart>().map((p) => p.callId), [
      'earlier',
      'tie',
      'later',
    ]);
    expect(original.parts.whereType<ToolPart>().first.payload, payload);
    expect(original.imageFilePaths, ['/images/kept.png']);
    final selected = (await store.message('m'))!;
    expect(selected.content, 'Edited body');
    expect(selected.currentVersionIndex, 1);
    expect(selected.parts.whereType<ToolPart>(), isEmpty);
    expect(selected.versionIds, ['v', 'edit']);
    expect((await AgentRepository(db).forRun('c', 'r')).map((a) => a.callId), [
      'earlier',
      'tie',
      'later',
    ]);
    await store.selectVersion('m', 'v');
    expect(
      await GenerationRunRepository(
        db,
      ).finalAnswer((await store.message('m'))!),
      original.content,
    );
    final migrated = (await db.query(
      'SELECT id,parts FROM message_revisions',
    )).map((r) => r.data).toList();
    await db.close();
    final reopened = AppDatabase(NativeDatabase(file));
    opened.add(reopened);
    expect(
      (await reopened.query(
        'SELECT id,parts FROM message_revisions',
      )).map((r) => r.data).toList(),
      migrated,
    );
    expect(
      (await reopened.query(
        'PRAGMA foreign_keys',
      )).single.read<int>('foreign_keys'),
      1,
    );
    await reopened.execute("DELETE FROM conversations WHERE id='c'");
    expect(await reopened.query('SELECT * FROM message_revisions'), isEmpty);
    expect(await reopened.query('SELECT * FROM revision_attachments'), isEmpty);
    expect(await reopened.query('PRAGMA foreign_key_check'), isEmpty);
  });

  test(
    'interrupted tools settle without replay and keep the draft history',
    () async {
      await seed(state: 'running');
      await tool(
        'remote',
        state: 'executing',
        payload: {'arguments': {}, 'serverId': 'server'},
      );
      await tool(
        'approval',
        state: 'pendingApproval',
        payload: {'arguments': {}},
      );
      await tool('prepared', state: 'prepared', payload: {'arguments': {}});
      await tool('approved', state: 'approved', payload: {'arguments': {}});
      await tool(
        'failed',
        state: 'failed',
        payload: {'arguments': {}, 'error': 'Failure'},
      );
      final db = await upgrade();
      var activities = await AgentRepository(db).forRun('c', 'r');
      expect(activities.map((a) => a.state), [
        'unknownOutcome',
        'cancelled',
        'cancelled',
        'cancelled',
        'failed',
      ]);
      expect(activities.first.part.result, isNull);
      await GenerationRunRepository(db).recover();
      activities = await AgentRepository(db).forRun('c', 'r');
      expect(activities.first.state, 'unknownOutcome');
      expect(activities.last.part.error, 'Failure');
      expect(await GenerationRunRepository(db).latestState('c'), 'interrupted');
      expect(
        (await db.query(
          "SELECT is_draft FROM message_revisions WHERE id='v'",
        )).single.read<int>('is_draft'),
        0,
      );
      expect((await ChatRecordStore(db).version('v'))!.imageFilePaths, [
        '/images/kept.png',
      ]);
    },
  );

  test(
    'receipts use one surviving revision when the original was deleted',
    () async {
      await seed();
      await previous.execute(
        "UPDATE generation_runs SET snapshot='{\"versionId\":\"deleted\"}' WHERE id='r'",
      );
      await previous.execute(
        "INSERT INTO message_revisions(id,message_id,position,run_id,created_at,content) VALUES('edit','m',1,'r',1,'Another edit')",
      );
      await tool('saved');
      final db = await upgrade();
      final store = ChatRecordStore(db);
      expect(
        (await store.version('v'))!.parts.whereType<ToolPart>(),
        hasLength(1),
      );
      expect(
        (await store.version('edit'))!.parts.whereType<ToolPart>(),
        isEmpty,
      );
    },
  );

  test(
    'conversion pages retain all revisions and empty/whitespace bodies',
    () async {
      await seed();
      await previous.transaction(() async {
        for (var i = 1; i <= 405; i++) {
          await previous.execute(
            'INSERT INTO message_revisions(id,message_id,position,created_at,content,reasoning_content) VALUES(?,?,?,?,?,?)',
            [
              'version-$i',
              'm',
              i,
              i,
              i % 2 == 0 ? '' : '\n ',
              i % 3 == 0 ? '\n' : null,
            ],
          );
        }
      });
      final db = await upgrade();
      expect(
        await db.query('SELECT id FROM message_revisions'),
        hasLength(406),
      );
      final store = ChatRecordStore(db);
      expect((await store.version('version-405'))!.content, '\n ');
      expect((await store.version('version-405'))!.reasoningContent, '\n');
      expect((await store.version('version-404'))!.parts, isEmpty);
    },
  );

  test(
    'failed conversion rolls back columns and data and can be retried',
    () async {
      await seed();
      await tool('bad');
      await previous.execute(
        "UPDATE tool_invocations SET payload='broken-json'",
      );
      final before = (await previous.query(
        'SELECT * FROM message_revisions',
      )).single.data;
      final db = await upgrade();
      await expectLater(
        db.query('SELECT id FROM messages'),
        throwsA(isA<FormatException>()),
      );
      await db.close();
      final old = _MainDatabase(file);
      opened.add(old);
      expect(
        (await old.query(
          'PRAGMA user_version',
        )).single.read<int>('user_version'),
        2,
      );
      expect(
        (await old.query('SELECT * FROM message_revisions')).single.data,
        before,
      );
      expect(
        (await old.query(
          'PRAGMA table_info(message_revisions)',
        )).map((r) => r.read<String>('name')),
        isNot(contains('parts')),
      );
      expect(
        await old.query('SELECT * FROM revision_attachments'),
        hasLength(1),
      );
      expect(await old.query('SELECT * FROM tool_invocations'), hasLength(1));
      await old.execute('UPDATE tool_invocations SET payload=?', [
        '{"arguments":{},"result":"fixed"}',
      ]);
      await old.close();
      final retry = AppDatabase(NativeDatabase(file));
      opened.add(retry);
      expect(
        (await ChatRecordStore(
          retry,
        ).version('v'))!.parts.whereType<ToolPart>().single.result,
        'fixed',
      );
      expect(
        (await retry.query(
          'PRAGMA user_version',
        )).single.read<int>('user_version'),
        3,
      );
    },
  );

  test(
    'foreign-key failure rolls back the table rebuild and receipt removal',
    () async {
      await seed();
      await tool('saved');
      await previous.customStatement('PRAGMA foreign_keys = OFF');
      await previous.execute(
        "INSERT INTO revision_attachments VALUES('missing-revision',0,'/images/orphan.png')",
      );
      await previous.customStatement('PRAGMA foreign_keys = ON');
      final before = (await previous.query(
        'SELECT * FROM message_revisions',
      )).single.data;
      final db = await upgrade();
      await expectLater(
        db.query('SELECT id FROM messages'),
        throwsA(isA<StateError>()),
      );
      await db.close();
      final old = _MainDatabase(file);
      opened.add(old);
      expect(
        (await old.query(
          'PRAGMA user_version',
        )).single.read<int>('user_version'),
        2,
      );
      expect(
        (await old.query('SELECT * FROM message_revisions')).single.data,
        before,
      );
      expect(await old.query('SELECT * FROM tool_invocations'), hasLength(1));
      expect(
        await old.query('SELECT * FROM revision_attachments'),
        hasLength(2),
      );
      expect(
        await old.query(
          "SELECT name FROM sqlite_master WHERE name='revisions_selected'",
        ),
        hasLength(1),
      );
    },
  );

  test(
    'schema 1 keeps the previous chat_drafts removal when upgrading',
    () async {
      await previous.close();
      previous = _MainDatabase(file, version: 1);
      opened.add(previous);
      await seed();
      await previous.execute("INSERT INTO chat_drafts VALUES('old-input')");
      final db = await upgrade();
      await db.validateDatabaseSchema(
        options: const ValidationOptions(validateDropped: true),
      );
      expect(
        await db.query(
          "SELECT name FROM sqlite_master WHERE name='chat_drafts'",
        ),
        isEmpty,
      );
      expect(
        (await ChatRecordStore(db).version('v'))!.content,
        '原始正文 🦙\n\n第二段',
      );
    },
  );
}
