# 39-01 — Research, contracts, ADR & mockup

> **Gate:** ⭐ user sign-off before any build. **Docs + `/dev` mockup only.** Parent: `../phase-39-run-inspection-observability.md`.

## Deliverables
1. **Capture contract** — finalize the additive events:
   - `agent.prompt` `{node, prompt_ref (blackboard file), model, mcp:[...], tools:[effective], image_docs:[...], iteration:{pass,item_label,item_index}|null, attempt}`.
   - `agent.result` gains `attempt` + `iteration` (rides `_CANONICAL_CUSTOM` verbatim into `run_events`).
   - the prompt file path convention (e.g. `_prompts/<node>-p<pass>-<attempt>-<seq>.txt`) + **retention rule** (default: keep prompt files; confirm vs cleanup) + **secret handling** (prompts embed only artifact text, but confirm no injected secrets; redact if needed).
2. **`_iteration` convention** — the reserved state key stamped by loop/heal program nodes; documented for the workflow-authoring standard. genesis-core reads it opaquely.
3. **Fold + endpoint contract** — `fold_iterations(events)` output shape (per §6 of the umbrella) + the decision of a **new `GET /runs/{id}/nodes/{node}/iterations`** endpoint vs a `/steps` extension.
4. **Topology** — `GraphNode.description` on `/workflows/{id}/graph` + run topology + `web/src/types/catalog.ts`.
5. **ADR-066** drafted (Proposed) + mirrored to `reference/decision-log.md`.
6. **Hi-fi coded mockup at `/dev`** (Phase 27–29 convention) of: the single-click **summary pane** (description + metrics) and the large **adaptive turn-explorer modal** — showing all four adaptive shapes (single turn / retries only / MAP-loop grouped by item / with an outer heal pass). Static fixture data; approved before 39-04.

## Decisions to lock here
- prompt-file retention + secret-redaction; new endpoint vs `/steps` extension; program-node per-turn artifact attribution; exact turn scan-chips + labels; modal size/interaction (double-click + "View details").

## Not in this sub-phase
No genesis-core/genesis wiring beyond the mockup route; capture + fold + real modal land in 39-02/03/04.
