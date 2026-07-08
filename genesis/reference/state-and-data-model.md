# Genesis — State & Data Model

The load-bearing rule (ADR-010): **LangGraph state holds only small, serializable,
human-editable data; bulk artifacts live in the per-run blackboard folder,
referenced by path.** This makes checkpoints small/fast, makes state-editing HITL
usable, and prevents the failure modes found in the ERD POC.

---

## 1. `PlatformState` (base)
```python
from typing import Annotated, TypedDict
from operator import add   # reducer for lists

class PlatformState(TypedDict):
    run_id: str
    workflow_id: str
    workflow_version: str
    inputs: dict                       # validated against META.inputs_schema
    artifacts: dict[str, str]          # logical name -> path in the run blackboard
    decisions: dict                    # small agent/program outputs (domain map, choices, ids)
    status: str                        # pending|running|awaiting_input|failed|done|cancelled
    cursor: str                        # current node name (for inspection/resume)
    retries: dict[str, int]            # per-node retry counters (reliability trio)
    errors: Annotated[list[dict], add] # appended via reducer
    _validation: dict                  # {validator_name: {ok, message}} (internal)
    _last_turn: dict                   # most recent agent turn (see §1.4)
    telemetry: dict                    # per-node metrics (see §1.4)
```

### 1.1 Reducers
- `errors` — append (`operator.add`).
- `artifacts`, `decisions`, `_validation` — shallow-merge (last-writer per key).
- `retries` — per-key increment (custom reducer).
- `telemetry` — deep-merge per node (accumulate attempts; sum durations/credits/tool_calls).

### 1.2 Per-workflow extension
Workflows subclass with a few extra **small** fields, e.g. ERD:
```python
class ErdState(PlatformState):
    scope: str                 # "business" | "full"
    document_id: str | None
```
Do **not** add bulk fields (schemas, generated code, docs) — those are artifacts.

### 1.3 Editability (HITL mode 3)
- Human-editable keys (default): `inputs`, `decisions`, and any workflow-declared
  `editable` fields in `META`.
- Read-only: `run_id`, `status`, `cursor`, `_validation`, `_last_turn`, `retries`.
- `artifacts` values (paths) are editable; the **contents** are edited by editing
  the files in the blackboard directly.
- Edits validated against the state schema server-side before resume (Phase 5).

### 1.4 Per-node telemetry (built in from Phase 1)

Because Genesis uses fine decomposition (many short agent sessions), per-node
telemetry must be captured from day one — retrofitting later is painful, and it's
needed for cost/usage reporting and the workbench.

`kiro_node` records, per node:
```python
telemetry[node_name] = {
    "attempts": int,        # incl. retries
    "duration_ms": int,     # summed wall-clock across attempts
    "tool_calls": int,      # ACP tool calls observed
    "turns": int,           # agent turns
    "credits": float|None,  # best-effort (see note), summed
    "retries": int,         # from state.retries[node]
    "last_error": str|None,
}
```
- `_last_turn` = the most recent turn record (same fields + `node`, `stop_reason`) — a convenience pointer; `telemetry` is the durable per-node history.
- **Run-level aggregate** for the workbench (`telemetry["_run"]`): summed `duration_ms`, `tool_calls`, `turns`, `credits`, and total `retries` across nodes.
- Program/CLI nodes may record `{duration_ms}` too (cheap, uniform timeline).

**Credits caveat (honesty):** `duration_ms`, `tool_calls`, `turns`, `retries`
are always capturable. **`credits` is best-effort** — it depends on ACP/Kiro
surfacing usage. This requires a `kiro-agent-sdk` enhancement to expose usage in
`TurnResult` (see that repo's backlog). If usage is unavailable, `credits` is
`None` and the field is populated once the SDK exposes it — the schema is present
from day one so nothing needs retrofitting.

Telemetry is small (fits the state-small rule) and streams to the UI (Phase 5/7).

---

## 2. The blackboard (`RunWorkspace`)

Per-run folder holding bulk artifacts + cross-step handoff docs, in the
**dedicated, configurable artifacts root** (NOT inside `~/.genesis/`; ADR-022):
`<GENESIS_ARTIFACTS_DIR>/<workflow_id>/<run_id>/` (default artifacts root
`~/Genesis/runs/`). The run record stores this path absolutely. API (from
`genesis_core/workspace.py`, promoted from `kiro-agent-sdk`):
```python
ws = RunWorkspace.for_run(run_id, workflow_id)   # under the configured artifacts root
doc = ws.doc("schema.json")                # pre-creates an empty doc, returns Doc
doc.write_json(obj) / doc.read_json()
doc.write_text(s)  / doc.read_text()
doc.is_empty()  / doc.path
ws.manifest()                              # {root, docs:{name:{path,bytes}}, total_bytes}
```

### 2.1 Conventions
- **Pre-create** the doc before an agent node runs; the node writes into it (agent nodes never return bulk via chat).
- Reference every doc from `state.artifacts` by a stable logical name.
- **Tag artifact role** in `META.artifacts` as `intermediate` (raw dumps, normalized data — prunable sooner) or `final` (reports, generated deliverables — kept longer). Drives retention (below).
- Handoff between steps = "step A writes `X.json`; step B reads `X.json`" — the doc, not chat, is the channel (ADR-018; mirrors solutions-copilot `.kiro/analysis`).

### 2.2 Artifact naming (recommended)
- Raw tool dumps: `raw_<thing>.json` (verbatim MCP output).
- Normalized/derived: `<thing>.json`.
- Final inputs to a CLI/tool: `<tool>-input.json`.
- Human-facing outputs: `report.md`, `<doc>.md`, diagrams, etc.
Workflows should list their artifacts in `META.artifacts` for the UI viewer.

---

## 3. Why the split (evidence)

From the ERD POC (`project-tracker/kiro-agent-sdk/tracker.md`):
- Asking the agent to return a large schema **inline** → truncation → a fragment
  was parsed as the whole object. **Fix:** write to a file (blackboard).
- Pushing bulk into orchestration state would bloat every checkpoint. **Fix:**
  state holds a *path*; the 48 KB / 75 KB schema lives in the blackboard.
- Small state = the human can actually read + edit it at a pause (HITL mode 3).

---

## 4. Persistence & durability

- **Checkpointer:** SQLite (`~/.genesis/genesis.db`), snapshot after every
  superstep (durability=full) — required for exact pause/resume + state-edit + fork.
- **Run records:** a table alongside checkpoints: `{run_id, workflow_id, version,
  inputs, status, cursor, created_at, updated_at, artifacts_dir}`.
- **Thread == run:** `thread_id = run_id`; resume/fork operate on the thread.
- **Blackboard is not checkpointed** — it's durable on disk in the configurable artifacts root; state points to it.

## 4.1 Artifact retention & lifecycle
- **Hard safety rule:** artifacts are pruned **only for terminal runs** (done/failed/cancelled). A running/paused/awaiting run's artifacts are never deleted — its checkpointed state references those paths and resume would break.
- **Configurable policy** (app settings): keep-last-N per workflow and/or delete-after-X-days; optionally prune `intermediate` artifacts sooner than `final` ones.
- **Disk accounting:** per-run `total_bytes` (from `ws.manifest()`) + artifacts-root total; surfaced in the workbench with an optional soft cap + warning.
- **Manual purge:** per-run and "purge all completed" from the workbench.
- **Relocation-safe:** run records store the absolute `artifacts_dir`; changing the default root doesn't orphan or double-count old runs.

---

## 5. Guardrails

- **State-size guard** (dev + CI): reject partial updates that push large blobs
  into state (heuristic on serialized size); force them to the blackboard.
- **Serializability:** everything in state must be JSON-serializable (checkpoint + edit + fork require it).
- **No secrets in state** (security-and-secrets.md).
