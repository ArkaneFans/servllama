import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/repositories/download_task_repository.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase db;
  late ModelDescriptor model;
  late DownloadTaskRecord task;
  late List<int> modelHive, downloadHive;

  setUp(() async {
    await Hive.close();
    root = await Directory.systemTemp.createTemp('inventory-migration-');
    db = AppDatabase.at(root);
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ModelDescriptorAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(DownloadFileRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(DownloadTaskRecordAdapter());
    }
    final directory = await Directory(
      '${root.path}/models/vision',
    ).create(recursive: true);
    final file = await File(
      '${directory.path}/model.gguf',
    ).writeAsString('fixture model');
    final projector = await File(
      '${directory.path}/mmproj.gguf',
    ).writeAsString('projector');
    model = ModelDescriptor(
      id: 'old-model',
      modelName: 'vision',
      sizeBytes: await file.length(),
      storedDirectoryPath: directory.path,
      storedFilePath: file.path,
      importedAt: DateTime.utc(2025, 1, 2, 3, 4, 5, 6),
      mmprojFilePath: projector.path,
      visionEnabled: false,
      mmprojFiles: {'vision/mmproj.gguf': projector.path},
      sourceValue: 'huggingface',
      repoId: 'owner/model',
      revision: 'pinned',
    );
    final staging = await Directory(
      '${root.path}/downloads/task',
    ).create(recursive: true);
    await File('${staging.path}/model.gguf.part').writeAsString('partial');
    task = DownloadTaskRecord(
      id: 'task',
      engineValue: 'llama_cpp',
      sourceValue: 'huggingface',
      repoId: 'owner/model',
      revision: 'pinned',
      modelName: 'download',
      requestedModelName: 'requested',
      files: [
        DownloadFileRecord(
          remotePath: 'dir/model.gguf',
          fileName: 'model.gguf',
          totalBytes: 100,
          receivedBytes: 7,
          sha256: 'fixture-hash',
          completed: false,
        ),
      ],
      statusValue: 'paused',
      createdAt: DateTime.utc(2025, 2, 3, 4, 5, 6, 7),
      stagingDirPath: staging.path,
      pausedByNetwork: true,
      quantLabel: 'Q4',
      errorDetail: 'fixture error',
      targetModelId: model.id,
    );
  });

  tearDown(() async {
    await Hive.close();
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> seed() async {
    final models = await Hive.openBox<ModelDescriptor>('imported_models');
    await models.put(model.id, model);
    final downloads = await Hive.openBox<DownloadTaskRecord>('download_tasks');
    await downloads.put(task.id, task);
    await Hive.close();
    modelHive = await File('${root.path}/imported_models.hive').readAsBytes();
    downloadHive = await File('${root.path}/download_tasks.hive').readAsBytes();
  }

  Future<void> expectSourcesUnchanged() async {
    expect(
      await File('${root.path}/imported_models.hive').readAsBytes(),
      modelHive,
    );
    expect(
      await File('${root.path}/download_tasks.hive').readAsBytes(),
      downloadHive,
    );
    expect(await File(model.storedFilePath).readAsString(), 'fixture model');
    expect(await File(model.mmprojFilePath!).readAsString(), 'projector');
    expect(
      await File('${task.stagingDirPath}/model.gguf.part').readAsString(),
      'partial',
    );
  }

  test(
    'independent inventory import preserves asset identity and never reimports deleted rows',
    () async {
      await seed();
      await db.setMetadata('legacyImportComplete', '1');
      // A stale/corrupt chat source must not be reopened after its prior migration.
      await File(
        '${root.path}/chat_sessions.hive',
      ).writeAsString('already migrated');
      await db.execute(
        "INSERT INTO model_assets VALUES(?,'llm','llama_cpp',?,'app',?,?,?,'ready',?)",
        [
          'stable-asset',
          model.modelName,
          model.storedFilePath,
          model.modelName,
          'pinned',
          jsonEncode({
            'libraryId': 'gguf:${model.id}',
            'images': false,
            'custom': 'keep',
          }),
        ],
      );
      final progress = <LegacyMigrationProgress>[];
      await LegacyImporter(db, root, onProgress: progress.add).run();
      expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
      expect(
        (await GgufModelStore(db).find(model.id))!.toJson(),
        model.toJson(),
      );
      final downloads = DownloadTaskRepository(database: db);
      expect((await downloads.listTasks()).single.toJson(), task.toJson());
      final assets = await db.query('SELECT id,manifest FROM model_assets');
      expect(assets.single.read<String>('id'), 'stable-asset');
      expect(
        jsonDecode(assets.single.read<String>('manifest'))['custom'],
        'keep',
      );
      expect(progress.last.stage, LegacyMigrationStage.complete);
      expect(
        progress
            .where((p) => p.stage == LegacyMigrationStage.writing)
            .last
            .completed,
        2,
      );
      await expectSourcesUnchanged();

      // Ordinary reconciliation cannot overwrite the newly authoritative details.
      final local = LocalModelRepository(
        database: db,
        appSupportDirectory: root,
      );
      await UnifiedModelRepository(
        database: db,
        localModelRepository: local,
      ).listAssets();
      expect(
        (await GgufModelStore(db).find(model.id))!.toJson(),
        model.toJson(),
      );
      await GgufModelStore(db).remove(model.id);
      await downloads.delete(task.id);
      progress.clear();
      await LegacyImporter(db, root, onProgress: progress.add).run();
      expect(await GgufModelStore(db).list(), isEmpty);
      expect(await downloads.listTasks(), isEmpty);
      expect(progress, isEmpty);
      await expectSourcesUnchanged();
    },
  );

  test(
    'write failure rolls back all domains and markers, same process retry succeeds',
    () async {
      await seed();
      final progress = <LegacyMigrationProgress>[];
      await db.customStatement(
        "CREATE TRIGGER reject_download BEFORE INSERT ON download_tasks BEGIN SELECT RAISE(ABORT,'fixture failure'); END",
      );
      final importer = LegacyImporter(db, root, onProgress: progress.add);
      await expectLater(importer.run(), throwsA(anything));
      expect(await db.metadata('legacyImportComplete'), isNull);
      expect(await db.metadata(LegacyImporter.inventoryMarker), isNull);
      expect(await db.query('SELECT id FROM model_assets'), isEmpty);
      expect(
        progress.any((p) => p.stage == LegacyMigrationStage.complete),
        isFalse,
      );
      await expectSourcesUnchanged();
      await db.customStatement('DROP TRIGGER reject_download');
      await importer.run();
      expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
      expect((await GgufModelStore(db).list()).single.toJson(), model.toJson());
      await expectSourcesUnchanged();
    },
  );

  test(
    'fresh installation marks empty migration without showing upgrade or creating Hive files',
    () async {
      final progress = <LegacyMigrationProgress>[];
      await LegacyImporter(db, root, onProgress: progress.add).run();
      expect(progress, isEmpty);
      expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
      expect(await db.metadata('legacyImportComplete'), '1');
      expect(
        await root.list().any((entry) => entry.path.endsWith('.hive')),
        isFalse,
      );
    },
  );

  test(
    'release database reopens and durable SQL writes no longer modify Hive',
    () async {
      await seed();
      await db.setMetadata('legacyImportComplete', '1');
      await db.close();
      db = AppDatabase.at(root);
      await LegacyImporter(db, root).run();
      expect(
        (await db.query(
          'PRAGMA user_version',
        )).single.read<int>('user_version'),
        2,
      );
      final downloads = DownloadTaskRepository(database: db);
      task.files.first.receivedBytes = 42;
      task.statusValue = 'running';
      await downloads.save(task);
      await db.close();
      db = AppDatabase.at(root);
      expect(
        (await DownloadTaskRepository(
          database: db,
        ).listTasks()).single.toJson(),
        task.toJson(),
      );
      await expectSourcesUnchanged();
    },
  );

  test(
    'corrupt source fails closed and preserves original bytes for retry',
    () async {
      final source = File('${root.path}/imported_models.hive');
      final bytes = utf8.encode('not a Hive frame');
      await source.writeAsBytes(bytes);
      await expectLater(LegacyImporter(db, root).run(), throwsA(anything));
      expect(await db.metadata(LegacyImporter.inventoryMarker), isNull);
      expect(await source.readAsBytes(), bytes);
      await source.delete();
      await LegacyImporter(db, root).run();
      expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
    },
  );

  test('1.x chat records and inventory migrate together', () async {
    await seed();
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChatMessageRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ChatSessionRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ChatRoleAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ChatMessageVersionRecordAdapter());
    }
    final sessions = await Hive.openBox<ChatSessionRecord>('chat_sessions');
    final messages = await Hive.openBox<ChatMessageRecord>('chat_messages');
    await sessions.put(
      'chat',
      ChatSessionRecord(
        id: 'chat',
        title: 'Legacy',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        messageIds: ['message'],
      ),
    );
    await messages.put(
      'message',
      ChatMessageRecord(
        id: 'message',
        sessionId: 'chat',
        role: ChatRole.user,
        content: 'fixture message',
        createdAt: DateTime(2025),
      ),
    );
    await Hive.close();
    await LegacyImporter(db, root).run();
    expect(
      (await db.query(
        'SELECT id FROM conversations',
      )).single.read<String>('id'),
      'chat',
    );
    expect(
      (await db.query('SELECT id FROM messages')).single.read<String>('id'),
      'message',
    );
    expect(await db.metadata('legacyImportComplete'), '1');
    expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
  });

  test(
    'lone compacted source is imported without renaming or modifying it',
    () async {
      await seed();
      final compacted = await File(
        '${root.path}/imported_models.hive',
      ).rename('${root.path}/imported_models.hivec');
      await LegacyImporter(db, root).run();
      expect(
        (await GgufModelStore(db).find(model.id))!.toJson(),
        model.toJson(),
      );
      expect(await compacted.readAsBytes(), modelHive);
      expect(await File('${root.path}/imported_models.hive').exists(), isFalse);
    },
  );

  test(
    '1.x message order, selected versions and attachments migrate atomically with inventory',
    () async {
      await seed();
      Hive.init(root.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChatMessageRecordAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ChatSessionRecordAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ChatRoleAdapter());
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(ChatMessageVersionRecordAdapter());
      }
      final sessions = await Hive.openBox<ChatSessionRecord>('chat_sessions');
      final messages = await Hive.openBox<ChatMessageRecord>('chat_messages');
      final versions = await Hive.openBox<ChatMessageVersionRecord>(
        'chat_message_versions',
      );
      final images = <File>[];
      for (final name in ['one.png', 'two.png']) {
        final file = File('${root.path}/chat_attachments/$name');
        await file.parent.create(recursive: true);
        images.add(await file.writeAsString(name));
      }
      final v1 = ChatMessageVersionRecord(
        id: 'v1',
        messageId: 'answer',
        content: 'First answer',
        createdAt: DateTime(2025, 1),
        modelName: 'Model one',
        reasoningContent: 'Reason one',
        imageFilePaths: [images[0].path],
      );
      final v2 = ChatMessageVersionRecord(
        id: 'v2',
        messageId: 'answer',
        content: 'Second answer',
        createdAt: DateTime(2025, 2),
        modelName: 'Model two',
        imageFilePaths: [images[1].path],
      );
      await versions.put(v2.id, v2);
      await versions.put(v1.id, v1);
      await messages.put(
        'answer',
        ChatMessageRecord(
          id: 'answer',
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime(2025),
          versionIds: ['v1', 'v2'],
        ).withVersion(v1, 0),
      );
      await messages.put(
        'question',
        ChatMessageRecord(
          id: 'question',
          role: ChatRole.user,
          content: 'Question',
          createdAt: DateTime(2025, 3),
        ),
      );
      await messages.put(
        'unfiled',
        ChatMessageRecord(
          id: 'unfiled',
          role: ChatRole.user,
          content: 'Unfiled history',
          createdAt: DateTime(2025),
        ),
      );
      await sessions.put(
        'chat',
        ChatSessionRecord(
          id: 'chat',
          title: 'Saved chat',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025, 3),
          messageIds: ['question', 'answer'],
        ),
      );
      await Hive.close();
      final sourceBytes = {
        for (final name in [
          'chat_sessions',
          'chat_messages',
          'chat_message_versions',
        ])
          name: await File('${root.path}/$name.hive').readAsBytes(),
      };
      await db.execute(
        "CREATE TRIGGER reject_version BEFORE INSERT ON message_revisions WHEN NEW.id='v2' BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(LegacyImporter(db, root).run(), throwsA(anything));
      for (final table in [
        'conversations',
        'messages',
        'message_revisions',
        'revision_attachments',
        'model_assets',
        'download_tasks',
      ]) {
        expect(await db.query('SELECT * FROM $table'), isEmpty);
      }
      expect(await db.metadata('legacyImportComplete'), isNull);
      expect(await db.metadata(LegacyImporter.inventoryMarker), isNull);
      await db.execute('DROP TRIGGER reject_version');
      await LegacyImporter(db, root).run();
      final store = ChatRecordStore(db);
      expect(await store.messageIds('chat'), ['question', 'answer']);
      final answer = (await store.message('answer'))!;
      expect(answer.content, v1.content);
      expect(answer.versionIds, ['v1', 'v2']);
      expect(answer.currentVersionIndex, 0);
      expect(answer.imageFilePaths, v1.imageFilePaths);
      expect((await store.version('v2'))!.imageFilePaths, v2.imageFilePaths);
      expect(answer.reasoningContent, v1.reasoningContent);
      expect(answer.modelName, v1.modelName);
      expect(
        (await store.sessions()).any((s) => s.messageIds.contains('unfiled')),
        isTrue,
      );
      expect(await db.query('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.query(
          'SELECT created_at FROM download_tasks',
        )).single.read<int>('created_at'),
        task.createdAt.millisecondsSinceEpoch,
      );
      for (final entry in sourceBytes.entries) {
        expect(
          await File('${root.path}/${entry.key}.hive').readAsBytes(),
          entry.value,
        );
      }
      await expectSourcesUnchanged();
    },
  );

  test(
    'conflicting destination cannot silently discard a legacy download',
    () async {
      await seed();
      final existing = DownloadTaskRecord.fromJson(task.toJson())
        ..modelName = 'Already saved';
      await DownloadTaskRepository(database: db).save(existing);
      await expectLater(LegacyImporter(db, root).run(), throwsStateError);
      expect(await db.metadata(LegacyImporter.inventoryMarker), isNull);
      expect(await GgufModelStore(db).list(), isEmpty);
      expect(
        (await DownloadTaskRepository(
          database: db,
        ).listTasks()).single.modelName,
        'Already saved',
      );
      await expectSourcesUnchanged();
    },
  );

  test(
    'download writes snapshot mutable progress and reads return independent objects',
    () async {
      final repository = DownloadTaskRepository(database: db);
      final original = task.toJson();
      final saving = repository.save(task);
      task.files.first.receivedBytes = 99;
      task.modelName = 'Changed in memory';
      await saving;
      final loaded = (await repository.listTasks()).single;
      expect(loaded.toJson(), original);
      loaded.files.clear();
      expect((await repository.listTasks()).single.files, hasLength(1));
    },
  );
}
