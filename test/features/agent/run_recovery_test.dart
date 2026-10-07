import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  test(
    'recovery retains tool-only replies and never replays their receipts',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final runs = GenerationRunRepository(db);
      final tools = AgentRepository(db);
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,message_ids) VALUES(?,?,?,?,?)',
        ['c', 'test', 0, 0, '["waiting","executing"]'],
      );
      for (final id in ['waiting', 'executing']) {
        final m = ChatMessageRecord(
          id: id,
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime(2026),
          sessionId: 'c',
          runId: id,
        );
        await db.execute(
          'INSERT INTO messages(id,conversation_id,role,created_at,payload) VALUES(?,?,?,?,?)',
          [id, 'c', 'assistant', 0, jsonEncode(encodeMessage(m))],
        );
        await runs.begin(id, 'c', id, {'versionId': 'v-$id'});
        if (id == 'executing') await runs.checkpoint(id, m);
        await tools.insert(
          ToolInvocation(
            id: '$id:call',
            runId: id,
            callId: 'call',
            conversationId: 'c',
            name: 'write_file',
            state: id == 'waiting' ? 'pendingApproval' : 'executing',
            payload: const {
              'arguments': {
                'path': 'never-replay.txt',
                'content': 'saved request',
              },
            },
          ),
        );
      }
      await tools.recover();
      await runs.recover();
      await runs.recover();
      final messages = await db.query('SELECT payload FROM messages');
      expect(messages, hasLength(2));
      for (final row in messages) {
        final m = decodeMessage(jsonDecode(row.read<String>('payload')));
        expect(m.content, isEmpty);
        expect(m.versionIds, ['v-${m.id}']);
        expect(m.runId, m.id);
      }
      expect(await db.query('SELECT id FROM message_revisions'), hasLength(2));
      expect((await tools.forRun('c', 'waiting')).single.state, 'cancelled');
      expect(
        (await tools.forRun('c', 'executing')).single.state,
        'unknownOutcome',
      );
      expect(await db.query('SELECT id FROM tool_invocations'), hasLength(2));
      expect(await runs.latestState('c'), 'interrupted');
    },
  );

  test(
    'recovery commits a partial revision once and removes an empty draft',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final runs = GenerationRunRepository(db);
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,message_ids) VALUES(?,?,?,?,?)',
        ['c', 'test', 0, 0, '["partial","empty"]'],
      );
      for (final id in ['partial', 'empty']) {
        final m = ChatMessageRecord(
          id: id,
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime(2026),
          sessionId: 'c',
          runId: id,
        );
        await db.execute(
          'INSERT INTO messages(id,conversation_id,role,created_at,payload) VALUES(?,?,?,?,?)',
          [id, 'c', 'assistant', 0, jsonEncode(encodeMessage(m))],
        );
        await runs.begin(id, 'c', id, {'versionId': 'v-$id'});
        if (id == 'partial') {
          await runs.checkpoint(id, m.copyWith(content: 'saved output'));
        }
      }
      await runs.recover();
      await runs.recover();
      expect((await db.query('SELECT * FROM message_revisions')).length, 1);
      final message = decodeMessage(
        jsonDecode(
          (await db.query(
            'SELECT payload FROM messages',
          )).single.read<String>('payload'),
        ),
      );
      expect(message.content, 'saved output');
      expect(message.versionIds, ['v-partial']);
      expect(
        (await db.query(
          'SELECT message_ids FROM conversations',
        )).single.read<String>('message_ids'),
        '["partial"]',
      );
      expect(
        (await db.query(
          'SELECT state FROM generation_runs',
        )).map((r) => r.read<String>('state')),
        everyElement('interrupted'),
      );
    },
  );
}
