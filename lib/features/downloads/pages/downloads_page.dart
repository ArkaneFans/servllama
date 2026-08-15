import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/widgets/download_task_card.dart';
import 'package:servllama/l10n/l10n.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DownloadProvider>().load();
      }
    });
  }

  Future<void> _confirmCancel(
    BuildContext context,
    DownloadTaskView task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.downloadCancelDialogTitle),
          content: Text(l10n.downloadCancelDialogContent(task.modelName)),
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
    await context.read<DownloadProvider>().cancel(task.id);
  }

  /// The two hubs serve byte-identical files, so a failed transfer can be
  /// finished from the other one without discarding what is already on disk.
  ModelHubSource _otherSource(ModelHubSource source) =>
      source == ModelHubSource.huggingFace
      ? ModelHubSource.modelScope
      : ModelHubSource.huggingFace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: Consumer<DownloadProvider>(
        builder: (context, downloads, _) {
          final tasks = downloads.tasks;
          if (downloads.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                l10n.downloadsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return SafeArea(
            top: false,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: tasks.length,
              itemBuilder: (_, index) {
                final task = tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DownloadTaskCard(
                    task: task,
                    onPause: () => downloads.pause(task.id),
                    onResume: () => downloads.resume(task.id),
                    onCancel: () => _confirmCancel(context, task),
                    onSwitchSource: () => downloads.switchSource(
                      task.id,
                      _otherSource(task.source),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
