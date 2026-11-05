# 51-15 — Review fixes from 51-12 (and the decisions D26–D32)

> **Status:** BUILT 2026-11-05 (2 sessions; genesis-review SHIP after one delta round — `reviews/51-15-review.md`). SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`,
> `story-verification`, `test-execution`: small fixes). Parent: `specs/phase-51-test-execution-engine.md`.
> Decisions: 51-01 D26–D32. Source of every finding (evidence, file:line, the reviewer's fix):
> `reviews/51-12-review.md` §Findings — read it first; this sub-spec says **what to build**, the review says **why**.
> Built first after the review, then 51-16, 51-17, then the 51-12 re-run.

## 1. Goal

Close every blocker, major, minor and nit the 51-12 review found (except n3, backlog), and build the seven decisions
the user took on them, so the re-run of 51-12 can pass all its gates and live steps.

## 2. Blockers

- **B1 — Replay poll loop (51-11).** As the review's fix: the job runner never resumes a job id it has already seen
  finish; the terminal poll refetches the item without cancelling the in-flight read (`cancelRefetch: false`) and sets
  the cached item's `replay_job` to null. Regression test: render the item page with a `running` `replay_job`, finish
  the job (MSW), assert the poll stops (request count) and the result shows; the same for `cancelled`.
- **B2 — the report can call `/api` → D26.** A second loopback listener in `genesis serve` (default port = app port
  + 100; a setting and a `genesis serve --reports-port`; the same host and ADR-026 non-loopback refusal; started and
  stopped with the app). A minimal read-only static server: registered roots only (execution report folders and,
  for D29, `library-replays`), refuses `..`, absolute paths and any resolved path outside its root (symlinks
  included), no directory listing, `X-Content-Type-Options: nosniff`, `Cache-Control: no-cache` on `index.html`
  (L-068), no other routes. The API returns report URLs on that origin (`report_url` fields); the old
  `/api/…/report/{path}` route is removed (or answers 410). The execution page links there; the story page frames
  Genesis's own `verification-report.html` with `sandbox=""` and its links open the reports origin in a new tab
  (`target="_blank" rel="noopener"`) — this closes **m2**. Tests: a route test per refusal; a real-browser test (the
  reviewer's probe, kept as a script under `scripts/`) that a report page on the reports origin gets no
  `/api/applications` data.
- **B3 + MJ3 — pause fails the run; cancel ends `error` with two `run.final` (run manager, pre-existing).** One fix:
  record the intended stop (`pausing` / `cancelling`) on the run record **before** `w.kill()`; the `worker_exit`
  handler ignores a run whose stored or intended status is `paused` or terminal; `_finalize` becomes single-shot (a
  CAS `UPDATE runs SET status=? WHERE run_id=? AND status NOT IN (<terminal>)`, emitting `run.final` only for the
  write that won; L-091, L-093). An unexpected worker death still fails the run. Regression tests through the real
  `RunManager` with a subprocess worker that exits non-zero on SIGTERM: pause → `paused`, resume → continues from the
  checkpoint (ADR-009 mode 2); cancel → exactly one `run.final{cancelled}`, execution `cancelled`. Check every existing
  run-control test still passes (Design/Implementation lanes, chat run control, L-003, L-008, L-065).

## 3. Majors

- **MJ1 + m6 — `automation_status` follows the script.** Saving, accepting (capture or verification apply) or adopting
  a case script sets `automated` (clears `broken`); deleting it sets `not-automated`; a library execution or
  verification that records a passed or flaky step for a scripted case sets `automated` over `broken`; verification
  triage still sets `broken` for an unhealed script defect (D14.5). One writer function in the store, used by every
  path. Tests for each path, through the real `RunManager._finalize` where a run is involved.
- **MJ2 → D27.** The contract is read only from the code: a code save without literal `inputs`/`outputs` in
  `defineAction` (outputs only in `defineSetup`) is refused with that message; the form-contract fallback in
  `library_service.py` is removed; the item page shows the contract as a read-only table ("Declared in the code — edit
  it in the editor"), name / area / role stay editable; the save API returns `changed: false` for a no-op and the page
  says "No changes". The proposal and verification apply paths take the contract from the code too. Tests: route +
  page with a literal-declared item; a no-op save; a breaking change in the code while used → refused with Save as new.

## 4. Minors, nits and the other decisions

- **m1** — `tsc` in `story-verification` and `action-capture`: start it in its own session and record its pgid in
  `<run>/.pids` (the program nodes reach Genesis's helpers through `ctx.extras['apwt']`); kill the group on timeout.
  Test.
- **m3** — delete `captures/<id>/trace_debug.json` after `record stop` and git-ignore `captures/*/*_debug.json`. Test.
- **m4** — `action-capture` `heal` turn timeout 600 s → 900 s (F10 rule: it came within 20 %); record in As built.
- **m5 → D28.** Actions: no Replay button and no `library-replay` for actions; the approve precondition becomes
  "passed in use at the current hash": the execution finalizer, for each passed scenario or setup of a library
  execution (not verification), walks `kb_test_refs` transitively to the actions it used and, where the action file's
  content at the execution's `workspace_commit` hashes to the action's current `content_hash`, transitions it Draft →
  Ready through `LifecycleService` (audited, actor = the execution). Capture apply keeps its rule (replay passed at
  that code). The item page explains "Ready after a scenario or data setup that uses it passes — use Run dependents".
  Tests: a passing dependent promotes; a stale hash does not; a verification execution does not; a failing one does
  not.
- **m7 → D31** (the row click). **m8** — CasesTable: lower `min-w` to ≤ 982 px from the review's measurement (Review
  136 → 112, Type 108 → 96, Title ≥ 200) and re-probe at 1280/1440/1920, both themes.
- **m9 → D32** (View run). **m10 → D29**: the setup item page shows the last replay with **Open report** and the
  failure screenshot inline, both from the reports origin; strip ANSI escapes from `last_replay.detail` when storing.
- **m11a** — the Action / Data setup item pages use the shared card header spacing (`CardHeader` or the spacing other
  detail pages use); no new tokens.
- **m11b → D31** — every Testing list (Library, Executions, Regression members, Setup users) in the Stories grid
  pattern (`StoriesTab.tsx`), widths from the L-090 probe.
- **m11c → D30** — remove Library's All · Actions · Data setups switch; add an "Any kind" filter; keep it in the URL.
- **m11d → D32** — the execution page as the decision describes.
- **n1** — `__test__ = False` on `TestExecutionState` (`workflows/test-execution/graph.py`). **n2** — a comment in
  `db/runner.py` on the m1′ key's limit.
- **Stalled capture.** Capture #2 ("Update evaluation") sits in `analysing` in the user's DB. Find why its
  `action-capture` run did not finalize (`CaptureFinalizer` reconcile, L-058/L-061/L-093) and fix the cause, or record
  that its run was killed by the review's restart and the reconcile now marks such captures `failed` with a reason.

## 5. Gates and evidence

pytest + ruff; genesis-workflows `validate_library`, `validate_skills`, pytest; web lint, tsc, vitest, jest-axe on
every changed view; `npm run build`, wait for the output to settle, commit `web/static` separately, then a rebuild and
an empty `git status` in its own call (L-089 + the 51-14 finding). Real-browser probes for B2 and the L-090 widths
(m8, D31, D32) with the numbers in the As built.

## Context manifest

```toml
areas    = ["runs-worker", "web-runs", "stories-workbench", "workflows-library", "security", "api"]
adrs     = ["ADR-009", "ADR-011", "ADR-012", "ADR-026", "ADR-027", "ADR-028", "ADR-050", "ADR-055", "ADR-067"]
lessons  = ["L-003", "L-005", "L-008", "L-011", "L-039", "L-058", "L-061", "L-065", "L-068", "L-069", "L-089", "L-090", "L-091", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/reviews/51-12-review.md", "tracker:specs/phase-51-test-execution-engine/51-01-findings.md"]
code     = ["genesis/genesis/runs/manager.py", "genesis/genesis/runs/supervisor.py", "genesis/genesis/testexec/**", "genesis/genesis/api/testing.py", "genesis/genesis/cli/main.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/chat/story_verification_finalizer.py", "genesis/web/src/features/testing/**", "genesis/web/src/features/test-design/**", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/workflows/story-verification/**", "genesis-workflows/workflows/test-execution/**"]
upstream = ["51-06", "51-07", "51-09", "51-10", "51-11", "51-14"]
```

## As built

### Session 1

Base: genesis `cca8ff8`, genesis-workflows `93e6e35`. Nothing pushed or tagged.

#### Commits

| Repo | Commit | What |
|---|---|---|
| genesis | `d8c1fc8` | B3 + MJ3 (run manager) + n2 |
| genesis | `e001b30` | MJ1 + m6 (`automation_status` follows the script) |
| genesis | `6fe9e71` | B2/D26 reports origin, MJ2/D27, D28, D29 (backend), m3, capture #2, m1 helper, contract fixtures |
| genesis | `f68c7ca` | web: B1, D27/D28/D29 item page, m11a (item page cards), m2, execution page links, captures gate note |
| genesis | `4412645` | web/static for `f68c7ca` (rebuilt after, `git status` empty in its own call) |
| genesis-workflows | `daf3612` | m1 (tsc process group + `.pids`), m4 (heal 600 → 900 s), n1 |

#### Changed

- **B3 + MJ3** (`runs/manager.py`, `runs/store.py`): `pause` stores `paused` and marks the *current worker* (per-worker
  state dict, not per run) before `kill()`; `cancel` claims `cancelled` with the compare-and-set before `kill()` and
  announces once. The killed worker's `worker_exit` / `error` / `on_exit` are ignored for an intended stop; a resume
  gets a fresh state, so a late exit of the killed worker cannot fail it. `RunStore.claim_status` = `UPDATE … WHERE
  status NOT IN (terminal)`, only the winner emits `run.final` (L-091, L-093). `RunStore.note_progress` moves the
  cursor without overwriting a stored pause/terminal. Pause/cancel of a terminal run change nothing (it used to
  overwrite `done` with `paused`). An unexpected worker death still fails the run.
- **MJ1 + m6** (`kb/testexec_store.py` `_follow_script`, the one rule): bind (save, capture/verification apply, adopt —
  all via `TestScriptStore.upsert`) → `automated`; delete → `not-automated`; a passed/flaky step with a binding →
  `automated` over `broken` (`record_run`); any other step that ran → `automated` over `not-automated` only;
  triage's unhealed script defect → `broken` (`mark_broken`). A refused apply's rollback restores the snapshot.
- **B2 / D26** (`testexec/reports_origin.py`, `cli/main.py`, `runtime/settings.py`): `ReportsServer` (stdlib
  `ThreadingHTTPServer`, daemon thread) started in `genesis serve` after the ADR-026 bind guard, stopped in a
  `finally` after uvicorn; port `--reports-port` › `GENESIS_REPORTS_PORT` › app port + 100; a busy port exits 2 with a
  hint. Roots: `/executions/{test-execution|story-verification}/r-…/report/**` (artifacts root) and
  `/library-replays/<app>/{ACT|DS}-…-<stamp>/report/**`; never a run's `checkout/`. Refusals → plain 404 (`..`,
  `.`, empty segment, backslash, NUL, encoded traversal, absolute, unregistered root, directory, symlink out of the
  root or into a non-report path); 405 for non-GET/HEAD; 421 for a foreign `Host` (DNS rebinding). Executions answer
  `report_url` and `attachment_links[{kind,label,path,url}]`; steps carry the case `title` (for D32). The old
  `/api/…/executions/{key}/report/{path}` answers **410** with `report_url`. The story page's
  `verification-report.html` route rewrites the workflow's `/api/…/report/` links to the reports origin with
  `target='_blank' rel='noopener noreferrer'` (another execution's link is disabled) and is served with
  `Content-Security-Policy: script-src 'none'; object-src 'none'` + `nosniff`.
- **MJ2 / D27** (`testexec/library_service.py`, `api/testing.py`): `_check_code` refuses an action without literal
  `inputs` and `outputs` (setup: `outputs`) or with a dynamic one; the declared contract is always what is stored (no
  form fallback); a `contract` metadata field is refused with "declared in its code" (400); `SaveResult.changed`
  (false for a no-op; a save whose code equals the catalog hash is metadata-only, no commit, no demotion — it used to
  drop a name edit silently too). The page shows `ContractTable` read-only, never sends `contract`, toasts "No
  changes".
- **D28** (`testexec/finalizer.py` `_promote_actions`, `library_service.promote_proven_actions`,
  `domain/transitions.py`): after a `done` library execution (not verification), roots = case steps of passed
  scenarios + their setups + passed `setup:` projects; walk `kb_test_refs` only through files whose content at the
  execution's `workspace_commit` equals their catalog hash; each Draft action reached gets `last_replay` evidence
  (`execution_key`, "passed in use in TE-…") and `approve` via `LifecycleService` (actor = the TE key). `check_replay`
  refuses an action ("use Run dependents"); the action cancel-replay route is not registered; the approve refusal for
  an action reads "becomes Ready after a scenario or data setup that uses it passes at its current code — use Run
  dependents". The item page shows "Proven in use" + Run dependents instead of Replay.
- **D29** (`replay.py` `replay_config_ts(html=True)` for library replays only — the default stays byte-equal to the
  action-capture copy; `record_replay(report=, screenshot=)`, ANSI stripped): the item read's `last_replay` gets
  `report_url` / `screenshot_url` on the reports origin; the setup page shows Open report and the screenshot inline.
- **m1** (genesis-workflows both graphs): `typecheck(…, ctx=ctx)` through `ctx.extras['apwt'].run_bounded` (new
  static helper: own group, pgid in `<run>/.pids`, group killed on timeout → `TimeoutError`); self-contained
  `start_new_session` + `killpg` fallback. **m4** heal `turn_timeout` 900 s. **n1** `__test__ = False`. **n2** comment
  in `db/runner.py`.
- **m3** (`recording.py`): `_drop_debug_trace` after `record stop` and in discard; template `.gitignore` gains
  `captures/*/*_debug.json` (new workspaces; the delete covers existing ones).
- **Capture #2 — finding:** its run `r-0ac738fb746d` was NOT lost or killed: segment retried twice, replay failed,
  healing restart, second replay failed → the run stopped at its `escalate` gate (`awaiting_input:gate`, 2026-11-05
  07:01:23 UTC); the user approved at 07:03:48; `CaptureFinalizer` set it `ready` 0.07 s after `run.final{done}`
  (log 12:33:49.578 IST); the user then discarded it. No finalizer bug. The real gap: the capture read only
  "analysing" while the run waited for the user. Fix: capture reads carry `run_status`; the panel says "Waiting for
  your decision … escalation gate" with the run link instead of the spinner.
- **B1** (`hooks.ts`, `LibraryItemPage.tsx`): the runner remembers the job ids it saw end and never resumes one;
  on a terminal job it nulls that `replay_job` in every cached testing read and invalidates with
  `cancelRefetch: false`; the page resumes once per job id.
- **m2**: the story page iframe is `sandbox="allow-popups allow-popups-to-escape-sandbox"` (no scripts, no
  same-origin). Deviation from the sub-spec's literal `sandbox=""`: with `""` the required `target="_blank"` links
  cannot open at all; the two popup flags add no script or same-origin power to the framed page.
- **m11a** (item page only so far): every card uses `CardHeader` (the misalignment was `CardBody`'s `pt-0` with the
  title inside it).

#### Tests (session 1)

- genesis pytest **1725 passed** (576 s; 1680 at base + 45 new/changed); `ruff check genesis` + changed tests clean.
- Regression tests proved failing on the old code: the four run-manager tests (pause/resume, cancel one
  `run.final`, late exit, CAS race) and both B1 web tests (succeeded / cancelled: polls stop, ≤ 1 item read after).
- New: `tests/test_reports_origin.py` (26: every refusal over a real socket, symlinks, methods, Host, `report_url`,
  serve's non-loopback refusal opens no port); real-worker cancel → execution `cancelled`
  (`test_testexec_execution.py`); D28 promote / stale hash / failing dependent / no action replay / verification never
  promotes; MJ1 execution + verification (overlay case, overlay action) paths; D27 code-only contract, no-op, setup
  outputs-only; D29 ANSI + evidence; m3 debug trace; capture `run_status`.
- genesis-workflows: `validate_library` PASSED (17), `validate_skills` PASSED (4), pytest **363 passed** (+3 m1).
- web: `tsc` clean, `eslint .` 0 errors (20 pre-existing warnings), vitest **672 passed (61 files)**, jest-axe on the
  setup replay-evidence state; build → `4412645`, rebuild → `git status --short --untracked-files=all` empty (own call).

#### Decisions / deviations

1. Cancel records its intent by claiming `cancelled` on the record before the kill (no new `cancelling` status: a new
   run status would reach every status consumer, L-094); pause stores `paused` before the kill.
2. m2 sandbox flags (above). 3. D29's HTML reporter only for library replays (`html=True`), so the action-capture
   parity copy is untouched. 4. The action replay POST answers 400 with the D28 rule (old clients get words, not a
   404); its DELETE is not registered. 5. MJ1: a verification whose overlay changes an action or setup promotes no
   case (the committed code did not run, D24). 6. The reports origin also checks `Host` (cheap DNS-rebinding guard).

#### Lesson candidates

- An intended stop must be recorded per worker, not per run: a per-run flag cleared by resume lets the killed
  worker's late `worker_exit` fail the resumed run (51-15 B3).
- L-089 recurrence: this session sent `npm run build` and a `git status` in one batch once; the read was discarded
  and redone alone after the build settled.

### Session 2 (2026-11-05)

#### Commits

| Repo | Commit | What |
|---|---|---|
| genesis | `f6d86ff` | web: D32 + m9, D31 + m7 + m11b, D30 + m11c, m8; `scripts/probes/` (B2 + L-090 probes) |
| genesis | `750f0d1` | web/static for `f6d86ff` |
| genesis | `b4265da` | review fixes: MJ-1, mi-1 (+ fixtures re-recorded), mi-2, mi-3, n-4 |
| genesis | `521910b` | web/static for `b4265da` (rebuilt after, `git status --short --untracked-files=all` empty in its own call) |
| project-tracker | this commit | As built, `reviews/51-15-review.md`, backlog §22 |

genesis-workflows: nothing in session 2 (`daf3612` stays the 51-15 commit). Nothing pushed or tagged.

#### Changed

- **D32 + m9** (`features/testing/ExecutionPage.tsx`): title = key + status and kind badges; actions View run
  (`/runs/<run_id>`, only when the execution has a run), Open report (reports origin, only while the files exist),
  Cancel while queued/running (409 detail in place). Summary card: 8 stat tiles (Scenarios, Cases, Passed, Failed,
  Flaky, Blocked, Not run, Duration) + the cancelled reason / launch error from `totals` + a collapsed `<details>`
  (environment, workspace commit, apwt, Playwright, trigger, started, finished). Results card: "N of M" + a
  "Show: all · failed · flaky · blocked" select; a grid of scenarios (Key, Title, Data setup, Status, Duration) whose
  rows are `role="button"` with `aria-expanded` (click/Enter/Space); failed and blocked start expanded
  (`logic.ts startsExpanded`); the expanded row holds a steps table (#, Case, Title, Status, Duration), each error once
  at its step (`scenarioErrorShown`: on the scenario only when no step has one), screenshots as 160×96 thumbnails that
  open full size in a new tab, other files as labelled links. Breadcrumb (`shared/layout/breadcrumbs.ts`): Application ›
  Testing (`?tab=testing`) › Executions (`?view=executions`); the Back button is gone.
- **D31 + m11b + m7** — the shared pattern in `features/testing/grid.tsx` (components: `GridCard`, `EmptyCard`,
  `Pager`, `CountOf`, `SortTh`, class constants) and `grid-logic.ts` (`rowOpenProps`, `rowClickProps`, `usePaged`
  page size 20, `nextSort`, `compare`). Library (`LibraryView.tsx`), Executions (`ExecutionsView.tsx`; server-side
  kind/status filters kept, a client search over key/trigger, "N of M" from the unfiltered query, `limit=200`, "200+"
  at the cap), Regression members (`RegressionView.tsx` `MembersGrid`: one table in data-setup group order with a
  Data setup column carrying shared/private, search + "Any data setup" filter, the suite actions on the right; a row
  opens its scenario page — m7) and Setup test users (`setup/UsersSection.tsx`: search, "N of M", Add user right; a row
  click opens Edit).
- **D30 + m11c** — the Library's All · Actions · Data setups `SegmentedControl` is gone; "Any kind" is a filter-row
  `Select` kept in the URL as `?kind=action|setup` (`logic.ts kindFromUrl`; unknown → Any kind). Testing now has one
  tab row below the application tabs.
- **m8** (`test-design/CasesTable.tsx`): Type 108 → 96, Review 136 → 112, `min-w` 1072 → 980 px (fixed 780 + Title
  floor 200); the layout pin in `testDesign.test.tsx` asserts `min-w = fixed + 200 ≤ 982`.
- **MJ-1 (review)** (`test-design/TestScenarioPage.tsx`, `types/testdesign.ts`, `breadcrumbs.ts`): a regression-owned
  scenario (`feature: {id: null, …}`, 51-08 D9) gets the trail Application › Testing › Regression, its automation from
  the scenario read's own `cases` (now for every scenario, not the feature suite), Add step through the Regression
  view's `CasePicker`, and Delete back to the Regression view; `NoFeatureRef` in the contract type.
- **mi-1 (review)**: `FakeRunner(evidence=True)` writes Playwright's report and a screenshot; a new API test drives a
  failed and a passed setup replay through the item read; the contract fixtures were re-recorded from real responses
  (`GENESIS_WRITE_CONTRACT_FIXTURES=1`; `library-setup-item.json` now carries a reports-origin `report_url`;
  `error-lifecycle.json` carried the pre-D28 refusal text, so its web test now asserts the recorded words).
- **mi-2 / mi-3 (review)** (`runs/manager.py`, `api/run_routes.py`): `_resumable` refuses resume/respond of a missing
  or terminal run (`RunStateError` → 409, nothing written, no worker); `_announce_final` drops the run's
  `_worker_state` entry.
- **Probes** (new, read-only, committed for the 51-12 re-run): `scripts/probes/reports-origin-isolation.mjs` (picks the
  newest execution with report files; 12 checks; exit 0/1/2) and `scripts/probes/testing-widths.mjs` (starts Vite from
  `web/` on :5174 proxying `/api` to :8760, measures every `main table` per page × width × theme, writes `result.json`
  + screenshots).

#### Tests (session 2)

- web: tsc clean; eslint 0 errors / 20 warnings (the base count; the new files are warning-free after moving the
  non-component exports to `grid-logic.ts` and `logic.ts`); vitest **698 passed (61 files)** (672 after session 1).
  New/rewritten: `executions.test.tsx` (grid open by click/Space, sort, server filters, search + N of M, paging 23 →
  20 + 3, 200+, empty; page header/View run/Open report, tiles + Details, expanded failed scenario with the error once,
  blocked scenario error, Show filter, thumbnails + labelled links + no `/api`, pruned, Cancel 409, waiting, axe);
  `library.test.tsx` (grid, Enter, D30 URL write/read, paging); `regression.test.tsx` (grid order, m7 row click and
  title-button Enter, filters, empty); `setup.test.tsx` (row click opens Edit, the password field does not; search);
  `testingTab.test.tsx` (one tablist; `?kind=` reaches Library); `phase49.test.tsx` (regression-owned scenario page,
  Delete → Regression); `breadcrumbs.test.tsx` (Executions trail; regression scenario trail).
- genesis: `ruff check genesis` clean; pytest **1727 passed** (937 s; 1725 + the D29 glue test + the resume guard
  test; the cancel test also asserts the `_worker_state` drop).
- genesis-workflows (unchanged, re-run): `validate_library` PASSED (17), `validate_skills` PASSED (4), pytest 363.
- Bundle: `750f0d1` and `521910b` each followed by a rebuild and an empty `git status --short --untracked-files=all`
  in its own call; the reviewer's out-of-tree build diffed identical both times.

#### Real-browser evidence

- **B2** — `node scripts/probes/reports-origin-isolation.mjs` against main :8760 (reports :8860, a live TE report):
  **12/12 PASS** — the report loads on :8860 (a different origin from :8760); `nosniff`; `index.html`
  `no-cache, must-revalidate`; same-origin `/api/applications` → 404 (9 bytes); cross-origin `fetch` and XHR to
  `:8760/api/applications` blocked (no CORS); `no-cors` fetch opaque, 0 bytes; `/executions/../../etc/passwd`,
  `/executions/%2e%2e/%2e%2e/`, `/`, `/api/applications` → 404; POST → 405. Result:
  `/tmp/genesis-probes/51-15/reports-origin-isolation.json`. Reviewer re-run: 12/12.
- **L-090** — `node scripts/probes/testing-widths.mjs --app _a-0000e5bc…_930416 --feature 4 --execution
  TE-000003,TE-000006`, 1280/1440/1920 × light/dark (`/tmp/genesis-probes/51-15/widths-run6/`): Tailwind resolved,
  no page horizontal scroll, no table wider than its card, no header wrapping or clipped, no cell spilling, in all 42
  entries. Column widths (px, identical in both themes):

  | Table | 1280 | 1440 | 1920 |
  |---|---|---|---|
  | Library (Key 108 · Kind 108 · Area 112 · Role 160 · Status 88 · Used by 84 · Last result 150) — table / Name | 982 / 172 | 1142 / 332 | 1350 / 540 |
  | Executions (Key 120 · Kind 136 · Trigger 150 · Status 116 · Duration 112 · Started 132) — table / Totals | 982 / 216 | 1142 / 376 | 1350 / 584 |
  | Regression (Key 112 · Data setup 176 · Source 168 · State 188 · controls 112) — table / Title | 982 / 226 | 1142 / 386 | 1350 / 594 |
  | Setup users (Username 180 · Password 136 · Set password 316 · actions 88) — table / Role | 940 / 220 | 1100 / 380 | 1308 / 588 |
  | Execution results (expand 44 · Key 112 · Data setup 150 · Status 200 · Duration 96) — table / Title; steps table | 982 / 380; 950 | 1142 / 540; 1110 | 1350 / 748; 1318 |
  | CasesTable (m8; fixed 780) — table / Title | **982 / 202** (was 982 scroller, 1072 table) | 1142 / 362 | 1074 / 294 (coverage beside it from 2xl) |

  Run 5 (the first clean run of the measure) still showed, in the screenshots, Library Role and Setup Role wrapping,
  Regression Source / not-automated pills wrapping into blobs and the Duration tile wrapping; the widths above and the
  Regression text/badge change came from those screenshots and were re-probed (run 6).

#### Review

`reviews/51-15-review.md`: first pass **NEEDS_CHANGES** (MJ-1; mi-1..mi-3; n-1..n-6), all session-1 and session-2
decisions accepted; delta re-review of `b4265da`/`521910b` **SHIP** (MJ-1 checked live on TS-000024: Regression
crumbs, no `features/null`, Automated). n-1, n-2, n-3, n-5 and the re-review nits rn-1..rn-3 → backlog
`specs/backlog/phase-51-follow-ups.md` §22.

#### Decisions / deviations (session 2)

1. Rows that hold their own controls (Regression move/remove, Setup password form) are not `role="button"`: a button
   inside `role="button"` fails axe `nested-interactive`. A click outside the controls opens the item; the keyboard
   path is an "Open TS-…" title button (Regression) or the existing Edit button (Setup). Library, Executions and the
   execution page's scenario rows are `role="button"` as D31 says.
2. Page size 20 (D31 names none; Stories uses 10).
3. Executions keep the server-side kind/status filters; "N of M" takes M from the unfiltered query (one request while
   no filter is set), capped at 200 and shown as "200+".
4. The execution page's "Not run" tile counts not-run + skipped (D32 lists no Skipped tile). The breadcrumb stops at
   Executions; the `TE-` key is the page title, as on the other Testing pages (D32 wrote "› `TE-…`"; review n-6).
5. Regression's Source is plain text and the not-automated reason sits under its badge (the probe showed wrapped
   pills).
6. The regression scenario page (MJ-1) takes the automation from the scenario read's own `cases` for every scenario,
   which also removes the feature-suite read from that section.

No ADR deviation.

#### Lesson candidates (session 2)

- A new link into an existing page is a new caller: test the target page with every shape the new caller sends
  (m7 linked regression scenarios, `feature.id === null`, to a page that only knew feature scenarios; the m7 test
  checked the URL only — 51-15 MJ-1).
- A contract fixture recorded once and never re-recorded drifts in its *values* while its *shape* stays: the shape
  check passed while `error-lifecycle.json` still carried the pre-D28 refusal text and a web test asserted that stale
  text (L-011 / L-083 corollary: re-record after changing a response's words, not only its keys).
- L-089 recurred twice in this session: a `git status` read sent in the same batch as `git add`/`commit` (and once
  before the build) reported the wrong tree; both commits were re-verified alone (`git show --stat`) and the bundle was
  proven with a rebuild and a status read in separate calls.
- A width probe that only checks overflow, clipping and header wrap passes layouts whose cells wrap badly (pills
  breaking across lines, a one-token role split at its hyphen): look at the screenshots too (L-090 corollary).

#### Code-map changes

- `genesis/web/src/features/testing/grid.tsx` + `grid-logic.ts` (new): the Testing grid pattern (D31).
- `genesis/web/src/features/testing/ExecutionPage.tsx`: the D32 layout; `logic.ts` gains `kindFromUrl`,
  `LIBRARY_KIND_LABEL`, `startsExpanded`, `scenarioErrorShown`.
- `genesis/web/src/features/test-design/TestScenarioPage.tsx`: handles a regression-owned scenario;
  `types/testdesign.ts` `NoFeatureRef`.
- `genesis/web/src/shared/layout/breadcrumbs.ts`: Executions crumb; `ts-regression:<id>` → Testing › Regression.
- `genesis/scripts/probes/` (new): `reports-origin-isolation.mjs`, `testing-widths.mjs`.
- `genesis/genesis/runs/manager.py`: `_resumable` (resume/respond refuse terminal runs); `_worker_state` dropped on the
  terminal announce. Session 1's map entries (as listed above in Session 1 → Changed) still apply:
  `genesis/testexec/reports_origin.py` (new), `RunStore.claim_status` / `note_progress`, `_follow_script` in
  `kb/testexec_store.py`, `promote_proven_actions`.

#### For 51-16, 51-17 and the 51-12 re-run

- **51-16 / 51-17:** reuse `SaveResult.changed`, the code-only contract (D27: every proposal and composed setup must
  declare literal `outputs`), `promote_proven_actions`, the reports-origin `report_url` helper, and the D31 grid
  helpers (`grid.tsx`, `grid-logic.ts`) for any new list. The Library's kind filter is `?kind=`; a new kind would need
  `kindFromUrl` and `LIBRARY_KIND_LABEL`. `FakeRunner(evidence=True)` in `tests/test_testing_api.py` is the fixture
  runner that writes report files.
- **51-12 re-run:** restart `serve` first (with no run active, L-061): :8760 still runs session-1 Python, so mi-2
  (resume of a terminal run → 409) and mi-3 are not live yet; the bundle on disk is current. Step 22 expects
  pause → paused → resume from the checkpoint; step 18 cancel → `cancelled` with one `run.final`; step 24 can use
  `scripts/probes/reports-origin-isolation.mjs`; step 20 can use `scripts/probes/testing-widths.mjs` (both themes,
  three widths) plus a look at the screenshots. The execution page has no Back button now (breadcrumb only).
