import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/chat_image_widgets.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.streamingMessages,
    required this.messages,
    required this.draftMessageId,
    required this.canManageMessages,
    required this.canRegenerateMessage,
    required this.onCopyMessage,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onRegenerateMessage,
    required this.onShowMessageActions,
    required this.onSelectMessageVersion,
  });

  final ScrollController controller;
  final StreamingChatMessageNotifier streamingMessages;
  final List<ChatMessageRecord> messages;
  final String? draftMessageId;
  final bool canManageMessages;
  final bool Function(String messageId) canRegenerateMessage;
  final Future<void> Function(ChatMessageRecord message) onCopyMessage;
  final Future<void> Function(ChatMessageRecord message) onEditMessage;
  final Future<void> Function(ChatMessageRecord message) onDeleteMessage;
  final Future<void> Function(ChatMessageRecord message) onRegenerateMessage;
  final Future<void> Function(ChatMessageRecord message) onShowMessageActions;
  final Future<void> Function(ChatMessageRecord message, int versionIndex)
  onSelectMessageVersion;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isDraft = message.id == draftMessageId;
        final streamingListenable = streamingMessages.listenableFor(message.id);
        if (streamingListenable != null) {
          return ValueListenableBuilder<StreamingChatMessageData>(
            valueListenable: streamingListenable,
            builder: (context, data, _) {
              final streamingMessage = data.message;
              return RepaintBoundary(
                key: ValueKey<String>(
                  'chat_message_repaint_${streamingMessage.id}',
                ),
                child: _MessageBubble(
                  key: ValueKey<String>(streamingMessage.id),
                  message: streamingMessage,
                  isDraft: data.isStreaming || isDraft,
                  canManageMessages: canManageMessages,
                  canRegenerate: canRegenerateMessage(streamingMessage.id),
                  onCopy: () => onCopyMessage(streamingMessage),
                  onEdit: () => onEditMessage(streamingMessage),
                  onDelete: () => onDeleteMessage(streamingMessage),
                  onRegenerate: () => onRegenerateMessage(streamingMessage),
                  onShowActions: () => onShowMessageActions(streamingMessage),
                  onSelectVersion: (versionIndex) =>
                      onSelectMessageVersion(streamingMessage, versionIndex),
                ),
              );
            },
          );
        }
        return RepaintBoundary(
          key: ValueKey<String>('chat_message_repaint_${message.id}'),
          child: _MessageBubble(
            key: ValueKey<String>(message.id),
            message: message,
            isDraft: isDraft,
            canManageMessages: canManageMessages,
            canRegenerate: canRegenerateMessage(message.id),
            onCopy: () => onCopyMessage(message),
            onEdit: () => onEditMessage(message),
            onDelete: () => onDeleteMessage(message),
            onRegenerate: () => onRegenerateMessage(message),
            onShowActions: () => onShowMessageActions(message),
            onSelectVersion: (versionIndex) =>
                onSelectMessageVersion(message, versionIndex),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isDraft,
    required this.canManageMessages,
    required this.canRegenerate,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onRegenerate,
    required this.onShowActions,
    required this.onSelectVersion,
  });

  final ChatMessageRecord message;
  final bool isDraft;
  final bool canManageMessages;
  final bool canRegenerate;
  final Future<void> Function() onCopy;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onRegenerate;
  final Future<void> Function() onShowActions;
  final Future<void> Function(int versionIndex) onSelectVersion;

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
    final userBubbleDecoration = BoxDecoration(
      color: colorScheme.secondaryContainer.withAlpha(92),
      borderRadius: BorderRadius.circular(22),
    );
    final footerColor = colorScheme.onSurfaceVariant;
    final canShowMessageActions = widget.canManageMessages && !isDraft;
    final showQuickActions = !isDraft;

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

    Widget wrapMessageActionTarget({
      required Widget child,
      required String keySuffix,
    }) {
      if (!canShowMessageActions) {
        return child;
      }
      return GestureDetector(
        key: Key('chat_message_target_${message.id}_$keySuffix'),
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          unawaited(widget.onShowActions());
        },
        child: child,
      );
    }

    final footer = buildFooter(includeModelName: !isUser);
    final contentWidget = hasVisibleContent
        ? RepaintBoundary(
            child: GptMarkdown(
              message.content.isEmpty && isDraft ? '...' : message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                height: 1.5,
              ),
            ),
          )
        : null;

    final userBubbleBody = wrapMessageActionTarget(
      keySuffix: 'bubble',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: userBubbleDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageFilePaths.isNotEmpty)
              MessageImageStrip(imageFilePaths: message.imageFilePaths),
            if (contentWidget != null) contentWidget,
          ],
        ),
      ),
    );

    final assistantContentBody = wrapMessageActionTarget(
      keySuffix: 'content',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contentWidget != null) contentWidget,
          if (showFooter) ...[
            if (contentWidget != null) const SizedBox(height: 10),
            footer,
          ],
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isUser) ...[
              userBubbleBody,
              if (showFooter) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: wrapMessageActionTarget(
                    keySuffix: 'footer',
                    child: footer,
                  ),
                ),
              ],
            ] else ...[
              if (hasReasoningContent) ...[
                Container(
                  key: Key('chat_message_reasoning_${message.id}'),
                  decoration: BoxDecoration(
                    color: reasoningBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: foregroundColor.withAlpha(210),
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
                          child: RepaintBoundary(
                            child: GptMarkdown(
                              reasoningContent,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: foregroundColor.withAlpha(210),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (contentWidget != null || showFooter) ...[
                if (hasReasoningContent) const SizedBox(height: 12),
                assistantContentBody,
              ],
            ],
            if (showQuickActions) ...[
              const SizedBox(height: 8),
              _MessageQuickActions(
                messageId: message.id,
                isUser: isUser,
                canUseActions: widget.canManageMessages,
                canRegenerate: widget.canRegenerate,
                currentVersionIndex: message.currentVersionIndex,
                versionCount: message.versionCount,
                onCopy: widget.onCopy,
                onEdit: widget.onEdit,
                onRegenerate: widget.onRegenerate,
                onShowActions: widget.onShowActions,
                onSelectVersion: widget.onSelectVersion,
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

class _MessageQuickActions extends StatelessWidget {
  const _MessageQuickActions({
    required this.messageId,
    required this.isUser,
    required this.canUseActions,
    required this.canRegenerate,
    required this.currentVersionIndex,
    required this.versionCount,
    required this.onCopy,
    required this.onEdit,
    required this.onRegenerate,
    required this.onShowActions,
    required this.onSelectVersion,
  });

  final String messageId;
  final bool isUser;
  final bool canUseActions;
  final bool canRegenerate;
  final int currentVersionIndex;
  final int versionCount;
  final Future<void> Function() onCopy;
  final Future<void> Function() onEdit;
  final Future<void> Function() onRegenerate;
  final Future<void> Function() onShowActions;
  final Future<void> Function(int versionIndex) onSelectVersion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MessageActionIconButton(
          buttonKey: Key('chat_message_copy_button_$messageId'),
          tooltip: context.l10n.chatCopyMessage,
          icon: Icons.content_copy_outlined,
          onPressed: canUseActions ? onCopy : null,
        ),
        _MessageActionIconButton(
          buttonKey: Key('chat_message_edit_button_$messageId'),
          tooltip: context.l10n.chatEditMessage,
          icon: Icons.edit_outlined,
          onPressed: canUseActions ? onEdit : null,
        ),
        _MessageActionIconButton(
          buttonKey: Key('chat_message_regenerate_button_$messageId'),
          tooltip: context.l10n.chatRegenerateMessage,
          icon: Icons.refresh_rounded,
          onPressed: canRegenerate ? onRegenerate : null,
        ),
        _MessageActionIconButton(
          buttonKey: Key('chat_message_more_button_$messageId'),
          tooltip: context.l10n.chatMoreActions,
          icon: Icons.more_horiz_rounded,
          onPressed: canUseActions ? onShowActions : null,
        ),
        if (!isUser && versionCount > 1)
          _MessageVersionSwitcher(
            messageId: messageId,
            currentVersionIndex: currentVersionIndex,
            versionCount: versionCount,
            canUseActions: canUseActions,
            onSelectVersion: onSelectVersion,
          ),
      ],
    );
  }
}

class _MessageVersionSwitcher extends StatelessWidget {
  const _MessageVersionSwitcher({
    required this.messageId,
    required this.currentVersionIndex,
    required this.versionCount,
    required this.canUseActions,
    required this.onSelectVersion,
  });

  final String messageId;
  final int currentVersionIndex;
  final int versionCount;
  final bool canUseActions;
  final Future<void> Function(int versionIndex) onSelectVersion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canGoPrevious = canUseActions && currentVersionIndex > 0;
    final canGoNext = canUseActions && currentVersionIndex < versionCount - 1;

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageVersionButton(
            buttonKey: Key('chat_message_version_previous_button_$messageId'),
            tooltip: context.l10n.chatPreviousMessageVersion,
            icon: Icons.chevron_left_rounded,
            onPressed: canGoPrevious
                ? () => onSelectVersion(currentVersionIndex - 1)
                : null,
          ),
          SizedBox(
            key: Key('chat_message_version_label_$messageId'),
            width: 38,
            child: Text(
              '${currentVersionIndex + 1}/$versionCount',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _MessageVersionButton(
            buttonKey: Key('chat_message_version_next_button_$messageId'),
            tooltip: context.l10n.chatNextMessageVersion,
            icon: Icons.chevron_right_rounded,
            onPressed: canGoNext
                ? () => onSelectVersion(currentVersionIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _MessageVersionButton extends StatelessWidget {
  const _MessageVersionButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () {
              unawaited(onPressed!.call());
            },
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: colorScheme.onSurfaceVariant,
      disabledColor: colorScheme.onSurfaceVariant.withAlpha(90),
      splashRadius: 16,
      constraints: const BoxConstraints.tightFor(width: 28, height: 36),
      icon: Icon(icon),
    );
  }
}

class _MessageActionIconButton extends StatelessWidget {
  const _MessageActionIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () {
              unawaited(onPressed!.call());
            },
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: colorScheme.onSurfaceVariant,
      disabledColor: colorScheme.onSurfaceVariant.withAlpha(90),
      splashRadius: 18,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(icon),
    );
  }
}
