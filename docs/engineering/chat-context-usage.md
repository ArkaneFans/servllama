# Chat context usage indicator

The composer ends with a 48 dp touch target containing a 32 dp context ring.
The percentage is **actual-data only**. Missing usage or capacity is the literal
ASCII `-`, never an estimate, a zero, or a model-catalog guess.

## Measurement and validity

- `GenerationMetrics.contextTokens` is the latest model round's backend input
  plus output token count. Cached input still occupies context. Multi-round
  aggregate/billed usage must never be summed into conversation occupancy.
- This is labelled a **latest-response usage snapshot**, not a live tokenizer or
  a measurement of the unsent draft.
- Only the final assistant response in the selected conversation is eligible.
  Its model, connection and `ChatRunner.historyContextKey` must match the current
  configuration and the complete preceding message list read from the repository
  (not the paginated visible message window).
- Empty, user-only and legacy histories without an eligible measured tail
  return unknown without issuing passive database reads. An eligible visible
  tail is only a fast-path candidate: full-prefix verification is still required.
- A draft, pending attachment, active generation, modified input prefix, missing
  legacy provenance or model change invalidates the displayed count. Switching
  revisions validates the newly selected revision's own measurement.
- If input + output exceeds the backend capacity, retained context cannot be
  inferred (e.g. context shift/truncation), so the usage becomes unknown rather
  than displaying an apparently actual percentage above 100%.

## Capacity

Only a matching running local llama.cpp runtime is probed. `GET /props` supplies
`default_generation_settings.n_ctx`, which is already a **per-slot** capacity and
must not be divided by `total_slots`. The probe is bounded to three seconds, does
not follow redirects and sends the runtime credential only to its own loopback
endpoint. Failures remain unknown and do not break chat.

Capacity is keyed by endpoint, model and runtime start time. The async indicator
also guards every result with the conversation/input key and an operation epoch,
so late results cannot restore a previous model or conversation's percentage.

MNN and remote provider capacity is currently unknown. MNN's `max_new_tokens` is
an output limit, while `max_all_tokens`/`max_position_embeddings` do not establish
an enforced runtime context capacity. No manual context budget is presented as
backend data. A future backend-specific capability may be added only if it
reports an authoritative capacity.

## Verification

Focused coverage lives in:

- `test/features/chat/chat_context_usage_test.dart`
- `test/features/chat/services/context_capacity_client_test.dart`
- `test/features/chat/widgets/chat_context_usage_ring_test.dart`
- `test/features/chat/widgets/chat_context_indicator_test.dart`
- `test/features/chat/providers/chat_context_provider_test.dart`

The ring tests cover 320/360 dp layouts, enlarged text, 48 dp send/stop targets,
actual detail display, unknown data, warning colors and dismissal. Setting
`--dart-define=CAPTURE_CONTEXT_UI=true` writes visual QA PNGs to
`build/context-ui/`; this optional capture uses locally installed Noto CJK fonts.
