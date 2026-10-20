import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('transaction rollback does not publish a migration marker', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await expectLater(
      db.transaction(() async {
        await db.setMetadata('legacyImportComplete', '1');
        throw StateError('power loss');
      }),
      throwsStateError,
    );
    expect(await db.metadata('legacyImportComplete'), isNull);
  });
  test(
    'secret copy is verified before legacy plaintext is removed; rerun is safe',
    () async {
      final db = AppDatabase.memory();
      final dir = await Directory.systemTemp.createTemp('v2-import');
      addTearDown(() async {
        await Hive.close();
        await db.close();
        await dir.delete(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        ServerPrefsKeys.apiKey: 'migration-secret',
      });
      final importer = LegacyImporter(db, dir);
      await importer.run();
      await importer.run();
      expect(await db.metadata('legacyImportComplete'), '1');
      expect(
        await SecretStore.instance.read(ServerPrefsKeys.apiKey),
        'migration-secret',
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          ServerPrefsKeys.apiKey,
        ),
        isNull,
      );
    },
  );
  test('lease ownership cannot be released by a stale completion', () {
    final r = ResourceCoordinator();
    final first = r.tryAcquire(
      kind: LocalResourceKind.asr,
      assetId: 'a',
      owner: 'job',
    )!;
    expect(
      r.tryAcquire(kind: LocalResourceKind.tts, assetId: 'b', owner: 'next'),
      isNull,
    );
    r.release(first);
    final second = r.tryAcquire(
      kind: LocalResourceKind.tts,
      assetId: 'c',
      owner: 'server',
    )!;
    expect(r.release(first), isFalse);
    expect(r.leaseFor(LocalResourceDomain.speech), second);
    r.dispose();
  });
  test('credentials are redacted in command, header and unlabelled error', () {
    LogRedactor.remember('sk-super-secret');
    final result = LogRedactor.redact(
      '--api-key sk-super-secret Authorization: Bearer other-token error sk-super-secret',
    );
    expect(result, isNot(contains('sk-super-secret')));
    expect(result, isNot(contains('other-token')));
  });
}
