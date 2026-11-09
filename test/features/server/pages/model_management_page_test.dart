import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';

void main() {
  late _Library library;
  late _Downloads downloads;
  setUp(() {
    library = _Library();
    downloads = _Downloads();
  });
  tearDown(() {
    library.dispose();
    downloads.dispose();
  });
  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider<ModelManagementProvider>.value(value: library),
      ChangeNotifierProvider<DownloadProvider>.value(value: downloads),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ModelManagementPage(),
    ),
  );

  testWidgets('empty library opens the GGUF or MNN copy action', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('还没有模型'), findsOneWidget);
    await tester.tap(find.byKey(const Key('model_management_import_fab')));
    await tester.pumpAndSettle();
    expect(find.text('将GGUF模型复制到应用'), findsOneWidget);
    expect(find.text('使用外部模型'), findsOneWidget);
    await tester.tap(find.text('MNN'));
    await tester.pumpAndSettle();
    expect(find.text('将MNN模型复制到应用'), findsOneWidget);
    await tester.tap(find.byKey(const Key('model_add_copy')));
    await tester.pumpAndSettle();
    expect(library.imported, [InferenceEngine.mnn]);
    expect(find.text('Imported MNN'), findsOneWidget);
  });

  testWidgets('models and pending downloads share the search field', (
    tester,
  ) async {
    library.entries = [
      _model('Gemma', InferenceEngine.llamaCpp),
      _model('Qwen MNN', InferenceEngine.mnn),
    ];
    downloads.entries = [
      DownloadTaskView(
        DownloadTaskRecord(
          id: 'download',
          engineValue: 'llama_cpp',
          sourceValue: 'hugging_face',
          repoId: 'org/qwen',
          revision: 'main',
          modelName: 'Qwen GGUF',
          files: const [],
          statusValue: DownloadStatus.paused.name,
          createdAt: DateTime(2026),
          stagingDirPath: '/downloads/qwen',
        ),
      ),
    ];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Gemma'), findsOneWidget);
    expect(find.text('Qwen GGUF'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('model_library_search_input')),
      'Qwen',
    );
    await tester.pump();
    expect(find.text('Gemma'), findsNothing);
    expect(find.text('Qwen MNN'), findsOneWidget);
    expect(find.text('Qwen GGUF'), findsOneWidget);
    await tester.tap(find.byKey(const Key('model_library_search_clear')));
    await tester.pump();
    expect(find.text('Gemma'), findsOneWidget);
  });

  for (final engine in InferenceEngine.values) {
    testWidgets('${engine.displayName} configuration saves the model name', (
      tester,
    ) async {
      library.entries = [_model('Qwen', engine)];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('${engine.displayName} · 1.00 GB'), findsOneWidget);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      final icon = tester.widget<AiIdentityIcon>(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(AiIdentityIcon),
        ),
      );
      expect(icon.model, 'Qwen');
      final prefix = engine == InferenceEngine.mnn
          ? 'mnn_model_settings'
          : 'model_settings';
      await tester.enterText(
        find.byKey(Key('${prefix}_name_field')),
        'Renamed model',
      );
      await tester.pump();
      await tester.tap(find.byKey(Key('${prefix}_save_name_button')));
      await tester.pumpAndSettle();
      expect(library.entries.single.name, 'Renamed model');
    });
  }

  testWidgets('model deletion requires confirmation and updates the list', (
    tester,
  ) async {
    library.entries = [_model('Qwen', InferenceEngine.llamaCpp)];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(library.entries, hasLength(1));
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('删除')),
    );
    await tester.pumpAndSettle();
    expect(library.entries, isEmpty);
    expect(find.text('还没有模型'), findsOneWidget);
  });
}

LibraryModel _model(String name, InferenceEngine engine) => LibraryModel(
  id: engine.storageValue,
  runtimeId: name,
  engine: engine,
  name: name,
  sizeBytes: 1073741824,
  importedAt: DateTime(2026),
  storagePath: '/models/${engine.storageValue}/model.gguf',
);

class _Library extends ModelManagementProvider {
  List<LibraryModel> entries = [];
  final imported = <InferenceEngine>[];
  @override
  List<LibraryModel> get libraryModels => entries;
  @override
  List<LibraryModel> libraryModelsFor(InferenceEngine engine) =>
      entries.where((m) => m.engine == engine).toList();
  @override
  List<ModelDescriptor> get models => entries
      .where((m) => m.engine == InferenceEngine.llamaCpp)
      .map(
        (m) => ModelDescriptor(
          id: m.id,
          modelName: m.name,
          sizeBytes: m.sizeBytes,
          storedDirectoryPath: '/models',
          storedFilePath: m.storagePath,
          importedAt: m.importedAt,
        ),
      )
      .toList();
  @override
  Future<void> load() async {}
  Future<String?> _import(InferenceEngine engine) async {
    imported.add(engine);
    entries.add(
      _model(
        engine == InferenceEngine.mnn ? 'Imported MNN' : 'Imported GGUF',
        engine,
      ),
    );
    notifyListeners();
    return null;
  }

  @override
  Future<String?> importModel() => _import(InferenceEngine.llamaCpp);
  @override
  Future<String?> importMnnModelDirectory() => _import(InferenceEngine.mnn);
  @override
  Future<String?> renameModel(String id, String name) =>
      renameLibraryModel(entries.singleWhere((m) => m.id == id), name);
  @override
  Future<String?> renameLibraryModel(LibraryModel model, String name) async {
    entries = entries
        .map((m) => m.id == model.id ? _model(name, m.engine) : m)
        .toList();
    notifyListeners();
    return null;
  }

  @override
  Future<String> deleteLibraryModel(LibraryModel model) async {
    entries.removeWhere((m) => m.id == model.id);
    notifyListeners();
    return '';
  }
}

class _Downloads extends DownloadProvider {
  List<DownloadTaskView> entries = [];
  @override
  List<DownloadTaskView> get tasks => entries;
  @override
  Future<void> load({bool startTransfers = true}) async {}
}
