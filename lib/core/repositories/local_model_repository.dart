import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
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

      if (descriptor.mmprojFilePath != null) {
        final mmprojFile = File(descriptor.mmprojFilePath!);
        if (!await mmprojFile.exists()) {
          final patched = descriptor.copyWith(mmprojFilePath: null);
          await box.put(patched.id, patched);
          validModels.add(patched);
          continue;
        }
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
      throw const ModelOperationException(
        ModelOperationErrorCode.unsupportedGgufFile,
      );
    }

    final sourceFile = File(pickedFile.path);
    if (!await sourceFile.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.selectedModelFileMissing,
      );
    }

    final modelName = _deriveModelName(pickedFile.fileName);
    if (modelName.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
    _validateModelName(modelName);

    final models = await listModels();
    final normalizedModelName = _normalizeModelKey(modelName);
    final hasDuplicate = models.any(
      (model) => _normalizeModelKey(model.modelName) == normalizedModelName,
    );
    if (hasDuplicate) {
      throw const ModelOperationException(
        ModelOperationErrorCode.duplicateModelName,
      );
    }

    final modelDirectory = await _storagePaths.getModelDirectory(modelName);
    if (await modelDirectory.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.duplicateModelName,
      );
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

  Future<ModelDescriptor> importMmproj(
    String modelId,
    PickedGgufFile pickedFile,
  ) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(ModelOperationErrorCode.modelNotFound);
    }

    final sourceFile = File(pickedFile.path);
    if (!await sourceFile.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.selectedMmprojFileMissing,
      );
    }
    if (!_isMmprojFileName(pickedFile.fileName)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.unsupportedMmprojFile,
      );
    }

    final mmprojDestPath = _joinPath(
      descriptor.storedDirectoryPath,
      pickedFile.fileName,
    );
    if (_sameFilePath(mmprojDestPath, descriptor.storedFilePath)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.mmprojSameAsModelFile,
      );
    }

    final existingMmprojPath = descriptor.mmprojFilePath;
    if (existingMmprojPath != null && !_sameFilePath(existingMmprojPath, mmprojDestPath)) {
      final existingMmprojFile = File(existingMmprojPath);
      if (await existingMmprojFile.exists()) {
        await existingMmprojFile.delete();
      }
    }

    final destinationFile = File(mmprojDestPath);
    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    final copiedFile = await sourceFile.copy(mmprojDestPath);
    final updated = descriptor.copyWith(mmprojFilePath: copiedFile.path);
    await box.put(descriptor.id, updated);
    return updated;
  }

  Future<ModelDescriptor> removeMmproj(String modelId) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(ModelOperationErrorCode.modelNotFound);
    }

    final currentPath = descriptor.mmprojFilePath;
    if (currentPath != null) {
      final file = File(currentPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final updated = descriptor.copyWith(mmprojFilePath: null);
    await box.put(descriptor.id, updated);
    return updated;
  }

  Future<ModelDescriptor> renameModel(String modelId, String newName) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(ModelOperationErrorCode.modelNotFound);
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.emptyModelName,
      );
    }
    _validateModelName(trimmed);

    final allModels = await listModels();
    final hasDuplicate = allModels.any(
      (m) =>
          m.id != modelId &&
          _normalizeModelKey(m.modelName) == _normalizeModelKey(trimmed),
    );
    if (hasDuplicate) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNameExists,
      );
    }

    final oldDir = Directory(descriptor.storedDirectoryPath);
    final newDir = await _storagePaths.getModelDirectory(trimmed);
    if (await newDir.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelDirectoryExists,
      );
    }
    final didRenameDirectory = await oldDir.exists();
    if (didRenameDirectory) {
      await oldDir.rename(newDir.path);
    }

    final oldFileName = descriptor.storedFilePath.split(Platform.pathSeparator).last;
    final newStoredFilePath = _joinPath(newDir.path, oldFileName);
    String? newMmprojPath;
    if (descriptor.mmprojFilePath != null) {
      final mmprojFileName =
          descriptor.mmprojFilePath!.split(Platform.pathSeparator).last;
      newMmprojPath = _joinPath(newDir.path, mmprojFileName);
    }

    final updated = descriptor.copyWith(
      modelName: trimmed,
      storedDirectoryPath: newDir.path,
      storedFilePath: newStoredFilePath,
      mmprojFilePath: newMmprojPath,
    );
    try {
      await box.put(descriptor.id, updated);
    } catch (_) {
      // Roll the directory back so the stale record does not point at a
      // missing path (listModels would garbage-collect the model otherwise).
      if (didRenameDirectory) {
        await Directory(newDir.path).rename(oldDir.path);
      }
      rethrow;
    }
    return updated;
  }

  /// Registers an already-downloaded GGUF file by *moving* it into the models
  /// directory. Import copies, which would mean writing a second multi-GB copy
  /// of a file the app just wrote itself; downloads land in private storage on
  /// the same volume, so a rename is both correct and free.
  Future<ModelDescriptor> adoptDownloadedModel({
    required String modelName,
    required File modelFile,
    File? mmprojFile,
  }) async {
    final trimmedName = modelName.trim();
    if (trimmedName.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.emptyModelName,
      );
    }
    _validateModelName(trimmedName);

    if (!await modelFile.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.selectedModelFileMissing,
      );
    }

    final models = await listModels();
    final normalized = _normalizeModelKey(trimmedName);
    if (models.any((m) => _normalizeModelKey(m.modelName) == normalized)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.duplicateModelName,
      );
    }

    final modelDirectory = await _storagePaths.getModelDirectory(trimmedName);
    if (await modelDirectory.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.duplicateModelName,
      );
    }
    await modelDirectory.create(recursive: true);

    try {
      final fileName = modelFile.path.split(RegExp(r'[\\/]')).last;
      final stored = await _moveInto(modelFile, modelDirectory.path, fileName);

      String? storedMmprojPath;
      if (mmprojFile != null && await mmprojFile.exists()) {
        final mmprojName = mmprojFile.path.split(RegExp(r'[\\/]')).last;
        final storedMmproj = await _moveInto(
          mmprojFile,
          modelDirectory.path,
          mmprojName,
        );
        storedMmprojPath = storedMmproj.path;
      }

      final descriptor = ModelDescriptor(
        id: _generateModelId(),
        modelName: trimmedName,
        sizeBytes: await stored.length(),
        storedDirectoryPath: modelDirectory.path,
        storedFilePath: stored.path,
        importedAt: DateTime.now(),
        mmprojFilePath: storedMmprojPath,
      );
      final box = await _box();
      await box.put(descriptor.id, descriptor);
      _logger.info('已收录下载的模型: $trimmedName', channel: LogChannel.model);
      return descriptor;
    } catch (_) {
      await _cleanupDirectory(modelDirectory.path);
      rethrow;
    }
  }

  /// Rename first; falls back to copy+delete when the source sits on another
  /// volume (rename fails with EXDEV there).
  Future<File> _moveInto(File source, String directoryPath, String fileName) async {
    final targetPath = _joinPath(directoryPath, fileName);
    try {
      return await source.rename(targetPath);
    } on FileSystemException {
      final copied = await source.copy(targetPath);
      await source.delete();
      return copied;
    }
  }

  Future<void> deleteModel(String modelId) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFoundOrDeleted,
      );
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

  // Model names become directory names under models/; anything that could
  // escape that directory or is invalid as a single path segment is rejected.
  static final RegExp _invalidModelNameChars = RegExp(
    r'[\\/\x00-\x1F]',
  );

  void _validateModelName(String modelName) {
    if (modelName == '.' ||
        modelName == '..' ||
        _invalidModelNameChars.hasMatch(modelName)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
  }

  bool _isGgufFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.gguf');

  bool _isMmprojFileName(String fileName) {
    final normalized = fileName.toLowerCase();
    return normalized.startsWith('mmproj') && normalized.endsWith('.gguf');
  }

  bool _sameFilePath(String left, String right) {
    final normalizedLeft = _normalizeFilePath(left);
    final normalizedRight = _normalizeFilePath(right);
    return normalizedLeft == normalizedRight;
  }

  String _normalizeFilePath(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator).replaceAll(
      '\\',
      Platform.pathSeparator,
    );
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

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
