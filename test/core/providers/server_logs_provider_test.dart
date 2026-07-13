import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/providers/server_logs_provider.dart';

void main() {
  group('ServerLogsProvider', () {
    test('loads existing server logs at initialization', () {
      final logger = AppLogger();
      logger.info('existing', channel: LogChannel.server, inMemory: true);

      final provider = ServerLogsProvider(logger: logger);

      expect(provider.logs, hasLength(1));
      expect(provider.logs.single.message, 'existing');
      provider.dispose();
    });

    test('updates when new server logs arrive', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger);

      logger.info('hello', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.count, 1);
      expect(provider.logs.single.formattedMessage, 'hello');
      provider.dispose();
    });

    test('copyText joins stored server logs', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger);

      logger.info('system', channel: LogChannel.server, inMemory: true);
      logger.info('out', channel: LogChannel.server, inMemory: true);
      logger.info('err', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.copyText, 'system\nout\nerr');
      provider.dispose();
    });

    test('caps in-memory logs to maxEntries, dropping oldest', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger, maxEntries: 2);

      logger.info('one', channel: LogChannel.server, inMemory: true);
      logger.info('two', channel: LogChannel.server, inMemory: true);
      logger.info('three', channel: LogChannel.server, inMemory: true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.count, 2);
      expect(provider.logs.first.message, 'two');
      expect(provider.logs.last.message, 'three');
      provider.dispose();
    });

    test('default maxEntries is 1000', () {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger);

      expect(provider.maxEntries, 1000);
      provider.dispose();
    });

    test('clear only clears server logs', () async {
      final logger = AppLogger();
      logger.info('server', channel: LogChannel.server, inMemory: true);
      logger.info('model', channel: LogChannel.model, inMemory: true);
      final provider = ServerLogsProvider(logger: logger);

      provider.clear();

      expect(provider.isEmpty, isTrue);
      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), hasLength(1));
      provider.dispose();
    });

    test('coalesces a burst of entries into one notification', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(
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

    test('clear notifies immediately and cancels the pending notification',
        () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(
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
    });
  });
}
