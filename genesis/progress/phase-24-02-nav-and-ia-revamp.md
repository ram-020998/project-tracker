# Progress — Phase 24-02: navigation & IA revamp (as-built)

**Shipped:** genesis **v0.48.6** (`f98bc04`), frontend-only, CI green (genesis + frontend + clean-install). **ADR-049 Accepted.**

## What shipped
Applications-first information architecture (ADR-049):

- **Landing + primary nav (`shared/layout/Sidebar.tsx`, `app/router.tsx`):** the primary sidebar is now
  **Applications · Chat · Runs · Documents** (single "Workspace" group, Applications first). Overview + Catalog removed from
  the sidebar. The index route `/` **redirects to `/applications`** (`<Navigate replace/>`) — chosen over rendering the list
  at `/` so the nav active-state + `/applications/:uuid` detail stay consistent (minor deviation from the spec's
  "no redirect"; the landing is still Applications). Dropped the now-unused `LayoutDashboard`/`Boxes` icons + the `OverviewPage`
  router import.
- **Overview + Catalog under Settings (`features/settings/SettingsPage.tsx`):** tabs are now
  `Overview · Catalog | MCP · CLI · GitLab · Environments · General` (a subtle divider separates the **Workspace** zone from the
  **Configuration** zone). **Default tab = Overview**, so Settings opens on the metrics home.
- **Reusable sections (no `Page` chrome):** extracted **`OverviewSection`** from `OverviewPage` (the range control +
  AutoRefreshChip + metrics/trend/active-runs/installed) and added **`CatalogSection`** to `CatalogPage` (Workflows|Skills via
  **local state**, so it composes inside a Settings tab). The standalone **`OverviewPage`** and **`/catalog[/:id/launch]`**
  routes/pages are retained for deep links (the Copilot launch flow + WorkflowDetail/RunsPage/LaunchForm/GitlabSection all
  still link to `/catalog`), and their tests keep passing.

## Deep-link / back-compat
- `/` → `/applications`. Old `/catalog`, `/catalog/:id`, `/catalog/:id/launch` still resolve (not in the sidebar). Overview
  moves to `/settings` (default tab). `window.location.href="/catalog"` (Overview empty-state) unaffected.

## Tests
- web **163** vitest (settings suite: repointed the MCP-content tests to `/settings/mcp`, added a "defaults to the Overview
  tab" test + a `/api/home` MSW mock; env-creds + delete tests reach Environments by clicking the tab). lint 0 errors,
  typecheck clean, build committed (`web/static`).
- Backend unchanged (frontend-only release).

## Not done / optional
ADR-049 Option B (rename the Settings container to "Manage"/"System") is deferred — a label-only follow-up if users still hunt
for Overview under the gear icon.
