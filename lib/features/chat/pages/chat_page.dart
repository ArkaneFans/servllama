import 'dart:async';

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
import 'package:servllama/features/chat/widgets/chat_runtime_capsule.dart';
import 'package:servllama/features/chat/widgets/chat_staged_message_list.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';

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
    _scrollCoordinator.attachProvider(context.read<ChatProvider>());
  }

  @override
  void dispose() {
    _scrollCoordinator.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext context) async {
    final text = _inputController.text;
    if (text.trim().isEmpty &&
        context.read<ChatProvider>().pendingImageAttachments.isEmpty) {
      return;
    }
    _inputController.clear();
    _scrollCoordinator.enableAutoStickToBottom();
    final provider = context.read<ChatProvider>();
    final attachments = List<String>.from(provider.pendingImageAttachments);
    await provider.sendMessage(text, imageAttachments: attachments);
    if (!context.mounted) return;
    final errorMessage = provider.lastErrorMessage;
    if (errorMessage != null) {
      provider.clearLastError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _handleServerAction(BuildContext context) async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null) {
      return;
    }

    if (runtime.isRunning) {
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
    if (engine == null || !context.mounted) {
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
      await _showModels(context);
      return;
    }

    await runtime.start();
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

    if (picked == null || !context.mounted) {
      return;
    }
    // One tap owns the whole bring-up: idle starts the engine, running swaps
    // within it. Progress surfaces on the hero, so the sheet closes first.
    await runtime.activateModel(picked.runtimeId);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          RuntimeLabels.runtimeError(context.l10n, error, runtime.port),
        ),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatMessageCopied)));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatMessageUpdated)));
  }

  Future<void> _handleDeleteMessage(
    BuildContext context,
    ChatMessageRecord message,
  ) async {
    await context.read<ChatProvider>().deleteMessage(message.id);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
      case ChatMessageAction.delete:
        await _handleDeleteMessage(context, message);
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        leadingWidth: 52,
        titleSpacing: 4,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onOpenSidebar,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatRuntimeTitle(onTap: () => _showModels(context)),
            const SizedBox(height: 3),
            Selector<ChatProvider, _ChatTitleSnapshot>(
              selector: (_, provider) =>
                  _ChatTitleSnapshot.fromProvider(provider),
              builder: (context, snapshot, _) => _ChatSessionTitle(
                conversationKey: snapshot.conversationKey,
                title: snapshot.title ?? context.l10n.chatNewSession,
                compact: true,
              ),
            ),
          ],
        ),
        actions: [
          Selector<ChatProvider, bool>(
            selector: (_, provider) => provider.canManageSessions,
            builder: (context, canManageSessions, _) => IconButton(
              onPressed: canManageSessions
                  ? () => context.read<ChatProvider>().createSession()
                  : null,
              tooltip: context.l10n.chatCreateSessionTooltip,
              icon: const Icon(Icons.add),
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
                onDiscoverModels: () => _openDiscovery(context),
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
    required this.onDiscoverModels,
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
  final VoidCallback onDiscoverModels;
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
        onDiscoverModels: widget.onDiscoverModels,
        onOpenModels: widget.onOpenModels,
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
    required this.onDiscoverModels,
    required this.onOpenModels,
    required this.onCopyMessage,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onRegenerateMessage,
    required this.onShowMessageActions,
    required this.onSelectMessageVersion,
  });

  final ChatScrollCoordinator scrollCoordinator;
  final double bottomContentPadding;
  final VoidCallback onDiscoverModels;
  final VoidCallback onOpenModels;
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
        onDiscoverModels: onDiscoverModels,
        onOpenModels: onOpenModels,
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
    final isServerRunning =
        serverProvider?.isRunning ?? snapshot.isServerRunning;
    final isServerBusy = serverProvider?.isBusy ?? false;
    final provider = context.read<ChatProvider>();

    return ChatInputBar(
      key: const Key('chat_input_bar'),
      controller: controller,
      hintText: _inputHintText(context, snapshot, isServerBusy: isServerBusy),
      isServerRunning: isServerRunning,
      isServerBusy: isServerBusy,
      modelLabel: _modelSelectorLabel(context, snapshot),
      canOpenModels: snapshot.canOpenModels && !isServerBusy,
      isModelLoading: isServerBusy,
      hasLoadedModel: snapshot.hasLoadedModel,
      onServerAction: serverProvider == null ? null : onServerAction,
      onOpenModels: onOpenModels,
      canSend: snapshot.canSend,
      isSending: snapshot.isSending,
      onSend: onSend,
      onStop: provider.cancelStreaming,
      onPickFromGallery: onPickFromGallery,
      pendingImageAttachments: snapshot.pendingImageAttachments,
      onRemoveImageAttachment: provider.removeImageAttachment,
    );
  }
}

class _ChatConversationBody extends StatelessWidget {
  const _ChatConversationBody({
    required this.snapshot,
    required this.serverProvider,
    required this.bottomContentPadding,
    required this.scrollCoordinator,
    required this.onDiscoverModels,
    required this.onOpenModels,
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
  final VoidCallback onDiscoverModels;
  final VoidCallback onOpenModels;
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
    final shouldShowHeroState =
        visibleMessages.isEmpty &&
        (!snapshot.isServerRunning || !snapshot.hasLoadedModel);
    if (shouldShowHeroState) {
      // The hero is the only place the orchestration progress shows while the
      // conversation is still empty, so it reads the runtime directly.
      final runtime = serverProvider;
      final isPreparing = runtime?.isBusy == true;
      final phase = runtime?.currentPhase;
      final preparingLabel = isPreparing && phase != null && runtime != null
          ? RuntimeLabels.phase(context.l10n, phase)
          : null;
      // Nullable like the runtime above: the page is embeddable without the
      // library scope (it only changes which hero action is offered).
      final hasLibraryModels = context.select<ModelManagementProvider?, bool>(
        (library) =>
            (library?.countFor(
                  runtime?.activeEngine ?? InferenceEngine.llamaCpp,
                ) ??
                0) >
            0,
      );
      return Padding(
        padding: EdgeInsets.only(bottom: bottomContentPadding),
        child: ChatConversationHero(
          key: ValueKey<String>('chat_conversation_hero_$conversationKey'),
          isPreparing: isPreparing,
          preparingLabel: preparingLabel,
          hasLibraryModels: hasLibraryModels,
          onDiscoverModels: onDiscoverModels,
          onOpenModels: isPreparing ? null : onOpenModels,
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

class _ChatSessionTitle extends StatelessWidget {
  const _ChatSessionTitle({
    required this.conversationKey,
    required this.title,
    this.compact = false,
  });

  final String conversationKey;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: compact ? Alignment.center : Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: Text(
          title,
          key: ValueKey<String>('chat_session_title_$conversationKey:$title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: compact
              ? Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _ChatRuntimeTitle extends StatelessWidget {
  const _ChatRuntimeTitle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<EngineRuntimeProvider?>();
    if (runtime == null) {
      return const SizedBox.shrink();
    }
    final library = context.watch<ModelManagementProvider?>();
    final l10n = context.l10n;
    final state = runtime.state;

    String label;
    if (state.status == EngineRuntimeStatus.preparing && state.phase != null) {
      label = RuntimeLabels.phase(l10n, state.phase!);
    } else if (state.status == EngineRuntimeStatus.stopping) {
      label = l10n.serverStatusStopping;
    } else {
      final runtimeId = runtime.activeModelId ?? runtime.selectedModelId;
      label =
          _modelName(library, state.engine, runtimeId) ??
          l10n.serverNoModelSelected;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: ChatRuntimeCapsule(state: state, label: label, onTap: onTap),
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
      conversationKey: provider.selectedSession?.id ?? 'draft',
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
    required this.isServerRunning,
    required this.hasLoadedModel,
    required this.streamingMessages,
    required this.draftMessageId,
    required this.canManageMessages,
  });

  factory _ChatBodySnapshot.fromProvider(ChatProvider provider) {
    return _ChatBodySnapshot(
      conversationKey: provider.selectedSession?.id ?? 'draft',
      isLoadingMessages: provider.isLoadingMessages,
      visibleMessages: provider.visibleMessages,
      visibleMessagesRevision: provider.visibleMessagesRevision,
      isServerRunning: provider.isServerRunning,
      hasLoadedModel: provider.currentModel?.isLoaded == true,
      streamingMessages: provider.streamingMessages,
      draftMessageId: provider.draftMessageId,
      canManageMessages: provider.canManageMessages,
    );
  }

  final String conversationKey;
  final bool isLoadingMessages;
  final List<ChatMessageRecord> visibleMessages;
  final int visibleMessagesRevision;
  final bool isServerRunning;
  final bool hasLoadedModel;
  final StreamingChatMessageNotifier streamingMessages;
  final String? draftMessageId;
  final bool canManageMessages;

  @override
  bool operator ==(Object other) {
    return other is _ChatBodySnapshot &&
        other.conversationKey == conversationKey &&
        other.isLoadingMessages == isLoadingMessages &&
        other.visibleMessagesRevision == visibleMessagesRevision &&
        other.isServerRunning == isServerRunning &&
        other.hasLoadedModel == hasLoadedModel &&
        identical(other.streamingMessages, streamingMessages) &&
        other.draftMessageId == draftMessageId &&
        other.canManageMessages == canManageMessages;
  }

  @override
  int get hashCode => Object.hash(
    conversationKey,
    isLoadingMessages,
    visibleMessagesRevision,
    isServerRunning,
    hasLoadedModel,
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
    required this.isSending,
    required this.pendingImageAttachments,
  });

  factory _ChatInputSnapshot.fromProvider(ChatProvider provider) {
    final currentModel = provider.currentModel;
    return _ChatInputSnapshot(
      isServerRunning: provider.isServerRunning,
      currentModelId: provider.currentModelId,
      loadedModelDisplayName: currentModel?.isLoaded == true
          ? currentModel?.displayName
          : null,
      hasLoadedModel: currentModel?.isLoaded == true,
      canOpenModels: provider.canSelectModels,
      canSend: provider.canSend,
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
