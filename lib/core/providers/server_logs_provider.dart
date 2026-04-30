import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';

class ServerLogsProvider extends ChangeNotifier {
  ServerLogsProvider({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance,
      _logs = List<AppLogEntry>.from(
        (logger ?? AppLogger.instance).entriesFor(LogChannel.server),
      ) {
    _subscription = _logger.streamFor(LogChannel.server).listen(_handleEntry);
  }

  final AppLogger _logger;
  final List<AppLogEntry> _logs;
  late final StreamSubscription<AppLogEntry> _subscription;

  List<AppLogEntry> get logs => List<AppLogEntry>.unmodifiable(_logs);
  int get count => _logs.length;
  bool get isEmpty => _logs.isEmpty;
  String get copyText =>
      _logs.map((entry) => entry.formattedMessage).join('\n');

  void clear() {
    _logger.clearChannel(LogChannel.server);
    _logs.clear();
    notifyListeners();
  }

  void _handleEntry(AppLogEntry entry) {
    _logs.add(entry);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
