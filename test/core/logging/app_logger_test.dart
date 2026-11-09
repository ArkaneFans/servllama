import 'dart:async';
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
  Completer<List<AppLogEntry>>? history;
  int historyReads = 0;

  @override
  void add(AppLogEntry entry) {
    if (failWrites) throw StateError('storage unavailable');
    added.add(entry);
  }

  @override
  Future<void> flush() async => flushCount++;

  @override
  Future<List<AppLogEntry>> loadRecent(int max) {
    historyReads++;
    return history?.future ?? Future.value(const <AppLogEntry>[]);
  }

  @override
  Future<void> clear() async => clearCount++;
}

void main() {
  group('AppLogger', () {
    test(
      'lazy history is shared and merges with bounded live startup logs',
      () async {
        final logger = AppLogger(maxEntries: 3);
        addTearDown(logger.dispose);
        final sink = _FakeLogSink()..history = Completer<List<AppLogEntry>>();
        logger.attachSink(sink);
        expect(sink.historyReads, 0);
        final read = logger.ensureHistoryLoaded();
        expect(identical(read, logger.ensureHistoryLoaded()), isTrue);
        logger.event('startup-one');
        logger.event('startup-two');
        sink.history!.complete([
          for (final name in ['oldest', 'old'])
            AppLogEntry(
              timestamp: DateTime(2020),
              channel: LogChannel.app,
              level: LogLevel.info,
              message: name,
            ),
          // A sink flush may include a live event written during its read.
          ...sink.added,
        ]);
        await read;
        expect(logger.entriesFor(LogChannel.app).map((e) => e.message), [
          'old',
          'startup-one',
          'startup-two',
        ]);
        expect(sink.added, hasLength(2));
        await logger.ensureHistoryLoaded();
        expect(sink.historyReads, 1);
      },
    );

    test(
      'clearing while history is pending cannot resurrect old logs',
      () async {
        final logger = AppLogger();
        addTearDown(logger.dispose);
        final sink = _FakeLogSink()..history = Completer<List<AppLogEntry>>();
        logger.attachSink(sink);
        final read = logger.ensureHistoryLoaded();
        logger.event('discard');
        logger.clearChannel(LogChannel.app);
        await logger.clearPersisted();
        logger.event('after-clear');
        sink.history!.complete([
          AppLogEntry(
            timestamp: DateTime(2020),
            channel: LogChannel.app,
            level: LogLevel.info,
            message: 'old',
          ),
        ]);
        await read;
        expect(logger.entriesFor(LogChannel.app).single.message, 'after-clear');
        await logger.ensureHistoryLoaded();
        expect(sink.historyReads, 1);
      },
    );

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

    test('clearChannel only clears the target channel', () {
      final logger = AppLogger();

      logger.info('server log', channel: LogChannel.server, inMemory: true);
      logger.info('model log', channel: LogChannel.model, inMemory: true);

      logger.clearChannel(LogChannel.server);

      expect(logger.entriesFor(LogChannel.server), isEmpty);
      expect(logger.entriesFor(LogChannel.model), hasLength(1));
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
  });
}
