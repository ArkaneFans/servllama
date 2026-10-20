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
      [id, conversationId, 'running', '{}', '{}'],
    );
  });
}
