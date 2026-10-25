# Cold start and bounded idle preparation

## Three boundaries

1. `main` admits business data before `runApp`: legacy migration checks,
   message storage and interrupted Run/tool recovery. Pending migration and
   admission failures use the existing visible `BootstrapGate` with explicit
   retry. Migration still precedes construction of business providers.
2. `ServLlamaApp` immediately displays `MainScaffold`, as on main. Locale,
   theme, timeout, runtime status and assistant/provider metadata restore
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

Provider keys are read only on editor/request demand. Those reads share a
single flight per secret reference. Verified saves populate the process-local
cache, while rotated/deleted references invalidate old cache entries. Missing
or unreadable storage is never cached as an empty secret. Existing editor
readiness and stable API Key rendering remain intact; persistence is guaranteed
by secure storage, not by prewarming or retaining the process.

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
Locale/theme/timeout edits similarly join their initial read, so an early edit
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

`StartupTask` emits typed phase/task/elapsed metadata and Dart timeline spans,
never keys, payloads or private paths. `app.startup.interactive` records the first
business frame's post-frame callback, including ordinary admission. It does not
mean every business field/cache is ready, Android's window draw or GPU raster
completion. Migration/manual retry must be measured separately.

Regression coverage blocks business reads while checking homepage first paint,
module-local error behavior, migration/retry visibility, coalesced early demand,
durable credential reads, typed-draft preservation and early native ownership
restoration. SVG tests still capture actual RGBA pixels for every bundled mark
in both palettes and compare with `SvgPicture.asset`, including demand/reentry.

Those host tests are not sufficient for the Release compiler: flutter_svg
2.3.0 compiles synchronously in Debug and uses a real isolate in Release.
`tool/verify_bundled_svg.dart` is a separate Release-only entrypoint that primes
real bundle string caches, then checks actual rendered alpha pixels for every
mark in both palettes, demand coalescing, route reentry and fallback colors.
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
gestures, background/resume and ongoing generation. Use DevTools and exported
startup spans; `am start -W` alone cannot establish business readiness. Removing
application-level waits does not imply zero native icon time or prove a measured
hardware improvement. Host tests/build audits do not replace device validation.
