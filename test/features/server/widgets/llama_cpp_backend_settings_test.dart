import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/services/llama_cpp_device_probe_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/server/widgets/llama_cpp_backend_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/stub_engine_adapter.dart';

void main() {
  late ServerConfigProvider provider;
  late EngineRuntimeProvider runtime;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = ServerConfigProvider(
      kvStorage: KvStorage(),
      llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
        resultOverride: () => const LlamaCppDeviceProbeResult(
          openclDeviceName: 'GPUOpenCL',
          hexagonDeviceName: 'HTP0',
        ),
      ),
    );
    runtime = EngineRuntimeProvider(
      llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
      mnnAdapter: StubEngineAdapter(),
    );
  });

  tearDown(() {
    provider.dispose();
    runtime.dispose();
  });

  Future<void> showSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
            ChangeNotifierProvider<ServerConfigProvider>.value(value: provider),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(child: LlamaCppBackendSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only backends on the llama.cpp allowlist', (tester) async {
    await showSettings(tester);

    for (final backend in LlamaCppBackend.values) {
      final tile = find.byKey(Key('llama_cpp_backend_${backend.name}'));
      expect(
        tile,
        ServerLaunchSettings.supportedLlamaCppBackends.contains(backend)
            ? findsOneWidget
            : findsNothing,
      );
    }

    expect(find.byKey(const Key('llama_cpp_backend_opencl')), findsNothing);

    await tester.tap(find.byKey(const Key('llama_cpp_backend_hexagon')));
    await tester.pumpAndSettle();
    expect(provider.llamaCppBackend, LlamaCppBackend.hexagon);
    expect(find.byKey(const Key('llama_cpp_gpu_layers')), findsOneWidget);

    await tester.tap(find.byKey(const Key('llama_cpp_backend_cpu')));
    await tester.pumpAndSettle();
    expect(provider.llamaCppBackend, LlamaCppBackend.cpu);
    expect(find.byKey(const Key('llama_cpp_gpu_layers')), findsNothing);
  });

  testWidgets('disables accelerators the probe did not find', (tester) async {
    provider.dispose();
    provider = ServerConfigProvider(
      kvStorage: KvStorage(),
      llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
        resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
      ),
    );
    await showSettings(tester);

    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('llama_cpp_backend_cpu')))
          .onTap,
      isNotNull,
    );
    expect(find.byKey(const Key('llama_cpp_backend_opencl')), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('llama_cpp_backend_hexagon')))
          .onTap,
      isNull,
    );
    expect(find.byKey(const Key('llama_cpp_gpu_layers')), findsNothing);
  });
  const savedUnavailableText = '已保存的后端当前不可用，请在启动前改选其他后端，或使用自动。';

  testWidgets(
    'does not warn that the saved backend is unavailable before probing',
    (tester) async {
      provider.dispose();
      SharedPreferences.setMockInitialValues({
        ServerPrefsKeys.llamaCppBackend: LlamaCppBackend.hexagon.name,
      });
      provider = ServerConfigProvider(
        kvStorage: KvStorage(),
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () =>
              const LlamaCppDeviceProbeResult(hexagonDeviceName: 'HTP0'),
        ),
      );
      await provider.load();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<EngineRuntimeProvider>.value(
                value: runtime,
              ),
              ChangeNotifierProvider<ServerConfigProvider>.value(
                value: provider,
              ),
            ],
            child: const Scaffold(
              body: SingleChildScrollView(child: LlamaCppBackendSettings()),
            ),
          ),
        ),
      );

      expect(find.text(savedUnavailableText), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text(savedUnavailableText), findsNothing);
    },
  );

  testWidgets('warns after probing when the saved accelerator is unavailable', (
    tester,
  ) async {
    provider.dispose();
    SharedPreferences.setMockInitialValues({
      ServerPrefsKeys.llamaCppBackend: LlamaCppBackend.hexagon.name,
    });
    provider = ServerConfigProvider(
      kvStorage: KvStorage(),
      llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
        resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
      ),
    );
    await provider.load();
    await showSettings(tester);

    expect(find.text(savedUnavailableText), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('llama_cpp_backend_hexagon')))
          .subtitle,
      isA<Text>().having((text) => text.data, 'data', '此设备不可用。'),
    );
  });
}
