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
  String get chatReasoningProcess => '深度思考';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsLanguage => '应用语言';

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
  String get serverConfigTitle => '服务器配置';

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
  String get serverConfigApiKeyDescription => '留空则不启用校验。';

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
  String get serverConfigUseMmap => '使用 mmap';

  @override
  String get serverConfigUseMmapSubtitle => '提高模型的加载性能';

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
  String get modelManagementEmptyTitle => '还没有导入模型';

  @override
  String get modelManagementEmptyDescription =>
      '点击右下角“导入模型”后，这里会显示本地 GGUF 模型列表。';

  @override
  String get modelManagementDeleteDialogTitle => '删除模型';

  @override
  String modelManagementDeleteDialogContent(String modelName) {
    return '确定删除 $modelName 吗？这会移除模型文件，且无法恢复。';
  }

  @override
  String get modelManagementDeleteTooltip => '删除';

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
}
