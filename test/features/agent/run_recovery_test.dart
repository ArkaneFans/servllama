import '../../support/tool_part_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  late AppDatabase db;
  late GenerationRunRepository runs;
  late ChatRecordStore store;
  setUp(() async {
    db = AppDatabase.memory();
    store = ChatRecordStore(db);
    runs = GenerationRunRepository(db);
    await store.saveSession(
      ChatSessionRecord(
        id: 'c',
        title: 'Chat',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });
  tearDown(() => db.close());

  Future<ChatMessageRecord> draft(String id) async {
    final m = ChatMessageRecord(
      id: id,
      sessionId: 'c',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2026),
      runId: id,
      versionIds: ['v-$id'],
      author: const MessageAuthor(assistantId: 'a', name: 'Assistant'),
    );
    await db.transaction(() async {
      await runs.begin(id, 'c', {'versionId': 'v-$id'});
      await store.saveMessage(m);
    });
    return m;
  }

  test(
    'interrupted reasoning keeps revision order and settles at the last checkpoint',
    () async {
      final m = await draft('thinking');
      final start = DateTime.utc(2026);
      final parts = [
        ReasoningPart('reason', 'Still thinking', startedAt: start),
      ];
      await runs.checkpoint('thinking', m.copyWith(parts: parts));
      final end = start.add(const Duration(seconds: 2));
      await db.execute(
        "UPDATE generation_runs SET updated_at=? WHERE id='thinking'",
        [end.millisecondsSinceEpoch],
      );
      await runs.recover();
      final saved = (await store.message('thinking'))!;
      expect((saved.parts.single as ReasoningPart).finishedAt, end);
      expect((saved.parts.single as ReasoningPart).text, 'Still thinking');
      expect(saved.reasoningContent, 'Still thinking');
      expect(
        await db.query(
          "SELECT name FROM sqlite_master WHERE name='tool_invocations'",
        ),
        isEmpty,
      );
      await runs.recover();
      expect(
        MessagePart.encode((await store.message('thinking'))!.parts),
        MessagePart.encode(saved.parts),
      );
    },
  );

  test(
    'recovery keeps a tool that never received its vendor ID as incomplete',
    () async {
      final m = await draft('partial-tool');
      await runs.checkpoint(
        'partial-tool',
        m.copyWith(
          parts: const [
            ToolPart(id: 'series', name: 'clock', input: '{"zone":'),
          ],
        ),
      );
      await runs.recover();
      final saved = (await store.message('partial-tool'))!;
      expect(saved.parts.single.id, 'series');
      expect((saved.parts.single as ToolPart).callId, isNull);
      expect((saved.parts.single as ToolPart).inputComplete, isFalse);
      expect((saved.parts.single as ToolPart).input, '{"zone":');
      expect((saved.parts.single as ToolPart).state, ToolState.cancelled);
      expect(
        await db.query(
          "SELECT name FROM sqlite_master WHERE name='tool_invocations'",
        ),
        isEmpty,
      );
      expect(await runs.latestState('c'), 'interrupted');
    },
  );

  test(
    'recovery retains tool-only replies and never replays their receipts',
    () async {
      final tools = AgentRepository(db);
      for (final id in ['waiting', 'executing']) {
        final m = await draft(id);
        if (id == 'executing') await runs.checkpoint(id, m);
        await tools.insert(
          toolActivity(
            id: '$id:call',
            runId: id,
            callId: 'call',
            conversationId: 'c',
            name: 'ask_user',
            state: id == 'waiting' ? 'pendingApproval' : 'executing',
            payload: const {'question': 'Continue?'},
          ),
        );
      }
      await runs.recover();
      await runs.recover();
      final messages = await store.messages('m.conversation_id=?', ['c']);
      expect(messages, hasLength(2));
      for (final m in messages) {
        expect(m.content, isEmpty);
        expect(m.versionIds, ['v-${m.id}']);
        expect(m.runId, m.id);
        expect(m.author?.assistantId, 'a');
      }
      expect(await db.query('SELECT id FROM message_revisions'), hasLength(2));
      expect((await tools.forRun('c', 'waiting')).single.state, 'cancelled');
      expect(
        (await tools.forRun('c', 'executing')).single.state,
        'unknownOutcome',
      );
      expect(await runs.latestState('c'), 'interrupted');
    },
  );

  test(
    'recovery commits a partial revision once and removes an empty draft',
    () async {
      final partial = await draft('partial');
      await draft('empty');
      await runs.checkpoint(
        'partial',
        partial.copyWith(content: 'saved output'),
      );
      await runs.recover();
      await runs.recover();
      expect(await db.query('SELECT id FROM message_revisions'), hasLength(1));
      final message = (await store.message('partial'))!;
      expect(message.content, 'saved output');
      expect(message.versionIds, ['v-partial']);
      expect(message.author?.assistantId, 'a');
      expect(await store.messageIds('c'), ['partial']);
      expect(
        (await db.query(
          'SELECT state FROM generation_runs',
        )).single.read<String>('state'),
        'interrupted',
      );
    },
  );

  test(
    'empty regeneration returns to the previously selected immutable version',
    () async {
      final first = await draft('answer');
      await runs.checkpoint('answer', first.copyWith(content: 'Original'));
      await runs.recover();
      final original = (await store.message('answer'))!;
      final regenerated = original.copyWith(
        content: '',
        runId: 'new-run',
        versionIds: [...original.versionIds, 'new-version'],
        currentVersionIndex: 1,
      );
      await db.transaction(() async {
        await runs.begin('new-run', 'c', {
          'versionId': 'new-version',
          'fallbackVersionId': original.versionIds.single,
        });
        await store.saveMessage(regenerated);
      });
      await runs.recover();
      final restored = (await store.message('answer'))!;
      expect(restored.content, 'Original');
      expect(restored.versionIds, original.versionIds);
      expect(restored.runId, original.runId);
      expect(await store.version('new-version'), isNull);
      expect(await db.query('SELECT id FROM generation_runs'), hasLength(1));
    },
  );

  test('deleted revisions cannot be recreated by a checkpoint', () async {
    final m = await draft('removed');
    await runs.checkpoint('removed', m.copyWith(content: 'Old checkpoint'));
    await db.execute("DELETE FROM messages WHERE id='removed'");
    await runs.recover();
    expect(await store.messageIds('c'), isEmpty);
    expect(await db.query('SELECT id FROM message_revisions'), isEmpty);
    expect(await db.query('SELECT id FROM generation_runs'), isEmpty);
  });
}
