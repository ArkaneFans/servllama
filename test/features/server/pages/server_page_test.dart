import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/engines/llama_cpp_engine_adapter.dart';

import '../../../support/stub_engine_adapter.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/features/server/widgets/runtime_hero_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerPage', () {
    setUp(() {
      AppL10nService.instance.setLocale(const Locale('zh'));
      // start() checks the notification-permission flag through KvStorage;
      // unmocked it throws after the test body has already finished.
      SharedPreferences.setMockInitialValues(<String, Object>{
        // Marking the prompt as already shown keeps start() away from the
        // foreground-task permission channel, whose future never resolves
        // under the test clock.
        'flutter.server.foreground_notification_permission_prompted': true,
      });
    });

    testWidgets('shows grouped layout, API Base URL and copies it', (
      tester,
    ) async {
      final serverService = _ControllableLlamaServerService();
      // The page re-reads the endpoint from settings when it mounts, so the
      // fixture has to come from the loader rather than a setEndpoint call
      // that the refresh would overwrite.
      const settings = ServerLaunchSettings(
        listenMode: ServerListenMode.allInterfaces,
        port: 9000,
      );
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(settings),
          modelRepository: _FixedModelStoragePaths(r'C:\app\models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(settings),
        localIpResolver: () async => null,
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('server_page_status_card')), findsOneWidget);
      expect(find.byKey(const Key('server_page_menu_group')), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('未运行'), findsOneWidget);
      expect(
        find.byKey(const Key('server_page_base_url_panel')),
        findsOneWidget,
      );
      expect(find.text('http://0.0.0.0:9000'), findsOneWidget);
      expect(find.text('服务器配置'), findsOneWidget);
      expect(find.text('日志'), findsOneWidget);
      expect(find.text('模型管理'), findsOneWidget);

      await tester.tap(find.byTooltip('复制 API Base URL'));
      await tester.pump();

      // The idle URL is informational only; copy becomes available once the
      // service is actually reachable.
      expect(clipboardText, isNull);
      expect(find.text('API Base URL 已复制'), findsNothing);
    });

    testWidgets('shows last error when server startup fails', (tester) async {
      final serverService = _FailingLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(
              listenMode: ServerListenMode.allInterfaces,
              port: 11434,
            ),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(
            listenMode: ServerListenMode.allInterfaces,
            port: 11434,
          ),
        ),
        localIpResolver: () async => null,
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await serverProvider.selectModel('test-model');
      await tester.runAsync(() => serverProvider.start());

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('server_page_base_url_panel')),
        findsOneWidget,
      );
      expect(find.text('http://0.0.0.0:11434'), findsOneWidget);
      expect(find.text('服务启动失败，请查看日志。'), findsOneWidget);
      expect(serverProvider.canSwitchEngine, isTrue);

      final selector = find.byKey(const Key('server_engine_selector'));
      final mnnLabel = find.descendant(
        of: selector,
        matching: find.text('MNN'),
      );
      final mnnGesture = find.ancestor(
        of: mnnLabel,
        matching: find.byType(GestureDetector),
      );
      expect(
        find.ancestor(of: selector, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.widget<GestureDetector>(mnnGesture).onTap, isNotNull);
    });

    testWidgets('shows running state and stop action when server is running', (
      tester,
    ) async {
      final stopCompleter = Completer<bool>()..complete(true);
      final serverService = _ControllableLlamaServerService(
        initiallyRunning: true,
        stopCompleter: stopCompleter,
      );
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      // Not pumpAndSettle: the uptime ticker holds a periodic timer open for
      // as long as the runtime is up, so no frame is ever "settled".
      await tester.pump();

      expect(find.text('运行中'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('server_page_toggle_button')),
          matching: find.text('停止'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows busy loading state while starting server', (
      tester,
    ) async {
      final completer = Completer<bool>();
      final serverService = _ControllableLlamaServerService(
        startCompleter: completer,
      );
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        kvStorage: KvStorage(),
      );
      addTearDown(() async {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      await serverProvider.selectModel('test-model');
      await tester.pump();
      await tester.tap(find.byKey(const Key('server_page_toggle_button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('server_page_toggle_button')),
      );
      expect(button.onPressed, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('server_page_toggle_button')),
          matching: find.text('取消'),
        ),
        findsOneWidget,
      );
      final statusCard = find.byKey(const Key('server_page_status_card'));
      expect(
        find.descendant(of: statusCard, matching: find.text('启动服务')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('server_page_phase_list')), findsNothing);
      expect(find.text('编排期间锁定，完成后仍需停止服务才能切换引擎。'), findsNothing);
      expect(find.text('服务运行中不可切换引擎，需先停止服务。'), findsNothing);

      await tester.tap(find.byKey(const Key('server_page_toggle_button')));
      await tester.pump();
      completer.complete(false);
      await tester.runAsync(() async {
        for (
          var attempt = 0;
          attempt < 30 && serverProvider.isBusy;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    });

    testWidgets('shows the current orchestration phase in the status pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuntimeHeroCard(
              state: const EngineRuntimeState(
                engine: InferenceEngine.llamaCpp,
                status: EngineRuntimeStatus.preparing,
                phase: RuntimePhase.startingServer,
              ),
              displayUrl: 'http://127.0.0.1:8080',
              selectedModelId: null,
              selectedModelName: null,
              canStart: false,
              onSelectModel: () {},
              onToggle: () {},
              onCopyUrl: () {},
            ),
          ),
        ),
      );

      final statusCard = find.byKey(const Key('server_page_status_card'));
      expect(
        find.descendant(of: statusCard, matching: find.text('启动服务')),
        findsOneWidget,
      );
      expect(find.text('准备中'), findsNothing);
      expect(find.byKey(const Key('server_page_phase_list')), findsNothing);
    });

    testWidgets('opens logs page from grouped menu', (tester) async {
      final serverService = _ControllableLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日志'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('日志')),
        findsOneWidget,
      );
    });

    testWidgets('menu item pressed state dims content and clears on cancel', (
      tester,
    ) async {
      final serverService = _ControllableLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      const targetKey = ValueKey<String>('server_page_menu_item_日志');
      final targetFinder = find.byKey(targetKey);

      double opacityOf(Finder finder) {
        final widget = tester.widget<AnimatedOpacity>(finder);
        return widget.opacity;
      }

      expect(opacityOf(targetFinder), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(targetFinder));
      await tester.pump(const Duration(milliseconds: 250));

      expect(opacityOf(targetFinder), lessThan(1.0));

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(opacityOf(targetFinder), 1.0);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.serverProvider});

  final EngineRuntimeProvider serverProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EngineRuntimeProvider>.value(
          value: serverProvider,
        ),
        // The page reads the unified library to name the selected model and
        // count entries in the menu; load() swallows its own I/O errors, so an
        // unseeded provider just yields an empty library here.
        ChangeNotifierProvider<ModelManagementProvider>(
          create: (_) => ModelManagementProvider(),
        ),
      ],
      child: const MaterialApp(home: ServerPage()),
    );
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _ControllableLlamaServerService implements LlamaServerService {
  _ControllableLlamaServerService({
    this.initiallyRunning = false,
    this.startCompleter,
    this.stopCompleter,
  }) : _isRunning = initiallyRunning;

  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();
  final bool initiallyRunning;
  final Completer<bool>? startCompleter;
  final Completer<bool>? stopCompleter;
  bool _isRunning;

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<String> loadBundledVersion() async => 'b9830';

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async {
    final started = await (startCompleter?.future ?? Future<bool>.value(true));
    if (started) {
      _isRunning = true;
      _runningStateController.add(true);
    }
    return started;
  }

  @override
  Future<bool> stopServer() async {
    final stopped = await (stopCompleter?.future ?? Future<bool>.value(true));
    if (stopped) {
      _isRunning = false;
      _runningStateController.add(false);
    }
    return stopped;
  }
}

class _FailingLlamaServerService extends _ControllableLlamaServerService {
  @override
  Future<bool> startServer({List<String>? args}) async => false;
}

class _FixedModelStoragePaths extends LocalModelRepository {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<List<ModelDescriptor>> listModels() async => <ModelDescriptor>[
    for (final name in const <String>['test-model', 'alpha', 'beta'])
      ModelDescriptor(
        id: name,
        modelName: name,
        sizeBytes: 1,
        storedDirectoryPath: '$modelsDirectoryPath/$name',
        storedFilePath: '$modelsDirectoryPath/$name/model.gguf',
        importedAt: DateTime(2026),
      ),
  ];
}
