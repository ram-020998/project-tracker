# 51-15 — Review fixes from 51-12 (and the decisions D26–D32)

> **Status:** SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`,
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
