import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/l10n/l10n.dart';

/// Renders the orchestration steps as one ordered checklist. Because the
/// adapters emit their own phase order, `llama.cpp` (server → model) and MNN
/// (model → server) both land in this single widget without the page knowing
/// which order it is looking at.
class RuntimePhaseList extends StatelessWidget {
  const RuntimePhaseList({
    super.key,
    required this.current,
    required this.completed,
    required this.port,
    required this.hint,
  });

  final RuntimePhase? current;
  final List<RuntimePhase> completed;
  final int port;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isLight = theme.brightness == Brightness.light;

    final phases = <RuntimePhase>[
      ...completed,
      if (current != null && !completed.contains(current)) current!,
    ];

    return DecoratedBox(
      key: const Key('server_page_phase_list'),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final phase in phases)
              _PhaseRow(
                label: RuntimeLabels.phase(l10n, phase, port),
                isCurrent: phase == current,
              ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.label, required this.isCurrent});

  final String label;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: isCurrent
                ? CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: palette.warningMark,
                  )
                : Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: palette.okMark,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
