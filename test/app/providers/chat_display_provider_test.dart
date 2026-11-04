import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/chat_display_provider.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedStorage extends KvStorage {
  final read = Completer<bool?>();
  int reads = 0;
  final writes = <bool>[];
  bool fail = false;

  @override
  Future<bool?> getBool(String key) {
    reads++;
    return read.future;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (fail) throw StateError('write failed');
    writes.add(value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'speed display defaults off without changing existing preferences',
    () async {
      final storage = KvStorage();
      final provider = ChatDisplayProvider(kvStorage: storage);
      addTearDown(provider.dispose);
      expect(provider.showGenerationSpeed, isFalse);
      await provider.load();
      expect(provider.showGenerationSpeed, isFalse);
      expect(provider.hasLoaded, isTrue);
      expect(
        await storage.containsKey(AppPrefsKeys.showGenerationSpeed),
        isFalse,
      );
    },
  );

  test('enabled and disabled choices survive a new provider', () async {
    final provider = ChatDisplayProvider(kvStorage: KvStorage());
    addTearDown(provider.dispose);
    await provider.updateShowGenerationSpeed(true);
    final restored = ChatDisplayProvider(kvStorage: KvStorage());
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.showGenerationSpeed, isTrue);
    await restored.updateShowGenerationSpeed(false);
    final disabled = ChatDisplayProvider(kvStorage: KvStorage());
    addTearDown(disabled.dispose);
    await disabled.load();
    expect(disabled.showGenerationSpeed, isFalse);
  });

  test(
    'early edits join restoration and rapid edits persist in order',
    () async {
      final storage = _DelayedStorage();
      final provider = ChatDisplayProvider(kvStorage: storage);
      addTearDown(provider.dispose);
      final load = provider.load();
      expect(identical(load, provider.load()), isTrue);
      final on = provider.updateShowGenerationSpeed(true);
      final off = provider.updateShowGenerationSpeed(false);
      storage.read.complete(false);
      await Future.wait([load, on, off]);
      expect(storage.reads, 1);
      expect(storage.writes, [true, false]);
      expect(provider.showGenerationSpeed, isFalse);
    },
  );

  test(
    'failed writes do not claim persistence and later edits still work',
    () async {
      final storage = _DelayedStorage()..fail = true;
      storage.read.complete(false);
      final provider = ChatDisplayProvider(kvStorage: storage);
      addTearDown(provider.dispose);
      await expectLater(
        provider.updateShowGenerationSpeed(true),
        throwsStateError,
      );
      expect(provider.showGenerationSpeed, isFalse);
      storage.fail = false;
      await provider.updateShowGenerationSpeed(true);
      expect(provider.showGenerationSpeed, isTrue);
    },
  );

  test(
    'dispose during restoration suppresses late notifications and writes',
    () async {
      final storage = _DelayedStorage();
      final provider = ChatDisplayProvider(kvStorage: storage);
      var notifications = 0;
      provider.addListener(() => notifications++);
      final load = provider.load();
      final edit = provider.updateShowGenerationSpeed(true);
      provider.dispose();
      storage.read.complete(false);
      await Future.wait([load, edit]);
      expect(notifications, 0);
      expect(storage.writes, isEmpty);
    },
  );
}
