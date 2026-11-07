import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:crypto/crypto.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_checkpoint_writer.dart';
import 'package:servllama/features/chat/controllers/chat_id_generator.dart';
import 'package:servllama/features/chat/controllers/chat_model_controller.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/repositories/chat_record_codec.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class ChatRunner extends ChangeNotifier {
  ChatRunner({
    required ChatSessionRepository repository,
    required LlamaChatApiClient apiClient,
    required ChatSessionListController sessionList,
    required ChatConversationController conversation,
    required ChatModelController models,
    required ChatIdGenerator idGenerator,
    required this.defaultSessionTitle,
    AppLogger? logger,
    ChatProtocolClient? protocolClient,
  }) : _logger = logger ?? AppLogger.instance,
       _protocol = protocolClient ?? ChatProtocolClient(logger: logger),
       _repository = repository,
       _apiClient = apiClient,
       _sessionList = sessionList,
       _conversation = conversation,
       _models = models,
       _idGenerator = idGenerator;

  final ChatSessionRepository _repository;
  final AppLogger _logger;
  final LlamaChatApiClient _apiClient;
  final ChatSessionListController _sessionList;
  final ChatConversationController _conversation;
  final ChatModelController _models;
  final ChatIdGenerator _idGenerator;
  final String defaultSessionTitle;
  final StreamingChatMessageNotifier streamingMessages =
      StreamingChatMessageNotifier();

  Future<ChatRunConfig> Function()? configuration;
  ChatSessionRecord Function(ChatSessionRecord)? initializeSession;
  bool Function(ChatRunConfig)? isAuthorized;
  void revalidateAuthorization() {
    final config = _activeConfig;
    if (_isSending && config != null && isAuthorized?.call(config) == false) {
      _cancel('configuration_revoked');
    }
  }

  ChatModelOption? targetModel;
  bool isRemote = false;
  bool targetReady = true;
  String? _runId;
  String? _stopReason;
  String? _stopConversationId;
  String? _conversationId;
  ChatRunConfig? _activeConfig;
  final List<AiTurn> _trace = [];
  String? _inputContextKey, _finalAnswer;
  final ChatProtocolClient _protocol;
  ChatCheckpointWriter? _checkpoints;
  GenerationRunRepository? get _runs => AppDatabase.current == null
      ? null
      : GenerationRunRepository(AppDatabase.current!);
  ChatModelOption? get _model => targetModel ?? _models.currentModel;
  bool _isSending = false;
  bool _isDisposed = false;
  ChatMessageRecord? _draftAssistantMessage;
  CancelToken? _activeCancelToken;
  String? _lastErrorMessage;
  List<String> _pendingImageAttachments = <String>[];

  bool get isSending => _isSending;
  String? get stopReason =>
      _isSending || _conversation.selectedSession?.id != _stopConversationId
      ? null
      : _stopReason;
  String? get draftMessageId => _draftAssistantMessage?.id;
  String? get lastErrorMessage => _lastErrorMessage;
  List<String> get pendingImageAttachments =>
      List<String>.unmodifiable(_pendingImageAttachments);

  bool get canManageSessions => !_isSending;
  bool get canSelectModels => !_isSending;
  bool get canSend =>
      !_isSending &&
      targetReady &&
      (isRemote || _models.isServerRunning) &&
      _model?.isLoaded == true;
  bool get canManageMessages => !_isSending;

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
    VoidCallback? onCommitted,
  }) async {
    if (!canSend) {
      return;
    }

    final model = _model;
    final normalizedText = text.trim();
    if (model == null ||
        (normalizedText.isEmpty &&
            (imageAttachments == null || imageAttachments.isEmpty))) {
      return;
    }

    var selectedSession = _conversation.selectedSession;
    if (selectedSession == null) {
      selectedSession = _createSessionRecord();
      selectedSession =
          initializeSession?.call(selectedSession) ?? selectedSession;
      _conversation.startDraftSession(selectedSession.id, notify: false);
    }
    final session = selectedSession;

    await _runExclusive(() async {
      final now = DateTime.now();
      final messageId = _idGenerator.generate('message');
      final userMessage = ChatMessageRecord(
        id: messageId,
        role: ChatRole.user,
        content: normalizedText,
        createdAt: now,
        sessionId: session.id,
        modelName: model.displayName,
        imageFilePaths: imageAttachments ?? const <String>[],
        versionIds: ['$messageId:initial'],
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
      clearImageAttachments(notify: false);
      onCommitted?.call();
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

    final ids = List<String>.from(message.versionIds);
    final edited = _versionFromMessage(
      message.copyWith(
        content: normalizedContent,
        clearReasoningContent: true,
        clearRunId: true,
        clearGenerationMetrics: true,
        createdAt: DateTime.now(),
      ),
    );
    final updatedSession = session.copyWith(updatedAt: DateTime.now());
    late ChatMessageRecord updatedMessage;
    await _atomic(() async {
      if (ids.isEmpty) {
        final original = _versionFromMessage(message);
        await _repository.saveMessageVersion(original);
        ids.add(original.id);
      }
      await _repository.saveMessageVersion(edited);
      ids.add(edited.id);
      updatedMessage = message
          .copyWith(versionIds: ids)
          .withVersion(edited, ids.length - 1);
      await _repository.commitSession(
        updatedSession,
        changedMessages: [updatedMessage],
      );
    });
    _publishSession(updatedSession);
    _conversation.updateVisibleMessage(updatedMessage, notify: false);
    notifyListeners();
  }

  Future<void> deleteMessage(
    String messageId, {
    bool allVersions = true,
    ChatMessageRecord? expectedMessage,
  }) async {
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
    if (expectedMessage != null &&
        jsonEncode(encodeMessage(message)) !=
            jsonEncode(encodeMessage(expectedMessage))) {
      throw StateError('Message changed before deletion');
    }
    ChatMessageRecord? replacement;
    if (!allVersions && message.hasMultipleVersions) {
      final ids = List<String>.from(message.versionIds)
        ..removeAt(message.currentVersionIndex);
      final index = (message.currentVersionIndex - 1).clamp(0, ids.length - 1);
      final version = await _repository.loadMessageVersion(ids[index]);
      if (version == null || version.messageId != message.id) {
        throw StateError('Message version missing');
      }
      replacement = message
          .copyWith(versionIds: ids)
          .withVersion(version, index);
    }
    final updatedSession = replacement == null
        ? session.copyWith(
            messageIds: session.messageIds
                .where((id) => id != messageId)
                .toList(growable: false),
            updatedAt: DateTime.now(),
          )
        : session.copyWith(updatedAt: DateTime.now());
    await _repository.commitMessageDeletion(
      updatedSession,
      message,
      replacement: replacement,
    );
    _sessionList.upsertSession(updatedSession, notify: false);
    if (replacement == null) {
      _conversation.removeVisibleMessage(messageId, notify: false);
    } else {
      _conversation.updateVisibleMessage(replacement, notify: false);
    }
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

    final updatedMessage = message.withVersion(version, versionIndex);
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
    final model = _model;
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
      final updatedSession = session.copyWith(
        messageIds: _idsOf(retainedMessages),
        updatedAt: DateTime.now(),
      );
      await _commitSession(updatedSession, fullMessages: retainedMessages);
      if (_runs != null) await _repository.cleanupFiles();
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
    final retainedMessages = List<ChatMessageRecord>.from(messages);

    var retainedTargetMessage = targetMessage;
    var versionIds = List<String>.from(targetMessage.versionIds);
    final changedMessages = <ChatMessageRecord>[];
    late ChatSessionRecord fallbackSession;
    await _atomic(() async {
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
      fallbackSession = session.copyWith(
        messageIds: _idsOf(retainedMessages),
        updatedAt: DateTime.now(),
      );
      await _repository.commitSession(
        fallbackSession,
        changedMessages: changedMessages,
      );
    });
    _publishSession(fallbackSession, fullMessages: retainedMessages);

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
    _cancel('user_cancelled');
  }

  void cancelForServerStop() {
    if (!(_activeConfig?.isLocal ?? !isRemote)) return;
    _cancel('server_stopped');
  }

  void _cancel(String reason) {
    final token = _activeCancelToken;
    if (token == null || token.isCancelled) return;
    _logger.event(
      'client.run.cancel_requested',
      channel: LogChannel.client,
      fields: {
        'run': _runId,
        'conversation': _conversationId,
        'reason': reason,
      },
    );
    token.cancel(reason);
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

  void replaceImageAttachments(List<String> paths, {bool notify = true}) {
    _pendingImageAttachments = List.of(paths);
    if (notify) notifyListeners();
  }

  /// Runs a generation flow under the sending mutex. The try/finally
  /// guarantees `_isSending` can never wedge on a thrown repository or
  /// network error.
  Future<void> _runExclusive(Future<void> Function() action) async {
    _isSending = true;
    notifyListeners();
    final foreground = ForegroundTaskService()..init();
    try {
      await foreground.acquire(
        owner: 'chat',
        notificationTitle: 'ServLlama',
        notificationText: _model?.displayName ?? 'ServLlama',
      );
      await action();
    } catch (error) {
      _logger.event(
        'client.action.failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
      rethrow;
    } finally {
      await foreground.release('chat');
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
    await _repository.commitSession(session, changedMessages: changedMessages);
    _publishSession(session, fullMessages: fullMessages);
  }

  Future<T> _atomic<T>(Future<T> Function() action) =>
      _runs?.db.transaction(action) ?? action();

  void _publishSession(
    ChatSessionRecord session, {
    List<ChatMessageRecord>? fullMessages,
  }) {
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
    _activeConfig = await configuration?.call();
    _checkpoints = ChatCheckpointWriter();
    final assistant = _activeConfig?.assistant;
    final author = assistant == null
        ? null
        : MessageAuthor(assistantId: assistant.id, name: assistant.name);
    _trace.clear();
    _inputContextKey = _finalAnswer = null;
    _runId = newId();
    final watch = Stopwatch()..start();
    final logFields = <String, Object?>{
      'run': _runId,
      'conversation': session.id,
      'assistant': _activeConfig?.assistant.id,
      'connection': _activeConfig?.connection.id,
      'model': _activeConfig?.modelId ?? model.id,
      'local': _activeConfig?.isLocal ?? !isRemote,
      'regenerate': draftSeed != null,
    };
    Object? failure;
    _conversationId = session.id;
    _stopReason = null;
    _stopConversationId = session.id;
    final completedVersionId = versionId ?? _idGenerator.generate('version');
    final draftVersionIds = [...?draftSeed?.versionIds];
    if (!draftVersionIds.contains(completedVersionId)) {
      draftVersionIds.add(completedVersionId);
    }
    final draftMessage =
        (draftSeed ??
                ChatMessageRecord(
                  id: _idGenerator.generate('draft'),
                  role: ChatRole.assistant,
                  content: '',
                  createdAt: DateTime.now(),
                  sessionId: session.id,
                  modelName: model.displayName,
                  reasoningContent: '',
                ))
            .copyWith(
              runId: _runId,
              clearGenerationMetrics: true,
              author: author,
              clearAuthor: author == null,
              versionIds: draftVersionIds,
              currentVersionIndex: draftVersionIds.indexOf(completedVersionId),
            );
    _draftAssistantMessage = draftMessage;
    _activeCancelToken = CancelToken();
    var began = false;
    var terminalState = 'completed';
    GenerationMetrics? completedMetrics;
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
    try {
      final fallback = emptyDraftFallbackMessages
          ?.where((m) => m.id == draftSeed?.id)
          .firstOrNull;
      await _atomic(() async {
        await _runs?.begin(_runId!, session.id, {
          ...?_activeConfig?.snapshot(),
          'modelId': _activeConfig?.modelId ?? model.id,
          'versionId': completedVersionId,
          if (fallback != null && fallback.versionIds.isNotEmpty)
            'fallbackVersionId':
                fallback.versionIds[fallback.currentVersionIndex],
        });
        await _repository.commitSession(
          currentSession,
          changedMessages: [draftMessage],
        );
      });
      began = true;
      _publishSession(currentSession, fullMessages: currentMessages);
      _logger.event(
        'client.run.started',
        channel: LogChannel.client,
        fields: logFields,
      );
      if (_isDisposed) {
        return;
      }
      notifyListeners();

      await for (final delta in _response(
        model.id,
        promptMessages ?? sessionMessages,
        _activeCancelToken!,
      )) {
        if (_isDisposed) {
          return;
        }
        completedMetrics = delta.generationMetrics ?? completedMetrics;
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
        // Publish every delta immediately; coalesce durable draft checkpoints.
        await _persistDraftDelta(_draftAssistantMessage!);
      }
    } catch (error) {
      failure = error;
      if (!began) {
        terminalState = 'failed';
        rethrow;
      }
      if (error is DioException && CancelToken.isCancel(error)) {
        terminalState = 'cancelled';
        // User-initiated cancellation leaves any partial draft intact.
      } else if (!_isDisposed) {
        terminalState = 'failed';
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
            modelName: _model?.displayName,
            runId: _runId,
            author: author,
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
        }
      }
    } finally {
      if (_activeCancelToken?.isCancelled == true) terminalState = 'cancelled';
      _draftAssistantMessage = _draftAssistantMessage?.copyWith(
        generationMetrics: terminalState == 'completed' && !_isDisposed
            ? completedMetrics?.withIdentity(
                modelId: _activeConfig?.modelId ?? model.id,
                connectionId: _activeConfig?.connection.id,
                contextKey: _inputContextKey,
              )
            : null,
        clearGenerationMetrics:
            terminalState != 'completed' ||
            _isDisposed ||
            completedMetrics == null,
      );
      try {
        if (began && _draftAssistantMessage != null) {
          await _persistDraftDelta(_draftAssistantMessage!, flush: true);
        } else {
          await _checkpoints?.flush();
        }
        if (began && !_isDisposed) {
          final draft = _draftAssistantMessage;
          final hasDraftContent =
              draft != null && draft.content.trim().isNotEmpty;
          final hasDraftReasoning =
              draft != null &&
              (draft.reasoningContent?.trim().isNotEmpty ?? false);
          final hasDraftTools =
              draft != null &&
              !hasDraftContent &&
              !hasDraftReasoning &&
              (await _runs?.hasToolInvocations(_runId!) ?? false);
          ChatMessageRecord? finalized;
          await _atomic(() async {
            if (draft != null &&
                !hasDraftContent &&
                !hasDraftReasoning &&
                !hasDraftTools) {
              if (versionId != null &&
                  emptyDraftFallbackSession != null &&
                  emptyDraftFallbackMessages != null) {
                currentSession = emptyDraftFallbackSession;
                currentMessages = emptyDraftFallbackMessages;
                await _repository.commitSession(
                  currentSession,
                  changedMessages: currentMessages
                      .where((m) => m.id == draft.id)
                      .toList(),
                );
                await _repository.deleteMessageVersions([versionId]);
              } else {
                currentMessages = _messagesWithoutMessage(
                  currentMessages,
                  draft.id,
                );
                currentSession = currentSession.copyWith(
                  messageIds: _idsOf(currentMessages),
                  updatedAt: DateTime.now(),
                );
                await _repository.deleteMessages([draft]);
                await _repository.commitSession(currentSession);
              }
            } else if (draft != null) {
              finalized = await _saveDraftVersion(draft, completedVersionId);
              currentMessages = _messagesWithStreamingDraft(
                currentMessages,
                finalized!,
                appendIfMissing: draftSeed == null,
              );
              currentSession = currentSession.copyWith(
                updatedAt: DateTime.now(),
              );
              await _repository.commitSession(
                currentSession,
                changedMessages: [finalized!],
              );
            }
            await _runs?.finish(
              _runId!,
              terminalState == 'completed'
                  ? (_stopReason ?? terminalState)
                  : terminalState,
            );
            await _runs?.deleteUnreferenced([_runId!]);
          });
          // Publish only after the body, selection and terminal Run commit.
          _publishSession(currentSession, fullMessages: currentMessages);
          if (finalized != null) {
            streamingMessages.update(finalized!, isStreaming: false);
          }
          if (draft != null) streamingMessages.remove(draft.id);
          if (_runs != null) await _repository.cleanupFiles();
        }
      } catch (error) {
        terminalState = 'failed';
        failure = error;
        _logger.event(
          'client.run.persistence_failed',
          channel: LogChannel.client,
          level: LogLevel.error,
          fields: {...logFields, ...AppLogger.errorFields(error)},
        );
        rethrow;
      } finally {
        if (!began && !_isDisposed) streamingMessages.remove(draftMessage.id);
        _logger.event(
          'client.run.finished',
          channel: LogChannel.client,
          level: terminalState == 'failed' ? LogLevel.error : LogLevel.info,
          fields: {
            ...logFields,
            'outcome': _isDisposed
                ? 'interrupted'
                : terminalState == 'completed'
                ? (_stopReason ?? terminalState)
                : terminalState,
            'elapsed_ms': watch.elapsedMilliseconds,
            if (failure != null) ...AppLogger.errorFields(failure),
          },
        );
        _draftAssistantMessage = null;
        _activeCancelToken = null;
        _activeConfig = null;
        _checkpoints = null;
        _runId = null;
        _conversationId = null;
      }
    }
  }

  /// One latest snapshot per interval, drained before tool/terminal boundaries.
  Future<void> _persistDraftDelta(
    ChatMessageRecord draft, {
    bool flush = false,
  }) async {
    if (_runs != null && _runId != null) {
      final runs = _runs!, runId = _runId!;
      final trace = _trace.map((t) => t.toJson()).toList();
      final context = _inputContextKey, answer = _finalAnswer;
      _checkpoints!.add(
        () => runs.checkpoint(
          runId,
          draft,
          trace: trace,
          contextKey: context,
          finalText: answer,
        ),
      );
      if (flush) await _checkpoints!.flush();
    } else {
      await _repository.saveMessage(draft);
    }
  }

  Future<ChatMessageRecord> _saveDraftVersion(
    ChatMessageRecord draft,
    String versionId,
  ) async {
    await _repository.saveMessageVersion(
      ChatMessageVersionRecord(
        id: versionId,
        messageId: draft.id,
        runId: _runId,
        author: draft.author,
        content: draft.content,
        createdAt: draft.createdAt,
        modelName: draft.modelName,
        generationMetrics: draft.generationMetrics,
        reasoningContent: draft.reasoningContent,
        imageFilePaths: draft.imageFilePaths,
      ),
    );
    final ids = [...draft.versionIds];
    if (!ids.contains(versionId)) ids.add(versionId);
    return draft.copyWith(
      versionIds: ids,
      currentVersionIndex: ids.indexOf(versionId),
    );
  }

  Future<List<AiTurn>> _turns(
    List<ChatMessageRecord> messages,
    ChatRunConfig config,
  ) async {
    final histories = <String, Map<String, dynamic>>{};
    for (final m in messages) {
      final history = await _runs?.history(m);
      if (history != null) histories[m.id] = history;
    }
    final result = <AiTurn>[];
    final preceding = <ChatMessageRecord>[];
    for (final m in messages) {
      final saved = histories[m.id]?['checkpoint'] as Map?;
      final trace = saved?['trace'] as List?;
      if (trace != null &&
          trace.isNotEmpty &&
          saved?['contextKey'] == historyContextKey(config, preceding)) {
        result.addAll(
          trace.map((t) => AiTurn.fromJson(Map<String, dynamic>.from(t))),
        );
        preceding.add(m);
        continue;
      }
      final images = <AiImage>[];
      for (final path in m.imageFilePaths) {
        final f = File(path);
        if (await f.exists()) {
          if (await f.length() > ImageAttachmentService.maxImageSizeBytes) {
            throw const FormatException('Image too large');
          }
          images.add(
            AiImage(
              ImageAttachmentService.mimeTypeForPath(path),
              base64Encode(await f.readAsBytes()),
            ),
          );
        }
      }
      result.add(AiTurn(role: m.role.name, text: m.content, images: images));
      preceding.add(m);
    }
    _inputContextKey = historyContextKey(config, preceding);
    return result;
  }

  /// Stable request identity shared by tool history and context-usage display.
  static String historyContextKey(
    ChatRunConfig config,
    List<ChatMessageRecord> messages,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            config.snapshot(),
            messages
                .map(
                  (m) => encodeMessage(m)
                    ..remove('author')
                    ..remove('generationMetrics')
                    ..remove('versionIds')
                    ..remove('currentVersionIndex'),
                )
                .toList(),
          ]),
        ),
      )
      .toString();

  Stream<ChatStreamDelta> _response(
    String modelId,
    List<ChatMessageRecord> messages,
    CancelToken token,
  ) async* {
    final config = _activeConfig;
    if (config == null) {
      yield* _apiClient.streamChatCompletion(
        modelId: modelId,
        messages: messages,
        cancelToken: token,
      );
      return;
    }
    final turns = await _turns(messages, config);
    if (!config.capabilities.supportsImages &&
        turns.any((t) => t.images.isNotEmpty)) {
      throw const FormatException('This model does not support images');
    }
    final service = AgentToolService.current;
    final toolSession = await service?.open(
      _runId!,
      _conversationId!,
      config,
      token,
    );
    final roundMetrics = <GenerationMetrics?>[];
    try {
      while (true) {
        revalidateAuthorization();
        if (token.isCancelled) throw token.cancelError!;
        final text = StringBuffer();
        final system = config.system + (toolSession?.skillInstructions ?? '');
        AiEvent? completed;
        await for (final e in _protocol.complete(
          config.connection,
          config.key,
          config.modelId,
          turns,
          cancelToken: token,
          runId: _runId,
          system: system,
          tools: config.capabilities.supportsTools
              ? (toolSession?.definitions ?? [])
              : const [],
          temperature: config.assistant.temperature,
        )) {
          text.write(e.text);
          if (e.stopReason != null) completed = e;
          yield ChatStreamDelta(content: e.text, reasoningContent: e.reasoning);
        }
        if (completed == null) throw StateError('Incomplete model turn');
        roundMetrics.add(completed.generationMetrics);
        final assistantTurn = AiTurn(
          role: 'assistant',
          text: text.toString(),
          calls: completed.calls,
          providerParts: completed.providerParts,
        );
        _trace.add(assistantTurn);
        if (completed.calls.isEmpty) {
          final metrics = GenerationMetrics.combineRounds(roundMetrics);
          if (metrics != null) {
            yield ChatStreamDelta(generationMetrics: metrics);
          }
          _finalAnswer = text.toString();
          if (_draftAssistantMessage != null) {
            await _persistDraftDelta(_draftAssistantMessage!, flush: true);
          }
          return;
        }
        if (!config.capabilities.supportsTools) {
          throw StateError('Tool calls are disabled for this response');
        }
        turns.add(assistantTurn);
        if (_draftAssistantMessage != null) {
          await _persistDraftDelta(_draftAssistantMessage!, flush: true);
        }
        for (final call in completed.calls) {
          if (toolSession == null) throw StateError('Tool service unavailable');
          final result = await toolSession.invoke(call);
          turns.add(result);
          _trace.add(result);
          if (_draftAssistantMessage != null) {
            await _persistDraftDelta(_draftAssistantMessage!, flush: true);
          }
        }
        yield const ChatStreamDelta(content: '\n\n');
      }
    } finally {
      await toolSession?.close();
    }
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

  ChatMessageVersionRecord _versionFromMessage(
    ChatMessageRecord message, {
    String? messageId,
  }) {
    final targetMessageId = messageId ?? message.id;
    return ChatMessageVersionRecord(
      id: _idGenerator.generate('version'),
      messageId: targetMessageId,
      runId: message.runId,
      author: message.author,
      content: message.content,
      createdAt: message.createdAt,
      modelName: message.modelName,
      generationMetrics: message.generationMetrics,
      reasoningContent: message.reasoningContent,
      imageFilePaths: message.imageFilePaths,
    );
  }

  String _chatErrorMessage(Object error) {
    return 'Request Failed: $error';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancel('disposed');
    streamingMessages.dispose();
    super.dispose();
  }
}
