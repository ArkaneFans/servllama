import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';

/// The initial app-owned providers, prepared without a mounted widget tree.
/// ServLlamaApp adopts these same instances and owns their disposal.
class AppStartupState {
  AppStartupState({
    AppLocaleProvider? locale,
    AppThemeModeProvider? theme,
    ChatTimeoutProvider? timeout,
    EngineRuntimeProvider? runtime,
    AssistantProvider? assistants,
    ModelManagementProvider? library,
    DownloadProvider? downloads,
    ChatProvider? chat,
  }) : locale = locale ?? AppLocaleProvider(),
       theme = theme ?? AppThemeModeProvider(),
       timeout = timeout ?? ChatTimeoutProvider() {
    this.runtime = runtime ?? EngineRuntimeProvider();
    this.assistants = assistants ?? AssistantProvider();
    this.library =
        library ??
        ModelManagementProvider(
          onModelDeleted: this.assistants.refreshAssets,
          onModelRenamed: this.runtime.handleModelRenamed,
        );
    this.downloads =
        downloads ??
        DownloadProvider(
          onLibraryChanged: this.library.refresh,
          modelNameCoordinator: this.library.nameCoordinator,
        );
    this.chat =
        chat ??
        ChatProvider(
          repository: ChatSessionRepository(retryCleanupOnOpen: false),
        );
  }

  final AppLocaleProvider locale;
  final AppThemeModeProvider theme;
  final ChatTimeoutProvider timeout;
  late final EngineRuntimeProvider runtime;
  late final AssistantProvider assistants;
  late final ModelManagementProvider library;
  late final DownloadProvider downloads;
  late final ChatProvider chat;
  bool _ready = false;
  Object? _error;
  bool get ready => _ready;
  Object? get error => _error;
  Future<void>? _preparing;

  Future<void> prepare() {
    if (ready) return Future<void>.value();
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    try {
      final critical = [
        StartupTask('locale', locale.load),
        StartupTask('theme', theme.load),
        StartupTask('chat_timeout', timeout.load),
        StartupTask('runtime_restore', runtime.ensureRestored),
        StartupTask(
          'download_snapshot',
          () => downloads.load(startTransfers: false),
        ),
        StartupTask(
          'assistant_snapshot',
          () => assistants.load(reconcileAssets: false),
        ),
      ];
      // Configuration snapshots only; no inventory/history/icon prefetch.
      await Future.wait(critical.map((task) => task.run(phase: 'critical')));
      if (!assistants.loaded || assistants.error != null) {
        throw StateError('Application settings could not be restored');
      }
      chat.bind(assistants, runtime);
      chat.updateServerState(
        baseUrl: runtime.baseUrl,
        isServerRunning: runtime.isRunning,
        engine: runtime.activeEngine,
        activeModelId: runtime.activeModelId,
        activeModelName: runtime.activeModelName,
      );
      chat.updateChatTimeout(timeout.timeout);
      await StartupTask(
        'chat_drafts',
        chat.prepareDrafts,
      ).run(phase: 'critical');
      _ready = true;
      _error = null;
    } catch (failure) {
      _error = failure;
      rethrow;
    }
  }
}
