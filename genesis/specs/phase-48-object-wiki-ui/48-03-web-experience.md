# 48-03 — Web: the Object Wiki tab and the object page

> **Status:** ✅ DONE 2026-10-21 (genesis `01288c9` + `5789f88` + `0b2ecec`, local; review SHIP — see As built). Repo: **genesis** (`web/`). Parent: `specs/phase-48-object-wiki-ui.md`.
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
    *(amended by 48-01 D8: the reason shows on every entry as a muted "Why: …" line — built in 48-04 H1)* ·
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

## As built (genesis-dev, 2026-10-21)

**Status:** ✅ DONE. Review **SHIP** (`reviews/48-03-review.md`), plus a delta SHIP on 5789f88. Committed locally only: not pushed, not tagged (48-05).

### Commits (genesis, base `148c064`)

| Commit | Message |
|---|---|
| `01288c9` | feat(web): Object Wiki tab + object page, URL-addressable application tabs (48-03) |
| `5789f88` | fix(web): 48-03 review follow-ups — tests for replace/404-retry/other-type options, safe copy, 404 copy, comments (48-03) |
| `0b2ecec` | test(web): deterministic 404-not-retried check (retryDelay 0) (48-03 review n5) |

Every commit that touched the bundle includes the rebuilt `web/static/`. The reviewer diffed a fresh build against it and found it identical.

### Changed (all under `genesis/web/src/`)

- `features/applications/ApplicationDetail.tsx`: the tabs are now a controlled `Tabs` bound to `?tab=` (`APP_TABS` and `resolveTab`; an absent or unknown value → `business-map`). A tab change calls functional `setSearchParams` with `replace: true` and keeps other params. A new "Object Wiki" tab sits after Overview and renders `<ObjectWikiTab>`.
- `app/router.tsx`: `applications/:appUuid/wiki` → `WikiRedirect` (to `?tab=object-wiki`), and `applications/:appUuid/wiki/:objectUuid` → `ObjectWikiPage`.
- `shared/layout/breadcrumbs.ts`: adds the `/applications/:appUuid/wiki` crumb ("Object Wiki") and the `/…/wiki/:objectUuid` crumb (`wiki:<uuid>` label, else "Object").
- `types/objectWiki.ts` (new): `WikiObjectRow`, `WikiEntry`, `WikiStoryRef`, `WikiListResponse`, `WikiObjectResponse`, `WikiChangeKind`.
- `lib/api/objectWiki.ts` (new): `objectWikiApi.list` and `.get`, with no `/api` prefix and both ids encoded. It is exported from `lib/api/index.ts`.
- `lib/query/keys.ts`: `qk.objectWiki.list(appUuid)` and `qk.objectWiki.detail(appUuid, objectUuid)`.
- `shared/ui/appian-object-types.ts` (new; re-exported from `shared/ui/index.ts`): `APPIAN_OBJECT_TYPES` for the 17 canonical keys, plus `objectTypeMeta(key, raw)`. `shared/ui/icons.ts` adds BarChart3, BookOpen, Box, Braces, Cable, Folder, Hash, Languages, LayoutTemplate, PanelsTopLeft, Split and SquareFunction.
- `features/object-wiki/` (new):
  - `hooks.ts`: `useObjectWiki`, `useObjectWikiPage`, `isNotFound`.
  - `wiki-logic.ts`: pure change-kind meta, filter, type options, sort and `nextSort`.
  - `badges.tsx`: `ChangeKindBadge` and `BugFixBadge`.
  - `ObjectWikiTab.tsx`, `ObjectWikiTable.tsx`, `ObjectWikiPage.tsx`, `HistoryTimeline.tsx`.
  - `fixtures.ts`: the 48-02 samples, verbatim.
  - `objectWiki.test.tsx`.

### Tests

- `features/object-wiki/objectWiki.test.tsx` (34 tests) covers all of §6 items 1–5:
  - URL tabs: open, fallback, `?tab` write, params kept, and `replace` (Back leaves the app page).
  - The tab: rows, labels and badges, search, the Type and Change filters, sort with `aria-sort`, the empty, no-match/Clear-filters and error states, row click, and Enter on the name button.
  - The page: header and metadata, Deprecated and "Not in the KB yet", newest-first entries, the Business/Technical switch, "Not recorded.", plain-text rendering, the story link vs an unresolved key, Back, 404, and a 404 not retried while a 500 is retried once.
  - `objectTypeMeta`; pure sort/filter (mixed `Z`/`+05:30` instants, unparseable values last, two `other` raw types kept apart).
  - jest-axe on both the tab and the page.
- `shared/layout/breadcrumbs.test.tsx`: +1 (Home › Application › Object Wiki).
- Mutation checks: the replace test fails with `replace:false`, and the 404 test fails when 404s are retried. The reviewer also mutation-checked the retry test.
- Gates: `npm run typecheck` is clean. `npm run lint` has 0 errors and 20 warnings; the one new warning is the react-refresh rule on `WikiRedirect`, the same as the existing `StoryRedirect`. `npm test` → 46 files, **367 passed** (332 at v0.77.0). `npm run build` OK. Backend untouched.

### Review

`genesis-review` gave **SHIP** on 01288c9: no blockers or majors, minors m1–m2, nits n1–n4. m2 and n1–n4 are fixed in 5789f88, which got a delta **SHIP** with a new nit n5; n5 is fixed in 0b2ecec. **m1 is open for the user (a D3 product question):** the `story-implementation` workflow writes `change_reason` on *every* entry (`genesis-workflows/workflows/story-implementation/graph.py:668`, stored at `:395`). Under D3 the UI shows it only on bug fixes, so the "why" of ordinary created/updated entries is never shown. The option on the table is to show the reason as muted text whenever it is present and keep the Bug fix badge for `is_bugfix` only. It should be decided before 48-04.

### Decisions / deviations (spec refinements; no ADR deviation)

1. **Focus refetch is turned on explicitly in the wiki hooks.** The app's QueryClient defaults to `refetchOnWindowFocus: false` (`lib/query/client.ts:9`), but D7 asks for refetch-on-focus/mount so that teammates' pulled entries show up.
2. **A 404 on the detail query is not retried.** Other errors keep the app's single retry.
3. **The Type filter matches by display label, not key**, so `other` rows with different `type_raw` values show up and filter as separate types.
4. **Sorting:** clicking a new column starts it in its natural direction (Last change and Changes descending, the others ascending), and a second click flips it. Unparseable or blank timestamps sort last in both directions, which matches the API's rule. Ties break by name, then uuid.
5. **Shared `Select` takes `ariaLabel`.** The Type and Change filters use it and are named "Filter by type" / "Filter by change".
6. **Small additions beyond the spec:**
   - "No changes recorded yet." for a page with 0 entries.
   - A broader 404 description ("…or the application isn't tracked here").
   - A copy failure shows an error toast.
   - Singular forms: "1 object" and "1 change".

### Lesson candidates

- **The shared `Select` silently drops `aria-label`.** It takes `ariaLabel`, and TypeScript does not check hyphenated JSX attributes, so `<Select aria-label=…>` type-checks but leaves the trigger with no accessible name. `features/features/StoriesTab.tsx:155,158` does this today, so its two filter triggers are unnamed. This is a pre-existing bug outside this sub-spec and should be filed for follow-up. One fix is to make `Select` accept and forward `aria-label`.
- **When a hook sets its own `retry`, the test QueryClient's `retry:false` doesn't apply.** Tests then wait out the real retry delay, and an "it wasn't retried" assertion becomes a timing race. Set `retryDelay: 0` in the test client and assert the call count.

### Code-map changes (for genesis-docs)

- `web/src/features/object-wiki/` (new): the Object Wiki tab (`ObjectWikiTab`/`ObjectWikiTable`), the object page (`ObjectWikiPage`/`HistoryTimeline`, route `/applications/:appUuid/wiki/:objectUuid`), the pure view logic `wiki-logic.ts`, and the hooks.
- `web/src/shared/ui/appian-object-types.ts` (new): the shared Appian object-type map (canonical key → label + icon; `objectTypeMeta`).
- `web/src/features/applications/ApplicationDetail.tsx`: the application tabs are URL-addressable through `?tab=` (ids: `business-map`, `overview`, `object-wiki`, `features`, `syncs`, `releases`, `business-artifacts`).
- `web/src/types/objectWiki.ts`, `web/src/lib/api/objectWiki.ts` and `qk.objectWiki` (new): the Object Wiki contract, client and query keys.
