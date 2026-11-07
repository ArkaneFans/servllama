# Generation statistics

## Presentation and persistence

Settings → Chat → **Show generation stats / 显示生成统计** controls the compact
rows below completed assistant messages. It defaults to off and is saved in
SharedPreferences without delaying the first frame. The setting affects existing
history as well as future responses; collection does not depend on visibility.

The rows show prefill/decode tokens per second and total input/output token
counts, with the cached part of input explicitly marked. Unknown cache is
**未知 / Unknown**, not zero. Missing rates are **暂无 / Unavailable**. Estimated
rates carry **估算 / estimated** per phase; actual and estimated phases can coexist.

`GenerationMetrics` belongs to each immutable message revision, not to a global
engine's most recent request. SQLite schema 2 adds nullable
`message_revisions.generation_metrics`; v1 history upgrades in place and retains
unknown statistics. Regeneration starts clean, selecting a revision restores its
own statistics, manual edits clear them, and cancelled/failed/interrupted runs do
not retain terminal statistics. Legacy Hive readers remain frozen.

## Sources and definitions

- llama.cpp completions provide the request-local top-level `timings` extension
  on their final SSE event or JSON completion. Native rates use
  `prompt_n / prompt_ms` and `predicted_n / predicted_ms`, converted to tok/s.
  Zero/negative/non-finite durations or counters cannot produce a rate.
- llama.cpp `prompt_n` counts newly processed input; `cache_n` is reused input.
  Input usage includes both. Custom compatible backends can explicitly mark
  `prompt_tokens_scope: total_input`; absent cache information remains unknown.
- Hosted `mnn_engine` 0.2.0 provides nonstreaming usage but does not emit final
  SSE usage or phase timings. Streaming MNN statistics therefore remain unknown;
  text chunks are never used to invent token counts or speeds. Nonstreaming
  token counts can be shown, but phase speeds remain unavailable without timings.
- OpenAI-compatible usage uses `prompt_tokens`, `completion_tokens`, and optional
  `prompt_tokens_details.cached_tokens`. Known zero and missing are distinct.
- Anthropic total input is `input_tokens + cache_read_input_tokens +
  cache_creation_input_tokens`; only `cache_read_input_tokens` is a cache hit.
- Gemini `promptTokenCount` already includes `cachedContentTokenCount`.
  Output counts include `candidatesTokenCount + thoughtsTokenCount` when reported,
  matching first-output detection for reasoning models.
- Counts retain provider/native tokenization semantics, including templates,
  reasoning, tool arguments, and potentially end-of-sequence tokens. They are not
  counts of visible text characters or transport chunks.

If a streaming backend lacks a valid native phase rate but reports actual token
counts, fallback estimation uses a request-local monotonic clock:

- Prefill estimate: uncached input tokens / time from request start to first
  observed output; if cache is unknown, total input is used and cache remains
  unknown. The first output includes reasoning and tool output, not empty role
  markers. This estimate includes queue, network, and first-token overhead.
- Decode estimate: `(output_tokens - 1)` / time from first output until terminal
  usage arrives. At least two output tokens and a positive interval are needed.
- Native rates always win. No token count is guessed from characters/chunks.
  A non-streaming response has no observable first-token boundary, so unavailable
  native phases remain unavailable rather than inventing a TTFT.

For a response containing tool rounds, counts and matching phase token/time pairs
are summed; a speed is a ratio of sums, never an average of rates. If any round
lacks a phase/count, that aggregate is unknown. Mixed native/estimated phases are
labelled estimated. Tool execution and approval waits are not generation time.
Each HTTP request holds its own timing/usage state, avoiding cross-request races.

## Context occupancy boundary

`contextTokens` is the final model round's actual total input plus output, **not**
the sum of tool-round billing counts. Cache tokens occupy context and are not
subtracted. It is persisted alongside model/connection identity and the request's
history context key; edits/model changes can therefore invalidate stale readings.
Speed estimates never create estimated context counts. If final-round usage is
unknown, occupancy is unknown even when earlier rounds reported usage. The
composer indicator separately requires a verified context capacity and must show
`-` rather than guessing a percentage.

## Verification

Focused tests cover native and estimated phases, missing/zero counters, unknown
cache, parallel HTTP responses, SSE-only usage tails, nonstream JSON, reasoning
and tool first-output detection, cancellation, weighted tool rounds, revision
selection/edit/regeneration, disk persistence, and schema v1→v2 upgrade.
Widget tests cover the preference, historical reactive updates, unknown/estimated
rows, and narrow/large-text layout. PNG fixtures demonstrate layout only, not
on-device inference measurements.
