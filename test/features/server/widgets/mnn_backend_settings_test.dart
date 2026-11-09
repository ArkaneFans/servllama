import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/server/widgets/mnn_backend_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_mnn_backend_service.dart';
import '../../../support/stub_engine_adapter.dart';

void main() {
  late FakeMnnBackendService service;
  late ServerConfigProvider provider;
  late EngineRuntimeProvider runtime;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeMnnBackendService()..activeBackend = MnnBackend.cpu;
    provider = ServerConfigProvider(
      kvStorage: KvStorage(),
      mnnBackendService: service,
    );
    runtime = EngineRuntimeProvider(
      llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
      mnnAdapter: StubEngineAdapter(),
    );
  });
  tearDown(() async {
    provider.dispose();
    runtime.dispose();
    await service.dispose();
  });

  Future<void> showSettings(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
            ChangeNotifierProvider<ServerConfigProvider>.value(value: provider),
          ],
          child: AppScaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  MnnBackendSettings(),
                  SizedBox(height: 18),
                  MnnRuntimeSettings(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('probe failure offers retry and recovers backend choices', (
    tester,
  ) async {
    service.error = StateError('device probe failed');
    await showSettings(tester);
    expect(find.textContaining('无法检测可用后端'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('mnn_backend_cpu'))).onTap,
      isNotNull,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('mnn_backend_vulkan')))
          .onTap,
      isNull,
    );
    service.error = null;
    await tester.tap(find.byKey(const Key('mnn_backend_refresh')));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法检测可用后端'), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('mnn_backend_vulkan')))
          .onTap,
      isNotNull,
    );
  });

  testWidgets('exposes mmap, precision, threads and cache clearing', (
    tester,
  ) async {
    service.mmapCacheBytes = 2048;
    await showSettings(tester);
    expect(find.byKey(const Key('mnn_runtime_settings')), findsOneWidget);
    expect(find.byKey(const Key('mnn_precision')), findsOneWidget);
    expect(find.byKey(const Key('mnn_thread_num')), findsOneWidget);
    expect(find.byKey(const Key('mnn_use_mmap')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mnn_use_mmap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mnn_use_mmap')));
    await tester.pumpAndSettle();
    expect(provider.mnnUseMmap, isTrue);

    await tester.ensureVisible(find.byKey(const Key('mnn_clear_mmap_cache')));
    await tester.tap(find.byKey(const Key('mnn_clear_mmap_cache')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('清理'));
    await tester.pumpAndSettle();
    expect(provider.mnnMmapCacheBytes, 0);
    expect(find.textContaining('已清理'), findsOneWidget);
  });
}
