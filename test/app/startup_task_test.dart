import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/core/logging/app_logger.dart';

void main() {
  test('startup timing includes phase and step, not error payloads', () async {
    final logger = AppLogger();
    await StartupTask(
      'snapshot',
      () async {},
    ).run(phase: 'critical', logger: logger);
    final success = logger.entriesFor(LogChannel.app).single.message;
    expect(success, contains('elapsed_ms='));
    expect(success, contains('phase="critical"'));
    final task = StartupTask('optional', () async {
      throw StateError('private prompt /storage/private/api-key');
    });
    await expectLater(
      task.run(phase: 'warmup', logger: logger),
      throwsStateError,
    );
    final failure = logger.entriesFor(LogChannel.app).last.message;
    expect(failure, contains('error_type="StateError"'));
    expect(failure, isNot(contains('private')));
    expect(failure, isNot(contains('api-key')));
  });
}
