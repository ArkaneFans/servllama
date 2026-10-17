import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/storage/owned_file_cleanup.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';
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
  late OwnedFileCleanup _files;
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
    _files = OwnedFileCleanup(db, directory);
    await _files.retry();
    return db;
  }

  Future<void> close() async {
    if (_directory != null && _injected == null && _ready != null) {
      await (await _ready!).close();
      _ready = null;
    }
  }

  Future<List<ChatSessionRecord>> loadSessions() async =>
      ChatRecordStore(await database).sessions();
  Future<int> countUsingConnection(
    String connectionId,
  ) async => (await (await database).query(
    "SELECT count(*) AS total FROM conversations c JOIN assistants a ON a.id=c.assistant_id "
    "WHERE json_extract(a.config,'\$.chatTarget.connectionId')=?",
    [connectionId],
  )).single.read<int>('total');

  Future<void> saveSession(ChatSessionRecord s) async {
    final db = await database;
    final store = ChatRecordStore(db);
    await db.transaction(() async {
      await store.saveSession(s);
      for (final m in s.legacyMessages) {
        await store.saveMessage(m.copyWith(sessionId: s.id));
      }
    });
  }

  Future<void> saveMessage(ChatMessageRecord m) async {
    final db = await database;
    await db.transaction(() => ChatRecordStore(db).saveMessage(m));
  }

  /// Header, membership, changed bodies and their references commit together.
  Future<void> commitSession(
    ChatSessionRecord session, {
    List<ChatMessageRecord> changedMessages = const [],
  }) async {
    final db = await database;
    final store = ChatRecordStore(db);
    await db.transaction(() async {
      await store.saveSession(session);
      final kept = session.messageIds.toSet();
      final removed = (await store.messageIds(
        session.id,
      )).where((id) => !kept.contains(id));
      await _deleteMessageRows(db, removed);
      final changed = {for (final m in changedMessages) m.id: m};
      for (final id in session.messageIds) {
        final message = changed[id];
        if (message != null) {
          await store.saveMessage(message.copyWith(sessionId: session.id));
        }
      }
    });
  }

  Future<void> cleanupFiles() async {
    await database;
    await _files.retry();
  }

  Future<ChatMessageRecord?> loadMessage(String id) async =>
      ChatRecordStore(await database).message(id);
  Future<void> warmUpMessageStore() async {
    await database;
  }

  Future<List<ChatMessageRecord>> loadAllMessages(ChatSessionRecord s) async =>
      ChatRecordStore(await database).messages('m.conversation_id=?', [s.id]);
  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord s, {
    int limit = 30,
  }) async => (await ChatRecordStore(await database).messages(
    'm.conversation_id=?',
    [s.id],
    order: 'm.position DESC',
    limit: limit,
  )).reversed.toList();
  Future<List<ChatMessageRecord>> loadMessagesBefore(
    ChatSessionRecord s, {
    required String beforeMessageId,
    int limit = 30,
  }) async => (await ChatRecordStore(await database).messages(
    'm.conversation_id=? AND m.position < (SELECT position FROM messages WHERE id=? AND conversation_id=?)',
    [s.id, beforeMessageId, s.id],
    order: 'm.position DESC',
    limit: limit,
  )).reversed.toList();

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
    final recent = (await loadRecentMessages(s, limit: max)).reversed.toList();
    var count = 0, weight = 0;
    for (final m in recent) {
      final w =
          m.content.length + ((m.reasoningContent?.length ?? 0) * .8).round();
      weight +=
          (m.role == ChatRole.user && w < 200 ? 200 : w) +
          m.imageFilePaths.length * 1200;
      count++;
      if (count >= min && weight >= budget) break;
    }
    if (count.isOdd && count < recent.length) count++;
    return recent.take(count).toList().reversed.toList();
  }

  Future<void> saveMessageVersion(ChatMessageVersionRecord v) async {
    final db = await database;
    await db.transaction(() => ChatRecordStore(db).saveVersion(v));
  }

  Future<ChatMessageVersionRecord?> loadMessageVersion(String id) async =>
      ChatRecordStore(await database).version(id);
  Future<List<ChatMessageVersionRecord>> loadMessageVersions(
    Iterable<String> ids,
  ) async {
    final result = <ChatMessageVersionRecord>[];
    for (final id in ids) {
      final v = await loadMessageVersion(id);
      if (v != null) result.add(v);
    }
    return result;
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.transaction(() async {
      await _deleteMessageRows(db, await ChatRecordStore(db).messageIds(id));
      await db.execute('DELETE FROM conversations WHERE id=?', [id]);
    });
    await cleanupFiles();
  }

  Future<Set<String>> deleteAssistantAndSessions(String assistantId) async {
    final db = await database;
    final deleted = await db.transaction(() async {
      final assistants = await db.query('SELECT id FROM assistants');
      if (!assistants.any((r) => r.read<String>('id') == assistantId)) {
        throw StateError('Assistant unavailable');
      }
      if (assistants.length == 1) {
        throw StateError(
          'Create another assistant before deleting the last one',
        );
      }
      final ids = (await db.query(
        'SELECT id FROM conversations WHERE assistant_id=?',
        [assistantId],
      )).map((r) => r.read<String>('id')).toSet();
      for (final id in ids) {
        await _deleteMessageRows(db, await ChatRecordStore(db).messageIds(id));
      }
      // Conversation, draft and run/receipt foreign keys follow current ownership.
      await db.execute('DELETE FROM assistants WHERE id=?', [assistantId]);
      return ids;
    });
    await cleanupFiles();
    return deleted;
  }

  Future<void> deleteMessages(Iterable<ChatMessageRecord> messages) async {
    final db = await database;
    await db.transaction(
      () => _deleteMessageRows(db, messages.map((m) => m.id)),
    );
  }

  Future<void> commitMessageDeletion(
    ChatSessionRecord session,
    ChatMessageRecord original, {
    ChatMessageRecord? replacement,
  }) async {
    final db = await database;
    final store = ChatRecordStore(db);
    await db.transaction(() async {
      final current = await store.message(original.id);
      if (current == null ||
          jsonEncode(encodeMessage(current)) !=
              jsonEncode(encodeMessage(original))) {
        throw StateError('Message changed before deletion');
      }
      final expectedIds = await store.messageIds(session.id);
      if (original.sessionId != session.id ||
          !expectedIds.contains(original.id)) {
        throw StateError('Conversation changed before deletion');
      }
      if (replacement == null) expectedIds.remove(original.id);
      if (jsonEncode(expectedIds) != jsonEncode(session.messageIds)) {
        throw StateError('Conversation changed before deletion');
      }
      final running = await db.query(
        "SELECT 1 FROM message_revisions r JOIN generation_runs g ON g.id=r.run_id "
        "WHERE r.message_id=? AND g.state IN ('running','awaitingApproval','cancelling') LIMIT 1",
        [original.id],
      );
      if (running.isNotEmpty) {
        throw StateError('Finish generation before deleting');
      }
      if (replacement == null) {
        await _deleteMessageRows(db, [original.id]);
      } else {
        final kept = [...original.versionIds]
          ..removeAt(original.currentVersionIndex);
        if (replacement.id != original.id ||
            replacement.sessionId != session.id ||
            kept.isEmpty ||
            jsonEncode(replacement.versionIds) != jsonEncode(kept)) {
          throw StateError('Invalid replacement message');
        }
        final removed = original.versionIds[original.currentVersionIndex];
        await store.saveMessage(replacement);
        await _deleteVersions(db, [removed]);
      }
      await store.saveSession(session);
    });
    await cleanupFiles();
  }

  Future<void> _markAttachments(
    AppDatabase db,
    String where,
    List<Object> args,
  ) async {
    for (final row in await db.query(
      'SELECT a.path FROM revision_attachments a JOIN message_revisions r ON r.id=a.revision_id WHERE $where',
      args,
    )) {
      await _files.enqueue(
        row.read<String>('path'),
        OwnedFileKind.chatAttachment,
      );
    }
  }

  Future<void> _deleteMessageRows(AppDatabase db, Iterable<String> ids) async {
    final runs = <String>{};
    for (final id in ids.toList()) {
      await _markAttachments(db, 'r.message_id=?', [id]);
      runs.addAll(
        (await db.query(
          'SELECT run_id FROM message_revisions WHERE message_id=? AND run_id IS NOT NULL',
          [id],
        )).map((r) => r.read<String>('run_id')),
      );
      await db.execute('DELETE FROM messages WHERE id=?', [id]);
    }
    await GenerationRunRepository(db).deleteUnreferenced(runs);
  }

  Future<void> _deleteVersions(AppDatabase db, Iterable<String> ids) async {
    final runs = <String>{};
    for (final id in ids) {
      if ((await db.query(
        'SELECT 1 FROM message_revisions WHERE id=? AND is_selected=1',
        [id],
      )).isNotEmpty) {
        throw StateError('Select another version before deleting');
      }
      await _markAttachments(db, 'r.id=?', [id]);
      runs.addAll(
        (await db.query(
          'SELECT run_id FROM message_revisions WHERE id=? AND run_id IS NOT NULL',
          [id],
        )).map((r) => r.read<String>('run_id')),
      );
      await db.execute('DELETE FROM message_revisions WHERE id=?', [id]);
    }
    await GenerationRunRepository(db).deleteUnreferenced(runs);
  }

  Future<void> deleteMessageVersions(Iterable<String> ids) async {
    final db = await database;
    await db.transaction(() => _deleteVersions(db, ids));
  }
}
