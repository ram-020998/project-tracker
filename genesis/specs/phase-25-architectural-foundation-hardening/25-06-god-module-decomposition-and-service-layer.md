# 25-06 — God-Module Decomposition & Application/Service Layer

- **Status:** ⏳ IN PROGRESS (2026-08-18) — service layer + KbStore fully decomposed + app.py config routes extracted; **runs-routes extraction remaining**. **NOT released** (ships via 25-14). · **Review items:** C-3, C-5, E-4 · **Roadmap:** Phase 2/3 · **Repos:** genesis · **Depends on:** 25-01 (done)

## Progress (as built so far — all committed locally, unreleased; 543 pytest + ruff green after each slice)

| Commit | Slice | Effect |
|---|---|---|
| `e143c5e` | **`ApplicationSyncService`** (C-5) | de-duplicated the app-sync orchestration shared by `api/applications.py` + `runtime/sync_jobs.py` (is-running / resolve baseline↔delta / start → `SyncBusyError`); +8 unit tests. **C-5 DONE.** |
| `57f0704` | `KbGraphReadsMixin` | KbStore split (graph-traversal reads) |
| `07a12f2` | `KbRelationshipReadsMixin` | KbStore split (entry-points/batches/shared/hub) |
| `579317b` | `KbEvidenceMixin` | KbStore split (Business Evidence Pack) |
| `8a80398` | `KbObjectReadsMixin` | KbStore split (object/dep/bundle/orphan reads) |
| `715fb1b` | `register_config_routes` (`api/config_routes.py`) | app.py split (24 `/config/*` routes) |

**Results:** `KbStore` **1373 → 652 LOC** (four read mixins; the SCD-2 **write/sync path deliberately kept** in `store.py` — the `to_thread` deadlock-sensitive code, bible §7). `api/app.py` **841 → 672 LOC** (config/integrations routes → `register_config_routes(api, config, settings, manager)`; shared request models + card formatters imported from `app.py` via a deferred import). Every extraction is a verbatim move; the composed class/router behaves identically (KbStore inherits the mixins — MRO keeps all `self.` calls identical).

## Remaining
- **Runs-routes extraction** (`api/app.py`, 17 routes → `register_run_routes`). **Highest-risk piece** — it touches the ADR-033 copilot blast-radius enforcement (`_enforce_copilot_start`) + SSE streaming, and the routes are interspersed with the artifacts routes (not a clean contiguous block). To be done as a careful dedicated step with the copilot/SSE logic preserved verbatim.
- **`FeatureService` — recommended SKIP** (honest pushback): 25-01 already established the single-authority `LifecycleService` in `api/features.py`; a wrapper adds churn without benefit. Marked not-needed unless requested.

## 1. Goal
Break the three god modules along seams they already imply, and introduce a **thin Application/Service layer** so multi-store orchestration lives in one place (reachable from API, scheduler, and copilot) instead of being duplicated in route closures.

## 2. Why (review evidence)
- **C-3 (god modules):** `kb/store.py` **1,373 LOC**, `api/app.py` **841 LOC**, `chat/manager.py` **716 LOC** — high fan-in, hard to unit-test in isolation, merge-contention magnets.
- **C-5 (missing service layer):** route handlers orchestrate stores + `RunManager` directly; `runtime/sync_jobs.py` **re-implements** the app-sync orchestration the API also does (the duplication tell).
- **E-4:** split the god modules along their existing section seams.

## 3. Current state (cited)
- `kb/store.py`: one `KbStore` class = app lifecycle + SCD-2 baseline/delta merge (`apply`) + bundle recompute + releases + 7 read-projections.
- `api/app.py`: 55 route decorators as closures inside a single `create_app` (run/artifact/config/home/etc.); other domains already modularized via `register_*_routes` — the core routes are the holdout.
- `chat/manager.py`: `ChatSession` + `ChatManager` (session lifecycle, tokens, notifications, run-linking, slash commands, models, permission bridge) — 716 LOC (mode branching split to 25-07).
- `runtime/sync_jobs.py`: `register_sync_jobs(...)` re-runs app-sync orchestration.

## 4. Design
### 4.1 Split `KbStore` (behavior-preserving)
Along the comment seams already in the file:
- `kb/sync_writer.py` — `KbSyncWriter`: `begin/apply(baseline|delta)/finish`, UUID-dedupe, bundle recompute (the write path; the `to_thread` deadlock lesson stays intact).
- `kb/query.py` — `KbQuery`: the read projections (overview/search/dependencies/entry-points/dependents/precedents/shared/hub/path/transitive) with Atlas-mirrored shapes.
- `kb/releases.py` — `ReleaseStore`: `tag_release/list_releases`/point-in-time.
- `KbStore` becomes a thin facade delegating to the three (keeps the public surface — `kb_server.py`, `api/applications.py`, `sync_jobs.py` don't change their calls). Optional: deprecate the facade later.

### 4.2 Extract the core routes from `api/app.py`
- Move run/artifact/config/home route groups into `register_run_routes`, `register_config_routes`, `register_home_routes` (mirroring the existing `register_*_routes` pattern). `create_app` shrinks to: build deps → `configure_logging` → register all route modules → mount SPA. Target `app.py` < ~250 LOC.

### 4.3 Thin service layer (`genesis/services/` — NEW)
- `ApplicationSyncService` — the single "add app → baseline sync" / "refresh" orchestration used by **both** `api/applications.py` and `runtime/sync_jobs.py` (removes the duplication C-5 flags).
- `SpecService` / `FeatureService` — wrap `FeatureStore` + `LifecycleService` (25-01) + the chat-session/artifact wiring so `api/features.py` handlers become thin.
- Services take their dependencies **by constructor** (explicit DI, no globals) — consistent with the existing `register_*_routes(deps)` style.

## 5. Files touched
- **New:** `kb/sync_writer.py`, `kb/query.py`, `kb/releases.py`, `genesis/services/{__init__,application_sync,feature_service}.py`, tests for each.
- **Edit:** `kb/store.py` (→ facade), `api/app.py` (extract route modules), `api/applications.py` + `runtime/sync_jobs.py` (call `ApplicationSyncService`), `api/features.py` (call `FeatureService`).

## 6. Tests
- Each split unit (`KbSyncWriter`/`KbQuery`/`ReleaseStore`) unit-tested directly (smaller surfaces = easier isolation).
- `ApplicationSyncService` tested once; API + scheduler both exercise the same path (a test asserts no divergent orchestration).
- Regression: existing KB/applications/features/sync tests pass unchanged (facade keeps the surface).

## 7. Risks & mitigations
- **Risk:** a large mechanical split introduces subtle behavior drift (esp. the SCD-2 `apply`). **Mitigation:** move code verbatim, keep the facade, rely on the existing KB test suite + a diff review; ship Kb-split and route-extraction as **separate commits/releases** to isolate blame.
- **Risk:** the `to_thread` write-deadlock lesson. **Mitigation:** the write path stays exactly as-is in `KbSyncWriter`.

## 8. Out of scope
Chat mode composition (25-07); changing any external behavior or API shape.

## 9. Definition of Done
`KbStore` split behind a facade; `api/app.py` route groups extracted (< ~250 LOC); `ApplicationSyncService` de-duplicates API vs scheduler; feature routes go through `FeatureService`; all existing suites green; genesis release(s) CI-green; `bible/03` codebase map updated; progress doc.
