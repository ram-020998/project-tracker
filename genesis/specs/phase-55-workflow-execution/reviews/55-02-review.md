# Review 55-02 — base 7f32ac0, head c8f9b27 (genesis-review, 2026-11-22)

What this change does: adds a dev-only, lazy-loaded route `/dev/phase-55` (`web/src/dev/mockups/phase55/**`) with six
mockup sections: the Documents tab By step and By type, six Documents states, the Resolve panel in two placements ×
five states with six confirm dialogs and six results, the escalation bell notice, and seven run-graph states with the
Live badge and Refresh. Stub data only, no API calls. `phase54/bell-chat.tsx` now exports `NotificationPanel` and
`BellButton` for reuse. `scripts/probes/phase55-mockups.mjs` adds the real-browser probe, and c8f9b27 is the bundle.

Commits reviewed: 4ef2694 (source, 12 files, +2505/−2) and c8f9b27 (web/static only, 73 files; no non-static path,
checked with `git diff --name-only 4ef2694 c8f9b27 | grep -v ^web/static/` → 0).

## Checklist

### ADRs
- [N/A] ADR-003, 007, 008, 013, 019, 021, 026, 029, 031, 033, 034, 043, 045, 046, 047, 049, 060, 061, 062, 063, 065,
  068, 069, 071, 074, 075, 076, 078, 080, 081, 082, 083, 084, 085, 086, 087: a dev-only mockup page with stub data. It
  adds no backend, nav entry, workflow, schedule, Kiro launch, trust or test execution. The router adds one `/dev`
  route beside `/dev/phase-54` (`router.tsx:41-43,123`) and no nav item, so ADR-049 is unchanged.
- [OK] ADR-011: no agent node. The mockup keeps the escalation gate as the place a run stops (graph `gate` state; D6).
- [OK] ADR-027 / ADR-055: shared primitives only (`Button`, `Badge`, `Card`, `SegmentedControl`, `RowMenu`, `Select`,
  `Popover`, `DefinitionList`, `Field`, `StatusPill`, `CreditBadge`, `RelativeTime` from `@/shared/ui`). Icons come from
  the curated re-export. A grep of `phase55/*` for raw palette classes (`bg-red-…`, `text-white`, …), hex, `rgb(` and
  `hsl(` finds 0 hits. The SVG strokes use `var(--primary|warning|success|fg-subtle|surface-1|fg-muted)`, which are
  full colours in `src/styles/tokens.css:24-112` (light and dark).
- [OK] ADR-028 / L-010: no `fetch(`, `/api` or `useQuery` in `phase55/*` (grep finds 0).
- [OK] ADR-032: every credit figure is a `CreditBadge` with a provenance (`metered`, or `partial` for the live and
  failed cases; `credits={null}` for the program-only state). See m6 for the header total.
- [OK] ADR-077: no agent-system change.

### Lessons
- [VIOLATION] L-083: real value shapes. The 31 files, their sizes and their times match the real folder
  `~/Genesis/runs/technical-design-analysis/r-d5ed99071d49` exactly (`stat`, file by file), and so do the 19 prompt
  names and the memory rows #40, #13 and #9 (`memory.db`: scope, type and importance match). The tool outputs do not
  match. See **M1**. The relaunch inputs also differ from the real run's inputs (m4).
- [OK] L-069: no `<Button asChild>`. The one `asChild` is `PopoverTrigger asChild` on a native `<button>`
  (`bell.tsx:26`), which is the pattern `shared/ui/popover.tsx:6` documents and `NotificationBell.tsx:117` uses.
- [OK] L-123: a grep of `phase55/*` for `<utility>-<token>/<n>` finds 0 hits. The tints are `*-subtle` tokens.
- [OK] L-014: jest-axe runs on every frame and then on the whole render, for every section, every Documents state,
  all 10 placement × state pairs, the 6 dialogs, the 6 results, the bell and the graph states (`phase55.test.tsx`).
  The ambient types and the global matcher are unchanged.
- [OK] L-015: the page is its own lazy chunk (`router.tsx:41-43`; `Phase55Mockups-BSQ5c01B.js` in the bundle).
- [OK] L-089: c8f9b27 holds web/static only. My out-of-tree build (`npx vite build --outDir /tmp/55-02-review-static`)
  matched `web/static` (`diff -rq`: identical), so the bundle is fresh for 4ef2694. `git status --short` is empty.
- [OK, final run open] L-090: the probe starts Vite with cwd = `web/`, checks that a Tailwind class resolves, covers 3
  widths × 2 themes, every variant and 3 portals, waits out the open animation, and writes to its own output folder.
  Its result `/tmp/genesis-probes/p55-run2` (216 entries + result.json) predates the last two edits. The re-run at the
  final head is still owed (the dev says it will run it). I looked at two screenshots myself; they show m1 and m2.
- [N/A] L-011, L-012, L-017, L-025, L-027, L-030, L-034, L-043, L-044, L-045, L-048, L-051, L-055, L-056, L-057,
  L-061, L-068, L-081, L-087, L-088, L-091, L-092, L-094, L-096, L-098, L-099, L-100, L-101, L-103, L-104, L-105,
  L-107, L-109, L-110, L-111, L-112, L-113, L-115, L-116, L-117, L-119, L-125: no contract type, Python, CI, release,
  DB, trust or registry change. L-061 does matter to a design decision the page shows; see m5.

### Gates (run by me at c8f9b27)
- [OK] `npm run lint`: 0 errors, 20 warnings, the same as the baseline. On the changed files only, the two warnings
  are the existing `router.tsx` react-refresh warnings, shifted by the insert.
- [OK] `npm run typecheck`: clean.
- [OK] `npx vitest run`: 82 files, 947 passed.
- [OK] `npm run build`: checked out of tree, identical to the committed `web/static`.
- [N/A] playwright-appian gates, genesis `pytest` and `ruff`, genesis-workflows `validate_library` and pytest: no
  Python, library or apwt file changed. The probe script matches the browser-testing glob only by path.

## Findings

### Blockers
None.

### Majors
- M1 **Tool-output fixtures are presented as the real run's, but four of their values are invented**
  (`fixtures.ts:3-6,212-223`). What: the header says the rows are r-d5ed99071d49's 125 `tool_output.recorded` events
  (node, ref, tool, bytes). Problem: the real events in `genesis.db` (read with `immutable=1`) differ:
  - The per-step split is plan_sections 1, analyze_section **113**, draft_section 8, **synthesize 2, verify 1**. The
    fixture has `[plan 1, analyze 116, draft 8]`, so the "Show all 125 (…)" button lists three steps and the user never
    sees that Synthesize and Verify called tools.
  - `call_6` is really `listApplicationObjects` (78 B), not `getRecordType` (21803 B).
  - `call_7` is really `listRecordTypes` (150 B), not `listRecordTypeFields` (9120 B).
  - `call_8` is `getCustomDataType` at 10500 B, not 3954 B.

  Calls 1–5 match. This is the L-083 failure: a fixture that looks real but is not, in a surface the user is asked to
  approve. Fix: set `TOOL_OUTPUT_BY_STEP` to the five real pairs, and take rows 6–8 from the real events (or real
  `getRecordType` rows such as call_12, 938 B, and call_13, 15076 B), keeping the header claim true. Add a unit
  assertion that the split sums to `TOOL_OUTPUT_TOTAL` and covers the five steps. If skipped: 55-09 inherits a stub
  that hides tool outputs outside the analysis loop.
- M2 **The "Several outputs" state drops two of story-implementation's files from the By step view, and no test
  catches it** (`documents.tsx:241-243`, `stepIds` from `STEPS`; fixture `documents.tsx:~548-552`). What: the step
  groups come from `STEPS`, which is technical-design-analysis's node list. Problem: in the default By step view of the
  story-implementation state, `implementation.json` (node `implement`) and `wiki.json` (node `author_wiki`) appear in
  no group. Neither node is in `STEPS`, and the "Other files" group takes only `node == null`. Only "Verify (grounded
  critic)" shows, and that is technical-design-analysis's label for `verify`; story-implementation's own label is
  "Verify touched objects" (`genesis-workflows/workflows/story-implementation/workflow.yaml`). The same lookup gives
  wrong step labels too. The screenshot `docs-states-several-1440-light.jpg` shows the outputs under the raw ids
  `render_report` and `prepare_rollback`, and the inputs under "Load spec + UX + comment" instead of "Load design + TD
  + story". The rail says "8 files" while the tab badge says 13 (`docCount={docs.length + 5}`). Fix: pass the step
  list (id, label, kind in graph order, from that workflow.yaml) in `RailData`, have `Rail`, `DocItem` and `Viewer` use
  it, and make the badge equal the rail's count. Extend the `several` test to assert that the By step view lists
  `implementation.json` and `wiki.json` and the label "Render report". If skipped: the user approves By step on a
  second workflow whose list is visibly incomplete, and the grouping bug can carry into 55-09.

### Minors
- m1 **The "Accept unavailable" state contradicts itself** (`resolve.tsx` `PanelHeader`, `GateGraph`). (a) The panel
  header always says "Escalated at Verify (grounded critic)", while the body, the strip and the sidebar say Validate
  synthesis (screenshot `resolve-side-no-accept-1440-light.jpg`). (b) The graph beside it shows the heal path
  (Validate decision → Patch or restart? → Escalate) instead of `v_synth → escalate`. (c) The header's "…" `RowMenu`
  offers "Accept the output as it is" and "Fix the output, then accept" enabled, while the card shows Accept disabled
  (L-106, the point of this state). `RowMenu` already supports `disabled` and `disabledReason`
  (`shared/ui/row-menu.tsx:10-12`). Fix: pass `noOutput` to `PanelHeader` and the graph. Disable the two menu items
  with `NO_OUTPUT_REASON`. Delete `ManualMenuList`'s `noOutput` branch, which no caller passes, or use it.
- m2 **The live-draft state leaves out `design_sections.json`, although its write count is set** (`documents.tsx`
  `liveDocs`). What: `liveDocs("draft_section", 4, {"design_sections.json": 3, …})` keeps only nodes up to
  `draft_section` in graph order. `advance_draft` comes later in the list, so the file is filtered out and the `3`
  never applies. A real run at workstream 4 has written it three times. Fix: include the nodes of the loop body, or
  list the live files explicitly.
- m3 **The loop-re-entry graph draws an edge that does not exist** (`graph.tsx` `GRAPH_CASES.loop`). What: it draws
  `heal → reassemble`. The real path is `heal → v_heal → heal_route → reassemble` (`technical-design-analysis/
  workflow.yaml:89-96`), yet the caption calls it "a slice of the real graph". Fix: add `v_heal` and `heal_route` (the
  gate state already uses them), or say in the caption that the slice skips them.
- m4 **The relaunch prefill differs from the real run's inputs** (`fixtures.ts` `RUN_INPUTS`). The real
  r-d5ed99071d49 inputs are `app_uuid "_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416"`,
  `spec_path …/feature-stage-artifacts/11/spec_snapshot.html`, `uxdesign_path …/11/ux_snapshot.html` and
  `comment ""`. The mockup has a different UUID, `…/features/6/spec.html`, `…/stages/ux/analysis.html` and `null`. Fix:
  copy the real values (the comment hint "Changed from empty" already matches `""`).
- m5 **Restart from a step (fork) says nothing about the stage binding** (`resolve.tsx` `RESULT.restart_from` and the
  confirm dialog). The relaunch result says the stage is rebound to the new run. The fork result says only "This run is
  unchanged and still waits here". The stage finalizers act only on the run currently bound to the stage (L-061,
  L-062). As drawn, the fork's document would never reach the Technical Design stage, and the original would wait at
  its gate with its bell notice unread until the user stops it. This is a user decision (see below), but the dialog and
  the result must state it either way. Fix: add one line, either "the stage is bound to the new run; this run ends
  Cancelled" or "the stage stays bound to this run; the new run's output does not move to the stage".
- m6 **The run's credit total disagrees with the tooltip in the Resolve states** (`resolve.tsx` `PanelHeader`
  tooltip vs `ResolvePlacementMock`). The tooltip says the chat is "Added to the run's total (42.21)", while the run
  header beside it shows 41.37 (`credits={CREDITS.run}`). The result frames do show `run + resolve`. Fix: show
  `CREDITS.run + chat` in the header once the chat has started, or drop "Added to the run's total" if 55-07 keeps them
  apart (F7: "shown on the run").

### Nits
- n1 The escalated run's header pill reads "Approval needed" (`statusMeta` for `awaiting_input:gate`) on an
  escalation. That is today's label, but 55-09 may want "Needs you" for an escalation gate, to match the bell notice.
- n2 "written N times · latest": with D9 only the latest write is kept, so "· latest" carries no information on its
  own. The tooltip already says it. Keep it only if the user wants the D8 "latest" mark visible.

## Known decisions not in the spec (my view; each goes to the user)
- **"written N times · latest"**: consistent with D9 (a count, no versions). See n2.
- **A gate edge lit in the warning colour**: D10's text says to light an edge only when its target is *running*, and
  a waiting gate is not running. The mockup is clearer this way, but it amends D10. 55-03's snapshot must then carry a
  "waiting" edge state. Recommend approving it, recorded as a decision.
- **On a loop re-entry, only the edge just taken is lit**: this is stricter than D10, under which every edge into a
  running node would light (e.g. `assemble → verify` too). It needs the snapshot to carry the last edge taken into each
  active node. Per-edge counts cannot give the order, so 55-03 must record transition order. Recommend approving it and
  adding it to 55-03.
- **Memory brief under Inputs, step "Run start"**: matches D8 (Inputs includes the memory brief).
- **System kept (collapsed) in By type**: matches D8 ("hidden by default").
- **Fork leaves the escalated run waiting at its gate**: this follows ADR-025 and D6 ("original untouched"), but it
  leaves the stage bound to the old run and the gate waiting forever (m5). The user should choose between "fork
  rebinds the stage and cancels the original, like relaunch" and "fork is exploratory; the stage stays bound".
- **Resolve credits shown separately on the panel**: fine under ADR-032 (metered, with provenance). The header total
  must agree (m6).
- **Bell links to `/runs/<id>/resolve`, marked read when the gate is answered**: a new route (55-09) and a
  notification write on gate answer (55-06/55-07). No objection; make sure 55-08/55-09 list them.
- **F6 payload and proposal field names are the mockup's**: stated in the fixture header (`fixtures.ts:10-11`).
  Acceptable.

## Not checked
- The probe at the final head: `p55-run2` predates the diff-wrap and caption edits. I opened only two of its
  screenshots and did not review the other 214 by eye.
- Dark theme by eye: the probe covers it, but I did not look at a dark screenshot.
- The user's live review of `/dev/phase-55` (the D8 gate). That is the user's step after the fixes.

## Verdict: NEEDS_CHANGES

Fix M1 (real tool-output split and rows) and M2 (per-workflow steps in the rail, plus a test) before the user reviews.
m1–m6 are small and should go in the same pass, since this page exists only for the user to approve. Then re-run
`node scripts/probes/phase55-mockups.mjs` at the final head and rebuild `web/static` in a separate commit (L-089).

---

## Re-run 1 — base c8f9b27, head 772980b2 (genesis-review, 2026-11-23)

Commits reviewed: d9f4509 (source: `documents.tsx`, `fixtures.ts`, `graph.tsx`, `resolve.tsx`, `phase55.test.tsx`;
+164/−59), c563ad8 (the Resolve thread's scroll reset, `resolve.tsx` only), and 640b037 / 772980b2 (web/static only:
`git diff --name-only c563ad89 772980b2 | grep -v ^web/static/` → 0). `genesis-ctx check --since c8f9b27` routes the
five source files to no area beyond the always-on release-ci and security; it lists no gates.

### Round-1 findings

- **M1 — fixed.** I re-read the real events from `genesis.db` (`immutable=1`; they are stored as `custom` rows with
  `data.type = tool_output.recorded`). The split is plan_sections 1, analyze_section 113, draft_section 8, synthesize 2,
  verify 1, which is exactly `TOOL_OUTPUT_BY_STEP` (`fixtures.ts:169-171`). Rows call_1..8, call_123 and call_125 match
  the real ref, tool, node and bytes one for one (call_6 `listApplicationObjects` 78 B, call_7 `listRecordTypes` 150 B,
  call_8 `getCustomDataType` 10500 B, call_123 `Creating synthesis.json` 144 B, call_125 `Creating verify.json` 141 B).
  The times are the real UTC times + 5:30 (for example call_1 at 12:33:50Z is 18:03:50). The new test "1. the
  tool-output split is the real run's" asserts the sum, the five steps and the call_6 shape. The "Show all" caption now
  prints the split only when `toolTotal` is the finished 125, so the live state's 92 no longer claims a wrong split
  (`documents.tsx:239-240`).
- **M2 — fixed.** `STORY_IMPL_STEPS` (`fixtures.ts:197-223`) matches all 25 nodes of
  `genesis-workflows/workflows/story-implementation/workflow.yaml:31-55` in order, with the same label and kind. The
  rail, `DocItem`, `ToolItem`, `StepGroup` and `Viewer` read the steps through `StepsCtx` (`documents.tsx:26-32`), and
  `DocumentsTabMock` provides `data.steps ?? STEPS`. A file whose node the workflow does not declare now goes to "Other
  files" (`documents.tsx:259-261`). The badge and the rail count both include System files. The probe screenshot
  `p55-final2/docs-states-several-1440-light.jpg` shows "Documents 11" and "11 files", "Render report" and "Prepare
  rollback doc" under the outputs, and "Load design + TD + story" under the inputs. The `several` test asserts
  `implementation.json`, `wiki.json`, `verify.json`, `rollback.md`, the labels, the absence of "Load spec + UX" and
  badge = rail. The preview text matches the real `r-fb5a9cd14f72/implementation-report.html` (`<h1>story-2-1 —
  Implementation Report</h1>`, "Objects changed: 3").
- **m1 — fixed.** The header reads "Escalated at Validate synthesis" when `noOutput` is set (`resolve.tsx:264`). The
  `RowMenu` items Accept and Fix are `disabled` with `disabledReason: NO_OUTPUT_REASON` (`resolve.tsx:272-276`).
  `GateGraph({ noOutput })` draws synthesize → v_synth (×3, back edge ×2) → escalate (waiting) → cleanup
  (`graph.tsx:305-315`). `ManualMenuList`'s unused branch is gone. The test asserts the header, the two
  `data-disabled` items and an enabled Stop. Screenshot `resolve-side-no-accept-1440-dark.jpg` shows the header, the
  graph and the body agreeing.
- **m2 — fixed.** `liveDocs` keeps any file named in `sofar` (`documents.tsx:504-505`), and `advance_draft` opens by
  default. The live-draft test asserts `design_sections.json` and "written 3 times · latest".
- **m3 — fixed** by the caption option: "Shortened: Heal → Re-assemble stands for Heal → Validate decision → Patch or
  restart? → Re-assemble" (`graph.tsx:184`).
- **m4 — fixed.** `RUN_INPUTS` equals `runs.inputs` for r-d5ed99071d49 field for field (app_uuid
  `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`, the two `feature-stage-artifacts/11/*_snapshot.html` paths,
  `comment: ""`).
- **m5 — fixed as asked.** The confirm dialog and the result both state that the stage stays bound to this run and that
  the new run's document does not move to the stage. The dialog marks it "To be chosen", so the decision stays with the
  user (`resolve.tsx:496-498, 530`).
- **m6 — fixed.** The run header shows `CREDITS.run + chat`, where chat is 0 for unopened/manual, 0.84 after the first
  turn and 0.84 + 1.37 while chatting (`resolve.tsx:373-374`). The test asserts 42.21 on first-turn; the dark
  screenshot shows 42.21 beside "This chat 0.84".
- **System files.** `r-d5ed99071d49` has no `_kiro/` (it ran on Kiro v2), so the fixture now uses three real v3
  shapes. I checked them in `~/Genesis/runs/agent-prompt/r-87781054aa00/_kiro/`: `settings/cli.json` 2 B,
  `logs/20261121T141109308/kiro.log` 35454 B, `sessions/738bdea751ff32d8/sess_3973bb01-…/messages.jsonl` 8594 B. Paths
  and sizes match. The times are moved onto the mockup run's clock, and the fixture comment says these are shapes from
  another run. That is honest, so L-083 holds.
- **c563ad8.** `el.scrollTop = state === "chatting" ? el.scrollHeight : 0` on a state change (`resolve.tsx:288-291`).
  The change is correct. See n4 for the missing test.
- n1 and n2 were left unchanged, as stated. They go to the user with the decisions list.

### Fail-first (checked by me)

I exported 772980b2's `web/` to `/tmp/55-02-rr1-ff` (node_modules symlinked, nothing in the repo touched) and swapped
single files back to c8f9b27:
- With the pre-fix `documents.tsx`, two tests fail: "3. Documents state live-draft" and "3. Documents state several".
- With the pre-fix `resolve.tsx`, five tests fail: side and tab first-turn, side and tab no-accept, and "result after
  restart_from".

Every fix that has a test has a test that fails without the fix. The M1 test is a data assertion. It fails on the old
fixture through the five-step list (1 + 116 + 8 also sums to 125, so the sum check alone would not have caught it).

### Checklist (delta only; round-1 answers stand for unchanged code)
- [OK] ADR-027 / ADR-055: the delta adds no raw palette class, hex or `rgb(`/`hsl(`. The new graph and menu use the
  existing `MiniGraph` and `RowMenu` (`disabled`/`disabledReason` per `shared/ui/row-menu.tsx:10-12`).
- [OK] ADR-028 / L-010: no `fetch(`, `/api` or `useQuery` is added.
- [OK] ADR-032: every new figure is a `CreditBadge`. The header total is the sum of two metered figures, and the
  tooltip's "Added to the run's total" is now true.
- [OK] ADR-011 / ADR-021 / ADR-025: the escalation gate stays the stopping point. The fork still seeds a new run and
  leaves the original untouched; the binding choice is flagged for the user.
- [N/A] ADR-019, 026, 029, 031, 033, 034, 045, 046, 047, 049, 061, 062, 063, 065, 068, 069, 074, 076, 077, 080–087: a
  dev-only stub page. No backend, nav, trust, Kiro launch, schedule, release or test-execution change.
- [OK] L-083: see M1, m4 and System files above; every value I sampled matches its real source.
- [OK] L-106: the no-accept menu is built from the run's state.
- [OK] L-089: 640b037 and 772980b2 hold web/static only. My out-of-tree `npx vite build --outDir /tmp/55-02-rr1-static`
  is identical to the committed `web/static` (`diff -rq`), and `git status --short` is empty at 772980b2.
- [OK] L-090: `/tmp/genesis-probes/p55-final2/result.json` was written at 00:02 on 2026-11-23, after the 772980b2 commit
  (23:59 on 2026-11-22). It has 216 entries; a scan for `page_hscroll`, `!tailwind_ok`, `overflow` or `clipped_text`
  finds 0. I looked at two of its screenshots (one light, one dark).
- [OK] L-014 / L-069 / L-123 / L-015: unchanged. jest-axe still runs on every frame, there is no `asChild` or `/<n>`
  token modifier in the delta, and the page is still its own lazy chunk (`Phase55Mockups-D-JW3yjZ.js`).
- [N/A] L-017, 025, 027, 030, 044, 045, 051, 056, 057, 087, 088, 092, 098–101, 104, 105, 111–113, 116, 117, 119, 125:
  no Python, CI, release, trust, registry or DB change.

### Gates (run by me at 772980b2)
- [OK] `npm run lint`: 0 errors, 20 warnings (baseline).
- [OK] `npm run typecheck`: clean.
- [OK] `npx vitest run`: 82 files, 948 passed (947 + the new M1 test).
- [OK] `npm run build` out of tree: identical to `web/static`.

### New findings (nits only)
- n3 **The no-accept graph shows Validate synthesis as "OK · check failed 3 times"** (`graph.tsx:309`). Today's Run
  Detail would show the same thing, because a validator that fails still completes its node. Side by side, though,
  "OK" and "failed" read as a contradiction, and this is the frame the user approves. Either use a warning tone for a
  validator whose last verdict failed, or record it as a 55-09 question. The same applies to `v_heal` in the gate
  state, if its decision led to escalate.
- n4 **c563ad8 has no regression test.** jsdom does no layout, but `scrollTop` can still be set and read. A test that
  renders `ResolveThread` as chatting, rerenders it as manual and asserts `scrollTop === 0` would pin the fix. This is
  a mockup, so it is optional.

### Not checked
- The other 214 probe screenshots by eye. I looked at `docs-states-several-1440-light` and
  `resolve-side-no-accept-1440-dark`.
- The live-draft and tool-metadata frames by eye. Their content is covered by tests and their layout by the probe JSON.
- The user's live review of `/dev/phase-55` (the D8 gate), and the decisions listed in round 1 (gate edge colour, the
  loop's last edge, the fork binding, the bell route), which still go to the user.

### Verdict: SHIP

M1, M2 and m1–m6 are fixed, and each fix is confirmed against the real data (genesis.db events and inputs, the
story-implementation workflow.yaml, the real run folders). Every fix with a test fails first without it. The gates
and the bundle are green, and the probe at the final head is clean. n3 and n4 are optional. The page is ready for the
user's review, together with n1, n2 and the decisions list from round 1.
