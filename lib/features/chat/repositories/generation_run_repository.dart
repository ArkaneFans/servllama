import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';

class GenerationRunRepository {
  GenerationRunRepository(this.db);
  final AppDatabase db;

  /// A shared run survives until its last revision reference disappears.
  /// Tool parts disappear with their revision; checkpoints never recreate a message.
  Future<void> deleteUnreferenced(Iterable<String> runIds) async {
    for (final id in runIds.toSet()) {
      await db.execute(
        'DELETE FROM generation_runs WHERE id=? AND NOT EXISTS '
        '(SELECT 1 FROM message_revisions WHERE run_id=generation_runs.id)',
        [id],
      );
    }
  }

  Future<String?> latestState(String conversationId) async {
    final rows = await db.query(
      'SELECT state FROM generation_runs WHERE conversation_id=? ORDER BY updated_at DESC LIMIT 1',
      [conversationId],
    );
    return rows.firstOrNull?.read<String>('state');
  }

  Future<void> begin(
    String id,
    String conversationId,
    Map<String, dynamic> snapshot,
  ) async {
    await db.execute(
      'INSERT INTO generation_runs(id,conversation_id,state,snapshot,checkpoint,updated_at) VALUES(?,?,?,?,?,?)',
      [
        id,
        conversationId,
        'running',
        jsonEncode(snapshot),
        '{}',
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// Streaming bodies live in the draft revision. The checkpoint contains only
  /// continuation data; terminal messages are not copied into Run JSON again.
  Future<void> checkpoint(
    String id,
    ChatMessageRecord message, {
    List<Map<String, dynamic>> trace = const [],
    String? contextKey,
    String? finalText,
  }) async {
    await db.transaction(() async {
      final rows = await db.query(
        'SELECT id,parts FROM message_revisions WHERE message_id=? AND run_id=? AND is_draft=1 '
        "AND EXISTS(SELECT 1 FROM generation_runs WHERE id=? AND state='running')",
        [message.id, id, id],
      );
      if (rows.isEmpty) return;
      final row = rows.single;
      final parts = mergeToolExecution(
        message.parts,
        MessagePart.decode(row.read<String>('parts')),
      );
      final written = await db.execute(
        'UPDATE message_revisions SET parts=? WHERE id=?',
        [MessagePart.encode(parts), row.read<String>('id')],
      );
      if (written == 0) return;
      final needsContinuation = trace.any(
        (t) =>
            (t['calls'] as List? ?? []).isNotEmpty ||
            (t['providerParts'] as List? ?? []).isNotEmpty ||
            t['role'] == 'tool',
      );
      await db.execute(
        'UPDATE generation_runs SET checkpoint=?,updated_at=? WHERE id=?',
        [
          jsonEncode({
            if (needsContinuation) 'trace': trace,
            if (needsContinuation) 'contextKey': contextKey,
            if (finalText != null)
              'finalTextStart': message.content.length - finalText.length,
          }),
          DateTime.now().millisecondsSinceEpoch,
          id,
        ],
      );
    });
  }

  Future<QueryRow?> _committedRun(ChatMessageRecord message) async {
    if (message.runId == null || message.versionIds.isEmpty) return null;
    final rows = await db.query(
      'SELECT g.state,g.snapshot,g.checkpoint FROM generation_runs g '
      'JOIN message_revisions r ON r.run_id=g.id '
      "WHERE g.id=? AND r.id=? AND r.parts=? AND r.is_draft=0 AND json_extract(g.snapshot,'\$.versionId')=r.id",
      [
        message.runId!,
        message.versionIds[message.currentVersionIndex],
        MessagePart.encode(message.parts),
      ],
    );
    return rows.firstOrNull;
  }

  Future<Map<String, dynamic>?> history(ChatMessageRecord message) async {
    final row = await _committedRun(message);
    if (row == null || row.read<String>('state') != 'completed') return null;
    return {
      'snapshot': jsonDecode(row.read<String>('snapshot')),
      'checkpoint': jsonDecode(row.read<String>('checkpoint')),
    };
  }

  Future<String?> finalAnswer(ChatMessageRecord message) async {
    if (message.runId == null) return message.content;
    final row = await _committedRun(message);
    if (row == null ||
        !const {
          'completed',
          'toolBudget',
          'turnBudget',
          'tokenBudget',
          'contextBudget',
        }.contains(row.read<String>('state'))) {
      return null;
    }
    final data = jsonDecode(row.read<String>('checkpoint')) as Map;
    final start = data['finalTextStart'] as int?;
    return start == null ? null : message.content.substring(start);
  }

  Future<void> finish(String id, String state) async {
    await db.execute(
      'UPDATE generation_runs SET state=?,updated_at=? WHERE id=?',
      [state, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> recover() async {
    await db.transaction(() async {
      final rows = await db.query(
        "SELECT * FROM generation_runs WHERE state IN ('running','awaitingApproval','cancelling')",
      );
      final store = ChatRecordStore(db);
      for (final row in rows) {
        final runId = row.read<String>('id');
        final snapshot = jsonDecode(row.read<String>('snapshot')) as Map;
        final drafts = await db.query(
          'SELECT * FROM message_revisions WHERE run_id=? AND is_draft=1',
          [runId],
        );
        for (final draft in drafts) {
          final id = draft.read<String>('id');
          final messageId = draft.read<String>('message_id');
          final parts = MessagePart.decode(draft.read<String>('parts'));
          if (messageText(parts).trim().isNotEmpty ||
              (messageReasoning(parts)?.trim().isNotEmpty ?? false) ||
              parts.any((p) => p is ToolPart)) {
            final checkpointAt = DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('updated_at'),
              isUtc: true,
            );
            final settled = parts.map((p) {
              if (p is ReasoningPart && p.finishedAt == null) {
                return p.copyWith(
                  finishedAt: p.startedAt?.isAfter(checkpointAt) == true
                      ? p.startedAt
                      : checkpointAt,
                );
              }
              if (p is ToolPart) {
                return switch (p.state) {
                  ToolState.executing => p.copyWith(
                    state: ToolState.unknownOutcome,
                  ),
                  ToolState.streaming ||
                  ToolState.ready ||
                  ToolState.prepared ||
                  ToolState.pendingApproval ||
                  ToolState.approved => p.copyWith(state: ToolState.cancelled),
                  _ => p,
                };
              }
              return p;
            }).toList();
            await db.execute(
              'UPDATE message_revisions SET is_draft=0,parts=? WHERE id=?',
              [MessagePart.encode(settled), id],
            );
          } else {
            final fallback = snapshot['fallbackVersionId'] as String?;
            if (fallback == null) {
              await db.execute('DELETE FROM messages WHERE id=?', [messageId]);
            } else {
              await store.selectVersion(messageId, fallback);
              await db.execute('DELETE FROM message_revisions WHERE id=?', [
                id,
              ]);
            }
          }
        }
        await finish(runId, 'interrupted');
      }
      await deleteUnreferenced(rows.map((r) => r.read<String>('id')));
    });
  }
}
