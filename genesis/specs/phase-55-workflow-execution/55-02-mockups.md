# 55-02 — Mockups: Documents tab, Resolve panel and run graph states, approved before the build

> **Status:** BUILT 2026-11-22 (genesis `7f32ac0..d0aa1b2`; review SHIP; user review D12–D15; shipped in v0.84.0). SPEC-DRAFTED 2026-11-22. Repo: genesis (`web/src/dev/`). Parent: `specs/phase-55-workflow-execution.md`.
> Built by **genesis-dev**. **Gate (D8):** the user reviews `/dev/phase-55` in the browser; the web parts of 55-03 and
> all of 55-09 do not start until the user approves (55-03's backend may start). Each change the user asks for is
> recorded as a decision in `55-01-findings.md` §9 and folded into 55-03 / 55-09 by the spec agent before they start.

## 1. What to build

One route `/dev/phase-55`, lazy-loaded like `/dev/phase-54` (`web/src/app/router.tsx:40,119`), under
`web/src/dev/mockups/phase55/`. A page of sections with a jump list, light and dark theme, **stub data only** (no API
calls), built only from the shared primitives and design tokens (ADR-027, ADR-055; no raw palette colours, no
opacity modifiers on token colours, L-123; no `Button asChild`, L-069). Each section is drawn inside a frame that looks
like Run Detail (header, tabs Flow · Documents · …), so the user judges it in place.

**Stub data uses real shapes (L-083):** file names, steps and counts from the real runs in `55-01-findings.md` §4.2
(e.g. `technical-design-analysis` r-d5ed99071d49: 31 files, steps `load_inputs`, `plan_sections`, `assemble`,
`verify`, `heal`; `_prompts/<node>-p<pass>-a<attempt>-<ms>.txt`; `tool_output.recorded` with tool names such as
`getRecordType`); gate payloads with the F6 fields; memory ids and texts shaped like `memory.db` rows (§2.1); run
statuses from `statusMeta`; credits with provenance.

## 2. Surfaces

1. **Documents tab — By step (default view, D8).** Left: search, the By step / By type toggle, then the groups:
   **Output** (pinned, auto-selected; label from META, e.g. "Technical design document", the file name under it),
   **Inputs** (uploaded, built from input, memory brief), **Steps** in graph order (each step collapsible: its files
   with a pass/fail mark on checks such as `verify.json`, and "Prompts (n)"), **Tool outputs (n)** (tool, step, size,
   time), **System** (collapsed, "show"). Each row: label, file name, step, written time (relative; exact on hover),
   size, **write count** ("written 3 times", D9), latest mark. Right: the viewer with its header (category badge, step
   · pass · attempt, written time, size, write count, Open in step, Download) and the existing preview.
2. **Documents tab — By type.** Flat sections Output · Inputs · Intermediate · Checks · Prompts · Tool outputs.
3. **Documents states:** a live run (a file being written: empty placeholder "being written by `assemble`", the
   Output group showing "not produced yet"); a finished run whose tool outputs are metadata only ("files removed at the
   end of the run", D9); an old run (no write records: "step unknown", name-rule categories, a one-line note); a run
   with no output (failed early); a workflow with several outputs (story-implementation: report + rollback).
4. **Resolve panel (D7).** Where it sits in Run Detail (a side panel beside the graph, or a Resolve tab; show both and
   let the user choose). States:
   - escalated, not opened yet: a summary strip (failed step, reason in one line, "Open Resolve");
   - the agent's first turn: what went wrong (failed step, validator messages, retry and heal history), the files that
     exist (linking into Documents), and **proposal cards** — one per suggested action, with its parameters (the
     guidance text, the input changes, the step to restart from, the file diff for fix-then-accept) and Confirm /
     Dismiss;
   - the user chatting (composer, a follow-up proposal replacing an earlier one);
   - a **manual action menu** (the six actions without the agent) with the same confirm dialogs;
   - the confirm dialog for each action (stop asks for a reason; relaunch shows the input form prefilled; fix-then-accept
     shows the diff);
   - after each action: retry running, accepted → done + "moved to the feature stage", relaunched → link to the new run,
     forked → link, stopped → failed with reason;
   - Accept unavailable (output missing or empty, L-106) shown disabled with the reason;
   - credits of the Resolve conversation on the panel (metered, provenance).
5. **Bell notification** for an escalation ("needs you", run name, failed step, link to the Resolve panel).
6. **Run graph states (D10):** a program node running (no agent events), an agent node running for minutes (elapsed
   time on the node), a loop re-entry (a node that was ok running again, round 2 of 3), waiting at the escalation gate,
   paused, done, failed; the edge into the running node lit and no other; the Live badge connected / reconnecting /
   polling; the Refresh control.

## 3. Review with the user

The dev opens each section at 1280 / 1440 / 1920 px, light and dark, in a real browser (L-090) and attaches
screenshots to As built. The user then reviews live. Record the verdict per surface (approved / changes) in As built;
changes go to 55-01 §9 as new decisions.

## 4. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test` (a smoke render of the route and a jest-axe check of
each section, L-014); `npm run build`, then commit `web/static/` as a separate step (L-089).

## Context manifest

```toml
areas    = ["web-runs", "web-shell"]
adrs     = ["ADR-027", "ADR-055", "ADR-066", "ADR-009"]
lessons  = ["L-014", "L-069", "L-083", "L-089", "L-090", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md"]
code     = ["genesis/web/src/dev/mockups/**", "genesis/web/src/app/router.tsx"]
upstream = []
```

## As built

**Status:** BUILT 2026-11-22, review **SHIP** (re-run 1). **User's D8 review done 2026-11-23: approved with one
change** (Rerun from the start, revised in `09fd371`), and the user's two choices (Resolve as a tab; a fork rebinds
the stage and cancels the original), applied in `7495448`/`1778a50`. Next: the spec agent records the change and the
choices in 55-01 §9 and folds them into 55-03/55-06/55-08/55-09 before the web parts of 55-03 and 55-09 start. Repo
genesis, branch master, base `7f32ac0`, head `d0aa1b2`, 12 local commits (not pushed, not tagged). Source: 12 files under `web/src/dev/mockups/phase55/` plus the
router, a one-word export change in the Phase 54 mockup, and a probe script. No app page changed.

### Commits (genesis)

| sha | what |
|---|---|
| `4ef2694` | `/dev/phase-55` (lazy chunk) with all six surfaces; stub data; tests; probe `scripts/probes/phase55-mockups.mjs` |
| `c8f9b27` | `web/static` for 4ef2694 (73 files) |
| `d9f4509` | review round 1: M1, M2, m1–m6, real v3 system-file shapes, regression tests |
| `640b037` | `web/static` for d9f4509 (68 files) |
| `c563ad8` | the Resolve thread starts at the top on a state switch |
| `772980b` | `web/static` for c563ad8 (66 files) |
| `09fd371` | the user's D8 change: Rerun from the start takes this run's inputs unchanged and asks only for additional instructions for every agent step |
| `d914111` | `web/static` for 09fd371 (67 files) |
| `7495448` | the user's choices: Resolve is a Run Detail tab (the side-panel option removed); Restart from a step binds the stage to the new run and cancels this run |
| `a7305db` | `web/static` for 7495448 (68 files) |
| `1778a50` | the action results show inside the Resolve tab |
| `d0aa1b2` | `web/static` for 1778a50 (66 files) |

Bundle proof (L-089): I checked each bundle commit with `git show --stat <sha> -- web/static` in its own call after the
build had exited. Each time, a rebuild in a later call left `git status --short --untracked-files=all` empty. The
reviewer's out-of-tree build matched `web/static` at `c8f9b27` and at `772980b`.

### Changed

- `web/src/app/router.tsx`: `{ path: "/dev/phase-55", element: <Phase55Mockups /> }` beside `/dev/phase-54`, through
  `React.lazy`, so it is its own chunk (`Phase55Mockups-*.js`, L-015).
- `web/src/dev/mockups/phase54/bell-chat.tsx`: `NotificationPanel` and `BellButton` are now exported, so the
  escalation notice reuses the approved bell panel instead of copying it.
- `web/src/dev/mockups/phase55/`:
  - `Phase55Mockups.tsx`: sticky header, jump list, and a theme button that sets the app theme, so portalled menus and
    popovers follow it (54-03 decision 1). It also holds the pickers for the Documents state, the Resolve placement
    and state, the confirm dialog and the result.
  - `frame.tsx`: `RunFrame`, a Run Detail lookalike (header with status, duration, credits, Live badge and Refresh,
    plus a picture of the tab strip), `LiveBadge` and `RefreshControl`. It re-exports `MockSection`, `MockFrame` and
    `DialogFrame` from the Phase 54 mockup.
  - `options.ts`: the picker lists and `LIVE_META`.
  - `fixtures.ts`, `documents.tsx` (surfaces 1–3), `resolve.tsx` (4), `bell.tsx` (5), `graph.tsx` (6),
    `phase55.test.tsx`.
- `scripts/probes/phase55-mockups.mjs`: the width/theme probe, built on `phase54-mockups.mjs`. It covers every section
  and variant plus three portals. It checks page sideways scroll, element overflow per frame, and badges or buttons
  whose text wraps (measured by the line rects of a Range).

Stub data (L-083; the reviewer checked it against the sources):
- **technical-design-analysis r-d5ed99071d49:**
  - its 31 files, with real sizes and write times shifted so the run ended two hours before page load;
  - its 19 real `_prompts/<node>-p<pass>-a<attempt>-<ms>.txt` names;
  - its 8 workstreams;
  - its node ids and labels from `workflow.yaml`;
  - its 125 `tool_output.recorded` events: the real split (plan 1, analyze 113, draft 8, synthesize 2, verify 1) and
    real rows call_1–8, call_123 and call_125.
- **Memory brief:** memories #40, #13 (shared) and #9 (personal) from `memory.db`.
- **story-implementation r-fb5a9cd14f72:** its real outputs (`implementation-report.html` 1624 B, `rollback.md`
  6368 B), its inputs, and its own 25 steps from its `workflow.yaml`.
- **Old run:** ux-design-analysis r-d945d439d221's real files.
- **System files:** real v3 `_kiro/` shapes from agent-prompt r-87781054aa00. The v2 run above has no system files.
- **VerificationReport fixes:** the real shape from its graph.py, `{target_id, issue, reason, evidence,
  suggested_change, severity}`. The fix texts themselves are made up.
- **Gate payload:** today's fields plus F6. The F6 field names are the mockup's; 55-06/55-07 own the real ones.

What each surface shows:
1. **By step:** Output pinned and selected; Inputs (three built from the inputs, plus the memory brief at "Run
   start"); Steps in graph order, each a collapsible group of its files and "Prompts (n)"; Tool outputs (125), collapsed;
   System, collapsed. A row shows label, file name, step, relative time (exact on hover), size, "written N times ·
   latest" and a Passed/Failed mark on a check. The viewer header shows the category badge, step · pass · attempt,
   item, written, size, writes, Open in step and Download. Search filters the list.
2. **By type:** Output, Inputs, Intermediate, Checks, Prompts, Tool outputs, with System collapsed.
3. **States:**
   - a live run at Draft design ("Not produced yet. Assemble document writes it…", with write counts so far);
   - a live run at Assemble ("being written by assemble", a zero-byte placeholder);
   - a finished run's tool output ("The file was removed at the end of the run"; the record stays);
   - an old run (a one-line note, "Step unknown", name-rule categories, an "Other files" group);
   - no output (failed at Resolve inputs);
   - several outputs (story-implementation: report and rollback, its own step labels).
4. **Resolve:** placement **A** (a side panel beside the graph on Flow) and **B** (a Resolve tab with a facts
   sidebar), each in 5 states:
   - escalated, not opened: a strip with "Open Resolve";
   - the agent's first turn: what went wrong, the critic's fixes, the retry and heal history, file chips into
     Documents, and proposal cards "Fix the output, then accept" (with a diff) and "Retry with guidance", each with
     Confirm… and Dismiss;
   - chatting: the earlier card struck through as "replaced by the newer suggestion below", a follow-up card and the
     composer;
   - without the agent: the six actions, no credits;
   - Accept unavailable (L-106): the card and the "…" menu disabled with the reason, and a header and graph that
     match.

   Also: the confirm dialog of each of the six actions (guidance; the accept consequences; the diff; relaunch with
   the real inputs prefilled; the step picker; a required stop reason) and the result of each. Credits: "This chat"
   on the panel (metered), and the run header total includes the chat.
5. **Bell:** a needs-you notice ("Technical Design Analysis needs you", naming the failed step), linking to
   `/runs/r-3f9a62c1e7b4/resolve`, shown beside two older read notices in the Phase 54 panel.
6. **Graph:** 7 states on slices of the real graph:
   - a program step running;
   - an agent step running 12 min, with a ticking clock;
   - a loop re-entry, Verify "round 2 of 3";
   - at the escalation gate;
   - paused;
   - done;
   - failed (turn_timeout, partial credits).

   Only the edge just taken into a running or waiting step is lit. Also shown: the four Live badge states (Live,
   Reconnecting, Polling every 3 s, Finished) and Refresh with "Updated 2 s ago".

### Tests

- `src/dev/mockups/phase55/phase55.test.tsx` (42 tests):
  - the route smoke render through `createMemoryRouter(router.routes)` at `/dev/phase-55` (h1, a jump list of 6, all
    6 headings and ids);
  - jest-axe on every `[data-mock-frame]` (all rules), then on the whole render with `landmark-unique` off (54-03
    decision 2), for every Documents state, all 10 placement × state pairs, each dialog, each result, the bell and the
    graph states;
  - content checks: Output pinned and selected; steps in graph order; write counts; Prompts (8) ×2; System collapsed;
    search; the real 31 + 1 files and prompt-name pattern; the real tool split (M1); By type sections; each state's
    text; the several-outputs groups, labels and badge = rail count (M2); live write counts (m2); proposals with
    Confirm/Dismiss; the replaced card; six manual actions; Accept disabled with its reason, and header and menu
    agreeing (m1); the run total 42.21 (m6); dialog fields; result wording (m5); the bell link; exactly one lit edge,
    into the expected node, per graph state (`reassemble->verify` on the loop).
- Fail-first: with the pre-fix `documents.tsx`, the live-draft and several tests fail. The reviewer also showed that
  with the pre-fix `resolve.tsx`, 5 tests fail.
- D8 change (`09fd371`): the relaunch dialog test now asserts one textbox, "Additional instructions for the new run",
  its "every agent step" hint and no input fields; it fails on the previous dialog.
- D8 choices (`7495448`): the Resolve test runs once per state on the tab (5 tests; the 5 side-panel ones are gone)
  and asserts the Resolve tab; the fork dialog and result tests assert the rebinding and the cancel.
- Gates at `1778a50`: lint 0 errors / 20 warnings (baseline); typecheck clean; `npm test` 82 files / **943 passed**
  (37 in `phase55.test.tsx`).
- Gates at `09fd371`:
  - `npm run lint`: 0 errors, 20 warnings, the baseline count; none in new files.
  - `npm run typecheck`: clean.
  - `npm test`: 82 files, **948 passed** (906 at v0.83.0).

### Screenshots (real browser, L-090)

`node scripts/probes/phase55-mockups.mjs` starts Vite from `web/` (cwd `web/`). It checks that the frames'
`border-dashed` resolves, then shoots each section, variant and portal at 1280 / 1440 / 1920 px in light and dark.
The final run at `c563ad8` (the source of `772980b`) gave **216 entries, all clean**. One earlier run flagged a false
"wraps" from a height-based check; the check now uses line rects. Visual fixes made from the screenshots:
- graph nodes clipped their second line: taller nodes, with the metrics moved off the pill row;
- a "via" edge note overlapped its count;
- diff lines were cut off in the side panel: they wrap now;
- the chat did not open on its newest turn.

Re-run after the D8 change and choices, at `1778a50` (the source of `d0aa1b2`): **186 entries, all clean** (the side
panel is gone, so 30 fewer). The folder below holds that run only; the side-panel screenshots are in project-tracker
history at `a1f7448`.

Folder: `specs/phase-55-workflow-execution/evidence/55-02/` (15 MB, JPEG q70, plus `result.json`). Names are
`<name>-<width>-<theme>.jpg`:

| surface | names |
|---|---|
| 1 By step | `docs-by-step` |
| 2 By type | `docs-by-type` |
| 3 States | `docs-states-live-draft`, `-live-assemble`, `-tool-metadata`, `-old-run`, `-no-output`, `-several` (plus `docs-states`) |
| 4 Resolve | `resolve-tab-<state>` (state ∈ unopened, first-turn, chatting, manual, no-accept); `resolve-dialog-<action>`, `resolve-result-<action>` (action ∈ retry, accept, fix_accept, relaunch, restart_from, stop); `portal-resolve-menu`, `portal-step-picker` |
| 5 Bell | `bell`, `portal-bell-popover` |
| 6 Graph | `graph-states` (all 7 states, the Live badges and Refresh) |

### Review

`specs/phase-55-workflow-execution/reviews/55-02-review.md`.
- **Round 1: NEEDS_CHANGES.**
  - M1: tool-output rows and split partly invented (L-083).
  - M2: the several-outputs rail used technical-design-analysis's steps, so two files were in no group and the
    labels were wrong.
  - m1: the Accept-unavailable header, graph and menu contradicted the body.
  - m2: a live write count was never shown.
  - m3: the loop slice drew a non-existent edge.
  - m4: the relaunch inputs were not the real ones.
  - m5: the fork said nothing about the stage binding.
  - m6: the header total disagreed with the chat tooltip.
  - n1, n2 (nits).
- Fixed in `d9f4509`/`640b037`, plus `c563ad8`/`772980b` (scroll).
- **Re-run 1: SHIP.** Every fix was checked against genesis.db, the workflow.yaml files and the run folders. New
  optional nits: n3 (below, for the user) and n4 (no test for the scroll reset; not added, since a mockup scroll is not
  behaviour 55-09 inherits).

### Decisions / deviations

No ADR deviation. Choices the spec did not cover; each is for the user to confirm in the D8 review:
1. **"Latest" mark as "written N times · latest"** (D9 keeps no versions). The tooltip says earlier writes are not
   kept. The reviewer notes "· latest" adds little (n2); drop it if you prefer.
2. **The edge into a waiting gate is lit in the warning colour.** D10 lights only edges into a *running* node. If
   approved, 55-03's snapshot needs a "waiting" edge state.
3. **On a loop re-entry only the edge just taken is lit** (`reassemble → verify`, not `assemble → verify`). Stricter
   than D10. 55-03 must then record the order of transitions; counts alone cannot give it.
4. **Restart from a step (fork) keeps the stage bound to the escalated run**, which stays at its gate (ADR-025,
   original untouched). The new run's document does not reach the stage. The alternative: bind the stage to the new
   run and cancel the original, like Rerun. The dialog says "To be chosen". **Needs your choice.**
5. **The memory brief is listed under Inputs** with the step "Run start (before the first step)".
6. **System is kept, collapsed, in By type too.**
7. **Resolve credits are shown on the panel ("This chat"), and the run header total includes them** (F7).
8. **The bell notice links to `/runs/<id>/resolve`** (a new route for 55-09). Opening the notice does not start the
   agent; opening Resolve does. The notice is marked read when the gate is answered (a write for 55-06/55-07).
9. **Placements:** both A (side panel) and B (tab) are built with all five states; the dialogs and results are shared
   by both. **Needs your choice.**
10. **The proposal and F6 payload field names are the mockup's.**
11. **Graph drawn statically** (SVG plus node cards, no React Flow) so seven states show side by side.
12. **Open nits for your view:**
    - n1: an escalation gate's run pill reads "Approval needed" (today's `statusMeta`); 55-09 may want "Needs you".
    - n3: a validator whose check failed shows "OK · check failed 3 times", because its node did complete.

### Lesson candidates

1. **A mockup's step labels must come from the run's own workflow.** One shared step list silently drops the files of
   steps it lacks and mislabels the rest (review M2). Never drop a file whose step is unknown: give it an "Other files"
   group.
2. **"Real data" in a fixture header is a claim to verify field by field.** The first five tool rows were real, the
   next three were not, and the per-step split hid two steps (M1). Copy from the source with a query; don't type it
   from memory.
3. **A height-based "text wraps" check gives false positives on fixed-height buttons.** Count the line rects of a
   Range over the element instead.

### Code-map changes (for genesis-docs, bible/03)

- `web/src/app/router.tsx`: `/dev/phase-55` (lazy).
- `web/src/dev/mockups/phase55/**`: the Phase 55 mockups (dev-only).
- `web/src/dev/mockups/phase54/bell-chat.tsx`: exports `NotificationPanel` and `BellButton`.
- `scripts/probes/phase55-mockups.mjs`: the mockup width/theme probe.

### User review (D8): per surface

The user's review, 2026-11-23 ("Everything looks good. One change…"). The change is for the spec agent to record in
55-01 §9 and fold into the sub-specs in the last column.

| # | surface | verdict | changes (→ sub-spec) |
|---|---|---|---|
| 1 | Documents tab, By step | approved | — |
| 2 | Documents tab, By type | approved | — |
| 3 | Documents states | approved | — |
| 4 | Resolve panel, dialogs, results | changes | **Rerun from the start** no longer shows the run's inputs: the new run takes every input from the escalated run (feature id, stage id and the rest) unchanged, and the user only gives **additional instructions**, which are passed to every agent node of the new run. The action is renamed "Rerun from the start with additional instructions". This amends D6 action 4 ("with changed inputs") and F9 (`POST /runs/{id}/relaunch {inputs}` → `{instructions}`); 55-06 must define how the instructions reach every agent node's prompt (likely beside the F4 prompt line in `kiro_node`) and that they persist for the new run's resume and fork (→ 55-06, 55-08, 55-09). Revised in `09fd371`. |
| 5 | Escalation in the bell | approved | — |
| 6 | Run graph states | approved | — |

Decisions 1–3, 5–8 and 10–12 above are taken as approved with the page ("Everything looks good"). The user's answers to
the two open ones (2026-11-23, "my choices 1. B 2. bind the stage to the new run and cancel the old one"):

| decision | choice (→ sub-spec) |
|---|---|
| 9 Placement | **B, a Resolve tab** in Run Detail beside Flow and Documents, with the facts sidebar; the side panel was removed from the mockup in `7495448`. The results of the actions show in that tab (`1778a50`). D7 "a Resolve panel … beside the graph and Documents" reads as this tab (→ 55-09). |
| 4 Fork | **Restart from an earlier step binds the stage (or story) to the new run and cancels the escalated run**, which links to it, like Rerun. This amends D6 action 5 ("`RunManager.fork`; original untouched"): the fork still seeds a new thread from the checkpoint (ADR-025 holds, the original's checkpoints are untouched) but the original run then ends `cancelled` through the stop-intent + CAS path, and the stage/story binding moves to the new run before it starts (L-061, L-108; → 55-06, 55-08, 55-09). |
