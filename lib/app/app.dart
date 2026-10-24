import 'package:servllama/shared/navigation/app_navigation_observer.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/app/bootstrap/app_startup_gate.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/services/app_info_service.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class ServLlamaApp extends StatelessWidget {
  const ServLlamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MultiProvider(
        providers: [
          Provider(
            create: (_) => BundledSvgCache(),
            dispose: (_, cache) => cache.dispose(),
          ),
          Provider(create: (_) => AppInfoService()),
          if (AgentToolService.current != null)
            ChangeNotifierProvider.value(value: AgentToolService.current!),
          ChangeNotifierProvider(create: (_) => AppLocaleProvider()),
          ChangeNotifierProvider(create: (_) => AppThemeModeProvider()),
          ChangeNotifierProvider(create: (_) => ChatTimeoutProvider()),
          ChangeNotifierProvider(create: (_) => EngineRuntimeProvider()),
          ChangeNotifierProvider(create: (_) => AssistantProvider()),
          ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
          ChangeNotifierProvider(
            create: (context) {
              final runtime = context.read<EngineRuntimeProvider>();
              final provider = ModelManagementProvider(
                onModelDeleted: () =>
                    context.read<AssistantProvider>().refreshAssets(),
                onModelRenamed:
                    ({
                      required engine,
                      required oldModelId,
                      required newModelId,
                    }) => runtime.handleModelRenamed(
                      engine: engine,
                      oldModelId: oldModelId,
                      newModelId: newModelId,
                    ),
              );
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (context) {
              final modelManagement = context.read<ModelManagementProvider>();
              final provider = DownloadProvider(
                onLibraryChanged: modelManagement.refresh,
                modelNameCoordinator: modelManagement.nameCoordinator,
              );
              return provider;
            },
          ),
          ChangeNotifierProvider(create: (_) => ModelDiscoveryProvider()),
          ChangeNotifierProxyProvider3<
            EngineRuntimeProvider,
            ChatTimeoutProvider,
            AssistantProvider,
            ChatProvider
          >(
            create: (_) => ChatProvider(),
            update:
                (
                  _,
                  runtimeProvider,
                  chatTimeoutProvider,
                  assistants,
                  chatProvider,
                ) {
                  final provider = chatProvider ?? ChatProvider();
                  provider.bind(assistants, runtimeProvider);
                  provider.updateServerState(
                    baseUrl: runtimeProvider.baseUrl,
                    isServerRunning: runtimeProvider.isRunning,
                    engine: runtimeProvider.activeEngine,
                    activeModelId: runtimeProvider.activeModelId,
                    activeModelName: runtimeProvider.activeModelName,
                  );
                  provider.updateChatTimeout(chatTimeoutProvider.timeout);
                  return provider;
                },
          ),
          ChangeNotifierProvider(
            // Startup recovery belongs to the app, not an offstage speech tab.
            lazy: false,
            create: (context) {
              final service = SpeechJobService(
                context.read<EngineRuntimeProvider>().resources,
              );
              return service;
            },
          ),
        ],
        child: Consumer2<AppThemeModeProvider, AppLocaleProvider>(
          builder: (context, themeModeProvider, localeProvider, _) =>
              MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                debugShowCheckedModeBanner: false,
                navigatorObservers: [AppNavigationObserver()],
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: themeModeProvider.themeMode,
                locale: localeProvider.locale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: AppStartupGate(
                  initialize: _prepareState,
                  child: const MainScaffold(),
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _prepareState(BuildContext context) async {
    final assistants = context.read<AssistantProvider>();
    final runtime = context.read<EngineRuntimeProvider>();
    final themes = [AppTheme.light().colorScheme, AppTheme.dark().colorScheme];
    await Future.wait([
      context.read<AppLocaleProvider>().load(),
      context.read<AppThemeModeProvider>().load(),
      context.read<ChatTimeoutProvider>().load(),
      runtime.ensureRestored(),
      context.read<ServerConfigProvider>().load(),
      context.read<ModelManagementProvider>().load(),
      context.read<DownloadProvider>().load(),
      context.read<ModelDiscoveryProvider>().prepare(),
      context.read<AppInfoService>().load(),
      context.read<BundledSvgCache>().warmUp(
        identityColors: themes.map((c) => c.onSurface),
        mcpColors: themes.map((c) => c.onSurfaceVariant),
      ),
    ]);
    if (!context.mounted) return;
    // Asset reconciliation precedes consumers that read the same inventory.
    await assistants.load();
    if (!context.mounted) return;
    if (!assistants.loaded || assistants.error != null) {
      throw StateError('Application settings could not be restored');
    }
    await Future.wait([
      context.read<ChatProvider>().load(),
      context.read<SpeechJobService>().initialize(),
      if (AgentToolService.current != null)
        AgentToolService.current!.loadSkills(),
      if (AgentToolService.current != null)
        AgentToolService.current!.mcp.load(),
    ]);
  }
}
