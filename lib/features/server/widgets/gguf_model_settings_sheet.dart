import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/features/downloads/widgets/download_wifi_only_gate.dart';
import 'package:servllama/features/downloads/widgets/model_repository_link.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

class GgufModelSettingsSheet extends StatefulWidget {
  const GgufModelSettingsSheet({super.key, required this.descriptor});

  final ModelDescriptor descriptor;

  @override
  State<GgufModelSettingsSheet> createState() => _GgufModelSettingsSheetState();
}

class _GgufModelSettingsSheetState extends State<GgufModelSettingsSheet> {
  late final TextEditingController _nameController;
  late String _lastModelName;
  HubRepoDetail? _repo;
  ModelHubErrorKind? _repoError;
  bool _loadingRepo = false;
  String? _enqueueingPath;

  ModelManagementProvider get _models =>
      context.read<ModelManagementProvider>();

  ModelDescriptor _currentModel(ModelManagementProvider provider) {
    for (final model in provider.models) {
      if (model.id == widget.descriptor.id) return model;
    }
    return widget.descriptor;
  }

  @override
  void initState() {
    super.initState();
    _lastModelName = widget.descriptor.modelName;
    _nameController = TextEditingController(text: _lastModelName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentModel(_models).isVisionEnabled) _loadRepo();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String? message) {
    if (mounted && message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _loadRepo() async {
    final model = _currentModel(_models);
    if (_loadingRepo || !model.hasHubSource) return;
    setState(() {
      _loadingRepo = true;
      _repoError = null;
    });
    try {
      final repo = await context.read<ModelDiscoveryProvider>().fetchRepoDetail(
        repoId: model.repoId!,
        source: ModelHubSource.fromStorageValue(model.sourceValue),
        engine: InferenceEngine.llamaCpp,
      );
      if (mounted) setState(() => _repo = repo);
    } on ModelHubException catch (error) {
      if (mounted) setState(() => _repoError = error.kind);
    } catch (_) {
      if (mounted) setState(() => _repoError = ModelHubErrorKind.network);
    } finally {
      if (mounted) setState(() => _loadingRepo = false);
    }
  }

  Future<void> _setVisionEnabled(bool enabled) async {
    _showMessage(await _models.setVisionEnabled(widget.descriptor.id, enabled));
    if (mounted &&
        enabled &&
        _repo == null &&
        _currentModel(_models).isVisionEnabled) {
      await _loadRepo();
    }
  }

  Future<void> _rename() async {
    FocusScope.of(context).unfocus();
    _showMessage(
      await _models.renameModel(
        widget.descriptor.id,
        _nameController.text.trim(),
      ),
    );
  }

  Future<void> _removeProjector(
    ModelDescriptor model,
    String path, {
    bool localImport = false,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.modelSettingsRemoveMmproj),
        content: Text(
          localImport
              ? l10n.modelSettingsRemoveMmprojConfirm(model.modelName)
              : l10n.modelSettingsProjectorDeleteConfirm(
                  path.split(RegExp(r'[\\/]')).last,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _showMessage(
      await (localImport
          ? _models.removeMmproj(model.id)
          : _models.removeMmprojFile(model.id, path)),
    );
  }

  Future<void> _download(HubRepoFile file) async {
    if (_enqueueingPath != null) return;
    if (!await confirmDownloadOnMeteredNetwork(context) || !mounted) return;
    final model = _currentModel(_models);
    setState(() => _enqueueingPath = file.path);
    try {
      await context.read<DownloadProvider>().enqueue(
        engine: InferenceEngine.llamaCpp,
        source: ModelHubSource.fromStorageValue(model.sourceValue),
        repoId: model.repoId!,
        revision: _repo?.revision ?? model.revision ?? 'main',
        modelName: model.modelName,
        files: <HubRepoFile>[file],
        quantLabel: file.fileName,
        targetModelId: model.id,
      );
      if (mounted) _showMessage(context.l10n.downloadStarted(file.fileName));
    } on DownloadException catch (error) {
      if (mounted) {
        _showMessage(
          RuntimeLabels.downloadError(context.l10n, error.kind.name),
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          RuntimeLabels.downloadError(
            context.l10n,
            DownloadErrorKind.network.name,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enqueueingPath = null);
    }
  }

  Future<void> _resume(DownloadTaskView task) async {
    if (await confirmDownloadOnMeteredNetwork(context) && mounted) {
      await context.read<DownloadProvider>().resume(task.id);
    }
  }

  String? _localPath(ModelDescriptor model, HubRepoFile file) {
    final exact = model.availableMmprojs[file.path];
    if (exact != null) return exact;
    // Before projector lists were persisted, only the selected basename was
    // known. Match that record without treating other repository paths alike.
    final legacy = model.mmprojFilePath;
    if (model.mmprojFiles.isEmpty &&
        legacy != null &&
        legacy.split(RegExp(r'[\\/]')).last == file.fileName &&
        _repo?.mmprojFiles
                .where((candidate) => candidate.fileName == file.fileName)
                .length ==
            1) {
      return legacy;
    }
    return null;
  }

  List<HubRepoFile> _projectors(
    ModelDescriptor model,
    List<DownloadTaskView> tasks,
  ) {
    final files = <HubRepoFile>[...?_repo?.mmprojFiles];
    for (final entry in model.availableMmprojs.entries) {
      if (!files.any((file) => _localPath(model, file) == entry.value)) {
        files.add(HubRepoFile(path: entry.key, sizeBytes: 0));
      }
    }
    for (final task in tasks) {
      for (final file in task.files) {
        if (!files.any((candidate) => candidate.path == file.path)) {
          files.add(file);
        }
      }
    }
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ModelManagementProvider, DownloadProvider>(
      builder: (context, models, downloads, _) {
        final model = _currentModel(models);
        if (_lastModelName != model.modelName) {
          if (_nameController.text.trim() == _lastModelName) {
            _nameController.text = model.modelName;
          }
          _lastModelName = model.modelName;
        }
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final l10n = context.l10n;
        final tasks = downloads.tasks
            .where((task) => task.targetModelId == model.id)
            .toList();
        final busy =
            models.isImportingMmproj ||
            models.updatingVisionModelId != null ||
            models.isRenaming;
        final canRename =
            !busy &&
            tasks.isEmpty &&
            _enqueueingPath == null &&
            _nameController.text.trim().isNotEmpty &&
            _nameController.text.trim() != model.modelName;
        final files = _projectors(model, tasks);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const ModelFormatBadge(engine: InferenceEngine.llamaCpp),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        model.modelName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('model_settings_name_field'),
                  controller: _nameController,
                  enabled: !busy && tasks.isEmpty && _enqueueingPath == null,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (canRename) _rename();
                  },
                  decoration: InputDecoration(
                    labelText: l10n.modelSettingsNameLabel,
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    key: const Key('model_settings_save_name_button'),
                    onPressed: canRename ? _rename : null,
                    icon: models.isRenaming
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.commonSave),
                  ),
                ),
                if (tasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.modelSettingsProjectorDownloadPending,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (model.hasHubSource) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('model_settings_open_repository_button'),
                    onPressed: () => openModelRepository(
                      context,
                      source: ModelHubSource.fromStorageValue(
                        model.sourceValue,
                      ),
                      repoId: model.repoId!,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.modelSettingsOpenRepository),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.repoId!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 8),
                if (model.hasHubSource || model.mmprojFilePath != null)
                  SwitchListTile(
                    key: const Key('model_settings_vision_switch'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.visibility_outlined),
                    title: Text(l10n.repoVisionEnable),
                    subtitle: !model.isVisionEnabled
                        ? Text(l10n.modelSettingsVisionDisabledHint)
                        : model.mmprojFilePath == null
                        ? Text(l10n.modelSettingsVisionNeedsProjector)
                        : null,
                    value: model.isVisionEnabled,
                    onChanged: busy ? null : _setVisionEnabled,
                  ),
                if (model.hasHubSource && model.isVisionEnabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.repoVisionMmprojSection,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.modelSettingsProjectorsHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingRepo)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (_repoError != null) ...[
                    NoticeBanner(
                      tone: StatusTone.warning,
                      message: RuntimeLabels.hubError(l10n, _repoError!),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key(
                          'model_settings_retry_projectors_button',
                        ),
                        onPressed: _loadingRepo ? null : _loadRepo,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.downloadRetry),
                      ),
                    ),
                  ],
                  if (!_loadingRepo && _repoError == null && files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n.repoVisionNoMmproj,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  RadioGroup<String>(
                    groupValue: model.mmprojFilePath,
                    onChanged: (path) async {
                      if (path != null && !busy) {
                        _showMessage(await models.selectMmproj(model.id, path));
                      }
                    },
                    child: Column(
                      children: [
                        for (final file in files)
                          _projectorRow(model, file, tasks, downloads, busy),
                      ],
                    ),
                  ),
                ],
                if (!model.hasHubSource) ...[
                  if (model.mmprojFilePath case final path?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        path.split(RegExp(r'[\\/]')).last,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        key: const Key('model_settings_remove_mmproj_button'),
                        tooltip: l10n.modelSettingsRemoveMmproj,
                        onPressed: busy
                            ? null
                            : () => _removeProjector(
                                model,
                                path,
                                localImport: true,
                              ),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.modelSettingsLocalVisionHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('model_settings_import_mmproj_button'),
                      onPressed: busy
                          ? null
                          : () async => _showMessage(
                              await models.importMmproj(model.id),
                            ),
                      icon: models.isImportingMmproj
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(l10n.modelSettingsImportMmproj),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonDone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _projectorRow(
    ModelDescriptor model,
    HubRepoFile file,
    List<DownloadTaskView> tasks,
    DownloadProvider downloads,
    bool busy,
  ) {
    DownloadTaskView? task;
    for (final candidate in tasks) {
      if (candidate.containsFile(file.path)) {
        task = candidate;
        break;
      }
    }
    final currentTask = task;
    final path = _localPath(model, file);
    return _ProjectorRow(
      file: file,
      localPath: path,
      selected: path != null && path == model.mmprojFilePath,
      busy: busy,
      enqueueing: _enqueueingPath == file.path,
      task: currentTask,
      onDownload: _enqueueingPath == null && _repo != null
          ? () => _download(file)
          : null,
      onDelete: path == null ? null : () => _removeProjector(model, path),
      onPause: currentTask == null
          ? null
          : () => downloads.pause(currentTask.id),
      onResume: currentTask == null ? null : () => _resume(currentTask),
      onCancel: currentTask == null
          ? null
          : () => downloads.cancel(currentTask.id),
    );
  }
}

class _ProjectorRow extends StatelessWidget {
  const _ProjectorRow({
    required this.file,
    required this.localPath,
    required this.selected,
    required this.busy,
    required this.enqueueing,
    required this.task,
    this.onDownload,
    this.onDelete,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final HubRepoFile file;
  final String? localPath;
  final bool selected;
  final bool busy;
  final bool enqueueing;
  final DownloadTaskView? task;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = task?.status;
    final subtitle = <String>[
      if (file.sizeBytes > 0) FormatUtils.bytes(file.sizeBytes),
      if (status != null)
        RuntimeLabels.downloadStatus(l10n, status)
      else if (localPath != null)
        selected
            ? l10n.modelSettingsProjectorSelected
            : l10n.modelSettingsProjectorDownloaded,
      if (task?.hasKnownTotal == true && status == DownloadStatus.running)
        '${(task!.progress * 100).round()}%',
      if (status == DownloadStatus.failed && task?.errorDetail != null)
        RuntimeLabels.downloadError(l10n, task!.errorDetail!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.surfaceContainerHighest.withAlpha(120)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.outline.withAlpha(120)
                : colors.outlineVariant.withAlpha(90),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 4, 6),
              child: Row(
                children: [
                  Radio<String>(
                    key: Key('model_projector_select_${file.path}'),
                    value: localPath ?? file.path,
                    enabled: !busy && localPath != null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: status == DownloadStatus.failed
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enqueueing || status == DownloadStatus.downloaded)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (status != null) ...[
                    if (status.canPause)
                      IconButton(
                        tooltip: l10n.downloadPause,
                        onPressed: onPause,
                        icon: const Icon(Icons.pause_rounded),
                      ),
                    if (status.isResumable)
                      IconButton(
                        tooltip: status == DownloadStatus.failed
                            ? l10n.downloadRetry
                            : l10n.downloadResume,
                        onPressed: onResume,
                        icon: Icon(
                          status == DownloadStatus.failed
                              ? Icons.refresh_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    if (status.canCancel)
                      IconButton(
                        tooltip: l10n.downloadCancel,
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ] else if (localPath != null)
                    IconButton(
                      key: Key('model_projector_delete_${file.path}'),
                      tooltip: l10n.commonDelete,
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    )
                  else
                    TextButton(
                      key: Key('model_projector_download_${file.path}'),
                      onPressed: busy ? null : onDownload,
                      child: Text(l10n.repoDownloadAction),
                    ),
                ],
              ),
            ),
            if (status == DownloadStatus.running)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: LinearProgressIndicator(
                  value: task!.hasKnownTotal ? task!.progress : null,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
