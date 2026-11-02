import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';

/// The relational chat mapping shared by normal writes, recovery and Hive import.
/// Callers group mutations in a transaction. ID lists on UI records are derived;
/// the database stores each body once, including the first user-message version.
class ChatRecordStore {
  ChatRecordStore(this.db);
  final AppDatabase db;

  Future<void> saveSession(ChatSessionRecord s) => db.execute(
    'INSERT INTO conversations(id,title,assistant_id,created_at,updated_at) '
    'VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,'
    'assistant_id=excluded.assistant_id,updated_at=excluded.updated_at',
    [
      s.id,
      s.title,
      s.assistantId,
      s.createdAt.millisecondsSinceEpoch,
      s.updatedAt.millisecondsSinceEpoch,
    ],
  );

  Future<List<String>> messageIds(String conversationId) async =>
      (await db.query(
        'SELECT id FROM messages WHERE conversation_id=? ORDER BY position',
        [conversationId],
      )).map((r) => r.read<String>('id')).toList();

  Future<List<ChatSessionRecord>> sessions() async {
    final rows = await db.query(
      'SELECT * FROM conversations ORDER BY updated_at DESC,id',
    );
    final ids = <String, List<String>>{};
    for (final r in await db.query(
      'SELECT id,conversation_id FROM messages ORDER BY conversation_id,position',
    )) {
      (ids[r.read<String>('conversation_id')] ??= []).add(r.read<String>('id'));
    }
    return rows
        .map((r) => sessionFromRow(r, ids[r.read<String>('id')] ?? []))
        .toList();
  }

  static ChatSessionRecord sessionFromRow(
    QueryRow r,
    List<String> ids,
  ) => ChatSessionRecord(
    id: r.read<String>('id'),
    title: r.read<String>('title'),
    assistantId: r.readNullable<String>('assistant_id'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
    messageIds: ids,
  );

  /// A node and its selected revision are inserted together. The unique partial
  /// index permits only one selected revision per node, without circular FKs.
  Future<void> saveMessage(ChatMessageRecord m, {int? position}) async {
    final existing = await db.query(
      'SELECT m.id,r.id AS selected_revision_id FROM messages m '
      'LEFT JOIN message_revisions r ON r.message_id=m.id AND r.is_selected=1 WHERE m.id=?',
      [m.id],
    );
    final selected = m.versionIds.isEmpty
        ? (existing.isEmpty
              ? '${m.id}:initial'
              : existing.single.readNullable<String>('selected_revision_id') ??
                    '${m.id}:initial')
        : m.versionIds[m.currentVersionIndex];
    if (existing.isEmpty) {
      final conversationId = m.sessionId;
      if (conversationId == null) {
        throw StateError('Message requires a conversation');
      }
      position ??= (await db.query(
        'SELECT COALESCE(MAX(position),-1)+1 AS next FROM messages WHERE conversation_id=?',
        [conversationId],
      )).single.read<int>('next');
      await db.execute(
        'INSERT INTO messages(id,conversation_id,position,role) VALUES(?,?,?,?)',
        [m.id, conversationId, position, m.role.name],
      );
    }
    final running =
        m.runId != null &&
        (await db.query(
          "SELECT 1 FROM generation_runs WHERE id=? AND state IN ('running','awaitingApproval','cancelling')",
          [m.runId!],
        )).isNotEmpty;
    await saveVersion(
      ChatMessageVersionRecord(
        id: selected,
        messageId: m.id,
        runId: m.runId,
        author: m.author,
        content: m.content,
        createdAt: m.createdAt,
        modelName: m.modelName,
        generationMetrics: m.generationMetrics,
        reasoningContent: m.reasoningContent,
        imageFilePaths: m.imageFilePaths,
      ),
      draft: running,
    );
    await selectVersion(m.id, selected);
  }

  Future<void> selectVersion(String messageId, String versionId) async {
    await db.execute(
      'UPDATE message_revisions SET is_selected=0 WHERE message_id=? AND is_selected=1',
      [messageId],
    );
    if (await db.execute(
          'UPDATE message_revisions SET is_selected=1 WHERE message_id=? AND id=?',
          [messageId, versionId],
        ) !=
        1) {
      throw StateError('Message version missing');
    }
  }

  Future<void> saveVersion(
    ChatMessageVersionRecord v, {
    bool draft = false,
    int? position,
  }) async {
    final existing = await db.query(
      'SELECT * FROM message_revisions WHERE id=?',
      [v.id],
    );
    if (existing.isNotEmpty && existing.single.read<int>('is_draft') == 0) {
      final saved = await version(v.id);
      if (jsonEncode(encodeVersion(saved!)) != jsonEncode(encodeVersion(v))) {
        throw StateError('A committed message revision is immutable');
      }
      return;
    }
    position ??= existing.isNotEmpty
        ? existing.single.read<int>('position')
        : (await db.query(
            'SELECT COALESCE(MAX(position),-1)+1 AS next FROM message_revisions WHERE message_id=?',
            [v.messageId],
          )).single.read<int>('next');
    await db.execute(
      'INSERT INTO message_revisions(id,message_id,position,run_id,is_draft,created_at,content,reasoning_content,model_name,author,generation_metrics) '
      'VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET '
      'is_draft=excluded.is_draft,content=excluded.content,reasoning_content=excluded.reasoning_content,'
      'model_name=excluded.model_name,author=excluded.author,generation_metrics=excluded.generation_metrics,run_id=excluded.run_id,created_at=excluded.created_at',
      [
        v.id,
        v.messageId,
        position,
        v.runId,
        draft ? 1 : 0,
        v.createdAt.millisecondsSinceEpoch,
        v.content,
        v.reasoningContent,
        v.modelName,
        v.author == null ? null : jsonEncode(v.author!.toJson()),
        v.generationMetrics == null
            ? null
            : jsonEncode(v.generationMetrics!.toJson()),
      ],
    );
    await db.execute('DELETE FROM revision_attachments WHERE revision_id=?', [
      v.id,
    ]);
    for (var i = 0; i < v.imageFilePaths.length; i++) {
      await db.execute(
        'INSERT INTO revision_attachments(revision_id,position,path) VALUES(?,?,?)',
        [v.id, i, v.imageFilePaths[i]],
      );
    }
  }

  Future<ChatMessageRecord?> message(String id) async {
    final rows = await messages('m.id=?', [id]);
    return rows.firstOrNull;
  }

  Future<List<ChatMessageRecord>> messages(
    String where,
    List<Object> args, {
    String order = 'm.position',
    int? limit,
  }) async {
    final rows = await db.query(
      'SELECT m.id AS node_id,m.conversation_id,m.role,r.id AS selected_revision_id,r.* '
      'FROM messages m JOIN message_revisions r ON r.message_id=m.id AND r.is_selected=1 '
      'WHERE $where ORDER BY $order${limit == null ? '' : ' LIMIT ?'}',
      [...args, if (limit != null) limit],
    );
    if (rows.isEmpty) return [];
    final ids = <String, List<String>>{};
    final images = <String, List<String>>{};
    // Bound SQLite parameters while batching references, including long chats.
    for (var offset = 0; offset < rows.length; offset += 400) {
      final chunk = rows.skip(offset).take(400).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      for (final r in await db.query(
        'SELECT id,message_id FROM message_revisions WHERE message_id IN ($placeholders) ORDER BY message_id,position',
        chunk.map((r) => r.read<String>('node_id')).toList(),
      )) {
        (ids[r.read<String>('message_id')] ??= []).add(r.read<String>('id'));
      }
      for (final r in await db.query(
        'SELECT revision_id,path FROM revision_attachments WHERE revision_id IN ($placeholders) ORDER BY revision_id,position',
        chunk.map((r) => r.read<String>('selected_revision_id')).toList(),
      )) {
        (images[r.read<String>('revision_id')] ??= []).add(
          r.read<String>('path'),
        );
      }
    }
    return rows.map((r) {
      final id = r.read<String>('node_id');
      final selected = r.read<String>('selected_revision_id');
      final v = versionFromRow(r, images[selected] ?? []);
      return ChatMessageRecord(
        id: id,
        sessionId: r.read<String>('conversation_id'),
        role: ChatRole.values.byName(r.read<String>('role')),
        content: v.content,
        createdAt: v.createdAt,
        runId: v.runId,
        author: v.author,
        modelName: v.modelName,
        generationMetrics: v.generationMetrics,
        reasoningContent: v.reasoningContent,
        imageFilePaths: v.imageFilePaths,
        versionIds: ids[id]!,
        currentVersionIndex: ids[id]!.indexOf(selected),
      );
    }).toList();
  }

  Future<ChatMessageVersionRecord?> version(String id) async {
    final rows = await db.query('SELECT * FROM message_revisions WHERE id=?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    final images = await db.query(
      'SELECT path FROM revision_attachments WHERE revision_id=? ORDER BY position',
      [id],
    );
    return versionFromRow(
      rows.single,
      images.map((r) => r.read<String>('path')).toList(),
    );
  }

  static ChatMessageVersionRecord versionFromRow(
    QueryRow r,
    List<String> images,
  ) {
    final author = r.readNullable<String>('author');
    final metrics = r.readNullable<String>('generation_metrics');
    return ChatMessageVersionRecord(
      id: r.read<String>('id'),
      messageId: r.read<String>('message_id'),
      runId: r.readNullable<String>('run_id'),
      content: r.read<String>('content'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      modelName: r.readNullable<String>('model_name'),
      generationMetrics: metrics == null
          ? null
          : GenerationMetrics.fromJson(jsonDecode(metrics)),
      reasoningContent: r.readNullable<String>('reasoning_content'),
      author: author == null
          ? null
          : MessageAuthor.fromJson(jsonDecode(author)),
      imageFilePaths: images,
    );
  }
}
