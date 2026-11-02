import 'dart:async';

import 'package:servllama/app/providers/app_provider_scope.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/chat_display_provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';

import 'stub_engine_adapter.dart';

class AppStartupFixture {
  final locale = _Locale();
  final theme = _Theme();
  final timeout = _Timeout();
  final chatDisplay = _ChatDisplay();
  final runtime = _Runtime();
  final assistants = StartupAssistants();
  final library = _Library();
  final downloads = StartupDownloads();
  final chat = StartupChat();
  late final scope = AppProviderScope(
    locale: locale,
    theme: theme,
    timeout: timeout,
    chatDisplay: chatDisplay,
    runtime: runtime,
    assistants: assistants,
    library: library,
    downloads: downloads,
    chat: chat,
  );

  void dispose() {
    chat.dispose();
    downloads.dispose();
    library.dispose();
    assistants.dispose();
    runtime.dispose();
    timeout.dispose();
    chatDisplay.dispose();
    theme.dispose();
    locale.dispose();
  }
}

class _Locale extends AppLocaleProvider {
  Completer<void>? pending;

  @override
  Future<void> load() async => await pending?.future;
}

class _Theme extends AppThemeModeProvider {
  @override
  Future<void> load() async {}
}

class _Timeout extends ChatTimeoutProvider {
  @override
  Future<void> load() async {}
}

class _ChatDisplay extends ChatDisplayProvider {
  Completer<void>? pending;

  @override
  Future<void> load() async => await pending?.future;
}

class _Runtime extends EngineRuntimeProvider {
  _Runtime()
    : super(
        llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
        mnnAdapter: StubEngineAdapter(),
      );

  @override
  Future<void> ensureRestored() async {}
}

class StartupAssistants extends AssistantProvider {
  Completer<void>? pending;
  bool fail = false;
  final reconciliationModes = <bool>[];

  @override
  Future<void> load({bool reconcileAssets = true}) async {
    reconciliationModes.add(reconcileAssets);
    await pending?.future;
    if (fail) throw StateError('fixture snapshot unavailable');
    assistants = [const Assistant(id: 'a', name: 'Assistant')];
    activeId = 'a';
    loaded = true;
    notifyListeners();
  }
}

class _Library extends ModelManagementProvider {
  bool importing = true;
  int loads = 0;
  @override
  bool get isImporting => importing;
  @override
  Future<void> load() async {
    loads++;
  }
}

class StartupDownloads extends DownloadProvider {
  final transferModes = <bool>[];

  @override
  Future<void> load({bool startTransfers = true}) async {
    transferModes.add(startTransfers);
  }

  @override
  void resumeRestoredTransfers() {}
}

class StartupChat extends ChatProvider {
  int draftLoads = 0, historyLoads = 0;

  @override
  Future<void> prepareDrafts() async {
    draftLoads++;
    await super.prepareDrafts();
  }

  @override
  Future<void> load({bool preloadMessages = true}) async {
    historyLoads++;
    await prepareDrafts();
  }
}
