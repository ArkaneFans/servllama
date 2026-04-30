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
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  child: provider.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(110),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    size: 32,
                    color: colorScheme.primary,
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
  });

  final ModelDescriptor descriptor;
  final String subtitle;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            const _ModelLeadingIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    descriptor.modelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.modelManagementDeleteTooltip,
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelLeadingIcon extends StatelessWidget {
  const _ModelLeadingIcon();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.memory_rounded, size: 22, color: colorScheme.primary),
    );
  }
}
