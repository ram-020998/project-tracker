# Review 49-07 — base d62ae03, change 8a7ca96 (genesis-review, 2026-10-30)

Scope: `git diff d62ae03..8a7ca96 -- web/src` (44 files, +4285/−27) plus the rebuilt `web/static/**`. Web only; no
`package.json` change (`@radix-ui/react-popover` 1.1.2 and `@dnd-kit/*` were already dependencies). Upstream contract:
49-06 As built (genesis `73b3bd3`) and the nine fixtures in `web/src/test/fixtures/testdesign/`. The 49-07 sub-spec has
no As built section yet; this review used the brief's summary and decisions.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `npm run lint` | 0 errors, 20 warnings, all in files this change did not add (router.tsx ones pre-existing) |
| `npm run typecheck` | clean |
| `npx vitest run` | **49 files / 438 tests passed** (baseline 380) |
| Stale bundle: `npx vite build --outDir /tmp/49-07-static` then `diff -r /tmp/49-07-static web/static` | **IDENTICAL**; `git status --short` empty afterwards |
| `.venv/bin/ruff check genesis` | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1355 passed** (207 s) |

## Checklist

### ADRs
- [N/A] ADR-001 — no control-flow code; the web only calls start/rerun/finalize routes.
- [OK] ADR-003 — local web app; no new external calls (all via `lib/api/testdesign.ts`).
- [N/A] ADR-007 — no role gating touched.
- [OK] ADR-008 — the custom workbench gains the screens; no Studio dependency.
- [N/A] ADR-011 — no agent nodes.
- [N/A] ADR-013 — no config UI.
- [N/A] ADR-021 — no workflow gate change; Finalize/top-up apply are user-confirmed program actions server-side.
- [OK] ADR-026 — no auth/network surface added; same-origin `/api` only.
- [OK] ADR-027 — Tailwind tokens + existing primitives (Button, Card, Dialog, Select, SegmentedControl, Badge); new `shared/ui/popover.tsx` wraps the already-installed Radix Popover; dnd-kit reused from the Workbench. Grep for raw palette classes (`bg-red-500` etc.) in `features/test-design`: none.
- [OK] ADR-028 — `lib/api/testdesign.ts` uses relative paths; the only literal `/api` is `exportCsvUrlFor` (an `<a download>` bypasses the client), the same pattern as `featuresApi.exportCsvUrlFor` (`lib/api/features.ts:104`). Grep of components for `"/api` / `fetch(`: none.
- [N/A] ADR-030 — no persistence change.
- [N/A] ADR-031 / 033 / 034 / 045 — no chat change (the stage reuses `StageArtifactWorkspace`).
- [OK] ADR-035 — start/re-run are multipart (`notes`, `files`), ≤ 3 files enforced client-side (`NotesAndFiles.tsx:15`); test "entry: Start sends the notes as multipart".
- [N/A] ADR-037 / 041 — no KB/document storage.
- [OK] ADR-042 — test records hang off the feature (Tests tab, `/features/:id/tests`).
- [OK] ADR-043 — preview reuses `featuresApi.previewUrlFor(…, "test_design", …)` in a sandboxed iframe; no Lavish server.
- [N/A] ADR-044 — superseded by 056.
- [OK] ADR-049 — primary nav untouched; the app gains a `test-impact` tab (`ApplicationDetail.tsx` `APP_TABS`).
- [OK] ADR-050 — lifecycle buttons render only from the server's `allowed` (`LifecycleActions.tsx:6-19`); refusals show `detail.reason` as-is (test "a refused Retire shows the server's reason as-is").
- [OK] ADR-055 — no `@mui/material`; token classes only.
- [OK] ADR-056 / ADR-058 — Test Design is a plug-in stage: one `STAGE_DEFS` row + a `STAGE_REGISTRY` entry; the new optional `gate` is evaluated generically in `deriveAvailability` (`stages.ts:125-135`), no `if key ===` in callers except the existing per-stage empty-state switch in `StageBuilderPage` (which already branched per stage).
- [N/A] ADR-057 / 059 — UX/Breakdown untouched apart from the grid.
- [OK] ADR-060 — gate reads `stories_finalized_at`; Finalize tests is modelled as a one-time confirm.
- [N/A] ADR-061 / 062 / 068 / 070 / 072 / 073 / 074 / 075 / 076 — not touched (Object Wiki page only gains a read-only section).
- [N/A] ADR-063 / 064 / 065 — no collaboration change.
- [N/A] ADR-067 — no workflow.
- [OK] ADR-071 — every story link goes to `/applications/:app/stories/:id` (`paths.ts:storyPath`), test "after Finalize: … coverage links".
- [OK] ADR-077 — review run without `--trust-all-tools`; context via genesis-ctx.

### Lessons
- [OK] L-010 — client prepends `/api`; MSW handlers use `/api/...`.
- [OK] L-011 — `contract.test.ts` types every DTO with `Exact<T>` key maps (tsc fails on a type drift) and compares all nine fixtures' keys + value domains (test fails on a fixture drift). Screen tests import the same fixtures.
- [N/A] L-012 — no MCP/CLI settings.
- [OK] L-014 — jest-axe used through the existing global setup; 17 `toHaveNoViolations` assertions across every screen.
- [OK] L-015 — no heavy lib added; mermaid chunks unchanged in the diff of `web/static` (hash churn only).
- [N/A] L-017, L-025, L-027, L-041, L-042, L-045, L-051, L-057, L-058, L-061, L-062, L-064, L-071, L-072, L-073, L-074, L-075, L-076, L-082, L-084, L-085, L-086, L-087, L-088 — areas not touched by a web-only change.
- [OK] L-030 — the change touches `web/**`, so the frontend job runs.
- [N/A] L-034 — no graph rendering.
- [N/A] L-043 — no new SDK embed.
- [OK] L-048 — bundle committed under `web/static` (package data), fresh (see gates).
- [N/A] L-055 — no large document render.
- [OK] L-056 — commit contains source + bundle; tests reference only committed files (vitest green on the committed tree).
- [OK with note] L-063 — both sides gate; the roll-up now includes Test Design and `stages.test.ts`/`features.test.tsx` were updated with it. See m2 for a partial drift in the gate condition.
- [N/A] L-068 — server unchanged.
- [OK] L-069 — no `<Button asChild>`; `PopoverTrigger asChild` is on a plain `<button>` (`TestImpactTab.tsx` `ViaPopover`); the card actions are tested in the states that render the new controls (in-review → Re-run; finalized → Export CSV).
- [OK] L-083 — fixtures carry real shapes (`TC-000001`, `TS-000001`, `GNS_000123`, Gherkin arrays) and `contract.test.ts` asserts them.
- [OK] L-089 — reviewer's out-of-tree rebuild is byte-identical to the committed `web/static`.
- [DEFERRED → 49-08] L-090 — Cases table / impact table column widths are px floors chosen without a probe (`CasesTable.tsx:79-89`, `TestImpactTab.tsx` thead). 49-08 row 15 budgets the probe for those two tables; see m4 for what it misses.

### Gates
- [OK] `pytest` (features-stages, stories-workbench) — 1355 passed.
- [OK] `ruff check genesis` — clean.
- [OK] `npm run lint && npm run typecheck && npm test` (features-stages, stories-workbench, web-shell) — see table.
- [OK] `npm run build` + committed `web/static` — fresh.

## The author's decisions

1. **Agree.** `serverMessage` (`logic.ts:52-68`) reads `stale_write` → the fixed message, then `detail.reason`, then `detail.allowed`, then a string `detail`; refusals render in a `role="alert"` `RefusalNotice` with Reload only for CAS. A refused upload goes through `useTdMutation`'s toast with the server text (no test — m3).
2. **Agree.** `previewDecisions` matches `expand_topup_decisions` (`services/testdesign_stage.py:208-255`) line for line: unaccepted → "rejected"; new_scenario steps / add_step case checked against accepted new cases then live cases; add_step scenario checked against live scenarios. The client sends `accepted` unchanged and the server stays authoritative. All-Accept default is fine.
3. **Agree.** No app-wide stories endpoint exists; the two-step picker is the smallest correct option. The empty-state fan-out reads one `GET /test-suite` per finalized-stories feature (cached under `qk.testDesign.suite`); acceptable at current scale (n2).
4. **Agree.** Matches the server's 422 on Task ids (`testdesign_stage.py:576-578`); tested ("Tasks not offered", needs-review unchecked with "3 need review").
5. **Agree.** `pages.has(o.object_uuid)` against `useObjectWiki(appUuid)` (`TestCasePage.tsx` ObjectsSection). Untested positive branch (m3).
6. **Agree** (L-063). Observation: with `deriveFeatureStatus` unchanged, a pre-Phase-49 feature whose four stages are completed and whose Test Design is not started now rolls up to **"Draft"**, not "In progress" (n6).

None of the six deviates from an ADR.

## Findings

### Blockers
None.

### Majors
None.

### Minors

- **m1 — "Needs review" means two different things on the Tests surfaces.** The server's `needs_review` is the story-change flag only (`kb/testdesign.py:307,338`), and the summary bar's "Needs review" count is the server's `coverage.needs_review` (`TestsTab.tsx` Stat ← `suiteSummary`). The Cases table's Review column and the "Needs review" filter use `hasReviewFlag` = needs_review **or** a suspect object (`logic.ts` `hasReviewFlag`, `CasesTable.tsx:106`). 49-01 R2/F7 treat Needs-review and suspect as separate flags. Result: a case whose only flag is a changed object gets a "Needs review" badge in the table and matches the filter, but the summary does not count it, and the case header shows no Needs-review badge (`TestCasePage.tsx:85`) while still offering Mark reviewed. Fix: label the suspect-only state distinctly in the table (e.g. an "Object changed" badge, reusing `OBJECT_STATE_LABEL.suspect`) and either rename the filter to "Needs review or object changed" or split it; keep the summary number and the filter's row count consistent. Add a logic test with a suspect-only case.

- **m2 — The web gate is looser than the server gate (L-063 drift).** `storiesFinalized` (`stages.ts:49-51`) checks only `stories_finalized_at`; `prereqs_ready` (`services/testdesign_stage.py:381-389`) also requires at least one Story-type story. For a Tasks-only feature the card shows Start and the entry page offers "Start test design", which then fails with the server's 409 toast. The server message is clear, so nothing breaks, but L-063 asks that the two sides not drift. Fix options: expose a `has_story` (or story-type counts) on `FeatureDetail` and check it in the gate, or record the accepted drift in the As built so 49-08 checks the Tasks-only path live.

- **m3 — Two stated behaviours have no test.** (a) Decision 5: the case page's object-name link appears only when the app's wiki list contains the object. The test's wiki stub always returns `objects: []`, so only the no-link branch runs. Add a case with one wiki object and assert the link to `/applications/:app/wiki/:uuid` plus a plain name for the other. (b) Decision 1's refused upload: no test drives a 400 from `…/test_design/start` and asserts the toast text. Both are short MSW tests in `testDesign.test.tsx`.

- **m4 — The L-090 probe in 49-08 misses two layouts this change sized by eye.** 49-08 row 15 covers the Cases table and the Test Impact table only. This change also moved the stage grid to `lg:grid-cols-3 xl:grid-cols-5` (`FeaturePage.tsx:168`), which puts five cards in one row at 1280 px, and added the case page's Objects table (`min-w-[520px]` inside a 2/3 column, `TestCasePage.tsx:302`). Ask genesis-spec/49-08 to add both to the probe (1280/1440/1920, both themes).

### Nits

- **n1 — Duplicate notes + files input.** The spec says the dropzone is "reused from Breakdown"; the change adds `NotesAndFiles.tsx` but leaves `BreakdownEntry`'s inline copy (`StageBuilderPage.tsx:~470-510`, `slice(0, 3)` at :473). Two homes for the 3-file rule. Fold Breakdown onto `NotesAndFiles` when that file is next touched (not required in this change).
- **n2 — Impact empty-state fan-out.** `TestImpactTab` issues one `GET /features/{id}/test-suite` per finalized-stories feature, and each runs `reconcile_stage` + `resolve_unresolved` server-side. Fine now. If apps grow many features, a small `GET /applications/{app}/test-suites/exists` would replace it.
- **n3 — Steps that reference a retired case.** `StepsSection.write` resubmits every `case_id`, and `_check_step_cases` (`kb/testdesign.py:660-672`) 422s on a retired one, so any reorder of such a scenario fails with "test case #N is retired" until that step is removed. The UI already renders retired steps, so the state is expected to be reachable. Worth one live check in 49-08 (retire a scenario, retire its case, restore the scenario, try Move down).
- **n4 — Unneeded cast.** `data.allowed as TestAction[]` (`TestScenarioPage.tsx:82`); `ScenarioDetail.allowed` is already `TestAction[]`.
- **n5 — Breadcrumb ends at "Tests".** §5 lists "Application › Feature › Tests › TC-…"; the trail drops the current page, which matches the shell's convention for every other route. Fine; mention it in the As built so docs don't read it as a gap.
- **n6 — Roll-up label for existing features.** See decision 6: four completed stages + Test Design not started → "Draft". This is L-063's expected pull-in, but "Draft" reads oddly for a feature with finalized stories. If that's not wanted, `deriveFeatureStatus` could return "In progress" when some stages are completed; that's a product call, not a 49-07 fix.
- **n7 — `TopupDialog` re-seeds its picks** whenever `tree.coverage.stories` changes identity while the dialog is open (`TopupDialog.tsx:18-23`). TanStack structural sharing keeps the reference stable unless the data changed, so this only bites when the suite changes underneath an open dialog.

## Not verified
No real browser and no live backend (jsdom has no layout). Live acceptance of the seven screens, the drag-to-reorder by pointer, the CSV download and the L-090 width probe belong to 49-08.

## Verdict: SHIP

No blockers or majors; every gate is green and the bundle is fresh. m1–m4 should be fixed or answered in the As built before 49-08 (m4 is a spec edit for 49-08, not a code change).

---

# Round 2 (delta 8a7ca96..5d69eb7) — genesis-review, 2026-10-30

Scope: `git diff 8a7ca96..5d69eb7 -- web/src` (one commit, 8 files, +109/−16) plus the rebuilt `web/static/**`. HEAD =
`5d69eb7`, working tree clean.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `npm run lint` | 0 errors, 20 warnings (the same pre-existing set as round 1) |
| `npm run typecheck` | clean |
| `npx vitest run` | **49 files / 444 tests passed** (round 1: 438; +6) |
| Stale bundle: `npx vite build --outDir /tmp/49-07r2-static-b --emptyOutDir` then `diff -rq … web/static` | **no differences**; `git status --short` empty afterwards |

Backend unchanged in the delta, so pytest/ruff were not re-run (round 1: 1355 passed, ruff clean).

## Round-1 findings

- **m1 — RESOLVED.** `hasObjectChanged` (`logic.ts` "case flags") is now the suspect-link flag on its own;
  `hasReviewFlag` = either flag and is used only for Mark reviewed (`TestCasePage.tsx:93`, F7 clears both). The
  Review column renders `NeedsReviewBadge` from `c.needs_review` and a new `ObjectChangedBadge` from `hasObjectChanged`
  (`CasesTable.tsx:107-111`); the case header shows both independently (`TestCasePage.tsx:87-88`). The filter's
  `needs-review` branch is `c.needs_review && c.status !== "retired"`, which matches the server's count exactly
  (`services/testdesign_stage.py:303-305`: skip retired, count `needs_review`). Tests: logic.test.ts "a suspect-only case
  is 'object changed', not 'needs review' — the filter matches the summary count" asserts the filtered length equals
  `TREE.coverage.needs_review`, plus "a retired case is not counted as needing review"; testDesign.test.tsx "a changed
  object shows 'Object changed' (not 'Needs review') and still offers Mark reviewed". The other `NeedsReviewBadge` uses
  (`TestsSections.tsx:21`, `TestsTab.tsx:215`, `TestCasePage.tsx:276`, `TopupDialog.tsx:53`) all read story-change
  fields only, so nothing else conflates the two.
- **m2 — RESOLVED (with an accepted card-level drift).** `TestDesignEntry.tsx:59-66` loads `useStories` (enabled only
  when the descriptor gate is ready and no run is active) and shows `Blocked` with "The feature has no Story-type
  stories" instead of Start. The server rule is `prereqs_ready` (`testdesign_stage.py:381-389`). The stage card still
  offers Start for a Tasks-only feature and lands on the locked page. That keeps the descriptor `gate` pure on
  `FeatureDetail`, which I accept; it should be recorded in the As built as the remaining L-063 difference. Test:
  "entry: a Tasks-only feature is locked with the reason instead of offering Start (review m2)".
- **m3 — RESOLVED.** (a) "an object name links to its Object Wiki page only when the app's wiki has that object" uses
  the 48-02 `WIKI_LIST` fixture with one row re-pointed at the case's object (L-083) and asserts both the link href and
  the plain unresolved name. (b) "entry: a refused upload (400) toasts the server's reason as-is" drives a 400 from
  `…/test_design/start` and asserts `toast.error` received the server text.
- **m4 — open as a spec edit** (49-08 probe scope: the stage grid at `FeaturePage.tsx:168` and the case page's Objects
  table). No code was expected. It must be in the As built hand-off to genesis-spec before 49-08 starts.
- **n4 — RESOLVED.** The cast is gone (`TestScenarioPage.tsx:82`); `TestAction` import dropped; typecheck clean.
- **n1, n2, n3, n5, n6, n7** — accepted / carried to 49-08 as the author states. No change expected.

## New findings in the delta

### Blockers / Majors / Minors
None.

### Nits
- **n8 — Story-type test differs slightly from the server.** The client checks `s.story_type === "Story"`; the server
  uses `(s.get("story_type") or "Story") == "Story"`, so an empty or null type counts as Story there. Today the column is
  `NOT NULL DEFAULT 'Story'` (`m0016_stories.py:55`) and the importer coerces to `VALID_STORY_TYPES`
  (`kb/stories.py:121`), so the case can't arise locally. The Hub returns null text as `""` (L-084;
  `collab/providers/local.py:57` lists `story_type`), so a pulled story is the only route. Mirroring the server
  (`(s.story_type || "Story") === "Story"`) costs nothing.
- **n9 — Start is briefly offered while stories load, and stays offered if the stories query fails.** `noStory` needs
  `stories.isSuccess`, so a fast click during load, or a failed load, still ends at the server's 409 toast. That failure
  mode is safe and the message is clear; no change needed.
- **n10 — Small test gaps in the m1 change.** The table's "Object changed" badge and the new three-level `review` sort
  (`logic.ts` `sortValue`: needs-review 0, object-changed 1, none 2) are not asserted; only the header badge and the
  filter are. The `object-changed` filter also includes retired cases while `needs-review` excludes them. That is
  defensible, because the server keeps no object-changed count to match. Add a line to the existing sort test when the
  file is next touched.

## Not verified
Same as round 1: no browser, no live backend. 49-08 owns the live checks: the Tasks-only card → locked entry path, both
badges in a real table, and the L-090 probe including m4's two layouts.

## Verdict: SHIP

m1–m3 and n4 are fixed with tests that would have caught the original problems. Every web gate is green and the
committed bundle matches a fresh out-of-tree build. Before 49-08, the As built needs to record m4 (the spec edit for
genesis-spec) and m2's remaining card-level difference.
