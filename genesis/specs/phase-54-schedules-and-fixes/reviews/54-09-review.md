# Review 54-09 — base 8f8b1a1, head b932136 (genesis-review, 2026-11-19)

What this change does: it adds current IANA zone names to the schedule zone picker (D42). It rebuilds
`GET /features/{id}/activity` as a paged merge of four sources: every stage's lifecycle, bound runs plus Test Design
top-ups, change requests from the CR store, and story finalization. It also adds `summary` and `run_status` to the
feature reads (D45 4). On the web it rebuilds the feature Overview and Activity tabs and the story Overview, Design,
Implementation and Verification tabs on the shared primitives, following the 54-03 mockup and D45.

Commits reviewed: `85fb749`, `1368d8c`, `a2b6c9d`, `6521608` and `b932136` (web/static). That is 5 commits; the brief
and As built say 6 (see N1). The review covers `git diff 8f8b1a1..b932136`.

## Gates (run by me)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` | All checks passed |
| full `pytest -q -p no:warnings` | **2094 passed** in 671 s, 21:20–21:31 IST (outside 00:00–02:00) |
| touched suites (`test_feature_activity`, `test_change_requests`, `test_cr_apply`, `test_cr_web_reads`, `test_metrics_api`) | 55 passed |
| `npm run lint` | 0 errors, 20 warnings (the old ones) |
| `npm run typecheck` | clean |
| `npx vitest run` | 81 files, **896 passed** |
| stale bundle: `npx vite build --outDir /tmp/5409-static` then `diff -r /tmp/5409-static web/static` | identical |
| live read on the probe server :8791: `GET …/cards/1/design/artifact?theme=dark&annotate=0` | 200, `text/html`, **no CSP, no nosniff** (M1) |

The probe evidence in `evidence/54-09/` was checked: `result.json` (no overflow, Objects changed columns unwrapped at
1280) and screenshots `story-design-1440-dark` (the frame takes the dark surface) and `story-implementation-1280-dark`.

## Checklist

ADRs
- [N/A] ADR-001 — no graph or orchestration change.
- [N/A] ADR-003 — no change to how the app runs.
- [N/A] ADR-007 — no role change.
- [N/A] ADR-008 — no change.
- [N/A] ADR-011 — no agent node.
- [OK] ADR-012 — the app process still imports no workflow code; `services/feature_activity.py` reads stores only.
- [N/A] ADR-013 — no config UI change.
- [N/A] ADR-019 — no CORE_MAJOR change.
- [OK] ADR-021 — D45 7: Re-run design now asks first (`StoryWorkspacePage.tsx` `ConfirmDialog` "Re-run the design?"); test "Re-run design asks first and then starts the run (D45 7)".
- [N/A] ADR-023 — no change.
- [OK] ADR-026 — no new listener or bind; the probe server is loopback.
- [OK] ADR-027 — the change reuses the shared Tabs, SectionCard, StatusHeader, Timeline, CategoryChips, DefinitionList and StatGrid. A grep of the revamped files for `/<n>` opacity modifiers, raw hex and `bg-white` found nothing. `frame-theme.ts` reads token values from `:root` (no raw colours).
- [OK] ADR-028 — `featuresApi.activity` goes through the client (`lib/api/features.ts:21`); no `/api` in components. The two `href`s that point at `/api/...` come from `workbenchApi.designArtifactUrl` and the server's `report_url`, as before.
- [N/A] ADR-029 — no trust change.
- [OK] ADR-030 — SQLite only; `TestDesignStore.live_case_count` is a plain query.
- [OK] ADR-031 — no chat change. M1 is a related risk: chat-authored HTML can run on the app origin.
- [OK] ADR-032 — credits come from `/runs/{id}/provenance` (`CreditBadge` with `credits_provenance`) and are never estimated; the screenshots show "n/a" for unavailable.
- [N/A] ADR-033 — no copilot change.
- [N/A] ADR-034 — no change.
- [N/A] ADR-035 — the test design start/rerun uploads are unchanged; only the response is wrapped.
- [N/A] ADR-037 — no KB change.
- [N/A] ADR-041 — no change.
- [OK] ADR-042 — spec authoring is unchanged.
- [N/A] ADR-043 — Lavish is unchanged (annotate=0 paths only).
- [OK] ADR-044 — the rolled-up feature status and badge are removed (D45 5); each stage shows its own status.
- [N/A] ADR-045 — no change.
- [N/A] ADR-046 — no change.
- [N/A] ADR-047 — no change.
- [N/A] ADR-049 — no nav change.
- [OK] ADR-050 — no new status writes. Activity reads only `lifecycle_transitions`. The recorded gap (writes outside `LifecycleService` leave no row) is pre-existing and listed in As built.
- [OK] ADR-055 — the work evolves the existing tokens and primitives; no MUI.
- [OK] ADR-056 — stages stay parallel; the "no stage gates another" text is removed, and prerequisites are shown as text.
- [N/A] ADR-057 — no change.
- [OK] ADR-058 — `overview.ts prerequisiteText` builds on `deriveAvailability` (in review or completed); `features.test.tsx` checks the texts.
- [N/A] ADR-059 — no change.
- [OK] ADR-060 — finalization is read only (an activity item).
- [OK] ADR-061 — "not on a board" counts read `on_board`; no change to membership.
- [OK] ADR-062 — Re-run design goes through `useStartDesign` behind a confirm, from the page and from the banner (test "the banner's Re-run goes through the same confirm").
- [N/A] ADR-063 — none.
- [N/A] ADR-064 — none.
- [N/A] ADR-065 — none.
- [N/A] ADR-067 — none.
- [OK] ADR-068 — Implementation is read only; no start or mutation is added.
- [N/A] ADR-069 — none.
- [N/A] ADR-070 — none.
- [OK] ADR-071 — still one story page; Verification moved from under every tab into its own tab on the same page.
- [N/A] ADR-072 — none.
- [N/A] ADR-073 — none.
- [N/A] ADR-074 — none.
- [N/A] ADR-075 — none.
- [OK] ADR-076 — CR items are read from the CR store; there are no CR writes.
- [OK] ADR-077 — the probe ran on a throwaway home; the fleet was not touched.
- [OK] ADR-078 — `live_case_count` excludes retired cases.
- [N/A] ADR-079 — none.
- [N/A] ADR-080 — no packaging change.
- [N/A] ADR-081 — none.
- [N/A] ADR-082 — none (the probe scripts are not test execution).
- [N/A] ADR-083 — none.
- [OK] ADR-084 — `defaultStoryTab` opens Verification in the verification lane; no lane-rule change.
- [OK] ADR-085 — the verification report keeps its sandbox and the reports-origin links (`VerificationSection.tsx` Report card unchanged in behaviour).
- [N/A] ADR-086 — no Kiro change.

Lessons
- [N/A] L-003 — no SSE change.
- [OK] L-004 — the data stays in SQLite.
- [OK] L-010 — see ADR-028.
- [OK] L-011 — `features/contract.test.ts` uses `Exact<>` key lists over `feature-activity.json` and `feature-detail.json`, which `tests/test_feature_activity.py` records from the real route.
- [N/A] L-012 — none.
- [OK] L-014 — jest-axe runs on every changed view: feature Overview and Activity (`features.test.tsx`, `observability.test.tsx`), story Overview, Design (running, failed, none, document), Implementation, the Verification tab and the banner (`StoryWorkspacePage.test.tsx:114,159,191–204,244,375`; `verification.test.tsx` layout test).
- [OK] L-015 — no new heavy dependency; `useInfiniteQuery` is already in TanStack.
- [N/A] L-017 — none.
- [N/A] L-018 — none.
- [N/A] L-019 — none.
- [OK] L-025 — ruff stays pinned (ran clean).
- [OK] L-027 — same.
- [OK] L-030 — web files changed, so the frontend job runs.
- [N/A] L-031 — none.
- [N/A] L-034 — none.
- [VIOLATION, minor] L-039 — the behaviour is right: `with_run_status` is used by `_with_badges`, `_out`, the CR `_spec_payload` (`stage_out=`) and the test design start/rerun. But only the detail, single-stage and spec GET reads are tested. See m1.
- [N/A] L-041 — none.
- [N/A] L-042 — none.
- [N/A] L-043 — none.
- [N/A] L-044 — none.
- [N/A] L-045 — none.
- [OK] L-048 — `web/static` is committed and fresh.
- [N/A] L-051 — none.
- [N/A] L-055 — none.
- [N/A] L-056 — no release yet.
- [N/A] L-057 — no release yet.
- [N/A] L-058 — none.
- [N/A] L-061 — none.
- [N/A] L-062 — none.
- [OK] L-063 — the prerequisite is shown on the card (Lock + text); start enforcement is unchanged.
- [N/A] L-064 — none.
- [N/A] L-068 — none.
- [OK] L-069 — no `Button asChild`; Edit / chat, Open in new tab and Open test report are `<a>` elements with `buttonVariants`.
- [N/A] L-071 — none.
- [N/A] L-072 — none.
- [N/A] L-073 — the story design reads `_current_design_html` (unchanged).
- [N/A] L-074 — none.
- [N/A] L-075 — none.
- [N/A] L-076 — none.
- [N/A] L-081 — none.
- [N/A] L-082 — none.
- [OK] L-083 — the fixtures are recorded from the real backend (`record("feature-activity", …)`, `record("feature-detail", …)`). The provenance MSW reply in `verification.test.tsx` mirrors `api/metrics.py`.
- [N/A] L-084 — none.
- [N/A] L-085 — none.
- [N/A] L-086 — none.
- [N/A] L-087 — none.
- [N/A] L-088 — none.
- [OK] L-089 — `b932136` holds only web/static, and my out-of-tree rebuild is identical.
- [OK] L-090 — the column floors come from the probe (`result.json` heads unwrapped at 1280/1440/1920), and `ObjectName` wraps at word boundaries.
- [N/A] L-091 — read-only endpoints.
- [OK] L-092 — no new `tests/__init__.py`; nothing named `test*` outside the tests.
- [N/A] L-093 — none.
- [OK] L-094 — all consumers of the retired `metricsApi.featureActivity`, `lib/api/metrics` `ActivityItem`/`FeatureActivity` and `cr-flow.activityText` are gone. A grep over `genesis/`, `web/src`, `packages/` and `genesis-workflows` finds no reader of the old `{feature_id, spec_id, activity}` shape, and the four backend tests were moved. All five writers of the sources are listed in the service docstring.
- [N/A] L-095 — none.
- [OK] L-096 — the activity route is the same path; the test design routes stay registered before the generic `/stages/{stage}` routes.
- [N/A] L-098 — none.
- [N/A] L-099 — none.
- [N/A] L-100 — none.
- [OK] L-101 — the probe script runs local tools; no bare `npx <bin>` against the registry.
- [N/A] L-103 — none.
- [N/A] L-104 — none.
- [N/A] L-105 — none.
- [OK] L-107 — no background job.
- [OK] L-109 — one helper (`with_run_status`) and one label builder (backend) serve every consumer; the web shows `label` as it comes.
- [OK] L-110 — I re-ran the gates myself at head (above).
- [OK] L-111 — no live acceptance claimed. The probe ran on seeded data only (Not checked).
- [N/A] L-112 — no release.
- [N/A] L-113 — none.
- [N/A] L-115 — none.
- [N/A] L-116 — none.
- [N/A] L-117 — none.
- [N/A] L-118 — none.
- [N/A] L-119 — none.

Gates listed by the check
- [OK] genesis pytest (2094 passed) and ruff.
- [OK] genesis/web lint, typecheck, test; build (stale-bundle diff identical).
- [N/A] playwright-appian lint/typecheck/test/build: that repo is unchanged. Only `scripts/probes/*` mapped to the area.
- [N/A] genesis-workflows validate_library and pytest: that repo is unchanged.

Points from the brief
- CR items from the CR store only, with the initiate/apply/discard audit rows dropped and labels kept — OK. See `_CR_ACTIONS` in `feature_activity.py` and `test_activity_labels_the_cr_transitions`: the `cr_label` values are unchanged, and the text "ram opened CR-01" is what `activityText` built before.
- Run items, with paused kept apart from gate — OK in Activity (`_RUN_WAIT`, `test_a_paused_run_is_paused_not_at_a_gate`) and in Needs attention (`waitsAtGate`). **Not OK in the Verification tab** (M2).
- `run_status` on every stage-row response — the code is OK; the tests are partial (m1).
- Re-run design gating and confirm, including the banner path — OK, with the tests above. The banner text is wrong in two cases (m2).
- Code review never says "Passed" — OK (`codeReviewState`; test "code review state comes from the lane and never says Passed").
- Frame theme (`frame-theme.ts`) — safe and faithful in the frame. The sheet's content comes only from the app's own computed token values, so nothing untrusted is injected. The frame has `allow-same-origin` with no `allow-scripts` (unchanged from base), and the iframe `src` carries `theme=`, so a theme change reloads the frame and `onLoad` re-applies the sheet. `story-design-1440-dark` shows the dark surface. `_DOC_STYLE`'s `.tag-*` and `pre` keep their own readable pairs. The new top-level "Open in new tab" path is not covered by any of this (M1).
- Tokens only, no opacity modifiers, no asChild — OK (grep above). The opacity modifiers in `VerificationSection.tsx` and `StoryTraceCards.tsx` were replaced.
- jest-axe and real-shape fixtures — OK.
- Retired types and helpers — OK (L-094 line).

## Findings

### Blockers
None.

### Majors

- M1 **"Open in new tab" runs agent-written design HTML as a top-level page on the app origin** (`web/src/features/workbench/StoryWorkspacePage.tsx:300`; served by `genesis/api/workbench.py:321-333`).
  - What: the new Design-document action links to `/api/workbench/boards/<app>/cards/<id>/design/artifact?annotate=0` with `target="_blank"`. That route returns the HTML as is, with no `Content-Security-Policy` and no `nosniff`. I confirmed this on :8791.
  - Problem: the HTML is agent-authored. `_current_design_html` serves the design chat's sandbox file `design.html` first; the chat agent writes that file directly and nothing sanitizes it. The workflow's `_sanitize_body` strips `<script>` but not `on*` attributes. A design containing `<img src=x onerror=…>` therefore runs on the app's origin as soon as the user clicks the link. From there it can call any `/api` route, including `…/implementation/start`, the write-capable lane. Every in-app frame of agent HTML avoids this: `sandbox="allow-scripts"` without same-origin elsewhere, and no scripts here. The verification report's own new-tab route is served with `script-src 'none'` for the same reason (51-15, `workbench.py:518`). A smaller issue on the same path: the new tab shows the light-only document in dark mode, because `frame-theme.ts` is not applied there.
  - Fix: when `annotate=0`, return the design HTML with `Content-Security-Policy: script-src 'none'; object-src 'none'` and `X-Content-Type-Options: nosniff`, as `story_verification_report` does. Add a backend test asserting the headers. Alternatively, drop the link, as D45 10 did for the Implementation report.
  - If skipped: Genesis gains its first path where agent-authored HTML runs scripts on the app origin.

- M2 **A paused verification run shows an empty "Waiting for your decision" card** (`web/src/features/workbench/VerificationSection.tsx:173` and the `waiting && runId` SectionCard below it).
  - What: `waiting = run_status.startsWith("awaiting_input")` is true for `awaiting_input:paused` as well as `:gate`. The diff now wraps `GatePanel` in an always-rendered warning `SectionCard` titled "Waiting for your decision".
  - Problem: a paused `story-verification` run has no pending gate, so `GatePanel` returns `null`. The page then shows a warning-bordered "Waiting for your decision" card with nothing in it. Before this diff the same case rendered nothing. This is the paused-vs-gate split the build fixed in Activity and Needs attention but not here.
  - Fix: `const waiting = !!runId && v.run_status === "awaiting_input:gate";` (reuse `waitsAtGate` from `features/overview.ts`, or move it to a shared place). Add a test with `awaiting_input:paused` that expects no "Waiting for your decision" region.

### Minors

- m1 **`run_status` on the CR and Test Design responses has no test** (`genesis/api/change_requests.py:50`, `genesis/api/features.py:1564` `stage_out=_out`, `genesis/api/testdesign.py:262-276`).
  - What: D45 4 and L-039 say every stage-row response carries `run_status`. `test_feature_detail_summary_and_run_status_on_every_stage_read` checks only `GET /features/{id}`, the single stage read and `GET …/spec`.
  - Case: deleting `stage_out=_out` at `features.py:1564`, or the `_with_run_status(...)` wraps in `testdesign.py`, keeps every test green.
  - Fix: in an existing CR test, assert `"run_status" in resp["spec"]` on one `_spec_payload` response (for example discard). In an existing Test Design start test, assert `"run_status" in resp["stage"]`.

- m2 **The design re-run banner gives the wrong instruction when the block is not the lane** (`StoryWorkspacePage.tsx`, `onBoard={!block}`; `StoryTraceCards.tsx:213`).
  - What: the banner's `onBoard` now means "no block". When it is false, the banner always says "Move the story into Design on its board to re-run the design."
  - Case: a story not on any board, or one with a design run in progress (`designRerunBlock` = "A design run is in progress."), gets "Move the story into Design on its board". That is wrong for both: the first has no board, and the second is already in Design.
  - Fix: pass `block` to the banner and show it as the reason, replacing the fixed sentence.

### Nits

- N1 The As built section and the brief say "6 local commits"; `git log 8f8b1a1..b932136` lists 5. Correct the count.
- N2 Activity paging uses `offset` over a newest-first list (`features/features/hooks.ts` `getNextPageParam`). If an item arrives between "Load more" clicks (a run finishes), the next page repeats the last item already shown. Item keys include the index, so nothing breaks. If it matters later, page by the oldest `at` seen instead of by offset.

## Not checked

- The Implementation report frame (`srcDoc`, `sandbox=""`) in dark mode. It sits below the fold in the probe screenshots, and the frame theme does not apply to it (opaque origin).
- `_spec_payload` and the Test Design start/rerun responses on the running probe server: these are mutation routes, and I made no mutations.
- Live acceptance on real runs (design re-run end to end, a real paused or gated verification).
- Keyboard-only navigation of the new Tabs and SegmentedControl beyond what jest-axe and RTL cover.

## Verdict: NEEDS_CHANGES

Fix M1 (CSP and nosniff on the `annotate=0` design artifact response, with a test, or remove the link) and M2 (gate-only
`waiting`, with a paused test). m1 and m2 are small and belong in the same pass. Everything else checked out: the
gates are green and the bundle is fresh.

---

# Re-run 1 — base b932136, head 2ad1c50 (genesis-review, 2026-11-19)

Commits reviewed: `0298731` (the fixes: 9 files, +64 −10) and `2ad1c50` (web/static only: `git show --stat 2ad1c50`
lists 64 files, all under `web/static`). The review covers `git diff b932136..2ad1c50`.

## Gates (run by me at 2ad1c50)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` | All checks passed |
| full `pytest -q -p no:warnings` | **2095 passed** in 708 s, finished 21:57 IST (outside 00:00–02:00); round 1 was 2094, plus the new M1 test |
| touched suites (`test_feature_activity`, `test_cr_web_reads`, `test_test_design_api`, `test_change_requests`, `test_cr_apply`, `test_metrics_api`) | 93 passed |
| `npm run lint` | 0 errors, 20 warnings (the old ones) |
| `npm run typecheck` | clean |
| `npx vitest run` | 81 files, **897 passed** |
| stale bundle: `npx vite build --outDir /tmp/5409r2-static` then `diff -r /tmp/5409r2-static web/static` | identical; `git status` clean |
| live read on :8791: `GET …/cards/1/design/artifact?theme=dark&annotate=0` | 200, `text/html`, `content-security-policy: script-src 'none'; object-src 'none'`, `x-content-type-options: nosniff` |

Fail-first, checked by me: I extracted the head tree to `/tmp/r5409b` with `git archive 2ad1c50` and put back the
b932136 versions of `genesis/api/workbench.py`, `VerificationSection.tsx`, `StoryTraceCards.tsx` and
`StoryWorkspacePage.tsx`, keeping the new tests. I confirmed the import resolved to `/private/tmp/r5409b/genesis/api/workbench.py`.
- `tests/test_feature_activity.py::test_read_only_design_artifact_runs_no_script`: **FAILED** on the old route.
- `verification.test.tsx` "a paused run shows no decision card": **FAILED** on the old code.
- `StoryWorkspacePage.test.tsx` "Re-run design is disabled with the reason when not on a board" and "… when past
  design review", and "Design tab: the re-run banner re-runs the design (on a board) or explains how": **FAILED** on the old code.
- All of them pass at head (the full vitest run above).

Probe evidence, re-run at 21:41 (`evidence/54-09/result.json` and the screenshots): 54 views, no `overflow`, no page
horizontal scroll. In all six story-design views `frame_bg` equals `surface` (light `rgb(255,255,255)`, dark
`rgb(18,21,28)`). `story-design-1440-dark.jpg` shows the document themed dark inside the frame under the new CSP. This
works because `applyFrameTheme` runs in the parent document and inserts a `<style>`, and the CSP restricts only scripts.

## Round-1 findings

- **M1 — fixed.** `workbench.py:330-338`: when `annotate=0`, the route returns the HTML with the same two headers as
  `story_verification_report`. Both consumers use `annotate=0`: the Design tab frame (`StoryWorkspacePage.tsx:280`) and
  "Open in new tab" (`:300`). The annotate=1 path, used by the design chat (`StoryDesignWorkspace.tsx:82` through
  `AnnotatablePreviewDialog`, `sandbox="allow-scripts"` without same-origin), still loads the SDK. The test pins
  this too (`design-sdk.js` is present and there is no CSP header). The test fixture writes an
  `<img onerror=…>` design, which is the concrete case from round 1. The no-HTML placeholder path has no CSP, but it
  serves only program-generated HTML, so that is fine.
- **M2 — fixed.** `VerificationSection.tsx:174-175` sets `waiting = !!runId && waitsAtGate(v.run_status)`, using the
  shared `overview.ts:26` helper (`=== "awaiting_input:gate"`). The test asserts that no "Waiting for your decision"
  region is rendered for `awaiting_input:paused`. The existing gate test still passes.
- **m1 — fixed.** `test_cr_web_reads.py:55-57` asserts `spec.run_status is None` on the discard `_spec_payload`.
  `test_test_design_api.py:132,137` asserts `"run_status" in out["stage"]` on start and on rerun.
- **m2 — fixed.** `DesignRerunBanner` takes `block` (`StoryTraceCards.tsx:203-220`) and shows it as the reason. It
  shows the Re-run button only when `block` is null. The caller passes `designRerunBlock`'s value
  (`StoryWorkspacePage.tsx:295`). The tests check the "not on a board" and "past design review" reasons, and that no
  button is shown inside the banner.
- **N1 — still open (accepted).** `54-09-ux-revamps.md:91` still says "6 local commits". After this round there are
  7: the 5 from round 1, then `0298731` and `2ad1c50`. The dev said the As built will be corrected. This does not block.
- **N2 — accepted as a known limit.** No code change, and none expected. It still needs to be recorded in the As built
  or the backlog.

## Checklist changes since round 1

- L-039: was VIOLATION (minor), now **OK**. Every `with_run_status` consumer named in m1 has a test assertion.
- ADR-031 / security: **OK**. Agent-authored design HTML no longer runs script anywhere on the app origin.
- ADR-043: still **N/A**. The Lavish path is unchanged and pinned by the new test.
- ADR-028, L-014, L-083, L-089 (`2ad1c50` is web/static only, and my rebuild is identical), L-094 (both banner callers
  pass `block`, and grep finds no remaining `onBoard=` use), L-110: **OK**, with the evidence above.
- All other lines are unchanged from round 1. The fix diff touches no other area.

## New findings

None. The fix diff is small and does what the brief says.

## Not checked

- Live acceptance on real runs: a real paused or gated `story-verification`, and a design re-run end to end. The probe
  used seeded data only.
- The Implementation report frame in dark mode (as in round 1).
- Opening the `annotate=1` URL by hand in a top-level tab. No UI links to it, it was already like that before this
  diff, and it is out of scope.

## Verdict: SHIP

M1, M2, m1 and m2 are fixed. Each has a test, and I saw each test fail on the old code. The gates are green at
2ad1c50 and the bundle is fresh. Still to do in the docs: correct the commit count in the As built (N1, now 7) and
record N2 as a known limit.
