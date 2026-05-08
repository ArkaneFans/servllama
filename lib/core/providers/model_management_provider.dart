import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
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
      return '模型导入成功: ${descriptor.modelName}';
    } catch (error, stackTrace) {
      _logger.error(
        '导入模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return '导入模型失败: ${_describeError(error)}';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<String> deleteModel(String modelId) async {
    if (_deletingModelId != null) {
      return '正在删除模型，请稍后。';
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
      return '模型已删除: ${model.modelName}';
    } catch (error, stackTrace) {
      _logger.error(
        '删除模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return '删除模型失败: ${_describeError(error)}';
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
      return 'mmproj 导入成功: ${updated.modelName}';
    } catch (error, stackTrace) {
      _logger.error(
        '导入 mmproj 失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return 'mmproj 导入失败: ${_describeError(error)}';
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
      return 'mmproj 已移除: ${updated.modelName}';
    } catch (error, stackTrace) {
      _logger.error(
        '移除 mmproj 失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return 'mmproj 移除失败: ${_describeError(error)}';
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
      return '模型已重命名为: ${updated.modelName}';
    } catch (error, stackTrace) {
      _logger.error(
        '重命名模型失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
      return '重命名失败: ${_describeError(error)}';
    } finally {
      _isRenaming = false;
      _renamingModelId = null;
      notifyListeners();
    }
  }

  String _describeError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return '$error';
  }
}
