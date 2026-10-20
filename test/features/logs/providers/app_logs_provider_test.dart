import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/log_sink.dart';
import 'package:servllama/features/logs/providers/app_logs_provider.dart';

void main() {
  group('AppLogsProvider', () {
    test(
      'all channels share combined channel, minimum level and keyword filters',
      () {
        final logger = AppLogger();
        addTearDown(logger.dispose);
        for (final channel in LogChannel.values) {
          logger.event('finished', channel: channel, fields: {'job': 'wanted'});
          logger.event(
            'failed',
            channel: channel,
            level: LogLevel.error,
            fields: {'job': 'wanted'},
          );
          logger.event(
            'failed',
            channel: channel,
            level: LogLevel.error,
            fields: {'job': 'different'},
          );
        }
        final provider = AppLogsProvider(logger: logger);
        addTearDown(provider.dispose);
        expect(provider.count, LogChannel.values.length * 3);
        final matching = provider.query(
          channel: LogChannel.speech,
          minimumLevel: LogLevel.warning,
          text: ' WANTED ',
        );
        expect(matching, hasLength(1));
        expect(matching.single.level, LogLevel.error);
        expect(provider.query(text: '[CLIENT]'), hasLength(3));
        expect(provider.query(text: 'missing'), isEmpty);
        expect(
          provider.formatEntry(
            AppLogEntry(
              timestamp: DateTime(2026, 9, 27, 8, 9, 10, 12),
              channel: LogChannel.app,
              level: LogLevel.info,
              message: 'boot',
            ),
          ),
          '2026-09-27 08:09:10.012 [INFO] [app] boot',
        );
      },
    );

    test(
      'failed disk clear is reported while memory is cleared and logging continues',
      () async {
        final logger = AppLogger()..attachSink(_ClearFailureSink());
        addTearDown(logger.dispose);
        logger.event('old');
        final provider = AppLogsProvider(logger: logger);
        addTearDown(provider.dispose);
        await expectLater(provider.clear(), throwsStateError);
        expect(
          provider.logs.single.message,
          startsWith('logging.clear_failed'),
        );
        logger.event('new', channel: LogChannel.client);
        expect(provider.logs.last.message, 'new');
      },
    );

    test('loads existing server logs at initialization', () {
      final logger = AppLogger();
      logger.info('existing', channel: LogChannel.server, inMemory: true);

      final provider = AppLogsProvider(logger: logger);

      expect(provider.logs, hasLength(1));
      expect(provider.logs.single.message, 'existing');
      provider.dispose();
    });

    test('updates when new server logs arrive', () async {
      final logger = AppLogger();
      final provider = AppLogsProvider(logger: logger);

      logger.info('hello', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.count, 1);
      expect(provider.logs.single.formattedMessage, 'hello');
      provider.dispose();
    });

    test('copyText joins stored server logs', () async {
      final logger = AppLogger();
      final provider = AppLogsProvider(logger: logger);

      logger.info('system', channel: LogChannel.server, inMemory: true);
      logger.info('out', channel: LogChannel.server, inMemory: true);
      logger.info('err', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      final copiedLines = provider.copyText.split('\n');
      expect(copiedLines, hasLength(3));
      expect(copiedLines[0], endsWith('[INFO] [server] system'));
      expect(copiedLines[1], endsWith('[INFO] [server] out'));
      expect(copiedLines[2], endsWith('[INFO] [server] err'));
      provider.dispose();
    });

    test('caps in-memory logs to maxEntries, dropping oldest', () async {
      final logger = AppLogger();
      final provider = AppLogsProvider(logger: logger, maxEntries: 2);

      logger.info('one', channel: LogChannel.server, inMemory: true);
      logger.info('two', channel: LogChannel.server, inMemory: true);
      logger.info('three', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.count, 2);
      expect(provider.logs.first.message, 'two');
      expect(provider.logs.last.message, 'three');
      provider.dispose();
    });

    test('default maxEntries is 2000', () {
      final logger = AppLogger();
      final provider = AppLogsProvider(logger: logger);

      expect(provider.maxEntries, 2000);
      provider.dispose();
    });

    test('clear removes every channel displayed by the log page', () async {
      final logger = AppLogger();
      logger.info('server', channel: LogChannel.server, inMemory: true);
      logger.info('model', channel: LogChannel.model, inMemory: true);
      logger.info('app', channel: LogChannel.app, inMemory: true);
      final provider = AppLogsProvider(logger: logger);

      await provider.clear();

      expect(provider.isEmpty, isTrue);
      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), isEmpty);
      expect(logger.entriesFor(LogChannel.app), isEmpty);
      provider.dispose();
    });

    test('coalesces a burst of entries into one notification', () async {
      final logger = AppLogger();
      final provider = AppLogsProvider(
        logger: logger,
        notifyThrottle: const Duration(milliseconds: 20),
      );
      var notifications = 0;
      provider.addListener(() => notifications += 1);

      for (var i = 0; i < 50; i++) {
        logger.info('line $i', channel: LogChannel.server, inMemory: true);
      }

      // Entries are stored immediately; the notification waits for the
      // throttle window.
      expect(provider.count, 50);
      expect(notifications, 0);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifications, 1);
      provider.dispose();
    });

    test(
      'clear notifies immediately and cancels the pending notification',
      () async {
        final logger = AppLogger();
        final provider = AppLogsProvider(
          logger: logger,
          notifyThrottle: const Duration(milliseconds: 20),
        );
        var notifications = 0;
        provider.addListener(() => notifications += 1);

        logger.info('line', channel: LogChannel.server, inMemory: true);
        provider.clear();

        expect(provider.isEmpty, isTrue);
        expect(notifications, 1);

        await Future<void>.delayed(const Duration(milliseconds: 60));

        // The throttled notification was cancelled — no second callback.
        expect(notifications, 1);
        provider.dispose();
      },
    );
  });
}

class _ClearFailureSink extends NoopLogSink {
  @override
  Future<void> clear() async => throw StateError('disk unavailable');
}
