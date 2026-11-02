# 51-04 — ADRs and data model: catalog, suites, executions, results, test users

> **Status:** SPEC-DRAFTED 2026-11-02. Repo: **genesis** (backend). Parent: `specs/phase-51-test-execution-engine.md`.
> Decisions: 51-01 D1, D2, D5, D9, D10, D14, D16, D17; F1, F11, F12, F14. One migration **m0026** (DB 25 → 26).

## 1. Goal

The persistent model every later sub-spec uses: new tables, the `kb_test_suites` rebuild that lets the regression suite
own scenarios, three id sequences, the stores, and the lifecycle for library items. No HTTP, UI, workflow or Node here.

## 2. Migration m0026 `test_execution`

New `genesis/genesis/db/migrations/m0026_test_execution.py` appended to `MIGRATIONS`. Module and `Migration` names must
not start with `test_` (L-092, m0025's R6). "Collab columns" = the m0019 set used by m0025 (unused, D17).

### 2.1 Rebuild `kb_test_suites` (D9)

Today `feature_id INTEGER NOT NULL UNIQUE` (m0025). New shape: `kind TEXT NOT NULL` (`feature` | `regression`),
`feature_id` nullable (UNIQUE when not null), `app_uuid TEXT` (required for `regression`; backfilled from the feature
for `feature` rows), a partial UNIQUE index on `app_uuid WHERE kind='regression'` (one regression suite per app), and a
CHECK that `feature` rows have a `feature_id` and `regression` rows have none. Procedure = SQLite's documented
"other ALTER TABLE changes" (create `kb_test_suites_new`, copy, drop, rename, recreate indexes): `PRAGMA
foreign_keys=OFF` is issued **before** the migration's transaction opens (the runner opens a connection per migration,
`genesis/genesis/db/runner.py:70-88`; Python's sqlite3 opens a transaction only before DML), `PRAGMA
foreign_key_check` must return nothing before commit, `foreign_keys` back ON after. If the runner cannot do this as is,
add a `Migration` flag (e.g. `foreign_keys_off=True`) with its own test — the first rebuild in Genesis (no precedent).
Children (`kb_test_cases`, `kb_test_scenarios`) keep `suite_id` FKs; cascade from feature → suite → cases/scenarios must
still work (test).

### 2.2 New tables

| Table | Columns (besides id, timestamps, collab columns where noted) | Keys / FKs |
|---|---|---|
| `kb_test_settings` | `app_uuid` PK, `site_path` (e.g. `/suite/sites/source-selection`), `workspace_path`, `browser_channel` (default `chromium`), `runtime_json` (last detected node/playwright/apwt versions) | FK `app_uuid` → `kb_applications` CASCADE |
| `kb_test_users` | `app_uuid`, `role_key` (`[a-z0-9-]+`), `role_label`, `username`, `notes` — the password lives in the SecretProvider (F12), never here | UNIQUE `(app_uuid, role_key)`; FK app CASCADE |
| `kb_test_actions` (collab) | `app_uuid`, `key` (`ACT-000001`), `name`, `area`, `slug`, `role_key` (default role, nullable), `path` (workspace-relative), `content_hash`, `contract_json` (`{inputs:[{name,type,required,description}], outputs:[…]}`), `status` draft·ready·retired, `origin` record·verification·manual, `last_replay_json`, `retired_at` | `key` UNIQUE; UNIQUE `(app_uuid, path)` |
| `kb_test_setups` (collab) | as actions but key `DS-000001`, `role_key` NOT NULL, `contract_json` has outputs only | same |
| `kb_test_case_scripts` | `case_id`, `path`, `content_hash`, `origin` verification·manual, `last_commit` | UNIQUE `case_id`; FK case CASCADE |
| `kb_test_refs` | `app_uuid`, `from_kind` (action·setup·case), `from_key`, `to_kind` (action·setup), `to_key` — a **derived** index rebuilt from the code's imports at every save/adopt (51-07 §3) | index `(app_uuid, to_kind, to_key)` |
| `kb_regression_items` | `suite_id` (the regression suite), `scenario_id` (a **feature** scenario referenced, D9), `position` | FK both CASCADE; UNIQUE `(suite_id, scenario_id)` |
| `kb_test_executions` (collab) | `key` (`TE-000001`), `app_uuid`, `kind` verification·regression·impact·adhoc, `trigger_json`, `run_id`, `status` queued·running·passed·failed·blocked·cancelled·error, `env_label`, `env_url`, `site_path`, `workspace_commit`, `apwt_version`, `playwright_version`, `selection_json` (scenario ids + setup instances), `totals_json`, `report_dir`, `files_pruned_at`, `started_at`, `finished_at` | `key` UNIQUE; index `(app_uuid, created_at)` |
| `kb_test_results` | `execution_id`, `scenario_id`, `case_id` (NULL = the scenario row), `step_position`, `setup_key` + `setup_instance`, `status` passed·failed·flaky·blocked·skipped·not-run, `attempts`, `duration_ms`, `error_text`, `classification` (script·product·blocked, verification only), `attachments_json` (paths relative to `report_dir`) | FK execution CASCADE; index `(scenario_id, created_at)`, `(case_id, created_at)` |
| `kb_test_captures` | `app_uuid`, `kind` recording·verification, `role_key`, `intent`, `run_id`, `trace_path`, `status` recording·analysing·ready·applied·discarded·failed, `proposals_json`, `decisions_json`, `row_version` | the `kb_test_topups` pattern (m0025) |

Column additions (ALTER TABLE ADD COLUMN): `kb_test_scenarios.setup_id` (nullable FK → `kb_test_setups`, F14 default
NULL) and `kb_test_scenarios.changes_shared_data INTEGER NOT NULL DEFAULT 0` (D10.4).

Sequences: `INSERT OR IGNORE INTO kb_sequences (name, next_val) VALUES ('test_action',1),('test_setup',1),
('test_execution',1)` (F1, ADR-072 pattern). Indexes on every collab `sync_uuid` (m0025 pattern).

## 3. Stores (`genesis/genesis/kb/testexec_store.py`, plus additions to `kb/testdesign.py`)

Synchronous, DB-agnostic signatures (ADR-030); async callers use `asyncio.to_thread` (L-026). A validate-then-write
transaction takes the write lock first (`BEGIN IMMEDIATE` or the CAS write, L-091).

- `TestSettingsStore`: get/upsert settings, list/upsert/delete test users (secrets via the config service, not here).
- `TestLibraryStore`: create action/setup (allocates the key inside the tx), get/list (filters: area, role, status,
  text), update metadata + hash, set status (persistence primitive only; transitions via `LifecycleService`), delete
  (only when never referenced: no `kb_test_refs` row ever pointed at it — keep a `ever_referenced` flag set on first
  ref), replace refs for one `from_key` (atomic), `where_used(kind, key)`.
- `TestScriptStore`: case script binding upsert/get; `automation_status` set (values not-automated · automated · broken,
  D14.5; a store-level validation, m0025 has no CHECK).
- `RegressionStore`: get-or-create the app's regression suite row; items add/remove/reorder; regression scenarios are
  normal `kb_test_scenarios` rows owned by it (Phase 49 scenario/step APIs, with the cross-feature rule: a regression
  scenario's step may reference any non-retired case of the **same application**; a feature scenario keeps the
  same-suite rule, 49 D2).
- `ExecutionStore`: create (key in tx, status queued), set running/finished, write results in one tx, list/get, latest
  per app, last N results per scenario/case (D14.4, flaky badge computed on read: flaky in ≥ 3 of the last 10), prune
  files bookkeeping (F11).
- `CaptureStore`: the `TopupStore` pattern.

Phase 49 changes: `TestDesignStore.delete_case`/retire preconditions count steps of **regression** scenarios too
(D9); `cases_for_*` reads return `automation_status` and a derived `last_result`.

## 4. Lifecycle (ADR-050)

Library items use `TEST_TRANSITIONS` (`genesis/genesis/domain/transitions.py:133-138`: draft → ready → retired,
restore) with new preconditions: `ready` requires a passing replay at the current hash; `retire` refused while a
non-retired action/setup/case script references the item (reason names them, the `_retire_case_reason` pattern). New
`EntityKind` members for action and setup; transitions only through `LifecycleService.transition`.

## 5. Tests

Fresh DB → v26; a v25 DB **with Phase 49 data** upgrades with every row, FK and cascade intact (feature delete still
removes its suite, cases, scenarios); one regression suite per app enforced; key allocation monotonic under concurrent
writers; retire/delete preconditions; refs replace is atomic; flaky computation; results write is one transaction; no
module or symbol named `test_*` outside tests (L-092).

## 6. ADR texts (written here, added by genesis-docs at release)

Draft the four decision-log sections (Context / Decision / Alternatives / Consequences, house format) for ADR-081..084
from the umbrella §12 and 51-01 §7, in `specs/phase-51-test-execution-engine/adr-drafts.md`, so 51-13 adds them with
`genesis-ctx add adr` (`--amends ADR-078` / `ADR-068` / `ADR-029` / `ADR-061`). ADR-083's text comes from the
umbrella §12 plus 51-01 D3a–D3d and the 51-03 As built (both sessions: the sandbox evidence S1/S5/S6 with residual 1 as
the reason a sandboxed shell was not used; the D3c recipe; the accepted risks — inherited environment, password in the
login/Playwright subprocess environment, global Kiro MCP servers with full trust); it names Phase 52 as the fix.

## Context manifest

```toml
areas    = ["db", "features-stages", "stories-workbench"]
adrs     = ["ADR-030", "ADR-042", "ADR-050", "ADR-072", "ADR-078", "ADR-079"]
lessons  = ["L-026", "L-039", "L-091", "L-092", "L-095"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-49-test-design/49-02-data-model.md"]
code     = ["genesis/genesis/db/migrations/**", "genesis/genesis/db/runner.py", "genesis/genesis/kb/testdesign.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/domain/**"]
upstream = ["51-03"]
```
