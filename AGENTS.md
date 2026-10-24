# ServLlama Agent Guide

## Project Overview

ServLlama is an Android AI application that combines an on-device LLM server with a local/cloud chat client. Flutter owns the product UI, business data and runtime orchestration; inference belongs to the underlying engines. Cloud chat is independent of the local server.

This guide describes the project map and durable development boundaries. Versions, backend availability, build parameters and implementation details belong in source files, manifests and focused documentation.

## Core Features

- Chat: local/cloud models, streaming text and reasoning, image input, conversation history, editing and message revisions.
- Assistants and providers: assistant instructions/model selection, remote provider configuration and model-level capabilities; OpenAI-compatible, Anthropic and Gemini protocols.
- Local models and serving: GGUF/MNN import, discovery, downloads, model configuration and an OpenAI-compatible HTTP service with lifecycle controls.
- Tools: built-in tools, static Skill packages and remote MCP, with authorization, user approval and persistent invocation records.
- Offline speech: ASR/TTS, recording/audio input, speech models and queued jobs with saved results.
- Diagnostics: unified application/runtime logs, filtering and export.

## Tech Stack

| Area | Technology |
|---|---|
| Application | Dart, Flutter, Material 3; Android arm64 |
| State and networking | Provider, Dio |
| Business storage | Drift/SQLite; Hive only for read-only legacy import |
| Settings and credentials | SharedPreferences, flutter_secure_storage |
| Local LLM | llama.cpp via a bundled `llama-server` child process; MNN via the `mnn_engine` Flutter plugin |
| Offline speech | sherpa-onnx, CrispASR; recording/playback plugins |
| Platform integration | Kotlin bridges, native libraries and Android foreground services |

Dependency versions are defined in `pubspec.yaml` and the lockfile. Native source pins and artifact metadata live in the corresponding manifests/build documentation.

## Architecture and Directories

The application is feature-first:

```text
lib/
  main.dart     Application entry and initialization
  app/          Bootstrap, navigation and app-scoped composition
  features/     Chat, assistants, server, downloads, agent, speech, logs and settings
  core/         Database, security, logging, model repositories and engine runtime
  shared/       Reusable UI, theme and presentation utilities
  l10n/         ARB localization sources and generated bindings
android/        Android host, platform bridges and native packaging
assets/         Bundled catalogs, icons, licenses and display metadata
native/         Native build definitions and provenance manifests
patches/        Application-owned upstream patches and build recipes
test/           Unit and widget tests
tool/           Build, packaging, generation and verification scripts
```

Pages present UI and route interactions; providers/controllers coordinate flows; services/repositories own I/O and persistence; models express typed data. Shared UI must remain independent of feature-specific business logic and design previews.

## Development Boundaries

- Engine integration: GGUF requests go through `llama-server` HTTP; MNN uses the public `mnn_engine` plugin API, never direct app calls to MNN. Keep llama.cpp adaptations in application-owned patches.
- Runtime ownership: reuse `EngineRuntimeProvider`, `UnifiedModelRepository`, `ChatRunner`, `ResourceCoordinator` and `SpeechJobService`; do not add parallel catalogs, schedulers or recovery systems. Execution/recovery is app-scoped, not page-scoped.
- Resource safety: one local LLM may coexist with speech; ASR/TTS share a FIFO. Speech must not stop the LLM to obtain resources. HTTP cancellation is not native cleanup: retain ownership until stop/unload is confirmed, retry failed cleanup, and isolate unresolved cleanup to its resource domain.
- Model selection: chat targets and published local serving are separate. Selection belongs to the owning assistant; history restoration must not change global assistant selection. Do not silently fall back from missing/disabled targets or replace a different published LLM.
- Data integrity: keep one business database and reuse existing repositories. Migration precedes business initialization; Hive remains read-only. Commit related message/revision/Run changes together, preserve referenced history, and clean owned files only after record transactions commit.
- Authority: freeze Run/job inputs and revalidate current model/tool permissions before side effects. Capabilities belong to individual models. Interrupted requests and unknown tool outcomes must not replay automatically; profiles/avatars are display-only.
- Product scope: Skills are static resources and MCP uses remote HTTP/SSE. Do not incidentally add shell execution, stdio subprocesses or platform automation. Speech is internal, not an HTTP API or cloud-forwarding service; preserve native watermark/provenance behavior.
- Privacy and consistency: reuse `AppLogger`/`FileLogSink` with bounded retention. Log lifecycle metadata, not prompts, responses, tool payloads, audio, paths or credentials. Store credentials securely, preserve shared UI/localization patterns, and avoid unrelated refactors or unsolicited dependency changes.

## Development and Verification

- Run `flutter analyze` and relevant `flutter test` cases. Add unit coverage for business changes and focused widget coverage for interaction changes.
- Never hand-edit generated files. Use localization/database generators; `build.yaml` limits database generation and preserves frozen Hive adapters.
- Build APKs through Flutter and verify manifest/version, signing and native contents with `tool/verify_android_bundle.py`. Build success does not establish hardware/model/provider correctness; report unexecuted checks explicitly.
- Keep local `pubspec_overrides.yaml`, application `.so` files, model weights and build caches out of commits. Follow native packaging documentation when changing binaries or build configuration.

## Further Reading

All paths below are relative to this repository.

- `pubspec.yaml` and `pubspec.lock`: dependencies and resolved versions.
- `lib/core/database/app_database.dart`: business database schema.
- `llama-server-README.md` and `patches/llama.cpp/README.md`: server integration and native builds.
- `native/speech/` and `tool/build_speech_native.ps1`: speech native build definitions and provenance.
