import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late ChatSessionRepository repository;
  late GenerationRunRepository runs;
  late AgentRepository tools;
  late ChatSessionRecord session;
  late ChatMessageRecord message;
  late List<ChatMessageVersionRecord> versions;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('message-deletion-');
    db = AppDatabase.memory();
    await db.setMetadata('legacyImportComplete', '1');
    repository = ChatSessionRepository(
      database: db,
      appSupportDirectory: directory,
    );
    await repository.warmUpMessageStore();
    runs = GenerationRunRepository(db);
    tools = AgentRepository(db);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed({
    int selected = 2,
    List<String> runIds = const ['r0', 'r1', 'r2'],
    List<List<String>>? images,
  }) async {
    final date = DateTime(2026, 9, 27);
    versions = [
      for (var i = 0; i < runIds.length; i++)
        ChatMessageVersionRecord(
          id: 'v$i',
          messageId: 'm',
          runId: runIds[i],
          content: 'answer $i',
          createdAt: date.add(Duration(minutes: i)),
          modelName: 'model $i',
          reasoningContent: i == 0 ? null : 'reason $i',
          author: MessageAuthor(assistantId: 'a$i', name: 'Assistant $i'),
          imageFilePaths: images?[i] ?? const [],
        ),
    ];
    for (final v in versions) {
      await repository.saveMessageVersion(v);
    }
    message = ChatMessageRecord(
      id: 'm',
      role: ChatRole.assistant,
      content: '',
      createdAt: date,
      sessionId: 'c',
      versionIds: versions.map((v) => v.id).toList(),
    ).withVersion(versions[selected], selected);
    session = ChatSessionRecord(
      id: 'c',
      title: 'Chat',
      createdAt: date,
      updatedAt: date,
      messageIds: const ['before', 'm', 'after'],
    );
    await repository.commitSession(
      session,
      changedMessages: [
        for (final id in ['before', 'after'])
          ChatMessageRecord(
            id: id,
            role: ChatRole.user,
            content: id,
            createdAt: date,
            sessionId: 'c',
          ),
        message,
      ],
    );
    for (final id in runIds.toSet()) {
      await runs.begin(id, 'c', 'm', {});
      await runs.finish(id, 'completed');
      await tools.insert(
        ToolInvocation(
          id: '$id:call',
          runId: id,
          callId: 'call',
          conversationId: 'c',
          name: 'clock',
          state: 'succeeded',
          payload: const {'result': 'saved'},
        ),
      );
    }
  }

  ChatMessageRecord withoutSelectedVersion() {
    final remaining = [...message.versionIds]
      ..removeAt(message.currentVersionIndex);
    final index = (message.currentVersionIndex - 1).clamp(
      0,
      remaining.length - 1,
    );
    return message
        .copyWith(versionIds: remaining)
        .withVersion(
          versions.singleWhere((v) => v.id == remaining[index]),
          index,
        );
  }

  ChatSessionRecord withoutMessage() =>
      session.copyWith(messageIds: const ['before', 'after']);

  for (final index in [0, 1, 2]) {
    test(
      'deleting selected version $index atomically keeps its adjacent version and later messages',
      () async {
        await seed(selected: index);
        final replacement = withoutSelectedVersion();
        await repository.commitMessageDeletion(
          session,
          message,
          replacement: replacement,
        );
        final saved = (await repository.loadMessage('m'))!;
        expect(saved.versionIds, replacement.versionIds);
        expect(saved.content, replacement.content);
        expect(saved.runId, replacement.runId);
        expect(saved.author?.assistantId, replacement.author?.assistantId);
        expect(saved.modelName, replacement.modelName);
        expect(saved.createdAt, replacement.createdAt);
        expect(saved.reasoningContent, replacement.reasoningContent);
        expect(saved.currentVersionIndex, replacement.currentVersionIndex);
        expect(await repository.loadMessageVersion('v$index'), isNull);
        expect(await tools.forRun('c', 'r$index'), isEmpty);
        expect(
          await db.query('SELECT id FROM generation_runs WHERE id=?', [
            'r$index',
          ]),
          isEmpty,
        );
        expect(await tools.history('c'), hasLength(2));
        expect(
          (await repository.loadSessions()).single.messageIds,
          session.messageIds,
        );
        expect((await repository.loadMessage('after'))!.content, 'after');
      },
    );
  }

  for (final count in [1, 3]) {
    test(
      'deleting all $count versions removes their runs and receipts from the conversation',
      () async {
        await seed(
          selected: count - 1,
          runIds: [for (var i = 0; i < count; i++) 'r$i'],
        );
        await repository.commitMessageDeletion(withoutMessage(), message);
        expect(await repository.loadMessage('m'), isNull);
        expect(await db.query('SELECT * FROM message_revisions'), isEmpty);
        expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
        expect(await tools.history('c'), isEmpty);
        expect(await runs.latestState('c'), isNull);
        expect((await repository.loadSessions()).single.messageIds, [
          'before',
          'after',
        ]);
        await runs.recover();
        expect(await repository.loadMessage('m'), isNull);
      },
    );
  }

  test(
    'legacy unversioned messages also own their old run and receipts',
    () async {
      await seed(selected: 0, runIds: ['legacy']);
      await db.execute('DELETE FROM message_revisions');
      message = message.copyWith(clearVersionIds: true);
      await repository.saveMessage(message);
      await repository.commitMessageDeletion(withoutMessage(), message);
      expect(await tools.history('c'), isEmpty);
      expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
    },
  );

  test(
    'a run shared by another revision is retained until its last owner is deleted',
    () async {
      await seed(selected: 0, runIds: ['shared', 'own', 'shared']);
      final replacement = withoutSelectedVersion();
      await repository.commitMessageDeletion(
        session,
        message,
        replacement: replacement,
      );
      expect(await tools.forRun('c', 'shared'), hasLength(1));
      await repository.commitMessageDeletion(withoutMessage(), replacement);
      expect(await tools.history('c'), isEmpty);
      expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
    },
  );

  test(
    'deleting a message preserves a run still referenced by another message',
    () async {
      await seed();
      final other = (await repository.loadMessage(
        'after',
      ))!.copyWith(runId: 'r0');
      await repository.saveMessage(other);
      await repository.commitMessageDeletion(withoutMessage(), message);
      expect((await tools.history('c')).single.runId, 'r0');
      final remaining = (await repository.loadSessions()).single;
      await repository.commitMessageDeletion(
        remaining.copyWith(messageIds: ['before']),
        other,
      );
      expect(await tools.history('c'), isEmpty);
      expect(await db.query('SELECT * FROM generation_runs'), isEmpty);
    },
  );

  test(
    'attachment cleanup removes only unreferenced owned files after committing',
    () async {
      final unique = File('${directory.path}/chat_attachments/unique.png');
      final shared = File('${directory.path}/chat_attachments/shared.png');
      final external = File('${directory.path}/external.png');
      await unique.parent.create(recursive: true);
      for (final file in [unique, shared, external]) {
        await file.writeAsString('fixture');
      }
      await seed(
        selected: 0,
        images: [
          [unique.path, shared.path, external.path],
          [shared.path],
          [],
        ],
      );
      final replacement = withoutSelectedVersion();
      await repository.commitMessageDeletion(
        session,
        message,
        replacement: replacement,
      );
      expect(await unique.exists(), isFalse);
      expect(await shared.exists(), isTrue);
      expect(await external.exists(), isTrue);
      await repository.commitMessageDeletion(withoutMessage(), replacement);
      expect(await shared.exists(), isFalse);
      expect(await external.exists(), isTrue);
    },
  );

  for (final wholeMessage in [false, true]) {
    test(
      'database failure rolls back ${wholeMessage ? 'message' : 'revision'}, runs, receipts, index and file deletion',
      () async {
        final file = File('${directory.path}/chat_attachments/keep.png');
        await file.parent.create(recursive: true);
        await file.writeAsString('Keep bytes');
        await seed(
          images: [
            [],
            [],
            [file.path],
          ],
        );
        await db.execute(
          "CREATE TRIGGER reject_index BEFORE UPDATE ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
        );
        await expectLater(
          repository.commitMessageDeletion(
            wholeMessage ? withoutMessage() : session,
            message,
            replacement: wholeMessage ? null : withoutSelectedVersion(),
          ),
          throwsA(anything),
        );
        expect(
          (await repository.loadMessage('m'))!.versionIds,
          message.versionIds,
        );
        expect((await repository.loadMessage('m'))!.runId, message.runId);
        expect(await db.query('SELECT * FROM message_revisions'), hasLength(3));
        expect(await db.query('SELECT * FROM generation_runs'), hasLength(3));
        expect(await tools.history('c'), hasLength(3));
        expect(
          (await repository.loadSessions()).single.messageIds,
          session.messageIds,
        );
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
        expect(await file.readAsString(), 'Keep bytes');
      },
    );
  }

  test(
    'a stale confirmation cannot delete a changed message or restore a deleted conversation',
    () async {
      await seed();
      await repository.saveMessage(message.withVersion(versions.first, 0));
      await expectLater(
        repository.commitMessageDeletion(withoutMessage(), message),
        throwsStateError,
      );
      expect(await tools.history('c'), hasLength(3));
      await repository.saveMessage(message);
      await db.execute("DELETE FROM conversations WHERE id='c'");
      await expectLater(
        repository.commitMessageDeletion(withoutMessage(), message),
        throwsStateError,
      );
      expect(await repository.loadSessions(), isEmpty);
      expect(await tools.history('c'), hasLength(3));
    },
  );

  for (final state in ['running', 'awaitingApproval', 'cancelling']) {
    test(
      'deleting a $state reply is rejected before changing its data',
      () async {
        await seed();
        await db.execute("UPDATE generation_runs SET state=? WHERE id='r2'", [
          state,
        ]);
        await expectLater(
          repository.commitMessageDeletion(withoutMessage(), message),
          throwsStateError,
        );
        expect(await tools.history('c'), hasLength(3));
        expect(
          (await repository.loadMessage('m'))!.versionIds,
          message.versionIds,
        );
      },
    );
  }

  test(
    'deleting unreferenced runs preserves every retained version',
    () async {
      await seed();
      await runs.begin('orphan', 'c', 'deleted-message', {});
      await runs.finish('orphan', 'completed');
      await tools.insert(
        const ToolInvocation(
          id: 'orphan:call',
          runId: 'orphan',
          callId: 'call',
          conversationId: 'c',
          name: 'clock',
          state: 'succeeded',
          payload: {},
        ),
      );
      await tools.insert(
        const ToolInvocation(
          id: 'missing:call',
          runId: 'missing',
          callId: 'call',
          conversationId: 'c',
          name: 'clock',
          state: 'succeeded',
          payload: {},
        ),
      );
      await runs.recover();
      await runs.deleteUnreferenced(['orphan', 'missing', 'r0', 'r1', 'r2']);
      expect(await tools.history('c'), hasLength(3));
      expect(await db.query('SELECT * FROM generation_runs'), hasLength(3));
      expect(
        jsonDecode(
          (await db.query(
            "SELECT payload FROM messages WHERE id='m'",
          )).single.read<String>('payload'),
        )['runId'],
        'r2',
      );
    },
  );

  test(
    'recovery cannot recreate versions from a deleted message checkpoint',
    () async {
      await seed();
      final deleted = message.copyWith(
        id: 'deleted',
        runId: 'orphan',
        clearVersionIds: true,
      );
      await runs.begin('orphan', 'c', deleted.id, {
        'versionId': 'deleted-version',
      });
      await runs.checkpoint('orphan', deleted);
      await tools.insert(
        const ToolInvocation(
          id: 'orphan:tool',
          runId: 'orphan',
          callId: 'tool',
          conversationId: 'c',
          name: 'clock',
          state: 'succeeded',
          payload: {},
        ),
      );
      await runs.recover();
      expect(await repository.loadMessageVersion('deleted-version'), isNull);
      expect(await db.query('SELECT id FROM generation_runs'), hasLength(3));
      expect(await tools.history('c'), hasLength(3));
    },
  );
}
