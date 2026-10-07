# ServLlama 2.0 真机冒烟报告（2026-09-27）

按本次要求，只检查主要功能能否串通，难以现场验证的功能允许跳过。本机已覆盖的主流程通过；发现的语音下载线路和录音焦点问题已修复、重新安装并复测。本报告不代表完整设备矩阵、模型效果或发布验收通过。

## 1. 测试环境与版本

| 项目 | 实际环境 |
|---|---|
| 手机 | Redmi K50 Ultra，型号 22081212C / diting，arm64-v8a |
| 系统 | Android 12 / API 31，4 KiB 内存页；屏幕 1220 × 2712，density 480 |
| 升级路径 | 原机 1.2.1+13 Debug → 2.0.0-dev.4+18 → 修复版 2.0.0-dev.5+19；同签名覆盖安装，无卸载或清数据 |
| 应用代码 | 从 81e5279 创建 fix/2.0-device-smoke；修复提交 c35f097，经 c6f5278 以 merge --no-ff 合入 feature/2.0 |
| 配套插件 | mnn_engine 0.2.0-dev.2 / 59d5810；本轮未修改插件 |
| 安装包 | build/app/outputs/flutter-apk/app-debug.apk，120,879,090 字节，minSdk 28 / targetSdk 35，仅 arm64-v8a |
| APK SHA-256 | c01a145172cad6be79ee2bf07c9b8da45b77a477fb45127b8e076cac6da64397 |
| 签名 SHA-256 | 99c212c1ab3bc814d227d5e60a273c3542d28af5795ad65d0281019d6c5ed1f9（本机 Debug 签名） |

本轮只重建和安装了 Debug。现有 app-release.apk 仍为上一轮 dev.4+18，不能当作包含本轮修复的 Release。原 APK、应用配置及旧 Hive 已在安装前备份到本机忽略目录；原有数 GB 模型权重未复制、未改写。

## 2. 实际覆盖结果

| 范围 | 实际操作与结果 |
|---|---|
| 启动、导航、升级 | 五入口可用；导入 17 个会话、38 条消息、13 个消息版本，旧历史可见，SQLite integrity_check 为 ok；再次启动未重复导入或创建默认助手 |
| 档案与助手 | 保存本地档案，创建、编辑、选择本地/远端助手；重启后保留；收尾通过页面删除测试助手并选回 ServLlama |
| GGUF 本地聊天 | Qwen2.5-3B-Instruct-Q4_0 / llama.cpp CPU：启动、流式回答、停止生成、保留部分内容、再次提问返回 OK，以及停服/进程退出 |
| MNN 本地聊天 | Qwen3.5-0.8B-MNN / Vulkan：模型加载、流式推理与最终文本；首字前取消后可继续请求，随后可停服。短预算试次有仅输出推理便耗尽 token 的情况，不作为回答质量通过证据 |
| 原有 LLM HTTP 服务 | 从服务中心发布 GGUF，通过 ADB 转发访问原 localhost:8083；GET /v1/models、POST /v1/chat/completions 非流式与流式均为 200，回复 OK，SSE 有 [DONE]；加载期间的一次 503 在 ready 后恢复。原配置无 API key，本次未覆盖鉴权/LAN 矩阵 |
| AI 连接与客户端 | 本机受控 OpenAI 兼容服务：连接保存、获取模型、连接测试、普通聊天，以及服务断开报错后恢复。经过真实 HTTP，但未使用真实云供应商凭据 |
| 基础 Agent | 测试服务发起 clock 调用，应用执行本地时间工具，保存回执并继续模型回答；工具过程页显示完成 |
| MCP | 本机 Streamable HTTP 服务完成 initialize、tools/list、逐工具授权、允许本次审批、tools/call 和后续回答；回执为 MCP_SMOKE_OK。未测试生产 MCP 鉴权及旧 SSE |
| 静态 Skill | Markdown 导入、元数据展示、助手权限列表可见；收尾删除成功。未绑定执行 Skill，不标记其调用链路通过 |
| 语音模型 | 自动线路修复后，sherpa Whisper tiny（约 99 MiB）和 AISHELL3 VITS（约 41 MiB）下载、大小/哈希校验完成并显示可用；不完整的 Crisp 包显示可继续下载，可经页面删除 |
| 录音与播放 | 麦克风授权后，修复版录音持续 21.106 秒，手动停止和播放流程正常；另一次录音退后台后自动停止并保留记录。未验证权限拒绝、真实来电或耳机切换 |
| sherpa TTS | AISHELL3、speaker 0、语速 1.0，输入 12345，合成、播放、导出 WAV 成功；输出为 8000 Hz、单声道 PCM16、2.8785 秒、46,100 字节 |
| sherpa ASR 与草稿 | 导入上述 8 kHz WAV，经解码/转换后 Whisper tiny（language=zh）任务完成；原结果为 112.3545。将结果修订为 Speech smoke test.，保存、TXT 导出内容一致，并明确追加到聊天草稿，没有自动发送 |
| LLM 与语音独立驻留 | MNN 驻留期间执行录音、TTS、ASR 及客户端操作，语音未停止 MNN；返回服务中心仍显示 MNN 运行。这里只验证驻留独立及短任务，未测持续同时生成的性能或竞态矩阵 |
| 应用日志 | 设置与服务中心进入同一日志页；可见 client、agent、speech 事件。分类 + 最低级别 + 关键词组合查询可用，复制反馈与导出正常；导出的 4 条语音 warning/error 与筛选一致，无结果时复制/导出禁用；覆盖升级后日志保留 |

语音样例只确认任务、结果和文件的流转。数字转录存在明显偏差，不能据此声称中文识别精度或音质已验收。该次 TTS 任务约 4.756 秒、ASR 约 3.921 秒，含模型准备与任务开销，均为单次 Debug 观察值，不是性能基准。使用的模型 revision 为 AISHELL3 e3e808eaab2385b812286c6707323362251bba65、Whisper tiny 65176e2deb88badc814a94058666cadccc29b61c。

MNN 首字前取消的一次客户端请求约 594 ms 后结束；这是客户端观测，不能等同于原生计算在同一时刻退出。后续请求、停服及资源释放的行为一并检查，未用 HTTP cancelled 单独证明卸载完成。

新增结构日志抽查了 94 条 client、56 条 agent、66 条 speech 记录，未发现本轮提示词、回复、转录和 Skill 名称的六个正文测试标记。该抽查只覆盖这些新增事件；原生 logcat 和旧服务输出不属于此结论，sherpa 原生控制台仍可能输出文本。为保留原有诊断历史，本轮没有清空全部日志。

## 3. 发现的问题与修复

### 3.1 语音下载未使用已配置的 Hugging Face 线路

原语音下载直接使用模型配方中的官网 URL，忽略下载设置中的自动/官网/镜像线路。本机网络下官网连接超时而镜像可达，导致语音包无法完成下载。

修复复用现有 DownloadSettingsStore 和 HuggingFaceRouteResolver，每次继续/重试下载读取当前线路。只改写明确属于 Hugging Face 官网或镜像的 origin，保留固定 revision、文件路径、查询参数与校验元数据；其他来源、带用户信息或自定义端口的 URL 保持不变。解析后复核取消状态，不新增下载队列或模型注册表，也不宣称已接入所有下载设置。

回归用例覆盖失败后更换线路重试、固定元数据不变、自动探测以及非 HF 来源不改写。修复版在手机上完整下载并校验了上述两个 sherpa 模型。

### 3.2 录音被自身的第二次焦点申请中断

修复前录音通常在约 192–222 ms 后自动停止，日志出现 speech.audio.interrupted。应用 AudioSession 已申请焦点，record 插件的默认中断策略又申请一次，触发了应用自身的失焦处理。

在 RecordConfig 中设置 AudioInterruptionMode.none，由已有 AudioSession 统一管理焦点和中断；仍保留离开前台、失焦时停止录音的逻辑。未修改上游插件。修复版完成了 21 秒录音、停止/播放，以及退后台自动停止的复测。

涉及代码：[线路解析](../../lib/features/downloads/services/hugging_face_route_resolver.dart)、[语音下载](../../lib/features/speech/services/speech_model_service.dart)、[音频 I/O](../../lib/features/speech/services/audio_io_service.dart)、[必要回归](../../test/features/speech/speech_model_download_test.dart)。

## 4. 自动化与构建核对

| 检查 | 本轮结果 |
|---|---|
| flutter analyze --no-pub | 无问题 |
| flutter test --no-pub test/features/speech test/features/downloads | 83 项通过，含本轮新增的 2 项回归 |
| Flutter Debug 构建与安装 | dev.5+19 成功；实际 manifest、签名和 APK SHA 已核对 |
| 原生包审查 | verify_android_bundle.py 通过；仅 arm64，26 个 AArch64 ELF 对齐通过，4 个 DSP 库与输入一致，Crisp 哈希一致；不代表 16 KiB 真机已验收 |
| 冷启动与应用异常 | 清理后冷启动正常；本轮观察未发现应用崩溃/ANR，最终进程 logcat 未出现 fatal/未处理异常标记 |

此前 522 项全应用测试、插件 Dart 16 项和 JVM 90 项属于前一阶段的基线，本轮没有重复执行全量套件。不能将新增用例数量相加后声称全量 524 项已通过。

## 5. 本轮未验证项

- Crisp Whisper base 下载发生传输失败（DownloadException），未取得完整权重；Crisp 原生 ASR 未测。Qwen3-TTS 约 1.3 GB 模型、默认 voicepack、参考音色/克隆及 C2PA 产物跳过。
- 真实 OpenAI / Anthropic / Gemini 凭据、计费、图片和模型能力；MCP 生产鉴权、旧 SSE、会话过期、未知副作用及断线恢复复杂场景。
- 长音频、识别精度、主观音质、多 speaker、SRT、所有语音取消/队列组合、LLM 与语音同时计算的压力和性能。
- 麦克风权限拒绝、通知权限拒绝、真实来电/蓝牙、长时后台、低内存/温控，以及其他 Android 版本、16 KiB 页、Hexagon 后端。
- 精确的 1.2.2 升级路径、完整鉴权/LAN HTTP 回归、正式签名与 dev.5 Release 发布验收；本机实际起点为 1.2.1+13。

设备 USB 曾短暂重连，系统浮层也曾改变前台焦点；在确认焦点或连接后才继续输入，未将这些干扰算成应用崩溃。Crisp 下载失败保持为未解决的本次网络/包下载现象，未据此判定原生引擎不可用。

## 6. 收尾与证据

测试会话、两个测试助手、临时 AI 连接、Skill、MCP、两个语音任务及失败的 Crisp 资产均通过应用页面删除；本地档案恢复默认，选回 ServLlama。只清理已确认由本轮产生的录音和四个 Download 测试文件，没有删除原有模型、历史或全部日志。

最终核对：仍为 17 个原会话、38 条原消息、13 个原消息版本，全部记录与迁移后基线一致；三个旧聊天 Hive 与升级前备份的 SHA 一致；三个原 LLM 资产登记和默认助手配置不变。原 Preferences 除迁移清理了原本为空的 server.api_key 外均未改变。没有遗留测试 Run、工具调用、语音任务或录音。

保留已验证可用的 Whisper tiny 和 AISHELL3 两个小型语音模型，方便继续试用。恢复原 llama.cpp / Qwen2.5-3B、CPU、localhost:8083 配置并停止 LLM，最终无 llama-server 子进程或活动前台服务。应用初始化仍会绑定 MNN 插件服务，该绑定本身不表示模型加载。临时测试服务已停止，ADB forward/reverse 映射为空。

本机证据目录（Git 忽略）：

~~~text
.dart_tool/device-smoke-20260927/
~~~

主要索引：analyze.log、regression-tests.log、build-debug.log、apk-audit.json、llm-http-smoke.json、migration-summary.json、after-cleanup-summary.json、final-verification.json、final-app.log，以及按步骤命名的 UI XML/PNG。transcript-export.txt 和 sherpa-tts-smoke.wav 保存了测试导出结果。

original-1.2.1.apk、original-private-data.tar 与数据库副本只留在本机，可能含原有私密配置或会话；不随报告或 Git 提交。应用修复和本报告仅本地提交，没有 push。完整后续清单见[验收指南](ACCEPTANCE_GUIDE_ZH.md)，当前实现范围见[实现报告](IMPLEMENTATION_REPORT_ZH.md)。
