import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';
import 'package:servllama/features/assistants/pages/connections_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/provider_model_picker.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';
import 'package:servllama/features/assistants/widgets/model_capabilities_sheet.dart';

const _cloud = AiConnection(
  id: 'cloud',
  name: 'Cloud fixture',
  protocol: AiProtocol.openai,
  baseUrl: 'https://example.com/v1',
  models: ['kept'],
  secretRef: 'stored-ref',
);
const _local = ModelAsset(
  id: 'gguf',
  kind: AssetKind.llm,
  engine: 'llama_cpp',
  runtimeId: 'runtime-gguf',
  storageOwner: 'fixture',
  path: '/fixture/gguf',
  name: 'Local GGUF',
  revision: '1',
);

class _Settings extends AssistantProvider {
  List<String> discovered = ['kept', 'new', 'other'];
  bool failDiscovery = false, blockDiscovery = false, sawClearKey = false;
  CancelToken? discoveryToken;
  _Settings() {
    loaded = true;
    connections = [
      _cloud,
      _cloud.changed({
        'id': 'off',
        'name': 'Disabled fixture',
        'enabled': false,
        'models': ['blocked'],
      }),
    ];
    assets = [
      _local,
      const ModelAsset(
        id: 'mnn',
        kind: AssetKind.llm,
        engine: 'mnn',
        runtimeId: 'runtime-mnn',
        storageOwner: 'fixture',
        path: '/fixture/mnn',
        name: 'Local MNN',
        revision: '1',
      ),
    ];
  }
  @override
  Future<void> refreshAssets() async {}
  @override
  Future<void> saveConnection(
    AiConnection c, {
    String? key,
    bool clearKey = false,
  }) async {
    c.validate();
    connections = [
      for (final old in connections)
        if (old.id == c.id) c.changed({'revision': old.revision + 1}) else old,
    ];
    notifyListeners();
  }

  @override
  Future<void> deleteConnection(String id) async {
    connections.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  @override
  Future<List<String>> discover(
    AiConnection draft,
    String typedKey, {
    bool clearKey = false,
    CancelToken? cancelToken,
  }) async {
    sawClearKey = clearKey;
    discoveryToken = cancelToken;
    if (blockDiscovery) throw await cancelToken!.whenCancel;
    if (failDiscovery) throw StateError('Fixture discovery failure');
    return discovered;
  }
}

class _Runtime extends Fake
    with ChangeNotifier
    implements EngineRuntimeProvider {
  @override
  EngineRuntimeState state = const EngineRuntimeState(
    engine: InferenceEngine.llamaCpp,
  );
  @override
  bool isPublished = false;
  @override
  bool get isRunning => state.isRunning;
  @override
  bool get isBusy => state.isBusy;
  @override
  InferenceEngine get activeEngine => state.engine;
  @override
  String? get activeModelId => state.activeModelId;
  @override
  String? get selectedModelId => state.activeModelId;
}

void main() {
  late _Settings settings;
  late _Runtime runtime;
  setUp(() {
    settings = _Settings();
    runtime = _Runtime();
  });
  tearDown(() {
    settings.dispose();
    runtime.dispose();
  });
  Widget app(Widget home, {double scale = 1, double keyboard = 0}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssistantProvider>.value(value: settings),
          ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorObservers: [AppNavigationObserver()],
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: home,
        ),
      );
  Widget editorLauncher() => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConnectionEditor(connection: settings.connections.first),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
  Widget pickerLauncher({Future<void> Function(ChatTarget)? onSelected}) =>
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showChatTargetPicker(
              context,
              initialTarget: const ChatTarget.remote('cloud', 'kept'),
              onSelected: onSelected,
            ),
            child: const Text('Pick'),
          ),
        ),
      );
  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('provider_models_tab')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('provider_models')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fetch(WidgetTester tester) async {
    final button = find.byKey(const Key('provider_fetch_models'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'configuration and models share a draft; capabilities save per model',
    (tester) async {
      settings.connections = [
        _cloud.changed({
          'models': ['kept', 'other'],
        }),
      ];
      await tester.pumpWidget(app(editorLauncher()));
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('provider_name')), 'Renamed');
      expect(find.byKey(const Key('model_images')), findsNothing);
      await tester.tap(find.byKey(const Key('provider_models_tab')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      final row = find.byKey(const ValueKey('provider_model_kept'));
      await reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model_images')));
      await tester.tap(find.byKey(const Key('model_tools')));
      await tester.tap(find.byKey(const Key('model_capabilities_done')));
      await tester.pumpAndSettle();
      expect(
        settings.connections.first.capabilitiesFor('kept').supportsImages,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('provider_config_tab')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('provider_name')))
            .controller!
            .text,
        'Renamed',
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(ConnectionEditor)),
      )!;
      await tester.tap(find.text(l.commonSave));
      await tester.pumpAndSettle();
      final saved = settings.connections.first;
      expect(saved.name, 'Renamed');
      expect(saved.capabilitiesFor('kept').supportsImages, isFalse);
      expect(saved.capabilitiesFor('kept').supportsTools, isFalse);
      expect(saved.capabilitiesFor('other').supportsImages, isTrue);
      expect(saved.capabilitiesFor('other').supportsTools, isTrue);
      await openEditor(tester);
      await reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model_images')));
      await tester.tap(find.byKey(const Key('model_capabilities_done')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        settings.connections.first.capabilitiesFor('kept').supportsImages,
        isFalse,
      );
    },
  );

  testWidgets(
    'model capability sheet fits narrow large text and cancels without applying',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(editorLauncher(), scale: 1.6));
      await openEditor(tester);
      await tester.tap(find.byKey(const Key('provider_models_tab')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('provider_model_kept'));
      await reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ModelCapabilitiesSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('model_images')));
      await tester.tap(find.byKey(const Key('model_capabilities_close')));
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('model_images')))
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker keeps provider headings simple and local status inline', (
    tester,
  ) async {
    await tester.pumpWidget(app(pickerLauncher()));
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    final local = tester.widget<ListTile>(
      find.byKey(const ValueKey('chat_target_local_gguf')),
    );
    expect(local.subtitle, isNull);
    expect(find.byIcon(Icons.folder_outlined), findsNothing);
    expect(find.byIcon(Icons.stop_circle_outlined), findsWidgets);
    expect(find.byKey(const Key('chat_target_search')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_target_close')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatTargetPicker), findsNothing);
  });

  testWidgets(
    'preset rows cannot be deleted and enable toggles preserve models',
    (tester) async {
      settings.connections = [providerPresets.first, _cloud];
      await tester.pumpWidget(app(const ConnectionsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Local · llama.cpp'), findsNothing);
      expect(find.text('Local · MNN'), findsNothing);
      final preset = find.byKey(const ValueKey('provider_preset:openai'));
      expect(
        find.descendant(
          of: preset,
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('provider_enabled_preset:openai')),
      );
      await tester.pumpAndSettle();
      expect(settings.connections.first.enabled, isTrue);
      expect(settings.connections.last.models, ['kept']);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('provider_cloud')),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual model validation, save and discarded removal form a complete edit flow',
    (tester) async {
      await tester.pumpWidget(app(editorLauncher()));
      await openEditor(tester);
      final add = find.byKey(const Key('provider_add_model'));
      await reveal(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AddProviderModelDialog)),
      )!;
      await tester.enterText(
        find.byKey(const Key('provider_manual_model')),
        ' kept ',
      );
      await tester.tap(find.text(l.v2Add));
      await tester.pump();
      expect(find.text(l.v2ModelAlreadyAdded), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('provider_manual_model')),
        ' new-model ',
      );
      await tester.tap(find.text(l.v2Add));
      await tester.pumpAndSettle();
      expect(settings.connections.first.models, ['kept']);
      await tester.tap(find.text(l.commonSave));
      await tester.pumpAndSettle();
      expect(settings.connections.first.models, ['kept', 'new-model']);
      expect(
        settings.connections.first.capabilitiesFor('new-model').toJson(),
        ModelCapabilities.textOnly.toJson(),
      );
      await openEditor(tester);
      final row = find.byKey(const ValueKey('provider_model_new-model'));
      await reveal(tester, row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.v2RemoveModelHelp('new-model')), findsOneWidget);
      await tester.tap(find.text(l.commonDelete));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(settings.connections.first.models, ['kept', 'new-model']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discovery adds only selected candidates; cancel and failure preserve the list',
    (tester) async {
      await tester.pumpWidget(app(editorLauncher()));
      await openEditor(tester);
      await fetch(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(ProviderModelPicker)),
      )!;
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('provider_candidate_kept')),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('provider_candidate_new')));
      await tester.tap(find.text(l.commonCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('provider_model_new')), findsNothing);
      await fetch(tester);
      await tester.enterText(
        find.byKey(const Key('provider_model_search')),
        'other',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('provider_candidate_other')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('provider_add_selected')));
      await tester.pumpAndSettle();
      expect(settings.connections.first.models, ['kept']);
      settings.failDiscovery = true;
      await fetch(tester);
      expect(find.byType(ProviderModelPicker), findsNothing);
      await tester.tap(find.text(l.commonSave));
      await tester.pumpAndSettle();
      expect(settings.connections.first.models, ['kept', 'other']);
      expect(
        settings.connections.first.capabilitiesFor('other').toJson(),
        ModelCapabilities.textOnly.toJson(),
      );
    },
  );

  testWidgets('leaving the editor cancels its model request without saving', (
    tester,
  ) async {
    settings.blockDiscovery = true;
    await tester.pumpWidget(app(editorLauncher()));
    await openEditor(tester);
    final button = find.byKey(const Key('provider_fetch_models'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.discoveryToken!.isCancelled, isTrue);
    expect(settings.connections.first.models, ['kept']);
  });

  testWidgets(
    'provider management and model selection preserve catalog order',
    (tester) async {
      settings.connections = [
        _cloud.changed({'id': 'zulu', 'name': 'Zulu provider'}),
        _cloud.changed({
          'id': 'disabled',
          'name': 'Disabled provider',
          'enabled': false,
        }),
        _cloud.changed({'id': 'alpha', 'name': 'Alpha provider'}),
      ];
      await tester.pumpWidget(app(const ConnectionsPage()));
      await tester.pumpAndSettle();
      final zulu = find.byKey(const ValueKey('provider_zulu'));
      final disabled = find.byKey(const ValueKey('provider_disabled'));
      final alpha = find.byKey(const ValueKey('provider_alpha'));
      expect(
        tester.getTopLeft(zulu).dy,
        lessThan(tester.getTopLeft(disabled).dy),
      );
      expect(
        tester.getTopLeft(disabled).dy,
        lessThan(tester.getTopLeft(alpha).dy),
      );

      await tester.pumpWidget(app(pickerLauncher()));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'provider',
      );
      await tester.pumpAndSettle();
      expect(find.text('Disabled provider'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Zulu provider')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha provider')).dy),
      );
    },
  );

  testWidgets(
    'model sheet searches providers and models and hides disabled providers and their models',
    (tester) async {
      ChatTarget? picked;
      await tester.pumpWidget(
        app(
          pickerLauncher(
            onSelected: (target) async {
              picked = target;
            },
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Local · llama.cpp'), findsOneWidget);
      expect(find.text('Local · MNN'), findsOneWidget);
      final localRow = tester.widget<ListTile>(
        find.byKey(const ValueKey('chat_target_local_gguf')),
      );
      final remoteRow = tester.widget<ListTile>(
        find.byKey(const ValueKey('chat_target_remote_cloud_kept')),
      );
      expect(localRow.trailing, isNull);
      expect(remoteRow.trailing, isNull);
      expect(remoteRow.selected, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat_target_local_gguf')),
          matching: find.byIcon(Icons.stop_circle_outlined),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'Disabled fixture',
      );
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Disabled fixture'), findsNothing);
      expect(
        find.byKey(const ValueKey('chat_target_remote_off_blocked')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'blocked',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat_target_remote_off_blocked')),
        findsNothing,
      );
      expect(picked, isNull);
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'Cloud fixture',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('chat_target_remote_cloud_kept')),
      );
      await tester.pumpAndSettle();
      expect(picked?.connectionId, 'cloud');
      expect(picked?.modelId, 'kept');
      expect(find.byType(ChatTargetPicker), findsNothing);
    },
  );

  testWidgets(
    'local activation displays progress, ignores duplicate taps and closes on success',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        app(
          pickerLauncher(
            onSelected: (target) async {
              calls++;
              expect(target.assetId, 'gguf');
              runtime.state = runtime.state.copyWith(
                status: EngineRuntimeStatus.preparing,
                activeModelId: 'runtime-gguf',
              );
              runtime.notifyListeners();
              await gate.future;
              runtime.state = runtime.state.copyWith(
                status: EngineRuntimeStatus.ready,
              );
              runtime.notifyListeners();
            },
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('chat_target_local_gguf'));
      await tester.tap(row);
      await tester.pump();
      expect(find.byType(ChatTargetPicker), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(row);
      expect(calls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ChatTargetPicker), findsNothing);
    },
  );

  testWidgets(
    'activation failures keep the sheet open for retry and published models stay protected',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          pickerLauncher(
            onSelected: (_) async {
              if (++calls == 1) throw StateError('Fixture load failed');
            },
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('chat_target_local_gguf'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ChatTargetPicker), findsOneWidget);
      expect(
        find.byKey(const Key('chat_target_error')).hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('Fixture load failed'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(calls, 2);
      runtime.isPublished = true;
      runtime.state = runtime.state.copyWith(
        status: EngineRuntimeStatus.ready,
        activeModelId: 'runtime-gguf',
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(row).enabled, isTrue);
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('chat_target_local_mnn')),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'candidate and provider search layouts fit a narrow large-text keyboard view',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(pickerLauncher(), scale: 1.8, keyboard: 260));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'kept',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('chat_target_close')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<List<String>>(
                  context: context,
                  builder: (_) => ProviderModelPicker(
                    models: List.generate(200, (i) => 'model-$i'),
                    existing: const {},
                  ),
                ),
                child: const Text('Candidates'),
              ),
            ),
          ),
          scale: 1.8,
          keyboard: 260,
        ),
      );
      await tester.tap(find.text('Candidates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('provider_model_search')),
        '199',
      );
      await tester.pump();
      final last = find.byKey(const ValueKey('provider_candidate_model-199'));
      await tester.scrollUntilVisible(
        last,
        120,
        scrollable: find
            .descendant(
              of: find.byType(ProviderModelPicker),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
