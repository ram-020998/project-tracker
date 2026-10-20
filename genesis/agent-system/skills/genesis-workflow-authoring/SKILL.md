---
name: genesis-workflow-authoring
description: Use when authoring or changing a Genesis workflow (a LangGraph graph in genesis-workflows) — the reliability trio, attach_healing, META↔workflow.yaml parity, validate_library, and node descriptions. For the genesis-dev agent.
---

# Workflow authoring

Authoritative standards (read in ranges):
- `{{TRACKER}}/reference/workflow-authoring-standard.md`
- `{{TRACKER}}/reference/reliability-standard.md`
- Rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-011` (reliability trio) and `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-067` (healing config), plus
  `{{GENESIS_HOME}}/bin/genesis-ctx area workflows-library`.

## Rules
- **Reliability trio is MANDATORY on every agent node** (ADR-011): a program validator + retry + escalation. CI enforces
  it. Attach healing via `attach_healing` with explicit `META.healing {max_heal, max_restart}` (ADR-067).
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
