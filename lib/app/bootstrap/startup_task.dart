import 'package:servllama/core/logging/app_logger.dart';

/// A fixed app-owned preparation step, not a job or dependency scheduler.
class StartupTask {
  const StartupTask(this.name, this.action);

  final String name;
  final Future<void> Function() action;

  Future<void> run({required String phase, AppLogger? logger}) async {
    try {
      await action();
    } catch (error) {
      (logger ?? AppLogger.instance).event(
        'app.startup.task.failed',
        level: LogLevel.warning,
        fields: {'phase': phase, 'task': name, ...AppLogger.errorFields(error)},
      );
      rethrow;
    }
  }
}
