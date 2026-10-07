import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/core/utils/new_id.dart';

class GenerationRunRepository {
  GenerationRunRepository(this.db);
  final AppDatabase db;

  /// Message revisions own runs and their receipts. A shared run survives until
  /// its last message/revision reference is gone. Joins the caller's deletion
  /// transaction when present; also used after discarding an empty draft.
  Future<void> deleteUnreferenced(Iterable<String> runIds) async {
    await db.transaction(() async {
      for (final id in runIds.toSet()) {
        final referenced = await db.query(
          "SELECT 1 FROM messages WHERE json_extract(payload,'\$.runId')=? "
          "UNION ALL SELECT 1 FROM message_revisions r JOIN messages m ON m.id=r.message_id "
          "WHERE json_extract(r.payload,'\$.runId')=? LIMIT 1",
          [id, id],
        );
        if (referenced.isNotEmpty) continue;
        await db.execute('DELETE FROM tool_invocations WHERE run_id=?', [id]);
        await db.execute('DELETE FROM generation_runs WHERE id=?', [id]);
      }
    });
  }

  Future<bool> hasToolInvocations(String runId) async => (await db.query(
    'SELECT 1 FROM tool_invocations WHERE run_id=? LIMIT 1',
    [runId],
  )).isNotEmpty;

  Future<String?> latestState(String conversationId) async {
    final rows = await db.query(
      'SELECT state FROM generation_runs WHERE conversation_id=? ORDER BY updated_at DESC LIMIT 1',
      [conversationId],
    );
    return rows.isEmpty ? null : rows.single.read<String>('state');
  }

  Future<void> begin(
    String id,
    String conversationId,
    String messageId,
    Map<String, dynamic> snapshot,
  ) async {
    await db.execute(
      'INSERT INTO generation_runs(id,conversation_id,message_id,state,snapshot,checkpoint,updated_at) '
      'VALUES(?,?,?, ?,?,?,?)',
      [
        id,
        conversationId,
        messageId,
        'running',
        jsonEncode(snapshot),
        '{}',
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> checkpoint(
    String id,
    ChatMessageRecord message, {
    List<Map<String, dynamic>> trace = const [],
    String? contextKey,
    String? finalText,
  }) async {
    await db.execute(
      'UPDATE generation_runs SET checkpoint=?,updated_at=? WHERE id=? AND state=?',
      [
        jsonEncode({
          'message': encodeMessage(message),
          'trace': trace,
          'contextKey': contextKey,
          'finalText': finalText,
        }),
        DateTime.now().millisecondsSinceEpoch,
        id,
        'running',
      ],
    );
  }

  /// Only the committed, unedited revision can supply native continuation data.
  Future<Map<String, dynamic>?> history(ChatMessageRecord message) async {
    if (message.runId == null) return null;
    final rows = await db.query(
      'SELECT state,snapshot,checkpoint FROM generation_runs WHERE id=?',
      [message.runId!],
    );
    if (rows.isEmpty || rows.single.read<String>('state') != 'completed') {
      return null;
    }
    final checkpoint = Map<String, dynamic>.from(
      jsonDecode(rows.single.read<String>('checkpoint')),
    );
    if (checkpoint['message']?['content'] != message.content) return null;
    return {
      'snapshot': jsonDecode(rows.single.read<String>('snapshot')),
      'checkpoint': checkpoint,
    };
  }

  Future<String?> finalAnswer(ChatMessageRecord message) async {
    if (message.runId == null) return message.content;
    final rows = await db.query(
      'SELECT state,checkpoint FROM generation_runs WHERE id=?',
      [message.runId!],
    );
    if (rows.isEmpty ||
        !const {
          'completed',
          'toolBudget',
          'turnBudget',
          'tokenBudget',
          'contextBudget',
        }.contains(rows.single.read<String>('state'))) {
      return null;
    }
    final checkpoint =
        jsonDecode(rows.single.read<String>('checkpoint')) as Map;
    if (checkpoint['message']?['content'] != message.content) return null;
    return checkpoint['finalText'] as String?;
  }

  Future<void> finish(String id, String state, {String? error}) async {
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
      for (final row in rows) {
        final data = jsonDecode(row.read<String>('checkpoint')) as Map;
        final snapshot = jsonDecode(row.read<String>('snapshot')) as Map;
        final stored = await db.query(
          'SELECT payload FROM messages WHERE id=?',
          [row.read<String>('message_id')],
        );
        if (stored.isEmpty) {
          // A checkpoint is not an owner: never recreate a deleted message's
          // revisions or keep its receipts alive during recovery.
          await finish(row.read<String>('id'), 'interrupted');
          continue;
        }
        final raw =
            data['message'] ??
            jsonDecode(stored.single.read<String>('payload'));
        if (raw is Map) {
          var m = decodeMessage(Map<String, dynamic>.from(raw));
          final runId = row.read<String>('id');
          final assistant = snapshot['assistant'];
          if (m.author == null &&
              m.runId == runId &&
              assistant is Map &&
              assistant['id'] is String &&
              assistant['name'] is String) {
            m = m.copyWith(
              author: MessageAuthor(
                assistantId: assistant['id'],
                name: assistant['name'],
              ),
            );
          }
          if (data['message'] == null &&
              m.runId != runId &&
              snapshot['fallbackMessage'] is Map) {
            // The process may exit after begin(), before replacing the original.
            m = decodeMessage(
              Map<String, dynamic>.from(snapshot['fallbackMessage']),
            );
          } else if (m.content.trim().isNotEmpty ||
              (m.reasoningContent?.trim().isNotEmpty ?? false) ||
              await hasToolInvocations(runId)) {
            final id = snapshot['versionId'] as String? ?? newId();
            final committed = await db.query(
              'SELECT payload FROM message_revisions WHERE id=?',
              [id],
            );
            final v = committed.isEmpty
                ? ChatMessageVersionRecord(
                    id: id,
                    messageId: m.id,
                    runId: runId,
                    author: m.author,
                    content: m.content,
                    createdAt: m.createdAt,
                    modelName: m.modelName,
                    reasoningContent: m.reasoningContent,
                    imageFilePaths: m.imageFilePaths,
                  )
                : decodeVersion({
                    if (m.author != null) 'author': m.author!.toJson(),
                    ...jsonDecode(committed.single.read<String>('payload'))
                        as Map<String, dynamic>,
                  });
            if (committed.isEmpty) {
              await db.execute(
                'INSERT INTO message_revisions(id,message_id,created_at,payload) VALUES(?,?,?,?)',
                [
                  id,
                  m.id,
                  m.createdAt.millisecondsSinceEpoch,
                  jsonEncode(encodeVersion(v)),
                ],
              );
            }
            final ids = [...m.versionIds];
            if (!ids.contains(id)) ids.add(id);
            m = m.copyWith(
              content: v.content,
              reasoningContent: v.reasoningContent,
              runId: v.runId,
              clearRunId: v.runId == null,
              author: v.author,
              clearAuthor: v.author == null,
              createdAt: v.createdAt,
              modelName: v.modelName,
              clearModelName: v.modelName == null,
              clearReasoningContent: v.reasoningContent == null,
              imageFilePaths: v.imageFilePaths,
              versionIds: ids,
              currentVersionIndex: ids.indexOf(id),
            );
          } else if (snapshot['fallbackMessage'] is Map) {
            m = decodeMessage(
              Map<String, dynamic>.from(snapshot['fallbackMessage']),
            );
          } else {
            await db.execute('DELETE FROM messages WHERE id=?', [m.id]);
            final conversations = await db.query(
              'SELECT message_ids FROM conversations WHERE id=?',
              [row.read<String>('conversation_id')],
            );
            if (conversations.isNotEmpty) {
              final ids = List<String>.from(
                jsonDecode(conversations.single.read<String>('message_ids')),
              )..remove(m.id);
              await db.execute(
                'UPDATE conversations SET message_ids=? WHERE id=?',
                [jsonEncode(ids), row.read<String>('conversation_id')],
              );
            }
            await finish(row.read<String>('id'), 'interrupted');
            continue;
          }
          await db.execute('UPDATE messages SET payload=? WHERE id=?', [
            jsonEncode(encodeMessage(m)),
            m.id,
          ]);
        }
        await finish(row.read<String>('id'), 'interrupted');
      }
      await deleteUnreferenced(rows.map((row) => row.read<String>('id')));
    });
  }
}
