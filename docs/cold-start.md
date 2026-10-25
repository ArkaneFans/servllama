# Cold start and bounded warm-up

## Boundaries

Startup has three small, explicit layers. Critical snapshots are listed in
`lib/app/bootstrap/app_startup_state.dart`, optional tasks in `lib/app/app.dart`;
neither is a dependency graph or a second business scheduler.

1. `main` admits business data: legacy migration, message storage and
   interrupted Run/tool recovery finish before business providers are created.
   `BootstrapGate` handles a pending migration or admission failure visibly.
2. `AppStartupState` prepares the first usable UI: locale, theme, timeout,
   runtime ownership/status, download task metadata, assistant/provider settings
   and credentials, cached model-asset rows and drafts. Independent snapshots
   overlap; chat binding follows assistant restoration. Filesystem inventories,
   history/message memberships, historical logs and SVG compilation are not
   admission conditions. `AppStartupGate` keeps required-state errors and
   preparation after a visible migration/retry closed and retryable.
3. `AppIdleWarmup`, above the Navigator, starts existing background services
   after the business frame is painted and prepares optional local caches in
   foreground idle slots. Optional failures never close routes.

Runtime restoration discovers existing native resources; it does not select a
different chat target, load model weights, start an idle server or replay a Run.
For MNN this means a service status snapshot, not `initializeEngine` or loading
the inference libraries. Native initialization belongs to an explicit engine
start, with cancellation checked before and after it. Cloud chat remains
independent of local inference startup.

Assistant restoration reads database asset rows with `reconcile: false`.
Persisted missing/disabled references are still validated and credentials are
restored before publishing editable settings. An idle inventory refresh later
detects files deleted outside the app and clears genuinely missing targets;
actual model starts continue to validate their own paths. Cached catalog rows
are display/configuration state, not proof that a model can be loaded.

## Launch presentation

Normal startup performs data admission and the small configuration preparation
before `runApp`, like Kelivo. `ServLlamaApp` adopts the exact prepared provider
instances, not another copy or another round of reads. Its normal first frame
contains the main scaffold, without a temporary loading widget tree.
Flutter and Android own native launch-screen removal. There is no application
`deferFirstFrame`/`allowFirstFrame`, splash preserve/remove callback or
keep-on-screen condition. The app does not change native launch icon assets.
The restored launch theme is applied without a theme-transition animation;
later user-initiated theme changes keep the normal animation.

A pending migration choice or a bootstrap/check failure runs `BootstrapGate`
immediately. Already-completed checks and captured failures are passed to the
visible flow instead of being repeated automatically. A required-snapshot
failure runs the app with its captured error; `AppStartupGate` waits for explicit
retry. Preparation after a visible migration also uses this gate. These flows
retain progress/retry UI and never return to a native splash or blank page.
The readiness boundary still applies after migration or retry:
business routes never expose editable placeholder settings or credentials.
This removes a transient UI, not the underlying persistence/recovery work;
there is no arbitrary timeout, delayed spinner or minimum splash duration.

## Work after the first business frame

Real background behavior is separate from prefetch:

- Interrupted range-resumable downloads resume through `DownloadProvider`.
  Its metadata snapshot is restored earlier with `startTransfers: false`, so
  the drawer and completion listener exist before network work starts.
  Pending display-name reservations are restored in memory without inventory
  scans; new allocations and final model commits still check real collisions
  through the existing name coordinator and authoritative model stores.
- MCP sessions start through the existing app-scoped connection manager.
  Remote connection completion is not part of readiness or cache warm-up.
- Initial session history starts after first paint, without preloading bodies.
  Draft input is already ready. Routes share the initial read, and new sessions,
  renames and deletions made while it is pending are merged over its older
  snapshot. The optional plan follows this read so it can choose actual recent
  sessions. Disposal suppresses late state notifications.

The optional queue is finite and sequential:

- Model inventory reconciliation, server settings, installed-model display
  lists, speech initialization, bundled discovery catalogs, the Skill list and
  About metadata come first, ahead of bulk icon/message prefetch.
- Bundled AI/MCP/app SVG marks, one compilation per slot. Retained variants are the
  fixed light/dark palette colors and the app mark, not interpolated animation
  colors or arbitrary user tints.
- Initial message windows for at most four recent sessions. They reuse the
  existing eight-entry cache and its per-window message/text budgets. Full
  histories and attachment decoding are never prefetched.
- Durable owned-file cleanup and historical logs come last. Database migration
  and interrupted Run/tool recovery remain admission work. Deferred cleanup
  retains its transactionally stored intents across process termination.

Every optional step waits past the next requested frame and checks Flutter's
idle scheduling strategy. Pointer gestures, animations, chat message loading,
generation, engine transitions, model imports, audio capture/playback and active
speech jobs take priority. Pausing
defers the next step; resuming continues the queue. Disposal abandons pending
steps. Already-started I/O settles under its original owner instead of being
mistaken for cancellable native work.

This deliberately avoids timers with an arbitrary startup delay, offstage
copies of pages, unbounded prefetch and concurrent native warm-up. Idle checks
are frame-paced: Flutter's `scheduleTask(Priority.idle)` can repeatedly post
zero-delay events when denied, so it is not used for this queue.

## Demand, freshness and failure

Prewarming is an optimization, not a page's prerequisite:

- Providers keep their own single-flight/idempotent initializers. A route can
  start a missing load or await an existing one without waiting for queue order.
- Bundled SVG consumers join the same compilation future and use a stable
  size while loading. The bounded app cache holds only compiled `ByteData`;
  a value-equal `BytesLoader` supplies it to the official `SvgPicture` widget.
  Ready bytes return synchronously for first-frame rendering and remain
  available across route disposal even if the library's byte LRU is evicted.
  Unsupported tints/standalone contexts use `SvgPicture.asset`. Picture/GPU
  decoding, fitting, clipping and disposal belong exclusively to the framework,
  not to an app-owned `CustomPainter` or retained GPU-picture cache.
- Speech entry pages request the existing app-owned initializer; initialization
  recovers jobs before allowing execution and never replays interrupted jobs.
  Failed initialization can be retried without leaking partial services.
- Explicit refresh remains separate from an already-prepared read. In
  particular, a Skill refresh after an edit/import must not reuse a prefetch
  begun before that mutation. Model-asset refresh serializes a fresh read after
  any older in-flight prefetch. MCP connection refresh also remains explicit.
- Warmed chat windows use the current session record, share foreground loads
  and retain existing signature validation/deletion safeguards. Prefetch never
  changes selection, drafts, visible messages or global assistant selection.
- Opening Logs early joins the same single-flight historical read as idle
  preparation. Restored records merge chronologically with live startup events,
  without duplicating persisted live records or re-persisting history. The
  application-wide bound still applies; clearing/replacing the sink invalidates
  a pending read so old records cannot reappear after Clear.

An optional step is attempted once per app scope. There is no automatic retry
loop; feature loaders and explicit retry/refresh own recovery. Network model
search, backend capability probes, microphone permission, recording/playback,
model loading and inference remain demand-driven. Secure credential durability
is guaranteed by storage, not by process-local caches or prewarming.

## Diagnostics and verification

`StartupTask` adds `startup.<phase>.<task>` spans to the Dart timeline and logs
phase, task and elapsed milliseconds using the bounded application logger.
Failures contain typed metadata only, never credentials, paths or payloads.
`app.startup.interactive` measures entry to the first business frame's
post-frame callback, including normal bootstrap. It is not Android's first
window draw, GPU raster completion or evidence that every optional cache is ready.
Migration/manual retry runs should be analyzed separately.

For performance comparisons use the same physical device, data and release or
profile build; do not compare Debug startup with release startup. Force-stop
only after explicitly stopping any inference/recording/download work whose
interruption is not intended. Measure at least ten ordinary cold starts and
compare median/tail readiness time plus first navigation to providers, model
library, speech, discovery and About. Include immediate navigation before
warm-up completes, scrolling, background/resume and ongoing generation.
Use DevTools frame/timeline traces alongside exported startup events; Android
`am start -W` alone does not measure business readiness.

The design borrows Kelivo's data-admission/shared-snapshot boundaries, and
RikkaHub's shared-state and startup-measurement separation. Kelivo's normal
`main` finishes database admission and loads `BusinessPreferences` before
`runApp`; it only constructs a progress app when restore/migration needs it.
Its `SettingsProvider` projects that shared state without making every page
catalog/history/icon a whole-app readiness condition. ServLlama follows that
lightweight approach, retaining its own local-resource ownership checks and
interrupted-work recovery rather than copying Kelivo's architecture.
RikkaHub's ART Baseline/Startup Profiles optimize Kotlin/Compose paths; they
are not a substitute for Flutter data readiness or SVG bytecode preparation.
Android's process/Flutter engine/first raster startup still has a cost. Removing
the artificial waits does not imply zero launch-icon time, and release-build
changes require physical-device timing before claiming a measured speedup.

Regression coverage verifies unmounted/single-flight configuration preparation,
adoption of prepared instances in the business first frame, ordinary startup
without a frame hold/preparation animation, migration visibility, captured
failures without automatic replay and explicit retries.
SVG tests capture actual first-frame RGBA pixels for every bundled mark in both
palettes, check nonempty alpha, and compare with `SvgPicture.asset`. Demand loads,
route reentry and disposal during compilation are covered too. These host
raster tests do not substitute for Android/Impeller hardware validation.
Additional tests cover snapshot-only assistant loading, lazy log-history
merging/clearing, concurrent history mutations, deferred durable file cleanup,
and ownership restoration without MNN initialization.
