# 51-08 — The regression suite

> **Status:** SPEC-DRAFTED 2026-11-02. Repo: **genesis** (backend). Parent: `specs/phase-51-test-execution-engine.md`.
> Decisions: 51-01 D2, D9, D10, D11, D12.6, D14; F13, F14.

## 1. Goal

One regression suite per application: references to feature scenarios plus its own cross-feature regression
scenarios, grouped by data setup, run on demand or on the app's schedule, with the latest result and a trend.

## 2. `RegressionService` (`genesis/genesis/testexec/regression_service.py`)

Over `RegressionStore` (51-04 §3):
- `get(app_uuid)` → the suite (created on first read), its **items** (referenced feature scenarios with their feature,
  position, automated flag) and its **own scenarios** (normal `TS-` scenarios owned by the suite), each with its data
  setup, `changes_shared_data`, automated flag and last result.
- `add_reference(scenario_id)` / `remove_reference` / `reorder` — only non-retired scenarios of the same application;
  a regression-owned scenario cannot be "referenced" (it is already a member).
- Own scenarios: create/edit/reorder steps/retire through the Phase 49 scenario paths with the cross-feature rule
  (51-04 §3); their lifecycle = `TEST_TRANSITIONS`; `TS-` keys from the same sequence.
- `grouping(app_uuid)` → the execution plan preview: setup instances (shared and private), roles, ordered scenarios,
  non-automated scenarios listed (what Run now will do; same function the generator uses, 51-06 §2).
- `run_now(app_uuid)` → a `regression` execution of every automated member (51-06 §3).
- `apply_verification_proposal(...)` → called by 51-09's proposal apply: add the story's feature scenarios as
  references (and any proposed regression scenario).
- `latest(app_uuid)` / `trend(app_uuid, n=20)` → the last executions' totals (pass rate over time) for the badge and the
  Regression view (D14.6–7).

## 3. Schedule settings

`get_schedule(app_uuid)` / `set_schedule(app_uuid, {cadence: off|daily|weekly, days, time})` read and write that app's
entry in the `regression-run` job's `options_json` (51-06 §8; the scheduler store's `update_settings` is generalized
for this job or a sibling method is added; `user_modified` respected, L-081). Default off (F13). The Setup view shows
it; turning it on is the approval for unattended runs (D8.4).

## 4. Tests

References vs own scenarios; cross-feature step allowed only within the app; retire of a case used by a regression
scenario refused (D9); grouping preview equals the generator's selection; schedule round-trip keeps other apps'
entries; run_now selection; trend over fixture executions.

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "runs-worker"]
adrs     = ["ADR-047", "ADR-050", "ADR-078", "ADR-079"]
lessons  = ["L-081", "L-091", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-49-test-design/49-02-data-model.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/kb/testdesign.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/api/schedules.py"]
upstream = ["51-04", "51-06"]
```
