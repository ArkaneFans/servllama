<div align="center">
  <img src="assets/app_icon.svg" alt="ServLlama 图标" width="112" />
  <h1>ServLlama</h1>
  <p><strong>一个支持本地大模型和云端模型的Android AI应用</strong></p>
  <p>
    <a href="https://github.com/ArkaneFans/Servllama/releases/latest">
      <img alt="下载最新版本" src="https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
    </a>
  </p>

  <p><a href="README.md">English</a> | <strong>简体中文</strong></p>
  <p>
    <a href="#快速开始">快速开始</a> ·
    <a href="#功能特性">功能特性</a> ·
    <a href="https://github.com/ArkaneFans/Servllama/issues">问题反馈</a>
  </p>
</div>

## 项目简介

ServLlama 是一款开源 Android AI 应用，将本地模型与云端供应商集成在同一个应用中。你可以使用设备上的模型离线聊天，也可以接入自己的 API 服务。不仅如此，ServLlama 也能将您的手机变成一台 OpenAI 兼容的本地大模型服务器，供本机或局域网内的其他应用调用。语音工坊则提供离线转录与语音合成。

## 应用截图

<p align="center">
  <img src="docs/Screenshot1.jpg" alt="ServLlama 应用截图 1" width="220" />
  <img src="docs/Screenshot2.jpg" alt="ServLlama 应用截图 2" width="220" />
  <img src="docs/Screenshot3.jpg" alt="ServLlama 应用截图 3" width="220" />
  <img src="docs/Screenshot4.jpg" alt="ServLlama 应用截图 4" width="220" />
</p>

## 下载安装

从 [GitHub Releases](https://github.com/ArkaneFans/Servllama/releases/latest) 下载 APK 并安装。

| 项目 | 要求 |
| --- | --- |
| 系统 | Android 9（API 28）及以上 |
| 设备架构 | 64 位 ARM（`arm64-v8a`） |
| 本地模型 | 足够容纳并运行所选模型的存储空间和内存 |

安装好模型后，本地大模型和离线语音无需联网即可使用。云端供应商、联网搜索、远程 MCP 和模型下载需要网络连接。如果不确定设备能运行多大的模型，建议先从小模型开始。

## 快速开始

安装后，可以从以下任一种方式开始；本地与云端模型可以在同一个应用中使用。

### 使用云端模型聊天

1. 打开 **设置 → 供应商**，配置预设供应商，或点击 **+** 添加自己的服务，填写 API 地址与 API Key。
2. 获取供应商的模型列表，或手动添加模型，并确保供应商已启用。
3. 在聊天输入栏选择模型，开始对话。需要区分不同角色时，可以新建助手，为其配置独立的指令和模型。

云端聊天不需要启动本地服务器。

### 使用本地模型聊天

1. 从侧栏打开 **模型库**，通过 **发现模型** 下载 GGUF 或 MNN 模型，或点击 **+** 导入本地模型。
2. 在聊天模型选择器中选择已安装的本地模型，应用会加载模型并启动本地服务。
3. 开始聊天。使用支持视觉的 GGUF 模型时，还需下载或导入匹配的投影器（`mmproj`）。

### 使用离线语音

1. 从侧栏打开 **语音工坊**，进入 **语音模型**，通过 **发现模型** 安装转录或语音合成模型。
2. 选择对应模型，录音或导入音频进行转录，也可以输入文本合成语音。
3. 查看结果，将转录文本插入聊天草稿，或导出文本与音频。

## 功能特性

### 聊天与助手

- **本地与云端模型**：支持 OpenAI 兼容、Anthropic 和 Gemini API，也支持设备上的 GGUF 与 MNN 模型。
- **自定义助手**：为每个助手设置名称、指令、模型、生成参数和启用的工具。
- **对话管理**：流式回复、可折叠的推理内容、Markdown 与代码块、受模型支持的图片输入，以及会话搜索、草稿、消息编辑和回复版本。

### 本地模型与服务

- **双推理引擎**：[llama.cpp](https://github.com/ggml-org/llama.cpp) 用于 GGUF 文件，[MNN](https://github.com/alibaba/MNN) 用于完整的 MNN 模型目录。
- **模型发现与下载**：浏览精选模型，或搜索 Hugging Face 与魔搭 ModelScope；支持暂停、继续、重试与切换下载来源。
- **模型管理**：导入、重命名、删除与配置已安装模型，并为 GGUF 视觉模型管理匹配的投影器。
- **手机上的模型服务器**：向其他客户端提供本地模型服务，支持自定义端口、仅本机或局域网访问、可选 API Key 认证，以及前台服务通知。

### 工具、技能与 MCP

- **内置工具**：联网搜索、查询当前时间，以及让模型向你提问并确认信息。
- **技能**：导入 Markdown 或 ZIP 技能包，也可以粘贴技能指令，再为助手启用。技能提供指令与资源，不执行包内脚本。
- **远程 MCP**：连接 HTTP/SSE MCP 服务，发现其工具并管理助手的使用权限。工具调用有可查看的记录，需要确认的操作会请求审批。

工具调用需要模型本身支持；当前不提供本地 Shell 执行或 stdio MCP 服务。

### 离线语音工坊

- **语音转文字**：录音或导入音频，查看与修订转录文本，导出 TXT；模型提供可靠时间戳时支持字幕导出。
- **文字转语音**：在设备上合成语音、试听结果，并导出 WAV 音频。
- **与聊天联动**：将转录文本插入草稿，朗读助手回复。语音任务保留结果，也可与本地大模型同时运行。

### 日常体验

- **本地数据**：对话、草稿、配置和语音结果保存在设备上，API 凭据使用安全存储。
- **外观与导航**：浅色与深色主题、中英文界面，通过侧栏访问助手、历史、模型、服务和设置。
- **问题诊断**：查看、筛选、复制与导出应用和运行日志，便于排查问题。

## 连接其他 AI 客户端

打开 **服务器**，选择推理引擎与模型并启动服务，再将页面显示的地址填入其他支持 OpenAI 兼容接口的客户端。

| 客户端配置 | 填写内容 |
| --- | --- |
| 同一手机上的 API Base URL | 默认端口下为 `http://127.0.0.1:8080/v1` |
| 其他设备上的 API Base URL | `http://<手机IP>:<端口>/v1`，需先开启监听所有网络接口 |
| API Key | 本地服务器中配置的密钥；未启用认证时无需提供 |
| 模型 ID | `GET /v1/models` 返回的模型 ID |

两种引擎都支持 `GET /v1/models` 和 `POST /v1/chat/completions`，包括流式回复；llama-server 的其他专有接口取决于当前引擎。同一时间只运行一个本地大模型，供其他客户端使用的服务模型与聊天模型的选择是独立设置。

## 架构


<p align="center">
  <img src="docs/architecture.svg" alt="ServLlama 架构" width="100%" />
</p>


## 使用与隐私说明

- **本地不代表所有功能都离线**：使用云端供应商时，对话内容会发送给所选服务；搜索和远程工具也会收到完成任务所需的输入。请使用可信的服务。
- **语音在本机处理**：转录不会自动上传原始音频或发送聊天消息。语音识别与合成属于应用内功能，不是本地大模型 API 的语音接口。
- **保护局域网访问**：监听所有接口后，服务器可能被当前 Wi-Fi、热点或 VPN 网络中的设备访问。请配置 API Key，并在可信网络中使用。
- **注意系统后台限制**：如果 Android 停止了服务，请检查通知、后台运行与自启动权限，并按需调整电池优化设置。
- **模型与设备存在差异**：语言、视觉、工具、GPU 加速和输出质量取决于模型与设备。首次加载或 GPU 调优可能较慢，输出异常时可尝试 CPU 或更高精度设置。下载模型前请查看其使用许可。

## 反馈与参与

欢迎通过 [GitHub Issues](https://github.com/ArkaneFans/Servllama/issues) 反馈问题与建议。反馈时请提供应用版本、手机型号、Android 版本、模型与后端，以及复现步骤；分享日志前请去除 API Key 和私人内容。

源码开发约定见 [AGENTS.md](AGENTS.md)。原生产物准备可参考 [llama.cpp 构建说明](patches/llama.cpp/README.md) 与 [语音构建脚本](tool/build_speech_native.ps1)，MNN 插件在 [mnn_engine](https://github.com/ArkaneFans/mnn_engine) 独立维护。功能与技术文档统一放在 [docs/engineering](docs/engineering)。

## 致谢

- [llama.cpp](https://github.com/ggml-org/llama.cpp)、[MNN](https://github.com/alibaba/MNN) 与 [mnn_engine](https://github.com/ArkaneFans/mnn_engine)：本地大模型推理。
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 与 [CrispASR](https://github.com/CrispStrobe/CrispASR)：离线语音能力。
- [Kelivo](https://github.com/Chevey339/kelivo) 与 [RikkaHub](https://github.com/re-ovo/rikkahub)：聊天交互与信息组织的设计参考。
- [Linux DO Community](https://linux.do/) 。

## 开源许可

ServLlama 基于 [GNU Affero General Public License v3.0](LICENSE) 开源，第三方组件与模型分别遵循各自的许可证。
