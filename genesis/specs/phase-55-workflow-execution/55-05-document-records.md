# 55-05 — Document records: who wrote each file, its role, and one categorized list

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/runs/`, `genesis/lint/contract.py`,
> `packages/genesis-core/genesis_core/workspace.py`, `genesis/api/run_routes.py`). Parent:
> `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. Decisions: D8, D9, F10–F12 (`55-01-findings.md`).
> The library's roles and labels are 55-10; the web is 55-09.

## 1. Write records (`file.written`)

- **Where:** in the worker, using 55-03's task start/finish. At a task start, take a stat snapshot (path, size, mtime)
  of the run folder; at its finish, diff and emit one canonical **`file.written`** `{path, node, execution, iteration?,
  attempt?, bytes, mtime}` per new or changed file, attributed to that node (F10). This catches every writer — program
  code, validators, `kiro_node` output docs, agent fs writes — with no change to each node type.
- Excluded from the diff: `_kiro/`, `.kiro/`, `_toolcalls/` (tool outputs have `tool_output.recorded`), `_prompts/`
  (`agent.prompt`), `.DS_Store`. Files written before the graph starts (uploads, ADR-035; the memory brief, 55-04) get a
  `file.written` with `node: "_launch"` / `"_memory"`.
- `execution` = the node's nth completion; `iteration` / `attempt` from the node's last `agent.prompt` when it is an
  agent node.
- A zero-byte file at a node's start that is filled later shows as "being written" until a `file.written` arrives.
- Limits (record in As built): no workflow uses parallel `Send` branches, so one node runs at a time; a write by a
  background thread after its node finished is attributed to the next node.
- Add `file.written` to `CANONICAL_KINDS`, the web list and fixtures (L-122). Stat cost: a run folder holds tens of
  files outside the excluded trees; measure on the largest real run and record it.

## 2. Artifact roles in `META` (F11)

- `META.artifacts` (and the mirrored `workflow.yaml` key) accepts today's list form **or** a map:
  `{name: {role: "output"|"input"|"intermediate"|"check", label: "Technical design document"}}`. Paths may be
  relative paths or simple globs (`report/*`).
- `genesis/lint/contract.py`: the parity lint compares both forms; a role outside the four values or a missing label
  in the map form is an error; the list form still passes (additive, ADR-019).
- One reader: a single parser (`genesis/runs/artifact_roles.py` or alongside the loader) used by the categorizer, the
  Resolve agent (55-07) and the lint (L-109, a parity test).

## 3. Categorization (`genesis/runs/documents.py`, new)

`categorize(run) -> RunDocuments` from: the manifest (now with `mtime`), the `file.written` events, `tool_output.recorded`
events (both stored forms, the legacy `custom` rows included, as `runs/steps.py:98-148` does), `agent.prompt` events,
the workflow's roles, `inputs_schema` (`format: "file"`), and the graph topology for step order.

| Category | Rule (first match wins) |
|---|---|
| system | prefix `_kiro/`, `.kiro/`, `checkout/`, or `.DS_Store` |
| prompt | `_prompts/*` (node, pass, attempt from its `agent.prompt` event) |
| tool_output | each `tool_output.recorded` event (tool, node, bytes, time); `file_available` only while `_toolcalls/<ref>.out` exists (D9) |
| input | `uploads/*`; a role `input`; `_memory/brief.md` (label "Memory brief") |
| output | a role `output` |
| check | a role `check` |
| intermediate | a role `intermediate`, or any other file a node wrote |
| unknown-step | old runs: no `file.written` → name rules (55-01 §4.2 patterns) with `node: null` (F12) |

Each document: `{path, label, category, node, execution, iteration, attempt, bytes, written_at, writes (count of
file.written for the path, D9), latest: true, preview_kind, media_type, passed?}` — `passed` for a check from its
node's `validator.result`. Plus `steps: [{node, label (GraphNode.description), documents, prompts}]` in graph order,
and `tool_outputs: [...]`. Bounded work per call (no whole-log fold on every poll; reuse the 55-03 incremental fold or
an `after_seq` cursor, L-066).

## 4. Endpoint (added here; 55-08 owns the contract table)

`GET /api/runs/{id}/documents` → `RunDocuments`. The old `GET /runs/{id}/artifacts` stays (its other readers: the
inspector panels, `NodeIterationsDialog`; list them, L-094); file read and download routes are unchanged.

## 5. Tests

- `file.written` from a fixture graph with a program node, a validator, an agent node (stubbed provider), a retry
  (writes = 2), a loop.
- Categorizer: one fixture per real run in 55-01 §4.2 (shapes from the real folders and events, L-083), legacy `custom`
  tool rows, old runs (`node: null`), a live run with a zero-byte file.
- Lint: list form, map form, bad role, missing label, yaml/META mismatch.

## 6. Gates

genesis-core pytest + ruff; genesis pytest + ruff.

## Context manifest

```toml
areas    = ["runs-worker", "core-engine", "workflows-library"]
adrs     = ["ADR-010", "ADR-018", "ADR-019", "ADR-022", "ADR-035", "ADR-066"]
lessons  = ["L-013", "L-021", "L-066", "L-083", "L-094", "L-109", "L-122"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md"]
code     = ["genesis/genesis/runs/**", "genesis/genesis/lint/contract.py", "genesis/packages/genesis-core/genesis_core/workspace.py", "genesis/genesis/api/run_routes.py"]
upstream = ["55-03", "55-04"]
```
