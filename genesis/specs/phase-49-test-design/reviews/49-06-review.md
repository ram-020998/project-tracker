# Review 49-06 — HTTP API — base a8ba5b8 (genesis-review, 2026-10-26)

Scope: `git -C genesis diff a8ba5b8` (HEAD = `a8ba5b8`, confirmed with `git log`) plus the untracked
`genesis/api/testdesign.py`, `tests/test_test_design_api.py` and `web/src/test/fixtures/testdesign/*.json` (9 files).
The change is uncommitted. Spec: `49-06-api.md` with its "Added after the 49-05 build" and "Added after the 49-04 build"
lists; upstream As built sections of 49-02, 49-04 and 49-05. Live acceptance is out of scope (49-08 does it).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1343 passed** in 211.86 s (49-04 left 1311; +32 = the 32 tests in `test_test_design_api.py`) |
| `.venv/bin/ruff check genesis tests/test_test_design_api.py` | All checks passed (ruff 0.15.20, pinned) |
| Stale bundle: `npx vite build --outDir /tmp/49-06-static` + `diff -r /tmp/49-06-static web/static` | identical |
| web lint / tsc / vitest | N/A. No TS/TSX changed; the JSON fixtures are not imported yet (49-07 will import them) |

## Checklist (`genesis-ctx check --since a8ba5b8 --repo genesis`, plus the manifest's L-011/L-026/L-058)

### ADRs
- [OK] ADR-011 reliability trio. No agent node is added or changed.
- [OK] ADR-012 the app never imports workflow Python. `api/testdesign.py` imports only `domain`, `kb`, `services`,
  `collab.identity`. Runs start through `RunManager.start` inside `TestDesignStageService`.
- [OK] ADR-023 FastAPI embedding. Plain routes on the shared `api` router.
- [OK] ADR-026 local, no auth. No bind or auth change, and no new network surface beyond `/api`.
- [N/A] ADR-027 / ADR-055 web stack and design language. The only web files are JSON test fixtures.
- [OK] ADR-028 everything under `/api`. Every route is registered on `api` (`testdesign.py:254-473`). Tests call `/api/...`.
- [N/A] ADR-031 / 033 / 034 / 045 chat posture. No chat code touched.
- [OK] ADR-035 uploads. `_uploads` caps at `MAX_DOCS` (3) before any read and returns 400 (`testdesign.py:236-247`).
  Files go to `RunManager.start` as `(name, bytes)`, which provisions them into the blackboard. The new
  `except FileUploadError → TestDesignInvalidError(status=400)` (`testdesign_stage.py:496-497`) is placed before the
  generic 409 fallback. Regression tests: `test_start_errors` (4 files → 400; `.exe` → 400).
- [N/A] ADR-043 Lavish. Not touched.
- [N/A] ADR-047 / ADR-074 sync. No scheduler/sync change. The impact sync source only reads `kb_syncs`.
- [OK] ADR-050 one transition authority. Both transition routes call
  `lifecycle.transition(EntityKind.TEST_CASE|TEST_SCENARIO, …, actor=canonical_username(settings))` on a
  `build_test_lifecycle_service(tests, emit=LifecycleAuditStore.record)` (`testdesign.py:186, 353-354, 424-425`). No
  route writes `status`. `update_case` refuses `status` (`kb/testdesign.py:597-600`). The stage start goes through the
  49-04 service. `allowed` comes from `lifecycle.allowed`, the action-based API.
- [OK] ADR-063 / ADR-065 collaboration. Untouched, and test design stays local-only (49-04 D12 guard).
- [OK] ADR-071 one canonical story page. `GET /applications/{app}/stories/{story_id}/test-cases` is a data read under
  the canonical page's prefix. It checks the story belongs to the app (`testdesign.py:441-443`, test
  `test_story_and_object_test_cases` → wrong app 404). No new story surface.
- [OK] ADR-076 locked spec through a CR. Not touched.
- [OK] ADR-077 agent system. Not touched.

### Lessons
- [N/A] L-003 / L-018 SSE. No SSE change.
- [OK] L-004 SQLite data plane. Every read and write goes through `TestDesignStore` / `TestImpactService` on `genesis.db`.
- [OK] L-010 `/api` prefix. Same evidence as ADR-028.
- [OK] L-011 contract fixtures. Nine fixtures under `web/src/test/fixtures/testdesign/`, checked by `_contract()` with a
  recursive key-shape compare (`test_test_design_api.py:72-94`). `test_the_contract_shape_catches_an_added_or_dropped_nested_field`
  proves the compare catches a dropped or added nested key. `impact-result.json` carries `hop` on suites and
  `object_removed` on cases and on `via` entries, as §1 requires. One gap: see m3.
- [N/A] L-017 / L-045 chat trust. Not touched.
- [N/A] L-019 secrets. Not touched.
- [OK] L-025 / L-027 ruff pinned. ruff 0.15.20, clean.
- [OK] L-026 no blocking DB work on the loop. Every handler is plain `def`, except the two multipart starts. Those are
  `async` only to `await f.read()`, then they `asyncio.to_thread(_call, svc.start|rerun, …)` (`testdesign.py:254-266`).
- [N/A] L-030 / L-051 / L-056 / L-057 release. No release here. Note for the release: the change is uncommitted, so
  make sure the commit includes the 3 untracked paths (L-056).
- [N/A] L-031 / L-048 / L-068. Not touched.
- [OK] L-039 one builder per DTO. `_scenario_dtos` is now the only scenario builder (`kb/testdesign.py:268-289`), used by
  `suite_tree` and `get_scenario`. `cases_for_scenario` and the story/object lists use `_case_dtos`. `SuiteTree` has
  one builder, `suite_view` (`testdesign_stage.py:395-400`), used by GET suite, Finalize and top-up apply. The refactor
  keeps `scenario_keys` semantics (`suite_tree` skips retired scenarios; `_case_dtos`'s own usage query filters
  `sc.status != 'retired'`, `kb/testdesign.py:323-330`). Test: `test_list_and_single_get_dtos_are_identical` covers
  suite vs case, suite vs scenario, story list and object list.
- [OK] L-058 level-triggered recovery. `_heal_stage` calls `StageFinalizer.reconcile_stage` (which never raises,
  `stage_finalizer.py:85-94`) on GET suite and GET latest top-up. `latest_topup` also reconciles a running top-up.
  `_resolve` runs `resolve_unresolved` on GET suite, GET case and POST impact (the impact call happens before the
  changed set is computed, `testdesign.py:467-469`). Failures are logged and the read still answers. Tests:
  `test_suite_read_heals_a_stranded_stage`, `test_suite_case_and_impact_reads_resolve_unresolved_links`,
  `test_impact_resolves_unresolved_links_first`, `test_resolve_failure_does_not_break_the_read`.
- [N/A] L-087 / L-088 / L-089. Not touched. The bundle was rebuilt out of tree and is identical.

### 49-06 spec items
- [OK] Route order (§1). The testdesign routes are registered before `register_features_routes` (`app.py:137-155`).
  `test_specific_stage_routes_are_registered_before_the_generic_ones` checks the router order for start and rerun.
  `test_each_specific_stage_route_answers_not_the_generic_one` shows the specific handlers answered (a multipart
  notes+file start, which the generic JSON route would reject). features.py has no generic `/stages/{stage}/finalize`
  (`features.py:1064-1551`), so finalize cannot collide.
- [OK] Error mapping (§1). `_call` (`testdesign.py:117-148`): `TestDesignError.status` is mapped one to one, as are
  `ImpactNotFound` → 404, `ImpactConflict` → 409, `StaleWriteError` → 409 `{error: stale_write, expected, actual}`,
  `IllegalTransition` / `PreconditionFailed` → 409 with the same bodies as `features.py:605-624` (stage_action),
  `UnknownEntity` → 404, `ConflictError` / `AlreadyFinalized` → 409 and `ValueError` → 422. Every 4xx in §2–§6 has a
  test: start/rerun/finalize, CSV, top-ups, case CRUD, scenario CRUD, cross reads, and impact 404/422/409 including
  "story of another app" (`test_impact_errors`).
- [OK] §3 coverage. `suite_coverage` is pure and has its own test (`test_suite_coverage_pure`). Retired cases are
  excluded (D15) and Tasks get `task` (D14). `VALID_STORY_TYPES` is `("Story", "Task")`, so `!= "Story"` ⇒ `task` is exact.
- [OK] §5 order. `_ordered` is a stable sort with retired cases last. Test asserts the retired case is last.
- [OK] §6 read-only. `test_impact_is_read_only` compares `iterdump()` before and after three sources, once any
  resolvable links are settled.
- [OK] 49-02 hand-off n3 (`case_title` / `case_status` in both builders) is covered by
  `test_scenario_read_with_derived_objects` plus the L-039 identity test.

## Judgement of the six deliberate decisions

1. **`allowed` on the case/scenario reads and transition responses.** Agree. It is additive and comes from
   `LifecycleService.allowed`, so the UI offers only legal actions without guessing (ADR-050). It is pinned in
   `case-detail.json` and `scenario-detail.json`.
2. **House dict detail for lifecycle refusals.** Agree. The body matches `features.py:605-624`, and `reason` names the
   blocking scenario (`test_case_transitions` asserts `TS-000001` in `reason`), which meets §4's "message names
   blocking scenarios". 49-07 must read `detail.reason` / `detail.allowed`, not a string.
3. **Retired cases last in the story/object lists.** Agree. This is what §5 asks for.
4. **The impact route's on-demand resolve can write.** Accept. §1 (the 49-05 addition) requires it, and it changes only
   link resolution, never stored impact data. The test pins "no change once settled". The §6 sentence "read-only (no
   writes, no Hub call)" now contradicts §1. The docs agent should reword it to "stores no impact data and makes no Hub
   call; it may resolve pending object links first".
5. **Fixtures under `web/`.** Agree. That is where L-011 and `contract.test.ts` already keep the golden fixtures.
6. **Delete the just-created draft when `set_steps` refuses.** Works, and the test proves no scenario remains. It is
   still create-then-undo, though: see m1.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1. Manual create is create-then-link, not one write.** `POST /features/{id}/test-scenarios` with `case_ids`
  (`testdesign.py:404-414`) commits the scenario, runs `set_steps` in a second transaction, and on refusal deletes the
  draft. A refused request still uses up a `TS-` number from `kb_sequences`. For a moment the draft is visible to other
  readers. If `delete_scenario` fails, the draft stays. `POST /features/{id}/test-cases` (`testdesign.py:321-335`)
  pre-checks foreign stories, but it also commits the case before `set_case_stories`, with no undo. Fix: validate
  `case_ids` up front, the same way `create_test_case` checks stories (same suite, not retired, one SELECT), so a
  refusal writes nothing and uses no key. Better still, add a store method that creates and links in one transaction.
- **m2. Every suite/case/impact read takes the DB write lock.** `resolve_unresolved` opens with `BEGIN IMMEDIATE` even
  when the app has no unresolved links (`services/testimpact.py:338-345`). Every `GET /test-suite`, every
  `GET /test-cases/{cid}` and every impact POST therefore queues behind any writer, such as a KB sync apply or a
  Finalize, for up to `busy_timeout=30000` (`db/database.py:28`) before it falls back to the log-and-continue path. That
  is the only effect, not a correctness bug, but it will show up as slow case pages during a sync. Fix: in `_resolve`,
  or at the top of `resolve_unresolved`, run a cheap read-only `SELECT EXISTS(… object_uuid IS NULL …)` and skip the
  write transaction when nothing is pending.
- **m3. `finalize.json` does not pin the item shapes of the dropped lists.** In the fixture, `dropped_story_keys`,
  `dropped_steps` and `dropped_scenarios` are all `[]`, so `_shape` reduces them to `[]`. 49-07 will report these to
  the user, and their item shapes (`{case, story_key}`, `{scenario, case, position}`, `{scenario, title}`, 49-04 As built
  decision 4) are not in any fixture. A rename on either side would not fail a test (L-011). Fix: generate the
  `finalize` fixture from a design that drops one of each. The 49-04 tests already build such designs.

### Nits
- **n1.** Several DTOs return the raw JSON column next to its parsed form: `gherkin_json` with `gherkin` on every case,
  `proposals_json` / `decisions_json` with `proposals` / `decisions` on the top-up. These are 49-02/49-04 builders, but
  this sub-spec freezes them into the web contract and roughly doubles the top-up payload. Consider dropping the raw
  columns at the API boundary before 49-07 types them.
- **n2.** `GET /applications/{app}/objects/{uuid}/test-cases` does not run `_resolve`, so a newly synced object's page
  can miss a link until the suite or case page is opened. That matches the spec's list of three reads; adding it would
  be cheap.
- **n3.** Some untested paths: `POST /features/9999/test-suite/topups` → 404, an unknown transition `action`, and
  scenario retire/restore through the API (the restore-blocked-by-retired-step rule is tested only at store level).
- **n4.** `remove_test_case_object` calls `tests.remove_case_object` without `_call` (`testdesign.py:374`). Harmless
  today. Wrapping it would keep the "one error mapper" rule uniform.

## Verdict: **SHIP**

No blockers or majors. Every gate is green on my own runs: 1343 passed, ruff clean, bundle identical. Every checklist
line is OK or N/A with evidence. m1–m3 should be fixed before 49-07 builds on this contract. m3 in particular is cheap
and protects the web types. They do not block this sub-spec. The §6 "read-only" wording goes to genesis-docs.

---

# Round 2 — base a8ba5b8, still uncommitted (genesis-review, 2026-10-26)

Scope: the same working tree (`git diff a8ba5b8` on `api/app.py`, `kb/testdesign.py`, `services/testdesign_stage.py`,
`services/testimpact.py`, plus the untracked `api/testdesign.py`, `tests/test_test_design_api.py` and the 9 fixtures).
I re-read the diff of the two changed store/service files and the changed routes and tests. `genesis-ctx check --since
a8ba5b8 --repo genesis` lists the same areas (api, release-ci, security) and the same checklist as round 1.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1345 passed** in 189.16 s (round 1: 1343; +2 new tests) |
| `.venv/bin/ruff check genesis tests/test_test_design_api.py` | All checks passed |
| `npx vite build --outDir /tmp/49-06-static-r2` + `diff -r … web/static` | identical |

## Round-1 findings

- **m1 — FIXED.** `create_case(…, story_ids=)` and `create_scenario(…, case_ids=)` now validate and link inside the
  same `tx()` as the insert (`kb/testdesign.py:577-608`). The no-op `UPDATE kb_test_suites` takes the write lock before
  the checks, and its `rowcount == 0` replaces `_require_suite`. Validation runs before `_insert_case` /
  `_insert_scenario`, so a refusal rolls back before any `kb_sequences` allocation. `set_steps` now uses the shared
  `_check_step_cases`. The routes call the store once (`api/testdesign.py:324, 396-397`). The create-then-delete is
  gone. Tests: `test_create_scenario_steps_and_errors` gets `TS-000004` after a retired-case and a foreign-case
  refusal. `test_create_case_and_its_errors` gets `TC-000005` after four refusals. The design has 4 cases, so no key
  was used.
- **m2 — FIXED.** `resolve_unresolved` returns early when the read-only `_has_unresolved` reports nothing pending
  (`services/testimpact.py:337-338, 368-377`). Its EXISTS predicate (`app_uuid=? AND object_uuid IS NULL AND
  tc.status != 'retired'`) is the same as the locked SELECT's, so the early return cannot skip a link the full path
  would resolve. `test_resolve_with_nothing_pending_takes_no_write_lock` holds `BEGIN IMMEDIATE` on a second connection
  and runs both the service and the impact route. Without the fix, the call would wait out `busy_timeout=30000` and
  raise "database is locked", so the test does catch a regression (slowly).
- **m3 — FIXED.** `finalize.json` now holds one item in each list: `dropped_story_keys`
  `[{case, story_key}]`, `dropped_steps` `[{scenario, case, position}]` ×2, and `dropped_scenarios`
  `[{scenario, title}]`. `test_finalize_response_is_a_suite_tree_with_coverage_and_the_dropped_lists` asserts the exact
  items (`test_test_design_api.py:183-197`) and then the contract shape.
- **n1 — FIXED.** `_case_dtos`, `_topup_dict` and `_suite_dict` `pop` the raw columns. A grep of `genesis/`,
  `tests/` and `web/src` finds no reader of `gherkin_json` / `proposals_json` / `decisions_json` / `upstream_json`
  outside the writers and the migration. No fixture contains a `*_json` key. Tests assert that the keys are absent
  (`:195-196`, `:327`).
- **n2 — FIXED, untested.** `object_test_cases` calls `_resolve(app_uuid)` (`api/testdesign.py:452`). No test shows
  that an unresolved link resolves on this read, unlike the suite, case and impact reads
  (`test_suite_case_and_impact_reads_resolve_unresolved_links`). See n5.
- **n3 — FIXED.** There are now tests for an unknown-feature top-up start → 404 (`:336`) and an unknown action → 409
  `illegal_transition` with `action` echoed (`:408`). `test_scenario_retire_and_restore_through_the_api` (`:545-563`)
  covers retire, then a restore refused with `precondition_failed` while a step case is retired, then a restore that
  succeeds after the case is restored.
- **n4 — FIXED.** `remove_test_case_object` goes through `_call` (`api/testdesign.py:371`).

## Checklist

Every ADR and lesson line answers as in round 1. The new code changes no evidence in a way that alters an answer:
- ADR-050: the create paths write `draft` directly, as before (initial state, not a transition). No status write was
  added.
- L-026: the handlers are still plain `def`. The new early-return path reads on its own connection.
- L-039: the builders lost columns in their one home, so list and single-get still agree
  (`test_list_and_single_get_dtos_are_identical` passes).
- L-011: the fixtures were regenerated, and the drift test still passes.
- L-056 (release note, unchanged): the commit must include the 3 untracked paths.

## New findings

### Blockers / Majors / Minors
None.

### Nits
- **n5.** The n2 change has no regression test. One line in `test_suite_case_and_impact_reads_resolve_unresolved_links`
  (or a sibling test) would pin it: a sync adds the planned object, then `GET /applications/{app}/objects/{uuid}/test-cases`
  lists the case.
- **n6.** `set_case_stories` (`kb/testdesign.py:691-706`) still has its own copy of the story-belongs-to-feature check
  that `_suite_stories` now owns. The two copies match today. Calling the helper with the case's suite would leave one
  copy.
- **n7.** The stale comment at `test_test_design_api.py:498` still says "the just-created draft is removed again".
  After m1, nothing is created. The comment should say "nothing is written and no key is used".

## Verdict: **SHIP**

All three round-1 minors and all four nits are fixed, and the m1–m3 fixes have tests. On my runs, 1345 tests pass,
ruff is clean and the bundle is identical. The new nits n5–n7 are optional and do not block 49-07. The round-1 note
for genesis-docs still applies: the §6 "read-only" wording needs rewording.
