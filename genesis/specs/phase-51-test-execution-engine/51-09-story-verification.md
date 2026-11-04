# 51-09 — Story verification: lane order, the Verification lane and `story-verification`

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (backend), **genesis-workflows** (`story-verification`
> v0.1.0). Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D3, D5, D6, D7, D8, D10, D12, D14; F2,
> F7, F10, D24.

## 1. Goal

Deployment moves before Verification; dragging a card from Deployment into Verification runs an agent workflow that
explores the story's screens as each affected role, authors case scripts from the library, runs them on QA, triages
failures, moves the card to Done or back to Implementation, proposes library and regression updates, and writes a
report.

## 2. Lane order and transitions (D6, D7)

- `STORY_LANES` (`genesis/genesis/domain/transitions.py:124-127`) becomes `… CODE_REVIEW, DEPLOYMENT, VERIFICATION,
  DONE`. `STORY_STAGE_TRANSITIONS` (`genesis/genesis/domain/transitions.py:105-123`): replace `(code-review, approve) → verification`, `(verification,
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
verification's authored scripts so a re-run resumes from them); `move_card(… "verification" …)`; start the run through
`RunManager.start(prepare=…)` (51-06 As built 3), whose prepare step exports the workspace HEAD into
`<run>/checkout` (`TestWorkspace.export`) before the worker starts; bind it; queue rule F7 (a verification waits behind
a running execution and shows Queued).
The confirm dialog text (51-11) asks the user to confirm the story's changes are deployed to QA (D7).

## 4. `story-verification` workflow (genesis-workflows `workflows/story-verification/`)

Every agent node: ADR-011 trio; skills: the CLI `playwright-appian` skill (from the workspace's package) +
`genesis-test-authoring` (51-07 §7) provisioned per ADR-069; ordinary `kiro_node` agents running `npx --no-install
apwt` from the run's workspace export on the program-opened sessions (D3c, 51-05 §4a; accepted risk until Phase 52);
bounds F10 (`turn_timeout` 900 s on `explore` and `author`; re-measure on a write flow and record it in the As built).

| Node | Kind | Does |
|---|---|---|
| `resolve_inputs` | program | Load inputs; compute the affected roles (roles of the story's cases + their scenarios' setups) |
| `open_sessions` | program | `ApwtClient` opens + logs in one session per role on QA (51-05 §4, §4a); the session names and the exact `npx --no-install apwt -s <name>` prefix go into the agents' prompts |
| `explore` | agent | Per role, visits the screens the story changed (story + cases + implementation report as files, L-042); no tests; `record-start`/`record-stop` captures; writes `exploration.json` (screens, addresses, notes) |
| `v_explore` | validator | Every role explored; captures present |
| `author` | agent | Writes, **in `<run>/checkout` only**, a case script per story case, data setups and new actions where the library lacks them, using library actions first (D2, §5.5 of findings), all to the 51-07 §2 contract; generated specs start on a blank page, so each data setup and each scenario's first case navigates itself (51-07 As built 5; the skill says so); records them in the overlay `authored.json` (§4a) |
| `v_author` | validator (program) | Overlay schema valid; checkout typechecks; the overlay-generated suites (§4a) make every story scenario automated and `playwright test --list` sees them all; every story case has a script; no edit to `lib/` or `suites/`; no hard-coded secrets |
| `execute` | program | Generate the overlay catalog's suites into the checkout (§4a), then the 51-06 runner on the checkout (kind `verification`) |
| `triage` | agent | Classifies each failure: **script** / **product** / **blocked** with evidence (`triage.json`) |
| healing | ADR-067 `attach_healing` | Script defects: patch in place (≤ 1) → re-execute affected scenarios; ≤ 1 guided restart of `author`; else escalate |
| `decide` | program | All story cases passed (flaky counts as passed, D14.3) → `passed`; any product defect → `failed`; blocked only → the gate |
| `escalate_blocked` | gate (escalation) | Retry · Send back · Accept as passed |
| `propose` | agent | On `passed`: proposals = new/changed actions and setups, the story's case scripts, scenarios to add to the regression suite (`proposals.json`, the 51-07 §5 shape + `regression` items) |
| `render_report` | program | `verification-report.html`: scenarios → cases → result, failures with expected vs actual, screenshot links, triage classes, a link to each session's action log, proposals summary |
| `present` | program | `result.json` `{decision: passed|failed|accepted, execution, proposals}` |
| `cleanup` | program | `ApwtFactory.cleanup_run(<run>)` (`close-all` + reap of `<run>/.pids`, 51-05 As built 11); then the 51-06 report scrub (`testexec/runner.py` `scrub_html`/`scrub_zip`, every text file and zip) over `<run>/apwt-out` with the roles' passwords, before the finalizer copies anything |

## 4a. The verification overlay (D24)

The agent's work is a proposal (D12), so nothing it writes reaches the workspace or `genesis.db` before the user
accepts it. The run executes **committed HEAD plus its own overlay**, inside `<run>/checkout`:
- `authored.json` (written by `author`, schema-validated by `v_author`): `cases: {<TC-key>: <checkout-relative path>}`,
  `setups: [{temp_key: "DS-NEW-<n>", name, role_key, path}]` (new setups; existing ones by real `DS-` key),
  `actions: [{temp_key: "ACT-NEW-<n>", name, area, path, contract}]`, `scenarios: {<TS-key>: {setup: <DS- or temp key
  | null>, changes_shared_data: bool}}`. Paths stay inside the checkout's `cases/`, `setups/`, `actions/`.
- **Overlay catalog:** extend 51-06's `generator.build_catalog` with an optional `overlay` argument (additive; the
  library path passes none). The overlay adds case-script bindings for the story's cases, provisional setups and
  per-scenario setup choices on top of the DB rows, and `script_text` reads from the checkout. The `execute` node
  generates `suites/` + `playwright.config.ts` **into the checkout**, never committing in the workspace, then runs the
  51-06 runner there.
- **Reproducible:** the execution row records `workspace_commit` and the overlay (`selection_json.overlay`, plus a
  hash of the authored files); the finalizer copies `authored.json` and the authored files into the story-stage dir
  (§5), and a re-run starts from them (§3).
- **Accepting proposals** (§6) is where the overlay becomes library code: real keys allocated, files written to the
  workspace through the 51-07 save path (typecheck, contract checks, one commit), case scripts bound, scenario setups
  set via `set_scenario_setup`.

## 5. `StoryVerificationFinalizer` (`genesis/genesis/chat/story_verification_finalizer.py`)

Copy of the implementation finalizer's guards (`chat/story_implementation_finalizer.py`: done run, workflow id, bound
run, card still in `verification`, idempotent, on-read + startup reconcile, status stored first, loud failures; L-058,
L-061, L-062, L-093). It imports the execution's results (51-06 §5 shared code), copies the report, `proposals.json`,
`authored.json` and the authored files (the overlay, §4a) into the story-stage dir, sets `automation_status = broken` for cases whose failure stayed a
**script** defect after healing, then: `passed`/`accepted` → audited `verify` → **Done**; `failed` → audited `reject` →
**Implementation** with the defect list stored on the stage row (shown on the story page). Proposals wait on the
story-stage row; the move does not wait for them (D12.6).

## 6. Applying proposals

Same apply path as 51-07 §6 (per item / Accept all, one commit) plus the regression items through
`RegressionService.apply_verification_proposal(app_uuid, scenario_ids=[…], regression_scenarios=[{title,
description?, case_ids}])` (built in 51-08, As built 7): it never refuses as a whole and returns what it added, what
was already referenced and what it skipped (with reasons), and creates proposed regression scenarios as **Draft**.
Call it after the case scripts are bound, show its three lists in the apply result, and pass `case_ids` of real
(accepted) cases only. Accepted case scripts are bound in `kb_test_case_scripts`.

## 7. Tests

Lane order + transitions + every listed consumer; start endpoint 409s (no QA, missing role user, no cases, not
installed); queue; workflow node tests with stub sessions and a stub runner (real JSON report fixture); the overlay
(D24): `authored.json` schema refusals, `build_catalog(overlay=…)` makes the story scenarios automated from checkout
files while the library path is unchanged, suites are generated into the checkout and the workspace HEAD and DB are
untouched until accept, the execution records the overlay, a re-run resumes from the stored authored files; triage routing;
healing bounds; gate options; finalizer through the real `RunManager._finalize` (L-093); `broken` marking; proposals
apply; reliability lint (`validate_library` gate 3).

## Context manifest

```toml
areas    = ["stories-workbench", "workflows-library"]
adrs     = ["ADR-011", "ADR-012", "ADR-050", "ADR-061", "ADR-062", "ADR-067", "ADR-068", "ADR-069", "ADR-071"]
lessons  = ["L-033", "L-042", "L-058", "L-061", "L-062", "L-064", "L-065", "L-076", "L-088", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/genesis/domain/transitions.py", "genesis/genesis/kb/boards.py", "genesis/genesis/kb/story_stages.py", "genesis/genesis/api/workbench.py", "genesis/genesis/chat/story_implementation_finalizer.py", "genesis/genesis/chat/story_verification_finalizer.py", "genesis/genesis/testexec/**", "genesis/genesis/runs/manager.py", "genesis-workflows/workflows/story-verification/**", "genesis-workflows/workflows/story-implementation/**", "genesis-workflows/workflows/test-execution/**"]
upstream = ["51-03", "51-05", "51-06", "51-07", "51-08"]
```

## As built (2026-11-04, genesis-dev)

**Task restated.** Move Deployment before Verification; make the Deployment → Verification drag start a
`story-verification` run that explores the story's screens per role on program-owned QA sessions, authors case
scripts (and missing setups/actions) only inside `<run>/checkout` as a D24 overlay, runs them with the 51-06 runner,
triages failures with one bounded heal, decides, proposes library and regression updates on a pass, and reports; a
finalizer imports the results, keeps the overlay and moves the card through the audited `verify` / `reject` edges;
proposals are applied through the 51-07 save path in one commit plus `apply_verification_proposal`.

**Applicable rules.** ADR-011 (trio on explore/author/triage/heal/propose), ADR-012 (graph.py imports nothing from
Genesis; Genesis reached via `ctx.extras['apwt'].verification()`), ADR-050 (audited lane edges), ADR-061 (lane order —
amended by the user's D6, ADR-084 at 51-13), ADR-062 (drag-confirm → bound run → finalizer), ADR-067 (healing tier,
`META.healing {1, 1}`), ADR-068 + ADR-021 (QA data writes with no `pre_mutation` gate — D8/D22, ADR-082 at 51-13),
ADR-069 (skills `playwright-appian` from the checkout + `genesis-test-authoring`), ADR-071 (story-scoped routes).
Lessons L-033, L-042, L-058, L-061, L-062, L-064, L-065, L-076, L-088, L-093, L-094 (+ L-026, L-039, L-083, L-091, L-092).

### Commits

- **genesis** (base `d701ea9`, local, not pushed or tagged): `7daa505` feat(testexec,51-09) — the whole change incl.
  every review fix; a separate `git status --short --untracked-files=all` afterwards was empty (L-056/L-089).
- **genesis-workflows** (base `966c022`, local): `93e6e35` feat(story-verification,51-09); `git status` afterwards
  empty (only ignored `__pycache__`).
- **project-tracker:** this As built and `reviews/51-09-review.md`.

### Changed (genesis)

- `domain/transitions.py` — `STORY_LANES` … `CODE_REVIEW, DEPLOYMENT, VERIFICATION, DONE`; edges `(code-review,
  approve) → deployment`, `(deployment, deployed) → verification`, `(verification, verify) → done`, `(verification,
  reject) → implementation` (kept). `domain/enums.py` comment.
- `kb/boards.py` — both card queries (board + single card, L-039) join the `verification` story stage and its run:
  `verification_story_stage_id`, `verification_run_id`, `verification_status`, `verification_run_status`.
- `kb/story_stages.py` — `VALID_STAGES += "verification"`; `run_states_for_feature` filtered to design +
  implementation (its documented shape).
- `kb/testexec_store.py` — `ExecutionStore.finish(selection=)` (additive).
- `testexec/generator.py` — `Overlay` + `build_catalog(overlay=)` (additive; the library path passes none):
  overlay case bindings, provisional setups (negative ids, temp keys `DS-NEW-<n>` as instances), per-scenario setup
  choices; an unknown setup key reads as "missing or retired".
- `testexec/runner.py` — `scrub_dir(root, secrets)` extracted from `PlaywrightRunner._scrub` (same behaviour); text
  suffixes += `.jsonl .ts .js .yml .yaml .csv` (apwt session artifacts).
- `testexec/execution_service.py` — `launchers` (kind → launcher) so a `verification` execution shares the one F7
  queue; the pump records a launcher's `problems` on the failed execution.
- `testexec/library_service.py` — `create_many(cases=[{case_id, code}])`: case scripts written, checked
  (`_check_code` kind `case`, with the pending new items), committed in the same commit and bound
  (`kb_test_case_scripts` + refs); a later failure restores the previous binding.
- `testexec/verification.py` (new) — `overlay_problems` (the one schema check), `parse_overlay`, `overlay_paths`,
  `overlay_hash`, `copy_overlay`, `story_context` (Ready story cases, the non-retired scenarios using them with all
  their cases, roles from committed scripts + setups, `roles_unknown`, `unscenarioed`), `VerificationTools` (worker
  side: `catalog`, `setup_keys`, `generate` into the checkout, `secret_hits`, `list_tests`, `scrub_session_artifacts`,
  `overlay_problems`).
- `testexec/verification_service.py` (new) — `StoryVerificationService`: `check` (codes `no_qa`, `no_cases`,
  `no_scenario`, `not_installed`, `not_ready`, `busy`), `start` (stage row, inputs files, `move()`, queued TE, pump),
  `_launch` (prepare: export HEAD → `<run>/checkout`, restore the stored overlay, `set_running`, bind the stage
  before the spawn), `view` (+ fallback to the story's newest verification execution), `latest_execution`,
  `report_path`, `decide`, `apply`.
- `chat/story_verification_finalizer.py` (new) — `StoryVerificationFinalizer` (§5) + `classifications`,
  `classify_rows`.
- `integrations/apwt/factory.py` — `ApwtFactory.verification(app, run_dir)`.
- `api/workbench.py` — `POST /workbench/boards/{app}/cards/{story}/verification/start` (409 `{detail, problems,
  code}` top level, 51-10 §1); `GET /applications/{app}/stories/{story}/verification` (+ `report_url`), `GET
  …/verification/report` (`no-cache`), `POST …/verification/proposals/decisions` (400 unknown, 409 stale), `POST
  …/verification/proposals/apply` (409 stale/not ready, 422 typecheck `{detail, errors}`, 400 refusal); board on-read
  recovery for verification cards.
- `api/app.py` — `StoryVerificationService` + `StoryVerificationFinalizer` wiring (`app.state.story_verification`,
  `story_verify_finalizer`), startup reconcile after the execution reconcile.
- Web (types/tests only): `Lane` order, `verification_*` card fields (`types/workbench.ts`); `workbench.test.tsx`
  fixture order + an assertion that the board renders the API order. `npm run build` then `git status`: `web/static`
  unchanged (no bundle commit).

### Changed (genesis-workflows)

- `workflows/story-verification/` (new, 0.1.0): `graph.py`, `workflow.yaml` (META parity + `graph:` topology of 24
  nodes), `__init__.py`, `tests/`; `registry.json` entry. No existing workflow changed.
  Graph: `resolve_inputs → open_sessions → explore(trio) → author(trio; v_author) → execute → [triage(verify) →
  heal → reexecute | author] → decide → propose(trio) → cleanup → render_report → present`; gates `escalate_blocked`
  (retry · send_back · accept) and `escalate` (send_back · accept · stop). `turn_timeout` 900 s explore/author, 600 s
  triage/heal/propose; `retry_defaults.max` 2; `healing {1, 1}`; `recursion_limit` 200; no `pre_mutation`.

### L-094 — every consumer of the lane order and of `VALID_STAGES` (grep at build time)

Lane order / values: `domain/transitions.py` (`STORY_LANES`, `STORY_STAGE_TRANSITIONS` — changed);
`domain/lifecycle.py:272` (`build_story_lifecycle_service` over the table — no change); `kb/boards.py:30`
`LANE_VALUES` (order from `STORY_LANES`; counts and `lanes` follow — no change); `api/workbench.py` move/lanes routes
(validate ∈ `LANE_VALUES` — no change); `kb/story_trace.py:24` `EDITABLE_LANES = (to-do, design)` (order-free —
no change); `kb/spec_impact.py` (uses `EDITABLE_LANES` — no change); `domain/enums.py:45` (comment updated);
`web/src/types/workbench.ts` (`Lane` union order + comment); `web/src/features/workbench/lanes.ts` (labels/tones
record, order from the API — no change); `web/src/features/workbench/story-view.ts:7` `IMPL_LANES` (a set — no
change); `web/src/features/workbench/story-view.test.ts:44` (order-free — no change);
`web/src/features/workbench/workbench.test.tsx` (fixture order + new order assertion); `tests/test_domain_transitions.py`
and `tests/test_board_store.py` (pinned the old order — updated). Collaboration board publish/pull: lane values are
unchanged, no Hub change; `test_lane_order_board_api_and_card_join` reads a card in `deployment` through the board.
`VALID_STAGES`: `StoryStageStore.get_or_create` (the only check); `run_states_for_feature` (now filtered — its
consumers `kb/spec_impact.py:72`, `services/spec_change.py:564/834/850` read design + implementation only);
`services/testimpact.py:297` (reads `implementation` by name); the two board card queries (verification join added);
`api/workbench.py` Story Workspace (design + implementation by name — unchanged); collaboration does not sync story
stages (grep of `genesis/collab` empty).

### Tests

- genesis `tests/test_story_verification.py` (15): lane order + card join + `run_states_for_feature`; overlay schema
  refusals (12 cases) + hash; `build_catalog(overlay=)` automates from checkout files while the library path is
  unchanged and the DB untouched; `VerificationTools.generate` into the checkout (workspace HEAD + status + DB
  unchanged), `secret_hits`; apwt-out scrub; start refusals (`not_installed`, `not_ready` missing password,
  `no_cases`, `no_scenario`, `no_qa` with the card left in Deployment); queue behind a running execution → launch,
  bound before the spawn, no password in the job or inputs; re-run resumes from the stored overlay; finalizer through
  the real `RunManager._finalize`: passed → Done (audited `verify`), TE passed with `selection.overlay` + hash, stage
  completed with the report, authored files copied, capture ready, workspace + scripts untouched, idempotent; failed
  → Implementation, `classification` on rows, `defects.json`, `broken`, no capture; cancelled / undecided leave the
  card; a launch failure shows on the story read with its problems; triage classes on rows; routes (409 top-level
  codes, `busy`, on-read recovery via the board GET, view, report `no-cache`, decisions 400/409/200, 404).
- genesis `tests/test_story_verification_apply.py` (3, real git + tsc + scan-refs; skips without node/npm): Accept
  (P7 rejected) → ONE commit of exactly the action, the setup and the accepted case script; keys allocated and temp
  keys gone; the case bound with `last_commit`; the rejected case not written; the scenario's setup set to the new
  `DS-`; regression reference added; a Draft regression scenario with scripted cases only; capture applied. A type
  error → nothing committed, no rows, binding unchanged, capture still ready. A case proposal without code refused by
  name; an unknown regression case key reported in `skipped_proposals` after a commit-less apply.
- genesis-workflows `workflows/story-verification/tests/` (16): `normalize_report` parity with test-execution on the
  real 1.59.1 report; `check_exploration`; `check_triage`; `decide_outcome` (flaky = passed, product, blocked, nothing
  ran); `merge_results` + `apply_heal_patches` (never `lib/`/`suites/`/`..`); `proposal_problems` +
  `complete_proposals`; gate routes and the state-dependent escalate prompt; `carry_attachments`; META ↔ yaml parity,
  the trio (`check_reliability`), topology ids = compiled nodes, no `pre_mutation`, 900 s bounds; whole graph (real
  `ctx.extras['apwt']`, stub turns, stub apwt + npx with DERIVED report shapes): a script defect healed by one patch
  and only that scenario re-run → passed with proposals (code + sha), the report links the scrubbed session log, both
  skills provisioned, no password in state/checkpoints/events/any run file, no DB writes; a product defect → failed
  without heal or proposals; blocked → paused at the gate; review M1 (product evidence kept after a heal of another
  scenario); healing bounds (1 patch, 1 guided restart, then the gate); a failed sign-in → the gate without agents;
  three refused explorations → `escalate`.
- Gates (final, after the review fixes): genesis `ruff check genesis` clean; pytest **1653 passed** (1635 at 51-08 +
  18); web `tsc --noEmit` clean, `eslint .` 0 errors, vitest **467 passed**, bundle unchanged; genesis-workflows
  `validate_library` PASSED (17), pytest **360 passed** (344 + 16), ruff clean.
- **Not run:** a live verification on QA with a real Kiro agent, and F10's write-flow re-measure of the 900 s bounds
  — both 51-12's (no QA test user on this machine).

### Review

`reviews/51-09-review.md`. First pass **NEEDS_CHANGES**: M1 (after a heal, the kept scenarios' attachments pointed
into the renamed `report-pass<n>` and 404'd), M2 (the `escalate` prompt promised outcomes a passed run then ignored),
m1 (a launch failure invisible on the story), m2 (no graph tests of the healing bounds / sign-in failure / trio
exhaustion), m3 (apply could raise after its commit), m4 (this As built), n1–n3. Fixed: M1 (`carry_attachments` +
graph test), M2 (`_escalate_prompt` by state; the answer is always honoured; tests), m1 (`view` falls back to the
story's newest verification execution; the pump records the problems; test), m2 (three graph tests), m3 (unknown keys
→ `skipped_proposals`; test), n1 (refused by name; test), n2 (`_launch` raises only). n3 recorded in decision 9.
**Re-review: SHIP** (reviewer re-ran genesis 1653, genesis-workflows 360 + `validate_library` 17, ruff, tsc, the
workbench vitest). Its optional nits: n4 (the gate tests could also assert which gate is pending — not done; the
bound counters and "no result" pin the behaviour), n5 (an apply refused by n1 still stores the decisions, so the
capture's `row_version` moves — **51-10/51-11 refetch after a 400**), n6 (the F10 re-measure is named only here —
**genesis-spec/docs: add it to 51-12**).

### Decisions / deviations

No ADR deviation beyond the user's approved D6 (ADR-061 lane order), D8/D22 (ADR-068/ADR-021: QA data writes, no
`pre_mutation`) — **51-13 owes ADR-082 (amends ADR-021, ADR-068) and ADR-084 (amends ADR-061)**. Choices, **bold =
affects 51-10..51-13**:
1. **A verification is a `verification` TE- row in the one F7 queue** (`TestExecutionService.launchers`); it shows
   Queued while another execution runs. The start moves the card at once; the stage binds when the run launches.
   **51-11:** the card's queued state = `GET …/stories/{id}/verification` `active.status == "queued"`.
2. **Node order: `cleanup` runs before `render_report`** (spec table: render, present, cleanup) so the report can link
   the scrubbed session logs, copied to `<run>/report/sessions/<session>/…` and served by the execution report route.
3. **Two gates.** `escalate_blocked` (Retry · Send back · Accept as passed) for decide = blocked, a failed sign-in
   (Retry re-opens the sessions) and triage/heal exhaustion; `escalate` (Send back · Accept as passed · Stop) for
   explore/author/propose exhaustion. Every answer is honoured; on a passed run whose `propose` was exhausted the
   prompt says so and Accept keeps Done without proposals. **Stop / any non-decision leaves the card in
   Verification** with the report. **51-11** renders the options from the gate descriptor.
4. **The defect list is `defects.json` in the story-stage dir** plus `classification` on each failed/blocked result
   row (spec §5: "on the stage row" — `kb_story_stages` has no free column; no migration added). `GET
   …/verification` returns it as `defects`.
5. **Proposals are a `verification` capture** (`kb_test_captures`, kind `verification`, bound by `run_id`) — the 51-04
   model; CAS decisions on its `row_version`. Item kinds: `action`/`setup` (`match` new with `temp_key`, or update
   with `key`), `case`, `scenario_setup`, `regression` (`scenario_keys`), `regression_scenario` (`title`,
   `description?`, `case_keys`). The program embeds each file's code (≤ 200 KB) + sha256. **51-10/51-11 render these
   kinds.**
6. **New start refusal `no_scenario`:** a Ready story case in no scenario could never be verified.
7. **Scope = Ready, non-retired story cases** (Draft cases are not verified); every case of the story's scenarios may
   be scripted by the overlay; a case's overlay path must be `cases/<TC-key>.ts`.
8. `normalize_report` is copied into `graph.py` (standalone, ADR-012) with a parity test on the real 1.59.1 report.
9. Heal patches go through `apply_heal_patches` (only overlay or `cases/`/`setups/`/`actions/` paths) but not through
   `v_author`'s secret check; the apply path re-checks the code. A healed library file the overlay does not name is
   not kept for a re-run (`copy_overlay` copies overlay paths only) — review n3.
10. Roles: from committed case scripts' literal roles and the scenarios' setups; when any case's role is unknown
    (no committed script yet) the run opens a session for **every** test user of the app, and readiness checks all.
11. **A gated or paused verification does not hold the F7 queue** (51-06 decision 5); its sessions are reaped only
    when the run ends (or by apwt's 30-min idle timeout). A failed/cancelled run's `apwt-out` is not scrubbed (the
    finalizer copies nothing from it; retention prunes it).
12. `report_url` is built by the backend under `/api/…` (the iframe/link target); the client does not prefix it.

### Lesson candidates

- **Renaming a report folder between passes breaks every relative link you kept from the earlier pass.** A merged
  result must carry its evidence into the folder the route serves (51-09 review M1).
- **A gate's prompt is a promise:** when routing depends on state, the prompt must too, or the person's answer is
  silently overridden (51-09 review M2).

### Code-map changes

For bible/03 in the "Phase 51" block: `domain.STORY_LANES` order; `kb/boards` verification join;
`StoryStageStore.VALID_STAGES` + verification; `ExecutionStore.finish(selection=)`; `generator.Overlay` /
`build_catalog(overlay=)`; `runner.scrub_dir`; `TestExecutionService.launchers`; `TestLibraryService.create_many(cases=)`;
`testexec/verification.py`, `testexec/verification_service.py`; `chat/story_verification_finalizer.py`;
`ApwtFactory.verification`; `api/workbench.py` verification routes; genesis-workflows `story-verification` 0.1.0.
