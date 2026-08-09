import 'package:flutter/material.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Lets the chat input choose which idle inference engine should be started.
class ChatEngineStartSheet extends StatelessWidget {
  const ChatEngineStartSheet({
    super.key,
    required this.currentEngine,
    required this.defaultModelNames,
    required this.onSelect,
  });

  final InferenceEngine currentEngine;
  final Map<InferenceEngine, String?> defaultModelNames;
  final ValueChanged<InferenceEngine> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.chatStartServer,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chatChooseEngineToStart,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            for (final engine in InferenceEngine.values) ...[
              _EngineStartOption(
                engine: engine,
                isCurrent: engine == currentEngine,
                defaultModelName: defaultModelNames[engine],
                onTap: () => onSelect(engine),
              ),
              if (engine != InferenceEngine.values.last)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _EngineStartOption extends StatelessWidget {
  const _EngineStartOption({
    required this.engine,
    required this.isCurrent,
    required this.defaultModelName,
    required this.onTap,
  });

  final InferenceEngine engine;
  final bool isCurrent;
  final String? defaultModelName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final modelName = defaultModelName ?? l10n.serverNoModelSelected;

    return Material(
      color: isCurrent
          ? colorScheme.primaryContainer.withAlpha(90)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCurrent
              ? colorScheme.primary.withAlpha(150)
              : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('chat_engine_start_option_${engine.storageValue}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ModelFormatBadge(engine: engine, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EngineBadge(engine: engine, compact: true),
                    const SizedBox(height: 7),
                    Text(
                      l10n.chatEngineDefaultModel(modelName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
