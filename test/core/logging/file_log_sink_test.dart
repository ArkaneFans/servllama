import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/file_log_sink.dart';

AppLogEntry _entry(String message, {int second = 0}) => AppLogEntry(
  timestamp: DateTime(2026, 6, 21, 10, 0, second),
  channel: LogChannel.server,
  level: LogLevel.info,
  message: message,
);

void main() {
  group('FileLogSink', () {
    late Directory logsDirectory;

    setUp(() async {
      logsDirectory = await Directory.systemTemp.createTemp('servllama_logs_');
    });

    tearDown(() async {
      if (await logsDirectory.exists()) {
        await logsDirectory.delete(recursive: true);
      }
    });

    test('writes entries and reads them back after flush', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory);

      sink.add(_entry('one', second: 1));
      sink.add(_entry('two', second: 2));
      await sink.flush();

      final loaded = await sink.loadRecent(10);
      expect(loaded.map((e) => e.message), ['one', 'two']);
      expect(loaded.first.channel, LogChannel.server);
      expect(loaded.first.level, LogLevel.info);
    });

    test('loadRecent returns only the last N entries', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory);

      for (var i = 0; i < 5; i++) {
        sink.add(_entry('m$i', second: i));
      }
      await sink.flush();

      final loaded = await sink.loadRecent(3);
      expect(loaded.map((e) => e.message), ['m2', 'm3', 'm4']);
    });

    test('preserves messages containing newlines and pipes', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory);

      sink.add(_entry('line1\nline2|tail', second: 1));
      await sink.flush();

      final loaded = await sink.loadRecent(10);
      expect(loaded.single.message, 'line1\nline2|tail');
    });

    test('rotates the file once it exceeds the size threshold', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory, maxFileBytes: 200);

      for (var i = 0; i < 20; i++) {
        sink.add(_entry('entry-number-$i', second: i));
      }
      await sink.flush();

      expect(await File('${logsDirectory.path}/app.log.1').exists(), isTrue);
      // History remains readable through loadRecent.
      final loaded = await sink.loadRecent(50);
      expect(loaded, isNotEmpty);
    });

    test('loadRecent reads across multiple rotated files when needed', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory, maxFileBytes: 150);

      // Write enough to trigger multiple rotations
      for (var i = 0; i < 30; i++) {
        sink.add(_entry('entry-$i', second: i));
      }
      await sink.flush();

      // Should have rotated, creating .1 and possibly .2
      final loaded = await sink.loadRecent(25);
      expect(loaded.length, greaterThanOrEqualTo(20));
      // Verify we got recent entries (exact count depends on rotation timing)
      expect(loaded.last.message, contains('entry-'));
    });

    test('clear removes the log files', () async {
      final sink = FileLogSink(logsDirectory: logsDirectory);

      sink.add(_entry('temp', second: 1));
      await sink.flush();
      expect(await File('${logsDirectory.path}/app.log').exists(), isTrue);

      await sink.clear();

      expect(await File('${logsDirectory.path}/app.log').exists(), isFalse);
      expect(await sink.loadRecent(10), isEmpty);
    });

    test('skips malformed lines when loading', () async {
      final file = File('${logsDirectory.path}/app.log');
      await file.writeAsString('not-a-valid-line\n');

      final sink = FileLogSink(logsDirectory: logsDirectory);
      sink.add(_entry('valid', second: 1));
      await sink.flush();

      final loaded = await sink.loadRecent(10);
      expect(loaded.map((e) => e.message), ['valid']);
    });
  });
}
