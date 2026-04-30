import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/providers/server_logs_provider.dart';

void main() {
  group('ServerLogsProvider', () {
    test('loads existing server logs at initialization', () {
      final logger = AppLogger();
      logger.pageInfo('existing', channel: LogChannel.server);

      final provider = ServerLogsProvider(logger: logger);

      expect(provider.logs, hasLength(1));
      expect(provider.logs.single.message, 'existing');
      provider.dispose();
    });

    test('updates when new server logs arrive', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger);

      logger.serverStdout('hello');
      await Future<void>.delayed(Duration.zero);

      expect(provider.count, 1);
      expect(provider.logs.single.formattedMessage, 'hello');
      provider.dispose();
    });

    test('copyText joins stored server logs', () async {
      final logger = AppLogger();
      final provider = ServerLogsProvider(logger: logger);

      logger.pageInfo('system', channel: LogChannel.server);
      logger.serverStdout('out');
      logger.serverStderr('err');
      await Future<void>.delayed(Duration.zero);

      expect(provider.copyText, 'system\nout\nerr');
      provider.dispose();
    });

    test('clear only clears server logs', () async {
      final logger = AppLogger();
      logger.pageInfo('server', channel: LogChannel.server);
      logger.pageInfo('model', channel: LogChannel.model);
      final provider = ServerLogsProvider(logger: logger);

      provider.clear();

      expect(provider.isEmpty, isTrue);
      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), hasLength(1));
      provider.dispose();
    });
  });
}
