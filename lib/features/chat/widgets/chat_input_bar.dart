import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
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
    this.canAttachImages = true,
    required this.isSending,
    required this.onServerAction,
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
  final bool canAttachImages;
  final bool isSending;
  final VoidCallback? onServerAction;
  final VoidCallback onOpenModels;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickFromGallery;
  final List<String> pendingImageAttachments;
  final ValueChanged<int> onRemoveImageAttachment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final actionStyle = IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      foregroundColor: c.onSurfaceVariant,
      disabledForegroundColor: c.onSurfaceVariant.withValues(alpha: .45),
      backgroundColor: Colors.transparent,
      shape: const StadiumBorder(),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
        child: Material(
          key: const Key('chat_composer_surface'),
          color: c.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: c.outlineVariant),
          ),
          child: Padding(
            // A centered 20 dp icon in a 48 dp button adds 14 dp inset.
            // Keep its left edge aligned with the text at 6 + 14 = 20 dp.
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pendingImageAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: PendingImageStrip(
                      paths: pendingImageAttachments,
                      onRemove: onRemoveImageAttachment,
                    ),
                  ),
                TextField(
                  key: const Key('chat_input_field'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  enabled: !isSending,
                  textInputAction: TextInputAction.send,
                  style: theme.textTheme.bodyLarge,
                  onSubmitted: (_) {
                    if (canSend) onSend();
                  },
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      key: const Key('chat_server_toggle_button'),
                      tooltip: isServerRunning ? l.serverStop : l.serverStart,
                      onPressed: isServerBusy ? null : onServerAction,
                      style: actionStyle,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.dns_outlined,
                            size: 20,
                            color: c.onSurfaceVariant,
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
                                    ? theme.palette.okMark
                                    : theme.palette.idleMark,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.surfaceContainerLowest,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('chat_model_selector_button'),
                      tooltip: modelLabel,
                      onPressed: canOpenModels ? onOpenModels : null,
                      style: actionStyle,
                      icon: const Icon(Icons.layers_outlined, size: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('chat_gallery_button'),
                      tooltip: canAttachImages
                          ? l.chatAttachImage
                          : l.v2ModelImagesUnavailable,
                      onPressed: canSend && canAttachImages
                          ? onPickFromGallery
                          : null,
                      style: actionStyle,
                      icon: const Icon(Icons.add, size: 20),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final ready =
                            canSend &&
                            (value.text.trim().isNotEmpty ||
                                pendingImageAttachments.isNotEmpty);
                        return IconButton.filledTonal(
                          key: const Key('chat_send_button'),
                          tooltip: isSending ? l.chatStop : l.chatSend,
                          onPressed: isSending
                              ? onStop
                              : ready
                              ? onSend
                              : null,
                          style: IconButton.styleFrom(
                            // A small visible disc inside the standard 48 dp
                            // Material tap target, like the other toolbar icons.
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            visualDensity: VisualDensity.standard,
                            padding: EdgeInsets.zero,
                            backgroundColor: isSending
                                ? c.errorContainer
                                : c.primaryContainer,
                            foregroundColor: isSending
                                ? c.onErrorContainer
                                : c.onPrimaryContainer,
                            disabledBackgroundColor: c.onSurface.withValues(
                              alpha: .08,
                            ),
                            disabledForegroundColor: c.onSurface.withValues(
                              alpha: .38,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: Icon(
                            isSending
                                ? Icons.stop_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                          ),
                        );
                      },
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
