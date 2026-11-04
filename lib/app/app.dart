import 'dart:async';

import 'package:flutter/services.dart';
import 'package:servllama/app/bootstrap/app_idle_warmup.dart';
import 'package:servllama/app/providers/app_provider_scope.dart';
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
  const ServLlamaApp({super.key, this.scope});
  final AppProviderScope? scope;

  @override
  State<ServLlamaApp> createState() => _ServLlamaAppState();
}

class _ServLlamaAppState extends State<ServLlamaApp> {
  late final AppProviderScope _scope;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.scope ?? AppProviderScope();
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
                mcpColors: colors.expand(
                  (c) => [c.onSurfaceVariant, c.outline],
                ),
              );
              return cache;
            },
            dispose: (_, cache) => cache.dispose(),
          ),
          Provider(create: (_) => AppInfoService()),
          if (AgentToolService.current != null)
            ChangeNotifierProvider.value(value: AgentToolService.current!),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('locale', _scope.locale.load);
              return _scope.locale;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('theme', _scope.theme.load);
              return _scope.theme;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('chat_timeout', _scope.timeout.load);
              return _scope.timeout;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('chat_display', _scope.chatDisplay.load);
              return _scope.chatDisplay;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('runtime_restore', _scope.runtime.ensureRestored);
              return _scope.runtime;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) {
              _startTask('assistant_snapshot', _scope.assistants.ensureLoaded);
              return _scope.assistants;
            },
            lazy: false,
          ),
          ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
          ChangeNotifierProvider(create: (_) => _scope.library, lazy: false),
          ChangeNotifierProvider(create: (_) => _scope.downloads, lazy: false),
          ChangeNotifierProvider(create: (_) => ModelDiscoveryProvider()),
          ChangeNotifierProxyProvider3<
            EngineRuntimeProvider,
            ChatTimeoutProvider,
            AssistantProvider,
            ChatProvider
          >(
            create: (_) => _scope.chat,
            lazy: false,
            update:
                (
                  _,
                  runtimeProvider,
                  chatTimeoutProvider,
                  assistants,
                  chatProvider,
                ) {
                  final provider = chatProvider ?? _scope.chat;
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
            // App-owned recovery is initialized on speech entry, never at launch.
            create: (context) {
              final service = SpeechJobService(
                context.read<EngineRuntimeProvider>().resources,
              );
              return service;
            },
          ),
        ],
        child: Consumer2<AppThemeModeProvider, AppLocaleProvider>(
          builder: (context, themeModeProvider, localeProvider, _) {
            final animateTheme = _themeLoaded;
            _themeLoaded = themeModeProvider.hasLoaded;
            return MaterialApp(
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              debugShowCheckedModeBanner: false,
              navigatorObservers: [AppNavigationObserver()],
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeModeProvider.themeMode,
              // A restored launch palette is not a user theme transition.
              themeAnimationDuration: animateTheme
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
                  ready: const AlwaysStoppedAnimation(true),
                  activity: Listenable.merge([runtime, chat, speech, library]),
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
              home: const MainScaffold(),
            );
          },
        ),
      ),
    );
  }

  void _startTask(String name, Future<void> Function() load) {
    unawaited(
      StartupTask(name, load).run(phase: 'background').catchError((_) {}),
    );
  }

  void _startBackground(BuildContext context) {
    // These services restore independently after paint, not behind idle work.
    _startTask('downloads', context.read<DownloadProvider>().load);
    final tools = AgentToolService.current;
    if (tools != null) _startTask('mcp', tools.mcp.start);
    // ChatPage owns its post-frame draft/history load. Do not start another
    // body prefetch or make the optional queue wait for all history rows.
  }

  Future<List<StartupTask>> _warmupTasks(BuildContext context) async {
    final cache = context.read<BundledSvgCache>();
    final cleanupFiles = context.read<ChatProvider>().cleanupFiles;
    final tools = AgentToolService.current;
    final colors = Theme.of(context).colorScheme;
    final pageTasks = <StartupTask>[
      StartupTask(
        'server_config',
        context.read<ServerConfigProvider>().ensureLoaded,
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
      // One compiled SVG per idle slot. MCP's paint-only tints share this load.
      for (final asset in assets) {
        final tints = asset == 'assets/app_icon.svg'
            ? {const Color(0xff000000)}
            : {
                asset.endsWith('/mcp.svg')
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              };
        for (final color in tints) {
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
    // No inventory scans, speech setup, discovery catalogs, history bodies or
    // historical logs at launch. Those pages use their existing demand loaders.
    return [...pageTasks, ...tasks, StartupTask('file_cleanup', cleanupFiles)];
  }
}
