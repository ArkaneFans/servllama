import 'package:flutter/material.dart';
import 'package:servllama/features/chat/widgets/chat_image_widgets.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
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
    required this.onPickFromGallery,
    required this.pendingImageAttachments,
    required this.onRemoveImageAttachment,
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
  final VoidCallback onPickFromGallery;
  final List<String> pendingImageAttachments;
  final ValueChanged<int> onRemoveImageAttachment;

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
                if (pendingImageAttachments.isNotEmpty)
                  PendingImageStrip(
                    paths: pendingImageAttachments,
                    onRemove: onRemoveImageAttachment,
                  ),
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
                    Tooltip(
                      message: l10n.chatAttachImage,
                      child: Semantics(
                        button: true,
                        label: l10n.chatAttachImage,
                        child: IconButton(
                          key: const Key('chat_gallery_button'),
                          onPressed: canSend ? onPickFromGallery : null,
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
                          icon: Icon(
                            Icons.add,
                            size: 22,
                            color: canSend
                                ? actionButtonIconColor
                                : disabledModelButtonIconColor,
                          ),
                        ),
                      ),
                    ),
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

Color _chatActionButtonBackgroundColor(Brightness brightness) {
  return brightness == Brightness.light
      ? const Color(0xFF565C68)
      : const Color(0xFF253042);
}

Color _chatDisabledActionButtonIconColor(Brightness brightness) {
  final color = _chatActionButtonBackgroundColor(brightness);
  return color.withAlpha(brightness == Brightness.light ? 170 : 190);
}
