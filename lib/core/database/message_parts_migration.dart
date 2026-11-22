import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/message_part.dart';

/// Upgrades the published text/receipt schema directly to revision-owned parts.
/// Unpublished timeline layouts are not an intermediate migration target.
Future<void> migrateMessageParts(
  AppDatabase db,
  Migrator migrator, {
  required int from,
}) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() async {
      if (from < 2) await migrator.deleteTable('chat_drafts');
      await migrator.addColumn(db.messageRevisions, db.messageRevisions.parts);

      // Bound memory while retaining every revision, including unselected ones.
      var lastRow = 0;
      while (true) {
        final rows = await db.query(
          'SELECT rowid AS source_row,id,content,reasoning_content '
          'FROM message_revisions WHERE rowid>? ORDER BY rowid LIMIT 200',
          [lastRow],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          await db.execute('UPDATE message_revisions SET parts=? WHERE id=?', [
            MessagePart.encode(
              messagePartsFromText(
                content: row.read<String>('content'),
                reasoning: row.readNullable<String>('reasoning_content'),
              ),
            ),
            row.read<String>('id'),
          ]);
        }
        lastRow = rows.last.read<int>('source_row');
      }

      lastRow = 0;
      while (true) {
        final runs = await db.query(
          'SELECT g.rowid AS source_row,g.id,g.conversation_id,g.snapshot '
          'FROM generation_runs g WHERE g.rowid>? AND EXISTS '
          '(SELECT 1 FROM tool_invocations i WHERE i.run_id=g.id) '
          'ORDER BY g.rowid LIMIT 100',
          [lastRow],
        );
        if (runs.isEmpty) break;
        for (final run in runs) {
          final snapshot = jsonDecode(run.read<String>('snapshot')) as Map;
          // Edits may share a Run. Attach its receipts once to the original
          // revision, or the earliest surviving revision if it was deleted.
          final owners = await db.query(
            'SELECT r.id,r.parts FROM message_revisions r '
            'JOIN messages m ON m.id=r.message_id '
            'WHERE r.run_id=? AND m.conversation_id=? '
            'ORDER BY CASE WHEN r.id=? THEN 0 ELSE 1 END,m.position,r.position '
            'LIMIT 1',
            [
              run.read<String>('id'),
              run.read<String>('conversation_id'),
              snapshot['versionId'] as String? ?? '',
            ],
          );
          if (owners.isEmpty) {
            throw StateError('Tool history has no surviving message revision');
          }
          final owner = owners.single;
          final body = MessagePart.decode(owner.read<String>('parts'));
          final tools = await db.query(
            'SELECT * FROM tool_invocations WHERE run_id=? '
            'ORDER BY created_at,rowid',
            [run.read<String>('id')],
          );
          // Main stored aggregate reasoning/text, without interleave offsets.
          // Keep their text exact and place calls between them in saved order.
          await db.execute('UPDATE message_revisions SET parts=? WHERE id=?', [
            MessagePart.encode([
              ...body.whereType<ReasoningPart>(),
              for (final tool in tools) _toolPart(tool),
              ...body.whereType<TextPart>(),
            ]),
            owner.read<String>('id'),
          ]);
        }
        lastRow = runs.last.read<int>('source_row');
      }

      // Drift rebuilds this table and restores its indexes. Foreign keys are
      // disabled outside the transaction so attachments are not cascaded away.
      await migrator.alterTable(TableMigration(db.messageRevisions));
      await migrator.deleteTable('tool_invocations');
      if ((await db.query('PRAGMA foreign_key_check')).isNotEmpty) {
        throw StateError('Message parts migration violates data ownership');
      }
    });
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
}

ToolPart _toolPart(QueryRow row) {
  final payload = Map<String, dynamic>.from(
    jsonDecode(row.read<String>('payload')) as Map,
  );
  final arguments = payload['arguments'] as Map? ?? const <String, dynamic>{};
  final state = switch (ToolState.values.byName(row.read<String>('state'))) {
    ToolState.executing => ToolState.unknownOutcome,
    ToolState.streaming ||
    ToolState.ready ||
    ToolState.prepared ||
    ToolState.pendingApproval ||
    ToolState.approved => ToolState.cancelled,
    final state => state,
  };
  return ToolPart(
    id: 'call:${row.read<String>('call_id')}',
    callId: row.read<String>('call_id'),
    name: row.read<String>('name'),
    input: jsonEncode(arguments),
    inputComplete: true,
  ).withExecution(state.name, payload);
}
