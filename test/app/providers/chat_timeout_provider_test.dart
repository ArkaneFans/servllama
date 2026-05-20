import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatTimeoutProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to 120 seconds', () async {
      final provider = ChatTimeoutProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.timeoutSeconds, 120);
      expect(provider.timeout, const Duration(seconds: 120));
      expect(provider.hasLoaded, isTrue);
    });

    test('loads stored timeout from local storage', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPrefsKeys.chatTimeoutSeconds: 300,
      });
      final provider = ChatTimeoutProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.timeoutSeconds, 300);
    });

    test('persists updated timeout', () async {
      final storage = KvStorage();
      final provider = ChatTimeoutProvider(kvStorage: storage);

      await provider.updateTimeoutSeconds(240);

      expect(provider.timeoutSeconds, 240);
      expect(await storage.getInt(AppPrefsKeys.chatTimeoutSeconds), 240);
    });

    test('clamps timeout into supported range', () async {
      final storage = KvStorage();
      final provider = ChatTimeoutProvider(kvStorage: storage);

      await provider.updateTimeoutSeconds(10);
      expect(provider.timeoutSeconds, 30);

      await provider.updateTimeoutSeconds(999);
      expect(provider.timeoutSeconds, 600);
    });
  });
}
