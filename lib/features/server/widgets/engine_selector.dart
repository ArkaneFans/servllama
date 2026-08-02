import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/inference_engine.dart';

/// Segmented control for the active engine. Disabled while anything is
/// running — switching engines mid-flight would need a stop/unload/start
/// rollback path, which design decision D5 exists to avoid.
class EngineSelector extends StatelessWidget {
  const EngineSelector({
    super.key,
    required this.selected,
    required this.enabled,
    required this.lockedHint,
    required this.onChanged,
  });

  final InferenceEngine selected;
  final bool enabled;
  final String lockedHint;
  final ValueChanged<InferenceEngine> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    final control = Container(
      key: const Key('server_engine_selector'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF1F3F7)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final engine in InferenceEngine.values)
            Expanded(
              child: _EngineSegment(
                engine: engine,
                isSelected: engine == selected,
                onTap: enabled ? () => onChanged(engine) : null,
              ),
            ),
        ],
      ),
    );

    if (enabled) {
      return control;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: 0.55,
          child: IgnorePointer(child: control),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            lockedHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EngineSegment extends StatelessWidget {
  const _EngineSegment({
    required this.engine,
    required this.isSelected,
    required this.onTap,
  });

  final InferenceEngine engine;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.palette.engineColor(engine);
    final isLight = theme.brightness == Brightness.light;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? (isLight ? Colors.white : theme.colorScheme.surfaceContainer)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(isLight ? 18 : 60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                engine.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
