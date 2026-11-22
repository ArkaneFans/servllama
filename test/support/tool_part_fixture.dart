import 'dart:convert';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/chat/models/message_part.dart';

ToolActivity toolActivity({
  required String id,
  required String runId,
  required String callId,
  required String conversationId,
  required String name,
  required String state,
  required Map<String, dynamic> payload,
}) => ToolActivity(
  runId: runId,
  conversationId: conversationId,
  revisionId: '$runId:fixture-version',
  part: ToolPart(
    id: callId,
    callId: callId,
    name: name,
    input: jsonEncode(payload['arguments'] ?? {}),
    inputComplete: true,
  ).withExecution(state, payload),
);

/// Seed saved history, including immutable/shared revisions, without adding a
/// production orphan-record API. Tests explicitly supply the owning revision.
extension ToolPartFixture on AgentRepository {
  Future<void> insert(ToolActivity activity) => db.transaction(() async {
    final rows = await db.query(
      'SELECT id,parts FROM message_revisions WHERE run_id=?',
      [activity.runId],
    );
    if (rows.isEmpty) throw StateError('Fixture requires a message revision');
    for (final r in rows) {
      final parts = MessagePart.decode(r.read<String>('parts')).toList();
      parts.add(activity.part);
      await db.execute('UPDATE message_revisions SET parts=? WHERE id=?', [
        MessagePart.encode(parts),
        r.read<String>('id'),
      ]);
    }
  });
}
