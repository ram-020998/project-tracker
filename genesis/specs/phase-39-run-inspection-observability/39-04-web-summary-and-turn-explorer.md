# 39-04 — genesis web: summary pane + adaptive turn-explorer modal

> **Gate:** independent review = SHIP. Matches the approved 39-01 mockup. `web/static` committed. Parent: `../phase-39-run-inspection-observability.md`.

## Scope (`web/src/features/run-detail`)
- **Summary pane (single-click, below the graph)** — replaces the current 4-tab dump: the node **`description`** (prominent) → a compact **metrics strip** (executions, per-execution response times, credits per-execution + total, tool-calls, status) → a **"View details"** button. Uses the 39-03 iterations fold + topology description.
- **`NodeIterationsDialog` (the adaptive turn explorer)** — a very large modal:
  - **left rail** = the adaptive **Pass › Item › Attempt** tree (render only the dimensions present, per umbrella §3), each leaf a turn with scan-chips (status / ✕retry / credits / duration); keyboard-navigable.
  - **right pane** = the selected turn's detail — **Prompt** (lazy fetch `prompt_ref`) · **Artifacts / inputs provided** (image_docs + upstream artifacts) · **Conversation** (reuse `Conversation`/`TurnView`, scoped to the turn's seq range) · **Output** (doc + state delta — reuse `InputsOutputsPanel`) · **Metrics**.
  - **program / validator** turns → summary + generated artifact only (no prompt/conversation).
- Double-click a graph node also opens the modal.

## Tests / a11y
- vitest: adaptive tree renders correctly for each of the 4 shapes (single / retries / MAP-loop / +heal-pass); lazy prompt fetch; program-node summary-only. jest-axe on the modal + tree + summary pane. `npm run build` + commit `web/static`.
