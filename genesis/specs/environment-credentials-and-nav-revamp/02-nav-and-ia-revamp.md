# Spec — Navigation & IA revamp (Applications-first; Overview + Catalog under Settings)

> **Status:** 📝 DRAFT (approved direction, 2026-08-18) · **Area:** genesis web (`app/router.tsx`,
> `shared/layout/Sidebar.tsx`, `features/settings`, `features/overview`, `features/catalog`) · **Type:** frontend-only UX.
> **Related ADR:** new ADR-049 (below). Frontend-only, but still ships a genesis release (committed `web/static`).

## 1. Problem
The primary nav exposes **6** destinations (Overview, Chat, Runs, Applications, Documents, Catalog). User feedback: the
landing + primary tabs should focus on daily work; Overview (metrics) and Catalog (browse/launch) clutter the top level.

## 2. Goal
- **Applications is the landing page** and the first primary tab.
- **Primary sidebar = 4 destinations:** Applications, Chat, Runs, Documents.
- **Overview + Catalog move into Settings**, still fully accessible.

## 3. Decisions (confirmed 2026-08-18)
- Keep the bottom-nav name **"Settings"** (Option A); group its tabs into two zones.
- **Default Settings tab = Overview** (Settings opens on the metrics "home").
- Keep the existing **`/catalog/:workflowId[/launch]`** deep-link routes (used by the Copilot launch flow); drop Catalog
  from the sidebar and embed the Catalog *browse* view as a Settings tab.
- `/` renders Applications directly (index route; no redirect). `/catalog` keeps working (not in nav).

## 4. Target IA
**Sidebar (primary):**
```
Applications   ← index / landing
Chat
Runs
Documents
```
**Settings tab strip (two zones, visual separator in TabsList):**
```
Workspace:      Overview | Catalog        (Catalog keeps Workflows | Skills sub-tabs)
Configuration:  MCP | CLI | GitLab | Environments | General
```
`SettingsPage` `TABS` becomes `["overview","catalog","mcp","cli","gitlab","environments","general"]`; default = `overview`.

## 5. Affected code
- `app/router.tsx` — `{ index: true } → <ApplicationsPage/>`. Keep `/catalog/*` detail/launch routes. (Old `OverviewPage`
  route wrapper retired; content moves into a section — see below.)
- `shared/layout/Sidebar.tsx` — nav = Applications, Chat, Runs, Documents (Applications first). Remove Overview + Catalog
  entries. (Re-label the groups or use one group; keep the brand/health/env header.)
- `features/overview/OverviewPage.tsx` — **extract the content into `OverviewSection`** (no `Page` chrome) so it renders
  inside the Settings "Overview" tab without a double title/padding (mirrors how `general` composes sections).
- `features/settings/SettingsPage.tsx` — add `overview` + `catalog` tabs, the two-zone grouping, default = overview.
- `features/catalog/CatalogPage.tsx` — render its body inside the Settings "Catalog" tab (it already self-contains the
  Workflows | Skills sub-tabs). Clicking a workflow navigates to the retained `/catalog/:id`.
- Tests: `settings.test.tsx` (new tabs + default), sidebar/router tests, overview/catalog render tests, **jest-axe** on the
  expanded Settings tabs. Then **`npm run build` + commit `web/static`** (stale-bundle guard, per §6 of the bible).

## 6. Back-compat / deep links
- `/` → Applications (existing `/` bookmarks now land on Applications).
- Old Overview at `/` → now Settings → Overview (`/settings` default). `/catalog` + `/catalog/:id[/launch]` still resolve
  (Copilot launch + direct links unaffected). Optional (later): redirect `/catalog` → `/settings/catalog`.

## 7. Open follow-up (not blocking)
If users still hunt for Overview under a gear icon, revisit renaming the container to "Manage"/"System" (Option B) — a
label-only change captured here for future reference.

## 8. Out of scope
Any metric/Catalog *content* changes (pure relocation); the credentials change (spec 01).
