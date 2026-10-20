import 'package:flutter/material.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/app/bootstrap/migration_status_view.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

/// Migration failure stays visible and retryable without opening a second
/// business context or falling back to partially migrated state.
class BootstrapGate extends StatefulWidget {
  const BootstrapGate({
    super.key,
    required this.initialize,
    required this.child,
  });
  final Future<void> Function(void Function(LegacyMigrationProgress))
  initialize;
  final Widget child;
  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  late Future<void> _initialization;
  bool _pending = false;
  LegacyMigrationProgress? _progress;
  Future<void> _start() {
    _pending = true;
    _progress = null;
    return Future<void>.sync(
      () => widget.initialize((progress) {
        if (mounted) setState(() => _progress = progress);
      }),
    ).whenComplete(() {
      _pending = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _initialization = _start();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, state) {
      if (state.connectionState == ConnectionState.done && !state.hasError) {
        return widget.child;
      }
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            final l = AppLocalizations.of(context)!;
            return PopScope(
              canPop: false,
              child: Scaffold(
                appBar: AppBar(title: Text(l.appTitle)),
                body: MigrationStatusView(
                  progress: _progress,
                  error: state.hasError ? state.error : null,
                  onRetry: () {
                    if (_pending) return;
                    setState(() {
                      _initialization = _start();
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
