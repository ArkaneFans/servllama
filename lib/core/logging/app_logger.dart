import 'dart:async';
import 'dart:developer' as developer;

import 'package:servllama/core/logging/log_sink.dart';

enum LogChannel { app, server, model }

enum LogLevel { debug, info, warning, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.channel,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final LogChannel channel;
  final LogLevel level;
  final String message;

  bool get isError => level == LogLevel.error;

  String get formattedMessage => message;
}

class AppLogger {
  AppLogger({this.maxEntries = defaultMaxEntries});

  AppLogger._shared() : maxEntries = defaultMaxEntries;

  static const int defaultMaxEntries = 2000;

  static final AppLogger instance = AppLogger._shared();

  final int maxEntries;

  LogSink _sink = const NoopLogSink();

  final Map<LogChannel, List<AppLogEntry>> _entries = {
    for (final channel in LogChannel.values) channel: <AppLogEntry>[],
  };
  final Map<LogChannel, StreamController<AppLogEntry>> _controllers = {
    for (final channel in LogChannel.values)
      channel: StreamController<AppLogEntry>.broadcast(sync: true),
  };

  void debug(
    String message, {
    LogChannel channel = LogChannel.app,
    bool inMemory = false,
    bool? persist,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.debug,
      inMemory: inMemory,
      persist: persist,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void info(
    String message, {
    LogChannel channel = LogChannel.app,
    bool inMemory = false,
    bool? persist,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.info,
      inMemory: inMemory,
      persist: persist,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void warning(
    String message, {
    LogChannel channel = LogChannel.app,
    bool inMemory = false,
    bool? persist,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.warning,
      inMemory: inMemory,
      persist: persist,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String message, {
    LogChannel channel = LogChannel.app,
    bool inMemory = false,
    bool? persist,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.error,
      inMemory: inMemory,
      persist: persist,
      error: error,
      stackTrace: stackTrace,
    );
  }

  List<AppLogEntry> entriesFor(LogChannel channel) =>
      List<AppLogEntry>.unmodifiable(_entries[channel]!);

  Stream<AppLogEntry> streamFor(LogChannel channel) =>
      _controllers[channel]!.stream;

  void attachSink(LogSink sink) {
    _sink = sink;
  }

  void restore(List<AppLogEntry> entries) {
    for (final entry in entries) {
      final cache = _entries[entry.channel]!;
      cache.add(entry);
      if (cache.length > maxEntries) {
        cache.removeRange(0, cache.length - maxEntries);
      }
    }
  }

  Future<void> flushSink() => _sink.flush();

  Future<void> clearPersisted() => _sink.clear();

  void clearChannel(LogChannel channel) {
    _entries[channel]!.clear();
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }

  void _record(
    String message, {
    required LogChannel channel,
    required LogLevel level,
    bool inMemory = false,
    bool? persist,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final normalizedMessage = _composeMessage(message, error);
    if (normalizedMessage.isEmpty) {
      return;
    }

    developer.log(
      normalizedMessage,
      name: channel.name,
      level: _developerLevel(level),
      error: error,
      stackTrace: stackTrace,
    );

    final shouldPersist = persist ?? inMemory;
    if (!inMemory && !shouldPersist) {
      return;
    }

    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      channel: channel,
      level: level,
      message: normalizedMessage,
    );

    if (shouldPersist) {
      _sink.add(entry);
    }

    if (!inMemory) {
      return;
    }

    final entries = _entries[channel]!;
    entries.add(entry);
    if (entries.length > maxEntries) {
      entries.removeRange(0, entries.length - maxEntries);
    }
    _controllers[channel]!.add(entry);
  }

  String _composeMessage(String message, Object? error) {
    final normalized = message.trimRight();
    if (error == null) {
      return normalized;
    }
    if (normalized.isEmpty) {
      return '$error';
    }
    return '$normalized: $error';
  }

  int _developerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
