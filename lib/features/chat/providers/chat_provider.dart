import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    ChatSessionRepository? repository,
    LlamaChatApiClient? apiClient,
  }) : _repository = repository ?? ChatSessionRepository(),
       _apiClient = apiClient ?? LlamaChatApiClient();

  static const String defaultSessionTitle = '新会话';

  final ChatSessionRepository _repository;
  final LlamaChatApiClient _apiClient;
  final Random _random = Random();

  List<ChatSessionRecord> _sessions = <ChatSessionRecord>[];
  List<ChatModelOption> _models = <ChatModelOption>[];

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isRefreshingModels = false;
  bool _isServerRunning = false;
  String _baseUrl = 'http://127.0.0.1:8080';
  String? _selectedSessionId;
  String? _currentModelId;
  String? _loadingModelId;
  String _sessionQuery = '';
  bool _isSending = false;
  ChatMessageRecord? _draftAssistantMessage;
  String? _streamingSessionId;
  CancelToken? _activeCancelToken;

  List<ChatSessionRecord> get sessions =>
      List<ChatSessionRecord>.unmodifiable(_sessions);
  List<ChatModelOption> get models =>
      List<ChatModelOption>.unmodifiable(_models);

  bool get isLoading => _isLoading;
  bool get isRefreshingModels => _isRefreshingModels;
  bool get isServerRunning => _isServerRunning;
  bool get isSending => _isSending;
  String get sessionQuery => _sessionQuery;
  String? get loadingModelId => _loadingModelId;
  String? get currentModelId => _currentModelId;
  String? get draftMessageId => _draftAssistantMessage?.id;

  bool get canManageSessions => !_isSending && _loadingModelId == null;
  bool get canSelectModels =>
      _isServerRunning && !_isSending && _loadingModelId == null;
  bool get canSend =>
      !_isSending &&
      _loadingModelId == null &&
      _isServerRunning &&
      currentModel?.isLoaded == true;

  ChatSessionRecord? get selectedSession => _findSession(_selectedSessionId);
  bool get isShowingDraftSession => _selectedSessionId == null;
  String get currentSessionTitle =>
      selectedSession?.title ?? defaultSessionTitle;

  ChatModelOption? get currentModel => _findModel(_currentModelId);

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

  List<ChatModelOption> get loadedModels =>
      _models.where((model) => model.isLoaded).toList(growable: false);

  List<ChatModelOption> get availableModels =>
      _models.where((model) => !model.isLoaded).toList(growable: false);

  List<ChatMessageRecord> get visibleMessages {
    final session = selectedSession;
    if (session == null) {
      return const <ChatMessageRecord>[];
    }

    if (_streamingSessionId != session.id || _draftAssistantMessage == null) {
      return List<ChatMessageRecord>.from(session.messages, growable: false);
    }

    return <ChatMessageRecord>[...session.messages, _draftAssistantMessage!];
  }

  List<ChatSessionRecord> get filteredSessions {
    final normalizedQuery = _normalizedSessionQuery;
    if (normalizedQuery.isEmpty) {
      return sessions;
    }
    return _sessions
        .where(
          (session) => session.title.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
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

  Future<void> load() async {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _sessions = List<ChatSessionRecord>.from(
        await _repository.loadSessions(),
      );
      if (_findSession(_selectedSessionId) == null) {
        _selectedSessionId = null;
      }
      _isInitialized = true;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSessionQuery(String value) {
    final nextQuery = value;
    if (_sessionQuery == nextQuery) {
      return;
    }
    _sessionQuery = nextQuery;
    notifyListeners();
  }

  void updateServerState({
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
      _activeCancelToken?.cancel('server stopped');
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
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

  Future<void> createSession() async {
    if (!canManageSessions) {
      return;
    }

    if (_selectedSessionId == null) {
      return;
    }

    _selectedSessionId = null;
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String title) async {
    if (!canManageSessions) {
      return;
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }

    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }

    final updated = session.copyWith(
      title: normalizedTitle,
      updatedAt: DateTime.now(),
    );
    await _saveSessionLocally(updated);
  }

  Future<void> deleteSession(String sessionId) async {
    if (!canManageSessions) {
      return;
    }

    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }

    final nextSessions = List<ChatSessionRecord>.from(_sessions);
    nextSessions.removeWhere((item) => item.id == sessionId);
    _sessions = nextSessions;
    await _repository.deleteSession(sessionId);

    if (_selectedSessionId == sessionId) {
      _selectedSessionId = null;
    }
    notifyListeners();
  }

  void selectSession(String sessionId) {
    if (!canManageSessions) {
      return;
    }
    if (_selectedSessionId == sessionId) {
      return;
    }
    if (_findSession(sessionId) == null) {
      return;
    }
    _selectedSessionId = sessionId;
    notifyListeners();
  }

  void selectLoadedModel(String modelId) {
    if (!canSelectModels) {
      return;
    }
    final model = _findModel(modelId);
    if (model == null || !model.isLoaded) {
      return;
    }
    _currentModelId = modelId;
    notifyListeners();
  }

  Future<void> loadAndSelectModel(String modelId) async {
    if (!canSelectModels) {
      return;
    }

    final model = _findModel(modelId);
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
    if (!canSelectModels) {
      return;
    }

    final model = _findModel(modelId);
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

  Future<void> sendMessage(String text) async {
    if (!canSend) {
      return;
    }

    final model = currentModel;
    final normalizedText = text.trim();
    if (model == null || normalizedText.isEmpty) {
      return;
    }

    var session = selectedSession;
    if (session == null) {
      session = _createSessionRecord();
      _selectedSessionId = session.id;
    }

    _isSending = true;

    final now = DateTime.now();
    final userMessage = ChatMessageRecord(
      id: _generateId('message'),
      role: ChatRole.user,
      content: normalizedText,
      createdAt: now,
      modelName: model.displayName,
    );

    final sessionTitle = session.title == defaultSessionTitle
        ? _deriveSessionTitle(normalizedText)
        : session.title;
    final updatedSession = session.copyWith(
      title: sessionTitle,
      messages: <ChatMessageRecord>[...session.messages, userMessage],
      updatedAt: now,
    );
    await _saveSessionLocally(updatedSession, notify: false);

    final draftMessage = ChatMessageRecord(
      id: _generateId('draft'),
      role: ChatRole.assistant,
      content: '',
      createdAt: now,
      modelName: model.displayName,
      reasoningContent: '',
    );
    _draftAssistantMessage = draftMessage;
    _streamingSessionId = updatedSession.id;
    _activeCancelToken = CancelToken();
    notifyListeners();

    var sessionAfterUserMessage = updatedSession;
    try {
      await for (final delta in _apiClient.streamChatCompletion(
        modelId: model.id,
        messages: updatedSession.messages,
        cancelToken: _activeCancelToken!,
      )) {
        final currentDraft = _draftAssistantMessage;
        if (currentDraft == null) {
          continue;
        }
        final nextContent = delta.content.isEmpty
            ? currentDraft.content
            : '${currentDraft.content}${delta.content}';
        final currentReasoningContent = currentDraft.reasoningContent ?? '';
        final nextReasoningContent = delta.reasoningContent.isEmpty
            ? currentDraft.reasoningContent
            : '$currentReasoningContent${delta.reasoningContent}';
        _draftAssistantMessage = currentDraft.copyWith(
          content: nextContent,
          reasoningContent: nextReasoningContent,
        );
        notifyListeners();
      }
    } catch (_) {
    } finally {
      final draft = _draftAssistantMessage;
      final hasDraftContent = draft != null && draft.content.trim().isNotEmpty;
      final hasDraftReasoning =
          draft != null && (draft.reasoningContent?.trim().isNotEmpty ?? false);
      if (draft != null && (hasDraftContent || hasDraftReasoning)) {
        final finalizedSession = sessionAfterUserMessage.copyWith(
          messages: <ChatMessageRecord>[
            ...sessionAfterUserMessage.messages,
            draft,
          ],
          updatedAt: DateTime.now(),
        );
        await _saveSessionLocally(finalizedSession, notify: false);
      }

      _draftAssistantMessage = null;
      _streamingSessionId = null;
      _activeCancelToken = null;
      _isSending = false;
      notifyListeners();
    }
  }

  void cancelStreaming() {
    _activeCancelToken?.cancel('user canceled');
  }

  Future<void> _saveSessionLocally(
    ChatSessionRecord session, {
    bool notify = true,
  }) async {
    await _repository.saveSession(session);
    final nextSessions = List<ChatSessionRecord>.from(_sessions);
    final index = nextSessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      nextSessions[index] = session;
    } else {
      nextSessions.add(session);
    }
    nextSessions.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    _sessions = nextSessions;
    if (notify) {
      notifyListeners();
    }
  }

  ChatSessionRecord _createSessionRecord() {
    final now = DateTime.now();
    return ChatSessionRecord(
      id: _generateId('session'),
      title: defaultSessionTitle,
      messages: const <ChatMessageRecord>[],
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatSessionRecord? _findSession(String? sessionId) {
    if (sessionId == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  ChatModelOption? _findModel(String? modelId) {
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

  String _deriveSessionTitle(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return defaultSessionTitle;
    }
    if (normalized.length <= 18) {
      return normalized;
    }
    return '${normalized.substring(0, 18)}...';
  }

  String _generateId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }

  String get _normalizedSessionQuery => _sessionQuery.trim().toLowerCase();

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
