import 'package:mnn_engine/mnn_engine.dart';
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
    final models = <LibraryModel>[
      ...await _listGgufModels(),
      ...await _listMnnModels(),
    ];
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
          .map(
            (model) => LibraryModel(
              id: libraryIdFor(InferenceEngine.mnn, model.modelId),
              runtimeId: model.modelId,
              engine: InferenceEngine.mnn,
              name: model.displayName,
              sizeBytes: model.sizeBytes,
              importedAt: DateTime.fromMillisecondsSinceEpoch(model.importedAt),
              storagePath: model.modelDirPath,
              supportsVision: model.supportsVision,
              supportsToolCalling: model.supportsToolCalling,
              warnings: model.validationWarnings,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      // The plugin is unavailable on non-Android hosts and in widget tests;
      // an empty MNN section is the correct degraded view, not a failure.
      _logger.warning('读取 MNN 模型列表失败: $error', channel: LogChannel.model);
      return const <LibraryModel>[];
    }
  }
}
