import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/l10n/l10n.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ModelManagementProvider>().load();
    });
  }

  Future<void> _importModel(BuildContext context) async {
    final message = await context.read<ModelManagementProvider>().importModel();
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

  Future<void> _deleteModel(
    BuildContext context,
    ModelDescriptor descriptor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.modelManagementDeleteDialogTitle),
          content: Text(
            l10n.modelManagementDeleteDialogContent(descriptor.modelName),
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

    final message = await context.read<ModelManagementProvider>().deleteModel(
      descriptor.id,
    );
    if (!context.mounted || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatSizeGb(int sizeBytes) {
    final sizeGb = sizeBytes / (1024 * 1024 * 1024);
    return '${sizeGb.toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManagementProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isLight = theme.brightness == Brightness.light;
        final l10n = context.l10n;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.modelManagementTitle)),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('model_management_import_fab'),
            onPressed: provider.isImporting
                ? null
                : () => _importModel(context),
            icon: provider.isImporting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(
              provider.isImporting
                  ? l10n.modelManagementImporting
                  : l10n.modelManagementImport,
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
                  child: provider.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
                          itemCount: provider.models.length,
                          itemBuilder: (context, index) {
                            final model = provider.models[index];
                            final isDeleting =
                                provider.deletingModelId == model.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ModelCard(
                                descriptor: model,
                                subtitle:
                                    '${_formatSizeGb(model.sizeBytes)} · GGUF',
                                isDeleting: isDeleting,
                                onDelete: isDeleting
                                    ? null
                                    : () => _deleteModel(context, model),
                                onSettings: () =>
                                    _showModelSettings(context, model),
                              ),
                            );
                          },
                        ),
                ),
        );
      },
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
            boxShadow: isLight
                ? const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
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
                  l10n.modelManagementEmptyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.modelManagementEmptyDescription,
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

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.descriptor,
    required this.subtitle,
    required this.isDeleting,
    required this.onDelete,
    required this.onSettings,
  });

  final ModelDescriptor descriptor;
  final String subtitle;
  final bool isDeleting;
  final VoidCallback? onDelete;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    final typeLabel = descriptor.mmprojFilePath != null
        ? l10n.modelMmprojBadgeLabel
        : l10n.modelTextBadgeLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    descriptor.modelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _ModelTypeBadge(
                              tooltip: typeLabel,
                              isMultimodal: descriptor.mmprojFilePath != null,
                            ),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ModelActionButton(
                        key: Key('model_card_settings_${descriptor.id}'),
                        tooltip: l10n.modelManagementSettingsTooltip,
                        onPressed: isDeleting ? null : onSettings,
                        icon: Icons.settings_outlined,
                      ),
                      const SizedBox(width: 2),
                      _ModelActionButton(
                        tooltip: l10n.modelManagementDeleteTooltip,
                        onPressed: onDelete,
                        icon: Icons.delete_outline_rounded,
                        foregroundColor: colorScheme.error,
                        child: isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTypeBadge extends StatelessWidget {
  const _ModelTypeBadge({
    required this.tooltip,
    required this.isMultimodal,
  });

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
          child: Icon(
            icon,
            size: 16,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}

class _ModelActionButton extends StatelessWidget {
  const _ModelActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.foregroundColor,
    this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? foregroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: foregroundColor ?? colorScheme.onSurfaceVariant,
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.all(8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: child ?? Icon(icon, size: 20),
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

  Future<void> _renameModel(BuildContext context, ModelDescriptor descriptor) async {
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
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
                                  : colorScheme.tertiaryContainer.withAlpha(150),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
  final normalized = path.replaceAll('/', separator).replaceAll('\\', separator);
  final segments = normalized.split(separator);
  return segments.isEmpty ? path : segments.last;
}
