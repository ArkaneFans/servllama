import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:servllama/app/bootstrap/migration_status_view.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

/// UI-only simulation. Never opens a database or invokes startup services.
class MigrationPreviewPage extends StatefulWidget {
  const MigrationPreviewPage({super.key});

  @override
  State<MigrationPreviewPage> createState() => _MigrationPreviewPageState();
}

class _MigrationPreviewPageState extends State<MigrationPreviewPage> {
  Timer? _timer;
  int _tick = 0;
  bool _failed = false;
  bool _complete = false;
  LegacyMigrationProgress _progress = const LegacyMigrationProgress(
    LegacyMigrationStage.chats,
    total: 20,
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start({bool fail = false}) {
    _timer?.cancel();
    _tick = 0;
    _failed = false;
    _complete = false;
    _progress = const LegacyMigrationProgress(
      LegacyMigrationStage.chats,
      total: 20,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _tick++;
        if (fail && _tick == 14) {
          _failed = true;
          timer.cancel();
          return;
        }
        if (_tick == 25) {
          _complete = true;
          timer.cancel();
          return;
        }
        _progress = LegacyMigrationProgress(
          LegacyMigrationStage.values[_tick ~/ 5],
          completed: (_tick % 5) * 5,
          total: 20,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppScaffold(
      appBar: AppBar(title: Text(l.migrationPreviewTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(l.migrationPreviewHelp, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('migration_preview_restart'),
                        onPressed: () => setState(() => _start()),
                        child: Text(l.migrationPreviewRestart),
                      ),
                      OutlinedButton(
                        key: const Key('migration_preview_failure'),
                        onPressed: () => setState(() => _start(fail: true)),
                        child: Text(l.migrationPreviewFailure),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _complete
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 48),
                            const SizedBox(height: 20),
                            Text(l.migrationPreviewComplete),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l.migrationPreviewReturn),
                            ),
                          ],
                        ),
                      ),
                    )
                  : MigrationStatusView(
                      progress: _progress,
                      error: _failed ? l.migrationPreviewError : null,
                      onRetry: () => setState(() => _start()),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
