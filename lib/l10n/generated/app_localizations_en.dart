// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ServLlama';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get drawerAllHistoryTooltip => 'All history';

  @override
  String get drawerServer => 'Server';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get chatSearchHint => 'Search chats...';

  @override
  String get chatNewSession => 'New conversation';

  @override
  String get chatCreateSessionTooltip => 'New conversation';

  @override
  String get chatHistoryTitle => 'Chat history';

  @override
  String get chatSessionEmpty => 'No conversations yet';

  @override
  String get chatSessionNotFound => 'No matching conversations';

  @override
  String get chatMoreActions => 'More actions';

  @override
  String get chatRenameSessionTitle => 'Rename conversation';

  @override
  String get chatRenameSessionHint => 'Enter conversation name';

  @override
  String get chatDeleteSessionTitle => 'Delete conversation';

  @override
  String chatDeleteSessionConfirm(String sessionTitle) {
    return 'Delete \"$sessionTitle\"?';
  }

  @override
  String get chatSelectModel => 'Select model';

  @override
  String get chatRefreshModels => 'Refresh models';

  @override
  String get chatLoadedModels => 'Loaded models';

  @override
  String get chatAvailableModels => 'Available models';

  @override
  String chatNoModels(String title) {
    return 'No $title';
  }

  @override
  String get chatHeroTitle => 'Start chatting';

  @override
  String get chatHeroDescriptionReady =>
      'Send a message to start chatting with your local model.';

  @override
  String get chatHeroDescriptionStartServer =>
      'Start the server first, then load a model to begin your AI conversation.';

  @override
  String get chatHeroDescriptionSelectModel =>
      'The server is running. Load a model to begin your AI conversation.';

  @override
  String get chatStartServer => 'Start server';

  @override
  String get chatStartingServer => 'Starting...';

  @override
  String get chatLoadingModel => 'Loading model...';

  @override
  String get chatInputHintStartServer => 'Start the server first';

  @override
  String get chatInputHintLoadingModel => 'Model loading...';

  @override
  String get chatInputHintSelectModel => 'Choose a model first';

  @override
  String get chatInputHintModelUnavailable => 'Current model is not loaded';

  @override
  String get chatInputHintEnterMessage => 'Enter a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatUnloadModel => 'Unload model';

  @override
  String get chatModelStatusLoaded => 'Loaded';

  @override
  String get chatModelStatusLoading => 'Loading';

  @override
  String get chatModelStatusAvailable => 'Available to load';

  @override
  String get chatModelStatusFailed => 'Load failed';

  @override
  String chatModelLoadTimeout(Object model) {
    return 'Model load timed out: $model';
  }

  @override
  String chatModelLoadFailed(Object model) {
    return 'Failed to load model: $model';
  }

  @override
  String chatModelUnloadTimeout(Object model) {
    return 'Model unload timed out: $model';
  }

  @override
  String chatModelRequestFailed(Object detail) {
    return 'Request failed: $detail';
  }

  @override
  String get chatReasoningProcess => 'Reasoning';

  @override
  String get chatCopyMessage => 'Copy';

  @override
  String get chatEditMessage => 'Edit';

  @override
  String get chatRegenerateMessage => 'Regenerate';

  @override
  String get chatPreviousMessageVersion => 'Previous version';

  @override
  String get chatNextMessageVersion => 'Next version';

  @override
  String get chatJumpToLatest => 'Jump to latest';

  @override
  String get chatMessageCopied => 'Message copied';

  @override
  String get chatMessageUpdated => 'Message updated';

  @override
  String get chatEditMessageTitle => 'Edit message';

  @override
  String get chatEditMessageHint => 'Update this message';

  @override
  String get chatAttachImage => 'Attach image';

  @override
  String get chatRemoveImage => 'Remove image';

  @override
  String get chatImageLimitExceeded => 'Maximum 5 images per message';

  @override
  String get chatImageSizeExceeded => 'Image size cannot exceed 10MB';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionChat => 'Chat';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsChatTimeout => 'Chat timeout';

  @override
  String settingsChatTimeoutValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get settingsChatTimeoutSheetTitle => 'Chat timeout';

  @override
  String get settingsChatTimeoutDescription =>
      'Controls how long chat responses can take. Increase it for multimodal image understanding when needed.';

  @override
  String get settingsChatTimeoutFieldLabel => 'Timeout';

  @override
  String get settingsChatTimeoutUnit => 's';

  @override
  String settingsChatTimeoutRange(int minSeconds, int maxSeconds) {
    return 'Allowed range: $minSeconds-$maxSeconds s';
  }

  @override
  String get settingsUnavailable => 'Coming soon';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsThemeModeSheetTitle => 'Theme mode';

  @override
  String get settingsLanguageSheetTitle => 'App language';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get languageModeSystem => 'Follow system';

  @override
  String get languageModeChinese => 'Simplified Chinese';

  @override
  String get languageModeEnglish => 'English';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutDescription =>
      'Turn your phone into a powerful LLM inference server, no Termux required';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutVersionCopied => 'Version copied';

  @override
  String aboutLlamaCppVersion(String version) {
    return 'llama.cpp $version';
  }

  @override
  String get aboutStarOnGitHub => 'Star on GitHub';

  @override
  String get aboutLicense => 'Open source license';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverMenuConfig => 'Server config';

  @override
  String get serverMenuLogs => 'Logs';

  @override
  String get serverMenuModels => 'Model management';

  @override
  String get serverStatusRunning => 'Running';

  @override
  String get serverStatusStopped => 'Stopped';

  @override
  String get serverStart => 'Start';

  @override
  String get serverStop => 'Stop';

  @override
  String get serverBaseUrlLabel => 'API Base URL';

  @override
  String get serverBaseUrlCopied => 'API Base URL copied';

  @override
  String get serverCopyBaseUrl => 'Copy API Base URL';

  @override
  String get serverForegroundNotificationTitle => 'ServLlama is running';

  @override
  String get serverForegroundNotificationText =>
      'ServLlama server is running in the background';

  @override
  String get serverStartFailedCheckLogs =>
      'Server failed to start. Check logs.';

  @override
  String serverStartFailed(String error) {
    return 'Failed to start: $error';
  }

  @override
  String serverStopFailed(String error) {
    return 'Failed to stop: $error';
  }

  @override
  String get serverConfigTitle => 'Server config';

  @override
  String get serverConfigStatusSaved => 'Configuration saved';

  @override
  String get serverConfigStatusLoading => 'Loading configuration...';

  @override
  String get serverConfigStatusLoaded => 'Configuration loaded';

  @override
  String serverConfigStatusLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get serverConfigStatusSaving => 'Saving configuration...';

  @override
  String serverConfigStatusSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get serverConfigSectionNetwork => 'Network & access';

  @override
  String get serverConfigListenMode => 'Listen scope';

  @override
  String get serverConfigListenModeDescription =>
      'Local loopback is for local-only use, while listen on all allows external access.';

  @override
  String get serverConfigListenLocalhost => 'Local loopback';

  @override
  String get serverConfigListenAllInterfaces => 'Listen on all';

  @override
  String get serverConfigPort => 'Port';

  @override
  String get serverConfigPortDescription => 'The server listening port';

  @override
  String get serverConfigApiKey => 'API key';

  @override
  String get serverConfigApiKeyDescription =>
      'Leave empty to disable verification';

  @override
  String get serverConfigSectionInference => 'Inference';

  @override
  String get serverConfigContextSize => 'Context size';

  @override
  String get serverConfigContextSizeDescription =>
      'The maximum number of context tokens the model can attend to';

  @override
  String get serverConfigBatchSize => 'Batch size';

  @override
  String get serverConfigBatchSizeDescription =>
      'Affects throughput and memory usage';

  @override
  String get serverConfigImageMaxTokens => 'Image max tokens';

  @override
  String get serverConfigImageMaxTokensDescription =>
      'Maximum number of tokens each image can use, only applies to vision models';

  @override
  String get serverConfigSectionPerformance => 'Performance';

  @override
  String get serverConfigCpuThreads => 'CPU threads';

  @override
  String get serverConfigCpuThreadsDescription =>
      'The number of CPU threads allocated to model inference';

  @override
  String get serverConfigParallelSlots => 'Parallel slots';

  @override
  String get serverConfigParallelSlotsDescription =>
      'Controls how many requests the server can handle at the same time';

  @override
  String get serverConfigSectionAdvanced => 'Advanced';

  @override
  String get serverConfigFlashAttention => 'Flash Attention';

  @override
  String get serverConfigFlashAttentionDescription =>
      'Reduces memory usage and inference time for some models';

  @override
  String get serverConfigUseMmap => 'Use mmap';

  @override
  String get serverConfigUseMmapSubtitle =>
      'Improves model loading performance';

  @override
  String get serverConfigSectionLogging => 'Logs';

  @override
  String get serverConfigLogEnabled => 'Enable logs';

  @override
  String get serverConfigLogEnabledSubtitle =>
      'Controls whether inference engine runtime logs are displayed and recorded in the app';

  @override
  String get serverConfigLogLevel => 'Log level';

  @override
  String get serverConfigLogLevelDescription =>
      'Controls the detail level of inference engine logs';

  @override
  String get serverConfigLogLevelError => 'Error';

  @override
  String get serverConfigLogLevelWarning => 'Warning';

  @override
  String get serverConfigLogLevelInfo => 'Info';

  @override
  String get serverConfigLogLevelDebug => 'Debug';

  @override
  String get serverConfigSectionReset => 'Reset';

  @override
  String get serverConfigResetTitle => 'Restore default config';

  @override
  String get serverConfigResetSubtitle =>
      'All default values will be saved immediately after confirmation.';

  @override
  String get serverConfigResetDialogTitle => 'Restore default config';

  @override
  String get serverConfigResetDialogContent =>
      'All settings will be reset to defaults. Continue?';

  @override
  String get serverConfigResetAction => 'Restore defaults';

  @override
  String get modelManagementTitle => 'Model management';

  @override
  String get modelManagementImport => 'Import model';

  @override
  String get modelManagementImporting => 'Importing...';

  @override
  String modelManagementImportSuccess(String modelName) {
    return 'Model imported: $modelName';
  }

  @override
  String modelManagementImportAutoRenamed(
    String requestedName,
    String finalName,
  ) {
    return 'Model imported: $finalName\n“$requestedName” already exists and was renamed automatically.';
  }

  @override
  String modelManagementImportFailed(String error) {
    return 'Failed to import model: $error';
  }

  @override
  String get modelManagementEmptyTitle => 'No models imported yet';

  @override
  String get modelManagementEmptyDescription =>
      'After tapping \"Import model\", your local GGUF model list will appear here.';

  @override
  String get modelManagementDeleteBusy => 'Deleting model. Please wait.';

  @override
  String modelManagementDeleteSuccess(String modelName) {
    return 'Model deleted: $modelName';
  }

  @override
  String modelManagementDeleteFailed(String error) {
    return 'Failed to delete model: $error';
  }

  @override
  String get modelManagementDeleteDialogTitle => 'Delete model';

  @override
  String modelManagementDeleteDialogContent(String modelName) {
    return 'Delete $modelName? This removes the model file and cannot be undone.';
  }

  @override
  String get modelManagementDeleteTooltip => 'Delete';

  @override
  String get modelMmprojBadgeLabel => 'Multimodal';

  @override
  String get modelTextBadgeLabel => 'Text';

  @override
  String get modelManagementSettingsTooltip => 'Settings';

  @override
  String get modelSettingsNameLabel => 'Model name';

  @override
  String get modelSettingsMmprojLabel => 'Multimodal projector';

  @override
  String get modelSettingsImportMmproj => 'Import mmproj file';

  @override
  String get modelSettingsRemoveMmproj => 'Remove mmproj';

  @override
  String modelManagementMmprojImportSuccess(String modelName) {
    return 'mmproj imported: $modelName';
  }

  @override
  String modelManagementMmprojImportFailed(String error) {
    return 'Failed to import mmproj: $error';
  }

  @override
  String modelManagementMmprojRemoveSuccess(String modelName) {
    return 'mmproj removed: $modelName';
  }

  @override
  String modelManagementMmprojRemoveFailed(String error) {
    return 'Failed to remove mmproj: $error';
  }

  @override
  String modelManagementRenameSuccess(String modelName) {
    return 'Model renamed to: $modelName';
  }

  @override
  String modelManagementRenameFailed(String error) {
    return 'Failed to rename model: $error';
  }

  @override
  String modelSettingsRemoveMmprojConfirm(String modelName) {
    return 'Remove mmproj file for $modelName?';
  }

  @override
  String get modelErrorUnsupportedGgufFile => 'Only .gguf files are supported.';

  @override
  String get modelErrorSelectedModelFileMissing =>
      'The selected model file does not exist.';

  @override
  String get modelErrorInvalidModelName => 'The model name is invalid.';

  @override
  String get modelErrorDuplicateModelName =>
      'A model with the same name already exists.';

  @override
  String get modelErrorModelNotFound => 'Model not found.';

  @override
  String get modelErrorSelectedMmprojFileMissing =>
      'The selected mmproj file does not exist.';

  @override
  String get modelErrorUnsupportedMmprojFile =>
      'Only .gguf files starting with mmproj are supported.';

  @override
  String get modelErrorMmprojSameAsModelFile =>
      'The mmproj file cannot have the same name as the main model file.';

  @override
  String get modelErrorEmptyModelName => 'The model name cannot be empty.';

  @override
  String get modelErrorModelNameExists => 'The model name already exists.';

  @override
  String get modelErrorModelDirectoryExists =>
      'The model directory already exists.';

  @override
  String get modelErrorModelNotFoundOrDeleted =>
      'The model does not exist or has already been deleted.';

  @override
  String get modelErrorSelectedFilePathUnavailable =>
      'Unable to get the selected file path.';

  @override
  String get serverLogsTitle => 'Logs';

  @override
  String get serverLogsCopyAll => 'Copy all';

  @override
  String get serverLogsClear => 'Clear';

  @override
  String get serverLogsCopied => 'Logs copied';

  @override
  String serverLogsCount(int count) {
    return '$count logs total';
  }

  @override
  String get serverLogsEmpty => 'No logs yet';

  @override
  String get serverLogsExport => 'Export logs';

  @override
  String serverLogsExported(String path) {
    return 'Logs exported to $path';
  }

  @override
  String serverLogsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get serverLogsAutoScroll => 'Auto-scroll';

  @override
  String get serverLogsFilterAll => 'All';

  @override
  String get serverLogsFilterEngine => 'Engine';

  @override
  String get serverLogsFilterServer => 'Service';

  @override
  String get serverLogsFilterModel => 'Model';

  @override
  String get serverLogsFilterDownload => 'Download';

  @override
  String get serverLogsFilterErrors => 'Errors only';

  @override
  String get engineSectionTitle => 'Inference engine';

  @override
  String get serverStatusIdle => 'Stopped';

  @override
  String get serverStatusPreparing => 'Starting';

  @override
  String get serverStatusStopping => 'Stopping';

  @override
  String get serverStatusError => 'Failed';

  @override
  String get serverCancelPreparation => 'Cancel';

  @override
  String serverUptime(String duration) {
    return 'Running for $duration';
  }

  @override
  String serverUptimeHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String serverUptimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get serverActiveModelLabel => 'Active model';

  @override
  String get serverNoModelSelected => 'No model selected';

  @override
  String get serverModelRequiredHint => 'Select a model before starting';

  @override
  String get serverSelectModelTitle => 'Select model';

  @override
  String serverNoModelsForEngine(String engine) {
    return 'No $engine models in the library yet';
  }

  @override
  String get serverPhaseLoadingModel => 'Loading model';

  @override
  String get serverPhaseStartingServer => 'Starting service';

  @override
  String get serverPhaseVerifying => 'Health check';

  @override
  String get serverPhaseUnloadingModel => 'Unloading model';

  @override
  String get serverPhaseStoppingServer => 'Stopping service';

  @override
  String runtimeErrorPortInUse(int port) {
    return 'Port $port is currently unavailable; another service may still be using it.';
  }

  @override
  String get runtimeErrorModelLoadFailed => 'Failed to load the model.';

  @override
  String get runtimeErrorServerStartFailed =>
      'The service failed to start. Check the logs.';

  @override
  String get runtimeErrorServerStopFailed => 'The service failed to stop.';

  @override
  String get runtimeErrorModelRequired => 'Select a model first.';

  @override
  String get runtimeErrorEngineUnavailable =>
      'This engine is unavailable on this device.';

  @override
  String runtimeErrorUnknown(String detail) {
    return 'Something went wrong: $detail';
  }

  @override
  String get serverOpenAccessWarning =>
      'The service listens on all interfaces without an API key, so any device on the same network can access it.';

  @override
  String get modelLibraryTitle => 'Models';

  @override
  String get modelLibraryAddTitle => 'Add a model';

  @override
  String get modelLibraryFilterAll => 'All';

  @override
  String get modelLibraryDownloadingSection => 'Downloading';

  @override
  String get modelLibraryInstalledSection => 'Installed';

  @override
  String get modelAddDownload => 'Download from a hub';

  @override
  String get modelAddDownloadDesc =>
      'Hugging Face and ModelScope, with resume support';

  @override
  String get modelAddGguf => 'Import a GGUF file';

  @override
  String get modelAddGgufDesc => 'A single .gguf file for llama.cpp';

  @override
  String get modelAddMnnDir => 'Import an MNN directory';

  @override
  String get modelAddMnnDirDesc => 'A whole model folder for the MNN engine';

  @override
  String get modelFormatExplainer =>
      'GGUF is a single file; MNN models are whole directories. The engine badge on each card tells them apart.';

  @override
  String get modelLibraryEmptyTitle => 'No models yet';

  @override
  String get modelLibraryEmptyDescription =>
      'Download one, or import a file you already have.';

  @override
  String modelLibraryDeleteDialogContent(String modelName) {
    return 'Delete “$modelName”? The files will be removed from this device.';
  }

  @override
  String get modelLibraryStatusRunning => 'Running';

  @override
  String get modelLibraryStatusIdle => 'Idle';

  @override
  String get modelLibraryActiveCannotDelete =>
      'The running model cannot be deleted';

  @override
  String get modelLibrarySwitchEngineBlocked =>
      'Stop the running service before switching engines.';

  @override
  String get modelLibraryActivationFailed =>
      'Could not activate the model. Check the server logs.';

  @override
  String get modelCapabilityChinese => 'Chinese';

  @override
  String get modelCapabilityEnglish => 'English';

  @override
  String get modelCapabilityVision => 'Vision';

  @override
  String get modelCapabilityToolCalling => 'Tool calling';

  @override
  String get discoverTitle => 'Discover models';

  @override
  String get discoverTabFeatured => 'Featured';

  @override
  String get discoverTabSearch => 'Search';

  @override
  String discoverDeviceMemory(String available, String total) {
    return '$available of $total RAM available';
  }

  @override
  String get discoverDeviceMemoryUnknown =>
      'Device memory unknown; feasibility is not checked.';

  @override
  String get discoverSearchHint => 'Search repositories';

  @override
  String get discoverSearchDisclaimer =>
      'Search results come straight from the hub and have not been verified on a device.';

  @override
  String get discoverBackToFeatured => 'View device-verified picks';

  @override
  String get discoverSortTrending => 'Trending';

  @override
  String get discoverSortDownloads => 'Downloads';

  @override
  String get discoverSortLikes => 'Likes';

  @override
  String get discoverSortUpdated => 'Recently updated';

  @override
  String get discoverFormatAll => 'All formats';

  @override
  String get discoverFeaturedNote =>
      'Every model here has been run on a real device.';

  @override
  String get discoverNoResults => 'No matching repositories';

  @override
  String get discoverSearchPrompt => 'Type a model name to search both hubs.';

  @override
  String get discoverErrorNetwork =>
      'Network unreachable. Check the connection or switch route.';

  @override
  String get discoverErrorUnauthorized =>
      'This repository needs a token. Add one in Settings.';

  @override
  String get discoverErrorNotFound => 'Repository not found.';

  @override
  String get discoverErrorMalformed =>
      'The hub returned an unexpected response.';

  @override
  String discoverResultCount(int count) {
    return '$count results';
  }

  @override
  String discoverDownloadsCount(int count) {
    return '$count downloads';
  }

  @override
  String get discoverUpdatedUnknown => 'Update time unknown';

  @override
  String discoverUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get repoQuantSectionTitle => 'Quantization';

  @override
  String get repoFilesSectionTitle => 'Files';

  @override
  String get repoDownloadAction => 'Download';

  @override
  String repoEstimatedMemory(String size) {
    return 'Needs about $size';
  }

  @override
  String get repoNoGgufFiles => 'This repository has no GGUF files.';

  @override
  String get repoNoMnnFiles => 'This repository has no MNN model files.';

  @override
  String repoMnnWholeDirectory(int count) {
    return 'MNN models download as a whole directory ($count files).';
  }

  @override
  String get feasibilityComfortable => 'Runs comfortably';

  @override
  String get feasibilityTight => 'Tight on memory';

  @override
  String get feasibilityNotEnoughMemory => 'Not enough memory';

  @override
  String get feasibilityUnknown => 'Unknown';

  @override
  String get catalogSummaryVerifiedSmallGeneralist =>
      'Small all-rounder, quick to load';

  @override
  String get catalogSummaryVerifiedEntryLevel =>
      'Entry level, runs on almost anything';

  @override
  String get catalogSummaryVerifiedBalanced =>
      'Balanced quality and speed for everyday use';

  @override
  String get catalogSummaryVerifiedMnnDefault =>
      'The MNN engine\'s default pick';

  @override
  String get catalogSummaryVerifiedMnnBalanced =>
      'Stronger MNN model for capable phones';

  @override
  String get catalogSummaryVerifiedMnnVision =>
      'MNN model with image understanding';

  @override
  String get catalogSummaryVerifiedStrong =>
      'Better quality, for capable devices';

  @override
  String get catalogSummaryVerifiedLfm25 =>
      '2.6B multilingual model for everyday use';

  @override
  String get catalogSummaryVerifiedMnnSmall =>
      'Compact MNN pick, easy on most phones';

  @override
  String get catalogSummaryVerifiedMnnEveryday =>
      'Everyday MNN model, balanced quality and speed';

  @override
  String get catalogSummaryVerifiedGemma4E2B =>
      'Lightweight vision model for mid-range phones';

  @override
  String get catalogSummaryVerifiedGemma4E4B =>
      'Stronger vision model for capable phones';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'No download tasks';

  @override
  String get downloadStatusQueued => 'Queued';

  @override
  String get downloadStatusRunning => 'Downloading';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadStatusDownloaded => 'Importing';

  @override
  String get downloadStatusCompleted => 'Done';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Resume';

  @override
  String get downloadCancel => 'Cancel';

  @override
  String get downloadRetry => 'Retry';

  @override
  String get downloadSwitchSource => 'Switch source';

  @override
  String downloadStarted(String modelName) {
    return 'Started downloading $modelName';
  }

  @override
  String downloadStartedAutoRenamed(String requestedName, String finalName) {
    return 'Started downloading $finalName\n“$requestedName” already exists and was renamed automatically.';
  }

  @override
  String downloadProgressDetail(String received, String total, String speed) {
    return '$received / $total - $speed/s';
  }

  @override
  String downloadProgressUnknownTotal(String received, String speed) {
    return '$received downloaded - $speed/s';
  }

  @override
  String downloadRemaining(String duration) {
    return '$duration left';
  }

  @override
  String downloadFilesProgress(int done, int total) {
    return '$done of $total files';
  }

  @override
  String get downloadErrorNetwork => 'Connection interrupted';

  @override
  String get downloadErrorUnauthorized =>
      'Access denied, a token may be required';

  @override
  String get downloadErrorNotFound => 'File no longer exists on the hub';

  @override
  String get downloadErrorDiskFull => 'Not enough storage';

  @override
  String get downloadErrorIntegrity => 'File length or checksum does not match';

  @override
  String get downloadErrorCancelled => 'Cancelled';

  @override
  String get downloadErrorAlreadyQueued =>
      'The same model is already in the download queue';

  @override
  String get downloadCancelDialogTitle => 'Cancel download';

  @override
  String downloadCancelDialogContent(String modelName) {
    return 'Cancel “$modelName”? Downloaded bytes will be discarded.';
  }

  @override
  String get downloadForegroundTitle => 'ServLlama is downloading models';

  @override
  String downloadForegroundText(int count, int percent) {
    return '$count tasks - $percent%';
  }

  @override
  String get settingsSectionDownload => 'Downloads';

  @override
  String get settingsHuggingFaceRoute => 'Hugging Face route';

  @override
  String get settingsHuggingFaceRouteDescription =>
      'The mirror helps when the official host is unreachable.';

  @override
  String get settingsRouteAuto => 'Auto';

  @override
  String get settingsRouteOfficial => 'Official';

  @override
  String get settingsRouteMirror => 'Mirror';

  @override
  String get settingsHuggingFaceToken => 'Hugging Face token';

  @override
  String get settingsModelScopeToken => 'ModelScope token';

  @override
  String get settingsTokenDescription =>
      'Stored on this device only. Never written to logs or exported files.';

  @override
  String get settingsTokenNotSet => 'Not set';

  @override
  String get settingsTokenSheetTitle => 'Access token';

  @override
  String get settingsWifiOnly => 'Download over Wi-Fi only';

  @override
  String get settingsWifiOnlySubtitle =>
      'Pause tasks when the network switches to cellular';

  @override
  String get settingsMaxConcurrentDownloads => 'Parallel downloads';

  @override
  String get settingsMaxConcurrentDownloadsDescription =>
      'How many tasks may run at once';

  @override
  String get settingsSectionStorage => 'Storage';

  @override
  String get settingsStorageModels => 'Models';

  @override
  String get settingsStorageDownloads => 'Unfinished downloads';

  @override
  String get settingsClearStaging => 'Clear unfinished downloads';

  @override
  String get settingsClearStagingDone => 'Cleared unfinished downloads';

  @override
  String get aboutMnnVersion => 'MNN version';

  @override
  String aboutMnnVersionDetail(String value) {
    return 'MNN version: $value';
  }

  @override
  String get chatEmptyTitle => 'Pick a model to start';

  @override
  String get chatEmptyDescription =>
      'The service starts on its own once a model is chosen.';

  @override
  String get chatEmptyAction => 'Choose a model';

  @override
  String get chatChooseEngineToStart => 'Choose the inference engine to start';

  @override
  String chatEngineDefaultModel(String model) {
    return 'Default model: $model';
  }

  @override
  String get chatCurrentRunning => 'Running now';

  @override
  String get chatLoadModelAction => 'Load';

  @override
  String get chatPreparingModel => 'Preparing model';

  @override
  String get chatEmptyNoModelsDescription =>
      'Download a model first. Everything runs on this device afterwards.';
}
