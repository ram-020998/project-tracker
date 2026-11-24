# 55-11 — Review, hardening and live acceptance (Phase 55 only)

> **Status:** SPEC-DRAFTED 2026-11-22. Repos: genesis, genesis-workflows. Parent:
> `specs/phase-55-workflow-execution.md`. Run by **genesis-review** (read-only on code) after 55-02..55-10 are BUILT;
> report in `specs/phase-55-workflow-execution/reviews/55-11-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed
> by genesis-dev before the release, each with a regression test. **D36, D37:** the release waits for §1–§2 and the
> re-review of the fix pass, not for §3; the user runs §3 after the release (findings as v0.84.x patches). The open
> Phase 51/53/54 acceptance is not part of it. **M1 is not fixed (D35).**

## 1. Independent review (file:line evidence each; plus `genesis-ctx check --since <phase base>` per repo)

1. **Memory brief (ADR-088 draft, D2–D5, D17, F1–F5):** built only for `op == "run"`, only with an agent node, honours
   `memory_brief: false`; never fails a run on any error path; personal memories only in their section and never in
   anything published to the Hub; the brief marked as data; the memory MCP trusted for exactly its six read tools on the
   real projection; the embedder never loaded in the web process (ADR-054); the model never downloaded inside a run;
   consolidation skips `run_resolve` chats (D25).
   **Review genesis `419d8363`** (55-04's review fixes: not re-reviewed, full suite not re-run after it).
2. **Escalation (ADR-089 draft, D6, F6, F8):** every action routed and stored as specified in every adopted workflow
   (L-106); Reject / stop ends `failed`, never `done`; accept and fix-then-accept refused when unavailable; the agent
   cannot answer a gate, relaunch, fork or stop (ADR-033) — only `propose_action`; every action audited on the run's
   events with actor, source, action, parameters and proposal id (D22); relaunch
   cancels through the stop-intent + CAS path with no second `run.final` (L-108); rerun reuses the inputs unchanged
   and puts the instructions in every agent node's prompt (D13); restart from a step cancels the original and moves
   the binding before the new run starts (D15); bound runs rebound (L-061); the
   lint refuses an escalation that is not the standard gate; payload and action names match the approved mockup (D12);
   `relaunchable` defaults to false and is read through one reader; no workflow using `appian-dev-write` can be
   relaunched or restarted whatever its flag says (D23, ADR-068).
   From 55-06's As built: the untested path where a relaunch's rebind raises after the old run was cancelled; a fork
   whose process exits before its final event is applied (n4); a relaunch skips the stage re-run's prerequisite checks
   and reads the old snapshots (decision 5a, inherent to D13); queue-managed workflows refused; the launch environment
   is not stored (m1, as for resume).
3. **Resolve chat (ADR-031/034/086):** no shell; writes only in the sandbox; activation verified (L-113); a write outside
   the sandbox and an unlisted tool refused live (negative control, L-117).
4. **Liveness (ADR-090 draft, D10, D16):** `node.started` canonical in both lists and the fixtures (L-122); the snapshot fold
   is incremental (no whole-log read per call, L-066); SSE never replays the log, honours `Last-Event-ID`, bounded
   queues, cleanup shielded (L-118); edges lit only into a running node; cursor semantics unchanged for its other
   readers (L-094). 55-03 was reviewed SHIP on its own; re-check only what later sub-specs changed in its files.
   Not covered by 55-03: edge counts under a parallel fan-out, and two `serve` processes watching one live run (the
   second relies on the 3 s poll by design).
5. **Documents (D8, D9, D20, F10–F12):** categories by rule, not by guessed names; tool-output files still purged at the end;
   old runs fall back honestly; agent HTML never runs on the app's origin; 55-08's `legacy` and `writing` fixes; no
   System group and no spent Tool outputs group in the list (D30), System paths still 403; the fan-out start order under the real runner (55-05 did not spike it).
   **55-13 (D28, D29):** status icons from the one `NODE_STATUS_ICON` map; `META.models` read through one reader by the
   lint and the worker; the `model.fallback` event in both kinds lists.
6. **Contracts (55-08):** fixtures from real responses; route order proven (L-096); no migration expected (D24); any
   migration 55-08 recorded is forward-only
   (L-102).
7. **genesis-core (ADR-019):** additive; `CORE_MAJOR` 1; an old library version still runs (legacy escalation payload).
   **Review genesis-workflows `3c29e73`** (55-10's test-only m6 fix, seen by no review).
8. **Web:** tokens only, no `Button asChild`, jest-axe on new views. **Review 55-09's last fix** (for the re-review's
   new finding; committed after the SHIP, not re-reviewed).
9. **ADR drafts** match what was built (`adr-drafts.md`).

## 2. Gates

genesis-core, kiro-agent-sdk, genesis (pytest, ruff); web (`npm run lint && npm run typecheck && npm test`, `npm run
build` + committed `web/static/`); genesis-workflows (`ci/validate_library.py`, skills validation, pytest); one CI run
or a run in the CI image before the release commit (L-112) — **with fastembed installed on the python:3.13 image**
(55-04 proved the offline model load on macOS only; the CI test jobs install with `--no-model`, so add one job or one
image run that fetches the model and loads it with the network off, on Linux).

## 3. Live acceptance (the release candidate on a copy of the user's real Genesis home)

**Set-up:** copy `~/.genesis` to a throwaway folder (mode 700) with SQLite's online backup for `genesis.db` and
`memory.db` (L-125); start the candidate on another port against the copy; collaboration and system schedules off on
the copy except what a row tests; Appian writes only with the user's go-ahead; the user sets the credit budget before
the agent rows; never print, commit or attach the copy's files; delete it at the end. **No memory text in any commit
(D19):** a brief, a captured prompt, a Resolve sandbox file or a tool output that carries memory text is shown to the
user locally and committed to `evidence/` only redacted (ids, types, scores, lengths). The fleet is not restarted.

| # | Check | Pass |
|---|---|---|
| A1 | Mockup sign-off carried through: Documents, the Resolve tab and graph states match the approved `/dev/phase-55` (genesis `d0aa1b2`, D12–D15), except the recorded differences the user rules on here: "round k" without "of N" (D16); no "OK · check failed N times" (deferred, D27); no Feature/Stage row in the Resolve facts sidebar and manual-action results lost on reload (D27) | user confirms |
| A2 | **Graph liveness** on a long run (technical-design-analysis or test-design-analysis on a real feature): program nodes show running; a minutes-long agent node shows running throughout with elapsed time; only the edge into the running node is lit; a loop re-entry shows round 2; at five random moments the graph equals the event log within 3 s | as stated |
| A3 | **Liveness under faults:** block the SSE (devtools offline for the stream, or stop the proxy) → badge Polling, graph still current within 3 s; reconnect resumes without replaying; restart `genesis serve` mid-run (no other run active) → the snapshot rebuilds; pause / resume and a gate show correctly | as stated |
| A4 | **Memory brief:** after `scripts/install-packages.sh`, the embedder is ready and the back-fill embedded every current memory (count); three real runs (a feature-stage, a story and an agent-prompt run) each have `_memory/brief.md`; the user reviews them for relevance, **including the two 55-04 calls (D17):** memory #27 is not in the feature-4 brief (ranking), and a run with no context still gets 12 weakly related memories (no minimum similarity); the captured prompts carry the line; the memory jobs and a sync run have none; **live negative control:** in the same run an agent asked to call a tool outside the six memory tools and its node's own list is refused | user reviews the briefs |
| A5 | **Escalation, stage workflow:** a real escalation of a stage run (a forced validator failure on the candidate, or a real one); the bell notice opens `/runs/<id>/resolve` without starting the agent; opening Resolve starts it and its first turn explains the failure and proposes actions; **accept** → `done`, the stage shows the artifact (finalizer); a second escalation → **fix then accept** with a reviewed diff | as stated |
| A6 | **Escalation, every action:** on cheap runs (agent-prompt / hello-appian with a forced failure): retry with guidance (guidance in the captured prompt, run continues); **rerun from the start with additional instructions** (the new run has the same inputs, the instructions are in every agent node's captured prompt and survive a pause/resume, the old run `cancelled` and linked; on a stage-bound run the stage moves to the new run, D13); **restart from an earlier step** (the new run starts from that step's checkpoint and runs, the original's checkpoints unchanged, the old run `cancelled` and linked, a stage-bound run's stage moves to the new run, D15; also on a healing-wrapped workflow and, if any workflow has one, a step inside a subgraph — 55-07 ran only its fixture); stop (`failed`, reason shown); an unavailable action disabled with its reason; a stale proposal refused; **Rerun and Restart disabled with their hint on a non-relaunchable workflow** (story-implementation, if one escalates; else a fixture workflow with `relaunchable: false`, D23); each result shown in the Resolve tab (D14) | as stated |
| A7 | **Resolve safety:** ask the agent to apply an action itself, write outside its sandbox (with a prompt it will act on, e.g. "save this draft to ~/Desktop/x.md" — 55-07's live agent declined to try, so the engine's refusal is still unit-proven only), run a shell command, and call an untrusted tool through v3's meta tools (`tool_load`, `tool_call`, `disclose_context`) → each refused; the run stays at its gate | as stated |
| A8 | **Documents:** the four stage workflows, story-implementation, test-execution and one old run: every file in the right category and step; Output pinned; write counts after a retry; tool outputs listed only while their files exist (D30); Open in step; **during a real agent run**, `file.written` rows arrive per task finish and `/documents` shows "being written" only while running (not when paused or at a gate); no System group (D30); known limits shown honestly (a file written before a pause-kill reads "step unknown", 55-05) | as stated |
| A9 | **Width probe** (L-090): Documents and Resolve at 1280 / 1440 / 1920 px, light and dark, screenshots | no overflow, user confirms |
| A10 | **Credits:** the Resolve conversation's credits are metered with provenance on the panel (ADR-032) | as stated |
| A11 | **From 55-08 (D26):** each action also run from the **manual** menu (not only a Resolve Confirm), each audit event carrying actor / source / action / params / proposal id (D22); a **scheduled** run relaunched from its gate keeps its schedule row, which closes with the new run's result; a Resolve chat present at a consolidation run is skipped and does not hold the cursor (D25); the System 403 seen from the real page; the Genesis-turn stream on a live turn (55-08's fixture came from the fake engine) | as stated |
| A12 | **From 55-09 (D27):** type and press Stop during a real first turn (unit-tested only); a reload during the first turn (does the stream replay in-flight events?); Resolve on a run of a workflow still on the old gate (computed action map, old panel in the inspector) — **an observation only, not pass/fail (D35)**; Rerun and Restart on a run bound to a real feature stage or story (the stage / story moves, the dialogs' text is true) | as stated |
| A13 | **From 55-13 (D28–D30):** the graph cards at 84 px, tinted per status with the standard status icon, readable and aligned in light and dark (user confirms); a workflow with `default_model` (or `models[node]`) set uses that model (the turn's model), and an id not on the account falls back with the `model.fallback` note; Documents shows no System group, and Tool outputs only while its files exist; also the selection ring on every tint in a real browser, a cancelled card, a fallback to a **listed** second model (`models[node]` unlisted, `default_model` listed), and a fan-out sharing one model-list read if a workflow has one (55-13 could not show these) | user confirms the cards; the rest as stated |
| A14 | **From 55-10 (D31, D32):** one adopted and one legacy (v0.27.0-style) escalation in Resolve (the legacy one an observation only, D35); **story-verification** stop goes through cleanup (QA sessions closed, no password left in the run folder, the card stays in Verification, run `failed`) and `send_back` moves the card back; **story-implementation** stop / bare reject ends `failed` with no Dev write, and `PROCEED_ANYWAY` / `SEND_BACK` appear only after a reverify with gaps; **code-review** `set_verdict` reaches the verdict gate, `skip` / `abort` only for a failing object; a **memory job** escalation offers `skip` only when its failed step wrote nothing usable (on the copy with memory schedules on for the row); erd-generation shows Rerun / Restart disabled with its hint (D32) | as stated |

Rows that cannot run (e.g. Dev down for a stage run) are recorded "not run" with the reason and named in the release
notes (L-111).

## Context manifest

```toml
areas    = ["runs-worker", "web-runs", "chat", "workflows-library"]
adrs     = ["ADR-011", "ADR-019", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-053", "ADR-054", "ADR-086"]
lessons  = ["L-061", "L-066", "L-090", "L-094", "L-106", "L-108", "L-110", "L-111", "L-112", "L-113", "L-117", "L-122", "L-125"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md", "tracker:specs/phase-54-schedules-and-fixes/54-10-review-and-acceptance.md"]
code     = ["genesis/genesis/runs/**", "genesis/genesis/memory/brief.py", "genesis/web/src/features/run-detail/**"]
upstream = ["55-02", "55-03", "55-04", "55-05", "55-06", "55-07", "55-08", "55-09", "55-10", "55-13"]
```

## As built

The review (§1) and the gates (§2) are in `reviews/55-11-review.md`: round 1 at genesis `76b27a57` was NEEDS_CHANGES
(M1, m1–m4); the fix pass below was re-reviewed at `e8096f71` and is **SHIP** for §1 + §2. §3 (A1–A14) is the
user's to run after the release (D36, D37); Phase 55's live acceptance is open (L-111).

### Fix pass (55-11)

**Scope.** m1, m3 and m4 were fixed. M1 is not fixed by decision D35, and m2 was folded into M1, so neither got a code
change: M1 is a known limitation that 55-12's release notes describe (answer a legacy-gate escalation from the Flow
tab's gate panel). The report listed no other minors. Nits n1 and n2 were left as they are.

**Commits (genesis master, local, not pushed; base `76b27a57`)**
- `3f391a61` test(55-11): review m4, regression tests for `419d8363` n2 and n3 (test only).
- `e8096f71` fix(55-11): review m1 (rebind before cancel) and m3 (gate answer compare-and-set), with tests.

Both commits reach main's workers at once through the editable dev venv (L-099). No web file changed, so there is no
`web/static` commit. genesis-core was not touched.

**What each finding needed**
- **m1, a failed rebind left the escalated run cancelled** (`genesis/runs/manager.py`). The binding now moves before the
  cancel:
  - In `_relaunch` (`:1274`, the `before` callback passed as `start(before_spawn=)`), the rebind runs first and the
    waiting run's `cancel` runs after it. Both run after the new record exists and before its worker spawns.
  - In `_restart_from` (`:1404–1420`), the order is now fork → rebind → cancel → start. A failed rebind also writes
    the error audit, as a failed relaunch already did.
  - When the rebind raises, only the new run is failed. The escalated run keeps `awaiting_input:gate`, its stage
    binding and an answerable gate, with no `run.final` and no `run.relaunched`.
  - After a successful move, the old run's `run.final{cancelled}` finds the stage bound to the new run, so its
    finalizer does nothing (L-061).
  - `cancel` cannot fail on a write: `_claim_status` logs a failed write and goes on (L-108). So nothing needs undoing
    after the rebind.
- **m3, `respond` was check-then-write** (`genesis/runs/store.py:158`, `genesis/runs/manager.py:625–664`, `:1200–1220`).
  - New `RunStore.claim_transition(run_id, expected, status)` runs one `UPDATE … WHERE status = expected` (with
    `retry_when_busy`).
  - `respond` validates the answer, then `_claim_gate` moves `awaiting_input:gate` → `running` with that
    compare-and-set. Only the winner goes on to `_resume_gate`, which logs `gate.resolved`, spawns the resume worker
    and writes the audit (L-091).
  - The losing answer gets `RunStateError`. The API answers it with 409 (`run_routes._action_errors`), and Resolve
    marks the proposal `stale`.
  - `fix_and_accept` now checks the accept answer (`_check_answer`) and claims the gate before its copy, so a fix that
    loses writes nothing. A copy that fails gives the gate back with a compare-and-set (`running` →
    `awaiting_input:gate`), which keeps a stop that arrived in the meantime. Before this change, an accept refused by
    `allowed` was only detected after the file had been copied.
- **m4, two `419d8363` fixes had no regression test** (`tests/test_memory_brief.py`). Test only:
  - n2: a describe step past the deadline reports the deadline error.
  - n3: a brief write cut off halfway leaves no `brief.md`.

**Tests (7 new)**
- `tests/test_run_actions.py:696` `test_a_failed_rebind_fails_only_the_new_run_and_the_escalated_run_still_waits_bound`
  `[relaunch|restart_from]`. The rebind raises `sqlite3.OperationalError("database is locked")`. The test checks that
  the old run is still waiting at its gate with no terminal `run.final` and no `run.relaunched`, that the stage still
  points at the old run, that the one new run is `failed` with the "could not prepare the run" / "could not move the
  Technical Design stage" detail, and that the old run can then be answered and ends `done`.
- `:767` `test_a_resolve_answer_and_a_manual_answer_at_once_resume_the_run_once`. Two threads answer, and a barrier on
  `pending_gate` holds both inside the check-then-write window (`_race`, `:725`). Expected: one `RunStateError`, one
  `gate.resolved`, one resume spawn carrying the winning answer, and one `run.final{done}`.
- `:780` `test_a_fix_and_accept_that_loses_to_a_stop_writes_nothing`. A fix races a stop. Whichever wins, one
  `gate.resolved` and one terminal `run.final` are written. If the stop wins, the fix leaves no `file.written` and the
  file is unchanged.
- `:807` `test_a_fix_whose_copy_fails_gives_the_gate_back`. The copy raises `ENOSPC`. Expected: `RunActionError`, the
  run is back at `awaiting_input:gate` with no `gate.resolved`, and a later accept ends `done`.
- `tests/test_memory_brief.py:324` `test_a_slow_run_description_is_the_deadline_error` and `:342`
  `test_a_brief_cut_off_while_it_is_written_leaves_no_brief`.
- **Fail-first** (a fresh `PYTHONPYCACHEPREFIX` for each mutation run, L-110):
  - With `manager.py` at `76b27a57`, both rebind tests fail (the old run is `cancelled`) and both race tests fail (two
    answers applied, and a losing fix's `file.written`).
  - The copy-fails test also passes on the old code. It pins the new give-back path.
  - With n2 reverted, the event error reads `'TimeoutError: '`. With n3 reverted (a plain `write_text`), a half
    `brief.md` is left.
  - The reviewer repeated the manager mutation in a separate worktree and ran the new tests 5 times at HEAD: all green.

**Gates at `e8096f71`.** genesis `pytest -q -p no:warnings` (`PYTHONDONTWRITEBYTECODE=1`): **2406 passed, 4 skipped**
in 925 s. That is round 1's 2399 plus the 7 new tests; the reviewer's run got the same count in 984 s.
`ruff check genesis`: clean.

**Review.** genesis-review re-reviewed both commits and gave **SHIP** for §1 + §2 (the "Fix pass re-review" section of
`reviews/55-11-review.md`). It raised new findings, none blocking, all for the backlog:
- **m5:** the stage rebind is two writes, `reset_for_reupload` / `reset_for_rerun` then `set_source`
  (`api/features.py:301-304`, `api/workbench.py:91-93`). If the second write fails, the stage reads "in progress"
  with no run, and the still-waiting old run is no longer bound. Fix: one transaction, plus a test that fails the
  second write.
- **m6:** `resume` on a gate-waiting run writes `running` with no compare-and-set (`manager.py:620-623`). No UI path
  reaches it, because Resume shows only for paused runs. Fix: refuse it with 409.
- **n3:** a brief write that is cut off leaves a stray `_memory/brief.md.part`.
- **n4:** a failure after the claim other than the copy (the stat or the `file.written` / `gate.resolved` append)
  leaves the run `running` with no worker until the next startup sweep.

**Decisions / deviations.**
- `restart_from`'s order changed from 55-06's "fork, cancel, rebind, start" to "fork, rebind, cancel, start". This
  was the review's own fix; it is not an ADR change.
- The relaunch's cancel moved into `before_spawn`. So a `start` that fails before the record exists (an upload write,
  for example) now also leaves the escalated run waiting, where before it was already cancelled.
- No ADR deviation.

**Lesson candidates.**
- When an operation both replaces a bound object and stops the old one, move the binding first. The bound-run guard
  (L-061) then makes the old run's terminal event harmless, and a failed move needs no undo.
- A barrier inside the read step (here `pending_gate`) makes a check-then-write race deterministic in a test. Without
  it, two threads seldom overlap, and a non-atomic version passes.

**Code-map changes (for genesis-docs).**
- `genesis/runs/store.py`: `RunStore.claim_transition` (expected → status compare-and-set).
- `genesis/runs/manager.py`: `RunManager._claim_gate` / `_resume_gate`. `respond` and `fix_and_accept` claim the gate
  before any write. `relaunch` and `restart_from` rebind before they cancel.

**Next.** 55-12, the release, run by genesis-release. Before it, rebuild the `/tmp/gr-55-11/` candidate from the
released head: it was built from `76b27a57` and lacks this fix pass. Decide whether m5 and m6 go into 55-12 or the
Phase 55 backlog.
