# Phase 16-04 — Applications surface — PROGRESS

> **Spec:** `specs/phase-16-appian-knowledge-base/16-04-applications-surface.md`
> **Status:** ✅ **SHIPPED** — genesis **v0.32.0** (CI green #6504611: `genesis` + `frontend` jobs). First consumer of
> the managed-native Dev MCP (16-08).

## What shipped

The user-facing surface over the internal Appian KB: an **Applications** page to see tracked apps, add one from the
dev-tagged env (→ baseline sync), and browse its KB (overview / objects / bundles / sync history).

### Backend (`genesis`)
- **`genesis/api/applications.py`** — `register_applications_routes(api, kb_store, run_manager, config)`:
  - `GET /api/applications` → `KbStore.list_applications()` (name, counts, coverage, current_release, last_sync).
  - `GET /api/applications/available` → apps in the **dev-tagged** env not yet tracked, enumerated via the Dev MCP
    (`{available, applications:[{app_uuid,name}], reason, dev_env}`); tracked uuids subtracted.
  - `POST /api/applications` `{app_uuid, name}` → resolve `dev_environment()` (400 "tag a dev environment" if none) →
    `register_application(...)` → `run_manager.start("sync-application", {app_uuid, app_name, mode:"baseline"},
    environment=<dev label>)` → `{app_uuid, sync_run_id}`.
  - `GET /api/applications/{uuid}` → `{application, overview (get_app_overview), releases (list_releases), syncs
    (list_syncs)}`.
  - `POST /api/applications/{uuid}/sync` `{mode}` → baseline now (delta → 400, wired in 16-07).
  - `GET /api/applications/{uuid}/sync-status` → the latest **`sync-application` run** for the app (found via
    `run_manager.list(workflow_id=…)` filtered by `inputs.app_uuid`, reconciled) **+** the latest `kb_syncs` row (counts).
    The run status is authoritative (covers a run that failed before `write_kb` ever created a kb_syncs row).
  - `GET /api/applications/{uuid}/objects?query=&type=` / `objects/{object_uuid}` / `bundles?query=&type=` /
    `bundles/{bundle_id}` → KB browse via `KbStore`.
  - `DELETE /api/applications/{uuid}` → `untrack_application` (table-scoped; never touches non-`kb_*` tables).
  - Registered in `create_app` + a `KbStore` on `app.state.kb_store`; FastAPI version `0.32.0`. Route order:
    `/applications/available` is declared before `/applications/{app_uuid}`.
- **`genesis/kb/dev_mcp.py`** — `available_applications(config)`: resolves the Dev MCP's launch+env via
  `config.merged_mcp_registry().acp_servers(["appian-dev"])` (which resolves the managed install + `${VAR}` secrets in
  one place — 16-08), then a **direct-stdio** `initialize` + `tools/call listApplications` (8 MiB stream limit; mirrors
  `genesis_core.mcp.introspect`, which only does `tools/list`). **Best-effort**: any failure (not installed / no dev env
  / missing secret / live error) → `{available:False, reason}`; never raises. Parses the tool result **defensively**
  (content→text→JSON; uuid keys `uuid/app_uuid/appUuid/id`; name `name/label/displayName`) — the Phase-12 lesson.
- **`KbStore`** — added `list_syncs(app_uuid, limit)` + `latest_sync(app_uuid)` (the sync-history read gap; kb_syncs
  ordered by `sync_id` DESC, carrying `run_id`).

### Web (`genesis/web`)
- **`features/applications/`**: `ApplicationsPage` (tracked-app cards: counts, coverage, last-sync badge, link to
  detail + "Add application"), `AddApplicationDialog` (available list from the Dev MCP with search + **Track** +
  an always-present **manual app-UUID** fallback, since headless enumeration may be unavailable), `ApplicationDetail`
  (Tabs **Overview | Objects | Bundles | Syncs | Releases** + a live **SyncStatus** banner polling
  `/sync-status` while a run is active + **Sync now** + untrack-with-confirm). The "view code" action is deferred to
  16-05.
- `lib/api/applications.ts` (`applicationsApi`), `types/applications.ts`, `features/applications/hooks.ts` (TanStack
  Query; `useSyncStatus` polls ~2s while `run.status ∈ {pending,running}`), `qk.applications` keys, a **Sidebar**
  "Applications" entry under **Library** (new `AppWindow` icon in `shared/ui/icons.ts`), router entries
  (`applications`, `applications/:appUuid`).

## Tests / verification
- Backend `tests/test_applications_api.py` (8, TestClient over a migrated+seeded KbStore; `RunManager.start` + the
  Dev-MCP enumeration stubbed): list/available(excludes tracked)/add(registers + starts sync)/no-dev-env→400/get+browse/
  404/sync-status/delta→400/table-scoped delete. Web `applications.test.tsx` (4, Vitest+MSW): page list, add→route to
  detail, detail tabs (overview/objects/bundles/syncs), live sync status, jest-axe. **genesis 274 pytest + web 125
  vitest; ruff/eslint/tsc clean; `web/static` rebuilt + committed.**
- **CI green #6504611** — `genesis` + `frontend` jobs. Because this release changed `web/**`, the `frontend`
  **stale-bundle guard ran green** — which also **closes the 16-08 Stage-B gap** where the guard hadn't executed (the
  v0.31.0 frontend job had died on a transient Gitaly 500 and v0.31.1 touched no web).

## Notes / deferred
- Live app enumeration + the actual baseline sync run need the Dev MCP installed + dev-env creds + network — not
  headlessly testable; the manual-UUID path keeps the page usable meanwhile.
- Out of scope (per spec): the live "view code" action + `genesis-kb` MCP (16-05), release tagging / point-in-time
  (16-06), delta sync trigger (16-07), `/changelog` (deferred with releases).
