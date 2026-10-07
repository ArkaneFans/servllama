import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

class ChatSessionRepository {
  ChatSessionRepository({
    Directory? appSupportDirectory,
    HiveInterface? hive,
    AppDatabase? database,
    this.onMigrationProgress,
  }) : _directory = appSupportDirectory,
       _hive = hive ?? Hive,
       _injected = database;
  static const boxName = 'chat_sessions';
  static const messageBoxName = 'chat_messages';
  static const versionBoxName = 'chat_message_versions';
  static const defaultInitialMessageMin = 2;
  static const defaultInitialMessageMax = 30;
  static const defaultInitialTextBudget = 20000;
  final Directory? _directory;
  final HiveInterface _hive;
  final AppDatabase? _injected;
  final void Function(LegacyMigrationProgress)? onMigrationProgress;
  Future<AppDatabase>? _ready;
  Future<AppDatabase> get database => _ready ??= _open();
  Future<AppDatabase> _open() async {
    final directory = _directory ?? await getApplicationSupportDirectory();
    final db =
        _injected ??
        (_directory == null
            ? await AppDatabase.shared()
            : AppDatabase.at(directory));
    await LegacyImporter(
      db,
      directory,
      hive: _hive,
      onProgress: onMigrationProgress,
    ).run();
    // The retired workspace has no reader/writer after this upgrade. Only
    // registered application-owned files enter the existing durable cleanup.
    await db.execute(
      "UPDATE artifacts SET state='deleting' WHERE owner_kind='conversation' AND state!='deleting'",
    );
    await _cleanupDeletedArtifacts(db, directory);
    return db;
  }

  Future<void> close() async {
    if (_directory != null && _injected == null && _ready != null) {
      await (await _ready!).close();
      _ready = null;
    }
  }

  Future<List<ChatSessionRecord>> loadSessions() async =>
      (await (await database).query(
        'SELECT * FROM conversations ORDER BY updated_at DESC',
      )).map(_session).toList();

  Future<int> countUsingConnection(
    String connectionId,
  ) async => (await (await database).query(
    "SELECT count(*) AS total FROM conversations c JOIN assistants a ON a.id=json_extract(c.config,'\$.assistantId') WHERE COALESCE(json_extract(a.config,'\$.chatTarget.connectionId'),json_extract(a.config,'\$.defaultTarget.connectionId'))=?",
    [connectionId],
  )).single.read<int>('total');
  ChatSessionRecord _session(QueryRow r) {
    final config = jsonDecode(r.read<String>('config')) as Map<String, dynamic>;
    return ChatSessionRecord(
      id: r.read<String>('id'),
      title: r.read<String>('title'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
      messageIds: List<String>.from(
        jsonDecode(r.read<String>('message_ids')) as List,
      ),
      assistantId: config['assistantId'] as String?,
    );
  }

  Future<void> saveSession(ChatSessionRecord s) async {
    final db = await database;
    await db.transaction(() async {
      for (final m in s.legacyMessages) {
        await saveMessage(m.copyWith(sessionId: s.id));
      }
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,message_ids,config)'
        ' VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,'
        'updated_at=excluded.updated_at,message_ids=excluded.message_ids,config=excluded.config',
        [
          s.id,
          s.title,
          s.createdAt.millisecondsSinceEpoch,
          s.updatedAt.millisecondsSinceEpoch,
          jsonEncode(s.messageIds),
          jsonEncode({'assistantId': s.assistantId}),
        ],
      );
    });
  }

  Future<void> saveMessage(ChatMessageRecord m) async {
    await (await database).execute(
      'INSERT INTO messages'
      '(id,conversation_id,role,created_at,payload) VALUES(?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET conversation_id=excluded.conversation_id,payload=excluded.payload',
      [
        m.id,
        m.sessionId,
        m.role.name,
        m.createdAt.millisecondsSinceEpoch,
        jsonEncode(encodeMessage(m)),
      ],
    );
  }

  /// A message and the conversation index become visible in the same commit.
  Future<void> commitSession(
    ChatSessionRecord session, {
    List<ChatMessageRecord> changedMessages = const [],
  }) async {
    final db = await database;
    await db.transaction(() async {
      for (final message in changedMessages) {
        await saveMessage(message);
      }
      await saveSession(session);
    });
  }

  Future<ChatMessageRecord?> loadMessage(String id) async {
    final rows = await (await database).query(
      'SELECT payload FROM messages WHERE id=?',
      [id],
    );
    return rows.isEmpty
        ? null
        : decodeMessage(
            await _withRunAuthor(
              jsonDecode(rows.single.read<String>('payload')),
            ),
          );
  }

  /// Older 2.0 records kept identity in the Run snapshot. Do not infer it from
  /// the currently selected assistant, or rewrite immutable revisions on read.
  Future<Map<String, dynamic>> _withRunAuthor(
    Map<String, dynamic> payload,
  ) async {
    if (payload['author'] != null ||
        payload['runId'] == null ||
        payload['role'] == 'user') {
      return payload;
    }
    final rows = await (await database).query(
      "SELECT json_extract(snapshot,'\$.assistant.id') AS assistant_id, "
      "json_extract(snapshot,'\$.assistant.name') AS assistant_name "
      'FROM generation_runs WHERE id=?',
      [payload['runId']],
    );
    if (rows.isEmpty) return payload;
    final id = rows.single.readNullable<String>('assistant_id');
    final name = rows.single.readNullable<String>('assistant_name');
    return id == null || name == null
        ? payload
        : {
            ...payload,
            'author': {'assistantId': id, 'name': name},
          };
  }

  Future<void> warmUpMessageStore() async {
    await database;
  }

  Future<List<ChatMessageRecord>> _load(Iterable<String> ids) async {
    final result = <ChatMessageRecord>[];
    for (final id in ids) {
      final m = await loadMessage(id);
      if (m != null) result.add(m);
    }
    return result;
  }

  Future<List<ChatMessageRecord>> loadAllMessages(ChatSessionRecord s) =>
      _load(s.messageIds);
  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord s, {
    int limit = 30,
  }) => _load(
    s.messageIds.skip(
      (s.messageIds.length - limit).clamp(0, s.messageIds.length),
    ),
  );
  Future<List<ChatMessageRecord>> loadMessagesBefore(
    ChatSessionRecord s, {
    required String beforeMessageId,
    int limit = 30,
  }) async {
    final i = s.messageIds.indexOf(beforeMessageId);
    if (i <= 0) return [];
    return _load(s.messageIds.sublist((i - limit).clamp(0, i), i));
  }

  Future<List<ChatMessageRecord>> loadInitialMessages(
    ChatSessionRecord s, {
    int minMessages = defaultInitialMessageMin,
    int maxMessages = defaultInitialMessageMax,
    int textBudget = defaultInitialTextBudget,
  }) async {
    if (s.messageIds.isEmpty) return [];
    final min = minMessages.clamp(1, s.messageIds.length);
    final max = (maxMessages <= 0 ? defaultInitialMessageMax : maxMessages)
        .clamp(min, s.messageIds.length);
    final budget = textBudget <= 0 ? defaultInitialTextBudget : textBudget;
    final out = <ChatMessageRecord>[];
    int index = s.messageIds.length, weight = 0;
    while (index > 0 && out.length < max) {
      final m = await loadMessage(s.messageIds[--index]);
      if (m == null) continue;
      out.add(m);
      final w =
          m.content.length + ((m.reasoningContent?.length ?? 0) * .8).round();
      weight +=
          (m.role == ChatRole.user && w < 200 ? 200 : w) +
          m.imageFilePaths.length * 1200;
      if (out.length >= min && weight >= budget) break;
    }
    if (out.length.isOdd && index > 0 && out.length < max) {
      final m = await loadMessage(s.messageIds[--index]);
      if (m != null) out.add(m);
    }
    return out.reversed.toList();
  }

  Future<void> saveMessageVersion(ChatMessageVersionRecord v) async {
    final db = await database;
    final payload = jsonEncode(
      encodeVersion(decodeVersion(await _withRunAuthor(encodeVersion(v)))),
    );
    await db.transaction(() async {
      final existing = await db.query(
        'SELECT payload FROM message_revisions WHERE id=?',
        [v.id],
      );
      if (existing.isNotEmpty) {
        if (jsonEncode(
              encodeVersion(
                decodeVersion(
                  await _withRunAuthor(
                    jsonDecode(existing.single.read<String>('payload')),
                  ),
                ),
              ),
            ) !=
            payload) {
          throw StateError('A committed message revision is immutable');
        }
        return;
      }
      await db.execute(
        'INSERT INTO message_revisions(id,message_id,created_at,payload)'
        ' VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING',
        [v.id, v.messageId, v.createdAt.millisecondsSinceEpoch, payload],
      );
    });
  }

  Future<ChatMessageVersionRecord?> loadMessageVersion(String id) async {
    final rows = await (await database).query(
      'SELECT payload FROM message_revisions WHERE id=?',
      [id],
    );
    return rows.isEmpty
        ? null
        : decodeVersion(
            await _withRunAuthor(
              jsonDecode(rows.single.read<String>('payload')),
            ),
          );
  }

  Future<List<ChatMessageVersionRecord>> loadMessageVersions(
    Iterable<String> ids,
  ) async {
    final out = <ChatMessageVersionRecord>[];
    for (final id in ids) {
      final v = await loadMessageVersion(id);
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    await db.transaction(() async {
      await _deleteSessionRows(db, directory, id);
      await _deleteDrafts(db, {id});
    });
    // Filesystem work happens after the database commit. Tombstones survive
    // process death or a locked file; speech jobs and voices own separate copies.
    await _cleanupDeletedArtifacts(db, directory);
  }

  /// Delete the assistant aggregate atomically, using current conversation
  /// ownership rather than historical message authors or Run snapshots.
  Future<Set<String>> deleteAssistantAndSessions(String assistantId) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    final deleted = await db.transaction(() async {
      final assistants = await db.query('SELECT id FROM assistants');
      if (!assistants.any((row) => row.read<String>('id') == assistantId)) {
        throw StateError('Assistant unavailable');
      }
      if (assistants.length == 1) {
        throw StateError(
          'Create another assistant before deleting the last one',
        );
      }
      final ids = (await db.query(
        "SELECT id FROM conversations WHERE json_extract(config,'\$.assistantId')=?",
        [assistantId],
      )).map((row) => row.read<String>('id')).toSet();
      for (final id in ids) {
        await _deleteSessionRows(db, directory, id);
      }
      await _deleteDrafts(db, {...ids, 'draft:$assistantId'});
      await db.execute('DELETE FROM assistants WHERE id=?', [assistantId]);
      return ids;
    });
    await _cleanupDeletedArtifacts(db, directory);
    return deleted;
  }

  Future<void> _deleteDrafts(AppDatabase db, Set<String> keys) async {
    final saved = await db.metadata('chatDrafts');
    if (saved == null) return;
    final drafts = Map<String, String>.from(jsonDecode(saved));
    drafts.removeWhere((key, _) => keys.contains(key));
    await db.setMetadata('chatDrafts', jsonEncode(drafts));
  }

  Future<void> _deleteSessionRows(
    AppDatabase db,
    Directory directory,
    String id,
  ) async {
    final rows = await db.query('SELECT * FROM conversations WHERE id=?', [id]);
    final messages = <String, ChatMessageRecord>{};
    if (rows.isNotEmpty) {
      for (final m in await loadAllMessages(_session(rows.single))) {
        messages[m.id] = m;
      }
    }
    for (final row in await db.query(
      'SELECT payload FROM messages WHERE conversation_id=?',
      [id],
    )) {
      final message = decodeMessage(jsonDecode(row.read<String>('payload')));
      messages[message.id] = message;
    }
    final paths = await _deleteMessageRows(db, messages.values);
    await _markAttachmentDeletion(db, directory, paths);
    await db.execute('DELETE FROM tool_invocations WHERE conversation_id=?', [
      id,
    ]);
    await db.execute('DELETE FROM generation_runs WHERE conversation_id=?', [
      id,
    ]);
    await db.execute(
      "UPDATE artifacts SET state='deleting' WHERE owner_kind='conversation' AND owner_id=?",
      [id],
    );
    await db.execute('DELETE FROM conversations WHERE id=?', [id]);
  }

  Future<void> deleteMessages(Iterable<ChatMessageRecord> messages) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    await db.transaction(() async {
      final paths = await _deleteMessageRows(db, messages);
      await _markAttachmentDeletion(db, directory, paths);
    });
    await _cleanupDeletedArtifacts(db, directory);
  }

  /// The selected body, revisions, conversation index and tool records commit
  /// together. Physical attachment cleanup follows the committed tombstones.
  Future<void> commitMessageDeletion(
    ChatSessionRecord session,
    ChatMessageRecord original, {
    ChatMessageRecord? replacement,
  }) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    await db.transaction(() async {
      final current = await loadMessage(original.id);
      if (current == null ||
          jsonEncode(encodeMessage(current)) !=
              jsonEncode(encodeMessage(original))) {
        throw StateError('Message changed before deletion');
      }
      final sessions = await db.query(
        'SELECT message_ids FROM conversations WHERE id=?',
        [session.id],
      );
      if (sessions.isEmpty || original.sessionId != session.id) {
        throw StateError('Conversation changed before deletion');
      }
      final expectedIds = List<String>.from(
        jsonDecode(sessions.single.read<String>('message_ids')),
      );
      if (!expectedIds.contains(original.id)) {
        throw StateError('Conversation changed before deletion');
      }
      if (replacement == null) expectedIds.remove(original.id);
      if (jsonEncode(expectedIds) != jsonEncode(session.messageIds)) {
        throw StateError('Conversation changed before deletion');
      }
      final running = await db.query(
        "SELECT 1 FROM generation_runs WHERE message_id=? AND state IN ('running','awaitingApproval','cancelling') LIMIT 1",
        [original.id],
      );
      if (running.isNotEmpty) {
        throw StateError('Finish generation before deleting');
      }
      final paths = <String>{};
      if (replacement == null) {
        paths.addAll(await _deleteMessageRows(db, [original]));
      } else {
        final keptIds = [...original.versionIds]
          ..removeAt(original.currentVersionIndex);
        if (replacement.id != original.id ||
            replacement.sessionId != session.id ||
            replacement.versionIds.isEmpty ||
            jsonEncode(replacement.versionIds) != jsonEncode(keptIds)) {
          throw StateError('Invalid replacement message');
        }
        final removed = original.versionIds.where(
          (id) => !replacement.versionIds.contains(id),
        );
        final runs = <String>{if (original.runId != null) original.runId!};
        paths.addAll(original.imageFilePaths);
        for (final id in removed) {
          final version = await loadMessageVersion(id);
          if (version == null || version.messageId != original.id) {
            throw StateError('Message version missing');
          }
          paths.addAll(version.imageFilePaths);
          if (version.runId != null) runs.add(version.runId!);
          await db.execute('DELETE FROM message_revisions WHERE id=?', [id]);
        }
        await saveMessage(replacement);
        await GenerationRunRepository(db).deleteUnreferenced(runs);
      }
      await saveSession(session);
      await _markAttachmentDeletion(db, directory, paths);
    });
    await _cleanupDeletedArtifacts(db, directory);
  }

  Future<Set<String>> _deleteMessageRows(
    AppDatabase db,
    Iterable<ChatMessageRecord> messages,
  ) async {
    final paths = <String>{};
    for (final message in messages) {
      final runs = <String>{
        if (message.runId != null) message.runId!,
        for (final row in await db.query(
          'SELECT id FROM generation_runs WHERE message_id=?',
          [message.id],
        ))
          row.read<String>('id'),
      };
      paths.addAll(message.imageFilePaths);
      for (final row in await db.query(
        'SELECT payload FROM message_revisions WHERE message_id=?',
        [message.id],
      )) {
        final version = decodeVersion(jsonDecode(row.read<String>('payload')));
        paths.addAll(version.imageFilePaths);
        final runId = version.runId;
        if (runId != null) runs.add(runId);
      }
      await db.execute('DELETE FROM message_revisions WHERE message_id=?', [
        message.id,
      ]);
      await db.execute('DELETE FROM messages WHERE id=?', [message.id]);
      await GenerationRunRepository(db).deleteUnreferenced(runs);
    }
    return paths;
  }

  Future<void> deleteMessageVersions(Iterable<String> ids) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    await db.transaction(() async {
      final versions = await loadMessageVersions(ids);
      for (final v in versions) {
        await db.execute('DELETE FROM message_revisions WHERE id=?', [v.id]);
      }
      await GenerationRunRepository(
        db,
      ).deleteUnreferenced(versions.map((v) => v.runId).whereType<String>());
      await _markAttachmentDeletion(
        db,
        directory,
        versions.expand((v) => v.imageFilePaths),
      );
    });
    await _cleanupDeletedArtifacts(db, directory);
  }

  Future<void> deleteMessageResources(
    Iterable<ChatMessageRecord> messages,
  ) async {
    final all = messages.toList();
    await deleteMessageVersions(all.expand((m) => m.versionIds));
    await deleteAttachmentFiles(all.expand((m) => m.imageFilePaths));
  }

  Future<void> deleteAttachmentFiles(Iterable<String> paths) async {
    final db = await database;
    final directory = _directory ?? await getApplicationSupportDirectory();
    await db.transaction(() => _markAttachmentDeletion(db, directory, paths));
    await _cleanupDeletedArtifacts(db, directory);
  }

  Future<void> _markAttachmentDeletion(
    AppDatabase db,
    Directory directory,
    Iterable<String> paths,
  ) async {
    final owned = p.join(directory.path, 'chat_attachments');
    for (final path in paths.toSet()) {
      if (!p.isWithin(owned, p.normalize(path))) continue;
      await db.execute(
        'INSERT INTO artifacts(id,path,mime_type,owner_kind,owner_id,hash,size,state) '
        "VALUES(?,?,'application/octet-stream','chat_attachment','','',0,'deleting') "
        'ON CONFLICT(path) DO NOTHING',
        [newId(), path],
      );
    }
  }

  Future<void> _cleanupDeletedArtifacts(
    AppDatabase db,
    Directory directory,
  ) async {
    try {
      final rows = await db.query(
        "SELECT * FROM artifacts WHERE state='deleting' AND owner_kind IN ('conversation','chat_attachment')",
      );
      if (rows.isEmpty) return;
      final referenced = <String>{};
      for (final row in await db.query(
        'SELECT payload FROM messages UNION ALL SELECT payload FROM message_revisions',
      )) {
        final data = jsonDecode(row.read<String>('payload')) as Map;
        referenced.addAll(
          List<String>.from(data['imageFilePaths'] as List? ?? []),
        );
      }
      final canonicalRoot = await directory.resolveSymbolicLinks();
      for (final row in rows) {
        final path = row.read<String>('path');
        final attachment = row.read<String>('owner_kind') == 'chat_attachment';
        final owner = row.read<String>('owner_id');
        if (!attachment && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(owner)) {
          continue;
        }
        final relative = attachment
            ? 'chat_attachments'
            : p.join('workspaces', owner);
        if (!p.isWithin(p.join(directory.path, relative), p.normalize(path))) {
          continue;
        }
        try {
          if (!referenced.contains(path)) {
            final f = File(path);
            final type = await FileSystemEntity.type(path, followLinks: false);
            if (type != FileSystemEntityType.notFound) {
              if (type != FileSystemEntityType.file ||
                  !p.isWithin(
                    p.join(canonicalRoot, relative),
                    await f.resolveSymbolicLinks(),
                  )) {
                continue;
              }
              await f.delete();
            }
          }
          await db.execute(
            "DELETE FROM artifacts WHERE id=? AND state='deleting'",
            [row.read<String>('id')],
          );
        } on FileSystemException {
          // A later launch retries the durable tombstone, without replaying work.
        }
      }
    } catch (error) {
      // A committed deletion must still update the UI if cleanup is unavailable.
      // Persistent tombstones are retried when the repository opens again.
      AppLogger.instance.event(
        'client.conversation.cleanup_failed',
        channel: LogChannel.client,
        level: LogLevel.warning,
        fields: AppLogger.errorFields(error),
      );
    }
  }
}
