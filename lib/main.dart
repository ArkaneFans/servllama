import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'dart:async';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/app/app.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/file_log_sink.dart';
import 'package:servllama/core/services/native_licenses.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/app/bootstrap/app_startup_state.dart';

Future<void> main() async {
  final startupWatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  registerNativeLicenses();
  FlutterForegroundTask.initCommunicationPort();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await StartupTask('log_sink', _initLogging).run(phase: 'admission');
  bool? pendingMigration;
  Object? admissionError;
  try {
    pendingMigration = await _hasPendingLegacyMigration();
    if (!pendingMigration) {
      await _initializeBusiness((_) {}, skipLegacyImport: false);
    }
  } catch (error) {
    admissionError = error;
  }
  if (pendingMigration != false || admissionError != null) {
    runApp(
      BootstrapGate(
        initialPendingMigration: pendingMigration,
        initialError: admissionError,
        hasPendingMigration: _hasPendingLegacyMigration,
        initialize: _initializeBusiness,
        child: ServLlamaApp(startupWatch: startupWatch),
      ),
    );
    return;
  }

  // Like data admission, the small configuration snapshot precedes runApp.
  // Flutter owns first-frame delivery; no native splash retention callbacks.
  final startup = AppStartupState();
  try {
    await StartupTask('ui_snapshot', startup.prepare).run(phase: 'critical');
  } catch (_) {
    // The app displays this captured failure, without an automatic retry.
  }
  runApp(ServLlamaApp(startupWatch: startupWatch, startup: startup));
}

Future<bool> _hasPendingLegacyMigration() async {
  final directory = await getApplicationSupportDirectory();
  return LegacyImporter.hasPendingImport(await AppDatabase.shared(), directory);
}

Future<void> _initializeBusiness(
  void Function(LegacyMigrationProgress) report, {
  required bool skipLegacyImport,
}) async {
  final watch = Stopwatch()..start();
  AppLogger.instance.event('app.initialize.started');
  try {
    await StartupTask(
      'message_store',
      () => ChatSessionRepository(
        onMigrationProgress: report,
        skipLegacyImport: skipLegacyImport,
        retryCleanupOnOpen: false,
      ).warmUpMessageStore(),
    ).run(phase: 'admission');
    await StartupTask(
      'run_recovery',
      () async => GenerationRunRepository(await AppDatabase.shared()).recover(),
    ).run(phase: 'admission');
    await StartupTask(
      'tool_recovery',
      AgentToolService.create,
    ).run(phase: 'admission');
    AppLogger.instance.event(
      'app.initialize.completed',
      fields: {'elapsed_ms': watch.elapsedMilliseconds},
    );
  } catch (error) {
    AppLogger.instance.event(
      'app.initialize.failed',
      level: LogLevel.error,
      fields: {
        'elapsed_ms': watch.elapsedMilliseconds,
        ...AppLogger.errorFields(error),
      },
    );
    rethrow;
  }
}

Future<void> _initLogging() async {
  try {
    final sink = await FileLogSink.open();
    AppLogger.instance.attachSink(sink);
    // Retained by WidgetsBinding as an observer; flushes on background/exit.
    AppLifecycleListener(
      onPause: () => unawaited(sink.flush()),
      onDetach: () => unawaited(sink.flush()),
    );
  } catch (error) {
    // Degrade to in-memory only logging if the file sink cannot be opened.
    AppLogger.instance.event(
      'logging.storage_unavailable',
      level: LogLevel.warning,
      fields: AppLogger.errorFields(error),
    );
  }
}
