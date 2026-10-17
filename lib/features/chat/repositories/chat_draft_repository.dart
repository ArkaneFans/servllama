import 'package:servllama/core/database/app_database.dart';

class ChatDraftRepository {
  ChatDraftRepository(this.db);
  final AppDatabase db;

  Future<Map<String, String>> load() async => {
    for (final row in await db.query('SELECT key,content FROM chat_drafts'))
      row.read<String>('key'): row.read<String>('content'),
  };

  Future<void> saveChanges(
    Map<String, String?> changes,
  ) => db.transaction(() async {
    for (final entry in changes.entries) {
      if (entry.value == null || entry.value!.isEmpty) {
        await db.execute('DELETE FROM chat_drafts WHERE key=?', [entry.key]);
        continue;
      }
      if (entry.key == 'draft') continue; // Only the pre-bind, in-memory draft.
      final assistant = entry.key.startsWith('draft:');
      final owner = assistant ? entry.key.substring(6) : entry.key;
      final column = assistant ? 'assistant_id' : 'conversation_id';
      final table = assistant ? 'assistants' : 'conversations';
      // A delayed autosave must not recreate a deleted owner or its draft.
      await db.execute(
        'INSERT INTO chat_drafts(key,$column,content) SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM $table WHERE id=?) '
        'ON CONFLICT(key) DO UPDATE SET content=excluded.content',
        [entry.key, owner, entry.value, owner],
      );
    }
  });
}
