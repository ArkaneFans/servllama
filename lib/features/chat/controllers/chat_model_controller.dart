import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

enum ChatModelOperationErrorKind {
  loadTimeout,
  loadFailed,
  unloadTimeout,
  requestFailed,
}

/// A failed model load/unload, kept as typed state so the page layer can
/// map it to localized text (AGENTS.md forbids display text below the UI).
class ChatModelOperationError {
  const ChatModelOperationError({
    required this.kind,
    required this.modelName,
    this.detail,
  });

  final ChatModelOperationErrorKind kind;
  final String modelName;

  /// Raw server/network message for [ChatModelOperationErrorKind.requestFailed].
  final String? detail;
}

class ChatModelController extends ChangeNotifier {
  ChatModelController({required LlamaChatApiClient apiClient})
    : _apiClient = apiClient;

  final LlamaChatApiClient _apiClient;

  List<ChatModelOption> _models = <ChatModelOption>[];
  bool _isRefreshingModels = false;
  bool _isServerRunning = false;
  String _baseUrl = 'http://127.0.0.1:8080';
  InferenceEngine _engine = InferenceEngine.llamaCpp;
  String? _currentModelId;
  String? _adoptedRuntimeModelId;
  String? _loadingModelId;
  ChatModelOperationError? _lastOperationError;

  List<ChatModelOption> get models =>
      List<ChatModelOption>.unmodifiable(_models);
  bool get isRefreshingModels => _isRefreshingModels;
  bool get isServerRunning => _isServerRunning;
  String? get currentModelId => _currentModelId;
  String? get loadingModelId => _loadingModelId;
  ChatModelOperationError? get lastOperationError => _lastOperationError;

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
    InferenceEngine engine = InferenceEngine.llamaCpp,
    String? activeModelId,
    String? activeModelName,
  }) {
    var changed = false;

    if (_baseUrl != baseUrl) {
      _baseUrl = baseUrl;
      _apiClient.updateBaseUrl(baseUrl);
    }

    final engineChanged = _engine != engine;
    if (engineChanged) {
      _engine = engine;
      _models = <ChatModelOption>[];
      _loadingModelId = null;
      _currentModelId = null;
      _adoptedRuntimeModelId = null;
      changed = true;
    }

    final stopped = _isServerRunning && !isServerRunning;
    if (_isServerRunning != isServerRunning) {
      _isServerRunning = isServerRunning;
      changed = true;
    }

    if (stopped) {
      _models = <ChatModelOption>[];
      _loadingModelId = null;
      _currentModelId = null;
      _adoptedRuntimeModelId = null;
      changed = true;
    }

    // The orchestrator owns which model is resident; chat follows it so
    // completions always target what the engine actually serves (FR-C1).
    // Tracked separately from _currentModelId because a refresh may clear the
    // latter, and re-adopting on every rebuild would loop.
    if (isServerRunning &&
        activeModelId != null &&
        activeModelId != _adoptedRuntimeModelId) {
      _adoptedRuntimeModelId = activeModelId;
      _currentModelId = activeModelId;
      changed = true;
    }

    // The runtime provider owns formal model activation for both engines.
    // Treat its successful result as the authoritative loaded-model snapshot
    // so chat can send immediately without depending on llama.cpp's private
    // `/models` control endpoint (which MNN intentionally does not expose).
    if (isServerRunning && activeModelId != null) {
      final nextModels = <ChatModelOption>[
        ChatModelOption(
          id: activeModelId,
          displayName: activeModelName?.trim().isNotEmpty == true
              ? activeModelName!.trim()
              : activeModelId,
          status: ChatModelStatus.loaded,
        ),
      ];
      if (!_sameModels(_models, nextModels)) {
        _models = nextModels;
        changed = true;
      }
      if (_currentModelId != activeModelId) {
        _currentModelId = activeModelId;
        changed = true;
      }
    } else if (isServerRunning && engine == InferenceEngine.mnn) {
      if (_models.isNotEmpty || _currentModelId != null) {
        _models = <ChatModelOption>[];
        _currentModelId = null;
        changed = true;
      }
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
    if (_isRefreshingModels ||
        !_isServerRunning ||
        _engine == InferenceEngine.mnn) {
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
    _lastOperationError = null;
    notifyListeners();

    try {
      await _apiClient.loadModel(modelId);
      _models = await _apiClient.fetchModels();
      _currentModelId = modelId;
    } catch (error) {
      _lastOperationError = _operationError(error, model.displayName);
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
    _lastOperationError = null;
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
    } catch (error) {
      _lastOperationError = _operationError(error, model.displayName);
      try {
        _models = await _apiClient.fetchModels();
      } catch (_) {}
    } finally {
      _loadingModelId = null;
      notifyListeners();
    }
  }

  void clearOperationError() {
    if (_lastOperationError == null) {
      return;
    }
    _lastOperationError = null;
    notifyListeners();
  }

  ChatModelOperationError _operationError(Object error, String modelName) {
    if (error is LlamaChatApiException) {
      switch (error.code) {
        case LlamaChatApiErrorCode.modelLoadTimeout:
          return ChatModelOperationError(
            kind: ChatModelOperationErrorKind.loadTimeout,
            modelName: modelName,
          );
        case LlamaChatApiErrorCode.modelLoadFailed:
          return ChatModelOperationError(
            kind: ChatModelOperationErrorKind.loadFailed,
            modelName: modelName,
          );
        case LlamaChatApiErrorCode.modelUnloadTimeout:
          return ChatModelOperationError(
            kind: ChatModelOperationErrorKind.unloadTimeout,
            modelName: modelName,
          );
        case null:
          return ChatModelOperationError(
            kind: ChatModelOperationErrorKind.requestFailed,
            modelName: modelName,
            detail: error.message,
          );
      }
    }
    return ChatModelOperationError(
      kind: ChatModelOperationErrorKind.requestFailed,
      modelName: modelName,
      detail: error.toString(),
    );
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

  bool _sameModels(List<ChatModelOption> left, List<ChatModelOption> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.id != b.id ||
          a.displayName != b.displayName ||
          a.status != b.status) {
        return false;
      }
    }
    return true;
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
