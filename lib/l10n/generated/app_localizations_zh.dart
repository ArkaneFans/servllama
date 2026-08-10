// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ServLlama';

  @override
  String get commonAuto => '自动';

  @override
  String get commonOptional => '可选';

  @override
  String get commonRename => '修改名称';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEnable => '开启';

  @override
  String get commonDisable => '关闭';

  @override
  String get drawerAllHistoryTooltip => '全部历史';

  @override
  String get drawerServer => '服务器';

  @override
  String get drawerSettings => '设置';

  @override
  String get chatSearchHint => '搜索聊天...';

  @override
  String get chatNewSession => '新对话';

  @override
  String get chatCreateSessionTooltip => '新建对话';

  @override
  String get chatHistoryTitle => '聊天历史';

  @override
  String get chatSessionEmpty => '暂无对话';

  @override
  String get chatSessionNotFound => '未找到匹配对话';

  @override
  String get chatMoreActions => '更多操作';

  @override
  String get chatRenameSessionTitle => '修改对话名称';

  @override
  String get chatRenameSessionHint => '输入对话名称';

  @override
  String get chatDeleteSessionTitle => '删除对话';

  @override
  String chatDeleteSessionConfirm(String sessionTitle) {
    return '确定删除“$sessionTitle”吗？';
  }

  @override
  String get chatSelectModel => '选择模型';

  @override
  String get chatRefreshModels => '刷新模型';

  @override
  String get chatLoadedModels => '已加载模型';

  @override
  String get chatAvailableModels => '可用模型';

  @override
  String chatNoModels(String title) {
    return '暂无$title';
  }

  @override
  String get chatHeroTitle => '开始对话';

  @override
  String get chatHeroDescriptionReady => '输入一条消息，开始与你的本地模型对话。';

  @override
  String get chatHeroDescriptionStartServer => '请先启动服务器，然后加载一个模型，马上开始你的AI对话~';

  @override
  String get chatHeroDescriptionSelectModel => '服务器已启动，请加载一个模型，马上开始你的 AI 对话~';

  @override
  String get chatStartServer => '启动服务器';

  @override
  String get chatStartingServer => '启动中...';

  @override
  String get chatLoadingModel => '加载模型中...';

  @override
  String get chatInputHintStartServer => '请先启动服务器';

  @override
  String get chatInputHintLoadingModel => '模型加载中...';

  @override
  String get chatInputHintSelectModel => '请先选择模型';

  @override
  String get chatInputHintModelUnavailable => '当前模型未加载';

  @override
  String get chatInputHintEnterMessage => '输入消息';

  @override
  String get chatSend => '发送';

  @override
  String get chatStop => '停止';

  @override
  String get chatUnloadModel => '卸载模型';

  @override
  String get chatModelStatusLoaded => '已加载';

  @override
  String get chatModelStatusLoading => '加载中';

  @override
  String get chatModelStatusAvailable => '可加载';

  @override
  String get chatModelStatusFailed => '加载失败';

  @override
  String chatModelLoadTimeout(Object model) {
    return '模型加载超时：$model，请稍后重试';
  }

  @override
  String chatModelLoadFailed(Object model) {
    return '模型加载失败：$model';
  }

  @override
  String chatModelUnloadTimeout(Object model) {
    return '模型卸载超时：$model';
  }

  @override
  String chatModelRequestFailed(Object detail) {
    return '请求失败：$detail';
  }

  @override
  String get chatReasoningProcess => '深度思考';

  @override
  String get chatCopyMessage => '复制';

  @override
  String get chatEditMessage => '编辑';

  @override
  String get chatRegenerateMessage => '重新生成';

  @override
  String get chatPreviousMessageVersion => '上一版本';

  @override
  String get chatNextMessageVersion => '下一版本';

  @override
  String get chatJumpToLatest => '跳到最新消息';

  @override
  String get chatMessageCopied => '消息已复制';

  @override
  String get chatMessageUpdated => '消息已更新';

  @override
  String get chatEditMessageTitle => '编辑消息';

  @override
  String get chatEditMessageHint => '修改这条消息';

  @override
  String get chatAttachImage => '添加图片';

  @override
  String get chatRemoveImage => '移除图片';

  @override
  String get chatImageLimitExceeded => '每条消息最多添加5张图片';

  @override
  String get chatImageSizeExceeded => '图片大小不能超过10MB';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionChat => '聊天';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsLanguage => '应用语言';

  @override
  String get settingsChatTimeout => '聊天超时时间';

  @override
  String settingsChatTimeoutValue(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get settingsChatTimeoutSheetTitle => '聊天超时时间';

  @override
  String get settingsChatTimeoutDescription => '用于控制聊天响应等待时长，多模态图片识别场景建议适当调大。';

  @override
  String get settingsChatTimeoutFieldLabel => '超时时间';

  @override
  String get settingsChatTimeoutUnit => '秒';

  @override
  String settingsChatTimeoutRange(int minSeconds, int maxSeconds) {
    return '允许范围：$minSeconds-$maxSeconds 秒';
  }

  @override
  String get settingsUnavailable => '暂未开放';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsThemeModeSheetTitle => '主题模式';

  @override
  String get settingsLanguageSheetTitle => '应用语言';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get languageModeSystem => '跟随系统';

  @override
  String get languageModeChinese => '简体中文';

  @override
  String get languageModeEnglish => 'English';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutDescription => '将你的手机变成强大的大模型推理服务器，无需Termux';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutVersionCopied => '版本号已复制';

  @override
  String aboutLlamaCppVersion(String version) {
    return 'llama.cpp $version';
  }

  @override
  String get aboutStarOnGitHub => '在 GitHub 上点亮 Star';

  @override
  String get aboutLicense => '开源许可';

  @override
  String get serverTitle => '服务器';

  @override
  String get serverMenuConfig => '服务器配置';

  @override
  String get serverMenuLogs => '日志';

  @override
  String get serverMenuModels => '模型管理';

  @override
  String get serverStatusRunning => '运行中';

  @override
  String get serverStatusStopped => '已停止';

  @override
  String get serverStart => '启动';

  @override
  String get serverStop => '停止';

  @override
  String get serverBaseUrlLabel => 'API Base URL';

  @override
  String get serverBaseUrlCopied => 'API Base URL 已复制';

  @override
  String get serverCopyBaseUrl => '复制 API Base URL';

  @override
  String get serverForegroundNotificationTitle => 'ServLlama 正在运行';

  @override
  String get serverForegroundNotificationText => 'ServLlama 服务器正在后台运行';

  @override
  String get serverStartFailedCheckLogs => '启动失败，请查看日志。';

  @override
  String serverStartFailed(String error) {
    return '启动失败: $error';
  }

  @override
  String serverStopFailed(String error) {
    return '停止失败: $error';
  }

  @override
  String get serverConfigTitle => '服务器配置';

  @override
  String get serverConfigStatusSaved => '配置已保存';

  @override
  String get serverConfigStatusLoading => '正在加载配置...';

  @override
  String get serverConfigStatusLoaded => '配置已加载';

  @override
  String serverConfigStatusLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get serverConfigStatusSaving => '正在保存配置...';

  @override
  String serverConfigStatusSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get serverConfigSectionNetwork => '网络与访问';

  @override
  String get serverConfigListenMode => '监听范围';

  @override
  String get serverConfigListenModeDescription => '本地回环仅本机使用，监听所有允许外部访问';

  @override
  String get serverConfigListenLocalhost => '本地回环';

  @override
  String get serverConfigListenAllInterfaces => '监听所有';

  @override
  String get serverConfigPort => '端口';

  @override
  String get serverConfigPortDescription => '服务器监听端口';

  @override
  String get serverConfigApiKey => 'API Key';

  @override
  String get serverConfigApiKeyDescription => '留空则不启用校验';

  @override
  String get serverConfigSectionInference => '推理参数';

  @override
  String get serverConfigContextSize => '上下文长度';

  @override
  String get serverConfigContextSizeDescription => '模型能关注的最大上下文toekn数量';

  @override
  String get serverConfigBatchSize => '批处理大小';

  @override
  String get serverConfigBatchSizeDescription => '影响吞吐和内存占用';

  @override
  String get serverConfigImageMaxTokens => '图片最大Token数';

  @override
  String get serverConfigImageMaxTokensDescription =>
      '每张图片可占用的最大token数量，仅对视觉模型生效';

  @override
  String get serverConfigSectionPerformance => '性能';

  @override
  String get serverConfigCpuThreads => 'CPU 线程数';

  @override
  String get serverConfigCpuThreadsDescription => '为模型推理分配的CPU线程数量';

  @override
  String get serverConfigParallelSlots => '并行槽位';

  @override
  String get serverConfigParallelSlotsDescription => '控制服务器同时处理的请求数';

  @override
  String get serverConfigSectionAdvanced => '高级';

  @override
  String get serverConfigFlashAttention => 'Flash Attention';

  @override
  String get serverConfigFlashAttentionDescription => '降低某些模型的内存使用量和推理时间';

  @override
  String get serverConfigUseMmap => '使用 mmap 内存映射';

  @override
  String get serverConfigUseMmapSubtitle => '提高模型的加载性能';

  @override
  String get serverConfigSectionLogging => '日志';

  @override
  String get serverConfigLogEnabled => '日志启用';

  @override
  String get serverConfigLogEnabledSubtitle => '控制推理引擎运行日志输出';

  @override
  String get serverConfigLogLevel => '日志级别';

  @override
  String get serverConfigLogLevelDescription => '控制推理引擎日志的详细程度';

  @override
  String get serverConfigLogLevelError => '错误';

  @override
  String get serverConfigLogLevelWarning => '警告';

  @override
  String get serverConfigLogLevelInfo => '信息';

  @override
  String get serverConfigLogLevelDebug => '调试';

  @override
  String get serverConfigSectionReset => '重置';

  @override
  String get serverConfigResetTitle => '恢复默认配置';

  @override
  String get serverConfigResetSubtitle => '确认后会立即保存全部默认值。';

  @override
  String get serverConfigResetDialogTitle => '恢复默认配置';

  @override
  String get serverConfigResetDialogContent => '所有配置项将恢复默认值，确定继续吗？';

  @override
  String get serverConfigResetAction => '恢复默认';

  @override
  String get modelManagementTitle => '模型管理';

  @override
  String get modelManagementImport => '导入模型';

  @override
  String get modelManagementImporting => '导入中...';

  @override
  String modelManagementImportSuccess(String modelName) {
    return '模型导入成功: $modelName';
  }

  @override
  String modelManagementImportFailed(String error) {
    return '导入模型失败: $error';
  }

  @override
  String get modelManagementEmptyTitle => '还没有导入模型';

  @override
  String get modelManagementEmptyDescription =>
      '点击右下角“导入模型”后，这里会显示本地 GGUF 模型列表。';

  @override
  String get modelManagementDeleteBusy => '正在删除模型，请稍后。';

  @override
  String modelManagementDeleteSuccess(String modelName) {
    return '模型已删除: $modelName';
  }

  @override
  String modelManagementDeleteFailed(String error) {
    return '删除模型失败: $error';
  }

  @override
  String get modelManagementDeleteDialogTitle => '删除模型';

  @override
  String modelManagementDeleteDialogContent(String modelName) {
    return '确定删除 $modelName 吗？这会移除模型文件，且无法恢复。';
  }

  @override
  String get modelManagementDeleteTooltip => '删除';

  @override
  String get modelMmprojBadgeLabel => '多模态';

  @override
  String get modelTextBadgeLabel => '文本';

  @override
  String get modelManagementSettingsTooltip => '设置';

  @override
  String get modelSettingsNameLabel => '模型名称';

  @override
  String get modelSettingsMmprojLabel => '多模态投影器';

  @override
  String get modelSettingsImportMmproj => '导入 mmproj 文件';

  @override
  String get modelSettingsRemoveMmproj => '移除 mmproj';

  @override
  String modelManagementMmprojImportSuccess(String modelName) {
    return 'mmproj 导入成功: $modelName';
  }

  @override
  String modelManagementMmprojImportFailed(String error) {
    return 'mmproj 导入失败: $error';
  }

  @override
  String modelManagementMmprojRemoveSuccess(String modelName) {
    return 'mmproj 已移除: $modelName';
  }

  @override
  String modelManagementMmprojRemoveFailed(String error) {
    return 'mmproj 移除失败: $error';
  }

  @override
  String modelManagementRenameSuccess(String modelName) {
    return '模型已重命名为: $modelName';
  }

  @override
  String modelManagementRenameFailed(String error) {
    return '重命名失败: $error';
  }

  @override
  String modelSettingsRemoveMmprojConfirm(String modelName) {
    return '确定移除 $modelName 的 mmproj 文件吗？';
  }

  @override
  String get modelErrorUnsupportedGgufFile => '仅支持导入 .gguf 文件。';

  @override
  String get modelErrorSelectedModelFileMissing => '所选模型文件不存在。';

  @override
  String get modelErrorInvalidModelName => '模型名称无效。';

  @override
  String get modelErrorDuplicateModelName => '模型已存在，请勿重复导入同名模型。';

  @override
  String get modelErrorModelNotFound => '模型不存在。';

  @override
  String get modelErrorSelectedMmprojFileMissing => '所选 mmproj 文件不存在。';

  @override
  String get modelErrorUnsupportedMmprojFile =>
      '仅支持导入文件名以 mmproj 开头的 .gguf 文件。';

  @override
  String get modelErrorMmprojSameAsModelFile => 'mmproj 文件不能与主模型文件同名。';

  @override
  String get modelErrorEmptyModelName => '模型名称不能为空。';

  @override
  String get modelErrorModelNameExists => '模型名称已存在。';

  @override
  String get modelErrorModelDirectoryExists => '模型目录已存在。';

  @override
  String get modelErrorModelNotFoundOrDeleted => '模型不存在或已被删除。';

  @override
  String get modelErrorSelectedFilePathUnavailable => '无法获取所选文件的路径。';

  @override
  String get serverLogsTitle => '日志';

  @override
  String get serverLogsCopyAll => '复制全部';

  @override
  String get serverLogsClear => '清空';

  @override
  String get serverLogsCopied => '日志已复制';

  @override
  String serverLogsCount(int count) {
    return '共 $count 条日志';
  }

  @override
  String get serverLogsEmpty => '暂无日志输出';

  @override
  String get serverLogsExport => '导出日志';

  @override
  String serverLogsExported(String path) {
    return '日志已导出到 $path';
  }

  @override
  String serverLogsExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get serverLogsAutoScroll => '自动滚动';

  @override
  String get serverLogsFilterAll => '全部';

  @override
  String get serverLogsFilterEngine => '引擎';

  @override
  String get serverLogsFilterServer => '服务';

  @override
  String get serverLogsFilterModel => '模型';

  @override
  String get serverLogsFilterDownload => '下载';

  @override
  String get serverLogsFilterErrors => '仅错误';

  @override
  String get engineSectionTitle => '推理引擎';

  @override
  String get serverStatusIdle => '未运行';

  @override
  String get serverStatusPreparing => '准备中';

  @override
  String get serverStatusStopping => '正在停止';

  @override
  String get serverStatusError => '启动失败';

  @override
  String get serverCancelPreparation => '取消';

  @override
  String serverUptime(String duration) {
    return '已运行 $duration';
  }

  @override
  String serverUptimeHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分';
  }

  @override
  String serverUptimeMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get serverActiveModelLabel => '当前模型';

  @override
  String get serverNoModelSelected => '未选择模型';

  @override
  String get serverNoModelSelectedHint => '可选 · 启动后按需加载';

  @override
  String get serverModelRequiredHint => 'MNN 需要先选择模型才能启动';

  @override
  String get serverSelectModelTitle => '选择模型';

  @override
  String get serverSelectModelNone => '不选择模型直接启动';

  @override
  String serverNoModelsForEngine(String engine) {
    return '模型库中还没有 $engine 模型';
  }

  @override
  String get serverPhaseLoadingModel => '加载模型';

  @override
  String get serverPhaseStartingServer => '启动服务';

  @override
  String get serverPhaseVerifying => '健康检查';

  @override
  String get serverPhaseUnloadingModel => '卸载模型';

  @override
  String get serverPhaseStoppingServer => '停止服务';

  @override
  String runtimeErrorPortInUse(int port) {
    return '端口 $port 当前不可用，可能仍有其他服务正在使用。';
  }

  @override
  String get runtimeErrorModelLoadFailed => '模型加载失败。';

  @override
  String get runtimeErrorServerStartFailed => '服务启动失败，请查看日志。';

  @override
  String get runtimeErrorServerStopFailed => '服务停止失败。';

  @override
  String get runtimeErrorModelRequired => '请先选择模型。';

  @override
  String get runtimeErrorEngineUnavailable => '该引擎在此设备上不可用。';

  @override
  String runtimeErrorUnknown(String detail) {
    return '发生错误：$detail';
  }

  @override
  String get serverConfigRestartNotice => '改动即时保存。服务正在运行，本页参数需停止并重新启动服务后才会生效。';

  @override
  String get serverConfigSavedNotice => '改动即时保存。';

  @override
  String get serverOpenAccessWarning =>
      '当前监听所有网络接口且未设置 API Key，同一网络中的设备都可访问此服务。';

  @override
  String get modelLibraryTitle => '模型库';

  @override
  String get modelLibraryAddTitle => '添加模型';

  @override
  String get modelLibraryFilterAll => '全部';

  @override
  String get modelLibraryDownloadingSection => '下载中';

  @override
  String get modelLibraryInstalledSection => '已安装';

  @override
  String get modelAddDownload => '从模型仓库下载';

  @override
  String get modelAddDownloadDesc => '支持 Hugging Face 与魔搭，断点续传';

  @override
  String get modelAddGguf => '导入 GGUF 文件';

  @override
  String get modelAddGgufDesc => 'llama.cpp 使用的单个 .gguf 文件';

  @override
  String get modelAddMnnDir => '导入 MNN 模型目录';

  @override
  String get modelAddMnnDirDesc => 'MNN 引擎使用的整个模型目录';

  @override
  String get modelFormatExplainer => 'GGUF 是单个文件，MNN 模型是整个目录。卡片上的引擎徽标用于区分两者。';

  @override
  String get modelLibraryEmptyTitle => '还没有模型';

  @override
  String get modelLibraryEmptyDescription => '可以下载一个，或导入已有的模型文件。';

  @override
  String modelLibraryDeleteDialogContent(String modelName) {
    return '确定删除「$modelName」？该模型的文件将从本机移除。';
  }

  @override
  String get modelLibraryStatusRunning => '运行中';

  @override
  String get modelLibraryStatusIdle => '空闲';

  @override
  String get modelLibraryActiveCannotDelete => '运行中的模型不可删除';

  @override
  String get modelLibrarySwitchEngineBlocked => '当前服务正在运行，请先停止服务再切换引擎。';

  @override
  String get modelLibraryActivationFailed => '模型激活失败，请查看服务器日志。';

  @override
  String get modelCapabilityChinese => '中文';

  @override
  String get modelCapabilityEnglish => '英文';

  @override
  String get modelCapabilityVision => '视觉';

  @override
  String get modelCapabilityToolCalling => '工具调用';

  @override
  String get discoverTitle => '发现模型';

  @override
  String get discoverTabFeatured => '精选';

  @override
  String get discoverTabSearch => '搜索';

  @override
  String discoverDeviceMemory(String available, String total) {
    return '可用内存 $available / 共 $total';
  }

  @override
  String get discoverDeviceMemoryUnknown => '无法读取设备内存，未做可行性判断。';

  @override
  String get discoverSearchHint => '搜索模型仓库';

  @override
  String get discoverSearchDisclaimer => '搜索结果直接来自仓库，未经真机验证。';

  @override
  String get discoverBackToFeatured => '查看真机验证的精选模型';

  @override
  String get discoverSortTrending => '综合';

  @override
  String get discoverSortDownloads => '下载量';

  @override
  String get discoverSortLikes => '喜欢数';

  @override
  String get discoverSortUpdated => '最近更新';

  @override
  String get discoverFormatAll => '全部格式';

  @override
  String get discoverFeaturedNote => '以下模型均经过真机验证。';

  @override
  String get discoverNoResults => '没有匹配的仓库';

  @override
  String get discoverSearchPrompt => '输入模型名称，在双源仓库中搜索。';

  @override
  String get discoverErrorNetwork => '网络不可达，请检查连接或切换线路。';

  @override
  String get discoverErrorUnauthorized => '该仓库需要访问令牌，请在设置中填写。';

  @override
  String get discoverErrorNotFound => '未找到该仓库。';

  @override
  String get discoverErrorMalformed => '仓库返回了无法解析的响应。';

  @override
  String discoverResultCount(int count) {
    return '共 $count 个结果';
  }

  @override
  String discoverDownloadsCount(int count) {
    return '$count 次下载';
  }

  @override
  String get discoverUpdatedUnknown => '更新时间未知';

  @override
  String discoverUpdatedAt(String date) {
    return '$date 更新';
  }

  @override
  String get discoverFileCountUnknown => '文件数待打开后获取';

  @override
  String discoverFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get repoQuantSectionTitle => '量化档位';

  @override
  String get repoFilesSectionTitle => '文件';

  @override
  String get repoDownloadAction => '下载';

  @override
  String repoEstimatedMemory(String size) {
    return '约需 $size';
  }

  @override
  String get repoNoGgufFiles => '该仓库没有 GGUF 文件。';

  @override
  String get repoNoMnnFiles => '该仓库没有 MNN 模型文件。';

  @override
  String repoMnnWholeDirectory(int count) {
    return 'MNN 模型按整个目录下载（$count 个文件）。';
  }

  @override
  String get feasibilityComfortable => '运行流畅';

  @override
  String get feasibilityTight => '内存吃紧';

  @override
  String get feasibilityNotEnoughMemory => '内存不足';

  @override
  String get feasibilityUnknown => '未知';

  @override
  String get catalogSummaryVerifiedSmallGeneralist => '小体积通用模型，加载快';

  @override
  String get catalogSummaryVerifiedEntryLevel => '入门级，几乎所有设备都能跑';

  @override
  String get catalogSummaryVerifiedBalanced => '质量与速度均衡';

  @override
  String get catalogSummaryVerifiedMnnDefault => 'MNN 引擎的默认选择';

  @override
  String get catalogSummaryVerifiedMnnBalanced => '更强的 MNN 模型，适合性能较好的手机';

  @override
  String get catalogSummaryVerifiedMnnVision => '支持图片理解的 MNN 模型';

  @override
  String get downloadsTitle => '下载任务';

  @override
  String get downloadsEmpty => '暂无下载任务';

  @override
  String get downloadStatusQueued => '排队中';

  @override
  String get downloadStatusRunning => '下载中';

  @override
  String get downloadStatusPaused => '已暂停';

  @override
  String get downloadStatusFailed => '失败';

  @override
  String get downloadStatusDownloaded => '导入中';

  @override
  String get downloadStatusCompleted => '已完成';

  @override
  String get downloadPause => '暂停';

  @override
  String get downloadResume => '继续';

  @override
  String get downloadCancel => '取消';

  @override
  String get downloadRetry => '重试';

  @override
  String get downloadSwitchSource => '换源';

  @override
  String downloadStarted(String modelName) {
    return '已开始下载 $modelName';
  }

  @override
  String downloadProgressDetail(String received, String total, String speed) {
    return '$received / $total · $speed/s';
  }

  @override
  String downloadProgressUnknownTotal(String received, String speed) {
    return '已下载 $received · $speed/s';
  }

  @override
  String downloadRemaining(String duration) {
    return '剩余 $duration';
  }

  @override
  String downloadFilesProgress(int done, int total) {
    return '$done/$total 个文件';
  }

  @override
  String get downloadErrorNetwork => '连接中断';

  @override
  String get downloadErrorUnauthorized => '无访问权限，可能需要令牌';

  @override
  String get downloadErrorNotFound => '仓库中已无此文件';

  @override
  String get downloadErrorDiskFull => '存储空间不足';

  @override
  String get downloadErrorIntegrity => '文件长度或校验值不匹配';

  @override
  String get downloadErrorCancelled => '已取消';

  @override
  String get downloadCancelDialogTitle => '取消下载';

  @override
  String downloadCancelDialogContent(String modelName) {
    return '取消「$modelName」？已下载的数据将被丢弃。';
  }

  @override
  String get downloadForegroundTitle => 'ServLlama 正在下载模型';

  @override
  String downloadForegroundText(int count, int percent) {
    return '$count 个任务 · $percent%';
  }

  @override
  String get settingsSectionDownload => '下载';

  @override
  String get settingsHuggingFaceRoute => 'Hugging Face 线路';

  @override
  String get settingsHuggingFaceRouteDescription => '官方站点不可达时可切换到镜像。';

  @override
  String get settingsRouteAuto => '自动';

  @override
  String get settingsRouteOfficial => '官方';

  @override
  String get settingsRouteMirror => '镜像';

  @override
  String get settingsHuggingFaceToken => 'Hugging Face 令牌';

  @override
  String get settingsModelScopeToken => '魔搭令牌';

  @override
  String get settingsTokenDescription => '仅保存在本机，不会写入日志，也不会出现在导出的日志文件中。';

  @override
  String get settingsTokenNotSet => '未设置';

  @override
  String get settingsTokenSheetTitle => '访问令牌';

  @override
  String get settingsWifiOnly => '仅在 Wi-Fi 下下载';

  @override
  String get settingsWifiOnlySubtitle => '切换到移动网络时暂停任务';

  @override
  String get settingsMaxConcurrentDownloads => '并行下载数';

  @override
  String get settingsMaxConcurrentDownloadsDescription => '同时进行的下载任务数量';

  @override
  String get settingsSectionStorage => '存储';

  @override
  String get settingsStorageModels => '模型';

  @override
  String get settingsStorageDownloads => '未完成的下载';

  @override
  String get settingsClearStaging => '清理未完成的下载';

  @override
  String get settingsClearStagingDone => '已清理未完成的下载';

  @override
  String get aboutMnnVersion => 'MNN 版本';

  @override
  String aboutMnnVersionDetail(String value) {
    return 'MNN 版本：$value';
  }

  @override
  String get chatEmptyTitle => '选一个模型开始';

  @override
  String get chatEmptyDescription => '选定模型后服务会自动启动。';

  @override
  String get chatEmptyAction => '选择模型';

  @override
  String get chatChooseEngineToStart => '选择要启动的推理引擎';

  @override
  String chatEngineDefaultModel(String model) {
    return '默认模型：$model';
  }

  @override
  String get chatCurrentRunning => '当前运行';

  @override
  String get chatLoadModelAction => '加载';

  @override
  String get chatPreparingModel => '模型准备中';

  @override
  String get chatEmptyNoModelsDescription => '先下载一个模型，之后全程在本机运行。';
}
