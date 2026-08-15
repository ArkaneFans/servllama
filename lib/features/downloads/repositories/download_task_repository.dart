import 'dart:io';

import 'package:hive/hive.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/features/downloads/models/download_task.dart';

/// Persists download tasks so an interrupted transfer survives an app
/// restart, and owns the staging directory each task writes into.
class DownloadTaskRepository {
  DownloadTaskRepository({
    ModelStoragePaths? storagePaths,
    HiveInterface? hive,
  }) : _storagePaths = storagePaths ?? ModelStoragePaths(),
       _hive = hive ?? Hive;

  static const String boxName = 'download_tasks';
  static const String stagingFolderName = 'downloads';

  final ModelStoragePaths _storagePaths;
  final HiveInterface _hive;

  Future<Box<DownloadTaskRecord>>? _boxFuture;
  String? _initializedHivePath;

  Future<List<DownloadTaskRecord>> listTasks() async {
    final box = await _box();
    final tasks = box.values.toList(growable: true);
    tasks.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return tasks;
  }

  Future<void> save(DownloadTaskRecord task) async {
    final box = await _box();
    await box.put(task.id, task);
  }

  Future<void> delete(String taskId) async {
    final box = await _box();
    await box.delete(taskId);
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
    final known = (await listTasks()).map((task) => task.stagingDirPath).toSet();
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
    final known = (await listTasks()).map((task) => task.stagingDirPath).toSet();
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

  Future<Box<DownloadTaskRecord>> _box() async => _boxFuture ??= _openBox();

  Future<Box<DownloadTaskRecord>> _openBox() async {
    final appSupport = await _storagePaths.getAppSupportDirectory();
    if (_initializedHivePath != appSupport.path) {
      _hive.init(appSupport.path);
      _initializedHivePath = appSupport.path;
    }
    if (!_hive.isAdapterRegistered(5)) {
      _hive.registerAdapter(DownloadFileRecordAdapter());
    }
    if (!_hive.isAdapterRegistered(6)) {
      _hive.registerAdapter(DownloadTaskRecordAdapter());
    }
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<DownloadTaskRecord>(boxName);
    }
    return _hive.openBox<DownloadTaskRecord>(boxName);
  }
}
