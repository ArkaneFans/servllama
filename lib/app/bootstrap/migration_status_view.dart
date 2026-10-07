import 'package:flutter/material.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

/// Shared presentation for real startup and the data-free migration preview.
class MigrationStatusView extends StatelessWidget {
  const MigrationStatusView({
    super.key,
    this.progress,
    this.error,
    required this.onRetry,
  });
  final LegacyMigrationProgress? progress;
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final failed = error != null;
    final migrating =
        progress != null && progress!.stage != LegacyMigrationStage.complete;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.error_outline : Icons.storage_rounded,
                  size: 48,
                ),
                const SizedBox(height: 20),
                Text(
                  migrating ? l.v2MigrationTitle : l.v2StartupPreparing,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (progress != null) ...[
                  Text(
                    _stageLabel(l, progress!.stage),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                if (migrating) ...[
                  Text(l.v2MigrationHelp, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                ],
                if (failed) ...[
                  Text(migrating ? l.v2MigrationFailed : l.v2StartupFailed),
                  const SizedBox(height: 12),
                  SelectableText(LogRedactor.redact(error.toString())),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(l.v2RetryStartup),
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    value: progress != null && progress!.total > 0
                        ? progress!.completed / progress!.total
                        : null,
                  ),
                  if (progress != null && progress!.total > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      l.v2MigrationRecords(
                        progress!.completed,
                        progress!.total,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stageLabel(AppLocalizations l, LegacyMigrationStage stage) =>
      switch (stage) {
        LegacyMigrationStage.chats => l.v2MigrationChats,
        LegacyMigrationStage.models => l.v2MigrationModels,
        LegacyMigrationStage.downloads => l.v2MigrationDownloads,
        LegacyMigrationStage.writing => l.v2MigrationWriting,
        LegacyMigrationStage.verifying => l.v2MigrationVerifying,
        LegacyMigrationStage.complete => l.v2MigrationComplete,
      };
}
