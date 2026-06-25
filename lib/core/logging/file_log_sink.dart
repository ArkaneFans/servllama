import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/log_sink.dart';

class FileLogSink implements LogSink {
  FileLogSink({
    required this.logsDirectory,
    this.maxFileBytes = 1024 * 1024,
    this.flushThreshold = 64,
    this.flushInterval = const Duration(seconds: 1),
    this.retainedFiles = 3,
  }) : _logFile = File('${logsDirectory.path}/$_logFileName');

  static const String _logFileName = 'app.log';

  final Directory logsDirectory;
  final int maxFileBytes;
  final int flushThreshold;
  final Duration flushInterval;
  final int retainedFiles;

  final File _logFile;
  List<String> _pending = <String>[];
  Timer? _timer;
  Future<void> _writeQueue = Future<void>.value();

  static Future<FileLogSink> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return FileLogSink(logsDirectory: dir);
  }

  @override
  void add(AppLogEntry entry) {
    _pending.add(_serialize(entry));
    if (_pending.length >= flushThreshold) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushInterval, () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  @override
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) {
      return _writeQueue;
    }
    final batch = '${_pending.join('\n')}\n';
    _pending = <String>[];
    _writeQueue = _writeQueue
        .then((_) => _append(batch))
        .catchError((_) {});
    return _writeQueue;
  }

  @override
  Future<List<AppLogEntry>> loadRecent(int max) async {
    await flush();
    final entries = <AppLogEntry>[];

    // Read current file first
    entries.addAll(await _readEntries(_logFile));

    // Read older rotated files until we have enough or run out
    for (var i = 1; i < retainedFiles && entries.length < max; i++) {
      final older = await _readEntries(File('${_logFile.path}.$i'));
      if (older.isEmpty) {
        break;
      }
      entries.insertAll(0, older);
    }

    // Return the most recent max entries
    if (entries.length > max) {
      return entries.sublist(entries.length - max);
    }
    return entries;
  }

  @override
  Future<void> clear() {
    _timer?.cancel();
    _timer = null;
    _pending = <String>[];
    _writeQueue = _writeQueue.then((_) async {
      for (var i = retainedFiles - 1; i >= 1; i--) {
        final f = File('${_logFile.path}.$i');
        if (await f.exists()) {
          await f.delete();
        }
      }
      if (await _logFile.exists()) {
        await _logFile.delete();
      }
    }).catchError((_) {});
    return _writeQueue;
  }

  Future<void> _append(String data) async {
    await _logFile.writeAsString(data, mode: FileMode.append, flush: true);
    await _rotateIfNeeded();
  }

  Future<void> _rotateIfNeeded() async {
    if (!await _logFile.exists()) {
      return;
    }
    if (await _logFile.length() < maxFileBytes) {
      return;
    }
    final oldest = File('${_logFile.path}.${retainedFiles - 1}');
    if (await oldest.exists()) {
      await oldest.delete();
    }
    for (var i = retainedFiles - 2; i >= 1; i--) {
      final current = File('${_logFile.path}.$i');
      if (await current.exists()) {
        await current.rename('${_logFile.path}.${i + 1}');
      }
    }
    await _logFile.rename('${_logFile.path}.1');
  }

  Future<List<AppLogEntry>> _readEntries(File file) async {
    if (!await file.exists()) {
      return <AppLogEntry>[];
    }
    final content = await file.readAsString();
    final entries = <AppLogEntry>[];
    for (final line in content.split('\n')) {
      final entry = _parse(line);
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  String _serialize(AppLogEntry entry) =>
      '${entry.timestamp.millisecondsSinceEpoch}'
      '|${entry.channel.name}'
      '|${entry.level.name}'
      '|${_escape(entry.message)}';

  AppLogEntry? _parse(String line) {
    if (line.isEmpty) {
      return null;
    }
    final parts = line.split('|');
    if (parts.length < 4) {
      return null;
    }
    final millis = int.tryParse(parts[0]);
    if (millis == null) {
      return null;
    }
    final channel = _channelByName(parts[1]);
    final level = _levelByName(parts[2]);
    if (channel == null || level == null) {
      return null;
    }
    final message = _unescape(parts.sublist(3).join('|'));
    return AppLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
      channel: channel,
      level: level,
      message: message,
    );
  }

  LogChannel? _channelByName(String name) {
    for (final channel in LogChannel.values) {
      if (channel.name == name) {
        return channel;
      }
    }
    return null;
  }

  LogLevel? _levelByName(String name) {
    for (final level in LogLevel.values) {
      if (level.name == name) {
        return level;
      }
    }
    return null;
  }

  String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('|', '\\p');

  String _unescape(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char == '\\' && i + 1 < value.length) {
        final next = value[i + 1];
        i++;
        switch (next) {
          case 'n':
            buffer.write('\n');
          case 'r':
            buffer.write('\r');
          case 'p':
            buffer.write('|');
          case '\\':
            buffer.write('\\');
          default:
            buffer.write(next);
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
