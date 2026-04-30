import 'package:shared_preferences/shared_preferences.dart';

class KvStorage {
  KvStorage();

  KvStorage._shared();

  static final KvStorage instance = KvStorage._shared();

  Future<SharedPreferences>? _prefsFuture;

  Future<String?> getString(String key) async {
    final prefs = await _prefs();
    return prefs.getString(key);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _prefs();
    return prefs.getInt(key);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs();
    return prefs.getBool(key);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await _prefs();
    return prefs.getDouble(key);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await _prefs();
    final value = prefs.getStringList(key);
    if (value == null) {
      return null;
    }
    return List<String>.from(value);
  }

  Future<void> setString(String key, String value) =>
      _write(key, (prefs) => prefs.setString(key, value));

  Future<void> setInt(String key, int value) =>
      _write(key, (prefs) => prefs.setInt(key, value));

  Future<void> setBool(String key, bool value) =>
      _write(key, (prefs) => prefs.setBool(key, value));

  Future<void> setDouble(String key, double value) =>
      _write(key, (prefs) => prefs.setDouble(key, value));

  Future<void> setStringList(String key, List<String> value) => _write(
    key,
    (prefs) => prefs.setStringList(key, List<String>.from(value)),
  );

  Future<bool> containsKey(String key) async {
    final prefs = await _prefs();
    return prefs.containsKey(key);
  }

  Future<void> remove(String key) =>
      _write(key, (prefs) => prefs.remove(key), actionDescription: 'remove');

  Future<void> clear() =>
      _write(null, (prefs) => prefs.clear(), actionDescription: 'clear');

  Future<SharedPreferences> _prefs() =>
      _prefsFuture ??= SharedPreferences.getInstance();

  Future<void> _write(
    String? key,
    Future<bool> Function(SharedPreferences prefs) action, {
    String actionDescription = 'write',
  }) async {
    final prefs = await _prefs();
    final success = await action(prefs);
    if (!success) {
      final detail = key == null ? 'store' : 'key "$key"';
      throw StateError('Failed to $actionDescription $detail.');
    }
  }
}
