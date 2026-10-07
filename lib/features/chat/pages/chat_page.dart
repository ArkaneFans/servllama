import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/features/agent/pages/tool_activity_page.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'dart:async';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/shared/widgets/async_action.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/chat/controllers/chat_scroll_coordinator.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';
import 'package:servllama/features/chat/widgets/chat_conversation_transition.dart';
import 'package:servllama/features/chat/widgets/chat_engine_start_sheet.dart';
import 'package:servllama/features/chat/widgets/chat_conversation_hero.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';
import 'package:servllama/features/chat/widgets/chat_input_overlay_layout.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_message_sheets.dart';
import 'package:servllama/features/chat/widgets/chat_model_sheet.dart';
import 'package:servllama/features/chat/widgets/chat_staged_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_session_actions.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/animated_text_swap.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, this.provider, this.onOpenSidebar});

  final ChatProvider? provider;
  final VoidCallback? onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    final existingProvider = provider;
    if (existingProvider != null) {
      return ChangeNotifierProvider<ChatProvider>.value(
        value: existingProvider,
        child: _ChatView(onOpenSidebar: onOpenSidebar),
      );
    }
    return _ChatView(onOpenSidebar: onOpenSidebar);
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({this.onOpenSidebar});

  final VoidCallback? onOpenSidebar;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ChatScrollCoordinator _scrollCoordinator = ChatScrollCoordinator();
  final TextEditingController _inputController = TextEditingController();
  ChatProvider? _draftProvider;
  void _saveInput() => _draftProvider?.updateDraft(_inputController.text);
  void _restoreInput() {
    final value = _draftProvider?.currentDraft ?? '';
    if (_inputController.text != value) {
      _inputController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  final ImageAttachmentService _imageAttachmentService =
      ImageAttachmentService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ChatProvider>().load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ChatProvider>();
    if (!identical(_draftProvider, provider)) {
      _draftProvider?.removeListener(_restoreInput);
      _inputController.removeListener(_saveInput);
      _draftProvider = provider;
      provider.addListener(_restoreInput);
      _inputController.addListener(_saveInput);
      _restoreInput();
    }
    _scrollCoordinator.attachProvider(context.read<ChatProvider>());
  }

  @override
  void dispose() {
    _draftProvider?.removeListener(_restoreInput);
    unawaited(_draftProvider?.flushDrafts());
    _scrollCoordinator.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    if (!chat.canSubmitInput) return;
    final text = _inputController.text;
    if (text.trim().isEmpty &&
        context.read<ChatProvider>().pendingImageAttachments.isEmpty) {
      return;
    }
    if (chat.hasAssistantContext && chat.currentTarget == null) {
      AppMessage.show(context, context.l10n.v2ChooseConversationModel);
      return;
    }
    _scrollCoordinator.enableAutoStickToBottom();
    final provider = context.read<ChatProvider>();
    final attachments = List<String>.from(provider.pendingImageAttachments);
    await runUiAction(
      context,
      () => provider.sendMessage(text, imageAttachments: attachments),
    );
    if (!context.mounted) return;
    final errorMessage = provider.lastErrorMessage;
    if (errorMessage != null) {
      provider.clearLastError();
      AppMessage.show(context, errorMessage, tone: AppMessageTone.error);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    // The Android picker is an activity, not a Flutter Navigator route.
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = context.read<ChatProvider>();
    try {
      final paths = await _imageAttachmentService.pickFromGallery(
        currentCount: provider.pendingImageAttachments.length,
      );
      for (final path in paths) {
        provider.addImageAttachment(path);
      }
    } on ImageAttachmentException catch (e) {
      if (!context.mounted) return;
      AppMessage.show(context, e.message, tone: AppMessageTone.error);
    }
  }

  Future<void> _handleServerAction(BuildContext context) async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null || runtime.isBusy) {
      return;
    }

    if (runtime.canStop) {
      await runtime.stop();
      if (context.mounted) {
        _showRuntimeError(context, runtime);
      }
      return;
    }

    final library = context.read<ModelManagementProvider>();
    unawaited(library.load());
    final engine = await showModalBottomSheet<InferenceEngine>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          Consumer2<EngineRuntimeProvider, ModelManagementProvider>(
            builder: (_, runtime, library, __) => ChatEngineStartSheet(
              currentEngine: runtime.activeEngine,
              defaultModelNames: <InferenceEngine, String?>{
                for (final engine in InferenceEngine.values)
                  engine: _modelDisplayName(
                    library,
                    engine,
                    runtime.selectedModelIdFor(engine),
                  ),
              },
              onSelect: (engine) => Navigator.of(sheetContext).pop(engine),
            ),
          ),
    );
    if (engine == null ||
        !context.mounted ||
        runtime.isBusy ||
        runtime.canStop) {
      return;
    }

    if (runtime.activeEngine != engine) {
      await runtime.switchEngine(engine);
    }
    if (!context.mounted || runtime.activeEngine != engine) {
      return;
    }

    // Both engines are model-specific. Choosing a model owns the remaining
    // start sequence when the selected engine has no saved default.
    if (runtime.selectedModelId == null) {
      await _showLocalModels(context, privateStart: true);
      return;
    }

    await runtime.startPrivate();
    if (context.mounted) {
      _showRuntimeError(context, runtime);
    }
  }

  String? _modelDisplayName(
    ModelManagementProvider library,
    InferenceEngine engine,
    String? modelId,
  ) {
    if (modelId == null) {
      return null;
    }
    for (final model in library.libraryModelsFor(engine)) {
      if (model.runtimeId == modelId) {
        return model.name;
      }
    }
    return modelId;
  }

  Future<void> _showModels(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    if (!chat.canSelectModels) return;
    if (chat.hasAssistantContext) {
      var source = chat.draftKey;
      await showChatTargetPicker(
        context,
        initialTarget: chat.currentTarget,
        onSelected: (picked) async {
          if (!chat.canSelectModels || chat.draftKey != source) {
            throw StateError('Conversation changed; reopen the model picker');
          }
          try {
            await chat.selectTarget(picked, startLocal: true);
          } finally {
            source = chat.draftKey;
          }
        },
      );
      return;
    }
    await _showLocalModels(context);
  }

  Future<void> _showLocalModels(
    BuildContext context, {
    bool privateStart = false,
  }) async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null) {
      return;
    }
    final library = context.read<ModelManagementProvider>();
    unawaited(library.load());

    final picked = await showModalBottomSheet<LibraryModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          Consumer3<
            EngineRuntimeProvider,
            ModelManagementProvider,
            DownloadProvider
          >(
            builder: (_, runtime, library, downloads, __) {
              final engine = runtime.activeEngine;
              final error = runtime.lastError;
              return ChatModelSheet(
                engine: engine,
                models: library.libraryModelsFor(engine),
                activeModelId: runtime.isRunning ? runtime.activeModelId : null,
                pendingModelId: runtime.isBusy ? runtime.selectedModelId : null,
                downloading: downloads.activeTasks
                    .where((task) => task.engine == engine)
                    .toList(growable: false),
                errorText: error == null
                    ? null
                    : RuntimeLabels.runtimeError(
                        AppLocalizations.of(sheetContext)!,
                        error,
                        runtime.port,
                      ),
                onSelect: (model) => Navigator.of(sheetContext).pop(model),
                onDiscover: () {
                  Navigator.of(sheetContext).pop();
                  _openDiscovery(context);
                },
              );
            },
          ),
    );

    if (picked == null ||
        !context.mounted ||
        runtime.activeEngine != picked.engine ||
        runtime.isBusy) {
      return;
    }
    // One tap owns the whole bring-up: idle starts the engine, running swaps
    // within it. Progress remains in the runtime subtitle after the sheet closes.
    if (privateStart) {
      // Starting a local service must not change the conversation's target.
      if (runtime.canStop) return;
      await runtime.selectModel(picked.runtimeId);
      await runtime.startPrivate();
    } else {
      await runtime.activateModel(picked.runtimeId);
    }
    if (!context.mounted) {
      return;
    }
    _showRuntimeError(context, runtime);
  }

  void _showRuntimeError(BuildContext context, EngineRuntimeProvider runtime) {
    final error = runtime.lastError;
    if (error == null) {
      return;
    }
    AppMessage.show(
      context,
      RuntimeLabels.runtimeError(context.l10n, error, runtime.port),
      tone: AppMessageTone.error,
    );
  }

  void _openDiscovery(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ModelDiscoveryPage()),
      ),
    );
  }

  Future<void> _handleCopyMessage(
    BuildContext context,
    ChatMessageRecord message,
  ) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) {
      return;
    }
    AppMessage.show(context, context.l10n.chatMessageCopied);
  }

  Future<void> _handleEditMessage(
    BuildContext context,
    ChatMessageRecord message,
  ) async {
    final editedContent = await showEditMessageSheet(
      context: context,
      initialValue: message.content,
    );
    if (!context.mounted || editedContent == null) {
      return;
    }
    await context.read<ChatProvider>().editMessage(
      messageId: message.id,
      newContent: editedContent,
    );
    if (!context.mounted) {
      return;
    }
    AppMessage.show(context, context.l10n.chatMessageUpdated);
  }

  Future<void> _handleDeleteMessage(
    BuildContext context,
    ChatMessageRecord message, {
    bool allVersions = true,
  }) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          allVersions ? l.chatDeleteMessageTitle : l.chatDeleteCurrentVersion,
        ),
        content: Text(
          allVersions
              ? l.chatDeleteAllVersionsConfirm
              : l.chatDeleteVersionConfirm(
                  message.currentVersionIndex + 1,
                  message.versionCount,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('chat_message_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    await runUiAction(
      context,
      () => context.read<ChatProvider>().deleteMessage(
        message.id,
        allVersions: allVersions,
        expectedMessage: message,
      ),
    );
  }

  Future<void> _handleRegenerateMessage(
    BuildContext context,
    ChatMessageRecord message,
  ) async {
    _scrollCoordinator.enableAutoStickToBottom();
    final provider = context.read<ChatProvider>();
    await provider.regenerateFromMessage(message.id);
    if (!context.mounted) {
      return;
    }
    final errorMessage = provider.lastErrorMessage;
    if (errorMessage != null) {
      provider.clearLastError();
      AppMessage.show(context, errorMessage, tone: AppMessageTone.error);
    }
  }

  Future<void> _handleSelectMessageVersion(
    BuildContext context,
    ChatMessageRecord message,
    int versionIndex,
  ) async {
    await context.read<ChatProvider>().selectMessageVersion(
      messageId: message.id,
      versionIndex: versionIndex,
    );
  }

  Future<void> _handleMessageAction(
    BuildContext context,
    ChatMessageAction action,
    ChatMessageRecord message,
  ) async {
    switch (action) {
      case ChatMessageAction.copy:
        await _handleCopyMessage(context, message);
      case ChatMessageAction.edit:
        await _handleEditMessage(context, message);
      case ChatMessageAction.regenerate:
        await _handleRegenerateMessage(context, message);
      case ChatMessageAction.rerun:
        await context.read<ChatProvider>().regenerateFromMessage(
          message.id,
          executeTools: true,
        );
      case ChatMessageAction.speak:
        await runUiAction(context, () async {
          final answer = await context.read<ChatProvider>().finalAnswer(
            message,
          );
          if (!context.mounted) return;
          if (answer == null) throw StateError(context.l10n.v2IncompleteAnswer);
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SpeechPage(
                  initialText: SpeechJobService.spokenText(answer),
                ),
              ),
            );
          }
        });
      case ChatMessageAction.delete:
        await _handleDeleteMessage(context, message);
      case ChatMessageAction.deleteVersion:
        await _handleDeleteMessage(context, message, allVersions: false);
    }
  }

  Future<void> _showMessageActions(
    BuildContext context,
    ChatMessageRecord message,
  ) async {
    final action = await showModalBottomSheet<ChatMessageAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ChatMessageActionSheet(
        message: message,
        canRegenerate: context.read<ChatProvider>().canRegenerateMessage(
          message.id,
        ),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    await _handleMessageAction(context, action, message);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: widget.onOpenSidebar,
        ),
        title: _ChatAppBarTitle(onSelectModel: () => _showModels(context)),
        actions: [
          Selector<ChatProvider, bool>(
            selector: (_, provider) => provider.canManageSessions,
            builder: (context, canManageSessions, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: canManageSessions
                    ? () => context.read<ChatProvider>().createSession()
                    : null,
                tooltip: context.l10n.chatCreateSessionTooltip,
                icon: const Icon(Icons.maps_ugc_outlined),
              ),
            ),
          ),
        ],
      ),
      body: Selector<ChatProvider, bool>(
        selector: (_, provider) =>
            provider.isLoading && provider.sessions.isEmpty,
        builder: (context, isInitialLoading, _) {
          if (isInitialLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 2, 15, 12),
              child: _ChatInputOverlayScaffold(
                scrollCoordinator: _scrollCoordinator,
                inputController: _inputController,
                onOpenModels: () => _showModels(context),
                onServerAction: () => _handleServerAction(context),
                onSend: () => _send(context),
                onPickFromGallery: () => _pickFromGallery(context),
                onCopyMessage: (message) =>
                    _handleCopyMessage(context, message),
                onEditMessage: (message) =>
                    _handleEditMessage(context, message),
                onDeleteMessage: (message) =>
                    _handleDeleteMessage(context, message),
                onRegenerateMessage: (message) =>
                    _handleRegenerateMessage(context, message),
                onShowMessageActions: (message) =>
                    _showMessageActions(context, message),
                onSelectMessageVersion: (message, versionIndex) =>
                    _handleSelectMessageVersion(context, message, versionIndex),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatInputOverlayScaffold extends StatefulWidget {
  const _ChatInputOverlayScaffold({
    required this.scrollCoordinator,
    required this.inputController,
    required this.onOpenModels,
    required this.onServerAction,
    required this.onSend,
    required this.onPickFromGallery,
    required this.onCopyMessage,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onRegenerateMessage,
    required this.onShowMessageActions,
    required this.onSelectMessageVersion,
  });

  final ChatScrollCoordinator scrollCoordinator;
  final TextEditingController inputController;
  final VoidCallback onOpenModels;
  final VoidCallback onServerAction;
  final VoidCallback onSend;
  final VoidCallback onPickFromGallery;
  final Future<void> Function(ChatMessageRecord message) onCopyMessage;
  final Future<void> Function(ChatMessageRecord message) onEditMessage;
  final Future<void> Function(ChatMessageRecord message) onDeleteMessage;
  final Future<void> Function(ChatMessageRecord message) onRegenerateMessage;
  final Future<void> Function(ChatMessageRecord message) onShowMessageActions;
  final Future<void> Function(ChatMessageRecord message, int versionIndex)
  onSelectMessageVersion;

  @override
  State<_ChatInputOverlayScaffold> createState() =>
      _ChatInputOverlayScaffoldState();
}

class _ChatInputOverlayScaffoldState extends State<_ChatInputOverlayScaffold> {
  static const double _defaultInputHeight = 126;
  static const double _messageBottomGap = 12;

  double _inputHeight = _defaultInputHeight;

  void _handleInputSizeChanged(Size size) {
    final nextHeight = size.height;
    if ((nextHeight - _inputHeight).abs() < 0.5) {
      return;
    }
    setState(() {
      _inputHeight = nextHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatInputOverlayLayout(
      content: _ChatConversationPanel(
        scrollCoordinator: widget.scrollCoordinator,
        bottomContentPadding: _inputHeight + _messageBottomGap,
        onCopyMessage: widget.onCopyMessage,
        onEditMessage: widget.onEditMessage,
        onDeleteMessage: widget.onDeleteMessage,
        onRegenerateMessage: widget.onRegenerateMessage,
        onShowMessageActions: widget.onShowMessageActions,
        onSelectMessageVersion: widget.onSelectMessageVersion,
      ),
      bottomOverlay: _MeasureSize(
        onChange: _handleInputSizeChanged,
        child: RepaintBoundary(
          child: _ChatInputPanel(
            controller: widget.inputController,
            onOpenModels: widget.onOpenModels,
            onServerAction: widget.onServerAction,
            onSend: widget.onSend,
            onPickFromGallery: widget.onPickFromGallery,
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.onChange, required this.child});

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final size = context.size;
      if (size == null || size == _lastSize) {
        return;
      }
      _lastSize = size;
      widget.onChange(size);
    });
    return widget.child;
  }
}

class _ChatConversationPanel extends StatelessWidget {
  const _ChatConversationPanel({
    required this.scrollCoordinator,
    required this.bottomContentPadding,
    required this.onCopyMessage,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onRegenerateMessage,
    required this.onShowMessageActions,
    required this.onSelectMessageVersion,
  });

  final ChatScrollCoordinator scrollCoordinator;
  final double bottomContentPadding;
  final Future<void> Function(ChatMessageRecord message) onCopyMessage;
  final Future<void> Function(ChatMessageRecord message) onEditMessage;
  final Future<void> Function(ChatMessageRecord message) onDeleteMessage;
  final Future<void> Function(ChatMessageRecord message) onRegenerateMessage;
  final Future<void> Function(ChatMessageRecord message) onShowMessageActions;
  final Future<void> Function(ChatMessageRecord message, int versionIndex)
  onSelectMessageVersion;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<ChatProvider, _ChatBodySnapshot>(
      _ChatBodySnapshot.fromProvider,
    );
    final serverProvider = context.watch<EngineRuntimeProvider?>();
    final animateConversationBody =
        Theme.of(context).platform != TargetPlatform.android;
    final conversationSwitchDelay = animateConversationBody
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return ChatConversationTransition(
      conversationKey: snapshot.conversationKey,
      animateBody: animateConversationBody,
      readyToCommit: !snapshot.isLoadingMessages,
      switchDelay: conversationSwitchDelay,
      maxUnreadyDelay: const Duration(milliseconds: 320),
      onConversationCommitted:
          scrollCoordinator.handleConversationBodyCommitted,
      child: _ChatConversationBody(
        snapshot: snapshot,
        serverProvider: serverProvider,
        bottomContentPadding: bottomContentPadding,
        scrollCoordinator: scrollCoordinator,
        onCopyMessage: onCopyMessage,
        onEditMessage: onEditMessage,
        onDeleteMessage: onDeleteMessage,
        onRegenerateMessage: onRegenerateMessage,
        onShowMessageActions: onShowMessageActions,
        onSelectMessageVersion: onSelectMessageVersion,
      ),
    );
  }
}

class _ChatInputPanel extends StatelessWidget {
  const _ChatInputPanel({
    required this.controller,
    required this.onOpenModels,
    required this.onServerAction,
    required this.onSend,
    required this.onPickFromGallery,
  });

  final TextEditingController controller;
  final VoidCallback onOpenModels;
  final VoidCallback onServerAction;
  final VoidCallback onSend;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<ChatProvider, _ChatInputSnapshot>(
      _ChatInputSnapshot.fromProvider,
    );
    final serverProvider = context.watch<EngineRuntimeProvider?>();
    final isRemote = context.select<ChatProvider, bool>((p) => p.isRemote);
    final provider = context.read<ChatProvider>();
    final isServerRunning = serverProvider?.canStop ?? false;
    final isServerBusy = serverProvider?.isBusy ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AgentApprovalBanner(),
        if (provider.stopReason?.endsWith('Budget') == true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(context.l10n.v2BudgetReached),
          ),
        ChatInputBar(
          key: const Key('chat_input_bar'),
          controller: controller,
          hintText: _inputHintText(
            context,
            snapshot,
            isServerBusy: !isRemote && isServerBusy,
          ),
          isServerRunning: isServerRunning,
          isServerBusy: isServerBusy,
          modelLabel: _modelSelectorLabel(context, snapshot),
          localModel: !isRemote,
          canOpenModels: snapshot.canOpenModels && (isRemote || !isServerBusy),
          isModelLoading: isServerBusy,
          hasLoadedModel: snapshot.hasLoadedModel,
          onServerAction: serverProvider == null || !provider.canManageSessions
              ? null
              : onServerAction,
          onOpenModels: onOpenModels,
          canSend: snapshot.canSend,
          canAttachImages: snapshot.canAttachImages,
          isSending: snapshot.isSending,
          onSend: onSend,
          onStop: provider.cancelStreaming,
          onPickFromGallery: onPickFromGallery,
          pendingImageAttachments: snapshot.pendingImageAttachments,
          onRemoveImageAttachment: provider.removeImageAttachment,
        ),
      ],
    );
  }
}

class _ChatConversationBody extends StatelessWidget {
  const _ChatConversationBody({
    required this.snapshot,
    required this.serverProvider,
    required this.bottomContentPadding,
    required this.scrollCoordinator,
    required this.onCopyMessage,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onRegenerateMessage,
    required this.onShowMessageActions,
    required this.onSelectMessageVersion,
  });

  final _ChatBodySnapshot snapshot;
  final EngineRuntimeProvider? serverProvider;
  final double bottomContentPadding;
  final ChatScrollCoordinator scrollCoordinator;
  final Future<void> Function(ChatMessageRecord message) onCopyMessage;
  final Future<void> Function(ChatMessageRecord message) onEditMessage;
  final Future<void> Function(ChatMessageRecord message) onDeleteMessage;
  final Future<void> Function(ChatMessageRecord message) onRegenerateMessage;
  final Future<void> Function(ChatMessageRecord message) onShowMessageActions;
  final Future<void> Function(ChatMessageRecord message, int versionIndex)
  onSelectMessageVersion;

  @override
  Widget build(BuildContext context) {
    final conversationKey = snapshot.conversationKey;
    if (snapshot.isLoadingMessages) {
      return Center(
        key: ValueKey<String>('chat_message_loading_$conversationKey'),
        child: const CircularProgressIndicator(),
      );
    }

    final visibleMessages = snapshot.visibleMessages;
    final chat = context.watch<ChatProvider>();
    if (visibleMessages.isEmpty && chat.hasAssistantContext) {
      if (chat.currentAssistant == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.v2UnassignedAssistant),
              if (chat.selectedSession != null)
                TextButton(
                  onPressed: !chat.canManageSessions
                      ? null
                      : () => runUiAction(
                          context,
                          () => ChatSessionActions.changeAssistant(
                            provider: chat,
                            presentationContext: context,
                            session: chat.selectedSession!,
                          ),
                        ),
                  child: Text(context.l10n.v2ChangeConversationAssistant),
                ),
            ],
          ),
        );
      }
    }
    if (visibleMessages.isEmpty) {
      final runtime = serverProvider;
      final status = runtime?.isBusy == true && runtime?.currentPhase != null
          ? RuntimeLabels.phase(context.l10n, runtime!.currentPhase!)
          : runtime?.isRunning == true
          ? context.l10n.serverStatusRunning
          : context.l10n.serverStatusStopped;
      void open(Widget page) => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
      return Padding(
        padding: EdgeInsets.only(bottom: bottomContentPadding),
        child: ChatConversationHero(
          key: ValueKey<String>('chat_conversation_hero_$conversationKey'),
          serverStatus: status,
          onServer: () => open(const ServerPage()),
          onTranscribe: () =>
              open(const SpeechPage(initialKind: AssetKind.asr)),
          onSynthesize: () =>
              open(const SpeechPage(initialKind: AssetKind.tts)),
        ),
      );
    }

    return Stack(
      key: ValueKey<String>('chat_message_list_stack_$conversationKey'),
      children: [
        Listener(
          onPointerSignal: scrollCoordinator.handlePointerSignal,
          child: NotificationListener<ScrollNotification>(
            onNotification: scrollCoordinator.handleMessageScrollNotification,
            child: ChatStagedMessageList(
              key: ValueKey<String>(
                'chat_staged_message_list_$conversationKey',
              ),
              conversationKey: conversationKey,
              messages: visibleMessages,
              onSettled: scrollCoordinator.handleConversationBodyCommitted,
              builder: (context, messages) {
                return ChatMessageList(
                  key: const ValueKey<String>('chat_message_list'),
                  controller: scrollCoordinator.scrollController,
                  streamingMessages: snapshot.streamingMessages,
                  messages: messages,
                  draftMessageId: snapshot.draftMessageId,
                  canManageMessages: snapshot.canManageMessages,
                  canRegenerateMessage: context
                      .read<ChatProvider>()
                      .canRegenerateMessage,
                  padding: EdgeInsets.fromLTRB(0, 24, 0, bottomContentPadding),
                  onCopyMessage: onCopyMessage,
                  onEditMessage: onEditMessage,
                  onDeleteMessage: onDeleteMessage,
                  onRegenerateMessage: onRegenerateMessage,
                  onShowMessageActions: onShowMessageActions,
                  onSelectMessageVersion: onSelectMessageVersion,
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: bottomContentPadding + 12,
          child: AnimatedBuilder(
            animation: scrollCoordinator,
            builder: (context, _) {
              if (!scrollCoordinator.showJumpToLatestButton) {
                return const SizedBox.shrink();
              }
              return FloatingActionButton.small(
                key: const Key('chat_jump_to_latest_button'),
                heroTag: null,
                tooltip: context.l10n.chatJumpToLatest,
                onPressed: scrollCoordinator.jumpToLatestMessage,
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatAppBarTitle extends StatelessWidget {
  const _ChatAppBarTitle({required this.onSelectModel});

  final VoidCallback onSelectModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Selector<ChatProvider, _ChatTitleSnapshot>(
          selector: (_, provider) => _ChatTitleSnapshot.fromProvider(provider),
          builder: (context, snapshot, _) {
            return AnimatedTextSwap(
              text: snapshot.title ?? context.l10n.chatNewSession,
              alignment: Alignment.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        _ChatRuntimeTitle(onTap: onSelectModel),
      ],
    );
  }
}

class _ChatRuntimeTitle extends StatelessWidget {
  const _ChatRuntimeTitle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final runtime = context.watch<EngineRuntimeProvider?>();
    final library = context.watch<ModelManagementProvider?>();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String label;
    if (chat.hasAssistantContext) {
      label = chat.targetLabel ?? l10n.chatSelectModel;
      if (chat.targetAsset != null &&
          runtime?.isBusy == true &&
          runtime?.currentPhase != null) {
        label = RuntimeLabels.phase(l10n, runtime!.currentPhase!);
      }
    } else {
      if (runtime == null) return const SizedBox.shrink();
      final state = runtime.state;
      String detail;
      if (state.status == EngineRuntimeStatus.preparing &&
          state.phase != null) {
        detail = RuntimeLabels.phase(l10n, state.phase!);
      } else if (state.status == EngineRuntimeStatus.stopping) {
        detail = l10n.serverStatusStopping;
      } else {
        detail =
            _modelName(
              library,
              state.engine,
              runtime.activeModelId ?? runtime.selectedModelId,
            ) ??
            l10n.serverNoModelSelected;
      }
      label = '${state.engine.displayName} / $detail';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Tooltip(
        message: l10n.chatSelectModel,
        child: InkWell(
          key: const Key('chat_runtime_subtitle'),
          borderRadius: BorderRadius.circular(6),
          onTap: chat.canSelectModels ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: AnimatedTextSwap(
              text: label,
              alignment: Alignment.center,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withAlpha(153),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  String? _modelName(
    ModelManagementProvider? library,
    InferenceEngine engine,
    String? runtimeId,
  ) {
    if (runtimeId == null) {
      return null;
    }
    for (final model
        in library?.libraryModelsFor(engine) ?? const <LibraryModel>[]) {
      if (model.runtimeId == runtimeId) {
        return model.name;
      }
    }
    return runtimeId;
  }
}

@immutable
class _ChatTitleSnapshot {
  const _ChatTitleSnapshot({
    required this.conversationKey,
    required this.title,
  });

  factory _ChatTitleSnapshot.fromProvider(ChatProvider provider) {
    return _ChatTitleSnapshot(
      conversationKey: provider.draftKey,
      title: provider.selectedSession?.title,
    );
  }

  final String conversationKey;
  final String? title;

  @override
  bool operator ==(Object other) {
    return other is _ChatTitleSnapshot &&
        other.conversationKey == conversationKey &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(conversationKey, title);
}

@immutable
class _ChatBodySnapshot {
  const _ChatBodySnapshot({
    required this.conversationKey,
    required this.isLoadingMessages,
    required this.visibleMessages,
    required this.visibleMessagesRevision,
    required this.streamingMessages,
    required this.draftMessageId,
    required this.canManageMessages,
  });

  factory _ChatBodySnapshot.fromProvider(ChatProvider provider) {
    return _ChatBodySnapshot(
      conversationKey: provider.draftKey,
      isLoadingMessages: provider.isLoadingMessages,
      visibleMessages: provider.visibleMessages,
      visibleMessagesRevision: provider.visibleMessagesRevision,
      streamingMessages: provider.streamingMessages,
      draftMessageId: provider.draftMessageId,
      canManageMessages: provider.canManageMessages,
    );
  }

  final String conversationKey;
  final bool isLoadingMessages;
  final List<ChatMessageRecord> visibleMessages;
  final int visibleMessagesRevision;
  final StreamingChatMessageNotifier streamingMessages;
  final String? draftMessageId;
  final bool canManageMessages;

  @override
  bool operator ==(Object other) {
    return other is _ChatBodySnapshot &&
        other.conversationKey == conversationKey &&
        other.isLoadingMessages == isLoadingMessages &&
        other.visibleMessagesRevision == visibleMessagesRevision &&
        identical(other.streamingMessages, streamingMessages) &&
        other.draftMessageId == draftMessageId &&
        other.canManageMessages == canManageMessages;
  }

  @override
  int get hashCode => Object.hash(
    conversationKey,
    isLoadingMessages,
    visibleMessagesRevision,
    streamingMessages,
    draftMessageId,
    canManageMessages,
  );
}

@immutable
class _ChatInputSnapshot {
  const _ChatInputSnapshot({
    required this.isServerRunning,
    required this.currentModelId,
    required this.loadedModelDisplayName,
    required this.hasLoadedModel,
    required this.canOpenModels,
    required this.canSend,
    required this.canAttachImages,
    required this.isSending,
    required this.pendingImageAttachments,
  });

  factory _ChatInputSnapshot.fromProvider(ChatProvider provider) {
    final currentModel = provider.currentModel;
    return _ChatInputSnapshot(
      isServerRunning: provider.isServerRunning || provider.isRemote,
      currentModelId: provider.currentModelId,
      loadedModelDisplayName: currentModel?.isLoaded == true
          ? currentModel?.displayName
          : null,
      hasLoadedModel: currentModel?.isLoaded == true,
      canOpenModels: provider.canSelectModels,
      canSend: provider.canSubmitInput,
      canAttachImages: provider.canAttachImages,
      isSending: provider.isSending,
      pendingImageAttachments: List<String>.unmodifiable(
        provider.pendingImageAttachments,
      ),
    );
  }

  final bool isServerRunning;
  final String? currentModelId;
  final String? loadedModelDisplayName;
  final bool hasLoadedModel;
  final bool canOpenModels;
  final bool canSend;
  final bool canAttachImages;
  final bool isSending;
  final List<String> pendingImageAttachments;

  @override
  bool operator ==(Object other) {
    return other is _ChatInputSnapshot &&
        other.isServerRunning == isServerRunning &&
        other.currentModelId == currentModelId &&
        other.loadedModelDisplayName == loadedModelDisplayName &&
        other.hasLoadedModel == hasLoadedModel &&
        other.canOpenModels == canOpenModels &&
        other.canSend == canSend &&
        other.canAttachImages == canAttachImages &&
        other.isSending == isSending &&
        listEquals(other.pendingImageAttachments, pendingImageAttachments);
  }

  @override
  int get hashCode => Object.hash(
    isServerRunning,
    currentModelId,
    loadedModelDisplayName,
    hasLoadedModel,
    canOpenModels,
    canSend,
    canAttachImages,
    isSending,
    Object.hashAll(pendingImageAttachments),
  );
}

String _inputHintText(
  BuildContext context,
  _ChatInputSnapshot snapshot, {
  required bool isServerBusy,
}) {
  final l10n = context.l10n;
  final chat = context.read<ChatProvider>();
  if (chat.hasAssistantContext) {
    if (chat.currentAssistant == null) return l10n.v2UnassignedAssistant;
    if (chat.currentTarget == null) return l10n.chatInputHintEnterMessage;
  }
  if (!snapshot.isServerRunning) {
    return l10n.chatInputHintStartServer;
  }
  if (isServerBusy) {
    return l10n.chatInputHintLoadingModel;
  }
  if (snapshot.currentModelId == null) {
    return l10n.chatInputHintSelectModel;
  }
  if (!snapshot.hasLoadedModel) {
    return l10n.chatInputHintModelUnavailable;
  }
  return l10n.chatInputHintEnterMessage;
}

String _modelSelectorLabel(BuildContext context, _ChatInputSnapshot snapshot) {
  final loadedModelDisplayName = snapshot.loadedModelDisplayName;
  if (loadedModelDisplayName != null) {
    return loadedModelDisplayName;
  }
  return context.l10n.chatSelectModel;
}
