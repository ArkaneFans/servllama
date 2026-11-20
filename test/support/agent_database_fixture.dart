import 'package:servllama/core/database/app_database.dart';

/// Tool-service tests omit chat UI, but still create the real owning aggregate.
Future<void> seedAgentRun(
  AppDatabase db,
  String id, {
  String conversationId = 'conversation',
}) async {
  await db.transaction(() async {
    await db.execute(
      'INSERT OR IGNORE INTO conversations(id,title,created_at,updated_at) VALUES(?,?,0,0)',
      [conversationId, 'Fixture'],
    );
    await db.execute(
      'INSERT OR IGNORE INTO generation_runs(id,conversation_id,state,snapshot,checkpoint,updated_at) VALUES(?,?,?,?,?,0)',
      [
        id,
        conversationId,
        'running',
        '{"versionId":"$id:fixture-version"}',
        '{}',
      ],
    );
    final next = (await db.query(
      'SELECT COALESCE(MAX(position),-1)+1 AS next FROM messages WHERE conversation_id=?',
      [conversationId],
    )).single.read<int>('next');
    await db.execute(
      'INSERT OR IGNORE INTO messages(id,conversation_id,position,role) VALUES(?,?,?,?)',
      ['$id:fixture-message', conversationId, next, 'assistant'],
    );
    await db.execute(
      'INSERT OR IGNORE INTO message_revisions(id,message_id,position,run_id,is_draft,is_selected,created_at) VALUES(?,?,0,?,1,1,0)',
      ['$id:fixture-version', '$id:fixture-message', id],
    );
  });
}
