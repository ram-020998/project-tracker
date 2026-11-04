# Review 51-08 — base bb577c4 (genesis-review, 2026-11-04)

Scope: the **uncommitted working tree** of `genesis` against `bb577c4` (51-07): `git diff bb577c4` (28 tracked files)
plus the untracked `genesis/db/migrations/m0027_regression_notes.py`, `genesis/kb/regression_notes.py`,
`genesis/testexec/regression_service.py`, `tests/test_testexec_regression.py`. Spec:
`specs/phase-51-test-execution-engine/51-08-regression-suite.md`; route rows checked against `51-10-api.md` §2.
`genesis-ctx check --since bb577c4 --repo genesis` → 32 files; areas api, collaboration-hub, db, features-stages,
kb-sync, release-ci, runs-worker, security, stories-workbench.

**Live acceptance: not run, by agreement.** This sub-spec is backend-only. Nothing browser-visible changes (the only web
change is one optional-to-render field on `ScenarioDto` plus its contract test and fixtures), and no QA environment
exists to drive a real regression run. The UI for this backend is 51-11, and its live check belongs to 51-12.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1635 passed** in 1661 s (matches the dev's claim) |
| `.venv/bin/ruff check genesis tests/test_testexec_regression.py` | All checks passed |
| `web: npm run lint` | 0 errors, 20 warnings (pre-existing) |
| `web: npm run typecheck` | clean |
| `web: npx vitest run` | 50 files, **467 passed** |
| Stale bundle: `npx vite build --outDir /tmp/5108-static` then `diff -r /tmp/5108-static web/static` | identical (no web/static change needed; the type change is type-only) |

## Checklist

### ADRs
- [N/A] ADR-001 — no graph/agent control flow touched.
- [N/A] ADR-008 — no app/UI bundling change.
- [N/A] ADR-009 — no HITL change. Turning a schedule on is the D8.4 approval; the route only stores it.
- [OK] ADR-010 — notes store keys/titles/positions only (`regression_notes.py` `_insert`), no bulk.
- [N/A] ADR-011 — no agent node.
- [OK] ADR-012 — the app process imports no workflow Python. Run now goes through `TestExecutionService.start` → RunManager worker (`test_plan_preview_equals_the_generator_and_run_now_selection` asserts the recorded spawn).
- [N/A] ADR-018 — no node-to-node data.
- [N/A] ADR-019 — no CORE_MAJOR / library change.
- [N/A] ADR-021 — no write/deploy MCP node.
- [N/A] ADR-022 — no run artifacts written.
- [OK] ADR-023 — routes are plain FastAPI on the embedded app (`api/app.py` +6).
- [OK] ADR-024 — sync handlers run in FastAPI's threadpool, the same as the other `api/testing.py` routes. No sync SqliteSaver.
- [N/A] ADR-025 — no fork.
- [OK] ADR-026 — no auth or bind change. No route returns a password (`test_schedule_routes_and_the_setup_read` asserts `PASSWORD not in put.text`; the run test asserts it is not in the job).
- [N/A] ADR-027 — no UI components (type + contract test only).
- [OK] ADR-028 — every new route is registered on the `/api` router (`register_regression_routes(api, …)`; the tests hit `/api/applications/…`).
- [OK] ADR-030 — SQLite, forward-only m0027, repository signatures DB-agnostic.
- [N/A] ADR-031 — no chat surface.
- [N/A] ADR-032 — no credit figures.
- [N/A] ADR-033 — no copilot tools.
- [N/A] ADR-034 — no skills.
- [N/A] ADR-035 — no run input files.
- [N/A] ADR-036 — KB untouched. `kb/store.py` gains a comment only.
- [OK] ADR-037 — no SAIL source stored.
- [N/A] ADR-038 / ADR-039 — n/a.
- [N/A] ADR-041 — documents untouched.
- [OK] ADR-042 — the feature cascade is unchanged. The note is written in the same transaction before `DELETE FROM kb_features` (`kb/features.py:113-118`). Untrack still removes the features and, through the app FK, the suite and its notes (`test_untrack_removes_the_suite_and_writes_no_note`).
- [N/A] ADR-043 / ADR-044 / ADR-045 / ADR-049 — n/a.
- [OK] ADR-047 — the `regression-run` job definition stays backend-defined (51-06). Only the per-app `options.apps[<uuid>]` entry is user-written (`ScheduleStore.update_option_entry`). `enabled` and the schedule are not touched.
- [OK] ADR-050 — RegressionService changes no status. Retire/restore in the tests go through `build_test_lifecycle_service(...).transition`. New regression scenarios are created Draft through `TestDesignStore.create_scenario`.
- [N/A] ADR-054 — memory.db untouched.
- [N/A] ADR-055 — no UI.
- [OK] ADR-056 — no stage model change.
- [N/A] ADR-057 / ADR-058 / ADR-059 / ADR-060 / ADR-061 / ADR-062 — n/a.
- [OK] ADR-063 / ADR-064 / ADR-065 — `kb_regression_notes` is not a collab table (m0027 docstring; no binding added). The only collab change is local: the feature tombstone writes a local note before its local delete (`collab/service.py:589-595`). No Hub contract change.
- [N/A] ADR-066 / ADR-067 / ADR-068 / ADR-069 — n/a.
- [OK] ADR-070 — Object Wiki untouched (the ledger is append-only and not affected).
- [N/A] ADR-071 / ADR-072 / ADR-073 / ADR-074 / ADR-075 / ADR-076 — n/a.
- [OK] ADR-077 — no agent-system change.
- [OK] ADR-078 — only Draft cases and scenarios can be hard-deleted (`delete_case` / `delete_scenario` keep the D15 refusal). A retired referenced scenario keeps its row and reads `retired` (D21.1–2; `test_retiring_a_referenced_scenario_is_allowed_kept_and_skipped_then_restored`).
- [OK] ADR-079 — case/object links untouched. Cross-feature steps stay within the app (`test_get_returns_items_…`: "not a test case of this application").
- [OK] ADR-080 — app-only change, no package/pin change.

### Lessons
- [N/A] L-003, L-005, L-008, L-018, L-020, L-021, L-023, L-033, L-059, L-060, L-065, L-066 — no SSE/event/worker changes.
- [OK] L-004 — notes and schedule live in SQLite (`kb_regression_notes`, `scheduled_jobs.options_json`).
- [N/A] L-009 — no LangGraph use.
- [OK] L-010 — all routes under `/api`.
- [N/A] L-016, L-017, L-019, L-031, L-032, L-034, L-035, L-037, L-040, L-041, L-042, L-043, L-045, L-048, L-050, L-051, L-064, L-068, L-069, L-071, L-072, L-073, L-075, L-076, L-077, L-078, L-079, L-084, L-086, L-087, L-088, L-090, L-095, L-098, L-099, L-100 — area not touched.
- [OK] L-025 / L-027 — the pinned ruff is clean.
- [OK] L-026 — blocking DB/git work runs in sync handlers (threadpool), not on the event loop. The scheduled job path is unchanged from 51-06.
- [OK] L-030 — web files changed. The bundle is unchanged (type-only), proven by an off-tree build and `diff -r`.
- [OK] L-039 — `referenced_by_regression` is computed in the one `_scenario_dtos` builder (`kb/testdesign.py:281-299`), so list, get and regression items all carry it (`test_referenced_by_regression_is_the_same_on_list_and_get`). GET and PUT `/testing/setup` share `_setup_view` (asserted in `test_schedule_routes_and_the_setup_read`).
- [N/A] L-056 / L-057 — no release yet. Note for the dev: the four untracked files must be `git add`-ed in the 51-08 commit, or the tests ship without their implementation.
- [OK] L-058 / L-061 / L-062 / L-093 — no finalizer change. Run now reuses `start_regression`.
- [OK] L-063 — no prerequisite-stage change.
- [OK] L-074 — membership stays explicit (add/remove reference). Nothing is auto-derived, and `add_items` adds only what the proposal names.
- [OK] L-080 — the `since` watermark is stamped at the save, before the job's next tick (`test_turning_a_schedule_on_does_not_run_the_most_recent_past_slot`).
- [OK] L-081 — `update_option_entry` sets `user_modified=1` and keeps other apps' entries. A later `ensure_defaults` keeps them (`test_schedule_round_trip_keeps_other_apps_and_writes_since`). The default is off.
- [OK] L-082 / L-085 — the tombstone path is exercised end to end over two instances and the local Hub (`test_a_collab_feature_tombstone_writes_the_note`).
- [OK] L-083 — the test stories use the real breakdown AC shape (Given/When/Then text).
- [OK] L-089 — reviewer verified the bundle in separate calls (build, then diff). The dev reports `git status` clean of `web/static`.
- [OK] L-091 — every writer takes the write lock before it validates or computes: `FeatureStore.delete_feature` and the collab tombstone use `BEGIN IMMEDIATE` before `note_feature_delete`. `delete_case` and `delete_scenario` run a no-op UPDATE first (`testdesign.py:824, 852-854`). `add_items`, `update_option_entry` and `RegressionStore.dismiss` write first.
- [OK] L-092 — the migration module and object are `regression_notes`, not `test_*` (asserted in `test_m0027_fresh_db_…`). No `tests/__init__.py` was added.
- [OK] L-094 — the new `referenced_by_regression` field and the new `cause` value were grepped by the reviewer: the scenario DTO consumers are the testdesign store, `RegressionStore.items/scenarios` and the generator catalog. None serializes the dict to the Hub (Test Design is local only).
- [OK] L-096 — the new paths do not collide with a generic path-param route. `/applications/{app}/test-scenarios/{key}/setup` is distinct from `/test-scenarios/{scenario_id}[/…]` (`api/testdesign.py:382-422`). `/testing/schedule` and `/testing/summary` share no generic `/testing/{x}` sibling. The route tests hit each of them.
- [N/A] L-097 — no startup sweep.

### Gates
- [OK] `pytest -q -p no:warnings`: 1635 passed. This one run covers the api, collaboration-hub, db, features-stages, kb-sync, runs-worker and stories-workbench lines.
- [OK] `ruff check genesis`: clean (all areas).
- [OK] `web: npm run lint && npm run typecheck && npm test`: 0 errors / clean / 467 passed (collaboration-hub, features-stages, stories-workbench).
- [OK] `web: npm run build` (then commit web/static): the off-tree build equals the committed `web/static`, so nothing needs committing.

## Spec conformance (51-08 §2–§5)

- §2 `get` / `add_reference` / `remove_reference` (works on a retired one) / `reorder` / own scenarios / `grouping`
  (implemented as `plan`) / `run_now` / `apply_verification_proposal` / `latest` / `trend` (n=20): all present and tested.
- D21 single selection: `regression_selection` (`kb/testexec_store.py`) is used by `RegressionService.plan` and
  `run_now`, by `TestExecutionService.regression_scenario_ids` and `start_regression` (and so by the job), and by
  `generator._catalog_order`. The old ad-hoc filter in `regression_scenario_ids` is removed. The plan's group and file
  order matches the generator: `ordered_folders` is shared, and `_config_ts` also iterates `sorted(folders)`.
- §3 m0027: columns, FK CASCADE, index, no `foreign_keys_off`, fresh DB and a populated v26 upgrade with rows intact plus `foreign_key_check` (two tests). Writers: every `DELETE FROM kb_features` site was grepped. They are `features.py:118` (noted), `collab/service.py` tombstone (noted) and `kb/store.py:130` untrack (no note, by spec). Each path has a test.
- §4 schedule: `since` is stamped on turn-on or a change, kept on an unchanged save, dropped on off. The other apps' entries are kept. The "within an hour" note is shown. Validation is tested.
- §5 tests: every listed item has a test, except "case delete writes exactly one note" (see m2) and "exactly one note" for a feature delete (see m1).

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1 — One note per (suite, kind), not one per suite (dev deviation 3).** `record_losses` writes a
  `reference-removed` note and a `steps-removed` note when one feature delete removes both (`regression_notes.py:72-80`;
  `test_feature_delete_writes_one_note_per_kind_…`). Spec §3 says "one note per affected suite" and §5 says "exactly one
  note". The spec's own schema has a single `kind` column, so it cannot hold both kinds in one row. The dev's reading is
  the consistent one and I accept it. **Fix:** record it as an As-built decision. Also tell 51-11 that one delete can
  produce two notes that share `cause` + `cause_key` (the UI may want to group them).
- **m2 — The `case-deleted` note is unreachable today (dev deviation 1).** `delete_case` refuses any case used by a
  scenario step, regression scenarios included (`testdesign.py:830-835`), so the `record_losses` call at
  `testdesign.py:840-845` always writes nothing. The shared writer is tested directly
  (`test_the_shared_writer_records_regression_steps_of_a_deleted_case`), and the refusal is tested
  (`test_case_delete_is_refused_…`). The code comment says this honestly. No change is required. **Fix:** record it in
  As built so the docs agent does not describe case deletes as a live note source.
- **m3 — The error codes differ from 51-10 §1 wording (dev deviations 4–5).** Schedule and request validation return 400. 51-10 §1 lists 404/409/422, and 422 only for a failed typecheck. The `PATCH …/test-scenarios/{key}/setup` route also requires `row_version`, which the 51-10 table omits. Both choices follow the existing `api/testing.py` convention and the Phase 49 CAS rule, and both are right. **Fix:** update the 51-10 table rows (`row_version` required; 400 for validation) so 51-11 builds against the real contract.

### Nits
- **n1** — `run_now` reads the selection, then `start_regression` reads it again (`regression_service.py` `run_now`).
  A retire landing between the two reads could make `not_run` disagree with what ran. This is harmless in a
  single-user app. Optionally pass the selection through.
- **n2** — `RegressionScenarioBody` (`api/testing.py`) restates the Phase 49 `ScenarioCreate` fields instead of reusing it.
- **n3** — Regenerating the four fixtures also churned every `sync_uuid` and timestamp. Only `referenced_by_regression`
  is meaningful in that diff. That is acceptable, but a reviewer reading the diff has to filter the noise.
- **n4** — `GET …/testing/regression` (and `/plan`, `/run`) creates the suite row on first read. The spec asks for this
  ("created on first read"). Noted only because it is a write behind a GET.

## Verdict: **SHIP**

There are no blockers and no majors, and every gate is green on the reviewer's own runs. The three minors are spec
and As-built records, not code changes. The dev must still `git add` the four untracked files in the 51-08 commit
(L-056).
