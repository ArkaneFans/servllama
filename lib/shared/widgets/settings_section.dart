import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (subtitle != null) ...[
          if (title != null) const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (title != null || subtitle != null) const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(110),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}
