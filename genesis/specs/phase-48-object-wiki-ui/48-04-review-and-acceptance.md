# 48-04 — Review, hardening and live acceptance

> **Status:** ✅ DONE 2026-10-21 — review **SHIP** (final, `reviews/48-04-review.md`, genesis `777e619`); live
> acceptance 1–11 PASS. Committed locally only (not pushed, not tagged — 48-05). Repo: genesis. Parent: `specs/phase-48-object-wiki-ui.md`.
> Run by **genesis-review** (read-only on code) after 48-02 and 48-03 are BUILT; report in
> `specs/phase-48-object-wiki-ui/reviews/48-04-review.md` with SHIP / NEEDS_CHANGES.

## 1. Independent review (file:line evidence for each)

1. **Read-only** — the new endpoints are GET only; no new code path writes `wiki_object_*`, `kb_*` or collab state;
   no Hub call on either request (ADR-063/070).
2. **One DTO builder** — list rows and the detail `object` come from the same helper (L-039); `is_bugfix` is a bool.
3. **Latest change is derived from entries**, never from `latest_entry_id` (48-01 §2.8); a pulled-shape test exists.
4. **No N+1** — the list is one query; story resolution is batched/joined; both scoped to the app.
5. **Story links** go only to `/applications/:appUuid/stories/:storyId` with the local id (ADR-071); a cross-app key
   never resolves.
6. **No code, no HTML injection** — nothing renders object source (ADR-037); descriptions render as plain text (no
   `dangerouslySetInnerHTML`).
7. **Consistency** — only existing primitives/tokens (no raw palette classes, no new dependency; ADR-027/055); no
   `<Button asChild>` (L-069); the client prepends `/api` (ADR-028); types mirror 48-02 (L-011); fixtures are real
   shapes (L-083).
8. **URL tabs** — every existing tab still reachable; unknown `?tab` safe; `replace` navigation; Back from the object
   page lands on the Object Wiki tab.
9. **Accessibility** — jest-axe clean; sortable headers expose `aria-sort`; row action reachable by keyboard; the
   switch is labelled.

Findings are fixed before release; each fix gets a regression test.

### 1.1 Hardening (built by **genesis-dev** before the review runs; the reviewer checks it like the rest)

- **H1 — show the change reason on every entry (48-01 D8, from 48-03 review m1).** In
  `genesis/web/src/features/object-wiki/HistoryTimeline.tsx`: when `change_reason` is present, render it under the
  entry's badge row as a muted plain-text line "Why: <reason>" for **every** change kind; the `Bug fix` badge renders
  only when `is_bugfix` and no longer carries the reason; absent reason → no line. Independent of the Business /
  Technical / Both switch (always shown). Tests: a `created` entry with a reason shows "Why: …"; a bug-fix entry shows
  the badge **and** the line once (not twice); an entry without a reason shows no line; jest-axe still clean. Gates as
  §2, rebuild + commit `web/static/`. Record in this sub-spec's As built.

### 1.2 Out of scope here

The shared `Select` `aria-label` bug found during 48-03 (9 pre-existing call sites) is **not** fixed in Phase 48 —
backlog `specs/backlog/phase-48-follow-ups.md` item 1. The Object Wiki tab's own selects are named correctly (48-03
review).

## 2. Gates

genesis: `pytest` + `ruff`; web: `lint`, `typecheck`, `vitest` (incl. jest-axe), `npm run build` byte-identical to the
committed `web/static`; a fresh DB migrates to **v24** (no new migration).

## 3. Live acceptance (local `genesis serve`, :8760)

The UI needs a browser — the reviewer drives what it can (API via `curl`, the built SPA) and hands the human the
browser checks.

| # | Step | Expected |
|---|---|---|
| 1 | `GET /api/applications/<app>/wiki` for an app with implemented stories | 200; one row per wiki page; counts and latest fields match the DB |
| 2 | Same for an app with no wiki pages; an untracked uuid | `objects: []`; 404 |
| 3 | Open the app → **Object Wiki** tab (right after Overview) | Table as 48-03 §4; URL shows `?tab=object-wiki` |
| 4 | Search, Type filter, Change = Deprecated, sort by each column | Rows filter/sort correctly; counts update; Clear filters works |
| 5 | Click an object | `/applications/<app>/wiki/<object>`; header, metadata, summary, newest-first history |
| 6 | Switch Business / Technical / Both | Only the chosen sections show |
| 7 | Click an entry's story link | The canonical story page opens; browser Back returns to the object page |
| 8 | Page **Back** and the "Object Wiki" breadcrumb | Both land on the Object Wiki tab |
| 9 | Reload the object URL directly (deep link) | Page loads; breadcrumb shows the app name |
| 10 | (collab on, if available) pull a teammate's entry | It appears on refocus with the teammate as author |
| 11 | Light + dark theme, narrow window | Layout consistent with Documents / Story pages; no overflow |

Record evidence (commands + outputs, screenshots from the human) in §4.

## 4. As run

Full evidence: `reviews/48-04-review.md` (the full review on `fdc47ab` plus five delta reviews; screenshots and probe
scripts under `/tmp/genesis-review/pw/`, not committed).

**Server.** The :8760 server was started on 2026-10-15, before 48-02, so it returned the generic `/api` 404 for the wiki
routes. genesis-dev backed up the DB (`/tmp/genesis-review/genesis.db.pre-48-04.bak`, `sqlite3 .backup`) and restarted
it on the Phase-48 code with `genesis down` / `genesis up --no-open`. No run was active, the install is editable, and the
running process's `GENESIS_*` variables were kept (collaboration on). There was no migration: the DB is at v24.

| # | Result | Evidence |
|---|---|---|
| 1 | PASS (reviewer) | 200 with 21 objects for `_a-0000e5bc-…_930416`. List and all 21 detail calls match the DB field by field (`live_compare.py`, `live_detail.py`: 0 mismatches). |
| 2 | PASS (reviewer) | The untracked app (it has 1 orphan page) and a random uuid both return 404 `Application '…' not tracked`; an unknown object returns 404. No tracked app without pages exists live; `test_tracked_app_with_no_pages_lists_empty` covers that case. |
| 48-02 m1 | PASS (reviewer) | `julianday(created_at)` is non-NULL for all 26 entries. |
| 3–9 | PASS (reviewer, headless Playwright, read-only guard) and PASS (human) | Reviewer: 0 non-GET requests, 0 console errors. Human: "All checks pass", 2026-10-21. |
| 10 | PASS (human) | Collaboration pull, checked by the human ("All checks pass"). The reviewer did not drive it. |
| 11 | PASS (human; the reviewer measured the automated half) | Before the fixes, M1 failed below about 1000 px. After `777e619`: no overflow at 1440 to 768 px in either theme; below 900 px the table scrolls inside its card. The human checked the look on bundle `index-zh0sG0zM.js`. |

## As built (genesis-dev, 2026-10-21)

**Status:** ✅ DONE. Final review verdict **SHIP** on `777e619`, with no open finding. Committed locally only: not pushed, not tagged (48-05).

### Commits (genesis, base `0b2ecec`)

| Commit | Message (short) | Fixes |
|---|---|---|
| `fdc47ab` | feat(web): show the change reason on every Object Wiki entry | H1 (48-01 D8) |
| `c86ed3e` | fix(web): no narrow-window overflow on the Object Wiki, nullable story key/app name | M1, n1, n2 |
| `809ac29` | fix(web): table keeps a minimum width and wraps header labels | m2 |
| `64b311a` | fix(web): table minimum width 640 → 600 px | m3 (source only; see B1) |
| `9d926fd` | fix(web): commit the rebuilt bundle; sort arrow `shrink-0` | B1, m4 |
| `4d2ea41` | fix(web): fixed px widths for the metric columns | M2 |
| `777e619` | fix(web): widen the "Last …" columns from xl | m5 |

Every commit except `64b311a` carries its rebuilt `web/static`. At `777e619` a fresh build is byte-identical to the commit.

### Changed (all under `genesis/web/src/`)

- `features/object-wiki/HistoryTimeline.tsx`:
  - **H1:** a muted plain-text line "Why: <reason>" under the badge row on every entry whose `change_reason` is not blank. It shows in all three views (Business, Technical, Both).
  - The Bug fix badge shows only for `is_bugfix` and no longer carries the reason.
  - n1: a story link reads `key · title`, or just the title when the key is null or blank.
- `features/object-wiki/ObjectWikiPage.tsx`: the title is wrapped in `[overflow-wrap:anywhere]`. Appian names have no spaces, and `anywhere` (unlike `break-word`) lowers min-content, so the `Page` flex row can shrink (M1).
- `features/object-wiki/ObjectWikiTable.tsx`:
  - The Last-change cell's badge and time can wrap (`flex-wrap`, M1).
  - The card is `overflow-x-auto` and the table `min-w-[600px]`: below that width it scrolls inside the card instead of clipping (m2, m3).
  - Sort-header buttons are `max-w-full text-left`, and the arrow is `shrink-0` (m2, m4).
  - Column widths come from live measurements, not guesses (M2, m5): Object 20%, Type 12%, Summary takes the rest, Changes `w-[100px]`, Last change `w-[104px] xl:w-[184px]`, Last changed by `w-[104px] xl:w-[168px]`.
- `types/objectWiki.ts`: `WikiStoryRef.key` and `app_name` are now `string | null`, as the API returns them (n1).

### Tests

- `features/object-wiki/objectWiki.test.tsx`, 34 → 47 tests:
  - **H1** (`describe "Object page — the change reason on every entry"`):
    - a created entry with a reason shows the line and no Bug fix badge;
    - a bug fix shows the badge, and the reason exactly once;
    - a null or blank (`""`, the Hub's null text) reason shows no line;
    - the line shows in every view;
    - a deprecated entry shows it too (n2);
    - jest-axe is clean.
  - **Narrow widths and nullable fields:**
    - the title wrap class and the Last-change `flex-wrap`;
    - the card scroll, the minimum width, header wrapping and the arrow's `shrink-0`;
    - the metric-column width classes, including `xl:`;
    - a key-less story link;
    - a null `app_name`.
  - The existing newest-first test now expects "Why: …".
- **Mutation checks** (the reviewer reproduced each one):
  - pre-H1 component: 5 failed;
  - pre-M1/n1 components: 3 failed;
  - pre-m2 table: 1 failed;
  - pre-M2 table: the width test fails.
- Gates at `777e619`:
  - Web: lint 0 errors / 20 warnings (unchanged); typecheck clean; vitest 46 files, **380 passed** (367 at 48-03); build byte-identical.
  - Backend (unchanged since 48-02): pytest **1187 passed**, ruff clean; a fresh DB migrates to v24.
- Live geometry probe `/tmp/genesis-review/dev/cols.cjs` (dev, read-only), confirmed by the reviewer's probes, at 1440 to 768 px: every active sort arrow is 12 px wide and inside its column, and no cell spills.

### Review

`reviews/48-04-review.md`. The full review gave NEEDS_CHANGES on `fdc47ab`, for M1 only: §1 items 1–9, H1 and every gate were OK. Five delta reviews followed:

| Delta | Verdict | Findings |
|---|---|---|
| `c86ed3e` | SHIP | new m2 |
| `809ac29` | SHIP | new m3 |
| `64b311a` | NEEDS_CHANGES | B1 (stale bundle); new m4 |
| `9d926fd` | NEEDS_CHANGES | new M2, a side effect of the m4 fix |
| `4d2ea41` | SHIP | new m5 |
| `777e619` | **SHIP (final)** | none |

All findings are resolved: M1, M2, B1, m1 (this section), m2–m5, n1 and n2.

### Decisions / deviations (no ADR deviation)

1. **A blank `change_reason` shows no line.** The value is trimmed, matching the "Not recorded." handling of the descriptions and the Hub's `""` null text (L-084).
2. **The :8760 server was restarted on unreleased code** so the live check could run. This was reversible: the DB was backed up first and the environment kept. It now serves genesis `777e619`, which is ahead of the v0.77.0 tag.
3. **The table scrolls inside its card below a 600 px table width (viewports under about 900 px) rather than squeezing columns.** Column widths are fixed px floors sized from measurements, and widen from `xl`.
4. **Out of scope and left alone:** the shared `Select` aria-label bug (backlog `phase-48-follow-ups.md` item 1), and the application page's tab strip overflowing by 97 px at 768 px. The second is pre-existing, and the Features tab does the same.

### Lesson candidates

- **Run edit → build → commit in sequence, never in one parallel tool batch.** B1 happened because the build ran before the source edit landed, and the commit then shipped a stale `web/static`. That broke the commit message's "rebuilt web/static" claim (L-030/L-056 in spirit). After committing, check with a fresh build plus an empty `git status`.
- **Size table columns from measured content, not percentages chosen by eye.** Four review rounds (m2 → m3 → m4 → M2 → m5) each fixed one narrow-width symptom and caused the next. What ended the loop was a one-shot geometry probe: each header's min-content against its content box, the active-arrow position per sorted column, and the per-cell spill. Fixed px floors plus breakpoint widening followed directly from its numbers.
- **jsdom can't catch layout bugs.** Class-level regression tests pin a fix, but only a real-browser probe at several widths proves it. Budget a probe in acceptance for any table or list UI.

### Code-map changes (for genesis-docs)

- None structural. `web/src/features/object-wiki/HistoryTimeline.tsx` now shows the change reason on every entry (48-01 D8). `ObjectWikiTable.tsx` columns are fixed-px metric columns with a 600 px minimum and scroll inside the card.

## Context manifest

```toml
areas    = ["api", "web-shell", "stories-workbench"]
adrs     = ["ADR-027", "ADR-028", "ADR-037", "ADR-055", "ADR-063", "ADR-070", "ADR-071"]
lessons  = ["L-011", "L-030", "L-039", "L-069", "L-083", "L-084"]
docs     = ["tracker:specs/phase-48-object-wiki-ui.md",
            "tracker:specs/phase-48-object-wiki-ui/48-01-findings.md"]
code     = ["genesis/genesis/kb/object_wiki.py", "genesis/genesis/kb/object_types.py",
            "genesis/genesis/api/object_wiki.py", "genesis/web/src/features/object-wiki/**",
            "genesis/web/src/features/applications/ApplicationDetail.tsx", "genesis/web/static/**"]
upstream = ["48-02", "48-03"]
```
