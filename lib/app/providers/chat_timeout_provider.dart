import 'package:flutter/foundation.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

class ChatTimeoutProvider extends ChangeNotifier {
  ChatTimeoutProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  static const int defaultTimeoutSeconds = 120;
  static const int minTimeoutSeconds = 30;
  static const int maxTimeoutSeconds = 600;

  final KvStorage _kvStorage;

  int _timeoutSeconds = defaultTimeoutSeconds;
  bool _hasLoaded = false;

  int get timeoutSeconds => _timeoutSeconds;
  bool get hasLoaded => _hasLoaded;
  Duration get timeout => Duration(seconds: _timeoutSeconds);

  Future<void> load() async {
    if (_hasLoaded) {
      return;
    }

    final storedValue = await _kvStorage.getInt(AppPrefsKeys.chatTimeoutSeconds);
    _timeoutSeconds = _normalizeTimeoutSeconds(storedValue);
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateTimeoutSeconds(int value) async {
    final nextValue = _normalizeTimeoutSeconds(value);
    if (_timeoutSeconds == nextValue) {
      return;
    }

    _timeoutSeconds = nextValue;
    await _kvStorage.setInt(AppPrefsKeys.chatTimeoutSeconds, _timeoutSeconds);
    notifyListeners();
  }

  static int _normalizeTimeoutSeconds(int? value) {
    final normalized = value ?? defaultTimeoutSeconds;
    if (normalized < minTimeoutSeconds) {
      return minTimeoutSeconds;
    }
    if (normalized > maxTimeoutSeconds) {
      return maxTimeoutSeconds;
    }
    return normalized;
  }
}
