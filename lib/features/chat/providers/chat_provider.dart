import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
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
  CancelToken? _activeCancelToken;
  String? _lastErrorMessage;
  List<String> _pendingImageAttachments = [];

  @visibleForTesting
  LlamaChatApiClient get apiClient => _apiClient;

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
  String? get lastErrorMessage => _lastErrorMessage;
  List<String> get pendingImageAttachments =>
      List<String>.unmodifiable(_pendingImageAttachments);

  bool get canManageSessions => !_isSending && _loadingModelId == null;
  bool get canSelectModels =>
      _isServerRunning && !_isSending && _loadingModelId == null;
  bool get canSend =>
      !_isSending &&
      _loadingModelId == null &&
      _isServerRunning &&
      currentModel?.isLoaded == true;
  bool get canManageMessages => !_isSending && _loadingModelId == null;

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

    return List<ChatMessageRecord>.from(session.messages, growable: false);
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

  bool canRegenerateMessage(String messageId) {
    if (!canSend) {
      return false;
    }
    final session = selectedSession;
    if (session == null) {
      return false;
    }
    final targetIndex = _messageIndex(session.messages, messageId);
    if (targetIndex < 0) {
      return false;
    }
    return _nearestUserMessageIndex(session.messages, targetIndex) >= 0;
  }

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    if (!canManageMessages) {
      return;
    }

    final session = selectedSession;
    if (session == null) {
      return;
    }

    final normalizedContent = newContent.trim();
    if (normalizedContent.isEmpty) {
      return;
    }

    final messageIndex = _messageIndex(session.messages, messageId);
    if (messageIndex < 0) {
      return;
    }

    final currentMessage = session.messages[messageIndex];
    if (currentMessage.content == normalizedContent) {
      return;
    }

    final updatedMessages = List<ChatMessageRecord>.from(session.messages);
    final updatedMessage = currentMessage.copyWith(content: normalizedContent);
    updatedMessages[messageIndex] = updatedMessage;

    if (currentMessage.versionIds.isNotEmpty &&
        currentMessage.role == ChatRole.assistant) {
      final versionId = _selectedVersionId(currentMessage);
      if (versionId != null) {
        final version = await _repository.loadMessageVersion(versionId);
        if (version != null) {
          await _repository.saveMessageVersion(
            ChatMessageVersionRecord(
              id: version.id,
              messageId: version.messageId,
              content: normalizedContent,
              createdAt: version.createdAt,
              modelName: version.modelName,
              reasoningContent: version.reasoningContent,
              imageFilePaths: version.imageFilePaths,
            ),
          );
        }
      }
    }

    await _saveSessionLocally(
      session.copyWith(messages: updatedMessages, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteMessage(String messageId) async {
    if (!canManageMessages) {
      return;
    }

    final session = selectedSession;
    if (session == null) {
      return;
    }

    final messageIndex = _messageIndex(session.messages, messageId);
    if (messageIndex < 0) {
      return;
    }

    final targetMessage = session.messages[messageIndex];
    final updatedMessages = List<ChatMessageRecord>.from(session.messages)
      ..removeAt(messageIndex);
    await _repository.deleteMessageResources(<ChatMessageRecord>[
      targetMessage,
    ]);
    await _saveSessionLocally(
      session.copyWith(messages: updatedMessages, updatedAt: DateTime.now()),
    );
  }

  Future<void> selectMessageVersion({
    required String messageId,
    required int versionIndex,
  }) async {
    if (!canManageMessages) {
      return;
    }

    final session = selectedSession;
    if (session == null) {
      return;
    }

    final messageIndex = _messageIndex(session.messages, messageId);
    if (messageIndex < 0) {
      return;
    }

    final message = session.messages[messageIndex];
    if (message.role != ChatRole.assistant ||
        versionIndex < 0 ||
        versionIndex >= message.versionIds.length ||
        versionIndex == message.currentVersionIndex) {
      return;
    }

    final version = await _repository.loadMessageVersion(
      message.versionIds[versionIndex],
    );
    if (version == null) {
      return;
    }

    final updatedMessages = List<ChatMessageRecord>.from(session.messages);
    updatedMessages[messageIndex] = _messageWithVersion(
      message,
      version,
      versionIndex,
    );

    await _saveSessionLocally(
      session.copyWith(messages: updatedMessages, updatedAt: DateTime.now()),
    );
  }

  Future<void> regenerateFromMessage(String messageId) async {
    if (!canRegenerateMessage(messageId)) {
      return;
    }

    final session = selectedSession;
    final model = currentModel;
    if (session == null || model == null) {
      return;
    }

    final targetIndex = _messageIndex(session.messages, messageId);
    final userIndex = _nearestUserMessageIndex(session.messages, targetIndex);
    if (userIndex < 0) {
      return;
    }

    final targetMessage = session.messages[targetIndex];
    if (targetMessage.role == ChatRole.assistant) {
      await _regenerateAssistantMessageVersion(
        session: session,
        targetIndex: targetIndex,
        model: model,
      );
      return;
    }

    final retainedMessages = List<ChatMessageRecord>.from(
      session.messages.take(userIndex + 1),
    );
    final removedMessages = session.messages.skip(userIndex + 1);
    await _repository.deleteMessageResources(removedMessages);

    final updatedSession = session.copyWith(
      messages: retainedMessages,
      updatedAt: DateTime.now(),
    );
    await _saveSessionLocally(updatedSession, notify: false);
    await _generateAssistantResponse(updatedSession, model);
  }

  Future<void> _regenerateAssistantMessageVersion({
    required ChatSessionRecord session,
    required int targetIndex,
    required ChatModelOption model,
  }) async {
    final targetMessage = session.messages[targetIndex];
    final promptMessages = List<ChatMessageRecord>.from(
      session.messages.take(targetIndex),
    );
    final retainedMessages = List<ChatMessageRecord>.from(
      session.messages.take(targetIndex + 1),
    );
    final removedMessages = session.messages.skip(targetIndex + 1);
    await _repository.deleteMessageResources(removedMessages);

    var retainedTargetMessage = targetMessage;
    var versionIds = List<String>.from(targetMessage.versionIds);
    if (versionIds.isEmpty) {
      final originalVersion = _versionFromMessage(targetMessage);
      await _repository.saveMessageVersion(originalVersion);
      versionIds = <String>[originalVersion.id];
      retainedTargetMessage = targetMessage.copyWith(
        versionIds: versionIds,
        currentVersionIndex: 0,
      );
      retainedMessages[targetIndex] = retainedTargetMessage;
    }

    final fallbackSession = session.copyWith(
      messages: retainedMessages,
      updatedAt: DateTime.now(),
    );
    await _saveSessionLocally(fallbackSession, notify: false);

    final now = DateTime.now();
    final nextVersion = ChatMessageVersionRecord(
      id: _generateId('version'),
      messageId: targetMessage.id,
      content: '',
      createdAt: now,
      modelName: model.displayName,
      reasoningContent: '',
    );
    final nextVersionIds = <String>[...versionIds, nextVersion.id];
    final nextVersionIndex = nextVersionIds.length - 1;
    retainedTargetMessage = retainedTargetMessage.copyWith(
      content: '',
      createdAt: now,
      modelName: model.displayName,
      reasoningContent: '',
      clearImageFilePaths: true,
      versionIds: nextVersionIds,
      currentVersionIndex: nextVersionIndex,
    );
    final streamingMessages = List<ChatMessageRecord>.from(retainedMessages);
    streamingMessages[targetIndex] = retainedTargetMessage;
    final streamingSession = fallbackSession.copyWith(
      messages: streamingMessages,
      updatedAt: now,
    );

    await _generateAssistantResponse(
      streamingSession,
      model,
      promptMessages: promptMessages,
      draftSeed: retainedTargetMessage,
      versionId: nextVersion.id,
      emptyDraftFallbackSession: fallbackSession,
    );
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

  Future<void> sendMessage(
    String text, {
    List<String>? imageAttachments,
  }) async {
    if (!canSend) {
      return;
    }

    final model = currentModel;
    final normalizedText = text.trim();
    if (model == null ||
        (normalizedText.isEmpty &&
            (imageAttachments == null || imageAttachments.isEmpty))) {
      return;
    }

    var session = selectedSession;
    if (session == null) {
      session = _createSessionRecord();
      _selectedSessionId = session.id;
    }

    _isSending = true;
    // 清空附件图片预览
    clearImageAttachments();

    final now = DateTime.now();
    final userMessage = ChatMessageRecord(
      id: _generateId('message'),
      role: ChatRole.user,
      content: normalizedText,
      createdAt: now,
      modelName: model.displayName,
      imageFilePaths: imageAttachments ?? const [],
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
    await _generateAssistantResponse(updatedSession, model);
  }

  void clearLastError() {
    _lastErrorMessage = null;
  }

  void cancelStreaming() {
    _activeCancelToken?.cancel('user canceled');
  }

  void addImageAttachment(String filePath) {
    if (_pendingImageAttachments.length >= 5) {
      return;
    }
    _pendingImageAttachments = List<String>.from(_pendingImageAttachments)
      ..add(filePath);
    notifyListeners();
  }

  void removeImageAttachment(int index) {
    if (index < 0 || index >= _pendingImageAttachments.length) {
      return;
    }
    _pendingImageAttachments = List<String>.from(_pendingImageAttachments)
      ..removeAt(index);
    notifyListeners();
  }

  void clearImageAttachments() {
    if (_pendingImageAttachments.isEmpty) {
      return;
    }
    _pendingImageAttachments = [];
    notifyListeners();
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

  Future<void> _generateAssistantResponse(
    ChatSessionRecord session,
    ChatModelOption model, {
    List<ChatMessageRecord>? promptMessages,
    ChatMessageRecord? draftSeed,
    String? versionId,
    ChatSessionRecord? emptyDraftFallbackSession,
  }) async {
    _isSending = true;

    final draftMessage =
        draftSeed ??
        ChatMessageRecord(
          id: _generateId('draft'),
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime.now(),
          modelName: model.displayName,
          reasoningContent: '',
        );
    _draftAssistantMessage = draftMessage;
    _activeCancelToken = CancelToken();

    var currentSession = _sessionWithStreamingDraft(
      session,
      draftMessage,
      appendIfMissing: draftSeed == null,
    );
    await _persistStreamingDraft(
      session: currentSession,
      draft: draftMessage,
      versionId: versionId,
      notify: true,
    );

    try {
      await for (final delta in _apiClient.streamChatCompletion(
        modelId: model.id,
        messages: promptMessages ?? session.messages,
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
        currentSession = _sessionWithStreamingDraft(
          currentSession,
          _draftAssistantMessage!,
          appendIfMissing: draftSeed == null,
        );
        await _persistStreamingDraft(
          session: currentSession,
          draft: _draftAssistantMessage!,
          versionId: versionId,
          notify: true,
        );
      }
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) {
        // 用户主动取消，不生成错误消息
      } else {
        final draft = _draftAssistantMessage;
        final errorMessage = _chatErrorMessage(error);
        if (draft != null && draft.content.trim().isNotEmpty) {
          _lastErrorMessage = errorMessage;
        } else {
          _draftAssistantMessage = ChatMessageRecord(
            id: draft?.id ?? _generateId('error'),
            role: ChatRole.assistant,
            content: errorMessage,
            createdAt: DateTime.now(),
            modelName: currentModel?.displayName,
            versionIds: draft?.versionIds ?? const [],
            currentVersionIndex: draft?.currentVersionIndex ?? 0,
          );
          currentSession = _sessionWithStreamingDraft(
            currentSession,
            _draftAssistantMessage!,
            appendIfMissing: draftSeed == null,
          );
          await _persistStreamingDraft(
            session: currentSession,
            draft: _draftAssistantMessage!,
            versionId: versionId,
            notify: true,
          );
        }
      }
    } finally {
      final draft = _draftAssistantMessage;
      final hasDraftContent = draft != null && draft.content.trim().isNotEmpty;
      final hasDraftReasoning =
          draft != null && (draft.reasoningContent?.trim().isNotEmpty ?? false);
      if (draft != null && !hasDraftContent && !hasDraftReasoning) {
        if (versionId != null) {
          await _repository.deleteMessageVersions(<String>[versionId]);
          final fallbackSession = emptyDraftFallbackSession;
          if (fallbackSession != null) {
            await _saveSessionLocally(fallbackSession, notify: false);
          }
        } else {
          final cleanedSession = _sessionWithoutMessage(
            currentSession,
            draft.id,
          );
          await _saveSessionLocally(cleanedSession, notify: false);
        }
      }

      _draftAssistantMessage = null;
      _activeCancelToken = null;
      _isSending = false;
      _pendingImageAttachments = [];
      notifyListeners();
    }
  }

  Future<void> _persistStreamingDraft({
    required ChatSessionRecord session,
    required ChatMessageRecord draft,
    required String? versionId,
    required bool notify,
  }) async {
    if (versionId != null) {
      await _repository.saveMessageVersion(
        ChatMessageVersionRecord(
          id: versionId,
          messageId: draft.id,
          content: draft.content,
          createdAt: draft.createdAt,
          modelName: draft.modelName,
          reasoningContent: draft.reasoningContent,
          imageFilePaths: draft.imageFilePaths,
        ),
      );
    }
    await _saveSessionLocally(session, notify: notify);
  }

  ChatSessionRecord _sessionWithStreamingDraft(
    ChatSessionRecord session,
    ChatMessageRecord draft, {
    required bool appendIfMissing,
  }) {
    final messages = List<ChatMessageRecord>.from(session.messages);
    final index = _messageIndex(messages, draft.id);
    if (index >= 0) {
      messages[index] = draft;
    } else if (appendIfMissing) {
      messages.add(draft);
    } else {
      return session;
    }
    return session.copyWith(messages: messages, updatedAt: DateTime.now());
  }

  ChatSessionRecord _sessionWithoutMessage(
    ChatSessionRecord session,
    String messageId,
  ) {
    final messages = List<ChatMessageRecord>.from(session.messages)
      ..removeWhere((message) => message.id == messageId);
    return session.copyWith(messages: messages, updatedAt: DateTime.now());
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

  int _messageIndex(List<ChatMessageRecord> messages, String messageId) {
    return messages.indexWhere((message) => message.id == messageId);
  }

  int _nearestUserMessageIndex(
    List<ChatMessageRecord> messages,
    int startIndex,
  ) {
    for (var index = startIndex; index >= 0; index -= 1) {
      if (messages[index].role == ChatRole.user) {
        return index;
      }
    }
    return -1;
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

  String? _selectedVersionId(ChatMessageRecord message) {
    if (message.versionIds.isEmpty ||
        message.currentVersionIndex < 0 ||
        message.currentVersionIndex >= message.versionIds.length) {
      return null;
    }
    return message.versionIds[message.currentVersionIndex];
  }

  ChatMessageVersionRecord _versionFromMessage(
    ChatMessageRecord message, {
    String? messageId,
  }) {
    final targetMessageId = messageId ?? message.id;
    return ChatMessageVersionRecord(
      id: _generateId('version'),
      messageId: targetMessageId,
      content: message.content,
      createdAt: message.createdAt,
      modelName: message.modelName,
      reasoningContent: message.reasoningContent,
      imageFilePaths: message.imageFilePaths,
    );
  }

  ChatMessageRecord _messageWithVersion(
    ChatMessageRecord message,
    ChatMessageVersionRecord version,
    int versionIndex,
  ) {
    return message.copyWith(
      content: version.content,
      createdAt: version.createdAt,
      modelName: version.modelName,
      clearModelName: version.modelName == null,
      reasoningContent: version.reasoningContent,
      clearReasoningContent: version.reasoningContent == null,
      imageFilePaths: version.imageFilePaths,
      currentVersionIndex: versionIndex,
    );
  }

  String get _normalizedSessionQuery => _sessionQuery.trim().toLowerCase();

  String _chatErrorMessage(Object error) {
    return "Request Failed: $error";
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
