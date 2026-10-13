# 45-05 — Dev MCP session client + package client

> **Status:** 🟡 DRAFTED. Repo: **genesis**. Implements **ADR-073**. Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. `DevMcpSession` (`genesis/kb/dev_mcp.py`)

Today `_call_tool` spawns one server process per call. A delta sync makes ~5–60 calls, so add a session:

```python
class DevMcpSession:           # sync facade; runs its own event loop in a worker thread
    def __enter__(self) / __exit__(...)       # spawn + initialize once; terminate on exit
    def call(self, tool: str, args: dict, *, timeout: float = 120) -> Any   # parsed JSON; raises DevMcpToolError
```

- Spec + env resolved exactly like `available_applications` (merged registry → dev-tagged env + env-scoped creds),
  from the **`appian-dev-packages`** entry for the package client and `appian-dev` for read-only listing. The registry
  allowlist caps agents only (ACP trust); direct calls rely on the client's own `ALLOWED_TOOLS` below.
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

## 5. As built (2026-10-13, genesis local) — corrections from the real 26.6.110 contract + live runs

- **`addPackageObjects` response** (SDK `AddObjectsToPackageResponse200`): `{success, added, failed, packageUuid,
  message, errors:[{uuid, type, error}]}` — **`failed` is a count**; per-object failures are in **`errors`** (45-01 §1's
  "reported in `failed`" was wrong). `add_objects` returns `{added, failed, errors, skipped, calls}`.
- **Live finding — one bad object poisons its batch:** a batch containing ONE unresolvable uuid (e.g. deleted since it
  was listed) fails **every** object in it, each reported "Could not resolve the object's type" (`[ER, ER, BOGUS]` →
  0 added; `[ER, ER]`, mixed types, GROUPs → all added). `add_objects` therefore **bisects** a failed batch on the
  failed subset until the bad objects are isolated (~2·log2(n) extra calls). Live: 22 changed + 1 bogus → 22 added,
  1 error, 7 calls.
- Package shapes: `createPackage` → PackageSummary (`uuid, name, appUuid, createdTimestamp` ISO-Z, …);
  `listPackages(appUuid, limit, offset)` → `{items, total, limit, offset}`; `getPackage` → PackageDetail
  (+ `objects[{uuid,type,name,description}]`, `objectCount`); `deletePackage` → `{deleted, uuid}`.
- **Package types** = 16 (`RECORD_TYPE INTERFACE EXPRESSION_RULE PROCESS_MODEL SITE PORTAL CONSTANT DATA_TYPE GROUP
  WEB_API CONNECTED_SYSTEM INTEGRATION FOLDER DOCUMENT DATA_STORE DECISION`, case-insensitive) — narrower than
  `listObjects`' vocabulary. `package_type()` maps listObjects types, package types and KB display types (for
  `delta_roots`: `CDT → DATA_TYPE`, …); AI Skill / Translation Set/String / Control Panel / Application are
  **skipped** (reported, never sent). `QUERY_RULE → EXPRESSION_RULE` kept (the server rejects `QUERY_RULE`).
- `list_changed(app, after)`: asks `lastModifiedFrom` = the **day before** `after`'s UTC date (the date filter's
  timezone is undocumented), then keeps `lastModifiedOn` > `after` exactly; unparseable timestamps are kept;
  deduped by uuid. **45-06 must advance `covered_until` to the time listing STARTED** (an object modified mid-listing
  can be missed by offset paging and is caught next time).
- `create_delta_package` returns `{uuid, name}`. `add_objects` writes only to a package this client created or one
  `getPackage` confirms is `genesis-delta-*`; `delete_delta_package` **always** re-reads the name first (even for
  its own packages). `sweep_leftovers` skips undated packages.
- `DevMcpSession`: private event loop in a daemon thread (works from `asyncio.to_thread`); stderr is drained (a
  chatty server can't block); timeouts → `DevMcpToolError(kind="unreachable")`; env values never in messages.
- Wiring: `ctx.extras["devmcp_packages"]` = `lambda: open_packages(ctx_mcp)` (a context manager). Launch spec =
  `appian-dev-packages`, falling back to `appian-dev` when the installed library predates 45-02 (same binary/env;
  the client's `ALLOWED_TOOLS` is the cap). Live on the host it currently resolves `appian-dev` (library v0.20.0).

**Evidence:** `tests/test_dev_packages.py` (12; fake stdio server with the real shapes incl. batch poisoning);
genesis pytest **891** + ruff. Live (merge-assist-dev, AS GSS): session open 1.2 s; `list_changed` since
2026-09-06 → 22 objects in 3.0 s; create → add → get → delete round trips; every temp package deleted in `finally`;
`listPackages` → **0** `genesis-delta-*` afterwards (the app has no other packages).
