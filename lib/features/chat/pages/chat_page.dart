import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, this.provider, this.onNavigateToServer});

  final ChatProvider? provider;
  final VoidCallback? onNavigateToServer;

  @override
  Widget build(BuildContext context) {
    final existingProvider = provider;
    if (existingProvider != null) {
      return ChangeNotifierProvider<ChatProvider>.value(
        value: existingProvider,
        child: _ChatView(onNavigateToServer: onNavigateToServer),
      );
    }
    return _ChatView(onNavigateToServer: onNavigateToServer);
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({this.onNavigateToServer});

  final VoidCallback? onNavigateToServer;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  ChatProvider? _provider;
  int _lastMessageCount = 0;

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
    if (identical(provider, _provider)) {
      return;
    }
    _provider?.removeListener(_handleProviderChanged);
    _provider = provider;
    _lastMessageCount = provider.visibleMessages.length;
    provider.addListener(_handleProviderChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleProviderChanged);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleProviderChanged() {
    final provider = _provider;
    if (provider == null) {
      return;
    }

    final shouldAutoScroll = _isNearBottom();
    final count = provider.visibleMessages.length;
    final countIncreased = count > _lastMessageCount;
    _lastMessageCount = count;
    if (shouldAutoScroll && countIncreased) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 72;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      return;
    }
    _inputController.clear();
    await context.read<ChatProvider>().sendMessage(text);
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: _ModelSheetContent(
                provider: provider,
                onRefresh: () => provider.refreshModels(),
                children: [
                  _ModelSection(
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
                  const SizedBox(height: 16),
                  _ModelSection(
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final serverProvider = context.watch<ServerProvider?>();
        final hasLoadedModel = provider.currentModel?.isLoaded == true;
        final shouldShowHeroState =
            provider.visibleMessages.isEmpty &&
            (!provider.isServerRunning || !hasLoadedModel);

        return Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leadingWidth: 52,
              titleSpacing: 4,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
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
                              child: shouldShowHeroState
                                  ? _ConversationHero(
                                      key: const ValueKey<String>(
                                        'chat_conversation_hero',
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
                                  : _MessageList(
                                      key: const ValueKey<String>(
                                        'chat_message_list',
                                      ),
                                      controller: _scrollController,
                                      messages: provider.visibleMessages,
                                      draftMessageId: provider.draftMessageId,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _InputBar(
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

class _ModelSheetContent extends StatelessWidget {
  const _ModelSheetContent({
    required this.provider,
    required this.onRefresh,
    required this.children,
  });

  final ChatProvider provider;
  final VoidCallback onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showInitialLoading =
        provider.isRefreshingModels && provider.models.isEmpty;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.chatSelectModel, style: titleStyle),
            const Spacer(),
            IconButton(
              onPressed: provider.isRefreshingModels ? null : onRefresh,
              tooltip: l10n.chatRefreshModels,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (showInitialLoading)
          const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                key: Key('chat_model_sheet_loading_indicator'),
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _ConversationHero extends StatelessWidget {
  const _ConversationHero({
    super.key,
    required this.isServerRunning,
    required this.isServerBusy,
    required this.isModelLoading,
    required this.hasModel,
    required this.onStartServer,
    required this.onOpenModels,
  });

  final bool isServerRunning;
  final bool isServerBusy;
  final bool isModelLoading;
  final bool hasModel;
  final VoidCallback? onStartServer;
  final VoidCallback? onOpenModels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final heroTitleColor = isLight
        ? const Color(0xFF171B24)
        : colorScheme.onSurface.withAlpha(236);
    final heroDescriptionColor = isLight
        ? const Color(0xFF7D8698)
        : colorScheme.onSurfaceVariant.withAlpha(210);
    final heroButtonBackgroundColor = _chatActionButtonBackgroundColor(
      brightness,
    );
    final heroButtonForegroundColor = _chatActionButtonForegroundColor(
      brightness,
    );
    var description = l10n.chatHeroDescriptionReady;
    if (!isServerRunning) {
      description = l10n.chatHeroDescriptionStartServer;
    } else if (!hasModel) {
      description = l10n.chatHeroDescriptionSelectModel;
    }

    String? actionLabel;
    VoidCallback? onAction;
    final isActionBusy = isServerBusy || isModelLoading;

    if (!isServerRunning) {
      actionLabel = isServerBusy
          ? l10n.chatStartingServer
          : l10n.chatStartServer;
      onAction = isServerBusy ? null : onStartServer;
    } else if (!hasModel) {
      actionLabel = isModelLoading
          ? l10n.chatLoadingModel
          : l10n.chatSelectModel;
      onAction = isModelLoading ? null : onOpenModels;
    }

    return Align(
      key: const Key('chat_conversation_hero_align'),
      alignment: const Alignment(0, -0.236),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('chat_empty_state_logo'),
              width: 118,
              height: 118,
              child: SvgPicture.asset('assets/app_icon.svg'),
            ),
            Text(
              l10n.chatHeroTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) + 4,
                fontWeight: FontWeight.w500,
                color: heroTitleColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 292),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: heroDescriptionColor,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              FilledButton(
                key: const Key('chat_empty_state_action_button'),
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: heroButtonBackgroundColor,
                  disabledBackgroundColor: heroButtonBackgroundColor.withAlpha(
                    isLight ? 190 : 210,
                  ),
                  foregroundColor: heroButtonForegroundColor,
                  disabledForegroundColor: heroButtonForegroundColor.withAlpha(
                    214,
                  ),
                  minimumSize: const Size(0, 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 44,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                  elevation: 0,
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isActionBusy
                      ? Row(
                          key: ValueKey<String>(actionLabel),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              key: const Key(
                                'chat_empty_state_action_progress',
                              ),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  heroButtonForegroundColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(actionLabel),
                          ],
                        )
                      : Text(actionLabel, key: ValueKey<String>(actionLabel)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hintText,
    required this.isServerRunning,
    required this.isServerBusy,
    required this.modelLabel,
    required this.canOpenModels,
    required this.isModelLoading,
    required this.hasLoadedModel,
    required this.canSend,
    required this.isSending,
    required this.onToggleServer,
    required this.onOpenModels,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isServerRunning;
  final bool isServerBusy;
  final String modelLabel;
  final bool canOpenModels;
  final bool isModelLoading;
  final bool hasLoadedModel;
  final bool canSend;
  final bool isSending;
  final VoidCallback? onToggleServer;
  final VoidCallback onOpenModels;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final panelBorderColor = colorScheme.outlineVariant.withAlpha(
      isLight ? 190 : 128,
    );
    final panelBackgroundColor = colorScheme.surface;
    final actionButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final actionButtonIconColor = _chatActionButtonBackgroundColor(brightness);
    final disabledModelButtonIconColor = _chatDisabledActionButtonIconColor(
      brightness,
    );
    final sendButtonBackgroundColor = isSending
        ? colorScheme.error
        : canSend
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final sendButtonForegroundColor = isSending
        ? colorScheme.onError
        : canSend
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              panelBackgroundColor.withAlpha(0),
              theme.scaffoldBackgroundColor.withAlpha(isLight ? 236 : 214),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
            decoration: BoxDecoration(
              color: panelBackgroundColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: panelBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 15 : 48),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(isLight ? 10 : 28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          if (value.text.isNotEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
                              child: Text(
                                hintText,
                                textAlign: TextAlign.left,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withAlpha(
                                    isLight ? 140 : 170,
                                  ),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
                        child: TextField(
                          key: const Key('chat_input_field'),
                          controller: controller,
                          minLines: 1,
                          maxLines: 6,
                          enabled: canSend,
                          textInputAction: TextInputAction.send,
                          cursorColor: colorScheme.primary,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.5,
                          ),
                          onSubmitted: (_) {
                            if (canSend) {
                              onSend();
                            }
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Tooltip(
                      message: isServerRunning
                          ? l10n.serverStop
                          : l10n.serverStart,
                      child: Semantics(
                        button: true,
                        label: isServerRunning
                            ? l10n.serverStop
                            : l10n.serverStart,
                        child: IconButton(
                          key: const Key('chat_server_toggle_button'),
                          onPressed: isServerBusy ? null : onToggleServer,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: actionButtonIconColor,
                            disabledForegroundColor: actionButtonIconColor,
                            minimumSize: const Size(42, 42),
                            padding: EdgeInsets.zero,
                            shape: actionButtonShape,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.dns_outlined,
                                size: 22,
                                color: actionButtonIconColor,
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  key: const Key('chat_server_status_badge'),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isServerRunning
                                        ? const Color(0xFF10B981)
                                        : colorScheme.outlineVariant,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: panelBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: modelLabel,
                      child: Semantics(
                        button: true,
                        label: modelLabel,
                        child: IconButton(
                          key: const Key('chat_model_selector_button'),
                          onPressed: canOpenModels ? onOpenModels : null,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: actionButtonIconColor,
                            disabledForegroundColor:
                                disabledModelButtonIconColor,
                            minimumSize: const Size(42, 42),
                            padding: EdgeInsets.zero,
                            shape: actionButtonShape,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: isModelLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: canOpenModels
                                        ? actionButtonIconColor
                                        : disabledModelButtonIconColor,
                                  ),
                                )
                              : Icon(
                                  Icons.memory_outlined,
                                  size: 22,
                                  color: canOpenModels
                                      ? actionButtonIconColor
                                      : disabledModelButtonIconColor,
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('chat_send_button'),
                      tooltip: isSending ? l10n.chatStop : l10n.chatSend,
                      onPressed: isSending ? onStop : (canSend ? onSend : null),
                      style: IconButton.styleFrom(
                        backgroundColor: sendButtonBackgroundColor,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
                        foregroundColor: sendButtonForegroundColor,
                        disabledForegroundColor: colorScheme.onSurfaceVariant
                            .withAlpha(170),
                        minimumSize: const Size(42, 42),
                        padding: EdgeInsets.zero,
                        shape: actionButtonShape,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        isSending ? Icons.stop_rounded : Icons.send_rounded,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.draftMessageId,
  });

  final ScrollController controller;
  final List<ChatMessageRecord> messages;
  final String? draftMessageId;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isDraft = message.id == draftMessageId;
        return _MessageBubble(
          key: ValueKey<String>(message.id),
          message: message,
          isDraft: isDraft,
        );
      },
    );
  }
}

class _ModelSection extends StatelessWidget {
  const _ModelSection({
    required this.title,
    required this.models,
    required this.currentModelId,
    required this.loadingModelId,
    required this.onTap,
    this.onSecondaryAction,
  });

  final String title;
  final List<ChatModelOption> models;
  final String? currentModelId;
  final String? loadingModelId;
  final ValueChanged<ChatModelOption>? onTap;
  final ValueChanged<ChatModelOption>? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.chatNoModels(title),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...models.map((model) {
            final isBusy = loadingModelId == model.id;
            final isSelected = currentModelId == model.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary.withAlpha(60)
                      : colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  model.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(_modelStatusLabel(context, model.status)),
                leading: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: model.isLoaded
                              ? colorScheme.primaryContainer
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          model.isLoaded
                              ? Icons.check_circle_outline_rounded
                              : Icons.memory_outlined,
                          color: model.isLoaded
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_outlined,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    if (onSecondaryAction != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        key: Key('chat_model_unload_button_${model.id}'),
                        tooltip: l10n.chatUnloadModel,
                        onPressed: isBusy
                            ? null
                            : () => onSecondaryAction!(model),
                        icon: const Icon(Icons.eject_outlined),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: onTap == null || isBusy ? null : () => onTap!(model),
              ),
            );
          }),
      ],
    );
  }

  String _modelStatusLabel(BuildContext context, ChatModelStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case ChatModelStatus.loaded:
        return l10n.chatModelStatusLoaded;
      case ChatModelStatus.loading:
        return l10n.chatModelStatusLoading;
      case ChatModelStatus.unloaded:
        return l10n.chatModelStatusAvailable;
      case ChatModelStatus.failed:
        return l10n.chatModelStatusFailed;
    }
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isDraft,
  });

  final ChatMessageRecord message;
  final bool isDraft;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isReasoningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isDraft = widget.isDraft;
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final foregroundColor = colorScheme.onSurface;
    final reasoningContent = message.reasoningContent?.trim() ?? '';
    final hasReasoningContent = reasoningContent.isNotEmpty;
    final hasVisibleContent =
        message.content.isNotEmpty || (isDraft && !hasReasoningContent);
    final showFooter = hasVisibleContent || hasReasoningContent || isDraft;
    final reasoningBackgroundColor = colorScheme.primaryContainer.withAlpha(
      110,
    );
    final reasoningBorderColor = colorScheme.primary.withAlpha(28);
    final userBubbleDecoration = BoxDecoration(
      color: colorScheme.secondaryContainer.withAlpha(92),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: colorScheme.outlineVariant.withAlpha(140)),
    );
    final footerColor = colorScheme.onSurfaceVariant;

    Widget buildFooter({required bool includeModelName}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: footerColor),
          ),
          if (includeModelName &&
              message.modelName != null &&
              message.modelName!.isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  message.modelName!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: footerColor,
                  ),
                ),
              ),
            ),
          if (isDraft) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: footerColor,
              ),
            ),
          ],
        ],
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: isUser
            ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82)
            : const BoxConstraints(),
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: isUser ? const EdgeInsets.all(16) : EdgeInsets.zero,
              decoration: isUser ? userBubbleDecoration : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasReasoningContent) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: reasoningBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: reasoningBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isReasoningExpanded = !_isReasoningExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.psychology_alt_outlined,
                                    size: 18,
                                    color: foregroundColor.withAlpha(210),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.chatReasoningProcess,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: foregroundColor.withAlpha(
                                              210,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    _isReasoningExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                    color: foregroundColor.withAlpha(210),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isReasoningExpanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: GptMarkdown(
                                reasoningContent,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: foregroundColor.withAlpha(210),
                                  height: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (hasVisibleContent) ...[
                    if (hasReasoningContent) const SizedBox(height: 12),
                    GptMarkdown(
                      message.content.isEmpty && isDraft
                          ? '...'
                          : message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (!isUser && showFooter) ...[
                    const SizedBox(height: 10),
                    buildFooter(includeModelName: true),
                  ],
                ],
              ),
            ),
            if (isUser && showFooter) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: buildFooter(includeModelName: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

Color _chatActionButtonBackgroundColor(Brightness brightness) {
  return brightness == Brightness.light
      ? const Color(0xFF565C68)
      : const Color(0xFF253042);
}

Color _chatActionButtonForegroundColor(Brightness brightness) {
  return brightness == Brightness.light
      ? Colors.white
      : const Color(0xFFF4F7FD);
}

Color _chatDisabledActionButtonIconColor(Brightness brightness) {
  final color = _chatActionButtonBackgroundColor(brightness);
  return color.withAlpha(brightness == Brightness.light ? 170 : 190);
}
