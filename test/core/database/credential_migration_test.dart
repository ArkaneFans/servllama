import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/credential_migration.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/core/storage/download_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';

class _LegacyStorage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  int reads = 0, cleanups = 0;
  bool failRead = false, failCleanup = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #readAll) {
      reads++;
      return failRead
          ? Future<Map<String, String>>.error(StateError('fixture read failed'))
          : Future<Map<String, String>>.value(Map.of(values));
    }
    if (invocation.memberName == #deleteAll) {
      cleanups++;
      if (failCleanup) {
        return Future<void>.error(StateError('fixture cleanup failed'));
      }
      values.clear();
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FailingPreferences extends KvStorage {
  @override
  Future<void> setString(String key, String value) async {
    throw StateError('fixture preference write failed');
  }
}

void main() {
  late AppDatabase db;
  late _LegacyStorage legacy;
  late KvStorage preferences;
  setUp(() {
    db = AppDatabase.memory();
    legacy = _LegacyStorage();
    preferences = KvStorage();
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    final connection =
        const AiConnection(
            id: 'provider',
            name: 'Provider',
            protocol: AiProtocol.openai,
            baseUrl: 'https://example.invalid/v1',
            models: ['model'],
          ).toJson()
          ..remove('apiKey')
          ..remove('credentialRevision')
          ..['secretRef'] = 'connection:provider:legacy';
    await db.execute(
      'INSERT INTO ai_connections(id,name,revision,config) VALUES(?,?,?,?)',
      ['provider', 'Provider', 1, jsonEncode(connection)],
    );
    await db.execute(
      'INSERT INTO mcp_servers(id,name,revision,config) VALUES(?,?,?,?)',
      [
        'mcp',
        'MCP',
        3,
        jsonEncode({
          'id': 'mcp',
          'name': 'MCP',
          'url': 'https://example.invalid/mcp',
          'revision': 3,
          'secretRef': 'mcp:legacy',
        }),
      ],
    );
    legacy.values.addAll({
      'connection:provider:legacy': 'fixture-provider-key',
      'mcp:legacy':
          'servllama-mcp-headers:v1:${jsonEncode({'Authorization': 'Bearer fixture-mcp-key', 'X-Key': 'fixture-header'})}',
      ServerPrefsKeys.apiKey: 'fixture-server-key',
      'servllama.download.hf_token': 'fixture-hf-token',
      'servllama.download.ms_token': 'fixture-ms-token',
    });
  }

  CredentialMigration migration({KvStorage? prefs}) => CredentialMigration(
    db,
    legacyStorage: legacy,
    preferences: prefs ?? preferences,
  );

  test(
    'all legacy credentials migrate with their settings and run only once',
    () async {
      await seed();
      await migration().run();
      final provider = (await AssistantRepository(db).connections()).single;
      expect(provider.apiKey, 'fixture-provider-key');
      expect(provider.credentialRevision, 1);
      expect(provider.models, ['model']);
      final server = (await AgentRepository(db).servers()).single;
      expect(server.headers, {
        'Authorization': 'Bearer fixture-mcp-key',
        'X-Key': 'fixture-header',
      });
      expect(server.revision, 3);
      expect(
        await preferences.getString(ServerPrefsKeys.apiKey),
        'fixture-server-key',
      );
      final downloads = await DownloadSettingsStore(
        kvStorage: preferences,
      ).load();
      expect(downloads.huggingFaceToken, 'fixture-hf-token');
      expect(downloads.modelScopeToken, 'fixture-ms-token');
      expect(legacy.values, isEmpty);
      expect(await db.metadata(CredentialMigration.marker), '1');
      legacy.failRead = true;
      await migration().run();
      expect(legacy.reads, 1);
      expect(legacy.cleanups, 1);
      expect(
        LogRedactor.redact('fixture-provider-key fixture-header'),
        '[REDACTED] [REDACTED]',
      );
    },
  );

  test(
    'missing or unreadable referenced credentials do not become empty settings',
    () async {
      await seed();
      legacy.failRead = true;
      await expectLater(migration().run(), throwsStateError);
      expect(await db.metadata(CredentialMigration.marker), isNull);
      expect(legacy.cleanups, 0);
      legacy.failRead = false;
      legacy.values.remove('connection:provider:legacy');
      await expectLater(migration().run(), throwsStateError);
      expect(
        (await db.query(
          'SELECT config FROM ai_connections',
        )).single.read<String>('config'),
        contains('secretRef'),
      );
      expect(await preferences.getString(ServerPrefsKeys.apiKey), isNull);
      expect(await db.metadata(CredentialMigration.marker), isNull);
      expect(legacy.cleanups, 0);
      legacy.values['connection:provider:legacy'] = 'recovered-key';
      await migration().run();
      expect(
        (await AssistantRepository(db).connections()).single.apiKey,
        'recovered-key',
      );
    },
  );

  test(
    'preference write failure keeps legacy values and is retryable',
    () async {
      await seed();
      await expectLater(
        migration(prefs: _FailingPreferences()).run(),
        throwsStateError,
      );
      expect(await db.metadata(CredentialMigration.marker), isNull);
      expect(legacy.cleanups, 0);
      await migration().run();
      expect(await db.metadata(CredentialMigration.marker), '1');
    },
  );

  test(
    'SQL failure rolls back both configuration rows and retains legacy storage',
    () async {
      await seed();
      await db.execute(
        "CREATE TRIGGER reject_mcp BEFORE UPDATE ON mcp_servers BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(migration().run(), throwsA(anything));
      expect(
        (await db.query(
          'SELECT config FROM ai_connections',
        )).single.read<String>('config'),
        contains('secretRef'),
      );
      expect(await db.metadata(CredentialMigration.marker), isNull);
      expect(legacy.cleanups, 0);
      await db.execute('DROP TRIGGER reject_mcp');
      await migration().run();
      expect(
        (await AssistantRepository(db).connections()).single.apiKey,
        'fixture-provider-key',
      );
    },
  );

  test(
    'cleanup retry preserves already migrated settings and intentional empty values',
    () async {
      await seed();
      legacy.failCleanup = true;
      await expectLater(migration().run(), throwsStateError);
      expect(await db.metadata(CredentialMigration.marker), isNull);
      final repository = AssistantRepository(db);
      await repository.saveConnection(
        (await repository.connections()).single,
        key: '',
      );
      await preferences.setString(DownloadPrefsKeys.huggingFaceToken, '');
      legacy.failCleanup = false;
      await migration().run();
      expect((await repository.connections()).single.apiKey, isEmpty);
      expect(
        await preferences.getString(DownloadPrefsKeys.huggingFaceToken),
        '',
      );
      expect(legacy.values, isEmpty);
    },
  );

  test(
    'production reader migrates the existing encrypted-preferences namespace',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        ServerPrefsKeys.apiKey: 'namespace-key',
      });
      await CredentialMigration(db, preferences: preferences).run();
      expect(
        await preferences.getString(ServerPrefsKeys.apiKey),
        'namespace-key',
      );
      expect(
        await const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ).readAll(),
        isEmpty,
      );
    },
  );

  test(
    'download tokens save, reload, clear and stay redacted without secure storage',
    () async {
      final store = DownloadSettingsStore(kvStorage: preferences);
      await store.saveHuggingFaceToken('fixture-direct-hf');
      await store.saveModelScopeToken('fixture-direct-ms');
      final restored = await DownloadSettingsStore(
        kvStorage: KvStorage(),
      ).load();
      expect(restored.huggingFaceToken, 'fixture-direct-hf');
      expect(restored.modelScopeToken, 'fixture-direct-ms');
      expect(
        LogRedactor.redact('fixture-direct-hf fixture-direct-ms'),
        '[REDACTED] [REDACTED]',
      );
      await store.saveHuggingFaceToken('');
      expect((await store.load()).huggingFaceToken, isEmpty);
    },
  );
}
