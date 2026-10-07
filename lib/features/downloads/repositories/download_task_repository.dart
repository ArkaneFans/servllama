import 'dart:io';

import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/features/downloads/models/download_task.dart';

/// Persists download tasks so an interrupted transfer survives an app
/// restart, and owns the staging directory each task writes into.
class DownloadTaskRepository {
  DownloadTaskRepository({
    ModelStoragePaths? storagePaths,
    AppDatabase? database,
  }) : _storagePaths = storagePaths ?? ModelStoragePaths(),
       _database = database;

  static const String stagingFolderName = 'downloads';

  final ModelStoragePaths _storagePaths;
  final AppDatabase? _database;

  Future<AppDatabase> get database async =>
      _database ?? await AppDatabase.shared();

  Future<List<DownloadTaskRecord>> listTasks() async =>
      (await (await database).query(
            'SELECT payload FROM download_tasks ORDER BY created_at DESC',
          ))
          .map(
            (row) => DownloadTaskRecord.fromJson(
              jsonDecode(row.read<String>('payload')),
            ),
          )
          .toList();

  Future<void> save(DownloadTaskRecord task) async {
    // Snapshot mutable progress before the first await.
    final id = task.id;
    final createdAt = task.createdAt.microsecondsSinceEpoch;
    final payload = jsonEncode(task.toJson());
    await (await database).execute(
      'INSERT INTO download_tasks(id,created_at,payload) VALUES(?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET created_at=excluded.created_at,payload=excluded.payload',
      [id, createdAt, payload],
    );
  }

  Future<void> delete(String taskId) async {
    await (await database).execute('DELETE FROM download_tasks WHERE id=?', [
      taskId,
    ]);
  }

  Future<Directory> createStagingDirectory(String taskId) async {
    final appSupport = await _storagePaths.getAppSupportDirectory();
    final directory = Directory(
      '${appSupport.path}${Platform.pathSeparator}$stagingFolderName'
      '${Platform.pathSeparator}$taskId',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> deleteStagingDirectory(String stagingDirPath) async {
    final directory = Directory(stagingDirPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Bytes sitting in staging directories that no longer belong to a task.
  Future<int> orphanedStagingBytes() async {
    final appSupport = await _storagePaths.getAppSupportDirectory();
    final root = Directory(
      '${appSupport.path}${Platform.pathSeparator}$stagingFolderName',
    );
    if (!await root.exists()) {
      return 0;
    }
    final known = (await listTasks())
        .map((task) => task.stagingDirPath)
        .toSet();
    var total = 0;
    await for (final entity in root.list()) {
      if (entity is! Directory || known.contains(entity.path)) {
        continue;
      }
      total += await _directorySize(entity);
    }
    return total;
  }

  Future<void> clearOrphanedStaging() async {
    final appSupport = await _storagePaths.getAppSupportDirectory();
    final root = Directory(
      '${appSupport.path}${Platform.pathSeparator}$stagingFolderName',
    );
    if (!await root.exists()) {
      return;
    }
    final known = (await listTasks())
        .map((task) => task.stagingDirPath)
        .toSet();
    await for (final entity in root.list()) {
      if (entity is Directory && !known.contains(entity.path)) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<int> _directorySize(Directory directory) async {
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
