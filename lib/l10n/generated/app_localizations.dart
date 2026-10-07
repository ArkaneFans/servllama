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

  /// No description provided for @v2McpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers yet. Tap + to add one.'**
  String get v2McpEmpty;

  /// No description provided for @v2SkillsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skills yet. Tap + to import one.'**
  String get v2SkillsEmpty;

  /// No description provided for @v2ManageMcp.
  ///
  /// In en, this message translates to:
  /// **'Manage MCP'**
  String get v2ManageMcp;

  /// No description provided for @v2ManageSkills.
  ///
  /// In en, this message translates to:
  /// **'Manage skills'**
  String get v2ManageSkills;

  /// No description provided for @v2LocalTools.
  ///
  /// In en, this message translates to:
  /// **'Local tools'**
  String get v2LocalTools;

  /// No description provided for @v2AssistantManagement.
  ///
  /// In en, this message translates to:
  /// **'Assistant management'**
  String get v2AssistantManagement;

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

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

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
  /// **'An LLM inference server on your phone'**
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

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @aboutLlamaCppLabel.
  ///
  /// In en, this message translates to:
  /// **'llama.cpp'**
  String get aboutLlamaCppLabel;

  /// No description provided for @aboutSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get aboutSystem;

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
  /// **'The maximum number of context tokens the model can attend to. A context size that is too high may cause an out-of-memory crash.'**
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

  /// No description provided for @llamaCppBackendTitle.
  ///
  /// In en, this message translates to:
  /// **'Acceleration backend'**
  String get llamaCppBackendTitle;

  /// No description provided for @llamaCppBackendNextStart.
  ///
  /// In en, this message translates to:
  /// **'Changes apply the next time the server starts.'**
  String get llamaCppBackendNextStart;

  /// No description provided for @llamaCppBackendRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check available backends'**
  String get llamaCppBackendRefresh;

  /// No description provided for @llamaCppBackendStopServer.
  ///
  /// In en, this message translates to:
  /// **'Stop the server to detect GPU and NPU support.'**
  String get llamaCppBackendStopServer;

  /// No description provided for @llamaCppBackendCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get llamaCppBackendCpu;

  /// No description provided for @llamaCppBackendOpencl.
  ///
  /// In en, this message translates to:
  /// **'GPU (OpenCL)'**
  String get llamaCppBackendOpencl;

  /// No description provided for @llamaCppBackendHexagon.
  ///
  /// In en, this message translates to:
  /// **'Hexagon (experimental)'**
  String get llamaCppBackendHexagon;

  /// No description provided for @llamaCppBackendCpuDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs entirely on the CPU. Broadest compatibility.'**
  String get llamaCppBackendCpuDescription;

  /// No description provided for @llamaCppBackendOpenclDescription.
  ///
  /// In en, this message translates to:
  /// **'Offload layers to Adreno GPU via OpenCL.'**
  String get llamaCppBackendOpenclDescription;

  /// No description provided for @llamaCppBackendHexagonDescription.
  ///
  /// In en, this message translates to:
  /// **'NPU acceleration on Snapdragon 8 Gen 2 and later.'**
  String get llamaCppBackendHexagonDescription;

  /// No description provided for @llamaCppBackendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device.'**
  String get llamaCppBackendUnavailable;

  /// No description provided for @llamaCppBackendProbeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check llama.cpp backends. CPU will be used if nothing else is available. Details are in the engine log.'**
  String get llamaCppBackendProbeFailed;

  /// No description provided for @llamaCppBackendSavedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The saved backend is currently unavailable. Choose another backend before starting, or use Auto.'**
  String get llamaCppBackendSavedUnavailable;

  /// No description provided for @llamaCppGpuLayers.
  ///
  /// In en, this message translates to:
  /// **'Offloaded layers'**
  String get llamaCppGpuLayers;

  /// No description provided for @llamaCppGpuLayersDescription.
  ///
  /// In en, this message translates to:
  /// **'How many layers to place on the selected GPU or NPU. Higher values use the accelerator more.'**
  String get llamaCppGpuLayersDescription;

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

  /// No description provided for @modelSettingsDownloadMmproj.
  ///
  /// In en, this message translates to:
  /// **'Download mmproj'**
  String get modelSettingsDownloadMmproj;

  /// No description provided for @modelSettingsReplaceMmproj.
  ///
  /// In en, this message translates to:
  /// **'Replace mmproj'**
  String get modelSettingsReplaceMmproj;

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
  /// **'Only .gguf files whose names contain mmproj are supported.'**
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

  /// No description provided for @appLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'App logs'**
  String get appLogsTitle;

  /// No description provided for @appLogsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy filtered logs'**
  String get appLogsCopyAll;

  /// No description provided for @appLogsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs'**
  String get appLogsClear;

  /// No description provided for @appLogsClearFailed.
  ///
  /// In en, this message translates to:
  /// **'The log view was cleared, but saved log files could not be deleted.'**
  String get appLogsClearFailed;

  /// No description provided for @appLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get appLogsCopied;

  /// No description provided for @appLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get appLogsEmpty;

  /// No description provided for @appLogsExport.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get appLogsExport;

  /// No description provided for @appLogsExported.
  ///
  /// In en, this message translates to:
  /// **'Logs exported to {path}'**
  String appLogsExported(String path);

  /// No description provided for @appLogsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String appLogsExportFailed(String error);

  /// No description provided for @appLogsAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get appLogsAutoScroll;

  /// No description provided for @appLogsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get appLogsFilterAll;

  /// No description provided for @appLogsFilterEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get appLogsFilterEngine;

  /// No description provided for @appLogsFilterServer.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get appLogsFilterServer;

  /// No description provided for @appLogsFilterModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get appLogsFilterModel;

  /// No description provided for @appLogsFilterDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get appLogsFilterDownload;

  /// No description provided for @appLogsFilterErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get appLogsFilterErrors;

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

  /// No description provided for @serverModelRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Select a model before starting'**
  String get serverModelRequiredHint;

  /// No description provided for @serverSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get serverSelectModelTitle;

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
  /// **'No models yet. Download from Discover or import a local model.'**
  String get modelLibraryEmptyTitle;

  /// No description provided for @modelLibraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Download one, or import a file you already have.'**
  String get modelLibraryEmptyDescription;

  /// No description provided for @modelLibrarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search model names'**
  String get modelLibrarySearchHint;

  /// No description provided for @modelLibraryEmptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching models'**
  String get modelLibraryEmptySearchTitle;

  /// No description provided for @modelLibraryEmptySearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different name.'**
  String get modelLibraryEmptySearchDescription;

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

  /// No description provided for @repoDownloadQueued.
  ///
  /// In en, this message translates to:
  /// **'In the download queue'**
  String get repoDownloadQueued;

  /// No description provided for @repoVisionOn.
  ///
  /// In en, this message translates to:
  /// **'Vision · On'**
  String get repoVisionOn;

  /// No description provided for @repoVisionOff.
  ///
  /// In en, this message translates to:
  /// **'Vision · Off'**
  String get repoVisionOff;

  /// No description provided for @repoVisionSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get repoVisionSheetTitle;

  /// No description provided for @repoVisionEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable vision'**
  String get repoVisionEnable;

  /// No description provided for @repoVisionMmprojSection.
  ///
  /// In en, this message translates to:
  /// **'Vision projector'**
  String get repoVisionMmprojSection;

  /// No description provided for @repoVisionDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'The selected projector will download with the model.'**
  String get repoVisionDownloadHint;

  /// No description provided for @repoVisionDownloadDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Download the text model only. You can add a vision projector in model settings later.'**
  String get repoVisionDownloadDisabledHint;

  /// No description provided for @modelSettingsVisionDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turning vision off keeps your downloaded projectors.'**
  String get modelSettingsVisionDisabledHint;

  /// No description provided for @modelSettingsVisionNeedsProjector.
  ///
  /// In en, this message translates to:
  /// **'Download and select a projector to enable image input.'**
  String get modelSettingsVisionNeedsProjector;

  /// No description provided for @modelSettingsProjectorsHint.
  ///
  /// In en, this message translates to:
  /// **'Keep multiple versions and select one to use at a time.'**
  String get modelSettingsProjectorsHint;

  /// No description provided for @modelSettingsLocalVisionHint.
  ///
  /// In en, this message translates to:
  /// **'Import a compatible vision projector to enable image input.'**
  String get modelSettingsLocalVisionHint;

  /// No description provided for @modelSettingsProjectorDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get modelSettingsProjectorDownloaded;

  /// No description provided for @modelSettingsProjectorSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get modelSettingsProjectorSelected;

  /// No description provided for @modelSettingsProjectorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{fileName}”? If it is selected, another downloaded version will be used. Vision turns off when no versions remain.'**
  String modelSettingsProjectorDeleteConfirm(String fileName);

  /// No description provided for @modelSettingsOpenRepository.
  ///
  /// In en, this message translates to:
  /// **'Open model repository'**
  String get modelSettingsOpenRepository;

  /// No description provided for @modelSettingsRepositoryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the model repository. Please try again.'**
  String get modelSettingsRepositoryOpenFailed;

  /// No description provided for @modelSettingsVisionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update vision settings: {error}'**
  String modelSettingsVisionUpdateFailed(String error);

  /// No description provided for @modelSettingsProjectorDownloadPending.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel projector downloads before renaming or deleting the model.'**
  String get modelSettingsProjectorDownloadPending;

  /// No description provided for @repoVisionNoMmproj.
  ///
  /// In en, this message translates to:
  /// **'This repository has no mmproj files.'**
  String get repoVisionNoMmproj;

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
  /// **'Balanced quality and speed for everyday use'**
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

  /// No description provided for @catalogSummaryVerifiedStrong.
  ///
  /// In en, this message translates to:
  /// **'Better quality, for capable devices'**
  String get catalogSummaryVerifiedStrong;

  /// No description provided for @catalogSummaryVerifiedLfm25.
  ///
  /// In en, this message translates to:
  /// **'2.6B multilingual model for everyday use'**
  String get catalogSummaryVerifiedLfm25;

  /// No description provided for @catalogSummaryVerifiedMnnSmall.
  ///
  /// In en, this message translates to:
  /// **'Compact MNN pick, easy on most phones'**
  String get catalogSummaryVerifiedMnnSmall;

  /// No description provided for @catalogSummaryVerifiedMnnEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday MNN model, balanced quality and speed'**
  String get catalogSummaryVerifiedMnnEveryday;

  /// No description provided for @catalogSummaryVerifiedGemma4E2B.
  ///
  /// In en, this message translates to:
  /// **'Lightweight vision model for mid-range phones'**
  String get catalogSummaryVerifiedGemma4E2B;

  /// No description provided for @catalogSummaryVerifiedGemma4E4B.
  ///
  /// In en, this message translates to:
  /// **'Stronger vision model for capable phones'**
  String get catalogSummaryVerifiedGemma4E4B;

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

  /// No description provided for @downloadQueued.
  ///
  /// In en, this message translates to:
  /// **'{fileName} has been added to the download queue'**
  String downloadQueued(String fileName);

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'{fileName} has finished downloading'**
  String downloadCompleted(String fileName);

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

  /// No description provided for @downloadWifiOnlyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'On a mobile network'**
  String get downloadWifiOnlyDialogTitle;

  /// No description provided for @downloadWifiOnlyDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'“Download over Wi-Fi only” is on, so downloads are paused on mobile networks. Continue over mobile data anyway?'**
  String get downloadWifiOnlyDialogMessage;

  /// No description provided for @downloadWifiOnlyDialogAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow mobile data'**
  String get downloadWifiOnlyDialogAllow;

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

  /// No description provided for @mnnBackendTitle.
  ///
  /// In en, this message translates to:
  /// **'MNN inference backend'**
  String get mnnBackendTitle;

  /// No description provided for @mnnBackendNextStart.
  ///
  /// In en, this message translates to:
  /// **'Changes apply the next time a model is loaded.'**
  String get mnnBackendNextStart;

  /// No description provided for @mnnBackendActive.
  ///
  /// In en, this message translates to:
  /// **'Loaded backend: {backend}'**
  String mnnBackendActive(String backend);

  /// No description provided for @mnnBackendRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check available backends'**
  String get mnnBackendRefresh;

  /// No description provided for @mnnBackendCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get mnnBackendCpu;

  /// No description provided for @mnnBackendOpencl.
  ///
  /// In en, this message translates to:
  /// **'OpenCL GPU'**
  String get mnnBackendOpencl;

  /// No description provided for @mnnBackendVulkan.
  ///
  /// In en, this message translates to:
  /// **'Vulkan GPU'**
  String get mnnBackendVulkan;

  /// No description provided for @mnnBackendHexagon.
  ///
  /// In en, this message translates to:
  /// **'Hexagon NPU (experimental)'**
  String get mnnBackendHexagon;

  /// No description provided for @mnnBackendCpuDescription.
  ///
  /// In en, this message translates to:
  /// **'Default, with the broadest model compatibility.'**
  String get mnnBackendCpuDescription;

  /// No description provided for @mnnBackendGpuDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses GPU acceleration. Loading a model for the first time requires some initialization time.'**
  String get mnnBackendGpuDescription;

  /// No description provided for @mnnBackendHexagonDescription.
  ///
  /// In en, this message translates to:
  /// **'Use a model exported for Hexagon, preferably symmetric 4-bit quantization with Transformer C4. Can speed up long input processing; token generation may be slower than CPU.'**
  String get mnnBackendHexagonDescription;

  /// No description provided for @runtimeErrorModelBackendIncompatible.
  ///
  /// In en, this message translates to:
  /// **'This model format is incompatible with Hexagon NPU. Select CPU/GPU, or import a model re-exported for Hexagon.'**
  String get runtimeErrorModelBackendIncompatible;

  /// No description provided for @mnnBackendHexagonArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Automatically matched the {architecture} runtime.'**
  String mnnBackendHexagonArchitecture(String architecture);

  /// No description provided for @mnnBackendNotBuilt.
  ///
  /// In en, this message translates to:
  /// **'Not included in this plugin build.'**
  String get mnnBackendNotBuilt;

  /// No description provided for @mnnBackendNativeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The MNN native runtime is unavailable.'**
  String get mnnBackendNativeUnavailable;

  /// No description provided for @mnnBackendLibrariesMissing.
  ///
  /// In en, this message translates to:
  /// **'This installation is missing compatible Hexagon runtime libraries.'**
  String get mnnBackendLibrariesMissing;

  /// No description provided for @mnnBackendDriverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The device driver is unavailable or inaccessible to this app.'**
  String get mnnBackendDriverUnavailable;

  /// No description provided for @mnnBackendDeviceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device could not match or initialize a supported Hexagon DSP runtime.'**
  String get mnnBackendDeviceUnsupported;

  /// No description provided for @mnnBackendNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Availability has not been checked.'**
  String get mnnBackendNotChecked;

  /// No description provided for @mnnBackendProbeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check backends. Try again, or select CPU. Details are in the engine log.'**
  String get mnnBackendProbeFailed;

  /// No description provided for @mnnBackendSavedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The saved backend is currently unavailable. Select another backend before starting.'**
  String get mnnBackendSavedUnavailable;

  /// No description provided for @runtimeErrorMnnBackendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected MNN backend is unavailable. Choose CPU or another available backend in Service settings.'**
  String get runtimeErrorMnnBackendUnavailable;

  /// No description provided for @mnnRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'MNN runtime'**
  String get mnnRuntimeTitle;

  /// No description provided for @mnnUseMmap.
  ///
  /// In en, this message translates to:
  /// **'Use mmap'**
  String get mnnUseMmap;

  /// No description provided for @mnnUseMmapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maps model weights from disk to reduce memory. The first load builds a cache.'**
  String get mnnUseMmapSubtitle;

  /// No description provided for @mnnPrecision.
  ///
  /// In en, this message translates to:
  /// **'Precision'**
  String get mnnPrecision;

  /// No description provided for @mnnPrecisionDescription.
  ///
  /// In en, this message translates to:
  /// **'Low is faster and uses less memory. High is more accurate.'**
  String get mnnPrecisionDescription;

  /// No description provided for @mnnPrecisionLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get mnnPrecisionLow;

  /// No description provided for @mnnPrecisionHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get mnnPrecisionHigh;

  /// No description provided for @mnnThreadNum.
  ///
  /// In en, this message translates to:
  /// **'Generation threads'**
  String get mnnThreadNum;

  /// No description provided for @mnnThreadNumDescription.
  ///
  /// In en, this message translates to:
  /// **'CPU threads used for generation.'**
  String get mnnThreadNumDescription;

  /// No description provided for @mnnMmapCache.
  ///
  /// In en, this message translates to:
  /// **'Clear mmap cache'**
  String get mnnMmapCache;

  /// No description provided for @mnnMmapCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current cache: {size}'**
  String mnnMmapCacheSubtitle(String size);

  /// No description provided for @mnnMmapCacheEmpty.
  ///
  /// In en, this message translates to:
  /// **'No mmap cache yet'**
  String get mnnMmapCacheEmpty;

  /// No description provided for @mnnMmapCacheStopServer.
  ///
  /// In en, this message translates to:
  /// **'Stop the server before clearing the cache.'**
  String get mnnMmapCacheStopServer;

  /// No description provided for @mnnMmapCacheClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get mnnMmapCacheClearAction;

  /// No description provided for @mnnMmapCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear mmap cache?'**
  String get mnnMmapCacheDialogTitle;

  /// No description provided for @mnnMmapCacheDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This deletes generated mmap and GPU runtime caches ({size}). The next model load will rebuild them.'**
  String mnnMmapCacheDialogContent(String size);

  /// No description provided for @mnnMmapCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared {size} of mmap cache'**
  String mnnMmapCacheCleared(String size);

  /// No description provided for @mnnMmapCacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the mmap cache.'**
  String get mnnMmapCacheClearFailed;

  /// No description provided for @v2FirstAssistants.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get v2FirstAssistants;

  /// No description provided for @v2Chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get v2Chat;

  /// No description provided for @v2Models.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get v2Models;

  /// No description provided for @v2Add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get v2Add;

  /// No description provided for @v2OperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get v2OperationFailed;

  /// No description provided for @v2NoInstructions.
  ///
  /// In en, this message translates to:
  /// **'Default conversation behavior'**
  String get v2NoInstructions;

  /// No description provided for @v2Duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get v2Duplicate;

  /// No description provided for @v2AssistantEditor.
  ///
  /// In en, this message translates to:
  /// **'Assistant settings'**
  String get v2AssistantEditor;

  /// No description provided for @v2Name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get v2Name;

  /// No description provided for @v2Instructions.
  ///
  /// In en, this message translates to:
  /// **'System instructions'**
  String get v2Instructions;

  /// No description provided for @v2Connection.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get v2Connection;

  /// No description provided for @v2LocalInference.
  ///
  /// In en, this message translates to:
  /// **'Local inference'**
  String get v2LocalInference;

  /// No description provided for @v2MissingTarget.
  ///
  /// In en, this message translates to:
  /// **'Target unavailable. Check that its provider is enabled and the model is listed, or choose another.'**
  String get v2MissingTarget;

  /// No description provided for @v2Model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get v2Model;

  /// No description provided for @v2CurrentLocal.
  ///
  /// In en, this message translates to:
  /// **'Current local model'**
  String get v2CurrentLocal;

  /// No description provided for @v2ModelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get v2ModelId;

  /// No description provided for @v2Connections.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get v2Connections;

  /// No description provided for @v2ConnectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a provider and its models to use them in chat.'**
  String get v2ConnectionsEmpty;

  /// No description provided for @v2ConnectionEditor.
  ///
  /// In en, this message translates to:
  /// **'Provider settings'**
  String get v2ConnectionEditor;

  /// No description provided for @v2Protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get v2Protocol;

  /// No description provided for @v2BaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get v2BaseUrl;

  /// No description provided for @v2BaseUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Include /v1 or /v1beta. Use HTTP only on a trusted local network.'**
  String get v2BaseUrlHelp;

  /// No description provided for @v2ApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get v2ApiKey;

  /// No description provided for @v2KeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Stored securely. Leave blank to keep the existing key.'**
  String get v2KeyHelp;

  /// No description provided for @v2ClearKey.
  ///
  /// In en, this message translates to:
  /// **'Clear saved key'**
  String get v2ClearKey;

  /// No description provided for @v2ModelsHelp.
  ///
  /// In en, this message translates to:
  /// **'Model IDs, one per line (manual entry supported)'**
  String get v2ModelsHelp;

  /// No description provided for @v2Images.
  ///
  /// In en, this message translates to:
  /// **'Image input supported'**
  String get v2Images;

  /// No description provided for @v2Tools.
  ///
  /// In en, this message translates to:
  /// **'Tool calls supported'**
  String get v2Tools;

  /// No description provided for @v2FetchModels.
  ///
  /// In en, this message translates to:
  /// **'Fetch models'**
  String get v2FetchModels;

  /// No description provided for @v2TestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test provider'**
  String get v2TestConnection;

  /// No description provided for @v2TestPassed.
  ///
  /// In en, this message translates to:
  /// **'Test succeeded. Changes are not saved yet.'**
  String get v2TestPassed;

  /// No description provided for @v2DraftHelp.
  ///
  /// In en, this message translates to:
  /// **'Save to apply changes; going back discards unsaved edits. Testing and model discovery do not save automatically.'**
  String get v2DraftHelp;

  /// No description provided for @v2Profile.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get v2Profile;

  /// No description provided for @v2ProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'Local user details stay on this device. Your avatar and name are used for display and are not automatically added to model requests.'**
  String get v2ProfileHelp;

  /// No description provided for @v2KeepOneAssistant.
  ///
  /// In en, this message translates to:
  /// **'Create another assistant before deleting the last one.'**
  String get v2KeepOneAssistant;

  /// No description provided for @v2DeleteConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Deleting this provider clears model selections for its assistants. Conversations and messages remain; select a model before sending.'**
  String get v2DeleteConnectionHelp;

  /// No description provided for @v2Avatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get v2Avatar;

  /// No description provided for @v2AvatarHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a local image or emoji for your avatar. Used for display only.'**
  String get v2AvatarHelp;

  /// No description provided for @v2AvatarImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get v2AvatarImage;

  /// No description provided for @v2AvatarEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose emoji'**
  String get v2AvatarEmoji;

  /// No description provided for @v2AvatarReset.
  ///
  /// In en, this message translates to:
  /// **'Reset avatar'**
  String get v2AvatarReset;

  /// No description provided for @v2AvatarImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose an image under 10 MB, with each side at most 8192 pixels and at most 32 megapixels.'**
  String get v2AvatarImageTooLarge;

  /// No description provided for @v2AvatarInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'This image could not be read. Choose another image.'**
  String get v2AvatarInvalidImage;

  /// No description provided for @v2AvatarEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose avatar emoji'**
  String get v2AvatarEmojiTitle;

  /// No description provided for @v2AvatarEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'Enter one emoji or character'**
  String get v2AvatarEmojiHint;

  /// No description provided for @v2ChatUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get v2ChatUserName;

  /// No description provided for @v2ChatAssistantName.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get v2ChatAssistantName;

  /// No description provided for @v2UserName.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get v2UserName;

  /// No description provided for @v2ProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get v2ProfileDescription;

  /// No description provided for @v2ProfileDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'A short introduction about yourself…'**
  String get v2ProfileDescriptionHint;

  /// No description provided for @v2StartLocal.
  ///
  /// In en, this message translates to:
  /// **'Load this conversation\'s local model'**
  String get v2StartLocal;

  /// No description provided for @v2RemoteReady.
  ///
  /// In en, this message translates to:
  /// **'Chat directly with the selected provider'**
  String get v2RemoteReady;

  /// No description provided for @v2Skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get v2Skills;

  /// No description provided for @v2SkillsHelp.
  ///
  /// In en, this message translates to:
  /// **'Import static packages containing SKILL.md, then select them in assistant permissions.'**
  String get v2SkillsHelp;

  /// No description provided for @v2ImportSkill.
  ///
  /// In en, this message translates to:
  /// **'Import skill (ZIP / Markdown)'**
  String get v2ImportSkill;

  /// No description provided for @v2ScriptsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Contains script references. Only static instructions are used; scripts are not executed.'**
  String get v2ScriptsUnsupported;

  /// No description provided for @v2Mcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get v2Mcp;

  /// No description provided for @v2McpHelp.
  ///
  /// In en, this message translates to:
  /// **'Streamable HTTP and legacy SSE. Select tools per assistant; approve each remote call.'**
  String get v2McpHelp;

  /// No description provided for @v2McpToken.
  ///
  /// In en, this message translates to:
  /// **'Static bearer token'**
  String get v2McpToken;

  /// No description provided for @v2McpHeaders.
  ///
  /// In en, this message translates to:
  /// **'Custom HTTP headers (JSON)'**
  String get v2McpHeaders;

  /// No description provided for @v2McpHeadersHelp.
  ///
  /// In en, this message translates to:
  /// **'JSON string values, for example an X-API-Key header. Stored securely; leave blank to keep existing headers. Protocol headers are managed by the app.'**
  String get v2McpHeadersHelp;

  /// No description provided for @v2ClearMcpToken.
  ///
  /// In en, this message translates to:
  /// **'Remove saved bearer token'**
  String get v2ClearMcpToken;

  /// No description provided for @v2ClearMcpHeaders.
  ///
  /// In en, this message translates to:
  /// **'Remove saved custom headers'**
  String get v2ClearMcpHeaders;

  /// No description provided for @v2ShowHideCredential.
  ///
  /// In en, this message translates to:
  /// **'Show / hide credential'**
  String get v2ShowHideCredential;

  /// No description provided for @v2DiscoverTools.
  ///
  /// In en, this message translates to:
  /// **'Connect and discover tools'**
  String get v2DiscoverTools;

  /// No description provided for @v2PermissionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Permissions are captured when a run starts. Revocation stops affected runs; additions apply next time.'**
  String get v2PermissionsHelp;

  /// No description provided for @v2ToolClock.
  ///
  /// In en, this message translates to:
  /// **'Current time'**
  String get v2ToolClock;

  /// No description provided for @v2ToolRead.
  ///
  /// In en, this message translates to:
  /// **'Read conversation files'**
  String get v2ToolRead;

  /// No description provided for @v2ToolAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask the user'**
  String get v2ToolAsk;

  /// No description provided for @v2ToolSkill.
  ///
  /// In en, this message translates to:
  /// **'Read selected skill resources'**
  String get v2ToolSkill;

  /// No description provided for @v2ToolActivity.
  ///
  /// In en, this message translates to:
  /// **'Tool call history'**
  String get v2ToolActivity;

  /// No description provided for @v2ToolHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tool call records in this conversation.'**
  String get v2ToolHistoryEmpty;

  /// No description provided for @v2AwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get v2AwaitingApproval;

  /// No description provided for @v2Succeeded.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get v2Succeeded;

  /// No description provided for @v2UnknownOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get v2UnknownOutcome;

  /// No description provided for @v2Rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get v2Rejected;

  /// No description provided for @v2Cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get v2Cancelled;

  /// No description provided for @v2Executing.
  ///
  /// In en, this message translates to:
  /// **'Executing'**
  String get v2Executing;

  /// No description provided for @v2Failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get v2Failed;

  /// No description provided for @v2UnknownOutcomeHelp.
  ///
  /// In en, this message translates to:
  /// **'The operation may have taken effect. It will not retry automatically. Verify the outcome before starting a new run.'**
  String get v2UnknownOutcomeHelp;

  /// No description provided for @v2Details.
  ///
  /// In en, this message translates to:
  /// **'Arguments, target and receipt'**
  String get v2Details;

  /// No description provided for @v2YourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get v2YourAnswer;

  /// No description provided for @v2Reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get v2Reject;

  /// No description provided for @v2ApproveOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get v2ApproveOnce;

  /// No description provided for @v2Review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get v2Review;

  /// No description provided for @v2Rerun.
  ///
  /// In en, this message translates to:
  /// **'Execute as a new run'**
  String get v2Rerun;

  /// No description provided for @v2RerunHelp.
  ///
  /// In en, this message translates to:
  /// **'Tools use current permissions; actions that require approval will ask again.'**
  String get v2RerunHelp;

  /// No description provided for @v2BudgetReached.
  ///
  /// In en, this message translates to:
  /// **'Run budget reached. Completed results are retained.'**
  String get v2BudgetReached;

  /// No description provided for @v2Interrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted. Create a new task explicitly to retry.'**
  String get v2Interrupted;

  /// No description provided for @v2Speech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get v2Speech;

  /// No description provided for @v2Asr.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get v2Asr;

  /// No description provided for @v2Tts.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get v2Tts;

  /// No description provided for @v2Tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get v2Tasks;

  /// No description provided for @v2SpeechModels.
  ///
  /// In en, this message translates to:
  /// **'Speech models'**
  String get v2SpeechModels;

  /// No description provided for @v2LlmModels.
  ///
  /// In en, this message translates to:
  /// **'Language models'**
  String get v2LlmModels;

  /// No description provided for @v2Voices.
  ///
  /// In en, this message translates to:
  /// **'Reference voices'**
  String get v2Voices;

  /// No description provided for @v2SpeechLocalHelp.
  ///
  /// In en, this message translates to:
  /// **'Audio stays on this device. Record or import a file, then view the transcript below.'**
  String get v2SpeechLocalHelp;

  /// No description provided for @v2SpeechAudioInput.
  ///
  /// In en, this message translates to:
  /// **'Recording & audio'**
  String get v2SpeechAudioInput;

  /// No description provided for @v2RecordingReady.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone to record'**
  String get v2RecordingReady;

  /// No description provided for @v2RecordingNow.
  ///
  /// In en, this message translates to:
  /// **'Recording · tap to stop'**
  String get v2RecordingNow;

  /// No description provided for @v2SpeechCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get v2SpeechCreatedAt;

  /// No description provided for @v2SynthesisContent.
  ///
  /// In en, this message translates to:
  /// **'Synthesis text'**
  String get v2SynthesisContent;

  /// No description provided for @v2SpeechAudioResult.
  ///
  /// In en, this message translates to:
  /// **'Synthesized audio'**
  String get v2SpeechAudioResult;

  /// No description provided for @v2TranscriptPending.
  ///
  /// In en, this message translates to:
  /// **'No transcript yet'**
  String get v2TranscriptPending;

  /// No description provided for @v2SpeechTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied'**
  String get v2SpeechTextCopied;

  /// No description provided for @v2LanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Language code (zh / en; empty for auto)'**
  String get v2LanguageHint;

  /// No description provided for @v2StartAsr.
  ///
  /// In en, this message translates to:
  /// **'Start transcription'**
  String get v2StartAsr;

  /// No description provided for @v2StartTts.
  ///
  /// In en, this message translates to:
  /// **'Start synthesis'**
  String get v2StartTts;

  /// No description provided for @v2InstallSpeechFirst.
  ///
  /// In en, this message translates to:
  /// **'Download or import a compatible speech model first.'**
  String get v2InstallSpeechFirst;

  /// No description provided for @v2SynthesisText.
  ///
  /// In en, this message translates to:
  /// **'Text to synthesize'**
  String get v2SynthesisText;

  /// No description provided for @v2SpeakerId.
  ///
  /// In en, this message translates to:
  /// **'Preset speaker ID (0–217)'**
  String get v2SpeakerId;

  /// No description provided for @v2Voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get v2Voice;

  /// No description provided for @v2PresetVoice.
  ///
  /// In en, this message translates to:
  /// **'Model default voice'**
  String get v2PresetVoice;

  /// No description provided for @v2SynthesisSpeed.
  ///
  /// In en, this message translates to:
  /// **'Synthesis speed'**
  String get v2SynthesisSpeed;

  /// No description provided for @v2CrispMarking.
  ///
  /// In en, this message translates to:
  /// **'CrispASR exports include AI-generated audio provenance.'**
  String get v2CrispMarking;

  /// No description provided for @v2NoSpeechJobs.
  ///
  /// In en, this message translates to:
  /// **'No speech tasks yet. Completed, cancelled and interrupted tasks appear here.'**
  String get v2NoSpeechJobs;

  /// No description provided for @v2CancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel task'**
  String get v2CancelTask;

  /// No description provided for @v2NoAudioSelected.
  ///
  /// In en, this message translates to:
  /// **'No audio selected'**
  String get v2NoAudioSelected;

  /// No description provided for @v2ImportAudio.
  ///
  /// In en, this message translates to:
  /// **'Import audio'**
  String get v2ImportAudio;

  /// No description provided for @v2Record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get v2Record;

  /// No description provided for @v2StopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get v2StopRecording;

  /// No description provided for @v2UseRecording.
  ///
  /// In en, this message translates to:
  /// **'Use latest recording'**
  String get v2UseRecording;

  /// No description provided for @v2RecordingHelp.
  ///
  /// In en, this message translates to:
  /// **'Record up to 10 minutes. Recording stops when the app enters the background or audio is interrupted.'**
  String get v2RecordingHelp;

  /// No description provided for @v2SpeechWaitingHelp.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the previous speech task to release its resources. LLM service and chat can run alongside speech.'**
  String get v2SpeechWaitingHelp;

  /// No description provided for @v2Queued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get v2Queued;

  /// No description provided for @v2WaitingLocal.
  ///
  /// In en, this message translates to:
  /// **'Waiting for speech resources'**
  String get v2WaitingLocal;

  /// No description provided for @v2Cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling; waiting for native completion'**
  String get v2Cancelling;

  /// No description provided for @v2TaskResult.
  ///
  /// In en, this message translates to:
  /// **'Task result'**
  String get v2TaskResult;

  /// No description provided for @v2CancellationHelp.
  ///
  /// In en, this message translates to:
  /// **'The next speech task waits until the native segment finishes and releases speech resources. LLM service and chat can continue.'**
  String get v2CancellationHelp;

  /// No description provided for @v2NoSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No text detected. Try a different language or model in a new task.'**
  String get v2NoSpeechDetected;

  /// No description provided for @v2ChunkTimingHelp.
  ///
  /// In en, this message translates to:
  /// **'This model provides chunk ranges without reliable subtitle timestamps. TXT export is available.'**
  String get v2ChunkTimingHelp;

  /// No description provided for @v2Transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get v2Transcript;

  /// No description provided for @v2EditTranscript.
  ///
  /// In en, this message translates to:
  /// **'Edit transcript'**
  String get v2EditTranscript;

  /// No description provided for @v2ExportTxt.
  ///
  /// In en, this message translates to:
  /// **'Export TXT'**
  String get v2ExportTxt;

  /// No description provided for @v2ExportSrt.
  ///
  /// In en, this message translates to:
  /// **'Export SRT'**
  String get v2ExportSrt;

  /// No description provided for @v2ExportWav.
  ///
  /// In en, this message translates to:
  /// **'Export WAV'**
  String get v2ExportWav;

  /// No description provided for @v2InsertTranscript.
  ///
  /// In en, this message translates to:
  /// **'Insert into chat draft'**
  String get v2InsertTranscript;

  /// No description provided for @v2PlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play / pause'**
  String get v2PlayPause;

  /// No description provided for @v2PreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Preview reference audio'**
  String get v2PreviewAudio;

  /// No description provided for @v2VoiceModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The original model is unavailable. You can export this reference audio and create a new voice after installing a compatible model.'**
  String get v2VoiceModelMissing;

  /// No description provided for @v2PlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed (keeps the generated audio)'**
  String get v2PlaybackSpeed;

  /// No description provided for @v2InputSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Task input snapshot'**
  String get v2InputSnapshot;

  /// No description provided for @v2SpeechPackageHelp.
  ///
  /// In en, this message translates to:
  /// **'Each recipe is a self-contained package. An import ZIP must contain speech-package.json at its root.'**
  String get v2SpeechPackageHelp;

  /// No description provided for @v2ImportSpeechPackage.
  ///
  /// In en, this message translates to:
  /// **'Import model ZIP'**
  String get v2ImportSpeechPackage;

  /// No description provided for @v2Ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get v2Ready;

  /// No description provided for @v2ModelIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete or paused'**
  String get v2ModelIncomplete;

  /// No description provided for @v2ResumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get v2ResumeDownload;

  /// No description provided for @v2PauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause download'**
  String get v2PauseDownload;

  /// No description provided for @v2DeleteSpeechModelHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete local model files. Existing results remain. Cancel queued jobs first; reference voices require a compatible model.'**
  String get v2DeleteSpeechModelHelp;

  /// No description provided for @v2AvailableModels.
  ///
  /// In en, this message translates to:
  /// **'Available recipes'**
  String get v2AvailableModels;

  /// No description provided for @v2ModelLicenseHelp.
  ///
  /// In en, this message translates to:
  /// **'Review the upstream model card, supported languages and license before downloading.'**
  String get v2ModelLicenseHelp;

  /// No description provided for @v2ModelCard.
  ///
  /// In en, this message translates to:
  /// **'Model card'**
  String get v2ModelCard;

  /// No description provided for @v2DownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get v2DownloadModel;

  /// No description provided for @v2CreateVoice.
  ///
  /// In en, this message translates to:
  /// **'Create reference voice'**
  String get v2CreateVoice;

  /// No description provided for @v2VoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Qwen3-TTS Base supports reference audio cloning. Use 3–30 seconds of clear single-speaker audio with an accurate transcript. Voices are bound to the model revision.'**
  String get v2VoiceHelp;

  /// No description provided for @v2InstallCloningFirst.
  ///
  /// In en, this message translates to:
  /// **'Install a cloning-capable recipe first.'**
  String get v2InstallCloningFirst;

  /// No description provided for @v2VoiceName.
  ///
  /// In en, this message translates to:
  /// **'Voice name'**
  String get v2VoiceName;

  /// No description provided for @v2ReferenceText.
  ///
  /// In en, this message translates to:
  /// **'Exact reference transcript'**
  String get v2ReferenceText;

  /// No description provided for @v2VoiceRights.
  ///
  /// In en, this message translates to:
  /// **'I have permission to use this voice as a reference'**
  String get v2VoiceRights;

  /// No description provided for @v2VoiceTestText.
  ///
  /// In en, this message translates to:
  /// **'Preview text (required)'**
  String get v2VoiceTestText;

  /// No description provided for @v2SaveAndPreview.
  ///
  /// In en, this message translates to:
  /// **'Save and create preview task'**
  String get v2SaveAndPreview;

  /// No description provided for @v2TranscribeToChat.
  ///
  /// In en, this message translates to:
  /// **'Voice to text'**
  String get v2TranscribeToChat;

  /// No description provided for @v2NoAutomaticAudioUpload.
  ///
  /// In en, this message translates to:
  /// **'Only text is inserted. Nothing is sent automatically; original audio is not uploaded.'**
  String get v2NoAutomaticAudioUpload;

  /// No description provided for @v2ReplaceDraft.
  ///
  /// In en, this message translates to:
  /// **'Replace draft'**
  String get v2ReplaceDraft;

  /// No description provided for @v2AppendDraft.
  ///
  /// In en, this message translates to:
  /// **'Append to draft'**
  String get v2AppendDraft;

  /// No description provided for @v2TranscriptInserted.
  ///
  /// In en, this message translates to:
  /// **'Transcript inserted into the selected chat draft.'**
  String get v2TranscriptInserted;

  /// No description provided for @v2ReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get v2ReadAloud;

  /// No description provided for @v2SynthesisParameters.
  ///
  /// In en, this message translates to:
  /// **'Speaker: {speaker} · Synthesis speed: {speed}'**
  String v2SynthesisParameters(String speaker, String speed);

  /// No description provided for @v2SampleRate.
  ///
  /// In en, this message translates to:
  /// **'Output sample rate: {rate} Hz'**
  String v2SampleRate(int rate);

  /// No description provided for @v2DownloadSize.
  ///
  /// In en, this message translates to:
  /// **'Download size: about {size} MiB'**
  String v2DownloadSize(int size);

  /// No description provided for @v2TranscriptDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination: {name}'**
  String v2TranscriptDestination(String name);

  /// No description provided for @v2RetrySpeech.
  ///
  /// In en, this message translates to:
  /// **'Retry as a new task'**
  String get v2RetrySpeech;

  /// No description provided for @v2TranscriptSegment.
  ///
  /// In en, this message translates to:
  /// **'Segment {index}'**
  String v2TranscriptSegment(int index);

  /// No description provided for @v2ReadAloudHelp.
  ///
  /// In en, this message translates to:
  /// **'The final answer is ready to edit and synthesize. Use up to 4,000 characters per task; split longer answers.'**
  String get v2ReadAloudHelp;

  /// No description provided for @v2NativeRestart.
  ///
  /// In en, this message translates to:
  /// **'Speech cleanup is unconfirmed. Restart the app before running another speech task. Task records are retained.'**
  String get v2NativeRestart;

  /// No description provided for @v2CancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel import'**
  String get v2CancelImport;

  /// No description provided for @v2OriginalChatMissing.
  ///
  /// In en, this message translates to:
  /// **'The original destination is unavailable. Choose a conversation or assistant draft. The transcript is retained.'**
  String get v2OriginalChatMissing;

  /// No description provided for @v2AssistantDraft.
  ///
  /// In en, this message translates to:
  /// **'New conversation · {name}'**
  String v2AssistantDraft(String name);

  /// No description provided for @v2TranscriptTarget.
  ///
  /// In en, this message translates to:
  /// **'Destination draft'**
  String get v2TranscriptTarget;

  /// No description provided for @v2DraftChanged.
  ///
  /// In en, this message translates to:
  /// **'The destination draft changed. Open it again before confirming a replacement.'**
  String get v2DraftChanged;

  /// No description provided for @v2IncompleteAnswer.
  ///
  /// In en, this message translates to:
  /// **'This answer is incomplete. Finish generating it before reading it aloud.'**
  String get v2IncompleteAnswer;

  /// No description provided for @v2SkillsGrantHelp.
  ///
  /// In en, this message translates to:
  /// **'Selected skills can read their own instructions and resources. Other tools still need separate authorization.'**
  String get v2SkillsGrantHelp;

  /// No description provided for @v2DiscardRecording.
  ///
  /// In en, this message translates to:
  /// **'Discard the recent recording'**
  String get v2DiscardRecording;

  /// No description provided for @v2StartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be opened. Existing data is retained; resolve the storage error and retry.'**
  String get v2StartupFailed;

  /// No description provided for @v2RetryStartup.
  ///
  /// In en, this message translates to:
  /// **'Retry startup'**
  String get v2RetryStartup;

  /// No description provided for @appLogsFilterApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get appLogsFilterApp;

  /// No description provided for @appLogsFilterClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get appLogsFilterClient;

  /// No description provided for @appLogsFilterAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get appLogsFilterAgent;

  /// No description provided for @appLogsFilterSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get appLogsFilterSpeech;

  /// No description provided for @appLogsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search logs or task ID'**
  String get appLogsSearch;

  /// No description provided for @appLogsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get appLogsClearSearch;

  /// No description provided for @appLogsAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get appLogsAllLevels;

  /// No description provided for @appLogsLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug and above'**
  String get appLogsLevelDebug;

  /// No description provided for @appLogsLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info and above'**
  String get appLogsLevelInfo;

  /// No description provided for @appLogsLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warnings and errors'**
  String get appLogsLevelWarning;

  /// No description provided for @appLogsVisibleCount.
  ///
  /// In en, this message translates to:
  /// **'{visible} / {total} logs'**
  String appLogsVisibleCount(int visible, int total);

  /// No description provided for @appLogsRetention.
  ///
  /// In en, this message translates to:
  /// **'Showing the latest {limit} entries. Copy and export use the current filters.'**
  String appLogsRetention(int limit);

  /// No description provided for @appLogsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching logs'**
  String get appLogsNoMatches;

  /// No description provided for @v2ToolSearch.
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get v2ToolSearch;

  /// No description provided for @v2SearchGrantHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow this assistant to send search queries to the selected provider without asking each time. Bing and DuckDuckGo need no API key. Changing providers stops an active run that uses this permission.'**
  String get v2SearchGrantHelp;

  /// No description provided for @v2SearchProvider.
  ///
  /// In en, this message translates to:
  /// **'Search provider'**
  String get v2SearchProvider;

  /// No description provided for @v2SearchBing.
  ///
  /// In en, this message translates to:
  /// **'Bing'**
  String get v2SearchBing;

  /// No description provided for @v2SearchDuckDuckGo.
  ///
  /// In en, this message translates to:
  /// **'DuckDuckGo'**
  String get v2SearchDuckDuckGo;

  /// No description provided for @v2SearchMaxResults.
  ///
  /// In en, this message translates to:
  /// **'Maximum results per search'**
  String get v2SearchMaxResults;

  /// No description provided for @v2SearchSources.
  ///
  /// In en, this message translates to:
  /// **'Search sources'**
  String get v2SearchSources;

  /// No description provided for @v2SearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching web results. Try a different query.'**
  String get v2SearchNoResults;

  /// No description provided for @v2SearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable. Check the network or select another provider.'**
  String get v2SearchUnavailable;

  /// No description provided for @v2SearchRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The search provider is limiting requests. Try again later or change providers.'**
  String get v2SearchRateLimited;

  /// No description provided for @v2SearchChallenge.
  ///
  /// In en, this message translates to:
  /// **'The provider requires verification or has blocked this request. Try later or select another provider.'**
  String get v2SearchChallenge;

  /// No description provided for @v2SearchInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an unrecognized search page. Try later or select another provider.'**
  String get v2SearchInvalidResponse;

  /// No description provided for @v2SearchTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The search response exceeded the size limit. Try a more specific query.'**
  String get v2SearchTooLarge;

  /// No description provided for @v2SearchTimeout.
  ///
  /// In en, this message translates to:
  /// **'The search timed out. Try again later or select another provider.'**
  String get v2SearchTimeout;

  /// No description provided for @v2SearchOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this source link.'**
  String get v2SearchOpenFailed;

  /// No description provided for @v2ConversationModel.
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get v2ConversationModel;

  /// No description provided for @v2ConversationModelHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a model by provider. Selecting a local model loads it and starts the service.'**
  String get v2ConversationModelHelp;

  /// No description provided for @v2NoLocalChatModels.
  ///
  /// In en, this message translates to:
  /// **'No local LLM is available. Download or import one from Models.'**
  String get v2NoLocalChatModels;

  /// No description provided for @v2AssistantDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Chat model'**
  String get v2AssistantDefaultModel;

  /// No description provided for @v2NoDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get v2NoDefaultModel;

  /// No description provided for @v2ClearDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Clear model selection'**
  String get v2ClearDefaultModel;

  /// No description provided for @v2AssistantDefaultModelHelp.
  ///
  /// In en, this message translates to:
  /// **'All conversations with this assistant share this model. Changing the model in chat updates this setting; historical messages stay unchanged.'**
  String get v2AssistantDefaultModelHelp;

  /// No description provided for @v2UnassignedAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant not assigned or removed'**
  String get v2UnassignedAssistant;

  /// No description provided for @v2ChangeConversationAssistant.
  ///
  /// In en, this message translates to:
  /// **'Change this conversation’s assistant'**
  String get v2ChangeConversationAssistant;

  /// No description provided for @v2ChangeConversationAssistantHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep this conversation’s model, messages, versions and draft. Future replies use the new assistant’s instructions and permissions; historical attribution stays unchanged.'**
  String get v2ChangeConversationAssistantHelp;

  /// No description provided for @v2ChooseConversationModel.
  ///
  /// In en, this message translates to:
  /// **'Please select a model'**
  String get v2ChooseConversationModel;

  /// No description provided for @v2AllAssistantHistory.
  ///
  /// In en, this message translates to:
  /// **'Conversations from all assistants'**
  String get v2AllAssistantHistory;

  /// No description provided for @v2ConnectionConversationCount.
  ///
  /// In en, this message translates to:
  /// **'{count} conversations use this provider and will need another model selection.'**
  String v2ConnectionConversationCount(int count);

  /// No description provided for @v2DeleteAssistantHelp.
  ///
  /// In en, this message translates to:
  /// **'Deleting this assistant also deletes all associated conversations, messages, and drafts. This cannot be undone.'**
  String get v2DeleteAssistantHelp;

  /// No description provided for @v2SwitchAssistantNewChat.
  ///
  /// In en, this message translates to:
  /// **'Switch assistant and start a new chat'**
  String get v2SwitchAssistantNewChat;

  /// No description provided for @v2ToolCallCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tool call} other{{count} tool calls}}'**
  String v2ToolCallCount(int count);

  /// No description provided for @v2ToolRetryLoad.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get v2ToolRetryLoad;

  /// No description provided for @v2ToolHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load tool activity.'**
  String get v2ToolHistoryFailed;

  /// No description provided for @v2ToolPrepared.
  ///
  /// In en, this message translates to:
  /// **'Waiting to execute'**
  String get v2ToolPrepared;

  /// No description provided for @v2ToolApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved, waiting to execute'**
  String get v2ToolApproved;

  /// No description provided for @v2ToolAwaitingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your answer'**
  String get v2ToolAwaitingAnswer;

  /// No description provided for @v2ToolList.
  ///
  /// In en, this message translates to:
  /// **'List conversation files'**
  String get v2ToolList;

  /// No description provided for @v2ToolWriteAction.
  ///
  /// In en, this message translates to:
  /// **'Write conversation file'**
  String get v2ToolWriteAction;

  /// No description provided for @v2ToolQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get v2ToolQuestion;

  /// No description provided for @v2ToolArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get v2ToolArguments;

  /// No description provided for @v2ToolResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get v2ToolResult;

  /// No description provided for @v2ToolSendAnswer.
  ///
  /// In en, this message translates to:
  /// **'Send answer'**
  String get v2ToolSendAnswer;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Delete this version'**
  String get chatDeleteCurrentVersion;

  /// No description provided for @chatDeleteAllVersions.
  ///
  /// In en, this message translates to:
  /// **'Delete all versions'**
  String get chatDeleteAllVersions;

  /// No description provided for @chatDeleteAllVersionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this message and all its versions? Their tool call records and generation data will also be removed. Later messages will remain. This cannot be undone.'**
  String get chatDeleteAllVersionsConfirm;

  /// No description provided for @chatDeleteVersionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete version {version} of {count}? Its tool call records and generation data will also be removed. Other versions and later messages will remain. This cannot be undone.'**
  String chatDeleteVersionConfirm(int version, int count);

  /// No description provided for @v2ToolResultTruncated.
  ///
  /// In en, this message translates to:
  /// **'This result was truncated. Only the saved excerpt can be viewed or exported.'**
  String get v2ToolResultTruncated;

  /// No description provided for @v2ProviderPreset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get v2ProviderPreset;

  /// No description provided for @v2ProviderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get v2ProviderCustom;

  /// No description provided for @v2ProviderPresetHelp.
  ///
  /// In en, this message translates to:
  /// **'Preset providers cannot be deleted. You can configure or disable them.'**
  String get v2ProviderPresetHelp;

  /// No description provided for @v2ProviderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable provider'**
  String get v2ProviderEnabled;

  /// No description provided for @v2ProviderEnabledHelp.
  ///
  /// In en, this message translates to:
  /// **'Disabling preserves settings and history and stops runs using this provider.'**
  String get v2ProviderEnabledHelp;

  /// No description provided for @v2ProviderOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get v2ProviderOn;

  /// No description provided for @v2ProviderOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get v2ProviderOff;

  /// No description provided for @v2ProviderModelCount.
  ///
  /// In en, this message translates to:
  /// **'{count} models'**
  String v2ProviderModelCount(int count);

  /// No description provided for @v2ProviderModelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No models added. Add models manually or fetch them in provider settings.'**
  String get v2ProviderModelsEmpty;

  /// No description provided for @v2AddModel.
  ///
  /// In en, this message translates to:
  /// **'Add model manually'**
  String get v2AddModel;

  /// No description provided for @v2RemoveModel.
  ///
  /// In en, this message translates to:
  /// **'Remove model'**
  String get v2RemoveModel;

  /// No description provided for @v2RemoveModelHelp.
  ///
  /// In en, this message translates to:
  /// **'Saving will remove {model} from this provider. Conversations and assistant defaults using it will be unavailable; messages remain.'**
  String v2RemoveModelHelp(String model);

  /// No description provided for @v2ModelIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a model ID'**
  String get v2ModelIdRequired;

  /// No description provided for @v2DiscoveredModels.
  ///
  /// In en, this message translates to:
  /// **'Choose models to add'**
  String get v2DiscoveredModels;

  /// No description provided for @v2ModelAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get v2ModelAlreadyAdded;

  /// No description provided for @v2ModelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search model IDs'**
  String get v2ModelSearch;

  /// No description provided for @v2ProviderNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching providers or models'**
  String get v2ProviderNoResults;

  /// No description provided for @v2ProviderModelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search providers or models'**
  String get v2ProviderModelSearch;

  /// No description provided for @v2AddSelectedModels.
  ///
  /// In en, this message translates to:
  /// **'Add selected ({count})'**
  String v2AddSelectedModels(int count);

  /// No description provided for @v2SelectVisible.
  ///
  /// In en, this message translates to:
  /// **'Select search results'**
  String get v2SelectVisible;

  /// No description provided for @v2DeselectVisible.
  ///
  /// In en, this message translates to:
  /// **'Deselect search results'**
  String get v2DeselectVisible;

  /// No description provided for @v2LocalProvider.
  ///
  /// In en, this message translates to:
  /// **'Local · {engine}'**
  String v2LocalProvider(String engine);

  /// No description provided for @v2LocalProviderHelp.
  ///
  /// In en, this message translates to:
  /// **'Managed in the local model library; load or stop models to control the runtime.'**
  String get v2LocalProviderHelp;

  /// No description provided for @v2ServicePublished.
  ///
  /// In en, this message translates to:
  /// **'Serving externally'**
  String get v2ServicePublished;

  /// No description provided for @v2PublishedModelLocked.
  ///
  /// In en, this message translates to:
  /// **'Stop the published model in the service center before switching local models.'**
  String get v2PublishedModelLocked;

  /// No description provided for @v2LocalModelLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded'**
  String get v2LocalModelLoaded;

  /// No description provided for @v2LocalModelUnloaded.
  ///
  /// In en, this message translates to:
  /// **'Not loaded'**
  String get v2LocalModelUnloaded;

  /// No description provided for @drawerAssistantSettings.
  ///
  /// In en, this message translates to:
  /// **'Assistant settings'**
  String get drawerAssistantSettings;

  /// No description provided for @settingsUser.
  ///
  /// In en, this message translates to:
  /// **'User settings'**
  String get settingsUser;

  /// No description provided for @settingsSectionServices.
  ///
  /// In en, this message translates to:
  /// **'Services & diagnostics'**
  String get settingsSectionServices;

  /// No description provided for @settingsSectionDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get settingsSectionDeveloper;

  /// No description provided for @settingsMnnTest.
  ///
  /// In en, this message translates to:
  /// **'MNN test'**
  String get settingsMnnTest;

  /// No description provided for @settingsDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get settingsDebug;

  /// No description provided for @localModelImport.
  ///
  /// In en, this message translates to:
  /// **'Import local model'**
  String get localModelImport;

  /// No description provided for @localModelChooseImport.
  ///
  /// In en, this message translates to:
  /// **'Choose and import'**
  String get localModelChooseImport;

  /// No description provided for @localModelImportHelp.
  ///
  /// In en, this message translates to:
  /// **'The selected file or folder is copied into app storage. Import starts after selection.'**
  String get localModelImportHelp;

  /// No description provided for @discoveryQuery.
  ///
  /// In en, this message translates to:
  /// **'Search preset names or engines'**
  String get discoveryQuery;

  /// No description provided for @discoveryReset.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get discoveryReset;

  /// No description provided for @discoveryPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get discoveryPurpose;

  /// No description provided for @discoveryEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get discoveryEngine;

  /// No description provided for @discoveryState.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get discoveryState;

  /// No description provided for @discoveryNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get discoveryNotInstalled;

  /// No description provided for @discoveryDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get discoveryDownloading;

  /// No description provided for @discoveryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Paused / incomplete'**
  String get discoveryIncomplete;

  /// No description provided for @discoveryCloneOnly.
  ///
  /// In en, this message translates to:
  /// **'Voice cloning'**
  String get discoveryCloneOnly;

  /// No description provided for @discoverySmallOnly.
  ///
  /// In en, this message translates to:
  /// **'Up to 200 MiB'**
  String get discoverySmallOnly;

  /// No description provided for @discoverySpeechHelp.
  ///
  /// In en, this message translates to:
  /// **'Download a complete preset package, including its dependencies. Runtime compatibility and quality still need verification on your device.'**
  String get discoverySpeechHelp;

  /// No description provided for @discoverySpeechLibraryHelp.
  ///
  /// In en, this message translates to:
  /// **'Get speech models from Discover. Installed and incomplete packages appear here.'**
  String get discoverySpeechLibraryHelp;

  /// No description provided for @discoveryOnlineLanguage.
  ///
  /// In en, this message translates to:
  /// **'Search language models online'**
  String get discoveryOnlineLanguage;

  /// No description provided for @v2StartupPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing ServLlama'**
  String get v2StartupPreparing;

  /// No description provided for @v2MigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrading your data'**
  String get v2MigrationTitle;

  /// No description provided for @v2MigrationHelp.
  ///
  /// In en, this message translates to:
  /// **'Your chats, model records and download progress are being upgraded. Model files stay in place. Original data is retained until the upgrade succeeds.'**
  String get v2MigrationHelp;

  /// No description provided for @v2MigrationFailed.
  ///
  /// In en, this message translates to:
  /// **'The upgrade could not finish. Resolve the storage issue and retry; your original data is retained.'**
  String get v2MigrationFailed;

  /// No description provided for @v2MigrationChats.
  ///
  /// In en, this message translates to:
  /// **'Reading chat history'**
  String get v2MigrationChats;

  /// No description provided for @v2MigrationModels.
  ///
  /// In en, this message translates to:
  /// **'Reading local model records'**
  String get v2MigrationModels;

  /// No description provided for @v2MigrationDownloads.
  ///
  /// In en, this message translates to:
  /// **'Reading download tasks'**
  String get v2MigrationDownloads;

  /// No description provided for @v2MigrationWriting.
  ///
  /// In en, this message translates to:
  /// **'Saving upgraded records'**
  String get v2MigrationWriting;

  /// No description provided for @v2MigrationVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying model and download records'**
  String get v2MigrationVerifying;

  /// No description provided for @v2MigrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Upgrade complete. Finishing startup…'**
  String get v2MigrationComplete;

  /// No description provided for @v2MigrationRecords.
  ///
  /// In en, this message translates to:
  /// **'This step: {completed} / {total} records'**
  String v2MigrationRecords(int completed, int total);

  /// No description provided for @migrationPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration preview'**
  String get migrationPreviewTitle;

  /// No description provided for @migrationPreviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Simulates the interface only. No real data is read or changed. You can leave at any time.'**
  String get migrationPreviewHelp;

  /// No description provided for @migrationPreviewRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart preview'**
  String get migrationPreviewRestart;

  /// No description provided for @migrationPreviewFailure.
  ///
  /// In en, this message translates to:
  /// **'Simulate failure'**
  String get migrationPreviewFailure;

  /// No description provided for @migrationPreviewError.
  ///
  /// In en, this message translates to:
  /// **'Simulated error: Not enough storage. Retry to preview recovery.'**
  String get migrationPreviewError;

  /// No description provided for @migrationPreviewComplete.
  ///
  /// In en, this message translates to:
  /// **'Preview complete. Your real data is unchanged.'**
  String get migrationPreviewComplete;

  /// No description provided for @migrationPreviewReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to sidebar'**
  String get migrationPreviewReturn;

  /// No description provided for @uiLabTitle.
  ///
  /// In en, this message translates to:
  /// **'UI primitives'**
  String get uiLabTitle;

  /// No description provided for @uiLabDark.
  ///
  /// In en, this message translates to:
  /// **'Preview dark theme'**
  String get uiLabDark;

  /// No description provided for @uiLabLight.
  ///
  /// In en, this message translates to:
  /// **'Preview light theme'**
  String get uiLabLight;

  /// No description provided for @uiLabVisuals.
  ///
  /// In en, this message translates to:
  /// **'Visuals'**
  String get uiLabVisuals;

  /// No description provided for @uiLabControls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get uiLabControls;

  /// No description provided for @uiLabScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get uiLabScenes;

  /// No description provided for @uiLabPreview.
  ///
  /// In en, this message translates to:
  /// **'Design preview'**
  String get uiLabPreview;

  /// No description provided for @uiLabHeadline.
  ///
  /// In en, this message translates to:
  /// **'Let content lead'**
  String get uiLabHeadline;

  /// No description provided for @uiLabIntro.
  ///
  /// In en, this message translates to:
  /// **'Neutral surfaces, gentle blue-violet accents. Compact and ordered, with room to breathe.'**
  String get uiLabIntro;

  /// No description provided for @uiLabQuiet.
  ///
  /// In en, this message translates to:
  /// **'Restrained'**
  String get uiLabQuiet;

  /// No description provided for @uiLabSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft & clear'**
  String get uiLabSoft;

  /// No description provided for @uiLabPalette.
  ///
  /// In en, this message translates to:
  /// **'Color & surfaces'**
  String get uiLabPalette;

  /// No description provided for @uiLabPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Neutral backgrounds with accents where attention matters.'**
  String get uiLabPaletteHint;

  /// No description provided for @uiLabCanvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get uiLabCanvas;

  /// No description provided for @uiLabSurface.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get uiLabSurface;

  /// No description provided for @uiLabPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get uiLabPrimary;

  /// No description provided for @uiLabSelected.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get uiLabSelected;

  /// No description provided for @uiLabTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get uiLabTypography;

  /// No description provided for @uiLabTypographyHint.
  ///
  /// In en, this message translates to:
  /// **'Hierarchy through size, weight and spacing.'**
  String get uiLabTypographyHint;

  /// No description provided for @uiLabTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Clarity starts with reading'**
  String get uiLabTypeTitle;

  /// No description provided for @uiLabTypeSection.
  ///
  /// In en, this message translates to:
  /// **'A clear section heading'**
  String get uiLabTypeSection;

  /// No description provided for @uiLabTypeBody.
  ///
  /// In en, this message translates to:
  /// **'Comfortable line spacing makes longer answers easy to read. Information flows naturally, with actions close at hand.'**
  String get uiLabTypeBody;

  /// No description provided for @uiLabTypeCaption.
  ///
  /// In en, this message translates to:
  /// **'Supporting text · 12 sp · Time, status and descriptions'**
  String get uiLabTypeCaption;

  /// No description provided for @uiLabRhythm.
  ///
  /// In en, this message translates to:
  /// **'Spacing, corners & icons'**
  String get uiLabRhythm;

  /// No description provided for @uiLabRhythmHint.
  ///
  /// In en, this message translates to:
  /// **'Compact groups, generous separation and comfortable touch targets.'**
  String get uiLabRhythmHint;

  /// No description provided for @uiLabRadii.
  ///
  /// In en, this message translates to:
  /// **'Card radius 18 dp · Fields 14 dp\nTouch targets at least 48 dp'**
  String get uiLabRadii;

  /// No description provided for @uiLabLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'These interactions preview the design without connecting to models or saving application data.'**
  String get uiLabLocalOnly;

  /// No description provided for @uiLabActions.
  ///
  /// In en, this message translates to:
  /// **'Buttons & overlays'**
  String get uiLabActions;

  /// No description provided for @uiLabActionsHint.
  ///
  /// In en, this message translates to:
  /// **'A clear primary action, softer secondary actions and lightweight utilities.'**
  String get uiLabActionsHint;

  /// No description provided for @uiLabPrimaryAction.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get uiLabPrimaryAction;

  /// No description provided for @uiLabSecondaryAction.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get uiLabSecondaryAction;

  /// No description provided for @uiLabSheet.
  ///
  /// In en, this message translates to:
  /// **'Bottom sheet'**
  String get uiLabSheet;

  /// No description provided for @uiLabDialog.
  ///
  /// In en, this message translates to:
  /// **'Dialog'**
  String get uiLabDialog;

  /// No description provided for @uiLabDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get uiLabDisabled;

  /// No description provided for @uiLabDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this selection?'**
  String get uiLabDialogTitle;

  /// No description provided for @uiLabDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This previews a dialog. Confirm to see feedback; your real settings stay unchanged.'**
  String get uiLabDialogBody;

  /// No description provided for @uiLabConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get uiLabConfirm;

  /// No description provided for @uiLabFeedback.
  ///
  /// In en, this message translates to:
  /// **'Done — this change applies only to the preview.'**
  String get uiLabFeedback;

  /// No description provided for @uiLabChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get uiLabChooseModel;

  /// No description provided for @uiLabOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On-device · Example'**
  String get uiLabOnDevice;

  /// No description provided for @uiLabCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud · Example'**
  String get uiLabCloud;

  /// No description provided for @uiLabForms.
  ///
  /// In en, this message translates to:
  /// **'Input & selection'**
  String get uiLabForms;

  /// No description provided for @uiLabFormsHint.
  ///
  /// In en, this message translates to:
  /// **'Try the field, switch, slider and chip states.'**
  String get uiLabFormsHint;

  /// No description provided for @uiLabName.
  ///
  /// In en, this message translates to:
  /// **'Assistant name'**
  String get uiLabName;

  /// No description provided for @uiLabNameHint.
  ///
  /// In en, this message translates to:
  /// **'Give your assistant a name'**
  String get uiLabNameHint;

  /// No description provided for @uiLabNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter an assistant name'**
  String get uiLabNameError;

  /// No description provided for @uiLabStreaming.
  ///
  /// In en, this message translates to:
  /// **'Stream responses'**
  String get uiLabStreaming;

  /// No description provided for @uiLabStreamingHint.
  ///
  /// In en, this message translates to:
  /// **'Show the answer as it arrives'**
  String get uiLabStreamingHint;

  /// No description provided for @uiLabTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get uiLabTemperature;

  /// No description provided for @uiLabVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get uiLabVision;

  /// No description provided for @uiLabValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate input'**
  String get uiLabValidate;

  /// No description provided for @uiLabStates.
  ///
  /// In en, this message translates to:
  /// **'Status & progress'**
  String get uiLabStates;

  /// No description provided for @uiLabStatesHint.
  ///
  /// In en, this message translates to:
  /// **'Color supports the label; the label always explains the state.'**
  String get uiLabStatesHint;

  /// No description provided for @uiLabReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get uiLabReady;

  /// No description provided for @uiLabWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get uiLabWaiting;

  /// No description provided for @uiLabFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get uiLabFailed;

  /// No description provided for @uiLabDownload.
  ///
  /// In en, this message translates to:
  /// **'Model download · Preview'**
  String get uiLabDownload;

  /// No description provided for @uiLabSimulate.
  ///
  /// In en, this message translates to:
  /// **'Simulate progress'**
  String get uiLabSimulate;

  /// No description provided for @uiLabAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get uiLabAgain;

  /// No description provided for @uiLabChat.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get uiLabChat;

  /// No description provided for @uiLabChatHint.
  ///
  /// In en, this message translates to:
  /// **'User bubbles, open assistant text, inline tools and message metadata.'**
  String get uiLabChatHint;

  /// No description provided for @uiLabYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get uiLabYou;

  /// No description provided for @uiLabQuestion.
  ///
  /// In en, this message translates to:
  /// **'Help me plan today’s reading.'**
  String get uiLabQuestion;

  /// No description provided for @uiLabAssistant.
  ///
  /// In en, this message translates to:
  /// **'Reading assistant'**
  String get uiLabAssistant;

  /// No description provided for @uiLabTool.
  ///
  /// In en, this message translates to:
  /// **'Completed · Find reading resources'**
  String get uiLabTool;

  /// No description provided for @uiLabToolDetail.
  ///
  /// In en, this message translates to:
  /// **'Search → Organize → Return results\nAn expandable tool example. No network request was made.'**
  String get uiLabToolDetail;

  /// No description provided for @uiLabAnswer.
  ///
  /// In en, this message translates to:
  /// **'Set aside 25 minutes to focus on one chapter.\n\nThen spend 5 minutes noting three key ideas and one question to explore. Leave some room for reflection.'**
  String get uiLabAnswer;

  /// No description provided for @uiLabReply.
  ///
  /// In en, this message translates to:
  /// **'Your preview message was received. This demonstrates text layout and send feedback without calling a model.'**
  String get uiLabReply;

  /// No description provided for @uiLabCopy.
  ///
  /// In en, this message translates to:
  /// **'Preview copy feedback'**
  String get uiLabCopy;

  /// No description provided for @uiLabMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get uiLabMore;

  /// No description provided for @uiLabManagement.
  ///
  /// In en, this message translates to:
  /// **'Grouped lists & model cards'**
  String get uiLabManagement;

  /// No description provided for @uiLabManagementHint.
  ///
  /// In en, this message translates to:
  /// **'Consistent alignment, subtle separators and details on demand.'**
  String get uiLabManagementHint;

  /// No description provided for @uiLabAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Organize ideas and explore reading'**
  String get uiLabAssistantHint;

  /// No description provided for @uiLabProviderHint.
  ///
  /// In en, this message translates to:
  /// **'2 configured models · Example'**
  String get uiLabProviderHint;

  /// No description provided for @uiLabVoice.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get uiLabVoice;

  /// No description provided for @uiLabVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Transcription & synthesis · Example'**
  String get uiLabVoiceHint;

  /// No description provided for @uiLabComposer.
  ///
  /// In en, this message translates to:
  /// **'Type a message to try the interaction'**
  String get uiLabComposer;

  /// No description provided for @uiLabSend.
  ///
  /// In en, this message translates to:
  /// **'Send preview message'**
  String get uiLabSend;

  /// No description provided for @uiLabExactValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get uiLabExactValue;

  /// No description provided for @uiLabNumericHint.
  ///
  /// In en, this message translates to:
  /// **'Drag for a rough value, or type up to two decimal places.'**
  String get uiLabNumericHint;

  /// No description provided for @uiLabNumericError.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}, with at most two decimal places.'**
  String uiLabNumericError(String min, String max);

  /// No description provided for @uiLabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get uiLabMessages;

  /// No description provided for @uiLabMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Centered at the top for 3 seconds. A new message replaces the previous one; you can also dismiss it.'**
  String get uiLabMessagesHint;

  /// No description provided for @uiLabDismissMessage.
  ///
  /// In en, this message translates to:
  /// **'Dismiss message'**
  String get uiLabDismissMessage;

  /// No description provided for @uiLabMessageSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get uiLabMessageSuccess;

  /// No description provided for @uiLabMessageInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get uiLabMessageInfo;

  /// No description provided for @uiLabMessageWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get uiLabMessageWarning;

  /// No description provided for @uiLabMessageError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get uiLabMessageError;

  /// No description provided for @uiLabMessageInfoText.
  ///
  /// In en, this message translates to:
  /// **'This is a design preview. Your real data stays unchanged.'**
  String get uiLabMessageInfoText;

  /// No description provided for @uiLabMessageWarningText.
  ///
  /// In en, this message translates to:
  /// **'Choose a model before continuing. (Example)'**
  String get uiLabMessageWarningText;

  /// No description provided for @uiLabMessageErrorText.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check your settings and retry. (Example)'**
  String get uiLabMessageErrorText;

  /// No description provided for @uiLabThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get uiLabThemeColor;

  /// No description provided for @uiLabViolet.
  ///
  /// In en, this message translates to:
  /// **'Mist violet'**
  String get uiLabViolet;

  /// No description provided for @uiLabTea.
  ///
  /// In en, this message translates to:
  /// **'Tea violet'**
  String get uiLabTea;

  /// No description provided for @uiLabTeaIntro.
  ///
  /// In en, this message translates to:
  /// **'Violet with a touch of tea, paired with warm neutral surfaces. Soft, restrained and clearly layered.'**
  String get uiLabTeaIntro;

  /// No description provided for @numericExactValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get numericExactValue;

  /// No description provided for @numericHint.
  ///
  /// In en, this message translates to:
  /// **'Drag for a rough value, or type up to two decimal places.'**
  String get numericHint;

  /// No description provided for @numericError.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}, with at most two decimal places.'**
  String numericError(String min, String max);

  /// No description provided for @commonDismissMessage.
  ///
  /// In en, this message translates to:
  /// **'Dismiss message'**
  String get commonDismissMessage;

  /// No description provided for @v2ProviderConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get v2ProviderConfiguration;

  /// No description provided for @v2ProviderIdentity.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get v2ProviderIdentity;

  /// No description provided for @v2ProviderConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get v2ProviderConnection;

  /// No description provided for @v2ProtocolOpenai.
  ///
  /// In en, this message translates to:
  /// **'OpenAI compatible'**
  String get v2ProtocolOpenai;

  /// No description provided for @v2ModelCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Model capabilities'**
  String get v2ModelCapabilities;

  /// No description provided for @v2ModelCapabilitiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Set capabilities for each model according to its documentation. Fetching models only returns IDs; it does not verify image or tool support. Save the provider to apply your changes.'**
  String get v2ModelCapabilitiesHelp;

  /// No description provided for @v2ModelText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get v2ModelText;

  /// No description provided for @v2ModelImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get v2ModelImages;

  /// No description provided for @v2ModelTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get v2ModelTools;

  /// No description provided for @v2IdentitySettings.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get v2IdentitySettings;

  /// No description provided for @v2InstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the assistant’s role, response style and requirements…'**
  String get v2InstructionsHint;

  /// No description provided for @v2Credentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get v2Credentials;

  /// No description provided for @v2ModelImagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This model has image input disabled. Check its capabilities in provider settings.'**
  String get v2ModelImagesUnavailable;

  /// No description provided for @v2AssistantModelChanged.
  ///
  /// In en, this message translates to:
  /// **'This assistant’s model selection changed. Reopen its settings before editing it.'**
  String get v2AssistantModelChanged;

  /// No description provided for @chatGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get chatGreetingMorning;

  /// No description provided for @chatGreetingNoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get chatGreetingNoon;

  /// No description provided for @chatGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get chatGreetingAfternoon;

  /// No description provided for @chatGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get chatGreetingEvening;

  /// No description provided for @chatWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'What’s on your mind today?'**
  String get chatWelcomeDescription;

  /// No description provided for @chatWelcomeTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get chatWelcomeTranscribe;

  /// No description provided for @chatWelcomeSynthesize.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get chatWelcomeSynthesize;

  /// No description provided for @chatWelcomeTranscribeHint.
  ///
  /// In en, this message translates to:
  /// **'Audio to text'**
  String get chatWelcomeTranscribeHint;

  /// No description provided for @chatWelcomeSynthesizeHint.
  ///
  /// In en, this message translates to:
  /// **'Text to audio'**
  String get chatWelcomeSynthesizeHint;
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
