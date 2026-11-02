# 51-09 — Story verification: lane order, the Verification lane and `story-verification`

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (backend), **genesis-workflows** (`story-verification`
> v0.1.0). Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D3, D5, D6, D7, D8, D10, D12, D14; F2,
> F7, F10.

## 1. Goal

Deployment moves before Verification; dragging a card from Deployment into Verification runs an agent workflow that
explores the story's screens as each affected role, authors case scripts from the library, runs them on QA, triages
failures, moves the card to Done or back to Implementation, proposes library and regression updates, and writes a
report.

## 2. Lane order and transitions (D6, D7)

- `STORY_LANES` (`genesis/genesis/domain/transitions.py:124-127`) becomes `… CODE_REVIEW, DEPLOYMENT, VERIFICATION,
  DONE`. `STORY_STAGE_TRANSITIONS` (`:105-120`): replace `(code-review, approve) → verification`, `(verification,
  verify) → deployment`, `(deployment, deployed) → done` with `(code-review, approve) → deployment`, `(deployment,
  deployed) → verification`, `(verification, verify) → done`; keep `(verification, reject) → implementation`.
- **Every consumer of the lane order** (L-094): `kb/boards.py:30` (`LANE_VALUES`, order from `STORY_LANES`), the board
  API's `lanes`, `web/src/features/workbench/lanes.ts` (labels; order comes from the API), `web/src/types/workbench.ts`,
  `web/src/features/workbench/story-view.ts:7` (`IMPL_LANES` is a set — order-free, keep), workbench tests that assert
  the old order, the collaboration board publish/pull (lane values unchanged, so no Hub change; verify a pulled card in
  `deployment` still renders). Grep again at build time and list every hit in the As built.
- Deployment stays a manual lane (D7): no automation.

## 3. Launch: `POST …/cards/{story_id}/verification/start` (mirrors `start_implementation`, `api/workbench.py:290`)

Fail-fast 409s: run manager present; card on the board; **no QA environment → the F2 warning** (card stays in
Deployment); `readiness(app_uuid)` (51-05 §6: site path, test users for every role the story's cases need, Node,
Chromium, workspace); the story has non-retired, Ready cases (else "no test cases — run Test Design first"); the
`story-verification` workflow installed (L-033). Then: `story_stages.get_or_create(story_id, "verification", …)` (add
`verification` to `StoryStageStore.VALID_STAGES`, `kb/story_stages.py:45`, and grep its consumers, L-094); write the
inputs to the story-stage dir (story, cases with Gherkin, scenarios, roles, catalog snapshot, any previous
verification's authored scripts so a re-run resumes from them); export the workspace HEAD; `move_card(… "verification"
…)`; start the run; bind it; queue rule F7 (a verification waits behind a running execution and shows Queued).
The confirm dialog text (51-11) asks the user to confirm the story's changes are deployed to QA (D7).

## 4. `story-verification` workflow (genesis-workflows `workflows/story-verification/`)

Every agent node: ADR-011 trio; skills `playwright-appian` + `genesis-test-authoring` (51-07 §7) provisioned per
ADR-069; the **sandboxed shell** per D3/51-03 (or the fallback MCP tools if 51-03 failed); bounds F10.

| Node | Kind | Does |
|---|---|---|
| `resolve_inputs` | program | Load inputs; compute the affected roles (roles of the story's cases + their scenarios' setups) |
| `open_sessions` | program | `ApwtClient` opens + logs in one session per role on QA (51-05 §4); writes the sandbox config into the run folder |
| `explore` | agent | Per role, visits the screens the story changed (story + cases + implementation report as files, L-042); no tests; `record-start`/`record-stop` captures; writes `exploration.json` (screens, addresses, notes) |
| `v_explore` | validator | Every role explored; captures present |
| `author` | agent | Writes a case script per story case, data setups and new actions where the library lacks them, using library actions first (D2, §5.5 of findings); sets each scenario's setup + `changes_shared_data` |
| `v_author` | validator (program) | Typecheck; `playwright test --list` sees every story scenario; every story case has a script; no edit to `lib/`; no hard-coded secrets |
| `execute` | program | The 51-06 runner on the run's checkout (kind `verification`) |
| `triage` | agent | Classifies each failure: **script** / **product** / **blocked** with evidence (`triage.json`) |
| healing | ADR-067 `attach_healing` | Script defects: patch in place (≤ 1) → re-execute affected scenarios; ≤ 1 guided restart of `author`; else escalate |
| `decide` | program | All story cases passed (flaky counts as passed, D14.3) → `passed`; any product defect → `failed`; blocked only → the gate |
| `escalate_blocked` | gate (escalation) | Retry · Send back · Accept as passed |
| `propose` | agent | On `passed`: proposals = new/changed actions and setups, the story's case scripts, scenarios to add to the regression suite (`proposals.json`, the 51-07 §5 shape + `regression` items) |
| `render_report` | program | `verification-report.html`: scenarios → cases → result, failures with expected vs actual, screenshot links, triage classes, a link to each session's action log, proposals summary |
| `present` | program | `result.json` `{decision: passed|failed|accepted, execution, proposals}` |
| `cleanup` | program | Close sessions; kill registered process groups (F8) |

## 5. `StoryVerificationFinalizer` (`genesis/genesis/chat/story_verification_finalizer.py`)

Copy of the implementation finalizer's guards (`chat/story_implementation_finalizer.py`: done run, workflow id, bound
run, card still in `verification`, idempotent, on-read + startup reconcile, status stored first, loud failures; L-058,
L-061, L-062, L-093). It imports the execution's results (51-06 §5 shared code), copies the report, `proposals.json`
and the authored scripts into the story-stage dir, sets `automation_status = broken` for cases whose failure stayed a
**script** defect after healing, then: `passed`/`accepted` → audited `verify` → **Done**; `failed` → audited `reject` →
**Implementation** with the defect list stored on the stage row (shown on the story page). Proposals wait on the
story-stage row; the move does not wait for them (D12.6).

## 6. Applying proposals

Same apply path as 51-07 §6 (per item / Accept all, one commit) plus the regression items through
`RegressionService.apply_verification_proposal` (51-08 §2). Accepted case scripts are bound in `kb_test_case_scripts`.

## 7. Tests

Lane order + transitions + every listed consumer; start endpoint 409s (no QA, missing role user, no cases, not
installed); queue; workflow node tests with stub sessions and a stub runner (real JSON report fixture); triage routing;
healing bounds; gate options; finalizer through the real `RunManager._finalize` (L-093); `broken` marking; proposals
apply; reliability lint (`validate_library` gate 3).

## Context manifest

```toml
areas    = ["stories-workbench", "workflows-library"]
adrs     = ["ADR-011", "ADR-012", "ADR-050", "ADR-061", "ADR-062", "ADR-067", "ADR-068", "ADR-069", "ADR-071"]
lessons  = ["L-033", "L-042", "L-058", "L-061", "L-062", "L-064", "L-065", "L-076", "L-088", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/genesis/domain/transitions.py", "genesis/genesis/kb/boards.py", "genesis/genesis/kb/story_stages.py", "genesis/genesis/api/workbench.py", "genesis/genesis/chat/story_implementation_finalizer.py", "genesis/genesis/chat/story_verification_finalizer.py", "genesis-workflows/workflows/story-verification/**", "genesis-workflows/workflows/story-implementation/**"]
upstream = ["51-03", "51-05", "51-06", "51-07", "51-08"]
```
