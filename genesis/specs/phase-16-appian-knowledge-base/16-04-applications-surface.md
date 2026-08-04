# Phase 16-04 — Applications surface (API + page + container model)

> **Status:** DRAFT (planning) · **Repos:** genesis (+ web) · **Depends on:** 16-08 §2.0 (dev-env toggle), 16-02 (KbStore), 16-03 (sync workflow)
> **Goal:** The user-facing surface: an **Applications** page where the user sees the apps in the **dev-tagged**
> environment (16-08 §2.0),
> **adds** the one(s) their team works on (triggering a baseline sync), and tracks each app's KB — overview, objects,
> bundles, sync history, and (16-06) releases. Backed by `/api/applications*` routes over `KbStore` + `RunManager`.

---

## 1. Current state (grounded)
- API: `genesis/genesis/api/app.py` `create_app()` builds one `APIRouter()` at `prefix="/api"` (ADR-028) with inner
  `@api.get/post/...` handlers sharing closed-over `manager`/`config`/`loader`; sub-features register via helpers
  (`register_chat_routes(api, chat, ...)`, `register_skills_routes(api, skills, ...)`) each in its own `api/*.py`.
  Pydantic body models at module top (e.g. `EnvBody`). SPA history fallback for non-`/api` paths.
- Environments: `config/service.py` `list_environments()`; `GET/POST/DELETE /api/config/environments`. The connected
  env's public vars resolve via `EnvironmentRegistry`.
- Launch/track a run: `RunManager.start(workflow_id, inputs, environment=<label>)`; run status/events from
  `RunStore`/`EventLog`; SSE stream at `/api/runs/{id}/events/stream`.
- Web: `web/src/app/router.tsx` (routes under `RootLayout`; static routes placed before dynamic to avoid collisions),
  `shared/layout/Sidebar.tsx` (`GROUPS` nav), `lib/api/client.ts` (`api.get/post/...`, prepends `/api`, `ApiError`),
  resource modules `lib/api/*.ts` typed against `types/*`, feature folders `features/*/` with `hooks.ts` (TanStack
  Query). Catalog is the closest template (browse + detail + sub-tabs + launch).

## 2. Design

### 2.1 Container model (uses 16-02 `kb_applications`)
An **Application** = a tracked Appian app (keyed by app UUID) bound to the **dev-tagged** env (`env_label` = the env
tagged `is_dev`, 16-08 §2.0), with a KB
(objects/bundles/releases/sync history). "Add application" is on-demand; a team adds only the app(s) they work on.

### 2.2 API — `genesis/genesis/api/applications.py` (`register_applications_routes(api, kb_store, run_manager, config, loader)`)
- `GET /api/applications` → tracked apps: `{app_uuid, name, object_count, bundle_count, current_release, last_sync:{status,at,kind}}` (from `KbStore.list_applications`).
- `GET /api/applications/available` → apps **in the dev-tagged env** (16-08 §2.0) not yet tracked. Enumerated via the **Dev MCP**
  "list applications" capability. **Wiring decision:** call the Dev MCP through a short-lived introspection-style
  client (like `mcp/introspect.py` direct-stdio), or a small helper that runs the Dev MCP `list applications` tool;
  return `{app_uuid, name}[]`. (If Dev MCP enumeration proves awkward headlessly, fall back to a manual "enter app
  UUID" affordance — flagged.)
- `POST /api/applications` `{app_uuid, name}` → resolve the **dev-tagged** env (`dev_environment()`; 400 with "tag a dev
  environment in Settings" if none) → `KbStore.register_application(app_uuid, name, env_label=<dev env label>)` then
  `run_manager.start("sync-application", {app_uuid, app_name, mode:"baseline"}, environment=<dev env label>)`; return
  `{app_uuid, sync_run_id}`.
- `GET /api/applications/{app_uuid}` → detail: overview (`KbStore.get_app_overview`), releases, recent syncs.
- `POST /api/applications/{app_uuid}/sync` `{mode:baseline|delta}` → start a sync run (delta wired in 16-07; baseline
  now). Return `{sync_run_id}`.
- `GET /api/applications/{app_uuid}/sync-status` → latest sync run status (join `kb_syncs` + `RunStore`), enough to
  render a live status + a link into Run Detail.
- `GET /api/applications/{app_uuid}/objects?query=&type=` / `/bundles?query=&type=` / `/changelog?from=&to=` → KB
  browse via `KbStore` (paginated; current state by default, `at_release=` later).
- `POST /api/applications/{app_uuid}/releases` (16-06) — declared here, implemented in 16-06.
- `DELETE /api/applications/{app_uuid}` → `KbStore.untrack_application` (table-scoped).
- Register the router + a `KbStore` instance on `app.state` in `create_app` (beside chat/skills), sharing the
  `Database`/`Settings`.

### 2.3 Web — `web/src/features/applications/`
- `ApplicationsPage` — tracked-apps list (cards/table: name, counts, current release, last-sync status dot linking to
  the sync run) + **"Add application"** button → `AddApplicationDialog`.
- `AddApplicationDialog` — fetches `GET /api/applications/available` (apps from the env), lets the user pick one (search
  + select), `POST /api/applications`, then routes to the app detail showing the baseline **SyncStatus** (reuse the run
  SSE machinery). Prereq/empty/error states via the shared feedback components.
- `ApplicationDetail` — Tabs shell (**Overview | Objects | Bundles | Releases | Syncs**). Overview = counts by type +
  coverage + dependency summary + bundle index. Objects/Bundles = searchable master-detail reusing existing primitives
  (object metadata; a bundle's flow + members; **code shown only via a live "View code" action** that calls
  `get_object_code` — 16-05). Syncs = sync history with run links. Releases = 16-06.
- `SyncStatus` — live status of the current sync run (reuse `useRunStream`/SSE); "Sync now" action.
- `lib/api/applications.ts` (`applicationsApi.list/available/add/get/sync/syncStatus/objects/bundles/remove`, client
  prepends `/api`) + `types/applications.ts` + `features/applications/hooks.ts` (TanStack Query keys + `useApplications`
  etc., poll while a sync is active like `useRuns`).
- One `Sidebar` `GROUPS` entry — **Applications** under **Library** (beside Catalog), lucide icon.
- Router: `applications`, `applications/:appUuid` (+ static sub-routes before any dynamic).
- Rebuild + commit `web/static/` (stale-bundle guard).

## 3. Files & tests
- New backend: `genesis/api/applications.py`; register in `create_app`; a `KbStore` on `app.state`.
- New web: `features/applications/**`, `lib/api/applications.ts`, `types/applications.ts`, a `Sidebar` item, router
  entries.
- Tests:
  - backend (`tests/test_applications_api.py`, TestClient): list/add/get/sync-status/objects/bundles/delete over a
    seeded `KbStore`; `POST /applications` triggers a `sync-application` run (stub `RunManager.start`); `available` lists
    env apps (stub the Dev MCP enumeration); delete is table-scoped.
  - web (Vitest + MSW): ApplicationsPage renders tracked apps + statuses; AddApplicationDialog lists available apps +
    add flow routes to detail; ApplicationDetail tabs render overview/objects/bundles from mocked API; SyncStatus shows
    live status; jest-axe on the new interactive UI.
- `web` lint + tsc + vitest + build; `web/static` committed.

## 4. Acceptance criteria
1. Applications page lists tracked apps with counts + last-sync status; nav entry present.
2. "Add application" lists apps from the connected env, adds the selected app, and kicks a **baseline sync** the user
   can watch to completion.
3. App detail shows overview/objects/bundles/syncs from the KB; delete untracks (table-scoped).
4. All new endpoints under `/api`; client prepends centrally; backend + web suites + build green; `web/static`
   committed.

## 5. Out of scope
- The `genesis-kb` MCP + the live "View code" action (16-05) — the button/route are stubbed until then.
- Release tagging + point-in-time UI (16-06); delta sync trigger + scheduling (16-07).
- Multi-environment (Phase 16 uses the single **dev-tagged** env; the registry may hold others).
