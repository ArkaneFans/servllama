import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/pages/hub_repo_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/repositories/download_task_repository.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/features/downloads/widgets/mmproj_picker_sheet.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const q4 = HubRepoFile(path: 'Qwen-Q4_K_M.gguf', sizeBytes: 40);
  const q8 = HubRepoFile(path: 'Qwen-Q8_0.gguf', sizeBytes: 80);
  const firstMmproj = HubRepoFile(
    path: 'Qwen3.5-0.8B-mmproj-f16.gguf',
    sizeBytes: 12,
  );
  const secondMmproj = HubRepoFile(path: 'mmproj-f32.gguf', sizeBytes: 24);
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('HubRepoPage GGUF vision picker', () {
    testWidgets('hides vision when the repository has no mmproj files', (
      tester,
    ) async {
      final downloads = _RecordingDownloadProvider();
      addTearDown(downloads.dispose);

      await tester.pumpWidget(
        _host(files: const <HubRepoFile>[q4, q8], downloads: downloads),
      );
      await tester.pumpAndSettle();
      await _openRepo(tester);

      expect(find.byKey(Key('quant_vision_button_${q4.path}')), findsNothing);
      expect(find.byKey(Key('quant_vision_button_${q8.path}')), findsNothing);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.repoDownloadAction).first,
      );
      await _settle(tester);

      expect(downloads.calls, hasLength(1));
      expect(downloads.calls.single.files, <HubRepoFile>[q4]);
    });

    testWidgets('defaults to vision on and the first mmproj', (tester) async {
      final downloads = _RecordingDownloadProvider();
      addTearDown(downloads.dispose);

      await tester.pumpWidget(
        _host(
          files: const <HubRepoFile>[q8, firstMmproj, q4, secondMmproj],
          downloads: downloads,
        ),
      );
      await tester.pumpAndSettle();
      await _openRepo(tester);

      expect(find.byKey(Key('quant_vision_button_${q4.path}')), findsOneWidget);
      expect(find.text(l10n.repoVisionOn), findsWidgets);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.repoDownloadAction).first,
      );
      await _settle(tester);

      expect(downloads.calls, hasLength(1));
      expect(downloads.calls.single.files, <HubRepoFile>[q4, firstMmproj]);
    });

    testWidgets('can disable vision and download only the quant', (
      tester,
    ) async {
      final downloads = _RecordingDownloadProvider();
      addTearDown(downloads.dispose);

      await tester.pumpWidget(
        _host(
          files: const <HubRepoFile>[q4, firstMmproj, secondMmproj],
          downloads: downloads,
        ),
      );
      await tester.pumpAndSettle();
      await _openRepo(tester);

      await tester.tap(find.byKey(Key('quant_vision_button_${q4.path}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mmproj_enable_switch')));
      await tester.pump();
      Navigator.of(tester.element(find.byType(MmprojPickerSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.text(l10n.repoVisionOff), findsWidgets);

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.repoDownloadAction).first,
      );
      await _settle(tester);

      expect(downloads.calls.single.files, <HubRepoFile>[q4]);
    });

    testWidgets('can switch to another mmproj before downloading', (
      tester,
    ) async {
      final downloads = _RecordingDownloadProvider();
      addTearDown(downloads.dispose);

      await tester.pumpWidget(
        _host(
          files: const <HubRepoFile>[q4, firstMmproj, secondMmproj],
          downloads: downloads,
        ),
      );
      await tester.pumpAndSettle();
      await _openRepo(tester);

      await tester.tap(find.byKey(Key('quant_vision_button_${q4.path}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('mmproj_option_${secondMmproj.path}')));
      await tester.pump();
      Navigator.of(tester.element(find.byType(MmprojPickerSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.repoDownloadAction).first,
      );
      await _settle(tester);

      expect(downloads.calls.single.files, <HubRepoFile>[q4, secondMmproj]);
    });
  });
}

Widget _host({
  required List<HubRepoFile> files,
  required _RecordingDownloadProvider downloads,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ModelDiscoveryProvider>(
        create: (_) => ModelDiscoveryProvider(
          catalogService: _EmptyCatalogService(),
          capabilityService: _UnknownCapabilityService(),
          settingsStore: _MemoryDownloadSettingsStore(),
          huggingFaceClient: _FakeHubClient(files: files),
          modelScopeClient: _FakeHubClient(files: files),
        ),
      ),
      ChangeNotifierProvider<DownloadProvider>.value(value: downloads),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HubRepoPage(
                      repoId: 'owner/qwen',
                      source: ModelHubSource.huggingFace,
                      engine: InferenceEngine.llamaCpp,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _openRepo(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

class _EnqueueCall {
  const _EnqueueCall({required this.files, this.targetModelId});

  final List<HubRepoFile> files;
  final String? targetModelId;
}

class _RecordingDownloadProvider extends DownloadProvider {
  _RecordingDownloadProvider()
    : super(
        taskRepository: _MemoryTaskRepository(),
        downloadService: ModelDownloadService(),
        settingsStore: _MemoryDownloadSettingsStore(),
        localModelRepository: _FakeLocalModelRepository(),
        logger: AppLogger(),
      );

  final List<_EnqueueCall> calls = <_EnqueueCall>[];

  @override
  Future<bool> isBlockedByWifiOnlyPolicy() async => false;

  @override
  Future<DownloadTaskView> enqueue({
    required InferenceEngine engine,
    required ModelHubSource source,
    required String repoId,
    required String revision,
    required String modelName,
    required List<HubRepoFile> files,
    String? quantLabel,
    String? targetModelId,
  }) async {
    calls.add(
      _EnqueueCall(
        files: List<HubRepoFile>.from(files),
        targetModelId: targetModelId,
      ),
    );
    return DownloadTaskView(
      DownloadTaskRecord(
        id: 'task',
        engineValue: engine.storageValue,
        sourceValue: source.storageValue,
        repoId: repoId,
        revision: revision,
        modelName: modelName,
        files: const <DownloadFileRecord>[],
        statusValue: DownloadStatus.queued.name,
        createdAt: DateTime(2026),
        stagingDirPath: '/tmp',
        targetModelId: targetModelId,
      ),
    );
  }
}

class _MemoryTaskRepository extends DownloadTaskRepository {
  @override
  Future<List<DownloadTaskRecord>> listTasks() async =>
      const <DownloadTaskRecord>[];

  @override
  Future<void> save(DownloadTaskRecord task) async {}

  @override
  Future<void> delete(String taskId) async {}

  @override
  Future<Directory> createStagingDirectory(String taskId) async =>
      Directory.systemTemp;

  @override
  Future<void> deleteStagingDirectory(String stagingDirPath) async {}
}

class _FakeLocalModelRepository extends LocalModelRepository {
  _FakeLocalModelRepository()
    : super(appSupportDirectory: Directory.systemTemp);

  @override
  Future<List<ModelDescriptor>> listModels() async => const <ModelDescriptor>[];

  @override
  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async => false;

  @override
  Future<ModelDescriptor> adoptDownloadedModel({
    required String modelName,
    required File modelFile,
    File? mmprojFile,
    String? sourceValue,
    String? repoId,
    String? revision,
  }) async {
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
  }) async {
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

class _EmptyCatalogService extends ModelCatalogService {
  @override
  Future<List<CatalogEntry>> load() async => const <CatalogEntry>[];
}

class _UnknownCapabilityService extends DeviceCapabilityService {
  @override
  Future<DeviceMemoryInfo> readMemory() async => DeviceMemoryInfo.unknown;
}

class _MemoryDownloadSettingsStore extends DownloadSettingsStore {
  @override
  Future<DownloadSettings> load() async =>
      const DownloadSettings(wifiOnly: false);
}

class _FakeHubClient implements ModelHubClient {
  _FakeHubClient({required this.files});

  final List<HubRepoFile> files;

  @override
  ModelHubSource get source => ModelHubSource.huggingFace;

  @override
  Set<HubModelFormat> get searchableFormats => const <HubModelFormat>{
    HubModelFormat.gguf,
  };

  @override
  Map<String, String> authHeaders(String? token) => const <String, String>{};

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) => '';

  @override
  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    HubSearchSort sort = HubSearchSort.trending,
    int limit = ModelHubClient.defaultSearchLimit,
    String? pageToken,
  }) async => const HubSearchPage(items: <HubRepoSummary>[]);

  @override
  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  }) async {
    return HubRepoDetail(
      summary: HubRepoSummary(
        source: ModelHubSource.huggingFace,
        format: expectedFormat ?? HubModelFormat.gguf,
        repoId: repoId,
        owner: repoId.split('/').first,
        name: repoId.split('/').last,
      ),
      files: files,
    );
  }
}
