import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';
import 'package:servllama/core/services/model_name_coordinator.dart';

class ModelManagementProvider extends ChangeNotifier {
  ModelManagementProvider({
    LocalModelRepository? repository,
    UnifiedModelRepository? unifiedRepository,
    GgufFilePicker? filePicker,
    MnnEngine? mnnEngine,
    ModelNameCoordinator? nameCoordinator,
    AppLogger? logger,
    Future<void> Function({
      required InferenceEngine engine,
      required String oldModelId,
      required String newModelId,
    })?
    onModelRenamed,
  }) : _repository = repository ?? LocalModelRepository(),
       _unifiedRepository =
           unifiedRepository ??
           UnifiedModelRepository(localModelRepository: repository),
       _filePicker = filePicker ?? GgufFilePicker(),
       _mnnEngine = mnnEngine ?? MnnEngine.instance,
       _logger = logger ?? AppLogger.instance,
       _onModelRenamed = onModelRenamed {
    _nameCoordinator =
        nameCoordinator ??
        ModelNameCoordinator(unifiedRepository: _unifiedRepository);
  }

  final LocalModelRepository _repository;
  final UnifiedModelRepository _unifiedRepository;
  final GgufFilePicker _filePicker;
  final MnnEngine _mnnEngine;
  final AppLogger _logger;
  late final ModelNameCoordinator _nameCoordinator;
  final Future<void> Function({
    required InferenceEngine engine,
    required String oldModelId,
    required String newModelId,
  })?
  _onModelRenamed;

  List<ModelDescriptor> _models = <ModelDescriptor>[];
  List<LibraryModel> _libraryModels = <LibraryModel>[];
  bool _disposed = false;
  bool _isLoading = false;
  bool _isImporting = false;
  bool _isImportingMmproj = false;
  bool _isRenaming = false;
  Future<void>? _modelRefreshInFlight;
  String? _deletingModelId;
  String? _importingMmprojModelId;
  String? _renamingModelId;

  List<ModelDescriptor> get models =>
      List<ModelDescriptor>.unmodifiable(_models);

  /// GGUF and MNN models in one list, told apart by [LibraryModel.engine]
  /// (design decision D2).
  List<LibraryModel> get libraryModels =>
      List<LibraryModel>.unmodifiable(_libraryModels);

  List<LibraryModel> libraryModelsFor(InferenceEngine engine) => _libraryModels
      .where((model) => model.engine == engine)
      .toList(growable: false);

  int countFor(InferenceEngine engine) =>
      _libraryModels.where((model) => model.engine == engine).length;

  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  bool get isImportingMmproj => _isImportingMmproj;
  bool get isRenaming => _isRenaming;
  String? get deletingModelId => _deletingModelId;
  String? get importingMmprojModelId => _importingMmprojModelId;
  String? get renamingModelId => _renamingModelId;
  bool get isEmpty => _models.isEmpty;
  ModelNameCoordinator get nameCoordinator => _nameCoordinator;

  AppL10nService get _l10nService => AppL10nService.instance;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Long-running operations (multi-GB model imports) can outlive the page;
  // notifying after dispose trips ChangeNotifier's debug assertion.
  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _refreshModelLists();
    } catch (error, stackTrace) {
      _models = <ModelDescriptor>[];
      _libraryModels = <LibraryModel>[];
      _logger.error(
        '加载模型列表失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the installed-model snapshot without replacing the page with a
  /// loading state. Downloads use this before their in-progress card leaves
  /// the model library, so the installed card appears in the same transition.
  Future<void> refresh() async {
    try {
      await _refreshModelLists();
      notifyListeners();
    } catch (error, stackTrace) {
      _logger.error(
        '刷新模型列表失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Pulls an MNN model directory in through the plugin's SAF picker. GGUF
  /// files come in via [importModel]; downloads bypass both.
  Future<String?> importMnnModelDirectory() async {
    if (_isImporting) {
      return null;
    }

    _isImporting = true;
    notifyListeners();

    const reservationId = 'import:mnn';
    try {
      final result = await _mnnEngine.importModelDirectoryWithResult(
        replaceExisting: false,
        autoRename: true,
        unavailableNames: await _nameCoordinator.unavailableNames(),
      );
      var model = result.model;
      AllocatedModelName allocation;
      try {
        allocation = await _nameCoordinator.reserveCommitted(
          ownerId: reservationId,
          requestedName: result.requestedModelName,
          committedName: model.modelKey,
          excludingLibraryId: UnifiedModelRepository.libraryIdFor(
            InferenceEngine.mnn,
            model.modelId,
          ),
        );
        if (allocation.name != model.modelKey) {
          model = await _mnnEngine.renameImportedModel(
            model.modelId,
            allocation.name,
          );
        }
      } catch (error) {
        try {
          await _mnnEngine.deleteImportedModel(model.modelId);
        } catch (cleanupError, stackTrace) {
          _logger.warning(
            '回滚重名 MNN 模型失败',
            channel: LogChannel.model,
            error: cleanupError,
            stackTrace: stackTrace,
          );
        }
        rethrow;
      }
      await _refreshModelLists();
      _logger.info('MNN 模型导入成功: ${model.modelKey}', channel: LogChannel.model);
      return allocation.wasRenamed
          ? _l10nService.current.modelManagementImportAutoRenamed(
              allocation.requestedName,
              allocation.name,
            )
          : _l10nService.current.modelManagementImportSuccess(model.modelKey);
    } catch (error, stackTrace) {
      _logger.error(
        '导入 MNN 模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementImportFailed(
        _describeError(error),
      );
    } finally {
      await _nameCoordinator.release(reservationId);
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Deletes a model from whichever store owns it.
  Future<String> deleteLibraryModel(LibraryModel model) async {
    if (_deletingModelId != null) {
      return _l10nService.current.modelManagementDeleteBusy;
    }

    _deletingModelId = model.id;
    notifyListeners();

    try {
      await _unifiedRepository.deleteModel(model);
      await _refreshModelLists();
      _logger.info('模型删除成功: ${model.name}', channel: LogChannel.model);
      return _l10nService.current.modelManagementDeleteSuccess(model.name);
    } catch (error, stackTrace) {
      _logger.error(
        '删除模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementDeleteFailed(
        _describeError(error),
      );
    } finally {
      _deletingModelId = null;
      notifyListeners();
    }
  }

  Future<String?> importModel() async {
    if (_isImporting) {
      return null;
    }

    _isImporting = true;
    notifyListeners();

    const reservationId = 'import:gguf';
    try {
      final pickedFile = await _filePicker.pickSingle();
      if (pickedFile == null) {
        _logger.info('用户取消导入模型', channel: LogChannel.model);
        return null;
      }

      final requestedName = LocalModelRepository.modelNameFromFileName(
        pickedFile.fileName,
      );
      final allocation = await _nameCoordinator.reserveAvailable(
        ownerId: reservationId,
        requestedName: requestedName,
      );
      final descriptor = await _repository.importModel(
        pickedFile,
        modelName: allocation.name,
      );
      await _refreshModelLists();
      _logger.info(
        '模型导入成功: ${descriptor.modelName}',
        channel: LogChannel.model,
      );
      return allocation.wasRenamed
          ? _l10nService.current.modelManagementImportAutoRenamed(
              allocation.requestedName,
              allocation.name,
            )
          : _l10nService.current.modelManagementImportSuccess(
              descriptor.modelName,
            );
    } catch (error, stackTrace) {
      _logger.error(
        '导入模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementImportFailed(
        _describeError(error),
      );
    } finally {
      await _nameCoordinator.release(reservationId);
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<String> deleteModel(String modelId) async {
    if (_deletingModelId != null) {
      return _l10nService.current.modelManagementDeleteBusy;
    }

    _deletingModelId = modelId;
    notifyListeners();

    try {
      final model = _models.firstWhere(
        (descriptor) => descriptor.id == modelId,
      );
      await _repository.deleteModel(modelId);
      await _refreshModelLists();
      _logger.info('模型删除成功: ${model.modelName}', channel: LogChannel.model);
      return _l10nService.current.modelManagementDeleteSuccess(model.modelName);
    } catch (error, stackTrace) {
      _logger.error(
        '删除模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementDeleteFailed(
        _describeError(error),
      );
    } finally {
      _deletingModelId = null;
      notifyListeners();
    }
  }

  Future<String?> importMmproj(String modelId) async {
    if (_isImportingMmproj) {
      return null;
    }

    var didStartImport = false;

    try {
      final pickedFile = await _filePicker.pickSingleMmproj();
      if (pickedFile == null) {
        _logger.info('用户取消导入 mmproj', channel: LogChannel.model);
        return null;
      }

      _isImportingMmproj = true;
      _importingMmprojModelId = modelId;
      didStartImport = true;
      notifyListeners();

      final updated = await _repository.importMmproj(modelId, pickedFile);
      await _refreshModelLists();
      _logger.info(
        'mmproj 导入成功: ${updated.modelName}',
        channel: LogChannel.model,
      );
      return _l10nService.current.modelManagementMmprojImportSuccess(
        updated.modelName,
      );
    } catch (error, stackTrace) {
      _logger.error(
        '导入 mmproj 失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementMmprojImportFailed(
        _describeError(error),
      );
    } finally {
      if (didStartImport) {
        _isImportingMmproj = false;
        _importingMmprojModelId = null;
        notifyListeners();
      }
    }
  }

  Future<String?> removeMmproj(String modelId) async {
    try {
      final updated = await _repository.removeMmproj(modelId);
      await _refreshModelLists();
      _logger.info(
        'mmproj 已移除: ${updated.modelName}',
        channel: LogChannel.model,
      );
      return _l10nService.current.modelManagementMmprojRemoveSuccess(
        updated.modelName,
      );
    } catch (error, stackTrace) {
      _logger.error(
        '移除 mmproj 失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementMmprojRemoveFailed(
        _describeError(error),
      );
    } finally {
      notifyListeners();
    }
  }

  Future<String?> renameModel(String modelId, String newName) async {
    LibraryModel? libraryModel;
    for (final model in _libraryModels) {
      if (model.engine == InferenceEngine.llamaCpp &&
          UnifiedModelRepository.rawIdOf(model.id) == modelId) {
        libraryModel = model;
        break;
      }
    }
    if (libraryModel == null) {
      return _l10nService.current.modelManagementRenameFailed(
        _l10nService.current.modelErrorModelNotFound,
      );
    }
    return renameLibraryModel(libraryModel, newName);
  }

  Future<void> ensureNameAvailable(String modelName) =>
      _nameCoordinator.ensureAvailable(modelName);

  Future<String?> renameLibraryModel(LibraryModel model, String newName) async {
    if (_isRenaming) {
      return null;
    }

    _isRenaming = true;
    _renamingModelId = model.engine == InferenceEngine.llamaCpp
        ? UnifiedModelRepository.rawIdOf(model.id)
        : model.id;
    notifyListeners();

    try {
      final reservationId = 'rename:${model.id}';
      await _nameCoordinator.reserveExact(
        ownerId: reservationId,
        name: newName,
        excludingLibraryId: model.id,
      );
      LibraryModel updated;
      try {
        updated = await _unifiedRepository.renameModel(model, newName);
      } finally {
        await _nameCoordinator.release(reservationId);
      }
      for (var index = 0; index < _libraryModels.length; index += 1) {
        if (_libraryModels[index].id == model.id) {
          _libraryModels[index] = updated;
          break;
        }
      }
      final onModelRenamed = _onModelRenamed;
      if (onModelRenamed != null) {
        try {
          await onModelRenamed(
            engine: model.engine,
            oldModelId: model.runtimeId,
            newModelId: updated.runtimeId,
          );
        } catch (error, stackTrace) {
          _logger.warning(
            '同步重命名后的默认模型失败',
            channel: LogChannel.model,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      await _refreshModelLists();
      _logger.info('模型重命名成功: ${updated.name}', channel: LogChannel.model);
      return _l10nService.current.modelManagementRenameSuccess(updated.name);
    } catch (error, stackTrace) {
      _logger.error(
        '重命名模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return _l10nService.current.modelManagementRenameFailed(
        _describeError(error),
      );
    } finally {
      _isRenaming = false;
      _renamingModelId = null;
      notifyListeners();
    }
  }

  Future<void> _refreshModelLists() async {
    while (true) {
      final activeRefresh = _modelRefreshInFlight;
      if (activeRefresh == null) {
        break;
      }
      try {
        await activeRefresh;
      } catch (_) {
        // The caller that started it reports the failure. A queued refresh
        // still gets its own attempt with the latest on-disk state.
      }
    }

    final operation = _readModelLists();
    _modelRefreshInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_modelRefreshInFlight, operation)) {
        _modelRefreshInFlight = null;
      }
    }
  }

  Future<void> _readModelLists() async {
    final models = await _repository.listModels();
    final libraryModels = await _unifiedRepository.listModels();
    _models = models;
    _libraryModels = libraryModels;
  }

  String _describeError(Object error) {
    final l10n = _l10nService.current;

    if (error is ModelOperationException) {
      switch (error.code) {
        case ModelOperationErrorCode.unsupportedGgufFile:
          return l10n.modelErrorUnsupportedGgufFile;
        case ModelOperationErrorCode.selectedModelFileMissing:
          return l10n.modelErrorSelectedModelFileMissing;
        case ModelOperationErrorCode.invalidModelName:
          return l10n.modelErrorInvalidModelName;
        case ModelOperationErrorCode.duplicateModelName:
          return l10n.modelErrorDuplicateModelName;
        case ModelOperationErrorCode.modelNotFound:
          return l10n.modelErrorModelNotFound;
        case ModelOperationErrorCode.selectedMmprojFileMissing:
          return l10n.modelErrorSelectedMmprojFileMissing;
        case ModelOperationErrorCode.unsupportedMmprojFile:
          return l10n.modelErrorUnsupportedMmprojFile;
        case ModelOperationErrorCode.mmprojSameAsModelFile:
          return l10n.modelErrorMmprojSameAsModelFile;
        case ModelOperationErrorCode.emptyModelName:
          return l10n.modelErrorEmptyModelName;
        case ModelOperationErrorCode.modelNameExists:
          return l10n.modelErrorModelNameExists;
        case ModelOperationErrorCode.modelDirectoryExists:
          return l10n.modelErrorModelDirectoryExists;
        case ModelOperationErrorCode.modelNotFoundOrDeleted:
          return l10n.modelErrorModelNotFoundOrDeleted;
        case ModelOperationErrorCode.selectedFilePathUnavailable:
          return l10n.modelErrorSelectedFilePathUnavailable;
      }
    }

    if (error is StateError) {
      return error.message.toString();
    }
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return '$error';
  }
}
