# Genesis — Phase 7.5 (Web Revamp: Catalog & Install Management) Implementation Record

> As-built record of `specs/phase-07-05-catalog-and-install.md`. Adds the install-
> lifecycle API and the catalog/detail/launch screens. Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — backend released (**genesis v0.10.0**,
54 pytest + ruff, CI green); frontend committed `63ffaeb` (23 web tests, tsc strict,
**frontend + genesis CI green**). Build-alongside (served `static/` untouched — cutover 07-10).

---

## 1. Summary

The read-only catalog is now a full lifecycle surface: browse installed + available
workflows with role/status filters and live prereq badges, install/update/remove from
the library, inspect a workflow (Overview / Graph / Runs sub-tabs), and launch a run via
a schema-driven form that routes into Run Detail. Reuses the 07-04 data-access layer
(`lib/api` + `lib/query` + TanStack Query + rhf/zod).

---

## 2. Backend — install-lifecycle API (genesis v0.10.0)

Spec §2 sanctioned exposing the existing `Installer`/`Loader` as endpoints (all under
`/api`, ADR-028):

| Method | Path | Purpose |
|---|---|---|
| GET | `/catalog/available` | library workflows not yet installed (needs GitLab token) |
| POST | `/library/install` | `{id, ref?}` → install/pull at ref (or latest) |
| POST | `/library/update` | `{id}` → re-pull latest compatible |
| DELETE | `/library/{id}` | remove installed workflow |

- `create_app` gained a **`source_factory`** param. Default `_default_source_factory`
  builds a `GitLabClient` from the stored `GITLAB_TOKEN` (mirrors the CLI defaults) and
  **raises 400** when no token is set. Tests inject a `LocalSource`-returning factory to
  run fully offline.
- `/catalog/available` filters out already-installed ids; network/parse failures → 502.
- Install/update run through `Installer.install_selection` (compat major recorded in the
  lockfile; the loader enforces the gate at load/run time). Remove uses `Installer(None,…)`
  — no token needed.
- Tests: `tests/test_library.py` (LocalSource fixture) exercises
  available → install → catalog-reflects → remove, plus the token-required guard on the
  default factory. **54 passed**, ruff clean.

---

## 3. Frontend (`genesis/web/features/catalog/`)

- **Data layer:** `types/catalog.ts` (CatalogEntry, AvailableEntry, WorkflowMeta, GraphTopology,
  JsonSchema), `types/run.ts` (RunRecord, RunStatus); `lib/api/catalog.ts` (installed/available/
  meta/graph/runsFor/install/update/remove/startRun); `lib/query/keys.ts` gained `catalog` + `runs` namespaces.
- **Hooks (`hooks.ts`):** useInstalled/useAvailable/useWorkflowMeta/useWorkflowGraph/useWorkflowRuns,
  mutations useInstall/useUpdate/useRemove/useStartRun (invalidate + toast), and a **prereq selector**
  (`useConfiguredSets` + `prereqFor`) that joins `required_mcp/cli` with live mcp-cards/cli-cards status
  — reusing the shared config query keys (no cross-feature coupling, shared cache).
- **CatalogPage (`/catalog`):** search + status SegmentedControl + role `<select>`; merged installed +
  available grid; per-card prereq badges; install (available) / launch+remove (installed) with a remove
  ConfirmDialog; non-fatal "available needs token" hint linking to Settings; empty/loading/error states.
- **WorkflowCard:** prereq-gated **Launch** (disabled + tooltip when unmet), Install, Remove.
- **WorkflowDetail (`/catalog/:workflowId`):** header actions (Launch/Install/Update/Remove) + sub-tabs:
  Overview (description, prereqs, inputs summary, HITL points), **Graph** (static topology preview),
  Runs (recent runs linking to Run Detail). Handles installed vs available-only states.
- **LaunchForm (`/catalog/:workflowId/launch`):** `launch-schema.ts` turns `META.inputs_schema`
  (JSON Schema) into **field descriptors + a zod schema + defaults**; widgets: text/number/textarea/
  select(enum)/switch(boolean)/JSON-fallback. Environment selector (optional), **prereq guard** (blocks
  submit + links to Settings), submit → `POST /runs` → navigate to `/runs/:runId`; 400s surfaced inline.
- **Tests (`catalog.test.tsx`, MSW):** browse+filter, prereq-gated Launch disabled, install action fires
  `POST /library/install`, and launch validation (required blocks submit) + valid submit posts `/runs` and
  navigates. Added `ResizeObserver`/`matchMedia` polyfills to `test-setup.ts` (Radix Switch in a form
  needs ResizeObserver under jsdom).

---

## 4. Verification

- Backend: `pytest` 54 passed, `ruff` clean; **v0.10.0** tag CI green.
- Frontend: `tsc --noEmit` strict clean; `vitest run` **23 passed** (14 ds + 5 settings + 4 catalog);
  temp `vite build` OK; `git status` confirms `static/` unchanged. Frontend + genesis CI **success**
  (commit `63ffaeb`).

---

## 5. Decisions & honest deviations

- **Graph preview is interim.** The detail's Graph tab renders a lightweight static topology
  (nodes + kinds + edges), not React Flow. The spec says it "reuses the Run-Detail graph renderer
  (07-07)", which doesn't exist yet — the rich interactive canvas lands in 07-07 and will **replace
  `GraphPreview`** here. Avoids building React Flow twice.
- **No "update available" auto-detection.** `/catalog/available` excludes installed workflows, so there's
  no installed-vs-latest version compare. **Update** is an explicit action (card/detail), not an amber
  auto-flag. A future enhancement could add a version-compare endpoint.
- **Install is synchronous** (blocking) — installs pull a few files over REST; the button shows a pending
  state. A job/status API is deferred (overkill for local single-user).
- **Markdown description** renders as plain preformatted text (no `react-markdown` yet — arrives with the
  document-preview work in 07-09).

---

## 6. Definition of done (07-05) — status

1. Catalog lists installed + available with role/status filters + accurate prereq badges — ✅.
2. Install / Update / Remove end-to-end via the new library endpoints (compat via lockfile) — ✅.
3. Workflow detail: overview, HITL points, prereqs, static graph preview — ✅ (React Flow deferred to 07-07).
4. Schema-driven Launch validates via zod, guards prereqs, starts a run, routes into Run Detail — ✅.
5. States + component/MSW tests for filter, prereq gating, install, launch-validation — ✅.

---

## 7. Next

07-06 (Runs List & History) — Executions-style table, filter chips, auto-refresh, status pills —
reusing `types/run.ts` + `lib/api` (the `/runs` list endpoint).
