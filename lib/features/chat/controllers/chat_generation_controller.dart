import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class ChatGenerationController extends ChangeNotifier {
  ChatGenerationController({
    required ChatSessionRepository repository,
    required LlamaChatApiClient apiClient,
    required ChatSessionListController sessionList,
    required ChatConversationController conversation,
    required ChatModelController models,
    required ChatIdGenerator idGenerator,
    required this.defaultSessionTitle,
  }) : _repository = repository,
       _apiClient = apiClient,
       _sessionList = sessionList,
       _conversation = conversation,
       _models = models,
       _idGenerator = idGenerator;

  final ChatSessionRepository _repository;
  final LlamaChatApiClient _apiClient;
  final ChatSessionListController _sessionList;
  final ChatConversationController _conversation;
  final ChatModelController _models;
  final ChatIdGenerator _idGenerator;
  final String defaultSessionTitle;
  final StreamingChatMessageNotifier streamingMessages =
      StreamingChatMessageNotifier();

  bool _isSending = false;
  bool _isDisposed = false;
  ChatMessageRecord? _draftAssistantMessage;
  CancelToken? _activeCancelToken;
  String? _lastErrorMessage;
  List<String> _pendingImageAttachments = <String>[];

  bool get isSending => _isSending;
  String? get draftMessageId => _draftAssistantMessage?.id;
  String? get lastErrorMessage => _lastErrorMessage;
  List<String> get pendingImageAttachments =>
      List<String>.unmodifiable(_pendingImageAttachments);

  bool get canManageSessions => !_isSending && _models.loadingModelId == null;
  bool get canSelectModels =>
      _models.isServerRunning && !_isSending && _models.loadingModelId == null;
  bool get canSend =>
      !_isSending &&
      _models.loadingModelId == null &&
      _models.isServerRunning &&
      _models.currentModel?.isLoaded == true;
  bool get canManageMessages => !_isSending && _models.loadingModelId == null;

  bool canRegenerateMessage(String messageId) {
    if (!canSend) {
      return false;
    }
    final visibleMessages = _conversation.visibleMessages;
    final targetIndex = _messageIndex(visibleMessages, messageId);
    if (targetIndex < 0) {
      return false;
    }
    final targetMessage = visibleMessages[targetIndex];
    if (targetMessage.role == ChatRole.user) {
      return true;
    }
    final sessionMessageIds =
        _conversation.selectedSession?.messageIds ?? const <String>[];
    final firstSessionMessageId = sessionMessageIds.isEmpty
        ? null
        : sessionMessageIds.first;
    return _nearestUserMessageIndex(visibleMessages, targetIndex) >= 0 ||
        firstSessionMessageId != targetMessage.id;
  }

  Future<void> sendMessage(
    String text, {
    List<String>? imageAttachments,
  }) async {
    if (!canSend) {
      return;
    }

    final model = _models.currentModel;
    final normalizedText = text.trim();
    if (model == null ||
        (normalizedText.isEmpty &&
            (imageAttachments == null || imageAttachments.isEmpty))) {
      return;
    }

    var selectedSession = _conversation.selectedSession;
    if (selectedSession == null) {
      selectedSession = _createSessionRecord();
      _conversation.startDraftSession(selectedSession.id, notify: false);
    }
    final session = selectedSession;

    await _runExclusive(() async {
      clearImageAttachments(notify: false);

      final now = DateTime.now();
      final userMessage = ChatMessageRecord(
        id: _idGenerator.generate('message'),
        role: ChatRole.user,
        content: normalizedText,
        createdAt: now,
        sessionId: session.id,
        modelName: model.displayName,
        imageFilePaths: imageAttachments ?? const <String>[],
      );

      final messages = await _repository.loadAllMessages(session);
      final sessionTitle = session.title == defaultSessionTitle
          ? _deriveSessionTitle(normalizedText)
          : session.title;
      final updatedMessages = <ChatMessageRecord>[...messages, userMessage];
      final updatedSession = session.copyWith(
        title: sessionTitle,
        messageIds: _idsOf(updatedMessages),
        updatedAt: now,
      );
      await _commitSession(
        updatedSession,
        changedMessages: <ChatMessageRecord>[userMessage],
        fullMessages: updatedMessages,
      );
      await _generateAssistantResponse(
        updatedSession,
        model,
        sessionMessages: updatedMessages,
      );
    });
  }

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    if (!canManageMessages) {
      return;
    }

    final session = _conversation.selectedSession;
    if (session == null || !session.messageIds.contains(messageId)) {
      return;
    }

    final normalizedContent = newContent.trim();
    if (normalizedContent.isEmpty) {
      return;
    }

    final message = await _repository.loadMessage(messageId);
    if (message == null || message.content == normalizedContent) {
      return;
    }

    if (message.versionIds.isNotEmpty && message.role == ChatRole.assistant) {
      final versionId = _selectedVersionId(message);
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

    final updatedMessage = message.copyWith(content: normalizedContent);
    await _commitSession(
      session.copyWith(updatedAt: DateTime.now()),
      changedMessages: <ChatMessageRecord>[updatedMessage],
    );
    _conversation.updateVisibleMessage(updatedMessage, notify: false);
    notifyListeners();
  }

  Future<void> deleteMessage(String messageId) async {
    if (!canManageMessages) {
      return;
    }

    final session = _conversation.selectedSession;
    if (session == null || !session.messageIds.contains(messageId)) {
      return;
    }

    final message = await _repository.loadMessage(messageId);
    if (message == null) {
      return;
    }

    await _repository.deleteMessages(<ChatMessageRecord>[message]);
    await _commitSession(
      session.copyWith(
        messageIds: session.messageIds
            .where((id) => id != messageId)
            .toList(growable: false),
        updatedAt: DateTime.now(),
      ),
    );
    _conversation.removeVisibleMessage(messageId, notify: false);
    notifyListeners();
  }

  Future<void> selectMessageVersion({
    required String messageId,
    required int versionIndex,
  }) async {
    if (!canManageMessages) {
      return;
    }

    final session = _conversation.selectedSession;
    if (session == null || !session.messageIds.contains(messageId)) {
      return;
    }

    final message = await _repository.loadMessage(messageId);
    if (message == null ||
        message.role != ChatRole.assistant ||
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

    final updatedMessage = _messageWithVersion(message, version, versionIndex);
    await _commitSession(
      session.copyWith(updatedAt: DateTime.now()),
      changedMessages: <ChatMessageRecord>[updatedMessage],
    );
    _conversation.updateVisibleMessage(updatedMessage, notify: false);
    notifyListeners();
  }

  Future<void> regenerateFromMessage(String messageId) async {
    if (!canRegenerateMessage(messageId)) {
      return;
    }

    final session = _conversation.selectedSession;
    final model = _models.currentModel;
    if (session == null || model == null) {
      return;
    }

    await _runExclusive(() async {
      final messages = await _repository.loadAllMessages(session);
      final targetIndex = _messageIndex(messages, messageId);
      if (targetIndex < 0) {
        return;
      }
      final userIndex = _nearestUserMessageIndex(messages, targetIndex);
      if (userIndex < 0) {
        return;
      }

      final targetMessage = messages[targetIndex];
      if (targetMessage.role == ChatRole.assistant) {
        await _regenerateAssistantMessageVersion(
          session: session,
          messages: messages,
          targetIndex: targetIndex,
          model: model,
        );
        return;
      }

      final retainedMessages = List<ChatMessageRecord>.from(
        messages.take(userIndex + 1),
      );
      await _repository.deleteMessages(messages.skip(userIndex + 1));

      final updatedSession = session.copyWith(
        messageIds: _idsOf(retainedMessages),
        updatedAt: DateTime.now(),
      );
      await _commitSession(updatedSession, fullMessages: retainedMessages);
      await _generateAssistantResponse(
        updatedSession,
        model,
        sessionMessages: retainedMessages,
      );
    });
  }

  Future<void> _regenerateAssistantMessageVersion({
    required ChatSessionRecord session,
    required List<ChatMessageRecord> messages,
    required int targetIndex,
    required ChatModelOption model,
  }) async {
    final targetMessage = messages[targetIndex];
    final promptMessages = List<ChatMessageRecord>.from(
      messages.take(targetIndex),
    );
    final retainedMessages = List<ChatMessageRecord>.from(
      messages.take(targetIndex + 1),
    );
    await _repository.deleteMessages(messages.skip(targetIndex + 1));

    var retainedTargetMessage = targetMessage;
    var versionIds = List<String>.from(targetMessage.versionIds);
    final changedMessages = <ChatMessageRecord>[];
    if (versionIds.isEmpty) {
      final originalVersion = _versionFromMessage(targetMessage);
      await _repository.saveMessageVersion(originalVersion);
      versionIds = <String>[originalVersion.id];
      retainedTargetMessage = targetMessage.copyWith(
        versionIds: versionIds,
        currentVersionIndex: 0,
      );
      retainedMessages[targetIndex] = retainedTargetMessage;
      changedMessages.add(retainedTargetMessage);
    }

    final fallbackSession = session.copyWith(
      messageIds: _idsOf(retainedMessages),
      updatedAt: DateTime.now(),
    );
    await _commitSession(
      fallbackSession,
      changedMessages: changedMessages,
      fullMessages: retainedMessages,
    );

    final now = DateTime.now();
    final nextVersion = ChatMessageVersionRecord(
      id: _idGenerator.generate('version'),
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
    final draftMessages = List<ChatMessageRecord>.from(retainedMessages);
    draftMessages[targetIndex] = retainedTargetMessage;

    await _generateAssistantResponse(
      fallbackSession.copyWith(updatedAt: now),
      model,
      sessionMessages: draftMessages,
      promptMessages: promptMessages,
      draftSeed: retainedTargetMessage,
      versionId: nextVersion.id,
      emptyDraftFallbackSession: fallbackSession,
      emptyDraftFallbackMessages: retainedMessages,
    );
  }

  void clearLastError() {
    _lastErrorMessage = null;
  }

  void cancelStreaming() {
    _activeCancelToken?.cancel('user canceled');
  }

  void cancelForServerStop() {
    _activeCancelToken?.cancel('server stopped');
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

  void clearImageAttachments({bool notify = true}) {
    if (_pendingImageAttachments.isEmpty) {
      return;
    }
    _pendingImageAttachments = <String>[];
    if (notify) {
      notifyListeners();
    }
  }

  /// Runs a generation flow under the sending mutex. The try/finally
  /// guarantees `_isSending` can never wedge on a thrown repository or
  /// network error.
  Future<void> _runExclusive(Future<void> Function() action) async {
    _isSending = true;
    try {
      await action();
    } finally {
      _isSending = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Persists one session change precisely: only the changed message
  /// records plus the session record itself, then syncs in-memory state.
  /// Pass [fullMessages] when the message structure changed so the visible
  /// window can be re-derived.
  Future<void> _commitSession(
    ChatSessionRecord session, {
    List<ChatMessageRecord> changedMessages = const <ChatMessageRecord>[],
    List<ChatMessageRecord>? fullMessages,
  }) async {
    for (final message in changedMessages) {
      await _repository.saveMessage(message);
    }
    await _repository.saveSession(session);
    _sessionList.upsertSession(session, notify: false);
    if (fullMessages != null) {
      _conversation.syncVisibleMessagesFromFullMessages(
        session.id,
        fullMessages,
        notify: false,
      );
    }
  }

  List<String> _idsOf(List<ChatMessageRecord> messages) {
    return messages.map((message) => message.id).toList(growable: false);
  }

  Future<void> _generateAssistantResponse(
    ChatSessionRecord session,
    ChatModelOption model, {
    required List<ChatMessageRecord> sessionMessages,
    List<ChatMessageRecord>? promptMessages,
    ChatMessageRecord? draftSeed,
    String? versionId,
    ChatSessionRecord? emptyDraftFallbackSession,
    List<ChatMessageRecord>? emptyDraftFallbackMessages,
  }) async {
    final draftMessage =
        draftSeed ??
        ChatMessageRecord(
          id: _idGenerator.generate('draft'),
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime.now(),
          sessionId: session.id,
          modelName: model.displayName,
          reasoningContent: '',
        );
    _draftAssistantMessage = draftMessage;
    _activeCancelToken = CancelToken();
    streamingMessages.update(draftMessage, isStreaming: true);

    var currentMessages = _messagesWithStreamingDraft(
      sessionMessages,
      draftMessage,
      appendIfMissing: draftSeed == null,
    );
    var currentSession = session.copyWith(
      messageIds: _idsOf(currentMessages),
      updatedAt: DateTime.now(),
    );
    await _saveDraftVersion(draftMessage, versionId);
    await _commitSession(
      currentSession,
      changedMessages: <ChatMessageRecord>[draftMessage],
      fullMessages: currentMessages,
    );
    if (_isDisposed) {
      // Not yet inside the try/finally below — clean up inline.
      _draftAssistantMessage = null;
      _activeCancelToken = null;
      return;
    }
    notifyListeners();

    try {
      await for (final delta in _apiClient.streamChatCompletion(
        modelId: model.id,
        messages: promptMessages ?? sessionMessages,
        cancelToken: _activeCancelToken!,
      )) {
        if (_isDisposed) {
          return;
        }
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
        streamingMessages.update(_draftAssistantMessage!, isStreaming: true);
        currentMessages = _messagesWithStreamingDraft(
          currentMessages,
          _draftAssistantMessage!,
          appendIfMissing: draftSeed == null,
        );
        // Hot path: persist only the draft message (and its version record)
        // per delta. The session record and sibling messages are unchanged.
        await _persistDraftDelta(_draftAssistantMessage!, versionId);
      }
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) {
        // User-initiated cancellation leaves any partial draft intact.
      } else if (!_isDisposed) {
        final draft = _draftAssistantMessage;
        final errorMessage = _chatErrorMessage(error);
        if (draft != null && draft.content.trim().isNotEmpty) {
          _lastErrorMessage = errorMessage;
        } else {
          _draftAssistantMessage = ChatMessageRecord(
            id: draft?.id ?? _idGenerator.generate('error'),
            role: ChatRole.assistant,
            content: errorMessage,
            createdAt: DateTime.now(),
            sessionId: session.id,
            modelName: _models.currentModel?.displayName,
            versionIds: draft?.versionIds ?? const <String>[],
            currentVersionIndex: draft?.currentVersionIndex ?? 0,
          );
          streamingMessages.update(_draftAssistantMessage!, isStreaming: true);
          currentMessages = _messagesWithStreamingDraft(
            currentMessages,
            _draftAssistantMessage!,
            appendIfMissing: draftSeed == null,
          );
          currentSession = currentSession.copyWith(
            messageIds: _idsOf(currentMessages),
            updatedAt: DateTime.now(),
          );
          await _commitSession(
            currentSession,
            changedMessages: <ChatMessageRecord>[_draftAssistantMessage!],
            fullMessages: currentMessages,
          );
        }
      }
    } finally {
      if (_isDisposed) {
        _draftAssistantMessage = null;
        _activeCancelToken = null;
      } else {
        final draft = _draftAssistantMessage;
        final hasDraftContent =
            draft != null && draft.content.trim().isNotEmpty;
        final hasDraftReasoning =
            draft != null &&
            (draft.reasoningContent?.trim().isNotEmpty ?? false);
        if (draft != null && !hasDraftContent && !hasDraftReasoning) {
          if (versionId != null) {
            await _repository.deleteMessageVersions(<String>[versionId]);
            final fallbackSession = emptyDraftFallbackSession;
            final fallbackMessages = emptyDraftFallbackMessages;
            if (fallbackSession != null && fallbackMessages != null) {
              // The per-delta hot path already wrote the draft over the
              // target record, so the original must be restored explicitly.
              await _commitSession(
                fallbackSession,
                changedMessages: fallbackMessages
                    .where((message) => message.id == draft.id)
                    .toList(growable: false),
                fullMessages: fallbackMessages,
              );
            }
          } else {
            final cleanedMessages = _messagesWithoutMessage(
              currentMessages,
              draft.id,
            );
            await _repository.deleteMessages(<ChatMessageRecord>[draft]);
            await _commitSession(
              currentSession.copyWith(
                messageIds: _idsOf(cleanedMessages),
                updatedAt: DateTime.now(),
              ),
              fullMessages: cleanedMessages,
            );
          }
          streamingMessages.remove(draft.id);
        } else if (draft != null) {
          currentMessages = _messagesWithStreamingDraft(
            currentMessages,
            draft,
            appendIfMissing: draftSeed == null,
          );
          await _saveDraftVersion(draft, versionId);
          await _commitSession(
            currentSession.copyWith(updatedAt: DateTime.now()),
            changedMessages: <ChatMessageRecord>[draft],
            fullMessages: currentMessages,
          );
          streamingMessages.update(draft, isStreaming: false);
          // Drop the streaming entry so the bubble renders from the
          // persisted record again — otherwise later edits or version
          // switches would be shadowed by the stale streaming snapshot.
          streamingMessages.remove(draft.id);
        }

        _draftAssistantMessage = null;
        _activeCancelToken = null;
      }
    }
  }

  /// Per-delta persistence: writes only the streaming draft message and,
  /// when regenerating, its version record. Keeps every delta durable
  /// without rewriting the session record or sibling messages.
  Future<void> _persistDraftDelta(
    ChatMessageRecord draft,
    String? versionId,
  ) async {
    await _repository.saveMessage(draft);
    await _saveDraftVersion(draft, versionId);
  }

  Future<void> _saveDraftVersion(
    ChatMessageRecord draft,
    String? versionId,
  ) async {
    if (versionId == null) {
      return;
    }
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

  List<ChatMessageRecord> _messagesWithStreamingDraft(
    List<ChatMessageRecord> messages,
    ChatMessageRecord draft, {
    required bool appendIfMissing,
  }) {
    final nextMessages = List<ChatMessageRecord>.from(messages);
    final index = _messageIndex(nextMessages, draft.id);
    if (index >= 0) {
      nextMessages[index] = draft;
    } else if (appendIfMissing) {
      nextMessages.add(draft);
    } else {
      return messages;
    }
    return nextMessages;
  }

  List<ChatMessageRecord> _messagesWithoutMessage(
    List<ChatMessageRecord> messages,
    String messageId,
  ) {
    return List<ChatMessageRecord>.from(messages)
      ..removeWhere((message) => message.id == messageId);
  }

  ChatSessionRecord _createSessionRecord() {
    final now = DateTime.now();
    return ChatSessionRecord(
      id: _idGenerator.generate('session'),
      title: defaultSessionTitle,
      messageIds: const <String>[],
      createdAt: now,
      updatedAt: now,
    );
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
      id: _idGenerator.generate('version'),
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

  String _chatErrorMessage(Object error) {
    return 'Request Failed: $error';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeCancelToken?.cancel('disposed');
    streamingMessages.dispose();
    super.dispose();
  }
}
