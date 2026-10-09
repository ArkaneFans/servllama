# ServLlama AGENTS Guide

## Project Overview

- `ServLlama` is an Android AI application with local/cloud chat, assistants, bounded tools, static Skills, remote MCP and offline speech. Local LLM HTTP serving remains available.
- Develop ServLlama on `feature/2.0` in the original `servllama` checkout. It uses unpublished `mnn_engine` 0.2.0 from the sibling `mnn_engine` checkout on `feature/0.2.0`. Keep the local `pubspec_overrides.yaml` out of commits.
- Application diagnostics use the existing `AppLogger` / `FileLogSink` and `features/logs`. Keep one global bounded cache, and record client/agent/speech lifecycle metadata without prompts, responses, tool payloads, audio, paths or credentials. Do not introduce a parallel logger or database.
- The project follows a feature-first structure.

## Tech Stack

- Language: `Dart 3`
- Framework: `Flutter`
- UI: `Material 3`
- Platform: currently focused on `Android`, with bundled `llama-server` binaries
- Persistence: one `Drift/SQLite` database for business records, `SharedPreferences` for simple settings/local profile, `flutter_secure_storage` for credentials. Hive remains a legacy import source; do not resume dual writes.
- Do not restore pre-release conversation inference, provider model backfill, workspace grant conversion or orphan-run migration scans. Retain 1.x Hive import, independent completion markers, runtime recovery and registered-file deletion retries.
- Schema 5 stores GGUF details in `model_assets.manifest.gguf` through `GgufModelStore` and language-model transfers in `download_tasks`. Do not add a second GGUF catalog or overwrite its details during MNN asset reconciliation. `LegacyImporter` migrates before application providers start; chat and inventory completion markers are independent. Keep retained Hive files read-only and keep dependency versions unchanged unless explicitly requested.
- State management: `provider`
- Networking: `dio`
- Dependencies: `path_provider`, `file_picker`, and others (see `pubspec.yaml`)

## llama-server Integration

- This project bundles `llama-server` for GGUF and uses `mnn_engine` for MNN; never call MNN directly from the app.
- The Flutter app does not implement model inference directly; it communicates with `llama-server` over HTTP APIs.
- `llama-server` is responsible for model loading, inference execution, request handling, and the core inference lifecycle.
- The Flutter app is responsible for service startup orchestration, parameter configuration, status presentation, error handling, and user interaction.
- When making changes related to `llama-server`, clarify the boundary first:
  - whether the change belongs to service process management
  - whether it belongs to API parameter adaptation
  - whether it belongs to model discovery and path management
  - whether it belongs to Flutter UI presentation and interaction logic
- If you need to adjust `llama-server` startup arguments, port, model path, context length, thread count, or similar settings, encapsulate them in the service or repository layer first. Do not scatter these details across page-level code.
- For detailed `llama-server` usage, see `llama-server-README.md`.

### Binary Maintenance

- `llama-server` binaries ship as jniLibs (`android/app/src/main/jniLibs/arm64-v8a/`). The `.so` files are **not** tracked in git; copy them from a Snapdragon WSL build or a release bundle. See `patches/llama.cpp/README.md`.
- The server executable is packaged as `libllama-server.so` and executed from `nativeLibraryDir`, with `LD_LIBRARY_PATH` and `ADSP_LIBRARY_PATH` pointing at that directory (plus vendor OpenCL / FastRPC paths).
- Every bundled file must be named `lib*.so`, otherwise AGP silently excludes it from the APK.
- Keep `packaging.jniLibs.useLegacyPackaging = true` in `android/app/build.gradle.kts`. The server runs as a child process and must exist as a real file on disk.
- OpenCL (`libggml-opencl.so`) and Hexagon (`libggml-hexagon.so` + `libggml-htp-v*.so`) are part of the Snapdragon bundle. Do not NDK-strip the HTP kernels.
- Hexagon empty-device fix is a project patch on llama.cpp **v0.4.1**: `patches/llama.cpp/0001-hexagon-skip-unsupported-devices.patch`.
- Offered llama.cpp backends are `ServerLaunchSettings.supportedLlamaCppBackends` (currently CPU and Hexagon). OpenCL stays compiled but is not offered. The device probe only enables or disables entries in that list.
- When updating llama-server, replace the `.so` files AND sync the version in `assets/bin/llama_server_manifest.json`. The manifest is display-only (About page) and is not validated against the binaries.

## Runtime and Speech Boundaries

- Keep one `ChatRunner` for ordinary chat and tool loops, one `ResourceCoordinator` for local residency, and one `SpeechJobService` FIFO. Do not add overlapping schedulers or model registries.
- Chat cancels through HTTP for every provider. Keep MNN request ownership inside its HTTP server; do not add private request headers, per-request MethodChannel APIs or chat-side native polling.
- Reuse `EngineRuntimeProvider`, `UnifiedModelRepository`, `ModelDownloadService`, and the foreground-service owner API. Local/cloud chat and a published LLM may run alongside speech. Keep separate LLM and speech leases in `ResourceCoordinator`; ASR/TTS still share one FIFO. Speech must never stop or cancel chat/the LLM service to obtain residency.
- Check adapter `hasResources`, not only HTTP `isRunning`, before releasing the LLM lease. Failed stop/unload retains only LLM ownership and permits an explicit stop retry; speech remains independent.
- A cancelled native call still owns its lease until cleanup is confirmed. Never kill an isolate and immediately declare its model unloaded; quarantine only its resource domain until process restart. Do not block starts using memory/thermal pressure signals or timers. Model starts proceed after confirmed cleanup; retain residency ownership and cleanup quarantine.
- A conversation owns only assistantId; Assistant.chatTarget is its shared current model selection. Chat selection updates that owning assistant for all its conversations. Missing/deleted/disabled models resolve to no selection; never fall back to previous conversations or the local runtime. AssistantRepository owns atomic target changes/clearing, ChatSessionRepository owns conversations; never restore a historical conversation by mutating AssistantProvider.activeId.
- Provider presets have stable IDs and cannot be deleted. Reuse AiConnection/ai_connections for enabled state and the explicitly saved model list; endpoint discovery supplies candidates only. Authorize remote Runs against both enabled state and model membership.
- AssistantRepository owns provider ordering through sortOrder in the existing connection config: new providers prepend, missing presets append in declaration order, and edits preserve position. Provider pages and model pickers consume this order; keep catalog position out of Run snapshots. Do not add a separate ordering store or pre-release backfill.
- Image/tool capabilities belong to each saved model in `AiConnection.modelCapabilities`. Use `ChatRunConfig.capabilities` for generation and revalidation; do not restore provider-wide switches. New models added in the editor start as text-only, while legacy flags are read into existing model entries. Configuration/model tabs share one provider draft.
- Local providers are views of UnifiedModelRepository and EngineRuntimeProvider, not another stored catalog. The chat model sheet selects and starts through ChatProvider; assistant-editor selection never starts a service, and chat must not replace a different published LLM.
- Delete assistants through ChatProvider.deleteAssistant. ChatSessionRepository deletes the assistant, currently owned conversations and persisted drafts in one transaction before cleaning owned files; transferred conversations and independent speech data remain. Never add a configuration-only assistant deletion path or automatically purge legacy missing-assistant conversations.
- Assistant configuration uses one editor draft for identity, instructions and local-tools/Skills/MCP tabs. Saving commits the draft once; returning discards it. User profiles are display-only and must not enter new model requests or Run snapshots. Retired profile grants are ignored; internal generation and execution bounds remain.
- Run/job inputs are frozen snapshots. Revalidate current authority before side effects. Interrupted requests, tools with unknown outcomes and speech jobs must not replay automatically.
- Inline tool activity belongs to the selected message version's Run, not the latest conversation Run. Reuse AgentToolService and ToolInvocationCard for chat and the activity page; retain tool-only replies on cancellation/recovery.
- Message/version deletion commits the selected body, revisions, conversation index, unreferenced Runs/receipts and attachment tombstones together. Use ChatProvider/ChatRunner and ChatSessionRepository.commitMessageDeletion; never retain orphan receipts as a conversation archive or recreate deleted messages from checkpoints.
- Conversation workspaces and built-in list_files/read_file/write_file are retired. Keep only registered legacy-file cleanup; do not add a workspace compatibility layer. Static Skill resource reads, remote MCP, image attachments and speech files keep their own boundaries. Tool results are bounded text receipts (16 KiB UTF-8 including truncation notice), not workspace artifacts.
- Skills are static text/resource packages. MCP supports remote HTTP/SSE. Do not add shell execution, stdio subprocesses or platform automation as an incidental extension.
- ASR/TTS are internal only. There is no speech HTTP API, cloud voice forwarding or Agent service endpoint.
- Speech forms and voice previews stay on their current page after enqueue. Reuse `SpeechJobResult` for inline progress/results and task details; pages retain selected job IDs only, while `SpeechJobService` owns execution and persistence. A newly opened speech page starts without historical results; only the task list restores history. Show ASR edited text or frozen TTS source with creation time, without displaying raw input snapshots.
- Speech uses pinned sherpa and Crisp bindings. Build Crisp with `tool/build_speech_native.ps1`, maintain `native/speech/android-arm64-v8a.json`, and retain upstream watermark/C2PA behavior. Keep native sources/builds in ignored `native-cache/`.
- All Android build types must filter to arm64-v8a; Flutter build-type defaults can override a defaultConfig ABI filter. Use `tool/verify_android_bundle.py` on the final APK, preserving DSP kernels unchanged.
- Input copies, model packages, reference voices and generated results have separate owners. Check live references and commit deletion state before removing files; never scan arbitrary paths to guess disposable data.
- Keep human-readable UI in ARB, and regenerate localization normally. Keep secrets out of SQL payloads, logs, test fixtures and exported reports.

## Development Practices

- Put new business logic under `lib/features/<feature>/` whenever possible.
- Use `lib/app/` for app entry, route assembly, and app-level composition. `MainScaffold` is the chat root with sidebar navigation; `ModelLibraryPage` composes language/speech model tabs. Keep providers and job recovery app-scoped when opening or closing routes; do not make recovery depend on an offstage page.
- Use `lib/core/` only for foundational capabilities shared across features.
- Use `lib/shared/` for reusable UI components and shared presentation utilities.
- Do not add extra entities unless necessary. Avoid defensive programming and do not design for hypothetical future requirements.
- Put user-facing strings in ARB localization files. Do not hard-code display text in Dart code.

## Shared Presentation

- Empty chats use the same greeting and server/ASR/TTS welcome shortcuts regardless of model selection or runtime readiness. Keep navigation in ChatPage and presentation in ChatConversationHero; shortcuts do not start inference or mutate chat targets.

- The chat server shortcut always reflects the local runtime, including with remote chat targets. Its engine/model start flow must not write ChatTarget; explicit stopping controls the current local service. Profiles contain only name/avatar/description and remain display-only.

- Use `FormListView` for multi-field forms with 16 dp gaps; do not add duplicate fixed gaps between its direct children. Chat and search controls use their own layouts. Tool receipts are view-only with optional inline approval/answer; there is no receipt export action.
- Group related editor fields with `SettingsSection.form` (18 dp surface, 16 dp inner padding/gaps) and use 20 dp page gutters. Inherit the shared input theme; avoid private field borders/fills or floating multiline placeholders. Keep help text in `bodySmall` and retain top messages, navigation focus cleanup and touch feedback.

- The application uses the mist-violet `AppVisualTheme` through `AppTheme`; tea is gallery-only. Keep shared UI independent of `features/design_preview`.
- Use `AppScaffold` for regular pages and `AppMessage.show` for transient feedback. The body anchor keeps messages below the actual AppBar/tabs; the app navigator observer clears them on route changes. Keep durable errors and validation near the affected content.
- Shared touch feedback uses `NoSplash` with pressed state layers; retain hover/keyboard focus feedback. Do not add per-button navigation delays or restore long-lived ripples.
- `AppNavigationObserver` clears departing input focus and transient messages when the top route changes. Use `AppTabBar` for page tabs; `PushSidebar` handles focus on open/close. Release the primary input before launching native pickers, which do not create Flutter routes. Do not restore input focus on return or defer a global unfocus that could steal destination autofocus.
- Use `AiIdentityIcon` for model/provider identity; preserve textual engine, capability and readiness labels. Logos are bundled, licensed assets and never imply protocol compatibility or trust.
- Download preferences belong to `DownloadSettingsPage`, reached through the General settings group.

## Layering Rules

- The page layer is responsible for presentation, interaction orchestration, and routing.
- The state layer is responsible for page state, user action coordination, and flow orchestration.
- The service or repository layer is responsible for I/O concerns such as processes, file system access, persistence, and networking.
- Models and types should express strongly typed data only, without page logic mixed in.

## Single Responsibility

- A class, component, or module should have one clear responsibility.
- Pages must not handle low-level I/O directly.
- The state layer must not own low-level resource implementation details.
- The service or repository layer must not contain UI presentation logic.
- Shared components must not embed feature-specific business decisions.
- Shared capabilities should remain reusable, and business capabilities should have clear boundaries.

## Development and Verification

- Run `flutter analyze` before submitting changes.
- Prefer adding unit tests when changing business logic.
- Add the minimum necessary widget tests when changing page interactions.
- Business verification lives in `test/features/agent`, `test/features/assistants`, `test/features/chat`, `test/features/speech` and core tests. Record hardware/model/provider checks that were not executed; do not label them passed merely because an APK builds.
- Build APKs through Flutter so pubspec version information is refreshed. Check the actual manifest, signature and native bundle before distribution; the release build falls back to debug signing without `android/key.properties`.
- Do not manually edit generated files, including `*.g.dart` and `lib/l10n/generated/*`.
- Do not perform unrelated refactors. When touching old code, only bring it closer to the standard within the scope of the current change.
