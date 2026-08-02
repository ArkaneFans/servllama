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
    expect(find.text('GGUF'), findsOneWidget);
    expect(find.text('MNN'), findsNothing);
    expect(find.text('共 20 个结果'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Hugging Face')).dx,
      moreOrLessEquals(tester.getTopLeft(find.text('下载量')).dx),
    );

    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -4000),
      5000,
    );
    await tester.pumpAndSettle();

    expect(huggingFace.calls.any((call) => call.pageToken == '2'), isTrue);
    expect(provider.searchResults, hasLength(21));

    await tester.tap(find.text('魔搭 ModelScope'));
    await tester.pumpAndSettle();

    expect(find.text('MNN'), findsWidgets);
    expect(
      modelScope.calls.map((call) => call.format),
      unorderedEquals(<HubModelFormat>[
        HubModelFormat.gguf,
        HubModelFormat.mnn,
      ]),
    );
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
  const _SearchCall(this.query, this.format, this.pageToken);

  final String query;
  final HubModelFormat format;
  final String? pageToken;
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
    int limit = 20,
    String? pageToken,
  }) async {
    calls.add(_SearchCall(query, format, pageToken));
    if (source == ModelHubSource.huggingFace) {
      final start = pageToken == null ? 0 : 20;
      final count = pageToken == null ? 20 : 1;
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
