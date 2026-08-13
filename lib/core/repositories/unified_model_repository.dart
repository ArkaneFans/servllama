import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';

/// Reads both model stores and presents them as one list. The two engines
/// keep their own storage (GGUF files under `models/`, MNN directories inside
/// the plugin), so this is a read-side merge rather than a shared store —
/// which avoids a Hive migration and keeps each engine authoritative over its
/// own format.
class UnifiedModelRepository {
  UnifiedModelRepository({
    LocalModelRepository? localModelRepository,
    MnnEngine? mnnEngine,
    AppLogger? logger,
  }) : _localModelRepository = localModelRepository ?? LocalModelRepository(),
       _mnnEngine = mnnEngine ?? MnnEngine.instance,
       _logger = logger ?? AppLogger.instance;

  static const String _ggufIdPrefix = 'gguf:';
  static const String _mnnIdPrefix = 'mnn:';

  final LocalModelRepository _localModelRepository;
  final MnnEngine _mnnEngine;
  final AppLogger _logger;

  static String libraryIdFor(InferenceEngine engine, String rawId) {
    switch (engine) {
      case InferenceEngine.llamaCpp:
        return '$_ggufIdPrefix$rawId';
      case InferenceEngine.mnn:
        return '$_mnnIdPrefix$rawId';
    }
  }

  static String rawIdOf(String libraryId) {
    final separator = libraryId.indexOf(':');
    return separator < 0 ? libraryId : libraryId.substring(separator + 1);
  }

  Future<List<LibraryModel>> listModels() async {
    final results = await Future.wait<List<LibraryModel>>(
      <Future<List<LibraryModel>>>[_listGgufModels(), _listMnnModels()],
    );
    final models = <LibraryModel>[...results[0], ...results[1]];
    models.sort((left, right) => right.importedAt.compareTo(left.importedAt));
    return models;
  }

  Future<List<LibraryModel>> listModelsFor(InferenceEngine engine) async {
    switch (engine) {
      case InferenceEngine.llamaCpp:
        return _listGgufModels();
      case InferenceEngine.mnn:
        return _listMnnModels();
    }
  }

  Future<void> deleteModel(LibraryModel model) async {
    switch (model.engine) {
      case InferenceEngine.llamaCpp:
        await _localModelRepository.deleteModel(rawIdOf(model.id));
      case InferenceEngine.mnn:
        await _mnnEngine.deleteImportedModel(rawIdOf(model.id));
    }
  }

  Future<LibraryModel> renameModel(LibraryModel model, String newName) async {
    final trimmedName = newName.trim();
    validateName(trimmedName);
    await _ensureUniqueName(trimmedName, excludingLibraryId: model.id);

    switch (model.engine) {
      case InferenceEngine.llamaCpp:
        final descriptor = await _localModelRepository.renameModel(
          rawIdOf(model.id),
          trimmedName,
        );
        return LibraryModel(
          id: model.id,
          runtimeId: descriptor.modelName,
          engine: model.engine,
          name: descriptor.modelName,
          sizeBytes: descriptor.sizeBytes,
          importedAt: descriptor.importedAt,
          storagePath: descriptor.storedFilePath,
          supportsVision: descriptor.mmprojFilePath != null,
          hasMmproj: descriptor.mmprojFilePath != null,
        );
      case InferenceEngine.mnn:
        final renamed = await _mnnEngine.renameImportedModel(
          model.runtimeId,
          trimmedName,
        );
        return _libraryModelFromMnn(renamed);
    }
  }

  Future<void> ensureNameAvailable(
    String name, {
    String? excludingLibraryId,
  }) async {
    final trimmedName = name.trim();
    validateName(trimmedName);
    await _ensureUniqueName(
      trimmedName,
      excludingLibraryId: excludingLibraryId,
    );
  }

  Future<bool> isStorageNameOccupied(
    String name, {
    String? excludingLibraryId,
  }) async {
    final trimmedName = name.trim();
    validateName(trimmedName);
    final excludingGgufId =
        excludingLibraryId?.startsWith(_ggufIdPrefix) == true
        ? rawIdOf(excludingLibraryId!)
        : null;
    if (await _localModelRepository.isModelDirectoryOccupied(
      trimmedName,
      excludingModelId: excludingGgufId,
    )) {
      return true;
    }
    final normalized = trimmedName.toLowerCase();
    final mnnModels = await _listMnnModels();
    return mnnModels.any(
      (model) =>
          model.id != excludingLibraryId &&
          model.name.toLowerCase() == normalized,
    );
  }

  Future<List<LibraryModel>> _listGgufModels() async {
    final descriptors = await _localModelRepository.listModels();
    return descriptors
        .map(
          (descriptor) => LibraryModel(
            id: libraryIdFor(InferenceEngine.llamaCpp, descriptor.id),
            // llama-server names each `--models-dir` entry after its
            // subdirectory, which is exactly the stored model name.
            runtimeId: descriptor.modelName,
            engine: InferenceEngine.llamaCpp,
            name: descriptor.modelName,
            sizeBytes: descriptor.sizeBytes,
            importedAt: descriptor.importedAt,
            storagePath: descriptor.storedFilePath,
            hasMmproj: descriptor.mmprojFilePath != null,
            supportsVision: descriptor.mmprojFilePath != null,
          ),
        )
        .toList(growable: false);
  }

  Future<List<LibraryModel>> _listMnnModels() async {
    try {
      final models = await _mnnEngine.listImportedModels();
      return models
          .map((model) => _libraryModelFromMnn(model))
          .toList(growable: false);
    } catch (error) {
      // The plugin is unavailable on non-Android hosts and in widget tests;
      // an empty MNN section is the correct degraded view, not a failure.
      _logger.warning('读取 MNN 模型列表失败: $error', channel: LogChannel.model);
      return const <LibraryModel>[];
    }
  }

  LibraryModel _libraryModelFromMnn(MnnModelInfo model) => LibraryModel(
    id: libraryIdFor(InferenceEngine.mnn, model.modelId),
    runtimeId: model.modelId,
    engine: InferenceEngine.mnn,
    name: model.modelKey,
    sizeBytes: model.sizeBytes,
    importedAt: DateTime.fromMillisecondsSinceEpoch(model.importedAt),
    storagePath: model.modelDirPath,
    supportsVision: model.supportsVision,
    supportsToolCalling: model.supportsToolCalling,
    warnings: model.validationWarnings,
  );

  Future<void> _ensureUniqueName(
    String name, {
    String? excludingLibraryId,
  }) async {
    final normalizedName = name.toLowerCase();
    final models = await listModels();
    final hasDuplicate = models.any(
      (model) =>
          model.id != excludingLibraryId &&
          model.name.toLowerCase() == normalizedName,
    );
    if (hasDuplicate) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNameExists,
      );
    }
  }

  void validateName(String modelName) {
    if (modelName.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.emptyModelName,
      );
    }
    if (modelName == '.' ||
        modelName == '..' ||
        RegExp(r'[\\/\x00-\x1F]').hasMatch(modelName)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
  }
}
