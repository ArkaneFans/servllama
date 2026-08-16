import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Repository detail. For GGUF repos this is a quantization picker ordered by
/// what the device can actually run — tiers that would not fit are disabled
/// rather than allowed to fail at load time. MNN repos download whole, so
/// there is a single action instead of a list.
class HubRepoPage extends StatefulWidget {
  const HubRepoPage({
    super.key,
    required this.repoId,
    required this.source,
    required this.engine,
  });

  final String repoId;
  final ModelHubSource source;
  final InferenceEngine engine;

  @override
  State<HubRepoPage> createState() => _HubRepoPageState();
}

class _HubRepoPageState extends State<HubRepoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ModelDiscoveryProvider>().openRepo(
          widget.repoId,
          source: widget.source,
          engine: widget.engine,
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startDownload({
    required HubRepoDetail detail,
    required List<HubRepoFile> files,
    required String modelName,
    String? quantLabel,
  }) async {
    final downloads = context.read<DownloadProvider>();
    try {
      final task = await downloads.enqueue(
        engine: widget.engine,
        source: widget.source,
        repoId: widget.repoId,
        revision: detail.revision,
        modelName: modelName,
        files: files,
        quantLabel: quantLabel,
      );
      if (!mounted) {
        return;
      }
      final l10n = context.l10n;
      final message = task.wasAutoRenamed
          ? l10n.downloadStartedAutoRenamed(
              task.requestedModelName,
              task.modelName,
            )
          : l10n.downloadStarted(task.modelName);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } on DownloadException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            RuntimeLabels.downloadError(context.l10n, error.kind.name),
          ),
        ),
      );
      return;
    } on ModelOperationException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.code) {
        ModelOperationErrorCode.invalidModelName =>
          context.l10n.modelErrorInvalidModelName,
        ModelOperationErrorCode.emptyModelName =>
          context.l10n.modelErrorEmptyModelName,
        _ => context.l10n.modelErrorModelNameExists,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.repoId.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Consumer<ModelDiscoveryProvider>(
        builder: (context, discovery, _) {
          if (discovery.isLoadingRepo) {
            return const Center(child: CircularProgressIndicator());
          }
          if (discovery.lastError != null) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: NoticeBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline_rounded,
                message: RuntimeLabels.hubError(l10n, discovery.lastError!),
              ),
            );
          }
          final detail = discovery.repoDetail;
          if (detail == null) {
            return const SizedBox.shrink();
          }
          return widget.engine == InferenceEngine.mnn
              ? _MnnBody(
                  detail: detail,
                  repoId: widget.repoId,
                  source: widget.source,
                  onDownload: () => _startDownload(
                    detail: detail,
                    files: detail.files,
                    modelName: widget.repoId.split('/').last,
                  ),
                )
              : _GgufBody(
                  detail: detail,
                  discovery: discovery,
                  source: widget.source,
                  onDownload: (file) => _startDownload(
                    detail: detail,
                    files: <HubRepoFile>[
                      file,
                      if (detail.mmprojFile != null) detail.mmprojFile!,
                    ],
                    modelName: _deriveModelName(file),
                    quantLabel: file.quantLabel,
                  ),
                );
        },
      ),
    );
  }

  /// The single-model server uses the downloaded model name as its API alias.
  String _deriveModelName(HubRepoFile file) {
    final fileName = file.fileName;
    return fileName.toLowerCase().endsWith('.gguf')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
  }
}

class _GgufBody extends StatelessWidget {
  const _GgufBody({
    required this.detail,
    required this.discovery,
    required this.source,
    required this.onDownload,
  });

  final HubRepoDetail detail;
  final ModelDiscoveryProvider discovery;
  final ModelHubSource source;
  final ValueChanged<HubRepoFile> onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final files = List<HubRepoFile>.from(detail.ggufFiles)
      // Smallest first: the tiers a phone can actually run come to the top.
      ..sort((left, right) => left.sizeBytes.compareTo(right.sizeBytes));

    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: NoticeBanner(
          tone: StatusTone.warning,
          message: l10n.repoNoGgufFiles,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _RepoHeader(detail: detail, source: source),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            l10n.repoQuantSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuantRow(
              file: file,
              feasibility: discovery.feasibilityOf(file.path),
              onDownload: () => onDownload(file),
            ),
          ),
      ],
    );
  }
}

class _MnnBody extends StatelessWidget {
  const _MnnBody({
    required this.detail,
    required this.repoId,
    required this.source,
    required this.onDownload,
  });

  final HubRepoDetail detail;
  final String repoId;
  final ModelHubSource source;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!detail.hasMnnModelFiles) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: NoticeBanner(
          tone: StatusTone.warning,
          message: l10n.repoNoMnnFiles,
        ),
      );
    }
    final totalBytes = detail.files.fold(
      0,
      (sum, file) => sum + file.sizeBytes,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _RepoHeader(detail: detail, source: source),
        const SizedBox(height: 16),
        NoticeBanner(
          tone: StatusTone.idle,
          icon: Icons.folder_open_rounded,
          message: l10n.repoMnnWholeDirectory(detail.files.length),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download_rounded),
          label: Text(
            '${l10n.repoDownloadAction} · ${FormatUtils.bytes(totalBytes)}',
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }
}

class _RepoHeader extends StatelessWidget {
  const _RepoHeader({required this.detail, required this.source});

  final HubRepoDetail detail;
  final ModelHubSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.summary.repoId,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          source.displayName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _QuantRow extends StatelessWidget {
  const _QuantRow({
    required this.file,
    required this.feasibility,
    required this.onDownload,
  });

  final HubRepoFile file;
  final ModelFeasibility feasibility;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.palette;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    // Over budget means the load would OOM; offering the button anyway would
    // just move the failure later.
    final isBlocked = feasibility == ModelFeasibility.notEnoughMemory;

    final (Color markColor, StatusTone tone) = switch (feasibility) {
      ModelFeasibility.comfortable => (palette.okMark, StatusTone.ok),
      ModelFeasibility.tight => (palette.warningMark, StatusTone.warning),
      ModelFeasibility.notEnoughMemory => (
        palette.dangerMark,
        StatusTone.danger,
      ),
      ModelFeasibility.unknown => (palette.idleMark, StatusTone.idle),
    };

    return Opacity(
      opacity: isBlocked ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: markColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.quantLabel ?? file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${FormatUtils.bytes(file.sizeBytes)} · '
                      '${RuntimeLabels.feasibility(l10n, feasibility)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tone == StatusTone.danger
                            ? palette.dangerText
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: isBlocked ? null : onDownload,
                child: Text(l10n.repoDownloadAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
