import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servllama/l10n/l10n.dart';

/// Chat empty state. Starting the runtime is an implementation detail the
/// user should not have to think about, so the only primary action here is
/// "pick a model" — the orchestrator brings the engine up behind it (FR-C1).
class ChatConversationHero extends StatelessWidget {
  const ChatConversationHero({
    super.key,
    required this.isPreparing,
    required this.preparingLabel,
    required this.hasLibraryModels,
    required this.onOpenModels,
    required this.onDiscoverModels,
  });

  /// The orchestrator is mid-flight (loading a model, binding the port…).
  final bool isPreparing;

  /// Phase text to show while [isPreparing]; falls back to a generic label.
  final String? preparingLabel;

  /// False on a fresh install, where the only useful action is downloading.
  final bool hasLibraryModels;

  final VoidCallback? onOpenModels;
  final VoidCallback? onDiscoverModels;

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

    final String description;
    final String actionLabel;
    final VoidCallback? onAction;

    if (isPreparing) {
      description = preparingLabel ?? l10n.chatPreparingModel;
      actionLabel = preparingLabel ?? l10n.chatPreparingModel;
      onAction = null;
    } else if (!hasLibraryModels) {
      // Nothing to pick yet, so the download entry is promoted to primary.
      description = l10n.chatEmptyNoModelsDescription;
      actionLabel = l10n.discoverTitle;
      onAction = onDiscoverModels;
    } else {
      description = l10n.chatEmptyDescription;
      actionLabel = l10n.chatEmptyAction;
      onAction = onOpenModels;
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
              l10n.chatEmptyTitle,
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
                child: isPreparing
                    ? Row(
                        key: ValueKey<String>(actionLabel),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            key: const Key('chat_empty_state_action_progress'),
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
            // Secondary entry so downloading stays one tap away even once the
            // primary action has become "pick a model".
            if (!isPreparing && hasLibraryModels)
              TextButton(
                key: const Key('chat_empty_state_discover_button'),
                onPressed: onDiscoverModels,
                style: TextButton.styleFrom(
                  foregroundColor: heroDescriptionColor,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(l10n.discoverTitle),
              ),
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
