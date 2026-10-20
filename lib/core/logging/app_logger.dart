import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:servllama/core/security/log_redactor.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'package:servllama/core/logging/log_sink.dart';

enum LogChannel { app, engine, server, model, download, client, agent, speech }

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

  // One application-wide bound, independent of how many channels exist.
  final ListQueue<AppLogEntry> _entries = ListQueue<AppLogEntry>();
  final Map<LogChannel, StreamController<AppLogEntry>> _controllers = {
    for (final channel in LogChannel.values)
      channel: StreamController<AppLogEntry>.broadcast(sync: true),
  };

  /// Diagnostic events contain identifiers, counts and states, never payloads.
  /// Keep the existing file format and sink for all application features.
  void event(
    String name, {
    LogChannel channel = LogChannel.app,
    LogLevel level = LogLevel.info,
    Map<String, Object?> fields = const {},
  }) {
    final parts = <String>[name];
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String) {
        final safe = LogRedactor.redact(value);
        final bounded = safe.length > 160 ? '${safe.substring(0, 160)}…' : safe;
        parts.add('${entry.key}=${jsonEncode(bounded)}');
      } else if (value is num || value is bool) {
        parts.add('${entry.key}=$value');
      }
    }
    _record(parts.join(' '), channel: channel, level: level, inMemory: true);
  }

  /// Exception messages may contain prompts, tool arguments, URLs or audio
  /// paths. Use only typed diagnostic metadata for client/speech failures.
  static Map<String, Object?> errorFields(Object error) => {
    'error_type': error.runtimeType.toString(),
    if (error is DioException) ...{
      'network_kind': error.type.name,
      'http_status': error.response?.statusCode,
    },
    if (error is FileSystemException) 'os_error': error.osError?.errorCode,
    if (error is PlatformException &&
        RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(error.code))
      'platform_code': error.code,
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
      List<AppLogEntry>.unmodifiable(
        _entries.where((entry) => entry.channel == channel),
      );

  Stream<AppLogEntry> streamFor(LogChannel channel) =>
      _controllers[channel]!.stream;

  void attachSink(LogSink sink) {
    _sink = sink;
  }

  void restore(List<AppLogEntry> entries) {
    for (final entry in entries) {
      _cache(
        AppLogEntry(
          timestamp: entry.timestamp,
          channel: entry.channel,
          level: entry.level,
          message: _sanitizeMessage(entry.message),
        ),
      );
    }
  }

  Future<void> flushSink() => _sink.flush();

  Future<void> clearPersisted() => _sink.clear();

  void clearChannel(LogChannel channel) {
    _entries.removeWhere((entry) => entry.channel == channel);
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
    final normalizedMessage = _sanitizeMessage(_composeMessage(message, error));
    if (normalizedMessage.isEmpty) {
      return;
    }

    developer.log(
      normalizedMessage,
      name: channel.name,
      level: _developerLevel(level),
      error: error == null ? null : LogRedactor.redact(error.toString()),
      stackTrace: stackTrace == null
          ? null
          : StackTrace.fromString(LogRedactor.redact(stackTrace.toString())),
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
      // Logging must not turn a successful inference into a failed task.
      try {
        _sink.add(entry);
      } catch (_) {
        // The in-memory view remains available if persistence fails.
      }
    }

    if (!inMemory) {
      return;
    }

    _cache(entry);
    _controllers[channel]!.add(entry);
  }

  void _cache(AppLogEntry entry) {
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  String _sanitizeMessage(String message) {
    final redacted = LogRedactor.redact(message);
    return redacted.length > 8192
        ? '${redacted.substring(0, 8192)}…'
        : redacted;
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
