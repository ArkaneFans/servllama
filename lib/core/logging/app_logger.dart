import 'dart:async';
import 'dart:developer' as developer;

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

  String get formattedMessage {
    switch (channel) {
      case LogChannel.server:
        return '[server] $message';
      default:
        return message;
    }
  }
}

class AppLogger {
  AppLogger({this.maxEntries = defaultMaxEntries});

  AppLogger._shared() : maxEntries = defaultMaxEntries;

  static const int defaultMaxEntries = 1000;

  static final AppLogger instance = AppLogger._shared();

  final int maxEntries;

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
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.debug,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void info(
    String message, {
    LogChannel channel = LogChannel.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.info,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void warning(
    String message, {
    LogChannel channel = LogChannel.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.warning,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String message, {
    LogChannel channel = LogChannel.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void pageInfo(
    String message, {
    required LogChannel channel,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.info,
      displayInPage: true,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void pageWarning(
    String message, {
    required LogChannel channel,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.warning,
      displayInPage: true,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void pageError(
    String message, {
    required LogChannel channel,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _record(
      message,
      channel: channel,
      level: LogLevel.error,
      displayInPage: true,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void serverStdout(String message) {
    _record(
      message,
      channel: LogChannel.server,
      level: LogLevel.info,
      displayInPage: true,
    );
  }

  void serverStderr(String message) {
    _record(
      message,
      channel: LogChannel.server,
      level: LogLevel.info,
      displayInPage: true,
    );
  }

  List<AppLogEntry> entriesFor(LogChannel channel) =>
      List<AppLogEntry>.unmodifiable(_entries[channel]!);

  Stream<AppLogEntry> streamFor(LogChannel channel) =>
      _controllers[channel]!.stream;

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
    bool displayInPage = false,
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

    if (!displayInPage) {
      return;
    }

    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      channel: channel,
      level: level,
      message: normalizedMessage,
    );
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
