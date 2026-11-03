# 51-08 — The regression suite

> **Status:** SPEC-DRAFTED 2026-11-02 (D21 added 2026-11-03). Repo: **genesis** (backend). Parent:
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
