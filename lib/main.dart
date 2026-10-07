import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'dart:async';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:servllama/app/app.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/file_log_sink.dart';
import 'package:servllama/core/services/native_licenses.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerNativeLicenses();
  FlutterForegroundTask.initCommunicationPort();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await _initLogging();
  runApp(
    BootstrapGate(initialize: _initializeBusiness, child: const ServLlamaApp()),
  );
}

Future<void> _initializeBusiness(
  void Function(LegacyMigrationProgress) report,
) async {
  final watch = Stopwatch()..start();
  AppLogger.instance.event('app.initialize.started');
  try {
    await ChatSessionRepository(
      onMigrationProgress: report,
    ).warmUpMessageStore();
    await GenerationRunRepository(await AppDatabase.shared()).recover();
    await AgentToolService.create();
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
    AppLogger.instance.restore(
      await sink.loadRecent(AppLogger.defaultMaxEntries),
    );
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
