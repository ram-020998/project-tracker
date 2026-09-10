# Phase 39 — Run Inspection & Node Observability — AS-BUILT (🟢 BUILT 39-01..39-06; ⏳ 39-07 release pending)

> **Status (2026-09-10):** 39-01 → 39-06 **built + independently reviewed + all gates green**, committed **LOCALLY on `master` of each code repo (UNPUSHED, no tag)**. **39-07 (coordinated release) is NOT done** — no version bump, no tag, no push, no doc "shipped" stamp yet. The fleet was restarted so both instances **run the new code locally** for live testing. **Next session: pick up at 39-07.** Umbrella: `../specs/phase-39-run-inspection-observability.md`. ADR-066 (Proposed).

## What shipped into the local build

**39-01 — mockup + contracts (approved).** `/dev/run-inspection` hi-fi mockup (`web/src/dev/mockups/RunInspectionMockups.tsx`, route in `app/router.tsx`) — a Scenario control cycling the 5 adaptive shapes. Locked contracts in `../specs/phase-39-run-inspection-observability/39-01-findings.md`.

**39-02 — genesis-core capture** (`genesis-core`, additive; `CORE_MAJOR` unchanged). `nodes/agent.py::kiro_node`: before the turn, writes the rendered prompt to a blackboard file `_prompts/<node>-p<pass>[-i<idx>]-a<attempt>-<ms>.txt` and emits **`agent.prompt`** `{node, prompt_ref, model, mcp, tools(effective), image_docs, iteration, attempt}` (pointer-only — bytes never inlined, ADR-010/018); adds `attempt`+`iteration` to `agent.result`. Reads the reserved `state["_iteration"]` opaquely. +2 tests (`tests/test_agent_capture.py`).

**39-05 (core half) — `_iteration` channel.** `genesis_core/state.py::PlatformState` gains `_iteration: dict` (last-writer) + `new_state` default, so loop/heal program nodes can stamp `{pass, item_label, item_index}`.

**39-03 — genesis fold + endpoint + persistence** (`genesis`; no DB migration). `runs/manager.py`: `agent.prompt` added to `_CANONICAL_CUSTOM` (persisted to `run_events`) + `node_iterations(run_id, node)`. `runs/steps.py::fold_iterations` — folds one node's ordered events into per-**turn** iterations (agent turns delimited by `agent.prompt`→`agent.result`; `node.completed` after a result attaches its delta to the just-closed turn via a `has_agent` guard, never a spurious program turn; program/validator nodes = one turn per completion). `api/run_routes.py`: **`GET /runs/{id}/nodes/{node}/iterations`** (guarded). `web/src/types/catalog.ts::GraphNode` gains optional `description` (`loader.graph_of` already passes it through). +3 tests (`tests/test_run_inspection.py`).

**39-04 — web summary + adaptive turn explorer** (`genesis/web`). `components/Inspector.tsx` rebuilt: single-click = **summary pane** (node `description` + per-execution metrics: Turns/credits/tool-calls/time + per-execution response-time chips); **View details / double-click** → `components/NodeIterationsDialog.tsx` — the adaptive **Pass › Item › Attempt** turn tree (renders only the dimensions that occurred) + per-turn detail (Prompt lazily fetched via `prompt_ref`; Artifacts/inputs; Conversation = node events sliced to `[seq_start, seq_end]` reusing the existing fold; Output; Metrics). Program/validator = summary-only; old runs → honest "capture unavailable". `types/event.ts` (`NodeTurn`/`NodeIterations`), `lib/api/runs.ts` (`nodeIterations`), `lib/query/keys.ts`, `features/run-detail/hooks.ts` (`useNodeIterations`). +4 vitest (`NodeIterationsDialog.test.tsx`, incl. jest-axe).

**39-05 — workflow descriptions + `_iteration` stamps** (`genesis-workflows`). Authored a `description` on **every graph node of all 12 workflows (175 nodes)**. The 4 analysis workflows stamp `state["_iteration"]` in their loop drivers — feature-breakdown `_next_epic` (epic), technical-design `_next_analysis`/`_next_draft` (workstream), story-design `_next_object` (object); pass = verify-round; reset to pass-only at loop end. `ci/validate_library.py` gained a **non-fatal** description warning (now passes with zero warnings).

**39-06 — independent review & hardening.** A sub-agent auditor reviewed the whole feature (gates re-run green). Fixes applied: **M1** — TD/story-design/ux `_route_verify` now re-stamps `_iteration={pass: rounds+2}` on the revise branch (the revise loops back to `synthesize`, bypassing the item driver, so heal-pass turns were mislabeled `Pass 1`); **S1** — the summary "Executions" metric renamed to **"Turns"** (it counts agent turns incl. retries — distinct from `fold_steps.executions` = completion count). NITs N1/N2 (prompt-file item encoding; theoretical sub-ms filename collision) left as-is (cosmetic). Audit confirmed correct: no prompt-text leak, `fold_iterations` attribution, old-run/program-node handling, metric reconciliation, `_prompts/` retention (survives cleanup for lazy fetch; reclaimed by run retention).

## Verification (all green in the local build)
- genesis-core `pytest` **85 passed** + ruff.
- genesis `pytest` **790 passed** + ruff; web **tsc/eslint clean**, **vitest 270 passed**, `npm run build` ok, `web/static` rebuilt.
- genesis-workflows `ci/validate_library.py` **PASSED (12 workflows, 0 warnings)** + `pytest` **179 passed**.
- Fleet restarted (main :8760 / userb :8761 healthy, collab on); `/api/runs/{id}/nodes/{node}/iterations` live in OpenAPI. **New-runs-only** — capture appears on runs started after the restart.

## Local commits to release at 39-07 (UNPUSHED, on `master`)
- **genesis-core:** `d875a3f` (39-02 capture) → `94041e2` (39-05 `_iteration` channel).
- **genesis:** `5a6ceb3f` (39-01 mockup) → `af519017` (39-03) → `dca12513` (39-04) → `c7bd47f7` (39-06 S1).
- **genesis-workflows:** `4317e13` → `ba0856c` → `8ff3628` (39-05) → `ed72b16` (39-06 M1).
- **project-tracker (pushed):** specs `7236f96` + findings `fc95a97`.

## 39-07 — remaining (next session)
Release order (ADR-019): **genesis-core vX.Y.Z → genesis vX.Y.0 (re-pin core) → genesis-workflows vX.Y.0 (re-pin genesis)**. Bump the 3 genesis version anchors (`pyproject.toml`, `web/src/version.ts`, `genesis/api/app.py`); tag + push each; verify CI via `glab`. **No DB migration.** Then flip **ADR-066 → Accepted**, and complete the Definition-of-Done doc sweep at the released versions (bible §2 version/test-counts, §3 map already staged here, §4 ADR-066, §7 any lesson; tracker §6 → SHIPPED; this progress doc → COMPLETE; onboarding banner + Last-refreshed). **Live acceptance** (drill a real agent run's turns) is user-observed.
