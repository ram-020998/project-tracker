# Genesis — Phase 5 Implementation Record

> As-built record of Phase 5 (Run Orchestration & HITL). Companion to
> `specs/phase-05-run-orchestration-and-hitl.md`.

**Date:** 2026-07-09 · **Milestone:** M5 (Supervised runs) · **Status:** ✅ COMPLETE (code) — 40 platform tests green, ruff clean, pushed. Studio GUI demo documented (not runnable in this env — see §5).

---

## 1. Summary

"A graph that can run" is now "a supervised run": durable run records, a
**disposable subprocess worker** per run (ADR-012), a streaming event bus, and
**all three HITL modes** — designed gates (approve/reject/feedback), pause/resume,
and mid-run state injection (edit + fork). Exposed through a FastAPI backend
embedding the RunManager (ADR-023). The app never imports workflow Python; that
happens only inside the worker.

---

## 2. What was built (`genesis/runs/` + `genesis/api/`)
```
runs/store.py       # RunStore: SQLite `runs` table in genesis.db (WAL); lifecycle state machine
                    #   (pending→running→awaiting_input:gate|paused→running→done|failed|cancelled)
runs/events.py      # Event + EventBus: thread-safe fan-out with history replay for late subscribers
runs/validation.py  # validate_inputs (jsonschema vs META.inputs_schema, fail-fast); editable-key
                    #   guardrails (READ_ONLY vs DEFAULT_EDITABLE ∪ META.editable); merge_patch
runs/worker.py      # subprocess entry `python -m genesis.runs.worker`; ONLY place workflow Python is
                    #   imported (via Loader→compat gate); ops: run|resume|get_state|update_state|fork;
                    #   streams updates+custom; emits JSONL {node|custom|final|error}
runs/supervisor.py  # Supervisor.spawn: Popen worker, feed job on stdin, pump JSONL on a reader thread;
                    #   Worker.kill (pause/cancel) + worker-death detection (nonzero exit → worker_exit)
runs/manager.py     # RunManager facade: start/pause/resume/cancel/respond/get_state/patch_state/fork/
                    #   list/wait/events; per-run EventBus; state reads via checkpointer (no import);
                    #   event_run_id so fork attributes events to the NEW run
api/app.py          # FastAPI: POST/GET /runs, GET/PATCH /runs/{id}/state, pause/resume/cancel/respond/
                    #   fork, /artifacts, /stream (SSE via sse-starlette), /catalog, /config/health
api/studio.py       # `graph` factory for `langgraph dev` (interim Studio debug)
langgraph.json      # points Studio at genesis/api/studio.py:graph
docs/debug-in-studio.md  # how to attach Studio; product-path vs Studio table + limitations
```

## 3. HITL mechanics (how each mode maps to code)
- **Mode 1 (gates):** `hitl_gate` `interrupt(payload)` → worker emits `final` with
  `interrupts` → run status `awaiting_input:gate`. `respond(decision)` spawns a
  **fresh worker** with `Command(resume=decision)` → approve/reject route via the
  workflow's conditional edge; `{feedback:..}` lands in `decisions[<gate>.feedback]`.
- **Mode 2 (pause/resume):** `pause` kills the worker (state already checkpointed);
  `resume` spawns a fresh worker that continues from the last checkpoint. Proven
  durable by resuming through a **brand-new RunManager** over the same db.
- **Mode 3 (state injection):** `get_state` reads the checkpointer directly (no
  import); `patch_state` runs `update_state` in a worker after editable-key checks;
  `fork` seeds a **new thread** from the current state + edits (`as_node`), leaving
  the original untouched (ADR-025).

---

## 4. Verification (evidence — acceptance criteria §6)

| Criterion | Result | Test |
|---|---|---|
| Start with validated inputs; invalid rejected pre-run | ✓ | `test_happy_path`, `test_input_validation_rejects_pre_run`, `test_api_catalog_and_run` (400) |
| Live step timeline streams (node + events) | ✓ | `test_happy_path` (node+final events), SSE endpoint `test_api_*` |
| Mode 1: gate stops; approve continues; reject routes; feedback reaches next | ✓ | `test_gate_approve`, `test_gate_reject`, `test_gate_feedback` |
| Mode 2: resume continues from last checkpoint across app restart | ✓ | `test_resume_from_checkpoint_new_manager` (fresh RunManager resumes) |
| Mode 3: edit a decision at a pause; resume uses it; fork is independent | ✓ | `test_state_edit_then_resume`, `test_fork_creates_independent_run` |
| State-edit guardrails reject read-only keys | ✓ | `test_state_edit_rejects_readonly_key`, `test_api_state_patch_guardrail` (400) |
| Worker isolation: a crashing workflow fails only its run; app survives; resumable | ✓ | `test_worker_isolation` (RuntimeError → failed; next run still succeeds) |
| Everything demonstrable in LangGraph Studio | ⚠️ documented, not run | `langgraph.json` + `studio.py` + `docs/debug-in-studio.md` (GUI — see §5) |
| Full suite | **40 passed** (26 prior + 10 runs + 4 api) | ruff clean |

Tests use **program-only workflows** through **real subprocess workers**, so worker
isolation + checkpoint-driven resume are exercised end-to-end without a real Kiro.

---

## 5. Honest gaps / notes
- **"Demonstrable in Studio"** is a manual GUI step; this environment has no
  browser. Delivered the wiring (`langgraph.json`, `studio.py`) + a runbook
  (`docs/debug-in-studio.md`). Studio uses its **own** persistence (the langgraph
  dev server manages threads); it does not attach to the same `genesis.db` the
  product workers use — documented as a limitation. The **product path** (FastAPI +
  worker against `genesis.db`) is fully implemented and tested.
- **In-flight ACP `session/cancel`** (cancel a slow Kiro turn mid-node on pause) is
  an SDK-level enhancement; pause currently kills the worker at the process level
  (the node re-runs on resume, partial blackboard writes ignored) — consistent with
  ADR-012. Flagged for the kiro-agent-sdk.
- Retention purge endpoints (`/runs/purge`, `/artifacts/usage`) build on the Phase-4
  `retention` module; wired minimally (`/artifacts`) — full purge endpoints can be
  finished alongside the Phase-7 UI.

---

## 6. Repos & tags after Phase 5
| Repo | Tag | Change |
|---|---|---|
| `genesis` | **v0.5.0** | +`genesis/runs/` (worker/supervisor/manager/store/events/validation), +`genesis/api/` (FastAPI+SSE, Studio), langgraph.json, Studio doc; deps fastapi/sse-starlette/jsonschema |
| `genesis-core` | v0.3.0 | unchanged |
| `genesis-workflows` | v0.1.2 | unchanged |

---

## 7. Next: Phase 6 — ERD Reference Workflow
Build the flagship `erd-generation` workflow in `genesis-workflows` (agent nodes +
`erd-gen` cli_node + reliability trio + gates), validating the whole platform on a
real SDLC task; dry-run parity with the known-good ERD (~37 tables / 174 rels). See
`specs/phase-06-erd-reference-workflow.md`.
