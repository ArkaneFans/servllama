import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/core/logging/app_logger.dart';

void main() {
  test('successful startup tasks do not emit logs', () async {
    final logger = AppLogger();
    await StartupTask(
      'snapshot',
      () async {},
    ).run(phase: 'critical', logger: logger);
    expect(logger.entriesFor(LogChannel.app), isEmpty);
  });

  test(
    'startup failures retain only phase, step and safe error metadata',
    () async {
      final logger = AppLogger();
      final error = StateError('private prompt /storage/private/api-key');
      final task = StartupTask('optional', () async {
        throw error;
      });
      await expectLater(
        task.run(phase: 'warmup', logger: logger),
        throwsA(same(error)),
      );
      final entry = logger.entriesFor(LogChannel.app).single;
      expect(entry.level, LogLevel.warning);
      final failure = entry.message;
      expect(failure, startsWith('app.startup.task.failed'));
      expect(failure, contains('phase="warmup"'));
      expect(failure, contains('task="optional"'));
      expect(failure, contains('error_type="StateError"'));
      expect(failure, isNot(contains('elapsed_ms')));
      expect(failure, isNot(contains('private')));
      expect(failure, isNot(contains('api-key')));
    },
  );
}
