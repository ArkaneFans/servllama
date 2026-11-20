import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  late AppDatabase db;
  late ChatRecordStore store;
  late GenerationRunRepository runs;
  late AgentRepository tools;
  late ChatMessageRecord draft;
  setUp(() async {
    db = AppDatabase.memory();
    store = ChatRecordStore(db);
    runs = GenerationRunRepository(db);
    tools = AgentRepository(db);
    await store.saveSession(
      ChatSessionRecord(
        id: 'c',
        title: 'Chat',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    draft = ChatMessageRecord(
      id: 'm',
      sessionId: 'c',
      runId: 'run',
      role: ChatRole.assistant,
      createdAt: DateTime(2026),
      versionIds: const ['v'],
      parts: const [
        TextPart('before', 'Before'),
        ToolPart(
          id: 'stream',
          callId: 'call',
          name: 'clock',
          input: '{}',
          inputComplete: true,
          state: ToolState.ready,
        ),
      ],
    );
    await db.transaction(() async {
      await runs.begin('run', 'c', {'versionId': 'v'});
      await store.saveMessage(draft);
    });
  });
  tearDown(() => db.close());

  test(
    'stale checkpoints preserve decisions and results in the original slot',
    () async {
      await tools.prepare('run', 'c', 'call', 'clock', {
        'arguments': {},
        'argumentsHash': 'hash',
      });
      expect(
        await tools.transition('run:call', 'prepared', 'pendingApproval', {
          'arguments': {},
        }),
        isTrue,
      );
      expect(
        await tools.transition('run:call', 'prepared', 'executing', {}),
        isFalse,
      );
      final streaming = draft.copyWith(
        parts: [...draft.parts, const TextPart('after', 'After')],
      );
      await runs.checkpoint('run', streaming);
      var saved = (await store.message('m'))!;
      expect(saved.parts.map((p) => p.id), ['before', 'stream', 'after']);
      expect((saved.parts[1] as ToolPart).state, ToolState.pendingApproval);
      expect(
        await tools.transition('run:call', 'pendingApproval', 'approved', {
          'arguments': {},
          'answer': 'Yes',
        }),
        isTrue,
      );
      expect(
        await tools.transition('run:call', 'approved', 'executing', {
          'arguments': {},
          'startedAt': 10,
        }),
        isTrue,
      );
      expect(
        await tools.transition('run:call', 'executing', 'succeeded', {
          'arguments': {},
          'startedAt': 10,
          'finishedAt': 20,
          'durationMs': 10,
          'result': 'Saved',
        }),
        isTrue,
      );
      await runs.checkpoint('run', streaming);
      saved = (await store.message('m'))!;
      final part = saved.parts[1] as ToolPart;
      expect(part.state, ToolState.succeeded);
      expect(part.result, 'Saved');
      expect(part.durationMs, 10);
      expect(saved.content, 'BeforeAfter');
      expect(await tools.forRun('c', 'run'), hasLength(1));
    },
  );

  test(
    'a changed complete input and a missing owner cannot reserve execution',
    () async {
      await expectLater(
        tools.prepare('run', 'c', 'call', 'clock', {
          'arguments': {'changed': true},
        }),
        throwsStateError,
      );
      expect(
        (await tools.toolActivity('run:call'))!.part.state,
        ToolState.ready,
      );
      await runs.begin('orphan', 'c', {'versionId': 'missing'});
      await expectLater(
        tools.prepare('orphan', 'c', 'call', 'clock', {'arguments': {}}),
        throwsStateError,
      );
      expect(await tools.forRun('c', 'orphan'), isEmpty);
    },
  );

  test(
    'committed tool parts are immutable and terminal checkpoints do nothing',
    () async {
      await tools.prepare('run', 'c', 'call', 'clock', {'arguments': {}});
      await tools.transition('run:call', 'prepared', 'succeeded', {
        'arguments': {},
        'result': 'Saved',
      });
      final saved = (await store.message('m'))!;
      await store.saveVersion(
        ChatMessageVersionRecord(
          id: 'v',
          messageId: 'm',
          runId: 'run',
          createdAt: saved.createdAt,
          parts: saved.parts,
        ),
      );
      await runs.finish('run', 'completed');
      expect(
        await tools.transition('run:call', 'succeeded', 'executing', {}),
        isFalse,
      );
      await runs.checkpoint('run', draft.copyWith(content: 'Wrong'));
      await expectLater(
        store.saveVersion(
          ChatMessageVersionRecord(
            id: 'v',
            messageId: 'm',
            runId: 'run',
            createdAt: saved.createdAt,
            parts: const [TextPart('body', 'Wrong')],
          ),
        ),
        throwsStateError,
      );
      expect(
        MessagePart.encode((await store.message('m'))!.parts),
        MessagePart.encode(saved.parts),
      );
    },
  );
}
