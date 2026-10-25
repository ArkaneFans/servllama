import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/core/storage/download_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';

class _BrokenStorage extends Fake implements FlutterSecureStorage {
  bool unavailable = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return unavailable
          ? Future<String?>.error(
              PlatformException(code: 'fixture_unavailable'),
            )
          : Future<String?>.value();
    }
    if (invocation.memberName == #write || invocation.memberName == #delete) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test(
    'provider and download credentials share one store across new readers',
    () async {
      final store = SecretStore();
      await store.write('connection:fixture', 'fixture-provider-key');
      final downloads = DownloadSettingsStore(kvStorage: KvStorage());
      await downloads.saveHuggingFaceToken('fixture-hf-token');
      await downloads.saveModelScopeToken('fixture-ms-token');
      final restored = await DownloadSettingsStore(
        kvStorage: KvStorage(),
      ).load();
      expect(
        await SecretStore().read('connection:fixture'),
        'fixture-provider-key',
      );
      expect(restored.huggingFaceToken, 'fixture-hf-token');
      expect(restored.modelScopeToken, 'fixture-ms-token');
    },
  );

  test(
    'migration removes plaintext only after a verified secure write',
    () async {
      final preferences = KvStorage();
      await preferences.setString(
        DownloadPrefsKeys.huggingFaceToken,
        'fixture-legacy',
      );
      final downloads = DownloadSettingsStore(
        kvStorage: preferences,
        secrets: SecretStore(storage: _BrokenStorage()),
      );
      await expectLater(downloads.load(), throwsStateError);
      expect(
        await preferences.getString(DownloadPrefsKeys.huggingFaceToken),
        'fixture-legacy',
      );
      final restored = await DownloadSettingsStore(
        kvStorage: preferences,
      ).load();
      expect(restored.huggingFaceToken, 'fixture-legacy');
      expect(
        await preferences.getString(DownloadPrefsKeys.huggingFaceToken),
        isNull,
      );
    },
  );

  test(
    'storage errors never masquerade as an empty credential or successful save',
    () async {
      final storage = _BrokenStorage()..unavailable = true;
      final downloads = DownloadSettingsStore(
        secureStorage: storage,
        kvStorage: KvStorage(),
      );
      await expectLater(downloads.load(), throwsA(isA<PlatformException>()));
      await expectLater(
        downloads.saveHuggingFaceToken('fixture-key'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
