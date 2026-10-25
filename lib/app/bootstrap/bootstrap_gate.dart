import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

typedef BootstrapInitializer =
    Future<void> Function(
      void Function(LegacyMigrationProgress) report, {
      required bool skipLegacyImport,
    });

/// Keeps the business UI closed until startup and any requested legacy import
/// have finished. A failed import remains retryable or can be skipped without
/// opening a second business context.
class BootstrapGate extends StatefulWidget {
  const BootstrapGate({
    super.key,
    required this.hasPendingMigration,
    required this.initialize,
    required this.child,
    this.initialPendingMigration,
    this.initialError,
  });

  final Future<bool> Function() hasPendingMigration;
  final BootstrapInitializer initialize;
  final Widget child;

  /// The entry point can check admission before constructing a widget tree.
  final bool? initialPendingMigration;
  final Object? initialError;

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  MigrationFlowPhase _phase = MigrationFlowPhase.checking;
  LegacyMigrationProgress? _progress;
  Object? _error;
  bool _pendingMigration = false;
  bool _migrationAttempted = false;
  bool _skipLegacyImport = false;
  bool _failedChecking = false;
  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialError != null) {
      _error = widget.initialError;
      _failedChecking = widget.initialPendingMigration == null;
      _phase = MigrationFlowPhase.failed;
    } else {
      _checkMigration(knownPending: widget.initialPendingMigration);
    }
  }

  Future<void> _checkMigration({bool? knownPending}) async {
    setState(() {
      _phase = MigrationFlowPhase.checking;
      _error = null;
      _failedChecking = false;
    });
    try {
      final pending = knownPending ?? await widget.hasPendingMigration();
      if (!mounted) return;
      _pendingMigration = pending;
      if (pending) {
        setState(() => _phase = MigrationFlowPhase.intro);
        return;
      }
      setState(() => _phase = MigrationFlowPhase.preparing);
      await _initialize(skipLegacyImport: false, migrationAttempt: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _failedChecking = true;
        _phase = MigrationFlowPhase.failed;
      });
    }
  }

  Future<void> _initialize({
    required bool skipLegacyImport,
    required bool migrationAttempt,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
      _failedChecking = false;
      _skipLegacyImport = skipLegacyImport;
      _migrationAttempted = migrationAttempt;
      _phase = migrationAttempt
          ? MigrationFlowPhase.migrating
          : MigrationFlowPhase.preparing;
    });
    try {
      await widget.initialize((progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }, skipLegacyImport: skipLegacyImport);
      if (!mounted) return;
      setState(() {
        if (migrationAttempt) {
          _phase = MigrationFlowPhase.complete;
        } else {
          _ready = true;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _phase = MigrationFlowPhase.failed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    if (_failedChecking) {
      await _checkMigration();
      return;
    }
    await _initialize(
      skipLegacyImport: _skipLegacyImport,
      migrationAttempt: _migrationAttempted,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    // The normal entry point admits data before runApp. This widget owns the
    // visible migration/retry flow, not the native launch screen lifetime.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MigrationFlowView(
        phase: _phase,
        progress: _progress,
        error: _error,
        migrationAttempted: _migrationAttempted,
        canSkip: _pendingMigration && !_skipLegacyImport && !_busy,
        onStart: _busy
            ? null
            : () =>
                  _initialize(skipLegacyImport: false, migrationAttempt: true),
        onSkip: _busy
            ? null
            : () =>
                  _initialize(skipLegacyImport: true, migrationAttempt: false),
        onRetry: _busy ? null : _retry,
        onFinish: () => setState(() => _ready = true),
      ),
    );
  }
}
