import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/widgets/reasoning_level_icon.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

extension ReasoningLevelPresentation on ReasoningLevel {
  String label(AppLocalizations l) => switch (this) {
    ReasoningLevel.off => l.reasoningOff,
    ReasoningLevel.auto => l.reasoningAuto,
    ReasoningLevel.low => l.reasoningLow,
    ReasoningLevel.medium => l.reasoningMedium,
    ReasoningLevel.high => l.reasoningHigh,
    ReasoningLevel.xhigh => l.reasoningXhigh,
    ReasoningLevel.max => l.reasoningMax,
  };
}

Future<void> showReasoningLevelPicker(
  BuildContext context, {
  required ReasoningLevel value,
  required Future<void> Function(ReasoningLevel) onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ReasoningLevelPicker(value: value, onChanged: onChanged),
);

class ReasoningLevelPicker extends StatefulWidget {
  const ReasoningLevelPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ReasoningLevel value;
  final Future<void> Function(ReasoningLevel) onChanged;

  @override
  State<ReasoningLevelPicker> createState() => _ReasoningLevelPickerState();
}

class _ReasoningLevelPickerState extends State<ReasoningLevelPicker> {
  late ReasoningLevel selected = widget.value;
  late ReasoningLevel saved = widget.value;
  bool saving = false;

  Future<void> _commit() async {
    if (selected == saved) return;
    setState(() => saving = true);
    await runUiAction(context, () async {
      await widget.onChanged(selected);
      saved = selected;
    });
    if (mounted) {
      setState(() {
        selected = saved;
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final color = selected == ReasoningLevel.off
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.reasoningDepth, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            ReasoningLevelIcon(level: selected, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              selected.label(l),
              key: const Key('reasoning_level_value'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
            Slider(
              key: const Key('reasoning_level_slider'),
              value: selected.index.toDouble(),
              max: (ReasoningLevel.values.length - 1).toDouble(),
              divisions: ReasoningLevel.values.length - 1,
              label: selected.label(l),
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                      selected = ReasoningLevel.values[value.round()];
                    }),
              onChangeEnd: saving ? null : (_) => _commit(),
            ),
            Text(
              l.reasoningDepthHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
