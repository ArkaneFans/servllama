import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ServLlama'**
  String get appTitle;

  /// No description provided for @commonAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get commonAuto;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get commonDisable;

  /// No description provided for @drawerAllHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'All history'**
  String get drawerAllHistoryTooltip;

  /// No description provided for @drawerServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get drawerServer;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats...'**
  String get chatSearchHint;

  /// No description provided for @chatNewSession.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatNewSession;

  /// No description provided for @chatCreateSessionTooltip.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatCreateSessionTooltip;

  /// No description provided for @chatHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get chatHistoryTitle;

  /// No description provided for @chatSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatSessionEmpty;

  /// No description provided for @chatSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations'**
  String get chatSessionNotFound;

  /// No description provided for @chatMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get chatMoreActions;

  /// No description provided for @chatRenameSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get chatRenameSessionTitle;

  /// No description provided for @chatRenameSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Enter conversation name'**
  String get chatRenameSessionHint;

  /// No description provided for @chatDeleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation'**
  String get chatDeleteSessionTitle;

  /// No description provided for @chatDeleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{sessionTitle}\"?'**
  String chatDeleteSessionConfirm(String sessionTitle);

  /// No description provided for @chatSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get chatSelectModel;

  /// No description provided for @chatRefreshModels.
  ///
  /// In en, this message translates to:
  /// **'Refresh models'**
  String get chatRefreshModels;

  /// No description provided for @chatLoadedModels.
  ///
  /// In en, this message translates to:
  /// **'Loaded models'**
  String get chatLoadedModels;

  /// No description provided for @chatAvailableModels.
  ///
  /// In en, this message translates to:
  /// **'Available models'**
  String get chatAvailableModels;

  /// No description provided for @chatNoModels.
  ///
  /// In en, this message translates to:
  /// **'No {title}'**
  String chatNoModels(String title);

  /// No description provided for @chatHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get chatHeroTitle;

  /// No description provided for @chatHeroDescriptionReady.
  ///
  /// In en, this message translates to:
  /// **'Send a message to start chatting with your local model.'**
  String get chatHeroDescriptionReady;

  /// No description provided for @chatHeroDescriptionStartServer.
  ///
  /// In en, this message translates to:
  /// **'Start the server first, then load a model to begin your AI conversation.'**
  String get chatHeroDescriptionStartServer;

  /// No description provided for @chatHeroDescriptionSelectModel.
  ///
  /// In en, this message translates to:
  /// **'The server is running. Load a model to begin your AI conversation.'**
  String get chatHeroDescriptionSelectModel;

  /// No description provided for @chatStartServer.
  ///
  /// In en, this message translates to:
  /// **'Start server'**
  String get chatStartServer;

  /// No description provided for @chatStartingServer.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get chatStartingServer;

  /// No description provided for @chatLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model...'**
  String get chatLoadingModel;

  /// No description provided for @chatInputHintStartServer.
  ///
  /// In en, this message translates to:
  /// **'Start the server first'**
  String get chatInputHintStartServer;

  /// No description provided for @chatInputHintLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Model loading...'**
  String get chatInputHintLoadingModel;

  /// No description provided for @chatInputHintSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model first'**
  String get chatInputHintSelectModel;

  /// No description provided for @chatInputHintModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current model is not loaded'**
  String get chatInputHintModelUnavailable;

  /// No description provided for @chatInputHintEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a message'**
  String get chatInputHintEnterMessage;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// No description provided for @chatUnloadModel.
  ///
  /// In en, this message translates to:
  /// **'Unload model'**
  String get chatUnloadModel;

  /// No description provided for @chatModelStatusLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded'**
  String get chatModelStatusLoaded;

  /// No description provided for @chatModelStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get chatModelStatusLoading;

  /// No description provided for @chatModelStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get chatModelStatusAvailable;

  /// No description provided for @chatModelStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get chatModelStatusFailed;

  /// No description provided for @chatReasoningProcess.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get chatReasoningProcess;

  /// No description provided for @chatAttachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get chatAttachImage;

  /// No description provided for @chatRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get chatRemoveImage;

  /// No description provided for @chatImageLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Maximum 5 images per message'**
  String get chatImageLimitExceeded;

  /// No description provided for @chatImageSizeExceeded.
  ///
  /// In en, this message translates to:
  /// **'Image size cannot exceed 10MB'**
  String get chatImageSizeExceeded;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @settingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsUnavailable;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsThemeModeSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeModeSheetTitle;

  /// No description provided for @settingsLanguageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageSheetTitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @languageModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageModeSystem;

  /// No description provided for @languageModeChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageModeChinese;

  /// No description provided for @languageModeEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageModeEnglish;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn your phone into a powerful LLM inference server, no Termux required'**
  String get aboutDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutVersionCopied.
  ///
  /// In en, this message translates to:
  /// **'Version copied'**
  String get aboutVersionCopied;

  /// No description provided for @aboutStarOnGitHub.
  ///
  /// In en, this message translates to:
  /// **'Star on GitHub'**
  String get aboutStarOnGitHub;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'Open source license'**
  String get aboutLicense;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// No description provided for @serverMenuConfig.
  ///
  /// In en, this message translates to:
  /// **'Server config'**
  String get serverMenuConfig;

  /// No description provided for @serverMenuLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get serverMenuLogs;

  /// No description provided for @serverMenuModels.
  ///
  /// In en, this message translates to:
  /// **'Model management'**
  String get serverMenuModels;

  /// No description provided for @serverStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get serverStatusRunning;

  /// No description provided for @serverStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serverStatusStopped;

  /// No description provided for @serverStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get serverStart;

  /// No description provided for @serverStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get serverStop;

  /// No description provided for @serverBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get serverBaseUrlLabel;

  /// No description provided for @serverBaseUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'API Base URL copied'**
  String get serverBaseUrlCopied;

  /// No description provided for @serverCopyBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy API Base URL'**
  String get serverCopyBaseUrl;

  /// No description provided for @serverStartFailedCheckLogs.
  ///
  /// In en, this message translates to:
  /// **'Server failed to start. Check logs.'**
  String get serverStartFailedCheckLogs;

  /// No description provided for @serverStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start: {error}'**
  String serverStartFailed(String error);

  /// No description provided for @serverStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop: {error}'**
  String serverStopFailed(String error);

  /// No description provided for @serverConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Server config'**
  String get serverConfigTitle;

  /// No description provided for @serverConfigStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get serverConfigStatusSaved;

  /// No description provided for @serverConfigStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading configuration...'**
  String get serverConfigStatusLoading;

  /// No description provided for @serverConfigStatusLoaded.
  ///
  /// In en, this message translates to:
  /// **'Configuration loaded'**
  String get serverConfigStatusLoaded;

  /// No description provided for @serverConfigStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String serverConfigStatusLoadFailed(String error);

  /// No description provided for @serverConfigStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving configuration...'**
  String get serverConfigStatusSaving;

  /// No description provided for @serverConfigStatusSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String serverConfigStatusSaveFailed(String error);

  /// No description provided for @serverConfigSectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network & access'**
  String get serverConfigSectionNetwork;

  /// No description provided for @serverConfigListenMode.
  ///
  /// In en, this message translates to:
  /// **'Listen scope'**
  String get serverConfigListenMode;

  /// No description provided for @serverConfigListenModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Local loopback is for local-only use, while listen on all allows external access.'**
  String get serverConfigListenModeDescription;

  /// No description provided for @serverConfigListenLocalhost.
  ///
  /// In en, this message translates to:
  /// **'Local loopback'**
  String get serverConfigListenLocalhost;

  /// No description provided for @serverConfigListenAllInterfaces.
  ///
  /// In en, this message translates to:
  /// **'Listen on all'**
  String get serverConfigListenAllInterfaces;

  /// No description provided for @serverConfigPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get serverConfigPort;

  /// No description provided for @serverConfigPortDescription.
  ///
  /// In en, this message translates to:
  /// **'The server listening port'**
  String get serverConfigPortDescription;

  /// No description provided for @serverConfigApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get serverConfigApiKey;

  /// No description provided for @serverConfigApiKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to disable verification.'**
  String get serverConfigApiKeyDescription;

  /// No description provided for @serverConfigSectionInference.
  ///
  /// In en, this message translates to:
  /// **'Inference'**
  String get serverConfigSectionInference;

  /// No description provided for @serverConfigContextSize.
  ///
  /// In en, this message translates to:
  /// **'Context size'**
  String get serverConfigContextSize;

  /// No description provided for @serverConfigContextSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'The maximum number of context tokens the model can attend to'**
  String get serverConfigContextSizeDescription;

  /// No description provided for @serverConfigBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch size'**
  String get serverConfigBatchSize;

  /// No description provided for @serverConfigBatchSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Affects throughput and memory usage'**
  String get serverConfigBatchSizeDescription;

  /// No description provided for @serverConfigImageMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Image max tokens'**
  String get serverConfigImageMaxTokens;

  /// No description provided for @serverConfigImageMaxTokensDescription.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of tokens each image can use, only applies to vision models'**
  String get serverConfigImageMaxTokensDescription;

  /// No description provided for @serverConfigSectionPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get serverConfigSectionPerformance;

  /// No description provided for @serverConfigCpuThreads.
  ///
  /// In en, this message translates to:
  /// **'CPU threads'**
  String get serverConfigCpuThreads;

  /// No description provided for @serverConfigCpuThreadsDescription.
  ///
  /// In en, this message translates to:
  /// **'The number of CPU threads allocated to model inference'**
  String get serverConfigCpuThreadsDescription;

  /// No description provided for @serverConfigParallelSlots.
  ///
  /// In en, this message translates to:
  /// **'Parallel slots'**
  String get serverConfigParallelSlots;

  /// No description provided for @serverConfigParallelSlotsDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls how many requests the server can handle at the same time'**
  String get serverConfigParallelSlotsDescription;

  /// No description provided for @serverConfigSectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get serverConfigSectionAdvanced;

  /// No description provided for @serverConfigFlashAttention.
  ///
  /// In en, this message translates to:
  /// **'Flash Attention'**
  String get serverConfigFlashAttention;

  /// No description provided for @serverConfigFlashAttentionDescription.
  ///
  /// In en, this message translates to:
  /// **'Reduces memory usage and inference time for some models'**
  String get serverConfigFlashAttentionDescription;

  /// No description provided for @serverConfigUseMmap.
  ///
  /// In en, this message translates to:
  /// **'Use mmap'**
  String get serverConfigUseMmap;

  /// No description provided for @serverConfigUseMmapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Improves model loading performance'**
  String get serverConfigUseMmapSubtitle;

  /// No description provided for @serverConfigSectionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get serverConfigSectionReset;

  /// No description provided for @serverConfigResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore default config'**
  String get serverConfigResetTitle;

  /// No description provided for @serverConfigResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All default values will be saved immediately after confirmation.'**
  String get serverConfigResetSubtitle;

  /// No description provided for @serverConfigResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore default config'**
  String get serverConfigResetDialogTitle;

  /// No description provided for @serverConfigResetDialogContent.
  ///
  /// In en, this message translates to:
  /// **'All settings will be reset to defaults. Continue?'**
  String get serverConfigResetDialogContent;

  /// No description provided for @serverConfigResetAction.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get serverConfigResetAction;

  /// No description provided for @modelManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Model management'**
  String get modelManagementTitle;

  /// No description provided for @modelManagementImport.
  ///
  /// In en, this message translates to:
  /// **'Import model'**
  String get modelManagementImport;

  /// No description provided for @modelManagementImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get modelManagementImporting;

  /// No description provided for @modelManagementImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Model imported: {modelName}'**
  String modelManagementImportSuccess(String modelName);

  /// No description provided for @modelManagementImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import model: {error}'**
  String modelManagementImportFailed(String error);

  /// No description provided for @modelManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No models imported yet'**
  String get modelManagementEmptyTitle;

  /// No description provided for @modelManagementEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'After tapping \"Import model\", your local GGUF model list will appear here.'**
  String get modelManagementEmptyDescription;

  /// No description provided for @modelManagementDeleteBusy.
  ///
  /// In en, this message translates to:
  /// **'Deleting model. Please wait.'**
  String get modelManagementDeleteBusy;

  /// No description provided for @modelManagementDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Model deleted: {modelName}'**
  String modelManagementDeleteSuccess(String modelName);

  /// No description provided for @modelManagementDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete model: {error}'**
  String modelManagementDeleteFailed(String error);

  /// No description provided for @modelManagementDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get modelManagementDeleteDialogTitle;

  /// No description provided for @modelManagementDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Delete {modelName}? This removes the model file and cannot be undone.'**
  String modelManagementDeleteDialogContent(String modelName);

  /// No description provided for @modelManagementDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get modelManagementDeleteTooltip;

  /// No description provided for @modelMmprojBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Multimodal'**
  String get modelMmprojBadgeLabel;

  /// No description provided for @modelTextBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modelTextBadgeLabel;

  /// No description provided for @modelManagementSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get modelManagementSettingsTooltip;

  /// No description provided for @modelSettingsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get modelSettingsNameLabel;

  /// No description provided for @modelSettingsMmprojLabel.
  ///
  /// In en, this message translates to:
  /// **'Multimodal projector'**
  String get modelSettingsMmprojLabel;

  /// No description provided for @modelSettingsImportMmproj.
  ///
  /// In en, this message translates to:
  /// **'Import mmproj file'**
  String get modelSettingsImportMmproj;

  /// No description provided for @modelSettingsRemoveMmproj.
  ///
  /// In en, this message translates to:
  /// **'Remove mmproj'**
  String get modelSettingsRemoveMmproj;

  /// No description provided for @modelManagementMmprojImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'mmproj imported: {modelName}'**
  String modelManagementMmprojImportSuccess(String modelName);

  /// No description provided for @modelManagementMmprojImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import mmproj: {error}'**
  String modelManagementMmprojImportFailed(String error);

  /// No description provided for @modelManagementMmprojRemoveSuccess.
  ///
  /// In en, this message translates to:
  /// **'mmproj removed: {modelName}'**
  String modelManagementMmprojRemoveSuccess(String modelName);

  /// No description provided for @modelManagementMmprojRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove mmproj: {error}'**
  String modelManagementMmprojRemoveFailed(String error);

  /// No description provided for @modelManagementRenameSuccess.
  ///
  /// In en, this message translates to:
  /// **'Model renamed to: {modelName}'**
  String modelManagementRenameSuccess(String modelName);

  /// No description provided for @modelManagementRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename model: {error}'**
  String modelManagementRenameFailed(String error);

  /// No description provided for @modelSettingsRemoveMmprojConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove mmproj file for {modelName}?'**
  String modelSettingsRemoveMmprojConfirm(String modelName);

  /// No description provided for @modelErrorUnsupportedGgufFile.
  ///
  /// In en, this message translates to:
  /// **'Only .gguf files are supported.'**
  String get modelErrorUnsupportedGgufFile;

  /// No description provided for @modelErrorSelectedModelFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected model file does not exist.'**
  String get modelErrorSelectedModelFileMissing;

  /// No description provided for @modelErrorInvalidModelName.
  ///
  /// In en, this message translates to:
  /// **'The model name is invalid.'**
  String get modelErrorInvalidModelName;

  /// No description provided for @modelErrorDuplicateModelName.
  ///
  /// In en, this message translates to:
  /// **'A model with the same name already exists.'**
  String get modelErrorDuplicateModelName;

  /// No description provided for @modelErrorModelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Model not found.'**
  String get modelErrorModelNotFound;

  /// No description provided for @modelErrorSelectedMmprojFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected mmproj file does not exist.'**
  String get modelErrorSelectedMmprojFileMissing;

  /// No description provided for @modelErrorUnsupportedMmprojFile.
  ///
  /// In en, this message translates to:
  /// **'Only .gguf files starting with mmproj are supported.'**
  String get modelErrorUnsupportedMmprojFile;

  /// No description provided for @modelErrorMmprojSameAsModelFile.
  ///
  /// In en, this message translates to:
  /// **'The mmproj file cannot have the same name as the main model file.'**
  String get modelErrorMmprojSameAsModelFile;

  /// No description provided for @modelErrorEmptyModelName.
  ///
  /// In en, this message translates to:
  /// **'The model name cannot be empty.'**
  String get modelErrorEmptyModelName;

  /// No description provided for @modelErrorModelNameExists.
  ///
  /// In en, this message translates to:
  /// **'The model name already exists.'**
  String get modelErrorModelNameExists;

  /// No description provided for @modelErrorModelDirectoryExists.
  ///
  /// In en, this message translates to:
  /// **'The model directory already exists.'**
  String get modelErrorModelDirectoryExists;

  /// No description provided for @modelErrorModelNotFoundOrDeleted.
  ///
  /// In en, this message translates to:
  /// **'The model does not exist or has already been deleted.'**
  String get modelErrorModelNotFoundOrDeleted;

  /// No description provided for @modelErrorSelectedFilePathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to get the selected file path.'**
  String get modelErrorSelectedFilePathUnavailable;

  /// No description provided for @serverLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get serverLogsTitle;

  /// No description provided for @serverLogsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get serverLogsCopyAll;

  /// No description provided for @serverLogsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get serverLogsClear;

  /// No description provided for @serverLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get serverLogsCopied;

  /// No description provided for @serverLogsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} logs total'**
  String serverLogsCount(int count);

  /// No description provided for @serverLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get serverLogsEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
