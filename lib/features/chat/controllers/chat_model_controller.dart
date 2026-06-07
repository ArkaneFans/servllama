import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class ChatModelController extends ChangeNotifier {
  ChatModelController({required LlamaChatApiClient apiClient})
    : _apiClient = apiClient;

  final LlamaChatApiClient _apiClient;

  List<ChatModelOption> _models = <ChatModelOption>[];
  bool _isRefreshingModels = false;
  bool _isServerRunning = false;
  String _baseUrl = 'http://127.0.0.1:8080';
  String? _currentModelId;
  String? _loadingModelId;

  List<ChatModelOption> get models =>
      List<ChatModelOption>.unmodifiable(_models);
  bool get isRefreshingModels => _isRefreshingModels;
  bool get isServerRunning => _isServerRunning;
  String? get currentModelId => _currentModelId;
  String? get loadingModelId => _loadingModelId;

  ChatModelOption? get currentModel => findModel(_currentModelId);

  List<ChatModelOption> get loadedModels =>
      _models.where((model) => model.isLoaded).toList(growable: false);

  List<ChatModelOption> get availableModels =>
      _models.where((model) => !model.isLoaded).toList(growable: false);

  String get currentModelDisplayName {
    final model = currentModel;
    if (model != null) {
      return model.displayName;
    }
    if (_currentModelId != null && _currentModelId!.trim().isNotEmpty) {
      return _currentModelId!;
    }
    return '未选择模型';
  }

  String get modelSelectorLabel {
    final model = currentModel;
    if (model != null && model.isLoaded) {
      return model.displayName;
    }
    return '选择模型';
  }

  String get currentModelStatusLabel {
    final model = currentModel;
    if (model == null) {
      return _currentModelId == null ? '请选择模型' : '模型暂不可用';
    }
    return _modelStatusLabel(model.status);
  }

  bool updateServerState({
    required String baseUrl,
    required bool isServerRunning,
  }) {
    var changed = false;

    if (_baseUrl != baseUrl) {
      _baseUrl = baseUrl;
      _apiClient.updateBaseUrl(baseUrl);
    }

    final stopped = _isServerRunning && !isServerRunning;
    if (_isServerRunning != isServerRunning) {
      _isServerRunning = isServerRunning;
      changed = true;
    }

    if (stopped) {
      _models = <ChatModelOption>[];
      _loadingModelId = null;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
    return stopped;
  }

  void updateChatTimeout(Duration timeout) {
    _apiClient.updateReceiveTimeout(timeout);
  }

  Future<void> refreshModels() async {
    if (_isRefreshingModels || !_isServerRunning) {
      return;
    }

    _isRefreshingModels = true;
    notifyListeners();

    try {
      _models = await _apiClient.fetchModels();
      final selectedModel = currentModel;
      if (_currentModelId != null &&
          (selectedModel == null || !selectedModel.isLoaded)) {
        _currentModelId = null;
      }
    } catch (_) {
    } finally {
      _isRefreshingModels = false;
      notifyListeners();
    }
  }

  void selectLoadedModel(String modelId) {
    final model = findModel(modelId);
    if (model == null || !model.isLoaded) {
      return;
    }
    _currentModelId = modelId;
    notifyListeners();
  }

  Future<void> loadAndSelectModel(String modelId) async {
    final model = findModel(modelId);
    if (model == null) {
      return;
    }

    if (model.isLoaded) {
      selectLoadedModel(modelId);
      return;
    }

    _loadingModelId = modelId;
    notifyListeners();

    try {
      await _apiClient.loadModel(modelId);
      _models = await _apiClient.fetchModels();
      _currentModelId = modelId;
    } catch (_) {
      try {
        _models = await _apiClient.fetchModels();
      } catch (_) {}
    } finally {
      _loadingModelId = null;
      notifyListeners();
    }
  }

  Future<void> loadCurrentModel() async {
    final modelId = _currentModelId;
    if (modelId == null) {
      return;
    }
    await loadAndSelectModel(modelId);
  }

  Future<void> unloadModel(String modelId) async {
    final model = findModel(modelId);
    if (model == null || !model.isLoaded) {
      return;
    }

    _loadingModelId = modelId;
    notifyListeners();

    try {
      await _apiClient.unloadModel(modelId);
      _models = await _apiClient.fetchModels();
      if (_currentModelId == modelId) {
        _currentModelId = null;
      } else {
        final selectedModel = currentModel;
        if (_currentModelId != null &&
            (selectedModel == null || !selectedModel.isLoaded)) {
          _currentModelId = null;
        }
      }
    } catch (_) {
      try {
        _models = await _apiClient.fetchModels();
      } catch (_) {}
    } finally {
      _loadingModelId = null;
      notifyListeners();
    }
  }

  ChatModelOption? findModel(String? modelId) {
    if (modelId == null) {
      return null;
    }
    for (final model in _models) {
      if (model.id == modelId) {
        return model;
      }
    }
    return null;
  }

  String get inputHintText {
    if (!_isServerRunning) {
      return '请先启动服务器';
    }
    if (_loadingModelId != null) {
      return '模型加载中...';
    }
    if (_currentModelId == null) {
      return '请先选择模型';
    }
    if (currentModel?.isLoaded != true) {
      return '当前模型未加载';
    }
    return '输入消息';
  }

  String _modelStatusLabel(ChatModelStatus status) {
    switch (status) {
      case ChatModelStatus.loaded:
        return '已加载';
      case ChatModelStatus.loading:
        return '加载中';
      case ChatModelStatus.unloaded:
        return '可加载';
      case ChatModelStatus.failed:
        return '加载失败';
    }
  }
}
