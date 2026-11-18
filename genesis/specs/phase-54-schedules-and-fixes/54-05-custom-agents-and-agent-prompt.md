# 54-05 — Custom agents, per-run skills and servers in `kiro_node`, and the `agent-prompt` workflow

> **Status:** SPEC-DRAFTED 2026-11-19. Repos: genesis (`packages/genesis-core`, `genesis/runs/`, a new
> `genesis/agents/` package, `genesis/runtime/context.py`), genesis-workflows. Parent:
> `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev**. Decisions: D2–D5, D7, F3–F5
> (`54-01-findings.md` §8–§9). ADR draft: `adr-drafts.md`.

## 0. From 54-04's As built (read it: "For 54-05 / 54-06")

- **Hook:** `register_target_handlers(scheduler, run_manager=, executions=, kb_store=, agent_prompt_inputs=None,
  kiro_ready=None)` in `api/app.py`. 54-05 passes `agent_prompt_inputs=fn(target: dict) -> dict` returning the
  `agent-prompt` inputs (§4) with the custom-agent snapshot taken at call time. Raise `LookupError` or `ValueError`
  (agent gone, a server no longer pickable under D3) and the row is recorded `failed` with that message. The handler
  already checks that `agent-prompt` is installed and Kiro is signed in, and starts the run with its trigger; today it
  records `skipped` ("nothing to run in this build") until the hook is passed.
- **`schedulable`:** the workflow handler reads `meta.get("schedulable") is True`; §5 adds the key to the loader, the
  parity lint and the library.
- **`custom_agents`** exists (m0030) with the F3 columns: `name` UNIQUE, `skills_json` and `mcp_servers_json`
  default `'[]'`, `model` nullable. §1 builds the store over it; no migration change.
- A one-off Run (§6) leaves `trigger` None.

## 1. Custom agents store (`genesis/agents/`)

Over m0030's `custom_agents` (54-04 §1): `list`, `get`, `create`, `update`, `delete` (409 with the schedule names when
any `agent_prompt` schedule references it, F3), `snapshot(id)` → `{id, name, instructions, skills, mcp_servers, model}`.
Validation on write:
- `name` unique, 1–60 chars; `instructions` ≤ 20 000 chars;
- `skills`: ids of installed managed skills (`~/.genesis/.kiro/skills/`, Phase 53 D7/D8); unknown ids refused;
- `mcp_servers`: names that pass the **read-only server rule** (§2); a custom server needs `read_only_mark: true`;
- `model`: a model id the model list knows, or null.
Genesis never reads or writes `~/.kiro/agents` (ADR-086).

## 2. The read-only server rule (D3) — one function, one home

`pickable_servers(registry)` in one module, used by the custom-agent store, the schedule API (54-06), the schedule
handler at fire time (54-04 §4) and the `agent-prompt` node (defence in depth; L-109). A server is pickable when:
- it is curated, has a non-empty `tool_allowlist`, and is one of the read-only set: `appian-dev`, `genesis-kb`,
  `appian-atlas` (a named list in code, with a test that fails if a curated server is added to the registry without
  a decision: every curated name must be classified pickable or not);
- or it is a custom server and the pick carries `read_only_mark: true` (the user's claim, stored with the pick).
Never pickable: `appian-dev-write` (ADR-068), `appian-dev-packages` (ADR-073), `appian-devops`, `jira`, `jarvis`,
`appian-data-generator` (no allowlist = every tool, ADR-029/086).

## 3. genesis-core: `kiro_node` takes per-run `skills`, `mcp`, `model` (F4)

`kiro_node(..., mcp=…, skills=…, model=…)` (`packages/genesis-core/genesis_core/nodes/agent.py:273-312`) accepts either
today's static value or a callable `(state, ctx) -> value`, resolved when the node runs, before the session starts.
Everything downstream is unchanged: skills through `ctx.extras['skill_source']` with the front-matter check (L-115),
provisioning into the run's `.kiro/skills/` (ADR-069), MCP trust `node.tools ∩ allowlist` in the projected agent
(ADR-029/086, L-116), D9's built-ins, credits from `turn_completion` (ADR-032). Static callers are untouched; the change
is additive, `CORE_MAJOR` stays 1 (ADR-019). Unit tests: static and callable forms give the same `KiroAgentOptions`;
a callable naming a missing skill fails the node with the existing message.

## 4. The `agent-prompt` workflow (genesis-workflows, new)

- Folder `workflows/agent-prompt/` (`workflow.yaml` + `graph.py`, self-contained, no sibling imports; the L0-core §4
  contracts), version 0.1.0, `schedulable: true`, `auto_approve: true`, no `pre_mutation` gate (no write-capable server is
  possible, D3).
- `inputs_schema`: `prompt` (string, textarea, required, ≤ 20 000 chars), `agent` (object, optional: the snapshot
  `{id, name, instructions, skills[], mcp_servers[], model}`), `skills` (array of strings), `mcp_servers` (array of
  `{name, read_only_mark}`), `model` (string, optional), `title` (string, optional, used in the output's heading).
  Effective skills/servers = agent's ∪ the run's own; effective model = run's, else agent's, else Kiro's default (F5).
- Graph: `run_agent` (`kiro_node`, callables from §3, prompt = agent instructions + the user prompt + a fixed output
  instruction: write the answer as Markdown to `output.md` in the run folder) → `validate_output` (program: `output.md`
  exists, non-empty after strip, decodes as UTF-8) → retry `run_agent` up to 2 times → escalation gate (ADR-011,
  `attach_reliability`). The node re-checks D3 with the core's copy of the rule data passed in by the app (the worker
  never imports app code, ADR-012): the app passes the pickable decision in inputs and the node refuses any server not
  marked pickable; record the exact mechanism in As built.
- `graph:` topology in `workflow.yaml` (L-006); parity lint green (L-013).
- Output viewed in Run Detail's documents (`/runs/:runId/docs/output.md`); declare `output.md` as the node's
  `output_doc` so the existing document list shows it.
- Tests in the workflow folder (no `tests/__init__.py`, L-092): graph builds; validator passes and fails on the right
  files; the effective-set merge.

## 5. `schedulable` META key

- genesis: `META.schedulable` (bool, default false) read from `workflow.yaml` by the loader (`dist/loader.py`), exposed
  in `GET /api/catalog` items and `GET /api/workflows/{id}` (54-06), parity lint knows the key.
- genesis-workflows: `schedulable: true` on `agent-prompt` and on standalone workflows that are safe unattended. Check
  each candidate before flagging (no stage/story binding in the finalizer registry, no `pre_mutation` gate, no write
  server, inputs that can be stored): `sync-documents`, `generate-business-map`, `hello-appian`,
  `memory-consolidation`, `memory-maintenance`. Record the final list and the reason for each exclusion in As built.
- A schedule's stored inputs may not contain `format:"file"` fields this phase (files are uploaded per launch,
  ADR-035); a workflow whose required inputs include a file is not offered (a default set in this sub-spec; the user
  may object at review).

## 6. One-off Run of a custom agent (D5)

`POST /api/custom-agents/{id}/run {prompt}` → `RunManager.start("agent-prompt", inputs with the snapshot)`;
`trigger_json` stays NULL (not a schedule). Refused with a clear message if `agent-prompt` is not installed (L-033).

## 7. Gates

genesis-core pytest + ruff; genesis pytest + ruff; genesis-workflows `ci/validate_library.py`, `ci/validate_skills.py`
if present, pytest (`workflows --ignore=workflows/_fixtures`).

## As built

_(genesis-dev fills in: commits per repo, changes, tests, review verdict, decisions/deviations, lesson candidates,
code-map changes, Resume note.)_

## Context manifest

```toml
areas    = ["core-engine", "workflows-library"]
adrs     = ["ADR-006", "ADR-010", "ADR-011", "ADR-012", "ADR-019", "ADR-021", "ADR-029", "ADR-032", "ADR-035", "ADR-068", "ADR-069", "ADR-073", "ADR-083", "ADR-086"]
lessons  = ["L-002", "L-006", "L-013", "L-016", "L-033", "L-042", "L-092", "L-109", "L-113", "L-115", "L-116"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/runtime/context.py", "genesis/genesis/dist/loader.py", "genesis/genesis/lint/**", "genesis/genesis/agents/**", "genesis-workflows/workflows/agent-prompt/**", "genesis-workflows/registry.json", "genesis-workflows/mcp-registry.json"]
upstream = ["54-04"]
```
