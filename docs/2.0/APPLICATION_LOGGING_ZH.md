# 应用日志设计与使用说明

适用版本：ServLlama 2.0.0-dev.6+20；日志平台自 dev.4+18 接入，dev.6 增加网络搜索事件。日志页由服务日志扩展为全应用诊断入口，客户端、Agent、语音与原有引擎/服务日志共用存储、查询和导出。ASR/TTS 仍只在应用内使用；这些日志功能没有修改 mnn_engine 或推理 HTTP 协议。

## 1. 功能边界

设置 → 应用日志，以及服务中心原有日志菜单，进入同一个页面。日志记录与页面是否打开无关。

- 按分类、最低级别、关键词组合查询；关键词忽略大小写，匹配完整显示行，可搜索日期或任务 ID。
- 显示本地日期、毫秒时间、级别、分类与事件；计数表示“匹配条数 / 当前缓存条数”。
- 复制、导出使用当前筛选结果；无匹配时禁用。清空操作始终清除全部分类的缓存和轮转文件。
- 保留连续文本选择、自动跟随新日志、手动查看历史时停止跟随。窄屏、大字体或键盘占用空间时，筛选区可以滚动。
- 这是有容量上限的诊断记录，不是业务历史、审计账本或全量崩溃采集系统。会话、工具回执、语音结果仍以各自 Repository 为准。

## 2. 结构与职责

~~~mermaid
flowchart LR
    Client[ChatRunner / ChatProtocolClient / 助手配置] --> Logger[AppLogger]
    Agent[AgentToolService / SkillService / McpClient / WebSearchService] --> Logger
    Speech[SpeechJobService / SpeechModelService / AudioIoService] --> Logger
    Existing[原有应用 / 引擎 / 服务 / 模型 / 下载日志] --> Logger
    Worker[SpeechWorker 阶段通知] --> Speech
    Logger --> Buffer[全应用有界内存缓存]
    Logger --> Files[原有 FileLogSink 轮转文件]
    Files -->|启动恢复| Buffer
    Buffer --> Query[AppLogsProvider]
    Query --> Page[AppLogsPage]
    Query --> Export[筛选结果复制 / TXT 导出]
~~~

| 位置 | 职责 |
|---|---|
| [AppLogger](../../lib/core/logging/app_logger.dart) | 统一事件入口、脱敏、长度限制、共享缓存及现有按分类订阅；可注入测试实例 |
| [FileLogSink](../../lib/core/logging/file_log_sink.dart) | 原格式落盘、批量刷新、轮转、恢复和清空；不引入新数据库 |
| [AppLogsProvider](../../lib/features/logs/providers/app_logs_provider.dart) | 聚合全部分类、排序、节流通知和纯筛选 |
| [AppLogsPage](../../lib/features/logs/pages/app_logs_page.dart) | 查询条件、展示、选择、复制/导出、清空和滚动交互 |
| 各业务 Service / Controller | 在已有生命周期边界记录结果；不从页面推测业务成功，不由日志触发调度或重试 |

没有第二套日志服务、遥测 SDK、日志表、任务调度器或通用追踪框架。原有 info/debug/warning/error 方法的入内存/落盘选项保持兼容；新的 event 默认进入内存和文件。

## 3. 分类和已接入事件

| 分类 | 范围 | 典型事件 / 信息 |
|---|---|---|
| app 应用 | 业务初始化、已捕获的 UI 操作失败、日志存储初始化/清空失败 | app.initialize.*、ui.action.failed、logging.* |
| engine 引擎 | 原有引擎事件 | 本地后端相关诊断，保留原入口 |
| server 服务 | 原有 LLM 服务启停与输出 | 不要求先发布服务才可查看应用日志 |
| model 模型 | 原有 LLM 模型管理 | 保留原入口 |
| download 下载 | 原有下载任务 | 保留原入口；语音下载在 speech 下提供任务级事件 |
| client 客户端 | 助手/连接/本地档案操作、模型发现/连接测试、聊天 Run 和供应商请求 | client.run.*、client.request.*、client.models.*、连接/助手保存与删除；状态码、耗时、可获得的 token 计数 |
| agent Agent | 工具会话、审批、执行状态、授权撤销、静态 Skill、远程 MCP、网络搜索 | agent.tool.state/decision/error、agent.skill.*、agent.mcp.*、agent.search.*；工具数量、RPC 方法/状态、搜索供应商/结果数、耗时 |
| speech 语音 | 语音模型、任务、录音、解码、播放、导出、参考音色 | speech.download/import/model/job/worker/recording/decode/playback/audio/voice/transcript.* |

语音任务包括入队、资源等待及原因、执行、取消申请、最终状态和资源释放。模型导入/下载失败附带 storage、transfer、extraction、validation 或 commit 等阶段，便于区分存储、传输和校验问题。音频记录覆盖权限/焦点拒绝、录音中断/后台停止/时长限制、播放完成、解码及导出失败。转录编辑和参考音色管理仅记录 ID、长度或时长。

网络搜索记录 agent.search.started / finished，含 run、call、provider、query_chars、limit、results、elapsed_ms、outcome，失败时提供有限 reason/http_status。工具回执保存搜索词、来源 URL 和摘要；诊断日志不记录这些正文或请求头。使用及设备结果见[网络搜索说明](WEB_SEARCH_ZH.md)。

日志不包含每个 token、每个音频帧、每次进度回调或转录分块正文。语音原生执行通过 worker 的 loading、ready、releasing、released 阶段进入主 isolate 的统一日志；没有把进程级 stderr 或原生控制台原文接入 speech 分类。

## 4. 关联与结束语义

| 字段 | 用途 |
|---|---|
| run / conversation | 定位一次聊天运行及所属会话；一个 Run 可以包含多个供应商请求和工具调用 |
| request | 客户端为一次协议请求生成的本地诊断 ID；不写入 HTTP 请求头，也不用于取消原生任务 |
| connection / protocol / model | 连接稳定 ID、协议类型与模型 ID；不记录连接显示名称、URL 或凭据 |
| call / tool | 工具调用 ID 及已授权工具标识；未识别的工具名记录为 unrecognized |
| provider / query_chars / results | 网络搜索供应商、查询长度与结果数；不记录查询词、结果 URL 或摘要 |
| server / session / rpc | MCP 配置 ID、本地诊断会话 ID、RPC 序号；不记录远端实际 MCP 会话凭据 |
| job / asset / recipe | 语音任务、统一模型资产和固定配方；显式重试生成新 job，并关联 previous_job |
| audio / voice | 录音/播放或音色的本地 ID；不记录文件路径、音色名称和参考转录 |

聊天区分 client.run（包括工具及持久化）与 client.request（一次 HTTP 请求）。请求结束记录 completed、cancelled、failed 或 consumer_closed；取消前已经收到响应时保留实际 HTTP 状态。first_output_ms 是首个文本、推理或工具输出的时间，不等同于原生首 token 测量。elapsed_ms 是客户端观察到的耗时，不代表云端停止计算或计费。token 计数沿用协议结果，0 也可能表示未提供统计，不作为计费依据。

语音的取消申请、任务终态和资源清理分别记录。只有 worker 确认清理并退出才记录 speech.worker.released；SpeechJobService 释放 lease 后才写 resources_released=true。清理无法确认时记录 speech.resources.quarantined 和 resources_released=false。即使任务显示 cancelled，也不能据此推断模型已经卸载。ASR/TTS FIFO 与独立 LLM 驻留规则保持不变。

工具执行日志来自已提交的状态转换。审批日志只记录允许/拒绝；重复点击不产生第二次批准或执行。远端副作用无法确认时保留 unknownOutcome，不能根据 HTTP 取消日志将其解释为“没有执行”。

## 5. 内容约束与故障处理

新增业务事件只传入明确选择的标量元数据。嵌套 Map、列表、null 不进入事件文本。错误采用 error_type、Dio network_kind / http_status、OS 错误码、有限格式的 platform_code；不把异常 message、请求/响应对象或堆栈直接序列化到新增事件。

不记录提示词、系统提示、回复/推理正文、工具参数/结果、用户档案值、Skill 内容、ASR 转录、TTS 输入、音频内容、参考文本、请求头或秘密。字符串经过现有 LogRedactor 后再截断和 JSON 转义，避免已知长凭据被截断后绕过脱敏；恢复的旧记录也经过脱敏与长度限制。实际模型 ID 与内部业务 ID属于诊断元数据。

旧的引擎/服务文本仍经统一脱敏，但其格式由既有代码或上游决定，可能包含模型路径等运行信息；此次并未将全部旧文本转换成结构化事件。新功能遵循上述限制，真实第三方输出的覆盖仍属于设备/服务联调验收。

日志写入失败不使聊天或语音任务失败：内存视图继续可用；文件刷新沿用尽力写入，不将其作为业务事务的提交条件。启动无法打开/恢复文件时写入存储告警；清空文件失败会在页面提示，并记录 logging.clear_failed，不能宣称磁盘已清空。worker 的诊断回调异常也不能阻止资源清理确认。

## 6. 容量与查询范围

- AppLogger 全应用合计保留最近 2000 条，AppLogsProvider 同样最多展示 2000 条；新增分类不会把缓存容量乘以分类数。
- 单条消息保留最多 8192 个 UTF-16 单元加省略号；单个字符串字段最多 160 个单元加省略号。原生日志超长行也受单条上限约束。
- 文件保持 timestamp|channel|level|escaped-message 格式；新增分类按名称解析，旧 server/engine 等记录可直接恢复，无数据库迁移。
- 沿用约 1 MiB 的轮转阈值和最多三个文件（当前文件及两份历史）。按批次追加后轮转，所以阈值不是严格字节总额上限。
- 64 条或 1 秒触发刷新；后台/退出时尝试刷新。异常杀进程可能丢失最后未刷新的批次。
- 启动最多恢复 2000 条。页面关键词查询和导出作用于当前缓存，不扫描全部旧文件，不提供跨日期分页、远端上传或无限期留存。
- 页面通知每 100 ms 合并一次，日志入缓存即时完成。清空后新产生的事件仍正常记录。

## 7. 验证与验收

自动化覆盖日志元数据脱敏/长度、落盘与旧格式恢复、全局容量、清空和失败处理、组合筛选、复制与导出一致、窄屏大字体/键盘布局、三种聊天协议的成功/HTTP 错误/取消、工具审批/Skill/MCP/网络搜索不含正文，以及语音导入/下载失败、音频 I/O、FIFO 取消和清理隔离。

语音 worker 用受控替身验证状态与资源所有权顺序；真实 FFI 的阶段到达、录音/播放焦点事件、磁盘压力、进程终止和长时并行日志负载仍需真机执行。操作步骤及结果记录见[验收指南](ACCEPTANCE_GUIDE_ZH.md)，当前检查结果见[实现报告](IMPLEMENTATION_REPORT_ZH.md)。
