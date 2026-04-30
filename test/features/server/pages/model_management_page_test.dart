import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelManagementPage', () {
    testWidgets('shows empty state when there are no models', (tester) async {
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(),
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await tester.pumpWidget(
        MaterialApp(home: ModelManagementPage(provider: provider)),
      );
      await tester.pump();

      expect(find.text('还没有导入模型'), findsOneWidget);
      expect(find.byKey(const Key('model_management_import_fab')), findsOneWidget);
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

      await tester.pumpWidget(
        MaterialApp(home: ModelManagementPage(provider: provider)),
      );
      await tester.pump();

      expect(find.text('model'), findsOneWidget);
      expect(find.text('2.00 GB · GGUF'), findsOneWidget);
      expect(find.byTooltip('删除'), findsOneWidget);
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

      await tester.pumpWidget(
        MaterialApp(home: ModelManagementPage(provider: provider)),
      );
      await tester.pump();

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

      await tester.pumpWidget(
        MaterialApp(home: ModelManagementPage(provider: provider)),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('模型已删除: delete'), findsOneWidget);
      expect(find.text('还没有导入模型'), findsOneWidget);
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

      await tester.pumpWidget(
        MaterialApp(home: ModelManagementPage(provider: provider)),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FloatingActionButton, '导入模型'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('模型导入成功: picked'), findsOneWidget);
      expect(find.text('picked'), findsOneWidget);
      expect(find.text('1.00 GB · GGUF'), findsOneWidget);
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
  Future<ModelDescriptor> importModel(PickedGgufFile pickedFile) async {
    final descriptor = _descriptor(
      id: 'm${_models.length + 1}',
      modelName: _deriveModelName(pickedFile.fileName),
      originalFileName: pickedFile.fileName,
    );
    _models.insert(0, descriptor);
    return descriptor;
  }

  @override
  Future<void> deleteModel(String modelId) async {
    _models.removeWhere((model) => model.id == modelId);
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
  FakeGgufFilePicker({this.pickedFile});

  final PickedGgufFile? pickedFile;

  @override
  Future<PickedGgufFile?> pickSingle() async => pickedFile;
}

ModelDescriptor _descriptor({
  required String id,
  required String modelName,
  String? originalFileName,
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
  );
}
