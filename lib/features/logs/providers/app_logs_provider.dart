import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';

class AppLogsProvider extends ChangeNotifier {
  AppLogsProvider({
    AppLogger? logger,
    Iterable<LogChannel>? channels,
    this.maxEntries = AppLogger.defaultMaxEntries,
    this.notifyThrottle = const Duration(milliseconds: 100),
  }) : _logger = logger ?? AppLogger.instance,
       _channels = List<LogChannel>.unmodifiable(channels ?? LogChannel.values),
       _logs = <AppLogEntry>[] {
    for (final channel in _channels) {
      _logs.addAll(_logger.entriesFor(channel));
      _subscriptions.add(_logger.streamFor(channel).listen(_handleEntry));
    }
    _logs.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    _trim();
  }

  final AppLogger _logger;
  final List<LogChannel> _channels;
  final int maxEntries;

  /// Server output can burst hundreds of lines per second while a model
  /// loads; notifications are coalesced so listeners rebuild at most once
  /// per window instead of once per line.
  final Duration notifyThrottle;

  final List<AppLogEntry> _logs;
  final List<StreamSubscription<AppLogEntry>> _subscriptions =
      <StreamSubscription<AppLogEntry>>[];
  Timer? _pendingNotify;

  List<AppLogEntry> get logs => List<AppLogEntry>.unmodifiable(_logs);
  int get count => _logs.length;
  bool get isEmpty => _logs.isEmpty;
  String get copyText => _logs.map(formatEntry).join('\n');

  List<AppLogEntry> query({
    LogChannel? channel,
    LogLevel? minimumLevel,
    String text = '',
  }) {
    final keyword = text.trim().toLowerCase();
    return _logs
        .where((entry) {
          if (channel != null && entry.channel != channel) return false;
          if (minimumLevel != null && entry.level.index < minimumLevel.index) {
            return false;
          }
          return keyword.isEmpty ||
              formatEntry(entry).toLowerCase().contains(keyword);
        })
        .toList(growable: false);
  }

  String formatEntry(AppLogEntry entry) {
    final time = entry.timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
        '${three(time.millisecond)} '
        '[${entry.level.name.toUpperCase()}] '
        '[${entry.channel.name}] ${entry.formattedMessage}';
  }

  Future<void> clear() {
    for (final channel in _channels) {
      _logger.clearChannel(channel);
    }
    _logs.clear();
    _pendingNotify?.cancel();
    _pendingNotify = null;
    notifyListeners();
    return _logger.clearPersisted().catchError((Object error) {
      _logger.event(
        'logging.clear_failed',
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
      throw error;
    });
  }

  void _handleEntry(AppLogEntry entry) {
    _logs.add(entry);
    _trim();
    _pendingNotify ??= Timer(notifyThrottle, () {
      _pendingNotify = null;
      notifyListeners();
    });
  }

  void _trim() {
    if (_logs.length > maxEntries) {
      _logs.removeRange(0, _logs.length - maxEntries);
    }
  }

  @override
  void dispose() {
    _pendingNotify?.cancel();
    _pendingNotify = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
