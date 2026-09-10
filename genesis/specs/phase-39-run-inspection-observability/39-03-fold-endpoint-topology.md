# 39-03 — genesis: per-iteration fold + endpoint + topology description

> **Gate:** independent review = SHIP. No genesis.db migration. Parent: `../phase-39-run-inspection-observability.md`.

## Scope
- **`runs/steps.py::fold_iterations(events)`** — framework-free (like `fold_steps`), reused by the introspection MCP. Per node, an ordered list of **turns**, grouped into the Pass › Item › Attempt tree:
  `{pass, item_label, item_index, attempt, seq_start, seq_end, status, duration_ms, credits, context_pct, tool_calls, prompt_ref, output_artifacts:[...]}`. Segment by `agent.result` boundaries; pass/item/attempt from the `iteration`/`attempt` fields captured in 39-02; per-turn `duration_ms`/`credits`/`context_pct` from that turn's `agent.result`; `output_artifacts` from `artifact.saved`/the node's declared output within the turn's seq range.
- **Endpoint** — `GET /runs/{id}/nodes/{node}/iterations` returning the fold (or a `/steps` `iterations` block, per 39-01). The prompt is fetched lazily via the existing `GET /runs/{id}/artifacts/{prompt_ref}`.
- **Topology** — `GraphNode` (backend topology model + `web/src/types/catalog.ts`) gains optional `description`; `/workflows/{id}/graph` + the run topology pass it through (UI-only, unaffected by META parity lint).

## Tests
- `fold_iterations` on a golden event log: a single-shot node (1 turn), a retried node (2 attempts), a MAP-loop node (N items, one retried), and a 2-pass (heal) log → correct grouping + per-turn metrics.
- endpoint returns the fold for a known run; topology carries `description`.
