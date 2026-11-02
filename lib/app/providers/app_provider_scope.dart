import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/chat_display_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';

/// App-scoped composition only. Each provider owns its asynchronous loading;
/// this scope never gates the first frame or aggregates business readiness.
class AppProviderScope {
  AppProviderScope({
    AppLocaleProvider? locale,
    AppThemeModeProvider? theme,
    ChatTimeoutProvider? timeout,
    ChatDisplayProvider? chatDisplay,
    EngineRuntimeProvider? runtime,
    AssistantProvider? assistants,
    ModelManagementProvider? library,
    DownloadProvider? downloads,
    ChatProvider? chat,
  }) : locale = locale ?? AppLocaleProvider(),
       theme = theme ?? AppThemeModeProvider(),
       timeout = timeout ?? ChatTimeoutProvider(),
       chatDisplay = chatDisplay ?? ChatDisplayProvider() {
    this.runtime = runtime ?? EngineRuntimeProvider();
    this.assistants =
        assistants ??
        AssistantProvider(
          loadDefaultName: () async {
            // Only first-use seeding needs the restored language. Existing
            // assistant snapshots and the homepage never wait for this label.
            await this.locale.load();
            return AppL10nService.instance.current.v2AssistantDefaultName;
          },
        );
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
  final ChatDisplayProvider chatDisplay;
  late final EngineRuntimeProvider runtime;
  late final AssistantProvider assistants;
  late final ModelManagementProvider library;
  late final DownloadProvider downloads;
  late final ChatProvider chat;
}
