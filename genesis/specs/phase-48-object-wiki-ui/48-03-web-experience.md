# 48-03 — Web: the Object Wiki tab and the object page

> **Status:** 🟡 SPEC-DRAFTED 2026-10-21. Repo: **genesis** (`web/`). Parent: `specs/phase-48-object-wiki-ui.md`.
> Decisions: 48-01 D1–D4, D6, D7. Upstream: **48-02** (read its As built — the real response samples — first).
> Existing stack, tokens and primitives only (ADR-027/055): no new dependency.

## 1. URL-addressable application tabs (D1)

`genesis/web/src/features/applications/ApplicationDetail.tsx:92-107`: replace `defaultValue="business-map"` with a
controlled `Tabs` bound to `?tab=` via `useSearchParams`:

- Ids (unchanged + new): `business-map` · `overview` · **`object-wiki`** · `features` · `syncs` · `releases` ·
  `business-artifacts`. Absent or unknown `?tab` → `business-map`.
- Changing tab → `setSearchParams({ tab }, { replace: true })` (no history entry per click; other params preserved).
- New trigger **"Object Wiki"** right after **Overview**; content `<ObjectWikiTab appUuid={appUuid} />` (Radix unmounts
  inactive content, so the wiki is fetched only when the tab is opened).

Router (`genesis/web/src/app/router.tsx`): add
`applications/:appUuid/wiki/:objectUuid` → `ObjectWikiPage`, and `applications/:appUuid/wiki` →
`<Navigate to="/applications/:appUuid?tab=object-wiki" replace />` (a small component like `StoryRedirect`).
Breadcrumbs (`genesis/web/src/shared/layout/breadcrumbs.ts` `ROUTES`): add `/applications/:appUuid/wiki` → "Object
Wiki" and `/applications/:appUuid/wiki/:objectUuid` → `l["wiki:<objectUuid>"] ?? "Object"`, so the object page's
trail reads **Home › <App> › Object Wiki** and the "Object Wiki" crumb returns to the tab.

## 2. Data layer

- Types `genesis/web/src/types/objectWiki.ts`: `WikiObjectRow`, `WikiEntry`, `WikiStoryRef`, `WikiListResponse`,
  `WikiObjectResponse` — mirror 48-02 §2 exactly (L-011).
- API `genesis/web/src/lib/api/objectWiki.ts` (`objectWikiApi.list(appUuid)`, `.get(appUuid, objectUuid)`; paths
  without `/api` — the client prepends it, ADR-028; `encodeURIComponent` on both ids); export from
  `src/lib/api/index.ts`.
- Query keys in `src/lib/query/keys.ts`: `qk.objectWiki.list(appUuid)`, `qk.objectWiki.detail(appUuid, objectUuid)`.
- Hooks `genesis/web/src/features/object-wiki/hooks.ts`: `useObjectWiki(appUuid)`, `useObjectWikiPage(appUuid,
  objectUuid)` with the app's default refetch-on-focus/mount (D7).

## 3. Shared Appian object-type map (D4)

`genesis/web/src/shared/ui/appian-object-types.ts` (re-exported from `src/shared/ui/index.ts`):
`APPIAN_OBJECT_TYPES: Record<TypeKey, { label: string; icon: LucideIcon }>` for every 48-02 §4 key (e.g. Record Type ·
Interface · Expression Rule · Process Model · Constant · Integration · Connected System · Web API · Data Type · Site ·
Group · Translation Set · Document · Folder · Decision · Report · Other), icons via `@/shared/ui/icons`; and
`objectTypeMeta(key, raw)` → `other` falls back to `raw` as the label. Only this phase's screens use it.

## 4. The Object Wiki tab (D2) — `features/object-wiki/ObjectWikiTab.tsx` + `ObjectWikiTable.tsx`

Visual reference: `features/library/DocumentTable.tsx` + the `LibraryPage.tsx` toolbar.

- **Toolbar:** search `Input` with a Search icon (matches name + summary, case-insensitive; `aria-label="Search
  objects"`) · **Type** `Select` (All + the types present, by label) · **Change** `Select` (All · Created · Updated ·
  Deprecated — the latest change kind) · a muted count "N objects" (or "N of M objects" when filtered).
- **Table** (rounded card, `bg-surface-2` uppercase header, `divide-y` rows, hover `bg-surface-2`):

  | Column | Content |
  |---|---|
  | Object | type icon + name as a focusable button (row is clickable too; Enter/Space work via the button) |
  | Type | the type label (muted) |
  | Summary | `summary`, one line, `truncate`, full text in `title`; "—" when null |
  | Changes | `entry_count`, right-aligned, tabular numerals |
  | Last change | change-kind `Badge` + `RelativeTime(last_changed_at)` |
  | Last changed by | `latest_author` or "—" |

- **Sorting:** headers are buttons with `aria-sort`; sortable: Object, Type, Changes, Last change (default
  **Last change desc**), Last changed by; click toggles asc/desc. Client-side (D7).
- **Badges** (one helper reused by the page): created → `success`, updated → `info`, deprecated → `warning`
  ("Deprecated"); Bug fix → `danger`.
- **States:** `LoadingState` · `ErrorState` with Retry · empty app → `EmptyState` (icon, "No objects documented yet",
  "The Object Wiki fills in as stories go through Implementation. Teammates' entries appear here when collaboration is
  on.") · no filter match → `EmptyState` "No objects match" + action "Clear filters".
- Row open → `navigate(\`/applications/${appUuid}/wiki/${encodeURIComponent(object_uuid)}\`)`.

## 5. The object page (D3) — `features/object-wiki/ObjectWikiPage.tsx` + `HistoryTimeline.tsx`

Layout follows `DocumentDetailPage.tsx` (`Page` + header actions + metadata chips + body); `max-w` and spacing as the
other detail pages.

- `useSetCrumb("app:<appUuid>", app_name)` and `useSetCrumb("wiki:<objectUuid>", object.name)`.
- **Header:** `Page` title = object name; type icon + type badge; `Deprecated` badge when `is_deprecated`; action
  **Back** (ghost, `ChevronLeft`) → `/applications/<appUuid>?tab=object-wiki` (explicit target, so a deep-linked page
  still goes to the tab, not out of the app).
- **Metadata line** (muted chips): object UUID (monospace, truncated with `title`) + a ghost icon button "Copy object
  UUID" (`navigator.clipboard.writeText` + the shared toast; there is no shared copy primitive today) · "Version
  <latest_object_version>" · "<entry_count> changes" · "First documented <RelativeTime>" · "Last changed
  <RelativeTime>" · "Not in the KB yet" chip when `in_kb` is false.
- **Current summary** `Card` (text, `whitespace-pre-wrap`; "No summary yet." when null).
- **History** section: heading "History" + a `SegmentedControl` **Both · Business · Technical** (default Both, local
  state) on the right; then `<ol aria-label="Change history">`, newest first. Each item = a card on a vertical rail
  (dot coloured by change kind, as `ActivityFeed.tsx`):
  - top row: change-kind badge · `Bug fix` badge (+ `change_reason` as text when present) · "v<object_version>" ·
    `RelativeTime(created_at)` · author;
  - story: resolved → `Link` to `/applications/<appUuid>/stories/<story.id>` reading "<key> · <title>" (ADR-071);
    unresolved with a `story_key` → the key as text inside a `Tooltip` "Story not available on this machine"; neither →
    nothing;
  - sections per the switch: **Business change** then **Technical change**, each a small uppercase label (`<h3>`) +
    text; a missing description → muted "Not recorded.".
- All description text is rendered as **plain text** (`whitespace-pre-wrap`) — never `dangerouslySetInnerHTML`.
- States: `LoadingState`; 404 → `EmptyState` "This object has no wiki page" + Back; other errors → `ErrorState` +
  Retry.
- Never use `<Button asChild>` (L-069) — use `Link` styled as needed or `Button` + `navigate`.

## 6. Tests (Vitest + Testing Library + msw + jest-axe; pattern `features/library/library.test.tsx`)

Fixtures = the 48-02 As-built samples, verbatim (L-083). `features/object-wiki/objectWiki.test.tsx` +
an `ApplicationDetail` tab test:

1. `?tab=object-wiki` opens the tab; no/unknown `?tab` → Business Map; clicking a tab updates `?tab` (replace).
2. Tab: rows render with labels/badges; search, Type and Change filters; sort toggles + `aria-sort`; empty app and
   no-match states (Clear filters resets); row click and name-button Enter navigate to the object URL.
3. Page: header, deprecated badge, metadata, summary; entries newest first; the switch hides/shows sections; resolved
   story link href; unresolved key shows text (no link); Back target; 404 state.
4. `objectTypeMeta`: known keys, `other` + raw fallback.
5. jest-axe clean on the tab and the page (L-014 setup).

Gates: `cd genesis/web && npm run lint && npm run typecheck && npm test`, then `npm run build` and **commit
`web/static/`** (stale-bundle guard; L-030).

## Context manifest

```toml
areas    = ["web-shell", "stories-workbench"]
adrs     = ["ADR-027", "ADR-028", "ADR-037", "ADR-049", "ADR-055", "ADR-070", "ADR-071"]
lessons  = ["L-010", "L-011", "L-014", "L-030", "L-069", "L-083", "L-084"]
docs     = ["tracker:specs/phase-48-object-wiki-ui/48-01-findings.md",
            "tracker:specs/phase-48-object-wiki-ui/48-02-api.md"]
code     = ["genesis/web/src/features/applications/ApplicationDetail.tsx",
            "genesis/web/src/features/object-wiki/**", "genesis/web/src/app/router.tsx",
            "genesis/web/src/shared/layout/breadcrumbs.ts", "genesis/web/src/shared/ui/appian-object-types.ts",
            "genesis/web/src/shared/ui/index.ts", "genesis/web/src/lib/api/objectWiki.ts",
            "genesis/web/src/lib/api/index.ts", "genesis/web/src/lib/query/keys.ts",
            "genesis/web/src/types/objectWiki.ts", "genesis/web/static/**"]
upstream = ["48-02"]
```
