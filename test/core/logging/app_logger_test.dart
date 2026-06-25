import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/log_sink.dart';

class _FakeLogSink implements LogSink {
  final List<AppLogEntry> added = <AppLogEntry>[];
  int flushCount = 0;
  int clearCount = 0;

  @override
  void add(AppLogEntry entry) => added.add(entry);

  @override
  Future<void> flush() async => flushCount++;

  @override
  Future<List<AppLogEntry>> loadRecent(int max) async => const <AppLogEntry>[];

  @override
  Future<void> clear() async => clearCount++;
}

void main() {
  group('AppLogger', () {
    test('background logs do not enter page cache', () {
      final logger = AppLogger();

      logger.info('background only', channel: LogChannel.server);

      expect(logger.entriesFor(LogChannel.server), isEmpty);
    });

    test('inMemory logs enter the matching channel cache', () {
      final logger = AppLogger();

      logger.info('visible log', channel: LogChannel.server, inMemory: true);

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(1));
      expect(entries.single.message, 'visible log');
      expect(entries.single.formattedMessage, 'visible log');
      expect(entries.single.level, LogLevel.info);
    });

    test('drops oldest entries when max cache size is exceeded', () {
      final logger = AppLogger(maxEntries: 2);

      logger.info('one', channel: LogChannel.server, inMemory: true);
      logger.info('two', channel: LogChannel.server, inMemory: true);
      logger.info('three', channel: LogChannel.server, inMemory: true);

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(2));
      expect(entries.first.message, 'two');
      expect(entries.last.message, 'three');
    });

    test('clearChannel only clears the target channel', () {
      final logger = AppLogger();

      logger.info('server log', channel: LogChannel.server, inMemory: true);
      logger.info('model log', channel: LogChannel.model, inMemory: true);

      logger.clearChannel(LogChannel.server);

      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), hasLength(1));
    });

    test('default max cache size is 2000', () {
      expect(AppLogger().maxEntries, 2000);
    });

    group('persistence', () {
      test('persist follows inMemory by default', () {
        final logger = AppLogger();
        final sink = _FakeLogSink();
        logger.attachSink(sink);

        logger.info('stored', channel: LogChannel.server, inMemory: true);

        expect(sink.added, hasLength(1));
        expect(sink.added.single.message, 'stored');
      });

      test('inMemory log can opt out of persistence', () {
        final logger = AppLogger();
        final sink = _FakeLogSink();
        logger.attachSink(sink);

        logger.info(
          'memory only',
          channel: LogChannel.server,
          inMemory: true,
          persist: false,
        );

        expect(logger.entriesFor(LogChannel.server), hasLength(1));
        expect(sink.added, isEmpty);
      });

      test('persist: true without inMemory writes to sink but not cache', () {
        final logger = AppLogger();
        final sink = _FakeLogSink();
        logger.attachSink(sink);

        logger.info('disk only', channel: LogChannel.app, persist: true);

        expect(logger.entriesFor(LogChannel.app), isEmpty);
        expect(sink.added, hasLength(1));
        expect(sink.added.single.message, 'disk only');
      });

      test('clearPersisted delegates to the sink', () async {
        final logger = AppLogger();
        final sink = _FakeLogSink();
        logger.attachSink(sink);

        await logger.clearPersisted();

        expect(sink.clearCount, 1);
      });
    });

    test('restore distributes entries by channel without re-persisting', () {
      final logger = AppLogger();
      final sink = _FakeLogSink();
      logger.attachSink(sink);

      logger.restore([
        AppLogEntry(
          timestamp: DateTime(2026, 6, 21, 10),
          channel: LogChannel.server,
          level: LogLevel.info,
          message: 'srv',
        ),
        AppLogEntry(
          timestamp: DateTime(2026, 6, 21, 11),
          channel: LogChannel.model,
          level: LogLevel.warning,
          message: 'mdl',
        ),
      ]);

      expect(logger.entriesFor(LogChannel.server).single.message, 'srv');
      expect(logger.entriesFor(LogChannel.model).single.message, 'mdl');
      expect(sink.added, isEmpty);
    });

    test('restore respects maxEntries per channel', () {
      final logger = AppLogger(maxEntries: 1);

      logger.restore([
        AppLogEntry(
          timestamp: DateTime(2026, 6, 21, 10),
          channel: LogChannel.server,
          level: LogLevel.info,
          message: 'old',
        ),
        AppLogEntry(
          timestamp: DateTime(2026, 6, 21, 11),
          channel: LogChannel.server,
          level: LogLevel.info,
          message: 'new',
        ),
      ]);

      final entries = logger.entriesFor(LogChannel.server);
      expect(entries, hasLength(1));
      expect(entries.single.message, 'new');
    });
  });
}
