<div align="center">
  <img src="assets/app_icon.svg" alt="ServLlama icon" width="112" />
  <h1>ServLlama</h1>
  <p><strong>Turn your phone into a powerful local LLM server with one tap</strong></p>

  <p>
    <a href="https://github.com/ArkaneFans/Servllama/releases/latest">
      <img alt="Download the latest release" src="https://img.shields.io/badge/Download-Latest_Release-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
    </a>
  </p>

<p align="center">
  <strong>English</strong> |
  <a href="./README_ZH.md">简体中文</a>
</p>

<p align="center">
  <table>
    <tr>
      <td><img src="docs/Screenshot1.jpg" width="280"></td>
      <td><img src="docs/Screenshot2.jpg" width="280"></td>
      <td><img src="docs/Screenshot3.jpg" width="280"></td>
      <td><img src="docs/Screenshot4.jpg" width="280"></td>
    </tr>
  </table>
</p>

</div>

## Overview

ServLlama turns your Android device into a self-contained local LLM server, combining model discovery and downloads, switching between the llama.cpp and MNN inference engines, server controls, log viewing, and chat in a single app. Model inference runs directly on the device, and other apps on the same phone or local network can call it through an OpenAI-compatible API.

## Features

- Dual inference engines: run GGUF models with [llama.cpp](https://github.com/ggml-org/llama.cpp) or MNN models with [MNN](https://github.com/alibaba/MNN).
- In-app model discovery: browse featured models, or search Hugging Face and ModelScope at the same time.
- Reliable download management: download GGUF / MNN models with support for pausing, resuming, retrying, and switching sources; tasks persist across page and app state changes.
- OpenAI-compatible API serving: core support for `GET /v1/models` and `POST /v1/chat/completions`, including streaming responses and optional API-key authentication, with the service kept alive in the background (if the service drops after the app goes to the background, see Usage Notes).
- Complete chat experience: streaming output, collapsible reasoning, Markdown and code blocks, image input for compatible vision models, message editing and regeneration, and conversation history and search.
- Practical server controls: switch between local-only and LAN access, configure the port and API key, tune llama.cpp inference parameters, and view, filter, copy, or export logs.
- Android integration: foreground service notifications, light and dark themes, and Chinese and English interfaces.

## Inference Engines

| Engine | Model format | Compatibility / ecosystem |
| --- | --- | --- |
| llama.cpp | A single `.gguf` file, with an optional `mmproj` file for vision | GGUF is the most widely adopted format for community model distribution — most popular open-source models on Hugging Face ship ready-made quantized GGUF builds, so choices are plentiful. |
| MNN | MNN model | Open-sourced and actively maintained by Alibaba, with deep optimization for mobile ARM CPU / GPU and strong performance; models must be exported through the MNN conversion toolchain. |

Both engines require a model to be selected before startup. Only one engine runs at a time and owns the configured server port. Both engines expose the core endpoints above; other llama-server-specific features are available only while the llama.cpp engine is active.

## Requirements

- Android 9 (API 28) or later
- 64-bit ARM device (`arm64-v8a`)
- Enough free storage and memory for the selected model

Actual speed and memory usage depend on the model, quantization, context length, and device. Start with a smaller model if you are unsure what your phone can handle.

## Quick Start

1. Download the latest APK from [GitHub Releases](https://github.com/ArkaneFans/Servllama/releases/latest) and install it.
2. Open the model library. Download a model from Hugging Face or ModelScope, or import a local GGUF or MNN model.
3. Choose an inference engine and model from the Chat or Server page.
4. Start the server and chat in ServLlama, or copy the API Base URL into another AI client.
5. For access from another device, select **Listen on all** in Server config and set an API key.

The default server address is `http://127.0.0.1:8080`, which is accessible only from the Android device itself.

## API

Use the model ID returned by `/v1/models` in chat requests:

```bash
curl http://<device-ip>:8080/v1/models
```

```bash
curl -N http://<device-ip>:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-id",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

If an API key is configured, add `-H "Authorization: Bearer <api-key>"`. For same-device clients, replace `<device-ip>` with `127.0.0.1`.

## Build from Source

You need a Flutter SDK compatible with Dart 3.9, Android SDK, and JDK 17.

```bash
git clone https://github.com/ArkaneFans/Servllama.git
cd Servllama
flutter pub get
flutter build apk --release
```

The repository already includes the required arm64 llama-server libraries, while MNN native artifacts are provided by the `mnn_engine` package. A normal app build does not require compiling either backend manually.

For development verification, run `flutter analyze` and `flutter test`.

Maintainers can update llama-server from the [Build llama-server for Android](https://github.com/ArkaneFans/Servllama/actions/workflows/build-llama-server-android.yml) workflow. Run it manually with an exact llama.cpp tag, download the generated artifact, and copy its `android` and `assets` directories over the repository.

## Usage Notes

- Listening on all network interfaces exposes the server to the current Wi-Fi, hotspot, and VPN networks. Use an API key and a trusted network.
- Some Android vendors restrict long-running background services. If requests stop after the app enters the background, allow ServLlama to auto-start and run in the background, and disable battery optimization for it.
- Models can consume several gigabytes of storage and memory. Choose models that fit your device.

## Related Projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [MNN](https://github.com/alibaba/MNN)
- [mnn_engine](https://pub.dev/packages/mnn_engine)

## License

ServLlama is released under the [GNU Affero General Public License v3.0](LICENSE).

---
Acknowledgements [`Linux DO Community`](https://linux.do/).