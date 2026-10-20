import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/widgets/speech_catalog_card.dart';
import 'package:servllama/features/speech/pages/speech_models_page.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import '../../speech/speech_test_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('speech presets filter by engine, size, clone and reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = SpeechHarness();
    await tester.runAsync(h.initialize);
    addTearDown(() => tester.runAsync(h.close));
    final discovery = ModelDiscoveryProvider(
      catalogService: _EmptyCatalogService(),
      capabilityService: _UnknownCapabilityService(),
      settingsStore: _MemoryDownloadSettingsStore(),
      huggingFaceClient: _WidgetFakeHubClient(ModelHubSource.huggingFace),
      modelScopeClient: _WidgetFakeHubClient(ModelHubSource.modelScope),
    );
    addTearDown(discovery.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ModelDiscoveryProvider>.value(
            value: discovery,
          ),
          ChangeNotifierProvider<SpeechJobService>.value(value: h.service),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelDiscoveryPage(initialPurpose: 'speech'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNWidgets(4));
    expect(find.text('导入语音模型包'), findsNothing);
    await tester.tap(find.text('不超过 200 MiB'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNWidgets(3));
    await tester.tap(find.text('不超过 200 MiB'));
    await tester.tap(find.widgetWithText(FilterChip, '声音克隆'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsOneWidget);
    await tester.tap(find.text('重置筛选'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).first, 'sherpa-onnx');
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('用途: 转录').last);
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '声音克隆'), findsNothing);
    final package = h.service.models.catalog.firstWhere(
      (p) => p.recipe == SpeechRecipe.sherpaWhisper,
    );
    final paused = (await tester.runAsync(
      () => h.service.models.createAsset(package),
    ))!;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安装状态: 未安装').last);
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNothing);
    await tester.tap(find.byType(DropdownButton<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安装状态: 已暂停 / 未完成').last);
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsOneWidget);
    expect(h.service.models.assetForPackage(package)?.id, paused.id);
    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引擎: CrispASR').last);
    await tester.pumpAndSettle();
    expect(find.byType(SpeechCatalogCard), findsNothing);

    expect(find.text('没有匹配的模型'), findsOneWidget);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    final searchFocus = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode;
    expect(searchFocus.hasFocus, isTrue);
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(searchFocus.hasFocus, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'installed speech has use action and no ZIP or catalog in library',
    (tester) async {
      final h = SpeechHarness();
      await tester.runAsync(h.initialize);
      addTearDown(() => tester.runAsync(h.close));
      final asset = (await tester.runAsync(h.model))!;
      final package = SpeechPackage.fromJson(asset.manifest);
      Widget host(Widget child) =>
          ChangeNotifierProvider<SpeechJobService>.value(
            value: h.service,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: child,
            ),
          );
      await tester.pumpWidget(host(const SpeechModelsPage()));
      await tester.pumpAndSettle();
      expect(find.text('导入语音模型包'), findsNothing);
      expect(find.byType(SpeechCatalogCard), findsNothing);
      expect(find.text('发现模型'), findsOneWidget);
      await tester.pumpWidget(
        host(Scaffold(body: SpeechCatalogCard(package: package))),
      );
      await tester.pumpAndSettle();
      expect(find.text('下载模型'), findsNothing);
      await tester.tap(find.text('合成'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeechPage), findsOneWidget);
      expect(
        tester.widget<SpeechPage>(find.byType(SpeechPage)).initialKind,
        asset.kind,
      );
      expect(h.service.ttsId, asset.id);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('uses one source, queries all initially, and scrolls for more', (
    tester,
  ) async {
    final huggingFace = _WidgetFakeHubClient(ModelHubSource.huggingFace);
    final modelScope = _WidgetFakeHubClient(ModelHubSource.modelScope);
    final provider = ModelDiscoveryProvider(
      catalogService: _EmptyCatalogService(),
      capabilityService: _UnknownCapabilityService(),
      settingsStore: _MemoryDownloadSettingsStore(),
      huggingFaceClient: huggingFace,
      modelScopeClient: modelScope,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ModelDiscoveryProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelDiscoveryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(huggingFace.calls.single.query, '');
    expect(huggingFace.calls.single.pageToken, isNull);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    expect(find.text('全部来源'), findsNothing);
    expect(find.text('全部格式'), findsNothing);
    expect(find.text('GGUF'), findsOneWidget);
    expect(find.text('MNN'), findsNothing);
    expect(provider.formatFilter, HubFormatFilter.gguf);
    expect(provider.searchSort, HubSearchSort.trending);
    expect(find.text('综合'), findsOneWidget);
    expect(find.text('喜欢数'), findsOneWidget);
    expect(find.text('共 10 个结果'), findsNothing);
    expect(find.textContaining('可用内存'), findsNothing);
    expect(find.textContaining('真机验证'), findsNothing);
    expect(find.textContaining('直接来自仓库'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Hugging Face')).dx,
      moreOrLessEquals(tester.getTopLeft(find.text('综合')).dx),
    );

    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -4000),
      5000,
    );
    await tester.pumpAndSettle();

    expect(huggingFace.calls.any((call) => call.pageToken == '2'), isTrue);
    expect(provider.searchResults, hasLength(11));

    await tester.tap(find.text('魔搭 ModelScope'));
    await tester.pumpAndSettle();

    expect(find.text('GGUF'), findsWidgets);
    expect(find.text('MNN'), findsWidgets);
    expect(provider.formatFilter, HubFormatFilter.gguf);
    expect(modelScope.calls.map((call) => call.format), <HubModelFormat>[
      HubModelFormat.gguf,
    ]);

    await tester.tap(find.text('MNN').last);
    await tester.pumpAndSettle();
    expect(provider.formatFilter, HubFormatFilter.mnn);
    expect(modelScope.calls.map((call) => call.format), <HubModelFormat>[
      HubModelFormat.gguf,
      HubModelFormat.mnn,
    ]);
  });
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
  DownloadSettings _settings = const DownloadSettings();

  @override
  Future<DownloadSettings> load() async => _settings;

  @override
  Future<void> savePreferredSource(ModelHubSource source) async {
    _settings = _settings.copyWith(preferredSource: source);
  }
}

class _SearchCall {
  const _SearchCall(this.query, this.format, this.pageToken, this.sort);

  final String query;
  final HubModelFormat format;
  final String? pageToken;
  final HubSearchSort sort;
}

class _WidgetFakeHubClient implements ModelHubClient {
  _WidgetFakeHubClient(this.source);

  @override
  final ModelHubSource source;
  final List<_SearchCall> calls = <_SearchCall>[];

  @override
  Set<HubModelFormat> get searchableFormats =>
      source == ModelHubSource.huggingFace
      ? const <HubModelFormat>{HubModelFormat.gguf}
      : const <HubModelFormat>{HubModelFormat.gguf, HubModelFormat.mnn};

  @override
  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    HubSearchSort sort = HubSearchSort.trending,
    int limit = ModelHubClient.defaultSearchLimit,
    String? pageToken,
  }) async {
    calls.add(_SearchCall(query, format, pageToken, sort));
    if (source == ModelHubSource.huggingFace) {
      final start = pageToken == null ? 0 : ModelHubClient.defaultSearchLimit;
      final count = pageToken == null ? ModelHubClient.defaultSearchLimit : 1;
      return HubSearchPage(
        items: List<HubRepoSummary>.generate(
          count,
          (index) => _summary(format, start + index),
          growable: false,
        ),
        nextPageToken: pageToken == null ? '2' : null,
      );
    }
    return HubSearchPage(items: <HubRepoSummary>[_summary(format, 0)]);
  }

  HubRepoSummary _summary(HubModelFormat format, int index) => HubRepoSummary(
    source: source,
    format: format,
    repoId: '${source.storageValue}/${format.name}-$index',
    owner: source.storageValue,
    name: '${format.name}-$index',
    downloads: 100 - index,
  );

  @override
  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  }) => throw UnimplementedError();

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) => '';

  @override
  Map<String, String> authHeaders(String? token) => const <String, String>{};
}
