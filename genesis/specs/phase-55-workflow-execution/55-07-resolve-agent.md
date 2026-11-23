# 55-07 — The Resolve agent: a run-bound chat that explains an escalation and proposes actions

> **Status:** BUILT 2026-11-23 (review SHIP at re-run 1; As built below). SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/chat/`, `genesis/mcp/`, `genesis/runtime/notifications.py`).
> Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. Decisions: D6, D7, D9, D12–D15, F7
> (`55-01-findings.md`). ADR draft: ADR-089 (`adr-drafts.md`). Routes are added here and listed in 55-08; the Resolve
> tab is 55-09.

## 1. Chat mode `run_resolve`

- A new mode in `genesis/chat/store.py:25-33`, hidden from the Chat page like the stage modes (`store.py:29`), with a
  `ChatModeProfile` (`genesis/chat/mode_profile.py`): `cwd_sandbox=True`, built-ins `fs_read` and `fs_write` confined to
  the session sandbox (`fs_write_root`, ADR-034), no shell, `auto_deny` for anything else (ADR-031); the chat default
  model (F7). Kiro is started as today (ADR-086): a projected agent whose activation is verified, fail closed (L-113).
- MCP: the read-only introspection server (`genesis/mcp/introspection_server.py`) and a new run-scoped
  **`genesis-resolve`** server (`genesis/mcp/resolve_server.py`, launched with the run id; reads through `/api` like
  `control_server.py` or a read-only DB connection):
  - read: `get_escalation()` (the pending gate payload with its F6 fields and `allowed`, 55-06),
    `get_run_documents()` (55-05), `get_run_events(kinds?, node?, limit)` (bounded), `get_node_iterations(node)`;
  - **`propose_action(action, params, rationale)`** — the only tool with an effect: it validates `action` (one of
    the mockup's keys `retry`, `accept`, `fix_accept`, `relaunch`, `restart_from`, `stop`, or an extra option, D12
    item 10) against the gate's current `allowed` and `params` against the action's schema (guidance text for retry;
    **instructions** text for relaunch, D13 — never changed inputs; the step to restart from (+ optional `values`) for restart_from, D21;
    `path` + `source_file` for fix_accept, the source inside the sandbox's `drafts/`; a reason for stop), stores a
    **proposal** and returns its id. It applies nothing.
  - Trust = exactly these tools + the sandboxed fs built-ins; tested on the real projection with a negative control
    (L-116, L-117).
- No tool answers a gate, relaunches, forks or stops (ADR-033: the agent never answers a gate; the user's Confirm does).

## 2. Proposals

- Stored in `copilot_actions` as `proposed` (source `resolve`, the session, the run, the gate occurrence, action,
  params, rationale) — that table holds the Resolve proposal → confirm flow only; the audit of the action itself is
  the run's event (D22). Emitted on the session stream as a `resolve.proposal` event so the panel renders a card (55-09).
  A newer proposal for the same action supersedes the older one. Dismiss → `dismissed`.
- **Confirm** (the user, via 55-08's route) re-validates against the run's current gate payload (stale → 409 with the
  reason) and calls the 55-06 operation — `RunManager.respond / fix_and_accept / relaunch / restart_from` with
  `source="resolve"`, the `session_id` and `proposal_id` (the proposal row's `tool_call_id`; `_audit` writes the
  confirmation and outcome onto it). Before `fix_and_accept`, check that the session is **this run's own** Resolve
  session (55-06 decision 12 checks only that it exists). Proposal cards and `propose_action` follow `gate.allowed`
  (computed when the gate is raised; the methods re-check at apply time), and the sandbox copy can use `gate.files`.
  A restart proposal names the **step to restart from** (D21), not a LangGraph `as_node`. The outcome (for relaunch and restart_from: the new run id, the old run
  `cancelled`, the stage / story moved, D13, D15) is written back to the row and posted to the session as a system
  note, so the agent knows what happened, and shown in the Resolve tab (D14).
- When the run leaves the gate (answered elsewhere, cancelled, ended), open proposals become `stale`.

## 3. Session lifecycle

- Created on the user's first open of Resolve (D7; no credits for an unopened escalation): create the session, copy
  the run's files into `<sandbox>/run/` (everything but System; take the list from `manager.documents(run_id)` and
  roles from `genesis.runs.artifact_roles.roles_of`, one reader, L-109, 55-05; `_toolcalls/` included while it exists, D9; `_prompts/`
  included), then `enqueue_system_turn` with a seed: workflow name and summary, the failed step and reason, the
  validator messages, the retry / heal history, the documents list with categories, the available actions, and the
  memory brief path if any. Steering: explain what went wrong in plain words, point to the files that show it, then
  propose one to three actions with reasons; say which facts come from the run and which are guesses; never claim an
  action was applied.
- One session per run, continued across later escalations of the same run; on a new escalation (a new gate
  occurrence) the sandbox copy is refreshed and a system note gives the new failure.
- The link run → session is stored by 55-08 (a dedicated table; `chat_run_links` keeps its one copilot session per
  run).
- Credits are metered per turn (ADR-032) and summed for the panel.

## 4. Notifications

- A `RunManager` event observer: every `gate.awaiting` of kind `escalation` (any run, not only scheduled) writes a
  `needs_you` notification (`genesis/runtime/notifications.py`) with the run name, the failed step and the link
  `/runs/<id>/resolve` (D12 item 8; opening the notice does not start the agent, opening Resolve does); deduped on (run, gate seq) so a scheduled run's existing notice (`runtime/scheduler.py:398`)
  is not doubled; marked read when the gate is resolved. Store the notification before announcing anything that refers
  to it (L-093); a level-triggered reconcile covers a missed live event (L-058).

## 5. Tests

- Profile: no shell; writes only in the sandbox; only the listed tools trusted; activation verified; a write outside the
  sandbox and an unlisted MCP tool are refused (negative controls).
- `propose_action`: each action valid and invalid; unavailable action refused; source file outside `drafts/` refused;
  supersede; stale after the gate is answered elsewhere.
- Seed content from a real escalated run's payload (shape from 55-06's real payload, L-083).
- Notification: once per escalation, not doubled for scheduled runs, cleared on resolve, recovered after a restart.

## 6. Gates

genesis pytest + ruff; kiro-agent-sdk pytest (if touched).

## Context manifest

```toml
areas    = ["chat", "runs-worker", "sdk-acp"]
adrs     = ["ADR-001", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-086"]
lessons  = ["L-017", "L-041", "L-042", "L-058", "L-083", "L-093", "L-113", "L-116", "L-117", "L-118"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/genesis/chat/mode_profile.py", "genesis/genesis/chat/store.py", "genesis/genesis/chat/manager.py", "genesis/genesis/mcp/introspection_server.py", "genesis/genesis/mcp/control_server.py", "genesis/genesis/runtime/notifications.py"]
upstream = ["55-02", "55-05", "55-06"]
```

## As built

**Status:** BUILT 2026-11-23, review **SHIP** (re-run 1). Repo genesis, branch master, base `88b57a52`, head
`0a4acd0c`, 2 local commits (not pushed, not tagged). **No genesis.db migration** (decision 1); genesis-core untouched;
kiro-agent-sdk untouched; no web change.

### Commits (genesis)

| sha | what |
|---|---|
| `70f7c383` | source and tests |
| `0a4acd0c` | review round 1: B1, M1, m1–m6, n1, n2 |

### Changed

- **`genesis/chat/store.py`:** `RUN_CHAT_MODES = ("run_resolve",)`, `HIDDEN_CHAT_MODES` (stage + run modes; the Chat
  page excludes it), `CHAT_MODES` includes it. `resolve_session_id(run_id)` / `resolve_run_of(session_id)`: the link
  (decision 1). `ChatStore.create` writes `mode` in the one insert. `CopilotActionStore`: `supersede_and_propose`,
  `get`, `claim` (CAS), `reopen`, `mark_open_stale`.
- **`genesis/chat/mode_profile.py`:** `_STEERING_RESOLVE`; profile `run_resolve` (`mcp_mode="run_resolve"`,
  `auto_deny`, `cwd_sandbox`, builtins `fs_read`/`fs_write`, `uses_control_token` for the session token). The model is
  the chat default (`chat_model`).
- **`genesis/chat/mcp.py`:** `RESOLVE_SERVER`, `RESOLVE_TOOLS`, `_resolve_entry`, `build_resolve_mcp`. The session
  gets the introspection server and genesis-resolve only. Every listed tool is auto-approved.
- **`genesis/mcp/resolve_server.py` (new):** stdio MCP server launched with `--base-url --run-id --token`. Its tools
  are `get_escalation`, `get_run_documents`, `get_run_events` (≤ 200 events, payloads cut at 2,000 chars, results ≤
  32 KB), `get_node_iterations` and `propose_action`. No tool takes a run id. Header `X-Genesis-Resolve-Token`.
- **`genesis/chat/resolve.py` (new):** `ResolveService` and its pure helpers.
  - Pure helpers: `validate_proposal`, `seed_text`, `allowed_lines`, `credits_of`.
  - Lifecycle: `open`, `refresh`, `first_turn_not_started`, `escalation`, `summary`.
  - Proposals: `propose`, `proposals`, `mark_stale`, `confirm`, `dismiss`.
  - The `_observe` observer and `_allowed` (the interim write guard, decision 9).
  - Constants: `ACTIONS`, `PARAMS`, `EDITABLE`, `TEXT_MAX` 1,500, `RATIONALE_MAX` 600, `EDIT_TEXT_MAX` 4,000,
    `DIGEST_MAX` 2,000, `RUN_DIR`/`DRAFTS_DIR`, the copy bounds (25 MB per file, 200 MB per run), the note kinds
    (`resolve.seed`, `resolve.escalation`, `resolve.outcome`), `PROPOSAL_EVENT`, `WRITE_SERVERS`.
- **`genesis/chat/manager.py`:** `_build_options` uses `build_resolve_mcp` for `run_resolve`. `stream_turn(...,
  genesis_turn=meta)` stores a Genesis-authored prompt as a `system` message and sends it as `Genesis: …`. Also
  `start_genesis_turn` (a background turn whose events go to the session stream), `queue_live_note` (used by
  `enqueue_agent_note`), and `create_session(session_id=)`. `set_session_mode` refuses a switch to or from
  `run_resolve`.
- **`genesis/runs/manager.py`:**
  - `pending_escalation(run_id) -> (gate, gate_seq)`: one reader for the service, the notices and the scheduler.
  - `gate_allowed(run_id, gate)`: the action map, with legacy escalation gates mapped (decision 8).
  - `restart_from(run_id, as_node=None, values=None, *, from_step=...)`: trigger and `run.relaunched` carry
    `from_step`; the fork job carries `from_step`, `rewrite_root` and `merge_dicts: True` (review B1).
- **`genesis/runs/worker.py`:** in the fork op, `_restart_point` finds the latest checkpoint whose `next` holds the
  step and its single writer. The first step and a fan-in are refused. `_rewrite_pointers` moves the folder pointers.
  `merge_dicts` merges dict channels one level.
- **`genesis/runtime/notifications.py`:**
  - `NotificationStore`: `add(once=)`, `unread_refs`, `known_refs`, `mark_read_refs(exact=)`.
  - `RUNS_SOURCE`, `escalation_ref` (`gate:<run>:<seq>`), `resolve_link` (`/runs/<id>/resolve`).
  - `EscalationNotifier`: an observer plus `notify`, `clear` and `reconcile`; `_gate_gone` reads the durable log.
- **`genesis/runtime/scheduler.py`:** a scheduled run's escalation notice uses the shared ref, `once` and the Resolve
  link (`_escalation`, `_notify(ref=)`).
- **`genesis/api/resolve_routes.py` (new):** `POST`/`GET /runs/{id}/resolve`, `GET …/resolve/escalation`, `POST
  …/resolve/proposals` (token), `POST …/proposals/{pid}/confirm` (optional `{guidance | instructions | reason}`), `POST
  …/proposals/{pid}/dismiss`.
- **`genesis/api/app.py`:** wires `ResolveService` (attach, bind_loop) and `EscalationNotifier` (attach, startup
  reconcile). **`genesis/api/notifications.py`:** the bell's poll runs the reconcile, at most every 30 s.
  **`genesis/api/chat.py`:** the Chat page excludes `HIDDEN_CHAT_MODES`.
- **`genesis/config/retention.py`:** applying retention to a run also removes its Resolve sandbox `run/` copy (review
  m4).

### Tests

- **`tests/test_resolve.py`** (33 tests; real subprocess workers on the 55-06 `esc` and `legacy` fixtures, the v3
  fake client):
  - Profile posture. The session-id link.
  - The real projection: exactly `read_file list_directory fs_write str_replace fs_append` plus the 9 introspection
    and 5 resolve tools; servers `{genesis, genesis-resolve}`; cwd = fs_write_root = sandbox.
  - The real permission ladder: negative controls refused (`run_command`/shell, `genesis-control/respond_to_gate`,
    `cancel_run`, `genesis-kb`, an unknown `genesis-resolve/answer_gate`, `web_fetch`); positive controls allowed.
  - The SDK client refuses a write outside the sandbox (3 paths); a write under `drafts/` works.
  - Hidden from the Chat page and the mode is locked. The server reads only its run and is bounded.
  - First open: the copy (no `_kiro`, the prompts), the seed's content from the real payload, the first turn
    (`system` + `assistant`, metered, on the session stream). Re-open; never escalated (409); double open.
  - A new escalation: the copy refreshed, one note, stale proposals.
  - `propose_action`: 6 valid actions and 15 invalid cases; an action the gate does not allow; supersede and
    dismiss.
  - Confirm: retry with an edited guidance (`gate.resolved {source: resolve}`, the row `allowed`, the outcome note,
    the others stale, a double Confirm 409); stale after the gate is answered elsewhere, live and on read;
    fix_accept from the run's own sandbox (a session that stopped being a Resolve chat is refused); restart_from
    a step (the step runs first, the pointers moved, the row's run id = the new run); relaunch with edited
    instructions.
  - restart_from refusals: the first step, both forms at once, a fan-in.
  - Notices: once per escalation; a read notice is not raised again; recovered after a restart; cleared live and by
    the reconcile; not cleared in the logged-before-stored gap; `once` and `exact` in the store.
  - The routes: 404/409/403/400, the first turn handed out once, confirm, dismiss.
  - Review round 1: decisions survive a restart (both forms), the legacy gate end to end, the sandbox tool copies
    and retention, the interim write guard, the over-long proposal, a first turn that did not start.
- **`tests/test_chat_v3_engine.py`** (+1): a resolve session on the REAL SDK client over the fake engine. The agent
  passes the D19 checks, is activated (`set_mode` before `session/prompt`) and lists exactly the expected tools.
- **`tests/test_scheduler.py`** (+2, `FakeRM.pending_escalation`): a scheduled escalation shows one notice whichever
  writes first, with the Resolve link.
- Adjusted: `test_chat_mode_profile.py` (the mode set), `test_chat_manager.py` (`run_resolve` has its own trust test),
  `test_logging_context.py` (the new stdio server is on the print allow-list).
- **Mutation probes** (each failed with the fault in, then restored): `merge_dicts` off → the B1 test fails;
  `_gate_gone` removed → the m1 test fails.
- **Gates:**
  - genesis full pytest at `0a4acd0c` (reviewer, scratch state, alone): **2331 passed, 4 skipped**.
  - The dev's run at the pre-n2 tree: 2329 passed plus 1 failure in `test_run_liveness.py`, a 55-03 SSE timing test
    that ran beside a second pytest; it passes alone and in the reviewer's run.
  - `ruff check genesis` clean. kiro-agent-sdk: not touched.
- **Live check** (allowed by the user; scratch `GENESIS_STATE_DIR=/tmp/gr-55-07/live/state`, serve :8790; evidence
  `evidence/55-07/live-check.json`, redacted: the scratch state had no `memory.db`, so there is no brief and no memory
  text, D19).
  - One `agent-prompt` run (library v0.27.0, legacy gate) was told not to write `output.md`. It failed 3 times and
    reached the gate.
  - The bell showed "Agent prompt needs you" with `/runs/<id>/resolve`. `POST /resolve` returned `created: true`.
  - The first turn read the run through `list_directory`/`read_file` and the resolve tools (`get_escalation`,
    `get_node_iterations`, `get_run_events`). It explained the failure from the run's files and stored two proposals
    (`stop` with a reason, `accept`). A re-open returned `created: false`.
  - Two negative turns asked the agent to answer the gate, write `/tmp/gr-55-07/live/outside.txt` and run a shell
    command. The run stayed at the gate (0 `gate.resolved` events), neither file exists, and the agent listed no
    shell tool among its tools. **It declined to attempt the outside write, so the live check does not show the
    refusal**; the client unit test does.
  - Resolve credits 0.995, metered.

### Review

`reviews/55-07-review.md`.
- **Round 1: NEEDS_CHANGES.**
  - B1: a restart dropped every earlier decision. The worker replaced the whole `decisions` dict with the seed's
    resets, and this was already the case for 55-06's `as_node` restart.
  - M1: the legacy escalation path had no test.
  - m1–m6, n1, n2.
- All of them were fixed in `0a4acd0c`.
- **Re-run 1: SHIP.** Two optional nits, recorded below and not fixed: n3 and n4.

### Decisions / deviations

No ADR deviation. **ADR-086 note:** reads stay unscoped, as in every spec-style chat mode (D16 defers read
path-scoping to Phase 52). The brief said "fs_read/fs_write confined to the sandbox"; only writes are confined, by
`fs_write_root`. Confining reads now would be the D16 alternative that ADR-086 rejected, so I did not do it; tell me
if you want it. Choices the spec did not settle:

1. **No m0031.** The run → session link is the session id `resolve-<run_id>`. The chat_sessions primary key makes
   two opens one session. `chat_run_links` is untouched. **For the spec agent / 55-08:** drop the planned
   `run_resolve_sessions` table, or record why it is kept (55-08 §2).
2. **The routes 55-08's table lists "From 55-07" are added here** (the spec header says routes are added here), plus
   an internal `POST /runs/{id}/resolve/proposals` with a per-session token. 55-08 owns the contract rows, the web
   types and the recorded fixtures.
3. **`restart_from(from_step=)` is built here** (D21: "the server forks from the latest checkpoint whose next holds
   that step", planned for 55-08) so that a Resolve restart can be confirmed. The fork happens in the worker, as the
   step's single writer. The first step ("rerun from the start") and a fan-in are refused. A refused fork leaves one
   failed run row, as a failed 55-06 fork does. The first step is already refused when the proposal is made.
4. **The first turn** is Genesis-authored: stored as a `system` message `meta.kind = resolve.seed` (with `gate_seq`),
   sent as `Genesis: …`, and run in the background. Its events and `resolve.proposal` / `resolve.note` go to the
   session stream (`/chat/sessions/{sid}/notifications/stream`), not to the POST `/messages` SSE.
5. **A new gate occurrence** refreshes `run/` and posts a note (`resolve.escalation`) without starting a turn, so no
   credits are spent until the person writes. This happens live (on its own thread) and on open.
6. **Proposal bounds:** the agent's text is capped at 1,500 characters and the rationale at 600. The stored proposal
   must fit `copilot_actions.args_digest` (2,000, m0006), otherwise it is refused with what to shorten. A person's edit
   on Confirm may use the operation's own bound (4,000).
7. **Notices:** one per `(run, gate seq)`, kept even after it is read (`once`). The scheduler's notice for a scheduled
   escalation shares the ref and leads to Resolve. The scheduler's cancel-time text is lost when the escalation
   notice was stored first.
8. **Legacy escalation gates** (every library workflow until 55-10) get a computed map:
   - retry, accept and stop come from the gate's options;
   - fix_accept is refused ("predates the standard escalation gate");
   - relaunch and restart_from follow the run-level rules.
9. **Interim write guard (review m5, ADR-068):** Resolve never offers relaunch or restart for a workflow whose
   `META.required_mcp` has `appian-dev-write`, and fails closed when the META is unreadable. 55-08's D23 reader
   replaces it.
10. **Outcome note:** for relaunch and restart it names the new run, says the old run was cancelled, and says the
    bound stage or story moved when the workflow has a binding.
11. **The sandbox tool-output copy** goes at the run's end (D9). Retention removes the whole `run/` copy; `drafts/`
    and the transcript stay until the chat is deleted.

**Limits (recorded, not fixed):**
- n3: an off-thread refresh still copying when the run ends can put `run/_toolcalls/` back. Retention removes it
  later.
- n4: a cold-start turn exactly while a note is stored on one thread and delivered on the loop could give the agent
  that note twice.
- Resolve chats are read by memory consolidation like every chat (`memory/chat_read.py` has no mode filter). An
  answer that quotes the brief could flow back into memory. This is a 55-11 question.
- Not checked live: a Confirm of any proposal; a refused outside write by the engine (the agent declined); what v3's
  meta tools (`tool_load`, `tool_call`, `disclose_context`) can reach; two servers on one home; restart_from on a
  healing workflow or inside a subgraph.

### Live effect before the release (the fleet runs from the editable dev venv)

- New fleet workers import HEAD, so the worker's fork op is live. It is backward compatible: an unrestarted v0.83.0
  server never sends `from_step`, `rewrite_root` or `merge_dicts`, so its forks behave as before.
- Nothing else reaches the fleet until a server restart: the Resolve mode and routes, the genesis-resolve server, the
  notices, and the scheduler's shared ref.
- **Do not restart the fleet onto this code before 55-08**, which owns the D23 guard that replaces the interim one,
  and the guard on 55-06's own relaunch and restart routes. Nothing was restarted. The live check ran on its own
  scratch state and port.

### Lesson candidates

1. **A seed written into an empty thread is the whole state.** A reducer merges only into what exists, so a dict
   that resets two keys replaces the whole channel in a fork. Merge a restart's resets into the source values
   yourself, and test that an earlier step's decision survives (review B1).
2. **When two observers react to one event, decide from the durable log, not a status read.** The notice was stored
   before the run's status said "awaiting", so a reconcile in that gap read "gone" and, with once-only notices, lost
   it for good (review m1, L-124).
3. **Store a note under the lock that decides it is needed; deliver it afterwards.** A note stored later on the loop
   let a racing open post it twice (review m3).

### Code-map changes (for genesis-docs, bible/03)

- `chat/resolve.py` (new) and `mcp/resolve_server.py` (new) as listed; `api/resolve_routes.py` (new).
- `chat/store.py`: `RUN_CHAT_MODES`, `HIDDEN_CHAT_MODES`, `resolve_session_id`, `resolve_run_of`, and the
  `CopilotActionStore` proposal methods. `chat/mode_profile.py`: `run_resolve`. `chat/mcp.py`: `build_resolve_mcp`.
  `chat/manager.py`: `start_genesis_turn`, `queue_live_note`, `stream_turn(genesis_turn=)`, `create_session(session_id=)`.
- `runs/manager.py`: `pending_escalation`, `gate_allowed`, `restart_from(from_step=)`. `runs/worker.py`:
  `_restart_point`, `_rewrite_pointers`, `merge_dicts`.
- `runtime/notifications.py`: `EscalationNotifier`, `escalation_ref`, `resolve_link`, `add(once=)`.
  `runtime/scheduler.py`: the shared ref. `config/retention.py`: the Resolve copy.
- Docs: `docs/architecture` chat-and-skills (the Resolve mode), runs-and-workers (restart from a step),
  scheduler-and-jobs / notifications (`runs` source).

### For 55-08+

- **55-08:**
  - Contract rows and recorded fixtures for the six Resolve routes and the session-stream events (`resolve.proposal
    {proposal}`, `resolve.note {kind, text, gate_seq | proposal_id}`, Genesis-turn events carrying `turn:
    "genesis"`).
  - The `ResolveProposal` shape: `{id, action, params, rationale, status: proposed | applying | confirmed | failed |
    dismissed | stale | superseded, gate_seq, proposed_at, resolved_at, run_id, result_run_id, error}`.
  - `POST /runs/{id}/restart-from {from_step, values?}` maps to `RunManager.restart_from(run_id, from_step=…)`.
  - Replace `ResolveService._allowed`'s interim `WRITE_SERVERS` guard with the D23 reader (`relaunchable`,
    `relaunch_hint`, the appian-dev-write guard), and guard the manual relaunch and restart routes too.
  - The m0031 decision (decision 1).
- **55-09:**
  - Open Resolve with `POST /runs/{id}/resolve`. Read the first turn, the proposals and the notes from the session
    stream; reload them from `GET /chat/sessions/{sid}` (system messages with `meta.kind`) and `GET
    /runs/{id}/resolve`.
  - Cards follow `GET …/resolve/escalation`'s `allowed`. Confirm edits only guidance, instructions or reason. A
    restart card names a step from `steps`. Follow `new_run_id` (L-120).
- **55-10:** once the library adopts `escalation_gate`, Resolve gets `fix_accept` and the F6 history. The legacy map
  stays for old runs.
- **55-11:**
  - A live Confirm of each action.
  - A forced write-outside attempt, with a prompt the agent will act on.
  - The meta-tools question.
  - Memory consolidation of Resolve chats.
- Cleanup for the user: `/tmp/gr-55-07/` (scratch states and the live check) and the reviewer's
  `/tmp/gr-55-07-review/` and `/tmp/gr-55-07-rerun1/`.
