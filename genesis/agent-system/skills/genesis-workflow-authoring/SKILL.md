---
name: genesis-workflow-authoring
description: Use when authoring or changing a Genesis workflow (a LangGraph graph in genesis-workflows) — the reliability trio, attach_healing, META↔workflow.yaml parity, validate_library, and node descriptions. For the genesis-dev agent.
---

# Workflow authoring

Authoritative standards (read in ranges):
- `{{TRACKER}}/reference/workflow-authoring-standard.md`
- `{{TRACKER}}/reference/reliability-standard.md`
- Rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-011` (reliability trio), `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-067` (healing config) and
  `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-089` (the standard escalation gate), plus
  `{{GENESIS_HOME}}/bin/genesis-ctx area workflows-library`.

## Rules
- **Reliability trio is MANDATORY on every agent node** (ADR-011): a program validator + retry + escalation. CI enforces
  it. Attach healing via `attach_healing` with explicit `META.healing {max_heal, max_restart}` (ADR-067).
- **Escalate to the standard gate** (ADR-089, genesis ≥ 0.84.0): build ONE `escalation_gate("escalate", …)` per
  workflow and pass the object to every `attach_reliability(on_exhaust_gate=…)` and `attach_healing(gate=…,
  artifact=<deliverable>)`. A `hitl_gate` or `END` as the escalation target fails lint rule F8. Use `stop_to=<cleanup>`
  when a stop must run cleanup; put workflow-specific answers in `extra_options` with a state-built availability, and a
  state-built `prompt_fn` (L-106). Test every answer through the compiled graph with `genesis.testing.escalation`
  (`answer_gate`, `topology_gaps`, `cleanup_losses`); `workflow.yaml` `graph:` carries `escalate_stop` and one edge per
  gate route.
- **Phase 55 META keys** (each mirrored in `workflow.yaml`; one reader each, used by the app and the lint; full table in
  `{{TRACKER}}/reference/workflow-authoring-standard.md` §2.1):
  - `artifacts` as a role map `{<name or glob>: {role: output|input|intermediate|check, label}}` (the list form still
    passes but declares no roles); every deliverable is `output`.
  - `relaunchable` (default `false`) + `relaunch_hint`: may Genesis rerun or restart a run of it. `true` only when a
    fresh run with the same inputs is safe; never effective for a workflow using `appian-dev-write` (ADR-068).
  - `memory_brief: false` opts the workflow out of the run-start memory brief (ADR-088); `kiro_node(memory=False)` opts
    one node out.
  - `models` `{<agent node>: <model id>}` and `default_model`: precedence node's own `model=` → `models[node]` →
    `default_model` → Kiro's default; an unlisted id falls back with `model.fallback`. Every `models` key must be an
    agent node (`check_node_models`).
- `META` is a static importable dict with NO side effects; `workflow.yaml` MUST mirror `META` (parity lint; UI-only keys
  like `graph:` are exempt via `YAML_ONLY_KEYS`).
- `graph.py` is loaded standalone (importlib on the file): keep it self-contained — no sibling-package imports; put pure
  functions in `graph.py`. Node fns are `async fn(state, config: RunnableConfig)`; read ctx via `ctx_from_config(config)`.
- Every node has a clear description (shown in the UI and used by validation).
- `build(ctx) -> CompiledStateGraph` compiled with `ctx.checkpointer`.

## Gates
- `{{REPOS}}/genesis/.venv/bin/python -m pytest -q` for the workflow's tests.
- Run the library validator: `genesis ... validate_library` (the command the standard names) — META↔yaml parity and the
  reliability trio must pass before commit.

## Regression rule
A new node or edge gets a test; a reliability/parity fix gets a test that fails before it.
