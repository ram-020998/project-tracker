# 51-08 — The regression suite

> **Status:** **DONE 2026-11-04** (genesis `d701ea9`, local; review `reviews/51-08-review.md` = SHIP; see "As built").
> SPEC-DRAFTED 2026-11-02 (D21 added 2026-11-03). Repo: **genesis** (backend). Parent:
> `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D2, D9, D10, D11, D12.6, D14, D21; F13, F14.
> One migration **m0027** (DB 26 → 27).

## 1. Goal

One regression suite per application: references to feature scenarios plus its own cross-feature regression
scenarios, grouped by data setup, run on demand or on the app's schedule, with the latest result and a trend. Losses
from the feature side stay visible (D21).

## 2. `RegressionService` (`genesis/genesis/testexec/regression_service.py`)

Over `RegressionStore` (51-04 §3):
- `get(app_uuid)` → the suite (created on first read), its **items** (referenced feature scenarios with their feature,
  position, automated flag, and `retired` when the referenced scenario is retired, D21.2) and its **own scenarios**
  (normal `TS-` scenarios owned by the suite), each with its data setup, `changes_shared_data`, automated flag and last
  result; plus the undismissed **change notes** (§3).
- `add_reference(scenario_id)` / `remove_reference` / `reorder` — only non-retired scenarios of the same application;
  a regression-owned scenario cannot be "referenced" (it is already a member). `remove_reference` works on a retired
  reference (the D21.2 **Remove reference** button).
- Own scenarios: create/edit/reorder steps/retire through the Phase 49 scenario paths with the cross-feature rule
  (51-04 §3); their lifecycle = `TEST_TRANSITIONS`; `TS-` keys from the same sequence.
- **Retired references (D21.1–2):** retiring a referenced feature scenario stays allowed. The Phase 49 scenario DTO
  gains `referenced_by_regression: bool` (one DTO builder for list and get, L-039) so the retire confirmation can say
  "used by the regression suite" (51-11). The reference row stays; `grouping`, `run_now`, the 51-06 generator and the
  `regression-run` job skip retired references (one selection function). Restore makes the scenario selectable again.
- `grouping(app_uuid)` → the execution plan preview: setup instances (shared and private), roles, ordered scenarios,
  non-automated scenarios listed, retired references listed as "not run" (what Run now will do; same function the
  generator uses, 51-06 §2).
- `run_now(app_uuid)` → a `regression` execution of every automated, non-retired member (51-06 §3).
- `apply_verification_proposal(...)` → called by 51-09's proposal apply: add the story's feature scenarios as
  references (and any proposed regression scenario).
- `latest(app_uuid)` / `trend(app_uuid, n=20)` → the last executions' totals (pass rate over time) for the badge and the
  Regression view (D14.6–7).

## 3. Suite change notes (D21.3) — migration m0027

New `genesis/genesis/db/migrations/m0027_regression_notes.py` (module and `Migration` names must not start with
`test_`, L-092): table `kb_regression_notes` — `id`, `suite_id` (FK → `kb_test_suites` CASCADE), `kind`
(`reference-removed` · `steps-removed`), `cause` (`feature-deleted` · `case-deleted`), `cause_key` (the feature id or
`TC-` key), `detail_json` (the removed references' `TS-` keys and titles, or per regression scenario the removed
steps' positions and `TC-` keys), `created_at`, `dismissed_at`; index `(suite_id, dismissed_at)`. Not a collab table
(D17; regression is local). No rebuild, so no `foreign_keys_off`.

Writers: the **feature delete** path and `TestDesignStore.delete_case` compute, inside their existing write transaction
and **before** the delete that cascades, which regression items and regression-owned steps will go, and insert one note
per affected suite (L-091: the write lock is already held). A delete that touches no regression row writes nothing.
`RegressionStore.notes(suite_id, include_dismissed=False)` and `dismiss(note_id)` (idempotent). Feature delete lives
outside `testdesign.py` today: find every path that deletes a feature (and an app untrack, which removes the
regression suite itself, so it writes no note) and route them through one helper; prove it with a test per path.

## 4. Schedule settings

`get_schedule(app_uuid)` / `set_schedule(app_uuid, {cadence: off|daily|weekly, days, time})` read and write that app's
entry under `options.apps[<app_uuid>]` of the `regression-run` job (built in 51-06: enabled, hourly tick, no default
options, so every app is off; per-app `{cadence, days, time, since?}`). Writes go through
`ScheduleStore.update_settings` (it sets `user_modified`, L-081; generalize it for the nested per-app entry or add a
sibling method, keeping other apps' entries). **Turning a schedule on (or changing its cadence/days/time) writes
`since` = now**, so the job does not run the most recent past slot at its next tick (51-06 As built 6). The view says
runs start within an hour of the set time (hourly tick). Default off (F13). The Setup view shows it; turning it on is
the approval for unattended runs (D8.4).

## 5. Tests

References vs own scenarios; cross-feature step allowed only within the app; retire of a case used by a regression
scenario refused (D9); retiring a referenced feature scenario is allowed, the item reads `retired`, `grouping` /
`run_now` / the generator / the job all skip it, restore brings it back, Remove reference works on it (D21);
`referenced_by_regression` is the same on list and get; a feature delete and a case delete each write exactly one note
with the right keys before the cascade, a delete with no regression impact writes none, dismiss is idempotent; m0027
fresh and from a populated v26 DB; grouping preview equals the generator's selection; schedule round-trip keeps other
apps' entries; trend over fixture executions.

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "runs-worker", "db"]
adrs     = ["ADR-030", "ADR-042", "ADR-047", "ADR-050", "ADR-078", "ADR-079"]
lessons  = ["L-039", "L-081", "L-091", "L-092", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-49-test-design/49-02-data-model.md", "tracker:specs/phase-51-test-execution-engine/51-04-adrs-and-data-model.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/kb/testdesign.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/db/migrations/**", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/api/schedules.py"]
upstream = ["51-04", "51-06"]
```

## As built (2026-11-04, genesis-dev)

**Task restated.** In genesis only: build `RegressionService` over the 51-04 `RegressionStore` and the 51-06 engine
(references, own cross-feature scenarios, the plan preview, Run now, the 51-09 proposal apply, latest/trend). Implement
D21: retired references stay in the suite, are shown as retired and are skipped by one selection function that the
preview, Run now, the generator and the `regression-run` job share. The Phase 49 scenario DTO gains
`referenced_by_regression`. Add m0027 `kb_regression_notes` (DB 26 → 27), written by every feature-delete path and by
`delete_case` inside their transaction before the cascade. Store the per-app schedule through the `ScheduleStore`
settings path and stamp `since` when a schedule is turned on or changed. Add the 51-08 routes to 51-10's table. No
workflow, UI or Hub change.

**Applicable rules.** ADR-030 (SQLite, forward-only migration, DB-agnostic signatures), ADR-042 (the feature cascade
stays; the note is written in the same transaction), ADR-047 (one fixed backend job; only the per-app options entry is
user-written), ADR-050 (no status change outside `LifecycleService`), ADR-078/079 (retire, not delete; links
untouched), ADR-063 (notes are local, not a collab table), ADR-028 (routes under `/api`). Lessons L-039 (one DTO builder
for list and get; GET and PUT setup share one shape), L-081 (`user_modified`, other apps kept, default off), L-091 (write
lock before the read the decision depends on), L-092 (no `test_*` names), L-094 (consumers of the scenario DTO grepped),
L-096 (no generic route collides), L-011 (web type + fixtures), L-056/L-089 (commit check; bundle proof).

### Commits

- **genesis** (base `bb577c4`, local, not pushed or tagged): `d701ea9` feat(testexec,51-08). A separate
  `git status --short --untracked-files=all` afterwards was empty.
- **project-tracker:** this As built, the 51-10 table rows, `reviews/51-08-review.md`.

### Changed (genesis)

- `db/migrations/m0027_regression_notes.py` (new; `Migration` `regression_notes`, v27, no `foreign_keys_off`) and
  `migrations/__init__.py`: `kb_regression_notes` (`suite_id` FK → `kb_test_suites` CASCADE, `kind`, `cause`,
  `cause_key`, `detail_json`, `created_at`, `dismissed_at`; index `(suite_id, dismissed_at)`).
- `kb/regression_notes.py` (new, standalone): `record_losses(c, cause, cause_key, scenario_ids, case_ids, context)`
  computes the references (`kb_regression_items` of the doomed scenarios) and the regression-scenario steps (of the
  doomed cases) the cascade will remove and inserts one note per suite and kind; `note_feature_delete(c, feature_id)` —
  the one helper every feature-delete path calls.
- Writers (all under the write lock, before the delete):
  - `kb/features.py` `FeatureStore.delete_feature` — now `BEGIN IMMEDIATE` → `note_feature_delete` → delete.
  - `collab/service.py` `_upsert_local` — a pulled **feature tombstone** (a third feature-delete path, found by
    grepping the generic `DELETE FROM {binding.table}`) takes the lock and calls `note_feature_delete` first.
  - `kb/testdesign.py` `delete_case` (cause `case-deleted`) and `delete_scenario` (cause `scenario-deleted`; now
    lock-first with a no-op UPDATE).
  - `kb/store.py` `untrack_application` — comment only: it writes no note (the suite and its notes go with the app).
- `kb/testdesign.py` `_scenario_dtos` — `referenced_by_regression` (an `EXISTS` in the one builder, so `suite_tree`,
  `get_scenario`, regression items and the generator catalog all carry it).
- `kb/testexec_store.py`:
  - `RegressionSelection` + `regression_selection(conn, app)`: references (item order) and own scenarios (position
    order) that are not retired, and the retired ones as `retired` (not run).
  - `RegressionStore`: `selection`; `items` gains `retired`; `add_items` (one transaction, returns
    `{added, already, skipped}`); `add_item` refactored onto the shared `_referenceable`/`_append`; `notes`,
    `get_note`, `dismiss` (idempotent; keeps the first `dismissed_at`).
  - `ExecutionStore.ran` — terminal executions except `cancelled`, newest first.
- `testexec/generator.py` — `_catalog_order` takes the regression order from `regression_selection`;
  `ordered_folders` extracted from `generate()` (same files, golden tests unchanged).
- `testexec/execution_service.py` — `regression_scenario_ids` = the selection; `start_regression(selection=)` (so
  Run now's `not_run` matches what runs, review n1); the "no scenarios" message names the retired count.
- `testexec/regression_job.py` — `next_slot` (advisory "next run" for the Setup view). The handler is unchanged.
- `runtime/schedule_store.py` — `update_option_entry(job_key, section, key, entry)`: a sibling of `update_settings`
  (sets `user_modified`, leaves `enabled` and the schedule alone), `BEGIN IMMEDIATE` read-modify-write of
  `options[section][key]`, other entries kept.
- `testexec/regression_service.py` (new) — `RegressionService`: `get`, `add_reference`, `remove_reference` (also a
  retired one), `reorder`, `create_scenario`, `scenario_by_key`, `set_scenario_setup` (by `DS-` key, CAS), `plan`,
  `run_now`, `apply_verification_proposal`, `dismiss_note`, `latest`, `trend`, `summary`, `get_schedule`,
  `set_schedule`; module-level `schedule_view` / `save_schedule`.
- `api/testing.py` — `register_regression_routes` (the 51-10 rows below); GET and PUT `…/testing/setup` share
  `_setup_view`, which adds `schedule`. `RegressionScenarioBody` subclasses the Phase 49 `ScenarioCreate` (review n2).
  `api/app.py` wires the service (`app.state.test_regression`).
- Web (types/tests only): `ScenarioDto.referenced_by_regression`; `contract.test.ts`; the four fixtures that carry a
  scenario DTO regenerated (`finalize`, `scenario-detail`, `suite-tree`, `topup-apply`; the other four were restored
  because only timestamps changed). `npm run build`, then a separate `git status`: `web/static` unchanged.

### Tests

- New `tests/test_testexec_regression.py` (25):
  - m0027 fresh → v27 (columns, index, FK CASCADE, L-092 names) and a populated v26 DB (references, a cross-feature
    regression scenario) upgrading with every row equal and `foreign_key_check` empty, then writing a note.
  - `referenced_by_regression` equal on list and get.
  - D21: retire a referenced scenario (allowed) → item `retired`, selection skips it, it cannot be re-referenced,
    restore brings it back, Remove reference works on it; a retired own scenario is listed not run.
  - D9: a case used by a regression scenario cannot be retired.
  - Notes: feature delete → one `reference-removed` and one `steps-removed` note with the keys, titles and positions,
    and the cascade happened after; no regression impact → none; untrack → none; `delete_case` refused while a
    regression step uses it (no note); the shared writer records a case's regression steps; a referenced Draft
    scenario delete → a `scenario-deleted` note; the collab tombstone over two instances and the local Hub → the
    note on the puller; dismiss idempotent.
  - Service over a real git workspace and a recording `RunManager`: `get` (items with feature, setup, automated,
    reasons), refusals (other app, regression-owned, unknown setup, other app's scenario); **the plan equals the
    generator's files folder by folder and Run now's selection**, with a private setup instance and a retired
    reference in `not_run`; the job path skips a retired reference and restore brings it back; Run now with only
    retired members is refused; `apply_verification_proposal`; latest/trend/summary over fixture executions
    (cancelled and ad-hoc left out, pass rate with flaky as passed).
  - Schedule: round trip keeps another app's entry and `user_modified`, `since` stamped on change, kept when
    unchanged, dropped on off, survives `ensure_defaults`; validation; **turning a schedule on at 03:00 does not run
    that day's 02:00 slot**, the next day's slot runs; `next_slot`.
  - Routes: every 51-08 row, happy path and refusals (400/404/409, `stale_write`), dismiss 204 twice, setup GET/PUT
    shape, no password in a response.
- Updated: DB-version asserts 26 → 27 in 10 files; the m0026 tests pinned to `MIGRATIONS[:26]`; `test_db` records
  `regression_notes` as v27.
- Gates (final): `.venv/bin/ruff check genesis` (+ the new test) clean; `.venv/bin/python -m pytest -q` **1635 passed**
  (1610 before + 25) before the two review nits; after them the five affected files ran again, 127 passed. Web: `npx tsc
  --noEmit` clean, `npx eslint .` 0 errors (20 old warnings), `npx vitest run` **467 passed**; bundle unchanged.

### Review

`reviews/51-08-review.md`: **SHIP** on the first pass, with no blockers or majors. The reviewer ran every gate
(1635 passed; an off-tree build was identical to `web/static`).
- **m1:** one feature delete can write two notes → decision 3.
- **m2:** the case-deleted note cannot happen today → decision 1.
- **m3:** the 51-10 table needed `row_version` and 400 → done in `51-10-api.md` §1–§2.
- **n1** (a second selection read in Run now) and **n2** (reuse `ScenarioCreate`) were fixed before the commit, with
  the five affected test files re-run (127 passed). These two fixes came after the SHIP verdict and were not
  re-reviewed.
- **n3** (fixture churn) and **n4** (GET creates the suite, as the spec asks) are accepted.

### Decisions / deviations

No ADR deviation. **Bold = affects 51-09..51-11.**
1. **`delete_case` never writes a note today.** It already refuses a case used by any scenario step, regression
   scenarios included (51-04), so a case delete cannot cascade regression steps. The hook is in place and the
   `case-deleted` path is proven on the shared writer. Docs should not describe case deletes as a live note source.
2. **A third cause, `scenario-deleted`:** `add_item` accepts a Draft feature scenario, and deleting it cascaded the
   reference silently. Deleting a regression-owned scenario writes no note (the user's own decision).
3. **One note per suite and kind.** A feature delete that removes both references and steps writes a
   `reference-removed` and a `steps-removed` note that share `cause` + `cause_key`; the spec's single `kind` column
   cannot hold both. **51-11 may group them.** Detail shapes: `{feature|case|scenario: {…}, references: [{scenario_id,
   scenario_key, title, position}]}` and `{…, scenarios: [{scenario_id, scenario_key, title, steps: [{position,
   case_key, case_title}]}]}`.
4. **A third feature-delete path:** the collaboration pull's feature tombstone. It writes the note on the puller.
5. **`PATCH /applications/{app}/test-scenarios/{key}/setup` requires `row_version`** (the Phase 49 CAS rule); invalid
   requests in the testing routes are **400** (the `api/testing.py` convention). Both are now in 51-10's table.
6. **The plan preview (`grouping` in §2) is `GET …/regression/plan`:** `{groups: [{folder, instance, setup,
   private_for, roles, scenarios}], roles, scenario_ids, not_automated, not_run}`. The groups are sorted by folder,
   as in the generated config, and the scenarios within a group are in the generator's file order.
7. **Run now returns the execution plus `not_run`** (the retired members). They are not stored in the execution's
   selection. The trigger is `{source: "user", username}`.
8. **Trend and latest skip cancelled executions**; `pass_rate` = (passed + flaky) / scenarios, None when nothing ran;
   the trend is oldest first, 20 by default. `GET …/testing/summary` = `{latest, active}`.
9. **Schedule:** the entry is `{cadence, days, time, since?}`. `days` is stored only for weekly, a weekly schedule
   needs at least one day, and daily/weekly need a time. An unchanged save keeps `since`; turning the schedule off
   drops it. The view adds `timezone` (the job's, Asia/Kolkata), `job_enabled`, `next_run` (advisory) and the
   within-an-hour note. A missing job row is seeded with `ensure_defaults([REGRESSION_JOB])`, as at startup.
10. **`apply_verification_proposal(app, scenario_ids=, regression_scenarios=[{title, description?, case_ids}])`**
    never refuses as a whole: references go in one transaction (`{added, already, skipped}`), each proposed
    regression scenario is created as a Draft or listed in `skipped_scenarios`. **51-09** calls it from its apply.
11. **`GET …/testing/regression` reads the workspace HEAD** (the catalog decides `automated`) and runs one history
    query per scenario. That is fine at today's sizes.

### Lesson candidates

- **A generic tombstone delete is a feature-delete path too.** Grepping `DELETE FROM kb_features` missed the collab
  pull's `DELETE FROM {binding.table}`. When a rule says "every path that deletes X", grep the dynamic-table deletes
  as well (51-08 decision 4).
- **A spec rule can be unreachable because of an older refusal.** The `delete_case` note can never fire while Phase
  49 refuses deleting a used case. Check the existing preconditions before writing tests the spec asks for, and
  record the gap instead of weakening the refusal (51-08 decision 1).

### Code-map changes

For bible/03 in the "Phase 51" block (genesis-docs):
- `db/migrations/m0027_regression_notes.py` (`regression_notes`, v27).
- `kb/regression_notes.py` (`record_losses`, `note_feature_delete`).
- `kb/testexec_store.py` (`RegressionSelection`, `regression_selection`, `RegressionStore.selection` / `add_items` /
  `notes` / `get_note` / `dismiss`, `ExecutionStore.ran`).
- `kb/testdesign.py` (`referenced_by_regression`; the note writes in `delete_case` and `delete_scenario`).
- `kb/features.py` `delete_feature` and the `collab/service.py` tombstone (notes).
- `runtime/schedule_store.py` `update_option_entry`.
- `testexec/regression_service.py`.
- `testexec/generator.py` `ordered_folders`.
- `testexec/regression_job.py` `next_slot`.
- `testexec/execution_service.py` `start_regression(selection=)`.
- `api/testing.py` `register_regression_routes`.

`context/state/current.md` at phase end: m0001–m0027, `current_version` = 27.
