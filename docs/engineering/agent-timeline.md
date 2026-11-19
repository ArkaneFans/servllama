# Agent activity in chat

## Display and ownership

Each generated reply retains the order of visible reasoning, prose and validated
tool calls. Consecutive reasoning/tool steps form one activity card; visible prose
ends that card. A later model round can produce another card before its answer.
Cards have vertical connectors, per-step details and elapsed times. More than two
steps collapse to the last two by default. Everything from the first queued,
pending approval, executing or unknown-outcome receipt stays visible.

Reasoning shows a bounded 100 dp preview while streaming and can expand to full
Markdown. Finished reasoning starts collapsed. Tools reuse `ToolInvocationCard`
for arguments, saved results, search sources, approval and ask-user controls.
Execution time excludes approval waiting. Small expansion state is held in
`PageStorage`; timers and render objects belong to mounted widgets.

`ChatRunner` remains the only model/tool loop. `AgentToolService` remains the tool
and approval owner. The view neither invokes nor replays tools. Opening history,
switching message versions or refreshing a receipt cannot resume execution.

## Revision data

Database schema 3 adds `message_revisions.timeline`, a JSON list of typed metadata:

- Text/reasoning ranges use UTF-16 offsets into that revision's existing
  `content` / `reasoning_content` bodies. Text is not copied into timeline JSON.
- Reasoning also carries start/end timestamps. A model-round boundary or a text
  delta closes the current reasoning step. Adjacent tokens extend one range.
- Tool entries carry a call ID and name; the selected revision's Run plus call ID
  identifies the existing `tool_invocations` row. Arguments/results are not copied.

Tool references become visible after the existing protocol client has completed
the model round and validated the complete call arguments. All calls in a round
are referenced before the first invocation. This includes queued calls that may
never execute after cancellation. A missing receipt is displayed as queued during
generation or as having no saved execution record in history.

The existing draft checkpoint commits both bodies and timeline metadata together.
Finalization keeps the same metadata in the immutable message version. Switching
versions loads that version's ranges and receipts; editing a response creates a
plain version with no Run or timeline while preserving its original versions.
Timeline metadata is excluded from prompt continuation keys and protocol traces.

Startup recovery commits saved partial ranges without replay. Unfinished reasoning
settles at the last Run checkpoint time, avoiding a timer that includes time while
the app was closed. Receipt recovery still maps executing to `unknownOutcome` and
unexecuted/approval states to `cancelled`. A receipt committed beyond the latest
timeline checkpoint remains inspectable in a trailing activity block.

## Projection and history

`projectChatTimeline` is pure: ordered revision metadata + scoped receipts →
text/activity blocks. It checks complete, contiguous coverage of both bodies and
matches tools by Run/conversation/call ID. Malformed ranges fall back to the
existing reasoning/tools/body order, preserving content without guessing order.

Schema 1/2 upgrades give old revisions an empty timeline. Those messages retain
the existing display. New replies use ordered blocks, including replies without
tools. `ChatToolActivity` shares its live/history loading with the timeline view:
one history read on mount or when a live tool session closes, with explicit retry;
body tokens and expansion do not cause database reads. Body rendering remains
available if receipt loading fails. Delayed reads are scoped to the selected Run.

## Implementation and verification

| Area | Path |
|---|---|
| Ranges and per-generation builder | `lib/features/chat/models/chat_timeline.dart` |
| Ordering/round boundaries | `lib/features/chat/controllers/chat_runner.dart` |
| Revision writes and reads | `lib/features/chat/repositories/chat_record_store.dart` |
| Atomic checkpoints and recovery | `lib/features/chat/repositories/generation_run_repository.dart` |
| Pure grouping and collapse policy | `lib/features/chat/presentation/chat_timeline_projection.dart` |
| Activity, connectors and reasoning | `lib/features/chat/widgets/chat_agent_timeline.dart` |
| Scoped receipt source | `lib/features/chat/widgets/chat_tool_activity.dart` |
| Shared tool details and approval | `lib/features/agent/widgets/tool_invocation_card.dart` |

Focused tests cover multi-round order, immutable streaming snapshots, scoped tool
updates, folding around approvals/unknown outcomes, cancellation, recovery,
version/edit behavior, schema 1/2 upgrades, receipt loading and narrow light/dark
layouts with enlarged text. Set `TIMELINE_PREVIEW=true` with Flutter's
`--dart-define` when running `chat_tool_activity_test.dart` to save fixture previews
under `.dart_tool/`; these contain synthetic data only.
For readable local fixture images, also pass `TIMELINE_PREVIEW_FONT` pointing to
an installed font with the needed character coverage. This is preview-only and
does not add a font asset or dependency to the application.

Device/provider verification should additionally exercise a real multi-round
tool response, MCP approval/rejection, cancellation while a tool executes, app
restart and switching older message versions. Build success and fixture previews
do not establish real provider behavior.
