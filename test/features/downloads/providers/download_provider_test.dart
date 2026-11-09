import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/model_name_coordinator.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/repositories/download_task_repository.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadProvider', () {
    late Directory tempDirectory;

    setUp(() async {
      AppL10nService.instance.setLocale(const Locale('zh'));
      tempDirectory = await Directory.systemTemp.createTemp(
        'servllama-download-provider-test-',
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            null,
          );
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'startup restores task metadata without starting network work',
      () async {
        final repository = _MemoryTaskRepository([
          _record(
            stagingDirPath: tempDirectory.path,
            status: DownloadStatus.running,
          ),
        ]);
        final downloads = _BlockingDownloadService();
        final provider = DownloadProvider(
          taskRepository: repository,
          downloadService: downloads,
          settingsStore: _MemorySettingsStore(),
          localModelRepository: _FakeLocalModelRepository(),
          logger: AppLogger(),
        );
        await Future.wait([
          provider.load(startTransfers: false),
          provider.load(startTransfers: false),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(repository.listCalls, 1);
        expect(provider.activeTaskCount, 1);
        expect(provider.tasks.single.status, DownloadStatus.queued);
        expect(downloads.callCount, 0);
        provider.resumeRestoredTransfers();
        provider.resumeRestoredTransfers();
        await downloads.started.future;
        await provider.load();
        expect(repository.listCalls, 1);
        expect(downloads.callCount, 1);
        downloads.release.complete();
        await _waitFor(() => provider.tasks.isEmpty);
        provider.dispose();
      },
    );

    test(
      'MNN SQL registration failure rolls back without completion',
      () async {
        var deleted = '', refreshes = 0;
        final completed = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.arkanefans.mnn_engine/methods'),
              (call) async {
                if (call.method == 'deleteImportedModel') {
                  deleted = (call.arguments as Map)['modelId'] as String;
                  return null;
                }
                if (call.method == 'importModelFromPathWithResult') {
                  return {
                    'requestedModelName': 'model',
                    'model': {
                      'modelId': 'model',
                      'modelKey': 'model',
                      'displayName': 'model',
                      'modelDirPath': '/models/model',
                      'configPath': '/models/model/config.json',
                      'sizeBytes': 10,
                      'importedAt': 1,
                      'isActive': false,
                    },
                  };
                }
                throw StateError('Unexpected native call: ${call.method}');
              },
            );
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final provider = DownloadProvider(
          taskRepository: _MemoryTaskRepository([
            _record(
              stagingDirPath: tempDirectory.path,
              status: DownloadStatus.downloaded,
              engineValue: 'mnn',
              completedFile: true,
            ),
          ]),
          downloadService: _BlockingDownloadService()..release.complete(),
          settingsStore: _MemorySettingsStore(),
          unifiedModelRepository: _RejectingMnnRepository(db),
          onLibraryChanged: () async {
            refreshes++;
          },
          logger: AppLogger(),
        );
        addTearDown(provider.dispose);
        provider.onDownloadCompleted = completed.add;
        await provider.load();
        await _waitFor(
          () =>
              provider.tasks.single.record.statusValue ==
              DownloadStatus.failed.name,
        );
        expect(deleted, 'model');
        expect(refreshes, 0);
        expect(completed, isEmpty);
        expect(await db.query('SELECT * FROM model_assets'), isEmpty);
      },
    );

    test(
      'a cancelled task cannot be persisted again by its old worker',
      () async {
        final repository = _MemoryTaskRepository(<DownloadTaskRecord>[
          _record(
            stagingDirPath: tempDirectory.path,
            status: DownloadStatus.queued,
          ),
        ]);
        final downloadService = _BlockingDownloadService(
          honorCancellation: false,
        );
        final provider = DownloadProvider(
          taskRepository: repository,
          downloadService: downloadService,
          settingsStore: _MemorySettingsStore(),
          localModelRepository: _FakeLocalModelRepository(),
          logger: AppLogger(),
        );

        await provider.load();
        await downloadService.started.future;
        await provider.cancel('task');
        downloadService.release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.tasks, isEmpty);
        expect(repository.containsTask('task'), isFalse);
        provider.dispose();
      },
    );

    test('adds a stable display name before importing an MNN download', () async {
      final metadataFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}market_config.json',
      );
      await metadataFile.writeAsString(
        jsonEncode(<String, Object?>{'vendor': 'MNN'}),
      );
      Map<String, dynamic>? importedMetadata;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            (call) async {
              if (call.method != 'importModelFromPathWithResult') {
                return null;
              }
              importedMetadata = Map<String, dynamic>.from(
                jsonDecode(await metadataFile.readAsString()) as Map,
              );
              return <String, Object?>{
                'requestedModelName': 'Qwen3-0.6B-MNN',
                'model': <String, Object?>{
                  'modelId': 'Qwen3-0.6B-MNN',
                  'modelKey': 'Qwen3-0.6B-MNN',
                  'displayName': 'Qwen3-0.6B-MNN',
                  'modelDirPath': '/models/Qwen3-0.6B-MNN',
                  'configPath': '/models/Qwen3-0.6B-MNN/config.json',
                  'sizeBytes': 10,
                  'importedAt': 1,
                  'isActive': false,
                },
              };
            },
          );

      final record = _record(
        stagingDirPath: tempDirectory.path,
        status: DownloadStatus.downloaded,
        engineValue: 'mnn',
        modelName: 'Qwen3-0.6B-MNN',
        completedFile: true,
      );
      final repository = _MemoryTaskRepository(<DownloadTaskRecord>[record]);
      var refreshCount = 0;
      final completed = <String>[];
      final local = _FakeLocalModelRepository();
      final catalog = UnifiedModelRepository(localModelRepository: local);
      final provider = DownloadProvider(
        taskRepository: repository,
        downloadService: _BlockingDownloadService()..release.complete(),
        settingsStore: _MemorySettingsStore(),
        localModelRepository: local,
        logger: AppLogger(),
        onLibraryChanged: () async {
          expect((await catalog.listModels()).single.name, 'Qwen3-0.6B-MNN');
          refreshCount += 1;
        },
      );
      provider.onDownloadCompleted = completed.add;

      await provider.load();
      // Completed downloads are pruned from the task list once committed to
      // the model library, so completion is observable as the list going empty.
      await _waitFor(() => provider.tasks.isEmpty);

      expect(importedMetadata?['modelName'], 'Qwen3-0.6B-MNN');
      expect(importedMetadata?['vendor'], 'MNN');
      expect(refreshCount, 1);
      expect(completed, <String>['Qwen3-0.6B-MNN']);
      provider.dispose();
    });

    test('checks global model-name availability before queueing', () async {
      var checkedName = '';
      final provider = DownloadProvider(
        taskRepository: _MemoryTaskRepository(const <DownloadTaskRecord>[]),
        settingsStore: _MemorySettingsStore(),
        logger: AppLogger(),
        modelNameCoordinator: _ThrowingNameCoordinator((name) {
          checkedName = name;
        }),
      );

      await expectLater(
        provider.enqueue(
          engine: InferenceEngine.mnn,
          source: ModelHubSource.modelScope,
          repoId: 'MNN/model',
          revision: 'master',
          modelName: 'duplicate',
          files: const <HubRepoFile>[],
        ),
        throwsA(isA<ModelOperationException>()),
      );

      expect(checkedName, 'duplicate');
      expect(provider.tasks, isEmpty);
      provider.dispose();
    });

    test(
      'auto-renames duplicate reserved names with the smallest suffix',
      () async {
        final coordinator = ModelNameCoordinator(
          unifiedRepository: UnifiedModelRepository(
            localModelRepository: _FakeLocalModelRepository(),
          ),
        );
        await coordinator.reserveAvailable(
          ownerId: 'existing-download',
          requestedName: 'duplicate',
        );
        final provider = DownloadProvider(
          taskRepository: _MemoryTaskRepository(const <DownloadTaskRecord>[]),
          settingsStore: _MemorySettingsStore(),
          logger: AppLogger(),
          modelNameCoordinator: coordinator,
        );

        final task = await provider.enqueue(
          engine: InferenceEngine.mnn,
          source: ModelHubSource.modelScope,
          repoId: 'MNN/another-model',
          revision: 'master',
          modelName: 'Duplicate',
          files: const <HubRepoFile>[],
        );

        expect(task.modelName, 'Duplicate (2)');
        expect(task.requestedModelName, 'Duplicate');
        provider.dispose();
      },
    );

    test(
      'serializes simultaneous attempts to enqueue the same download',
      () async {
        final provider = DownloadProvider(
          taskRepository: _MemoryTaskRepository(const <DownloadTaskRecord>[]),
          settingsStore: _MemorySettingsStore(),
          logger: AppLogger(),
        );
        const files = <HubRepoFile>[
          HubRepoFile(path: 'model.gguf', sizeBytes: 10),
        ];

        final results = await Future.wait<Object>(
          List<Future<Object>>.generate(
            2,
            (_) => provider
                .enqueue(
                  engine: InferenceEngine.llamaCpp,
                  source: ModelHubSource.modelScope,
                  repoId: 'MNN/model',
                  revision: 'master',
                  modelName: 'model',
                  files: files,
                )
                .then<Object>((task) => task)
                .catchError((Object error) => error),
          ),
        );

        expect(results.whereType<DownloadTaskView>(), hasLength(1));
        expect(
          results.whereType<DownloadException>().single.kind,
          DownloadErrorKind.alreadyQueued,
        );
        expect(provider.tasks, hasLength(1));
        provider.dispose();
      },
    );

    test(
      'commits a replacement mmproj onto the target library model',
      () async {
        final local = _FakeLocalModelRepository();
        final record = _record(
          stagingDirPath: tempDirectory.path,
          status: DownloadStatus.queued,
          completedFile: true,
          targetModelId: 'library-model',
          remotePath: 'Qwen3.5-0.8B-mmproj-f16.gguf',
        );
        final provider = DownloadProvider(
          taskRepository: _MemoryTaskRepository(<DownloadTaskRecord>[record]),
          downloadService: _BlockingDownloadService()..release.complete(),
          settingsStore: _MemorySettingsStore(),
          localModelRepository: local,
          logger: AppLogger(),
        );

        await provider.load();
        await _waitFor(() => provider.tasks.isEmpty);

        expect(local.adoptedMmprojModelIds, <String>['library-model']);
        provider.dispose();
      },
    );
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was not reached');
}

DownloadTaskRecord _record({
  required String stagingDirPath,
  required DownloadStatus status,
  String engineValue = 'llama_cpp',
  String modelName = 'model',
  bool completedFile = false,
  String? targetModelId,
  String? remotePath,
}) {
  final fileName =
      remotePath ?? (engineValue == 'mnn' ? 'llm.mnn' : 'model.gguf');
  return DownloadTaskRecord(
    id: 'task',
    engineValue: engineValue,
    sourceValue: 'modelscope',
    repoId: 'MNN/model',
    revision: 'master',
    modelName: modelName,
    files: <DownloadFileRecord>[
      DownloadFileRecord(
        remotePath: fileName,
        fileName: fileName,
        totalBytes: 10,
        receivedBytes: completedFile ? 10 : 0,
        completed: completedFile,
      ),
    ],
    statusValue: status.name,
    createdAt: DateTime(2026),
    stagingDirPath: stagingDirPath,
    targetModelId: targetModelId,
  );
}

DownloadTaskRecord _cloneTask(DownloadTaskRecord task) {
  return DownloadTaskRecord(
    id: task.id,
    engineValue: task.engineValue,
    sourceValue: task.sourceValue,
    repoId: task.repoId,
    revision: task.revision,
    modelName: task.modelName,
    requestedModelName: task.requestedModelName,
    files: task.files
        .map(
          (file) => DownloadFileRecord(
            remotePath: file.remotePath,
            fileName: file.fileName,
            totalBytes: file.totalBytes,
            receivedBytes: file.receivedBytes,
            sha256: file.sha256,
            completed: file.completed,
          ),
        )
        .toList(growable: false),
    statusValue: task.statusValue,
    createdAt: task.createdAt,
    stagingDirPath: task.stagingDirPath,
    quantLabel: task.quantLabel,
    errorDetail: task.errorDetail,
    pausedByNetwork: task.pausedByNetwork,
    targetModelId: task.targetModelId,
  );
}

class _MemoryTaskRepository extends DownloadTaskRepository {
  _MemoryTaskRepository(List<DownloadTaskRecord> tasks)
    : _tasks = <String, DownloadTaskRecord>{
        for (final task in tasks) task.id: _cloneTask(task),
      };

  final Map<String, DownloadTaskRecord> _tasks;
  int listCalls = 0;

  @override
  Future<List<DownloadTaskRecord>> listTasks() async {
    listCalls += 1;
    return _tasks.values.map(_cloneTask).toList(growable: false);
  }

  @override
  Future<void> save(DownloadTaskRecord task) async {
    _tasks[task.id] = _cloneTask(task);
  }

  @override
  Future<void> delete(String taskId) async {
    _tasks.remove(taskId);
  }

  @override
  Future<Directory> createStagingDirectory(String taskId) async =>
      Directory.systemTemp;

  @override
  Future<void> deleteStagingDirectory(String stagingDirPath) async {}

  bool containsTask(String taskId) => _tasks.containsKey(taskId);
}

class _MemorySettingsStore extends DownloadSettingsStore {
  @override
  Future<DownloadSettings> load() async {
    return const DownloadSettings(wifiOnly: false);
  }
}

class _BlockingDownloadService extends ModelDownloadService {
  _BlockingDownloadService({this.honorCancellation = true});

  final bool honorCancellation;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  int callCount = 0;

  @override
  Future<File> downloadFile({
    required String url,
    required DownloadFileRecord file,
    required Directory targetDirectory,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
    DownloadProgressCallback? onProgress,
  }) async {
    callCount += 1;
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    if (honorCancellation && cancelToken?.isCancelled == true) {
      throw const DownloadException(DownloadErrorKind.cancelled);
    }
    file
      ..receivedBytes = file.totalBytes
      ..completed = true;
    onProgress?.call(file, file.totalBytes);
    return File(
      '${targetDirectory.path}${Platform.pathSeparator}${file.fileName}',
    );
  }
}

class _FakeLocalModelRepository extends LocalModelRepository {
  _FakeLocalModelRepository() : this._(AppDatabase.memory());

  _FakeLocalModelRepository._(AppDatabase db)
    : super(database: db, appSupportDirectory: Directory.systemTemp) {
    addTearDown(db.close);
  }

  @override
  Future<List<ModelDescriptor>> listModels() async => const <ModelDescriptor>[];

  @override
  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async => false;

  final List<String> adoptedMmprojModelIds = <String>[];
  final List<String> adoptedNames = <String>[];

  @override
  Future<ModelDescriptor> adoptDownloadedModel({
    required String modelName,
    required File modelFile,
    File? mmprojFile,
    String? mmprojRemotePath,
    String? sourceValue,
    String? repoId,
    String? revision,
  }) async {
    adoptedNames.add(modelName);
    return ModelDescriptor(
      id: 'model',
      modelName: modelName,
      sizeBytes: 10,
      storedDirectoryPath: modelFile.parent.path,
      storedFilePath: modelFile.path,
      importedAt: DateTime(2026),
      mmprojFilePath: mmprojFile?.path,
      sourceValue: sourceValue,
      repoId: repoId,
      revision: revision,
    );
  }

  @override
  Future<ModelDescriptor> adoptDownloadedMmproj({
    required String modelId,
    required File mmprojFile,
    String? remotePath,
  }) async {
    adoptedMmprojModelIds.add(modelId);
    return ModelDescriptor(
      id: modelId,
      modelName: 'model',
      sizeBytes: 10,
      storedDirectoryPath: mmprojFile.parent.path,
      storedFilePath: mmprojFile.path,
      importedAt: DateTime(2026),
      mmprojFilePath: mmprojFile.path,
    );
  }
}

class _RejectingMnnRepository extends UnifiedModelRepository {
  _RejectingMnnRepository(AppDatabase db) : super(database: db);

  @override
  Future<LibraryModel> registerImportedMnnModel(
    MnnModelInfo info, {
    String? assetId,
  }) async {
    throw StateError('fixture SQL write failure');
  }
}

class _ThrowingNameCoordinator extends ModelNameCoordinator {
  _ThrowingNameCoordinator(this.onAllocate)
    : super(
        unifiedRepository: UnifiedModelRepository(
          localModelRepository: _FakeLocalModelRepository(),
        ),
      );

  final ValueChanged<String> onAllocate;

  @override
  Future<AllocatedModelName> reserveAvailable({
    required String ownerId,
    required String requestedName,
    String? preferredName,
    String? excludingLibraryId,
  }) async {
    onAllocate(requestedName);
    throw const ModelOperationException(
      ModelOperationErrorCode.modelNameExists,
    );
  }
}
