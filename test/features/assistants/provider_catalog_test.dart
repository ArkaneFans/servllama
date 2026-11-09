import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';

class _EmptyAssets extends UnifiedModelRepository {
  @override
  Future<List<ModelAsset>> listLlmAssets() async => [];
}

class _TrackedAssets extends UnifiedModelRepository {
  int readCount = 0;
  Completer<List<ModelAsset>>? pending;
  List<ModelAsset> current = [];

  @override
  Future<List<ModelAsset>> listLlmAssets() async {
    readCount++;
    return pending == null ? current : await pending!.future;
  }
}

void main() {
  late AppDatabase db;
  late AssistantRepository repository;
  const custom = AiConnection(
    id: 'custom',
    name: 'Custom',
    protocol: AiProtocol.openai,
    baseUrl: 'https://example.com/v1',
    models: ['kept'],
  );
  setUp(() {
    db = AppDatabase.memory();
    repository = AssistantRepository(db);
  });
  tearDown(() => db.close());

  test(
    'initial demand is single flight and an early save waits for it',
    () async {
      final models = _TrackedAssets()..pending = Completer<List<ModelAsset>>();
      final provider = AssistantProvider(
        repository: repository,
        models: models,
      );
      addTearDown(provider.dispose);
      final initial = provider.ensureLoaded();
      expect(identical(initial, provider.ensureLoaded()), isTrue);
      final saving = provider.saveConnection(custom, key: 'fixture-key');
      await Future<void>.delayed(Duration.zero);
      expect(provider.loaded, isFalse);
      expect(
        (await repository.connections()).any((c) => c.id == custom.id),
        isFalse,
      );
      models.pending!.complete([]);
      await Future.wait([initial, saving]);
      expect(models.readCount, 1);
      expect(provider.connection(custom.id)!.models, ['kept']);
      expect(provider.connection(custom.id)!.apiKey, 'fixture-key');
    },
  );

  test(
    'inline credentials survive settings reload and process recreation',
    () async {
      var saved = await repository.saveConnection(custom, key: 'fixture-first');
      final provider = AssistantProvider(
        repository: repository,
        models: _EmptyAssets(),
      );
      await provider.load();
      expect(provider.loaded, isTrue);
      expect(provider.connection(saved.id)!.apiKey, 'fixture-first');
      await provider.saveConnection(saved, key: 'fixture-second');
      saved = provider.connection(custom.id)!;
      expect(saved.apiKey, 'fixture-second');
      provider.dispose();
      final restored = AssistantProvider(
        repository: AssistantRepository(db, preferences: KvStorage()),
        models: _EmptyAssets(),
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.connection(custom.id)!.apiKey, 'fixture-second');
      expect(
        jsonEncode(
          (await repository.connections()).map((c) => c.toJson()).toList(),
        ),
        contains('fixture-second'),
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

  test(
    'presets seed once without network credentials and remain editable but undeletable',
    () async {
      await repository.initializeProviders();
      final initial = await repository.connections();
      expect(initial, hasLength(providerPresets.length));
      expect(initial.map((c) => c.id), providerPresets.map((c) => c.id));
      expect(
        initial.every(
          (c) => !c.enabled && c.models.isEmpty && c.apiKey.isEmpty,
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

      final reopened = AssistantRepository(db);
      await reopened.initializeProviders();
      final loaded = await reopened.connections();
      expect(loaded.map((c) => c.id), expected);
      expect(loaded[1].toJson(), first.toJson());

      await reopened.deleteConnection(newest.id);
      expect((await reopened.connections()).map((c) => c.id), expected.skip(1));
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
    'failed commit preserves the key; omitted input keeps it and explicit empty input clears it',
    () async {
      final original = await repository.saveConnection(
        custom,
        key: 'fixture-old',
      );
      await db.execute(
        "CREATE TRIGGER reject_provider BEFORE INSERT ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.saveConnection(original, key: 'fixture-new'),
        throwsA(anything),
      );
      expect(
        (await repository.connections()).single.toJson(),
        original.toJson(),
      );
      await db.execute('DROP TRIGGER reject_provider');
      final preserved = await repository.saveConnection(
        original.changed({'name': 'Updated'}),
      );
      expect(preserved.apiKey, original.apiKey);
      expect(preserved.credentialRevision, original.credentialRevision);
      final cleared = await repository.saveConnection(preserved, key: '');
      expect(cleared.apiKey, isEmpty);
      expect(cleared.credentialRevision, original.credentialRevision + 1);
      final replaced = await repository.saveConnection(
        cleared,
        key: 'fixture-new',
      );
      expect(replaced.apiKey, 'fixture-new');
      expect(replaced.credentialRevision, cleared.credentialRevision + 1);
    },
  );

  test(
    'rotating away and back still revokes a frozen request and snapshots exclude keys',
    () async {
      const assistant = Assistant(id: 'a', name: 'A');
      final original = await repository.saveConnection(
        custom,
        key: 'fixture-old',
      );
      final run = ChatRunConfig(
        assistant: assistant,
        connection: original,
        key: original.apiKey,
        modelId: 'kept',
        isLocal: false,
      );
      final unchanged = await repository.saveConnection(
        original,
        key: original.apiKey,
      );
      expect(run.authorizedBy(assistant, unchanged), isTrue);
      final rotated = await repository.saveConnection(
        unchanged,
        key: 'fixture-new',
      );
      final restored = await repository.saveConnection(
        rotated,
        key: 'fixture-old',
      );
      expect(run.authorizedBy(assistant, restored), isFalse);
      expect(jsonEncode(run.snapshot()), isNot(contains('fixture-old')));
      expect(run.snapshot()['connection'], isNot(contains('apiKey')));
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
        key: 'fixture-stored-key',
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
      expect(saved.apiKey, 'fixture-stored-key');
    },
  );
}
