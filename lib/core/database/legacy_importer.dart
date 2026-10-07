import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';

import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/core/logging/app_logger.dart';

/// Imports source records and completion markers in one SQLite transaction.
/// Retained Hive files are never business stores after startup succeeds.
class LegacyImporter {
  LegacyImporter(
    this.db,
    this.directory, {
    HiveInterface? hive,
    this.onProgress,
  }) : hive = hive ?? Hive;
  static const inventoryMarker = 'legacyInventoryImportComplete';
  final AppDatabase db;
  final Directory directory;
  final HiveInterface hive;
  final void Function(LegacyMigrationProgress)? onProgress;

  Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    final oldKey = prefs.getString(ServerPrefsKeys.apiKey);
    if (oldKey != null && oldKey.isNotEmpty) {
      await SecretStore.instance.write(ServerPrefsKeys.apiKey, oldKey);
    }
    final importChats = await db.metadata('legacyImportComplete') != '1';
    final importInventory = await db.metadata(inventoryMarker) != '1';
    final names = [
      if (importChats) ...[
        'chat_sessions',
        'chat_messages',
        'chat_message_versions',
      ],
      if (importInventory) ...['imported_models', 'download_tasks'],
    ];
    var hasLegacyFiles = false;
    for (final name in names) {
      if (hive.isBoxOpen(name) || await _sourceFile(name) != null) {
        hasLegacyFiles = true;
      }
    }
    var stage = LegacyMigrationStage.chats;
    void report(
      LegacyMigrationStage value, {
      int completed = 0,
      int total = 0,
    }) {
      stage = value;
      if (hasLegacyFiles) {
        onProgress?.call(
          LegacyMigrationProgress(value, completed: completed, total: total),
        );
      }
    }

    try {
      if (importChats || importInventory) {
        if (hasLegacyFiles) {
          AppLogger.instance.event('storage.migration.started');
        }
        hive.init(directory.path);
        if (!hive.isAdapterRegistered(0)) {
          hive.registerAdapter(ModelDescriptorAdapter());
        }
        if (!hive.isAdapterRegistered(1)) {
          hive.registerAdapter(ChatMessageRecordAdapter());
        }
        if (!hive.isAdapterRegistered(2)) {
          hive.registerAdapter(ChatSessionRecordAdapter());
        }
        if (!hive.isAdapterRegistered(3)) {
          hive.registerAdapter(ChatRoleAdapter());
        }
        if (!hive.isAdapterRegistered(4)) {
          hive.registerAdapter(ChatMessageVersionRecordAdapter());
        }
        if (!hive.isAdapterRegistered(5)) {
          hive.registerAdapter(DownloadFileRecordAdapter());
        }
        if (!hive.isAdapterRegistered(6)) {
          hive.registerAdapter(DownloadTaskRecordAdapter());
        }
        report(LegacyMigrationStage.chats);
        final sessions = importChats
            ? await _read<ChatSessionRecord>('chat_sessions')
            : <ChatSessionRecord>[];
        final messages = importChats
            ? await _read<ChatMessageRecord>('chat_messages')
            : <ChatMessageRecord>[];
        final versions = importChats
            ? await _read<ChatMessageVersionRecord>('chat_message_versions')
            : <ChatMessageVersionRecord>[];
        report(LegacyMigrationStage.models);
        final models = importInventory
            ? await _read<ModelDescriptor>('imported_models')
            : <ModelDescriptor>[];
        report(LegacyMigrationStage.downloads);
        final downloads = importInventory
            ? await _read<DownloadTaskRecord>('download_tasks')
            : <DownloadTaskRecord>[];
        final messageIds = {
          for (final m in messages) m.id,
          for (final s in sessions) ...s.legacyMessages.map((m) => m.id),
        };
        final total =
            sessions.length +
            messageIds.length +
            versions.length +
            models.length +
            downloads.length;
        var written = 0;
        void step() => report(
          LegacyMigrationStage.writing,
          completed: ++written,
          total: total,
        );
        report(LegacyMigrationStage.writing, total: total);
        await db.transaction(() async {
          if (importChats) {
            await _importChats(sessions, messages, versions, step);
          }
          if (importInventory) {
            final store = GgufModelStore(db);
            for (final model in models) {
              final existing = await store.find(model.id);
              if (existing != null &&
                  jsonEncode(existing.toJson()) != jsonEncode(model.toJson())) {
                throw StateError('Conflicting existing GGUF record');
              }
              await store.save(model);
              step();
            }
            for (final task in downloads) {
              await db.execute(
                'INSERT OR IGNORE INTO download_tasks(id,created_at,payload) VALUES(?,?,?)',
                [
                  task.id,
                  task.createdAt.microsecondsSinceEpoch,
                  jsonEncode(task.toJson()),
                ],
              );
              step();
            }
            // Read back the complete payloads before publishing the marker.
            var verified = 0;
            final verifyTotal = models.length + downloads.length;
            report(LegacyMigrationStage.verifying, total: verifyTotal);
            for (final model in models) {
              final saved = await store.find(model.id);
              if (saved == null ||
                  jsonEncode(saved.toJson()) != jsonEncode(model.toJson())) {
                throw StateError('GGUF migration verification failed');
              }
              report(
                LegacyMigrationStage.verifying,
                completed: ++verified,
                total: verifyTotal,
              );
            }
            for (final task in downloads) {
              final saved = await db.query(
                'SELECT payload FROM download_tasks WHERE id=?',
                [task.id],
              );
              if (saved.length != 1 ||
                  saved.single.read<String>('payload') !=
                      jsonEncode(task.toJson())) {
                throw StateError('Download migration verification failed');
              }
              report(
                LegacyMigrationStage.verifying,
                completed: ++verified,
                total: verifyTotal,
              );
            }
            await db.setMetadata(inventoryMarker, '1');
            await db.setMetadata(
              'legacyInventoryImportCounts',
              jsonEncode({
                'models': models.length,
                'downloads': downloads.length,
              }),
            );
          }
        });
        if (hasLegacyFiles) {
          AppLogger.instance.event(
            'storage.migration.completed',
            fields: {'records': total},
          );
        }
      }
      // Credentials are outside SQLite; only retire the old preference after commit.
      if (oldKey != null && !await prefs.remove(ServerPrefsKeys.apiKey)) {
        throw StateError('Legacy credential cleanup failed');
      }
      report(LegacyMigrationStage.complete);
    } catch (error) {
      AppLogger.instance.event(
        'storage.migration.failed',
        level: LogLevel.error,
        fields: {
          'stage': stage.name,
          'error_type': error.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  Future<void> _importChats(
    List<ChatSessionRecord> sessions,
    List<ChatMessageRecord> messages,
    List<ChatMessageVersionRecord> versions,
    void Function() step,
  ) async {
    final allMessages = {for (final m in messages) m.id: m};
    for (final s in sessions) {
      for (final m in s.legacyMessages) {
        allMessages[m.id] = m.copyWith(sessionId: s.id);
      }
      for (final id in s.messageIds) {
        final m = allMessages[id];
        if (m != null) allMessages[id] = m.copyWith(sessionId: s.id);
      }
      await db.execute(
        'INSERT OR IGNORE INTO conversations'
        '(id,title,created_at,updated_at,message_ids) VALUES(?,?,?,?,?)',
        [
          s.id,
          s.title,
          s.createdAt.millisecondsSinceEpoch,
          s.updatedAt.millisecondsSinceEpoch,
          jsonEncode(s.messageIds),
        ],
      );
      step();
    }
    for (final m in allMessages.values) {
      await db.execute(
        'INSERT OR IGNORE INTO messages'
        '(id,conversation_id,role,created_at,payload) VALUES(?,?,?,?,?)',
        [
          m.id,
          m.sessionId,
          m.role.name,
          m.createdAt.millisecondsSinceEpoch,
          jsonEncode(encodeMessage(m)),
        ],
      );
      step();
    }
    for (final v in versions) {
      await db.execute(
        'INSERT OR IGNORE INTO message_revisions'
        '(id,message_id,created_at,payload) VALUES(?,?,?,?)',
        [
          v.id,
          v.messageId,
          v.createdAt.millisecondsSinceEpoch,
          jsonEncode(encodeVersion(v)),
        ],
      );
      step();
    }
    await db.setMetadata('legacyImportComplete', '1');
    await db.setMetadata(
      'legacyImportCounts',
      jsonEncode({
        'sessions': sessions.length,
        'messages': allMessages.length,
        'versions': versions.length,
      }),
    );
  }

  Future<List<T>> _read<T>(String name) async {
    if (hive.isBoxOpen(name)) return hive.box<T>(name).values.toList();
    final source = await _sourceFile(name);
    if (source == null) return [];
    final bytes = await source.readAsBytes();
    final result = Completer<List<T>>();
    void fail(Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    }

    // Hive 2.2.3 also fails an internal, unobserved opening-box completer.
    // Confine both copies of that error to this read and surface one failure.
    runZonedGuarded(() async {
      try {
        // The memory backend validates checksums without touching source files
        // or applying Hive's on-disk compaction/recovery side effects.
        final box = await hive.openBox<T>(
          name,
          bytes: bytes,
          crashRecovery: false,
        );
        late List<T> records;
        try {
          records = box.values.toList();
        } finally {
          await box.close();
        }
        if (!result.isCompleted) result.complete(records);
      } catch (error, stack) {
        fail(error, stack);
      }
    }, fail);
    return result.future;
  }

  Future<File?> _sourceFile(String name) async {
    // Hive prefers the ordinary file; a lone .hivec is a completed compaction
    // awaiting its final rename. Read it without renaming or deleting either.
    for (final extension in ['hive', 'hivec']) {
      final file = File(p.join(directory.path, '$name.$extension'));
      if (await file.exists()) return file;
    }
    return null;
  }
}
