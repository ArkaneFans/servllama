import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';

class _Secrets extends SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
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
    'old capability flags become per-model settings and save without stale entries',
    () async {
      final legacy = custom.toJson()..remove('modelCapabilities');
      legacy['supportsImages'] = false;
      legacy['supportsTools'] = true;
      legacy['models'] = ['kept', 'other'];
      final loaded = AiConnection.fromJson(legacy);
      expect(loaded.capabilitiesFor('kept').supportsImages, isFalse);
      expect(loaded.capabilitiesFor('other').supportsImages, isFalse);
      expect(loaded.capabilitiesFor('other').supportsTools, isTrue);
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
      ),
    );
    expect(saved.models, ['model']);
    expect(saved.capabilitiesFor('model').supportsImages, isFalse);
    expect(saved.capabilitiesFor('model').supportsTools, isFalse);
  });

  test(
    'presets seed once without network credentials and remain editable but undeletable',
    () async {
      await repository.initializeProviders();
      final initial = await repository.connections();
      expect(initial, hasLength(8));
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
      final config = jsonEncode({
        'assistantId': 'a',
        'target': const ChatTarget.remote(
          'custom',
          'conversation-only',
        ).toJson(),
      });
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,message_ids,config) VALUES(?,?,0,0,?,?)',
        ['conversation', 'Existing', '[]', config],
      );
      await repository.initializeProviders();
      var loaded = (await repository.connections()).singleWhere(
        (c) => c.id == custom.id,
      );
      expect(loaded.enabled, isTrue);
      expect(loaded.models, ['kept']);
      expect(
        (await db.query(
          'SELECT config FROM conversations',
        )).single.read<String>('config'),
        config,
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
    'failed commit preserves the old credential and clear removes it only after saving',
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
      final cleared = await repository.saveConnection(
        original,
        clearSecret: true,
      );
      expect(cleared.secretRef, isNull);
      expect(secrets.values, isEmpty);
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
          }),
        ),
        isTrue,
      );
    },
  );

  test(
    'discovery respects a cleared credential draft and typed replacement without saving',
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
      expect(await provider.discover(saved, '', clearKey: true), ['candidate']);
      await provider.discover(saved, 'fixture-typed-key', clearKey: true);
      await provider.discover(saved, '');
      expect(headers, [
        null,
        'Bearer fixture-typed-key',
        'Bearer fixture-stored-key',
      ]);
      expect((await repository.connections()).single.toJson(), saved.toJson());
      expect(secrets.values.values.single, 'fixture-stored-key');
    },
  );
}
