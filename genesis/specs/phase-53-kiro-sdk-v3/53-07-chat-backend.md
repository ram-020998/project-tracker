# 53-07 — Chat backend on v3

> **Status:** BUILT 2026-11-12 (genesis 8139cd2 + b46c877 + 2af786f; review SHIP, round 2). SPEC-DRAFTED 2026-11-03.
> Repo: **genesis** (`genesis/chat/**`, `genesis/api/chat.py`,
> `packages/kiro-agent-sdk` v2 removal). Parent: `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D7, D10;
> F1–F4, F6, F8, F11, F15. Uses 53-02 W6, W7, W8.

## 1. Goal

Chat in every mode runs on the v3 SDK with the same API shapes the web reads (53-01 §2.2), plus steering, a Stop that
keeps the session, resume with `session/load` and an MCP failure notice. When this sub-spec is BUILT, no caller uses the
v2 path and it is deleted from the SDK (D5).

## 2. Session start (`chat/manager.py` `_ensure_started`, `:98-168`)

- **Home** (D6): `kiro_home = settings.state_dir / "kiro-home" / "chat"` (created on first use); cwd unchanged
  (`state_dir`, or the skill-output sandbox for the spec modes), so managed skills keep loading from
  `~/.genesis/.kiro/skills/` (D7).
- **Trust per mode** (F2), from `chat/mode_profile.py` + `chat/mcp.py` `build_chat_mcp` (which returns MCP tool names as
  today):
  - `read_only`: `TrustPolicy(builtins=(), mcp_tools=<read tools>, auto_approve=<read tools>, mode="auto_deny")`.
  - `copilot`: `mcp_tools=<read + control mutating tools>`, `auto_approve=<read tools>`, `mode="ask"` →
    `on_permission` (the confirm bridge, `manager.py:181-227`, unchanged; ADR-033).
  - spec-style modes (`feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`,
    `test_design`: every `PROFILES` entry with `extra_trust=("fs_read","fs_write")`, `mode_profile.py:243-283`):
    `builtins=("fs_read", "fs_write")` added to `mcp_tools`/`auto_approve` (replaces `extra_trust`),
    `fs_write_root` = the skill-output dir (L-041). Derive the policy from the profile's fields, not from a list of
    mode names, so a ninth mode gets the right agent.
- **Agent prompt:** the mode's steering text moves from "prepended to the first prompt" (`profile.steering`,
  `manager.py:243-247`) into the custom agent's `prompt` (sent once with the agent; survives `session/load`).
- **MCP readiness** (F3): a failed server → a `session.notice` event `{kind: "mcp_failed", servers: [...],
  detail}` on the first turn's stream; the turn proceeds.
- **Resume** (F4): if the chat record has `kiro_session_id` (53-03) and the client is new (idle reap, restart, after a
  model change), call `load(kiro_session_id)`. The engine's replay of old turns is not shown again and its replayed
  credits are not stored again (53-02 W6). On success no preamble is sent; on failure (logged with the classified
  error) fall back to `session/new` + today's preamble (`_build_preamble`, `:382-395`). After every `session/new`,
  store the new id with `ChatStore.set_kiro_session` (53-03; `ChatStore.create` does not write it, and the setter
  leaves `updated_at` alone so a new Kiro session does not reorder the chat list). The chat API does not return the id
  (`api/chat.py:54` lists its fields).
- **Model** (unchanged behaviour, 21-05): the session's model is applied at start with `set_config_option("model", …)`
  instead of `--model`.

## 3. Catalog (`ensure_agent_catalog`, `available_models`, `available_commands`, `:438-477`)

The throwaway catalog client uses the chat home and `TrustPolicy(builtins=(), mcp_tools=(), auto_approve=(),
mode="auto_deny")`. `models` from `config_options["model"]` mapped to today's shape `{availableModels:[{modelId, name,
description}], currentModelId}` so `GET /chat/models` is unchanged; `commands` from `available_commands_update` mapped
to `SlashCommand {name (with "/"), description, meta}`; `modes` unchanged. The cache is cleared on a kiro-cli version
change.

## 4. Turn behaviour (`stream_turn`, `:228-348`)

- **Slash commands typed by the user:** the palette lists the engine's commands; a typed `/…` is sent as a prompt only if
  the engine listed it (v3 handles its listed commands in `session/prompt`; 53-02 W8 confirms which); `/clear` and
  `/compact` are mapped to §5. An unlisted `/x` is sent as plain text, as v3 would.
- **Steering** (D10; SDK `steer`, 53-04, from 53-02 W7): `steer(session_id, text)`: when a turn is running, store the
  text as a user message with `meta_json.kind = "steer"`, call the SDK `steer` (text only), and emit
  `user.steer {seq, text, status: "queued"}`, then `status: "delivered"` on the engine's `steering_injected`. A steer
  sent while a tool runs is delivered only after that tool ends. If a steer arrives as the turn ends, the engine runs
  a second turn inside the same prompt. That is still one Genesis turn: one `agent.result`, with the summed credits
  (53-04 `usage.py`). At turn end, every steer the engine did not consume (`steering_cleared` without
  `steering_injected`; never seen in 53-02, still handled) is reported on `agent.result` as `unread_steers: [seq]`,
  and the web sends them as the next message (53-10). No steer while no turn runs (→ 409 at the API, use the normal
  send).
- **Stop** (D10): `cancel()` becomes `session/cancel` (wait the grace, then mark the turn `cancelled`); the client stays
  alive; pending permission futures resolve as today (`cancel`, `:359-376`; the future loop `:360-364`); only `delete_session`, idle reap and mode/model
  changes close the client (`session/close`). **After a Stop (D15):** the turn is stored as cancelled and the stopped
  user message keeps its row. When the next prompt is sent and the latest turn before it in the stored transcript ended
  cancelled, `stream_turn` puts the fixed note `STOPPED_TURN_NOTE` (a module constant: "[The previous request was
  cancelled by the user. Answer only the request below; use the cancelled request only if this request refers to it.]")
  before the user's text in the prompt sent to Kiro. The stored user message is the user's text only. The note is sent
  once per Stop, read from the transcript, so it also applies after an app restart and after `session/load`, which
  replays the stopped prompt (53-02 W19 d). The note never contains the stopped request's text or any model or tool
  output. No `_kiro/checkpoint/revertMultiple`.
- **Refusals and elicitation:** the SDK's notices (53-05) arrive as agent text; nothing to do here.
- **Usage:** `agent.result` adds `model`, `fallback_from` when present (F6); `chat_messages.usage` stores them (no schema
  change).
- `session.status` events: from the SDK's `SessionStatus` (summarization kinds) instead of `_kiro.dev/*/status`
  (`_on_session_status`, `:170-179`); same event shape.

## 5. Clear, Compact, delete (`run_slash_command`, `:486-505`; `api/chat.py:210-224`, `delete_session`)

- **Compact** (F15): `compact()` → `{ok, error?}`.
- **Clear** (F15): `session/close` the Kiro session, `session/new` a fresh one (new `kiro_session_id`), no preamble;
  Genesis's transcript stays; `{ok, error?}`.
- **Delete chat:** `_kiro/session/delete` for the stored `kiro_session_id` (best effort, logged), then today's delete.
- **Idle reap** (`reap_idle`, `:683-692`): `session/close` (record kept for resume).

## 6. v2 removal (D5)

Chat switches from `LegacyKiroACPClient` / `LegacyKiroAgentOptions` (53-06) to the public v3 names. Then delete the old
`client.py` and the `Legacy*` aliases, rename `_v3client.py` to `client.py` (53-04 §1 sequencing), and update the
`test_public_surface.py` pin to the final F1 set.

Delete from the SDK: the v2 launch flags, `_kiro.dev/metadata` folding, `_kiro.dev/commands/*`, `_kiro.dev/{compaction,
clear}/status`, `execute_command`, `set_model`, the removed options; their tests are replaced by the fixture tests. Grep
the monorepo and genesis-workflows for any remaining use (`trust_tools`, `trust_all_tools`, `agent_engine`,
`on_session_status`, `execute_command`) and fail the sub-spec until none is left. At HEAD `62537c2a` the hits are
`chat/manager.py`, `chat/mcp.py` (docstring), `genesis-core/nodes/agent.py`, `genesis-core/tests/test_core_units.py`,
`kiro-agent-sdk/tests/test_transport.py`, `tests/test_chat_manager.py`, `tests/test_copilot_mode.py` and
`scripts/spikes/51-03/harness.py` (`:282-284`); none in genesis-workflows. The 51-03 spike harness is marked
historical (a header comment; it is outside the F13 gate, 53-01 §9.4).

## 7. Tests

`tests/test_chat_manager.py`, `test_chat_api.py`, `test_copilot_*`, `test_chat_store.py`, `test_chat_mode_profile.py`
moved onto the fake engine
(53-04): every mode's `TrustPolicy` (all eight `PROFILES` entries); catalog shapes from v3 fixtures; steer delivered/queued/unread; Stop keeps the
client and the next turn needs no preamble; after a Stop the next prompt sent to the fake engine starts with
`STOPPED_TURN_NOTE` exactly once (also after a restart with `load`), the stored user message does not contain it, and a
prompt after a normal turn has no note; resume by load and the fallback; Clear gives a new Kiro session; Compact;
delete removes the record; `session.notice` on an MCP failure; usage with `model`/`fallback_from`. Web fixtures in
`web/src/test/fixtures/` regenerated from real responses (L-011, L-083).

## As built (2026-11-12, genesis-dev) — review SHIP (round 2)

**Task restated.** Move chat in all eight modes onto the v3 SDK client: the chat `KIRO_HOME`, one `TrustPolicy` per
mode derived from the profile, the steering as the agent prompt, the MCP notice, resume with `session/load` (fallback:
`session/new` + preamble, the id stored after every `session/new`), the model through `set_config_option`, the catalog
from v3 sources with unchanged API shapes, steering (queued/delivered/unread, 409), Stop with `session/cancel` and the
D15 note, Clear/Compact/delete/reap on the v3 methods; then delete the v2 client and the `Legacy*` aliases, rename
`_v3client.py`, set the final F1 pin, and grep both repos clean. Rules applied: ADR-004/020 (per-session MCP, own
`KIRO_HOME`, `includeMcpJson: false`), ADR-029/031/033/034/045 (fail closed, no shell, copilot mutations only through
`ask`, writes in the sandbox), ADR-032 (no replayed credits; a stopped turn's own usage kept), ADR-042, ADR-053,
ADR-075/076 (post-turn hook kept); L-007, L-011, L-017, L-018, L-041, L-045, L-046, L-047, L-073, L-083, L-086, L-089,
L-092, L-093, L-094, L-107, L-110. KiroCrew read as a reference only: `context_assembly/replay.py`
`cancelled_turn_preamble` (its note re-sends the stopped turn; Genesis's does not, D15),
`docs/system-specs/modules/session.md` (steer and Stop handling), `dashboard/steer_settle.py` (no evidence of
injection = unread, so the steer is re-sent rather than lost), `discord/renderer_text.py` `_STEER_MARKER_RE` (the
`[STEERING steer-…]` ack is protocol, not the reply). No ADR deviation.

### Commits (genesis, local, base d5a6a4e, not pushed)

- `8139cd2` feat(chat,sdk,53-07): chat on v3 and the v2 client removed (everything under Changed).
- `b46c877` fix(chat,sdk,53-07): live findings (a Stop before the engine began the turn ended `protocol_error`; the
  steer ack in the stored answer) + the live scripts and evidence.
- `2af786f` fix(chat,sdk,53-07): review M1/m1/n1.
- project-tracker: this As built, the status line and `reviews/53-07-review.md` (one commit).

### Changed

genesis — app:
- `chat/manager.py` (`ChatSession` rewritten, `ChatManager` catalog / Clear / Compact / delete / cancel / steer):
  - start: `_build_options` (home `settings.chat_kiro_home`, `trust_policy(...)`, `agent_id` and `agent_prompt` from
    the profile, `model`, the confirm bridge only for `ask`); `_ensure_started` = `_resume` (`client.load(kiro_session_id)`;
    a failure is logged with its code and falls back) else `start()` + `set_kiro_session` + the preamble; a resumed
    session gets the agent notes posted after its last turn (`_notes_since_last_turn`); `_mcp_notice` once per client.
  - turn: `stream_turn` builds the prompt as `[STOPPED_TURN_NOTE] + [preamble] + [notes] + User: <text>` (the note from
    `_latest_turn_cancelled` on the stored transcript, read before the message is stored); events from `_absorb`
    (`user.steer` delivered on `steering_injected`, `session.status` on `summarization_completed`); the whole `finally`
    in `anyio.CancelScope(shield=True)` (review M1); a stream closed mid-turn sends `session/cancel` and drains
    (`_finish_abandoned`); the assistant message stored with `meta.turn_status = "cancelled"` after a Stop and with
    `strip_steering_acks` applied; `agent.result` adds `model` / `fallback_from` / `code` / `unread_steers`; a start
    failure is the turn's `error` + `agent.result` with the code; `process_died` / `agent_not_active` drop the client.
  - commands: `engine_commands` drops custom-agent entries; `catalog_commands` maps the rest to `SlashCommand` and adds
    `GENESIS_COMMANDS` (`/clear`, `/compact`); a typed `/clear` / `/compact` is `_command_turn` (no prompt; reply meta
    `{command, ok}`; a successful `/clear` ends the D15 scan, review n1); a listed engine command is sent raw, an
    unlisted `/x` as text.
  - `steer` (client steer first, then the message stored with `meta.kind = "steer"`), `stop` (`session/cancel`, the
    client stays, pending confirms denied), `_clear` (`client.new_session()` + `set_kiro_session`, or a fresh start when
    no client), `_compact`, `aclose` (`session/close`); `ChatManager.ensure_agent_catalog` (throwaway client in the chat
    home with `TrustPolicy()`, deletes its own record; cache keyed on `check_kiro()`'s version), `_remember_catalog`,
    `run_slash_command` (`/clear` | `/compact` only), `delete_session` → `_delete_kiro_session` (a throwaway client's
    `delete(id)` before start), `cancel` → `stop`, new `steer`; new `ChatNotRunningError`.
- `chat/mode_profile.py`: `extra_trust` → `builtins`; `ChatModeProfile.agent_id` (`genesis-chat-<mode>`);
  `trust_policy(profile, read_tools, confirm_tools)`; comments say the steering is the agent prompt.
- `chat/mcp.py`: `chat_confirm_tools(mode)` (copilot's three mutating tools); docstrings without the v2 flag names.
- `api/chat.py`: `POST /chat/sessions/{id}/steer` (`SteerBody {text}`; 400 empty or over `chat_max_prompt_chars`, 404,
  409 when no turn runs or the engine did not queue it); `/cancel` docstring.
- `runtime/settings.py`: `Settings.chat_kiro_home` (`state_dir/kiro-home/chat`).
- `pyproject.toml`: `anyio>=4,<5` declared directly (already transitive via starlette / sse-starlette).
- `web/src/features/chat/Composer.tsx`: a stale comment only (`npm run build` left `web/static` byte-identical).

genesis — `packages/kiro-agent-sdk`:
- v2 `client.py` deleted; `_v3client.py` renamed `client.py` (docstrings updated); `__init__.py` without `Legacy*`,
  `extract_tool_output` now from `updates.py` (public F1 name kept); `messages.py`, `session.py` docstrings.
- `client.py`: `new_session()` (`session/close` + `session/new` in the same process, activation and readiness checked
  again; the Clear of F15) and `delete(session_id)` before `start` (launch + `initialize` only).
- `session.py` `_result` (b46c877): a requested cancel answered with an engine error ends the turn `cancelled`, the
  detail kept.
- `README.md`: the v3 example and flow.
- Tests: `test_public_surface.py` = the final F1 pin (exact `__all__`, option fields and client methods; no `Legacy*`,
  no `_v3client.py`); deleted the v2-only `test_acp_extensions`, `test_fs_write_sandbox`, `test_permission_ask`,
  `test_permission_policy`, `test_transport`, `test_usage_metering` (their behaviour is covered by the v3 replays,
  `test_v3_trust`, `test_v3_units`); `test_tool_output.py` trimmed to the public helper; `test_v3_*` import
  `kiro_agent_sdk.client`.

genesis — spike (outside the gates): `scripts/spikes/51-03/harness.py` header marked HISTORICAL (code unchanged);
`scripts/spikes/53-07/{subagent_probe.py, live_chat.py, evidence/*.json}`.

### Tests

- genesis: `tests/chat_fakes.py` (`FakeV3Client`: the real client's surface, the SDK's real message classes, the
  recorded `configOptions` and `availableCommands` mapped by the real client's own property code; L-083). Rewritten
  `test_chat_manager.py` (40): every `PROFILES` entry's policy (no shell, `includeMcpJson` false, copilot's three
  mutations listed and never approved, spec modes' file tools and cwd = sandbox), steering as agent prompt, model,
  id stored, resume by load (no preamble, nothing replayed stored), load failure → new + preamble (logged), notes after
  a load, MCP notice on the first turn only, catalog from the recorded shapes and its version refresh, listed vs
  unlisted commands, steer queued → delivered with one result and summed credits, unread steer, no steer without a
  turn, Stop (client kept, note once, never stored, never the stopped text), the note after a restart with load, no
  note after a normal turn, a closed stream stops the turn, Stop denies a pending confirm, Clear (new id, no preamble;
  and fresh start without a client), typed `/clear` / `/compact`, a typed `/clear` drops the note, Compact, delete,
  reap, steer ack stripped, a start failure's code, `model` / `fallback_from`. New `test_chat_v3_engine.py` (3): the
  real SDK client over the SDK's fake engine — a read-only turn (the chat's projected agent passes the D19 checks, the
  notice, metered credits, the id stored), the catalog, and a **browser Stop** (anyio task-group cancel at the first
  tool call on `cancel-after-tool`: `session/cancel` received, 0.0505 metered credits stored; fails without 2af786f).
  `test_chat_mode_profile.py` (+2: the policy for every profile; a ninth mode from its fields), `test_chat_api.py`
  (steer 400/404/409, `/cancel` keeps the session and marks the turn, unchanged catalog shapes, the id not in the API),
  `test_copilot_mode.py`, `test_copilot_safety.py`, `test_change_requests.py`, `test_spec_clauses_api.py` moved onto
  the v3 shapes.
- SDK: `test_v3_replay.py` + `test_new_session_closes_then_opens_a_new_session_in_the_same_process`,
  `test_delete_before_start_launches_without_a_session`; `test_v3_units.py` +
  `test_a_cancel_answered_with_an_engine_error_is_still_cancelled` (fails without b46c877).
- **Gates at 2af786f:** genesis `pytest -q` **1896 passed**, `ruff check genesis` clean; SDK `pytest -q` **266 passed**
  (321 at d5a6a4e, minus the v2-only files), `ruff check src tests` clean; genesis-core `pytest -q` **109 passed**, ruff
  clean (no core change). The reviewer re-ran all of them and web lint / tsc / vitest 726 / an identical bundle.
- **Grep** `git grep -n -E 'trust_tools|trust_all_tools|agent_engine|on_session_status|execute_command'`: genesis-workflows
  none; genesis only `scripts/spikes/51-03/harness.py:284-286`, the historical harness §6 names (review ruling 10).
- **Live, kiro-cli 2.37.1** (`scripts/spikes/53-07/live_chat.py`: the real `ChatManager`, SDK, kiro-cli and chat MCP
  servers in this process, isolated state dir `/tmp/g5307-live`, copilot's control server on a dead port; the fleet
  was not touched or restarted, D20):

  | Run | Result | Credits |
  |---|---|---:|
  | Sub-agent probe (`subagent_probe.py`, before the build) | with a projected agent (no tools / one MCP read tool) the engine listed only that agent as a command; `/general-task-execution` and `/context-gatherer` typed were plain text to the model, no tool, file not created | 0.30 |
  | `read_only` | `list_runs`; a steer queued → delivered (`message_seq` 2), the answer ended with 42 | 0.144 |
  | `copilot` | `start_run` confirm card → denied, nothing started; the SDK's `not_confirmed` notice steered | 0.148 |
  | `feature_spec` | `fs_write` wrote `spec.html` in the sandbox | 0.093 |
  | `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design` | `list_directory` → `probe.txt` | 0.074–0.083 each |
  | Stop 1 s after the prompt ×3 (before the engine began the turn) | stored `cancelled`; before b46c877 the result read `protocol_error` (-32603), after it `cancelled` (`unavailable`, no `turn_completion`); next prompt (note + "alive") → `alive`, **carried out 0/3** (and 0/3 before the fix) | 0.040 + 0.044 |
  | Stop at the first streamed event ×3 (the engine's Tool Load step: the turn had begun) | `cancelled`, metered 0.020–0.025; next → `alive`, **carried out 0/3** | 0.109 |
  | Stop, then a new process (a serve restart) | the second process resumed with `session/load` (same id), the note was sent from the stored transcript → `alive`, **carried out 0/1** | 0.048 |

  Total **1.31 credits**. The stopped request was carried out 0 of 7 times on the final code (0 of 10 counting the
  runs before b46c877). Evidence: `scripts/spikes/53-07/evidence/{subagent-probe-*,live-modes,live-stop,
  live-stop-before-fix,live-stop-first-event,live-restart-a,live-restart-b}.json`.
- **Not run:** the `python:3.13` CI image (L-112); a real `genesis serve` with the web (the browser Stop is covered by
  the anyio-scope test, not a browser); a mode change that loads the Kiro session under a different agent; a steer
  while a tool runs, an unread steer and a steer racing the turn's end, live; whether `reload_skills` re-discovers
  skills after a `session/load` in the new process; the model-fallback frame (none seen).

### Final event and record shapes (review m2)

Recorded from the live run (`live-modes.json`) and the code; 53-09 owns the contract table and the web fixtures.

- `user.steer {type, seq, message_seq, text, status: "queued" | "delivered"}` — `seq` stays the stream's own
  ordinal (the web dedupes on it), `message_seq` is the stored user message (live: `message_seq` 2, `queued` then
  `delivered`). **53-09's table writes `user.steer {seq, …}`: the field is `message_seq`.**
- `POST /chat/sessions/{id}/steer` → `{ok: true, seq: <message seq>, status: "queued"}` (live: `{ok: true, seq: 2,
  status: "queued"}`).
- `session.notice {type, seq, kind: "mcp_failed", servers: [name], detail: "<name>: <error or state>; …"}` — first
  turn of a client only.
- `agent.result {type, seq, ok, stop_reason, error, tool_calls, credits, context_pct, provenance}` plus, only when
  set, `model`, `fallback_from`, `code` (the 53-04 code, e.g. `cancelled`), `unread_steers: [message seq]`. Live
  read-only: `{ok: true, stop_reason: "end_turn", credits: 0.14354657217247097, provenance: "metered", tool_calls: 1}`;
  live Stop: `{ok: false, stop_reason: "cancelled", code: "cancelled", provenance: "unavailable" | "metered"}`.
- `error {type, seq, detail, code}`; `session.status {type, seq, method: "summarization_completed", params}`.
- Stored: the steer user message `meta {kind: "steer"}`; a stopped turn's assistant message
  `meta {turn_status: "cancelled"}`; a Genesis command reply `meta {command, ok}`; `usage` as the SDK's (may carry
  `model`, `fallback_from`). `GET /chat/commands` today returns only `/clear` and `/compact`.
- **§7's web-fixture line:** `web/src/test/fixtures/` has no chat fixture to regenerate, and `web/src/types/chat.ts`
  has none of the new fields; both go to 53-09 (fixtures from real responses, including a steer and a notice) and 53-10
  (types and rendering).

### Review

`reviews/53-07-review.md`: round 1 **NEEDS_CHANGES** at b46c877 — M1 (a browser Stop: sse-starlette cancels the
stream's anyio task group, which re-cancelled every await in the `finally`, so the stopped turn was stored without its
metered usage; the test used `aclose()`), m1 (`def test_context_usage` overwritten by the new delete test), m2 (record
the shapes and the hand-offs: above), n1 (the note after Stop → `/clear`), n2 (`reap_idle` uncalled: backlog below).
All fixed in 2af786f; round 2 **SHIP**. Left: r2-n1 (optional: a test where POST `/cancel` arrives during the shielded
drain; the reviewer's probe showed it stores the metered usage with one `session/cancel`). Rulings recorded there: the
`message_seq` name, custom-agent commands never offered, `/clear` and `/compact` in the catalog, the SSE close as a
Stop, delete through a throwaway process, timeouts not marked cancelled, the 51-03 harness satisfying the grep.

### Decisions / deviations

No ADR deviation. Spec clarifications, each ruled OK in the review:

1. **`user.steer` carries `message_seq`**, not a second `seq` (the stream already numbers every event).
2. **Custom-agent commands are neither offered nor sent raw** (narrows §4 "sent as a prompt only if the engine listed
   it"). The 53-02 W2 recording, with a bare spike agent, listed bundled sub-agents such as `general-task-execution`
   ("access to all tools"); whether such a sub-agent stays inside the session's `TrustPolicy` was never measured, so it
   fails closed (ADR-031). With the projected agent the engine lists only that agent, so in practice no engine command
   is offered; typed, such a name is plain text.
3. **`/clear` and `/compact` are in the catalog** and typed they are Genesis commands (v3 has no prompt-path Clear or
   Compact, 53-01 P12).
4. **A stream closed mid-turn is a Stop** (the web aborts the SSE before it posts `/cancel`): `session/cancel` from the
   stream's own `finally`, shielded from the server's anyio cancellation.
5. **Delete uses a throwaway client** (`delete()` before `start`: one process, no `session/new`) after closing the live
   one.
6. **Timeouts are not a Stop:** a `timeout_*` turn gets no `turn_status: cancelled` and no D15 note (the note says
   "cancelled by the user").
7. **A mode change resumes the Kiro session under the new mode's agent** (`session/load` re-sends the agent); any load
   error falls back to `session/new` + the preamble. Not exercised live.
8. **The Clear button stores no exchange**, so after Stop → button Clear the note is still sent once (harmless: it holds
   no stopped text). A typed `/clear` ends the scan.
9. **A requested cancel answered with an engine error is `cancelled`** (SDK, b46c877): live, a Stop before the engine
   began the turn got `-32603 Internal error`, not `stopReason: "cancelled"` (53-02 W5/W19 cancelled after
   `turn_start`).
10. **The `[STEERING steer-<id>: …]` acknowledgement** the model writes after a steer or a refusal notice is removed
    from the stored answer (live finding; KiroCrew's pattern). The live stream still carries it (53-10).
11. **`anyio` declared directly** in `pyproject.toml` (precedent: `beautifulsoup4`, 46-02).

### Lesson candidates

- **sse-starlette ends a stream by cancelling an anyio task group, not by `aclose()`**: the cancellation is
  level-triggered, so every await in the generator's `finally` is cancelled again and a cleanup that must finish
  (store usage, wait for the engine) has to run in a shielded scope. Test the server's real mechanism (a task group
  whose scope is cancelled), never `aclose()` (review M1; extends L-110).
- **A cancel that lands before the engine begins the turn is answered with an error, not `cancelled`**: classify a
  turn's end by what the caller asked for when the caller asked for a cancel (53-07 live, -32603).
- **A command catalog recorded with a bare spike agent is not the product's**: the W2 recording listed bundled
  sub-agents; the projected Genesis agent sees only itself. Re-probe a catalog with the product's agent before
  designing on it (extends 53-05's D19 lesson).
- **The model writes kiro-cli's steering acknowledgement into its reply** (`[STEERING steer-<id>: …]`): it is protocol;
  strip it wherever the reply is stored or shown.

### Code-map changes

- `genesis/genesis/chat/manager.py`: `STOPPED_TURN_NOTE`, `TURN_CANCELLED`, `GENESIS_COMMANDS`, `engine_commands`,
  `catalog_commands`, `strip_steering_acks`, `ChatNotRunningError`; `ChatSession._build_options` / `_resume` /
  `steer` / `stop` / `_clear` / `_compact` / `_command_turn` / `_finish_abandoned`; `ChatManager.steer`,
  `_remember_catalog`, `_kiro_version`, `_delete_kiro_session`.
- `genesis/genesis/chat/mode_profile.py`: `ChatModeProfile.builtins` (was `extra_trust`), `.agent_id`,
  `trust_policy()`. `chat/mcp.py`: `chat_confirm_tools()`. `runtime/settings.py`: `Settings.chat_kiro_home`.
- `genesis/genesis/api/chat.py`: `POST /chat/sessions/{id}/steer`.
- `packages/kiro-agent-sdk/src/kiro_agent_sdk/`: `client.py` is the v3 client (the v2 client and `_v3client.py` are
  gone), `KiroACPClient.new_session()`, `delete()` before start; `updates.extract_tool_output`. Public surface = the
  final F1 set.
- Tests: `genesis/tests/chat_fakes.py` (`FakeV3Client`), `tests/test_chat_v3_engine.py`.
- Spike: `genesis/scripts/spikes/53-07/` (sub-agent probe, live chat runs); `scripts/spikes/51-03/` historical.

### Changes for 53-08..53-12

- **53-08 (readiness, skills):** the chat home is `Settings.chat_kiro_home` (created on first use); the catalog cache
  is keyed on `check_kiro()`'s version, so a preflight can reuse that probe. `reload_skills` / `reload_all_skill_clients`
  close the client and the next turn resumes with `session/load` in a new process: check that a skill installed
  meanwhile is discovered after a load (not verified). `SkillInfo.shadows_personal` is still there (D7 removes it).
- **53-09 (API):** `POST /chat/sessions/{id}/steer` exists (400 / 404 / 409 as above; 409 also when the engine did not
  queue the steer, so the web sends it normally). Use the shapes under "Final event and record shapes": the steer
  event's field is **`message_seq`** (correct the table's `user.steer {seq, …}`), `unread_steers` are message seqs,
  `agent.result.code` and `error.code` exist, `session.status.method` is `summarization_completed`. Record the web
  contract fixtures from real responses (a steer, an MCP notice, a cancelled result); none exists for chat today.
  `GET /chat/commands` now returns `/clear` and `/compact` only (custom agents filtered).
- **53-10 (web):** strip `[STEERING steer-<id>: …]` in the live stream view (the backend strips only the stored
  answer; KiroCrew strips an unclosed trailing fragment while streaming too); the engine's "Tool Load" step arrives as
  an `agent.tool_update` with no `agent.tool_call` (name `Tool Load`) — hide or label it; the "Stopped" label reads
  `meta.turn_status == "cancelled"` after reload and `agent.result.code == "cancelled"` live; re-send
  `unread_steers` (message seqs) in order; on a 409 from `/steer` send the text as a normal message; the Stop order
  (abort, then `/cancel`) is handled by the backend. The copilot notice after a denied confirm card reads "…was not
  approved, so it did not run." when the web answers with no option (`option_id: null`); answering with the reject
  option id gives no notice (53-05).
- **53-11 (acceptance):** A3 (the D15 wording) has a first live answer: 0/7 carried out (two Stop windows and a
  restart). Still to run live: a mode change that loads under a different agent; a steer during a tool, an unread
  steer and a steer racing the turn's end; the browser's Stop through `genesis serve`; skill re-discovery after a
  load; the first model-fallback frame.
- **53-12 (release):** chats created before this build have no `kiro_session_id`, so their first turn is `session/new`
  + the preamble, then `session/load` from then on. From the next fleet `serve` restart chat runs this code (D20).
  The SDK's public surface changed (`Legacy*` gone, `extract_tool_output` from `updates.py`, `new_session`): release
  notes. Run the three Python suites in `python:3.13` once (L-112); `anyio` is now a direct dependency.
- **Backlog:** `ChatManager.reap_idle` has no caller (pre-existing; "idle reap = `session/close`" is not live behaviour
  until something schedules it, review n2); the Clear-button note residual (decision 8); r2-n1 (a test with POST
  `/cancel` during the shielded drain); a steer whose `_session/steer` is in flight as the turn ends is reported unread
  and re-sent, and whether the engine also queues it for the next prompt is unmeasured (`_session/steer/clear`
  exists, unused); measure a sub-agent's trust if a later engine lists bundled sub-agents for a projected agent.

## Context manifest

```toml
areas    = ["chat", "sdk-acp", "api"]
adrs     = ["ADR-031", "ADR-033", "ADR-034", "ADR-042", "ADR-045", "ADR-032", "ADR-053", "ADR-004", "ADR-020"]
lessons  = ["L-007", "L-017", "L-018", "L-041", "L-045", "L-046", "L-047", "L-073", "L-086", "L-011", "L-083"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/tests/test_chat_manager.py", "genesis/tests/test_chat_api.py", "genesis/tests/test_chat_mode_profile.py", "genesis/tests/test_copilot_mode.py", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**", "genesis/packages/genesis-core/tests/test_core_units.py", "genesis/scripts/spikes/51-03/harness.py"]
upstream = ["53-03", "53-04", "53-05", "53-06"]
```
