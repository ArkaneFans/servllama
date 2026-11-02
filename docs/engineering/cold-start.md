# Cold start and bounded idle preparation

## Three boundaries

1. `main` admits business data before `runApp`: one-time credential migration, legacy migration checks,
   message storage and interrupted Run/tool recovery. Pending migration and
   admission failures use the existing visible `BootstrapGate` with explicit
   retry. Migration still precedes construction of business providers.
2. `ServLlamaApp` immediately displays `MainScaffold`, as on main. Locale,
   theme, timeout, chat display preferences, runtime status and assistant/provider metadata restore
   independently without a whole-app readiness future. `AppProviderScope`
   only composes the existing owners; it performs no I/O or readiness gating.
   `ChatPage` starts its draft/history read after the first frame, without
   automatically prefetching message bodies.
3. `AppIdleWarmup`, above the Navigator, prepares a finite set of small local
   caches after paint. Routes can always use the same loaders on demand.

There is no `AppStartupState.prepare`, `AppStartupGate`, explicit
`deferFirstFrame`/`allowFirstFrame`, splash preserve/remove callback, arbitrary
startup delay or minimum splash duration. Flutter and Android own native
launch-screen removal; native launch icon assets are unchanged. Restoring the
launch theme does not animate as a user theme change. Because settings load
asynchronously, the first frame may use system locale/theme before restoration,
just as main does. Fast homepage paint takes priority over an all-ready frame.

## Independent restoration and early interaction

Assistant restoration uses database model-asset rows (`reconcile: false`), not
filesystem inventories or native initialization. Missing/disabled references
are still validated. A model picker/import/delete uses the authoritative
existing repositories and explicit asset refresh; cached rows do not establish
that a model can actually be loaded.

`AssistantProvider.ensureLoaded` shares its initial metadata read with route
loads. Mutations join that read before changing settings. The provider publishes
its restored fields together; a provider/profile page entered early shows only
its own loading/retry state and does not expose empty editable settings as if
restoration had completed. A module failure does not close unrelated routes.

Only first-use assistant seeding joins locale restoration to resolve its name
from ARB. Existing assistant snapshots do not wait for that label, and the
homepage remains ungated. The localized initial name is persisted as ordinary
editable assistant data; language changes never rename existing assistants.

Provider keys and MCP headers now persist inside their existing SQLite config
rows. Download tokens and the local HTTP service key persist with their existing
Preferences. These are app-private files, not application-level encrypted stores;
Android backup remains disabled. Log redaction and credential-free Run snapshots
remain independent privacy boundaries.

The shared provider/server snapshot contains its credentials. Editors initialize
controllers synchronously from it, including known empty values for new entries;
there is no separate secret-reference lookup, credential cache or editor
credential-loading state. This avoids both empty-key first frames and the MCP
buttons' unnecessary disabled-to-enabled 200 ms foreground animation. Real
save/connect operations retain their existing busy states and normal animations.
An omitted provider key edit preserves it; explicitly clearing the field saves
an empty key. A repository-owned credential revision advances only when the key
changes, revoking frozen requests even if a key is changed away and back. MCP
header changes replace stale connections; unrelated edits still reuse them.

`CredentialMigration` runs in existing database admission before business
providers or MCP startup. It reads the old encrypted-Preferences namespace once,
moves referenced provider/MCP credentials into their existing config rows and
service/download values into Preferences, then cleans the old namespace and
publishes `inlineCredentialsComplete`. Config rows commit together; failed
Preferences writes, SQL commits and cleanup remain retryable without overwriting
already migrated values. Missing referenced credentials or malformed headers
fail admission rather than becoming empty settings. Retry uses `BootstrapGate`,
not a new gate or idle task. Later launches only check the completion marker;
ordinary business code never uses the secure-storage plugin. The dependency is
temporarily retained solely so existing installs can migrate, and can be removed
after the supported upgrade window. Downgrading to the old credential format is
not supported.

Drafts and assistant metadata may finish in either order. Saved drafts merge
without overwriting new input; text typed before the owning assistant is known
moves to that assistant's draft and takes precedence over an older saved value.
Sending and assistant/model selection stay locally unavailable until their
required draft/assistant state exists. Conversation creation registers its
single-flight lock before awaiting restoration.

Runtime operations join `ensureRestored` before using persisted engine/model
selection or native ownership. Local-chat startup also waits before deciding
whether to reuse/stop a resident model. Restoration never loads model weights,
starts an idle server, changes the assistant's target or replays a Run. MNN
restoration reads service status, not `initializeEngine`. Explicit start and
native cleanup retain the existing cancellation and resource-lease boundaries.
Locale/theme/timeout/chat-display edits similarly join their initial read, so an early edit
cannot later be overwritten by restoration.

## Background services and idle work

Real services are not optional prefetch. After paint, existing download
metadata/restoration and MCP startup begin independently. They do not wait for
history, queue order or user inactivity. Download display-name reservations
restore in memory; allocation and final commits still check real collisions.

The sequential idle plan contains only:

- Server configuration, the small Skill list and About metadata.
- Bundled AI/MCP/app SVG bytecode, one variant per slot, in the current palette.
  Other palettes/consumers load through the same bounded cache on demand.
- Pending owned-file deletion intents, last. This is durable maintenance,
  not a scan of installed models or chat history. Failed intents survive exit.

Model inventory scans, installed-model lists, speech initialization, discovery
catalogs, recent message windows and historical logs are no longer part of the
launch plan. Their existing page/operation loaders remain demand-driven. Speech
entry recovers interrupted jobs before execution without automatically replaying
them. Logs join the existing bounded single-flight historical read when opened.
Explicit refresh after a mutation must still read fresh state rather than
reuse an older prefetch.

Every idle step waits beyond a requested frame and checks Flutter's idle
scheduling strategy. Gestures, animations, generation, message loading, engine
transitions, imports and active audio/jobs take priority. Backgrounding defers
the next step; resuming continues. Disposal abandons pending steps, but in-flight
I/O settles under its original owner. Optional failures are isolated and are
attempted once; demand loaders/explicit retry own recovery. There is no second
business scheduler, offstage page tree or unbounded native warming.

The SVG cache holds compiled `ByteData` only. Official `SvgPicture` owns GPU
picture decoding, fitting and disposal; no retained app-owned painter is used.
Ready bytes are available synchronously, while demand consumers join compilation
and keep stable dimensions. Current-theme preparation is an optimization, not a
requirement for correct first-frame rendering.

The monochrome MCP mark uses one neutral compiled shape and framework paint-time
tinting. Both fixed `onSurfaceVariant` (settings/list) and `outline` (empty state)
colors in the light/dark palettes use this shared loader. Preparing or displaying
either consumer also prepares the other, even before idle warmup reaches the
mark; size and tint changes do not start a second compilation. Other, potentially
multicolor logos retain color-aware compilation and unsupported tints retain the
framework fallback. This adds no startup gate, extra MCP warmup slot or app-owned
GPU picture cache.

Asset reads stay on the UI isolate. Only SVG XML bytes and the immutable color
theme enter flutter_svg's compiler, via `SvgBytesLoader`. Do not pass a live
`rootBundle`/`CachingAssetBundle` to the compiler's `SvgAssetLoader`: in the
resolved flutter_svg 2.3.0, its Release compute closure captures that loader,
including the bundle's unsendable cached Futures. Ordinary `loadString` calls
can therefore make every later explicit-bundle SVG load fail. The library's
pending cache also retains failed loads, so reopening a page cannot repair it.
This is a compilation/isolate boundary, not a GPU picture lifetime problem.

## Reference and verification

The launch priority now follows ServLlama main, rather than copying Kelivo's
pre-runApp business snapshot. Kelivo normally admits its database and loads one
shared `BusinessPreferences` snapshot before `runApp`, then projects provider
state and initializes chat locally without a whole-app page readiness gate.
We borrow that shared-owner/local-boundary principle, not its storage layout.
RikkaHub's shared state and startup profiling offer similar boundaries, but its
Kotlin/Compose Baseline/Startup Profiles are not a Flutter loading mechanism.

Successful background restoration and idle preparation emit no per-task timing
logs or Dart timeline spans, and there is no first-frame timing log. Existing
business initialization diagnostics remain; `StartupTask` records only failures
with phase/task/error-type metadata, never keys, payloads or private paths.
Migration/manual retry must be measured separately.

Regression coverage blocks business reads while checking homepage first paint,
module-local error behavior, migration/retry visibility, coalesced early demand,
inline credential restoration/migration, typed-draft preservation and early native ownership
restoration. SVG tests still capture actual RGBA pixels for every bundled mark
in both palettes and compare with `SvgPicture.asset`, including demand/reentry.

Those host tests are not sufficient for the Release compiler: flutter_svg
2.3.0 compiles synchronously in Debug and uses a real isolate in Release.
`tool/verify_bundled_svg.dart` is a separate Release-only entrypoint that primes
real bundle string caches, then checks actual rendered alpha pixels for every
mark in both palettes, demand coalescing, route reentry and fallback colors.
MCP checks also cover both real consumer tints, shared compiled bytes and unchanged
rendered RGBA colors rather than merely accepting an eventually visible fallback.
It opens no business database or settings. On an idle test device, build it with:

```text
flutter build apk --release --target-platform android-arm64 --target tool/verify_bundled_svg.dart
```

Verify matching signing before `adb install -r`, then look for `SVG_VERIFY PASS`
in logcat. Afterwards rebuild the normal `lib/main.dart` Release APK and reinstall
with `-r`. Never uninstall or clear application data just to run this check.

Compare release builds on the same device/data over multiple ordinary cold
starts. Check both homepage latency and immediate provider/model/speech/log
navigation before idle preparation finishes. Include input during restoration,
gestures, background/resume and ongoing generation. Use DevTools and Android
system startup traces; `am start -W` alone cannot establish business readiness.
Removing application-level waits does not imply zero native icon time or prove
a measured hardware improvement. Host tests/build audits do not replace device
validation.
