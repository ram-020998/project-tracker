# 48-01 — Findings: the Object Wiki in the application page

> **Status:** ✅ DONE — research + Q&A with the user (2026-10-21); decisions D1–D7 locked.
> Parent: `specs/phase-48-object-wiki-ui.md`. Relates to **ADR-070** (Object Wiki), **ADR-071** (canonical story
> page), **ADR-027/055** (web stack + design language), **ADR-028** (`/api`), **ADR-037** (code-free).

---

## 1. The ask (user, 2026-10-21)

Show the Object Wiki in the application page (`/applications/:appUuid`) as a new tab **right after Overview**: a
grid of the application's documented objects; clicking an object opens its **summary** with the object's **full
change history**. The UI/UX must be standard, look good, and be consistent with the rest of the app.

Confirmed scope (user, 2026-10-21): read-only; local tables only (teammates' entries arrive via the existing collab
pull); no object code; no wiki editing; no agent-memory use (backlog `wiki-as-agent-memory.md`); no Hub contract change.

## 2. How Genesis works today (verified in the code)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`.

### 2.1 Data (ADR-070, m0021)

- `wiki_object_pages` (`genesis/db/migrations/m0021_object_wiki.py:33-60`): `id`, `app_uuid`, `object_uuid`,
  `object_type`, `object_name`, `current_summary`, `latest_entry_id`, `created_at`, `updated_at` + collab columns
  (`sync_uuid`, `row_version`, `owner_username`, `team_uuid`, `published_by/_at/_version`); `UNIQUE(app_uuid,
  object_uuid)`; index on `app_uuid`.
- `wiki_object_entries` (m0021:62-86, append-only): `id`, `page_id` → pages (CASCADE), `change_kind`
  (created|updated|deprecated), `business_description`, `technical_description`, `story_key`, `story_sync_uuid`,
  `is_bugfix` (0/1), `change_reason`, `object_version`, `author_username`, `created_at` + collab columns; index on
  `page_id`. m0022–m0024 do not touch either table.
- Teammates' rows are pulled into the **same** tables (`genesis/collab/service.py:117-125` bindings `wiki_page` /
  `wiki_entry`; `_upsert_local` stamps `published_by/_at/_version`, `service.py:561-666`). There is no explicit
  `origin` column.

### 2.2 Store (`genesis/kb/object_wiki.py`)

`ObjectWikiStore(db)`: `upsert_page`, `get_page`, `get_page_by_id`, `list_for_app(app_uuid)` (all pages, sorted by
name, no pagination/filter/aggregates), `append_entry` (idempotent per `(page_id, story_key)`), `get_entry`,
`list_entries(page_id)` (oldest → newest), `get_object_history(app_uuid, object_uuid) -> {page, entries}`. Rows are raw
`dict(row)` (`is_bugfix` is an int). Only constructed in `genesis/runtime/context.py:157` for workflow nodes —
**no API exposes the wiki today**, and no web code references it.

### 2.3 Story references

- The `story-implementation` workflow writes `story_key = story["key"]`
  (`genesis-workflows/workflows/story-implementation/graph.py:307,392`) — a `GNS_<6-digit>` key (ADR-072) for current
  stories; older Hub data shows pre-ADR-072 keys like `story-1-1` (`specs/appian-env/01-data-model-reference.md:155`).
- The canonical story page is `/applications/:appUuid/stories/:storyId` (`web/src/app/router.tsx:65`, ADR-071) where
  `storyId` is the **local integer** `kb_stories.id` (`genesis/api/workbench.py:400-409`, `kb/stories.py:187-202`).
  No endpoint resolves a `story_key`/`story_sync_uuid` to a local id today.

### 2.4 Object name/type

- Pages carry their own `object_name`/`object_type`, so the wiki does not depend on a KB row (a newly created object
  may not be in `kb_objects` until the next sync).
- `kb_objects` (m0007, SCD-2) has canonical `name`/`type` keyed by `(app_uuid, object_uuid)`.
- Wiki `object_type` values are **inconsistent** in real data (`Record Type`, `record_type`, `recordData`,
  `constant`, …; `specs/appian-env/01-data-model-reference.md:154`).
- The web has **no** shared Appian object-type label/icon map (only workflow `NODE_KIND_ICON`,
  `web/src/shared/ui/icons.ts`); the Overview tab prints KB type names verbatim
  (`web/src/features/applications/ApplicationDetail.tsx:179-183`).

### 2.5 API conventions

Per-app routes live in `genesis/api/applications.py` (`register_applications_routes`, list + detail pair
`/applications/{app_uuid}/objects[/{object_uuid}]`, `:190-196`); routers close over stores built from
`settings.db_path` (`genesis/api/workbench.py:55-63`); unknown app → `HTTPException(404)` (`applications.py:68-71`).
Tests: flat `tests/test_*_api.py`, fixture pattern `tests/test_applications_api.py:53-71` (TestClient + migrate).

### 2.6 Web conventions

- Application page: `ApplicationDetail.tsx:92-107` — Radix `Tabs` with **local state** (`defaultValue="business-map"`),
  order Business Map · Overview · Features · Syncs · Releases · Business Artifacts. Tabs are **not URL-driven**, so
  returning from a sub-page lands on Business Map.
- No generic DataTable and no grid library (`package.json`); tables are hand-rolled per feature. Reference list:
  `web/src/features/library/DocumentTable.tsx` (rounded card table, uppercase subtle header, row click + focusable
  name button) with search `Input` + `FilterSelect` in `LibraryPage.tsx`. Reference detail:
  `DocumentDetailPage.tsx` (`Page` + Back + metadata chips). Reference history list:
  `web/src/features/features/ActivityFeed.tsx` (dot + text + `at · actor` `<ol>`).
- Shared primitives: `Badge`/`StatusPill` (`shared/ui/badge.tsx`), `EmptyState`/`ErrorState`/`LoadingState`
  (`shared/feedback/states.tsx`), `RelativeTime` (`shared/ui/format.tsx`), `Select`, `FilterChip`, `Card`, `Tabs`,
  breadcrumbs `useSetCrumb` (`shared/layout/breadcrumbs.ts`).
- API: `src/lib/api/client.ts` prepends `/api`; resource modules `src/lib/api/*.ts`; hooks `src/features/<x>/hooks.ts`;
  keys `src/lib/query/keys.ts`; types `src/types/*.ts`. Tests: Vitest + Testing Library + msw + jest-axe
  (`src/features/library/library.test.tsx`).

### 2.7 Prior art

The read-only Genesis Hub Appian site already has an Object Wiki page — object cards by type → a Wiki Page record
view with a timeline (`specs/appian-env/00-overview.md:55-60`).

### 2.8 Gotchas the build must respect

- **`latest_entry_id` is local-only** (`genesis/collab/service.py:41`, `_LOCAL_ONLY`): a **pulled** page never gets it
  (only `append_entry` advances it), so "latest change" must be **derived from the entries** (newest by
  `created_at`, then `id`), never from the pointer.
- **`created_at` crosses the Hub**, and the Hub may return dates in a different string form (L-084), so sort by
  `created_at, id` and let the web parse with `Date` (`RelativeTime` already shows "—" for unparseable values).
- Real `kb_objects.type` values are the parser's display names (`Expression Rule`, `Interface`, `Record Type`,
  `Process Model`, `Constant`, `Integration`, `Connected System`, `Web API`, `Data Type`, `Site`, `Group`,
  `Translation Set`, `Document`; `genesis-appian-parser`); the current KB row is the one with
  `valid_to_sync IS NULL` (`genesis/kb/_object_reads_mixin.py:121`).
- `kb_stories` carries `sync_uuid` (m0019 collab tables, `m0019_collab.py:43`) and `key` (`GNS_…`, m0022).

## 3. Decisions (Q&A with the user, one at a time)

| # | Decision | Reason |
|---|---|---|
| D1 | Clicking an object opens a **full page with its own URL** `/applications/:appUuid/wiki/:objectUuid` (Back button + breadcrumb + shareable link) — not a drawer. The application page's tabs become **URL-addressable** (`?tab=<id>`, all six tabs + the new one; default stays Business Map) so Back returns to the Object Wiki tab. | Matches the existing list → detail pattern (Documents, Features, Stories); deep-linkable; without URL tabs, Back would land on Business Map (2026-10-21). |
| D2 | The tab is a **Documents-style table** (no cards). Columns in order: **Object** (type icon + name) · **Type** (normalized label) · **Summary** (current summary, one-line truncated) · **Changes** (entry count) · **Last change** (change-kind badge + relative time) · **Last changed by** (author). Toolbar: search (name + summary) · Type filter · Change-kind filter. Default sort = last changed, newest first; column headers sortable. | Scannable/sortable/comparable at scale and consistent with `DocumentTable`; the cards-by-type layout (Hub site) scans worse for large apps (2026-10-21). |
| D3 | Object page layout: **header** (object name · type badge · `Deprecated` badge when the latest entry is `deprecated` · Back) → **metadata line** (object UUID + copy · current object version · change count · first documented · last changed) → **Current summary** card → **History** timeline, newest first. Each entry: change-kind badge · `Bug fix` badge + reason (when `is_bugfix`) · object version · time · author · story link (plain text when the story is not local) · labelled **Business change** then **Technical change** sections. A page-level **Business / Technical / Both** segmented switch (default Both) filters which description sections render. | One audience-switchable view: a PO reads the business story, a developer the technical one, without per-entry clicking (2026-10-21). |
| D4 | Display name/type: prefer the **current KB row** (`kb_objects`, open SCD-2 version, by `(app_uuid, object_uuid)`) and fall back to the page's own `object_name`/`object_type` when the object is not in the KB (e.g. created since the last sync). The **backend normalizes** the type to one canonical key (pure helper; `record_type` / `Record Type` / `recordData` → `record_type`, unknown → `other`, raw value kept alongside). The web adds **one shared Appian object-type map** (key → label + icon) under `web/src/shared/**`, reusable elsewhere later (re-pointing the Overview tab is out of scope). | Renamed objects show their current name; real wiki type values are inconsistent (`01-data-model-reference.md:154`); one normalization home, unit-testable (2026-10-21). |
| D5 | **No cross-links in Phase 48** — the Object Wiki tab is the only entry point. The story → wiki "Objects changed" link (and ⌘K search over wiki objects) is deferred to backlog `specs/backlog/wiki-story-cross-link.md`. | The story Implementation tab shows the object table only inside the report iframe, so the link needs a new list + a story filter on the API; the user will decide it later (2026-10-21). |
| D7 | Defaults (user OK'd, 2026-10-21): tab label **"Object Wiki"** (`?tab=object-wiki`); empty state "No objects documented yet" + how the wiki fills (Implementation lane; teammates' entries when collaboration is on); the list API returns **all** of an app's pages with SQL-computed aggregates (entry count, latest change kind/time/author) and the web searches/filters/sorts **client-side** (no pagination — tens–hundreds of objects); TanStack Query refetch-on-focus/mount for freshness; deprecated objects **shown** by default (badge + Change filter); release = **genesis-only minor v0.78.0**, no migration, no genesis-core / genesis-workflows / Hub change; sub-specs 48-01 findings · 48-02 API · 48-03 web · 48-04 review & acceptance · 48-05 release & onboarding. | Scale matches Documents; keeps the phase genesis-only and additive (2026-10-21). |
| D6 | Story references resolve **server-side** to the canonical story page (ADR-071): match `story_sync_uuid` → `kb_stories.sync_uuid`, else `story_key` → `kb_stories.key` within the app; the entry carries `story: {id, key, title} | null`. Unresolved → the raw key as plain text + a tooltip "Story not available on this machine". | ADR-071 needs the local integer id; the wiki stores the key/sync id (§2.3). Minor default chosen by the spec agent, noted to the user (2026-10-21). |

## Context manifest

```toml
areas   = ["stories-workbench", "api", "web-shell"]
adrs    = ["ADR-027", "ADR-028", "ADR-037", "ADR-055", "ADR-063", "ADR-070", "ADR-071", "ADR-072"]
lessons = ["L-010", "L-011", "L-039", "L-069", "L-083"]
docs    = ["tracker:specs/appian-env/00-overview.md", "tracker:specs/appian-env/01-data-model-reference.md"]
code    = ["genesis/genesis/kb/object_wiki.py", "genesis/genesis/api/applications.py",
           "genesis/web/src/features/applications/**", "genesis/web/src/app/router.tsx"]
upstream = []
```
