import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  factory SettingsSection.form({
    Key? key,
    String? title,
    String? subtitle,
    required List<Widget> children,
  }) => SettingsSection(
    key: key,
    title: title,
    subtitle: subtitle,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: children,
    ),
  );

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
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
        Material(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}
