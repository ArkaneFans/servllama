import 'package:flutter/material.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// The one card that answers "is it up, what is it serving, where do I point
/// my client". Deliberately carries no memory / speed / throughput readouts —
/// those have no bearing on that question and the two engines cannot report
/// them consistently (design decision D7).
class RuntimeHeroCard extends StatelessWidget {
  const RuntimeHeroCard({
    super.key,
    required this.state,
    required this.displayUrl,
    required this.selectedModelId,
    required this.selectedModelName,
    required this.canStart,
    required this.onSelectModel,
    required this.onToggle,
    required this.onCopyUrl,
  });

  final EngineRuntimeState state;
  final String displayUrl;
  final String? selectedModelId;
  final String? selectedModelName;
  final bool canStart;
  final VoidCallback onSelectModel;
  final VoidCallback onToggle;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isLight = theme.brightness == Brightness.light;
    final statusLabel = state.isBusy && state.phase != null
        ? RuntimeLabels.phase(l10n, state.phase!)
        : RuntimeLabels.status(l10n, state.status);

    return DecoratedBox(
      key: const Key('server_page_status_card'),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(label: statusLabel, tone: _tone),
                const Spacer(),
                EngineBadge(engine: state.engine),
              ],
            ),
            if (state.isRunning && state.startedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.serverUptime(
                  RuntimeLabels.uptime(
                    l10n,
                    DateTime.now().difference(state.startedAt!),
                  ),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _ModelRow(
              engine: state.engine,
              modelName: selectedModelName,
              hasModel: selectedModelId != null,
              onTap: state.isBusy ? null : onSelectModel,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.serverBaseUrlLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _BaseUrlPanel(
              baseUrl: displayUrl,
              enabled: state.isRunning,
              onCopy: onCopyUrl,
            ),
            const SizedBox(height: 18),
            _PrimaryAction(
              state: state,
              canStart: canStart,
              onToggle: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  StatusTone get _tone {
    switch (state.status) {
      case EngineRuntimeStatus.ready:
        return StatusTone.ok;
      case EngineRuntimeStatus.preparing:
      case EngineRuntimeStatus.stopping:
        return StatusTone.warning;
      case EngineRuntimeStatus.error:
        return StatusTone.danger;
      case EngineRuntimeStatus.idle:
        return StatusTone.idle;
    }
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.engine,
    required this.modelName,
    required this.hasModel,
    required this.onTap,
  });

  final InferenceEngine engine;
  final String? modelName;
  final bool hasModel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isLight = theme.brightness == Brightness.light;

    // Without a model, llama.cpp still starts and loads on demand, while MNN
    // cannot start at all — so the same empty row means different things.
    final subtitle = hasModel
        ? l10n.serverActiveModelLabel
        : (engine.requiresModelBeforeStart
              ? l10n.serverModelRequiredHint
              : l10n.serverNoModelSelectedHint);

    return Material(
      color: isLight
          ? const Color(0xFFF1F3F7)
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('server_page_model_row'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              ModelFormatBadge(engine: engine, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelName ?? l10n.serverNoModelSelected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasModel
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseUrlPanel extends StatelessWidget {
  const _BaseUrlPanel({
    required this.baseUrl,
    required this.enabled,
    required this.onCopy,
  });

  final String baseUrl;
  final bool enabled;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        key: const Key('server_page_base_url_panel'),
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFF1F3F7)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: enabled ? onCopy : null,
                tooltip: l10n.serverCopyBaseUrl,
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  minimumSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.content_copy_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.state,
    required this.canStart,
    required this.onToggle,
  });

  final EngineRuntimeState state;
  final bool canStart;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isRunning = state.isRunning;
    final isPreparing = state.status == EngineRuntimeStatus.preparing;
    final isStopping = state.status == EngineRuntimeStatus.stopping;
    final enabled = isPreparing || (isRunning ? !isStopping : canStart);

    final String label;
    if (isPreparing) {
      label = l10n.serverCancelPreparation;
    } else if (isStopping) {
      label = l10n.serverStatusStopping;
    } else {
      label = isRunning ? l10n.serverStop : l10n.serverStart;
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('server_page_toggle_button'),
        onPressed: enabled ? onToggle : null,
        icon: isStopping
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: colorScheme.onPrimary,
                ),
              )
            : Icon(
                isPreparing
                    ? Icons.close_rounded
                    : (isRunning
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded),
                size: 20,
              ),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: isRunning
              ? colorScheme.errorContainer
              : colorScheme.primary,
          foregroundColor: isRunning
              ? colorScheme.onErrorContainer
              : colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
