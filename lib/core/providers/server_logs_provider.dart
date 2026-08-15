import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';

class ServerLogsProvider extends ChangeNotifier {
  ServerLogsProvider({
    AppLogger? logger,
    Iterable<LogChannel>? channels,
    this.maxEntries = 1000,
    this.notifyThrottle = const Duration(milliseconds: 100),
  }) : _logger = logger ?? AppLogger.instance,
       _channels = List<LogChannel>.unmodifiable(
         channels ??
             const <LogChannel>[
               LogChannel.engine,
               LogChannel.server,
               LogChannel.model,
               LogChannel.download,
             ],
       ),
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

  String formatEntry(AppLogEntry entry) {
    final time = entry.timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
        '${three(time.millisecond)} '
        '[${entry.level.name.toUpperCase()}] '
        '[${entry.channel.name}] ${entry.formattedMessage}';
  }

  void clear() {
    for (final channel in _channels) {
      _logger.clearChannel(channel);
    }
    unawaited(_logger.clearPersisted());
    _logs.clear();
    _pendingNotify?.cancel();
    _pendingNotify = null;
    notifyListeners();
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
