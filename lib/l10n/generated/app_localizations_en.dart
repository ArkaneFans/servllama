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
  String get chatModelStatusAvailable => 'Available';

  @override
  String get chatModelStatusFailed => 'Load failed';

  @override
  String get chatReasoningProcess => 'Reasoning';

  @override
  String get chatCopyMessage => 'Copy';

  @override
  String get chatEditMessage => 'Edit';

  @override
  String get chatRegenerateMessage => 'Regenerate';

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
      'Leave empty to disable verification.';

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
}
