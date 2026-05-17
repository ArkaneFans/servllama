import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

class ModelManagementProvider extends ChangeNotifier {
  ModelManagementProvider({
    LocalModelRepository? repository,
    GgufFilePicker? filePicker,
    AppLogger? logger,
  }) : _repository = repository ?? LocalModelRepository(),
       _filePicker = filePicker ?? GgufFilePicker(),
       _logger = logger ?? AppLogger.instance;

  final LocalModelRepository _repository;
  final GgufFilePicker _filePicker;
  final AppLogger _logger;

  List<ModelDescriptor> _models = <ModelDescriptor>[];
  bool _isLoading = false;
  bool _isImporting = false;
  bool _isImportingMmproj = false;
  bool _isRenaming = false;
  String? _deletingModelId;
  String? _importingMmprojModelId;
  String? _renamingModelId;

  List<ModelDescriptor> get models =>
      List<ModelDescriptor>.unmodifiable(_models);
  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  bool get isImportingMmproj => _isImportingMmproj;
  bool get isRenaming => _isRenaming;
  String? get deletingModelId => _deletingModelId;
  String? get importingMmprojModelId => _importingMmprojModelId;
  String? get renamingModelId => _renamingModelId;
  bool get isEmpty => _models.isEmpty;

  AppL10nService get _l10nService => AppL10nService.instance;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _models = await _repository.listModels();
    } catch (error, stackTrace) {
      _models = <ModelDescriptor>[];
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

  Future<String?> importModel() async {
    if (_isImporting) {
      return null;
    }

    _isImporting = true;
    notifyListeners();

    try {
      final pickedFile = await _filePicker.pickSingle();
      if (pickedFile == null) {
        _logger.info('用户取消导入模型', channel: LogChannel.model);
        return null;
      }

      final descriptor = await _repository.importModel(pickedFile);
      _models = await _repository.listModels();
      _logger.info(
        '模型导入成功: ${descriptor.modelName}',
        channel: LogChannel.model,
      );
      return _l10nService.current.modelManagementImportSuccess(
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
      _models = await _repository.listModels();
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
      _models = await _repository.listModels();
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
      _models = await _repository.listModels();
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
    if (_isRenaming) {
      return null;
    }

    _isRenaming = true;
    _renamingModelId = modelId;
    notifyListeners();

    try {
      final updated = await _repository.renameModel(modelId, newName);
      _models = await _repository.listModels();
      _logger.info(
        '模型重命名成功: ${updated.modelName}',
        channel: LogChannel.model,
      );
      return _l10nService.current.modelManagementRenameSuccess(
        updated.modelName,
      );
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
