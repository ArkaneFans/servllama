import 'package:flutter/material.dart';

class ChoiceListOption<T> {
  const ChoiceListOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A vertically stacked single-choice list styled like the other setting
/// widgets. Suited to dynamic option sets whose labels are too long for
/// [SegmentedButton].
class ChoiceListSetting<T> extends StatelessWidget {
  const ChoiceListSetting({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String? description;
  final T value;
  final List<ChoiceListOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

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
        const SizedBox(height: 6),
        for (final option in options)
          _ChoiceRow(
            label: option.label,
            selected: option.value == value,
            enabled: enabled,
            onTap: enabled ? () => onChanged(option.value) : null,
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disabledColor = colorScheme.onSurface.withAlpha(97);
    final iconColor = !enabled
        ? disabledColor
        : selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final textColor = enabled ? colorScheme.onSurface : disabledColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
