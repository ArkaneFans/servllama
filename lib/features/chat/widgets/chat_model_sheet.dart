import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Model picker for the chat page.
///
/// Only the active engine's models are listed: D5 forbids switching engines
/// while the service runs, so showing the other engine's models as unreachable
/// rows would only invite taps that cannot work (FR-C3). The other engine gets
/// one entry row that explains the constraint and routes to the server page.
class ChatModelSheet extends StatelessWidget {
  const ChatModelSheet({
    super.key,
    required this.engine,
    required this.models,
    required this.activeModelId,
    required this.pendingModelId,
    required this.downloading,
    required this.otherEngineCount,
    required this.errorText,
    required this.onSelect,
    required this.onOpenOtherEngine,
    required this.onDiscover,
  });

  final InferenceEngine engine;

  /// Library models belonging to [engine] only.
  final List<LibraryModel> models;

  /// The model the runtime is currently serving, if any.
  final String? activeModelId;

  /// The model an in-flight `activateModel` call is switching to.
  final String? pendingModelId;

  final List<DownloadTaskView> downloading;
  final int otherEngineCount;
  final String? errorText;

  final ValueChanged<LibraryModel> onSelect;
  final VoidCallback onOpenOtherEngine;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final active = _findActive();
    final switchable = models
        .where((model) => model.runtimeId != activeModelId)
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatSelectModel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                EngineBadge(engine: engine),
              ],
            ),
            // llama.cpp hot-swaps without dropping the socket, so this warning
            // would be a lie there; only MNN restarts on a model change.
            if (engine.restartsOnModelSwap) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                key: const Key('chat_model_sheet_mnn_notice'),
                tone: StatusTone.warning,
                icon: Icons.autorenew_rounded,
                message: l10n.chatMnnSwapNotice,
              ),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                key: const Key('chat_model_sheet_error'),
                tone: StatusTone.danger,
                icon: Icons.error_outline_rounded,
                message: errorText!,
              ),
            ],
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (active != null) ...[
                    _SectionLabel(l10n.chatCurrentRunning),
                    _ModelRow(
                      model: active,
                      isActive: true,
                      isPending: pendingModelId == active.runtimeId,
                      onTap: null,
                    ),
                  ],
                  if (switchable.isNotEmpty) ...[
                    _SectionLabel(
                      l10n.chatSameEngineModels(engine.displayName),
                    ),
                    ...switchable.map(
                      (model) => _ModelRow(
                        model: model,
                        isActive: false,
                        isPending: pendingModelId == model.runtimeId,
                        onTap: pendingModelId == null
                            ? () => onSelect(model)
                            : null,
                      ),
                    ),
                  ],
                  if (models.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            l10n.serverNoModelsForEngine(engine.displayName),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            key: const Key('chat_model_sheet_discover'),
                            onPressed: onDiscover,
                            icon: const Icon(Icons.travel_explore_rounded),
                            label: Text(l10n.discoverTitle),
                          ),
                        ],
                      ),
                    ),
                  if (downloading.isNotEmpty) ...[
                    _SectionLabel(l10n.downloadStatusRunning),
                    ...downloading.map(
                      (task) => _DownloadingRow(key: Key(
                        'chat_model_sheet_downloading_${task.id}',
                      ), task: task),
                    ),
                  ],
                  if (otherEngineCount > 0) ...[
                    _SectionLabel(l10n.chatOtherEngines),
                    ListTile(
                      key: const Key('chat_model_sheet_other_engine'),
                      contentPadding: EdgeInsets.zero,
                      leading: ModelFormatBadge(engine: _otherEngine, size: 40),
                      title: Text(
                        l10n.chatOtherEnginesEntry(
                          _otherEngine.displayName,
                          otherEngineCount,
                        ),
                      ),
                      subtitle: Text(l10n.chatOtherEnginesHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onOpenOtherEngine,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InferenceEngine get _otherEngine => engine == InferenceEngine.llamaCpp
      ? InferenceEngine.mnn
      : InferenceEngine.llamaCpp;

  LibraryModel? _findActive() {
    if (activeModelId == null) {
      return null;
    }
    for (final model in models) {
      if (model.runtimeId == activeModelId) {
        return model;
      }
    }
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.isActive,
    required this.isPending,
    required this.onTap,
  });

  final LibraryModel model;
  final bool isActive;
  final bool isPending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListTile(
      key: Key('chat_model_sheet_row_${model.runtimeId}'),
      contentPadding: EdgeInsets.zero,
      leading: ModelFormatBadge(engine: model.engine, size: 40),
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(FormatUtils.bytes(model.sizeBytes)),
      selected: isActive,
      enabled: onTap != null,
      onTap: onTap,
      trailing: isPending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isActive
          ? Icon(Icons.check_circle_rounded, color: theme.palette.okMark)
          : Text(
              l10n.chatLoadModelAction,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _DownloadingRow extends StatelessWidget {
  const _DownloadingRow({super.key, required this.task});

  final DownloadTaskView task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: ModelFormatBadge(engine: task.engine, size: 40),
      title: Text(task.modelName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          value: task.totalBytes > 0 ? task.progress : null,
          minHeight: 4,
        ),
      ),
      trailing: Text(
        '${(task.progress * 100).round()}%',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
