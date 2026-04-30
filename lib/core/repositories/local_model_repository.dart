import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';
import 'package:servllama/core/services/model_storage_paths.dart';

class LocalModelRepository {
  LocalModelRepository({
    Directory? appSupportDirectory,
    ModelStoragePaths? storagePaths,
    HiveInterface? hive,
    AppLogger? logger,
  }) : _storagePaths =
           storagePaths ??
           ModelStoragePaths(appSupportDirectory: appSupportDirectory),
       _hive = hive ?? Hive,
       _logger = logger ?? AppLogger.instance;

  static const String boxName = 'imported_models';
  static const String modelsFolderName = ModelStoragePaths.modelsFolderName;

  final ModelStoragePaths _storagePaths;
  final HiveInterface _hive;
  final AppLogger _logger;

  Future<Box<ModelDescriptor>>? _boxFuture;
  String? _initializedHivePath;
  final Random _random = Random();

  Future<List<ModelDescriptor>> listModels() async {
    final box = await _box();
    final descriptors = box.values.toList(growable: false);
    final staleIds = <String>[];
    final validModels = <ModelDescriptor>[];

    for (final descriptor in descriptors) {
      final currentFile = File(descriptor.storedFilePath);
      if (!await currentFile.exists()) {
        staleIds.add(descriptor.id);
        await _cleanupDirectory(descriptor.storedDirectoryPath);
        _logger.warning(
          '清理失效模型记录: ${descriptor.modelName}',
          channel: LogChannel.model,
        );
        continue;
      }
      validModels.add(descriptor);
    }

    if (staleIds.isNotEmpty) {
      await box.deleteAll(staleIds);
    }

    validModels.sort(
      (left, right) => right.importedAt.compareTo(left.importedAt),
    );
    return validModels;
  }

  Future<ModelDescriptor> importModel(PickedGgufFile pickedFile) async {
    if (!_isGgufFileName(pickedFile.fileName)) {
      throw StateError('仅支持导入 .gguf 模型文件。');
    }

    final sourceFile = File(pickedFile.path);
    if (!await sourceFile.exists()) {
      throw StateError('所选模型文件不存在。');
    }

    final modelName = _deriveModelName(pickedFile.fileName);
    if (modelName.isEmpty) {
      throw StateError('模型名称无效。');
    }

    final models = await listModels();
    final normalizedModelName = _normalizeModelKey(modelName);
    final hasDuplicate = models.any(
      (model) => _normalizeModelKey(model.modelName) == normalizedModelName,
    );
    if (hasDuplicate) {
      throw StateError('模型已存在，请勿重复导入同名模型。');
    }

    final modelDirectory = await _storagePaths.getModelDirectory(modelName);
    if (await modelDirectory.exists()) {
      throw StateError('模型已存在，请勿重复导入同名模型。');
    }
    await modelDirectory.create(recursive: true);

    final storedFilePath = _joinPath(modelDirectory.path, pickedFile.fileName);

    try {
      final copiedFile = await sourceFile.copy(storedFilePath);
      final fileSize = await copiedFile.length();
      final descriptor = ModelDescriptor(
        id: _generateModelId(),
        modelName: modelName,
        sizeBytes: fileSize,
        storedDirectoryPath: modelDirectory.path,
        storedFilePath: copiedFile.path,
        importedAt: DateTime.now(),
      );
      final box = await _box();
      await box.put(descriptor.id, descriptor);
      return descriptor;
    } catch (_) {
      await _cleanupDirectory(modelDirectory.path);
      rethrow;
    }
  }

  Future<void> deleteModel(String modelId) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw StateError('模型不存在或已被删除。');
    }

    await _cleanupDirectory(descriptor.storedDirectoryPath);
    await box.delete(modelId);
  }

  Future<Box<ModelDescriptor>> _box() async {
    return _boxFuture ??= _openBox();
  }

  Future<Box<ModelDescriptor>> _openBox() async {
    await _ensureHiveInitialized();
    if (!_hive.isAdapterRegistered(0)) {
      _hive.registerAdapter(ModelDescriptorAdapter());
    }
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<ModelDescriptor>(boxName);
    }
    return _hive.openBox<ModelDescriptor>(boxName);
  }

  Future<void> _ensureHiveInitialized() async {
    final appSupportDirectory = await _storagePaths.getAppSupportDirectory();
    if (_initializedHivePath == appSupportDirectory.path) {
      return;
    }
    _hive.init(appSupportDirectory.path);
    _initializedHivePath = appSupportDirectory.path;
  }

  Future<void> _cleanupDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return;
    }
    await directory.delete(recursive: true);
  }

  String _generateModelId() {
    return 'model_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }

  String _deriveModelName(String sourceValue) {
    final trimmed = sourceValue.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    const suffix = '.gguf';
    if (trimmed.toLowerCase().endsWith(suffix)) {
      return trimmed.substring(0, trimmed.length - suffix.length).trim();
    }
    return trimmed;
  }

  String _normalizeModelKey(String modelName) => modelName.toLowerCase();

  bool _isGgufFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.gguf');

  String _joinPath(String left, String right) {
    final needsSeparator =
        !left.endsWith(Platform.pathSeparator) &&
        !right.startsWith(Platform.pathSeparator);
    if (needsSeparator) {
      return '$left${Platform.pathSeparator}$right';
    }
    return '$left$right';
  }
}
