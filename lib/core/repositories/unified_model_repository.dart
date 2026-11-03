import 'dart:convert';

import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/model_selection_cleanup.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/utils/new_id.dart';

/// The shared SQL model catalog. File operations remain with their owning store.
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
       database =
           database ?? localModelRepository?.database ?? AppDatabase.current;

  final LocalModelRepository _localModelRepository;
  final MnnEngine _mnnEngine;
  final AppLogger _logger;
  final AppDatabase? database;

  static const mnnInventoryMarker = 'mnnSqlInventoryComplete';

  /// Startup admission for old private MNN models, independent of Hive import.
  Future<void> registerLegacyMnnInventory({
    Future<List<MnnModelInfo>> Function()? readInventory,
  }) async {
    final db = database ?? await AppDatabase.shared();
    if (await db.metadata(mnnInventoryMarker) == '1') return;
    final inventory = await (readInventory ?? _mnnEngine.listImportedModels)();
    await db.transaction(() async {
      for (final model in inventory) {
        final existing = await db.query(
          "SELECT state,storage_owner FROM model_assets WHERE engine='mnn' AND path=?",
          [model.modelDirPath],
        );
        if (existing.isEmpty ||
            (existing.single.read<String>('state') == 'ready' &&
                existing.single.read<String>('storage_owner') ==
                    'mnn_engine')) {
          await registerImportedMnnModel(model);
        }
      }
      await db.setMetadata(mnnInventoryMarker, '1');
    });
  }

  Future<List<ModelAsset>> listAssets() async {
    final db = database ?? await AppDatabase.shared();
    return (await db.query(
      'SELECT * FROM model_assets ORDER BY name,id',
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
      'VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET runtime_id=excluded.runtime_id,storage_owner=excluded.storage_owner,path=excluded.path,'
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

  Future<List<LibraryModel>> listModels() async {
    final db = database ?? await AppDatabase.shared();
    final models = (await db.query(
      "SELECT * FROM model_assets WHERE kind='llm' AND state='ready'",
    )).map((row) => _fromAsset(ModelAsset.fromRow(row))).toList();
    models.sort((a, b) {
      final time = b.importedAt.compareTo(a.importedAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
    return models;
  }

  Future<List<LibraryModel>> listModelsFor(InferenceEngine engine) async =>
      (await listModels()).where((model) => model.engine == engine).toList();

  Future<ModelAsset> _requireModel(String id) async {
    final current = await asset(id);
    if (current == null || current.kind != AssetKind.llm || !current.isReady) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNotFound,
      );
    }
    return current;
  }

  ModelDescriptor _gguf(ModelAsset a) => ModelDescriptor.fromJson(
    Map<String, dynamic>.from(a.manifest['gguf'] as Map),
  );

  Future<void> deleteModel(LibraryModel model) async {
    final current = await _requireModel(model.id);
    if (current.engine == InferenceEngine.llamaCpp.storageValue) {
      await _localModelRepository.deleteModel(_gguf(current).id);
      return;
    }
    if (current.storageOwner != 'external') {
      await _mnnEngine.deleteImportedModel(current.runtimeId);
    }
    final db = database ?? await AppDatabase.shared();
    await db.transaction(() async {
      await db.execute('DELETE FROM model_assets WHERE id=?', [current.id]);
      await clearLocalChatTargetsForAsset(db, current.id);
    });
    if (current.storageOwner == 'external') {
      await _clearExternalMnnCache(current.runtimeId);
    }
  }

  Future<LibraryModel> renameModel(LibraryModel model, String newName) async {
    final current = await _requireModel(model.id);
    final name = newName.trim();
    validateName(name);
    await _ensureUniqueName(name, excludingLibraryId: current.id);
    if (name == current.name) return _fromAsset(current);
    if (current.engine == InferenceEngine.llamaCpp.storageValue) {
      await _localModelRepository.renameModel(_gguf(current).id, name);
      return _fromAsset((await asset(current.id))!);
    }
    if (current.storageOwner == 'external') {
      final db = database ?? await AppDatabase.shared();
      await db.execute(
        'UPDATE model_assets SET name=?,runtime_id=? WHERE id=?',
        [name, name, current.id],
      );
      await _clearExternalMnnCache(current.runtimeId);
      return _fromAsset((await asset(current.id))!);
    }
    final renamed = await _mnnEngine.renameImportedModel(
      current.runtimeId,
      name,
    );
    try {
      return await registerImportedMnnModel(renamed, assetId: current.id);
    } catch (_) {
      try {
        await _mnnEngine.renameImportedModel(
          renamed.modelId,
          current.runtimeId,
        );
      } catch (error, stackTrace) {
        _logger.warning(
          '回滚 MNN 模型改名失败',
          channel: LogChannel.model,
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<LibraryModel> registerImportedMnnModel(
    MnnModelInfo info, {
    String? assetId,
  }) => _saveMnnModel(
    info,
    path: info.modelDirPath,
    storageOwner: 'mnn_engine',
    assetId: assetId,
  );

  Future<LibraryModel> _saveMnnModel(
    MnnModelInfo info, {
    required String path,
    required String storageOwner,
    String? assetId,
    String? name,
  }) async {
    final db = database ?? await AppDatabase.shared();
    return db.transaction(() async {
      final rows = await db.query(
        assetId == null
            ? "SELECT * FROM model_assets WHERE engine='mnn' AND path=?"
            : 'SELECT * FROM model_assets WHERE id=?',
        [assetId ?? path],
      );
      final previous = rows.isEmpty ? null : ModelAsset.fromRow(rows.single);
      if ((assetId != null && previous == null) ||
          (previous != null &&
              (previous.kind != AssetKind.llm ||
                  previous.engine != 'mnn' ||
                  previous.storageOwner != storageOwner))) {
        throw StateError('Conflicting MNN asset identity');
      }
      final a = ModelAsset(
        id: previous?.id ?? newId(),
        kind: AssetKind.llm,
        engine: 'mnn',
        runtimeId: name ?? info.modelId,
        storageOwner: storageOwner,
        path: path,
        name: name ?? info.modelKey,
        revision: previous?.revision ?? 'local',
        manifest: {
          ...?previous?.manifest,
          'sizeBytes': info.sizeBytes,
          'importedAt': previous?.manifest['importedAt'] ?? info.importedAt,
          'images': info.supportsVision,
          'tools': info.supportsToolCalling,
          'warnings': info.validationWarnings,
        },
      );
      await saveAsset(a);
      return _fromAsset(a);
    });
  }

  Future<LibraryModel> addExternalMnnModel(String path, String name) async {
    final db = database ?? await AppDatabase.shared();
    final rows = await db.query(
      "SELECT * FROM model_assets WHERE engine='mnn' AND path=? AND state='ready' AND storage_owner='external'",
      [path],
    );
    if (rows.isNotEmpty) return _fromAsset(ModelAsset.fromRow(rows.single));
    final info = await _mnnEngine.getModelInfoFromPath(path);
    return _saveMnnModel(
      info,
      path: path,
      storageOwner: 'external',
      name: name,
    );
  }

  Future<LibraryModel?> externalMnnModel(String runtimeId) async {
    final db = database ?? await AppDatabase.shared();
    final rows = await db.query(
      "SELECT * FROM model_assets WHERE engine='mnn' AND storage_owner='external' AND state='ready' AND runtime_id=?",
      [runtimeId],
    );
    return rows.isEmpty ? null : _fromAsset(ModelAsset.fromRow(rows.single));
  }

  LibraryModel _fromAsset(ModelAsset a) {
    final engine = InferenceEngine.fromStorageValue(a.engine);
    final gguf = engine == InferenceEngine.llamaCpp ? _gguf(a) : null;
    return LibraryModel(
      id: a.id,
      runtimeId: a.runtimeId,
      engine: engine,
      name: a.name,
      sizeBytes: gguf?.sizeBytes ?? (a.manifest['sizeBytes'] as int? ?? 0),
      importedAt:
          gguf?.importedAt ??
          DateTime.fromMillisecondsSinceEpoch(
            a.manifest['importedAt'] as int? ?? 0,
          ),
      storagePath: a.path,
      supportsVision: a.manifest['images'] == true,
      supportsToolCalling: a.manifest['tools'] == true,
      hasMmproj: gguf?.mmprojFilePath != null,
      sourceValue: gguf?.sourceValue,
      repoId: gguf?.repoId,
      revision: gguf?.revision,
      warnings: List<String>.from(a.manifest['warnings'] as List? ?? const []),
      isExternal: a.storageOwner == 'external',
    );
  }

  Future<void> ensureNameAvailable(
    String name, {
    String? excludingLibraryId,
  }) async {
    validateName(name.trim());
    await _ensureUniqueName(
      name.trim(),
      excludingLibraryId: excludingLibraryId,
    );
  }

  Future<bool> isStorageNameOccupied(
    String name, {
    String? excludingLibraryId,
  }) async {
    validateName(name.trim());
    final excluded = excludingLibraryId == null
        ? null
        : await asset(excludingLibraryId);
    final ggufId = excluded?.engine == InferenceEngine.llamaCpp.storageValue
        ? _gguf(excluded!).id
        : null;
    // Explicit name allocation still protects unregistered private GGUF directories.
    if (await _localModelRepository.isModelDirectoryOccupied(
      name.trim(),
      excludingModelId: ggufId,
    )) {
      return true;
    }
    final normalized = name.trim().toLowerCase();
    return (await listModels()).any(
      (model) =>
          model.id != excludingLibraryId &&
          model.name.toLowerCase() == normalized,
    );
  }

  Future<void> _ensureUniqueName(
    String name, {
    String? excludingLibraryId,
  }) async {
    if ((await listModels()).any(
      (model) =>
          model.id != excludingLibraryId &&
          model.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const ModelOperationException(
        ModelOperationErrorCode.modelNameExists,
      );
    }
  }

  Future<void> _clearExternalMnnCache(String modelId) async {
    try {
      await _mnnEngine.clearMmapCache(modelId: modelId);
    } catch (error, stackTrace) {
      _logger.warning(
        '清理外部 MNN 缓存失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void validateName(String name) {
    if (name.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.emptyModelName,
      );
    }
    if (name == '.' ||
        name == '..' ||
        RegExp(r'[\\/\x00-\x1F]').hasMatch(name)) {
      throw const ModelOperationException(
        ModelOperationErrorCode.invalidModelName,
      );
    }
  }
}
