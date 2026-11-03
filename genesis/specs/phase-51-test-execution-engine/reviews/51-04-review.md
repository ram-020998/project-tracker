# Review 51-04 — base 55af523 (genesis-review, 2026-11-03)

Scope: `git diff 55af523` in `genesis` (uncommitted working tree, 28 modified files) plus the untracked
`genesis/db/migrations/m0026_test_execution.py`, `genesis/kb/testexec_store.py`, `tests/test_testexec_migration.py`,
`tests/test_testexec_store.py`; and `specs/phase-51-test-execution-engine/adr-drafts.md` (ADR-081..084). Base
`55af523` resolves (HEAD of the working tree). `genesis-ctx check --since 55af523 --repo genesis` → 32 files, areas db,
features-stages, kb-sync, stories-workbench (+ always-on release-ci, security). No live acceptance: this sub-spec adds
no HTTP route, UI, workflow or Node behaviour.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` (+ the two new test files) | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | 1452 collected, all passed (100%, no failures) |
| new + touched suites alone (`test_testexec_store`, `test_testexec_migration`, `test_test_design_store`, `test_db`) | 90 passed |
| `web: npx tsc --noEmit` | clean |
| `web: npx eslint .` | 0 errors, 20 warnings (pre-existing) |
| `web: npx vitest run` | 467 passed, 50 files |
| stale bundle: `npx vite build --outDir /tmp/51-04-static` then `diff -r /tmp/51-04-static web/static` | identical (no commit of `web/static/` needed) |
| **Real-data upgrade (reviewer extra):** sqlite backup-API snapshots of `~/.genesis/genesis.db` (v25: 2 suites, 126 cases, 23 scenarios, 135 steps) and `~/.genesis-fleet/instances/userb/state/genesis.db` (v25, no suites), migrated in `/tmp` with `migrate(db, MIGRATIONS)` | both → `[26]`; `foreign_key_check` empty; `integrity_check` ok; every case/scenario/step row equal; both suites `kind=feature` with the right `app_uuid`; old columns value-equal; indexes `sqlite_autoindex_…_1`, `ux_kb_test_suites_sync_uuid`, `ux_kb_test_suites_regression`, `ix_kb_test_suites_app` present. Snapshots deleted afterwards. |

## Checklist

### ADRs
- [N/A] ADR-001 — no graph/control-flow code touched.
- [N/A] ADR-010 — no LangGraph state; bulk (traces, reports) stays files, rows hold relative paths (`attachments_json`, `report_dir`).
- [N/A] ADR-011 — no agent node.
- [N/A] ADR-019 — no genesis-core change; `CORE_MAJOR` untouched.
- [N/A] ADR-021 — no gate/workflow; ADR-082 draft discusses the relation (open point for docs).
- [N/A] ADR-024 — stores are sync by design (ADR-030 signatures); no engine change.
- [N/A] ADR-026 — no network surface.
- [OK] ADR-027 — web change is types + a contract test only; no new deps or UI.
- [OK] ADR-030 — SQLite only; store methods are plain sync, DB-agnostic signatures (`testexec_store.py` classes take/return dicts and ids; no cursor leaks).
- [N/A] ADR-031/033/034/045 — no chat surface.
- [N/A] ADR-035 — no run inputs.
- [N/A] ADR-036/037/039/047/073/074 — no KB sync/parser change. The `testimpact.py` edit only filters `s.kind='feature'`.
- [N/A] ADR-038 — no MCP install.
- [N/A] ADR-041 — no documents.
- [OK] ADR-042 — new tables cascade with the application (`m0026:66,136` and every table's `app_uuid … ON DELETE CASCADE`); feature delete still cascades suite → cases/scenarios/steps/links/top-ups (`test_feature_delete_still_cascades_after_the_rebuild`); untrack removes suites + settings (`test_untracking_the_app_removes_its_suites_and_new_rows`).
- [N/A] ADR-043/044/049/055/056/057/058/059/060/062/063/064/065/067/068/070/071/075/076 — not touched (Phase 49 test records stay local-only; no collab code reads `kb_test_*`: grep of `genesis/collab`, `genesis/api` finds only `api/testdesign.py:205`, which tolerates the new `None`).
- [OK] ADR-050 — library items change status only through `LifecycleService` (`build_library_lifecycle(_service)`, `lifecycle.py`); `TestLibraryStore.set_status` is the CAS primitive and re-checks invariants inside its write; audit wiring tested (`test_ready_needs_a_passing_replay_at_the_current_hash` asserts the m0013 history). Execution/capture status machines are run-like records, not SDLC lifecycle (the `kb_test_topups` precedent). **But see M1:** the retire precondition is wrong after a case or feature delete.
- [OK] ADR-061 — untouched in code; ADR-084 draft amends it.
- [OK] ADR-072 — `ACT-`/`DS-`/`TE-` from `kb_sequences` inside the write tx via the shared `allocate_key` (`testdesign.py:75`); monotonic under 4 threads × 8 writers (`test_keys_are_monotonic_under_concurrent_writers`); m0026 seeds the rows with `INSERT OR IGNORE`.
- [OK] ADR-077 — reviewer used `genesis-ctx` only; no bulk docs read.
- [OK] ADR-078 — retire-not-delete preserved; `automation_status` values validated in the store (`TestScriptStore.set_automation_status`); `create_case` refuses the regression suite (`testdesign.py:604-606`); Phase 49 retire/delete rules already count every scenario's steps, so regression scenarios are covered (`_active_scenario_keys`, `delete_case` have no suite filter; `test_phase49_retire_and_delete_count_regression_scenarios`). Amendment recorded in the ADR-081 draft (`--amends ADR-078`).
- [OK] ADR-079 — impact still walks on demand; regression scenarios are excluded until 51-06 (`testimpact.py:557-563`, `test_impact_steps_skip_regression_scenarios_for_now`); none can exist before then (no API creates them).
- [N/A] ADR-080 — no packaging change.

### Lessons
- [N/A] L-004, L-009, L-017, L-025/L-027 (ruff pinned, unchanged), L-030, L-031, L-032, L-034, L-035, L-037, L-040, L-041, L-042, L-043, L-045, L-050, L-051, L-056/L-057 (release-time), L-058, L-061, L-062, L-063, L-064, L-069, L-071, L-072, L-073, L-074, L-075, L-076, L-077, L-078, L-079, L-080, L-081, L-082, L-084, L-085, L-086, L-087, L-088, L-089 (no commit yet; bundle proven identical), L-090, L-093, L-094 (no registry value added; `EntityKind` members are consumed only by the new service), L-096, L-098, L-099, L-100 — not touched by this diff.
- [OK] L-011 — web types, fixtures and the exact-keys contract test follow the new DTO keys (`contract.test.ts` CASE/SCENARIO/SUITE); fixtures regenerated by the generator (churn is timestamps/uuids + the new keys only). See m2 for one type that is now wrong.
- [OK] L-026 — all store methods are sync; no async caller yet; docstring directs `asyncio.to_thread`.
- [OK] L-039 — `last_result` is built in the one `_case_dtos` builder used by list and get (`testdesign.py:357`; `test_list_and_single_get_dtos_are_identical` still green); library and execution DTOs share one `_dto` each.
- [OK] L-083 — test fixtures use real key shapes (`TC-000001`, `ACT-000002`, `TE-000009`).
- [OK] L-091 — every read-validate-write takes the lock first: `BEGIN IMMEDIATE` (`testexec_store.py:202,280,364,392,419,731,765`) or CAS-first (`set_scenario_setup`, `ExecutionStore._cas_status`, `CaptureStore.set_status`); `set_status` re-checks after its UPDATE (`test_set_status_rechecks_the_invariants_inside_its_write`). The remaining check-then-insert paths (`upsert_user`, `TestScriptStore.upsert`, `RegressionStore.get_or_create`, `ExecutionStore.create`) only check existence that the FK also enforces.
- [OK] L-092 — module `testexec_store.py`, Migration attr `testexecution`, `__test__ = False` on `TestSettingsStore`/`TestLibraryStore`/`TestScriptStore` (`:161,264,617`); `test_no_module_or_symbol_named_test_outside_tests` and `test_the_migration_object_is_not_a_test_name` pass.
- [N/A] L-095 — no object-UUID links written.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` (db, features-stages, kb-sync, stories-workbench) — 1452 passed.
- [OK] `cd genesis && .venv/bin/ruff check genesis` (×4) — clean.
- [OK] `cd genesis/web && npm run lint && npm run typecheck && npm test` (×2) — eslint 0 errors, tsc clean, vitest 467.
- [OK] `cd genesis/web && npm run build # then commit web/static/` (×2) — out-of-tree build identical to `web/static/`; nothing to commit.

### Spec conformance (51-04 §2–§6)
- §2.1 rebuild — OK. Documented procedure (create new, copy, drop, rename, recreate indexes) under the new runner flag; ids and the AUTOINCREMENT high-water mark kept (`m0026:86-92`; `test_upgraded_data_still_reads_and_writes_through_the_stores` gets id 4 after a deleted id 3); `LEFT JOIN` so an orphan suite fails loudly on NOT NULL (`m0026:84`); CHECK + partial UNIQUE (`m0026:74,98`, `test_one_regression_suite_per_app_and_the_kind_check`). The runner flag has its own tests, including "without the flag DROP cascades into children" and DDL rollback. Deviation to record in As built: `app_uuid` is NOT NULL for both kinds with an FK to `kb_applications` (the spec only required it for regression); `kind` has `DEFAULT 'feature'`.
- §2.2 tables/columns/sequences/indexes — OK, all present (`test_fresh_db_reaches_v26_with_tables_indexes_and_counters`), plus `ever_referenced` per §3.
- §3 stores — OK apart from M1.
- §4 lifecycle — OK apart from M1. Extension to record: a scenario that names a setup counts as a referrer (D10.2; sensible).
- §5 tests — all listed cases covered (v25 with Phase 49 data, cascade, one regression suite per app, concurrent keys, retire/delete preconditions, atomic refs replace, flaky, one-tx results, L-092).
- §6 ADR drafts — OK. House format (Status / Context / Decision / Alternatives rejected / Consequences) with header tables for `genesis-ctx add adr`; `--amends` ADR-078 / ADR-068 / ADR-029 / ADR-061 as specified. ADR-083 covers D3, D3a, D3b, D3c, D3d; the 51-03 sandbox evidence S1/S5/S6 with residual 1 as the reason the sandboxed shell was rejected; the D3c recipe (Decision 2–4); the three accepted risks (inherited environment, password in the `open --login`/replay subprocess environment, global Kiro MCP servers with full trust); and names Phase 52 as the fix. Figures spot-checked against `51-03-spike-sandboxed-shell.md` (2.37.1, 194.2 s / 26 tool calls / 8.44 credits, 10.0–13.5 s, D-114 / 0.3.0, `applyConfig`, `default_blocked`, seatbelt, `--password-stdin`, residual 1): all match.
- Out-of-scope consequence the dev flagged (Phase 49 API DTOs now carry `last_result`, `setup_id`, `changes_shared_data`, `kind`, `app_uuid`): **acceptable.** The fields are additive, the API is local-only (no Hub contract, ADR-064 unaffected), the contract fixtures/types/test moved with them (L-011) and the bundle is unchanged. Record it in As built.

## Findings

### Blockers
None.

### Majors
- **M1 — `kb_test_refs` rows from a deleted case make an action/setup un-retirable and show a ghost in where-used.**
  `kb_test_refs` has no FK (it is derived), and `TestLibraryStore._referrers` (`testexec_store.py:569-590`) takes a
  referrer's status from `COALESCE(a.status, s.status, tc.status)`; when the source row is gone the status is `NULL`,
  and `active_only` keeps it (`None != "retired"`). Deleting a feature cascades its cases (and `kb_test_case_scripts`)
  but leaves their `from_kind='case'` refs; `TestDesignStore.delete_case` (draft case, `testdesign.py:814`) does the
  same. Reproduced with a reviewer probe on the dev's own fixtures: bind a script to `TC-000001`, `replace_refs(case →
  ACT)`, delete the feature → `where_used` = `[{'kind': 'case', 'key': 'TC-000001', 'status': None}]` and
  `retire` → `PreconditionFailedError: it is used by TC-000001 — change or retire them first`, permanently (the case
  cannot be retired or edited any more). Not reachable through the UI until 51-07 writes case refs, but it is a defect
  in the precondition this sub-spec delivers (§3/§4), and no test covers refs across a case or feature delete.
  **Fix:** in `_referrers`, treat a referrer whose source row no longer exists as gone (e.g. `WHERE COALESCE(a.status,
  s.status, tc.status) IS NOT NULL`, or join with an existence test per `from_kind`), so the derived index never
  outlives its source; optionally also delete the case's refs in `delete_case` (as `TestScriptStore.delete` and
  `TestLibraryStore.delete` already do). Add a regression test: case ref → feature delete (and draft `delete_case`) →
  `where_used` empty and retire succeeds.

### Minors
- **m1 — `foreign_key_check` is database-wide.** `runner.py:63` runs `PRAGMA foreign_key_check` with no table, so any
  pre-existing orphan row anywhere in a user's DB would stop startup at v26 with `ForeignKeyCheckError`, unrelated to
  the rebuild. Both live DBs are clean today (verified above), so this does not block; consider checking only the
  tables the migration touched (`foreign_key_check(<table>)` for the rebuilt table and its children) or, if the
  whole-DB check is kept deliberately (SQLite's procedure step 10), say so in the runner docstring with the operator
  remedy.
- **m2 — `SuiteDto.feature_id` is typed `number` but is now nullable.** `web/src/types/testdesign.ts:120` — a
  regression suite has `feature_id: null`. Type it `number | null`, or make `SuiteDto` a union discriminated on `kind`
  (coding-standards §3). No Phase 49 endpoint returns a regression suite yet, so nothing breaks today.
- **m3 — result rows are not "kept forever" when their scenario or case goes.** `kb_test_results.scenario_id` and
  `case_id` are `ON DELETE CASCADE` (`m0026:229-230`); D14.2/F11 say result rows are kept permanently. A feature
  delete (or a draft scenario/case delete) removes those rows from past regression executions, so the execution's
  `totals_json` no longer matches its results. Either record this as the intended meaning ("kept while the scenario
  exists") in As built and the ADR-081 Consequences, or keep the rows (`SET NULL` plus a stored scenario/case key).
- **m4 — As built must list the deviations** (none recorded yet; the spec file has no As built section): `app_uuid`
  NOT NULL + FK for both suite kinds; `kind DEFAULT 'feature'`; scenarios that name a setup count as referrers;
  `testimpact._scenario_steps` limited to feature scenarios until 51-06; the Phase 49 DTO/API additions and the web
  contract changes.

### Nits
- **n1** — `runner.py:120` `PRAGMA foreign_keys=ON` after commit has no effect: the connection is closed in `finally`
  right after, and every new connection sets it ON. Drop it or note that it is belt-and-braces.
- **n2** — `changes_shared_data` reaches the DTO as `0`/`1` (`testdesign.ts:102` `number`) while the library DTO
  converts `ever_referenced` to a bool. Pick one convention for flags.
- **n3** — `ExecutionStore.finish` accepts result rows for any existing scenario/case, even another application's,
  or a case that is not a step of the scenario. The engine (51-06) is the only writer, so this is optional hardening.
- **n4** — ADR-083 Consequences cite "`52-01-findings.md` §7 option B" as Phase 52's input. In 52-01 option B is the
  sandbox, "usable as a second layer"; the proposed design is option E (§8, superseded in part by §14). Name it so a
  reader doesn't take option B as the fix.
- **n5** — a feature scenario held in `kb_regression_items` can still be retired without notice. Leave it to 51-08, but
  decide whether retiring should warn about or skip the regression reference.

## Verdict: NEEDS_CHANGES

One major (M1): fix `_referrers` so refs whose source row is gone stop counting, and add the regression test (case ref
→ feature delete / draft `delete_case` → where-used empty, retire succeeds). Address m1–m4 or record them in As built.
Every gate is green, and m0026 upgrades both live databases cleanly. Once M1 is fixed, a re-review of the
`testexec_store.py` diff and the new test is enough.

---

# Re-review 51-04 — base 55af523 (genesis-review, 2026-11-03)

Scope: the same uncommitted working tree (28 modified + 4 untracked files, `git status --short`), with the fixes the
dev listed for M1, m1–m4 and n1–n5; the ADR-081 and ADR-083 Consequences in `adr-drafts.md`. I read the diff around
each fix, not whole files.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis tests/test_testexec_store.py tests/test_testexec_migration.py` | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1455 passed** (205.6 s) |
| `web: npx tsc --noEmit && npx eslint . --quiet && npx vitest run` | tsc clean, eslint 0 errors, vitest 467 passed (50 files) |
| stale bundle: `npx vite build --outDir /tmp/51-04-static-rr` then `diff -r /tmp/51-04-static-rr static` | IDENTICAL |

## Fixes, one by one

- **M1 — FIXED.** `TestLibraryStore._referrers` (`testexec_store.py:569-591`) now ends its WHERE with
  `AND COALESCE(a.status, s.status, tc.status) IS NOT NULL`, so a ref whose action, setup or case row is gone is not a
  user. The status columns are NOT NULL in their tables, so NULL here can only mean the source row is gone.
  `TestDesignStore.delete_case` (`testdesign.py:831-833`) deletes the case's `from_kind='case'` refs in the same
  transaction. The match is by key alone, which is safe because `TC-` keys are global (ADR-072). The regression test
  `test_refs_from_a_deleted_case_never_block_a_retire` (`tests/test_testexec_store.py:282`) covers both paths: the
  draft delete clears its refs, the feature delete leaves one ref row (`_count == 1`), `where_used` returns `[]`, and
  `retire` succeeds through `LifecycleService`. This is the regression test the first review asked for.
- **m1 — PARTLY FIXED; one case is still refused (minor, m1′ below).** The runner change itself is fine
  (`runner.py` diff). It records `foreign_key_check` before `BEGIN`, refuses only rows not in that set and logs the
  pre-existing ones. `test_the_flag_tolerates_a_violation_that_existed_before` covers an orphan in a table whose foreign
  keys the migration leaves alone. **I agree with the deviation from the spec's literal "must return nothing".** The
  spec's goal is that the rebuild adds no violation, and refusing to start on an unrelated old orphan would be worse.
  Record it in As built.
- **m2 — FIXED.** `web/src/types/testdesign.ts`: `SuiteDto.feature_id: number | null`, plus
  `kind: "feature" | "regression"` and `app_uuid: string`.
- **m3 — FIXED.** `m0026:225-249`: `scenario_id` (nullable) and `case_id` are `ON DELETE SET NULL`, with
  `scenario_key TEXT NOT NULL` and `case_key TEXT`. `ExecutionStore.finish` (`testexec_store.py:828-857`) resolves both
  keys inside the transaction through `_key_in_app`, which joins through the suite and raises `ValueError` for an
  unknown id or another application's id. `test_result_rows_outlive_a_deleted_feature` shows both rows survive a feature
  delete with their keys and NULL ids, and that `totals` is unchanged. The ADR-081 draft Consequences say this
  (`adr-drafts.md:76-78`). The readers still behave correctly: `last_result` (`testdesign.py:342-349`) and `_history`
  filter on `case_id`/`scenario_id`, so a deleted case's rows simply stop showing for it.
- **m4 — OPEN by design**, to be done in As built. It must list: `app_uuid` NOT NULL + FK for both suite kinds;
  `kind DEFAULT 'feature'`; scenarios that name a setup count as referrers; `testimpact._scenario_steps` limited to
  feature scenarios until 51-06; the Phase 49 DTO/API additions and the web contract changes; the m1 deviation (above);
  m3's SET NULL + stored keys; n5 deferred to 51-08.
- **n1 — FIXED.** The no-op `PRAGMA foreign_keys=ON` is gone. The module docstring says the connection is closed and
  every new `Database.connect()` turns foreign keys on again.
- **n2 — FIXED.** `_scenario_dtos` sets `changes_shared_data = bool(...)` (`testdesign.py:292-293`), the TS type is
  `boolean`, and the regenerated fixtures pass `contract.test.ts`.
- **n3 — FIXED** with m3 (`_key_in_app`). The finish test now expects `ValueError` for an unknown or other-app id. A
  case that is not a step of the scenario is still accepted. That is fine: 51-06 is the only writer.
- **n4 — FIXED.** `adr-drafts.md:215-217` names "`52-01-findings.md` §8 option E, revised by §14 D1" as the design and
  §7 option B as "an optional second layer … not the fix".
- **n5 — deferred to 51-08** (acceptable; note it in As built).

## Findings

### Blockers
None.

### Majors
None. M1 is fixed and has a regression test.

### Minors
- **m1′ — the "pre-existing violation" tolerance misses a table that m0026 gives a new foreign key.** The before/after
  sets compare whole `foreign_key_check` rows `(table, rowid, parent, fkid)`. `fkid` is the foreign key's index in the
  table's FK list, and `ALTER TABLE … ADD COLUMN … REFERENCES` renumbers that list. A toy check showed it:
  `('ch', 1, 'p', 0)` became `('ch', 1, 'p', 1)` after an FK column was added. m0026 adds
  `kb_test_scenarios.setup_id REFERENCES kb_test_setups(id)` (`m0026:273`). I probed a v25 DB (`MIGRATIONS[:25]`) with
  one orphan scenario (`suite_id=999`, inserted with foreign keys off), then ran `migrate(db, MIGRATIONS)`. The
  runner logged "1 foreign-key violation(s) existed before it ran" and then raised
  `ForeignKeyCheckError: migration 26 left 1 foreign-key violation(s): kb_test_scenarios#7→kb_test_suites`.
  Nothing is lost: the transaction rolls back and startup refuses with a clear message, which is the old strict
  behaviour. Both live DBs were clean in the first review, so this does not block.
  **Fix:** compare on `(table, rowid, parent)` and drop `fkid`. Extend the m1 test so the flagged migration also adds an
  FK column to the orphan's table.

### Nits
None new.

## Verdict: SHIP

There are no blockers or majors, and every gate is green (ruff clean; pytest 1455; tsc, eslint, vitest 467; the bundle
is identical). M1 is fixed and has a regression test. m2, m3, n1–n4 are fixed. m1′ is a minor that is fine to fix
before commit: a one-line change plus one extra test line. Record it in As built if you leave it. m4 and n5 belong in
the As built, with the list above.
