import 'package:flutter/material.dart';
import 'package:servllama/l10n/l10n.dart';

enum AppMessageTone { success, info, warning, error }

class AppMessageCard extends StatelessWidget {
  const AppMessageCard({
    super.key,
    required this.text,
    required this.tone,
    required this.onClose,
  });
  final String text;
  final AppMessageTone tone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final (foreground, background, icon) = switch (tone) {
      AppMessageTone.success => (
        Color(dark ? 0xFF9DD9B9 : 0xFF32654D),
        Color(dark ? 0xFF23392F : 0xFFE6F3EC),
        Icons.check_circle_outline_rounded,
      ),
      AppMessageTone.info => (
        c.onPrimaryContainer,
        c.primaryContainer,
        Icons.info_outline_rounded,
      ),
      AppMessageTone.warning => (
        Color(dark ? 0xFFE9C37B : 0xFF80601F),
        Color(dark ? 0xFF3D3422 : 0xFFF8F0DB),
        Icons.warning_amber_rounded,
      ),
      AppMessageTone.error => (
        c.onErrorContainer,
        c.errorContainer,
        Icons.error_outline_rounded,
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          key: const Key('app_top_message'),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: foreground.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('app_close_message'),
                  tooltip: context.l10n.commonDismissMessage,
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: foreground, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
