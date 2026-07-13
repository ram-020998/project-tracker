# Progress: Phase 8 — Settings & Integrations Revamp

**Spec:** `specs/phase-08-settings-revamp.md`
**Delivered in:** genesis v0.16.0 (commit `d054491`, tag `v0.16.0`)
**CI:** master #6332251 + tag #6332254 — SUCCESS
**Date:** 2026-07-13 · **Layer:** `web` only (no backend/API change)

---

## Summary

Replaced the one-long-scroll settings page (5 stacked sections + 3 inconsistent add/edit
dialogs) with a single **tabbed Settings workspace** — **MCP · CLI · GitLab · Environments ·
General** — and ONE standardized, reusable master-detail + add/edit pattern used by every
integration type. Fixed several real data-fidelity bugs surfaced in the review.

---

## Deliverables

### Navigation & shell
- `SettingsPage.tsx` → `Tabs` shell at **`/settings/:tab?/:id?`** (URL is the source of truth;
  only the active tab's queries run — Radix unmounts inactive content).
- `shared/layout/Sidebar.tsx` — removed the "Configure" group (Integrations + Environments items);
  the single bottom **Settings** entry (active on `/settings*`) is the way in.
- `app/router.tsx` — `/settings`, `/settings/:tab`, `/settings/:tab/:id`.
- `app/RootLayout.tsx` — breadcrumb labels for the tabs.

### Standardized framework (`components/manager/`)
- **`ResourceManager`** — generic searchable master-detail scaffold (list + `HealthDot` + tier
  chip + attention-first sort + `Add`; responsive; `listbox`/`option` a11y). Used by MCP and CLI.
- **`ResourceFormDialog`** — the ONE add/edit dialog (shared `Dialog` + `DialogDescription`),
  with a **Guided ⇄ JSON** `SegmentedControl` (Advanced JSON via `JsonEditor`), per-field errors,
  name pattern + collision validation, and a tokenized security callout. Retires both hand-rolled
  `fixed inset-0` overlays.
- **`SpecForm`** — schema-driven guided form + `specToValues`/`valuesToSpec` (text/textarea/list/kv).
- **`ConfirmDialog`** — shared confirm (replaces browser `confirm()`).

### MCP tab (`components/mcp/`)
- `McpTab` + `McpDetail` on the framework. New **`useMcpResources`** selector joins
  `mcp-cards` (status + secret fields) with `mcp-servers` (raw spec + allowlist + source) by name.
- **Bug fixes:** detail now shows the **real** `command`/`args`/`env` (was a fabricated `{mode}`),
  seeds the allowlist from `spec.tool_allowlist` (was reset to `[]`), detects `source` correctly
  (custom servers are now **editable + deletable** — previously impossible), and **wires
  `updateMcpServer`** (was never called). Raw `emerald/red/amber` → semantic tokens + `HealthDot`.

### CLI tab (`components/cli/`)
- `CliTab` + `CliDetail` + **`useCliResources`** (cli-cards ⋈ clis). **Wires the previously-dead
  edit/delete** for custom CLIs.

### Data layer (`hooks.ts`)
- Added `useUpdateMcpServer`, `useUpdateCli`, `useMcpResources`, `useCliResources`; merged view
  types `McpResource`/`CliResource` in `types/integrations.ts`.

### Removed
- `McpSection.tsx`, `McpServerDetail.tsx`, `CliSection.tsx` (dead after the revamp).

### Reused as-is
- `GitlabSection`, `EnvironmentsSection` (already the canonical Dialog/RHF/zod pattern),
  `StorageSection` (spec 04 retention) — re-homed under their tabs.

---

## Tests (`settings.test.tsx`, rewritten — 9)

- Defaults to MCP tab; lists curated + custom attention-first; tabs present.
- **Regression:** custom server detail shows the real `command` + allowlist chip (`read_file`)
  seeded from `spec.tool_allowlist`; Edit + Delete available.
- Curated server → read-only "edit via MR" banner, no Delete.
- Secret save is write-only (value never rendered).
- Readiness test result renders inline.
- Add a custom MCP server via the standard form dialog → `POST /config/mcp-servers`.
- Environments tab → confirm-before-delete.
- **Regression:** CLI custom edit/delete are wired (were dead).
- **jest-axe** on the MCP tab shell.

---

## Evidence

```
$ npm run typecheck  → clean
$ npm run lint       → 0 errors, 13 warnings (react-refresh, same class as pre-existing)
$ npm test           → 9 files, 67 tests passed
$ npm run build      → ✓ built; web/static/ rebuilt + committed
$ pytest -q          → 83 passed   $ ruff check genesis → clean   (backend unchanged)
Pipeline #6332251 (master): SUCCESS   Pipeline #6332254 (v0.16.0): SUCCESS
```

---

## Decisions / Deviations

- **Route reshuffle:** old `/settings/:server` deep links now resolve to the MCP tab (bare server
  ids aren't tabs); acceptable for a local app (spec §8).
- **Config edit via the dialog**, not an inline editor in the detail pane — keeps ONE add/edit
  surface (the standardized `ResourceFormDialog`); the detail shows a read-only spec view.
- **Merged selectors** treat cards (status/secrets) and entries (spec/source) as independent
  queries joined by name; a custom-only entry lists with status "unknown", a curated card with no
  entry is read-only.
- **Lint warnings +4** are all `react-refresh/only-export-components` (e.g. `SpecForm` exports
  helper fns alongside the component) — same class as the 9 pre-existing; CI passes on 0 errors.

## What's NOT verified (honest disclosure)

- **Live browser QA** not performed headlessly: tab nav, add/edit/delete MCP + CLI against a real
  `genesis serve`, the guided ⇄ JSON round-trip visuals, and responsive collapse. Covered by
  vitest + jsdom + MSW; a manual pass would confirm the interaction polish.

---

## Next

Phase 8 complete. Upcoming polish phases (per the reshuffle) TBD; the **skill-migration program**
remains in `specs/backlog/` (resumes after the polish phases).
