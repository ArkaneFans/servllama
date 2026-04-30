import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('background logs do not enter page cache', () {
      final logger = AppLogger();

      logger.info('background only', channel: LogChannel.server);

      expect(logger.entriesFor(LogChannel.server), isEmpty);
    });

    test('page logs enter the matching channel cache', () {
      final logger = AppLogger();

      logger.pageInfo('visible log', channel: LogChannel.server);

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(1));
      expect(entries.single.message, 'visible log');
      expect(entries.single.formattedMessage, 'visible log');
      expect(entries.single.level, LogLevel.info);
    });

    test('server stdout and stderr are stored in server cache', () {
      final logger = AppLogger();

      logger.serverStdout('hello');
      logger.serverStderr('boom');

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(2));
      expect(entries.first.message, 'hello');
      expect(entries.first.formattedMessage, 'hello');
      expect(entries.last.message, 'boom');
      expect(entries.last.formattedMessage, 'boom');
    });

    test('drops oldest entries when max cache size is exceeded', () {
      final logger = AppLogger(maxEntries: 2);

      logger.pageInfo('one', channel: LogChannel.server);
      logger.pageInfo('two', channel: LogChannel.server);
      logger.pageInfo('three', channel: LogChannel.server);

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(2));
      expect(entries.first.message, 'two');
      expect(entries.last.message, 'three');
    });

    test('clearChannel only clears the target channel', () {
      final logger = AppLogger();

      logger.pageInfo('server log', channel: LogChannel.server);
      logger.pageInfo('model log', channel: LogChannel.model);

      logger.clearChannel(LogChannel.server);

      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), hasLength(1));
    });
  });
}
