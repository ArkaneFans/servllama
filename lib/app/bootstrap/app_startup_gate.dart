import 'package:flutter/material.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/core/logging/app_logger.dart';

/// Opens business routes only after their local snapshots are prepared.
/// This is a readiness boundary, not a delay or a hidden copy of every page.
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({
    super.key,
    required this.initialize,
    required this.child,
  });
  final Future<void> Function(BuildContext) initialize;
  final Widget child;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _ready = false, _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  Future<void> _initialize() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final watch = Stopwatch()..start();
    try {
      await widget.initialize(context);
      if (mounted) setState(() => _ready = true);
      AppLogger.instance.event(
        'app.ui_prepare.completed',
        fields: {'elapsed_ms': watch.elapsedMilliseconds},
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
      AppLogger.instance.event(
        'app.ui_prepare.failed',
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : MigrationFlowView(
          phase: _error == null
              ? MigrationFlowPhase.preparing
              : MigrationFlowPhase.failed,
          progress: null,
          error: _error,
          migrationAttempted: false,
          canSkip: false,
          onStart: null,
          onSkip: null,
          onRetry: _busy ? null : _initialize,
          onFinish: null,
        );
}
