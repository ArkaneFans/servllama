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
  /// **'Available to load'**
  String get chatModelStatusAvailable;

  /// No description provided for @chatModelStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get chatModelStatusFailed;

  /// No description provided for @chatModelLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Model load timed out: {model}'**
  String chatModelLoadTimeout(Object model);

  /// No description provided for @chatModelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load model: {model}'**
  String chatModelLoadFailed(Object model);

  /// No description provided for @chatModelUnloadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Model unload timed out: {model}'**
  String chatModelUnloadTimeout(Object model);

  /// No description provided for @chatModelRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {detail}'**
  String chatModelRequestFailed(Object detail);

  /// No description provided for @chatReasoningProcess.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get chatReasoningProcess;

  /// No description provided for @chatCopyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopyMessage;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEditMessage;

  /// No description provided for @chatRegenerateMessage.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatRegenerateMessage;

  /// No description provided for @chatPreviousMessageVersion.
  ///
  /// In en, this message translates to:
  /// **'Previous version'**
  String get chatPreviousMessageVersion;

  /// No description provided for @chatNextMessageVersion.
  ///
  /// In en, this message translates to:
  /// **'Next version'**
  String get chatNextMessageVersion;

  /// No description provided for @chatJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get chatJumpToLatest;

  /// No description provided for @chatMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get chatMessageCopied;

  /// No description provided for @chatMessageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Message updated'**
  String get chatMessageUpdated;

  /// No description provided for @chatEditMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessageTitle;

  /// No description provided for @chatEditMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Update this message'**
  String get chatEditMessageHint;

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

  /// No description provided for @settingsSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get settingsSectionChat;

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

  /// No description provided for @settingsChatTimeout.
  ///
  /// In en, this message translates to:
  /// **'Chat timeout'**
  String get settingsChatTimeout;

  /// No description provided for @settingsChatTimeoutValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingsChatTimeoutValue(int seconds);

  /// No description provided for @settingsChatTimeoutSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat timeout'**
  String get settingsChatTimeoutSheetTitle;

  /// No description provided for @settingsChatTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls how long chat responses can take. Increase it for multimodal image understanding when needed.'**
  String get settingsChatTimeoutDescription;

  /// No description provided for @settingsChatTimeoutFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get settingsChatTimeoutFieldLabel;

  /// No description provided for @settingsChatTimeoutUnit.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get settingsChatTimeoutUnit;

  /// No description provided for @settingsChatTimeoutRange.
  ///
  /// In en, this message translates to:
  /// **'Allowed range: {minSeconds}-{maxSeconds} s'**
  String settingsChatTimeoutRange(int minSeconds, int maxSeconds);

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

  /// No description provided for @aboutLlamaCppVersion.
  ///
  /// In en, this message translates to:
  /// **'llama.cpp {version}'**
  String aboutLlamaCppVersion(String version);

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

  /// No description provided for @serverForegroundNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'ServLlama is running'**
  String get serverForegroundNotificationTitle;

  /// No description provided for @serverForegroundNotificationText.
  ///
  /// In en, this message translates to:
  /// **'ServLlama server is running in the background'**
  String get serverForegroundNotificationText;

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
  /// **'Leave empty to disable verification'**
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

  /// No description provided for @serverConfigSectionLogging.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get serverConfigSectionLogging;

  /// No description provided for @serverConfigLogEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable logs'**
  String get serverConfigLogEnabled;

  /// No description provided for @serverConfigLogEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Controls whether inference engine runtime logs are displayed and recorded in the app'**
  String get serverConfigLogEnabledSubtitle;

  /// No description provided for @serverConfigLogLevel.
  ///
  /// In en, this message translates to:
  /// **'Log level'**
  String get serverConfigLogLevel;

  /// No description provided for @serverConfigLogLevelDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls the detail level of inference engine logs'**
  String get serverConfigLogLevelDescription;

  /// No description provided for @serverConfigLogLevelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get serverConfigLogLevelError;

  /// No description provided for @serverConfigLogLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get serverConfigLogLevelWarning;

  /// No description provided for @serverConfigLogLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get serverConfigLogLevelInfo;

  /// No description provided for @serverConfigLogLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get serverConfigLogLevelDebug;

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

  /// No description provided for @modelManagementImportAutoRenamed.
  ///
  /// In en, this message translates to:
  /// **'Model imported: {finalName}\n“{requestedName}” already exists and was renamed automatically.'**
  String modelManagementImportAutoRenamed(
    String requestedName,
    String finalName,
  );

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

  /// No description provided for @serverLogsExport.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get serverLogsExport;

  /// No description provided for @serverLogsExported.
  ///
  /// In en, this message translates to:
  /// **'Logs exported to {path}'**
  String serverLogsExported(String path);

  /// No description provided for @serverLogsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String serverLogsExportFailed(String error);

  /// No description provided for @serverLogsAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get serverLogsAutoScroll;

  /// No description provided for @serverLogsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get serverLogsFilterAll;

  /// No description provided for @serverLogsFilterEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get serverLogsFilterEngine;

  /// No description provided for @serverLogsFilterServer.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serverLogsFilterServer;

  /// No description provided for @serverLogsFilterModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get serverLogsFilterModel;

  /// No description provided for @serverLogsFilterDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get serverLogsFilterDownload;

  /// No description provided for @serverLogsFilterErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get serverLogsFilterErrors;

  /// No description provided for @engineSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Inference engine'**
  String get engineSectionTitle;

  /// No description provided for @serverStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serverStatusIdle;

  /// No description provided for @serverStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get serverStatusPreparing;

  /// No description provided for @serverStatusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get serverStatusStopping;

  /// No description provided for @serverStatusError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get serverStatusError;

  /// No description provided for @serverCancelPreparation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serverCancelPreparation;

  /// No description provided for @serverUptime.
  ///
  /// In en, this message translates to:
  /// **'Running for {duration}'**
  String serverUptime(String duration);

  /// No description provided for @serverUptimeHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String serverUptimeHoursMinutes(int hours, int minutes);

  /// No description provided for @serverUptimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String serverUptimeMinutes(int minutes);

  /// No description provided for @serverActiveModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Active model'**
  String get serverActiveModelLabel;

  /// No description provided for @serverNoModelSelected.
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get serverNoModelSelected;

  /// No description provided for @serverNoModelSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Optional - loaded on demand after start'**
  String get serverNoModelSelectedHint;

  /// No description provided for @serverModelRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'MNN needs a model before it can start'**
  String get serverModelRequiredHint;

  /// No description provided for @serverSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get serverSelectModelTitle;

  /// No description provided for @serverSelectModelNone.
  ///
  /// In en, this message translates to:
  /// **'Start without a model'**
  String get serverSelectModelNone;

  /// No description provided for @serverNoModelsForEngine.
  ///
  /// In en, this message translates to:
  /// **'No {engine} models in the library yet'**
  String serverNoModelsForEngine(String engine);

  /// No description provided for @serverPhaseLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model'**
  String get serverPhaseLoadingModel;

  /// No description provided for @serverPhaseStartingServer.
  ///
  /// In en, this message translates to:
  /// **'Starting service'**
  String get serverPhaseStartingServer;

  /// No description provided for @serverPhaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Health check'**
  String get serverPhaseVerifying;

  /// No description provided for @serverPhaseUnloadingModel.
  ///
  /// In en, this message translates to:
  /// **'Unloading model'**
  String get serverPhaseUnloadingModel;

  /// No description provided for @serverPhaseStoppingServer.
  ///
  /// In en, this message translates to:
  /// **'Stopping service'**
  String get serverPhaseStoppingServer;

  /// No description provided for @runtimeErrorPortInUse.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is currently unavailable; another service may still be using it.'**
  String runtimeErrorPortInUse(int port);

  /// No description provided for @runtimeErrorModelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the model.'**
  String get runtimeErrorModelLoadFailed;

  /// No description provided for @runtimeErrorServerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The service failed to start. Check the logs.'**
  String get runtimeErrorServerStartFailed;

  /// No description provided for @runtimeErrorServerStopFailed.
  ///
  /// In en, this message translates to:
  /// **'The service failed to stop.'**
  String get runtimeErrorServerStopFailed;

  /// No description provided for @runtimeErrorModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a model first.'**
  String get runtimeErrorModelRequired;

  /// No description provided for @runtimeErrorEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This engine is unavailable on this device.'**
  String get runtimeErrorEngineUnavailable;

  /// No description provided for @runtimeErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String runtimeErrorUnknown(String detail);

  /// No description provided for @serverOpenAccessWarning.
  ///
  /// In en, this message translates to:
  /// **'The service listens on all interfaces without an API key, so any device on the same network can access it.'**
  String get serverOpenAccessWarning;

  /// No description provided for @modelLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get modelLibraryTitle;

  /// No description provided for @modelLibraryAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a model'**
  String get modelLibraryAddTitle;

  /// No description provided for @modelLibraryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get modelLibraryFilterAll;

  /// No description provided for @modelLibraryDownloadingSection.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get modelLibraryDownloadingSection;

  /// No description provided for @modelLibraryInstalledSection.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get modelLibraryInstalledSection;

  /// No description provided for @modelAddDownload.
  ///
  /// In en, this message translates to:
  /// **'Download from a hub'**
  String get modelAddDownload;

  /// No description provided for @modelAddDownloadDesc.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face and ModelScope, with resume support'**
  String get modelAddDownloadDesc;

  /// No description provided for @modelAddGguf.
  ///
  /// In en, this message translates to:
  /// **'Import a GGUF file'**
  String get modelAddGguf;

  /// No description provided for @modelAddGgufDesc.
  ///
  /// In en, this message translates to:
  /// **'A single .gguf file for llama.cpp'**
  String get modelAddGgufDesc;

  /// No description provided for @modelAddMnnDir.
  ///
  /// In en, this message translates to:
  /// **'Import an MNN directory'**
  String get modelAddMnnDir;

  /// No description provided for @modelAddMnnDirDesc.
  ///
  /// In en, this message translates to:
  /// **'A whole model folder for the MNN engine'**
  String get modelAddMnnDirDesc;

  /// No description provided for @modelFormatExplainer.
  ///
  /// In en, this message translates to:
  /// **'GGUF is a single file; MNN models are whole directories. The engine badge on each card tells them apart.'**
  String get modelFormatExplainer;

  /// No description provided for @modelLibraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No models yet'**
  String get modelLibraryEmptyTitle;

  /// No description provided for @modelLibraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Download one, or import a file you already have.'**
  String get modelLibraryEmptyDescription;

  /// No description provided for @modelLibraryDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Delete “{modelName}”? The files will be removed from this device.'**
  String modelLibraryDeleteDialogContent(String modelName);

  /// No description provided for @modelLibraryStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get modelLibraryStatusRunning;

  /// No description provided for @modelLibraryStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get modelLibraryStatusIdle;

  /// No description provided for @modelLibraryActiveCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'The running model cannot be deleted'**
  String get modelLibraryActiveCannotDelete;

  /// No description provided for @modelLibrarySwitchEngineBlocked.
  ///
  /// In en, this message translates to:
  /// **'Stop the running service before switching engines.'**
  String get modelLibrarySwitchEngineBlocked;

  /// No description provided for @modelLibraryActivationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not activate the model. Check the server logs.'**
  String get modelLibraryActivationFailed;

  /// No description provided for @modelCapabilityChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get modelCapabilityChinese;

  /// No description provided for @modelCapabilityEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get modelCapabilityEnglish;

  /// No description provided for @modelCapabilityVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get modelCapabilityVision;

  /// No description provided for @modelCapabilityToolCalling.
  ///
  /// In en, this message translates to:
  /// **'Tool calling'**
  String get modelCapabilityToolCalling;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover models'**
  String get discoverTitle;

  /// No description provided for @discoverTabFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get discoverTabFeatured;

  /// No description provided for @discoverTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get discoverTabSearch;

  /// No description provided for @discoverDeviceMemory.
  ///
  /// In en, this message translates to:
  /// **'{available} of {total} RAM available'**
  String discoverDeviceMemory(String available, String total);

  /// No description provided for @discoverDeviceMemoryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Device memory unknown; feasibility is not checked.'**
  String get discoverDeviceMemoryUnknown;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search repositories'**
  String get discoverSearchHint;

  /// No description provided for @discoverSearchDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Search results come straight from the hub and have not been verified on a device.'**
  String get discoverSearchDisclaimer;

  /// No description provided for @discoverBackToFeatured.
  ///
  /// In en, this message translates to:
  /// **'View device-verified picks'**
  String get discoverBackToFeatured;

  /// No description provided for @discoverSortTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get discoverSortTrending;

  /// No description provided for @discoverSortDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get discoverSortDownloads;

  /// No description provided for @discoverSortLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get discoverSortLikes;

  /// No description provided for @discoverSortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get discoverSortUpdated;

  /// No description provided for @discoverFormatAll.
  ///
  /// In en, this message translates to:
  /// **'All formats'**
  String get discoverFormatAll;

  /// No description provided for @discoverFeaturedNote.
  ///
  /// In en, this message translates to:
  /// **'Every model here has been run on a real device.'**
  String get discoverFeaturedNote;

  /// No description provided for @discoverNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching repositories'**
  String get discoverNoResults;

  /// No description provided for @discoverSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a model name to search both hubs.'**
  String get discoverSearchPrompt;

  /// No description provided for @discoverErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network unreachable. Check the connection or switch route.'**
  String get discoverErrorNetwork;

  /// No description provided for @discoverErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'This repository needs a token. Add one in Settings.'**
  String get discoverErrorUnauthorized;

  /// No description provided for @discoverErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Repository not found.'**
  String get discoverErrorNotFound;

  /// No description provided for @discoverErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'The hub returned an unexpected response.'**
  String get discoverErrorMalformed;

  /// No description provided for @discoverResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String discoverResultCount(int count);

  /// No description provided for @discoverDownloadsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads'**
  String discoverDownloadsCount(int count);

  /// No description provided for @discoverUpdatedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Update time unknown'**
  String get discoverUpdatedUnknown;

  /// No description provided for @discoverUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String discoverUpdatedAt(String date);

  /// No description provided for @discoverFileCountUnknown.
  ///
  /// In en, this message translates to:
  /// **'File count available after opening'**
  String get discoverFileCountUnknown;

  /// No description provided for @discoverFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String discoverFileCount(int count);

  /// No description provided for @repoQuantSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quantization'**
  String get repoQuantSectionTitle;

  /// No description provided for @repoFilesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get repoFilesSectionTitle;

  /// No description provided for @repoDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get repoDownloadAction;

  /// No description provided for @repoEstimatedMemory.
  ///
  /// In en, this message translates to:
  /// **'Needs about {size}'**
  String repoEstimatedMemory(String size);

  /// No description provided for @repoNoGgufFiles.
  ///
  /// In en, this message translates to:
  /// **'This repository has no GGUF files.'**
  String get repoNoGgufFiles;

  /// No description provided for @repoNoMnnFiles.
  ///
  /// In en, this message translates to:
  /// **'This repository has no MNN model files.'**
  String get repoNoMnnFiles;

  /// No description provided for @repoMnnWholeDirectory.
  ///
  /// In en, this message translates to:
  /// **'MNN models download as a whole directory ({count} files).'**
  String repoMnnWholeDirectory(int count);

  /// No description provided for @feasibilityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Runs comfortably'**
  String get feasibilityComfortable;

  /// No description provided for @feasibilityTight.
  ///
  /// In en, this message translates to:
  /// **'Tight on memory'**
  String get feasibilityTight;

  /// No description provided for @feasibilityNotEnoughMemory.
  ///
  /// In en, this message translates to:
  /// **'Not enough memory'**
  String get feasibilityNotEnoughMemory;

  /// No description provided for @feasibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get feasibilityUnknown;

  /// No description provided for @catalogSummaryVerifiedSmallGeneralist.
  ///
  /// In en, this message translates to:
  /// **'Small all-rounder, quick to load'**
  String get catalogSummaryVerifiedSmallGeneralist;

  /// No description provided for @catalogSummaryVerifiedEntryLevel.
  ///
  /// In en, this message translates to:
  /// **'Entry level, runs on almost anything'**
  String get catalogSummaryVerifiedEntryLevel;

  /// No description provided for @catalogSummaryVerifiedBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced quality and speed'**
  String get catalogSummaryVerifiedBalanced;

  /// No description provided for @catalogSummaryVerifiedMnnDefault.
  ///
  /// In en, this message translates to:
  /// **'The MNN engine\'s default pick'**
  String get catalogSummaryVerifiedMnnDefault;

  /// No description provided for @catalogSummaryVerifiedMnnBalanced.
  ///
  /// In en, this message translates to:
  /// **'Stronger MNN model for capable phones'**
  String get catalogSummaryVerifiedMnnBalanced;

  /// No description provided for @catalogSummaryVerifiedMnnVision.
  ///
  /// In en, this message translates to:
  /// **'MNN model with image understanding'**
  String get catalogSummaryVerifiedMnnVision;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No download tasks'**
  String get downloadsEmpty;

  /// No description provided for @downloadStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadStatusQueued;

  /// No description provided for @downloadStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadStatusRunning;

  /// No description provided for @downloadStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadStatusPaused;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStatusFailed;

  /// No description provided for @downloadStatusDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get downloadStatusDownloaded;

  /// No description provided for @downloadStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get downloadStatusCompleted;

  /// No description provided for @downloadPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPause;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResume;

  /// No description provided for @downloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadCancel;

  /// No description provided for @downloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadRetry;

  /// No description provided for @downloadSwitchSource.
  ///
  /// In en, this message translates to:
  /// **'Switch source'**
  String get downloadSwitchSource;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Started downloading {modelName}'**
  String downloadStarted(String modelName);

  /// No description provided for @downloadStartedAutoRenamed.
  ///
  /// In en, this message translates to:
  /// **'Started downloading {finalName}\n“{requestedName}” already exists and was renamed automatically.'**
  String downloadStartedAutoRenamed(String requestedName, String finalName);

  /// No description provided for @downloadProgressDetail.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} - {speed}/s'**
  String downloadProgressDetail(String received, String total, String speed);

  /// No description provided for @downloadProgressUnknownTotal.
  ///
  /// In en, this message translates to:
  /// **'{received} downloaded - {speed}/s'**
  String downloadProgressUnknownTotal(String received, String speed);

  /// No description provided for @downloadRemaining.
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String downloadRemaining(String duration);

  /// No description provided for @downloadFilesProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files'**
  String downloadFilesProgress(int done, int total);

  /// No description provided for @downloadErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted'**
  String get downloadErrorNetwork;

  /// No description provided for @downloadErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Access denied, a token may be required'**
  String get downloadErrorUnauthorized;

  /// No description provided for @downloadErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists on the hub'**
  String get downloadErrorNotFound;

  /// No description provided for @downloadErrorDiskFull.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage'**
  String get downloadErrorDiskFull;

  /// No description provided for @downloadErrorIntegrity.
  ///
  /// In en, this message translates to:
  /// **'File length or checksum does not match'**
  String get downloadErrorIntegrity;

  /// No description provided for @downloadErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get downloadErrorCancelled;

  /// No description provided for @downloadErrorAlreadyQueued.
  ///
  /// In en, this message translates to:
  /// **'The same model is already in the download queue'**
  String get downloadErrorAlreadyQueued;

  /// No description provided for @downloadCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get downloadCancelDialogTitle;

  /// No description provided for @downloadCancelDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Cancel “{modelName}”? Downloaded bytes will be discarded.'**
  String downloadCancelDialogContent(String modelName);

  /// No description provided for @downloadForegroundTitle.
  ///
  /// In en, this message translates to:
  /// **'ServLlama is downloading models'**
  String get downloadForegroundTitle;

  /// No description provided for @downloadForegroundText.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks - {percent}%'**
  String downloadForegroundText(int count, int percent);

  /// No description provided for @settingsSectionDownload.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsSectionDownload;

  /// No description provided for @settingsHuggingFaceRoute.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face route'**
  String get settingsHuggingFaceRoute;

  /// No description provided for @settingsHuggingFaceRouteDescription.
  ///
  /// In en, this message translates to:
  /// **'The mirror helps when the official host is unreachable.'**
  String get settingsHuggingFaceRouteDescription;

  /// No description provided for @settingsRouteAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsRouteAuto;

  /// No description provided for @settingsRouteOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get settingsRouteOfficial;

  /// No description provided for @settingsRouteMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get settingsRouteMirror;

  /// No description provided for @settingsHuggingFaceToken.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face token'**
  String get settingsHuggingFaceToken;

  /// No description provided for @settingsModelScopeToken.
  ///
  /// In en, this message translates to:
  /// **'ModelScope token'**
  String get settingsModelScopeToken;

  /// No description provided for @settingsTokenDescription.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device only. Never written to logs or exported files.'**
  String get settingsTokenDescription;

  /// No description provided for @settingsTokenNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsTokenNotSet;

  /// No description provided for @settingsTokenSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get settingsTokenSheetTitle;

  /// No description provided for @settingsWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download over Wi-Fi only'**
  String get settingsWifiOnly;

  /// No description provided for @settingsWifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause tasks when the network switches to cellular'**
  String get settingsWifiOnlySubtitle;

  /// No description provided for @settingsMaxConcurrentDownloads.
  ///
  /// In en, this message translates to:
  /// **'Parallel downloads'**
  String get settingsMaxConcurrentDownloads;

  /// No description provided for @settingsMaxConcurrentDownloadsDescription.
  ///
  /// In en, this message translates to:
  /// **'How many tasks may run at once'**
  String get settingsMaxConcurrentDownloadsDescription;

  /// No description provided for @settingsSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsSectionStorage;

  /// No description provided for @settingsStorageModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsStorageModels;

  /// No description provided for @settingsStorageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Unfinished downloads'**
  String get settingsStorageDownloads;

  /// No description provided for @settingsClearStaging.
  ///
  /// In en, this message translates to:
  /// **'Clear unfinished downloads'**
  String get settingsClearStaging;

  /// No description provided for @settingsClearStagingDone.
  ///
  /// In en, this message translates to:
  /// **'Cleared unfinished downloads'**
  String get settingsClearStagingDone;

  /// No description provided for @aboutMnnVersion.
  ///
  /// In en, this message translates to:
  /// **'MNN version'**
  String get aboutMnnVersion;

  /// No description provided for @aboutMnnVersionDetail.
  ///
  /// In en, this message translates to:
  /// **'MNN version: {value}'**
  String aboutMnnVersionDetail(String value);

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a model to start'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The service starts on its own once a model is chosen.'**
  String get chatEmptyDescription;

  /// No description provided for @chatEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get chatEmptyAction;

  /// No description provided for @chatChooseEngineToStart.
  ///
  /// In en, this message translates to:
  /// **'Choose the inference engine to start'**
  String get chatChooseEngineToStart;

  /// No description provided for @chatEngineDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model: {model}'**
  String chatEngineDefaultModel(String model);

  /// No description provided for @chatCurrentRunning.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get chatCurrentRunning;

  /// No description provided for @chatLoadModelAction.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get chatLoadModelAction;

  /// No description provided for @chatPreparingModel.
  ///
  /// In en, this message translates to:
  /// **'Preparing model'**
  String get chatPreparingModel;

  /// No description provided for @chatEmptyNoModelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Download a model first. Everything runs on this device afterwards.'**
  String get chatEmptyNoModelsDescription;
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
