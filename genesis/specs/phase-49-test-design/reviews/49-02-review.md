# Review 49-02 — base df9011dc (genesis-review, 2026-10-26)

## Re-review after fixes (genesis-review, 2026-10-26, round 2) — Verdict: SHIP

Same scope (working tree, still uncommitted, vs `df9011dc`). `genesis-ctx check --since df9011dc --repo genesis` lists the
same 18 files and the same checklist as round 1 (areas db, release-ci, security; `genesis/domain/**` and
`genesis/kb/testdesign.py` still unmapped, n4 stands for genesis-docs). Every round-1 checklist answer below still holds;
this section records only what changed.

**Gates (re-run by the reviewer):** `.venv/bin/python -m pytest -q -p no:warnings` → **1222 passed** in 164 s (round 1: 1218;
+4 new tests). `.venv/bin/ruff check genesis tests/test_test_design_store.py` → All checks passed.

| Round-1 finding | Status | Evidence |
|---|---|---|
| **M1** scenario restore lets a retired case back | **Fixed** | `transitions.py` `TEST_SCENARIO_PRECONDITIONS[(RETIRED,"restore")] = _no_retired_steps`, callable reason `_restore_scenario_reason` names the keys; `testdesign.py` `lifecycle_context` returns `retired_step_keys` (`_retired_step_keys`). Regression test `test_restoring_a_scenario_never_brings_back_a_retired_case` runs the exact round-1 repro (retire TS-000002 → retire TC-000003 → restore refused `match="TC-000003"`, status stays retired; restore case → restore scenario succeeds). |
| **M2** case retire hidden from `allowed()` | **Fixed** | `TEST_FILTERING_PRECONDITIONS = frozenset()` passed as `filtering_preconditions` in `build_test_lifecycle`; `_filtered` (lifecycle.py:107-118) then keeps every action (`not filters` → append). Test now asserts `"retire" in svc.allowed(...)` and `transition` raises `PreconditionFailedError` matching `TS-000002` (tests/test_test_design_store.py:541-543). Scenario `approve`/`restore` are offered-and-refused the same way, as documented next to the constant. Matches 49-06/49-07/49-08. |
| m1 49-04 empty-scenario hand-off | Deferred to As built (agreed) | — |
| m2 `set_topup_status` edges | **Fixed** | `_TOPUP_EDGES` (testdesign.py:50), check at :420 → `ConflictError`; `test_set_topup_status_enforces_its_edges` covers running→discarded refused, applied refused, CAS stale, discarded→running refused, ready→discarded allowed. |
| m3 story-specific Finalize message | **Fixed** | `AlreadyFinalizedError(..., what="stories")` default keeps the story message; test Finalize passes `"tests"`; test line 249 asserts `"tests already finalized"`. |
| m4 check-then-write race | **Fixed for `set_status` / `set_steps` / `delete_case`** | `set_status` re-checks after its UPDATE in the same tx (testdesign.py ~712-725) → `ConflictError` + rollback; `set_steps` CAS UPDATE now precedes the case checks; `delete_case` takes the lock with a no-op UPDATE. Python `sqlite3` opens the transaction at the first DML, so after these UPDATEs the checks run under the write lock and see committed state. `test_set_status_rechecks_invariants_inside_its_transaction` exercises both re-checks directly (it does not run threads; acceptable, the ordering is the mechanism). See m5 for the one remaining path. |
| n1 `TestStatus ⊆ LifecycleState` | **Fixed** | `test_every_test_status_is_a_lifecycle_state`. |
| n2 position bases | **Fixed** | module docstring testdesign.py:18-19. |
| n3, n4, decision #4 (49-03 `add_step.position` is 1-based) | Deferred to As built (agreed) | — |

### New finding

- **m5 (minor) — `apply_topup` has the same check-then-write window for `add_step` on an existing case.** `case_id_for`
  (testdesign.py ~483-489) checks the case is not retired with a SELECT. When the accepted set has no `new_case`, no write has
  run yet in that `with tx`, so the SELECT runs outside the write lock; a concurrent case retire can commit between it and
  `_insert_step_at`. The retire's own re-check passes because the step does not exist yet, so a ready scenario ends up with a
  retired case. The window is narrow and needs two concurrent UI actions on a single-user app. Fix (one line, can ride with
  49-04 or a follow-up): take the lock at the top of the tx (e.g. a no-op `UPDATE kb_test_topups SET updated_at=updated_at
  WHERE id=?`, as `delete_case` does) before resolving step cases. Record it in As built if not fixed now.

### Verdict: **SHIP**

No blockers, no majors; both majors are fixed with regression tests, every gate is green (1222 passed, ruff clean). Record in
As built: m1, m5, n3, n4 and the decision #4 hand-off. The change is still uncommitted; the dev should commit before handing to
release (L-056: confirm the commit includes the three untracked files).

---

## Round 1

Scope: genesis working tree (uncommitted) vs `df9011dc34ec2e4021187be80d04a42e7dbfd3c8`. Modified: `genesis/db/migrations/__init__.py`,
`genesis/domain/{__init__,enums,errors,lifecycle,transitions}.py`, 9 test files (version 24 → 25 bumps). Untracked:
`genesis/db/migrations/m0025_test_design.py`, `genesis/kb/testdesign.py`, `tests/test_test_design_store.py`.
Backend only; no API, web or live acceptance in scope.

`genesis-ctx check --files …` mapped only the migration files to an area (`db`); `genesis/domain/**` and
`genesis/kb/testdesign.py` map to no area. I added the sub-spec manifest's rules (ADR-050, ADR-072, ADR-075, L-039, L-083,
area stories-workbench) to the checklist by hand. Docs agent: `areas.toml` should route `genesis/domain/**` (ADR-050) and
`genesis/kb/testdesign.py`.

## Gates

- `.venv/bin/python -m pytest -q -p no:warnings` → **1218 passed** in 168 s (matches the dev's claim).
- `.venv/bin/ruff check genesis` → All checks passed. `ruff check tests/test_test_design_store.py` → All checks passed (ruff 0.15.20, pinned).

## Checklist

### ADRs
- [OK] ADR-010 — state small / bulk on blackboard: no graph state touched; the store holds records and pointers only.
- [N/A] ADR-011 — no agent node.
- [OK] ADR-024 — no engine change; the store is sync like `StoryStore` (docstring cites L-026).
- [N/A] ADR-026 — no network surface.
- [OK] ADR-030 — SQLite; repository methods take ids/mappings. `set_status(conn=)` passes a connection, the existing 46-04 pattern.
- [OK] ADR-036 / ADR-037 — no KB writes; object links store name/type/uuid/diff_hash only, no SAIL. `kb_objects` is read only
  (`testdesign.py` `_case_dtos`, `mark_reviewed`).
- [N/A] ADR-041 — documents untouched.
- [OK] ADR-042 — the suite cascades with the feature: `kb_test_suites.feature_id … ON DELETE CASCADE` (m0025); test
  `test_feature_delete_cascades_everything_even_with_referenced_cases` (all 7 tables → 0 rows).
- [OK] ADR-050 — status changes go through `LifecycleService` (`build_test_lifecycle_service`, lifecycle.py:348); `update_case`
  refuses `status` (test `test_update_case_cas_and_field_rules`); CAS on `row_version` / `expected_status` → `StaleWriteError`.
  Finalize/top-up insert records as `ready` without a transition, which matches how `StoryStore.finalize` creates stories.
  See **M1** and **M2** for two gaps in the lifecycle wiring.
- [N/A] ADR-054 — memory.db untouched.
- [OK] ADR-060 — one-time Finalize: `create_from_design` raises `AlreadyFinalizedError` inside the tx (testdesign.py:359); test
  asserts the second call raises. See m3 for the message.
- [OK] ADR-063 / ADR-065 — collab columns present and unused (`_COLLAB` in m0025); no sync wired.
- [N/A] ADR-070 — no wiki writes and no FK to `wiki_object_pages` (D5).
- [OK] ADR-072 — `TC-`/`TS-` keys from `kb_sequences` inside the write tx (`_next_key`); rollback also rolls back the counter
  (`test_create_from_design_is_atomic` gets `TC-000001` on retry); never reused (`test_keys_monotonic_and_never_reused_after_delete`);
  serialized under 4 threads × 10 (`test_concurrent_key_allocation_is_serialized`).
- [N/A] ADR-073 / ADR-074 / ADR-075 — not touched.
- [OK] ADR-077 — review run without `--trust-all-tools`; context via `genesis-ctx`.

### Lessons
- [OK] L-004 — data in genesis.db.
- [N/A] L-017 — no chat trust.
- [OK] L-025 / L-027 — ruff is pinned; no linter change.
- [OK] L-026 — sync methods documented for off-loop use; no async caller yet (49-04/49-06 must use `run_in_threadpool`/`to_thread`).
- [N/A] L-030 — no web change, no tag.
- [OK] L-032 — the object join picks `MAX(k2.id)` among open rows; `test_duplicate_current_kb_rows_do_not_duplicate_links`.
- [OK] L-039 — one `_case_dtos` builder for `suite_tree` / `get_case` / `cases_for_story` / `cases_for_object`;
  `test_list_and_single_get_dtos_are_identical` asserts equality, including `get_scenario` == the tree's scenario.
- [N/A] L-045, L-051, L-056, L-057, L-087, L-088 — no release or agent-system change in this sub-spec.
- [OK] L-083 — fingerprints tested with the real breakdown AC shape `"Given …\nWhen …\nThen …"` (`test_story_fingerprint_real_ac_shape`, fixture `AC`).
- [N/A] L-089 — no bundle.

### Spec §6 test list
- [OK] fresh → v25 with tables/indexes/counters; v24 → v25 upgrade keeps rows and the `story` counter; idempotent re-run.
- [OK] key allocation (monotonic, not reused, concurrent); Finalize atomic (failure injected on the 2nd story link → 0 rows in all tables) and refuses a second call; document order (F10, document deliberately out of epic order).
- [OK] referenced case refuses `delete_case` while the feature cascade still works; draft-only delete; CAS → `StaleWriteError`; `set_steps` cross-suite / retired / stale refusals.
- [OK] feature and story cascades; every object `state` and `needs_review`; `mark_reviewed` (removed stays removed, F8).
- [OK] `suite_tree` ≤ 5 SELECTs with 33 cases (trace callback count); `cases_for_story` ≤ 4.
- [OK] lifecycle: allowed/refused transitions, retire-while-referenced message names `TS-000002`, caller ctx cannot bypass, audit rows with actor.

## Deliberate decisions (dev's list)

1. READY/RETIRED on `LifecycleState` + `TestStatus` as the store's validation set — **OK**. Nothing iterates `LifecycleState`
   (grep), so the additions change no existing behaviour. Nit n1: no test pins `TestStatus ⊆ LifecycleState`.
2. `EntityLifecycle.context` + callable `precondition_reasons` — **OK**; additive (both default to the old behaviour; the whole
   suite passes) and tested (`ctx={"active_scenario_keys": []}` still refused). Consequence: with a context provider, `allowed()`
   always applies preconditions, which leads to **M2**.
3. `ConflictError` — **OK**. 49-06 must map it to 409 (it is not mapped in `genesis/api` yet; expected).
4. 1-based step positions — **OK**, consistent across `create_from_design`, `set_steps`, `_insert_step_at`. Hand-off: 49-03 §4.3
   `add_step.position` does not say 1-based; the workflow prompt must say so. Case/scenario `position` is 0-based (n2).
5. Rigid `create_from_design` — **OK**, tested for each refusal. Hand-off (m1): 49-04 §5 step 2 removes steps that point at
   dropped cases but does not say to drop a scenario left with zero steps; the store will then refuse the whole Finalize.
6. Extra methods (`get_case`, `get_scenario`, top-up row methods) — **OK**; see m2 on `set_topup_status`.
7. Top-up object links keep origin `design` — **OK**, matches the spec's object-origin set and is asserted in the top-up test.
8. `include_retired=False` default — **OK**, matches D15 ("retired excluded from impact and coverage").
9. `testdesign` Migration name and `__test__ = False` — **OK** (R6). `__test__` inside a `StrEnum` body is a dunder, so it is
   not an enum member (`VALID_STATUSES` has 3 values).

## Findings

### Blockers
None.

### Majors

- **M1 — Restoring a scenario can produce a ready scenario whose steps include a retired case.** The model's rule is that a live
  scenario never contains a retired case: `set_steps` refuses one, and retiring a case used by a non-retired scenario is refused.
  But `(RETIRED, "restore")` on a scenario has no precondition (`transitions.py:152`, `TEST_SCENARIO_PRECONDITIONS` only covers
  `approve`). Sequence: retire scenario → its case is no longer "used" → retire the case → restore the scenario. Reproduced
  against the working tree:
  ```
  restore scenario -> ready
  scenario ready [('TC-000003', 'retired')]
  ```
  49-04 (CSV/coverage) and 49-06 would then show a ready scenario running a retired case, which D15 excludes from coverage.
  **Fix:** add a scenario precondition on `(RETIRED, "restore")`: every step case is non-retired; put `retired_step_keys` in
  `lifecycle_context` for scenarios and a callable reason naming them ("restore TC-… first or edit the steps"). Add a regression
  test for the sequence above.

- **M2 — Case `retire` is hidden from `allowed()` when a scenario uses the case, so the UI can never show the refusal that
  49-06/49-07/49-08 specify.** `build_test_lifecycle` sets no `filtering_preconditions` (lifecycle.py:335-344), so every
  precondition filters; and because `context` is always merged, `allowed()` always filters for test kinds. The test pins this:
  `assert "retire" not in svc.allowed(EntityKind.TEST_CASE, c3["id"], ctx={})` (tests/test_test_design_store.py:542).
  Downstream contracts expect the opposite: 49-06 `POST /test-cases/{cid}/transition` → "409 refused (message names blocking
  scenarios)"; 49-07 "lifecycle actions from the allowed set (Approve · Retire · Restore; refused retire shows the blocking
  scenarios)"; 49-08 acceptance row 7 "retire a case used by a scenario → retire refused naming the scenario". The spec
  precedent is the same: `SPEC_FILTERING_PRECONDITIONS` (transitions.py:66-73) keeps reason-bearing actions visible so the
  button returns a 409 with the reason. **Fix:** give the test kinds a `filtering_preconditions` set that excludes the case
  retire keys (keep the scenario `approve`/M1 restore choice deliberate and documented), and flip the test assertion to
  "retire is offered; transition raises naming TS-…". If the dev prefers hiding, that is a contract change for 49-07/49-08 that
  the spec author must sign off; either way it should be settled here, where the lifecycle is defined.

### Minors

- **m1 — Hand-off gap to 49-04 (decision 5).** After 49-04 removes steps that point at dropped cases, a scenario may have no
  steps, and `create_from_design` raises `ValueError("scenario … has no steps")`, failing the whole Finalize. Record in As built
  that 49-04 must also drop (and report) scenarios left empty; or flag it to genesis-spec to amend 49-04 §5.2.
- **m2 — `set_topup_status` does not enforce its documented edges** (testdesign.py:410). The docstring says running → ready |
  failed and ready → discarded, but any CAS pair is accepted except a target of `applied`; e.g.
  `set_topup_status(id, "running", expected_status="applied")` would reopen an applied top-up. Add an edge table
  (`{"running": {"ready","failed"}, "ready": {"discarded"}}`) → `ConflictError`, with a test.
- **m3 — `AlreadyFinalizedError` message is story-specific.** Reusing it for tests yields "feature #N **stories** already
  finalized at …" (errors.py:105-110), which 49-04/49-06 would surface on a second test Finalize. Add an optional `what`
  parameter (default `"stories"`) and pass `"tests"`.
- **m4 — Check-then-write race on retire.** `lifecycle_context` reads on its own connection, then `set_status` writes in a
  separate tx; a concurrent `set_steps` that validated the case as ready can commit in between and leave a live scenario with a
  retired case (the M1 invariant again). Single-user makes this unlikely; acceptable if documented, or re-check
  `active_scenario_keys` inside `set_status` for `retired` on cases.

### Nits

- **n1** — Add a one-line test that `{s.value for s in TestStatus} <= {s.value for s in LifecycleState}`; `read()` relies on it.
- **n2** — Case/scenario `position` starts at 0 (`_next_position`, testdesign.py:790) while step positions start at 1. Fine
  internally, but say so in the module docstring next to the 1-based step note, since 49-04's CSV prints `TS-…#position`.
- **n3** — 49-06 `ScenarioDto.steps` adds `case_title` and `case_status`; when 49-06 adds them, add them in both `suite_tree`
  and `get_scenario` (L-039; the equality test will catch a drift).
- **n4** — `genesis-ctx` routing: `genesis/domain/**` and `genesis/kb/testdesign.py` map to no area, so `check` missed ADR-050
  (pass to genesis-docs).

## Verdict: NEEDS_CHANGES

The migration, store, key allocation, fingerprints, derived states and tests are solid, and every gate is green. Two
lifecycle issues must be settled before ship: **M1** (scenario restore lets a retired case back into a live scenario; add the
precondition and a regression test) and **M2** (case retire is filtered out of `allowed()`, contradicting the 49-06/49-07/49-08
refusal flow; add `filtering_preconditions` or get a spec sign-off). Minors m1–m4 can go into As built / follow-ups.
