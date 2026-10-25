import 'dart:async';

import 'package:flutter/services.dart';
import 'package:servllama/app/bootstrap/app_idle_warmup.dart';
import 'package:servllama/app/bootstrap/app_startup_state.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/models/speech_models.dart';

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

class ServLlamaApp extends StatefulWidget {
  const ServLlamaApp({super.key, this.startupWatch, this.startup});
  final Stopwatch? startupWatch;
  final AppStartupState? startup;

  @override
  State<ServLlamaApp> createState() => _ServLlamaAppState();
}

class _ServLlamaAppState extends State<ServLlamaApp> {
  late final AppStartupState _startup;
  late final bool _preparedOnEntry;
  late final ValueNotifier<bool> _ready;

  @override
  void initState() {
    super.initState();
    _startup = widget.startup ?? AppStartupState();
    _preparedOnEntry = _startup.ready;
    _ready = ValueNotifier(_preparedOnEntry);
  }

  @override
  void dispose() {
    _ready.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MultiProvider(
        providers: [
          Provider(
            create: (_) {
              final cache = BundledSvgCache();
              final colors = [
                AppTheme.light().colorScheme,
                AppTheme.dark().colorScheme,
              ];
              cache.configureColors(
                identityColors: colors.map((c) => c.onSurface),
                mcpColors: colors.map((c) => c.onSurfaceVariant),
              );
              return cache;
            },
            dispose: (_, cache) => cache.dispose(),
          ),
          Provider(create: (_) => AppInfoService()),
          if (AgentToolService.current != null)
            ChangeNotifierProvider.value(value: AgentToolService.current!),
          ChangeNotifierProvider(create: (_) => _startup.locale, lazy: false),
          ChangeNotifierProvider(create: (_) => _startup.theme, lazy: false),
          ChangeNotifierProvider(create: (_) => _startup.timeout, lazy: false),
          ChangeNotifierProvider(create: (_) => _startup.runtime, lazy: false),
          ChangeNotifierProvider(
            create: (_) => _startup.assistants,
            lazy: false,
          ),
          ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
          ChangeNotifierProvider(create: (_) => _startup.library, lazy: false),
          ChangeNotifierProvider(
            create: (_) => _startup.downloads,
            lazy: false,
          ),
          ChangeNotifierProvider(create: (_) => ModelDiscoveryProvider()),
          ChangeNotifierProxyProvider3<
            EngineRuntimeProvider,
            ChatTimeoutProvider,
            AssistantProvider,
            ChatProvider
          >(
            create: (_) => _startup.chat,
            lazy: false,
            update:
                (
                  _,
                  runtimeProvider,
                  chatTimeoutProvider,
                  assistants,
                  chatProvider,
                ) {
                  final provider = chatProvider ?? _startup.chat;
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
            // App-owned recovery is prepared during idle time or on demand.
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
                // A restored launch palette is not a user theme transition.
                themeAnimationDuration: _ready.value
                    ? kThemeAnimationDuration
                    : Duration.zero,
                locale: localeProvider.locale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) {
                  final runtime = context.read<EngineRuntimeProvider>();
                  final chat = context.read<ChatProvider>();
                  final speech = context.read<SpeechJobService>();
                  final library = context.read<ModelManagementProvider>();
                  return AppIdleWarmup(
                    ready: _ready,
                    startupWatch: widget.startupWatch,
                    activity: Listenable.merge([
                      runtime,
                      chat,
                      speech,
                      library,
                    ]),
                    isBusy: () =>
                        runtime.isBusy ||
                        chat.isSending ||
                        chat.isLoadingMessages ||
                        chat.isLoadingOlderMessages ||
                        speech.jobs.any((job) => job.state.active) ||
                        library.isImporting ||
                        library.isImportingMmproj ||
                        library.isRenaming ||
                        library.deletingModelId != null ||
                        (speech.ready &&
                            (speech.audio.recording ||
                                speech.audio.recordingBusy ||
                                speech.audio.playbackActive ||
                                speech.models.importing ||
                                speech.models.progress.isNotEmpty)),
                    onReady: () => _startBackground(context),
                    createTasks: () => _warmupTasks(context),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: _preparedOnEntry
                    ? const MainScaffold()
                    : AppStartupGate(
                        initialError: _startup.error,
                        initialize: (_) => _startup.prepare(),
                        onReady: () => _ready.value = true,
                        child: const MainScaffold(),
                      ),
              ),
        ),
      ),
    );
  }

  Future<void> _startBackground(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    context.read<DownloadProvider>().resumeRestoredTransfers();
    final tools = AgentToolService.current;
    if (tools != null) unawaited(tools.mcp.start());
    // History is not the fresh-chat input. Start it immediately after first
    // paint; demand loads join it and concurrent new conversations survive it.
    await StartupTask(
      'chat_sessions',
      () => chat.load(preloadMessages: false),
    ).run(phase: 'background');
  }

  Future<List<StartupTask>> _warmupTasks(BuildContext context) async {
    final cache = context.read<BundledSvgCache>();
    final chat = context.read<ChatProvider>();
    final tools = AgentToolService.current;
    final themes = [AppTheme.light().colorScheme, AppTheme.dark().colorScheme];
    final pageTasks = <StartupTask>[
      StartupTask(
        'model_assets',
        context.read<AssistantProvider>().ensureAssetsReconciled,
      ),
      StartupTask(
        'server_config',
        context.read<ServerConfigProvider>().ensureLoaded,
      ),
      StartupTask(
        'model_library',
        context.read<ModelManagementProvider>().load,
      ),
      StartupTask('speech', context.read<SpeechJobService>().initialize),
      StartupTask(
        'local_catalog',
        context.read<ModelDiscoveryProvider>().prepare,
      ),
      if (tools != null) StartupTask('skills', tools.ensureSkillsLoaded),
      StartupTask('app_info', context.read<AppInfoService>().load),
    ];
    final tasks = <StartupTask>[];
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = [
        for (final asset in manifest.listAssets())
          if (asset.startsWith('assets/ai-icons/') && asset.endsWith('.svg'))
            asset,
        'assets/app_icon.svg',
      ];
      // One compiled SVG per idle slot; rendering remains framework-owned.
      for (final asset in assets) {
        final colors = asset == 'assets/app_icon.svg'
            ? {const Color(0xff000000)}
            : themes
                  .map(
                    (c) => asset.endsWith('/mcp.svg')
                        ? c.onSurfaceVariant
                        : c.onSurface,
                  )
                  .toSet();
        for (final color in colors) {
          tasks.add(
            StartupTask('bundled_icon', () => cache.load(asset, color)),
          );
        }
      }
    } catch (error) {
      AppLogger.instance.event(
        'app.startup.icon_manifest_failed',
        level: LogLevel.warning,
        fields: AppLogger.errorFields(error),
      );
    }
    // ServLlama starts on a new draft. Only a few recent windows are useful;
    // full histories, attachments and Run recovery never belong to prefetch.
    for (final session in chat.sessions.take(4)) {
      final id = session.id;
      tasks.add(
        StartupTask('recent_chat_window', () => chat.warmUpSession(id)),
      );
    }
    return [
      ...pageTasks,
      ...tasks,
      StartupTask('file_cleanup', chat.cleanupFiles),
      StartupTask('log_history', AppLogger.instance.ensureHistoryLoaded),
    ];
  }
}
