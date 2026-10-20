import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';

void main() {
  late AppDatabase db;
  late AssistantRepository repository;
  const one = ChatTarget.remote('p', 'one');
  const two = ChatTarget.remote('p', 'two');
  setUp(() async {
    db = AppDatabase.memory();
    repository = AssistantRepository(db);
    await repository.saveConnection(
      const AiConnection(
        id: 'p',
        name: 'Provider',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        models: ['one', 'two'],
      ),
    );
    await repository.saveAssistantEdit(
      const Assistant(id: 'a', name: 'A', chatTarget: one),
    );
    await repository.saveAssistantEdit(
      const Assistant(id: 'b', name: 'B', chatTarget: two),
    );
  });
  tearDown(() => db.close());

  test(
    'model removal clears only matching selections in the same transaction',
    () async {
      final provider = (await repository.connections()).single;
      await db.execute(
        "CREATE TRIGGER fail_clear BEFORE UPDATE ON assistants BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.saveConnection(
          provider.changed({
            'models': ['two'],
          }),
        ),
        throwsA(anything),
      );
      expect((await repository.connections()).single.models, ['one', 'two']);
      expect((await repository.assistants()).first.chatTarget, one);
      await db.execute('DROP TRIGGER fail_clear');
      await repository.saveConnection(
        provider.changed({
          'models': ['two'],
        }),
      );
      final assistants = await repository.assistants();
      expect(assistants.first.chatTarget, isNull);
      expect(assistants.first.revision, 2);
      expect(assistants.last.chatTarget, two);
      expect(assistants.last.revision, 1);
    },
  );

  test('provider deletion rolls back when selection cleanup fails', () async {
    await db.execute(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    await expectLater(repository.deleteConnection('p'), throwsA(anything));
    expect((await repository.assistants()).map((a) => a.chatTarget), [
      one,
      two,
    ]);
    await db.execute('DROP TRIGGER fail_delete');
    await repository.deleteConnection('p');
    expect(
      (await repository.assistants()).every((a) => a.chatTarget == null),
      isTrue,
    );
    expect(await repository.connections(), isEmpty);
  });

  test(
    'stale editor cannot overwrite a newer selection or resurrect a deleted model',
    () async {
      final stale = (await repository.assistants()).first;
      await repository.setChatTarget('a', two);
      await expectLater(
        repository.saveAssistantEdit(
          stale.changed({'name': 'Edited'}),
          expectedRevision: stale.revision,
        ),
        throwsStateError,
      );
      expect((await repository.assistants()).first.chatTarget, two);
      final selected = (await repository.assistants()).first;
      await repository.deleteConnection('p');
      await expectLater(
        repository.saveAssistantEdit(selected, expectedRevision: selected.revision),
        throwsStateError,
      );
      await expectLater(repository.setChatTarget('a', one), throwsStateError);
      expect((await repository.assistants()).first.chatTarget, isNull);
    },
  );

  test(
    'GGUF deletion clears legacy and current assistant selections, preserving other assistants',
    () async {
      final store = GgufModelStore(db);
      await store.save(
        ModelDescriptor(
          id: 'gguf',
          modelName: 'Fixture',
          sizeBytes: 1,
          storedDirectoryPath: '/fixture',
          storedFilePath: '/fixture/model.gguf',
          importedAt: DateTime(2026),
        ),
      );
      final assetId = (await db.query(
        'SELECT id FROM model_assets',
      )).single.read<String>('id');
      final target = ChatTarget.local(assetId);
      await repository.setChatTarget('a', target);
      final a = (await repository.assistants()).first;
      final old = a.toJson()..remove('chatTarget');
      old['defaultTarget'] = target.toJson();
      await db.execute('UPDATE assistants SET config=? WHERE id=?', [
        jsonEncode(old),
        'a',
      ]);
      expect((await repository.assistants()).first.chatTarget, target);
      await store.remove('gguf');
      final saved = await repository.assistants();
      expect(saved.first.chatTarget, isNull);
      expect(saved.first.revision, a.revision + 1);
      expect(saved.last.chatTarget, two);
      expect(
        Assistant.fromJson({...old, 'chatTarget': null}).chatTarget,
        isNull,
      );
    },
  );
}
