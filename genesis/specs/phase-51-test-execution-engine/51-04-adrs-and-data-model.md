# 51-04 — ADRs and data model: catalog, suites, executions, results, test users

> **Status:** **DONE 2026-11-03** (genesis `316ac5a`, local; review `reviews/51-04-review.md` = SHIP; see "As built").
> SPEC-DRAFTED 2026-11-02. Repo: **genesis** (backend). Parent: `specs/phase-51-test-execution-engine.md`.
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

## As built (2026-11-03, genesis-dev)

**Task restated.** Build the persistent model the rest of Phase 51 uses, in genesis only: migration m0026 (DB 25 → 26).
It rebuilds `kb_test_suites` so the per-app regression suite can own scenarios. This is the first table rebuild in
Genesis, run with foreign keys off and checked before commit. m0026 also adds ten new tables, two scenario columns and
the `ACT-`/`DS-`/`TE-` counters. On top of it sit the §3 stores, with DB-agnostic sync signatures and the write lock
taken before any validation. Actions and setups get a Draft → Ready → Retired lifecycle through `LifecycleService`.
The Phase 49 store gains the cross-feature regression rule, `last_result` and the setup column. Finally, the four ADR
texts are drafted for 51-13. Out of scope: HTTP, UI, workflow or Node behaviour.

**Applicable rules.** ADR-030 (SQLite; DB-agnostic repository signatures), ADR-042 (everything cascades with its
application/feature), ADR-050 (status only through `LifecycleService`; the store is the CAS primitive), ADR-072 (ids
from `kb_sequences` inside the transaction), ADR-078/079 (retire not delete; the impact walk), ADR-011/012 n/a.
Lessons L-026 (sync stores; async callers use `to_thread`), L-039 (one DTO builder for list and get), L-091 (lock
first, then validate), L-092 (no `test_*` names outside tests), L-095 n/a (no object UUIDs written), L-011 (web
contract parity, see deviation 6), L-056/L-089 (commit check, bundle proof).

### Commits

- **genesis** (base `55af523`, local, not pushed): `316ac5a` feat(db,51-04) — the whole change, including the review
  fixes.
- **project-tracker:** this As built, `adr-drafts.md` and `reviews/51-04-review.md` (one commit, below).

### Changed (genesis)

- `genesis/db/runner.py` — `Migration.foreign_keys_off` + `ForeignKeyCheckError`. When the flag is set, the runner
  issues `PRAGMA foreign_keys=OFF` (and checks that it took effect) before an explicit `BEGIN`, so the DDL is
  transactional too. It then runs `up` and refuses to commit when `PRAGMA foreign_key_check` shows a violation the
  migration added. Comparison is on `(table, rowid, parent)`, because `fkid` is renumbered by an `ADD COLUMN …
  REFERENCES`. Violations that existed before the migration are logged as a warning and left alone. Unflagged
  migrations behave exactly as before.
- `genesis/db/migrations/m0026_test_execution.py` (`testexecution`, name `test_execution`, v26, `foreign_keys_off=True`)
  and `migrations/__init__.py`.
  - The `kb_test_suites` rebuild: create `_new`, copy with `LEFT JOIN kb_features` (an orphan suite fails loudly on
    the NOT NULL `app_uuid`), drop, rename, carry the AUTOINCREMENT high-water mark over, recreate the indexes. New
    columns: `kind` NOT NULL DEFAULT `'feature'`, nullable UNIQUE `feature_id`, and `app_uuid` NOT NULL with an FK to
    `kb_applications` CASCADE. A CHECK ties `feature_id` to `kind`; `ux_kb_test_suites_regression` is a partial
    UNIQUE on `app_uuid` WHERE `kind='regression'`.
  - The ten §2.2 tables.
  - `kb_test_results` keeps its rows when a scenario or case is deleted: `scenario_id`/`case_id` use
    `ON DELETE SET NULL`, and the stored `scenario_key` (NOT NULL) and `case_key` keep the identity (review m3).
  - `kb_test_actions`/`kb_test_setups` have an `ever_referenced` column.
  - `kb_test_scenarios` gains `setup_id` (FK → setups, SET NULL) and `changes_shared_data`.
  - `sync_uuid` indexes, and the three `kb_sequences` rows.
  - Idempotent: the rebuild and the ADD COLUMNs are skipped once they have run.
- `genesis/kb/testexec_store.py` (new):
  - `TestSettingsStore`: settings upsert of the given fields only; test users; no password parameter (F12).
  - `TestLibraryStore`: create with the key allocated inside the transaction; one file = one item across both tables;
    the contract is validated and a setup has outputs only. Also get/get_by_key/list (area, role, status, text), CAS
    `update`, `record_replay` and `delete` (only when never referenced). `replace_refs` is atomic, validates every
    key in the app and marks targets `ever_referenced`. `where_used` includes the scenarios that name a setup, and the
    lifecycle accessors re-check the invariants after their write.
  - `TestScriptStore`: upsert/get/delete (delete clears the case's refs), `set_automation_status`
    (not-automated · automated · broken).
  - `RegressionStore`: `get_or_create` (one per app, race-safe), `items`, `scenarios`, `add_item` (a non-retired
    feature scenario of the same app), `remove_item` (renumbers), `reorder` (must list every item exactly once).
  - `ExecutionStore`: `create` (queued, `TE-`), `set_running`, and `finish`, which writes the terminal status and
    every result row in one transaction (each row's scenario/case must belong to the execution's app). Also get /
    get_by_key / for_run / list / latest / results, `scenario_history` and `case_history` (last 10 that ran, plus
    the flaky badge), `prunable` (F11, keep 20) and `mark_files_pruned`.
  - `CaptureStore`: the top-up pattern (status edges with a CAS).
  - Module level: `is_flaky`, the value sets, and `__test__ = False` on each `Test…Store`.
- `genesis/domain/` — `EntityKind.TEST_ACTION`/`TEST_SETUP`, plus `LIBRARY_PRECONDITIONS` and their reasons on
  `TEST_TRANSITIONS`. Approve and restore need `replay_passed_at_hash`. Retire needs no active referrers, and the
  refusal names them. New `build_library_lifecycle(_service)`, exported.
- `genesis/kb/testdesign.py`:
  - Shared `allocate_key`; `_ensure_suite` writes `kind`/`app_uuid`.
  - `_check_step_cases` lets a regression scenario use any non-retired case of a feature suite of the same app; a
    feature scenario keeps the same-suite rule.
  - `create_case` refuses the regression suite, and `feature_id_for_suite` returns None for it.
  - `_case_dtos` adds the derived `last_result` (one grouped query, `not-run` ignored).
  - `_scenario_dtos` returns `changes_shared_data` as a bool.
  - New `set_scenario_setup`: CAS first, the setup must be of the same app and not retired, and it sets
    `ever_referenced`.
  - `delete_case` deletes the case's refs.
- `genesis/services/testimpact.py` — `_scenario_steps` returns feature scenarios only. A regression scenario has no
  feature, and `_assemble` would raise `KeyError` on `suites[None]`.
- Tests: DB-version asserts 25 → 26 in 9 files; the two m0025 tests are pinned to `MIGRATIONS[:25]`;
  `test_db`'s synthetic next migration is `len(MIGRATIONS)+1`; the suite-tree query bound is +1.
- Web, types and tests only: `web/src/types/testdesign.ts` gains `CaseLastResult` and `CaseDto.last_result`,
  `ScenarioDto.setup_id` and `changes_shared_data: boolean`, and `SuiteDto.kind`, `app_uuid` and
  `feature_id: number | null`. `contract.test.ts` key lists and the 8 regenerated fixtures (`GENESIS_WRITE_CONTRACT_FIXTURES=1`)
  follow. `npm run build` then a separate `git status` showed `web/static` unchanged, so there was no bundle to commit.

### Tests

- New `tests/test_testexec_migration.py` (15 tests):
  - A fresh DB reaches v26 with every table, index and counter.
  - A **v25 DB with Phase 49 data** (two apps, three features, suites including a deleted one, cases, scenarios with
    a repeated step, story and object links, a top-up, advanced counters, an audit row) upgrades with every old
    column value-equal. `foreign_key_check` is empty and `integrity_check` returns ok; the children still reference
    `kb_test_suites`; the stores still read and write; `TC-000004` comes next; the new suite id is 4, not the
    deleted 3.
  - Feature delete still cascades suite → cases/scenarios/steps/links/top-ups; untrack removes the app's suites and
    settings; re-running `up` changes nothing.
  - One regression suite per app, plus the kind CHECK (4 refused inserts).
  - The runner flag: without it a rebuild cascades into the children; with it, foreign keys are off inside one
    transaction; an added violation is refused and nothing is committed; a pre-existing violation is tolerated,
    including after an FK column is added to its table; the real v26 upgrade passes with an old orphan scenario; a
    failing flagged migration rolls back its DDL.
- New `tests/test_testexec_store.py` (25 tests):
  - Library: create/validate/no key used on refusal; one file per item across both tables; list filters and the
    update CAS; keys `ACT-`/`TE-` monotonic under 4 threads × 8 writers.
  - Lifecycle: approve/restore need a passing replay at the current hash (three distinct reasons), with the m0013
    audit; retire refused while an action, a setup or a case script uses the item, then allowed once they are
    retired; `set_status` re-checks inside its write.
  - A scenario naming a setup blocks its retire and delete; `set_scenario_setup` refusals and the CAS.
  - **Refs from a deleted case never block a retire** (review M1). Delete only a never-used item; `replace_refs` is
    atomic and mirrors the code.
  - Case scripts and automation status.
  - Regression: items, regression scenarios across features, Phase 49 retire/delete counting regression scenarios,
    feature delete cascading into the regression suite, impact steps skipping regression scenarios.
  - Executions: the lifecycle with results in one transaction (an invalid or other-app row writes nothing, not even
    the status); flaky badge and `last_result`; result rows outliving a deleted feature; prunable keeps the newest
    20; the capture status machine; settings and test users.
  - L-092: an AST scan of `genesis/**` refuses `test_*` modules and symbols and `Test*` classes without
    `__test__ = False`. The one exemption is the pre-existing `genesis/cli/test_workflow.py`.
- Gates (final, after every fix): `.venv/bin/ruff check genesis` (+ the new tests) clean;
  `.venv/bin/python -m pytest -q` **1456 passed** (1418 at the last release, plus 38 new).
  Web: `npx tsc --noEmit` clean, `npx eslint .` 0 errors (20 warnings, all pre-existing), `npx vitest run`
  **467 passed** (50 files).
- The m1′ fix was mutation-checked: putting the old full-tuple comparison back makes both new tolerance tests fail.

### Review

`reviews/51-04-review.md`. The first pass was **NEEDS_CHANGES**:
- **M1 (major):** refs from a deleted case blocked a retire forever.
- **m1:** the FK check was database-wide.
- **m2:** `SuiteDto.feature_id` typed as non-null.
- **m3:** result rows cascaded away.
- **m4:** As built needed.
- **n1–n5:** nits.

The reviewer also migrated read-only snapshots of the live `~/.genesis/genesis.db` (126 cases, 23 scenarios, 135
steps) and the userb fleet DB in `/tmp`. Both reached v26 with the FK and integrity checks clean and every row
unchanged.

The **re-review verdict is SHIP**, after M1, m1–m3 and n1–n4 were fixed. Its one new minor, m1′ (`fkid` renumbering
defeated the pre-existing-violation tolerance on `kb_test_scenarios`), was fixed before the commit, with two tests and
the mutation check above. That fix came after the SHIP verdict and was not re-reviewed: it is a one-line change to the
comparison key plus tests.

### Decisions / deviations

No ADR deviation. Recorded choices:
1. **`app_uuid` is NOT NULL for both suite kinds**, with an FK to `kb_applications` CASCADE; the spec required it
   only for `regression`. Every v25 suite has a feature, so the backfill always succeeds, and the copy fails loudly
   rather than dropping a row. `kind` defaults to `'feature'`.
2. **Runner FK check refuses only violations the migration adds** (review m1, agreed by the reviewer). This deviates
   from the spec's literal "must return nothing": an unrelated old orphan must not stop startup. The pre-existing
   ones are logged.
3. **Result rows outlive their scenario or case** (D14.2): `SET NULL` with stored `scenario_key`/`case_key`, and the
   scenario row is the one with `case_key IS NULL`. `finish` refuses ids from another app (review n3).
4. **A scenario that names a setup counts as a user** of that setup, for retire, delete and where-used.
5. **Library `restore` needs a passing replay at the current hash too**, because it lands on Ready. A content-hash
   change does **not** demote a Ready item: that would be a status change outside `LifecycleService`. **Open for
   51-07:** the save flow must re-replay, or deliberately demote through a transition.
6. **The Phase 49 API now carries additive fields**: `last_result`, `setup_id`, `changes_shared_data`, `kind`,
   `app_uuid`. These follow from §3 (`cases_for_*` return `last_result`), go through the one DTO builder, and need
   the web types, fixtures and contract test to move with them (L-011). The reviewer judged this acceptable: local
   API, no Hub contract, bundle unchanged.
7. **`testimpact._scenario_steps` returns feature scenarios only until 51-06** adds the regression suite to the
   impact result (F9). Without the guard, an impact read hitting a regression scenario would raise `KeyError`.
8. **Execution and capture statuses are store state machines with a CAS**, not `LifecycleService` kinds. They are run
   records, as `kb_test_topups` is (the §4 lifecycle covers library items only).
9. **Browser channels** are `chromium` (default) and `chrome` (D4).
10. **Contract `required` defaults to true**; a missing `type` defaults to `string`.
11. **Deferred to 51-08 (review n5):** a feature scenario referenced by the regression suite can still be retired
    without notice. Decide whether retire warns about the reference or skips it.
12. A regression scenario whose cases are deleted with their feature silently loses those steps. That is the Phase
    49 step cascade (F9). 51-08 should show it, for example as a "scenario changed" note.
13. **Open point for genesis-docs** (in `adr-drafts.md`): should ADR-082 also carry `--amends ADR-021`?

### Lesson candidates

- **A SQLite table rebuild needs the runner's help.** `PRAGMA foreign_keys` is a no-op inside a transaction, and
  Python's sqlite3 runs DDL in autocommit until the first DML. So: turn the keys off before an explicit `BEGIN`; prove
  with a test that without it the DROP cascades into the children; and compare `foreign_key_check` rows on
  `(table, rowid, parent)`, because an `ADD COLUMN … REFERENCES` renumbers `fkid` (51-04 m1′).
- **A derived index with no FK must not outlive its source.** Every reader that treats its rows as live users has to
  join to the source and skip the gone ones, and the deleting store should remove them in the same transaction
  (51-04 M1).

### Code-map changes

For bible/03 under a new "Phase 51" block (genesis-docs):
- `db/runner.py` `Migration.foreign_keys_off` / `ForeignKeyCheckError`.
- `db/migrations/m0026_test_execution.py` (`testexecution`, v26: the suite rebuild, the 10 tables, the scenario
  columns, the 3 sequences).
- `kb/testexec_store.py` (the six stores, `is_flaky`, the value sets).
- `kb/testdesign.py` `allocate_key`, `set_scenario_setup`, `last_result`, the regression step rule.
- `domain/` `TEST_ACTION`/`TEST_SETUP`, `LIBRARY_PRECONDITIONS`, `build_library_lifecycle(_service)`.
- `services/testimpact.py` `_scenario_steps`, feature-only.
- `web/src/types/testdesign.ts` `CaseLastResult` and the new fields.

`context/state/current.md` at phase end: m0001–m0026, `current_version` = 26.
