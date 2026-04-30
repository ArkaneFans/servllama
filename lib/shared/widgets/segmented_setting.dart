import 'package:flutter/material.dart';

class SegmentedSettingOption<T> {
  const SegmentedSettingOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class SegmentedSetting<T> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final T value;
  final List<SegmentedSettingOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: colorScheme.primary);
                }
                return BorderSide(color: colorScheme.outlineVariant);
              }),
            ),
            segments: [
              for (final option in options)
                ButtonSegment<T>(
                  value: option.value,
                  label: Text(option.label),
                ),
            ],
            selected: {value},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) {
                return;
              }
              onChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }
}
