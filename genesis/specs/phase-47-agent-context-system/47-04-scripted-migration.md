# 47-04 — Scripted migration and lossless proof

> **Status:** ✅ BUILT 2026-10-20 (session S3; As built below). Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D7, D8. Tools: `47-03` (`archive`, `mark`, `verify-lossless`, `propose-tags`). Session S3.

## 1. Goal

Take history out of the mandatory set and give lessons stable ids, **by script**, with the agent reading only the
scripts' reports — never the corpus. Prove that no paragraph was lost.

## 2. Principles

1. **Move, never rewrite.** Text is cut from one file and pasted verbatim into an `archive/` file (or into
   `context/L0-core.md` for the implementation contracts). Nothing is summarized in this step.
2. **Pointer at the old place.** Each moved block leaves one line, e.g.
   `> 📦 Moved verbatim to [archive/tracker-status-log.md](archive/tracker-status-log.md) (Phase 47-04, 2026-10-2x). Search with \`genesis-ctx search <term> --archive\`.`
3. **Duplicates are removed from the active layer only.** The other copy stays (in the archive or in its home file),
   so `verify-lossless` stays green by construction.
4. **One commit per step**, so any step can be reverted on its own.

## 3. Baseline

Before any change: commit or stash pending project-tracker edits, record `BASELINE=$(git rev-parse HEAD)` in
`archive/LOSSLESS.json` (via `verify-lossless --baseline $BASELINE --write` at the end).

## 4. Steps (the plan file `agent-system/migration/47-04.plan.toml`)

| # | Move | From → To | Selector |
|---|---|---|---|
| 1 | Status log | `tracker.md` §6 body → `archive/tracker-status-log.md` | from the line after `## 6. Status log` to EOF. §6 keeps its heading, the pointer, and a note: "From Phase 47 on: ≤ 5 lines per phase; detail lives in `progress/`." |
| 2 | Shipped phases | `bible/08` → `archive/bible-08-shipped-phases.md` | every `### ` block whose heading contains `SHIPPED` or `CLOSED`, up to the next `### ` / `## ` / the closing "Do not start backlog…" paragraph. Keeps the `## 9` heading, non-shipped blocks and the closing paragraph. |
| 3 | Onboarding banners | `AGENT_ONBOARDING.md` → `archive/onboarding-banners.md` | the `## ⭐ SHIPPED — Phase 26..30 …` sections and the historical note above them. (The file itself is rewritten at 47-10; the full pre-switch version is also archived then.) |
| 4 | Lesson ids | `bible/06` in place | `genesis-ctx mark` inserts `<!-- L-NNN -->` after the dash of each top-level lesson bullet in §7, document order, L-001.. |
| 5 | Tag proposals | — → `context/tags/*.proposed.toml` | `genesis-ctx propose-tags` (input to 47-05) |

`bible/00` and `bible/01` are archived in 47-05, at the moment their replacements (`L0-core.md`, `state/current.md`)
exist. The `bible/04` "Key implementation contracts" bullets move into `L0-core.md` in 47-05 as well.

Each step: `genesis-ctx archive --plan … --step N` (dry run → shows line ranges and byte counts) → `--apply` →
`verify-lossless --baseline $BASELINE` (must be 0 missing) → commit.

## 5. Duplicate report

`verify-lossless` also prints units that appear **more than once in the active layer** (everything outside `archive/`,
`specs/`, `progress/`). For each, the agent decides keep/remove using only the unit text and its locations (a short
table). Expected to be small after steps 1–3 (most duplication was between history files).

## 6. Expected result

| | Before | After 47-04 |
|---|---|---|
| `tracker.md` | 386 KB | ~33 KB (and no longer mandatory) |
| `bible/08` | 134 KB | ≲ 15 KB backlog / what's next |
| `AGENT_ONBOARDING.md` | 35 KB | ~10 KB until the 47-10 rewrite |
| Archive | — | ~500 KB verbatim, never mandatory |

## 7. Acceptance

- `verify-lossless --baseline $BASELINE` → **0 missing units**; result written to `archive/LOSSLESS.json`.
- Every lesson in `bible/06` §7 has exactly one marker (`lint` lesson check passes; tags may still be missing — 47-05).
- `git log` shows one commit per step; each commit message names the step.
- The agent's context in S3 stays under 25 % (it reads plan output, diffs of pointer lines and reports — not the files).

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-03-genesis-ctx.md"]
```

## As built

**Session:** S3, 2026-10-20. **Bootstrap rule honored:** no whole-file reads of the bible, the tracker or the
decision-log. Context came from tool reports, `grep -n` heading listings and ranged reads of the specific lines a
selector or a pointer needed. **Baseline:** `d89f763` (the 13 baseline files are unchanged since `b127a4d`).
Plan: `agent-system/migration/47-04.plan.toml`.

### Commits (project-tracker, local, not pushed)

| Commit | Step |
|---|---|
| `d89f763` | 47-03 fix: `bible/03` base-map entries start only on path-like 2-space lines (47-02 §4.3 (a); 46 sections) |
| `4d64783` | 47-03 fix: `archive` pads the pointer with blank lines so it stays its own unit |
| `6f173bd` | **Step 1:** `tracker.md` L246–L2204 (353,538 B) → `archive/tracker-status-log.md` |
| `407046c` | **Step 2:** `bible/08`, 29 blocks (132,015 B) → `archive/bible-08-shipped-phases.md` |
| `0da2d9e` | `bible/08` "### Deferred items (pointers)" |
| `8c2d12f` | **Step 3:** `AGENT_ONBOARDING.md` L87–L234 (14,431 B) → `archive/onboarding-banners.md` |
| `b62cea4` | **Step 4:** `genesis-ctx mark`: L-001..L-086 in `bible/06` (+1,290 B) |
| `62aceb5` | **Step 5:** `genesis-ctx propose-tags` → `context/tags/{adr,lesson,codemap}.proposed.toml` |
| `d383151` | 47-03 fix: the duplicate scan skips `agent-system/tests/fixtures/` |
| `abccfe4` | `tracker.md` §6 order: heading → note → Phase 47 entry → pointer |
| (this) | `archive/LOSSLESS.json`, this As-built, Status BUILT |

After every step, `verify-lossless --baseline d89f763` reported **0 missing** of 1,338 baseline units. Re-running
the whole plan reports every entry "already applied".

### Deviations (user-approved in S3)

1. **Step 1:** the selector starts at the 2026-10-20 Phase 47 entry, which stays as §6's first entry. Everything
   after it moves.
2. **Step 2: stops amended.**
   - The real closing line is bold (`**Do not start backlog…`), so `^Do not start backlog` never matched.
   - The Phase 16 CLOSED block is followed only by a `---` line and then a history/backlog list.
   - As specified, the last block would have run L613–L854 and archived the backlog bullets and the closing
     paragraph. New stops: `['^### ', '^## ', '^---\s*$', '^\*{0,2}Do not start backlog']`.
3. **Step 2 (b), beyond `###` blocks:** a second selector-A entry also moved L772–L840 (the "Shipped:" summary
   and the Phase 13 / Phase 14 COMPLETE bullets, 7,407 B). Kept: "Backlog (`specs/backlog/`)", "Open follow-ups
   (may be assigned)" and the closing paragraph. The stale "Open follow-ups" list was left as is (out of scope).
4. **Deferred pointers.** I listed every archived line mentioning deferred / backlog / follow-up / not started /
   next (72 lines). The user then chose the pointer list.
   - `bible/08` got "### Deferred items (pointers)": the 14 `specs/backlog/` files by H1 title, plus 8 items
     from shipped phases not covered there: Phases 29, 26 (merged), 25, 22, 21, 18, 14 and 27. Each gives a
     `genesis-ctx search … --archive` term, and every term was checked to hit.
   - Dropped as delivered: Phase 23's delta sync and schedule (Phase 45), the 27-11 memory-graph keyboard nav,
     and the Phase 13 pin bump / token gating.
   - The grep of later `progress/` docs also dropped the Phase 26 "OS-user default for `memory_owner_username`".
     35-03 replaced it with `canonical_username()`.
   - Row 44 is the **chat-transcript** PDF export (21-06), not a spec export; it is worded that way.
5. **Step 3:** the file has `## ⭐ SHIPPED` sections for Phases **27–30** only; Phase 26's leftovers sit inside
   the Phase 27 section. The L20–36 "Last refreshed" banner stays, because 47-10 archives the whole pre-switch
   file.
6. **Duplicates (§5):** none removed. After the fixture skip, 4 remain, all repeated short labels or a table header:
   - `**Prompt:**` ×5 in OPERATOR_GUIDE
   - `**Mechanism:**` ×3 in hitl-design
   - `**Consequences:**` ×2 in the decision-log
   - `| Term | Definition |` ×2
   Checked separately: with fixtures also excluded from the *present* set, the result is still 0 missing, so the
   fixture copies hide no loss.
7. **Pointers:** `pointer = "each"` leaves 29 identical pointer lines in `bible/08`. They are kept as specified;
   47-05/47-10 may collapse them.

### Result (bytes; before = `d89f763`)

| | Before | After 47-04 | Spec expectation |
|---|---:|---:|---|
| `tracker.md` | 387,281 | 33,980 | ~33 KB ✅ |
| `bible/08` | 134,766 | 11,199 (incl. the new pointer list) | ≲ 15 KB ✅ |
| `AGENT_ONBOARDING.md` | 34,874 | 20,608 | ~10 KB: the L20–36 banner and the onboarding prompt stay until 47-10 |
| `bible/06` | 80,477 | 81,767 (markers) | — |
| `archive/` | 835 (README) | 504,122 | ~500 KB ✅ |
| 13-file baseline corpus | 1,125,521 | 635,677 (−43.5 %) | `bible/00` + `01` move in 47-05; `tracker.md` leaves the mandatory set at 47-10 |

### Acceptance (§7)

- `verify-lossless --baseline d89f763 --write` → **0 missing**, PASS. Written to `archive/LOSSLESS.json`.
- Every `bible/06` §7 lesson has exactly one marker: 86 markers, no duplicate ids, 0 `lesson-unmarked`.
- `lint` → 211 errors, all expected for 47-05: adr-untagged 76, lesson-untagged 86, codemap-untagged 46,
  generated-stale 3.
- `propose-tags`:

  | Tags | Entries | High | Medium | Low | No area |
  |---|---:|---:|---:|---:|---:|
  | ADRs | 76 | 22 | 43 | 11 | — |
  | Lessons | 86 | 11 | 64 | 11 | 5 |
  | Code-map | 46 | 15 | 27 | 4 | 4 |

- One commit per step; each message names its step.
- Tests: `pytest` → **92 passed**.
