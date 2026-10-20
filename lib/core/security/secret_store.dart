import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:servllama/core/security/log_redactor.dart';

/// Credentials never belong in application JSON, exports or Preferences.
class SecretStore {
  SecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static final instance = SecretStore();
  final FlutterSecureStorage _storage;
  Future<String?> read(String key) async {
    final value = await _storage.read(key: key);
    if (value != null) LogRedactor.remember(value);
    return value;
  }

  Future<void> write(String key, String value) async {
    LogRedactor.remember(value);
    await _storage.write(key: key, value: value);
    if (await _storage.read(key: key) != value) {
      throw StateError('Credential storage verification failed');
    }
  }

  Future<void> delete(String key) => _storage.delete(key: key);
}
