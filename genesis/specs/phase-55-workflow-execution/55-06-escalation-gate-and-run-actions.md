# 55-06 — The standard escalation gate and the run actions behind it

> **Status:** BUILT 2026-11-23 (review SHIP; As built below). SPEC-DRAFTED 2026-11-22. Repo: genesis (`packages/genesis-core/genesis_core/nodes/`,
> `genesis/lint/reliability.py`, `genesis/runs/manager.py`, `genesis/api/features.py`, `genesis/api/workbench.py`).
> Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. Decisions: D6 (as amended by D13, D15),
> D12 item 10, F6, F8, F9 (`55-01-findings.md`). ADR draft: ADR-089 (`adr-drafts.md`; amends ADR-011, ADR-031, ADR-033). The library adopts the
> gate in 55-10; the Resolve agent is 55-07. The relaunch registry (§3) also touches `genesis/api/features.py` and
> `genesis/api/workbench.py`: kept out of the manifest to hold the pack under budget, so before changing them load
> `genesis-ctx area features-stages` and `area stories-workbench` and the full ADR-050, ADR-084, ADR-035 texts.

## 1. `escalation_gate` (genesis-core, additive; `nodes/escalation.py`, new)

- `escalation_gate(name, *, failed_node, retry_to, accept_to, prompt_fn=None, extra_options=None)` returns a node
  marked `_genesis_kind = "escalation_gate"` and a router. Built on `interrupt()` like `hitl_gate`
  (`nodes/gate.py:19-54`, kind `escalation`, ADR-021).
- `attach_reliability` (`nodes/reliability.py:25-75`) and `attach_healing` (`nodes/healing.py:87-161`) accept it as
  their escalation target; `retry_to` defaults to the failed agent node (reliability) or the healing restart target
  (healing), `accept_to` to the validator's pass successor (reliability) or the post-verify node (healing).
- **Payload (F6; field names fixed by the approved mockup, D12 item 10 — `web/src/dev/mockups/phase55/fixtures.ts`
  `ESC_GATE`, `HistoryEntry`, `ActionKey`):** today's fields (`node, kind, prompt, options, context_refs, raised_at`)
  plus, flat: `failed_node`; `validator_messages: [str]` (the failed node's last validator / critic findings);
  `history: [{at, kind: verify|heal|restart|retry, text, ok?}]`; `last_error: str | null`; `files: [{path, role,
  bytes, writes, check?: passed|failed}]`; `allowed: {retry, accept, fix_accept, relaunch, restart_from, stop: null |
  "<reason it is unavailable>"}` plus one key per `extra_options` entry. Core fills `failed_node`,
  `validator_messages`, `last_error` and `allowed` for the gate-level actions from state (L-106): `accept` and
  `fix_accept` only when the failed node's output exists and is non-empty, else the reason (e.g. "technical-design.html
  was not produced: …"); `retry` and `stop` always. `RunManager`, when it logs `gate.awaiting`, adds `history` (with
  times, from the failed node's `validator.result`, `retry.scheduled` and healing events), `files` (55-05 roles and
  write counts) and `allowed.relaunch` / `allowed.restart_from` (run-level, §3). The enriched payload is what
  `snapshot.run.gate` carries (55-03), so the snapshot fold needs no change; the gate node already reads `awaiting`
  with a `waiting` edge. `interrupt()`'s `__interrupt__` updates chunk is filtered by the worker (55-03 `_internal`).
- **Answers** (keys = the mockup's `ActionKey`): `{"action": "retry", "guidance": str}` → `retry_to`, the node's retry
  budget reset (`retries[node] = 0`; for healing, the heal/restart budget reset), guidance stored in
  `decisions["<failed_node>.guidance"]`; `{"action": "accept"}` → `accept_to`, `decisions["<gate>.outcome"] =
  "accepted"` and `decisions["<failed_node>.accepted_unverified"] = true`; `{"action": "stop", "reason": str}` → a
  core terminal node that sets `status = "failed"` with the reason (L-065; the worker reports `failed`, not `done`);
  `{"action": <extra id>, ...}` → its route. `fix_accept`, `relaunch` and `restart_from` are run operations (§3), not
  gate answers. Legacy answers map: `"approve"` → accept, `"reject"` → stop (reason "rejected
  at the gate"), `{"feedback": text}` → retry with that guidance (L-106, Phase 54 note: every gate answer is routed).
- **Guidance in the prompt:** `kiro_node` (`nodes/agent.py:364`, after the 55-04 memory line) appends "Guidance from
  the user after an escalation: <text>" when `decisions["<node>.guidance"]` is set; cleared when the node next passes
  its validator, so an old round's guidance does not leak into later prompts (54-05 review n4).
- **Run instructions in the prompt (D13):** `kiro_node` also appends "Additional instructions from the user for this
  run: <text>" to **every** agent node's prompt when `ctx.extras["run_instructions"]` is set (the worker sets it from
  the run's `trigger.instructions`, §3), beside 55-04's `MEMORY_LINE`. Order: memory line, run instructions, node
  guidance. The captured prompt includes them (ADR-066). A relaunch is a new `op == "run"`, so it gets a fresh
  memory brief; `restart_from` (a fork) reuses the copied one (55-04).
- `CORE_MAJOR` unchanged; `hitl_gate` unchanged for approval / pre_mutation / review gates.

## 2. Reliability lint (F8)

`genesis/lint/reliability.py:71`: an agent node's escalation edge must reach an `escalation_gate` node. Custom options
live beside the standard ones as `extra_options` (story-verification's `send_back`, setup-composer's `discard`,
code-review's `skip` / `abort`, story-implementation's `PROCEED_ANYWAY` / `SEND_BACK`), not as a separate gate. The lint
is publish-time; an old library still runs, and the app handles a legacy escalation payload (none of the F6 fields:
only approve / reject / feedback, plus the run operations of §3).

## 3. Run operations (`RunManager`)

- **`respond`** (`manager.py:435-449`): accepts the action dicts; refuses (400) an action whose `allowed[action]` is a
  reason (not `null`) in the pending gate's payload, re-checked against the current payload at apply time.
- **`fix_and_accept(run_id, *, path, source_file)`:** only while the run waits at an `escalation_gate` and
  `allowed.fix_accept` is `null`; `path` must resolve inside the run folder, be an existing file of category output / intermediate / check
  (55-05), never `_kiro/`, `.kiro/`, `_toolcalls/`, `_prompts/`, `uploads/`; `source_file` must resolve inside the
  Resolve session's sandbox (55-07); atomic write; then `RunManager` logs one `file.written {path, node: "_resolve",
  source: "resolve", bytes, mtime}` itself — the worker's diff will **not** catch it, because the copy lands before the
  resumed gate task's start snapshot (55-05 As built) — and adds `"_resolve"` to `PSEUDO_NODES` (`genesis/runs/writes.py`)
  and the categorizer, so the file reads "Fixed in Resolve", not the step that wrote the earlier version; then
  `respond(accept)`.
- **Binding registry (shared by relaunch and restart_from):** one registry maps bound workflows to two operations:
  `rerun(run, trigger)` — the existing rerun entry points (stage runs: `genesis/api/features.py:1151,1413`; story
  design / implementation / verification: `genesis/api/workbench.py:227-386`, `reset_for_rerun`), extended to accept a
  `trigger` — and `rebind(old_run, new_run)` — move the stage / story binding to an existing run and set the stage back
  to in progress, as `reset_for_rerun` does, without starting a run. Unbound workflows have neither and skip it.
- **`relaunch(run_id, instructions) -> new_run_id` (D13, F9 as amended):** allowed when the run waits at a gate or is
  failed, cancelled or done. **Every input is reused unchanged** (binding keys included); file inputs are
  re-provisioned from the old run's `uploads/` (ADR-035). `instructions` is free text (bounded, e.g. 4,000 chars;
  empty allowed). A non-terminal run is first cancelled through the stop-intent + CAS path (L-108) with the reason
  "relaunched as <new id>". Bound workflows go through `rerun`; unbound ones through `RunManager.start`. The new run
  records `trigger = {source: "relaunch", from_run, instructions}` (`runs.trigger_json`, m0030; no new column); the
  worker passes `trigger.instructions` to `ctx.extras["run_instructions"]` on every op (run, resume, fork), so they
  persist for the new run's resume and fork. The old run gets a canonical `run.relaunched {to_run}` event (L-122). The
  handler returns the new run id and the caller follows it (L-120).
- **`restart_from(run_id, as_node, values=None) -> new_run_id` (D15):** allowed while the run waits at a gate or is
  failed / cancelled. It forks (`manager.py:653-669`, a new thread seeded from the checkpoint; the original's
  checkpoints and history untouched, ADR-025); the fork copies the blackboard (without `_kiro/`, `_toolcalls/`) into
  the new run first if `state.artifacts` point at the old folder (verify, then decide), and inherits the old run's
  `trigger.instructions`. Then, in this order: cancel the escalated run through the stop-intent + CAS path (reason
  "restarted from <node> as <new id>"); `rebind(old, new)` for a bound workflow (before the new run starts, L-061);
  start the fork running (not left paused). The new run records `trigger = {source: "restart_from", from_run,
  as_node}`; the old run gets `run.relaunched {to_run, as_node}`. The plain `POST /runs/{id}/fork` (ADR-009 mode 3)
  stays as it is: no cancel, no rebind, left paused.
- **Audit:** every action, from a Resolve proposal or the manual menu, is written to `copilot_actions` (proposal →
  confirmation → outcome), with the actor `user` and the source `resolve` / `manual`.
- **Finalizers:** accept ends the run `done` through the graph, so `StageFinalizer` and the story finalizers promote
  as today (L-093); stop ends `failed` (story verification's finalizer treats failed as today); test them through the
  real `_finalize`.

## 4. Tests

- Core: each action on a reliability-wrapped and a healing-wrapped fixture graph → route → stored outcome → run status
  (L-106); legacy answers; `available` rules; guidance appended once and cleared after a pass; stop → `failed`.
- Lint: a direct escalate→END edge fails; `extra_options` pass.
- `RunManager`: relaunch of an unbound run, of a stage-bound and a story-bound run (inputs unchanged, instructions in
  every agent node's captured prompt and still there after a pause/resume, rebound, old run cancelled once, no second
  `run.final`, L-108); restart_from (fork running, original's checkpoints unchanged, old run cancelled and linked,
  stage / story rebound before the new run starts, instructions inherited); the plain fork unchanged; fix-and-accept
  path checks (traversal, System, sandbox origin); fork copies the folder.
- Every existing workflow test in genesis-workflows still passes against the new core (55-10 changes them).

## 5. Gates

genesis-core pytest + ruff; genesis pytest + ruff; genesis-workflows `ci/validate_library.py` + pytest against the local
core. The F8 lint rule makes `validate_library` fail on every workflow that still escalates through `hitl_gate`
until 55-10 adopts the gate: record that the only new failures are that rule, workflow by workflow; every workflow's
own pytest must still pass (the old gates keep working at run time). The library's CI is unaffected until its pin
moves (55-12).

## Context manifest

```toml
areas    = ["core-engine", "runs-worker"]
adrs     = ["ADR-001", "ADR-011", "ADR-019", "ADR-021", "ADR-025", "ADR-033", "ADR-067"]
lessons  = ["L-020", "L-058", "L-061", "L-062", "L-065", "L-075", "L-093", "L-106", "L-108", "L-120", "L-121", "L-122"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/**", "genesis/genesis/lint/reliability.py", "genesis/genesis/runs/manager.py"]
upstream = ["55-02", "55-04", "55-05"]
```

## As built

**Status:** BUILT 2026-11-23, review **SHIP** (re-run 1). Repo genesis, branch master, base `3c3e38ae`, head
`88b57a52`, 3 local commits (not pushed, not tagged). No genesis.db migration; genesis-core additive (`CORE_MAJOR` 1);
no `web/static` change (the only web change is a test fixture under `src/test/`).

### Commits (genesis)

| sha | what |
|---|---|
| `6c6f93a5` | source, tests, web fixtures (`run.relaunched`) |
| `a9a1cce8` | review round 1: M1, M2, M3 tests, n1, n2, m3 |
| `88b57a52` | review re-run m4 (test) and n3 (one history wording line); after the SHIP, not re-reviewed |

### Changed

- **genesis-core** `nodes/escalation.py` (new): `escalation_gate(name, *, failed_node, retry_to, accept_to, prompt_fn,
  extra_options, output)` → `EscalationGate` (the interrupt node, `_genesis_kind = "escalation_gate"`; `<gate>_stop`,
  which sets `status = "failed"`; a router that returns node names). `ExtraOption`, `normalize_answer`,
  `validator_messages`, `verify_findings`, `ACTIONS`, `GATE_ACTIONS`, `RUN_ACTIONS`, `FROM_KEY`, `STOPPED_KEY`,
  `GUIDANCE_LINE`, `INSTRUCTIONS_LINE`, `guidance_key`. Exported from `genesis_core`.
  - Payload: `node, kind: "escalation", prompt, options, context_refs, raised_at` + `failed_node`,
    `validator_messages`, `last_error`, `allowed {retry, accept, fix_accept, stop, <extra ids>}`, `extra_options
    [{id, label, hint}]`. `options` = `approve` (only when accept is allowed) + `reject` + the extra ids, so the
    v0.83.0 Run Detail still offers an answer the state allows.
  - Answers: retry (budget `retries[node] = 0`, `decisions["<node>.guidance"]`; healing: `_healing` 0/0 + the
    guidance as carry-forward, `_iteration.pass` + 1), accept (`<gate>.outcome = "accepted"`,
    `<node>.accepted_unverified = true`, `<gate>.fixed` from fix-and-accept), stop (`_escalation.stopped`), extras
    (`<gate>.answer`), legacy approve / reject / `{feedback}`; an unknown answer stops the run.
- `nodes/reliability.py`: `on_exhaust_gate` may be an `EscalationGate` (registers the agent as a target, attaches the
  gate, the exhausting validator records `decisions["_escalation.from"]`); the validator clears
  `<agent>.guidance` on a pass; `agent_output`. `nodes/healing.py`: `gate` may be an `EscalationGate`; new
  `artifact=` (the assembled deliverable that gates Accept); the ladder registers `verify@healing` (retry →
  `restart_target`, accept → `nxt`, messages = the critic's open fixes); verify/heal trio exhaustion accepts into
  `nxt`. `nodes/agent.py`: `_user_lines` (the run-instructions line, then the guidance line, after `MEMORY_LINE`;
  in the captured prompt); `_genesis_output_doc` on the node fn. `nodes/validator.py`: `target_artifact` on the node.
  `types.py`: `NodeKind` gains `"escalation_gate"`.
- `genesis/lint/reliability.py`: F8, `ESCALATION_GATE`; an agent's escalation target must be an `escalation_gate`.
  `genesis/cli/create_workflow.py`: the template uses `escalation_gate`.
- `genesis/runs/bindings.py` (new): `Binding {workflow_id, find, rebind, label, refusal}`, `BindingRegistry`
  (`register`, `refuse`, `get`, `refusal`). `genesis/api/features.py` `_register_stage_bindings` (the four
  `StageFinalizer._BINDINGS` workflows; rebind = `reset_for_reupload` + `set_source(run_id=new)`, keeping a UX
  stage's `source.pdf`; test-design top-ups refused). `genesis/api/workbench.py` `STORY_BINDINGS`,
  `_register_story_bindings` (story-design-analysis, story-implementation; `reset_for_rerun` + `set_source`).
  `genesis/kb/stages.py`, `genesis/kb/story_stages.py`: `get_by_run(run_id, stage=None)`. `genesis/testexec/`
  `execution_service.py`, `verification_service.py`, `compose.py`, `recording.py`: refuse their workflow.
- `genesis/runs/manager.py`:
  - `RUN_RELAUNCHED` (canonical), `RunActionError`, `RELAUNCHABLE`, `RESTARTABLE`, `INSTRUCTIONS_MAX` (4,000),
    `FIX_REFUSED_DIRS`, `FIX_CATEGORIES`, `FORK_COPY_SKIP`, `HISTORY_MAX`; `self.bindings`; `_replace_lock`.
  - `_enrich_gate` (on `gate.awaiting` and the cold path) with `_gate_history` / `_gate_files` /
    `_relaunch_refusal` / `_restart_refusal`.
  - `respond(…, source, session_id, proposal_id)` + `_check_answer`.
  - `fix_and_accept`, `relaunch` / `_relaunch`, `restart_from` / `_restart_from`, `_reupload`, `_audit`,
    `_run_instructions`, `_stop_detail`.
  - `start(run_id=, before_spawn=)`, `cancel(detail=)`.
  - `_spawn` adds `job["run_instructions"]`. A plain `fork` records an inherited `trigger.instructions`, and only
    when the source has some.
- `genesis/runs/worker.py`: `job["run_instructions"]` → `ctx.extras["run_instructions"]` on every op.
- `genesis/runs/writes.py`: `RESOLVE = "_resolve"` in `PSEUDO_NODES`.
- Web (fixtures only): `run.relaunched` in `CANONICAL_EVENT_KINDS` with one golden event; `canonical-kinds.json`
  regenerated.

### Tests

- genesis-core `tests/test_escalation_gate.py` (22):
  - **Reliability graph** (real `kiro_node`, scripted collect, `MemorySaver`). The F6 payload. Accept, retry and
    stop each → route → outcome → status. Guidance appears in every prompt until a pass (`[0, 0, 1, 1, 0]`) and is
    then cleared. Stop sets `failed` and the graph completes. The legacy answers are mapped. An extra option routes
    and reports its availability. An empty output makes Accept unavailable and drops approve from `options`. An
    unknown answer stops the run. The instructions line appears in every prompt, ordered memory < instructions <
    guidance, and is in the captured prompt.
  - **One gate, two agents** (M3). The second agent's escalation retries only that agent and accepts into its own
    successor.
  - **Healing graph.** Ladder exhaustion gives the payload (critic fixes). Accept goes to `present`. Retry goes to
    `restart_target` with the budget reset and the user's guidance. Stop. Accept is unavailable on an empty
    artifact. Verify-trio exhaustion: retry re-runs verify and accept skips heal.
- `tests/test_lint.py` (+4): a hitl_gate escalation fails F8, `escalate → END` fails, a shared gate with extra
  options and healing passes, and the scaffolded workflow passes.
- `tests/test_run_actions.py` (24; REAL subprocess workers, the real `kiro_node` over a provider set in
  `build(ctx)`, an observer that reads the stored status at each `run.final`):
  - **Gate.** The enriched payload, also in `snapshot.run.gate`. Retry, accept, stop and the 3 legacy answers each
    end in the right stored status, with exactly one terminal `run.final`, through the real `_finalize`. Refusals by
    `allowed`, by run operation, and by fix-accept. A legacy escalation gate takes the action dicts.
  - **Relaunch.** From a gate: cancelled once with its detail; `run.relaunched` comes after `run.final`; inputs
    unchanged; the trigger is recorded; the instructions are in every agent prompt and survive a pause → resume and
    a gate resume. From a done run, and a second relaunch is refused. Two relaunches at once give one new run.
    Refused while running or paused, and over 4,000 characters. Uploads are re-provisioned.
  - **Bound runs.** A stage-bound and a story-bound run are rebound after the record exists and before any run or
    resume worker spawns (a spy on `_spawn`). A run whose stage moved on is refused. Queue-managed workflows are
    refused.
  - **restart_from.** The fork runs and the original's checkpoint count is unchanged. The original is cancelled and
    linked, and the binding is moved first. The folder is copied without `_kiro/` and the pointers moved. The
    instructions are inherited. The fork starts with a fresh retry and healing budget and no stale stop marker (M1,
    m4). A done run is refused. The plain fork is unchanged.
  - **fix_and_accept and audit.** Fix-and-accept refuses traversal, absolute, System, missing and `.part` paths, a
    source outside the sandbox, and a bad or unknown session id. On success it copies the file, logs one
    `file.written {node: "_resolve", source: "resolve"}`, the document reads `node: "_resolve"`, and the gate answer
    carries `fixed`. The `copilot_actions` audit is written for Resolve-sourced actions.
- **Mutation probes** (each killed, then restored): the restart rebind moved after the resume spawn; the replace lock
  removed; the restart resets removed; the healing reset removed; `target_for` ignoring `FROM_KEY` (the reviewer's
  probe). **L-122 negative control:** dropping `run.relaunched` from the web list fails `contract.test.ts`.
- **Gates.**
  - genesis full pytest: **2295 passed, 4 skipped** at `a9a1cce8`, on the dev venv with
    `GENESIS_STATE_DIR=/tmp/gr-55-06/state`; the reviewer reproduced it. At `88b57a52` only `test_run_actions.py` was
    re-run (24 passed).
  - `ruff check genesis` clean.
  - genesis-core: **152 passed**, `ruff check genesis_core` clean.
  - Web: `vitest run src/test` 26 passed, typecheck clean.
- **genesis-workflows against the local core** (the dev venv; no genesis-workflows change):
  - `ci/validate_library.py` exits 1 with **56 violations, all the F8 message**, in 16 workflows: action-capture 2,
    agent-prompt 1, code-review 8, erd-generation 2, feature-breakdown-analysis 4, generate-business-map 2,
    hello-appian 1, memory-consolidation 2, memory-maintenance 2, setup-composer 2, story-design-analysis 3,
    story-implementation 6, story-verification 5, technical-design-analysis 6, test-design-analysis 4,
    ux-design-analysis 6. sync-application, sync-documents and test-execution have no agent node. There are no other
    violations.
  - pytest: **456 passed, 7 failed**. The 7 are the tests that call `check_reliability` themselves, and each fails on
    F8: `_template`, action-capture, agent-prompt, code-review, hello-appian, setup-composer and story-verification.
    No routing or runtime test fails. Deviation from §4's "every workflow test still passes": the rule those 7 tests
    assert is the one §5 expects to fail. 55-10 makes them green, and must do so before 55-12 moves the pin.

### Review

`reviews/55-06-review.md`.
- **Round 1: NEEDS_CHANGES.**
  - M1: `restart_from` copied the exhausted retry and healing budget and the stop markers into the fork.
  - M2: an unchecked `session_id=".."` escaped the sandbox in `fix_and_accept`.
  - M3: no test covered the shared-gate target selection.
  - m1–m3, n1, n2.
- All fixed in `a9a1cce8` except m1 and m2, which are recorded below as limits.
- **Re-run 1: SHIP.** It raised m4 (the healing reset had no test) and n3 (the verify summary was dropped); both are
  fixed in `88b57a52` (not re-reviewed). n4 and n5 are recorded below.

### Decisions / deviations

No ADR deviation. The ADR-050 note: rebind writes the stage status through `reset_for_reupload` / `reset_for_rerun`,
the same direct path every existing re-run endpoint uses, as the spec asks. Choices the spec did not cover:

1. **One gate serves many agents.** Each `attach_*` registers a target; the exhausting validator / `heal_route`
   records `decisions["_escalation.from"]`. The router has **no path map** (targets register after the edge exists,
   and LangGraph copies a path map), so it returns node names; the lint reads the gate's kind marker. Keys live in
   `decisions` (present in every workflow state), not a new state channel.
2. **`failed_node` for a healing escalation is the verify node** (as the mockup). Accept depends on
   `attach_healing(artifact=)`. Without it (every current workflow until 55-10 passes it) Accept is always offered.
3. **The payload also carries `extra_options [{id, label, hint}]`** (the UI needs the labels). `options` keeps the
   legacy list, filtered by `allowed`.
4. **An unknown answer stops the run** (`failed`, "unknown answer at the gate: …") instead of ending it `done`.
5. **Relaunch does not call the stage / story HTTP re-run entry points.** They `rmtree` the stage dir the unchanged
   inputs point at and re-snapshot upstream artifacts, against D13. Relaunch starts with the old inputs and rebinds
   (reset + `set_source`) in `start(before_spawn=)`: after the record exists, before the worker spawns (L-061). The
   reviewer agreed. Consequences for 55-08 / 55-09:
   - (a) A relaunch skips the re-run's prerequisite checks, and the new run reads the old snapshots even if the user
     has since replaced the upstream artifact.
   - (b) **Relaunching a done `story-implementation` writes to Dev again** (ADR-068), so the confirm must say so.
   - (c) A later re-drag of the same story overwrites the snapshot file a relaunched run reads.
6. **Validate, then cancel.** Inputs and uploads are validated before the escalated run is cancelled. The new run's
   id is chosen first, so the cancel detail can name it.
7. **One run is never replaced twice.** `_replace_lock` makes the check, the cancel and the start one step, and
   `_replaced_by` (a logged `run.relaunched`) refuses a second relaunch or restart.
8. **Queue-managed workflows are refused** for relaunch and restart_from, with a reason that says where to restart:
   test-execution, story-verification, setup-composer and action-capture. They need their queue, execution record
   and checkout (ADR-081/082). A test-design top-up is refused too (it is bound to its top-up row).
9. **restart_from copies the folder.** State `artifacts` are absolute paths into the old folder, which I verified in
   `kiro_node` and the program nodes. So the folder is copied (without `_kiro/`, `_toolcalls/`, `.pids/`) and every
   pointer under it is rewritten into the seed. The fork's seed resets `status`, `retries`, `_healing` and the
   `_escalation.*` markers (review M1). The fork worker is checked before the original is cancelled (n1). The plain
   fork copies nothing, as before.
10. **The plain fork carries a relaunch's instructions** (`trigger {source: "fork", from_run, instructions}`), and
    only when the source has instructions (D13: "they persist for … fork"). Otherwise it is unchanged.
11. **Audit (deviation from D6's "every action").** `copilot_actions.session_id` is `NOT NULL` with a foreign key
    (m0006), so only a Resolve-sourced action with a session id is written there (proposal row + confirmation +
    outcome, `run.<action>`, args with `source` and `actor: "user"`). A manual action is recorded by the run log:
    `gate.resolved.source` and `run.relaunched.source`. Deleting the Resolve chat cascades its audit rows away. **For
    the spec agent:** either amend D6, or schedule m0031 (a nullable session, `actor`, `source`) in 55-08.
12. **fix_and_accept takes `session_id`** (not in the spec's signature): the sandbox is
    `skill_output_dir/<session_id>/`, and the id must be one plain segment of an existing chat session. 55-07 must
    still check that the session belongs to the run.
13. **Fix targets** must be an existing document of category output, intermediate or check, outside
    `_kiro .kiro _toolcalls _prompts uploads .pids checkout _memory`, not `*.part`, at most 25 MB.
14. **History wording** follows the mockup: "Verify round N: … (summary)", "Heal N: …", "Restart N: …". "of N" is not
    in the events. Retry entries are the failed node's failed checks and its `retry.scheduled`.
15. **Stop's reason** becomes the failed run's `detail` ("stopped at the gate: <reason>"), read from the worker's
    final state.

**Limits (recorded, not fixed):**
- m1: a run's launch `environment` is never stored, so a relaunch (and, already, a resume) uses the active
  environment.
- m2: a scheduled run that is relaunched or restarted leaves its schedule history on the cancelled run, because the
  scheduler follows the fire's `run_id`. This is a 55-08 follow-up: follow `run.relaunched.to_run`.
- n4: if a fork's process exits before its reader thread applies the final event, the fork reads PENDING and is
  taken as seeded. This is unlikely and untested.
- n5: `_iteration.pass` is not reset in the fork seed (cosmetic).
- A relaunch whose rebind raises after the old run was cancelled leaves the old run cancelled with no
  `run.relaunched`, and the stage may be left in progress with no run. This path is untested.

### Live effect before the release (the fleet runs from the editable dev venv)

New fleet workers import HEAD, but no installed library workflow uses `escalation_gate` (genesis-workflows v0.27.0
uses `hitl_gate`). So for fleet runs:
- the guidance line never appears (nothing sets `<node>.guidance`);
- the instructions line never appears (the v0.83.0 servers never send `run_instructions`);
- `_escalation.from` is never written;
- the `attach_reliability` / `attach_healing` string-gate paths are unchanged.

Nothing in `RunManager` reaches the fleet until a server restart. The CLI from the dev venv is live, though:
`genesis create-workflow` now scaffolds the standard gate, and `genesis test-workflow` (and the library's own
lint-calling tests, if run from this venv) fail F8 on today's workflows. Nothing was restarted and no live run was
made.

### Lesson candidates

1. **A fork copies the state that made the run fail.** A seed taken whole carries the exhausted retry counter, the
   spent heal budget and the gate's own markers, so a "restart" escalates at its first failed check. Reset what the
   restart is meant to renew, and test it with a step that fails once (review M1; the first test passed only because
   the copied turn counter made the step succeed).
2. **A path built from an id is a path.** `skill_output_dir / session_id` with `session_id=".."` made the sandboxes
   root the "sandbox". Check that an id is one plain segment of a real record before you join it (review M2).
3. **A loop variable can shadow a binding the code uses later.** `for key, val in resets.items()` replaced the stage
   key that `rebind(key, …)` used a few lines below. Only the ordering spy test caught it.

### Code-map changes (for genesis-docs, bible/03)

- genesis-core `nodes/escalation.py` (new) as listed. `reliability.py` `agent_output` and the `EscalationGate` path.
  `healing.py` `artifact=` and `verify@healing`. `agent.py` `_user_lines` and `_genesis_output_doc`. `validator.py`
  `target_artifact`. `types.NodeKind` `"escalation_gate"`.
- `genesis/runs/bindings.py` (new). `genesis/runs/manager.py`: `RUN_RELAUNCHED`, `RunActionError`, `relaunch`,
  `restart_from`, `fix_and_accept`, `_enrich_gate`, `_check_answer`, `bindings`, `start(run_id, before_spawn)`,
  `cancel(detail)`. `genesis/runs/writes.py` `RESOLVE`.
- `genesis/lint/reliability.py` F8 `ESCALATION_GATE`. `genesis/cli/create_workflow.py` template.
- `genesis/api/features.py` `_register_stage_bindings`. `genesis/api/workbench.py` `STORY_BINDINGS` and
  `_register_story_bindings`. `kb/stages.py` and `kb/story_stages.py` `get_by_run`. The four testexec services'
  refusals.
- Docs (genesis-docs): the reliability standard / `docs/architecture` text that names `hitl_gate` as the escalation
  target, and L-106 (every answer routed; the standard gate).

### For 55-07+

- **55-07 (Resolve):**
  - Call `RunManager.respond / fix_and_accept / relaunch / restart_from` with `source="resolve"`, `session_id` and
    `proposal_id` (the proposal row's `tool_call_id`). `_audit` writes the confirmation and outcome onto it
    (`INSERT OR IGNORE`, then update).
  - Check that the session is the run's own Resolve session before calling `fix_and_accept` (decision 12).
  - Build proposal cards from `gate.allowed` and refuse what it refuses. `allowed.relaunch` / `restart_from` are
    computed when the gate is raised, and the methods re-check them at apply time.
  - The sandbox copy can use `gate.files`.
- **55-08 (HTTP):**
  - Routes for `POST /runs/{id}/relaunch {instructions}`, `POST /runs/{id}/restart-from {as_node, values}` and
    fix-and-accept. `respond` takes action dicts.
  - Map the errors: `RunActionError` and `GateResponseError` → 400; `RunStateError` → 409; an unknown workflow
    (`FileNotFoundError`) → 409.
  - Follow the new run id (L-120).
  - Contract rows: the enriched gate payload (`history`, `files`, `allowed` with 6 + extra keys, `extra_options`)
    and `run.relaunched`.
  - The m0031 audit decision (decision 11); the scheduler follow-up (m2).
  - The relaunch confirm text for story-implementation (decision 5b).
  - `as_node` semantics: the fork continues after `as_node`, so "restart from step S" means `as_node` = S's
    predecessor. The UI must say which.
- **55-09:** a `_resolve` writer reads "Fixed in Resolve". The `<gate>_stop` node appears as a step in a stopped
  run's graph; the old Run Detail renders `options` (approve only when allowed).
- **55-10:** in every workflow with an agent node, replace the `escalate` `hitl_gate` with one shared
  `escalation_gate("escalate", extra_options=[…])` and pass it as `on_exhaust_gate=` / `gate=`. Pass
  `attach_healing(artifact=<deliverable>)`. Drop the `escalate → cleanup → END` edges, because accept and stop are
  routed by the gate; a workflow whose cleanup must run on stop needs an extra option or a later change. Move custom
  answers to `extra_options` (`send_back`, `discard`, `skip`/`abort`, `PROCEED_ANYWAY`/`SEND_BACK`). Turn the 7
  lint-calling tests and `validate_library` green. Add a healing-wrapped history assertion (n3).
- Cleanup for the user: `/tmp/gr-55-06/` (scratch state dirs) and the reviewer's `/tmp/55-06-probe/` and
  `/tmp/55-06-rerun/`.
