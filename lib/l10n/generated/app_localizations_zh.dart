// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get chatContextChanged => '发送消息后可获取当前上下文的实际用量。';

  @override
  String get chatContextUsage => '上下文用量';

  @override
  String chatContextTokens(String used, String capacity) {
    return '$used / $capacity 词元';
  }

  @override
  String get chatContextActual => '后端实测词元';

  @override
  String get chatContextUnknownCapacity => '上下文上限未知，未取得后端数据时不显示百分比。';

  @override
  String get chatContextActualNote =>
      '最近一次回复的用量快照，包含缓存词元，并非累计计费用量。草稿或对话变更后需重新测量。';

  @override
  String get chatContextBackendCapacity => '正在运行的后端报告的上下文上限。';

  @override
  String get chatContextUnavailable => '词元用量未知';

  @override
  String get chatSpeedEstimated => '估算';

  @override
  String get chatTokenUnknown => '未知';

  @override
  String chatInputTokenUsage(String count, String cached) {
    return '输入 $count（缓存 $cached）';
  }

  @override
  String chatOutputTokenUsage(String count) {
    return '输出 $count';
  }

  @override
  String get settingsGenerationSpeed => '显示生成统计';

  @override
  String get settingsGenerationSpeedSubtitle => '在每条回复下显示速度、输入输出 token 数和缓存命中';

  @override
  String chatPrefillSpeed(String speed) {
    return '预填充 $speed';
  }

  @override
  String chatDecodeSpeed(String speed) {
    return '解码 $speed';
  }

  @override
  String get chatSpeedUnavailable => '暂无';

  @override
  String get v2McpEmpty => '还没有 MCP 服务';

  @override
  String get v2McpEmptyHint => '点击右上角 + 添加';

  @override
  String get v2McpSearchHint => '搜索 MCP 服务';

  @override
  String get v2McpSearchClear => '清除搜索';

  @override
  String get v2McpNoResults => '没有匹配的 MCP 服务';

  @override
  String get v2McpStatus => '状态';

  @override
  String get v2McpStatusEnabled => '已启用';

  @override
  String get v2McpStatusDisabled => '已禁用';

  @override
  String get v2McpStatusDisconnected => '未连接';

  @override
  String get v2McpStatusConnecting => '连接中';

  @override
  String get v2McpStatusConnected => '已连接';

  @override
  String get v2McpStatusFailed => '连接失败';

  @override
  String v2McpToolCount(num count) {
    return '$count 个工具';
  }

  @override
  String get v2McpConnectionError => '连接错误';

  @override
  String get v2McpEnableOnMcpPage => '请先在 MCP 页启用';

  @override
  String get v2SkillsEmpty => '还没有技能';

  @override
  String get v2SkillsEmptyHint => '点击右上角 + 导入';

  @override
  String get v2LocalTools => '本地工具';

  @override
  String get v2AssistantManagement => '助手';

  @override
  String get v2AssistantDefaultName => 'AI 助手';

  @override
  String get v2AssistantAddTitle => '新建助手';

  @override
  String get v2AssistantNameRequired => '请输入助手名称';

  @override
  String get v2AssistantSearchHint => '搜索助手';

  @override
  String get v2AssistantSearchClear => '清除搜索';

  @override
  String get v2AssistantNoResults => '没有匹配的助手';

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
  String get commonDone => '完成';

  @override
  String get commonClose => '关闭';

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
  String get chatInputHintStartServer => '模型未加载，请加载模型';

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
  String get settingsThemeModeSubtitle => '选择主题颜色';

  @override
  String get settingsDownloadsSubtitle => '模型下载与存储';

  @override
  String get settingsLanguage => '应用语言';

  @override
  String get settingsLanguageSubtitle => '界面显示语言';

  @override
  String get settingsChatTimeout => '聊天超时时间';

  @override
  String get settingsChatTimeoutSubtitle => '模型响应等待上限';

  @override
  String get settingsAssistantsSubtitle => '提示词、模型与工具';

  @override
  String get settingsConnectionsSubtitle => '供应商与 API 连接';

  @override
  String get settingsSkillsSubtitle => '可复用的技能包';

  @override
  String get settingsMcpSubtitle => '外部工具连接';

  @override
  String get settingsServerSubtitle => '本地 OpenAI 兼容服务';

  @override
  String get settingsSpeechSubtitle => '本机转录与语音合成';

  @override
  String get settingsLogsSubtitle => '运行日志与请求诊断';

  @override
  String get settingsAboutSubtitle => '版本、许可与项目信息';

  @override
  String get settingsMnnTestSubtitle => '模型加载与推理测试';

  @override
  String get settingsDebugSubtitle => '服务启动参数';

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
  String get aboutDescription => '手机上的大模型推理服务器';

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
  String get aboutVersionLabel => '版本';

  @override
  String get aboutVersionSubtitle => '点击复制版本号';

  @override
  String get aboutLlamaCppLabel => 'llama.cpp';

  @override
  String get aboutLlamaCppSubtitle => 'GGUF 推理引擎';

  @override
  String get aboutSystem => '系统';

  @override
  String get aboutSystemSubtitle => '当前运行平台';

  @override
  String get aboutMnnSubtitle => '端侧推理引擎';

  @override
  String get aboutGitHubSubtitle => '源码与问题反馈';

  @override
  String get aboutLicenseSubtitle => '第三方依赖许可';

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
  String get serverConfigContextSizeDescription =>
      '模型能关注的最大上下文 token 数量。上下文过高可能导致内存不足闪退';

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
  String get llamaCppBackendTitle => '加速后端';

  @override
  String get llamaCppBackendNextStart => '下次启动服务时生效。';

  @override
  String get llamaCppBackendRefresh => '检测可用后端';

  @override
  String get llamaCppBackendStopServer => '请先停止服务，再检测 GPU / NPU 支持。';

  @override
  String get llamaCppBackendCpu => 'CPU';

  @override
  String get llamaCppBackendOpencl => 'GPU（OpenCL）';

  @override
  String get llamaCppBackendHexagon => 'Hexagon(实验性)';

  @override
  String get llamaCppBackendCpuDescription => '完全在 CPU 上运行，兼容性最好。';

  @override
  String get llamaCppBackendOpenclDescription => '通过 OpenCL 将层卸载到 Adreno GPU。';

  @override
  String get llamaCppBackendHexagonDescription => '支持骁龙 8 Gen 2 及以上NPU加速';

  @override
  String get llamaCppBackendUnavailable => '此设备不可用。';

  @override
  String get llamaCppBackendProbeFailed =>
      '无法检测 llama.cpp 后端。若没有其他可用加速器将使用 CPU。详细原因已记录到引擎日志。';

  @override
  String get llamaCppBackendSavedUnavailable =>
      '已保存的后端当前不可用，请在启动前改选其他后端，或使用自动。';

  @override
  String get llamaCppGpuLayers => '卸载层数';

  @override
  String get llamaCppGpuLayersDescription =>
      '放到所选 GPU 或 NPU 上的层数。数值越大，加速器承担越多。';

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
  String modelManagementImportAutoRenamed(
    String requestedName,
    String finalName,
  ) {
    return '模型导入成功：$finalName\n“$requestedName”与已有模型重名，已自动重命名。';
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
  String get modelSettingsDownloadMmproj => '下载 mmproj';

  @override
  String get modelSettingsReplaceMmproj => '更换 mmproj';

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
  String get modelErrorUnsupportedMmprojFile => '仅支持导入文件名包含 mmproj 的 .gguf 文件。';

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
  String get appLogsTitle => '应用日志';

  @override
  String get appLogsCopyAll => '复制筛选结果';

  @override
  String get appLogsClear => '清空全部日志';

  @override
  String get appLogsClearFailed => '已清空日志视图，但未能删除已保存的日志文件。';

  @override
  String get appLogsCopied => '日志已复制';

  @override
  String get appLogsEmpty => '暂无日志输出';

  @override
  String get appLogsExport => '导出日志';

  @override
  String appLogsExported(String path) {
    return '日志已导出到 $path';
  }

  @override
  String appLogsExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get appLogsAutoScroll => '自动滚动';

  @override
  String get appLogsFilterAll => '全部';

  @override
  String get appLogsFilterEngine => '引擎';

  @override
  String get appLogsFilterServer => '服务';

  @override
  String get appLogsFilterModel => '模型';

  @override
  String get appLogsFilterDownload => '下载';

  @override
  String get appLogsFilterErrors => '仅错误';

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
  String get serverModelRequiredHint => '请先选择模型再启动';

  @override
  String get serverSelectModelTitle => '选择模型';

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
  String get modelLibraryEmptyDescription => '点击 + 添加模型';

  @override
  String get modelLibrarySearchHint => '搜索模型名称';

  @override
  String get modelLibraryEmptySearchTitle => '没有匹配的模型';

  @override
  String get modelLibraryEmptySearchDescription => '换个名称再试试。';

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
  String get repoQuantSectionTitle => '量化档位';

  @override
  String get repoFilesSectionTitle => '文件';

  @override
  String get repoDownloadAction => '下载';

  @override
  String get repoDownloadQueued => '已加入下载任务';

  @override
  String get repoVisionOn => '视觉 · 开';

  @override
  String get repoVisionOff => '视觉 · 关';

  @override
  String get repoVisionSheetTitle => '视觉能力';

  @override
  String get repoVisionEnable => '启用视觉能力';

  @override
  String get repoVisionMmprojSection => '视觉投影器';

  @override
  String get repoVisionDownloadHint => '所选投影器会与模型一起下载。';

  @override
  String get repoVisionDownloadDisabledHint => '仅下载文本模型，之后仍可在模型设置中添加视觉投影器。';

  @override
  String get modelSettingsVisionDisabledHint => '关闭视觉不会删除已下载的投影器。';

  @override
  String get modelSettingsVisionNeedsProjector => '下载并选用一个投影器后，即可使用图片输入。';

  @override
  String get modelSettingsProjectorsHint => '可保留多个版本，一次只使用选中的一个。';

  @override
  String get modelSettingsLocalVisionHint => '导入与此模型匹配的视觉投影器，即可启用图片输入。';

  @override
  String get modelSettingsProjectorDownloaded => '已下载';

  @override
  String get modelSettingsProjectorSelected => '当前选用';

  @override
  String modelSettingsProjectorDeleteConfirm(String fileName) {
    return '删除「$fileName」？删除当前版本后会选用其他已下载版本；没有其他版本时将关闭视觉。';
  }

  @override
  String get modelSettingsOpenRepository => '打开模型仓库';

  @override
  String get modelSettingsRepositoryOpenFailed => '无法打开模型仓库，请稍后重试。';

  @override
  String modelSettingsVisionUpdateFailed(String error) {
    return '更新视觉配置失败：$error';
  }

  @override
  String get modelSettingsProjectorDownloadPending => '投影器下载完成或取消后，可重命名或删除模型。';

  @override
  String get repoVisionNoMmproj => '该仓库没有 mmproj 文件。';

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
  String get catalogSummaryVerifiedBalanced => '质量与速度均衡，适合日常使用';

  @override
  String get catalogSummaryVerifiedMnnDefault => 'MNN 引擎的默认选择';

  @override
  String get catalogSummaryVerifiedMnnBalanced => '更强的 MNN 模型，适合性能较好的手机';

  @override
  String get catalogSummaryVerifiedMnnVision => '支持图片理解的 MNN 模型';

  @override
  String get catalogSummaryVerifiedStrong => '效果更好，适合性能较好的设备';

  @override
  String get catalogSummaryVerifiedLfm25 => '2.6B 多语言模型，适合日常使用';

  @override
  String get catalogSummaryVerifiedMnnSmall => '体积小、加载快，适合大多数手机';

  @override
  String get catalogSummaryVerifiedMnnEveryday => '日常使用更均衡，适合中端设备';

  @override
  String get catalogSummaryVerifiedGemma4E2B => '轻量视觉模型，适合中端设备';

  @override
  String get catalogSummaryVerifiedGemma4E4B => '更强的视觉模型，适合性能较好的手机';

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
  String downloadQueued(String fileName) {
    return '$fileName 已加入下载任务';
  }

  @override
  String downloadCompleted(String fileName) {
    return '$fileName 已下载完成';
  }

  @override
  String downloadStartedAutoRenamed(String requestedName, String finalName) {
    return '已开始下载 $finalName\n“$requestedName”与已有模型重名，已自动重命名。';
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
  String get downloadErrorAlreadyQueued => '相同模型已在下载队列中';

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
  String get settingsHuggingFaceRouteDescription => '官方不可达时切换镜像';

  @override
  String get settingsRouteAuto => '自动';

  @override
  String get settingsRouteOfficial => '官方';

  @override
  String get settingsRouteMirror => '镜像';

  @override
  String get settingsHuggingFaceToken => 'Hugging Face 令牌';

  @override
  String get settingsHuggingFaceTokenSubtitle => '访问私有或受限模型';

  @override
  String get settingsModelScopeToken => '魔搭令牌';

  @override
  String get settingsModelScopeTokenSubtitle => '访问私有或受限模型';

  @override
  String get settingsTokenDescription => '仅保存在本机，不会写入日志，也不会出现在导出的日志文件中。';

  @override
  String get settingsTokenNotSet => '未设置';

  @override
  String get settingsTokenSheetTitle => '访问令牌';

  @override
  String get settingsWifiOnly => '仅在 Wi-Fi 下下载';

  @override
  String get settingsWifiOnlySubtitle => '移动网络下暂停';

  @override
  String get downloadWifiOnlyDialogTitle => '当前为移动网络';

  @override
  String get downloadWifiOnlyDialogMessage =>
      '“仅在 Wi-Fi 下下载”已开启，因此下载在移动网络下会自动暂停。是否仍然使用移动数据继续下载？';

  @override
  String get downloadWifiOnlyDialogAllow => '使用移动数据下载';

  @override
  String get settingsMaxConcurrentDownloads => '并行下载数';

  @override
  String get settingsMaxConcurrentDownloadsDescription => '同时运行的最大任务数';

  @override
  String get settingsSectionStorage => '存储';

  @override
  String get settingsStorageModels => '模型';

  @override
  String get settingsStorageDownloads => '未完成的下载';

  @override
  String get settingsClearStaging => '清理未完成的下载';

  @override
  String get settingsClearStagingSubtitle => '移除临时文件';

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

  @override
  String get mnnBackendTitle => 'MNN 推理后端';

  @override
  String get mnnBackendNextStart => '下次加载模型时生效。';

  @override
  String mnnBackendActive(String backend) {
    return '已加载的后端：$backend';
  }

  @override
  String get mnnBackendRefresh => '检测可用后端';

  @override
  String get mnnBackendCpu => 'CPU';

  @override
  String get mnnBackendOpencl => 'OpenCL GPU';

  @override
  String get mnnBackendVulkan => 'Vulkan GPU';

  @override
  String get mnnBackendHexagon => 'Hexagon NPU（实验性）';

  @override
  String get mnnBackendCpuDescription => '默认选项，模型兼容性最好。';

  @override
  String get mnnBackendGpuDescription => '使用 GPU 加速，首次加载模型需要一定初始化时间。';

  @override
  String get mnnBackendHexagonDescription =>
      '需使用为 Hexagon 导出的模型，推荐对称 4 位量化与 Transformer C4。可能加快长输入处理，逐字生成速度可能慢于 CPU。';

  @override
  String get runtimeErrorModelBackendIncompatible =>
      '此模型的格式不适用于 Hexagon NPU。请选择 CPU/GPU，或导入为 Hexagon 重新导出的模型。';

  @override
  String mnnBackendHexagonArchitecture(String architecture) {
    return '已自动匹配 $architecture 运行库。';
  }

  @override
  String get mnnBackendNotBuilt => '当前插件构建未包含此后端。';

  @override
  String get mnnBackendNativeUnavailable => 'MNN 引擎运行库不可用。';

  @override
  String get mnnBackendLibrariesMissing => '此安装包缺少兼容的 Hexagon 运行库。';

  @override
  String get mnnBackendDriverUnavailable => '设备驱动不可用，或应用无法访问。';

  @override
  String get mnnBackendDeviceUnsupported => '此设备无法匹配或初始化可用的 Hexagon DSP 运行库。';

  @override
  String get mnnBackendNotChecked => '尚未检测可用性。';

  @override
  String get mnnBackendProbeFailed => '无法检测可用后端。请重试，或选择 CPU。详细原因已记录到引擎日志。';

  @override
  String get mnnBackendSavedUnavailable => '已保存的后端当前不可用，请在启动前选择其他后端。';

  @override
  String get runtimeErrorMnnBackendUnavailable =>
      '所选 MNN 后端不可用，请到服务设置中选择 CPU 或其他可用后端。';

  @override
  String get mnnRuntimeTitle => 'MNN 运行参数';

  @override
  String get mnnUseMmap => '使用 mmap';

  @override
  String get mnnUseMmapSubtitle => '将模型权重从磁盘映射到内存，降低占用。首次加载会生成缓存。';

  @override
  String get mnnPrecision => '计算精度';

  @override
  String get mnnPrecisionDescription => '低精度更快、更省内存；高精度 AI 回复更准确。';

  @override
  String get mnnPrecisionLow => '低精度';

  @override
  String get mnnPrecisionHigh => '高精度';

  @override
  String get mnnThreadNum => '生成线程数';

  @override
  String get mnnThreadNumDescription => '生成时使用的 CPU 线程数。';

  @override
  String get mnnMmapCache => '清理 mmap 缓存';

  @override
  String mnnMmapCacheSubtitle(String size) {
    return '当前缓存：$size';
  }

  @override
  String get mnnMmapCacheEmpty => '暂无 mmap 缓存';

  @override
  String get mnnMmapCacheStopServer => '请先停止服务再清理缓存。';

  @override
  String get mnnMmapCacheClearAction => '清理';

  @override
  String get mnnMmapCacheDialogTitle => '清理 mmap 缓存？';

  @override
  String mnnMmapCacheDialogContent(String size) {
    return '将删除已生成的 mmap 和 GPU 运行时缓存（$size）。下次加载模型时会重新生成。';
  }

  @override
  String mnnMmapCacheCleared(String size) {
    return '已清理 $size mmap 缓存';
  }

  @override
  String get mnnMmapCacheClearFailed => '无法清理 mmap 缓存。';

  @override
  String get v2FirstAssistants => '助手';

  @override
  String get v2Chat => '聊天';

  @override
  String get v2Models => '模型';

  @override
  String get v2Add => '新增';

  @override
  String get v2AddProvider => '添加供应商';

  @override
  String get v2OperationFailed => '操作未完成';

  @override
  String get v2NoInstructions => '使用默认对话行为';

  @override
  String get v2Duplicate => '复制';

  @override
  String get v2AssistantEditor => '助手设置';

  @override
  String get v2Name => '名称';

  @override
  String get v2Instructions => '系统指令';

  @override
  String get v2Connection => '供应商';

  @override
  String get v2LocalInference => '本地推理';

  @override
  String get v2MissingTarget => '目标不可用，请检查供应商是否启用、模型是否仍在列表中，或重新选择。';

  @override
  String get v2Model => '模型';

  @override
  String get v2CurrentLocal => '当前本地模型';

  @override
  String get v2ModelId => '模型 ID';

  @override
  String get v2Connections => '供应商';

  @override
  String get v2ConnectionsEmpty => '添加供应商并维护模型列表，即可在聊天中选择。';

  @override
  String get v2ConnectionEditor => '供应商设置';

  @override
  String get v2Protocol => '协议';

  @override
  String get v2BaseUrl => 'API 基础地址';

  @override
  String get v2ApiKey => 'API Key';

  @override
  String get v2ShowApiKey => '显示 API Key';

  @override
  String get v2HideApiKey => '隐藏 API Key';

  @override
  String get v2ApiPath => 'API 路径';

  @override
  String get v2ModelsHelp => '模型 ID，每行一个（可手工输入）';

  @override
  String get v2Images => '支持图片输入';

  @override
  String get v2Tools => '支持工具调用';

  @override
  String get v2FetchModels => '获取模型列表';

  @override
  String get v2TestConnection => '测试供应商';

  @override
  String get v2TestPassed => '测试成功，尚未保存。';

  @override
  String get v2Profile => '用户档案';

  @override
  String get v2KeepOneAssistant => '请先创建另一个助手，再删除最后一个助手。';

  @override
  String get v2DeleteConnectionHelp =>
      '删除此供应商将清空相关助手的模型选择。历史会话与消息保留，发送消息前请重新选择模型。';

  @override
  String get v2Avatar => '头像';

  @override
  String get v2AvatarHelp => '选择本地图片或表情作为头像。仅用于显示。';

  @override
  String get v2AvatarImage => '选择图片';

  @override
  String get v2AvatarEmoji => '选择表情';

  @override
  String get v2AvatarReset => '恢复默认';

  @override
  String get v2AvatarImageTooLarge =>
      '图片过大，请选择不超过 10 MB、边长不超过 8192 像素且总像素不超过 3200 万的图片。';

  @override
  String get v2AvatarInvalidImage => '无法读取这张图片，请选择其他图片。';

  @override
  String get v2AvatarEmojiTitle => '选择头像表情';

  @override
  String get v2AvatarEmojiHint => '输入一个表情或字符';

  @override
  String get v2ChatUserName => '用户';

  @override
  String get v2ChatAssistantName => '助手';

  @override
  String get v2UserName => '用户名称';

  @override
  String get v2ProfileDescription => '描述';

  @override
  String get v2ProfileDescriptionHint => '简单介绍一下自己…';

  @override
  String get v2StartLocal => '加载当前会话的本地模型';

  @override
  String get v2RemoteReady => '直接与所选供应商对话';

  @override
  String get v2Skills => '技能';

  @override
  String get v2ImportSkill => '导入技能（ZIP / Markdown）';

  @override
  String get v2SkillImportPaste => '粘贴 Markdown';

  @override
  String get v2SkillImportFile => '从文件导入';

  @override
  String get v2SkillImportPasteTitle => '粘贴 Markdown';

  @override
  String get v2SkillMarkdownLabel => 'SKILL.md';

  @override
  String get v2SkillImportMarkdownHint => '粘贴包含 SKILL.md 内容的 Markdown';

  @override
  String get v2SkillImportConfirm => '导入';

  @override
  String get v2SkillImportInvalid => 'SKILL.md 格式无效，请检查内容和元数据。';

  @override
  String get v2SkillNameRequired => 'SKILL.md 必须包含 name 或 Markdown 标题。';

  @override
  String get v2SkillDescriptionRequired => 'SKILL.md 的元数据必须包含 description。';

  @override
  String get v2SkillMetadataInvalid => 'name 和 description 必须是简短文本。';

  @override
  String get v2SkillSearchHint => '搜索技能';

  @override
  String get v2SkillSearchClear => '清除搜索';

  @override
  String get v2SkillNoResults => '没有匹配的技能';

  @override
  String get v2SkillMetadataIncomplete => '技能元数据不完整';

  @override
  String get v2SkillStatus => '状态';

  @override
  String get v2SkillEnabled => '已启用';

  @override
  String get v2SkillDisabled => '已停用';

  @override
  String get v2SkillDescription => '描述';

  @override
  String get v2SkillMetadata => '信息';

  @override
  String get v2SkillScripts => '脚本';

  @override
  String get v2SkillDetailBodyEmpty => 'SKILL.md 没有正文内容。';

  @override
  String get v2SkillResources => '资源文件';

  @override
  String get v2SkillNoResources => '无附加资源。';

  @override
  String get v2SkillMoreActions => '更多操作';

  @override
  String get v2SkillEdit => '编辑';

  @override
  String get v2SkillExport => '导出 ZIP';

  @override
  String get v2SkillDelete => '删除技能';

  @override
  String v2SkillDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get v2SkillDeleteCannotUndo => '此操作无法撤销';

  @override
  String v2SkillExported(String path) {
    return '已导出到 $path';
  }

  @override
  String get v2SkillLoadFailed => '无法加载技能。';

  @override
  String get v2SkillFileReadFailed => '无法读取此文件。';

  @override
  String get v2SkillDiscardChanges => '放弃修改？';

  @override
  String get v2SkillDiscardChangesHelp => '未保存的内容将不会保留。';

  @override
  String get v2SkillDiscard => '放弃';

  @override
  String get v2SkillSelectAllEnabled => '全选已启用';

  @override
  String get v2SkillClearSelection => '清空';

  @override
  String get v2SkillEnableOnSkillsPage => '请先在技能页启用';

  @override
  String get v2ScriptsUnsupported => '含脚本参考；本应用只读取静态说明，不执行脚本。';

  @override
  String get v2Mcp => 'MCP';

  @override
  String v2McpDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get v2McpDeleteCannotUndo => '此操作无法撤销';

  @override
  String get v2McpHeaders => '自定义请求头';

  @override
  String get v2McpHeaderName => '请求头名称';

  @override
  String get v2McpHeaderValue => '请求头值';

  @override
  String get v2AddHeader => '添加请求头';

  @override
  String get v2RemoveHeader => '删除请求头';

  @override
  String get v2DiscoverTools => '连接并发现工具';

  @override
  String get v2ToolClock => '当前时间';

  @override
  String get v2ToolRead => '读取会话文件';

  @override
  String get v2ToolAsk => '向用户提问';

  @override
  String get v2ToolSkill => '读取选定技能的参考文件';

  @override
  String get v2ToolActivity => '工具调用记录';

  @override
  String get v2ToolHistoryEmpty => '当前会话没有工具调用记录。';

  @override
  String get v2AwaitingApproval => '等待审批';

  @override
  String get v2Succeeded => '已完成';

  @override
  String get v2UnknownOutcome => '结果未知';

  @override
  String get v2Rejected => '已拒绝';

  @override
  String get v2Cancelled => '已取消';

  @override
  String get v2Executing => '执行中';

  @override
  String get v2Failed => '失败';

  @override
  String get v2UnknownOutcomeHelp => '操作可能已经生效，不会自动重试。核查结果后再明确发起新的运行。';

  @override
  String get v2Details => '参数、目标与回执';

  @override
  String get v2YourAnswer => '你的回答';

  @override
  String get v2Reject => '拒绝';

  @override
  String get v2ApproveOnce => '允许本次';

  @override
  String get v2Review => '审阅';

  @override
  String get v2BudgetReached => '已达到本轮预算，保留已完成的结果。';

  @override
  String get v2Interrupted => '执行已中断，请明确创建新任务重试。';

  @override
  String get v2Speech => '语音工坊';

  @override
  String get v2Asr => '转录';

  @override
  String get v2Tts => '合成';

  @override
  String get v2Tasks => '任务';

  @override
  String get v2SpeechModels => '语音模型';

  @override
  String get v2LlmModels => '语言模型';

  @override
  String get v2Voices => '参考音色';

  @override
  String get v2SpeechAudioInput => '录音与音频';

  @override
  String get v2RecordingReady => '点击麦克风开始录音';

  @override
  String get v2RecordingNow => '正在录音 · 点击停止';

  @override
  String get v2SpeechCreatedAt => '创建时间';

  @override
  String get v2SynthesisContent => '合成文本';

  @override
  String get v2SpeechAudioResult => '合成音频';

  @override
  String get v2TranscriptPending => '暂无转录文本';

  @override
  String get v2SpeechTextCopied => '文本已复制';

  @override
  String get v2LanguageHint => '语言代码（zh / en；留空自动识别）';

  @override
  String get v2StartAsr => '开始转录';

  @override
  String get v2StartTts => '开始合成';

  @override
  String get v2SynthesisText => '要合成的文本';

  @override
  String get v2SpeakerId => '预置说话人 ID（0–217）';

  @override
  String get v2Voice => '音色';

  @override
  String get v2PresetVoice => '模型默认音色';

  @override
  String get v2SynthesisSpeed => '合成语速';

  @override
  String get v2CrispMarking => 'CrispASR 导出音频保留 AI 生成来源标记。';

  @override
  String get v2NoSpeechJobs => '尚无语音任务。完成、取消和中断的结果都会保留在这里。';

  @override
  String get v2NoSpeechJobsEmpty => '尚无语音任务';

  @override
  String get v2CancelTask => '取消任务';

  @override
  String get v2NoAudioSelected => '尚未选择音频';

  @override
  String get v2ImportAudio => '导入音频';

  @override
  String get v2Record => '录音';

  @override
  String get v2StopRecording => '停止录音';

  @override
  String get v2UseRecording => '使用最近录音';

  @override
  String get v2RecordingHelp => '录音最长 10 分钟；离开应用或音频被中断时自动停止。';

  @override
  String get v2SpeechWaitingHelp => '等待上一项语音任务释放资源后自动继续。LLM 服务和聊天可与语音同时运行。';

  @override
  String get v2Queued => '已排队';

  @override
  String get v2WaitingLocal => '等待语音资源';

  @override
  String get v2Cancelling => '取消中，等待原生执行结束';

  @override
  String get v2TaskResult => '任务结果';

  @override
  String get v2CancellationHelp => '当前原生分段结束后释放语音资源，再开始下一项语音任务。LLM 服务和聊天可继续运行。';

  @override
  String get v2NoSpeechDetected => '没有识别到文本。可更换语言或模型后创建新任务。';

  @override
  String get v2ChunkTimingHelp => '此模型仅提供分段时间范围，未提供可靠字幕时间戳，因此只支持 TXT 导出。';

  @override
  String get v2Transcript => '转录文本';

  @override
  String get v2EditTranscript => '修订文本';

  @override
  String get v2ExportTxt => '导出 TXT';

  @override
  String get v2ExportSrt => '导出 SRT';

  @override
  String get v2ExportWav => '导出 WAV';

  @override
  String get v2InsertTranscript => '插入聊天草稿';

  @override
  String get v2PlayPause => '播放 / 暂停';

  @override
  String get v2PreviewAudio => '试听参考音频';

  @override
  String get v2VoiceModelMissing => '原模型已不可用。可导出参考音频，安装兼容模型后重新创建音色。';

  @override
  String get v2PlaybackSpeed => '播放倍速（不改变已合成音频）';

  @override
  String get v2InputSnapshot => '任务输入快照';

  @override
  String get v2SpeechPackageHelp =>
      '语音模型按固定配方安装，每个包独立保存模型、词表、codec 和音色依赖。导入 ZIP 根目录须包含 speech-package.json。';

  @override
  String get v2ImportSpeechPackage => '导入模型 ZIP';

  @override
  String get v2Ready => '可用';

  @override
  String get v2ModelIncomplete => '文件不完整或下载已暂停';

  @override
  String get v2ResumeDownload => '继续下载';

  @override
  String get v2PauseDownload => '暂停下载';

  @override
  String get v2DeleteSpeechModelHelp =>
      '删除本机模型文件。已完成的结果会保留；队列中的任务须先取消，参考音色将需要重新选择模型。';

  @override
  String get v2AvailableModels => '可下载配方';

  @override
  String get v2ModelLicenseHelp => '下载前请查看上游模型说明、支持语言和使用许可。';

  @override
  String get v2ModelCard => '模型说明';

  @override
  String get v2DownloadModel => '下载';

  @override
  String get v2CreateVoice => '创建参考音色';

  @override
  String get v2VoiceHelp =>
      'Qwen3-TTS Base 支持参考音频克隆。使用 3–30 秒清晰单人录音，并填写准确参考文本；音色绑定当前模型版本。';

  @override
  String get v2InstallCloningFirst => '请先安装支持克隆的模型配方。';

  @override
  String get v2VoiceName => '音色名称';

  @override
  String get v2ReferenceText => '参考音频的准确文本';

  @override
  String get v2VoiceRights => '我有权使用这段声音作为参考音色';

  @override
  String get v2VoiceTestText => '试听文本（必填）';

  @override
  String get v2SaveAndPreview => '保存并创建试听任务';

  @override
  String get v2TranscribeToChat => '语音转文字';

  @override
  String get v2NoAutomaticAudioUpload => '只插入文本，不自动发送消息或上传原始音频。';

  @override
  String get v2ReplaceDraft => '替换草稿';

  @override
  String get v2AppendDraft => '追加到草稿';

  @override
  String get v2TranscriptInserted => '转录文本已写入指定聊天草稿。';

  @override
  String get v2ReadAloud => '朗读回答';

  @override
  String v2SynthesisParameters(String speaker, String speed) {
    return '说话人：$speaker · 合成语速：$speed';
  }

  @override
  String v2SampleRate(int rate) {
    return '输出采样率：$rate Hz';
  }

  @override
  String v2DownloadSize(int size) {
    return '下载大小约 $size MiB';
  }

  @override
  String v2TranscriptDestination(String name) {
    return '投递到：$name';
  }

  @override
  String get v2RetrySpeech => '重新创建任务';

  @override
  String v2TranscriptSegment(int index) {
    return '第 $index 段';
  }

  @override
  String get v2ReadAloudHelp => '已填入最终回答正文，可编辑后合成。单次最多 4000 字；长回答请分段处理。';

  @override
  String get v2NativeRestart => '语音资源释放尚未确认。请重启应用后再运行语音任务；当前记录会保留。';

  @override
  String get v2CancelImport => '取消导入';

  @override
  String get v2OriginalChatMissing => '原目标已失效或无法确认，请选择其他会话或助手草稿。转录结果仍会保留。';

  @override
  String v2AssistantDraft(String name) {
    return '新对话 · $name';
  }

  @override
  String get v2TranscriptTarget => '投递到草稿';

  @override
  String get v2DraftChanged => '目标草稿已变化，请重新打开并确认后再替换。';

  @override
  String get v2IncompleteAnswer => '这条回答尚未完整生成，请完成回答后再朗读。';

  @override
  String get v2DiscardRecording => '删除最近录音';

  @override
  String get v2StartupFailed => '暂时无法打开本地数据。已有数据会保留，请处理存储错误后重试。';

  @override
  String get v2RetryStartup => '重新启动';

  @override
  String get appLogsFilterApp => '应用';

  @override
  String get appLogsFilterClient => '客户端';

  @override
  String get appLogsFilterAgent => 'Agent';

  @override
  String get appLogsFilterSpeech => '语音';

  @override
  String get appLogsSearch => '搜索日志或任务 ID';

  @override
  String get appLogsClearSearch => '清除搜索';

  @override
  String get appLogsAllLevels => '全部级别';

  @override
  String get appLogsLevelDebug => '调试及以上';

  @override
  String get appLogsLevelInfo => '信息及以上';

  @override
  String get appLogsLevelWarning => '警告及错误';

  @override
  String appLogsVisibleCount(int visible, int total) {
    return '$visible / $total 条日志';
  }

  @override
  String appLogsRetention(int limit) {
    return '显示最近 $limit 条记录，复制与导出使用当前筛选结果。';
  }

  @override
  String get appLogsNoMatches => '没有匹配的日志';

  @override
  String get v2ToolSearch => '网络搜索';

  @override
  String get v2SearchProvider => '搜索供应商';

  @override
  String get v2SearchBing => 'Bing';

  @override
  String get v2SearchDuckDuckGo => 'DuckDuckGo';

  @override
  String get v2SearchMaxResults => '每次搜索最多返回结果数';

  @override
  String get v2SearchSources => '搜索来源';

  @override
  String get v2SearchNoResults => '没有匹配的网页结果，可以换一个搜索词重试。';

  @override
  String get v2SearchUnavailable => '暂时无法搜索，请检查网络或切换供应商。';

  @override
  String get v2SearchRateLimited => '搜索服务限制了请求频率，请稍后重试或切换供应商。';

  @override
  String get v2SearchChallenge => '搜索服务要求验证或限制了本次访问，请稍后重试或切换供应商。';

  @override
  String get v2SearchInvalidResponse => '搜索服务返回了无法识别的页面，请稍后重试或切换供应商。';

  @override
  String get v2SearchTooLarge => '搜索响应超过大小限制，请使用更具体的搜索词重试。';

  @override
  String get v2SearchTimeout => '搜索超时，请稍后重试或切换供应商。';

  @override
  String get v2SearchOpenFailed => '无法打开此来源链接。';

  @override
  String get v2ConversationModel => '选择模型';

  @override
  String get v2ConversationModelHelp => '按供应商选择模型。点击本地模型后加载并启动服务。';

  @override
  String get v2NoLocalChatModels => '暂无模型';

  @override
  String get v2AssistantDefaultModel => '聊天模型';

  @override
  String get v2NoDefaultModel => '未选择模型';

  @override
  String get v2ClearDefaultModel => '清除模型选择';

  @override
  String get v2UnassignedAssistant => '助手未指定或已删除';

  @override
  String get v2ChangeConversationAssistant => '更换此会话的助手';

  @override
  String get v2ChangeConversationAssistantHelp =>
      '保留本会话的模型、消息、版本和草稿。之后的生成使用新助手的提示词与权限，历史消息署名保持不变。';

  @override
  String get v2ChooseConversationModel => '请选择模型';

  @override
  String v2ConnectionConversationCount(int count) {
    return '$count 个会话使用此供应商，删除后需重新选择模型。';
  }

  @override
  String get v2DeleteAssistantHelp => '删除助手会同时删除关联的所有会话、消息和草稿。此操作不可撤销。';

  @override
  String get v2SwitchAssistantNewChat => '切换助手并新建会话';

  @override
  String v2ToolCallCount(int count) {
    return '工具调用 · $count 次';
  }

  @override
  String get v2ToolRetryLoad => '重新加载';

  @override
  String get v2ToolHistoryFailed => '工具记录加载失败。';

  @override
  String get v2ToolPrepared => '等待执行';

  @override
  String get v2ToolApproved => '已批准，等待执行';

  @override
  String get v2ToolAwaitingAnswer => '等待你的回答';

  @override
  String get v2ToolList => '列出会话文件';

  @override
  String get v2ToolWriteAction => '写入会话文件';

  @override
  String get v2ToolQuestion => '问题';

  @override
  String get v2ToolArguments => '调用参数';

  @override
  String get v2ToolResult => '结果';

  @override
  String get v2ToolSendAnswer => '提交回答';

  @override
  String get chatDeleteMessageTitle => '删除消息';

  @override
  String get chatDeleteCurrentVersion => '删除本版本';

  @override
  String get chatDeleteAllVersions => '删除全部版本';

  @override
  String get chatDeleteAllVersionsConfirm =>
      '确定删除此消息及其全部版本吗？关联的工具调用记录和生成数据也会一并清理，后续消息保留。此操作无法撤销。';

  @override
  String chatDeleteVersionConfirm(int version, int count) {
    return '确定删除第 $version/$count 个版本吗？关联的工具调用记录和生成数据也会一并清理，其他版本和后续消息保留。此操作无法撤销。';
  }

  @override
  String get v2ToolResultTruncated => '此结果已截断，仅可查看或导出已保存的片段。';

  @override
  String get v2ProviderPreset => '预设';

  @override
  String get v2ProviderCustom => '自定义';

  @override
  String get v2ProviderPresetHelp => '预设供应商不可删除，可以修改配置或禁用。';

  @override
  String get v2ProviderEnabled => '启用供应商';

  @override
  String get v2ProviderOn => '已启用';

  @override
  String get v2ProviderOff => '已禁用';

  @override
  String v2ProviderModelCount(int count) {
    return '$count 个模型';
  }

  @override
  String get v2ProviderModelsEmpty => '尚未添加模型，请在供应商设置中手动添加或获取模型。';

  @override
  String get v2AddModel => '手动添加模型';

  @override
  String get v2AddModelAction => '添加';

  @override
  String get v2EditModel => '编辑模型';

  @override
  String get v2RemoveModel => '移除模型';

  @override
  String v2RemoveModelHelp(String model) {
    return '保存后将从供应商列表移除 $model。使用它的会话和助手默认目标将不可用，历史消息保留。';
  }

  @override
  String get v2ModelIdRequired => '请输入模型 ID';

  @override
  String get v2DiscoveredModels => '选择要添加的模型';

  @override
  String get v2ModelAlreadyAdded => '已添加';

  @override
  String get v2ModelSearch => '搜索模型 ID';

  @override
  String get v2ProviderNoResults => '没有匹配的供应商或模型';

  @override
  String get v2ProviderModelSearch => '搜索供应商或模型';

  @override
  String v2AddSelectedModels(int count) {
    return '添加所选（$count）';
  }

  @override
  String get v2SelectVisible => '选择搜索结果';

  @override
  String get v2DeselectVisible => '取消选择搜索结果';

  @override
  String v2LocalProvider(String engine) {
    return '本地 · $engine';
  }

  @override
  String get v2LocalProviderHelp => '从本地模型库管理，通过加载和停止控制运行。';

  @override
  String get v2ServicePublished => '正在对外提供服务';

  @override
  String get v2PublishedModelLocked => '请先在服务中心停止已发布的模型，再切换本地模型。';

  @override
  String get v2LocalModelLoaded => '已加载';

  @override
  String get v2LocalModelUnloaded => '未加载';

  @override
  String get drawerAssistantSettings => '助手';

  @override
  String get settingsUser => '用户设置';

  @override
  String get settingsSectionServices => '服务与诊断';

  @override
  String get settingsSectionDeveloper => '开发工具';

  @override
  String get settingsUiLabSubtitle => '组件、配色与交互预览';

  @override
  String get settingsMigrationPreviewSubtitle => '模拟新版数据迁移流程';

  @override
  String get settingsMnnTest => 'MNN 测试';

  @override
  String get settingsDebug => '调试';

  @override
  String get localModelImport => '导入本地模型';

  @override
  String get localModelChooseImport => '选择并导入';

  @override
  String get localModelImportHelp => '选择文件或目录后即开始导入，文件将复制到应用存储中。';

  @override
  String get discoveryQuery => '搜索预设名称或引擎';

  @override
  String get discoveryReset => '重置筛选';

  @override
  String get discoveryPurpose => '用途';

  @override
  String get discoveryEngine => '引擎';

  @override
  String get discoveryState => '安装状态';

  @override
  String get discoveryNotInstalled => '未安装';

  @override
  String get discoveryDownloading => '下载中';

  @override
  String get discoveryIncomplete => '已暂停 / 未完成';

  @override
  String get discoveryCloneOnly => '声音克隆';

  @override
  String get discoverySmallOnly => '不超过 200 MiB';

  @override
  String get discoverySpeechHelp => '下载包含全部依赖的预设模型包。运行兼容性和效果仍需在你的设备上验证。';

  @override
  String get discoverySpeechLibraryHelp => '请前往发现模型下载语音模型。已安装和未完成的模型包将在这里显示。';

  @override
  String get discoveryOnlineLanguage => '在线搜索语言模型';

  @override
  String get v2StartupPreparing => '正在启动 ServLlama';

  @override
  String get v2CheckingData => '正在检查本地数据';

  @override
  String get v2MigrationTitle => '正在升级应用数据';

  @override
  String get v2MigrationHelp => '正在升级聊天、模型记录和下载进度。模型文件保持原位，升级成功前保留原始数据。';

  @override
  String get v2MigrationFailed => '数据升级未完成。请排除存储问题后重试，原始数据仍保留。';

  @override
  String get v2MigrationChats => '读取聊天记录';

  @override
  String get v2MigrationModels => '读取本地模型记录';

  @override
  String get v2MigrationDownloads => '读取下载任务';

  @override
  String get v2MigrationWriting => '保存升级后的记录';

  @override
  String get v2MigrationVerifying => '校验模型和下载记录';

  @override
  String get v2MigrationComplete => '数据升级完成，正在完成启动…';

  @override
  String v2MigrationRecords(int completed, int total) {
    return '当前步骤：$completed / $total 条记录';
  }

  @override
  String get migrationSetupTitle => '升级本地数据';

  @override
  String get migrationSetupSubtitle => '将旧版聊天、模型记录和下载任务迁移到新的 SQLite 存储。';

  @override
  String get migrationStorageHive => 'Hive';

  @override
  String get migrationStorageSqlite => 'SQLite';

  @override
  String get migrationSetupDataTitle => '将迁移';

  @override
  String get migrationSetupRetainNote => '原始 Hive 文件和模型文件会保留在原位置。';

  @override
  String get migrationProgressTitle => '迁移进度';

  @override
  String get migrationStartButton => '开始迁移';

  @override
  String get migrationSkipFreshButton => '跳过迁移并全新开始';

  @override
  String get migrationSkipFreshTitle => '跳过迁移？';

  @override
  String get migrationSkipFreshMessage =>
      '旧版 Hive 文件会保留，但不会导入 ServLlama。此操作无法撤销。';

  @override
  String get migrationSkipFreshCancel => '取消';

  @override
  String get migrationSkipFreshConfirm => '跳过并开始';

  @override
  String get migrationCompleteTitle => '迁移完成';

  @override
  String get migrationCompleteBody => '旧版聊天、模型记录和下载任务已迁移到 SQLite。';

  @override
  String get migrationStartUsing => '开始使用';

  @override
  String get migrationFailedTitle => '迁移未完成';

  @override
  String get migrationStartupFailedTitle => '无法打开本地数据';

  @override
  String get migrationRetryButton => '重试迁移';

  @override
  String get migrationPreviewTitle => '迁移演示';

  @override
  String get migrationPreviewHelp => '仅模拟界面与交互，不读取或修改真实数据。可随时返回退出。';

  @override
  String get migrationPreviewRestart => '重新演示';

  @override
  String get migrationPreviewFailure => '模拟失败';

  @override
  String get migrationPreviewError => '模拟错误：存储空间不足。点击重试可演示恢复流程。';

  @override
  String get uiLabTitle => 'UI 原语';

  @override
  String get uiLabDark => '预览深色';

  @override
  String get uiLabLight => '预览浅色';

  @override
  String get uiLabVisuals => '视觉基础';

  @override
  String get uiLabControls => '交互组件';

  @override
  String get uiLabScenes => '场景示例';

  @override
  String get uiLabPreview => '设计预览';

  @override
  String get uiLabHeadline => '让内容成为主角';

  @override
  String get uiLabIntro => '以灰白承托内容，用柔和蓝紫标记重点。紧凑有序，也留出恰当的呼吸空间。';

  @override
  String get uiLabQuiet => '简洁克制';

  @override
  String get uiLabSoft => '柔和清爽';

  @override
  String get uiLabPalette => '色彩与表面';

  @override
  String get uiLabPaletteHint => '大面积保持中性，强调色只出现在需要注意的位置。';

  @override
  String get uiLabCanvas => '页面底色';

  @override
  String get uiLabSurface => '内容表面';

  @override
  String get uiLabPrimary => '主色';

  @override
  String get uiLabSelected => '选中底色';

  @override
  String get uiLabTypography => '文字层级';

  @override
  String get uiLabTypographyHint => '通过字号、字重与间距建立层级，减少装饰。';

  @override
  String get uiLabTypeTitle => '清晰，从阅读开始';

  @override
  String get uiLabTypeSection => '一个恰当的分组标题';

  @override
  String get uiLabTypeBody => '正文保持舒适的行高，让长回答也容易阅读。信息自然流动，操作安静地留在需要的位置。';

  @override
  String get uiLabTypeCaption => '辅助信息 · 12 sp · 用于时间、状态与说明';

  @override
  String get uiLabRhythm => '间距、圆角与图标';

  @override
  String get uiLabRhythmHint => '组内紧凑，组间舒展；小图标也拥有充足触控空间。';

  @override
  String get uiLabRadii => '卡片圆角 18 dp · 输入框 14 dp\n操作区域至少 48 dp';

  @override
  String get uiLabLocalOnly => '以下操作仅用于体验样式，不连接模型或保存业务数据。';

  @override
  String get uiLabActions => '按钮与浮层';

  @override
  String get uiLabActionsHint => '主要操作突出，次要操作柔和，低频操作保持轻量。';

  @override
  String get uiLabPrimaryAction => '主要操作';

  @override
  String get uiLabSecondaryAction => '次要操作';

  @override
  String get uiLabSheet => '底部弹窗';

  @override
  String get uiLabDialog => '确认对话框';

  @override
  String get uiLabDisabled => '不可用';

  @override
  String get uiLabDialogTitle => '确认本次选择？';

  @override
  String get uiLabDialogBody => '这是一个对话框样式示例。确认后将展示轻量提示，不会修改真实配置。';

  @override
  String get uiLabConfirm => '确认';

  @override
  String get uiLabFeedback => '交互已完成，仅在当前预览中生效。';

  @override
  String get uiLabChooseModel => '选择模型';

  @override
  String get uiLabOnDevice => '本地模型 · 示例';

  @override
  String get uiLabCloud => '云端模型 · 示例';

  @override
  String get uiLabForms => '输入与选择';

  @override
  String get uiLabFormsHint => '点按输入框、开关、滑块和标签，感受状态变化。';

  @override
  String get uiLabName => '助手名称';

  @override
  String get uiLabNameHint => '为助手取个名字';

  @override
  String get uiLabNameError => '请填写助手名称';

  @override
  String get uiLabStreaming => '流式输出';

  @override
  String get uiLabStreamingHint => '逐步呈现回答内容';

  @override
  String get uiLabTemperature => '温度';

  @override
  String get uiLabVision => '视觉能力';

  @override
  String get uiLabValidate => '校验输入';

  @override
  String get uiLabStates => '状态与进度';

  @override
  String get uiLabStatesHint => '颜色辅助识别，文字始终说明当前状态。';

  @override
  String get uiLabReady => '已就绪';

  @override
  String get uiLabWaiting => '等待中';

  @override
  String get uiLabFailed => '失败';

  @override
  String get uiLabDownload => '模型下载 · 演示';

  @override
  String get uiLabSimulate => '模拟进度';

  @override
  String get uiLabAgain => '重新体验';

  @override
  String get uiLabChat => '聊天';

  @override
  String get uiLabChatHint => '用户气泡、助手正文、工具过程与消息末尾信息。';

  @override
  String get uiLabYou => '用户';

  @override
  String get uiLabQuestion => '帮我整理一下今天的阅读计划。';

  @override
  String get uiLabAssistant => '阅读助手';

  @override
  String get uiLabTool => '已完成 · 检索阅读资料';

  @override
  String get uiLabToolDetail => '搜索 → 整理 → 返回结果\n这是可展开的工具过程示例，没有发送网络请求。';

  @override
  String get uiLabAnswer =>
      '可以先留出 25 分钟，专注读完一个章节。\n\n然后用 5 分钟写下三个要点，以及一个想继续探索的问题。让阅读有节奏，也给思考留一点空间。';

  @override
  String get uiLabReply => '已收到这条预览消息。这里展示正文排版与发送反馈，不会调用真实模型。';

  @override
  String get uiLabCopy => '复制反馈示例';

  @override
  String get uiLabMore => '更多选项';

  @override
  String get uiLabManagement => '分组列表与模型卡片';

  @override
  String get uiLabManagementHint => '统一对齐、轻量分隔，详细信息按需展开。';

  @override
  String get uiLabAssistantHint => '整理知识，陪伴阅读';

  @override
  String get uiLabProviderHint => '已配置 2 个模型 · 示例';

  @override
  String get uiLabVoice => '语音';

  @override
  String get uiLabVoiceHint => '转录与合成 · 示例';

  @override
  String get uiLabComposer => '输入一条消息，体验交互';

  @override
  String get uiLabSend => '发送预览消息';

  @override
  String get uiLabExactValue => '精确值';

  @override
  String get uiLabNumericHint => '滑动粗调，右侧输入精确值，最多两位小数。';

  @override
  String uiLabNumericError(String min, String max) {
    return '请输入 $min–$max 范围内的数值，最多两位小数。';
  }

  @override
  String get uiLabMessages => '消息提示';

  @override
  String get uiLabMessagesHint => '顶部居中悬浮，3 秒后消失。新消息替换旧消息，也可手动关闭。';

  @override
  String get uiLabDismissMessage => '关闭提示';

  @override
  String get uiLabMessageSuccess => '成功';

  @override
  String get uiLabMessageInfo => '信息';

  @override
  String get uiLabMessageWarning => '警告';

  @override
  String get uiLabMessageError => '错误';

  @override
  String get uiLabMessageInfoText => '当前为样式预览，操作不会影响真实数据。';

  @override
  String get uiLabMessageWarningText => '尚未选择模型，请先完成选择。（示例）';

  @override
  String get uiLabMessageErrorText => '连接失败，请检查设置后重试。（示例）';

  @override
  String get uiLabThemeColor => '切换主题色';

  @override
  String get uiLabViolet => '雾紫';

  @override
  String get uiLabTea => '茶紫';

  @override
  String get uiLabTeaIntro => '紫调融入淡茶色，搭配温润的中性表面。柔和克制，层次清晰。';

  @override
  String get numericExactValue => '精确值';

  @override
  String get numericHint => '滑动粗调，右侧输入精确值，最多两位小数。';

  @override
  String numericError(String min, String max) {
    return '请输入 $min–$max 范围内的数值，最多两位小数。';
  }

  @override
  String get commonDismissMessage => '关闭提示';

  @override
  String get v2ProviderConfiguration => '配置';

  @override
  String get v2ProviderIdentity => '供应商信息';

  @override
  String get v2ProviderConnection => '连接配置';

  @override
  String get v2ProtocolOpenai => 'OpenAI 兼容';

  @override
  String get v2ModelCapabilities => '模型能力';

  @override
  String get v2ModelText => '文本';

  @override
  String get v2ModelImages => '图片';

  @override
  String get v2ModelTools => '工具';

  @override
  String get v2IdentitySettings => '头像与名称';

  @override
  String get v2InstructionsHint => '描述助手的角色、回复风格和要求…';

  @override
  String get v2ModelImagesUnavailable => '当前模型未启用图片输入，可在供应商的模型设置中调整。';

  @override
  String get chatGreetingMorning => '早上好';

  @override
  String get chatGreetingNoon => '中午好';

  @override
  String get chatGreetingAfternoon => '下午好';

  @override
  String get chatGreetingEvening => '晚上好';

  @override
  String get chatWelcomeDescription => '今天想聊些什么？';
}
