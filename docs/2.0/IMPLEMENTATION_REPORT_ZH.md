# ServLlama 2.0 实现报告

> 2026-10-07，开发目录与版本整理：应用 2.0 的 103 个提交整合为单个汇总提交；ServLlama 在原目录使用 `feature/2.0`，配套插件在原目录使用 `feature/0.2.0`。应用版本统一为 2.0.0+15，构建号从 1.2.2+14 递增；插件为 0.2.0，仅本地提交，未 push 或发布。当前目录见第 1 节；下文旧阶段的 dev 版本、分支、提交和临时日志路径作为历史记录保留，历史 APK 信息不随源码版本调整而改变。

> 2026-10-06，dev.36+50：按要求移除整套内存/温控压力启动拦截，包括 Android 监听、压力通道、30 秒复查及语音压力等待提示。停止确认释放后可立即启动同引擎另一模型或切换引擎，仍保留真实资源占用及清理失败保护。全量 725 项测试、静态分析通过；当前无 ADB 设备。设计与验收见[模型重新启动](MODEL_RESTART_ZH.md)。

> 2026-10-06，dev.35+49：修正输入栏左侧服务器/模型图标在按压区域内偏左的问题，保持 48 dp 点击区域、20 dp 文字留白及图标与文字左对齐。26 项相关回归、静态分析、明暗离屏按压检查及 APK 校验通过；当前无 ADB 设备。见[输入栏按压反馈](COMPOSER_FEEDBACK_ZH.md)。

> 2026-10-06，dev.34+48：聊天输入栏服务器按钮恢复固定线框图标与右下角状态点，未运行灰色、运行中绿色；保留两引擎快捷启动、停止和忙时禁用。56 项聊天相关回归及静态分析通过；当前无 ADB 设备，真机待验收。见[本地服务快捷入口](UI_DETAILS_SERVER_SHORTCUT_ZH.md)。

> 2026-10-06，dev.33+47：供应商与模型图标采用 LobeHub 彩色资源，移除整图统一染色；内置 21 个 SVG（17 个彩色），单色标志适配明暗主题。Claude、Gemma、Kimi 使用各自标志，Kimi 白色字形单独适配以保证浅色可见。15 项相关回归、静态分析、明暗离屏检查及 APK 版本/签名/对齐/原生库/图标资源校验通过；当前无 ADB 设备。来源与验收见[全应用 UI 重构](UI_REDESIGN_ZH.md#dev33-彩色图标验收)。

> 2026-10-06，dev.32+46：欢迎区顶部加入应用图标，去掉用户称呼，彩色时段图标移到问候前且无背景；三个入口固定竖排，采用共享卡片底色和蓝/琥珀/青绿图标底块，提升色彩对比。48 项相关回归、最终紧凑布局检查及静态分析通过，Debug APK 版本、签名、对齐与原生库校验通过；当前无 ADB 设备。明暗、大字体和键盘滚动截图见[聊天欢迎区](CHAT_WELCOME_ZH.md)。

> 2026-10-05，dev.31+45：聊天空白页统一为时段问候、用户名称与服务器/语音转录/语音合成三入口；采用雾紫卡片，适配大字体与键盘。725 项全量测试、静态分析、实际页面离屏检查及 Debug APK 校验通过；当前无 ADB 设备。设计、截图和验收见[聊天欢迎区](CHAT_WELCOME_ZH.md)。

> 2026-10-05，dev.30+44：模型选择统一属于助手；聊天切模同步影响同助手所有会话，转移会话跟随新助手模型。删除供应商/模型或停用供应商清空相关选择；未选模型时保留正常输入，发送提示“请选择模型”且不创建消息/Run。移除会话 target 与最近模型回退，保留历史版本/工具记录及 Run 快照；补齐本地删除清理和旧编辑页冲突保护。722 项全量测试、最后修改后的 55 项相关回归及静态分析通过；Debug APK 的版本、签名与原生库审计通过。当前无 ADB 设备。设计、边界和验收见[会话、助手与模型选择](CONVERSATION_ASSISTANTS_ZH.md)。

> 2026-10-05，dev.29+43：语音页重新进入时不自动回显上次转录/合成结果，历史任务保留；转录模型与语言配置移到录音区上方。25 项相关测试及静态分析通过。详见 [语音页内结果与任务展示](SPEECH_UI_ZH.md)。

> 2026-10-05，dev.28+42：设置新增语音入口；转录、合成及音色试听改为原页等待并显示结果；转录采用大麦克风与计时，任务卡增加文本预览和日期时间，结果详情统一文本/音频分组并隐藏输入快照。716 项全量测试、静态分析、明暗/大字体离屏检查及 APK 成品核对通过；无连接设备，真机语音流程待验收。详见 [语音页内结果与任务展示](SPEECH_UI_ZH.md)。

> 2026-10-04，dev.27+41：去掉 llama.cpp 后端选中底色，可编辑头像增加角标，用户档案收敛为头像/用户名称/描述，修正侧栏与历史搜索居中，隐藏聊天顶部工具记录入口。服务器快捷按钮在云端聊天中保持显示，恢复引擎选择及缺省模型补选，不改变聊天目标。711 项全量测试、25 项最终页面回归、静态分析、离屏检查及 APK 校验通过；无连接设备，真机待验收。详见 [UI 细节与服务快捷入口](UI_DETAILS_SERVER_SHORTCUT_ZH.md)。

> 2026-10-04，dev.26+40：图片输入和工具调用改为逐模型配置；供应商编辑页采用底部“配置 / 模型”标签，两页共享草稿并统一保存，旧模型继承已有能力，新模型默认文本。统一供应商、助手、档案、MCP、语音和设置表单的分组、间距与主题样式。706 项全量测试、静态分析、实际页面离屏检查和 Debug APK 成品校验通过；当前无 ADB 设备，真机及真实供应商复核待执行。详见 [模型能力配置与 UI 统一](PROVIDER_MODEL_UI_ZH.md)。

> 2026-10-03，dev.25+39：统一页面跳转与弹窗的焦点释放，返回后保留草稿而不自动弹键盘；补齐侧边栏开合、标签点击/滑动和聊天图片/语音音频选择入口。目的界面的主动聚焦保留。700 项全量测试及静态分析通过，真机输入法待验收。详见 [导航焦点设计与验收](NAVIGATION_FOCUS_ZH.md)。

> 2026-10-03，dev.24+38：输入栏移除语音图标，“+”移至发送旁；发送圆底缩为 32 dp、触控范围保留 48 dp，左侧内边距增至 20 dp。助手管理去掉选中态与提示词摘要；共享主题采用轻量按压底色，去掉扩散水波。690 项全量测试、静态分析和离屏检查通过，真机待复验。详见 [设计与验收](COMPOSER_FEEDBACK_ZH.md)。

> 2026-10-03，dev.23+37：助手管理与编辑页简化，能力配置合并为本地工具/技能/MCP 标签；移除档案注入与参数编辑控件，技能/MCP 改为居中空状态和浮动添加按钮；聊天图标对齐，模型弹窗去掉行尾图标。686 项全量测试、静态分析和离屏 UI 检查通过，真机待验收。详见 [设计、实现与验收](ASSISTANT_UI_ZH.md)。

> 2026-10-03，dev.22+36：统一表单间距，简化工具卡片与模型选择弹窗，输入栏向 UI 原语样式统一，标题恢复原字号；移除回执导出。684 项全量测试、静态分析与离屏 UI 检查通过，真机待验收。详见 [UI 细化与验收](UI_REFINEMENT_ZH.md)。

> 2026-10-02，dev.21+35：全应用采用雾紫 UI 原语；下载设置移至独立页面，供应商支持搜索，内置模型/供应商品牌图标，短暂反馈统一为 AppBar 下方消息。682 项全量测试及静态分析通过。已检查实际页面明暗离屏截图、窄屏与键盘；当前未连接 ADB 设备，真机验收待执行。设计、截图、包校验及操作指南见 [全应用 UI 重构](UI_REDESIGN_ZH.md)。

> 2026-10-02，dev.20+34：UI 原语的消息提示移至 AppBar（含页签栏）下方 12 dp，进入动画也不会遮挡顶部操作。20 项相关测试、静态分析和离屏渲染通过；真机待安装体验。详见 [UI 原语样板](UI_PRIMITIVES_ZH.md)。

> 2026-10-02，dev.19+33：UI 原语新增「雾紫／茶紫」主题色切换，支持独立明暗模式及弹窗配色同步。20 项相关测试和静态分析通过；真机待安装体验。详见 [UI 原语样板](UI_PRIMITIVES_ZH.md)。

> 2026-10-02，dev.18+32：UI 原语的滑块新增右侧精确数值输入；短暂反馈改为顶部居中消息，支持四种语义状态、自动消失与手动关闭。仅作用于预览页。19 项相关测试及静态分析通过；真机待安装体验。详见 [UI 原语样板](UI_PRIMITIVES_ZH.md)。

> 2026-10-02，dev.17+31：侧边栏新增“UI 原语”，包含独立明暗主题、基础样式、交互组件与场景样板。详见 [UI 原语样板](UI_PRIMITIVES_ZH.md)。

> dev.16+30：侧边栏新增“迁移演示”，支持模拟进度、失败重试和完成返回，不访问真实数据。使用说明见 [存储迁移指南](STORAGE_MIGRATION_ZH.md#迁移-ui-演示dev16)。

> 最新进展（dev.15）：Drift 真机覆盖升级与 SQLite 写入冒烟通过，已清理四类早期 2.0 迁移。当前结果及兼容边界见 [真机验收与迁移清理](DRIFT_DEVICE_ACCEPTANCE_ZH.md)。

> 2026-09-30：Drift 已升级到兼容当前 Flutter 3.35.2 / Dart 3.9.0 的 2.31.0；保留 sqlite3_flutter_libs 0.5.39。验证结果与本次 APK 信息见 [Drift 升级记录](DRIFT_UPGRADE_ZH.md)。

最近交付：2026-09-30。应用版本：2.0.0-dev.14+28；配套插件：mnn_engine 0.2.0-dev.2。以下保留各阶段历史验证记录。

四阶段的应用与插件代码已实现，并按阶段提交、合入本地 feature/2.0。没有 push，也没有发布 APK 或插件。本报告区分代码交付、自动化验证与真机验收；当前交付是可继续验收的开发版本，不能把编译成功等同于模型和设备认证完成。

四阶段实现基于工作区 docs/servllama-2.0 中的 1.1 版设计，当前已补充到 1.8 版：统一 HTTP 取消、LLM 与语音独立驻留、会话绑定助手且独立选模型、助手级联删除，消息版本删除与工作区移除，供应商和统一模型选择，以及侧栏导航、设置和模型双标签。用户最终确认的边界已落实：用户资料仅在本地保存；对外仍只有本地 LLM 服务；ASR/TTS 只供应用内部使用。

配套文件：[侧栏导航与模型库](NAVIGATION_ZH.md)、[供应商与统一模型选择](PROVIDERS_ZH.md)、[消息版本删除与工作区移除](MESSAGE_DELETION_ZH.md)、[聊天内工具过程设计](CHAT_TOOL_ACTIVITY_ZH.md)、[验收指南](ACCEPTANCE_GUIDE_ZH.md)、[语音模型包说明](SPEECH_MODEL_PACKAGES_ZH.md)、[HTTP 取消与资源释放设计 1.3](CANCELLATION_DESIGN_ZH.md)、[应用日志设计](APPLICATION_LOGGING_ZH.md)、[dev.5 真机冒烟报告](DEVICE_SMOKE_2026-09-27_ZH.md)、[网络搜索使用与验收](WEB_SEARCH_ZH.md)、[头像与聊天署名设计/界面](CHAT_IDENTITY_ZH.md)、[会话、助手与模型设计](CONVERSATION_ASSISTANTS_ZH.md)。此前已完成 Redmi K50 Ultra / Android 12 主流程冒烟、语音修复与搜索接入；dev.7 已增加用户/助手图片头像及消息署名；dev.8 补齐会话归属、独立模型和草稿隔离；dev.9 将删除助手改为同时删除关联会话；dev.10 在助手回复内显示工具过程；dev.11 补齐删除本版本/全部版本和关联记录清理，移除工作区与内置文件工具，保留提问、搜索、Skill、MCP 和回执导出；dev.12 将“AI 连接”改为供应商，加入固定预设、启用开关、显式模型清单与可搜索的统一底部弹窗，本地模型点选后加载启动；本轮 dev.13 去掉底部导航，将助手选择和五个功能图标放到侧栏，合并设置入口，并统一语言/语音模型库。模型效果、Crisp 和完整发布矩阵仍有待验收项。

## 1. 仓库与提交

| 仓库 | 当前开发目录 | 起点 | 交付分支 |
|---|---|---|---|
| ServLlama | D:/flutter projects/MNN-runtime/servllama | 39a334c | feature/2.0 |
| mnn_engine | D:/flutter projects/MNN-runtime/mnn_engine | 7c0cfc3 | feature/0.2.0 |

两个项目均在原始目录开发，`main` 分支保持原样。应用的 Gradle 配置已恢复仓库版本；签名文件、`.claude/`、本地插件覆盖及必要原生库继续保留且不提交。2.0 的临时工作树不再作为开发入口。MNN、llama.cpp、sherpa-onnx、CrisperWeaver、Kelivo、RikkaHub 等参考检出没有为本次功能修改。

以下阶段表记录整理前的开发过程；应用当前只保留一个 2.0 汇总提交，不再保留旧阶段分支。插件提交历史不变，只将交付分支重命名为 `feature/0.2.0`。

| 阶段 | 特性分支 | 实现提交 | 内容 |
|---|---|---|---|
| P1 基础 | feature/2.0-p1-foundation | 174e870 | 事务存储、旧数据导入、稳定模型 ID、运行时所有权、私用端点、宿主生命周期 |
| P2 聊天 | feature/2.0-p2-chat | 0232e87 | 本地档案、助手、供应商连接、三协议聊天、五入口导航 |
| P3 Agent | feature/2.0-p3-agent | d9ac125 | 有限工具循环、审批与回执、静态 Skill、远程 MCP、历史再生成 |
| P3 插件配套 | feature/2.0-p3-request-cancellation | 509eb44 | 初版取消实现和 Android 服务所有权；插件合入点 7b1646b；公开请求 ID 方案已由后续 HTTP 取消优化替代 |
| P4 语音与集成 | feature/2.0-p4-speech | 110f5a4 | 双引擎语音、模型包、音频 I/O、参考音色、聊天语音、全链路收尾 |

应用四阶段集成点：2b52c6f，首次交付报告：bee36c9。随后在两个仓库各自的 fix/2.0-http-cancellation 分支落实 HTTP 取消优化，再合入当时的 feature/2.0。各阶段当时采用本地 merge --no-ff；当前分支结构以上述整理结果为准。

| HTTP 取消优化仓库 | 实现提交 | 合入 feature/2.0 |
|---|---|---|
| ServLlama | 189be17 | 1e73abc |
| mnn_engine | 9e10673 | 59d5810 |

上述是 HTTP 取消优化的实现与合入点。随后，独立驻留实现提交 43bb321 经 f8b3e6d 合入，报告提交为 cc1bf92。应用日志从 cc1bf92 创建 feature/2.0-app-logs，完成接入、查询和导出；实现提交 b1d831c 经 d12b0f7 合入，报告提交为 81e5279。

此前从 81e5279 创建 fix/2.0-device-smoke，在已连接真机上验证主要流程。语音修复提交 c35f097 经 c6f5278 以 merge --no-ff 合入 feature/2.0，版本提升到 dev.5+19，报告提交为 63acf00。

网络搜索从 63acf00 创建 feature/2.0-web-search，版本提升到 dev.6+20。实现提交 2ab9554 经 7e05358 以 merge --no-ff 合入 feature/2.0，报告提交为 641ad31。

dev.7 从 641ad31 创建 feature/2.0-chat-identity，增加头像编辑、消息署名与历史兼容，版本提升到 dev.7+21。实现提交 73cf935 经 0948f19 以 merge --no-ff 合入 feature/2.0，没有 push。插件仍为 59d5810，原始 main 工作树的本机配置保留。

dev.8 从 c2adff2 创建 feature/2.0-conversation-assistants，版本提升到 dev.8+22；助手可不指定默认模型，会话分别保存归属和实际目标。实现提交 bfb1ae0 经 d6cbf00 以 merge --no-ff 合入本地 feature/2.0，没有 push；本轮不修改 mnn_engine。

dev.9 从 bb69527 创建 feature/2.0-assistant-deletion，版本提升到 dev.9+23；实现提交 18fa987 经 5712c7c 以 merge --no-ff 合入本地 feature/2.0，未 push。仅修改应用，插件与参考仓库保持原样。

dev.10 从 571b2f0 创建 feature/2.0-chat-tool-activity，版本为 dev.10+24；实现提交 5b14745 经 8b8ae5c 以 merge --no-ff 合入本地 feature/2.0，未 push。仅修改应用，插件仍为 59d5810；设计、实际界面与验收结果随功能提交保存。

dev.11 从 7e22ce9 创建 feature/2.0-message-deletion，版本为 dev.11+25；实现提交 388b4dd 经 39ca913 以 merge --no-ff 合入本地 feature/2.0，未 push。插件仍为 59d5810，参考检出未修改。

dev.12 从 834f17a 创建 feature/2.0-providers，版本为 dev.12+26；实现提交 3ba9825 经 610f58c 以 merge --no-ff 合入本地 feature/2.0，未 push。该轮只改应用，插件保持 59d5810。

本轮从 47ec9e3 创建 feature/2.0-navigation，版本为 dev.13+27；实现提交 748b398 经 75dc1e4 以 merge --no-ff 合入本地 feature/2.0，未 push。仅修改应用，插件仍为 59d5810。Debug APK 对应此实现，后续报告补记不改变应用代码。

## 2. 功能交付与边界

| 能力 | 已实现的闭环 | 主要代码 |
|---|---|---|
| 导航与设置 | 聊天首页；侧栏底部助手选择和助手设置/服务器/模型库/语音/设置五图标；档案置顶与统一设置菜单；语言/语音模型双标签 | [导航设计与界面](NAVIGATION_ZH.md)、[main_scaffold.dart](../../lib/app/main_scaffold.dart)、[model_library_page.dart](../../lib/app/model_library_page.dart) |
| 本地档案 | 昵称、图片/表情头像、称呼、偏好；助手默认不使用资料，按字段授权；只有选中的称呼/偏好进入请求快照 | [assistant.dart](../../lib/features/assistants/models/assistant.dart)、[profile_page.dart](../../lib/features/assistants/pages/profile_page.dart) |
| 助手 | 创建、编辑、复制、删除、切换；头像、可选的新会话默认模型、提示词、生成参数和 Agent 授权；确认后级联删除关联会话/草稿，已转移会话保留；自动修正偏好，最后一个不可删 | [assistants_page.dart](../../lib/features/assistants/pages/assistants_page.dart) |
| 供应商 | 三协议、八个不可删除预设、启用/禁用、自定义供应商、手动/发现勾选模型、安全保存密钥；底部弹窗分组搜索，本地点选加载启动；禁用和模型移除保留历史并撤销当前请求授权 | [chat_protocol_client.dart](../../lib/features/chat/services/chat_protocol_client.dart)、[connections_page.dart](../../lib/features/assistants/pages/connections_page.dart) |
| 聊天 | 一个执行器统一本地与远端；流式文字/推理、图片、停止、用户/助手消息版本及删除本版/全部版本、历史上下文、运行快照与草稿；提交失败不清空草稿 | [chat_runner.dart](../../lib/features/chat/controllers/chat_runner.dart)、[chat_provider.dart](../../lib/features/chat/providers/chat_provider.dart) |
| 会话关系 | 会话绑定助手、独立选模型；历史入口统一恢复，侧栏按助手筛选；明确更换归属保留模型/消息/版本/草稿；失效引用可修复 | [会话关系设计](CONVERSATION_ASSISTANTS_ZH.md) |
| 头像与署名 | 消息头显示用户/实际助手的头像和名称；时间/实际模型在末尾；版本独立署名，旧 Run 补身份，未知作者不套用当前助手，删除后保留生成时名称 | [头像与聊天署名](CHAT_IDENTITY_ZH.md)、[chat_message_list.dart](../../lib/features/chat/widgets/chat_message_list.dart) |
| 基础 Agent | 有界模型—工具—续答循环；时间、询问用户、读取 Skill、网络搜索和远程 MCP；回复内工具卡片、就地审批/回答、拒绝/取消、版本对应记录和停止原因 | [agent_tool_service.dart](../../lib/features/agent/services/agent_tool_service.dart) |
| 网络搜索 | 一个 web_search 工具；每个助手授权并选择 Bing/DuckDuckGo，默认 Bing、无需 key；结果含来源/摘要，工具卡片可打开链接，取消/超时与日志接入已有流程 | [web_search_service.dart](../../lib/features/agent/services/web_search_service.dart)、[使用说明](WEB_SEARCH_ZH.md) |
| Skill | 导入单个 Markdown 或静态 ZIP 包；元数据、不可变版本、按需读取说明/文本资源、助手绑定、删除清理授权；脚本只作不支持提示 | [skill_service.dart](../../lib/features/agent/services/skill_service.dart) |
| MCP | 远程 Streamable HTTP 和旧 SSE；初始化、分页列工具、会话、调用、断线处理；Bearer/自定义头安全保存，逐工具授权，失效或撤销后停止使用 | [mcp_client.dart](../../lib/features/agent/services/mcp_client.dart)、[mcp_servers_page.dart](../../lib/features/agent/pages/mcp_servers_page.dart) |
| 语音模型 | 共用模型索引与下载服务；四个固定配方目录；暂停、继续、重试、离线 ZIP/ZIP64 导入、取消、校验、删除和中断恢复 | [speech_model_service.dart](../../lib/features/speech/services/speech_model_service.dart)、[catalog.json](../../assets/speech/catalog.json) |
| 转录 | 录音/文件导入、Android 解码、规范化、双引擎 ASR、分块进度、部分结果保留、编辑、TXT/SRT 导出和显式重试 | [speech_job_service.dart](../../lib/features/speech/services/speech_job_service.dart)、[audio_io_service.dart](../../lib/features/speech/services/audio_io_service.dart) |
| 合成与音色 | sherpa VITS 和 Crisp Qwen3-TTS；分块合成、播放/暂停/倍速/WAV 导出；Qwen3-TTS Base 参考音色创建、试听、改名、删除、失效模型提示 | [speech_worker.dart](../../lib/features/speech/services/speech_worker.dart)、[voice_profiles_page.dart](../../lib/features/speech/pages/voice_profiles_page.dart) |
| 聊天语音 | 麦克风使用同一转录队列；结果经明确选择追加/替换草稿，草稿已改变时拒绝覆盖；朗读仅使用最终回答，明确启动合成和播放 | [chat_speech_button.dart](../../lib/features/chat/widgets/chat_speech_button.dart) |
| 本地 LLM 服务 | 保留 GGUF/llama-server 与 MNN 插件服务；同一时间一个 LLM 模型驻留，可与一个语音模型同时运行；私用请求不需要对外发布，语音不停止或卸载 LLM | [engine_runtime_provider.dart](../../lib/core/providers/engine_runtime_provider.dart) |
| 应用日志 | 设置与服务中心统一入口；接入客户端、Agent、语音生命周期；分类/级别/关键词组合查询，筛选结果复制与导出，全局容量限制与脱敏 | [AppLogger](../../lib/core/logging/app_logger.dart)、[AppLogsPage](../../lib/features/logs/pages/app_logs_page.dart) |

不在此次边界内：会话工作区/内置文件工具/会话文本导入、账号/云同步、云端语音、语音 HTTP API、云模型 API 转发、Agent HTTP 网关、MCP stdio/OAuth、任意脚本/终端/系统自动化、多 Agent、实时全双工语音与通用 RAG 平台。这里没有以占位页面宣称支持这些功能。

## 3. 最终架构与可靠性

~~~mermaid
flowchart TD
    UI[页面与 Provider] --> Chat[ChatRunner]
    UI --> Speech[SpeechJobService]
    UI --> Models[UnifiedModelRepository]
    Chat --> Protocol[三个协议适配器]
    Chat --> Tools[AgentToolService / Skill / MCP / Search]
    Chat --> LLM[EngineRuntimeProvider]
    Speech --> Worker[一个任务一个 SpeechWorker]
    LLM --> Lease[ResourceCoordinator]
    Speech --> Lease
    Models --> Download[现有 ModelDownloadService]
    Chat --> DB[Repository / 单个 Drift 数据库]
    Tools --> DB
    Speech --> DB
    LLM --> FG[现有前台服务 owner]
    Speech --> FG
~~~

### 3.1 唯一所有者

- ChatRunner 负责当前 Run、模型轮次、工具续答与取消；普通聊天走同一执行路径。
- EngineRuntimeProvider 及原有引擎适配器负责本地 LLM 启停；应用不绕过 mnn_engine 直接调 MNN。
- ResourceCoordinator 分别记录 LLM 与语音的进程内驻留凭据和清理隔离。dev.36 移除系统资源压力标记及准入拦截。SpeechJobService 独自管理语音 FIFO；LLM 发布状态只归 EngineRuntimeProvider，没有第二套调度器。
- SpeechWorker 在独立 isolate 内拥有原生句柄。同步 FFI 退出、句柄清理确认后才释放 lease；取消不等于立即停止原生计算。
- Android 使用缓存业务 FlutterEngine；Activity 相关通道重新绑定。复用 ForegroundTaskService owner，MNN 的服务仍由插件管理。
- 本地/云端聊天、对外 LLM 服务均可与语音并行；语音不依赖聊天或 LLM 的生命周期。

### 3.2 数据、恢复与文件

[AppDatabase](../../lib/core/database/app_database.dart) 是 schema 5，共 15 个逻辑表，使用 Drift 管理显式 SQL 与事务。关系定位字段建列，有限领域配置使用 JSON；没有通用 EAV、完整事件溯源或逐 token 表。简单设置/本地档案在 SharedPreferences，秘密在 Secure Storage。

[LegacyImporter](../../lib/core/database/legacy_importer.dart) 从原 Hive 会话、消息、版本、GGUF 模型记录和语言模型下载任务导入，当前待迁移的业务数据与完成标记同事务提交。dev.14 补齐后，Hive 才完全退出日常业务读写；此前 GGUF 和下载任务仍使用 Hive。GGUF 完整详情进入既有资产行，保留资产 ID，下载任务进入 `download_tasks`。旧文件保留，已完成的迁移不重跑；原 API key 成功写入 Secure Storage、业务事务提交后才清理旧 Preferences。启动页面显示迁移阶段、当前步骤记录数、错误与重试；成功后才创建业务 Provider。详细边界、验证和升级验收见[存储迁移说明](STORAGE_MIGRATION_ZH.md)。

Run 保存不可变配置、消息版本和节流 checkpoint。进程重启将未完成 Run/语音任务标为中断，工具副作用不自动重放。消息提交与会话索引同事务；草稿在用户消息落盘后才清空。原供应商的工具签名/状态只在协议及上下文仍匹配时复用。

图片附件、语音任务、参考音色各有明确所有权；旧工作区登记仅用于升级清理。会话删除先事务处理消息/Run/工具记录，再通过持久删除标记清理自有文件；失败在启动时重试。语音任务使用自己的输入和参考副本，独立语音任务及共享附件不随会话误删。模型包自包含，不引入共享权重引用计数池。

### 3.3 授权与外部副作用

工具批准通过持久状态的比较更新执行，连点批准只消费一次。内置文件工具及其覆盖哈希审批已移除。远端 MCP 调用按可能有副作用处理，断流/取消无法证明结果时记录 unknownOutcome，不自动重试。

助手、连接、Skill、MCP 当前授权在执行前复核；撤销会中止旧 Run，普通名称/提示词编辑留到下一 Run。连接地址、协议、密钥域变化也会停止旧请求。凭据使用独立 secret reference，保存失败清理新凭据，不破坏旧配置。

静态包统一使用有界 ZIP 读取；先限制目录元数据，再解压，拒绝越界路径、链接、重复/大小写冲突和超出实际输出上限的条目。大工具结果在 16 KiB UTF-8 内保存带截断提示的片段，卡片说明仅可查看/导出已保存的回执。日志和错误展示统一脱敏，但实际第三方响应仍需在联调时检查。

历史回答默认“重新表述”，只读已有工具回执；明确“重新执行任务”创建新 Run 并重新审批。未知结果需要先核对外部状态。

### 3.4 按最小必要原则做出的取舍

1. 保留 Provider、现有模型索引、下载器、引擎和通知所有者；没有同时替换 UI 状态框架。
2. Skill、MCP 与工具回执集中在 agent 功能内；供应商与助手配置在 assistants 内，不为每个名词加转发层。
3. Crisp 使用现有 Dart FFI 包加应用内 native/speech 构建层，不再制造一个只为打包而存在的 Flutter 插件。
4. 每个语音任务创建/释放 worker 和模型，减少常驻状态。代价是连续任务需要重新加载模型，耗时须在真机测量。
5. 一个 Run 使用一个有界总时限，包含审批等待；没有另造独立 30 分钟审批计时器。
6. 图片头像规范化为 128×128 的有界 PNG，直接随档案/助手 JSON 保存；消息只记录助手 ID/名称，不增加头像文件仓库、回收器或云同步链路。

### 3.5 HTTP 取消与原生资源释放

聊天对本地 MNN、llama-server 和云端统一取消 HTTP，不再发送私有请求头或经 MethodChannel 取消/轮询特定请求。MNN 只在服务内部匹配请求归属；SSE 心跳覆盖首 token 前与工具缓冲，断开被发现后停止对应推理，并等待 JNI 返回再释放准入。一个请求在执行，其他请求仍返回 429，没有增加等待队列。

运行时区分服务是否可用与是否仍有原生资源。MNN stopServer 确认请求退出后才 unloadModel；llama.cpp 保留进程引用直到实际退出。停止超时/卸载失败保留 LLM lease 和重试停止入口，只阻止下一次 LLM 加载或换模。对外服务的固定占用也不会因一个错误状态被提前撤销。

取消启动或换模也会等待原编排流程结束，设置读取与引擎准备完成后复核取消状态。等待期间不能启动另一个 LLM，语音仍可运行，避免旧启动任务迟到并重置取消标志。

TCP 半关闭不等于取消，云端停止计算/计费由供应商决定；非流式响应也不通过提前写入 200 或心跳改变语义。这些边界和真实 TCP 测试详见[取消设计](CANCELLATION_DESIGN_ZH.md)。

### 3.6 LLM 与语音并行

按用户确认，撤销全局单模型驻留限制。保留同一个 ResourceCoordinator，将 LLM 和语音的 lease 分开；ASR/TTS 仍由现有 FIFO 串行执行。SpeechJobService 只接收资源协调器，不引用 ChatProvider 或 EngineRuntimeProvider，删除停止聊天/LLM 后启动语音的代码和界面入口。

两侧可独立启动、运行和取消。LLM 停服失败不阻止语音，语音清理无法确认只隔离语音侧；迟到的取消或释放不能影响其他所有者。dev.36 起不再按系统内存/温度压力阻止新的模型加载，也不按“另一个模型已驻留”拒绝运行。并行时的峰值内存、首 token 延迟与语音 RTF 列入真机验收，当前不增加自动卸载、优先级抢占或内存预测调度。

### 3.7 全应用日志

复用 AppLogger / FileLogSink，日志查询与 UI 迁入 features/logs。新增 client、agent、speech 分类，分别覆盖聊天 Run 与 HTTP 请求、工具/Skill/MCP/网络搜索，以及模型包/语音任务/音频 I/O/参考音色。记录稳定 ID、状态、阶段、数量、状态码和耗时；不保存新增功能的提示词、回复、工具载荷、转录或音频内容。

全应用合计缓存最近 2000 条，保留原有轮转文件格式；不增加日志表或第二套诊断框架。页面按分类、最低级别和关键词查询，复制与导出使用同一筛选结果，清空作用于所有分类。取消申请与原生资源释放分别记录，不能从任务 cancelled 推断模型已经卸载。详细范围和限制见[应用日志设计](APPLICATION_LOGGING_ZH.md)。

### 3.8 网络搜索

网络搜索集中在 agent 功能内，配置保存在助手现有 JSON；没有新增数据表、全局供应商注册表或独立执行器。仅助手授权后向模型提供 web_search，Bing/DuckDuckGo 均使用公开 HTML 搜索；返回有界的标题、来源和摘要，供模型续答和用户核对。

每次 Run 固定供应商与结果上限。撤销授权或改供应商会停止受影响的旧 Run；搜索自身超时只生成失败回执，不取消整个聊天。成功回执可以复用，失败/中断不自动重放。搜索内容作为不可信数据处理，不自动读取来源网页，也不自动换供应商。日志只记录元数据，详见[网络搜索说明](WEB_SEARCH_ZH.md)。

### 3.9 头像与消息署名

设置、助手列表、聊天选择器及消息区共用 IdentityAvatar，图片值变化时才解析图片；编辑页共用 AvatarEditor 和图片规范化服务。保存前只修改草稿，取消不会写入配置，图片处理期间禁用保存。沿用现有 file_picker、dart:ui 和存储，没有新增依赖或数据表。

ChatRunner 从本次 Run 冻结配置记录 MessageAuthor，消息及不可变版本只保存助手 ID/名称。显示按该 ID 查找当前配置，切换助手不影响其他作者；删除后使用保存名称和首字头像。重生成、人工编辑、版本切换、错误与中断恢复均保留对应署名；旧 2.0 Run 可以补身份，1.x 无身份消息显示通用“助手”。头像不进入 Run/checkpoint，昵称/头像不增加模型提示词或附件。界面与详细边界见[头像设计](CHAT_IDENTITY_ZH.md)。

### 3.10 会话、助手与模型选择

Assistant.defaultTarget 只初始化新会话。ChatSessionRecord 保存 assistantId/target，由 ChatSessionRepository 沿用 conversations.config 一次提交；AssistantProvider 不再旁路改写或恢复会话，activeId 仅是新草稿偏好。ChatProvider 统一历史选择、切模型、更换归属与草稿隔离，并将配置和消息写入纳入同一操作锁，避免迟到旧记录覆盖新选择。

新 Run 使用会话当前目标及绑定助手的最新行为配置；消息/版本仍保留实际作者与模型。侧栏切助手进入新草稿，明确更换会话助手才改变原归属。旧数据通过幂等事务补齐，缺失引用要求显式修复。聊天不会把其他驻留模型误标为当前已加载模型，也不会从启动按钮误停另一已发布模型。没有新表、执行器、模型注册表或插件 API。详见[设计和验收](CONVERSATION_ASSISTANTS_ZH.md)。

删除助手会一并删除其当前关联会话，失效的默认偏好自动切到剩余助手；已转移会话和升级前遗留的缺失助手会话继续保留。转录投递也使用统一草稿目标：按助手区分新草稿，明确选择、确认时复查存在性和替换冲突，不向另一个助手的当前输入自动回填。冷启动先读取已保存会话，再选择最近模型或本地运行时默认值。

### 3.11 删除助手与关联会话

确认框明确提示关联会话、消息和草稿会一并删除且不可撤销，取消不产生变更。删除入口统一为 ChatProvider.deleteAssistant，复用会话操作锁；ChatSessionRepository 复用原会话清理逻辑，在同一事务处理助手、会话、消息/版本、Run/工具记录和持久草稿。文件在提交后按所有权与引用清理，失败留待启动重试。删除仅依据会话当前 assistantId，已转移的会话不受旧作者删除影响。独立语音结果、音色、模型及连接不随助手删除。

状态同步移除消息缓存、文字与图片草稿，排空旧保存后暂停防抖写入，防止已删内容恢复。失效偏好自动修正，当前被删会话回到有效助手草稿；最后一个助手仍不可删除。没有新增表、管理器、调度器或插件 API，也不在升级时清空旧的孤立会话。

### 3.12 消息版本删除与工作区移除

用户和助手消息均可切换版本。删除本版保留相邻版本，删除全部或最后版本移除整条消息，后续消息保留。消息头、版本、会话索引、失去引用的 Run/工具回执及附件删除标记同事务提交，文件仅在提交后按所有权与实际引用清理。确认绑定原消息快照，生成/审批时禁用删除。取消空草稿和重启恢复也清理无主 Run，checkpoint 不复活已删消息。

工作区页面、会话文本导入、三个文件工具及助手旧权限已移除；只保留已登记旧文件的安全清理。静态 Skill 包内资源、远程 MCP、图片和语音各自保留。成功/失败的大工具结果统一截断并标记，用户可导出已存回执。没有新表、执行器、依赖或文件兼容层。详细规则与升级处理见[删除设计](MESSAGE_DELETION_ZH.md)。

### 3.13 供应商与统一模型选择

供应商沿用 AiConnection/ai_connections，新增 enabled 并将已保存模型清单作为远端选择和请求授权依据。八个固定预设默认禁用且无模型，可编辑、不可删除；自定义供应商继续可增删。升级以事务补缺失预设和旧目标用过的模型，仅迁移一次，不让用户已移除的模型在重启后复活。保存检查 revision，避免并发旧草稿覆盖；模型发现只提供候选，使用当前草稿凭据，可搜索勾选和取消。

聊天模型按钮改为底部弹窗，按供应商显示模型，支持名称/模型搜索；禁用项仍显示状态但不可选。llama.cpp/MNN 直接展示现有资产和运行时状态，选择与加载放在同一会话操作锁中，失败在弹窗内提示并可重试；不同已发布模型受保护，云端选择不停止本地服务。助手默认模型复用同一弹窗，只保存默认值。没有第二个供应商 SDK、模型目录、运行时或插件 API。详见[设计与验收](PROVIDERS_ZH.md)。

### 3.14 侧栏导航与模型库

移除 PlatformShell 和五页 IndexedStack，MainScaffold 直接作为聊天首页。侧栏底部提供助手选择与五个功能图标；原有功能页通过 Navigator 打开，手机模式先关闭侧栏，返回保留原会话、模型和输入草稿。设置页用户档案置顶，直接提供通用、聊天、服务诊断、下载、关于和 Debug 开发工具分组。

ModelLibraryPage 组合现有语言/语音模型页面，语音入口默认打开语音标签；语言模型搜索与筛选在切换时保留，隐藏页不保留输入焦点。下载、引擎和语音任务仍使用应用级所有者；SpeechJobService 主动初始化恢复记录，不依赖隐藏页，不自动重放中断任务。未新增数据库表或导航状态框架。细节、组件渲染与验收见[导航设计](NAVIGATION_ZH.md)。

## 4. 已落实的运行上限

| 项目 | 当前行为 |
|---|---|
| Agent 默认预算 | 最多 8 个模型回合、16 次工具调用、2048 输出 token、24000 上下文字符、180 秒总时限；最后一回合保留给无工具回答 |
| Token 统计 | 优先使用供应商 usage；无 usage 时按文字/参数长度估算，不能当作精确计费或 tokenizer 上限 |
| 审批 | 计入同一个 Run 总时限；超时后旧批准无效 |
| 工具结果 | 单次结果文本最多 16 KiB UTF-8（包含截断提示）；超限只保存完整字符边界内的片段，不生成工作区文件 |
| Skill | 包/实际展开总量 10 MiB，最多 128 个条目；SKILL.md 长度有界 |
| 模型发现 | 接收超时 30 秒，最多 32 页/5000 个去重候选；Anthropic/Gemini 跟随协议分页，缺失或循环游标失败；模型 ID 最长 512 字符 |
| 网络搜索 | 查询最多 512 个 UTF-16 单元；默认 5 条、最多 10 条且受助手上限约束；20 秒、2 MiB HTML、最多 3 次供应商域内 HTTPS 跳转，结果项 JSON 合计最多 12 KiB |
| 头像 | 输入最多 10 MiB、单边 8192 像素、3200 万像素；解码后居中裁剪 128×128 PNG，结果最多 72 KiB；不保留删除助手的头像历史 |
| 语音队列 | 最多 8 个活动任务，FIFO；重启后不自动续跑 |
| 音频输入 | 文件最多 512 MiB；解码音频最多 3 小时；录音最多 10 分钟，退后台/失焦停止录音 |
| ASR | 25 秒分块；sherpa Whisper 只有块级近似时间，提供 TXT；Crisp Whisper 原生分段时间支持 SRT |
| TTS | 输入最多 4000 个 UTF-16 单元；分块不拆代理对；WAV 输出最多 64 MiB |
| 参考音色 | 3–30 秒，标准化 24 kHz 单声道；绑定模型资产 ID/revision，填写参考转录及使用权确认 |
| 模型包 | 最多 256 个文件、12 GiB 资源；全部依赖、大小、哈希校验完成后可运行 |
| 驻留范围 | LLM 和语音各一个 lease，可同时使用；ASR/TTS 共用 FIFO，任务结束后释放语音模型 |
| 应用日志 | 全应用与页面各最多 2000 条；单条最多 8192 个 UTF-16 单元加省略号；约 1 MiB 阈值、三个轮转文件；查询/导出针对缓存 |
| 资源准入 | dev.36 移除 Android thermal/trim 启动拦截；仍保留同侧驻留互斥及清理未确认的隔离 |

thermal/trim 不会拦截已经发布的原生 LLM HTTP 服务的每个外部请求，也没有承诺自动避免 Android LMK。

## 5. 原生和模型交付

语音依赖固定为 sherpa_onnx 1.13.8、crispasr 0.8.37。Crisp 原生固定来源：

| 内容 | revision / 配置 |
|---|---|
| CrispASR | 2165cb64633cc8fed8e04c6002332809860b245e |
| ggml | 2f5a80d258c46e6ac8eee95f1328c0f58376d7ee |
| c2pa-audio | e40329b83f16f67bb5ddc7bb13ae18de0a9376fc |
| 构建 | NDK 27.0.12077973、CMake 3.22.1、arm64-v8a、API 28、静态 libc++/ggml、OpenMP 关闭、C2PA 开启 |
| 动态库 | libservllama_crispasr.so；19,012,248 字节；SHA-256 e035c0753023f8e7e053320fb68dc2da3b055f56e92f3b0b100fafe84ef61d0b |

[build_speech_native.ps1](../../tool/build_speech_native.ps1) 构建并产生 [原生清单](../../native/speech/android-arm64-v8a.json)。Gradle 打包前验证库哈希；符号版本脚本只导出 crispasr_*，避免与 llama.cpp 的 ggml 混用。Crisp 默认音频标记/C2PA 保留，未增加关闭绕过。相关源码许可与 LLVM NOTICE 注册到应用许可证页。

llama.cpp 继续使用 v0.4.1 Snapdragon 预编译包与原补丁，MNN 仍钉住插件文档中的 3.6.1 commit。应用和插件的 .so、模型权重、native-cache、编译目录均不提交。

内置四个下载配方：sherpa Whisper tiny、sherpa AISHELL3 VITS、Crisp Whisper base、Crisp Qwen3-TTS 0.6B Base。下载元数据和 SHA 已固定。此前两个 sherpa 模型已在真机下载、校验并执行短音频任务；Crisp Whisper 下载传输失败，Qwen3-TTS 大模型及克隆未测。语音下载现复用全局 HF 自动/官网/镜像线路，每次继续/重试重新读取设置，不改变固定模型元数据。离线打包、自定义同架构模型、默认音色和许可状态见[模型包说明](SPEECH_MODEL_PACKAGES_ZH.md)。特别是转换后的 sherpa Whisper/VITS 许可尚需核对，不能以引擎许可替代模型许可。

## 6. 已运行验证

| 检查 | 结果 | 本机证据 |
|---|---|---|
| 应用 Flutter analyze（本轮） | 无问题 | .dart_tool/navigation-20260927/analyze.log |
| 应用 Flutter test（本轮） | 全量 655 项通过；新增 6 项导航交互；原会话、供应商、工具和语音回归通过 | .dart_tool/navigation-20260927/tests.log |
| 最终 UI 回归 | 最后补齐设置值对齐和滑动标签焦点释放后，导航/设置/日志 26 项通过；另有 1 项离屏渲染检查，未计入 655 项 | .dart_tool/navigation-20260927/final-ui-tests.log |
| 应用定点回归（dev.5 真机修复） | 当时语音与下载 83 项通过 | .dart_tool/device-smoke-20260927/regression-tests.log |
| 插件 Flutter analyze / test | 上一轮无问题、16 项通过；本轮插件未改动，未重跑 | 插件 .dart_tool/http-cancellation-analyze.log、http-cancellation-tests.log |
| 插件 Kotlin/JVM | 上一轮编译通过；90 项、0 失败/错误/跳过；本轮未重跑 | 应用 .dart_tool/http-cancellation-jvm-all.log；build/mnn_engine/test-results/testDebugUnitTest |
| 离线模型包工具 | 沿用已有的 3 项 Python 测试通过记录；工具未改动 | python -m unittest discover -s tool -p test_package_speech_model.py -v |
| Android Debug（本轮） | Flutter 入口构建成功，版本 2.0.0-dev.13+27；设备未连接，未安装 | .dart_tool/navigation-20260927/build-debug.log |
| Android Release（日志阶段基线） | 上一轮 2.0.0-dev.4+18 构建通过；本轮未重建 Release | .dart_tool/app-logs-build-release.log |
| 最终 Debug 原生审查（本轮） | arm64、ELF 对齐、Crisp 哈希及 HTP DSP 库检查通过；manifest、签名及 ZIP 对齐通过 | .dart_tool/navigation-20260927/apk-audit.json、apk-manifest.log、apk-signature.log、apk-zipalign.log |
| 设计与文档 | 导航设计、组件界面、实现报告与验收更新；工作区 1.8 方案同步新入口，1.3 网页原型保留为历史 | [导航设计](NAVIGATION_ZH.md)；.dart_tool/navigation-20260927/docs-check.json |
| dev.13 真机冒烟 | 未执行：ADB 设备列表为空；待补返回手势、输入法、任务持续和升级冷启动 | .dart_tool/navigation-20260927/devices.log |
| dev.12 真机冒烟 | 未执行：ADB 设备列表为空；待补预设/模型维护/选择启动/冷启动验证 | .dart_tool/providers-20260927/devices.log |
| dev.11 真机冒烟 | 未执行：ADB 设备列表为空；待补最小版本删除/汇总/冷启动验证 | .dart_tool/message-deletion-20260927/devices.log |
| 聊天内工具真机冒烟（dev.10 历史） | 就地回答/审批、三工具完成与续答、展开结果、空正文取消、冷启动历史加载通过；原业务数据、草稿及偏好保留 | [实际范围与界面](CHAT_TOOL_ACTIVITY_ZH.md#dev10-真机冒烟)；.dart_tool/chat-tool-activity-20260927/device-report.json、after-cleanup-report.json、cleanup-resources.json |
| 删除助手真机冒烟（dev.9） | 确认提示、取消、两个空会话和三个草稿目标的级联删除、自动回到原助手、冷启动及日志通过；测试数据已清理 | .dart_tool/assistant-deletion-20260927/device-report.json、after-restart-report.json |
| 会话关系真机冒烟（dev.8） | A/M1、A/M2、B/M1 的历史恢复、独立默认、明确更换归属、旧版本署名、失效助手修复、连接删除引用、冷启动与草稿保留通过 | [会话设计/验收](CONVERSATION_ASSISTANTS_ZH.md)及 .dart_tool/conversation-assistants-20260927/ |
| 头像真机冒烟（dev.7） | 用户/助手图片与表情保存、混合助手版本署名、冷启动保留、删除作者回退、请求/日志隔离通过 | [头像设计/验收](CHAT_IDENTITY_ZH.md)及 .dart_tool/chat-identity-20260927/ |
| 网络搜索真机冒烟（dev.6） | Bing 返回 3 条真实来源并完成工具续答，来源链接可打开；DuckDuckGo 直连超时且正确显示失败，聊天正常结束；日志页可查 | [网络搜索说明](WEB_SEARCH_ZH.md)及 .dart_tool/web-search-20260927/ |
| 当天真实网页解析（dev.6） | 抓取的 Bing/DDG 页面通过应用解析，各返回 5 条；不等同于 DDG 直连成功 | .dart_tool/web-search-20260927/captured-parsing.log |
| 真机主流程（dev.5） | Redmi K50 Ultra / Android 12 / 4 KiB：升级、本地 LLM、客户端/Agent/MCP 测试服务、sherpa 语音及日志主流程通过；本轮未重复整套硬件测试 | [真机冒烟报告](DEVICE_SMOKE_2026-09-27_ZH.md)及 .dart_tool/device-smoke-20260927/ |

自动化覆盖包括数据库事务/恢复、私用端点和 lease、三类流式协议、工具审批/撤销/重放边界、MCP 会话、ZIP 解压边界、模型校验/取消、语音 FIFO 与部分结果、WAV 时长/重采样、聊天草稿、会话/音色删除，以及 360 dp/暗色/大字体的关键 UI。

dev.10 真机通过时间、提问、写文件和模型续答链路；直接在回复内回答、允许写入和展开参数/结果，无需跳转汇总页。审批前停止时，空正文的助手回复和其工具版本保留；冷启动后已完成/已取消卡片均可查看，历史没有可用审批按钮，消息、版本、Run、回执逐行不变。61 条对应 Run 的诊断事件没有测试问题、回答、文件路径或正文，冷启动进程日志未见崩溃标记。模型响应由临时 HTTP 服务提供，该轮不重复真实搜索、生产 MCP、原生模型或系统导出目的地操作；其余展示状态和版本隔离由自动化覆盖。

USB 重连曾导致端口映射丢失，两次早期尝试连接拒绝；恢复后完整流程通过，失败中的既有回执也保留。服务共收到 7 次请求（早期尝试 2 次、完整链路 4 次、取消流程 1 次），冷启动查看历史没有新增请求。通过应用删除测试助手后，3 会话、8 消息、4 版本、4 Run、6 条工具回执及登记文件已清理；测试脚本仅额外移除一个空目录。临时连接、服务及 tcp:18891 映射已清理。原有 19 会话、42 消息、15 版本、2 助手、5 模型、2 语音任务、2 Run、1 条工具回执及其他业务行、全部草稿、偏好和元数据逐项一致。完整证据与截图见[工具过程设计](CHAT_TOOL_ACTIVITY_ZH.md#dev10-真机冒烟)。

dev.9 真机仅使用新建助手、两个空会话和三个草稿目标验证删除流程，原有 19 会话、38 消息、13 版本、2 助手、5 模型、2 语音任务及其他业务行逐行一致，原 Preferences 与草稿值保留。返回原助手时仅多一个空草稿键，其余元数据一致。日志记录删除数量 2 且不含测试正文，冷启动未见崩溃标记。消息/版本/附件、已转移会话、事务失败、最后一个助手和生成中删除由自动化验证；该轮不重复模型推理或 MCP 真机调用。详见[删除验证及界面](CONVERSATION_ASSISTANTS_ZH.md#dev9-删除助手验证)。

此前独立驻留回归覆盖 LLM 与语音双向并行启动、各自取消及停止、同侧清理隔离、旧 lease 无法影响后续任务、系统压力只限制新加载，以及语音等待界面。日志阶段新增容量、脱敏、文件恢复、组合查询、复制/导出一致性、窄屏大字体/键盘测试，并扩展三协议 HTTP 取消/状态码、工具审批/Skill/MCP、语音失败/取消/清理等回归，当时全量 522 项通过；dev.5 语音修复后定点 83 项通过；dev.6 搜索版全量 541 项通过。dev.7 全量 560 项通过。dev.8 全量 581 项通过。dev.9 全量 590 项通过。dev.10 全量 602 项通过。dev.11 全量 625 项通过：移除已退役文件工具的专用用例，审批/撤销改用提问和真实 HTTP MCP 测试端，新增版本删除/事务/迁移/恢复回归与 UI 检查。dev.12 全量 649 项通过；新增长期预设身份、模型列表迁移/保存、HTTP 分页和取消、禁用/移除撤权、本地选择启动及底部弹窗 UI 验证。本轮 dev.13 全量 655 项通过，导航覆盖五入口往返、会话/模型/草稿保留、助手使用返回、档案保存、设置菜单、模型双标签与活动语音任务；含窄屏、大字体、键盘和嵌入侧栏。

dev.6 搜索回归覆盖两家解析与来源还原、广告/去重、参数编码、授权与快照、持久回执、取消/超时、响应容量、日志正文隔离，以及供应商设置和来源卡片布局。手机使用临时模型服务触发真实搜索，不替代真实云模型能力验收。该轮测试后两条会话、临时助手和连接已删除，当时基线的 18 会话、38 消息、13 版本、5 模型资产及其他业务行逐项保持一致，原有 Preferences 值未变化，临时服务与端口映射已移除。

dev.7 头像新增 19 项回归，覆盖规范化与输入限制、编辑草稿、助手复制/删除、生成/错误署名、版本与人工编辑、旧 Run 身份恢复、checkpoint 和窄屏大字体。Redmi K50 Ultra 覆盖安装 dev.7 后，用户/助手图片经实际文件选择器保存成功，表情和历史版本显示正确；切换助手后旧消息不串作者，冷启动保留头像及选择的版本，删除作者后按保存名称回退。两次实际 HTTP 请求不含显示身份，Run/checkpoint 无头像，应用日志无测试身份正文。用于驱动聊天的是临时模型服务；USB 重连曾导致 adb reverse 丢失、首次请求失败，恢复映射后生成成功。

dev.7 头像测试已删除当轮会话、两个助手、连接和四个测试图片文件，恢复原用户档案及当前助手，停止临时服务并移除 tcp:18890 映射。该轮开始前的 19 会话、38 消息、13 版本、1 助手、5 模型资产、2 个已完成语音任务及其他业务行逐项一致；所有原 Preferences 和数据库元数据（含草稿）保持一致。证据见 .dart_tool/chat-identity-20260927/device-identity-report.json、cleanup-report.json 和[实际界面](CHAT_IDENTITY_ZH.md)。

dev.8 会话关系测试使用两个助手和两个测试模型，三个会话经过切换、归属更换和缺失助手修复，共 5 次 HTTP 请求成功；助手提示词标记、实际模型及保存版本均对应正确。删除连接前正确提示 3 个会话引用。冷启动恢复助手、模型、版本和文字草稿。语音跨助手回填、旧草稿键、确认时删除目标与替换冲突由自动化覆盖，本轮未重新进行原生语音推理。

dev.8 测试的 3 会话、2 助手和 1 连接已清理，原助手偏好已恢复，临时模型服务停止且 tcp:18891 映射已移除。原 19 会话只发生预期的 config 补齐迁移，其他列未变；原 38 消息、13 版本、1 助手、5 模型、2 语音任务、其他业务行、草稿及 Preferences 逐项保留。报告位于 .dart_tool/conversation-assistants-20260927/device-conversation-report.json 和 cleanup-report.json，未输出原消息正文。

前次真机发现录音在约 192–222 ms 后被自身的重复音频焦点申请中断。修复由现有 AudioSession 统一管理焦点后，完成 21.106 秒录音、手动停止/播放及退后台自动停止。HF 线路修复后两个 sherpa 模型下载、校验、执行完成；MNN 驻留期间语音没有停止 LLM。ASR 数字样例存在识别偏差，测试只判定任务链路通过。真实云供应商、生产 MCP、Crisp 与性能压力均未以测试服务或编译结果替代验收。

上一轮 HTTP 取消回归覆盖首响应前/流式取消、MNN 实际 CIO TCP 重置与合法半关闭、SSE 工具缓冲心跳、原生退出等待和停服超时重试，以及启动/换模取消、驻留资源保留和停止重试入口。JVM 测试用同步阻塞替身代替 JNI，不代表真实 MNN 批次取消时延已验证。

本机工具链为 Flutter 3.35.2、Dart 3.9.0、JDK 17、Gradle 8.12、AGP 8.9.1。Windows JDK 管道临时目录和本地 Gradle ZIP 的处理写入[验收指南](ACCEPTANCE_GUIDE_ZH.md)；这些路径不进入发布配置。最终 APK 的 aapt、apksigner、zipalign 校验通过；Crisp 的动态依赖只有 libdl/libmediandk/libm/libc，311 个导出项均为 crispasr_* 或符号版本节点。

已处理直接 Gradle 构建沿用旧版本号、增量构建复用旧 Flutter 资源的问题。日志阶段分别强制执行 compileFlutterBuildDebug/Release，再从 Flutter 入口打包，并核对包内许可证和模型目录；记录为 .dart_tool/app-logs-forced-debug.log、app-logs-forced-release.log。dev.8–12 和本轮 dev.13 均先强制重新编译 Debug，再由 Flutter 打包；当前记录为 .dart_tool/navigation-20260927/forced-debug.log 和 build-debug.log。临时本机 Gradle Wrapper 配置已恢复。

| 本机产物 | 字节 | SHA-256 |
|---|---:|---|
| build/app/outputs/flutter-apk/app-debug.apk（本轮 dev.13+27） | 121,718,190 | 985bae60ef35e1cbfb03f75abbe21d3844c9cafe3df3f76b66b3f52a883cc29c |
| build/app/outputs/flutter-apk/app-release.apk（旧 dev.4+18） | 52,989,893 | 9ddd97f0784d87c4619362b68646611dc091a9e70e95e0f1f20bc52082180782 |

两包均为 com.arkanefans.servllama，minSdk 28 / targetSdk 35 / compileSdk 36。Release 未设置 debuggable，但使用本机 Android Debug 签名，证书 SHA-256 为 99c212c1ab3bc814d227d5e60a273c3542d28af5795ad65d0281019d6c5ed1f9；正式分发需换正式签名。原生文件对齐通过不等于 16 KiB 真机推理已验证。本机日志和 APK 在忽略的构建目录内，不进入提交；可按指南重新生成。

日志阶段的成品元数据、签名与 ZIP 对齐记录在 .dart_tool/app-logs-apk-debug-checks.log、app-logs-apk-release-checks.log，大小、SHA 与资源比对在 .dart_tool/app-logs-final-artifacts.json；这些记录对应旧 dev.4。当前 dev.13 Debug 的 SHA 与成品审查在 .dart_tool/navigation-20260927/；dev.8–12 证据保留在原目录。dev.11–13 设备未连接，没有新增设备验证记录。旧 Release 不含 dev.5 语音修复以及后续搜索、头像、会话关系、消息管理、供应商和本轮导航调整。

[flutter-v2-checks.yml](../../.github/workflows/flutter-v2-checks.yml) 提供手动 CI：本地化生成一致性、应用分析/测试/覆盖率、Python 打包器与插件 Dart 检查。由于未 push、插件 0.2.0 尚未发布，GitHub 上没有执行记录；运行需提供已存在于远端的插件 ref。此工作流不下载权重、不构建 native、不声称覆盖真机。

## 7. 待验收与发布条件

此前已完成单设备主流程冒烟：实际 1.2.1+13 覆盖升级、两种本地 LLM 聊天与取消、GGUF 发布 HTTP、sherpa ASR/TTS、语音与 MNN 驻留独立、应用日志查询；完整范围见真机报告。dev.6 完成 Bing 搜索与 DuckDuckGo 超时处理，dev.7 完成头像/消息署名冒烟；dev.8–9 的会话关系及删除结果见[会话设计](CONVERSATION_ASSISTANTS_ZH.md)，dev.10 结果见[消息内工具过程](CHAT_TOOL_ACTIVITY_ZH.md)；dev.11 自动化和未执行的设备冒烟见[消息删除](MESSAGE_DELETION_ZH.md)；dev.12 的供应商验证与边界见[供应商设计](PROVIDERS_ZH.md)，本轮 dev.13 的导航与界面检查见[导航设计](NAVIGATION_ZH.md)。以下仍保留在后续验收阶段：

- 两种 LLM 与语音配方的中文/英文效果、长音频、参考音色质量、C2PA 产物及完整取消时延矩阵；Crisp Whisper 下载传输失败，两个 Crisp 配方的原生推理仍未测试。
- 冷/热启动时间、峰值 PSS、RTF、长任务温升、低内存与 DSP/CPU 后端表现；特别是 LLM 与 Qwen3-TTS 并行时的手机内存预算，并比较独立/并行的 TTFT、RTF 与峰值 PSS。
- 语音取消、隔离、来电/耳机焦点事件和长时日志负载；此前已见 sherpa 正常执行/清理、录音及后台停止日志，未覆盖全部故障场景。ASR/TTS 原生控制台原文仍不在接入范围内。
- Android 12–16、4 KiB/16 KiB 真机、Activity 重建、锁屏/后台、音频焦点、蓝牙/耳机/来电、通知拒绝及进程被杀。
- 新侧栏五入口、系统返回/输入法、模型双标签和任务持续的真机冒烟；组件渲染不替代设备验证。
- 预设供应商启用、模型手动/发现添加、底部弹窗选择、实际本地启动和升级迁移的真机冒烟；当前只有自动化和成品验证。
- 实际云服务的鉴权/模型能力/usage/限流、代理兼容性，以及实际 MCP 服务的分页、会话过期、拒绝和未知副作用。
- DuckDuckGo 在可达网络下的真机成功搜索、两家公开页面的地区差异/限流/验证，以及真实模型使用搜索结果的质量。dev.6 验证时电脑与手机的 DuckDuckGo 直连均超时，未将该项标为成功；本轮未重复外网搜索。
- 精确的同签名 1.2.2 → 2.0 升级、完整鉴权/LAN HTTP 矩阵及长时间后台服务；此前主流程冒烟的原机版本为 1.2.1+13，HTTP 使用原无 key 的 localhost:8083 配置。
- 正式签名、mnn_engine 发布/依赖锁定、模型分发许可、targetSdk 35 与 specialUse 前台服务的目标分发渠道审核。

此前全量构建出现过 Kotlin metadata 和依赖的旧 Java source target 告警；后续升级工具链时需评估，不通过关闭 R8 或全局保留所有类掩盖。清理无法确认的原生任务不会假装释放资源，UI 可能保持取消/隔离直到重启，这是有意保护状态一致性。

验收按[指南](ACCEPTANCE_GUIDE_ZH.md)逐项记录实际结果。满足设备、模型、签名和分发条件后，再决定正式 2.0 版本号与发布，不把此 dev 构建当作已认证稳定版。


## 模型发现与导入入口收敛（2026-09-28）

本次交付统一 GGUF/MNN 本地导入、隐藏语音 ZIP 页面入口、四个语音预设发现与筛选、语言/语音下载管理及安装后用途跳转。复用现有模型目录和语音服务，无数据库或插件改动。静态分析无问题，全量 657 项测试通过。未新构建 APK、下载权重或执行真机验证。设计、范围和设备验收见 [模型发现设计](MODEL_DISCOVERY_ZH.md)。


## 2026-09-29 UI 真机补充

模型获取主流程 UI 已在 Redmi K50 Ultra / Android 12 检查，发现并修复取消反馈、空态文案、分隔符和跨标签输入焦点问题。修复回归 17 项通过，修复包已覆盖安装；2026-09-29 解锁后四项修复最终复验全部通过，本次 UI 冒烟范围已完成。未执行实际模型下载、导入或推理。详见 [真机 UI 报告](DEVICE_UI_SMOKE_2026-09-29_ZH.md)。
