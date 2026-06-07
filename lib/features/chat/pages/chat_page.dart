import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/features/chat/controllers/chat_scroll_coordinator.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';
import 'package:servllama/features/chat/widgets/chat_conversation_hero.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_message_sheets.dart';
import 'package:servllama/features/chat/widgets/chat_model_sheet.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    this.provider,
    this.onNavigateToServer,
    this.onOpenSidebar,
  });

  final ChatProvider? provider;
  final VoidCallback? onNavigateToServer;
  final VoidCallback? onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    final existingProvider = provider;
    if (existingProvider != null) {
      return ChangeNotifierProvider<ChatProvider>.value(
        value: existingProvider,
        child: _ChatView(
          onNavigateToServer: onNavigateToServer,
          onOpenSidebar: onOpenSidebar,
        ),
      );
    }
    return _ChatView(
      onNavigateToServer: onNavigateToServer,
      onOpenSidebar: onOpenSidebar,
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({this.onNavigateToServer, this.onOpenSidebar});

  final VoidCallback? onNavigateToServer;
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
    _scrollCoordinator.addListener(_handleScrollCoordinatorChanged);
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
    _scrollCoordinator.removeListener(_handleScrollCoordinatorChanged);
    _scrollCoordinator.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleScrollCoordinatorChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      // Rebuild only the floating jump button visibility.
    });
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

  Future<void> _showModels(BuildContext context) async {
    final provider = context.read<ChatProvider>();
    final l10n = context.l10n;
    unawaited(provider.refreshModels());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer<ChatProvider>(
        builder: (context, provider, _) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              child: ChatModelSheetContent(
                provider: provider,
                onRefresh: () => provider.refreshModels(),
                children: [
                  ChatModelSection(
                    title: l10n.chatLoadedModels,
                    models: provider.loadedModels,
                    currentModelId: provider.currentModelId,
                    loadingModelId: provider.loadingModelId,
                    onTap: provider.canSelectModels
                        ? (model) {
                            provider.selectLoadedModel(model.id);
                            Navigator.of(sheetContext).pop();
                          }
                        : null,
                    onSecondaryAction: provider.canSelectModels
                        ? (model) => provider.unloadModel(model.id)
                        : null,
                  ),
                  if (provider.availableModels.isNotEmpty) ...[
                    ChatModelSection(
                      title: l10n.chatAvailableModels,
                      models: provider.availableModels,
                      currentModelId: provider.currentModelId,
                      loadingModelId: provider.loadingModelId,
                      onTap: provider.canSelectModels
                          ? (model) async {
                              await provider.loadAndSelectModel(model.id);
                              if (!context.mounted) {
                                return;
                              }
                              final currentModel = provider.currentModel;
                              if (currentModel != null &&
                                  currentModel.id == model.id &&
                                  currentModel.isLoaded) {
                                Navigator.of(sheetContext).pop();
                              }
                            }
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final serverProvider = context.watch<ServerProvider?>();
        final hasLoadedModel = provider.currentModel?.isLoaded == true;
        final conversationKey = provider.selectedSession?.id ?? 'draft';
        final shouldShowHeroState =
            !provider.isLoadingMessages &&
            provider.visibleMessages.isEmpty &&
            (!provider.isServerRunning || !hasLoadedModel);

        return Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leadingWidth: 52,
              titleSpacing: 4,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenSidebar,
              ),
              title: Text(
                _sessionTitle(context, provider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              actions: [
                IconButton(
                  onPressed: provider.canManageSessions
                      ? () => provider.createSession()
                      : null,
                  tooltip: context.l10n.chatCreateSessionTooltip,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            body: provider.isLoading && provider.sessions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 2, 15, 12),
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return currentChild ?? const SizedBox.shrink();
                              },
                              child: provider.isLoadingMessages
                                  ? Center(
                                      key: ValueKey<String>(
                                        'chat_message_loading_$conversationKey',
                                      ),
                                      child: CircularProgressIndicator(),
                                    )
                                  : shouldShowHeroState
                                  ? ChatConversationHero(
                                      key: ValueKey<String>(
                                        'chat_conversation_hero_$conversationKey',
                                      ),
                                      isServerRunning: provider.isServerRunning,
                                      isServerBusy:
                                          serverProvider?.isBusy == true,
                                      isModelLoading:
                                          provider.loadingModelId != null,
                                      hasModel: hasLoadedModel,
                                      onStartServer: serverProvider == null
                                          ? null
                                          : () {
                                              serverProvider.start();
                                            },
                                      onOpenModels: provider.isServerRunning
                                          ? () => _showModels(context)
                                          : null,
                                    )
                                  : Stack(
                                      key: ValueKey<String>(
                                        'chat_message_list_stack_$conversationKey',
                                      ),
                                      children: [
                                        Listener(
                                          onPointerSignal: _scrollCoordinator
                                              .handlePointerSignal,
                                          child: NotificationListener<ScrollNotification>(
                                            onNotification: _scrollCoordinator
                                                .handleMessageScrollNotification,
                                            child: ChatMessageList(
                                              key: const ValueKey<String>(
                                                'chat_message_list',
                                              ),
                                              controller: _scrollCoordinator
                                                  .scrollController,
                                              streamingMessages:
                                                  provider.streamingMessages,
                                              messages:
                                                  provider.visibleMessages,
                                              draftMessageId:
                                                  provider.draftMessageId,
                                              canManageMessages:
                                                  provider.canManageMessages,
                                              canRegenerateMessage:
                                                  provider.canRegenerateMessage,
                                              onCopyMessage: (message) =>
                                                  _handleCopyMessage(
                                                    context,
                                                    message,
                                                  ),
                                              onEditMessage: (message) =>
                                                  _handleEditMessage(
                                                    context,
                                                    message,
                                                  ),
                                              onDeleteMessage: (message) =>
                                                  _handleDeleteMessage(
                                                    context,
                                                    message,
                                                  ),
                                              onRegenerateMessage: (message) =>
                                                  _handleRegenerateMessage(
                                                    context,
                                                    message,
                                                  ),
                                              onShowMessageActions: (message) =>
                                                  _showMessageActions(
                                                    context,
                                                    message,
                                                  ),
                                              onSelectMessageVersion:
                                                  (message, versionIndex) =>
                                                      _handleSelectMessageVersion(
                                                        context,
                                                        message,
                                                        versionIndex,
                                                      ),
                                            ),
                                          ),
                                        ),
                                        if (_scrollCoordinator
                                            .showJumpToLatestButton)
                                          Positioned(
                                            right: 12,
                                            bottom: 12,
                                            child: FloatingActionButton.small(
                                              key: const Key(
                                                'chat_jump_to_latest_button',
                                              ),
                                              heroTag: null,
                                              tooltip:
                                                  context.l10n.chatJumpToLatest,
                                              onPressed: _scrollCoordinator
                                                  .jumpToLatestMessage,
                                              child: const Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ChatInputBar(
                            controller: _inputController,
                            hintText: _inputHintText(context, provider),
                            isServerRunning: serverProvider?.isRunning == true,
                            isServerBusy: serverProvider?.isBusy == true,
                            modelLabel: _modelSelectorLabel(context, provider),
                            canOpenModels: provider.canSelectModels,
                            isModelLoading: provider.loadingModelId != null,
                            hasLoadedModel: hasLoadedModel,
                            onToggleServer: serverProvider == null
                                ? null
                                : () => serverProvider.toggle(),
                            onOpenModels: () => _showModels(context),
                            canSend: provider.canSend,
                            isSending: provider.isSending,
                            onSend: () => _send(context),
                            onStop: provider.cancelStreaming,
                            onPickFromGallery: () => _pickFromGallery(context),
                            pendingImageAttachments:
                                provider.pendingImageAttachments,
                            onRemoveImageAttachment:
                                provider.removeImageAttachment,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

String _sessionTitle(BuildContext context, ChatProvider provider) {
  return provider.selectedSession?.title ?? context.l10n.chatNewSession;
}

String _inputHintText(BuildContext context, ChatProvider provider) {
  final l10n = context.l10n;
  if (!provider.isServerRunning) {
    return l10n.chatInputHintStartServer;
  }
  if (provider.loadingModelId != null) {
    return l10n.chatInputHintLoadingModel;
  }
  if (provider.currentModelId == null) {
    return l10n.chatInputHintSelectModel;
  }
  if (provider.currentModel?.isLoaded != true) {
    return l10n.chatInputHintModelUnavailable;
  }
  return l10n.chatInputHintEnterMessage;
}

String _modelSelectorLabel(BuildContext context, ChatProvider provider) {
  final model = provider.currentModel;
  if (model != null && model.isLoaded) {
    return model.displayName;
  }
  return context.l10n.chatSelectModel;
}
