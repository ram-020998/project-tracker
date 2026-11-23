# 55-06 — The standard escalation gate and the run actions behind it

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`packages/genesis-core/genesis_core/nodes/`,
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
  Resolve session's sandbox (55-07); atomic write; a `file.written {node: "_resolve", source: "resolve"}` event; then
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
core.

## Context manifest

```toml
areas    = ["core-engine", "runs-worker"]
adrs     = ["ADR-001", "ADR-011", "ADR-019", "ADR-021", "ADR-025", "ADR-033", "ADR-067"]
lessons  = ["L-020", "L-058", "L-061", "L-062", "L-065", "L-075", "L-093", "L-106", "L-108", "L-120", "L-121", "L-122"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/**", "genesis/genesis/lint/reliability.py", "genesis/genesis/runs/manager.py"]
upstream = ["55-02", "55-04", "55-05"]
```
