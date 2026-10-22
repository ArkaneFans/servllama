import 'package:flutter/material.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/theme/app_visual_theme.dart';

/// A welcome surface shared by local, remote and unconfigured empty chats.
class ChatConversationHero extends StatelessWidget {
  const ChatConversationHero({
    super.key,
    this.now,
    required this.onServer,
    required this.onSpeech,
  });

  final DateTime? now;
  final VoidCallback onServer, onSpeech;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = (now ?? DateTime.now()).hour;
    final greeting = switch (hour) {
      >= 5 && < 11 => l.chatGreetingMorning,
      >= 11 && < 14 => l.chatGreetingNoon,
      >= 14 && < 18 => l.chatGreetingAfternoon,
      _ => l.chatGreetingEvening,
    };
    final daytime = hour >= 5 && hour < 18;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 420 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return SingleChildScrollView(
          key: const Key('chat_welcome_scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: const Alignment(0, -.24),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: compact ? 12 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              daytime
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nights_stay_outlined,
                              key: const Key('chat_welcome_time_icon'),
                              size: compact ? 20 : 22,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              greeting,
                              key: const Key('chat_welcome_greeting'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontSize: compact ? 20 : 22,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.chatWelcomeDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: compact ? 16 : 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: compact ? 20 : 28),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _WelcomeAction(
                                key: const Key('chat_welcome_server'),
                                icon: Icons.dns_outlined,
                                label: l.serverTitle,
                                onTap: onServer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _WelcomeAction(
                                key: const Key('chat_welcome_speech'),
                                icon: Icons.graphic_eq_rounded,
                                label: l.v2Speech,
                                onTap: onSpeech,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      child: Material(
        color: colors.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppVisualTheme.cardRadius),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 24, color: colors.primary),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
