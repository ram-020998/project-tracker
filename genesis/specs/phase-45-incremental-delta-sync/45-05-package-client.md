# 45-05 — Dev MCP session client + package client

> **Status:** 🟡 DRAFTED. Repo: **genesis**. Implements **ADR-073**. Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. `DevMcpSession` (`genesis/kb/dev_mcp.py`)

Today `_call_tool` spawns one server process per call. A delta sync makes ~5–60 calls, so add a session:

```python
class DevMcpSession:           # sync facade; runs its own event loop in a worker thread
    def __enter__(self) / __exit__(...)       # spawn + initialize once; terminate on exit
    def call(self, tool: str, args: dict, *, timeout: float = 120) -> Any   # parsed JSON; raises DevMcpToolError
```

- Spec + env resolved exactly like `available_applications` (merged registry → dev-tagged env + env-scoped creds).
- `DevMcpToolError(kind, message)` with `kind` from `classify_tool_error` (45-02).
- Never logs resolved env values.
- Blocking — workflow nodes call it via `asyncio.to_thread` (the §7 event-loop lesson).

## 2. `DevMcpPackages` (`genesis/kb/dev_packages.py`) — the only path to package tools

```python
ALLOWED_TOOLS = frozenset({"listObjects", "listPackages", "getPackage", "createPackage",
                           "addPackageObjects", "deletePackage"})
DELTA_PREFIX = "genesis-delta-"

class DevMcpPackages:
    def list_changed(self, app_uuid, since_date: date, after: datetime) -> list[dict]
        # pages listObjects(appUuid, lastModifiedFrom=since_date, limit=50) to exhaustion, then keeps
        # items with lastModifiedOn (UTC) > after
    def create_delta_package(self, app_uuid) -> str            # name genesis-delta-<UTC yyyymmddTHHMMSSZ>
    def add_objects(self, package_uuid, refs) -> {added, failed}   # batches of 50; merges `failed`
    def get_package(self, package_uuid) -> dict
    def delete_delta_package(self, package_uuid) -> None       # getPackage first; refuses unless name startswith DELTA_PREFIX
    def sweep_leftovers(self, app_uuid, older_than_minutes=60) -> list[str]   # deletes stale genesis-delta-* only
```

Guards (code, not configuration):
- Any tool not in `ALLOWED_TOOLS` → `ValueError` before a call is made.
- `deletePackage` only after `getPackage` confirms the `genesis-delta-` prefix → **implementation packages (backlog)
  can never be deleted by this client**.
- Type pass-through: `listObjects` types are valid package types (45-01 §4); `QUERY_RULE → EXPRESSION_RULE` alias kept
  defensively; any other unexpected type goes to `skipped` instead of the package.

## 3. Wiring

`runtime/context.build_context` adds `ctx.extras["devmcp_packages"]` = a factory returning a `DevMcpPackages` bound to
a fresh `DevMcpSession` (context manager), so the workflow opens one session per phase of the run. Standalone
workflow code never imports the platform (it uses the factory).

## 4. Tests

- Fake session: allowlist enforcement, delete-guard (non-prefix name refused), batching + `failed` aggregation,
  `list_changed` paging + exact-timestamp filter (UTC parsing incl. milliseconds), leftover sweep only touches stale
  `genesis-delta-*`.
- `DevMcpSession` against a fake stdio MCP server (handshake once, many calls, clean shutdown).
