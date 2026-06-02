import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatConversationHero extends StatelessWidget {
  const ChatConversationHero({
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
