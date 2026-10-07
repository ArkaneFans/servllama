<div align="center">
  <img src="assets/app_icon.svg" alt="ServLlama icon" width="112" />
  <h1>ServLlama</h1>
  <p><strong>Local and cloud AI, assistants, tools and offline speech on your phone</strong></p>

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

ServLlama 2.0 combines local and cloud chat, configurable assistants, bounded Agent tools, static Skills, remote MCP, and offline transcription/speech synthesis in one Android app. Local LLM inference uses llama.cpp or MNN and can still be published as an OpenAI-compatible service for other clients. Speech runs inside the app.

This branch is **2.0.0-dev.8**, not a published stable release. Code and automated checks are complete; device/model/provider qualification is tracked in the [implementation report](docs/2.0/IMPLEMENTATION_REPORT_ZH.md) and [acceptance guide](docs/2.0/ACCEPTANCE_GUIDE_ZH.md) (Chinese). The screenshots above show the 1.x interface; the current [chat avatars and attribution](docs/2.0/CHAT_IDENTITY_ZH.md) include a device preview.

## Features

- Five destinations: Chat, Assistants, Speech, Models, Settings.
- Local profile and assistant settings, with explicit selection of which profile fields an assistant may use; no account or cloud sync.
- Conversations belong to assistants and keep independent model selections; changing an assistant's optional default does not retarget existing chats. See the [relationship design](docs/2.0/CONVERSATION_ASSISTANTS_ZH.md).
- Direct OpenAI-compatible, Anthropic and Gemini connections, with credentials in secure storage.
- Bounded Agent runs with tool approval, conversation files, saved execution receipts, static Skill import, and remote MCP over Streamable HTTP or legacy SSE.
- Offline ASR/TTS through sherpa-onnx and CrispASR: recording/import, transcription editing, TXT/SRT export where timestamps are available, synthesis/playback/WAV export, and model-compatible reference voices.
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

Both LLM engines require a model before startup. LLM and speech have independent residency and can run together. ASR/TTS share one speech FIFO. Speech does not stop local chat or a published LLM service. Both LLM engines expose the core endpoints above; other llama-server-specific features are available only while the llama.cpp engine is active.

Speech packages currently cover sherpa Whisper, sherpa VITS, Crisp Whisper and Crisp Qwen3-TTS Base. Download/import instructions, model dependencies and license status are in the [speech model package guide](docs/2.0/SPEECH_MODEL_PACKAGES_ZH.md). ASR/TTS do not expose an HTTP API.

Use the Vision control on a GGUF download card to choose whether to download a projector with the model. Model settings let you open the original repository, download or delete projector versions, and select one installed version to use. Turning vision off keeps the files. Deleting the selected version selects another installed version, or turns vision off when none remain. Locally imported models support importing a compatible projector and toggling vision separately.

## Requirements

- Android 9 (API 28) or later
- 64-bit ARM device (`arm64-v8a`)
- Enough free storage and memory for the selected model

Actual speed and memory usage depend on the model, quantization, context length, and device. Start with a smaller model if you are unsure what your phone can handle.

## Quick Start

1. Build this development version using the guide below. [GitHub Releases](https://github.com/ArkaneFans/Servllama/releases/latest) contains published versions; this local 2.0 branch has not been published.
2. For local chat, download/import a GGUF or MNN model under Models. For cloud chat, add a provider connection under Settings.
3. Choose an assistant, then select a model for the conversation. An assistant may provide an optional default for new chats. Enable individual tools or Skills only for assistants that need them.
4. For transcription or synthesis, download/import a compatible speech package and open Speech. Chat microphone input inserts a reviewed transcript into the draft; it does not send automatically.
5. To serve local LLM requests to other clients, open the server center under Settings and start the service. For another device, select **Listen on all** and set an API key.

The default published server address is `http://127.0.0.1:8080`, accessible only from the Android device itself. Internal local chat uses its own private endpoint.

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

Validated with Flutter 3.35.2 / Dart 3.9.0, Android SDK, JDK 17 and NDK 27.0.12077973. Use the sibling application/plugin checkouts described in the [acceptance guide](docs/2.0/ACCEPTANCE_GUIDE_ZH.md). The unpublished mnn_engine 0.2.0 requires a local sibling override; a fresh public checkout cannot resolve that version yet.

```bash
flutter pub get
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
# After preparing the native bundles described below:
flutter build apk --release --no-pub --target-platform android-arm64
```

MNN native artifacts are provided by the sibling `mnn_engine` plugin. llama-server is a prebuilt Snapdragon bundle (CPU variants + OpenCL + Hexagon) that is **not** stored in git. Copy the `.so` files into `android/app/src/main/jniLibs/arm64-v8a/` from a release extra, the GitHub Actions artifact, or a local WSL build before compiling the APK. See `patches/llama.cpp/README.md`.

Build the pinned Crisp library with `pwsh -File tool/build_speech_native.ps1 -AndroidSdk <sdk-path>`; sherpa native libraries come from the pinned pub dependencies. Gradle checks the Crisp manifest hash. Run `python tool/verify_android_bundle.py <apk-path>` on the final APK and verify its version/signature. Without `android/key.properties`, release builds use the debug signing certificate. Model weights are separate from the APK.

For development verification, run `flutter analyze` and `flutter test`.

The GitHub workflow `.github/workflows/build-llama-server-android.yml` builds that bundle. It checks out the selected llama.cpp tag, applies `patches/llama.cpp/0001-hexagon-skip-unsupported-devices.patch`, and compiles CPU variants, OpenCL, and Hexagon inside `ghcr.io/snapdragon-toolchain/arm64-android:v0.7`. The patch matches v0.4.1; other tags fail the job when it does not apply.

## Usage Notes

- Listening on all network interfaces exposes the server to the current Wi-Fi, hotspot, and VPN networks. Use an API key and a trusted network.
- Some Android vendors restrict long-running background services. If requests stop after the app enters the background, allow ServLlama to auto-start and run in the background, and disable battery optimization for it.
- Models can consume several gigabytes of storage and memory. Choose models that fit your device.

## Related Projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [MNN](https://github.com/alibaba/MNN)
- [mnn_engine](https://pub.dev/packages/mnn_engine)
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- [CrispASR](https://github.com/CrispStrobe/CrispASR)

## License

ServLlama is released under the [GNU Affero General Public License v3.0](LICENSE).

---
Acknowledgements [`Linux DO Community`](https://linux.do/).
