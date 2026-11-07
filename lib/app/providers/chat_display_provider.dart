import 'package:flutter/foundation.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

/// Presentation only: timings are recorded regardless of this preference.
class ChatDisplayProvider extends ChangeNotifier {
  ChatDisplayProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;
  bool _showGenerationSpeed = false;
  bool _hasLoaded = false;
  bool _disposed = false;
  Future<void>? _loadFuture;
  Future<void>? _pendingWrite;

  bool get showGenerationSpeed => _showGenerationSpeed;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() => _hasLoaded
      ? Future<void>.value()
      : _loadFuture ??= _load().whenComplete(() => _loadFuture = null);

  Future<void> _load() async {
    final stored = await _kvStorage.getBool(AppPrefsKeys.showGenerationSpeed);
    if (_disposed) return;
    _showGenerationSpeed = stored ?? false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateShowGenerationSpeed(bool value) {
    // Serialize writes so rapid toggles cannot restore an older preference.
    final pending = _pendingWrite;
    final update = pending == null
        ? _update(value)
        : pending.then((_) => _update(value));
    _pendingWrite = update.catchError((Object _) {});
    return update;
  }

  Future<void> _update(bool value) async {
    await load();
    if (_disposed || value == _showGenerationSpeed) return;
    await _kvStorage.setBool(AppPrefsKeys.showGenerationSpeed, value);
    if (_disposed) return;
    _showGenerationSpeed = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
