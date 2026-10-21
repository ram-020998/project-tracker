# Review 48-04 — base `d6ee6cd` (v0.77.0) → HEAD `fdc47ab` (genesis-review, 2026-10-21)

Scope: the whole Phase-48 genesis diff — `940deef`, `148c064` (48-02 API), `01288c9`, `5789f88`, `0b2ecec` (48-03 web),
`fdc47ab` (48-04 H1). Local only (not pushed or tagged). Pack: `genesis-ctx pack 48-04`; check:
`genesis-ctx check --since d6ee6cd --repo genesis` (88 files; areas api, features-stages, release-ci, security,
stories-workbench, web-shell). Read: 48-01 §3 D1–D8, 48-02 and 48-03 As built, and the diff.

## Verdict: **NEEDS_CHANGES**

The code, the contract and every gate are green. H1 is correct and mutation-checked. Live API rows 1–2 and browser
rows 3–9 pass on the real data. **One acceptance row fails: row 11, narrow window.** Below about 1000 px the object
page's title (an unbroken Appian name) runs past the right edge, and the table's "Last change" cell spills into
"Last changed by". The Documents and Story pages do not overflow at the same width. The genesis-live-acceptance skill
grades a failed acceptance row as at least major. The fix is two class changes plus a test (M1).

## Findings

### Blockers
None.

### Majors
- **M1 — Row 11 fails: horizontal overflow at narrow widths (object page title and table cell).**
  - Evidence:
    - At 768 px the object page's `<main>` scrolls 217 px horizontally. The `h1` `AS_GSS_REF_ID_DOCUMENT_BUILDER_DRAFT_STA…` is clipped at the edge (`/tmp/genesis-review/pw/row11-object-light-768.png`). At 900 px the overflow is 85 px.
    - At 768 px the Last-change cell's content is 107 px wide in an 80 px cell, so "26 days ago" overprints "admin.user" (`row11-tab-dark-768.png`; `widths.cjs` worst cell overflow 30 px at 768, 8 px at 900).
    - Same width, same session: `/documents`, `/documents/1` and `/applications/…/stories/77` have `main` overflow 0 (`compare768.cjs`).
    - Both pages are clean at 1024, 1280 and 1440, in both themes.
  - Causes:
    - `Page`'s `h1` (`web/src/shared/layout/Page.tsx:20`) does not wrap. Object names have no spaces, so they never break. Story and document titles do have spaces.
    - `ObjectWikiTable.tsx:90` wraps the badge and the time in a non-wrapping `inline-flex` inside a `table-fixed` 17% column.
  - Fix, kept to the phase's files:
    - In `ObjectWikiPage.tsx:93`, pass the title as `<span className="break-all">{object.name}</span>`. `[overflow-wrap:anywhere]` also works.
    - In `ObjectWikiTable.tsx:90`, add `flex-wrap` (with `gap-y-1`) to the cell's span, or stack the time under the badge.
    - Add a regression test, for example that the title element carries the wrap class. Then rebuild and commit `web/static`.
  - The pre-existing tab-strip overflow on the app page (97 px at 768, the same on the Features tab) is **not** caused by this phase. It is not counted here.

### Minors
- **m1 — 48-04 sub-spec has no "As built" for H1.** §1.1 says "Record in this sub-spec's As built", but
  `48-04-review-and-acceptance.md` ends at §4 "As run" and the Context manifest. The commit and tests exist (`fdc47ab`).
  Add the As built section: the commit, the tests, the mutation check and the gates.

### Nits
- **n1** — `web/src/types/objectWiki.ts:35,59,66`: `WikiStoryRef.key` and `app_name` are typed `string`, but the backend can return null:
  - `kb_stories.key` for a pre-m0022 story resolved by `sync_uuid` (`kb/object_wiki.py:286`);
  - `app.get("name")` (`api/object_wiki.py:28,37`).
  A null key would render as " · title" (`HistoryTimeline.tsx:41`). The live DB has 0 blank keys, so this is not observed. Type them `string | null` and guard the separator.
- **n2** — The H1 tests cover `created` and `updated` (bug fix) entries, not a `deprecated` entry with a reason. The code is kind-independent (`HistoryTimeline.tsx:87`), so this is optional.

(Out of scope by instruction: the shared `Select` aria-label bug, backlog `phase-48-follow-ups.md` item 1.)

## §1 Independent review

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Read-only; no Hub call | OK | Only `@api.get` routes in `genesis/api/object_wiki.py:24,30`. The store's new methods `list_objects`/`get_object` (`kb/object_wiki.py:173,190`) use `connect()` + SELECT only. No diff under `genesis/db` or `genesis/collab` (`git diff --name-only d6ee6cd..HEAD -- genesis/db genesis/collab` is empty). No collab import in the new modules. Live: the Playwright route guard saw **0** non-GET `/api` requests (`results.json` `blocked: []`). |
| 2 | One DTO builder; `is_bugfix` bool | OK | `_object_row` (`kb/object_wiki.py:250`) is used by both list (`:186`) and detail (`:208`). `_truthy` (`:243`) feeds `_entry_row` (`:276`). Test `test_list_row_equals_detail_object_and_kb_values_win`. Live: all 21 objects have detail `object` == list row, and every `is_bugfix` is a JSON bool (`live_detail.py`: 0 problems). |
| 3 | Latest change derived from entries; pulled-shape test | OK | `_ROW_SELECT` `le`/`fe` correlated subqueries ordered by `julianday(created_at)`, then id (`kb/object_wiki.py:221-240`); `latest_entry_id` is not read. `test_pulled_page_derives_latest_from_entries` (`tests/test_object_wiki_api.py:141`). Live: an independent Python-side "latest" matched all 21 rows (`live_compare.py`: 0 mismatches). |
| 4 | No N+1; app-scoped | OK | The list is one statement (`kb/object_wiki.py:179-185`). The detail is row + entries + one batched story query (`_resolve_stories`, `:290-327`, `WHERE f.app_uuid = ?`). `test_pages_of_another_app_are_not_listed`. |
| 5 | Story links canonical; cross-app key never resolves | OK | `HistoryTimeline.tsx:37` links to `/applications/${appUuid}/stories/${entry.story.id}`. `test_story_resolution` covers a key from another app → null. Live row 7: href `/applications/<app>/stories/77`. |
| 6 | No code, no HTML injection | OK | `grep dangerouslySetInnerHTML` finds nothing in `features/object-wiki`. Text renders as `whitespace-pre-wrap` `<p>` (`HistoryTimeline.tsx:22,88`; `ObjectWikiPage.tsx:107`). The entry DTO has no code field. Test "descriptions are plain text, never HTML". |
| 7 | Consistency (tokens, deps, asChild, /api, types, fixtures) | OK | No raw palette classes; `text-[11px]` matches `DocumentTable.tsx:32`. No `package.json`/lock change. No `<Button asChild>` in the new code. Paths have no `/api` (`lib/api/objectWiki.ts:7,9`). Types mirror `_object_row`/`_entry_row` (n1 aside). `fixtures.ts` holds the 48-02 samples (`GNS_000123`, `Record Type`, `Z`/`+00:00` values). |
| 8 | URL tabs | OK | `APP_TABS` + `resolveTab` (`ApplicationDetail.tsx:31-39`), with `replace: true` (`:53`). Tests at `objectWiki.test.tsx:101,116,125`. Live rows 3 and 8: all 7 tabs are present, and Back and the breadcrumb both land on `?tab=object-wiki` with the tab selected. |
| 9 | Accessibility | OK | jest-axe tests at `objectWiki.test.tsx:236,364,420`. `aria-sort` sits on the `<th>` (`ObjectWikiTable.tsx:22`), test `:181`; live: each sortable column toggles asc↔desc. The row action is a `<button>` (`:73`), test `:228`. The switch is labelled `aria-label="Show descriptions"` (`ObjectWikiPage.tsx:117`). |

### §1.1 H1 (48-01 D8) — OK
- `HistoryTimeline.tsx:87-89`: `{e.change_reason?.trim() && <p …>{`Why: ${e.change_reason.trim()}`}</p>}`. It renders for every kind, outside the `view` conditionals (`:91-92`). A blank or null reason renders no line.
- `:79`: `{e.is_bugfix && <BugFixBadge />}`. The old `is_bugfix && change_reason` span was removed (`git show fdc47ab`).
- Tests are in `describe("Object page — the change reason on every entry (48-01 D8, 48-04 H1)")` (`objectWiki.test.tsx:371-426`): created+reason, bug fix shown once, null, blank, every view, jest-axe.
- **Mutation check reproduced.** The pre-H1 component (`0b2ecec`) was run with the H1 test file in a /tmp copy: **5 failed | 35 passed**. The failures were the four new positive tests plus the amended "lists entries newest first…". The two "no Why line" tests pass on both versions, as expected.
- Live: on the multi-entry constant, both `created` entries show "Why: …" in Both, Business and Technical (rows 5 and 6). Every live entry has a reason and none is a bug fix (26/26 and 0), so before H1 the UI would have shown no reasons at all.

## Rule checklist (`genesis-ctx check`)

ADRs:
- OK — ADR-027, ADR-055: existing primitives (`Badge`, `Card`, `SegmentedControl`, `Select`, `EmptyState`, `Tooltip`), tokens only, no new dependency.
- OK — ADR-028: GETs under `/api` (`app.py:155-157`); the client adds the prefix.
- OK — ADR-030: SQLite read model.
- OK — ADR-037: no code stored or returned.
- OK — ADR-063, ADR-065: no collab or Hub path; the local-first read of pulled rows works.
- OK — ADR-070: read-only over the append-only ledger.
- OK — ADR-071: canonical story link with the local id.
- OK — ADR-026: no new bind or auth surface; still loopback.
- OK — ADR-012: the app imports no workflow code.
- OK — ADR-049: tab added inside the Applications page; primary nav unchanged.
- OK — ADR-077: the review used the pack and the checklist.
- N/A — ADR-001, 003, 007, 008, 011, 013, 021, 023, 031, 033, 034, 035, 041, 042, 043, 044, 045, 047, 050, 056, 057, 058, 059, 060, 061, 062, 064, 067, 068, 072, 073, 074, 075, 076. No workflow, graph, chat, stage, lifecycle, Hub-contract, sequence, package or sync code changed. Story ids are read, not allocated.

Lessons:
- OK — L-004 (SQLite).
- OK — L-010, L-011 (types + golden fixtures; contract test via fixtures).
- OK — L-014 (jest-axe setup reused).
- OK — L-015: no heavy lib added; icons go through `shared/ui/icons.ts`.
- OK — L-030: every bundle-touching commit carries `web/static`; the rebuild is identical.
- OK — L-039 (one builder + list==detail test, also live).
- OK — L-069 (no `<Button asChild>`).
- OK — L-083 (real fixture shapes).
- OK — L-084: `julianday` ordering, blank `created_at` fallback, `_truthy`, blank-key never matches. Live m1 passes (see §3).
- OK — L-025, L-027: ruff is pinned; unchanged.
- N/A — L-056, L-057, L-051: release is 48-05; no pin change here.
- N/A — L-003, 012, 017, 018, 019, 031, 034, 041, 042, 043, 045, 048, 055, 058, 061, 062, 063, 064, 068, 071, 072, 073, 074, 075, 076, 082, 085, 086, 087, 088. Untouched areas: SSE, settings, chat trust, secrets, Appian export, graphs, agents, finalizers, the SPA index route, the collab puller, the doc corpus, agent hooks.

## §2 Gates (run by the reviewer on `fdc47ab`)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1187 passed** in 175.67 s, exit 0 |
| `.venv/bin/ruff check genesis` | `All checks passed!` |
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean, exit 0 |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 373 passed (373)` |
| `npm run build` → `git status --short` | `✓ built`; **0** changed or untracked files, so the build is byte-identical to the committed `web/static`. Nothing to restore. |
| Fresh temp DB `migrate(db, MIGRATIONS)` | `applied 24 max 24 current_version 24`; no new migration. The temp DB was deleted. |

These match the dev's claims exactly.

## §3 Live acceptance (http://127.0.0.1:8760, `genesis serve` pid 60492 started 18:27 on HEAD `fdc47ab`; DB backup `/tmp/genesis-review/genesis.db.pre-48-04.bak`)

Ground rules:
- DB reads were read-only (`sqlite3 …?mode=ro` from Python).
- The browser was headless Chromium (Playwright 1.62.1) from `/tmp/genesis-review/pw/`. A route guard aborted every non-GET `/api` request and every `/api/collab/*` call except a stubbed `collab/config` = off, so the SPA's auto-pull could not run. It recorded **0 blocked requests**: the pages issued only GETs.
- No server restart, sync, run, publish or pull was triggered. 0 console errors.

| # | Command / evidence | Result |
|---|---|---|
| 1 | `curl /api/applications/_a-0000e5bc-…_930416/wiki` → HTTP 200, 21 objects (`live-list.json`). `live_compare.py`: 21 DB pages = 21 rows, 0 mismatches on name, in_kb, summary, entry_count, latest kind, author, version, last_changed_at, is_deprecated; sorted by parsed `last_changed_at` desc. `live_detail.py`: all 21 detail calls have object == list row, entries newest first, `is_bugfix` bool, every field == DB, stories == the `kb_stories` join (e.g. entry 18 → story 77 `story-1-4`), no provenance keys. | **PASS** |
| 2 | Orphan-page app `_a-0000abcd-…_00001` → 404 `Application '…' not tracked`. Random uuid → 404. Unknown object → 404 `No wiki page for object 'no-such-object'`. A *tracked* app with no pages can't be tested live (only 1 tracked app, and it has pages); covered by `test_tracked_app_with_no_pages_lists_empty`. | **PASS** (empty-list case by test) |
| m1 | `SELECT created_at, julianday(created_at) FROM wiki_object_entries WHERE published_by IS NOT NULL LIMIT 5` → `2026-09-24T09:09:37.210Z, 2461307.88…` (5 rows, none NULL). All 26 entries: 0 NULL `julianday`. | **PASS** |
| 3 | Tabs `[Business Map, Overview, Object Wiki, Features, …]`; URL `?tab=object-wiki`; headers OBJECT/TYPE/SUMMARY/CHANGES/LAST CHANGE/LAST CHANGED BY; 21 rows; "21 objects" (`row3-tab-light.png`). | **PASS** |
| 4 | Search "TEMPLATE" → 13 rows ("13 of 21 objects"). Type options All/Constant/Expression Rule/Record Type; Constant → 3 rows, all Constant. Change=Deprecated → "No objects match" (live has 0 deprecated, `row4-deprecated-nomatch.png`). Clear filters → 21. All 5 sortable headers toggle `aria-sort`. Object asc order verified. | **PASS** |
| 5 | Click `AS_GSS_REF_ID_DOCUMENT_BUILDER_DRAFT_STATUS_FAILED` → `/applications/<app>/wiki/_a-0000f071-…_28257`. h1, type badge, metadata chips (uuid+copy, "2 changes", first/last), Current summary; 2 entries newest first (story-1-4, then story-1-3); 2 "Why:" lines (`row5-object-light.png`). | **PASS** |
| 6 | Business → 2 business / 0 technical; Technical → 0 / 2 (`row6-technical.png`); Both → 2 / 2; Why lines stay 2. | **PASS** |
| 7 | Story link href `/applications/<app>/stories/77` → canonical story page opens (`row7-story-page.png`); browser Back → the object URL. | **PASS** |
| 8 | Page Back → `/applications/<app>?tab=object-wiki`, tab `aria-selected=true`. Breadcrumb "AS GSS Full Application › Object Wiki" → same URL, tab selected. | **PASS** |
| 9 | `goto` + `reload` on the object URL → page loads; crumbs "AS GSS Full Application Object Wiki" (`row9-deeplink.png`). | **PASS** |
| 10 | Pull a teammate's entry — **not driven**: it needs a collab pull, a mutation excluded by instruction. Indirect: all 26 local entries carry `published_by='admin.user'`, and pulled-shape handling is covered by `test_pulled_page_derives_latest_from_entries`. | **NOT RUN (manual)** |
| 11 | Light and dark (`html.theme-light/dark`) at 1440/1280/1024: no overflow, screenshots `row11-*-1440.png`. At **768–900 px**: object page `main` overflows 217 px / 85 px (unbroken title), and the Last-change cell overflows by up to 30 px into the next column (`row11-object-light-768.png`, `row11-tab-dark-768.png`). Reference pages at 768: overflow 0 (`cmp-*-768.png`). Visual "consistent with Documents/Story" at desktop width still needs the human's eye. | **FAIL** (narrow) → M1 |

## Re-review needed
After M1 (and ideally m1/n1) are fixed:
- a delta review of the fix commit;
- the gates again, including the `web/static` rebuild;
- rerun `/tmp/genesis-review/pw/widths.cjs` (expect `mainOverflow` 0 and `lastChangeCellOverflowPx` ≤ 0 at 768 and 900);
- the human's browser check for row 10 (collab) and the visual half of row 11.

---

# Delta review (c86ed3e) — genesis `fdc47ab` → `c86ed3e` (genesis-review, 2026-10-21)

One commit, `c86ed3e fix(web): 48-04 review — no narrow-window overflow on the Object Wiki, nullable story key/app
name (48-04 M1, n1, n2)`. It touches 5 source files plus the rebuilt `web/static`. No backend change, so the
backend gates from §2 (pytest 1187, ruff clean on `fdc47ab`) still apply.

## Delta verdict: **SHIP**

- **M1 is resolved for its defect.** The object page no longer overflows at 768 or 900 px in either theme; the title
  now wraps onto 2 lines. In the table, "26 days ago" no longer prints over "admin.user".
- n1 and n2 are resolved.
- All gates are green, and the build is byte-identical to the committed bundle.
- One new minor (m2): at 768 px only, the table still overflows slightly — the "Updated" badge by 5 px and a
  header's sort icon by 18 px. No text collides. It does not block; it is a follow-up.
- m1 (the As built section) is still open. As instructed, the dev writes it after this verdict, so it does not block.

## Delta findings

### Resolved
- **M1 — narrow-window overflow.**
  - `ObjectWikiPage.tsx:94-96` now passes `title={<span className="[overflow-wrap:anywhere]">{object.name}</span>}`.
    This works for the reason the dev gave. `Page`'s title `<div>` is a flex item with `min-width:auto`
    (`shared/layout/Page.tsx:19-21`). `anywhere`, unlike `break-word`, lowers the text's min-content size, so the
    flex row can shrink below the length of the unbroken name.
  - `ObjectWikiTable.tsx:91-93`: the Last-change span is now `inline-flex max-w-full flex-wrap items-center gap-x-2 gap-y-1`.
  - Live numbers are below. A residual overflow at 768 px is m2.
- **n1 — nullable story key and app name.**
  - `types/objectWiki.ts:36,59,66`: `key` and `app_name` are now `string | null`.
  - `HistoryTimeline.tsx:39` joins the non-blank values of `[key, title]` with " · ". A null or blank key gives the
    title alone, with no stray separator.
  - `ObjectWikiPage.tsx:60` passes `q.data?.app_name` to `useSetCrumb`, which already accepts
    `string | null | undefined` (`shared/layout/breadcrumbs.ts:35`). A null name leaves that breadcrumb unset rather
    than crashing.
  - The table side reads no `app_name`, per `grep app_name features/object-wiki`.
- **n2 — no deprecated-entry test.** `objectWiki.test.tsx:427-435` now checks that a `deprecated` entry with a reason
  shows the "Deprecated" badge and "Why: Replaced by VM_R_SUPPLIER".
- **Regression tests.** New describe "Narrow windows and nullable fields (review 48-04 M1, n1)",
  `objectWiki.test.tsx:438-471`, with 4 tests: the title's wrap class, the Last-change span's `flex-wrap`, a key-less
  story link (exact text + canonical href), and a null `app_name`.
  - The class assertions only pin the classes, because jsdom does no layout. The live measurement below covers the
    behaviour.
  - **Mutation check reproduced.** I extracted `c86ed3e` `web/` with `git archive` into `/tmp/genesis-review/mut`
    (`node_modules` symlinked). I swapped in the `fdc47ab` versions of `HistoryTimeline.tsx`, `ObjectWikiPage.tsx` and
    `ObjectWikiTable.tsx`, then ran `npx vitest run src/features/object-wiki`. Result: **3 failed | 42 passed (45)**.
  - The 3 failures were the title wrap test, the Last-change `flex-wrap` test and the key-less story test.
  - The null-`app_name` test and the n2 test pass on both versions, as expected: the old code already tolerated both.
    This matches the dev's claim.

### New
- **m2 (minor, non-blocking) — at 768 px the Object Wiki table still overflows a little; no text collides.**
  Measured by `/tmp/genesis-review/pw/table768.cjs` and `widths-delta.cjs`:
  - *Body cell.* The Last-change column is 80 px wide, with a 56 px content box. Its widest item, the "Updated" badge,
    is 73 px and cannot wrap. Its right edge is at 682 px. The next cell starts at 677 px, but that cell's text starts
    at 689 px, so the badge reaches 5 px into the next cell's padding and stops 7 px short of its text.
    `delta-tab-light-768.png` shows no overlap.
  - *Header.* The last column, "Last changed by", is 66 px wide. Its sort button and icon end at 762 px. The table
    wrapper ends at 744 px and has `overflow-x: hidden`, so the sort icon is clipped by about 18 px. This makes the
    `tableOverflow: 19` reading.
  - This header has been the same since 48-03; my first run did not measure headers.
  - Both effects disappear at 900 px and above.
  - Suggested follow-up:
    - Give the Last-change and Last-changed-by columns a `min-w` that fits the "Updated" badge, or let the table
      scroll horizontally below about 800 px.
    - Let the header label wrap with the icon kept beside it.
  - I grade this minor, not major: 768 px is below the usual desktop width, nothing becomes unreadable, and on the
    same app page the tab strip (not from this phase) already overflows by 97 px at 768.
- **Observation (no finding).** With `flex-wrap` and `max-w-full`, the badge and the time now sit on two lines in
  every row (21 of 21) at 1280, 1024, 900 and 768 px. At 1440 they stay on one line. This is the intended "time under
  the badge" behaviour and does not overflow, but the human may want to confirm the look at 1280 during the visual
  check (row 11).

## Delta gates (run by the reviewer on `c86ed3e`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean, exit 0 |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 378 passed (378)` (373 before + 5 new) |
| `npm run build` → `git status --short` | `✓ built in 12.13s`; empty status, so the build is **byte-identical** to the committed `web/static`. The tree is clean on HEAD `c86ed3e`. |
| Backend | No backend change in the delta (`git diff --stat fdc47ab c86ed3e` touches only `web/`); §2's pytest 1187 and ruff clean still apply. |

These match the dev's claims exactly.

## Delta live check (http://127.0.0.1:8760, server not restarted)

Ground rules:
- The server was the same editable install as in §3. It served bundle `assets/index-gcZihyVJ.js`, which is the
  committed `c86ed3e` bundle.
- Headless Chromium (Playwright 1.62.1) used the same read-only route guard as §3. It recorded **0** blocked
  requests and 0 console errors.
- The theme was set with `localStorage genesis.theme` and confirmed through `html.theme-light` / `html.theme-dark`.
- Script: `/tmp/genesis-review/pw/widths-delta.cjs`. It is `widths.cjs` plus both themes, a wait for the real object
  heading, and the cell's content-box width (padding excluded).
- Screenshots: `delta-{object,tab}-{light,dark}-{768,900}.png`.

| Width | Theme | Object page `main` overflow | h1 overflow / lines | Last-change cell overflow (px past the content box) | Table overflow | App page `main` overflow |
|---|---|---|---|---|---|---|
| 1440 | light / dark | 0 / 0 | 0 / 1 line | −15 / −15 | 0 | 0 |
| 1280 | light / dark | 0 / 0 | 0 / 1 line | 0 / 0 (wrapped) | 0 | 0 |
| 1024 | light / dark | 0 / 0 | 0 / 1 line | 0 / 0 (wrapped) | 0 | 0 |
| 900 | light / dark | **0 / 0** (was 85) | 0 / 2 lines | **0 / 0** (was 8) | 0 | 0 |
| 768 | light / dark | **0 / 0** (was 217) | 0 / 2 lines | **17 / 17** (was 30; the badge reaches 5 px into the next cell's padding and does not overprint, m2) | 19 (header sort icon clipped, m2) | 97 (the tab strip, not from this phase, unchanged) |

`delta-object-dark-768.png` shows the title wrapped at the underscore boundary in "…DOCUMENT_BUILDER / _DRAFT_STATUS_FAILED",
with "Back" still at the top right.

### Updated row 11
| # | Result |
|---|---|
| 11 | **PASS (automated half)**. Both themes, no `main` overflow on the object page at 1440/1280/1024/900/768. The Last-change cell has no overflow at 900 px and above. At 768 there is no text overprint, only the cosmetic m2 spill (5 px into the next cell's padding, and the header icon clipped). **The visual half ("consistent with Documents/Story", plus the two-line Last-change look at 1280) is NOT RUN; it needs the human's browser check.** |
| 10 | Unchanged: **NOT RUN (manual)**, needs a collab pull. |

## Remaining before 48-05
- m1: the dev writes the 48-04 As built section (commits `fdc47ab` and `c86ed3e`, the tests, the mutation checks, the gates).
- The human's manual checks for row 10 and the visual half of row 11.
- m2 is optional polish, or can go to the backlog as a follow-up.
- Housekeeping: the mutation-check copy `/tmp/genesis-review/mut/` could not be removed, because the reviewer's
  profile denies `rm -rf`. It is outside every repo and safe to delete by hand.

# Delta review (809ac29) — genesis `c86ed3e` → `809ac29` (genesis-review, 2026-10-21)

The delta is one commit: `809ac29 fix(web): Object Wiki table keeps a minimum width and wraps header labels at narrow
widths (48-04 review m2)`. It changes `ObjectWikiTable.tsx` (+7/−3) and `objectWiki.test.tsx` (+10), plus the
rebuilt `web/static`. Nothing else in `web/src` and no backend file changed (`git diff --stat c86ed3e 809ac29`).

## Delta verdict: **SHIP**

- **m2 is resolved at 768 px.**
  - No body content spills out of its cell.
  - The "Last changed by" sort icon is no longer clipped. The table scrolls inside its card, as intended.
- Gates are green and the build is byte-identical to the committed bundle.
- I reproduced the mutation check.
- One new minor, **m3**: the fix also changes the 900–937 px range, where nothing overflowed before. It does not
  block. There is a one-token fix, below.

## Delta findings

### Resolved
- **m2 — the 768 px table spill and the clipped header icon.**
  - `ObjectWikiTable.tsx:61`: the card is now `overflow-x-auto rounded-2xl …`, where it was `overflow-hidden`.
  - `:62`: the table is `w-full min-w-[640px] table-fixed`.
  - `:31`: the SortHeader button gets `max-w-full … text-left`.
  - Live numbers at 768 px, both themes:
    - The card scrolls: `scrollWidth 640` vs `clientWidth 470`.
    - Body cells: **0** descendants spill past their own cell. The "Updated" badge now fits, because the Last-change
      column is 109 px with an 85 px content box.
    - With the card scrolled to the end (`scrollLeft 170`), the last header icon ends at 731 px and the card at
      744 px, so it is **visible**.
- **Rounded corners and visuals.**
  - `overflow-x:auto` makes `overflow-y` compute to `auto` as well. Any value other than `visible` clips to the
    padding box with the 22 px border radius (`borderTopLeftRadius: 22px`).
  - `delta2-tab-dark-768.png` shows the `bg-surface-2` header clipped into both top corners.
  - There is no vertical scrollbar: `scrollHeight == clientHeight` (1364 at 768, 967 at 1440).
  - Nothing in `features/object-wiki/` is sticky (`grep sticky` finds nothing), so sticky behaviour cannot regress.
- **Regression test.** `objectWiki.test.tsx:456-464`, "the table scrolls in its card below its minimum width; header
  labels can wrap (review 48-04 m2)".
  - It checks classes only (jsdom does no layout). The live measurements above cover the behaviour.
  - **Mutation check reproduced.** I put the `809ac29` `web/src` in `/tmp/genesis-review/mut/g/web`, restored the
    `c86ed3e` `ObjectWikiTable.tsx`, and ran `npx vitest run src/features/object-wiki`. Result: **1 failed | 45
    passed (46)**, and the failure is exactly the m2 test. This matches the dev's claim.

### New
- **m3 (minor, non-blocking) — at 900 to about 937 px the table now scrolls horizontally. Before this fix it did
  not.**
  - The cause: the card's client width is below 640 px until the viewport reaches about 938 px. At 900 px the card is
    602 px wide and the table is 640 px, so 38 px of the "Last changed by" column is hidden at `scrollLeft 0`. The
    header reads "LAST / CHANG / BY" (`delta2-tab-light-900.png`).
  - Before `809ac29`, the same width had no overflow at all (the c86ed3e table above: 900 px, cell overflow 0, table
    overflow 0).
  - The horizontal scrollbar sits at the bottom of the 1364 px-tall card, below the fold. Overlay scrollbars also
    hide it, so the user gets no visible cue that the column is cut off.
  - This is cosmetic. The content is still reachable by scrolling, and 768 px, the case that was asked for, behaves
    as intended.
  - **Suggested fix:** use `min-w-[600px]` (any value from about 580 to 602).
    - Rule: the badge fits when 17 % of the table width, minus 24 px of padding, is at least 73 px. That holds at
      about 571 px or more.
    - At 600 px the Last-change content box is 78 px, so the badge still fits.
    - The 900 px card (602 px) would no longer scroll.
    - The regression test only needs its class string updated.
- **Observation (pre-existing, improved, no finding) — the "Changes" header label is wider than its 9 % column.**
  - At 1024 px and below, the column is 58–65 px wide, with a 34–41 px content box. The single word "CHANGES" cannot
    wrap, so it overruns the column. The sort icon (shown only when sorting by Changes) lands in the next header's
    padding.
  - I compared the `c86ed3e` classes against the new ones by swapping only the changed classes in the live DOM
    (`table-oldnew.cjs`). How far the icon overlaps the "LAST CHANGE" label:

    | Width | c86ed3e | 809ac29 |
    |---|---|---|
    | 1024 | 6 px | 0 px |
    | 900 | 17 px | 1 px |
    | 768 | 29 px | 1 px |

  - Header height is the same in both (44 px at 1440, 84 px at 1024 and below). So the label wrap that `max-w-full`
    allows changed no row height.
  - Optional polish: give the Changes column a `min-w`, or a shorter label.

## Delta gates (run by the reviewer on `809ac29`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean, exit 0 |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 379 passed (379)` (378 + 1 new) |
| `npm run build` → `git status --short` | `✓ built in 12.37s`; empty status, so the build is **byte-identical** to the committed `web/static`. The tree is clean on HEAD `809ac29`. |
| Backend | No change in the delta; §2's pytest 1187 and ruff clean still apply. |

These match the dev's claims exactly.

## Delta live check (http://127.0.0.1:8760, server not restarted)

Ground rules:
- The server served bundle `assets/index-Cpk3DY2c.js`, which is the committed `809ac29` bundle.
- The read-only route guard was the same as in §3, and it recorded **0** blocked requests and 0 console errors.
- Both themes were checked, via `localStorage genesis.theme`.
- Scripts:
  - `/tmp/genesis-review/pw/table768-r2.cjs`: per-cell spill, header icon positions, card scroll/client sizes, and
    the state scrolled to the end.
  - `/tmp/genesis-review/pw/table-oldnew.cjs`: the old/new class comparison, default sort and sort by Changes.
- Screenshots: `delta2-tab-{light,dark}-{768,900}.png`, `delta2-tab-*-scrolled.png`,
  `delta2-thead-sortChanges-{new,old}-{768,1024}.png`.
- The earlier `widths-delta.cjs` / `table768.cjs` measure against the card's right edge. That no longer applies now
  that the card scrolls, so `table768-r2.cjs` replaces them with a per-cell check.

| Width | Theme | Card scrollW / clientW | Body cells spilling past their own cell | Header icon past the card (after scrolling to the end) | App page `main` overflow |
|---|---|---|---|---|---|
| 1440 | light / dark | 1142 / 1142 | 0 | 0 | 0 |
| 1024 | light / dark | 726 / 726 | 0 (only the pre-existing Changes header, above) | 0 | 0 |
| 900 | light / dark | **640 / 602** (scrolls 38 px; m3) | 0 | 0 (visible, 863 vs 876) | 0 |
| 768 | light / dark | **640 / 470** (scrolls 170 px, intended) | **0** (was 17) | **0** (was 18 clipped; now 731 vs 744) | 97 (tab strip, out of scope, unchanged) |

Row 11 (automated half) stays **PASS**. Row 10 and the visual half of row 11 are still **NOT RUN (manual)**.

## Housekeeping
- `/tmp/genesis-review/mut/` was removed with `rm -r` (no `-f`). Its `node_modules` symlink was not followed, and
  `genesis/web/node_modules` is intact (513 entries, `.bin/vitest` present).

## Consolidated status — 48-04 (after `809ac29`)

| Finding | State |
|---|---|
| M1 — narrow-window overflow (object page title, Last-change cell) | **Resolved** (`c86ed3e`) |
| m1 — the 48-04 As built section | Open, for the dev to write after this verdict (not blocking) |
| m2 — 768 px badge spill and clipped header icon | **Resolved** (`809ac29`) |
| m3 — 900–937 px now scrolls 38 px (`min-w-[640px]` is larger than needed) | **New, open, non-blocking**; fix is `min-w-[600px]` |
| n1 — nullable story key and app name | **Resolved** (`c86ed3e`) |
| n2 — no deprecated-entry test | **Resolved** (`c86ed3e`) |
| Row 10 (collab pull) and the visual half of row 11 | **NOT RUN (manual)**; need the human |
| Out of scope | the shared Select aria-label bug; the app-page tab-strip overflow (97 px at 768) |

**48-04: SHIP.** The open items before 48-05 are m1 (the As built section), the human's checks for row 10 and the
visual half of row 11, and, optionally, m3.

---

# Delta review (9e3e2b0) — genesis `809ac29` → **`64b311a`** (genesis-review, 2026-10-21)

**The SHA does not match the brief.** `9e3e2b0` does not exist in the genesis repo. `git rev-parse` fails, and neither
`git log --all` nor `git reflog` contains it. HEAD is `64b311a fix(web): Object Wiki table minimum width 640 -> 600
px so 900 px windows don't scroll (48-04 review m3)`, the only commit after `809ac29` (master is 9 ahead of origin).
This section reviews `64b311a`. The heading keeps the brief's id so it can be found.

The delta, from `git show --stat 64b311a`, is 2 files, +5/−4:
- `ObjectWikiTable.tsx:59-63`: `min-w-[640px]` becomes `min-w-[600px]`, and the comment is rewritten (the 17 % column
  minus 24 px of padding is at least 73 px from about 571 px of table width).
- `objectWiki.test.tsx:460`: the class string becomes `min-w-[600px]`.
- **No `web/static` file is in the commit**, although the message says "rebuilt web/static".

## Delta verdict: **NEEDS_CHANGES**

- **B1 (blocker): the committed `web/static` is stale.** CI's stale-bundle guard will fail. The fix is
  `npm run build` plus a commit of `web/static/`.
- The source change is correct, and once it is built it resolves m3 (numbers below).
- New minor **m4** (non-blocking): at 600 px the active sort arrow on "Last changed by" collapses to 0 px width. It
  could go into the same rebuild commit as one class.

## Delta findings

### Blocker
- **B1 — the committed bundle does not match the source (coding standards §1, the stale-bundle guard; L-056 in
  spirit).**
  - `git grep` on HEAD `web/static` finds `min-w-[640px]` in both `assets/index-Cpk3DY2c.js` and
    `assets/index-BdDxnt9N.css`, and **no** `min-w-[600px]`.
  - A fresh `npm run build` on `64b311a` writes `assets/index-ARFXcC5t.js` and `assets/index-CY3aU6v8.css`, which
    hold `min-w-[600px] table-fixed`. `git status` then shows **56 deleted + 56 untracked assets and a modified
    `index.html`**, 57 files in the diff stat. So the build is **not** byte-identical to the commit.
  - The dev's "tree clean" claim is true, but only because the rebuilt bundle was never committed.
  - The served app at :8760 still serves `index-Cpk3DY2c.js`, the `809ac29` bundle. **Users therefore still get the
    640 px behaviour (m3 not fixed for them)** until the bundle is committed.
  - Fix: run `npm run build` in `genesis/web` and commit `web/static/` (the 57 files). The source needs no change
    for B1.

### Resolved (in source; takes effect once B1 is fixed)
- **m3 — the 900–937 px horizontal scroll.** I measured the fresh build by serving `/tmp/genesis-review/build-64b311a`
  through a Playwright route. `/api` still goes to the live server through the same read-only guard. At 900 px the
  card is **602 / 602** (no scroll), against 640 / 602 for the committed bundle. Body-cell spill is **0**. Table below.

### New
- **m4 (minor, non-blocking) — the sort-direction arrow on "Last changed by" is squeezed to nothing.**
  - Cause: the `ArrowUp` in `SortHeader` (`ObjectWikiTable.tsx:36-43`, `h-3 w-3`, no `shrink-0`) is a flex child of
    the `max-w-full inline-flex` button, so it gives up its width before the label wraps further.
  - Measured with the column sorted (`hdr-probe3-r3.cjs`, click on the header, client-side only, 0 blocked
    requests). Arrow `svg` width when "Last changed by" is the active sort:

    | Viewport | `809ac29` bundle (640) | `64b311a` fresh build (600) |
    |---|---|---|
    | 1440 | 12.0 px | 12.0 px |
    | 1024 | 7.6 px | 7.6 px |
    | 900 | 5.2 px | **0.0 px** |
    | 768 | 5.2 px | **0.0 px** |

  - The `svg` is `overflow:hidden`, so at 0 px the arrow is **invisible**: the active column and its direction have
    no visual cue. `aria-sort` on the `<th>` is still correct, so assistive technology is unaffected.
  - The "Changes" header has the same 0 px arrow in both bundles. That is the pre-existing observation in the
    `809ac29` delta, now explained by the same missing `shrink-0`.
  - This is partly pre-existing, since 1024 px was already 7.6 px. But 600 removes the last few pixels.
  - Suggested fix: add `shrink-0` to the `ArrowUp` className. The label then wraps one more word, which "Last changed
    by" can do.
- **Correction to my `809ac29` delta.** There I reported that the last header icon was "visible" when scrolled to the
  end (731 vs 744 px at 768). That metric checked only the arrow's right edge against the card, not its width. The
  icon was inside the card, but only 5.2 of its 12 px were shown, and it is `opacity-0` unless that column is sorted.
  `table768-r3.cjs` reports `lastIconVisible: true` for the same reason. The real visibility is the m4 table above.
- **Spill counts in the per-cell script.** All non-zero counts are `<th>` `path` boxes of arrows that are shrunk or
  `opacity-0`, not visible overflow:
  - "Changes": +25 / +33 / +36 px.
  - "Last changed by": +7 px, fresh build only, at 900 and 768.
  - **Body-cell (`<td>`) spill is 0** at every width, in both bundles and both themes.

## Delta checklist (`genesis-ctx check --since 809ac29`; areas release-ci, security)

| Line | Answer | Evidence |
|---|---|---|
| ADR-011 reliability trio | N/A | No workflow or agent node touched. |
| ADR-026 local, no auth | N/A | No server or bind change. |
| ADR-027 web stack and tokens | OK | Only a Tailwind arbitrary-width utility changed; no raw palette colour (`ObjectWikiTable.tsx:63`). |
| ADR-055 design language | OK | Same primitives and tokens; no MUI. |
| ADR-063 / 065 / 074 collaboration and KB sync | N/A | No collaboration or sync code touched. |
| ADR-077 agent context | OK | Review used `genesis-ctx check`; no bulk docs read. |
| L-017 chat trust | N/A | No chat code. |
| L-025 / L-027 ruff pin | N/A | No Python or CI configuration. |
| L-030 frontend job and stale-bundle guard | **VIOLATION (B1)** | `web/**` changed but `web/static` was not rebuilt and committed; the guard will red the frontend job. |
| L-045 CLI surface | N/A | — |
| L-051 shipping | N/A | No release in this delta. |
| L-056 commit contains every changed file | **VIOLATION (B1)** | Commit message says "rebuilt web/static", but the commit has 2 files and no bundle. |
| L-057 transitive pins | N/A | No tag or pin. |
| L-087 doc corpus migration | N/A | — |
| L-088 shell guard | N/A | — |

## Delta gates (run by the reviewer on `64b311a`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 379 passed (379)` |
| `npm run build` → `git status` | `✓ built in 13.44s`. **Not byte-identical**: 57 files differ (B1). I restored the tree with `git stash push --include-untracked -- web/static` then `git stash drop`, because `git clean` is denied. `git status --short` is now empty on HEAD `64b311a`. |
| Fresh build for the live check | `npx vite build --outDir /tmp/genesis-review/build-64b311a` (outside the repo; tree untouched) |
| Backend | No change in the delta; §2's pytest and ruff results still apply. |

Lint, typecheck and vitest match the dev's claims. "Build OK" is true, but the build output was not committed.

## Delta live check (http://127.0.0.1:8760, server not restarted)

Setup:
- Read-only guard as in §3: 0 blocked requests, 0 console errors in every run.
- Both themes.
- Scripts:
  - `table768-r3.cjs`: a copy of `-r2` with `delta3-<tag>-` screenshot names, and `FRESH=1` to serve the
    `/tmp/genesis-review/build-64b311a` SPA.
  - `hdr-probe{,2,3}-r3.cjs`: header geometry and the sorted state.
- Logs: `r3-live.log`, `r3-fresh.log`.
- Screenshots: `delta3-{live,fresh}-tab-{light,dark}-{768,900}[-scrolled].png` and
  `delta3-thead-sortBy-{live,fresh}-{1440,1024,900,768}.png`.

Results are identical in light and dark:

| Width | Bundle | Card scrollW / clientW | `<td>` spill | Scrolled to end: last arrow right / card right | `main` overflow |
|---|---|---|---|---|---|
| 1440 | live (`809ac29`) / fresh (`64b311a`) | 1142 / 1142, both | 0 / 0 | no scroll | 0 |
| 1024 | live / fresh | 726 / 726, both | 0 / 0 | no scroll | 0 |
| 900 | live | 640 / 602 (scrolls 38; m3 still live) | 0 | 863 / 876 | 0 |
| 900 | **fresh** | **602 / 602 (no scroll)** | **0** | no scroll | 0 |
| 768 | live | 640 / 470 (scrolls 170) | 0 | 731 / 744 | 97 (tab strip, out of scope) |
| 768 | **fresh** | **600 / 470 (scrolls 130, inside the card)** | **0** | 731 / 744 (inside the card, but 0 px wide when sorted: m4) | 97 (unchanged) |

Against the brief's expectations:
- 900 px, no card scroll and 0 body spill: **met by the source / fresh build; not yet live** (B1).
- 768 px, scrolls inside the card with 0 spill: **met**.
- 768 px, last header icon visible: **partly met**. It is inside the card, but when sorted it is 0 px wide (m4).
- 1024 px and wider unchanged: **met**. Every number matches the `809ac29` table.

## Consolidated status — 48-04 (after `64b311a`)

| Finding | State |
|---|---|
| M1 — narrow-window overflow (object page title, Last-change cell) | **Resolved** (`c86ed3e`) |
| m1 — the 48-04 As built section | Open, for the dev to write after the final verdict (not blocking) |
| m2 — 768 px badge spill and clipped header icon | **Resolved** (`809ac29`); arrow width caveat under m4 |
| m3 — 900–937 px scrolls 38 px | **Resolved in source** (`64b311a`); **not live** until B1 is fixed |
| **B1 — committed `web/static` is stale (still 640 px); the stale-bundle guard will fail** | **New, open, BLOCKING**; rebuild and commit `web/static/` |
| **m4 — the active sort arrow shrinks to 0 px ("Last changed by" at 600 px, "Changes" pre-existing)** | **New, open, non-blocking**; add `shrink-0` to `ArrowUp` |
| n1 — nullable story key and app name | **Resolved** (`c86ed3e`) |
| n2 — no deprecated-entry test | **Resolved** (`c86ed3e`) |
| Row 10 (collab pull) and the visual half of row 11 | **NOT RUN (manual)**; need the human |
| Out of scope | the shared Select aria-label bug; the app-page tab-strip overflow (97 px at 768) |
| Brief / repo mismatch | The brief's `9e3e2b0` does not exist; the reviewed commit is `64b311a` |

**48-04: NEEDS_CHANGES**, for B1 only. A one-commit fix (rebuild and commit `web/static/`, optionally with
`shrink-0` for m4) gets a SHIP. To re-check it, confirm `git grep 'min-w-\[600px\]' -- web/static` finds a match and
that `npm run build` leaves `git status` empty.

---

## Delta review (9d926fd)

Delta: genesis `64b311a` → `9d926fd`, one commit (`git log --oneline -3`: `9d926fd`, `64b311a`, `809ac29`). It has 64
files: the rebuilt `web/static` (`index-B0RSUas7.js`, `index-WX2jv4qd.css`), and `ObjectWikiTable.tsx:39-41`, which
adds `shrink-0` to the `SortHeader` `ArrowUp` (m4). It also extends the m2 test (`objectWiki.test.tsx:464-465`), which
now asserts the header `svg` has `shrink-0`.

## Delta verdict: **NEEDS_CHANGES**

- **B1 is resolved.** The committed bundle matches the source, and the live server serves it.
- **m4 is resolved as asked.** The active arrow is 12 px wide at every width on both headers.
- **New major M2.** Now that the arrow keeps its 12 px, the active "Changes" arrow lands on top of the "LAST CHANGE"
  header label at 1024, 900 and 768 px. This is the same overprint defect as M1, now in the header. Before this
  commit the arrow was invisible here (0 px wide), so the overlap is new in `9d926fd`.

## Delta findings

### Resolved
- **B1 — stale `web/static`.**
  - `git grep 'min-w-\[600px\]' -- web/static` matches `assets/index-WX2jv4qd.css`.
  - `min-w-[640px]` matches nothing.
  - `index-B0RSUas7.js` contains both `min-w-[600px]` and `h-3 w-3 shrink-0 transition-transform` (one match each).
  - `index.html` references `index-B0RSUas7.js` and `index-WX2jv4qd.css`.
  - A fresh `npm run build` (`✓ built in 12.31s`) leaves `git status --short` **empty**, so the build is
    byte-identical. The tree is clean on HEAD `9d926fd`.
  - The live server (`curl http://127.0.0.1:8760/`) serves `index-B0RSUas7.js` / `index-WX2jv4qd.css`, and the
    browser loaded `http://127.0.0.1:8760/assets/index-B0RSUas7.js`.
- **m3 — scroll in 900 px windows.** Fixed in the live app: at 900 px the card is 602 / 602 (table below).
- **m4 — active arrow shrinks to 0 px.** Measured by `hdr-probe4-r4.cjs` with the column sorted. The arrow `svg` is
  12.0 × 12.0, `opacity 1`, has `shrink-0`, and `aria-sort` is correct. This holds for both "Last changed by" and
  "Changes", at 1440/1024/900/768, in light and dark.

### New
- **M2 (major) — the active "Changes" arrow overprints the "LAST CHANGE" header label at ≤ 1024 px.**
  - Evidence:
    - `delta4-thead-dark-1024-changes.png`: the `↓` sits on the "L" of "LAST CHANGE".
    - `delta4-thead-light-900-changes.png`: the `↓` sits between "LAST" and "CHANGE", touching both.
    - `hdr-probe4-r4.cjs` reports `inTh: false` for "Changes" at 1024/900/768, both themes, and `inTh: true` at 1440.
    - `table768-r3.cjs` (live) reports the `<th>` spill as `svg`/`path` boxes going **+18 / +15 px past the cell at
      1024** and **+29 / +27 px at 900 and 768**. Both themes are the same.
  - Cause: the "Changes" column is `w-[9%]` (`ObjectWikiTable.tsx:64`). That is 65 px at 1024 and 54 px at the
    600 px table minimum. After the 24 px padding, 30–41 px are left for the content. The single-word label
    "CHANGES" (11 px, uppercase, tracking-wide) cannot wrap. With `shrink-0` the 12 px arrow (plus the 4 px gap) is
    therefore pushed out of the `max-w-full` button, past the cell and into the next column's label.
  - Before `9d926fd` the arrow had shrunk to 0 px and was hidden by `overflow:hidden`. That made the arrow invisible
    (m4) but avoided the overlap.
  - Even unsorted, the label nearly touches "LAST" at 900 px (`delta4-thead-light-900-changes.png`). The column is
    simply too narrow for its header below ~1100 px.
  - Scope: visible only while the table is sorted by Changes. Assistive technology is unaffected (`aria-sort` is
    correct; the `svg` is `aria-hidden`). It is still a visible overprint, the same class as M1, and it appears in
    a commit meant to fix header-icon rendering. I therefore rate it **major, not a nit**.
  - Suggested fix (dev's choice):
    - Give "Changes" a fixed width that fits label + gap + arrow + padding, about **100 px** (e.g. `w-[100px]` in
      place of `w-[9%]`). The auto-width Summary column absorbs the difference.
    - Then re-check that the `min-w-[600px]` arithmetic in the comment at `ObjectWikiTable.tsx:58-60` still holds
      for Last change (17%).
    - Alternatively, shorten the visible label and keep the full name as the accessible name.
  - Regression test: jsdom has no layout. A class assertion on the "Changes" `<th>` (the new width) next to the m2
    test is the practical guard. The live probe verifies the geometry.

## Delta checklist (`genesis-ctx check --since 64b311a`; areas release-ci, security)

| Line | Answer | Evidence |
|---|---|---|
| ADR-011 reliability trio | N/A | No workflow or agent node touched. |
| ADR-026 local, no auth | N/A | No server or bind change. |
| ADR-027 web stack and tokens | OK | Only the Tailwind utility `shrink-0` was added (`ObjectWikiTable.tsx:41`); no raw colour. |
| ADR-055 design language | OK | Same primitives and tokens. |
| ADR-063 / 065 / 074 collaboration and KB sync | N/A | No collaboration or sync code. Live guard: 0 blocked requests. |
| ADR-077 agent context | OK | `genesis-ctx check` used; no bulk docs read. |
| L-017 chat trust | N/A | No chat code. |
| L-025 / L-027 ruff pin | N/A | No Python or CI configuration. |
| L-030 frontend job and stale-bundle guard | OK | `web/**` changed and `web/static` is rebuilt and byte-identical (fresh build leaves `git status` empty). |
| L-045 CLI surface | N/A | — |
| L-051 shipping | N/A | No release. |
| L-056 commit contains every changed file | OK | Source, test and all 64 rebuilt bundle files are in `9d926fd`. Nothing left unstaged. |
| L-057 transitive pins | N/A | No tag or pin. |
| L-087 doc corpus migration | N/A | — |
| L-088 shell guard | N/A | — |

## Delta gates (run by the reviewer on `9d926fd`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 379 passed (379)` |
| `npm run build` → `git status --short` | `✓ built in 12.31s`; status **empty** (byte-identical; tree left clean) |
| Backend | No change in the delta; §2 still applies. |

All gates match the dev's claims.

## Delta live check (http://127.0.0.1:8760, server not restarted, live bundle `index-B0RSUas7.js`)

Setup:
- Read-only guard as in §3: **0 blocked requests, 0 console errors** in both scripts.
- Both themes.
- Scripts (in `/tmp/genesis-review/pw/`):
  - `table768-r3.cjs`: run without `FRESH`, with `TAG=r4live`. Log `r4-live.log`. Screenshots
    `delta3-r4live-tab-{light,dark}-{768,900}[-scrolled].png`.
  - `hdr-probe4-r4.cjs` (new): `hdr-probe3-r3.cjs` changed to use the live bundle only, run in both themes, and sort
    "Last changed by" and "Changes" in turn. Log `r4-hdr.log`. Screenshots
    `delta4-thead-{light,dark}-{1440,1024,900,768}-{by,changes}.png`.

Light and dark gave the same numbers:

| Width | Card scrollW / clientW | `<td>` spill | `<th>` spill (Changes arrow svg/path) | Scrolled to end: last arrow right / card right | `main` overflow | Active arrow width (Last changed by / Changes) |
|---|---|---|---|---|---|---|
| 1440 | 1142 / 1142 | 0 | 0 | no scroll | 0 | 12.0 / 12.0, both inside their `<th>` |
| 1024 | 726 / 726 | 0 | +18 / +15 px | no scroll | 0 | 12.0 / 12.0; **Changes outside its `<th>` (M2)** |
| 900 | **602 / 602 (no scroll)** | **0** | +29 / +27 px | no scroll | 0 | 12.0 / 12.0; **Changes outside its `<th>` (M2)** |
| 768 | **600 / 470 (scrolls 130, inside the card)** | **0** | +29 / +27 px | 743 / 744 | 97 (tab strip, out of scope) | 12.0 / 12.0; **Changes outside its `<th>` (M2)** |

Against the brief's expectations:
- The live server serves `index-B0RSUas7.js`: **met**.
- 900 px with no card scroll and 0 `<td>` spill: **met**.
- 768 px scrolls inside the card with 0 spill: **met**.
- Active sort arrow 12 px at every width for both headers: **met**. For "Changes" at ≤ 1024 px, though, the 12 px
  arrow sits outside its cell and over the next header label (M2).

## Consolidated status — 48-04 (after `9d926fd`)

| Finding | State |
|---|---|
| M1 — narrow-window overflow (object page title, Last-change cell) | **Resolved** (`c86ed3e`) |
| **M2 — the active "Changes" sort arrow overprints the "LAST CHANGE" header at ≤ 1024 px** | **New, open, BLOCKING**; widen "Changes" to fit label + arrow (about 100 px) |
| m1 — the 48-04 As built section | Open, for the dev to write after the final verdict (not blocking) |
| m2 — 768 px badge spill and clipped header icon | **Resolved** (`809ac29`) |
| m3 — 900–937 px scrolls 38 px | **Resolved** (live since `9d926fd`: 602 / 602 at 900) |
| m4 — active sort arrow shrinks to 0 px | **Resolved** (`9d926fd`: 12 px everywhere); its side effect is M2 |
| B1 — committed `web/static` was stale | **Resolved** (`9d926fd`; byte-identical, served live) |
| n1 — nullable story key and app name | **Resolved** (`c86ed3e`) |
| n2 — no deprecated-entry test | **Resolved** (`c86ed3e`) |
| Row 10 (collab pull) and the visual half of row 11 | **NOT RUN (manual)**; need the human |
| Out of scope | the shared Select aria-label bug; the app-page tab-strip overflow (97 px at 768) |

**48-04: NEEDS_CHANGES**, for M2 only. A one-commit fix (a wider "Changes" column, a class-level test, then
`npm run build` and the commit of `web/static/` **run in sequence**) gets a SHIP. To re-check it:
- run `hdr-probe4-r4.cjs` and expect `inTh: true` for "Changes" at every width;
- run `table768-r3.cjs` and expect 0 `<th>` spill from the Changes arrow, 0 `<td>` spill and 900 px still unscrolled;
- confirm the build is byte-identical again.

---

## Delta review (4d2ea41)

Delta: genesis `9d926fd` → `4d2ea41`, one commit (`git log --oneline -3`: `4d2ea41`, `9d926fd`, `64b311a`). It
touches 64 files (`git show --stat`: 90+/78−):
- `ObjectWikiTable.tsx:61-75`. Column widths: Object `w-[24%]` → `w-[20%]`, Type `w-[13%]` → `w-[12%]`, Summary
  stays auto, Changes `w-[9%]` → `w-[100px]`, Last change `w-[17%]` → `w-[104px]`, Last changed by `w-[14%]` →
  `w-[104px]`. `min-w-[600px] table-fixed` is unchanged. The comment now gives the measured needs.
- `objectWiki.test.tsx:468-476`: a new test, "the metric columns have fixed widths that fit their header + sort
  arrow and the widest badge (review 48-04 M2)". It asserts the three `<th>` width classes, and it fails on
  `9d926fd`, where Changes is `w-[9%]`.
- The rebuilt `web/static`: `index-BBFKmVpb.js`, `index-CkcLcR1A.css`, `index.html` and the re-hashed lazy chunks.

## Delta verdict: **SHIP**

- **M2 is resolved.** With each column sorted in turn, every active arrow is 12 px wide and sits inside its own
  content box. Overprint onto the next header label is 0 px at 1440, 1280, 1024, 900 and 768, in both themes.
- **New minor m5 (not blocking).** On wide windows the header row is now 84 px tall instead of 44 px, because
  "LAST CHANGED BY" wraps onto three lines and "LAST CHANGE" onto two. Details below. You asked whether the stacked
  Last-change cell is a finding: I count it as part of m5, also minor.

## Delta findings

### Resolved
- **M2 — the active "Changes" arrow overprints "LAST CHANGE" at ≤ 1024 px.**
  - `hdr-probe5-r5.cjs` checks five sortable columns × five widths × two themes, 50 cases in all. In every case:
    `svgW 12`, `opacity 1`, `inContent: true`, `inTh: true`, `overprintPx: 0`, and `aria-sort` is correct
    (Changes `descending`, the others `ascending`).
  - The screenshot `delta5-thead-dark-900-changes.png` shows "CHANGES ↓" clear of "LAST CHANGE". This was the worst
    case in `9d926fd`.
  - `table768-r3.cjs` (live) gives `<th>` and `<td>` spill **0** (it was +29 / +27 px at 900 and 768) and
    `iconsOutsideTh []` at every width.
  - The dev's `cols.cjs`, re-run by me, shows that header min-content fits the content box at every width:
    Changes 72 ≤ 76, Last change 65 ≤ 80, Last changed by 73 ≤ 80, Type 43 ≤ 48 at the 600 px minimum. `tdSpill`
    is 0 everywhere.

### New
- **m5 (minor) — fixed 104 px metric columns make the header and the Last-change cells wrap at wide widths too.**
  - In `9d926fd`, at 1440 px, the header row was **44 px** tall ("Last changed by" `<th>` 160 px wide, `thH 44` in
    `r4-hdr.log`). In `4d2ea41` it is **84 px** at every width (`hdr-probe5-r5.cjs`, `table768-r3.cjs`): "LAST
    CHANGED BY" is three lines and "LAST CHANGE" two (`delta5-thead-light-1440-lastchange.png`).
  - At the same time Summary has 469 px at 1440, so the wrapping is not caused by a lack of room.
  - As you note, the Last-change badge and its relative time now stack on two lines at every width (before, only at
    ≤ 1280). Every row is therefore taller on the most common desktop widths.
  - Nothing is clipped, nothing overlaps, and the a11y is unchanged. This is density and polish, not a defect, so it
    does not block.
  - Suggested follow-up (dev's choice): keep the px widths as the floor and widen at large viewports, for example
    `w-[100px] xl:w-[112px]` for Changes and `w-[104px] xl:w-[168px]` for the two "Last …" columns. At 1440 that
    restores single-line headers (the 160 px column fitted "LAST CHANGED BY" in `9d926fd`) and keeps Summary at
    about 340 px or more. Extend the class test to match.
  - This can wait for 48-05 or later; a separate commit is fine.

## Delta checklist (`genesis-ctx check --since 9d926fd`; areas release-ci, security)

| Line | Answer | Evidence |
|---|---|---|
| ADR-011 reliability trio | N/A | No workflow or agent node touched. |
| ADR-026 local, no auth | N/A | No server or bind change. |
| ADR-027 web stack and tokens | OK | Only Tailwind width utilities changed (`ObjectWikiTable.tsx:70-75`); no raw colour, no new dependency. |
| ADR-055 design language | OK | Same primitives and tokens. |
| ADR-063 / 065 / 074 collaboration and KB sync | N/A | No collaboration or sync code. Live guard: 0 blocked requests. |
| ADR-077 agent context | OK | `genesis-ctx check` used; no bulk docs read. |
| L-017 chat trust | N/A | No chat code. |
| L-025 / L-027 ruff pin | N/A | No Python or CI configuration. |
| L-030 frontend job and stale-bundle guard | OK | `web/**` changed; `web/static` is rebuilt and byte-identical (a fresh build leaves `git status` empty). |
| L-045 CLI surface | N/A | — |
| L-051 shipping | N/A | No release. |
| L-056 commit contains every changed file | OK | The source, the test and all 64 bundle files are in `4d2ea41`. `git status --short` is empty. |
| L-057 transitive pins | N/A | No tag or pin. |
| L-087 doc corpus migration | N/A | — |
| L-088 shell guard | N/A | — |

## Delta gates (run by the reviewer on `4d2ea41`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 380 passed (380)` (+1, the new M2 test) |
| `npm run build` → `git status --short` | `✓ built in 12.23s`, emits `index-BBFKmVpb.js`; status **empty** (byte-identical; tree left clean) |
| Backend | No change in the delta. |

All gates match the dev's claims.

## Delta live check (http://127.0.0.1:8760, server not restarted, live bundle `index-BBFKmVpb.js`)

Setup:
- `curl http://127.0.0.1:8760/` and the browser both serve and load `index-BBFKmVpb.js`.
- Same read-only guard: **0 blocked requests, 0 console errors** in all three scripts.
- Scripts:
  - `/tmp/genesis-review/pw/hdr-probe5-r5.cjs` (new): `hdr-probe4-r4.cjs` extended to all five sortable columns,
    to 1280 px, and to a direct overprint measure (the active arrow's right edge against the next header label's
    left edge). Screenshots: `delta5-thead-{light,dark}-{1440,1280,1024,900,768}-{changes,lastchange}.png`.
  - `/tmp/genesis-review/pw/table768-r3.cjs`, live, `TAG=r5live`. Log: `r5-live.log`.
  - `/tmp/genesis-review/dev/cols.cjs` (the dev's). Log: `/tmp/genesis-review/pw/r5-cols.log`.

Light and dark gave the same numbers:

| Width | Card scrollW / clientW | `<td>` / `<th>` spill | Active arrow (all 5 cols) | Overprint | Header row height | Th widths Obj/Type/Summ/Chg/Last/By | Scrolled to end: last arrow / card right |
|---|---|---|---|---|---|---|---|
| 1440 | 1142 / 1142 | 0 / 0 | 12 px, inside | 0 | 84 (was 44; m5) | 228/137/469/100/104/104 | no scroll |
| 1280 | 982 / 982 | 0 / 0 | 12 px, inside | 0 | 84 | 196/118/360/100/104/104 | no scroll |
| 1024 | 726 / 726 | 0 / 0 | 12 px, inside | 0 | 84 | 145/87/186/100/104/104 | no scroll |
| 900 | **602 / 602 (no scroll)** | 0 / 0 | 12 px, inside | 0 | 84 | 120/72/101/100/104/104 | no scroll |
| 768 | 600 / 470 (scrolls 130 inside the card) | 0 / 0 | 12 px, inside | 0 | 84 | 120/72/100/100/104/104 | 731 / 744, visible |

`main` overflow is 0 at ≥ 900 and 97 at 768. That 97 px is the app-page tab strip, out of scope and unchanged.

The re-check criteria from the `9d926fd` verdict are all **met**:
- "Changes" is `inTh: true` at every width.
- The Changes arrow causes 0 `<th>` spill.
- `<td>` spill is 0.
- 900 px still does not scroll.
- The build is byte-identical.

## Consolidated status — 48-04 (after `4d2ea41`)

| Finding | State |
|---|---|
| M1 — narrow-window overflow (object page title, Last-change cell) | **Resolved** (`c86ed3e`) |
| M2 — the active "Changes" sort arrow overprints the "LAST CHANGE" header at ≤ 1024 px | **Resolved** (`4d2ea41`; 0 px overprint, 50/50 cases) |
| m1 — the 48-04 As built section | Open, for the dev to write now that the verdict is in (not blocking) |
| m2 — 768 px badge spill and clipped header icon | **Resolved** (`809ac29`) |
| m3 — 900–937 px scrolls 38 px | **Resolved** (`9d926fd`; 602 / 602 at 900, still true) |
| m4 — active sort arrow shrinks to 0 px | **Resolved** (`9d926fd`) |
| **m5 — fixed 104 px metric columns wrap the headers (84 px row) and the Last-change cells at wide widths** | **New, open, not blocking**; responsive `xl:` widths suggested as a follow-up |
| B1 — committed `web/static` was stale | **Resolved** (`9d926fd`; byte-identical again at `4d2ea41`) |
| n1 — nullable story key and app name | **Resolved** (`c86ed3e`) |
| n2 — no deprecated-entry test | **Resolved** (`c86ed3e`) |
| Row 10 (collab pull) and the visual half of row 11 | **NOT RUN (manual)**; need the human |
| Out of scope | the shared Select aria-label bug; the app-page tab-strip overflow (97 px at 768) |

**48-04: SHIP.** No blocker or major remains open. Open items:
- m1, the As built section, which is the dev's next step;
- m5, a minor polish follow-up;
- rows 10 and 11 (visual half), which are manual checks for the human.

---

## Delta review (777e619)

Delta: genesis `4d2ea41` → `777e619`, one commit (`git log --oneline -3`: `777e619`, `4d2ea41`, `9d926fd`). It
touches 64 files (`git diff --stat`: 77+/76−):
- `ObjectWikiTable.tsx:75-76`: Last change `w-[104px]` → `w-[104px] xl:w-[184px]`; Last changed by `w-[104px]` →
  `w-[104px] xl:w-[168px]`. Changes stays `w-[100px]`, Object `w-[20%]`, Type `w-[12%]`, `min-w-[600px]
  table-fixed`. The comment at `:61-66` now cites m5 and the xl widening.
- `objectWiki.test.tsx:474-475`: the M2 class test now asserts both the floor and the `xl:` class for each column.
- The rebuilt `web/static`: `index-zh0sG0zM.js`, `index-DZrm-hwc.css`, `index.html` and the re-hashed lazy chunks.

No browser or Playwright run this time: the human declined another probe run. The visual checks are the human's
(see below).

## Delta verdict: **SHIP**

- **m5 is resolved.** The fix is the one suggested in the `4d2ea41` review, minus the optional Changes widening.
  That widening is not needed: "Changes" already fits on one line (72 px header min-content in a 76 px content box,
  `cols.cjs` at `4d2ea41`).
- No new findings.

## Delta findings

### Resolved
- **m5 (minor): fixed 104 px metric columns wrapped the headers (84 px row) and the Last-change cells at wide
  widths.**
  - Static evidence. The built CSS has `@media (min-width: 1280px){.xl\:w-\[168px\]{width:168px}.xl\:w-\[184px\]{width:184px}}`.
    `xl` is the default 1280 px breakpoint, so below 1280 px the widths are byte-for-byte those of `4d2ea41`. I
    measured that state clean at 1024, 900 and 768 (0 overprint, 0 spill, 900 px does not scroll).
  - Width arithmetic under `table-fixed`, using the card widths measured live at `4d2ea41`:

    | Viewport | Card | Object 20% | Type 12% | Fixed (100 + 184 + 168) | Summary |
    |---|---|---|---|---|---|
    | 1280 (xl starts) | 982 | 196.4 | 117.8 | 452 | **≈ 216 px** (was 360) |
    | 1440 | 1142 | 228.4 | 137.0 | 452 | **≈ 325 px** (was 469) |
    | 1279 (below xl) | ≈ 981 | unchanged from `4d2ea41` | | 308 | ≈ 359 px |

    Summary keeps at least about 216 px wherever the widening applies. That is more than twice the ≈ 100 px floor
    at the 600 px minimum, so Summary is never squeezed.
    - At 1279 → 1280 px Summary drops by about 144 px in one step. This is expected for a breakpoint and not a
      finding.
  - Header fit: the "Last changed by" content box is now 168 − 24 = 144 px. In `9d926fd` a 160 px `<th>`
    (136 px content box) held "LAST CHANGED BY" on one line (`thH 44`, `r4-hdr.log`), so 144 px fits too. "LAST
    CHANGE" is shorter and gets 160 px.
  - Last-change cell: 160 px of content holds the widest badge ("Updated", 73 px) plus the gap and the relative
    time. This is confirmed visually by the human (below), not measured by me.
  - The regression test asserts both classes for both columns. Before this delta, the `xl:` assertion fails.

### New
- None.

## Delta checklist (`genesis-ctx check --since 4d2ea41`; areas release-ci, security)

| Line | Answer | Evidence |
|---|---|---|
| ADR-011 reliability trio | N/A | No workflow or agent node touched. |
| ADR-026 local, no auth | N/A | No server or bind change. |
| ADR-027 web stack and tokens | OK | Only Tailwind responsive width utilities changed (`ObjectWikiTable.tsx:75-76`); no raw colour, no new dependency. |
| ADR-055 design language | OK | Same primitives and tokens. |
| ADR-063 / 065 / 074 collaboration and KB sync | N/A | No collaboration or sync code. The human's row-10 collaboration check is recorded below. |
| ADR-077 agent context | OK | `genesis-ctx check` used; no bulk docs read. |
| L-017 chat trust | N/A | No chat code. |
| L-025 / L-027 ruff pin | N/A | No Python or CI configuration. |
| L-030 frontend job and stale-bundle guard | OK | `web/**` changed; `web/static` is rebuilt and byte-identical (a fresh build leaves `git status` empty). |
| L-045 CLI surface | N/A | — |
| L-051 shipping | N/A | No release. |
| L-056 commit contains every changed file | OK | The source, the test and all 64 bundle files are in `777e619`. `git status --short` is empty (0 lines). |
| L-057 transitive pins | N/A | No tag or pin. |
| L-087 doc corpus migration | N/A | — |
| L-088 shell guard | N/A | — |

## Delta gates (run by the reviewer on `777e619`, in `genesis/web`)

| Gate | Result |
|---|---|
| `npm run lint` | `✖ 20 problems (0 errors, 20 warnings)`, exit 0 |
| `npm run typecheck` | `tsc --noEmit` clean |
| `npx vitest run` | `Test Files 46 passed (46)`, `Tests 380 passed (380)` |
| `npm run build` → `git status --short` | `✓ built in 14.15s`, emits `index-zh0sG0zM.js` and `index-DZrm-hwc.css`; status **empty** (byte-identical; tree left clean) |
| Served bundle | `curl http://127.0.0.1:8760/` → `index-zh0sG0zM.js`, `index-DZrm-hwc.css`, the same as the committed `static/index.html` |
| Backend | No change in the delta. |

All gates match the dev's claims.

## Human verification (manual, 2026-10-21)

The human ran the manual browser checks for rows 3–11 on this exact bundle. This includes row 10 (collaboration
pull) and the visual half of row 11, which the reviewer cannot drive. The live :8760 server was serving
`index-zh0sG0zM.js` at the time: the dev confirmed it with curl, and I re-confirmed it above. The human reported:
**"All checks pass"**. I record this as human-verified; the reviewer took no screenshots or measurements of it.

## FINAL consolidated status — 48-04 (after `777e619`)

| Item | State |
|---|---|
| Rows 3–11 of the acceptance table (incl. row 10 collaboration pull and row 11 visual half) | **PASS (human, 2026-10-21)**: "All checks pass", on bundle `index-zh0sG0zM.js` |
| B1 — committed `web/static` was stale | **Resolved** (`9d926fd`; byte-identical again at `777e619`) |
| M1 — narrow-window overflow (object page title, Last-change cell) | **Resolved** (`c86ed3e`) |
| M2 — the active "Changes" sort arrow overprints "LAST CHANGE" at ≤ 1024 px | **Resolved** (`4d2ea41`; unchanged below xl in `777e619`) |
| m1 — the 48-04 As built section | **In progress**: the dev is writing it now (not blocking) |
| m2 — 768 px badge spill and clipped header icon | **Resolved** (`809ac29`) |
| m3 — 900–937 px scrolls 38 px | **Resolved** (`9d926fd`) |
| m4 — active sort arrow shrinks to 0 px | **Resolved** (`9d926fd`) |
| m5 — fixed 104 px metric columns wrap headers and Last-change cells at wide widths | **Resolved** (`777e619`; `xl:w-[184px]` / `xl:w-[168px]`, Summary ≥ ≈ 216 px; visual confirmed by the human) |
| n1 — nullable story key and app name | **Resolved** (`c86ed3e`) |
| n2 — no deprecated-entry test | **Resolved** (`c86ed3e`) |
| Out of scope (unchanged) | the shared Select aria-label bug; the app-page tab-strip overflow (97 px at 768) |

**48-04: SHIP (final).** No blocker, major or minor finding remains open. The only open item is m1, the As built
section, which the dev is writing now.
