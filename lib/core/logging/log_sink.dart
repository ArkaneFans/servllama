import 'package:servllama/core/logging/app_logger.dart';

abstract class LogSink {
  void add(AppLogEntry entry);

  Future<void> flush();

  Future<List<AppLogEntry>> loadRecent(int max);

  Future<void> clear();
}

class NoopLogSink implements LogSink {
  const NoopLogSink();

  @override
  void add(AppLogEntry entry) {}

  @override
  Future<void> flush() async {}

  @override
  Future<List<AppLogEntry>> loadRecent(int max) async => const <AppLogEntry>[];

  @override
  Future<void> clear() async {}
}
