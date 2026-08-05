import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/pages/downloads_page.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/widgets/download_task_card.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

class ModelManagementPage extends StatelessWidget {
  const ModelManagementPage({super.key, this.provider});

  final ModelManagementProvider? provider;

  @override
  Widget build(BuildContext context) {
    final existingProvider = provider;
    if (existingProvider != null) {
      return ChangeNotifierProvider<ModelManagementProvider>.value(
        value: existingProvider,
        child: const _ModelManagementView(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ModelManagementProvider(),
      child: const _ModelManagementView(),
    );
  }
}

class _ModelManagementView extends StatefulWidget {
  const _ModelManagementView();

  @override
  State<_ModelManagementView> createState() => _ModelManagementViewState();
}

class _ModelManagementViewState extends State<_ModelManagementView> {
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ModelManagementProvider>().load();
      context.read<DownloadProvider>().load();
    });
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<_AddModelChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AddModelSheet(),
    );
    if (choice == null || !context.mounted) {
      return;
    }

    switch (choice) {
      case _AddModelChoice.download:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ModelDiscoveryPage()),
        );
        if (context.mounted) {
          await context.read<ModelManagementProvider>().load();
        }
      case _AddModelChoice.ggufFile:
        await _runImport(
          context,
          () => context.read<ModelManagementProvider>().importModel(),
        );
      case _AddModelChoice.mnnDirectory:
        await _runImport(
          context,
          () =>
              context.read<ModelManagementProvider>().importMnnModelDirectory(),
        );
    }
  }

  Future<void> _runImport(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final message = await action();
    if (!context.mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showModelSettings(BuildContext context, ModelDescriptor descriptor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return ChangeNotifierProvider<ModelManagementProvider>.value(
          value: context.read<ModelManagementProvider>(),
          child: _ModelSettingsSheet(descriptor: descriptor),
        );
      },
    );
  }

  Future<void> _deleteLibraryModel(
    BuildContext context,
    LibraryModel model,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.modelManagementDeleteDialogTitle),
          content: Text(l10n.modelLibraryDeleteDialogContent(model.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final message = await context
        .read<ModelManagementProvider>()
        .deleteLibraryModel(model);
    if (!context.mounted || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _activateLibraryModel(
    BuildContext context,
    LibraryModel model,
  ) async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null || runtime.isBusy) {
      return;
    }
    if (runtime.activeEngine != model.engine) {
      if (!runtime.canSwitchEngine) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.modelLibrarySwitchEngineBlocked)),
        );
        return;
      }
      await runtime.switchEngine(model.engine);
    }
    await runtime.activateModel(model.runtimeId);
    if (!context.mounted || runtime.lastError == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.modelLibraryActivationFailed)),
    );
  }

  ModelDescriptor? _descriptorFor(
    ModelManagementProvider provider,
    LibraryModel model,
  ) {
    if (model.engine != InferenceEngine.llamaCpp) {
      return null;
    }
    final rawId = UnifiedModelRepository.rawIdOf(model.id);
    for (final descriptor in provider.models) {
      if (descriptor.id == rawId) {
        return descriptor;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ModelManagementProvider, DownloadProvider>(
      builder: (context, provider, downloads, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isLight = theme.brightness == Brightness.light;
        final l10n = context.l10n;
        final runtime = context.watch<EngineRuntimeProvider?>();

        final models = _filteredModels(provider.libraryModels, _filter);
        // In-flight downloads sit in the library rather than hiding on another
        // page — the model is on its way here, so this is where it belongs.
        final activeDownloads = downloads.activeTasks
            .where((task) => _downloadMatches(task.engine, _filter))
            .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.modelLibraryTitle),
            actions: [
              IconButton(
                key: const Key('model_management_downloads_button'),
                tooltip: l10n.downloadsTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadsPage(),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: downloads.activeTaskCount > 0,
                  label: Text('${downloads.activeTaskCount}'),
                  child: const Icon(Icons.download_rounded),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('model_management_import_fab'),
            onPressed: provider.isImporting
                ? null
                : () => _openAddSheet(context),
            icon: provider.isImporting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              provider.isImporting
                  ? l10n.modelManagementImporting
                  : l10n.modelLibraryAddTitle,
            ),
            backgroundColor: isLight
                ? colorScheme.primaryContainer
                : colorScheme.primary,
            foregroundColor: isLight
                ? colorScheme.onPrimaryContainer
                : colorScheme.onPrimary,
            elevation: 0,
            extendedPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _EngineFilterBar(
                        selected: _filter,
                        counts: <InferenceEngine, int>{
                          for (final engine in InferenceEngine.values)
                            engine: provider.countFor(engine),
                        },
                        visionCount: provider.libraryModels
                            .where((model) => model.supportsVision)
                            .length,
                        toolsCount: provider.libraryModels
                            .where((model) => model.supportsToolCalling)
                            .length,
                        onChanged: (filter) => setState(() => _filter = filter),
                      ),
                      Expanded(
                        child: models.isEmpty && activeDownloads.isEmpty
                            ? const _EmptyState()
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  112,
                                ),
                                children: [
                                  if (activeDownloads.isNotEmpty) ...[
                                    _SectionLabel(
                                      text: l10n.modelLibraryDownloadingSection,
                                    ),
                                    for (final task in activeDownloads)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: DownloadTaskCard(
                                          task: task,
                                          onPause: () =>
                                              downloads.pause(task.id),
                                          onResume: () =>
                                              downloads.resume(task.id),
                                          onCancel: () =>
                                              downloads.cancel(task.id),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    _SectionLabel(
                                      text: l10n.modelLibraryInstalledSection,
                                    ),
                                  ],
                                  for (final model in models)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _LibraryModelCard(
                                        model: model,
                                        isActive:
                                            runtime?.isRunning == true &&
                                            runtime?.activeEngine ==
                                                model.engine &&
                                            runtime?.activeModelId ==
                                                model.runtimeId,
                                        isRuntimeBusy: runtime?.isBusy == true,
                                        isDeleting:
                                            provider.deletingModelId ==
                                            model.id,
                                        onActivate: () => _activateLibraryModel(
                                          context,
                                          model,
                                        ),
                                        onDelete: () =>
                                            _deleteLibraryModel(context, model),
                                        onSettings: () {
                                          final descriptor = _descriptorFor(
                                            provider,
                                            model,
                                          );
                                          if (descriptor != null) {
                                            _showModelSettings(
                                              context,
                                              descriptor,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  List<LibraryModel> _filteredModels(
    List<LibraryModel> models,
    _LibraryFilter filter,
  ) {
    return models
        .where((model) {
          switch (filter) {
            case _LibraryFilter.all:
              return true;
            case _LibraryFilter.llamaCpp:
              return model.engine == InferenceEngine.llamaCpp;
            case _LibraryFilter.mnn:
              return model.engine == InferenceEngine.mnn;
            case _LibraryFilter.vision:
              return model.supportsVision;
            case _LibraryFilter.tools:
              return model.supportsToolCalling;
          }
        })
        .toList(growable: false);
  }

  bool _downloadMatches(InferenceEngine engine, _LibraryFilter filter) {
    switch (filter) {
      case _LibraryFilter.all:
        return true;
      case _LibraryFilter.llamaCpp:
        return engine == InferenceEngine.llamaCpp;
      case _LibraryFilter.mnn:
        return engine == InferenceEngine.mnn;
      case _LibraryFilter.vision:
      case _LibraryFilter.tools:
        return false;
    }
  }
}

enum _LibraryFilter { all, llamaCpp, mnn, vision, tools }

enum _AddModelChoice { download, ggufFile, mnnDirectory }

class _AddModelSheet extends StatelessWidget {
  const _AddModelSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.modelLibraryAddTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _AddOption(
              icon: Icons.cloud_download_outlined,
              title: l10n.modelAddDownload,
              subtitle: l10n.modelAddDownloadDesc,
              onTap: () => Navigator.of(context).pop(_AddModelChoice.download),
            ),
            _AddOption(
              icon: Icons.insert_drive_file_outlined,
              title: l10n.modelAddGguf,
              subtitle: l10n.modelAddGgufDesc,
              onTap: () => Navigator.of(context).pop(_AddModelChoice.ggufFile),
            ),
            _AddOption(
              icon: Icons.folder_open_rounded,
              title: l10n.modelAddMnnDir,
              subtitle: l10n.modelAddMnnDirDesc,
              onTap: () =>
                  Navigator.of(context).pop(_AddModelChoice.mnnDirectory),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _EngineFilterBar extends StatelessWidget {
  const _EngineFilterBar({
    required this.selected,
    required this.counts,
    required this.visionCount,
    required this.toolsCount,
    required this.onChanged,
  });

  final _LibraryFilter selected;
  final Map<InferenceEngine, int> counts;
  final int visionCount;
  final int toolsCount;
  final ValueChanged<_LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = counts.values.fold(0, (sum, value) => sum + value);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          _FilterChip(
            label: '${l10n.modelLibraryFilterAll} · $total',
            isSelected: selected == _LibraryFilter.all,
            onTap: () => onChanged(_LibraryFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label:
                '${InferenceEngine.llamaCpp.displayName} · '
                '${counts[InferenceEngine.llamaCpp] ?? 0}',
            isSelected: selected == _LibraryFilter.llamaCpp,
            onTap: () => onChanged(_LibraryFilter.llamaCpp),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label:
                '${InferenceEngine.mnn.displayName} · '
                '${counts[InferenceEngine.mnn] ?? 0}',
            isSelected: selected == _LibraryFilter.mnn,
            onTap: () => onChanged(_LibraryFilter.mnn),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '${l10n.modelCapabilityVision} · $visionCount',
            isSelected: selected == _LibraryFilter.vision,
            onTap: () => onChanged(_LibraryFilter.vision),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '${l10n.modelCapabilityToolCalling} · $toolsCount',
            isSelected: selected == _LibraryFilter.tools,
            onTap: () => onChanged(_LibraryFilter.tools),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.onSurface
              : (isLight
                    ? const Color(0xFFF1F3F7)
                    : colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected ? colorScheme.surface : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LibraryModelCard extends StatelessWidget {
  const _LibraryModelCard({
    required this.model,
    required this.isActive,
    required this.isRuntimeBusy,
    required this.isDeleting,
    required this.onActivate,
    required this.onDelete,
    required this.onSettings,
  });

  final LibraryModel model;
  final bool isActive;
  final bool isRuntimeBusy;
  final bool isDeleting;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    // Rename and mmproj attachment are GGUF-side concerns; MNN model metadata
    // comes from the model's own config and is not editable here.
    final canEditSettings = model.engine == InferenceEngine.llamaCpp;

    return Material(
      color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outlineVariant.withAlpha(96),
        ),
      ),
      child: InkWell(
        key: Key('model_library_card_${model.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: isActive || isRuntimeBusy ? null : onActivate,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ModelFormatBadge(engine: model.engine),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive
                              ? l10n.modelLibraryStatusRunning
                              : l10n.modelLibraryStatusIdle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${model.engine.displayName} · '
                          '${FormatUtils.bytes(model.sizeBytes)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (model.supportsVision || model.supportsToolCalling) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    if (model.supportsVision)
                      _Tag(label: l10n.modelCapabilityVision),
                    if (model.supportsToolCalling)
                      _Tag(label: l10n.modelCapabilityToolCalling),
                  ],
                ),
              ],
              if (model.warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                NoticeBanner(
                  tone: StatusTone.warning,
                  message: model.warnings.first,
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canEditSettings)
                    IconButton(
                      tooltip: l10n.modelManagementSettingsTooltip,
                      onPressed: onSettings,
                      icon: const Icon(Icons.tune_rounded, size: 20),
                    ),
                  IconButton(
                    tooltip: isActive
                        ? l10n.modelLibraryActiveCannotDelete
                        : l10n.modelManagementDeleteTooltip,
                    onPressed: isDeleting || isActive ? null : onDelete,
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF1F3F7)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(110),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFEAF0FF)
                        : colorScheme.primaryContainer.withAlpha(110),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    size: 32,
                    color: isLight
                        ? colorScheme.primary
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.modelLibraryEmptyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.modelLibraryEmptyDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelTypeBadge extends StatelessWidget {
  const _ModelTypeBadge({required this.tooltip, required this.isMultimodal});

  final String tooltip;
  final bool isMultimodal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isMultimodal
        ? (theme.brightness == Brightness.light
              ? const Color(0xFFFCE7F3)
              : colorScheme.tertiaryContainer)
        : (theme.brightness == Brightness.light
              ? const Color(0xFFE7EDFF)
              : colorScheme.primaryContainer);
    final foregroundColor = isMultimodal
        ? (theme.brightness == Brightness.light
              ? const Color(0xFF9D174D)
              : colorScheme.onTertiaryContainer)
        : (theme.brightness == Brightness.light
              ? const Color(0xFF3730A3)
              : colorScheme.onPrimaryContainer);
    final icon = isMultimodal
        ? Icons.image_search_outlined
        : Icons.text_fields_rounded;

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: foregroundColor),
        ),
      ),
    );
  }
}

class _ModelSettingsSheet extends StatefulWidget {
  const _ModelSettingsSheet({required this.descriptor});

  final ModelDescriptor descriptor;

  @override
  State<_ModelSettingsSheet> createState() => _ModelSettingsSheetState();
}

class _ModelSettingsSheetState extends State<_ModelSettingsSheet> {
  late final TextEditingController _nameController;
  late String _lastSyncedModelName;

  @override
  void initState() {
    super.initState();
    _lastSyncedModelName = widget.descriptor.modelName;
    _nameController = TextEditingController(text: widget.descriptor.modelName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _renameModel(
    BuildContext context,
    ModelDescriptor descriptor,
  ) async {
    final nextName = _nameController.text.trim();
    if (nextName.isEmpty || nextName == descriptor.modelName) {
      return;
    }

    FocusScope.of(context).unfocus();
    final message = await context.read<ModelManagementProvider>().renameModel(
      descriptor.id,
      nextName,
    );
    if (!context.mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importMmproj(
    BuildContext context,
    ModelDescriptor descriptor,
  ) async {
    final message = await context.read<ModelManagementProvider>().importMmproj(
      descriptor.id,
    );
    if (!context.mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeMmproj(
    BuildContext context,
    ModelDescriptor descriptor,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.modelSettingsRemoveMmproj),
          content: Text(
            l10n.modelSettingsRemoveMmprojConfirm(descriptor.modelName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final message = await context.read<ModelManagementProvider>().removeMmproj(
      descriptor.id,
    );
    if (!context.mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncNameDraft(ModelDescriptor descriptor) {
    if (descriptor.modelName == _lastSyncedModelName) {
      return;
    }

    final hasUserEdited =
        _nameController.text.trim() != _lastSyncedModelName.trim();
    _lastSyncedModelName = descriptor.modelName;
    if (hasUserEdited) {
      return;
    }

    _nameController.value = TextEditingValue(
      text: descriptor.modelName,
      selection: TextSelection.collapsed(offset: descriptor.modelName.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManagementProvider>(
      builder: (context, provider, _) {
        final descriptor =
            _findDescriptorById(provider.models, widget.descriptor.id) ??
            widget.descriptor;
        _syncNameDraft(descriptor);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final draftName = _nameController.text.trim();
        final isRenamingThisModel = provider.renamingModelId == descriptor.id;
        final isImportingMmproj =
            provider.importingMmprojModelId == descriptor.id;
        final isLight = theme.brightness == Brightness.light;
        final canSaveName =
            draftName.isNotEmpty &&
            draftName != descriptor.modelName &&
            !isRenamingThisModel;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              28 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        descriptor.modelName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ModelTypeBadge(
                      tooltip: descriptor.mmprojFilePath != null
                          ? l10n.modelMmprojBadgeLabel
                          : l10n.modelTextBadgeLabel,
                      isMultimodal: descriptor.mmprojFilePath != null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.modelSettingsNameLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withAlpha(220),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('model_settings_name_field'),
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (canSaveName) {
                      _renameModel(context, descriptor);
                    }
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isLight
                        ? const Color(0xFFF5F6F8)
                        : colorScheme.surfaceContainerHighest.withAlpha(90),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('model_settings_save_name_button'),
                    onPressed: canSaveName
                        ? () => _renameModel(context, descriptor)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      backgroundColor: canSaveName
                          ? colorScheme.primary
                          : (isLight
                                ? const Color(0xFFF0F0F0)
                                : colorScheme.surfaceContainerHighest),
                      foregroundColor: canSaveName
                          ? colorScheme.onPrimary
                          : (isLight
                                ? const Color(0xFFA0A0A0)
                                : colorScheme.onSurfaceVariant),
                    ),
                    icon: isRenamingThisModel
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(l10n.commonSave),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.modelSettingsMmprojLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withAlpha(220),
                  ),
                ),
                const SizedBox(height: 10),
                if (descriptor.mmprojFilePath case final mmprojPath?)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFF5F6F8)
                          : colorScheme.surfaceContainerHighest.withAlpha(86),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isLight
                                  ? const Color(0xFFFCE7F3)
                                  : colorScheme.tertiaryContainer.withAlpha(
                                      150,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.perm_media_outlined,
                              size: 18,
                              color: isLight
                                  ? const Color(0xFF9D174D)
                                  : colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _fileNameFromPath(mmprojPath),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            key: const Key(
                              'model_settings_remove_mmproj_button',
                            ),
                            onPressed: isImportingMmproj
                                ? null
                                : () => _removeMmproj(context, descriptor),
                            style: IconButton.styleFrom(
                              foregroundColor: isLight
                                  ? const Color(0xFFDC2626)
                                  : colorScheme.error,
                              backgroundColor: isLight
                                  ? const Color(0xFFFEE2E2)
                                  : colorScheme.errorContainer,
                              minimumSize: const Size(38, 38),
                              padding: const EdgeInsets.all(10),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      key: const Key('model_settings_import_mmproj_button'),
                      onPressed: isImportingMmproj
                          ? null
                          : () => _importMmproj(context, descriptor),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isImportingMmproj
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(l10n.modelSettingsImportMmproj),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

ModelDescriptor? _findDescriptorById(
  List<ModelDescriptor> models,
  String descriptorId,
) {
  for (final model in models) {
    if (model.id == descriptorId) {
      return model;
    }
  }
  return null;
}

String _fileNameFromPath(String path) {
  final separator = Platform.pathSeparator;
  final normalized = path
      .replaceAll('/', separator)
      .replaceAll('\\', separator);
  final segments = normalized.split(separator);
  return segments.isEmpty ? path : segments.last;
}
