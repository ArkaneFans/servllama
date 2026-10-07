import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servllama/l10n/l10n.dart';

/// A welcome surface shared by local, remote and unconfigured empty chats.
class ChatConversationHero extends StatelessWidget {
  const ChatConversationHero({
    super.key,
    this.now,
    required this.serverStatus,
    required this.onServer,
    required this.onTranscribe,
    required this.onSynthesize,
  });

  final String serverStatus;
  final DateTime? now;
  final VoidCallback onServer, onTranscribe, onSynthesize;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final hour = (now ?? DateTime.now()).hour;
    final greeting = switch (hour) {
      >= 5 && < 11 => l.chatGreetingMorning,
      >= 11 && < 14 => l.chatGreetingNoon,
      >= 14 && < 18 => l.chatGreetingAfternoon,
      _ => l.chatGreetingEvening,
    };
    final daytime = hour >= 5 && hour < 18;
    // Decorative feature accents, independent of engine identity/status colors.
    final serverAccent = Color(dark ? 0xFF78C5EE : 0xFF227BAA);
    final transcribeAccent = Color(dark ? 0xFFF1C36F : 0xFFA4660C);
    final synthesizeAccent = Color(dark ? 0xFF74D2B4 : 0xFF248269);
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
                      SvgPicture.asset(
                        'assets/app_icon.svg',
                        key: const Key('chat_welcome_app_icon'),
                        width: compact ? 64 : 108,
                        height: compact ? 64 : 108,
                        semanticsLabel: l.appTitle,
                      ),
                      SizedBox(height: compact ? 8 : 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              daytime
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nights_stay_outlined,
                              key: const Key('chat_welcome_time_icon'),
                              size: compact ? 24 : 28,
                              color: daytime
                                  ? transcribeAccent
                                  : colors.primary,
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
                                fontSize: compact ? 24 : 28,
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
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: compact ? 20 : 28),
                      _WelcomeAction(
                        key: const Key('chat_welcome_server'),
                        icon: Icons.dns_outlined,
                        accent: serverAccent,
                        label: l.serverTitle,
                        detail: serverStatus,
                        onTap: onServer,
                      ),
                      const SizedBox(height: 12),
                      _WelcomeAction(
                        key: const Key('chat_welcome_asr'),
                        icon: Icons.mic_none_rounded,
                        accent: transcribeAccent,
                        label: l.chatWelcomeTranscribe,
                        detail: l.chatWelcomeTranscribeHint,
                        onTap: onTranscribe,
                      ),
                      const SizedBox(height: 12),
                      _WelcomeAction(
                        key: const Key('chat_welcome_tts'),
                        icon: Icons.graphic_eq_rounded,
                        accent: synthesizeAccent,
                        label: l.chatWelcomeSynthesize,
                        detail: l.chatWelcomeSynthesizeHint,
                        onTap: onSynthesize,
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
    required this.accent,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String label, detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: theme.brightness == Brightness.dark ? .14 : .09,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 25, color: accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(detail, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
