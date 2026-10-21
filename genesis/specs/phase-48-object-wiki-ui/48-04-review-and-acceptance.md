# 48-04 — Review, hardening and live acceptance

> **Status:** 🟡 SPEC-DRAFTED 2026-10-21. Repo: genesis. Parent: `specs/phase-48-object-wiki-ui.md`.
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

_(filled by genesis-review)_

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
