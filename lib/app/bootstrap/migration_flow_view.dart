import 'package:flutter/material.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

enum MigrationFlowPhase {
  checking,
  intro,
  preparing,
  migrating,
  complete,
  failed,
}

class MigrationFlowView extends StatelessWidget {
  const MigrationFlowView({
    super.key,
    required this.phase,
    required this.progress,
    required this.error,
    required this.migrationAttempted,
    required this.canSkip,
    required this.onStart,
    required this.onSkip,
    required this.onRetry,
    required this.onFinish,
  });

  final MigrationFlowPhase phase;
  final LegacyMigrationProgress? progress;
  final Object? error;
  final bool migrationAttempted;
  final bool canSkip;
  final VoidCallback? onStart;
  final VoidCallback? onSkip;
  final VoidCallback? onRetry;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AppScaffold(
      body: MigrationFlowBody(
        phase: phase,
        progress: progress,
        error: error,
        migrationAttempted: migrationAttempted,
        canSkip: canSkip,
        onStart: onStart,
        onSkip: onSkip,
        onRetry: onRetry,
        onFinish: onFinish,
      ),
    ),
  );
}

class MigrationFlowBody extends StatelessWidget {
  const MigrationFlowBody({
    super.key,
    required this.phase,
    required this.progress,
    required this.error,
    required this.migrationAttempted,
    required this.canSkip,
    required this.onStart,
    required this.onSkip,
    required this.onRetry,
    required this.onFinish,
  });

  final MigrationFlowPhase phase;
  final LegacyMigrationProgress? progress;
  final Object? error;
  final bool migrationAttempted;
  final bool canSkip;
  final VoidCallback? onStart;
  final VoidCallback? onSkip;
  final VoidCallback? onRetry;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (phase) {
                  MigrationFlowPhase.checking => _StatusView(
                    key: const ValueKey('migration-checking'),
                    title: l.v2CheckingData,
                  ),
                  MigrationFlowPhase.intro => _IntroView(
                    key: const ValueKey('migration-intro'),
                    onStart: onStart,
                    onSkip: onSkip,
                  ),
                  MigrationFlowPhase.preparing => _StatusView(
                    key: const ValueKey('migration-preparing'),
                    title: l.v2StartupPreparing,
                  ),
                  MigrationFlowPhase.migrating => _ProgressView(
                    key: const ValueKey('migration-progress'),
                    progress: progress,
                  ),
                  MigrationFlowPhase.complete => _CompleteView(
                    key: const ValueKey('migration-complete'),
                    onFinish: onFinish,
                  ),
                  MigrationFlowPhase.failed => _FailedView(
                    key: const ValueKey('migration-failed'),
                    error: error,
                    migrationAttempted: migrationAttempted,
                    canSkip: canSkip,
                    onRetry: onRetry,
                    onSkip: onSkip,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({super.key, required this.onStart, required this.onSkip});

  final VoidCallback? onStart;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.migrationSetupTitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l.migrationSetupSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                const _StorageFlowCard(),
                const SizedBox(height: 16),
                SettingsSection.grouped(
                  title: l.migrationSetupDataTitle,
                  children: [
                    SettingsMenuTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l.v2MigrationChats,
                    ),
                    SettingsMenuTile(
                      icon: Icons.developer_board_outlined,
                      title: l.v2MigrationModels,
                    ),
                    SettingsMenuTile(
                      icon: Icons.download_rounded,
                      title: l.v2MigrationDownloads,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.migrationSetupRetainNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('migration_start'),
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(l.migrationStartButton),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const Key('migration_skip'),
          onPressed: onSkip == null
              ? null
              : () => _confirmSkip(context, l, onSkip),
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: Text(l.migrationSkipFreshButton),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({super.key, required this.progress});

  final LegacyMigrationProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = progress?.stage;
    final value = progress != null && progress!.total > 0
        ? (progress!.completed / progress!.total).clamp(0.0, 1.0)
        : null;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoundIcon(
                  icon: Icons.sync_rounded,
                  color: colors.primary,
                  background: colors.primaryContainer,
                ),
                const SizedBox(height: 20),
                Text(l.v2MigrationTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  l.v2MigrationHelp,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Material(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current == null
                              ? l.v2StartupPreparing
                              : _stageLabel(l, current),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                          ),
                        ),
                        if (progress != null && progress!.total > 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            l.v2MigrationRecords(
                              progress!.completed,
                              progress!.total,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SettingsSection.grouped(
                  title: l.migrationProgressTitle,
                  children: [
                    for (final stage in LegacyMigrationStage.values)
                      if (stage != LegacyMigrationStage.complete)
                        _stageTile(context, l, stage, current),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stageTile(
    BuildContext context,
    AppLocalizations l,
    LegacyMigrationStage stage,
    LegacyMigrationStage? current,
  ) {
    final state = current == null
        ? _StageState.pending
        : current == LegacyMigrationStage.complete ||
              stage.index < current.index
        ? _StageState.done
        : stage == current
        ? _StageState.active
        : _StageState.pending;
    return SettingsMenuTile(
      icon: switch (stage) {
        LegacyMigrationStage.chats => Icons.chat_bubble_outline_rounded,
        LegacyMigrationStage.models => Icons.developer_board_outlined,
        LegacyMigrationStage.downloads => Icons.download_rounded,
        LegacyMigrationStage.writing => Icons.save_outlined,
        LegacyMigrationStage.verifying => Icons.fact_check_outlined,
        LegacyMigrationStage.complete => Icons.check_rounded,
      },
      title: _stageLabel(l, stage),
      trailing: switch (state) {
        _StageState.done => Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        _StageState.active => const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        _StageState.pending => const Icon(
          Icons.radio_button_unchecked_rounded,
          size: 18,
        ),
      },
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

enum _StageState { pending, active, done }

class _CompleteView extends StatelessWidget {
  const _CompleteView({super.key, required this.onFinish});

  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 52),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l.migrationCompleteTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  l.migrationCompleteBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('migration_start_using'),
            onPressed: onFinish,
            child: Text(l.migrationStartUsing),
          ),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    super.key,
    required this.error,
    required this.migrationAttempted,
    required this.canSkip,
    required this.onRetry,
    required this.onSkip,
  });

  final Object? error;
  final bool migrationAttempted;
  final bool canSkip;
  final VoidCallback? onRetry;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: colors.error,
                ),
                const SizedBox(height: 18),
                Text(
                  migrationAttempted
                      ? l.migrationFailedTitle
                      : l.migrationStartupFailedTitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  migrationAttempted ? l.v2MigrationFailed : l.v2StartupFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      LogRedactor.redact(
                        (error ?? l.v2StartupFailed).toString(),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('migration_retry'),
            onPressed: onRetry,
            child: Text(
              migrationAttempted ? l.migrationRetryButton : l.v2RetryStartup,
            ),
          ),
        ),
        if (canSkip) ...[
          const SizedBox(height: 6),
          TextButton(
            key: const Key('migration_failed_skip'),
            onPressed: onSkip == null
                ? null
                : () => _confirmSkip(context, l, onSkip),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text(l.migrationSkipFreshButton),
          ),
        ],
      ],
    );
  }
}

Future<void> _confirmSkip(
  BuildContext context,
  AppLocalizations l,
  VoidCallback? onSkip,
) async {
  if (onSkip == null) return;
  final colors = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.migrationSkipFreshTitle),
      content: Text(l.migrationSkipFreshMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.migrationSkipFreshCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: Text(l.migrationSkipFreshConfirm),
        ),
      ],
    ),
  );
  if (confirmed == true) onSkip();
}

class _StatusView extends StatelessWidget {
  const _StatusView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const Spacer(),
        const SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
      ],
    );
  }
}

class _StorageFlowCard extends StatelessWidget {
  const _StorageFlowCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _StorageLabel(
                icon: Icons.inventory_2_outlined,
                label: l.migrationStorageHive,
                background: colors.surfaceContainerLow,
                foreground: colors.onSurfaceVariant,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: _StorageLabel(
                icon: Icons.storage_rounded,
                label: l.migrationStorageSqlite,
                background: colors.primaryContainer,
                foreground: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageLabel extends StatelessWidget {
  const _StorageLabel({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(height: 8),
          Text(label, style: text.labelLarge?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 30),
  );
}
