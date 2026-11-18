# Cold start and idle preparation

## Startup flow

1. `main` completes business-data admission before constructing providers:
   credential migration, legacy Hive/message-store import, independent MNN
   inventory registration, old missing-model SQL cleanup and interrupted
   Run/tool recovery. Pending Hive import uses `BootstrapGate` for the existing
   choice, skip and retry flow; admission failures use the same retry entry.
2. `ServLlamaApp` displays `MainScaffold` while locale, theme, timeout, runtime
   status and assistant metadata restore independently. `AppProviderScope`
   composes the owners without I/O or a combined readiness gate. `ChatPage`
   loads history after its first frame with `preloadMessages: false`.
3. After paint, download restoration and MCP startup begin independently of
   user inactivity. `AppIdleWarmup`, above the Navigator, then runs the finite
   optional preparation plan described below.

Ordinary launches check durable migration markers. MNN registration remains
independent of the Hive import choice, reads plugin metadata without initializing
inference, and commits its marker with the SQL registrations. Missing-model
cleanup follows registration and preserves model files, speech assets and
history. Credential migration finishes before business providers or MCP startup;
normal configuration reads then use the existing SQLite/Preferences snapshots.

Flutter and Android own launch-screen removal. The app adds no first-frame
hold, minimum splash duration or startup delay. The initial frame may use system
locale/theme; applying the restored theme does not animate as a user change.

## Restoration and early interaction

Each owner shares its initial read with demand callers. Settings edits join that
read so restoration cannot overwrite an early edit. Assistant/profile/provider
pages show their own loading or retry state until their snapshot is ready; a
failure leaves unrelated routes available. Only first-use assistant seeding
waits for locale restoration to resolve the initial name from ARB.

Assistant restoration and the model library share the ready-LLM SQL query.
Inventory scans and native initialization stay outside that read. Model mutations
commit registrations before refreshing providers, and operations still validate
missing or disabled references.

Runtime operations join `EngineRuntimeProvider.ensureRestored` before using
saved selections or native resource ownership. Restoration reads service status
without loading weights, starting an idle server or replaying interrupted work.
Explicit chat/server starts use the saved server configuration; model switches
use `activateModel` and the existing stop/start flow. Runtime selection and the
assistant's chat target remain separate.

Chat input stays in memory. Metadata restoration preserves text typed into the
initial input; assistant/conversation switches clear it. Sending and selection
wait only for their required metadata, and conversation creation uses its
existing single-flight guard.

## Idle preparation

The sequential plan in `ServLlamaApp._warmupTasks` contains:

- Server configuration, the small Skill list and About metadata.
- Bundled AI/MCP/app SVG bytecode in the current palette, one variant per slot.
- Pending owned-file deletion intents, last; failures remain durable for retry.

Each step waits beyond a requested frame and checks Flutter's idle scheduling
strategy. Pointer gestures, animations, generation, message loading, engine
transitions, model mutations and active speech/audio take priority. Backgrounding
pauses the next step; resuming continues. Disposal abandons pending steps while
in-flight I/O settles under its original owner. Optional failures are isolated
and attempted once; demand loaders and explicit retry own recovery.

Installed-model scans, discovery catalogs, speech initialization, message bodies
and historical logs load on demand. Speech entry recovers interrupted jobs before
execution without replaying them. Logs share a bounded historical read. Explicit
refresh after a mutation reads fresh state. Preparation reuses these owners and
caches without constructing offstage pages or adding another business scheduler.

`BundledSvgCache` stores compiled `ByteData`; `SvgPicture` owns GPU decoding,
fitting and disposal. Ready bytes are synchronous, and concurrent demand loads
share compilation. MCP uses one neutral compiled shape with paint-time tinting
for its light/dark consumers; other logos retain color-aware compilation.

Asset reads stay on the UI isolate. Only XML bytes and an immutable color theme
enter the compiler through `SvgBytesLoader`. Passing a live asset bundle to
`SvgAssetLoader` can capture unsendable cached Futures in flutter_svg's Release
compute closure. Keep this boundary covered by the device verifier below.

## Core implementation paths

Paths are relative to the repository root.

| Mechanism | Implementation |
|---|---|
| Admission and migration/retry UI | [lib/main.dart](../../lib/main.dart): `_initializeBusiness`; [bootstrap_gate.dart](../../lib/app/bootstrap/bootstrap_gate.dart) |
| Data migration | [credential_migration.dart](../../lib/core/database/credential_migration.dart), [legacy_importer.dart](../../lib/core/database/legacy_importer.dart), [unified_model_repository.dart](../../lib/core/repositories/unified_model_repository.dart): `registerLegacyMnnInventory`, `cleanupLegacyMissingModels` |
| App composition, background startup and idle plan | [app.dart](../../lib/app/app.dart): `_startBackground`, `_warmupTasks`; [app_provider_scope.dart](../../lib/app/providers/app_provider_scope.dart) |
| Idle scheduling and failure isolation | [app_idle_warmup.dart](../../lib/app/bootstrap/app_idle_warmup.dart), [startup_task.dart](../../lib/app/bootstrap/startup_task.dart) |
| Assistant and runtime restoration | [assistant_provider.dart](../../lib/features/assistants/providers/assistant_provider.dart): `ensureLoaded`; [engine_runtime_provider.dart](../../lib/core/providers/engine_runtime_provider.dart): `ensureRestored` |
| History and owned-file cleanup | [chat_page.dart](../../lib/features/chat/pages/chat_page.dart), [chat_provider.dart](../../lib/features/chat/providers/chat_provider.dart), [chat_session_repository.dart](../../lib/features/chat/repositories/chat_session_repository.dart) |
| Shared SVG bytecode and rendering | [bundled_svg_asset.dart](../../lib/shared/widgets/bundled_svg_asset.dart) |

## Verification

Focused host coverage lives in [test/app/](../../test/app/) (`app_first_frame_test`,
`bootstrap_gate_test`, `app_idle_warmup_test`, `providers/async_settings_restore_test`),
[test/core/database/credential_migration_test.dart](../../test/core/database/credential_migration_test.dart),
[test/core/repositories/mnn_inventory_registration_test.dart](../../test/core/repositories/mnn_inventory_registration_test.dart)
and [test/shared/widgets/bundled_svg_asset_test.dart](../../test/shared/widgets/bundled_svg_asset_test.dart).
Check first paint while reads are blocked, local retry, coalesced early demand,
input preservation, native ownership and idle deferral. SVG tests compare rendered
pixels in both palettes, including MCP tints and route reentry.

Host tests do not exercise flutter_svg's Release compiler isolate. On an idle
test device, build [tool/verify_bundled_svg.dart](../../tool/verify_bundled_svg.dart):

```text
flutter build apk --release --target-platform android-arm64 --target tool/verify_bundled_svg.dart
```

Install with matching signing via `adb install -r` and check `SVG_VERIFY PASS` in
logcat. Then rebuild/reinstall the normal `lib/main.dart` Release APK. Preserve
application data throughout. The verifier checks real bundle caches and rendered
pixels without opening business storage.

Compare repeated ordinary Release cold starts on the same device/data, separately
from migration or manual retry. Check homepage paint and immediate navigation,
input, gestures, background/resume and ongoing generation before warmup finishes.
Use DevTools and Android startup traces; `am start -W` alone does not establish
business readiness. `StartupTask` logs failures only; successful restoration and
warmup add no per-task timing logs. Build success does not establish device speed.
