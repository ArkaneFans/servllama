import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';

class _Preferences extends KvStorage {
  final pending = Completer<void>();
  int reads = 0;
  Object? written;

  @override
  Future<String?> getString(String key) async {
    reads++;
    await pending.future;
    return 'en';
  }

  @override
  Future<int?> getInt(String key) async {
    reads++;
    await pending.future;
    return 90;
  }

  @override
  Future<void> setString(String key, String value) async => written = value;

  @override
  Future<void> setInt(String key, int value) async => written = value;
}

void main() {
  test('locale edits join restoration and keep the new value', () async {
    final prefs = _Preferences();
    final provider = AppLocaleProvider(kvStorage: prefs);
    addTearDown(provider.dispose);
    final initial = provider.load();
    expect(identical(initial, provider.load()), isTrue);
    final edit = provider.updateLocaleMode(AppLocaleMode.zh);
    prefs.pending.complete();
    await Future.wait([initial, edit]);
    expect(prefs.reads, 1);
    expect(provider.localeMode, AppLocaleMode.zh);
    expect(prefs.written, 'zh');
  });

  test('theme edits join restoration and keep the new value', () async {
    final prefs = _Preferences();
    final provider = AppThemeModeProvider(kvStorage: prefs);
    addTearDown(provider.dispose);
    final initial = provider.load();
    final edit = provider.updateThemeMode(ThemeMode.dark);
    prefs.pending.complete();
    await Future.wait([initial, edit]);
    expect(prefs.reads, 1);
    expect(provider.themeMode, ThemeMode.dark);
    expect(prefs.written, 'dark');
  });

  test('timeout edits join restoration and keep the new value', () async {
    final prefs = _Preferences();
    final provider = ChatTimeoutProvider(kvStorage: prefs);
    addTearDown(provider.dispose);
    final initial = provider.load();
    final edit = provider.updateTimeoutSeconds(240);
    prefs.pending.complete();
    await Future.wait([initial, edit]);
    expect(prefs.reads, 1);
    expect(provider.timeoutSeconds, 240);
    expect(prefs.written, 240);
  });

  test('disposing during restoration suppresses late notifications', () async {
    final prefs = _Preferences();
    final providers = [
      AppLocaleProvider(kvStorage: prefs),
      AppThemeModeProvider(kvStorage: prefs),
      ChatTimeoutProvider(kvStorage: prefs),
    ];
    final loads = [
      (providers[0] as AppLocaleProvider).load(),
      (providers[1] as AppThemeModeProvider).load(),
      (providers[2] as ChatTimeoutProvider).load(),
    ];
    for (final provider in providers) {
      provider.dispose();
    }
    prefs.pending.complete();
    await Future.wait(loads);
  });
}
