import 'dart:developer';

import 'package:servllama/core/logging/app_logger.dart';

/// A fixed app-owned preparation step, not a job or dependency scheduler.
class StartupTask {
  const StartupTask(this.name, this.action);

  final String name;
  final Future<void> Function() action;

  Future<void> run({required String phase, AppLogger? logger}) async {
    final log = logger ?? AppLogger.instance;
    final watch = Stopwatch()..start();
    final trace = TimelineTask()..start('startup.$phase.$name');
    try {
      await action();
      log.event(
        'app.startup.task.completed',
        fields: {
          'phase': phase,
          'task': name,
          'elapsed_ms': watch.elapsedMilliseconds,
        },
      );
    } catch (error) {
      log.event(
        'app.startup.task.failed',
        level: LogLevel.warning,
        fields: {
          'phase': phase,
          'task': name,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    } finally {
      trace.finish();
    }
  }
}
