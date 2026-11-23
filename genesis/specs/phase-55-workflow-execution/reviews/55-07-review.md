# Review 55-07 — base 88b57a52, head 70f7c383 (genesis-review, 2026-11-23)

What this change does: it adds the Resolve agent. A hidden chat mode `run_resolve` gets the introspection server and a
new run-scoped `genesis-resolve` MCP server, whose only effect is `propose_action` (it stores a proposal in
`copilot_actions`). `ResolveService` opens one session per run (id `resolve-<run>`), copies the run's files into the
sandbox and starts a Genesis-authored seed turn. A user Confirm re-validates the proposal and calls the 55-06
`RunManager` operations. `restart_from` gains `from_step=` (the worker forks from the latest checkpoint whose `next`
holds the step). `EscalationNotifier` raises one needs-you notice per (run, gate seq), and the scheduler shares that ref.

Commit checked: `git rev-parse --short HEAD` = `70f7c383` (one local commit on master, not pushed).

## Gates (run by the reviewer)

- `GENESIS_STATE_DIR=/tmp/gr-55-07-review/state .venv/bin/python -m pytest -q -p no:warnings` → **2322 passed, 4
  skipped** in 777 s. The dev reported 2321 + 1 failure that was then fixed; the full suite is green at the head.
- `.venv/bin/ruff check genesis` → `All checks passed!`
- kiro-agent-sdk pytest: N/A. `git diff --stat 88b57a52..70f7c383` touches nothing under `packages/`.
- web lint/typecheck/vitest/build: N/A. No `web/**` file changed.
- Probe `/tmp/gr-55-07-review/probe_decisions.py` (for B1): it mirrors the worker's fork op on `PlatformState`. Output:
  `source decisions: {'planned': True, 'x': 1}` → `fork decisions: {'_escalation.from': None, '_escalation.stopped': None}`.

## Checklist

### ADRs
- [OK] ADR-001 — The agent only proposes. Program code applies a proposal on Confirm (`resolve.py:562-633`), and the graph routes the gate answer.
- [OK] ADR-002 — The turn goes through `kiro-agent-sdk` with per-session MCP (`chat/mcp.py:build_resolve_mcp`). The v3 test asserts `mcpServers == {genesis, genesis-resolve}`.
- [OK] ADR-004 — Servers are injected per session: `includeMcpJson is False` (`test_the_projected_agent_lists_exactly…`).
- [N/A] ADR-005 — No registry change.
- [N/A] ADR-008 — No UI change.
- [OK] ADR-009 — The plain fork is unchanged. `restart_from(as_node=)` still works, and `from_step` is additive (`worker.py:359-366`).
- [OK] ADR-010 — Bulk stays in files (`<sandbox>/run/`). State holds only pointers, and the proposal row is bounded to 2,000 chars.
- [N/A] ADR-011 — No workflow or agent node change.
- [OK] ADR-012 — Only the worker imports workflow code. `_restart_point` runs in the worker. The app reads META via the loader.
- [VIOLATION→B1] ADR-018 — Restart forks a state that loses every earlier step's `decisions` (B1).
- [N/A] ADR-019 — `CORE_MAJOR` and genesis-core are untouched.
- [OK] ADR-020 — Nothing is written to `~/.kiro`. The agent is projected under the chat `KIRO_HOME` (v3 engine test).
- [OK] ADR-021 — No new gate. Gate answers still come only from a person (the Confirm route).
- [minor m4] ADR-022 — The sandbox copy of run files (incl. `_toolcalls/`) lives outside the artifacts root and its retention.
- [OK] ADR-023 — Plain FastAPI routes (`api/resolve_routes.py`).
- [OK] ADR-024 — Blocking service calls go through `asyncio.to_thread` (`resolve_routes._call`). The reconcile runs via `to_thread` (`api/notifications.py`, `app.py` startup).
- [OK with B1] ADR-025 — Restart seeds a NEW thread from the chosen checkpoint, and the original is untouched (`test_confirm_relaunch_and_restart_from…`). The seeded values are wrong (B1).
- [OK] ADR-026 — No new bind. The confirm route has no auth, like every route in a local single-user app.
- [N/A] ADR-027 — No web change.
- [OK] ADR-028 — Every route is under `/api` (`register_resolve_routes(api, …)`). The MCP server calls `/api/runs/{run}/…`.
- [OK] ADR-029 — Trust = `@genesis/*` introspection reads + `@genesis-resolve/*` (`build_resolve_mcp`). The ladder refuses unlisted servers and tools (`test_the_ladder_refuses…`).
- [OK] ADR-030 — Still SQLite, with no migration. The run → session link is the derived session id (dev choice 1).
- [OK] ADR-031 — `auto_deny`. Sandboxed `fs_read`/`fs_write`, no shell (ladder refuses `shell`, `web_fetch`, `genesis-control/*`, unknown `genesis-resolve/answer_gate`). Writes are confined by `fs_write_root` (`test_a_write_outside_the_sandbox_is_refused_by_the_client`).
- [OK] ADR-032 — Credits come from the turn's metered usage. `credits_of` gives metered, partial or unavailable (`resolve.py:254-261`). Live: 0.995 metered.
- [OK] ADR-033 — No tool answers, relaunches, forks or stops. `propose_action` stores only. Confirm is the user's route, and the agent has no HTTP or shell path to it. Live negative turns: `gate_resolved_events: 0`.
- [OK] ADR-034 — Writes happen only inside `skill_output_dir/<sid>`. `fix_accept` requires `drafts/` (`_draft`, tests for `loose.json`, `/etc/hosts`, `drafts/../loose.json`).
- [N/A] ADR-035 — Run input files are not touched.
- [N/A] ADR-037 — KB is not touched.
- [N/A] ADR-041, ADR-042, ADR-043 — Not touched.
- [OK] ADR-045 — The mode reuses the chat surface and stays inside ADR-031 (no slash path; a Genesis turn is sent as `Genesis: …`).
- [N/A] ADR-046, ADR-047, ADR-049 — Not touched.
- [N/A] ADR-050 — No lifecycle status change (the binding rebind is 55-06's existing path).
- [OK] ADR-051 — The chat path is not a workflow-agent path. Unchanged.
- [N/A] ADR-053, ADR-054 — The seed names the brief by path only (D19). `memory.db` is not touched.
- [N/A] ADR-055, ADR-059, ADR-060, ADR-061, ADR-062, ADR-063, ADR-065, ADR-066 — Not touched.
- [minor m5] ADR-068 — Legacy `gate_allowed` offers relaunch/restart_from for `story-implementation` (appian-dev-write). D23's guard is 55-08's job, and these routes open the path first.
- [N/A] ADR-069 — No workflow skills.
- [N/A] ADR-071, ADR-073, ADR-074, ADR-075, ADR-076 — Not touched.
- [N/A] ADR-077 — Agent system not touched.
- [OK] ADR-080 — One repo. No package dependency added.
- [N/A] ADR-081, ADR-082, ADR-083, ADR-084, ADR-085 — Queue-managed workflows stay refused by 55-06's bindings. No test execution, no reports.
- [OK] ADR-086 — v3 projected agent `genesis-chat-run-resolve`, activated before the prompt (set_mode before `session/prompt`, `agent_checked`) on the real SDK client over the fake engine (`test_a_resolve_session_projects…`). Reads are unscoped, per D16 (dev choice 5).
- [N/A] ADR-087 — The scheduler change is only the notice ref and link.

### Lessons
- [OK] L-001 — `env: []` list form (`_resolve_entry`).
- [OK] L-003 — No run-bus change. The session stream is the existing notification SSE.
- [OK] L-004 — Proposals and notices are stored in SQLite.
- [OK] L-005 — No new run event kinds. `resolve.proposal` and `resolve.note` are session-stream events, not run events.
- [N/A] L-007 — No web change.
- [N/A] L-008 — Error handling of `worker_exit` is unchanged. A failed `from_step` lookup emits a specific `error` (`worker.py:362-364`).
- [OK] L-009 — The fork uses async `aget_state_history`/`aupdate_state` on the checkpointer-compiled graph.
- [OK] L-010 — Under `/api`.
- [OK] L-016 — Real credits.
- [OK] L-017 — Fail-closed `@server/tool` allowlist, `auto_deny`.
- [N/A] L-018 — No new SSE reader.
- [N/A] L-019 — No secret writes.
- [OK] L-020 — The fork keeps `_recursion_limit_of(meta)`.
- [OK] L-021 — MCP results are capped at 32 KB, event payloads at 2,000 chars, at most 200 events (`test_the_server_reads_only_its_run_and_bounds_events`).
- [OK] L-023 — `_body` handles non-JSON and error bodies.
- [N/A] L-024 — No skills.
- [OK] L-025/L-027 — ruff is pinned and clean.
- [OK] L-026 — Routes off the loop. Observer DB work runs on the reader thread, not the loop.
- [N/A] L-030 — No web change.
- [N/A] L-031 — Not touched.
- [N/A] L-033 — Not touched.
- [N/A] L-039 — No list/get pair added.
- [OK] L-041 — `cwd = fs_write_root = sandbox`, and the fs tools are trusted (v3 engine test asserts `cwd == fs_write_root`).
- [OK] L-042 — The run is given as files under `./run/`.
- [OK] L-044 — Activation is checked on the real client.
- [OK] L-045 — Human-confirm backstop kept.
- [OK] L-046 — The Genesis turn uses the normal `prompt()` path.
- [N/A] L-047 — No export change.
- [N/A] L-048 — No SPA change.
- [N/A] L-050 — Not touched.
- [N/A] L-051 — Not touched.
- [N/A] L-056, L-057 — No release here (the release agent's job).
- [OK] L-058 — Failures are logged (`log.error(... exc_info=True)` in both observers and the background turn). Level-triggered recovery: notifier `reconcile` (startup + bell poll), `summary()` settles stale proposals, `open()` re-checks the gate seq. See m1 for a race in the reconcile.
- [OK] L-059, L-060 — Not affected.
- [OK] L-061 — Restart rebinds before start (55-06 path, unchanged order).
- [N/A] L-062, L-065 — Not touched.
- [OK] L-066 — `_steps`/`_escalations` read filtered event lists on request, not per tick.
- [N/A] L-068, L-069, L-073 — Not touched.
- [OK] L-081 — The scheduler's non-escalation notices keep the old `schedule:<id>` rule. `add(once=False)` is unchanged (`test_store_add_once_counts_a_read_notice`).
- [N/A] L-086, L-087, L-088, L-089 — Not touched.
- [OK] L-091 — `supersede_and_propose`, `mark_open_stale` and `NotificationStore.add` take `BEGIN IMMEDIATE` before reading. `claim` is a CAS (`WHERE outcome IS NULL` / `= current`). A double Confirm applies once (`test_confirm_retry…` last assert).
- [N/A] L-092 — No test package folders.
- [OK] L-093 — The notice is stored by the observer, and nothing announces it (the bell reads the store). Proposals are stored before the `resolve.proposal` emit (`resolve.py:515-516`). Outcome notes are posted after `_audit` wrote the row.
- [VIOLATION→M1] L-094 — Nothing exercises the legacy-gate consumer of `gate_allowed`/`respond` from Resolve, which every installed workflow uses today.
- [OK] L-096 — No generic `/runs/{run_id}/{x}` route exists to shadow the new ones (grep).
- [OK] L-097 — The reconcile writes only notices, never a run state.
- [N/A] L-098, L-099 — No version change. Dev-venv effect: see "What reaches the fleet" below.
- [N/A] L-100, L-101, L-104, L-105 — Not touched.
- [OK] L-106 — Proposals and cards follow the gate's CURRENT `allowed`. Confirm re-validates (`test_an_action_the_gate_does_not_allow_is_refused`).
- [OK] L-107 — The background turn ends on every error path (`start_genesis_turn` catches and logs, and `_bg_turns` drops it on done). A failed apply sets the row to failed or reopens it.
- [OK] L-108 — Restart/relaunch cancel through 55-06's CAS path (unchanged).
- [OK] L-109 — One reader for each contract: `resolve_session_id`, `pending_escalation`, `escalation_ref`, `TOKEN_HEADER` (pinned by a test).
- [OK] L-111 — Live check run on scratch state (evidence/55-07/live-check.json). Confirm was not run live (Not checked).
- [OK] L-112 — The suite has no new tool assumption (real subprocess workers already used by 55-06 tests).
- [OK] L-113 — Trust is the projected agent with activation verified (v3 engine test).
- [OK] L-114 — The ladder test uses `_meta.kiro` identity.
- [N/A] L-115 — No skills provisioned.
- [OK] L-116 — The trust set is tested on the real projection (`agent_spec.project`) and the real ladder.
- [OK] L-117 — Real projection, real ladder, production sandbox layout, negative controls that must fail (shell, control, KB, unknown resolve tool, web_fetch).
- [OK] L-118 — No new SSE generator. The background turn is a task, not a stream finally.
- [N/A] L-119 — Not touched.
- [OK] L-120 — Confirm returns `new_run_id` for relaunch/restart, and the route documents that the caller follows it.
- [OK] L-121 — The restart fork op uses the existing `_spawn(job, event_run_id=new_id)`. It never writes the old run's status.
- [OK] L-122 — No new run event kind.
- [minor m1] L-124 — The reconcile decides "gate gone" from a live status read that can lag the stored notice, not from the durable log.
- [N/A] L-125 — Not touched.

### Gates
- [OK] `pytest` (api) — 2322 passed, 4 skipped.
- [OK] `ruff check genesis` (api) — clean.
- [N/A] kiro-agent-sdk pytest (chat) — not touched.
- [OK] `pytest` (chat) — as above.
- [OK] `ruff` (chat) — as above.
- [N/A] web lint/typecheck/test (chat) — no web change.
- [N/A] web build (chat) — no web change.
- [OK] `pytest` (runs-worker) — as above.
- [OK] `ruff` (runs-worker) — as above.

## The dev's open choices

1. **Session id as the link (`resolve-<run_id>`), no m0031.** OK. The primary key makes two opens produce one session.
   `_RUN_ID` keeps the id a single path segment (`test_the_session_id_is_the_link_to_its_run`), and `set_session_mode`
   refuses switching into or out of the mode. 55-08's planned table is not needed for "one session per run". 55-08
   should drop it or record why it is kept. One gap: retention of the run does not reach the session's sandbox (m4).
2. **The routes, plus the internal `POST …/resolve/proposals` with `X-Genesis-Resolve-Token`.** OK. The token is minted
   per live session and held in memory. `propose` requires `session_for_token(token) == resolve_session_id(run_id)`,
   and no token or another session's token gets 403 (`test_the_resolve_routes`, `ResolveForbidden` case). The token is
   on the server's argv like the control server's; that is local single-user and acceptable. Opening relaunch/restart
   now runs ahead of D23's guard (m5).
3. **`restart_from(from_step=)` + worker `_restart_point`.** The design matches D21 (latest checkpoint whose `next` holds
   the step, forked as its single writer). The first step is refused and tested; fan-in is refused but untested (m6).
   The seeded state drops earlier decisions (B1).
4. **The Genesis-authored first turn.** OK. It is stored as `system` with `meta.kind = resolve.seed`, sent as `Genesis: …`,
   metered, with events on the session stream. It replays as a Genesis note on a cold start (`_build_preamble`).
5. **Reads unscoped, writes confined.** OK per ADR-086 (D16 defers read scoping to Phase 52), the same as every
   spec-style mode. The live check could not show a refused outside write (the agent declined), so the client unit test
   is the proof. See Not checked.
6. **Proposals bounded to fit `args_digest`.** OK as a rule (`resolve.py:510-513`), but no test hits it (m6).
7. **Notices `gate:<run>:<seq>` with `once=True`, shared with the scheduler, reconciled.** OK in design and tested both
   ways (`test_a_scheduled_runs_escalation_gets_one_notice…[True/False]`). It has a race that can lose a notice for
   good (m1).
8. **Legacy gates get a computed action map.** The mapping logic is right (`manager.py:797-814` plus `_check_answer`'s
   legacy branch: retry → `{feedback}`, accept → approve, stop → reject). It has no test at all (M1).

## What reaches the fleet through the editable dev venv before a release

The fleet servers (:8760/:8761) loaded their app code at start, so the new app modules (routes, `ResolveService`,
notifier, `ChatStore.create` inserting the mode) take effect only on a restart. Each new worker subprocess imports
`genesis/runs/worker.py` fresh, so the fork-op change is live now. It is backward compatible: an old app's fork job has
no `from_step`, and `as_node = job.get("as_node")` behaves like the old `job["as_node"]` (`worker.py:359-373`).
`resolve_server.py` is launched only by the new app. If the fleet is restarted before 55-08, the Resolve API (no UI
until 55-09) is live with B1 and m5 open.

## Findings

### Blockers

- B1 **A restart drops every decision the earlier steps made** (`genesis/runs/worker.py:370`,
  `genesis/runs/manager.py:1256,1263`).
  - What: `_restart_from` seeds `decisions = {"_escalation.from": None, "_escalation.stopped": None}` (the review-M1
    resets). The worker's fork does `merged = dict(src.values); merged.update(job["values"])`, which replaces the
    whole top-level `decisions` dict. It then calls `aupdate_state` on an empty new thread, so the `_merge` reducer has
    nothing to merge into.
  - Problem: the probe above shows a checkpoint with `{'planned': True, 'x': 1}` forking into
    `{'_escalation.from': None, '_escalation.stopped': None}`. Any workflow whose step reads a decision an earlier step
    wrote breaks after "Restart from a step": a KeyError, a wrong branch, or a validator router that reads its verdict
    from `decisions`. The same happens on the `as_node` path. That path existed since 55-06, but 55-07 builds `from_step`
    on it and makes it reachable from a Resolve Confirm. The fixture `plan` node writes `decisions.planned` in
    `tests/test_run_actions.py:93`, but no test asserts that it survives.
  - Fix: in the worker's fork op, merge dict channels instead of replacing them, for restart jobs (`from_step` or an
    explicit `merge: true` flag the manager sets): `for k, v in values.items(): merged[k] = {**merged[k], **v} if
    isinstance(merged.get(k), dict) and isinstance(v, dict) else v`. Add a regression test in `test_run_actions.py` and
    `test_resolve.py` that restarts (both `as_node` and `from_step`) and asserts `get_state(new)["decisions"]["planned"]
    is True` and `"_escalation.from"` is None.
  - If skipped: Resolve's restart proposal and 55-08's `restart-from` route launch runs with an amnesiac state.

### Majors

- M1 **The legacy escalation path has no test, and every installed workflow takes it today**
  (`genesis/runs/manager.py:797-814`; `resolve.py:632` → `_check_answer` legacy branch).
  - What: `gate_allowed` computes a legacy map (retry always, accept/stop from approve/reject, fix_accept refused with
    the "predates" reason, run-level relaunch/restart). A Resolve `retry` confirm is mapped to `{feedback}`.
  - Problem: `grep gate_allowed|predates the standard` over `tests/` finds nothing. `test_resolve.py` drives only the
    55-06 standard-gate fixture `esc`. Until 55-10 every library workflow raises the legacy gate (the live check's
    `agent-prompt` did, with `gate_options: [approve, reject]`). The live check stored proposals but confirmed none. A
    regression in that mapping would go unseen: for example, retry sent as `{"action": "retry"}` to a legacy gate, or
    accept offered on a gate without approve.
  - Fix: add tests on the existing legacy fixture (`tests/test_run_actions.py:112-117`, `hitl_gate(kind="escalation")`):
    the `gate_allowed` map, including a gate whose options lack `reject`; `propose fix_accept` refused with the reason;
    Resolve confirm of `retry` reaching the gate as `{"feedback": <guidance>}` and of `accept`/`stop` as
    approve/reject; and the seed's "Actions the gate allows now" lines for a legacy gate.

### Minors

- m1 **The reconcile can mark a just-raised notice read, and `once=True` then keeps it read forever**
  (`genesis/runtime/notifications.py:225-243`; `genesis/runs/manager.py:401-410`).
  - What: the worker's `final` handler logs `gate.awaiting`, and the notifier stores the notice inside that `_log`,
    before `_claim_status(AWAITING_GATE)`. On the bell's poll, `reconcile` (in a thread) lists `AWAITING_GATE` runs and
    then marks read every unread `gate:` notice not in that set.
  - Problem: when the poll's `rm.list` runs while the run is still `running`, and its `unread_refs` runs after the
    notice was stored, the new notice is marked read. Because it is `once`, neither the live path nor a later reconcile
    raises it again: the escalation never shows in the bell. The window is milliseconds per escalation, but the loss is
    permanent.
  - Fix: decide "gone" from the durable log (L-124). Mark `gate:<run>:<seq>` read only when the run's latest
    `gate.resolved` has `seq > <seq>`, or the run is terminal, or a later `gate.awaiting` exists. Otherwise keep it.
- m2 **A second escalation's sandbox refresh copies up to 200 MB on the worker reader thread, inside `_log`**
  (`resolve.py:437-449` → `refresh` → `_copy_run`).
  - What: the copy runs in the `gate.awaiting` observer. That is before the run's status is claimed `awaiting_input:gate`,
    and before the notifier's observer (registered later in `create_app`) stores the notice.
  - Problem: during the copy, Run Detail shows the gate while the record says `running`. A manual answer in that window
    gets `_resumable`'s refusal, and the needs-you notice is delayed by the copy time.
  - Fix: from `_observe`, hand `refresh` to a thread (`threading.Thread(target=self.refresh, args=…, daemon=True)` or the
    loop's default executor through `_on_loop`). Keep `mark_stale` where it is.
- m3 **`open()` racing the live refresh posts the escalation note twice** (`resolve.py:362-364, 420-428`).
  - What: `refresh` releases `_refresh_lock` before the note's message is stored, because `_note` runs later on the loop.
    `_seeded_seq` reads stored messages.
  - Problem: an `open()` between the observer's refresh and the loop tick sees `seeded < seq`, recopies `run/` and posts
    a second "escalated again" note, which the agent then receives twice.
  - Fix: store the system message inside the lock with `self.chat.msgs.append(...)` (thread-safe). On the loop, push
    only the live `_pending_notes` entry and the stream event. Alternatively, keep a `(sid, seq)` set under the lock.
- m4 **The sandbox copy of the run outlives the run, including `_toolcalls/` that D9 purges at run end**
  (`resolve.py:367-399`).
  - What: `<skill_output_dir>/resolve-<run>/run/` keeps copies of `_toolcalls/*.out` and every non-System file.
  - Problem: after the run ends, its own `_toolcalls/` is purged (D9, `purge_tool_store_on_final`), but the copy stays.
    Retention (ADR-022) reclaims the run folder and never the copy, so tool outputs (which may hold Appian data) and up
    to 200 MB per run remain indefinitely.
  - Fix: on the terminal `run.final` the observer already handles (`resolve.py:446`), remove `<sandbox>/run/_toolcalls/`.
    Have retention, or the observer on purge, delete `<sandbox>/run/` with the run. Leave `drafts/` until the session is
    deleted.
- m5 **Resolve makes relaunch/restart of `story-implementation` confirmable before D23's guard exists**
  (`manager.py:808-809` via `_relaunch_refusal`/`_restart_refusal`; `resolve_routes.py` confirm).
  - What: legacy `gate_allowed` offers relaunch/restart_from for any workflow not refused by a binding. Only the
    queue-managed ones are refused.
  - Problem: an escalated `story-implementation` run (which uses appian-dev-write) gets a relaunch proposal card. A
    Confirm starts a new Dev-writing run outside the Implementation lane's confirm, which D23 and the ADR-089 draft rule
    out.
  - Fix: 55-08 owns the guard. Record in this sub-spec's As built / Resume note that 55-07 must not reach a release or a
    fleet restart without it. If 55-08 slips, add an interim
    `run_manager.bindings.refuse("story-implementation", "Re-run it from the Implementation lane")` where the story lane
    is wired.
- m6 **Two new refusals have no test.** The worker's fan-in refusal ("reached from several steps at once",
  `worker.py:257-258`) and the over-long proposal refusal (`resolve.py:510-513`, dev choice 6) are both untested.
  - Fix: a two-branch fixture that joins into one step (`restart_from(from_step=<join>)` → `RunActionError` "several
    steps", original not cancelled), and a `propose` whose rationale plus text params push the JSON over 2,000 chars →
    `ProposalInvalid` "shorten".

### Nits

- n1 `open()` on a run that no longer waits still posts "The run escalated again" when the last logged escalation is
  newer than the seed (`resolve.py:344, 362-364`: `_waiting` is ignored). Say "stopped again earlier at gate
  occurrence N" when not waiting, or skip the refresh.
- n2 If `start_genesis_turn` returns False after `open()` handed out the first turn, `_handed` stops this process from
  seeding again (`resolve.py:357-361`). This is unreachable today (a just-created session has no turn), but the
  `_handed.add` could move after a successful start.

## Not checked

- A live Confirm of any proposal (retry, accept, fix, relaunch, restart, stop) on a real engine. The live check stored
  proposals only, and the user asked not to spend more credits.
- A live refused write outside the sandbox. The agent declined to try, so the refusal is proven only by
  `test_a_write_outside_the_sandbox_is_refused_by_the_client` (SDK `_fs_write`). That test does not prove that v3's
  built-in `fs_write` is routed through that client path for this mode. This is the same posture as every existing
  spec-style mode.
- What the v3 meta tools the live agent listed (`tool_load`, `tool_call`, `disclose_context`) can reach. They are
  pre-existing for all v3 chat modes, and the ladder test covers `@server/tool` permission requests only.
- Behaviour with two `genesis serve` processes on one home (the token registry and `_handed` are per process; a peer
  would refuse proposals from the other's session). This is a single-user setup and was not exercised.
- `restart_from(from_step)` on a healing (`attach_healing`) workflow and on a step inside a subgraph. Only the `esc`
  fixture was run.

## Verdict: NEEDS_CHANGES

Fix B1 (merge dict channels on the restart fork, plus a regression test for both forms) and M1 (legacy-gate tests).
m1–m6 should be fixed in the same pass, and they are small. m5 can instead be recorded as a release-order constraint
on 55-08.

---

## Re-run 1 — head 0a4acd0c (genesis-review, 2026-11-23)

Commit checked: `git log --oneline -1` = `0a4acd0c` (master, one fix commit on top of `70f7c383`). The working tree is
clean. I read `git diff 70f7c383..0a4acd0c` (8 files: `api/resolve_routes.py`, `chat/manager.py`, `chat/resolve.py`,
`config/retention.py`, `runs/manager.py`, `runs/worker.py`, `runtime/notifications.py`, `tests/test_resolve.py`), plus
the call sites of the functions it changes (`_restart_from` and its seed, `enqueue_agent_note`, `_build_preamble`,
`_notes_since_last_turn`, `pending_escalation`, `EventLog.latest`).

### Gates (run by the reviewer at 0a4acd0c)

- `GENESIS_STATE_DIR=/tmp/gr-55-07-rerun1/state .venv/bin/python -m pytest -q -p no:warnings` → **2331 passed, 4
  skipped** in 822 s. Nothing else ran at the same time. That is the dev's 2329 + 1 (the liveness test, which passes
  here) + 1 (the n2 test added after their run). `test_run_liveness.py::test_live_reconnect_that_missed_a_hint_gets_one_resync_and_no_replay`
  passed, which fits the dev's explanation that it failed only because two pytest runs overlapped.
- `.venv/bin/ruff check genesis tests/test_resolve.py` → `All checks passed!`
- kiro-agent-sdk and web: N/A. The diff touches nothing under `packages/` or `web/`.

### Round-1 findings

- **B1: fixed.** `_restart_from` sends `merge_dicts: True` (`manager.py:1275`). The worker merges each seeded dict
  channel one level into the source checkpoint's values (`worker.py:370-378`). The resets still take effect:
  `retries` is seeded with one zero per key the escalated state holds, `_healing` with its full three keys, and the two
  `decisions._escalation.*` keys as None. Every other `decisions` key now survives. The plain fork (`manager.py:898`)
  sends no flag and keeps its old replace behaviour. Test `test_a_restart_keeps_the_decisions_earlier_steps_made[as_node|from_step]`
  asserts `decisions.planned is True`, `_escalation.from is None` and a DONE fork. The 55-06 reset tests in
  `test_run_actions.py` (retry counts, healing budget, stop markers) still pass in the full run. With the flag off, the
  merge branch is skipped and `decisions` is replaced, so the new test would fail. That matches the dev's mutation probe.
  One side effect is acceptable: a user's own `values` on a restart now merge into a dict channel instead of
  replacing it. This is the same as what the channel's reducer does on any later update.
- **M1: fixed.** `test_resolve_on_a_legacy_escalation_gate` runs on the `legacy` fixture three times. It checks the full
  `gate_allowed` map, the seed's lines for fix_accept and accept, a refused `fix_accept` with the "predates" reason, and
  Resolve confirms of retry, accept and stop reaching `gate.resolved` as `{"feedback": "use the form"}`, `approve` and
  `reject`. A gate whose options lack approve and reject gets both refusals.
- **m1: fixed.** `_gate_gone` (`notifications.py:245-261`) marks a notice read only when the run is gone or terminal,
  or when the log has a `gate.resolved` or `gate.awaiting` with a seq greater than the ref's. `gate_seq` is the
  `gate.awaiting` event seq (`pending_escalation`, `manager.py:794-795`), so the comparison is like for like.
  `test_the_reconcile_keeps_a_notice_raised_just_before_the_status_is_stored` reproduces the gap (status set back to
  `running` after the notice was stored) and expects `cleared: 0`.
- **m2: fixed.** `_observe` starts `_refresh_quietly` on a daemon thread (`resolve.py:474-478`). Failures are logged
  with `exc_info`. The existing refresh test now polls for the note. No test pins the ordering (status claimed before
  the copy ends). That ordering would be hard to test, and the change is small, so I accept it.
- **m3: fixed.** `_note` stores the message in the calling thread, which for `refresh` is inside `_refresh_lock`, and
  then delivers on the loop (`_deliver_note` → `ChatManager.queue_live_note`). `enqueue_agent_note` is refactored onto
  the same helper and its behaviour is unchanged. The stored `meta` keys (`kind`, `agent_text`, `gate_seq` /
  `proposal_id`) are the same ones `_build_preamble` and `_notes_since_last_turn` read. No race test, which is
  acceptable for a minor. See n4 for a remaining window.
- **m4: fixed.** On terminal `run.final`, the observer removes `<sandbox>/run/_toolcalls/` (`_drop_tool_copies`).
  `RetentionService.apply` removes `<skill_output_dir>/resolve-<run>/run/` and counts its bytes
  (`retention.py:177-183`). `test_the_sandbox_copy_of_tool_outputs_goes_with_the_run` covers both, and checks that
  `drafts/` survives. See n3 for a small leftover.
- **m5: fixed in code (interim).** `ResolveService._allowed` (`resolve.py:530-542`) refuses relaunch and restart_from
  when `META.required_mcp` contains `appian-dev-write`, and it fails closed when the META cannot be read. One map feeds
  the seed (`_seed`), `escalation()`, `propose` and the confirm re-validation (`resolve.py:635`). `story-implementation`
  declares `appian-dev-write` in `graph.py:154` and `workflow.yaml:17`, so this guard covers it.
  `test_no_new_run_of_a_workflow_that_writes_to_dev` checks the refusals and that retry stays available. The guard
  covers Resolve only. 55-06's own `relaunch` and `restart_from` routes are still unguarded, and that stays 55-08's
  D23 job: 55-08 should replace `WRITE_SERVERS` with its reader so that only one guard exists.
- **m6: fixed.** `test_restart_from_a_step_two_steps_led_to_is_refused` uses a real fan-in graph. It expects
  `RunActionError` "several steps at once", and the original run keeps `awaiting_input:gate`.
  `test_a_proposal_too_long_to_store_whole_is_refused` expects "shorten the rationale" and that nothing is stored.
- **n1: fixed.** `open()` refreshes only when `_waiting` (`resolve.py:368`). No test, which is fine for a nit.
- **n2: fixed.** The route calls `resolve.first_turn_not_started` when `start_genesis_turn` returns False
  (`resolve_routes.py:56-57`). `test_a_first_turn_that_did_not_start_is_handed_out_again` covers it.

### Checklist lines that changed since round 1

- [OK] ADR-018, ADR-025: the restart now seeds a new thread with the earlier steps' decisions kept (B1 test).
- [OK] ADR-022: the copy of a run's files goes when retention removes the run, and the tool-output copy goes at the
  run's end (m4 test).
- [OK] ADR-068: Resolve offers no new run of a Dev-writing workflow (m5 test). The lane-level guard is 55-08's job.
- [OK] L-094: the legacy-gate consumer is now tested (M1).
- [OK] L-124: the reconcile decides from the durable log (m1 test).
- [OK] L-058: the background refresh logs its failures (`_refresh_quietly`).
- All other round-1 lines are unchanged. The diff touches none of the code they cite.

### New findings

No blockers, majors or minors.

- n3 **The off-thread refresh can recreate `run/_toolcalls/` after `run.final` removed it** (`resolve.py:474-482`).
  Case: an escalation starts a refresh thread that is copying a large run, and the user stops the run at the gate
  before the copy ends. Then `_drop_tool_copies` runs first and the thread copies `_toolcalls/` back. The copy only
  succeeds if the source purge has not happened yet. Retention still removes the whole `run/` later, so this leak is
  bounded. Smallest fix: in `_copy_run`, skip tool outputs when `self.rm.get(run_id).status` is terminal, or run
  `_drop_tool_copies` again at the end of `_refresh_quietly` when the run is terminal.
- n4 **Splitting store and delivery opens a small window in which a note can reach the agent twice**
  (`resolve.py:444-453`). The note is stored on a thread and queued on the loop a moment later. Case: a cold-start
  turn builds its preamble from the transcript, which already includes the note, and its client becomes live before
  `_deliver_note` runs. Then `queue_live_note` queues the same note again. This needs a cold start within
  milliseconds of a refresh, and the cost is one repeated note. Smallest fix, if wanted: record the note's message seq
  and have `_deliver_note` skip it when the live client started after that seq.

### Not checked (in addition to round 1's list, which still holds)

- I did not run my own mutation probes. Code edits are denied to me. I confirmed by reading `worker.py:370-378` and
  `notifications.py:245-261` that the B1 and m1 tests fail without the fixes, as the dev reports.
- I did not repeat a live check of the new code. No Kiro credits were spent and the fleet was not restarted. The fleet
  (:8760/:8761) picks up the new `worker.py` in each new worker subprocess, and that change is backward compatible
  (no `merge_dicts` flag means the old behaviour). The app-side changes take effect only after a restart.

## Re-run 1 verdict: SHIP

Every round-1 finding is fixed, and each fix that matters has a regression test. The full suite passes (2331 passed,
4 skipped) and ruff is clean at `0a4acd0c`. n3 and n4 are optional. Carry-forward for 55-08: replace the interim
`WRITE_SERVERS` guard with the D23 reader, and guard 55-06's own relaunch and restart routes.
