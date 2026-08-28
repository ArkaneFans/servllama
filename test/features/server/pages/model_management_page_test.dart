import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';

import '../../../support/stub_engine_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelManagementPage', () {
    setUp(() {
      // Provider-produced snackbar text comes from AppL10nService, which
      // otherwise follows the host platform locale.
      AppL10nService.instance.setLocale(const Locale('zh'));
      // The unified library also asks the MNN plugin for its models; with no
      // handler the platform call never completes and the page stays on its
      // loading spinner forever.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            (call) async =>
                call.method == 'listImportedModels' ? <Object?>[] : null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            null,
          );
    });

    testWidgets('shows empty state when there are no models', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      expect(find.text('还没有模型'), findsOneWidget);
      expect(
        find.byKey(const Key('model_management_import_fab')),
        findsOneWidget,
      );
    });

    testWidgets('shows model cards with modelName and size', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'model', sizeBytes: 2147483648),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      expect(find.text('model'), findsOneWidget);
      expect(find.text('llama.cpp · 2.00 GB'), findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);
      expect(find.byTooltip('删除'), findsOneWidget);
    });

    testWidgets('tapping a model card does not start the runtime', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.server.foreground_notification_permission_prompted': true,
      });
      final runtime = EngineRuntimeProvider(
        llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
        mnnAdapter: StubEngineAdapter(),
        localIpResolver: () async => null,
      );
      addTearDown(runtime.dispose);

      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'model'),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider, runtime: runtime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('model'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(runtime.isRunning, isFalse);
      expect(runtime.status, EngineRuntimeStatus.idle);
      expect(runtime.activeModelId, isNull);
      expect(find.text('空闲'), findsOneWidget);
    });

    testWidgets('shows text badge when mmproj does not exist', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'text-only'),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Capability tags are additive now: a text-only model carries none.
      expect(find.text('视觉'), findsNothing);
      expect(find.text('工具调用'), findsNothing);
    });

    testWidgets('shows multimodal badge when mmproj exists', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(
              id: 'm1',
              modelName: 'vision',
              mmprojFilePath: 'C:\\models\\vision\\mmproj-projector-f16.gguf',
            ),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      expect(find.text('视觉'), findsOneWidget);
    });

    testWidgets('shows confirmation dialog before deleting a model', (
      tester,
    ) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'delete'),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();

      expect(find.text('删除模型'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('delete'),
        ),
        findsOneWidget,
      );
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('deletes model and shows snackbar after confirmation', (
      tester,
    ) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'delete'),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await _settle(tester);

      expect(find.text('模型已删除: delete'), findsOneWidget);
      expect(find.text('还没有模型'), findsOneWidget);
    });

    testWidgets('imports model and shows snackbar feedback', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(),
        filePicker: FakeGgufFilePicker(
          pickedFile: const PickedGgufFile(
            path: 'C:\\mock\\picked.gguf',
            fileName: 'picked.gguf',
          ),
        ),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // The FAB now offers download / GGUF file / MNN directory rather than
      // importing a GGUF straight away.
      await tester.tap(find.byKey(const Key('model_management_import_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入 GGUF 文件'));
      await _settle(tester);

      expect(find.text('模型导入成功: picked'), findsOneWidget);
      expect(find.text('picked'), findsOneWidget);
      expect(find.text('llama.cpp · 1.00 GB'), findsOneWidget);
    });

    testWidgets('renames model from settings sheet', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'before'),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('model_settings_name_field')),
        'after',
      );
      // The save button stays disabled until the draft name rebuilds.
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('model_settings_save_name_button')),
      );
      await _settle(tester);

      expect(find.text('模型已重命名为: after'), findsOneWidget);
      expect(find.text('after'), findsWidgets);
    });

    testWidgets('renames an MNN model from its settings sheet', (tester) async {
      var modelName = 'mnn-before';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            (call) async {
              switch (call.method) {
                case 'listImportedModels':
                  return <Object?>[_mnnModelMap(modelName)];
                case 'renameImportedModel':
                  final arguments = Map<Object?, Object?>.from(
                    call.arguments! as Map,
                  );
                  expect(arguments['modelId'], 'mnn-before');
                  modelName = arguments['newName']! as String;
                  return _mnnModelMap(modelName);
              }
              return null;
            },
          );
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mnn_model_settings_name_field')),
        'mnn-after',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('mnn_model_settings_save_name_button')),
      );
      await _settle(tester);

      expect(find.text('模型已重命名为: mnn-after'), findsOneWidget);
      expect(find.text('mnn-after'), findsWidgets);
    });

    testWidgets('imports mmproj from settings sheet', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(id: 'm1', modelName: 'vision'),
          ],
        ),
        filePicker: FakeGgufFilePicker(
          pickedMmprojFile: const PickedGgufFile(
            path: 'C:\\mock\\mmproj-f16.gguf',
            fileName: 'mmproj-f16.gguf',
          ),
        ),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('model_settings_import_mmproj_button')),
      );
      await _settle(tester);

      expect(find.text('mmproj 导入成功: vision'), findsOneWidget);
      expect(find.text('视觉'), findsWidgets);
      expect(
        find.byKey(const Key('model_settings_remove_mmproj_button')),
        findsOneWidget,
      );
    });

    testWidgets('removes mmproj from settings sheet after confirmation', (
      tester,
    ) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _descriptor(
              id: 'm1',
              modelName: 'vision',
              mmprojFilePath: 'C:\\models\\vision\\mmproj-f16.gguf',
            ),
          ],
        ),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('model_settings_remove_mmproj_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('确定移除 vision 的 mmproj 文件吗？'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await _settle(tester);

      expect(find.text('mmproj 已移除: vision'), findsOneWidget);
      expect(
        find.byKey(const Key('model_settings_import_mmproj_button')),
        findsOneWidget,
      );
    });
  });
}

class FakeLocalModelRepository extends LocalModelRepository {
  FakeLocalModelRepository({List<ModelDescriptor>? initialModels})
    : _models = List<ModelDescriptor>.from(
        initialModels ?? const <ModelDescriptor>[],
      ),
      super(appSupportDirectory: Directory.systemTemp);

  final List<ModelDescriptor> _models;

  @override
  Future<List<ModelDescriptor>> listModels() async =>
      List<ModelDescriptor>.from(_models);

  @override
  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async => _models.any(
    (model) =>
        model.id != excludingModelId &&
        model.modelName.toLowerCase() == modelName.toLowerCase(),
  );

  @override
  Future<ModelDescriptor> importModel(
    PickedGgufFile pickedFile, {
    String? modelName,
  }) async {
    final descriptor = _descriptor(
      id: 'm${_models.length + 1}',
      modelName: modelName ?? _deriveModelName(pickedFile.fileName),
      originalFileName: pickedFile.fileName,
    );
    _models.insert(0, descriptor);
    return descriptor;
  }

  @override
  Future<void> deleteModel(String modelId) async {
    _models.removeWhere((model) => model.id == modelId);
  }

  @override
  Future<ModelDescriptor> importMmproj(
    String modelId,
    PickedGgufFile pickedFile,
  ) async {
    final index = _models.indexWhere((model) => model.id == modelId);
    final updated = _models[index].copyWith(mmprojFilePath: pickedFile.path);
    _models[index] = updated;
    return updated;
  }

  @override
  Future<ModelDescriptor> removeMmproj(String modelId) async {
    final index = _models.indexWhere((model) => model.id == modelId);
    final updated = _models[index].copyWith(mmprojFilePath: null);
    _models[index] = updated;
    return updated;
  }

  @override
  Future<ModelDescriptor> renameModel(String modelId, String newName) async {
    final index = _models.indexWhere((model) => model.id == modelId);
    final current = _models[index];
    final updated = current.copyWith(
      modelName: newName,
      storedDirectoryPath: 'C:\\models\\$newName',
      storedFilePath:
          'C:\\models\\$newName\\${current.storedFilePath.split('\\').last}',
      mmprojFilePath: current.mmprojFilePath == null
          ? null
          : 'C:\\models\\$newName\\${current.mmprojFilePath!.split('\\').last}',
    );
    _models[index] = updated;
    return updated;
  }

  String _deriveModelName(String fileName) {
    const suffix = '.gguf';
    if (fileName.toLowerCase().endsWith(suffix)) {
      return fileName.substring(0, fileName.length - suffix.length);
    }
    return fileName;
  }
}

class FakeGgufFilePicker extends GgufFilePicker {
  FakeGgufFilePicker({this.pickedFile, this.pickedMmprojFile});

  final PickedGgufFile? pickedFile;
  final PickedGgufFile? pickedMmprojFile;

  @override
  Future<PickedGgufFile?> pickSingle() async => pickedFile;

  @override
  Future<PickedGgufFile?> pickSingleMmproj() async => pickedMmprojFile;
}

ModelDescriptor _descriptor({
  required String id,
  required String modelName,
  String? originalFileName,
  String? mmprojFilePath,
  int sizeBytes = 1073741824,
}) {
  final fileName = originalFileName ?? '$modelName.gguf';
  return ModelDescriptor(
    id: id,
    modelName: modelName,
    sizeBytes: sizeBytes,
    storedDirectoryPath:
        'C:${Platform.pathSeparator}models${Platform.pathSeparator}$modelName',
    storedFilePath:
        'C:${Platform.pathSeparator}models${Platform.pathSeparator}$modelName${Platform.pathSeparator}$fileName',
    importedAt: DateTime(2026, 1, 1),
    mmprojFilePath: mmprojFilePath,
  );
}

Map<String, Object?> _mnnModelMap(String name) => <String, Object?>{
  'modelId': name,
  'modelKey': name,
  'displayName': name,
  'modelDirPath': 'C:\\mnn\\models\\$name',
  'configPath': 'C:\\mnn\\models\\$name\\config.json',
  'sizeBytes': 1024,
  'importedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
  'isActive': false,
};

/// The library page lists in-flight downloads alongside imported models, so it
/// needs the download queue in scope even when no test exercises it.
Widget _host(
  ModelManagementProvider provider, {
  EngineRuntimeProvider? runtime,
}) {
  return MultiProvider(
    providers: [
      // Above MaterialApp on purpose: the settings sheet builds under the
      // Navigator's overlay, so a provider scoped to the page itself would be
      // out of its reach.
      ChangeNotifierProvider<ModelManagementProvider>.value(value: provider),
      ChangeNotifierProvider<DownloadProvider>(
        create: (_) => DownloadProvider(),
      ),
      if (runtime != null)
        ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
    ],
    child: MaterialApp(home: ModelManagementPage(provider: provider)),
  );
}

/// Flushes the provider's async refresh without advancing far enough for a
/// SnackBar to dismiss itself.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}
