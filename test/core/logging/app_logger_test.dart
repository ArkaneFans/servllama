import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/log_sink.dart';
import 'package:servllama/core/security/log_redactor.dart';

class _FakeLogSink implements LogSink {
  final List<AppLogEntry> added = <AppLogEntry>[];
  int flushCount = 0;
  int clearCount = 0;
  bool failWrites = false;

  @override
  void add(AppLogEntry entry) {
    if (failWrites) throw StateError('storage unavailable');
    added.add(entry);
  }

  @override
  Future<void> flush() async => flushCount++;

  @override
  Future<List<AppLogEntry>> loadRecent(int max) async => const <AppLogEntry>[];

  @override
  Future<void> clear() async => clearCount++;
}

void main() {
  group('AppLogger', () {
    test(
      'diagnostic events persist safe scalar metadata in the page cache',
      () {
        final logger = AppLogger();
        addTearDown(logger.dispose);
        final sink = _FakeLogSink();
        logger.attachSink(sink);
        final credential = 'long-event-credential-' * 20;
        LogRedactor.remember(credential);
        logger.event(
          'speech.job.finished',
          channel: LogChannel.speech,
          fields: {
            'job': 'one\ntwo',
            'elapsed_ms': 42,
            'released': true,
            'credential': credential,
            'absent': null,
            'payload': {'text': 'private-payload'},
            'samples': [1, 2, 3],
          },
        );
        final entry = logger.entriesFor(LogChannel.speech).single;
        expect(sink.added.single, same(entry));
        expect(entry.message, contains('elapsed_ms=42 released=true'));
        expect(entry.message, contains(r'job="one\ntwo"'));
        expect(entry.message, isNot(contains('\n')));
        expect(entry.message, contains('[REDACTED]'));
        for (final excluded in [
          'long-event-credential',
          'private-payload',
          'payload=',
          'samples=',
          'absent=',
        ]) {
          expect(entry.message, isNot(contains(excluded)));
        }
      },
    );

    test(
      'failure metadata excludes request, response, path and platform messages',
      () {
        final options = RequestOptions(
          path: 'https://private-host/secret-path',
          data: {'prompt': 'private-prompt'},
          headers: {'Authorization': 'private-key'},
        );
        final error = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          message: 'private-error',
          response: Response(
            requestOptions: options,
            statusCode: 429,
            data: 'private-response',
          ),
        );
        expect(AppLogger.errorFields(error), {
          'error_type': 'DioException',
          'network_kind': 'badResponse',
          'http_status': 429,
        });
        expect(
          AppLogger.errorFields(
            const FileSystemException(
              'private-message',
              '/private-path',
              OSError('private-os-message', 13),
            ),
          ),
          {'error_type': 'FileSystemException', 'os_error': 13},
        );
        expect(
          AppLogger.errorFields(
            PlatformException(
              code: 'audio_decode',
              message: 'private-text',
              details: 'private-details',
            ),
          ),
          {'error_type': 'PlatformException', 'platform_code': 'audio_decode'},
        );
      },
    );

    test(
      'failed sink writes do not fail an event or hide it from the page',
      () {
        final logger = AppLogger();
        addTearDown(logger.dispose);
        logger.attachSink(_FakeLogSink()..failWrites = true);
        expect(() => logger.event('client.request.finished'), returnsNormally);
        expect(
          logger.entriesFor(LogChannel.app).single.message,
          'client.request.finished',
        );
      },
    );

    test('new and restored messages stay bounded', () {
      final logger = AppLogger();
      addTearDown(logger.dispose);
      logger.event('bounded', fields: {'id': 'z' * 500});
      expect(
        logger.entriesFor(LogChannel.app).single.message.length,
        lessThan(200),
      );
      logger.info('z' * 9000, inMemory: true);
      expect(logger.entriesFor(LogChannel.app).last.message.length, 8193);
      logger.restore([
        AppLogEntry(
          timestamp: DateTime(2026),
          channel: LogChannel.client,
          level: LogLevel.info,
          message: 'z' * 9000,
        ),
      ]);
      expect(logger.entriesFor(LogChannel.client).single.message.length, 8193);
    });

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

    test('cache bound is shared across all application channels', () {
      final logger = AppLogger(maxEntries: 2);
      addTearDown(logger.dispose);
      logger.event('old', channel: LogChannel.server);
      logger.event('recent-client', channel: LogChannel.client);
      logger.event('recent-speech', channel: LogChannel.speech);
      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(
        logger.entriesFor(LogChannel.client).single.message,
        'recent-client',
      );
      expect(
        logger.entriesFor(LogChannel.speech).single.message,
        'recent-speech',
      );
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

    test('restore respects maxEntries', () {
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
