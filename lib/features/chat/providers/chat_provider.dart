import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_generation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
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
       _apiClient = apiClient ?? LlamaChatApiClient() {
    _idGenerator = ChatIdGenerator();
    _sessionList = ChatSessionListController(repository: _repository);
    _conversation = ChatConversationController(
      repository: _repository,
      sessionList: _sessionList,
      messageWindowSize: messageWindowSize,
    );
    _models = ChatModelController(apiClient: _apiClient);
    _generation = ChatGenerationController(
      repository: _repository,
      apiClient: _apiClient,
      sessionList: _sessionList,
      conversation: _conversation,
      models: _models,
      idGenerator: _idGenerator,
      defaultSessionTitle: defaultSessionTitle,
    );

    _sessionList.addListener(_notify);
    _conversation.addListener(_notify);
    _models.addListener(_notify);
    _generation.addListener(_notify);
  }

  static const String defaultSessionTitle = '新会话';
  static const int messageWindowSize = 30;
  static const int initialMessagePreloadCount = 8;

  final ChatSessionRepository _repository;
  final LlamaChatApiClient _apiClient;

  late final ChatIdGenerator _idGenerator;
  late final ChatSessionListController _sessionList;
  late final ChatConversationController _conversation;
  late final ChatModelController _models;
  late final ChatGenerationController _generation;

  @visibleForTesting
  LlamaChatApiClient get apiClient => _apiClient;

  StreamingChatMessageNotifier get streamingMessages =>
      _generation.streamingMessages;

  List<ChatSessionRecord> get sessions => _sessionList.sessions;
  List<ChatModelOption> get models => _models.models;

  bool get isLoading => _sessionList.isLoading;
  bool get isLoadingMessages => _conversation.isLoadingMessages;
  bool get isLoadingOlderMessages => _conversation.isLoadingOlderMessages;
  bool get isRefreshingModels => _models.isRefreshingModels;
  bool get isServerRunning => _models.isServerRunning;
  bool get isSending => _generation.isSending;
  String get sessionQuery => _sessionList.query;
  String? get loadingModelId => _models.loadingModelId;
  ChatModelOperationError? get modelOperationError => _models.lastOperationError;
  String? get currentModelId => _models.currentModelId;
  String? get draftMessageId => _generation.draftMessageId;
  String? get lastErrorMessage => _generation.lastErrorMessage;
  List<String> get pendingImageAttachments =>
      _generation.pendingImageAttachments;

  bool get canManageSessions => _generation.canManageSessions;
  bool get canSelectModels => _generation.canSelectModels;
  bool get canSend => _generation.canSend;
  bool get canManageMessages => _generation.canManageMessages;

  ChatSessionRecord? get selectedSession => _conversation.selectedSession;
  bool get isShowingDraftSession => _conversation.isShowingDraftSession;
  String get currentSessionTitle =>
      selectedSession?.title ?? defaultSessionTitle;

  bool get hasOlderMessages => _conversation.hasOlderMessages;

  ChatModelOption? get currentModel => _models.currentModel;
  String get currentModelDisplayName => _models.currentModelDisplayName;
  String get modelSelectorLabel => _models.modelSelectorLabel;
  String get currentModelStatusLabel => _models.currentModelStatusLabel;
  List<ChatModelOption> get loadedModels => _models.loadedModels;
  List<ChatModelOption> get availableModels => _models.availableModels;
  List<ChatMessageRecord> get visibleMessages => _conversation.visibleMessages;
  int get visibleMessagesRevision => _conversation.visibleMessagesRevision;
  List<ChatSessionRecord> get filteredSessions => _sessionList.filteredSessions;
  String get inputHintText => _models.inputHintText;

  Future<void> load() async {
    await _sessionList.load();
    _conversation.clearIfSelectedSessionMissing(notify: false);
    unawaited(_repository.warmUpMessageStore().catchError((_) {}));
    _conversation.preloadInitialMessages(
      _sessionList.sessions.take(initialMessagePreloadCount),
    );
  }

  void updateSessionQuery(String value) {
    _sessionList.updateQuery(value);
    _conversation.preloadInitialMessages(
      _sessionList.filteredSessions.take(initialMessagePreloadCount),
    );
  }

  void updateServerState({
    required String baseUrl,
    required bool isServerRunning,
    InferenceEngine engine = InferenceEngine.llamaCpp,
    String? activeModelId,
    String? activeModelName,
  }) {
    final stopped = _models.updateServerState(
      baseUrl: baseUrl,
      isServerRunning: isServerRunning,
      engine: engine,
      activeModelId: activeModelId,
      activeModelName: activeModelName,
    );
    if (stopped) {
      _generation.cancelForServerStop();
    }
  }

  void updateChatTimeout(Duration timeout) {
    _models.updateChatTimeout(timeout);
  }

  Future<void> refreshModels() async {
    await _models.refreshModels();
  }

  Future<void> createSession() async {
    if (!canManageSessions || _conversation.selectedSessionId == null) {
      return;
    }
    _conversation.clearSelection();
  }

  Future<void> renameSession(String sessionId, String title) async {
    if (!canManageSessions) {
      return;
    }
    await _sessionList.renameSession(sessionId, title);
  }

  Future<void> deleteSession(String sessionId) async {
    if (!canManageSessions) {
      return;
    }
    final isSelected = _conversation.selectedSessionId == sessionId;
    if (isSelected) {
      _conversation.clearSelection(notify: false);
    }
    final deleted = await _sessionList.deleteSession(sessionId);
    if (isSelected && !deleted) {
      _notify();
    }
  }

  bool beginSessionSelection(
    String sessionId, {
    bool keepVisibleMessages = true,
  }) {
    if (!canManageSessions) {
      return false;
    }
    return _conversation.beginSessionSelection(
      sessionId,
      keepVisibleMessages: keepVisibleMessages,
    );
  }

  Future<void> loadSelectedSessionMessages(String sessionId) async {
    if (!canManageSessions) {
      return;
    }
    await _conversation.loadSelectedSessionMessages(sessionId);
  }

  Future<bool> switchSession(String sessionId, {bool staged = false}) async {
    if (!canManageSessions) {
      return false;
    }
    return _conversation.switchSession(sessionId, staged: staged);
  }

  Future<void> selectSession(String sessionId) async {
    await switchSession(sessionId);
  }

  Future<void> loadOlderMessages() async {
    await _conversation.loadOlderMessages();
  }

  void selectLoadedModel(String modelId) {
    if (!canSelectModels) {
      return;
    }
    _models.selectLoadedModel(modelId);
  }

  Future<void> loadAndSelectModel(String modelId) async {
    if (!canSelectModels) {
      return;
    }
    await _models.loadAndSelectModel(modelId);
  }

  Future<void> loadCurrentModel() async {
    await _models.loadCurrentModel();
  }

  Future<void> unloadModel(String modelId) async {
    if (!canSelectModels) {
      return;
    }
    await _models.unloadModel(modelId);
  }

  void clearModelOperationError() {
    _models.clearOperationError();
  }

  Future<void> sendMessage(
    String text, {
    List<String>? imageAttachments,
  }) async {
    await _generation.sendMessage(text, imageAttachments: imageAttachments);
  }

  bool canRegenerateMessage(String messageId) {
    return _generation.canRegenerateMessage(messageId);
  }

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    await _generation.editMessage(messageId: messageId, newContent: newContent);
  }

  Future<void> deleteMessage(String messageId) async {
    await _generation.deleteMessage(messageId);
  }

  Future<void> selectMessageVersion({
    required String messageId,
    required int versionIndex,
  }) async {
    await _generation.selectMessageVersion(
      messageId: messageId,
      versionIndex: versionIndex,
    );
  }

  Future<void> regenerateFromMessage(String messageId) async {
    await _generation.regenerateFromMessage(messageId);
  }

  void clearLastError() {
    _generation.clearLastError();
  }

  void cancelStreaming() {
    _generation.cancelStreaming();
  }

  void addImageAttachment(String filePath) {
    _generation.addImageAttachment(filePath);
  }

  void removeImageAttachment(int index) {
    _generation.removeImageAttachment(index);
  }

  void clearImageAttachments() {
    _generation.clearImageAttachments();
  }

  void _notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionList.removeListener(_notify);
    _conversation.removeListener(_notify);
    _models.removeListener(_notify);
    _generation.removeListener(_notify);
    _generation.dispose();
    _models.dispose();
    _conversation.dispose();
    _sessionList.dispose();
    super.dispose();
  }
}
