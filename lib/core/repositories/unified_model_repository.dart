import 'package:servllama/core/database/model_selection_cleanup.dart';
import 'dart:convert';
import 'dart:io';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';

/// Maintains shared asset identities. GGUF details already live in this database;
/// only MNN needs indexing from the plugin. Plugin directory ownership is unchanged.
class UnifiedModelRepository {
  UnifiedModelRepository({
    LocalModelRepository? localModelRepository,
    MnnEngine? mnnEngine,
    AppLogger? logger,
    AppDatabase? database,
  }) : _localModelRepository =
           localModelRepository ?? LocalModelRepository(database: database),
       _mnnEngine = mnnEngine ?? MnnEngine.instance,
       _logger = logger ?? AppLogger.instance,
       database = database ?? AppDatabase.current;

  static const String _ggufIdPrefix = 'gguf:';
  static const String _mnnIdPrefix = 'mnn:';

  final LocalModelRepository _localModelRepository;
  final MnnEngine _mnnEngine;
  final AppLogger _logger;
  final AppDatabase? database;

  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async {
    final db = database ?? await AppDatabase.shared();
    if (reconcile) {
      for (final m in await listModels()) {
        // LocalModelRepository commits GGUF details and asset metadata together.
        if (m.engine == InferenceEngine.llamaCpp) continue;
        final found = await db.query(
          'SELECT id FROM model_assets WHERE kind=? AND engine=? AND path=?',
          ['llm', m.engine.storageValue, m.storagePath],
        );
        final id = found.isEmpty ? newId() : found.single.read<String>('id');
        await saveAsset(
          ModelAsset(
            id: id,
            kind: AssetKind.llm,
            engine: m.engine.storageValue,
            runtimeId: m.runtimeId,
            storageOwner: m.engine == InferenceEngine.mnn
                ? 'mnn_engine'
                : 'app',
            path: m.storagePath,
            name: m.name,
            revision: m.revision ?? 'local',
            manifest: {
              'libraryId': m.id,
              'images': m.supportsVision,
              'tools': m.supportsToolCalling,
            },
          ),
        );
      }
      final records = await db.query(
        "SELECT id,path FROM model_assets WHERE kind='llm' AND state='ready'",
      );
      for (final row in records) {
        if (await FileSystemEntity.type(row.read<String>('path')) ==
            FileSystemEntityType.notFound) {
          await db.execute(
            "UPDATE model_assets SET state='missing' WHERE id=?",
            [row.read<String>('id')],
          );
        }
      }
    }
    return (await db.query(
      'SELECT * FROM model_assets ORDER BY name',
    )).map(ModelAsset.fromRow).toList();
  }

  Future<ModelAsset?> asset(String id) async {
    final db = database ?? await AppDatabase.shared();
    final rows = await db.query('SELECT * FROM model_assets WHERE id=?', [id]);
    return rows.isEmpty ? null : ModelAsset.fromRow(rows.single);
  }

  Future<void> saveAsset(ModelAsset a) async {
    final db = database ?? await AppDatabase.shared();
    await db.execute(
      'INSERT INTO model_assets(id,kind,engine,runtime_id,storage_owner,path,name,revision,state,manifest) '
      'VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET runtime_id=excluded.runtime_id,path=excluded.path,'
      'name=excluded.name,revision=excluded.revision,state=excluded.state,manifest=excluded.manifest',
      [
        a.id,
        a.kind.name,
        a.engine,
        a.runtimeId,
        a.storageOwner,
        a.path,
        a.name,
        a.revision,
        a.state,
        jsonEncode(a.manifest),
      ],
    );
  }

  Future<void> _renamedAsset(LibraryModel before, LibraryModel after) async {
    if (database == null) return;
    await database!.execute(
      'UPDATE model_assets SET runtime_id=?,path=?,name=? WHERE engine=? AND path=?',
      [
        after.runtimeId,
        after.storagePath,
        after.name,
        before.engine.storageValue,
        before.storagePath,
      ],
    );
  }

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
        return;
      case InferenceEngine.mnn:
        await _mnnEngine.deleteImportedModel(rawIdOf(model.id));
    }
    final db = database ?? await AppDatabase.shared();
    await db.transaction(() async {
      await db.execute(
        "UPDATE model_assets SET state='missing' WHERE engine=? AND path=?",
        [model.engine.storageValue, model.storagePath],
      );
      await clearMissingLocalChatTargets(db);
    });
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
        final result = LibraryModel(
          id: model.id,
          runtimeId: descriptor.modelName,
          engine: model.engine,
          name: descriptor.modelName,
          sizeBytes: descriptor.sizeBytes,
          importedAt: descriptor.importedAt,
          storagePath: descriptor.storedFilePath,
          supportsVision: descriptor.activeMmprojFilePath != null,
          hasMmproj: descriptor.mmprojFilePath != null,
          sourceValue: descriptor.sourceValue,
          repoId: descriptor.repoId,
          revision: descriptor.revision,
        );
        await _renamedAsset(model, result);
        return result;
      case InferenceEngine.mnn:
        final renamed = await _mnnEngine.renameImportedModel(
          model.runtimeId,
          trimmedName,
        );
        final result = _libraryModelFromMnn(renamed);
        await _renamedAsset(model, result);
        return result;
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
            // The single-model server receives this name through `--alias`,
            // so the API id stays equal to the stored model name.
            runtimeId: descriptor.modelName,
            engine: InferenceEngine.llamaCpp,
            name: descriptor.modelName,
            sizeBytes: descriptor.sizeBytes,
            importedAt: descriptor.importedAt,
            storagePath: descriptor.storedFilePath,
            hasMmproj: descriptor.mmprojFilePath != null,
            supportsVision: descriptor.activeMmprojFilePath != null,
            sourceValue: descriptor.sourceValue,
            repoId: descriptor.repoId,
            revision: descriptor.revision,
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
