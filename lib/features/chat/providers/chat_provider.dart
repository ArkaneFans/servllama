import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'dart:async';
import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_runner.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    ChatSessionRepository? repository,
    LlamaChatApiClient? apiClient,
    ChatProtocolClient? protocolClient,
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
    _generation = ChatRunner(
      repository: _repository,
      apiClient: _apiClient,
      sessionList: _sessionList,
      conversation: _conversation,
      models: _models,
      idGenerator: _idGenerator,
      defaultSessionTitle: defaultSessionTitle,
      protocolClient: protocolClient,
    );

    _sessionList.addListener(_notify);
    _conversation.addListener(_conversationChanged);
    _models.addListener(_notify);
    _generation.addListener(_notify);
  }

  static const String defaultSessionTitle = '新会话';
  static const int messageWindowSize = 30;
  static const int initialMessagePreloadCount = 8;

  bool _disposed = false;
  String? _bindingKey;
  AssistantProvider? _assistants;
  EngineRuntimeProvider? _runtime;
  bool get isRemote => _generation.isRemote;
  bool _draftInitialized = false,
      _changingSettings = false,
      _preparingLocal = false;
  String? _draftAssistantId, _attachmentContext;
  final Map<String, List<String>> _attachmentDrafts = {};
  bool get hasAssistantContext => _assistants != null;
  String? get currentAssistantId => selectedSession != null
      ? selectedSession!.assistantId
      : _draftAssistantId ?? _assistants?.activeId;
  Assistant? get currentAssistant => _assistants?.assistants
      .where((a) => a.id == currentAssistantId)
      .firstOrNull;
  ChatTarget? get currentTarget =>
      _assistants?.resolveTarget(currentAssistant?.chatTarget);
  ModelAsset? get targetAsset => _assistants?.assets
      .where((a) => a.id == currentTarget?.assetId && a.kind == AssetKind.llm)
      .firstOrNull;

  String? get targetLabel {
    final target = currentTarget;
    if (target == null) return null;
    if (target.isRemote) {
      final connection = _assistants?.connection(target.connectionId);
      return connection == null
          ? target.modelId
          : '${connection.name} / ${target.modelId ?? ''}';
    }
    return targetAsset?.name;
  }

  void _initializeDraft() {
    if (_draftInitialized || _assistants?.loaded != true) return;
    _draftInitialized = true;
    _draftAssistantId = _assistants!.activeId;
    _adoptLegacyDraft();
  }

  void _adoptLegacyDraft() {
    if (currentAssistantId == null ||
        selectedSession != null ||
        !_drafts.containsKey('draft')) {
      return;
    }
    _drafts.putIfAbsent(draftKey, () => _drafts['draft']!);
    _drafts.remove('draft');
  }

  void _syncDraftImages() {
    final key = draftKey;
    if (_attachmentContext == key) return;
    if (_attachmentContext != null) {
      _attachmentDrafts[_attachmentContext!] = List.of(
        _generation.pendingImageAttachments,
      );
    }
    _attachmentContext = key;
    _generation.replaceImageAttachments(
      _attachmentDrafts[key] ?? const [],
      notify: false,
    );
  }

  void _moveDraft(String from, String to) {
    _drafts[to] = _drafts.remove(from) ?? '';
    _attachmentDrafts.remove(from);
    _attachmentContext = to;
  }

  void _conversationChanged() {
    _syncDraftImages();
    _refreshBinding();
    _notify();
  }

  ChatSessionRecord _initializeSession(ChatSessionRecord session) =>
      session.copyWith(assistantId: currentAssistantId);
  final Map<String, String> _drafts = {};
  bool _draftsLoaded = false;
  Future<void>? _draftLoad;
  Future<void> _draftWrites = Future.value();
  bool _deletingAssistant = false;
  Timer? _draftDebounce;
  Future<String>? _creatingConversation;
  String _assistantDraftKey(String? id) => id == null ? 'draft' : 'draft:$id';
  String get draftKey =>
      selectedSession?.id ?? _assistantDraftKey(currentAssistantId);
  String get newDraftKey {
    final preferred = _assistantDraftKey(
      (currentAssistant ?? _assistants?.active)?.id,
    );
    final drafts = newConversationDrafts;
    return drafts.containsKey(preferred) ? preferred : drafts.keys.first;
  }

  /// Available unsent destinations, labelled by assistant rather than model.
  Map<String, String> get newConversationDrafts =>
      _assistants?.assistants.isNotEmpty == true
      ? {
          for (final assistant in _assistants!.assistants)
            _assistantDraftKey(assistant.id): assistant.name,
        }
      : const {'draft': ''};
  bool hasDraftDestination(String key) =>
      newConversationDrafts.containsKey(key) ||
      sessions.any((session) => session.id == key);
  String get currentDraft => _drafts[draftKey] ?? '';
  String draftFor(String key) => _drafts[key] ?? '';
  void updateDraft(String value, {String? key}) {
    final destination = key ?? draftKey;
    if (!hasDraftDestination(destination)) return;
    if (_drafts[destination] == value) return;
    _drafts[destination] = value;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(flushDrafts()),
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadDrafts() => _draftLoad ??= () async {
    if (_draftsLoaded) return;
    final saved = await AppDatabase.current?.metadata('chatDrafts');
    if (saved != null) {
      for (final entry in Map<String, String>.from(jsonDecode(saved)).entries) {
        _drafts.putIfAbsent(entry.key, () => entry.value);
      }
    }
    _draftsLoaded = true;
    _adoptLegacyDraft();
  }();
  Future<void> flushDrafts() async {
    _draftDebounce?.cancel();
    final db = AppDatabase.current;
    if (db == null) return;
    try {
      await _loadDrafts();
      if (_deletingAssistant) return;
      final payload = jsonEncode(_drafts);
      final saved = _draftWrites.then(
        (_) => db.setMetadata('chatDrafts', payload),
      );
      _draftWrites = saved.catchError((Object _) {});
      await saved;
    } catch (e) {
      AppLogger.instance.event(
        'client.draft.save_failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: AppLogger.errorFields(e),
      );
    }
  }

  String? get stopReason => _generation.stopReason;
  Future<String?> finalAnswer(ChatMessageRecord message) async {
    final db = AppDatabase.current;
    return db == null || message.runId == null
        ? message.content
        : GenerationRunRepository(db).finalAnswer(message);
  }

  Future<String> ensureConversation() async {
    if (_creatingConversation != null) return _creatingConversation!;
    final selected = selectedSession;
    if (selected != null) return selected.id;
    if (isSending || _preparingLocal) {
      throw StateError('The conversation is busy');
    }
    final operation = _creatingConversation =
        () async {
          await _loadDrafts();
          final now = DateTime.now();
          final oldKey = draftKey;
          final session = _initializeSession(
            ChatSessionRecord(
              id: _idGenerator.generate('session'),
              title: defaultSessionTitle,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await _repository.saveSession(session);
          _sessionList.upsertSession(session, notify: false);
          _moveDraft(oldKey, session.id);
          _conversation.beginSessionSelection(
            session.id,
            keepVisibleMessages: false,
          );
          await flushDrafts();
          return session.id;
        }().whenComplete(() {
          _creatingConversation = null;
          if (!_disposed) notifyListeners();
        });
    notifyListeners();
    return operation;
  }

  String get assistantName => currentAssistant?.name ?? '';
  void bind(AssistantProvider assistants, EngineRuntimeProvider runtime) {
    _assistants = assistants;
    _runtime = runtime;
    _initializeDraft();
    if (selectedSession == null &&
        currentAssistant == null &&
        assistants.active != null) {
      _draftAssistantId = assistants.activeId;
    }
    _syncDraftImages();
    _generation.initializeSession = _initializeSession;
    _generation.isAuthorized = (config) => config.authorizedBy(
      assistants.assistants
          .where((a) => a.id == config.assistant.id)
          .firstOrNull,
      assistants.connection(config.connection.id),
    );
    _generation.configuration = _configuration;
    _refreshBinding();
  }

  void _refreshBinding() {
    final assistants = _assistants, runtime = _runtime;
    if (assistants == null || runtime == null) return;
    _generation.revalidateAuthorization();
    final assistant = currentAssistant;
    final target = currentTarget;
    final connection = assistants.connection(target?.connectionId);
    final asset = targetAsset;
    final readyLocal =
        asset?.isReady == true &&
        runtime.isRunning &&
        runtime.activeModelId == asset!.runtimeId &&
        runtime.activeEngine.storageValue == asset.engine;
    _generation.isRemote = target?.isRemote == true;
    _generation.targetReady =
        assistant != null &&
        target?.isConfigured == true &&
        (isRemote ? connection?.hasModel(target?.modelId) == true : readyLocal);
    _generation.targetModel = target == null
        ? null
        : ChatModelOption(
            id: target.isRemote
                ? target.modelId ?? ''
                : asset?.runtimeId ?? target.assetId ?? '',
            displayName: target.isRemote
                ? target.modelId ?? ''
                : asset?.name ?? target.assetId ?? '',
            status: _generation.targetReady
                ? ChatModelStatus.loaded
                : ChatModelStatus.unloaded,
          );
    final key = jsonEncode([
      selectedSession?.id,
      assistant?.id,
      assistant?.revision,
      target?.toJson(),
      connection?.revision,
      runtime.isRunning,
      runtime.isBusy,
      runtime.activeModelId,
      _generation.targetReady,
    ]);
    if (key != _bindingKey) {
      _bindingKey = key;
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    }
  }

  Future<ChatRunConfig> _configuration() async {
    final assistants = _assistants!, runtime = _runtime!;
    final selected = currentAssistant, target = currentTarget;
    if (selected == null) {
      throw StateError('Select an assistant for this conversation');
    }
    if (target?.isConfigured != true) {
      throw StateError('Select an available model for this conversation');
    }
    final copy = Assistant.fromJson(selected.toJson());
    final remote = target!.isRemote;
    if (!remote &&
        (!runtime.isRunning ||
            runtime.activeModelId != targetAsset?.runtimeId ||
            runtime.activeEngine.storageValue != targetAsset?.engine)) {
      throw StateError('The selected local model is not running');
    }
    final connection = remote
        ? assistants.connection(target.connectionId)
        : AiConnection(
            id: 'local',
            name: runtime.activeEngine.displayName,
            protocol: AiProtocol.openai,
            baseUrl: '${runtime.baseUrl}/v1',
          );
    if (connection == null) {
      throw StateError('Connection missing; select another model');
    }
    final modelId = remote
        ? target.modelId!
        : (runtime.activeModelName ?? targetAsset!.runtimeId);
    final key = remote
        ? await assistants.credential(connection)
        : runtime.apiKey;
    if (connection.secretRef != null && key.isEmpty) {
      throw StateError('Credential unavailable; enter it again');
    }
    return ChatRunConfig(
      assistant: copy,
      connection: connection,
      key: key,
      modelId: modelId,
      isLocal: !remote,
      target: target,
    );
  }

  // Serialize conversation writes so a delayed rename/message edit cannot
  // overwrite a newly selected model or assistant with its earlier record.
  Future<void> _changeConversation(Future<void> Function() write) async {
    _changingSettings = true;
    notifyListeners();
    try {
      await write();
    } finally {
      _changingSettings = false;
      _refreshBinding();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> selectAssistant(String id) async {
    if (!canManageSessions) return;
    final assistants = _assistants;
    final assistant = assistants?.assistants
        .where((a) => a.id == id)
        .firstOrNull;
    if (assistant == null) throw StateError('Assistant unavailable');
    await _changeConversation(() async {
      await assistants!.select(id);
      _draftAssistantId = id;
      _draftInitialized = true;
      _conversation.clearSelection();
      _sessionList.updateQuery('');
      _refreshBinding();
    });
  }

  Future<void> selectTarget(
    ChatTarget target, {
    bool startLocal = false,
  }) async {
    if (!canManageSessions) return;
    if (!target.isConfigured) throw StateError('Choose a model');
    await _changeConversation(() async {
      if (target.isRemote) {
        if (_assistants
                ?.connection(target.connectionId)
                ?.hasModel(target.modelId) !=
            true) {
          throw StateError('Connection unavailable');
        }
      } else {
        final asset = await _assistants?.models.asset(target.assetId!);
        if (asset?.isReady != true || asset?.kind != AssetKind.llm) {
          throw StateError('Local model unavailable');
        }
        final runtime = _runtime;
        if (startLocal &&
            runtime?.isPublished == true &&
            (runtime!.activeModelId != asset!.runtimeId ||
                runtime.activeEngine.storageValue != asset.engine)) {
          throw StateError(
            'Stop the published LLM service before changing its model',
          );
        }
      }
      final assistantId = currentAssistantId;
      if (assistantId == null) throw StateError('Assistant unavailable');
      await _assistants!.setChatTarget(assistantId, target);
      _refreshBinding();
      AppLogger.instance.event(
        'client.assistant.model_selected',
        channel: LogChannel.client,
        fields: {
          'assistant': assistantId,
          'local': !target.isRemote,
          'connection': target.connectionId,
        },
      );
      if (startLocal && !target.isRemote) await _prepareLocalTarget();
    });
  }

  Future<void> reassignAssistant(String sessionId, String assistantId) async {
    if (!canManageSessions) return;
    final session = _sessionList.findSession(sessionId);
    if (session == null ||
        _assistants?.assistants.any((a) => a.id == assistantId) != true) {
      throw StateError('Conversation or assistant unavailable');
    }
    await _changeConversation(() async {
      final updated = session.copyWith(assistantId: assistantId);
      await _repository.saveSession(updated);
      _sessionList.upsertSession(updated);
      _refreshBinding();
      AppLogger.instance.event(
        'client.conversation.assistant_changed',
        channel: LogChannel.client,
        fields: {'conversation': sessionId, 'assistant': assistantId},
      );
    });
  }

  Future<void> prepareLocalTarget() async {
    if (!canManageSessions) return;
    await _prepareLocalTarget();
  }

  Future<void> _prepareLocalTarget() async {
    final runtime = _runtime, assistants = _assistants;
    final target = currentTarget;
    if (runtime == null || assistants == null || target?.isRemote == true) {
      return;
    }
    if (target?.assetId == null) throw StateError('Choose a local model');
    _preparingLocal = true;
    notifyListeners();
    try {
      final asset = await assistants.models.asset(target!.assetId!);
      if (asset == null || !asset.isReady || asset.kind != AssetKind.llm) {
        throw StateError('Local model unavailable');
      }
      if (runtime.isRunning &&
          runtime.activeEngine.storageValue == asset.engine &&
          runtime.activeModelId == asset.runtimeId) {
        return;
      }
      if (runtime.isPublished) {
        throw StateError(
          'Stop the published LLM service before changing its model',
        );
      }
      if (runtime.canStop) await runtime.stop();
      if (!runtime.canSwitchEngine || runtime.isBusy) {
        throw StateError('Local runtime is busy');
      }
      await runtime.switchEngine(
        InferenceEngine.fromStorageValue(asset.engine),
      );
      await runtime.selectModel(asset.runtimeId);
      await runtime.startPrivate();
      if (!runtime.isRunning) {
        throw StateError(
          runtime.lastError?.detail ?? 'Local model startup failed',
        );
      }
    } finally {
      _preparingLocal = false;
      _refreshBinding();
      if (!_disposed) notifyListeners();
    }
  }

  final ChatSessionRepository _repository;
  final LlamaChatApiClient _apiClient;

  late final ChatIdGenerator _idGenerator;
  late final ChatSessionListController _sessionList;
  late final ChatConversationController _conversation;
  late final ChatModelController _models;
  late final ChatRunner _generation;

  @visibleForTesting
  LlamaChatApiClient get apiClient => _apiClient;

  StreamingChatMessageNotifier get streamingMessages =>
      _generation.streamingMessages;

  List<ChatSessionRecord> get sessions => _sessionList.sessions;
  List<ChatModelOption> get models => _models.models;

  bool get isLoading => _sessionList.isLoading;
  bool get isLoadingMessages => _conversation.isLoadingMessages;
  bool get isLoadingOlderMessages => _conversation.isLoadingOlderMessages;
  bool get isServerRunning => _models.isServerRunning;
  bool get isSending => _generation.isSending;
  String get sessionQuery => _sessionList.query;
  String? get currentModelId => currentModel?.id;
  String? get draftMessageId => _generation.draftMessageId;
  String? get lastErrorMessage => _generation.lastErrorMessage;
  List<String> get pendingImageAttachments =>
      _generation.pendingImageAttachments;

  bool get canManageSessions =>
      !isLoading &&
      _creatingConversation == null &&
      !_changingSettings &&
      !_preparingLocal &&
      _generation.canManageSessions;
  bool get canSelectModels => canManageSessions && _generation.canSelectModels;
  bool get canSend =>
      canManageSessions && !isLoadingMessages && _generation.canSend;

  bool get canSubmitInput =>
      canSend ||
      (hasAssistantContext &&
          currentAssistant != null &&
          currentTarget == null &&
          canManageSessions &&
          !isLoadingMessages);

  bool get canAttachImages =>
      (!hasAssistantContext || currentTarget != null) &&
      (!isRemote ||
          (_assistants
                  ?.connection(currentTarget?.connectionId)
                  ?.capabilitiesFor(currentTarget?.modelId ?? '')
                  .supportsImages ??
              false));
  bool get canManageMessages =>
      canManageSessions && !isLoadingMessages && _generation.canManageMessages;

  ChatSessionRecord? get selectedSession => _conversation.selectedSession;
  bool get isShowingDraftSession => _conversation.isShowingDraftSession;
  String get currentSessionTitle =>
      selectedSession?.title ?? defaultSessionTitle;

  bool get hasOlderMessages => _conversation.hasOlderMessages;

  ChatModelOption? get currentModel =>
      hasAssistantContext ? _generation.targetModel : _models.currentModel;
  List<ChatMessageRecord> get visibleMessages => _conversation.visibleMessages;
  int get visibleMessagesRevision => _conversation.visibleMessagesRevision;
  List<ChatSessionRecord> get filteredSessions => _sessionList.filteredSessions;
  List<ChatSessionRecord> get assistantSessions => hasAssistantContext
      ? filteredSessions
            .where((s) => s.assistantId == currentAssistantId)
            .toList()
      : filteredSessions;

  Future<void> load() async {
    await _loadDrafts();
    await _sessionList.load();
    _refreshBinding();
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

  Future<void> createSession() async {
    if (!canManageSessions || _conversation.selectedSessionId == null) {
      return;
    }
    final assistant = currentAssistant ?? _assistants?.active;
    _draftAssistantId = assistant?.id;
    _conversation.clearSelection();
  }

  Future<void> renameSession(String sessionId, String title) async {
    if (!canManageSessions) {
      return;
    }
    await _changeConversation(
      () => _sessionList.renameSession(sessionId, title),
    );
  }

  Future<int> countUsingConnection(String id) =>
      _repository.countUsingConnection(id);

  /// The single assistant deletion entry point, sharing the conversation lock.
  Future<void> deleteAssistant(String assistantId) async {
    if (!canManageSessions) return;
    final assistants = _assistants;
    if (assistants == null) throw StateError('Assistant unavailable');
    await _changeConversation(() async {
      // Also persist adoption of any legacy unowned draft before deleting its
      // assistant; a crash after commit must not adopt that draft again.
      await flushDrafts();
      // Drain earlier saves and suspend debounce writes until memory matches
      // the committed deletion, so stale drafts cannot be written back.
      _deletingAssistant = true;
      try {
        await _loadDrafts();
        await _draftWrites;
        final ids = await _repository.deleteAssistantAndSessions(assistantId);
        _forgetDeletedSessions(ids, assistantId: assistantId);
        await assistants.load();
        if (_draftAssistantId == assistantId) {
          _draftAssistantId = assistants.activeId;
        }
        _syncDraftImages();
        AppLogger.instance.event(
          'client.assistant.deleted',
          channel: LogChannel.client,
          fields: {'assistant': assistantId, 'conversations': ids.length},
        );
      } finally {
        _deletingAssistant = false;
        await flushDrafts();
      }
    });
  }

  void _forgetDeletedSessions(Set<String> ids, {String? assistantId}) {
    final keys = {
      ...ids,
      if (assistantId != null) _assistantDraftKey(assistantId),
    };
    for (final key in keys) {
      _drafts.remove(key);
      _attachmentDrafts.remove(key);
    }
    if (keys.contains(_attachmentContext)) {
      _attachmentContext = null;
      _generation.replaceImageAttachments(const [], notify: false);
    }
    _sessionList.removeSessions(ids, notify: false);
    _conversation.forgetSessions(ids, notify: false);
  }

  Future<void> deleteSession(String sessionId) async {
    if (!canManageSessions || _sessionList.findSession(sessionId) == null) {
      return;
    }
    await _changeConversation(() async {
      await _repository.deleteSession(sessionId);
      _forgetDeletedSessions({sessionId});
      _syncDraftImages();
      await flushDrafts();
    });
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

  Future<void> sendMessage(
    String text, {
    List<String>? imageAttachments,
  }) async {
    if (_creatingConversation != null) await _creatingConversation;
    if (!canSend) return;
    final key = draftKey;
    final submittedDraft = draftFor(key);
    await _generation.sendMessage(
      text,
      imageAttachments: imageAttachments,
      onCommitted: () {
        var destination = key;
        if (selectedSession != null && key != selectedSession!.id) {
          destination = selectedSession!.id;
          _moveDraft(key, destination);
        }
        if (draftFor(destination) == submittedDraft &&
            submittedDraft.trim() == text.trim()) {
          updateDraft('', key: destination);
        }
        unawaited(flushDrafts());
      },
    );
  }

  bool canRegenerateMessage(String messageId) {
    return canManageMessages && _generation.canRegenerateMessage(messageId);
  }

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    if (!canManageMessages) return;
    await _changeConversation(
      () =>
          _generation.editMessage(messageId: messageId, newContent: newContent),
    );
  }

  Future<void> deleteMessage(
    String messageId, {
    bool allVersions = true,
    ChatMessageRecord? expectedMessage,
  }) async {
    if (!canManageMessages) return;
    await _changeConversation(
      () => _generation.deleteMessage(
        messageId,
        allVersions: allVersions,
        expectedMessage: expectedMessage,
      ),
    );
  }

  Future<void> selectMessageVersion({
    required String messageId,
    required int versionIndex,
  }) async {
    if (!canManageMessages) return;
    await _changeConversation(
      () => _generation.selectMessageVersion(
        messageId: messageId,
        versionIndex: versionIndex,
      ),
    );
  }

  Future<void> regenerateFromMessage(
    String messageId, {
    bool executeTools = false,
  }) async {
    if (!canManageMessages) return;
    await _generation.regenerateFromMessage(
      messageId,
      executeTools: executeTools,
    );
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
    _disposed = true;
    _draftDebounce?.cancel();
    unawaited(flushDrafts());
    _sessionList.removeListener(_notify);
    _conversation.removeListener(_conversationChanged);
    _models.removeListener(_notify);
    _generation.removeListener(_notify);
    _generation.dispose();
    _models.dispose();
    _conversation.dispose();
    _sessionList.dispose();
    super.dispose();
  }
}
