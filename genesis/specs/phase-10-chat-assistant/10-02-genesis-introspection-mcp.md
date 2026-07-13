# 10-02 — Genesis-introspection MCP server (read-only)

**Repo:** `genesis` · **Ships with:** v0.19.0 · **Depends on:** — · **Blocks:** 10-04
**Goal:** give the chat agent read-only tools to answer questions about the platform's own state
(runs, failures, progress, workflows, health) without any ability to mutate.

## 1. Objective

A stdlib-only stdio JSON-RPC MCP server, launched per chat session by kiro-cli, that reads
`genesis.db` (+ the lockfile) through a **read-only** connection and exposes a small set of
SELECT-backed tools. Modeled on the Phase-9 blackboard server.

## 2. Current state (verified)

- Template: `genesis-core/genesis_core/mcp/blackboard_server.py` — stdlib stdio JSON-RPC 2.0
  (`initialize` / `notifications/initialized` / `tools/list` / `tools/call`), launched
  `<python> -m genesis_core.mcp.blackboard_server --root <dir>`. Copy its framing exactly.
- Data sources (all read-only APIs, `Database`-injected):
  - `genesis/runs/store.py` `RunStore` — `runs` table: `get`, `list(status?, workflow_id?, limit)`.
  - `genesis/runs/eventlog.py` `EventLog` — `run_events`: `list(run_id, after_seq, kinds, node,
    limit, offset)`, `latest(run_id, kind)`, `count`, `aggregate_tool_calls`.
  - `genesis/runs/manager.py` `RunManager.steps()` — a pure fold of the event log into per-node
    summaries (status/attempts/tool_calls/messages/duration). Reuse the **fold logic** (extract to a
    pure helper the server can import without constructing a full RunManager, or reimplement the
    same fold in the server).
  - `genesis/dist/loader.py` `Loader.installed()`/`meta_of()` — installed workflows (yaml, no import).
  - `genesis/config/service.py` `ConfigService.health()`/`mcp_cards()`/`cli_cards()` — integration
    status; cards expose only key **names** + `is_set`, never secret values.
  - `genesis/api/home.py` `build_home(...)` — the Overview aggregate (counts, trend, active runs).
- `genesis/db/database.py` `Database.connect()` opens read-write with WAL. The server must instead
  open a **read-only** connection: `sqlite3.connect("file:{db_path}?mode=ro", uri=True)`.

## 3. Design

### 3.1 Location + launch

`genesis/genesis/mcp/introspection_server.py` (new package `genesis/mcp/` with `__init__.py`).
Launched by `ChatSession` (10-04) as an ACP MCP entry:

```python
{"name": "genesis", "command": sys.executable,
 "args": ["-m", "genesis.mcp.introspection_server", "--db", <db_path>, "--library", <library_dir>],
 "env": []}
```

It imports genesis read modules (`RunStore`, `EventLog`, `Loader`, and the steps fold). Importing
genesis in this subprocess is fine — it is Genesis's own code, not workflow Python (ADR-012 concerns
workflow graphs). It constructs a `Database(db_path)` but **only reads**; to be safe it uses a
read-only connection helper (§3.4) rather than `Database.connect()`.

### 3.2 Tools (read-only; every result is bounded JSON text)

| Tool | Args | Returns |
|---|---|---|
| `list_runs` | `status?`, `workflow?`, `limit?≤50` | recent runs: id, workflow, version, status, cursor, created/updated |
| `get_run` | `run_id` | the run record + `gate` summary + a progress summary (nodes done/total, current) |
| `get_run_steps` | `run_id` | per-node fold: node, status, attempts, tool_calls, messages, duration_ms |
| `get_run_events` | `run_id`, `kinds?`, `limit?≤200` | bounded slice of the timeline (seq, node, kind, ts, compact payload) |
| `list_failures` | `limit?≤50` | failed runs + their `error` event detail (bounded) |
| `list_workflows` | — | installed workflows: id, version, name, roles, summary, required_mcp/cli |
| `get_workflow` | `id` | full META for one workflow |
| `integration_health` | — | MCP/CLI/GitLab statuses (configured/missing) — **no secret values** |
| `platform_stats` | — | Overview aggregate (total/active/failed counts, recent trend) |

All tools are nouns/gets; there is no create/update/delete tool. Payloads are truncated to a byte
cap (e.g. 32 KB) with a `truncated: true` flag, keeping ADR-010 (no bulk dumps).

### 3.3 Secret / PII redaction (§7 risk)

- Config surfaces already return only key names + `is_set` — pass through unchanged.
- Run **inputs** and checkpoint **state** may contain sensitive values. `get_run` returns input
  **keys** + short (≤120-char) previews, running a redaction pass that masks values for keys matching
  `/(token|secret|password|key|authorization|cookie)/i`. `get_run_events` payloads are compacted +
  length-capped. No tool returns full state or full artifacts (those live behind the run's own
  authenticated file APIs, not chat).

### 3.4 Read-only DB access

```python
def _ro_conn(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn
```

`mode=ro` fails writes at the SQLite layer — defense in depth even if a tool were mis-coded.

### 3.5 Reuse the steps fold

Extract `RunManager.steps()`'s inner fold into a module-level pure function
`fold_steps(events: list[EventRecord]) -> list[dict]` in `genesis/runs/eventlog.py` (or a new
`genesis/runs/steps.py`) and call it from both `RunManager.steps()` and the server, so the chat's
"progress" answer matches Run Detail exactly. (Small refactor; keep `RunManager.steps()` behavior
identical, covered by existing tests.)

## 4. Files to touch

- `genesis/genesis/mcp/__init__.py` (new)
- `genesis/genesis/mcp/introspection_server.py` (new) — the server.
- `genesis/genesis/runs/steps.py` (new) or eventlog helper — extracted `fold_steps`.
- `genesis/genesis/runs/manager.py` — call the extracted `fold_steps` (no behavior change).
- `genesis/tests/test_introspection_server.py` (new) — see §5.

## 5. Tests / DoD

- Seed a temp `genesis.db` via `Database` + `migrate` + `RunStore`/`EventLog` fixtures (a done run,
  a failed run with an `error` event, an installed workflow via a temp lockfile/library).
- Drive the server **in-process** by calling its `_dispatch`/tool functions directly (like the
  blackboard server tests): assert each tool's JSON shape, the failure detail, the steps fold matches
  `RunManager.steps()`, bounds/truncation, and that secret-looking input keys are redacted.
- Assert the ro connection refuses writes (attempt an INSERT → `sqlite3.OperationalError`).
- pytest + ruff green. No behavior change to existing `RunManager.steps()` tests.

## 6. Risks

- Importing `ConfigService`/`Loader` may pull heavier deps into the MCP subprocess (slower startup).
  Mitigate: import lazily inside the tool handlers; keep `list_runs`/`get_run`/events on the light
  `RunStore`/`EventLog` path. Measure startup in the 10-04 spike.
- The library dir / lockfile may be absent in some environments → `list_workflows` returns `[]`
  gracefully rather than erroring.
