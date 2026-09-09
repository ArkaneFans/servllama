import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/server/widgets/mnn_backend_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_mnn_backend_service.dart';

void main() {
  late FakeMnnBackendService service;
  late ServerConfigProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeMnnBackendService()..activeBackend = MnnBackend.cpu;
    provider = ServerConfigProvider(
      kvStorage: KvStorage(),
      mnnBackendService: service,
    );
  });
  tearDown(() async {
    provider.dispose();
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
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: MnnBackendSettings(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers GPU selection and explains unavailable Hexagon', (
    tester,
  ) async {
    await showSettings(tester);
    expect(find.text('已加载的后端：CPU'), findsOneWidget);
    expect(find.text('此安装包缺少兼容的 Hexagon 运行库。'), findsOneWidget);
    final hexagon = tester.widget<ListTile>(
      find.byKey(const Key('mnn_backend_hexagon')),
    );
    expect(hexagon.onTap, isNull);
    await tester.tap(find.byKey(const Key('mnn_backend_opencl')));
    await tester.pumpAndSettle();
    expect(provider.mnnBackend, MnnBackend.opencl);
    expect(find.text('已加载的后端：CPU'), findsOneWidget);
    expect(find.textContaining('下次加载模型时生效'), findsOneWidget);
  });

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

  testWidgets('fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showSettings(tester, textScale: 2);
    await tester.ensureVisible(find.byKey(const Key('mnn_backend_hexagon')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the automatic DSP match and allows selecting Hexagon', (
    tester,
  ) async {
    service.capabilities = [
      ...service.capabilities.where(
        (item) => item.backend != MnnBackend.hexagon,
      ),
      const MnnBackendCapability(
        backend: MnnBackend.hexagon,
        compiled: true,
        available: true,
        status: MnnBackendStatus.available,
        dspArchitecture: 'v79',
      ),
    ];
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showSettings(tester, textScale: 2);
    final hexagon = find.byKey(const Key('mnn_backend_hexagon'));
    await tester.ensureVisible(hexagon);
    await tester.pumpAndSettle();
    expect(find.textContaining('已自动匹配 v79 运行库'), findsOneWidget);
    expect(tester.widget<ListTile>(hexagon).onTap, isNotNull);
    await tester.tap(hexagon);
    await tester.pumpAndSettle();
    expect(provider.mnnBackend, MnnBackend.hexagon);
    expect(tester.takeException(), isNull);
  });
}
