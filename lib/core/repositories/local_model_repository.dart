import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/utils/gguf_file_name.dart';

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

  // Providers own separate repository instances, but share the Hive box.
  // Serialize projector updates so concurrent downloads cannot lose entries.
  static Future<void> _projectorOperations = Future<void>.value();

  Future<T> _withProjectorLock<T>(Future<T> Function() operation) {
    final result = _projectorOperations.then((_) => operation());
    _projectorOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<List<ModelDescriptor>> listModels() => _withProjectorLock(_listModels);

  Future<List<ModelDescriptor>> _listModels() async {
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

      final projectors = descriptor.availableMmprojs;
      final existingProjectors = <String, String>{};
      for (final entry in projectors.entries) {
        if (await File(entry.value).exists()) {
          existingProjectors[entry.key] = entry.value;
        }
      }
      if (existingProjectors.length != projectors.length) {
        final selected =
            existingProjectors.containsValue(descriptor.mmprojFilePath)
            ? descriptor.mmprojFilePath
            : (existingProjectors.isEmpty
                  ? null
                  : existingProjectors.values.first);
        final patched = descriptor.copyWith(
          mmprojFilePath: selected,
          mmprojFiles: existingProjectors,
          visionEnabled:
              existingProjectors.isNotEmpty && descriptor.isVisionEnabled,
        );
        await box.put(patched.id, patched);
        validModels.add(patched);
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

  Future<ModelDescriptor> importModel(
    PickedGgufFile pickedFile, {
    String? modelName,
  }) async {
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

    final resolvedModelName =
        modelName?.trim() ?? modelNameFromFileName(pickedFile.fileName);
    if (resolvedModelName.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
    _validateModelName(resolvedModelName);

    final models = await listModels();
    final normalizedModelName = _normalizeModelKey(resolvedModelName);
    final hasDuplicate = models.any(
      (model) => _normalizeModelKey(model.modelName) == normalizedModelName,
    );
    if (hasDuplicate) {
      throw const ModelOperationException(
        ModelOperationErrorCode.duplicateModelName,
      );
    }

    final modelDirectory = await _storagePaths.getModelDirectory(
      resolvedModelName,
    );
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
        modelName: resolvedModelName,
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
  ) => _withProjectorLock(() async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
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

    final copiedFile = _sameFilePath(sourceFile.path, mmprojDestPath)
        ? sourceFile
        : await sourceFile.copy(mmprojDestPath);
    final updated = descriptor.copyWith(
      mmprojFilePath: copiedFile.path,
      visionEnabled: true,
    );
    await box.put(descriptor.id, updated);
    final previous = descriptor.mmprojFilePath;
    if (previous != null &&
        !descriptor.mmprojFiles.containsValue(previous) &&
        !_sameFilePath(previous, copiedFile.path) &&
        await File(previous).exists()) {
      await File(previous).delete();
    }
    return updated;
  });

  Future<ModelDescriptor> removeMmproj(String modelId) async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
    }

    final selected = descriptor.mmprojFilePath;
    if (selected == null) {
      return descriptor;
    }
    return removeMmprojFile(modelId, selected);
  }

  Future<ModelDescriptor> setVisionEnabled(String modelId, bool enabled) =>
      _withProjectorLock(() async {
        final box = await _box();
        final descriptor = _requireModel(box, modelId);
        final updated = descriptor.copyWith(visionEnabled: enabled);
        await box.put(descriptor.id, updated);
        return updated;
      });

  Future<ModelDescriptor> selectMmproj(String modelId, String filePath) =>
      _withProjectorLock(() async {
        final box = await _box();
        final descriptor = _requireModel(box, modelId);
        if (!descriptor.availableMmprojs.containsValue(filePath) ||
            !await File(filePath).exists()) {
          throw const ModelOperationException(
            ModelOperationErrorCode.selectedMmprojFileMissing,
          );
        }
        final updated = descriptor.copyWith(mmprojFilePath: filePath);
        await box.put(modelId, updated);
        return updated;
      });

  Future<ModelDescriptor> removeMmprojFile(String modelId, String filePath) =>
      _withProjectorLock(() async {
        final box = await _box();
        final descriptor = _requireModel(box, modelId);
        final files = Map<String, String>.from(descriptor.availableMmprojs);
        if (!files.containsValue(filePath)) {
          throw const ModelOperationException(
            ModelOperationErrorCode.selectedMmprojFileMissing,
          );
        }
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        files.removeWhere((_, path) => path == filePath);
        final selected = files.containsValue(descriptor.mmprojFilePath)
            ? descriptor.mmprojFilePath
            : (files.isEmpty ? null : files.values.first);
        final updated = descriptor.copyWith(
          mmprojFilePath: selected,
          mmprojFiles: files,
          visionEnabled: files.isNotEmpty && descriptor.isVisionEnabled,
        );
        await box.put(modelId, updated);
        return updated;
      });

  ModelDescriptor _requireModel(Box<ModelDescriptor> box, String modelId) {
    final model = box.get(modelId);
    if (model == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
    }
    return model;
  }

  Future<ModelDescriptor> renameModel(
    String modelId,
    String newName,
  ) => _withProjectorLock(() async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.emptyModelName,
      );
    }
    _validateModelName(trimmed);

    final allModels = await _listModels();
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

    final oldFileName = descriptor.storedFilePath
        .split(Platform.pathSeparator)
        .last;
    final newStoredFilePath = _joinPath(newDir.path, oldFileName);
    String relocatedPath(String path) =>
        '${newDir.path}${path.substring(oldDir.path.length)}';

    final updated = descriptor.copyWith(
      modelName: trimmed,
      storedDirectoryPath: newDir.path,
      storedFilePath: newStoredFilePath,
      mmprojFilePath: descriptor.mmprojFilePath == null
          ? null
          : relocatedPath(descriptor.mmprojFilePath!),
      mmprojFiles: descriptor.mmprojFiles.map(
        (remotePath, localPath) =>
            MapEntry(remotePath, relocatedPath(localPath)),
      ),
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
  });

  /// Registers an already-downloaded GGUF file by *moving* it into the models
  /// directory. Import copies, which would mean writing a second multi-GB copy
  /// of a file the app just wrote itself; downloads land in private storage on
  /// the same volume, so a rename is both correct and free.
  Future<ModelDescriptor> adoptDownloadedModel({
    required String modelName,
    required File modelFile,
    File? mmprojFile,
    String? mmprojRemotePath,
    String? sourceValue,
    String? repoId,
    String? revision,
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
        mmprojFiles: <String, String>{
          if (storedMmprojPath != null)
            mmprojRemotePath ?? _fileName(storedMmprojPath): storedMmprojPath,
        },
        sourceValue: sourceValue,
        repoId: repoId,
        revision: revision,
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

  /// Adds and selects a downloaded projector without deleting other versions.
  /// An explicit vision-off preference is preserved if changed during download.
  Future<ModelDescriptor> adoptDownloadedMmproj({
    required String modelId,
    required File mmprojFile,
    String? remotePath,
  }) => _withProjectorLock(() async {
    final box = await _box();
    final descriptor = box.get(modelId);
    if (descriptor == null) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
    }

    if (!await mmprojFile.exists()) {
      throw const ModelOperationException(
        ModelOperationErrorCode.selectedMmprojFileMissing,
      );
    }

    final mmprojName = _fileName(mmprojFile.path);
    if (!_isMmprojFileName(mmprojName)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.unsupportedMmprojFile,
      );
    }

    final key = remotePath ?? mmprojName;
    final segments = key.split(RegExp(r'[\\/]'));
    if (segments.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          RegExp(r'[:\x00-\x1F]').hasMatch(part),
    )) {
      throw const ModelOperationException(
        ModelOperationErrorCode.unsupportedMmprojFile,
      );
    }
    final files = Map<String, String>.from(descriptor.availableMmprojs);
    final mmprojDestPath =
        files[key] ??
        _joinPath(
          _joinPath(descriptor.storedDirectoryPath, 'projectors'),
          segments.join(Platform.pathSeparator),
        );
    if (_sameFilePath(mmprojDestPath, descriptor.storedFilePath)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.mmprojSameAsModelFile,
      );
    }

    final destinationFile = File(mmprojDestPath);
    await destinationFile.parent.create(recursive: true);
    final stored = _sameFilePath(mmprojFile.path, mmprojDestPath)
        ? mmprojFile
        : await _moveInto(
            mmprojFile,
            destinationFile.parent.path,
            _fileName(mmprojDestPath),
          );
    files[key] = stored.path;
    final updated = descriptor.copyWith(
      mmprojFilePath: stored.path,
      mmprojFiles: files,
    );
    await box.put(descriptor.id, updated);
    return updated;
  });

  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async {
    ModelDescriptor? excluded;
    if (excludingModelId != null) {
      for (final model in await listModels()) {
        if (model.id == excludingModelId) {
          excluded = model;
          break;
        }
      }
    }
    final directory = await _storagePaths.getModelDirectory(modelName);
    if (await directory.exists() &&
        !_sameDirectoryPath(directory.path, excluded?.storedDirectoryPath)) {
      return true;
    }
    final parent = directory.parent;
    if (!await parent.exists()) {
      return false;
    }
    final normalized = _normalizeModelKey(modelName.trim());
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is Directory &&
          !_sameDirectoryPath(entity.path, excluded?.storedDirectoryPath) &&
          _normalizeModelKey(_fileName(entity.path)) == normalized) {
        return true;
      }
    }
    return false;
  }

  /// Rename first; falls back to copy+delete when the source sits on another
  /// volume (rename fails with EXDEV there).
  Future<File> _moveInto(
    File source,
    String directoryPath,
    String fileName,
  ) async {
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

  static String modelNameFromFileName(String sourceValue) {
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

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  bool _sameDirectoryPath(String path, String? other) =>
      other != null && _normalizeFilePath(path) == _normalizeFilePath(other);

  // Model names become directory names under models/; anything that could
  // escape that directory or is invalid as a single path segment is rejected.
  static final RegExp _invalidModelNameChars = RegExp(r'[\\/\x00-\x1F]');

  void _validateModelName(String modelName) {
    if (modelName == '.' ||
        modelName == '..' ||
        _invalidModelNameChars.hasMatch(modelName)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
  }

  bool _isGgufFileName(String fileName) => isGgufFileName(fileName);

  bool _isMmprojFileName(String fileName) => isMmprojFileName(fileName);

  bool _sameFilePath(String left, String right) {
    final normalizedLeft = _normalizeFilePath(left);
    final normalizedRight = _normalizeFilePath(right);
    return normalizedLeft == normalizedRight;
  }

  String _normalizeFilePath(String path) {
    final normalized = path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
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
