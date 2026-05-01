<div align="center">
  <img src="assets/app_icon.png" alt="ServLlama icon" width="120" />
  <h1>ServLlama</h1>
  <p>一键让你的手机变成强大的LLM服务器</p>
</div>

<p align="center">
  <a href="./README.md">English</a> |
  <strong>中文</strong>
</p>

<p align="center">
  <table>
    <tr>
      <td><img src="docs/Screenshot1.jpg" width="280"></td>
      <td><img src="docs/Screenshot5.jpg" width="280"></td>
      <td><img src="docs/Screenshot6.jpg" width="280"></td>
      <td><img src="docs/Screenshot2.jpg" width="280"></td>
    </tr>
  </table>
</p>


## 📖 项目简介

ServLlama 是一个能够让你的Android手机变成本地大模型部署服务器的应用，无需Termux。ServLlama 提供了用户友好的界面，可以进行模型文件管理、服务进程控制、运行参数配置、日志查看和聊天交互等操作，还有一个Web UI，用户可以在浏览器中与模型进行对话。

ServLlama 的核心原理是使用交叉编译的llama-server直接在Android系统中运行，这与你在Termux中运行的llama-server相同。


## ✨ 功能特色

- 🦙 服务管理：在应用内启动、停止大模型服务器，并查看运行状态与日志。
- 🔌 API 能力：基于强大的 `llama-server`，可对外提供 OpenAI 以及 Anthropic 格式的API。
- 🌐 Web UI：服务启动后，可直接在浏览器中访问Web UI进行聊天对话。
- 🧠 模型管理：导入、托管、删除本地 `GGUF` 模型，支持加载、切换和卸载。
- 💬 对话体验：支持流式回复、推理内容折叠、代码块渲染，以及会话历史搜索和管理。
- ⚙️ 参数配置：可视化调整监听地址、端口、API Key、上下文长度、线程数等关键参数。
- 🎨 主题切换：支持亮色、暗色以及跟随系统三种主题模式。
- 🌍 国际化：支持中文与 English 界面切换。

## 🚀 使用流程

1. 先到 [Hugging Face](https://huggingface.co/) 下载 `GGUF` 模型，建议优先选择适合手机的量化版本，例如 `Q4_K_M`。
2. 打开 ServLlama，进入模型管理页，把下载好的 `GGUF` 文件导入到应用中。
3. 进入服务页面，按需调整端口、上下文长度、线程数等基础参数。
4. 启动本地服务，等待状态变为可用。
5. 进入聊天页面或打开 Web UI，选择一个模型，发送第一条消息，开始对话。
   
你可以将 ServLlama 服务器的base URL 复制到其他AI客户端应用例如kelivo、rikkaHub、ChatterUI中使用，发挥你的想象力！


## 📚 相关文档

- [`llama-server-README.md`](llama-server-README.md)：`llama-server` 的详细使用说明与参数参考。


## 🙏 鸣谢

- [`llama.cpp`](https://github.com/ggml-org/llama.cpp)：本应用核心功能基于llama.cpp实现。
- [`Linux DO 社区`](https://linux.do/)。