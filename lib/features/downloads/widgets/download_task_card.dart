import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// One download task. MNN models are whole directories, so a single card can
/// represent many files — the file counter makes that visible instead of
/// showing one bar per file.
class DownloadTaskCard extends StatelessWidget {
  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.onSwitchSource,
  });

  final DownloadTaskView task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onSwitchSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.palette;
    final l10n = context.l10n;
    final isLight = theme.brightness == Brightness.light;
    final status = task.status;
    final remaining = task.remaining;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ModelFormatBadge(engine: task.engine, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.modelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${task.source.displayName} · ${task.repoId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(task.progress * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 7,
                backgroundColor: isLight
                    ? const Color(0xFFF1F3F7)
                    : colorScheme.surfaceContainerHighest,
                color: status == DownloadStatus.failed
                    ? palette.dangerMark
                    : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status == DownloadStatus.running
                        ? l10n.downloadProgressDetail(
                            FormatUtils.bytes(task.receivedBytes),
                            FormatUtils.bytes(task.totalBytes),
                            FormatUtils.bytesPerSecond(task.bytesPerSecond),
                          )
                        : RuntimeLabels.downloadStatus(l10n, status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (task.fileCount > 1)
                  Text(
                    l10n.downloadFilesProgress(
                      task.completedFileCount,
                      task.fileCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (remaining != null)
                  Text(
                    l10n.downloadRemaining(
                      FormatUtils.shortDuration(remaining),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (task.errorDetail != null) ...[
              const SizedBox(height: 10),
              NoticeBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline_rounded,
                message: RuntimeLabels.downloadError(l10n, task.errorDetail!),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status.isResumable && onSwitchSource != null)
                  TextButton(
                    onPressed: onSwitchSource,
                    child: Text(l10n.downloadSwitchSource),
                  ),
                if (status.isActive)
                  TextButton(
                    onPressed: onPause,
                    child: Text(l10n.downloadPause),
                  )
                else if (status.isResumable)
                  TextButton(
                    onPressed: onResume,
                    child: Text(
                      status == DownloadStatus.failed
                          ? l10n.downloadRetry
                          : l10n.downloadResume,
                    ),
                  ),
                TextButton(
                  onPressed: onCancel,
                  child: Text(l10n.downloadCancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
