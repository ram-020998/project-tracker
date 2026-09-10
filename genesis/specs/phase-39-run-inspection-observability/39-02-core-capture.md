# 39-02 — genesis-core: per-turn capture

> **Gate:** independent review = SHIP. Additive; `CORE_MAJOR` unchanged. Parent: `../phase-39-run-inspection-observability.md`.

## Scope
In `genesis-core/genesis_core/nodes/agent.py::kiro_node._run`:
- After building `prompt = prompt_fn(...)`, **write it to a blackboard file** (`ctx.workspace.doc("_prompts/<node>-p<pass>-a<attempt>-<seq>.txt")`) and **emit `agent.prompt`** with `{node, prompt_ref, model, mcp, tools (effective_tools), image_docs, iteration: state.get("_iteration"), attempt}`.
- Add `attempt` (already computed) + `iteration` to the emitted **`agent.result`**.
- Read `state["_iteration"]` opaquely (no workflow semantics in core).
- Keep everything additive — image-unaware / older peers unaffected; the manager's `_CANONICAL_CUSTOM` persists the new fields for free.

## Tests
- stubbed `collect`: assert `agent.prompt` is emitted with a readable `prompt_ref` whose file contains the prompt; `agent.result` carries `attempt`/`iteration`; a node with no `_iteration` emits `iteration: null`.
- retry path: two turns → `attempt` 1 then 2.

## Notes
- Honor ADR-010/018 — the prompt is a blackboard **file**, never inlined in the event. Respect the 39-01 retention/redaction rule.
