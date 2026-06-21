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
  });
}
