# 39-05 — genesis-workflows: node descriptions + `_iteration` stamps

> **Gate:** independent review = SHIP. Parent: `../phase-39-run-inspection-observability.md`.

## Scope
- **Descriptions:** add an authored `description` to **every** node in every workflow's `workflow.yaml` `graph.nodes[]` (all shipped workflows: hello-appian, erd-generation, code-review, sync-application, generate-business-map, ux-design-analysis, technical-design-analysis, feature-breakdown-analysis, story-design-analysis, memory-consolidation, memory-maintenance — whichever declare a `graph:`). Each description explains, in plain language, **what the node does** (1–3 sentences). UI-only (exempt from META parity).
- **`_iteration` stamps:** in each **loop / heal** program node, set `state["_iteration"] = {"pass": <verify/heal pass>, "item_label": <e.g. epic title>, "item_index": <n>}` so agent turns are grouped by item/pass in the turn explorer. Single-shot nodes need no stamp (turns render as a flat attempt list).
- Update the **workflow-authoring standard** (steering/reference) to require `description` on every node + the `_iteration` convention for loop nodes.

## Tests
- a lightweight check (or extend `validate_library`) that every `graph:` node has a non-empty `description`.
