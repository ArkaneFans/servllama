import 'dart:async';

import 'package:flutter/material.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';

/// UI-only simulation. Never opens a database or invokes startup services.
class MigrationPreviewPage extends StatefulWidget {
  const MigrationPreviewPage({super.key});

  @override
  State<MigrationPreviewPage> createState() => _MigrationPreviewPageState();
}

class _MigrationPreviewPageState extends State<MigrationPreviewPage> {
  static const _simulationStages = [
    LegacyMigrationStage.chats,
    LegacyMigrationStage.models,
    LegacyMigrationStage.downloads,
    LegacyMigrationStage.writing,
    LegacyMigrationStage.verifying,
  ];

  Timer? _timer;
  int _tick = 0;
  MigrationFlowPhase _phase = MigrationFlowPhase.intro;
  LegacyMigrationProgress? _progress;
  Object? _error;
  bool _migrationAttempted = false;

  void _start({bool fail = false}) {
    _timer?.cancel();
    _tick = 0;
    setState(() {
      _phase = MigrationFlowPhase.migrating;
      _progress = const LegacyMigrationProgress(
        LegacyMigrationStage.chats,
        total: 20,
      );
      _error = null;
      _migrationAttempted = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _tick++;
      if (fail && _tick >= 8) {
        timer.cancel();
        setState(() {
          _phase = MigrationFlowPhase.failed;
          _progress = null;
          _error = AppLocalizations.of(context)!.migrationPreviewError;
        });
        return;
      }
      if (_tick >= 20) {
        timer.cancel();
        setState(() {
          _phase = MigrationFlowPhase.complete;
          _progress = const LegacyMigrationProgress(
            LegacyMigrationStage.complete,
          );
        });
        return;
      }
      final stageIndex = (_tick ~/ 4)
          .clamp(0, _simulationStages.length - 1)
          .toInt();
      setState(() {
        _progress = LegacyMigrationProgress(
          _simulationStages[stageIndex],
          completed: ((_tick % 4) + 1) * 5,
          total: 20,
        );
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    _tick = 0;
    setState(() {
      _phase = MigrationFlowPhase.intro;
      _progress = null;
      _error = null;
      _migrationAttempted = false;
    });
  }

  void _closePreview() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.migrationPreviewTitle),
        actions: [
          IconButton(
            key: const Key('migration_preview_restart'),
            tooltip: l.migrationPreviewRestart,
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            key: const Key('migration_preview_failure'),
            tooltip: l.migrationPreviewFailure,
            onPressed: () => _start(fail: true),
            icon: const Icon(Icons.error_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.migrationPreviewHelp,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: MigrationFlowBody(
              phase: _phase,
              progress: _progress,
              error: _error,
              migrationAttempted: _migrationAttempted,
              canSkip: _phase == MigrationFlowPhase.failed,
              onStart: () => _start(),
              onSkip: _closePreview,
              onRetry: () => _start(),
              onFinish: _closePreview,
            ),
          ),
        ],
      ),
    );
  }
}
