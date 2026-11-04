# Review 51-10 — base 7daa505 (genesis-review, 2026-11-04)

Scope: the uncommitted working tree of `genesis` against `7daa505` (51-09): 15 modified files and 47 untracked files
(`genesis/testexec/jobs.py`, `tests/test_testing_api.py`, `tests/contract_fixtures.py`, `web/src/types/testing.ts`,
`web/src/features/testing/contract.test.ts`, 42 fixtures under `web/src/test/fixtures/testing/`). I also read the
project-tracker working-tree change to `51-10-api.md` (§2 contract table reconciled).
`genesis-workflows` is clean (`git status --short` empty). This change does not touch it, so no working workflow changed.

**Live acceptance: not needed and not run.** 51-10 adds backend routes plus web types and fixtures, with no UI. The
screens that use these routes are built and accepted live in 51-11/51-12.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` (+ the two new test modules) | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1666 passed** in 482 s (1653 at 51-09 + 13 new) |
| `web: npx tsc --noEmit` | clean |
| `web: npx eslint src/types/testing.ts src/features/testing/contract.test.ts src/types/testdesign.ts` | clean |
| `web: npx vitest run` | **510 passed** (51 files) |
| stale bundle: `npx vite build --outDir /tmp/51-10-static` then `diff -r /tmp/51-10-static web/static` | identical (the change affects no shipped web code) |
| `grep Pw\|password` over the 42 fixtures | no test password in any fixture |

## Checklist

### ADRs
- [N/A] ADR-011 — reliability trio: no agent node or workflow changed.
- [OK] ADR-012 — the app never imports workflow Python. `RecordingService.start` calls `RunManager._meta`
  (`recording.py:140-145`), which reads only `check_compat` and the yaml (`runs/manager.py:110-112`, "no graph import").
  The library Replay runs Playwright from the app process as a job thread. That is the 51-07 design, which this
  sub-spec §1 adopts.
- [N/A] ADR-019 — no package version or `CORE_MAJOR` change.
- [OK] ADR-023 — the new routes are FastAPI routes registered on the existing `api` router (`app.py` diff).
- [OK] ADR-026 — no bind or auth change. The new routes add no network surface beyond the loopback app.
- [N/A] ADR-027 / ADR-055 — no component or styling change. Only types and a contract test.
- [OK] ADR-028 — every new route is declared on `api` (the `/api` router). The test's `ScanningClient` resolves
  through `/api/…`, and `test_every_phase_51_route_answers_without_a_secret` asserts that every declared Phase 51 route
  was answered through `/api`.
- [N/A] ADR-031 / 033 / 034 / 045 — no chat or copilot change, and no chat tool reaches these routes.
- [N/A] ADR-035 — no run-input upload change.
- [N/A] ADR-043 — no Lavish change.
- [N/A] ADR-046 / ADR-080 — no packaging change.
- [N/A] ADR-047 / ADR-074 — no sync change.
- [OK] ADR-050 — library transitions go through `library.transition` (51-07's `LifecycleService` path). The route
  maps `IllegalTransitionError` and `PreconditionFailedError` to 409 (`api/testing.py` `_call`).
  `test_every_phase_51_route…` asserts the `precondition_failed` refusal (`error-lifecycle.json`).
- [N/A] ADR-063 / ADR-065 — nothing published to the Hub.
- [N/A] ADR-071 — no story surface.
- [N/A] ADR-076 — no spec change path.
- [OK] ADR-077 — review run without `--trust-all-tools`. The context came from `genesis-ctx check`.

### Lessons
- [N/A] L-003 / L-018 — no SSE change.
- [OK] L-004 — jobs are intentionally in memory (D23: not persisted; 404 after a restart, while the setup and runtime
  reads report the real state). All durable data stays in SQLite.
- [OK] L-010 — see ADR-028.
- [OK] L-011 / L-083 — the 42 fixtures are written by `record()` from real responses (`tests/contract_fixtures.py`).
  The backend fails on a shape drift (`shape()` compares keys recursively). `contract.test.ts` checks every fixture
  against an `Exact<T>` key list and fails on a fixture that has no check. The impact stub's `totals` now has the real
  keys (`test_testexec_execution.py`, L-083).
- [N/A] L-017 / L-045 — no chat trust change.
- [OK] L-019 — password writes are unchanged. `secret_values` only reads (`settings_service.py:207-217`).
- [N/A] L-025 / L-027 — the ruff pin is untouched.
- [N/A] L-030 / L-056 / L-057 / L-089 — release items for 51-13. Note for release: the commit must include all 47
  untracked files (L-056).
- [N/A] L-031 / L-048 / L-051 / L-068 / L-087 / L-088 / L-098 / L-099 / L-100.
- [OK] L-026 (from the manifest) — every new handler is a sync `def`. `grep "async def" genesis/api/testing.py` finds
  none, so they run in the threadpool. The long work runs in a daemon thread per job (`jobs.py` `submit`). The startup
  sweep uses `asyncio.to_thread` (`app.py` diff).
- [OK] L-039 — the list row is the store row + `where_used_count`. The single get adds `where_used` / `allowed` /
  code / history. The §2 table documents both shapes, and each has its own fixture (`library-list.json`,
  `library-item.json`).
- [N/A] L-092 — `contract_fixtures.py` is not named `test_*`. `TestingJobs.__test__ = False`.
- [OK] L-096 — no `{kind}` path parameter (`_register_kind` registers literal `/testing/actions` and `/testing/setups`,
  so `/testing/setup` cannot be shadowed). `test_no_route_is_shadowed_by_an_earlier_path_parameter_route` walks the whole
  route table, including the `_IncludedRouter` unwrap. `test_literal_routes_answer_beside_their_parameter_siblings`
  proves it by behaviour (changes/adopt, setup/setups, test-impact/run, regression/plan).
- [OK] L-097 — `test_jobs.reap_stale` and `test_library.prune_replays` run only inside
  `if manager.holds_run_owner_lock():` (`app.py` diff, next to the existing `reap_stale_replays`). The prune after each
  replay deletes only finished folders (an empty `.pids`) of this server's artifacts dir, and it never writes a
  terminal state.
- [OK] L-033 (manifest-adjacent) — recording start refuses when `action-capture` is not installed
  (`test_recording_start_refuses_without_the_skill_or_the_workflow`,
  `test_testexec_recording.py::test_one_recording_at_a_time_and_readiness_refusals`).

### Specific asks
- [OK] No secret in any response or job. `ScanningClient` checks every response of every Phase 51 route for the raw,
  JSON-escaped and HTML-escaped forms of `Pw"5110&<x>` (`c.leaks == []`). Job error and result text is scrubbed
  (`test_jobs_single_flight_status_and_scrubbed_error`). No fixture contains a test password.
- [OK] CAS conventions. `ItemSaveBody.expected_row_version: int` is required, so a body without it gets a 422. A stale
  version returns the house `stale_write` body and writes nothing (`test_item_put_requires_and_checks_expected_row_version`,
  which checks a metadata save and a code save, and that HEAD does not contain `// stale`). The verification decisions
  route now returns the same house body (`test_story_verification.py` asserts `detail.error == "stale_write"`).
- [OK] D23 jobs. The routes return 202. A second POST returns the same running job (single flight). The status moves
  to succeeded or failed with the error. An unknown id, or any id after a restart, returns 404. Children are recorded in
  `jobs/.pids` and reaped at startup. Finished jobs are kept for 1 h. Tests:
  `test_setup_jobs_answer_202_single_flight_and_404_after_a_restart`, `test_finished_jobs_are_kept_one_hour`,
  `test_a_jobs_children_are_recorded_and_reaped_at_startup`.
- [OK] Library Replay as a job. A repeat POST returns the running job (single flight). A cancel reaps a real child and
  records nothing (`last_replay is None`). The refusals (400, and 409 for a missing password) come back before any job
  is queued. A pass approves the item. Retention keeps 20 folders per app, skips a busy one, and leaves other apps
  alone. Tests: `test_replay_job_single_flight_cancel_reaps_and_records_nothing`,
  `test_replay_refusals_answer_at_once_and_a_pass_approves`, `test_replay_retention_keeps_the_newest_20_per_app`.
- [OK] `set_scenario_setup` wrapper fix (`api/testing.py:447-450`). The fix is defensive: `set_scenario_setup` raises
  only `RegressionError`/`StaleWriteError`/`RegressionNotFound`, so the `JSONResponse` branch was not reachable before.
  No regression test is possible, and none is required.
- [OK] Discard refuses 409 unless the capture is `recording` or `ready`. The test sends an `analysing` capture and
  asserts the 409 with `problems`.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1 — A failure while finishing a job leaves it `running` forever.** In `TestingJobs._run` (`jobs.py:187-205`),
  `self._scrubbed(result, secrets)` (`json.dumps` → scrub → `json.loads`) and `scrub_text` run outside the `try`. If
  they raise, the thread dies with the job still `running`. `done` is never set, and the single-flight key blocks every
  later Chromium, workspace or replay job until a restart. `json.dumps` errors are caught (with a fallback to
  `str(result)`), but the `json.loads` after the scrub is not. A scrub replacement can leave the JSON invalid: a password
  that equals the tail of a `\uXXXX` escape in the dumped text, for example, leaves `\***`. The trigger is unlikely,
  but the failure mode is a wedged registry. **Fix:** wrap the finish (scrub + store) in `try/except Exception`. On
  failure, store `status = "failed"` with a generic error and `result = None`, and always `job.done.set()` in a
  `finally`. Add a unit test with a `secrets` callable whose value breaks the JSON (or one that raises after the
  lookup).
- **m2 — The verification-apply 422 and 409 shapes changed with no route-level test.** `api/workbench.py:516-520`
  changed the 422 from a nested `{detail:{detail, errors}}` to `{detail, typecheck}`, and the `ConflictError` 409 from
  a string to `refused()`. `typecheck_failed` is tested through the library PUT, but no test drives
  `POST …/verification/proposals/apply` into a `TypecheckError`. The exception order matters here, because `TypecheckError`
  has to be caught before `(VerificationError, LibraryError)`. Also, no `error-typecheck` fixture is recorded from this
  route, although 51-11 will read it there. **Fix:** add one route test in `test_story_verification_apply.py` that
  makes the typecheck fail, asserts `422` with `r.json()["typecheck"]`, and calls `record("error-typecheck", …)` or
  asserts the same shape.
- **m3 — Discard checks the status outside the recording lock (TOCTOU).** `api/testing.py:788-795` reads
  `cap["status"]` and then calls `recordings.discard`. A recording whose window closes, or that `refresh`/`stop` moves to
  `analysing`, between the two calls reaches the service's silent no-op and answers 200 with the capture. That is
  the behaviour this route was changed to refuse. **Fix:** have `RecordingService.discard` raise
  `RecordingError(..., problems=[...])` itself, under its lock, when the status is not `recording`/`ready` (so
  `conflict` maps it to 409). Keep the route's check as a fast path or drop it.
- **m4 — A small cancel window lets a replay's Playwright escape the cancel reap.** `library_service.py:884-886`
  checks `stopped()` and then creates and starts the runner. A cancel that lands between the check and
  `start_long_lived` reaps an empty `.pids`. Playwright then runs to the end (up to `REPLAY_GLOBAL_TIMEOUT_S` = 900 s)
  before the post-run `stopped()` turns the job `cancelled`. Nothing is recorded, so this is not a correctness bug. The
  cost is a stray browser and a job that stays `running` for minutes after the user pressed Cancel. **Fix (cheap):** in
  `JobContext`, check `cancelled()` again right after the runner records its group, or have the runner take a
  `cancelled` callback and stop its child when it turns true. Otherwise, document the window in the docstring.

### Nits
- **n1 — The fixtures contain machine-specific absolute paths.** `report_dir`, `html_path`, `inputs_dir`,
  `source_doc_path` and the workspace `path` in `verification.json`, `job.json`, `setup.json`, `execution*.json`,
  `impact-run.json` and `library-run-dependents.json` contain
  `/private/var/folders/…/pytest-of-ramaswamy.u/pytest-635/…`. Only key shapes are compared, so tests are unaffected.
  However, every regeneration churns these files, and the local username ends up in the repo. Normalise the paths in
  `record()` when writing (for example, replace the tmp prefix with `<tmp>`).
- **n2 — Some read routes have no error mapping.** `adopt_changes` calls `library.status(app_uuid)` outside `_call`
  (`api/testing.py:673`), and `get_capture` calls `capture_finalizer.reconcile_capture(cap)` bare (`:769`). A
  `WorkspaceError` there becomes a 500 instead of the documented 502.
- **n3 — `list_captures` does not validate `status`** (`:755`). An unknown value silently returns an empty list. The
  executions list answers 400 for a bad status (`test_execution_routes`).
- **n4 — Two copies of the private `_meta` probe.** `RecordingService.start` now calls `RunManager._meta` as 51-09's
  verification check does. Two callers of a private method suggest a small public `RunManager.is_installed(workflow_id)`
  later (backlog, not now).
- **n5 — No "As built" section yet.** `51-10-api.md` has only the reconciled §2. The dev still has to write the As
  built section (commits, the `cancelled` status deviation from D23, the shape changes on the verification routes).

## Deviations and their effect on 51-11..51-13
- **Job status `cancelled`** (D23 listed only running·succeeded·failed). It is in the §2 table and in
  `TERMINAL_JOB_STATUSES` (`types/testing.ts`). 51-11's polling must treat it as terminal. The types already do.
- **Verification decisions/apply error bodies changed.** The 409 is now `{detail:{error:"stale_write",…}}` (was a
  string), a `ConflictError` is a top-level `{detail, problems}`, and the 422 is `{detail, typecheck}` (was nested
  `errors`). No web code consumed the old shapes (grep of `web/src` found none). 51-11 can reuse
  `features/test-design/logic.ts` `isStaleWrite`.
- **New route** `POST …/{key}/save-as-new`, required by D16.5's "Save as new". The recording start error is split:
  409 when `conflict`, 400 for no intent or a bad start page. Discard is now a 409 outside recording/ready. All three are
  in §2. 51-11 should key its UI on these codes.
- **Setup routes return 202 + job** instead of the 51-05 synchronous body (and 502). No current web or CLI caller
  exists (grep). 51-11 §(Setup) already plans polling, and its Settings → CLI Install uses the same job.
- 51-12 acceptance should include a live check of the job flow (create the workspace, install Chromium, cancel a
  replay) and the m4 window, because the fixture test uses a stand-in runner.
- 51-13: the commit must include all 47 untracked files (L-056).

## Verdict: SHIP

No blockers and no majors. Every gate is green and was re-run by the reviewer. The minors (m1–m4) are real but
bounded. m1 and m3 should be fixed before 51-11 builds on the job and discard behaviour. They are small changes in
`jobs.py` and `recording.py`, each with a unit test, and can go in a follow-up commit within this sub-spec or at the
start of 51-11.

---

## Re-review — follow-up fixes, still uncommitted on base 7daa505 (genesis-review, 2026-11-02)

Scope: the working-tree changes made after the SHIP verdict above, which address m1–m4 and n1–n3. I read the diff
(`git diff 7daa505` plus the untracked `jobs.py`, `contract_fixtures.py`, `test_testing_api.py`) and re-ran the gates.
`genesis-ctx check --since 7daa505 --repo genesis` lists the same areas (api, release-ci, security) and rules as the
first review. No fix touches a new area, ADR or lesson, so the checklist above stands unchanged.

### Fix-by-fix

- [OK] **m1 — the job always finishes.** `jobs.py` `_run`: the scrub and store sit in `try/except Exception`. On
  failure the job gets status `failed` (or `cancelled` if a cancel was asked for), the generic error "the job finished
  but its outcome could not be stored", and `result=None`. The `self._lock` store is in a `try/finally: job.done.set()`.
  `_secret_values` already swallows lookup failures. Test
  `test_a_job_whose_outcome_cannot_be_stored_still_finishes` (`test_testing_api.py:278`) makes `_scrubbed` raise. It
  asserts `failed`, `result is None` and the generic error, and that a second submit on the same flight creates a new
  job, which proves the single-flight key is released. Before the fix the thread died and `wait(…, 10)` returned
  `running`, so the test would have failed.
- [OK] **m2 — apply-route error shapes.** `test_the_apply_route_answers_the_shared_error_shapes`
  (`test_story_verification.py:573`) monkeypatches `env.ver.apply` and drives the real route three times:
  - `TypecheckError` → 422 `== {detail, typecheck}`, recorded as `error-typecheck`.
  - `ConflictError` → 409 with `problems == [detail]`.
  - `StaleWriteError` → 409 `{"detail": {"error": "stale_write", "expected": 1, "actual": 2}}`.
  
  This also pins the exception order (`TypecheckError` before the 400s). The decisions route now asserts the
  `stale_write` body too. The test is in `test_story_verification.py`, not `_apply.py` as I suggested. That placement
  is fine.
- [OK] **m3 — discard refuses under the lock.** `recording.py` `_discard` re-reads the capture inside the service lock.
  It raises `RecordingError(reason, problems=[reason])` unless the status is `recording`/`ready`; `conflict` is true
  because `problems` is given, so `_call` maps it to 409. The `set_status` call is now unconditional, with
  `expected_status`. The route (`api/testing.py:795-801`) dropped its pre-check and relies on `_call`. No other caller
  depended on the old silent no-op: grep finds no other `recordings.discard` caller. Tests: the second discard is
  refused with `conflict` (`test_testexec_recording.py::test_discard_stops_the_recorder`), and the route answers 409
  with `problems` for an `analysing` capture (`test_testing_api.py:654`).
- [OK] **m4 — a child started after the cancel is stopped.** `cancel` reaps once and then starts
  `_reap_until_done`. That thread runs `job.done.wait(0.5)` in a loop, re-reaping the job's own folders
  (`pid_dirs[1:]`, never the shared jobs folder) until the job's thread returns or 60 s pass. The replay's `.pids` is
  registered by `ctx.add_pid_dir` before `library.replay` starts its runner (`api/testing.py:869`), so the window I
  described is covered. Test `test_a_cancel_also_stops_a_child_started_after_it` cancels before the work spawns a real
  `sleep 60` child in that folder. It asserts the job ends `cancelled` within 20 s and the child has exited. Without
  the re-reap the child would live 60 s, so the test would fail.
- [OK] **n1 — no machine paths in the fixtures.** `contract_fixtures.record()` replaces pytest tmp paths
  (macOS `/private/var/folders/…/T/pytest-of-*/pytest-N/<test>` and Linux `/tmp/pytest-of-*`) with `<tmp>` when
  writing. `grep -rl "pytest-of\|/private/var\|ramaswamy" web/src/test/fixtures/testing/` finds nothing.
- [OK] **n2 — read routes use the error mapping.** `library_changes` and `adopt_changes` call `_call(library.status, …)`
  and return its `JSONResponse` unchanged (`api/testing.py:666,674`). `reconcile_capture` is documented as never
  raising and does catch everything (`capture_finalizer.py:91-95`), so calling it bare is correct.
- [OK, nit] **n3 — the capture-list status is validated.** `list_captures` answers 400 for a status outside
  `VALID_CAPTURE_STATUSES` (`api/testing.py:763-764`). No test drives the 400 (grep for the message in `tests/` finds
  nothing). See n6.
- n4 is deferred to the backlog, as agreed. n5 (the As built) is still open and due after the commit.

### Gates (re-run by the reviewer)

- `ruff check genesis` plus the 9 changed or added test files: **All checks passed**. A bare `ruff check tests` shows
  26 errors in older test files that this change does not touch. CI runs `ruff check genesis`.
- `pytest tests/test_testing_api.py tests/test_testexec_recording.py tests/test_story_verification.py
  tests/test_story_verification_apply.py` in compare mode (no `GENESIS_WRITE_CONTRACT_FIXTURES`): **49 passed**.
- Full backend run (the author's background run, `/tmp/g5110-pytest2.log`): **1669 passed in 533.80 s**, no failures.
- Web: `vitest run src/features/testing` **43 passed**; `tsc --noEmit` clean. The follow-up changes only fixture JSON
  under `web/`, and `web/static` is unaffected.

### New findings

- **n6 (nit) — no test for the n3 400.** Add one line to the captures route test:
  `assert c.get(f"{base}/captures", params={"status": "bogus"}).status_code == 400`.
- **n7 (nit) — the m1 test's `broken_lookup` does nothing.** `_secret_values` already catches that error, so only the
  patched `_scrubbed` exercises the new `except`. The test is still valid. Drop the lookup, or keep it with a comment.

### L-056 reminder for the commit

The untracked set now also includes `tests/contract_fixtures.py`, `tests/test_testing_api.py`, `genesis/testexec/jobs.py`,
`web/src/features/testing/`, `web/src/test/fixtures/testing/` and `web/src/types/testing.ts`. Run `git status` before
committing and confirm that none of these is left out.

### Re-review verdict: SHIP

m1–m4 are fixed, each with a test that would have failed before the fix. n1–n3 are addressed. All gates are green,
including the full backend run (1669 passed). The two new nits (n6, n7) are optional and can go into this commit or
the next.
