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
import 'package:servllama/features/downloads/widgets/download_wifi_only_gate.dart';
import 'package:servllama/features/downloads/widgets/mmproj_picker_sheet.dart';
import 'package:servllama/features/downloads/widgets/model_repository_link.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Quant file plus the currently selected projector when vision is on.
List<HubRepoFile> ggufDownloadFiles({
  required HubRepoFile quantFile,
  required bool visionEnabled,
  HubRepoFile? mmprojFile,
}) {
  return <HubRepoFile>[
    quantFile,
    if (visionEnabled && mmprojFile != null) mmprojFile,
  ];
}

/// GGUF repositories list quantizations by size with advisory memory labels.
/// MNN repositories download as a whole through a single action.

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
  bool _visionEnabled = true;
  HubRepoFile? _selectedMmproj;

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

  Future<void> _startDownload({
    required HubRepoDetail detail,
    required List<HubRepoFile> files,
    required String modelName,
    required String queuedLabel,
    String? quantLabel,
  }) async {
    final downloads = context.read<DownloadProvider>();
    final alreadyQueued = widget.engine == InferenceEngine.mnn
        ? _isRepoQueued(downloads)
        : _isQuantQueued(downloads, files.first.path);
    if (alreadyQueued) {
      _showMessage(context.l10n.downloadErrorAlreadyQueued);
      return;
    }
    if (!await confirmDownloadOnMeteredNetwork(context) || !mounted) {
      return;
    }
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
      _showMessage(
        task.wasAutoRenamed
            ? l10n.downloadStartedAutoRenamed(
                task.requestedModelName,
                task.modelName,
              )
            : l10n.downloadQueued(queuedLabel),
      );
    } on DownloadException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(RuntimeLabels.downloadError(context.l10n, error.kind.name));
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
      _showMessage(message);
      return;
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isQuantQueued(DownloadProvider downloads, String filePath) {
    return downloads.libraryTasks.any(
      (task) =>
          task.engine == widget.engine &&
          task.repoId == widget.repoId &&
          task.targetModelId == null &&
          task.containsFile(filePath),
    );
  }

  bool _isRepoQueued(DownloadProvider downloads) {
    return downloads.libraryTasks.any(
      (task) =>
          task.engine == widget.engine &&
          task.repoId == widget.repoId &&
          task.targetModelId == null,
    );
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
        actions: [
          IconButton(
            tooltip: l10n.modelSettingsOpenRepository,
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openModelRepository(
              context,
              source: widget.source,
              repoId: widget.repoId,
            ),
          ),
        ],
      ),
      body: Consumer2<ModelDiscoveryProvider, DownloadProvider>(
        builder: (context, discovery, downloads, _) {
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
                  isQueued: _isRepoQueued(downloads),
                  onDownload: () => _startDownload(
                    detail: detail,
                    files: detail.files,
                    modelName: widget.repoId.split('/').last,
                    queuedLabel: widget.repoId.split('/').last,
                  ),
                )
              : _GgufBody(
                  detail: detail,
                  discovery: discovery,
                  source: widget.source,
                  visionEnabled: _visionEnabled,
                  selectedMmproj: _resolvedMmproj(detail),
                  queuedFilePaths: <String>{
                    for (final task in downloads.libraryTasks)
                      if (task.engine == widget.engine &&
                          task.repoId == widget.repoId &&
                          task.targetModelId == null)
                        for (final file in task.files) file.path,
                  },
                  onVisionTap: detail.hasMmproj
                      ? () => _openVisionSheet(detail)
                      : null,
                  onDownload: (file) => _startDownload(
                    detail: detail,
                    files: ggufDownloadFiles(
                      quantFile: file,
                      visionEnabled: _visionEnabled,
                      mmprojFile: _resolvedMmproj(detail),
                    ),
                    modelName: _deriveModelName(file),
                    queuedLabel: file.fileName,
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

  HubRepoFile? _resolvedMmproj(HubRepoDetail detail) {
    final files = detail.mmprojFiles;
    if (files.isEmpty) {
      return null;
    }
    final selectedPath = _selectedMmproj?.path;
    if (selectedPath != null) {
      for (final file in files) {
        if (file.path == selectedPath) {
          return file;
        }
      }
    }
    return files.first;
  }

  Future<void> _openVisionSheet(HubRepoDetail detail) async {
    final files = detail.mmprojFiles;
    if (files.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return MmprojPickerSheet(
          files: files,
          allowDisable: true,
          initialEnabled: _visionEnabled,
          initialFile: _resolvedMmproj(detail),
          onChanged: (result) {
            setState(() {
              _visionEnabled = result.enabled;
              _selectedMmproj = result.file;
            });
          },
        );
      },
    );
  }
}

class _GgufBody extends StatelessWidget {
  const _GgufBody({
    required this.detail,
    required this.discovery,
    required this.source,
    required this.visionEnabled,
    required this.selectedMmproj,
    required this.queuedFilePaths,
    required this.onDownload,
    this.onVisionTap,
  });

  final HubRepoDetail detail;
  final ModelDiscoveryProvider discovery;
  final ModelHubSource source;
  final bool visionEnabled;
  final HubRepoFile? selectedMmproj;
  final Set<String> queuedFilePaths;
  final ValueChanged<HubRepoFile> onDownload;
  final VoidCallback? onVisionTap;

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
              visionEnabled: visionEnabled,
              selectedMmproj: selectedMmproj,
              isQueued: queuedFilePaths.contains(file.path),
              onVisionTap: onVisionTap,
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
    required this.isQueued,
    required this.onDownload,
  });

  final HubRepoDetail detail;
  final String repoId;
  final ModelHubSource source;
  final bool isQueued;
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
          icon: Icon(
            isQueued ? Icons.downloading_rounded : Icons.download_rounded,
          ),
          label: Text(
            isQueued
                ? l10n.repoDownloadQueued
                : '${l10n.repoDownloadAction} · ${FormatUtils.bytes(totalBytes)}',
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
    this.visionEnabled = false,
    this.selectedMmproj,
    this.isQueued = false,
    this.onVisionTap,
  });

  final HubRepoFile file;
  final ModelFeasibility feasibility;
  final VoidCallback onDownload;
  final bool visionEnabled;
  final HubRepoFile? selectedMmproj;
  final bool isQueued;
  final VoidCallback? onVisionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.palette;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    final (Color markColor, StatusTone tone) = switch (feasibility) {
      ModelFeasibility.comfortable => (palette.okMark, StatusTone.ok),
      ModelFeasibility.tight => (palette.warningMark, StatusTone.warning),
      ModelFeasibility.notEnoughMemory => (
        palette.dangerMark,
        StatusTone.danger,
      ),
      ModelFeasibility.unknown => (palette.idleMark, StatusTone.idle),
    };

    return DecoratedBox(
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
                    file.fileName,
                    maxLines: 2,
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
                  if (isQueued) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.repoDownloadQueued,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (onVisionTap != null) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      key: Key('quant_vision_button_${file.path}'),
                      onPressed: onVisionTap,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.compact,
                        alignment: Alignment.centerLeft,
                        foregroundColor: colorScheme.onSurfaceVariant,
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withAlpha(120),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            visionEnabled
                                ? l10n.repoVisionOn
                                : l10n.repoVisionOff,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                    if (visionEnabled && selectedMmproj != null)
                      Text(
                        '${selectedMmproj!.fileName} · ${FormatUtils.bytes(selectedMmproj!.sizeBytes)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: Key('quant_download_button_${file.path}'),
              tooltip: isQueued
                  ? l10n.repoDownloadQueued
                  : l10n.repoDownloadAction,
              onPressed: onDownload,
              icon: Icon(
                isQueued ? Icons.downloading_rounded : Icons.download_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
