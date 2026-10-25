import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';

class _Secrets extends SecretStore {
  final values = <String, String>{};
  int reads = 0;
  bool failReads = false;
  @override
  Future<String?> read(String key) async {
    reads++;
    if (failReads) throw StateError('fixture secure storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _EmptyAssets extends UnifiedModelRepository {
  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async => [];
}

class _TrackedAssets extends UnifiedModelRepository {
  final modes = <bool>[];
  Completer<List<ModelAsset>>? pending;
  List<ModelAsset> current = [];

  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async {
    modes.add(reconcile);
    return pending == null ? current : await pending!.future;
  }
}

void main() {
  late AppDatabase db;
  late AssistantRepository repository;
  late _Secrets secrets;
  const custom = AiConnection(
    id: 'custom',
    name: 'Custom',
    protocol: AiProtocol.openai,
    baseUrl: 'https://example.com/v1',
    models: ['kept'],
  );
  setUp(() {
    db = AppDatabase.memory();
    secrets = _Secrets();
    repository = AssistantRepository(db, secrets: secrets);
  });
  tearDown(() => db.close());

  test(
    'light startup restores credentials and targets from the database snapshot',
    () async {
      final saved = await repository.saveConnection(
        custom,
        newSecret: 'fixture-key',
      );
      await repository.saveAssistant(
        const Assistant(
          id: 'a',
          name: 'A',
          chatTarget: ChatTarget.remote('custom', 'kept'),
        ),
      );
      final models = _TrackedAssets();
      final provider = AssistantProvider(
        repository: repository,
        models: models,
      );
      addTearDown(provider.dispose);
      await provider.load(reconcileAssets: false);
      expect(models.modes, [false]);
      expect(provider.cachedCredential(saved), 'fixture-key');
      expect(provider.active!.chatTarget!.modelId, 'kept');
      expect(provider.resolveTarget(provider.active!.chatTarget), isNotNull);
      models.pending = Completer<List<ModelAsset>>();
      final refresh = provider.ensureAssetsReconciled();
      expect(identical(refresh, provider.ensureAssetsReconciled()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(models.modes, [false, true]);
      models.pending!.complete([]);
      await refresh;
      await provider.ensureAssetsReconciled();
      expect(models.modes, [false, true]);
      expect(provider.active!.chatTarget!.modelId, 'kept');
      expect(provider.cachedCredential(saved), 'fixture-key');
    },
  );

  test(
    'explicit asset refresh reads after an older in-flight prefetch',
    () async {
      final models = _TrackedAssets();
      final provider = AssistantProvider(
        repository: repository,
        models: models,
      );
      addTearDown(provider.dispose);
      await provider.load(reconcileAssets: false);
      final pending = Completer<List<ModelAsset>>();
      models.pending = pending;
      final warmup = provider.ensureAssetsReconciled();
      await Future<void>.delayed(Duration.zero);
      final explicit = provider.refreshAssets();
      const fresh = ModelAsset(
        id: 'fresh',
        kind: AssetKind.llm,
        engine: 'mnn',
        runtimeId: 'model',
        storageOwner: 'mnn',
        path: '',
        name: 'Fresh',
        revision: '1',
      );
      models.pending = null;
      models.current = [fresh];
      pending.complete([]);
      await Future.wait([warmup, explicit]);
      expect(models.modes, [false, true, true]);
      expect(provider.assets.single.id, 'fresh');
    },
  );

  test(
    'credential failure preserves settings and stays retryable instead of caching an empty key',
    () async {
      final saved = await repository.saveConnection(
        custom,
        newSecret: 'fixture-key',
      );
      secrets.failReads = true;
      final provider = AssistantProvider(
        repository: repository,
        models: _EmptyAssets(),
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.loaded, isTrue);
      expect(provider.connection(custom.id)!.secretRef, saved.secretRef);
      expect(provider.cachedCredential(saved), isNull);
      await expectLater(provider.credential(saved), throwsStateError);
      secrets.failReads = false;
      expect(await provider.credential(saved), 'fixture-key');
      expect(provider.cachedCredential(saved), 'fixture-key');
    },
  );

  test(
    'settings restore hydrates credentials before publishing and refreshes rotated keys',
    () async {
      var saved = await repository.saveConnection(
        custom,
        newSecret: 'fixture-first',
      );
      final provider = AssistantProvider(
        repository: repository,
        models: _EmptyAssets(),
      );
      await provider.load();
      expect(provider.loaded, isTrue);
      expect(provider.cachedCredential(saved), 'fixture-first');
      final reads = secrets.reads;
      expect(await provider.credential(saved), 'fixture-first');
      expect(secrets.reads, reads);
      await provider.saveConnection(saved, key: 'fixture-second');
      saved = provider.connection(custom.id)!;
      expect(provider.cachedCredential(saved), 'fixture-second');
      provider.dispose();
      final restored = AssistantProvider(
        repository: AssistantRepository(
          db,
          secrets: secrets,
          preferences: KvStorage(),
        ),
        models: _EmptyAssets(),
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(
        restored.cachedCredential(restored.connection(custom.id)!),
        'fixture-second',
      );
      expect(
        jsonEncode(
          (await repository.connections()).map((c) => c.toJson()).toList(),
        ),
        isNot(contains('fixture-second')),
      );
    },
  );

  test(
    'old capability flags become per-model settings and save without stale entries',
    () async {
      final legacy = custom.toJson()..remove('modelCapabilities');
      legacy['supportsImages'] = false;
      legacy['supportsTools'] = true;
      legacy['models'] = ['kept', 'other'];
      legacy['modelNames'] = {'kept': 'Primary', 'other': 'Other'};
      final loaded = AiConnection.fromJson(legacy);
      expect(loaded.capabilitiesFor('kept').supportsImages, isFalse);
      expect(loaded.capabilitiesFor('other').supportsImages, isFalse);
      expect(loaded.capabilitiesFor('other').supportsTools, isTrue);
      expect(loaded.nameFor('kept'), 'Primary');
      final edited = loaded.changed({
        'modelCapabilities': {
          'kept': const ModelCapabilities(
            supportsImages: true,
            supportsTools: false,
          ).toJson(),
          'other': loaded.capabilitiesFor('other').toJson(),
        },
      });
      final saved = await repository.saveConnection(edited);
      expect(saved.capabilitiesFor('kept').supportsTools, isFalse);
      expect(saved.capabilitiesFor('other').supportsTools, isTrue);
      final persisted =
          jsonDecode(
                (await db.query(
                  'SELECT config FROM ai_connections',
                )).single.read<String>('config'),
              )
              as Map;
      expect(persisted.containsKey('supportsTools'), isFalse);
      expect(persisted.containsKey('supportsImages'), isFalse);
      final removed = await repository.saveConnection(
        saved.changed({
          'models': ['other'],
        }),
      );
      expect(removed.modelCapabilities.keys, ['other']);
      expect(removed.modelNames.keys, ['other']);
      expect(
        (await repository.connections()).single.toJson(),
        removed.toJson(),
      );
    },
  );

  test('capability revocation affects only runs using that model', () {
    final c = custom.changed({
      'models': ['kept', 'other'],
    });
    const a = Assistant(id: 'a', name: 'A');
    ChatRunConfig run(String model) => ChatRunConfig(
      assistant: a,
      connection: c,
      key: '',
      modelId: model,
      isLocal: false,
    );
    for (final capability in ['supportsImages', 'supportsTools']) {
      final changed = c.changed({
        'modelCapabilities': {
          'kept': {...c.capabilitiesFor('kept').toJson(), capability: false},
          'other': c.capabilitiesFor('other').toJson(),
        },
      });
      expect(run('kept').authorizedBy(a, changed), isFalse);
      expect(run('other').authorizedBy(a, changed), isTrue);
      expect(run('kept').capabilities.toJson()[capability], isTrue);
    }
  });

  test('normalizing a model ID preserves its capability settings', () async {
    final saved = await repository.saveConnection(
      AiConnection(
        id: 'trim',
        name: 'Trim',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        models: [' model '],
        modelCapabilities: {
          ' model ': const ModelCapabilities(
            supportsImages: false,
            supportsTools: false,
          ),
        },
        modelNames: {' model ': ' Friendly model '},
      ),
    );
    expect(saved.models, ['model']);
    expect(saved.nameFor('model'), 'Friendly model');
    expect(saved.capabilitiesFor('model').supportsImages, isFalse);
    expect(saved.capabilitiesFor('model').supportsTools, isFalse);
  });

  test(
    'presets seed once without network credentials and remain editable but undeletable',
    () async {
      await repository.initializeProviders();
      final initial = await repository.connections();
      expect(initial, hasLength(providerPresets.length));
      expect(initial.map((c) => c.id), providerPresets.map((c) => c.id));
      expect(
        initial.every(
          (c) => !c.enabled && c.models.isEmpty && c.secretRef == null,
        ),
        isTrue,
      );
      for (final c in initial) {
        await expectLater(repository.deleteConnection(c.id), throwsStateError);
      }
      final changed = await repository.saveConnection(
        initial.first.changed({
          'enabled': true,
          'models': ['private-model'],
          'name': 'My endpoint',
          'baseUrl': 'https://proxy.example/v1',
        }),
      );
      await repository.initializeProviders();
      final restored = (await repository.connections()).singleWhere(
        (c) => c.id == changed.id,
      );
      expect(restored.toJson(), changed.toJson());
      expect(
        (await repository.connections()).map((c) => c.id),
        initial.map((c) => c.id),
      );
      expect(secrets.values, isEmpty);
      await repository.saveConnection(custom);
      await repository.deleteConnection(custom.id);
      expect(
        (await repository.connections()).map((c) => c.id),
        isNot(contains(custom.id)),
      );
    },
  );

  test(
    'new providers prepend while renaming, toggling and reloading preserve positions',
    () async {
      await repository.initializeProviders();
      var first = await repository.saveConnection(
        custom.changed({'id': 'first', 'name': 'Alpha provider'}),
      );
      final newest = await repository.saveConnection(
        custom.changed({'id': 'newest', 'name': 'Zulu provider'}),
      );
      final expected = [
        newest.id,
        first.id,
        ...providerPresets.map((c) => c.id),
      ];
      expect((await repository.connections()).map((c) => c.id), expected);

      first = await repository.saveConnection(
        first.changed({
          'name': 'ZZZ renamed provider',
          'enabled': false,
          'sortOrder': -999,
          'models': ['updated'],
        }),
      );
      expect((await repository.connections()).map((c) => c.id), expected);
      first = await repository.saveConnection(first.changed({'enabled': true}));

      final reopened = AssistantRepository(db, secrets: secrets);
      await reopened.initializeProviders();
      final loaded = await reopened.connections();
      expect(loaded.map((c) => c.id), expected);
      expect(loaded[1].toJson(), first.toJson());

      await reopened.deleteConnection(newest.id);
      expect((await reopened.connections()).map((c) => c.id), expected.skip(1));
    },
  );

  test(
    'missing presets append without reordering existing providers',
    () async {
      await repository.initializeProviders();
      final missing = providerPresets.first;
      await db.execute('DELETE FROM ai_connections WHERE id=?', [missing.id]);
      final added = await repository.saveConnection(custom);
      final existing = await repository.connections();
      await repository.initializeProviders();
      final result = await repository.connections();
      expect(result.map((c) => c.id), [
        ...existing.map((c) => c.id),
        missing.id,
      ]);
      expect(result.first.toJson(), added.toJson());
      expect(
        result.take(existing.length).map((c) => c.toJson()),
        existing.map((c) => c.toJson()),
      );
    },
  );

  test(
    'concurrent additions retain distinct positions ahead of presets',
    () async {
      await repository.initializeProviders();
      final added = await Future.wait([
        repository.saveConnection(
          custom.changed({'id': 'one', 'name': 'Alpha'}),
        ),
        repository.saveConnection(
          custom.changed({'id': 'two', 'name': 'Zulu'}),
        ),
      ]);
      final result = await repository.connections();
      expect(result.take(2).map((c) => c.id), unorderedEquals(['one', 'two']));
      expect(added.map((c) => c.sortOrder).toSet(), hasLength(2));
      expect(result.skip(2).map((c) => c.id), providerPresets.map((c) => c.id));
    },
  );

  test(
    'preset initialization never infers saved model permissions from historical targets',
    () async {
      final old = custom.toJson();
      await db.execute(
        'INSERT INTO ai_connections(id,name,revision,config) VALUES(?,?,1,?)',
        [custom.id, custom.name, jsonEncode(old)],
      );
      await repository.saveAssistant(
        const Assistant(
          id: 'a',
          name: 'A',
          chatTarget: ChatTarget.remote('custom', 'assistant-only'),
        ),
      );
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,assistant_id) VALUES(?,?,0,0,?)',
        ['conversation', 'Existing', 'a'],
      );
      await repository.initializeProviders();
      var loaded = (await repository.connections()).singleWhere(
        (c) => c.id == custom.id,
      );
      expect(loaded.enabled, isTrue);
      expect(loaded.models, ['kept']);
      expect(
        (await db.query(
          'SELECT assistant_id FROM conversations',
        )).single.read<String>('assistant_id'),
        'a',
      );
      loaded = await repository.saveConnection(
        loaded.changed({'models': [], 'enabled': false}),
      );
      await repository.initializeProviders();
      expect(
        (await repository.connections())
            .singleWhere((c) => c.id == custom.id)
            .toJson(),
        loaded.toJson(),
      );
    },
  );

  test('preset initialization rolls back on failure', () async {
    await repository.saveConnection(custom);
    await repository.saveAssistant(
      const Assistant(
        id: 'a',
        name: 'A',
        chatTarget: ChatTarget.remote('custom', 'missing'),
      ),
    );
    await db.execute(
      "CREATE TRIGGER reject_catalog BEFORE INSERT ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    await expectLater(repository.initializeProviders(), throwsA(anything));
    expect((await repository.connections()).single.models, ['kept']);
    await db.execute('DROP TRIGGER reject_catalog');
    await repository.initializeProviders();
    expect(
      (await repository.connections()),
      hasLength(providerPresets.length + 1),
    );
  });

  test('model lists normalize IDs and reject invalid entries', () async {
    final saved = await repository.saveConnection(
      custom.changed({
        'models': [' model/a ', 'model/a', 'model:b'],
      }),
    );
    expect(saved.models, ['model/a', 'model:b']);
    await expectLater(
      repository.saveConnection(
        saved.changed({
          'models': [' '],
        }),
      ),
      throwsFormatException,
    );
    expect((await repository.connections()).single.toJson(), saved.toJson());
  });

  test(
    'stale concurrent settings cannot restore old models or rotate a key',
    () async {
      final original = await repository.saveConnection(
        custom,
        newSecret: 'fixture-old',
      );
      final updated = await repository.saveConnection(
        original.changed({
          'models': ['new'],
          'enabled': false,
        }),
      );
      final before = Map.of(secrets.values);
      await expectLater(
        repository.saveConnection(
          original.changed({'name': 'Stale'}),
          newSecret: 'fixture-new',
        ),
        throwsStateError,
      );
      expect(
        (await repository.connections()).single.toJson(),
        updated.toJson(),
      );
      expect(secrets.values, before);
      final outcomes = await Future.wait([
        repository
            .saveConnection(updated.changed({'name': 'First'}))
            .then((_) => true, onError: (_) => false),
        repository
            .saveConnection(updated.changed({'name': 'Second'}))
            .then((_) => true, onError: (_) => false),
      ]);
      expect(outcomes.where((succeeded) => succeeded), hasLength(1));
    },
  );

  test(
    'failed commit preserves the old credential and empty input keeps it',
    () async {
      final original = await repository.saveConnection(
        custom,
        newSecret: 'fixture-old',
      );
      final before = Map.of(secrets.values);
      await db.execute(
        "CREATE TRIGGER reject_provider BEFORE INSERT ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.saveConnection(original, newSecret: 'fixture-new'),
        throwsA(anything),
      );
      expect(secrets.values, before);
      expect(
        (await repository.connections()).single.toJson(),
        original.toJson(),
      );
      await db.execute('DROP TRIGGER reject_provider');
      final preserved = await repository.saveConnection(
        original.changed({'name': 'Updated'}),
        newSecret: '',
      );
      expect(preserved.secretRef, original.secretRef);
      expect(secrets.values.values.single, 'fixture-old');

      final replaced = await repository.saveConnection(
        preserved,
        newSecret: 'fixture-new',
      );
      expect(replaced.secretRef, isNot(preserved.secretRef));
      expect(secrets.values.values.single, 'fixture-new');
    },
  );

  test(
    'disabled or removed models revoke runs; unrelated list edits do not',
    () {
      const assistant = Assistant(id: 'a', name: 'A');
      const config = ChatRunConfig(
        assistant: assistant,
        connection: custom,
        key: '',
        modelId: 'kept',
        isLocal: false,
      );
      expect(config.authorizedBy(assistant, custom), isTrue);
      expect(config.snapshot()['connection'], isNot(contains('sortOrder')));
      expect(config.snapshot()['connection'], isNot(contains('modelNames')));
      expect(
        config.authorizedBy(assistant, custom.changed({'enabled': false})),
        isFalse,
      );
      expect(
        config.authorizedBy(
          assistant,
          custom.changed({
            'models': ['other'],
          }),
        ),
        isFalse,
      );
      expect(
        config.authorizedBy(
          assistant,
          custom.changed({
            'models': ['kept', 'other'],
            'name': 'Renamed',
            'sortOrder': 99,
          }),
        ),
        isTrue,
      );
    },
  );

  test(
    'discovery uses the stored credential and honors a typed replacement',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final headers = <String?>[];
      server.listen((request) async {
        headers.add(request.headers.value('authorization'));
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"data":[{"id":"candidate"}]}');
        await request.response.close();
      });
      final saved = await repository.saveConnection(
        custom.changed({'baseUrl': 'http://127.0.0.1:${server.port}/v1'}),
        newSecret: 'fixture-stored-key',
      );
      final provider = AssistantProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.discover(saved, '');
      await provider.discover(saved, 'fixture-typed-key');
      expect(headers, [
        'Bearer fixture-stored-key',
        'Bearer fixture-typed-key',
      ]);
      expect((await repository.connections()).single.toJson(), saved.toJson());
      expect(secrets.values.values.single, 'fixture-stored-key');
    },
  );
}
