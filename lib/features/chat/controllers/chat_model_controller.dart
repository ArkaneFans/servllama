import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class ChatModelController extends ChangeNotifier {
  ChatModelController({required LlamaChatApiClient apiClient})
    : _apiClient = apiClient;

  final LlamaChatApiClient _apiClient;

  List<ChatModelOption> _models = <ChatModelOption>[];
  bool _isServerRunning = false;
  String _baseUrl = 'http://127.0.0.1:8080';
  String? _currentModelId;

  List<ChatModelOption> get models =>
      List<ChatModelOption>.unmodifiable(_models);
  bool get isServerRunning => _isServerRunning;
  String? get currentModelId => _currentModelId;

  ChatModelOption? get currentModel {
    final modelId = _currentModelId;
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

  bool updateServerState({
    required String baseUrl,
    required bool isServerRunning,
    String? activeModelId,
    String? activeModelName,
  }) {
    if (_baseUrl != baseUrl) {
      _baseUrl = baseUrl;
      _apiClient.updateBaseUrl(baseUrl);
    }

    final stopped = _isServerRunning && !isServerRunning;
    var changed = _isServerRunning != isServerRunning;
    _isServerRunning = isServerRunning;

    final normalizedModelId = activeModelId?.trim();
    final hasActiveModel =
        isServerRunning && normalizedModelId?.isNotEmpty == true;
    final nextModels = hasActiveModel
        ? <ChatModelOption>[
            ChatModelOption(
              id: normalizedModelId!,
              displayName: activeModelName?.trim().isNotEmpty == true
                  ? activeModelName!.trim()
                  : normalizedModelId,
              status: ChatModelStatus.loaded,
            ),
          ]
        : <ChatModelOption>[];
    final nextModelId = hasActiveModel ? normalizedModelId : null;

    if (!_sameModels(_models, nextModels)) {
      _models = nextModels;
      changed = true;
    }
    if (_currentModelId != nextModelId) {
      _currentModelId = nextModelId;
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
}
