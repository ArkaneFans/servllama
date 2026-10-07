// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get v2McpEmpty => 'No MCP servers yet. Tap + to add one.';

  @override
  String get v2SkillsEmpty => 'No skills yet. Tap + to import one.';

  @override
  String get v2ManageMcp => 'Manage MCP';

  @override
  String get v2ManageSkills => 'Manage skills';

  @override
  String get v2LocalTools => 'Local tools';

  @override
  String get v2AssistantManagement => 'Assistant management';

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
  String get commonDone => 'Done';

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
  String get aboutDescription => 'An LLM inference server on your phone';

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
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutLlamaCppLabel => 'llama.cpp';

  @override
  String get aboutSystem => 'System';

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
      'The maximum number of context tokens the model can attend to. A context size that is too high may cause an out-of-memory crash.';

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
  String get llamaCppBackendTitle => 'Acceleration backend';

  @override
  String get llamaCppBackendNextStart =>
      'Changes apply the next time the server starts.';

  @override
  String get llamaCppBackendRefresh => 'Check available backends';

  @override
  String get llamaCppBackendStopServer =>
      'Stop the server to detect GPU and NPU support.';

  @override
  String get llamaCppBackendCpu => 'CPU';

  @override
  String get llamaCppBackendOpencl => 'GPU (OpenCL)';

  @override
  String get llamaCppBackendHexagon => 'Hexagon (experimental)';

  @override
  String get llamaCppBackendCpuDescription =>
      'Runs entirely on the CPU. Broadest compatibility.';

  @override
  String get llamaCppBackendOpenclDescription =>
      'Offload layers to Adreno GPU via OpenCL.';

  @override
  String get llamaCppBackendHexagonDescription =>
      'NPU acceleration on Snapdragon 8 Gen 2 and later.';

  @override
  String get llamaCppBackendUnavailable => 'Not available on this device.';

  @override
  String get llamaCppBackendProbeFailed =>
      'Could not check llama.cpp backends. CPU will be used if nothing else is available. Details are in the engine log.';

  @override
  String get llamaCppBackendSavedUnavailable =>
      'The saved backend is currently unavailable. Choose another backend before starting, or use Auto.';

  @override
  String get llamaCppGpuLayers => 'Offloaded layers';

  @override
  String get llamaCppGpuLayersDescription =>
      'How many layers to place on the selected GPU or NPU. Higher values use the accelerator more.';

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
  String get modelSettingsDownloadMmproj => 'Download mmproj';

  @override
  String get modelSettingsReplaceMmproj => 'Replace mmproj';

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
      'Only .gguf files whose names contain mmproj are supported.';

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
  String get appLogsTitle => 'App logs';

  @override
  String get appLogsCopyAll => 'Copy filtered logs';

  @override
  String get appLogsClear => 'Clear all logs';

  @override
  String get appLogsClearFailed =>
      'The log view was cleared, but saved log files could not be deleted.';

  @override
  String get appLogsCopied => 'Logs copied';

  @override
  String get appLogsEmpty => 'No logs yet';

  @override
  String get appLogsExport => 'Export logs';

  @override
  String appLogsExported(String path) {
    return 'Logs exported to $path';
  }

  @override
  String appLogsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get appLogsAutoScroll => 'Auto-scroll';

  @override
  String get appLogsFilterAll => 'All';

  @override
  String get appLogsFilterEngine => 'Engine';

  @override
  String get appLogsFilterServer => 'Service';

  @override
  String get appLogsFilterModel => 'Model';

  @override
  String get appLogsFilterDownload => 'Download';

  @override
  String get appLogsFilterErrors => 'Errors only';

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
  String get modelLibraryEmptyTitle =>
      'No models yet. Download from Discover or import a local model.';

  @override
  String get modelLibraryEmptyDescription =>
      'Download one, or import a file you already have.';

  @override
  String get modelLibrarySearchHint => 'Search model names';

  @override
  String get modelLibraryEmptySearchTitle => 'No matching models';

  @override
  String get modelLibraryEmptySearchDescription => 'Try a different name.';

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
  String get repoDownloadQueued => 'In the download queue';

  @override
  String get repoVisionOn => 'Vision · On';

  @override
  String get repoVisionOff => 'Vision · Off';

  @override
  String get repoVisionSheetTitle => 'Vision';

  @override
  String get repoVisionEnable => 'Enable vision';

  @override
  String get repoVisionMmprojSection => 'Vision projector';

  @override
  String get repoVisionDownloadHint =>
      'The selected projector will download with the model.';

  @override
  String get repoVisionDownloadDisabledHint =>
      'Download the text model only. You can add a vision projector in model settings later.';

  @override
  String get modelSettingsVisionDisabledHint =>
      'Turning vision off keeps your downloaded projectors.';

  @override
  String get modelSettingsVisionNeedsProjector =>
      'Download and select a projector to enable image input.';

  @override
  String get modelSettingsProjectorsHint =>
      'Keep multiple versions and select one to use at a time.';

  @override
  String get modelSettingsLocalVisionHint =>
      'Import a compatible vision projector to enable image input.';

  @override
  String get modelSettingsProjectorDownloaded => 'Downloaded';

  @override
  String get modelSettingsProjectorSelected => 'Selected';

  @override
  String modelSettingsProjectorDeleteConfirm(String fileName) {
    return 'Delete “$fileName”? If it is selected, another downloaded version will be used. Vision turns off when no versions remain.';
  }

  @override
  String get modelSettingsOpenRepository => 'Open model repository';

  @override
  String get modelSettingsRepositoryOpenFailed =>
      'Could not open the model repository. Please try again.';

  @override
  String modelSettingsVisionUpdateFailed(String error) {
    return 'Could not update vision settings: $error';
  }

  @override
  String get modelSettingsProjectorDownloadPending =>
      'Finish or cancel projector downloads before renaming or deleting the model.';

  @override
  String get repoVisionNoMmproj => 'This repository has no mmproj files.';

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
  String downloadQueued(String fileName) {
    return '$fileName has been added to the download queue';
  }

  @override
  String downloadCompleted(String fileName) {
    return '$fileName has finished downloading';
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
  String get downloadWifiOnlyDialogTitle => 'On a mobile network';

  @override
  String get downloadWifiOnlyDialogMessage =>
      '“Download over Wi-Fi only” is on, so downloads are paused on mobile networks. Continue over mobile data anyway?';

  @override
  String get downloadWifiOnlyDialogAllow => 'Allow mobile data';

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

  @override
  String get mnnBackendTitle => 'MNN inference backend';

  @override
  String get mnnBackendNextStart =>
      'Changes apply the next time a model is loaded.';

  @override
  String mnnBackendActive(String backend) {
    return 'Loaded backend: $backend';
  }

  @override
  String get mnnBackendRefresh => 'Check available backends';

  @override
  String get mnnBackendCpu => 'CPU';

  @override
  String get mnnBackendOpencl => 'OpenCL GPU';

  @override
  String get mnnBackendVulkan => 'Vulkan GPU';

  @override
  String get mnnBackendHexagon => 'Hexagon NPU (experimental)';

  @override
  String get mnnBackendCpuDescription =>
      'Default, with the broadest model compatibility.';

  @override
  String get mnnBackendGpuDescription =>
      'Uses GPU acceleration. Loading a model for the first time requires some initialization time.';

  @override
  String get mnnBackendHexagonDescription =>
      'Use a model exported for Hexagon, preferably symmetric 4-bit quantization with Transformer C4. Can speed up long input processing; token generation may be slower than CPU.';

  @override
  String get runtimeErrorModelBackendIncompatible =>
      'This model format is incompatible with Hexagon NPU. Select CPU/GPU, or import a model re-exported for Hexagon.';

  @override
  String mnnBackendHexagonArchitecture(String architecture) {
    return 'Automatically matched the $architecture runtime.';
  }

  @override
  String get mnnBackendNotBuilt => 'Not included in this plugin build.';

  @override
  String get mnnBackendNativeUnavailable =>
      'The MNN native runtime is unavailable.';

  @override
  String get mnnBackendLibrariesMissing =>
      'This installation is missing compatible Hexagon runtime libraries.';

  @override
  String get mnnBackendDriverUnavailable =>
      'The device driver is unavailable or inaccessible to this app.';

  @override
  String get mnnBackendDeviceUnsupported =>
      'This device could not match or initialize a supported Hexagon DSP runtime.';

  @override
  String get mnnBackendNotChecked => 'Availability has not been checked.';

  @override
  String get mnnBackendProbeFailed =>
      'Could not check backends. Try again, or select CPU. Details are in the engine log.';

  @override
  String get mnnBackendSavedUnavailable =>
      'The saved backend is currently unavailable. Select another backend before starting.';

  @override
  String get runtimeErrorMnnBackendUnavailable =>
      'The selected MNN backend is unavailable. Choose CPU or another available backend in Service settings.';

  @override
  String get mnnRuntimeTitle => 'MNN runtime';

  @override
  String get mnnUseMmap => 'Use mmap';

  @override
  String get mnnUseMmapSubtitle =>
      'Maps model weights from disk to reduce memory. The first load builds a cache.';

  @override
  String get mnnPrecision => 'Precision';

  @override
  String get mnnPrecisionDescription =>
      'Low is faster and uses less memory. High is more accurate.';

  @override
  String get mnnPrecisionLow => 'Low';

  @override
  String get mnnPrecisionHigh => 'High';

  @override
  String get mnnThreadNum => 'Generation threads';

  @override
  String get mnnThreadNumDescription => 'CPU threads used for generation.';

  @override
  String get mnnMmapCache => 'Clear mmap cache';

  @override
  String mnnMmapCacheSubtitle(String size) {
    return 'Current cache: $size';
  }

  @override
  String get mnnMmapCacheEmpty => 'No mmap cache yet';

  @override
  String get mnnMmapCacheStopServer =>
      'Stop the server before clearing the cache.';

  @override
  String get mnnMmapCacheClearAction => 'Clear';

  @override
  String get mnnMmapCacheDialogTitle => 'Clear mmap cache?';

  @override
  String mnnMmapCacheDialogContent(String size) {
    return 'This deletes generated mmap and GPU runtime caches ($size). The next model load will rebuild them.';
  }

  @override
  String mnnMmapCacheCleared(String size) {
    return 'Cleared $size of mmap cache';
  }

  @override
  String get mnnMmapCacheClearFailed => 'Could not clear the mmap cache.';

  @override
  String get v2FirstAssistants => 'Assistants';

  @override
  String get v2Chat => 'Chat';

  @override
  String get v2Models => 'Models';

  @override
  String get v2Add => 'Add';

  @override
  String get v2OperationFailed => 'Operation failed';

  @override
  String get v2NoInstructions => 'Default conversation behavior';

  @override
  String get v2Duplicate => 'Duplicate';

  @override
  String get v2AssistantEditor => 'Assistant settings';

  @override
  String get v2Name => 'Name';

  @override
  String get v2Instructions => 'System instructions';

  @override
  String get v2Connection => 'Provider';

  @override
  String get v2LocalInference => 'Local inference';

  @override
  String get v2MissingTarget =>
      'Target unavailable. Check that its provider is enabled and the model is listed, or choose another.';

  @override
  String get v2Model => 'Model';

  @override
  String get v2CurrentLocal => 'Current local model';

  @override
  String get v2ModelId => 'Model ID';

  @override
  String get v2Connections => 'Providers';

  @override
  String get v2ConnectionsEmpty =>
      'Add a provider and its models to use them in chat.';

  @override
  String get v2ConnectionEditor => 'Provider settings';

  @override
  String get v2Protocol => 'Protocol';

  @override
  String get v2BaseUrl => 'API base URL';

  @override
  String get v2BaseUrlHelp =>
      'Include /v1 or /v1beta. Use HTTP only on a trusted local network.';

  @override
  String get v2ApiKey => 'API key';

  @override
  String get v2KeyHelp =>
      'Stored securely. Leave blank to keep the existing key.';

  @override
  String get v2ClearKey => 'Clear saved key';

  @override
  String get v2ModelsHelp => 'Model IDs, one per line (manual entry supported)';

  @override
  String get v2Images => 'Image input supported';

  @override
  String get v2Tools => 'Tool calls supported';

  @override
  String get v2FetchModels => 'Fetch models';

  @override
  String get v2TestConnection => 'Test provider';

  @override
  String get v2TestPassed => 'Test succeeded. Changes are not saved yet.';

  @override
  String get v2DraftHelp =>
      'Save to apply changes; going back discards unsaved edits. Testing and model discovery do not save automatically.';

  @override
  String get v2Profile => 'User profile';

  @override
  String get v2ProfileHelp =>
      'Local user details stay on this device. Your avatar and name are used for display and are not automatically added to model requests.';

  @override
  String get v2KeepOneAssistant =>
      'Create another assistant before deleting the last one.';

  @override
  String get v2DeleteConnectionHelp =>
      'Deleting this provider clears model selections for its assistants. Conversations and messages remain; select a model before sending.';

  @override
  String get v2Avatar => 'Avatar';

  @override
  String get v2AvatarHelp =>
      'Choose a local image or emoji for your avatar. Used for display only.';

  @override
  String get v2AvatarImage => 'Choose image';

  @override
  String get v2AvatarEmoji => 'Choose emoji';

  @override
  String get v2AvatarReset => 'Reset avatar';

  @override
  String get v2AvatarImageTooLarge =>
      'Choose an image under 10 MB, with each side at most 8192 pixels and at most 32 megapixels.';

  @override
  String get v2AvatarInvalidImage =>
      'This image could not be read. Choose another image.';

  @override
  String get v2AvatarEmojiTitle => 'Choose avatar emoji';

  @override
  String get v2AvatarEmojiHint => 'Enter one emoji or character';

  @override
  String get v2ChatUserName => 'User';

  @override
  String get v2ChatAssistantName => 'Assistant';

  @override
  String get v2UserName => 'User name';

  @override
  String get v2ProfileDescription => 'Description';

  @override
  String get v2ProfileDescriptionHint => 'A short introduction about yourself…';

  @override
  String get v2StartLocal => 'Load this conversation\'s local model';

  @override
  String get v2RemoteReady => 'Chat directly with the selected provider';

  @override
  String get v2Skills => 'Skills';

  @override
  String get v2SkillsHelp =>
      'Import static packages containing SKILL.md, then select them in assistant permissions.';

  @override
  String get v2ImportSkill => 'Import skill (ZIP / Markdown)';

  @override
  String get v2ScriptsUnsupported =>
      'Contains script references. Only static instructions are used; scripts are not executed.';

  @override
  String get v2Mcp => 'MCP';

  @override
  String get v2McpHelp =>
      'Streamable HTTP and legacy SSE. Select tools per assistant; approve each remote call.';

  @override
  String get v2McpToken => 'Static bearer token';

  @override
  String get v2McpHeaders => 'Custom HTTP headers (JSON)';

  @override
  String get v2McpHeadersHelp =>
      'JSON string values, for example an X-API-Key header. Stored securely; leave blank to keep existing headers. Protocol headers are managed by the app.';

  @override
  String get v2ClearMcpToken => 'Remove saved bearer token';

  @override
  String get v2ClearMcpHeaders => 'Remove saved custom headers';

  @override
  String get v2ShowHideCredential => 'Show / hide credential';

  @override
  String get v2DiscoverTools => 'Connect and discover tools';

  @override
  String get v2PermissionsHelp =>
      'Permissions are captured when a run starts. Revocation stops affected runs; additions apply next time.';

  @override
  String get v2ToolClock => 'Current time';

  @override
  String get v2ToolRead => 'Read conversation files';

  @override
  String get v2ToolAsk => 'Ask the user';

  @override
  String get v2ToolSkill => 'Read selected skill resources';

  @override
  String get v2ToolActivity => 'Tool call history';

  @override
  String get v2ToolHistoryEmpty => 'No tool call records in this conversation.';

  @override
  String get v2AwaitingApproval => 'Awaiting approval';

  @override
  String get v2Succeeded => 'Completed';

  @override
  String get v2UnknownOutcome => 'Outcome unknown';

  @override
  String get v2Rejected => 'Rejected';

  @override
  String get v2Cancelled => 'Cancelled';

  @override
  String get v2Executing => 'Executing';

  @override
  String get v2Failed => 'Failed';

  @override
  String get v2UnknownOutcomeHelp =>
      'The operation may have taken effect. It will not retry automatically. Verify the outcome before starting a new run.';

  @override
  String get v2Details => 'Arguments, target and receipt';

  @override
  String get v2YourAnswer => 'Your answer';

  @override
  String get v2Reject => 'Reject';

  @override
  String get v2ApproveOnce => 'Allow once';

  @override
  String get v2Review => 'Review';

  @override
  String get v2Rerun => 'Execute as a new run';

  @override
  String get v2RerunHelp =>
      'Tools use current permissions; actions that require approval will ask again.';

  @override
  String get v2BudgetReached =>
      'Run budget reached. Completed results are retained.';

  @override
  String get v2Interrupted =>
      'Interrupted. Create a new task explicitly to retry.';

  @override
  String get v2Speech => 'Speech';

  @override
  String get v2Asr => 'Transcribe';

  @override
  String get v2Tts => 'Synthesize';

  @override
  String get v2Tasks => 'Tasks';

  @override
  String get v2SpeechModels => 'Speech models';

  @override
  String get v2LlmModels => 'Language models';

  @override
  String get v2Voices => 'Reference voices';

  @override
  String get v2SpeechLocalHelp =>
      'Audio stays on this device. Record or import a file, then view the transcript below.';

  @override
  String get v2SpeechAudioInput => 'Recording & audio';

  @override
  String get v2RecordingReady => 'Tap the microphone to record';

  @override
  String get v2RecordingNow => 'Recording · tap to stop';

  @override
  String get v2SpeechCreatedAt => 'Created';

  @override
  String get v2SynthesisContent => 'Synthesis text';

  @override
  String get v2SpeechAudioResult => 'Synthesized audio';

  @override
  String get v2TranscriptPending => 'No transcript yet';

  @override
  String get v2SpeechTextCopied => 'Text copied';

  @override
  String get v2LanguageHint => 'Language code (zh / en; empty for auto)';

  @override
  String get v2StartAsr => 'Start transcription';

  @override
  String get v2StartTts => 'Start synthesis';

  @override
  String get v2InstallSpeechFirst =>
      'Download or import a compatible speech model first.';

  @override
  String get v2SynthesisText => 'Text to synthesize';

  @override
  String get v2SpeakerId => 'Preset speaker ID (0–217)';

  @override
  String get v2Voice => 'Voice';

  @override
  String get v2PresetVoice => 'Model default voice';

  @override
  String get v2SynthesisSpeed => 'Synthesis speed';

  @override
  String get v2CrispMarking =>
      'CrispASR exports include AI-generated audio provenance.';

  @override
  String get v2NoSpeechJobs =>
      'No speech tasks yet. Completed, cancelled and interrupted tasks appear here.';

  @override
  String get v2CancelTask => 'Cancel task';

  @override
  String get v2NoAudioSelected => 'No audio selected';

  @override
  String get v2ImportAudio => 'Import audio';

  @override
  String get v2Record => 'Record';

  @override
  String get v2StopRecording => 'Stop recording';

  @override
  String get v2UseRecording => 'Use latest recording';

  @override
  String get v2RecordingHelp =>
      'Record up to 10 minutes. Recording stops when the app enters the background or audio is interrupted.';

  @override
  String get v2SpeechWaitingHelp =>
      'Waiting for the previous speech task to release its resources. LLM service and chat can run alongside speech.';

  @override
  String get v2Queued => 'Queued';

  @override
  String get v2WaitingLocal => 'Waiting for speech resources';

  @override
  String get v2Cancelling => 'Cancelling; waiting for native completion';

  @override
  String get v2TaskResult => 'Task result';

  @override
  String get v2CancellationHelp =>
      'The next speech task waits until the native segment finishes and releases speech resources. LLM service and chat can continue.';

  @override
  String get v2NoSpeechDetected =>
      'No text detected. Try a different language or model in a new task.';

  @override
  String get v2ChunkTimingHelp =>
      'This model provides chunk ranges without reliable subtitle timestamps. TXT export is available.';

  @override
  String get v2Transcript => 'Transcript';

  @override
  String get v2EditTranscript => 'Edit transcript';

  @override
  String get v2ExportTxt => 'Export TXT';

  @override
  String get v2ExportSrt => 'Export SRT';

  @override
  String get v2ExportWav => 'Export WAV';

  @override
  String get v2InsertTranscript => 'Insert into chat draft';

  @override
  String get v2PlayPause => 'Play / pause';

  @override
  String get v2PreviewAudio => 'Preview reference audio';

  @override
  String get v2VoiceModelMissing =>
      'The original model is unavailable. You can export this reference audio and create a new voice after installing a compatible model.';

  @override
  String get v2PlaybackSpeed => 'Playback speed (keeps the generated audio)';

  @override
  String get v2InputSnapshot => 'Task input snapshot';

  @override
  String get v2SpeechPackageHelp =>
      'Each recipe is a self-contained package. An import ZIP must contain speech-package.json at its root.';

  @override
  String get v2ImportSpeechPackage => 'Import model ZIP';

  @override
  String get v2Ready => 'Ready';

  @override
  String get v2ModelIncomplete => 'Incomplete or paused';

  @override
  String get v2ResumeDownload => 'Resume download';

  @override
  String get v2PauseDownload => 'Pause download';

  @override
  String get v2DeleteSpeechModelHelp =>
      'Delete local model files. Existing results remain. Cancel queued jobs first; reference voices require a compatible model.';

  @override
  String get v2AvailableModels => 'Available recipes';

  @override
  String get v2ModelLicenseHelp =>
      'Review the upstream model card, supported languages and license before downloading.';

  @override
  String get v2ModelCard => 'Model card';

  @override
  String get v2DownloadModel => 'Download';

  @override
  String get v2CreateVoice => 'Create reference voice';

  @override
  String get v2VoiceHelp =>
      'Qwen3-TTS Base supports reference audio cloning. Use 3–30 seconds of clear single-speaker audio with an accurate transcript. Voices are bound to the model revision.';

  @override
  String get v2InstallCloningFirst => 'Install a cloning-capable recipe first.';

  @override
  String get v2VoiceName => 'Voice name';

  @override
  String get v2ReferenceText => 'Exact reference transcript';

  @override
  String get v2VoiceRights =>
      'I have permission to use this voice as a reference';

  @override
  String get v2VoiceTestText => 'Preview text (required)';

  @override
  String get v2SaveAndPreview => 'Save and create preview task';

  @override
  String get v2TranscribeToChat => 'Voice to text';

  @override
  String get v2NoAutomaticAudioUpload =>
      'Only text is inserted. Nothing is sent automatically; original audio is not uploaded.';

  @override
  String get v2ReplaceDraft => 'Replace draft';

  @override
  String get v2AppendDraft => 'Append to draft';

  @override
  String get v2TranscriptInserted =>
      'Transcript inserted into the selected chat draft.';

  @override
  String get v2ReadAloud => 'Read aloud';

  @override
  String v2SynthesisParameters(String speaker, String speed) {
    return 'Speaker: $speaker · Synthesis speed: $speed';
  }

  @override
  String v2SampleRate(int rate) {
    return 'Output sample rate: $rate Hz';
  }

  @override
  String v2DownloadSize(int size) {
    return 'Download size: about $size MiB';
  }

  @override
  String v2TranscriptDestination(String name) {
    return 'Destination: $name';
  }

  @override
  String get v2RetrySpeech => 'Retry as a new task';

  @override
  String v2TranscriptSegment(int index) {
    return 'Segment $index';
  }

  @override
  String get v2ReadAloudHelp =>
      'The final answer is ready to edit and synthesize. Use up to 4,000 characters per task; split longer answers.';

  @override
  String get v2NativeRestart =>
      'Speech cleanup is unconfirmed. Restart the app before running another speech task. Task records are retained.';

  @override
  String get v2CancelImport => 'Cancel import';

  @override
  String get v2OriginalChatMissing =>
      'The original destination is unavailable. Choose a conversation or assistant draft. The transcript is retained.';

  @override
  String v2AssistantDraft(String name) {
    return 'New conversation · $name';
  }

  @override
  String get v2TranscriptTarget => 'Destination draft';

  @override
  String get v2DraftChanged =>
      'The destination draft changed. Open it again before confirming a replacement.';

  @override
  String get v2IncompleteAnswer =>
      'This answer is incomplete. Finish generating it before reading it aloud.';

  @override
  String get v2SkillsGrantHelp =>
      'Selected skills can read their own instructions and resources. Other tools still need separate authorization.';

  @override
  String get v2DiscardRecording => 'Discard the recent recording';

  @override
  String get v2StartupFailed =>
      'Local data could not be opened. Existing data is retained; resolve the storage error and retry.';

  @override
  String get v2RetryStartup => 'Retry startup';

  @override
  String get appLogsFilterApp => 'App';

  @override
  String get appLogsFilterClient => 'Client';

  @override
  String get appLogsFilterAgent => 'Agent';

  @override
  String get appLogsFilterSpeech => 'Speech';

  @override
  String get appLogsSearch => 'Search logs or task ID';

  @override
  String get appLogsClearSearch => 'Clear search';

  @override
  String get appLogsAllLevels => 'All levels';

  @override
  String get appLogsLevelDebug => 'Debug and above';

  @override
  String get appLogsLevelInfo => 'Info and above';

  @override
  String get appLogsLevelWarning => 'Warnings and errors';

  @override
  String appLogsVisibleCount(int visible, int total) {
    return '$visible / $total logs';
  }

  @override
  String appLogsRetention(int limit) {
    return 'Showing the latest $limit entries. Copy and export use the current filters.';
  }

  @override
  String get appLogsNoMatches => 'No matching logs';

  @override
  String get v2ToolSearch => 'Web search';

  @override
  String get v2SearchGrantHelp =>
      'Allow this assistant to send search queries to the selected provider without asking each time. Bing and DuckDuckGo need no API key. Changing providers stops an active run that uses this permission.';

  @override
  String get v2SearchProvider => 'Search provider';

  @override
  String get v2SearchBing => 'Bing';

  @override
  String get v2SearchDuckDuckGo => 'DuckDuckGo';

  @override
  String get v2SearchMaxResults => 'Maximum results per search';

  @override
  String get v2SearchSources => 'Search sources';

  @override
  String get v2SearchNoResults =>
      'No matching web results. Try a different query.';

  @override
  String get v2SearchUnavailable =>
      'Search is unavailable. Check the network or select another provider.';

  @override
  String get v2SearchRateLimited =>
      'The search provider is limiting requests. Try again later or change providers.';

  @override
  String get v2SearchChallenge =>
      'The provider requires verification or has blocked this request. Try later or select another provider.';

  @override
  String get v2SearchInvalidResponse =>
      'The provider returned an unrecognized search page. Try later or select another provider.';

  @override
  String get v2SearchTooLarge =>
      'The search response exceeded the size limit. Try a more specific query.';

  @override
  String get v2SearchTimeout =>
      'The search timed out. Try again later or select another provider.';

  @override
  String get v2SearchOpenFailed => 'Unable to open this source link.';

  @override
  String get v2ConversationModel => 'Choose model';

  @override
  String get v2ConversationModelHelp =>
      'Choose a model by provider. Selecting a local model loads it and starts the service.';

  @override
  String get v2NoLocalChatModels =>
      'No local LLM is available. Download or import one from Models.';

  @override
  String get v2AssistantDefaultModel => 'Chat model';

  @override
  String get v2NoDefaultModel => 'No model selected';

  @override
  String get v2ClearDefaultModel => 'Clear model selection';

  @override
  String get v2AssistantDefaultModelHelp =>
      'All conversations with this assistant share this model. Changing the model in chat updates this setting; historical messages stay unchanged.';

  @override
  String get v2UnassignedAssistant => 'Assistant not assigned or removed';

  @override
  String get v2ChangeConversationAssistant =>
      'Change this conversation’s assistant';

  @override
  String get v2ChangeConversationAssistantHelp =>
      'Keep this conversation’s model, messages, versions and draft. Future replies use the new assistant’s instructions and permissions; historical attribution stays unchanged.';

  @override
  String get v2ChooseConversationModel => 'Please select a model';

  @override
  String get v2AllAssistantHistory => 'Conversations from all assistants';

  @override
  String v2ConnectionConversationCount(int count) {
    return '$count conversations use this provider and will need another model selection.';
  }

  @override
  String get v2DeleteAssistantHelp =>
      'Deleting this assistant also deletes all associated conversations, messages, and drafts. This cannot be undone.';

  @override
  String get v2SwitchAssistantNewChat =>
      'Switch assistant and start a new chat';

  @override
  String v2ToolCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tool calls',
      one: '1 tool call',
    );
    return '$_temp0';
  }

  @override
  String get v2ToolRetryLoad => 'Reload';

  @override
  String get v2ToolHistoryFailed => 'Could not load tool activity.';

  @override
  String get v2ToolPrepared => 'Waiting to execute';

  @override
  String get v2ToolApproved => 'Approved, waiting to execute';

  @override
  String get v2ToolAwaitingAnswer => 'Waiting for your answer';

  @override
  String get v2ToolList => 'List conversation files';

  @override
  String get v2ToolWriteAction => 'Write conversation file';

  @override
  String get v2ToolQuestion => 'Question';

  @override
  String get v2ToolArguments => 'Arguments';

  @override
  String get v2ToolResult => 'Result';

  @override
  String get v2ToolSendAnswer => 'Send answer';

  @override
  String get chatDeleteMessageTitle => 'Delete message';

  @override
  String get chatDeleteCurrentVersion => 'Delete this version';

  @override
  String get chatDeleteAllVersions => 'Delete all versions';

  @override
  String get chatDeleteAllVersionsConfirm =>
      'Delete this message and all its versions? Their tool call records and generation data will also be removed. Later messages will remain. This cannot be undone.';

  @override
  String chatDeleteVersionConfirm(int version, int count) {
    return 'Delete version $version of $count? Its tool call records and generation data will also be removed. Other versions and later messages will remain. This cannot be undone.';
  }

  @override
  String get v2ToolResultTruncated =>
      'This result was truncated. Only the saved excerpt can be viewed or exported.';

  @override
  String get v2ProviderPreset => 'Preset';

  @override
  String get v2ProviderCustom => 'Custom';

  @override
  String get v2ProviderPresetHelp =>
      'Preset providers cannot be deleted. You can configure or disable them.';

  @override
  String get v2ProviderEnabled => 'Enable provider';

  @override
  String get v2ProviderEnabledHelp =>
      'Disabling preserves settings and history and stops runs using this provider.';

  @override
  String get v2ProviderOn => 'Enabled';

  @override
  String get v2ProviderOff => 'Disabled';

  @override
  String v2ProviderModelCount(int count) {
    return '$count models';
  }

  @override
  String get v2ProviderModelsEmpty =>
      'No models added. Add models manually or fetch them in provider settings.';

  @override
  String get v2AddModel => 'Add model manually';

  @override
  String get v2RemoveModel => 'Remove model';

  @override
  String v2RemoveModelHelp(String model) {
    return 'Saving will remove $model from this provider. Conversations and assistant defaults using it will be unavailable; messages remain.';
  }

  @override
  String get v2ModelIdRequired => 'Enter a model ID';

  @override
  String get v2DiscoveredModels => 'Choose models to add';

  @override
  String get v2ModelAlreadyAdded => 'Already added';

  @override
  String get v2ModelSearch => 'Search model IDs';

  @override
  String get v2ProviderNoResults => 'No matching providers or models';

  @override
  String get v2ProviderModelSearch => 'Search providers or models';

  @override
  String v2AddSelectedModels(int count) {
    return 'Add selected ($count)';
  }

  @override
  String get v2SelectVisible => 'Select search results';

  @override
  String get v2DeselectVisible => 'Deselect search results';

  @override
  String v2LocalProvider(String engine) {
    return 'Local · $engine';
  }

  @override
  String get v2LocalProviderHelp =>
      'Managed in the local model library; load or stop models to control the runtime.';

  @override
  String get v2ServicePublished => 'Serving externally';

  @override
  String get v2PublishedModelLocked =>
      'Stop the published model in the service center before switching local models.';

  @override
  String get v2LocalModelLoaded => 'Loaded';

  @override
  String get v2LocalModelUnloaded => 'Not loaded';

  @override
  String get drawerAssistantSettings => 'Assistant settings';

  @override
  String get settingsUser => 'User settings';

  @override
  String get settingsSectionServices => 'Services & diagnostics';

  @override
  String get settingsSectionDeveloper => 'Developer tools';

  @override
  String get settingsMnnTest => 'MNN test';

  @override
  String get settingsDebug => 'Debug';

  @override
  String get localModelImport => 'Import local model';

  @override
  String get localModelChooseImport => 'Choose and import';

  @override
  String get localModelImportHelp =>
      'The selected file or folder is copied into app storage. Import starts after selection.';

  @override
  String get discoveryQuery => 'Search preset names or engines';

  @override
  String get discoveryReset => 'Reset filters';

  @override
  String get discoveryPurpose => 'Purpose';

  @override
  String get discoveryEngine => 'Engine';

  @override
  String get discoveryState => 'Installation';

  @override
  String get discoveryNotInstalled => 'Not installed';

  @override
  String get discoveryDownloading => 'Downloading';

  @override
  String get discoveryIncomplete => 'Paused / incomplete';

  @override
  String get discoveryCloneOnly => 'Voice cloning';

  @override
  String get discoverySmallOnly => 'Up to 200 MiB';

  @override
  String get discoverySpeechHelp =>
      'Download a complete preset package, including its dependencies. Runtime compatibility and quality still need verification on your device.';

  @override
  String get discoverySpeechLibraryHelp =>
      'Get speech models from Discover. Installed and incomplete packages appear here.';

  @override
  String get discoveryOnlineLanguage => 'Search language models online';

  @override
  String get v2StartupPreparing => 'Preparing ServLlama';

  @override
  String get v2MigrationTitle => 'Upgrading your data';

  @override
  String get v2MigrationHelp =>
      'Your chats, model records and download progress are being upgraded. Model files stay in place. Original data is retained until the upgrade succeeds.';

  @override
  String get v2MigrationFailed =>
      'The upgrade could not finish. Resolve the storage issue and retry; your original data is retained.';

  @override
  String get v2MigrationChats => 'Reading chat history';

  @override
  String get v2MigrationModels => 'Reading local model records';

  @override
  String get v2MigrationDownloads => 'Reading download tasks';

  @override
  String get v2MigrationWriting => 'Saving upgraded records';

  @override
  String get v2MigrationVerifying => 'Verifying model and download records';

  @override
  String get v2MigrationComplete => 'Upgrade complete. Finishing startup…';

  @override
  String v2MigrationRecords(int completed, int total) {
    return 'This step: $completed / $total records';
  }

  @override
  String get migrationPreviewTitle => 'Migration preview';

  @override
  String get migrationPreviewHelp =>
      'Simulates the interface only. No real data is read or changed. You can leave at any time.';

  @override
  String get migrationPreviewRestart => 'Restart preview';

  @override
  String get migrationPreviewFailure => 'Simulate failure';

  @override
  String get migrationPreviewError =>
      'Simulated error: Not enough storage. Retry to preview recovery.';

  @override
  String get migrationPreviewComplete =>
      'Preview complete. Your real data is unchanged.';

  @override
  String get migrationPreviewReturn => 'Return to sidebar';

  @override
  String get uiLabTitle => 'UI primitives';

  @override
  String get uiLabDark => 'Preview dark theme';

  @override
  String get uiLabLight => 'Preview light theme';

  @override
  String get uiLabVisuals => 'Visuals';

  @override
  String get uiLabControls => 'Controls';

  @override
  String get uiLabScenes => 'Scenes';

  @override
  String get uiLabPreview => 'Design preview';

  @override
  String get uiLabHeadline => 'Let content lead';

  @override
  String get uiLabIntro =>
      'Neutral surfaces, gentle blue-violet accents. Compact and ordered, with room to breathe.';

  @override
  String get uiLabQuiet => 'Restrained';

  @override
  String get uiLabSoft => 'Soft & clear';

  @override
  String get uiLabPalette => 'Color & surfaces';

  @override
  String get uiLabPaletteHint =>
      'Neutral backgrounds with accents where attention matters.';

  @override
  String get uiLabCanvas => 'Canvas';

  @override
  String get uiLabSurface => 'Surface';

  @override
  String get uiLabPrimary => 'Primary';

  @override
  String get uiLabSelected => 'Selection';

  @override
  String get uiLabTypography => 'Typography';

  @override
  String get uiLabTypographyHint =>
      'Hierarchy through size, weight and spacing.';

  @override
  String get uiLabTypeTitle => 'Clarity starts with reading';

  @override
  String get uiLabTypeSection => 'A clear section heading';

  @override
  String get uiLabTypeBody =>
      'Comfortable line spacing makes longer answers easy to read. Information flows naturally, with actions close at hand.';

  @override
  String get uiLabTypeCaption =>
      'Supporting text · 12 sp · Time, status and descriptions';

  @override
  String get uiLabRhythm => 'Spacing, corners & icons';

  @override
  String get uiLabRhythmHint =>
      'Compact groups, generous separation and comfortable touch targets.';

  @override
  String get uiLabRadii =>
      'Card radius 18 dp · Fields 14 dp\nTouch targets at least 48 dp';

  @override
  String get uiLabLocalOnly =>
      'These interactions preview the design without connecting to models or saving application data.';

  @override
  String get uiLabActions => 'Buttons & overlays';

  @override
  String get uiLabActionsHint =>
      'A clear primary action, softer secondary actions and lightweight utilities.';

  @override
  String get uiLabPrimaryAction => 'Primary';

  @override
  String get uiLabSecondaryAction => 'Secondary';

  @override
  String get uiLabSheet => 'Bottom sheet';

  @override
  String get uiLabDialog => 'Dialog';

  @override
  String get uiLabDisabled => 'Disabled';

  @override
  String get uiLabDialogTitle => 'Confirm this selection?';

  @override
  String get uiLabDialogBody =>
      'This previews a dialog. Confirm to see feedback; your real settings stay unchanged.';

  @override
  String get uiLabConfirm => 'Confirm';

  @override
  String get uiLabFeedback => 'Done — this change applies only to the preview.';

  @override
  String get uiLabChooseModel => 'Choose a model';

  @override
  String get uiLabOnDevice => 'On-device · Example';

  @override
  String get uiLabCloud => 'Cloud · Example';

  @override
  String get uiLabForms => 'Input & selection';

  @override
  String get uiLabFormsHint => 'Try the field, switch, slider and chip states.';

  @override
  String get uiLabName => 'Assistant name';

  @override
  String get uiLabNameHint => 'Give your assistant a name';

  @override
  String get uiLabNameError => 'Enter an assistant name';

  @override
  String get uiLabStreaming => 'Stream responses';

  @override
  String get uiLabStreamingHint => 'Show the answer as it arrives';

  @override
  String get uiLabTemperature => 'Temperature';

  @override
  String get uiLabVision => 'Vision';

  @override
  String get uiLabValidate => 'Validate input';

  @override
  String get uiLabStates => 'Status & progress';

  @override
  String get uiLabStatesHint =>
      'Color supports the label; the label always explains the state.';

  @override
  String get uiLabReady => 'Ready';

  @override
  String get uiLabWaiting => 'Waiting';

  @override
  String get uiLabFailed => 'Failed';

  @override
  String get uiLabDownload => 'Model download · Preview';

  @override
  String get uiLabSimulate => 'Simulate progress';

  @override
  String get uiLabAgain => 'Try again';

  @override
  String get uiLabChat => 'Conversation';

  @override
  String get uiLabChatHint =>
      'User bubbles, open assistant text, inline tools and message metadata.';

  @override
  String get uiLabYou => 'You';

  @override
  String get uiLabQuestion => 'Help me plan today’s reading.';

  @override
  String get uiLabAssistant => 'Reading assistant';

  @override
  String get uiLabTool => 'Completed · Find reading resources';

  @override
  String get uiLabToolDetail =>
      'Search → Organize → Return results\nAn expandable tool example. No network request was made.';

  @override
  String get uiLabAnswer =>
      'Set aside 25 minutes to focus on one chapter.\n\nThen spend 5 minutes noting three key ideas and one question to explore. Leave some room for reflection.';

  @override
  String get uiLabReply =>
      'Your preview message was received. This demonstrates text layout and send feedback without calling a model.';

  @override
  String get uiLabCopy => 'Preview copy feedback';

  @override
  String get uiLabMore => 'More options';

  @override
  String get uiLabManagement => 'Grouped lists & model cards';

  @override
  String get uiLabManagementHint =>
      'Consistent alignment, subtle separators and details on demand.';

  @override
  String get uiLabAssistantHint => 'Organize ideas and explore reading';

  @override
  String get uiLabProviderHint => '2 configured models · Example';

  @override
  String get uiLabVoice => 'Speech';

  @override
  String get uiLabVoiceHint => 'Transcription & synthesis · Example';

  @override
  String get uiLabComposer => 'Type a message to try the interaction';

  @override
  String get uiLabSend => 'Send preview message';

  @override
  String get uiLabExactValue => 'Value';

  @override
  String get uiLabNumericHint =>
      'Drag for a rough value, or type up to two decimal places.';

  @override
  String uiLabNumericError(String min, String max) {
    return 'Enter a value from $min to $max, with at most two decimal places.';
  }

  @override
  String get uiLabMessages => 'Messages';

  @override
  String get uiLabMessagesHint =>
      'Centered at the top for 3 seconds. A new message replaces the previous one; you can also dismiss it.';

  @override
  String get uiLabDismissMessage => 'Dismiss message';

  @override
  String get uiLabMessageSuccess => 'Success';

  @override
  String get uiLabMessageInfo => 'Info';

  @override
  String get uiLabMessageWarning => 'Warning';

  @override
  String get uiLabMessageError => 'Error';

  @override
  String get uiLabMessageInfoText =>
      'This is a design preview. Your real data stays unchanged.';

  @override
  String get uiLabMessageWarningText =>
      'Choose a model before continuing. (Example)';

  @override
  String get uiLabMessageErrorText =>
      'Connection failed. Check your settings and retry. (Example)';

  @override
  String get uiLabThemeColor => 'Theme color';

  @override
  String get uiLabViolet => 'Mist violet';

  @override
  String get uiLabTea => 'Tea violet';

  @override
  String get uiLabTeaIntro =>
      'Violet with a touch of tea, paired with warm neutral surfaces. Soft, restrained and clearly layered.';

  @override
  String get numericExactValue => 'Value';

  @override
  String get numericHint =>
      'Drag for a rough value, or type up to two decimal places.';

  @override
  String numericError(String min, String max) {
    return 'Enter a value from $min to $max, with at most two decimal places.';
  }

  @override
  String get commonDismissMessage => 'Dismiss message';

  @override
  String get v2ProviderConfiguration => 'Configuration';

  @override
  String get v2ProviderIdentity => 'Provider';

  @override
  String get v2ProviderConnection => 'Connection';

  @override
  String get v2ProtocolOpenai => 'OpenAI compatible';

  @override
  String get v2ModelCapabilities => 'Model capabilities';

  @override
  String get v2ModelCapabilitiesHelp =>
      'Set capabilities for each model according to its documentation. Fetching models only returns IDs; it does not verify image or tool support. Save the provider to apply your changes.';

  @override
  String get v2ModelText => 'Text';

  @override
  String get v2ModelImages => 'Images';

  @override
  String get v2ModelTools => 'Tools';

  @override
  String get v2IdentitySettings => 'Identity';

  @override
  String get v2InstructionsHint =>
      'Describe the assistant’s role, response style and requirements…';

  @override
  String get v2Credentials => 'Credentials';

  @override
  String get v2ModelImagesUnavailable =>
      'This model has image input disabled. Check its capabilities in provider settings.';

  @override
  String get v2AssistantModelChanged =>
      'This assistant’s model selection changed. Reopen its settings before editing it.';

  @override
  String get chatGreetingMorning => 'Good morning';

  @override
  String get chatGreetingNoon => 'Good afternoon';

  @override
  String get chatGreetingAfternoon => 'Good afternoon';

  @override
  String get chatGreetingEvening => 'Good evening';

  @override
  String get chatWelcomeDescription => 'What’s on your mind today?';

  @override
  String get chatWelcomeTranscribe => 'Transcribe';

  @override
  String get chatWelcomeSynthesize => 'Synthesize';

  @override
  String get chatWelcomeTranscribeHint => 'Audio to text';

  @override
  String get chatWelcomeSynthesizeHint => 'Text to audio';
}
