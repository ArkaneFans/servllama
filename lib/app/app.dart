import 'package:servllama/shared/navigation/app_navigation_observer.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/main_scaffold.dart';
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
          if (AgentToolService.current != null)
            ChangeNotifierProvider.value(value: AgentToolService.current!),
          ChangeNotifierProvider(
            create: (_) {
              final provider = AppLocaleProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = AppThemeModeProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = ChatTimeoutProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = EngineRuntimeProvider();
              unawaited(provider.restore());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final p = AssistantProvider();
              unawaited(p.load());
              return p;
            },
          ),
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
              unawaited(provider.load());
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
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = ModelDiscoveryProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
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
              unawaited(service.initialize());
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
                home: const MainScaffold(),
              ),
        ),
      ),
    );
  }
}
