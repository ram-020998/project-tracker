# Review 54-06 — base 9f63fc2, head ab9a13e (genesis-review, 2026-11-19)

What this change does: adds the Phase 54 HTTP contract. That is `/schedules*` (14 routes, including D39's
`sync-status`), the `/custom-agents` CRUD beside the 54-05 Run route, `/notifications*`, chat `mode`/`agent_id`
(D37, which answers 409 until 54-08), `trigger` on runs and `schedulable` on `GET /workflows/{id}`. It edits the
unreleased m0030 in place (`schedule_runs.counts_toward_pause`, D36; `chat_sessions.agent_json`, D37), moves the 54-05
n1 agent check under the schedule write lock, and adds the web types, client functions, golden fixtures and contract
tests, plus the §3a carry-overs (`agent.prompt` kind parity, the `CaptureProposals` union).

Commits: `9895cdb` (source, tests, fixtures) and `ab9a13e` (web/static). Both resolve; HEAD = `ab9a13e`; the tree is
clean (`git status --short --untracked-files=all` empty).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` (full, no deselect, 15:3x–15:5x IST) | **2073 passed** in 662.73 s |
| `.venv/bin/ruff check genesis tests/test_schedules_api.py` | All checks passed |
| `npm run lint` | 0 errors, 20 warnings (none in changed files) |
| `npm run typecheck` | clean |
| `npx vitest run` | **816 passed**, 70 files |
| Stale bundle: `npx vite build --outDir /tmp/54-06-static` then `diff -r /tmp/54-06-static web/static` | IDENTICAL |
| Targeted: `test_schedules_api.py test_schedule_migration.py test_chat_store.py test_sync_jobs.py` | 65 passed |
| D36/D37 condition: `ps -ww -eo pid,lstart,command` (read only) | main pid 10561 started Wed Nov 18 16:32:16; userb pid 56871 started Sun Nov 15 03:33:19. Both are before m0030 first landed (`41d4d0e`, 11-18 18:48), so the in-place edit is safe |

The check also lists the genesis-workflows, kiro-agent-sdk and playwright-appian gates. They are N/A: nothing in those
trees changed (the check is mapping `web/static/**` to every area).

## Checklist

Areas: api, browser-testing, chat, db, release-ci, runs-worker, security. The check lists 125 files (61 without
`web/static`), so it pulls in nearly every ADR and lesson. Each line is answered; most are N/A because the diff touches
only the HTTP layer, the schedule store, m0030 and web types.

### ADRs
- [N/A] ADR-001 LangGraph owns control flow: no graph code changed.
- [N/A] ADR-002 narrow Kiro turns via ACP: no agent-turn code.
- [N/A] ADR-004 per-node MCP injection: none. `check_picks` is only reused (schedule_routes.py:203).
- [N/A] ADR-005 library registry: no change to the registry.
- [N/A] ADR-008 one local app: no change.
- [OK] ADR-009 HITL modes: `last_run.gate_cancel_at` only reads the gate wait (`Scheduler.gate_cancel_at`, scheduler.py:376). The gate logic is unchanged (test_last_run_of_a_run_waiting_at_a_gate_says_when_it_is_cancelled).
- [OK] ADR-010 state stays small: `agent_json` is a snapshot column on `chat_sessions`, not LangGraph state.
- [N/A] ADR-011 reliability trio: no agent node.
- [OK] ADR-012 the app never imports workflow Python: `_check_workflow` uses `loader.meta_of`/`schedulable_of` (META only), and `pickable` uses `loader.installed()`.
- [N/A] ADR-018, ADR-019, ADR-020: no blackboard, compat or Kiro-config change.
- [N/A] ADR-021 auto-approve and gates: no gate change.
- [N/A] ADR-022 artifacts root: no change.
- [OK] ADR-023 FastAPI embedding: routes are plain FastAPI on the `/api` router (app.py:317-325).
- [OK] ADR-024 async-first: async routes do their blocking work through `asyncio.to_thread`; sync routes run in the threadpool (choices 4 and 5).
- [N/A] ADR-025 fork: no change.
- [OK] ADR-026 local single user, no auth: no new bind or exposure.
- [OK] ADR-027 web stack: types and client only; no new dependency.
- [OK] ADR-028 everything under `/api`: every route is registered on `api` (app.py:319-332). The client paths carry no `/api` (lib/api/schedules.ts, customAgents.ts, notifications.ts), and MSW serves `/api${path}` with `onUnhandledRequest: "error"` (phase54-contract.test.ts).
- [OK] ADR-029 two-tier registry and trust: `pickable` and `_check_agent_prompt` use `pickable_servers`/`check_picks` over `config.merged_mcp_registry` (D33 has one home).
- [N/A] ADR-030 SQLite: additive columns only.
- [OK] ADR-031 chat read-only: `mode` accepts only `read_only|copilot` (chat.py:220). An `agent_id` is refused with copilot (422) and with read_only (409, nothing stored, test_chat_session_create_with_mode_and_agent). The mode change is refused for an agent session (D26).
- [OK] ADR-032 real credits with provenance: history credits come from `eventlog.aggregate_credits`, and each figure carries `credits_provenance` (schedule_routes.py:418-434). A row with no run gets `credits: null, provenance: null`, and an empty set gets `unavailable` (test_history_has_durations_idle_time_counts_and_metered_credits asserts 1.25/metered and None/None).
- [OK] ADR-033 copilot run control: creating a copilot session honours the kill-switch (chat.py:229; the last assertion of the test). No new copilot tools.
- [OK] ADR-034 skills: `pickable.skills` and the skills check read the managed `skills.list()` only.
- [N/A] ADR-035 run input files: the file-input rule refuses them for schedules (422 `target.inputs`, tested). Nothing is provisioned.
- [N/A] ADR-036, ADR-037: `app_sync_per_app` is moved verbatim; it reads KB metadata only and no SAIL.
- [N/A] ADR-041, 042, 043, 045, 046, 050, 051, 053, 054, 055, 059, 060, 061, 062, 063, 065, 066, 068, 069, 070, 071, 072, 073, 074, 075, 076, 078, 080, 081, 082, 083, 084, 085, 086: none of their surfaces changed (`collab_enabled` only moved; `CaptureProposals` is a type-only change over the existing stored shapes, ADR-081).
- [OK] ADR-047 fixed, backend-defined maintenance syncs: system rows accept only `schedule, enabled, options, policy` (403 otherwise, tested); `reset` restores defaults.
- [OK] ADR-077 agents load L0 + pack: N/A to code; this review used `genesis-ctx check`.

### Lessons
- [OK] L-001, L-002: N/A (no ACP env).
- [OK] L-003, L-018, L-118: N/A (no SSE change).
- [OK] L-004 SQLite: the new columns are in `genesis/db/migrations` only.
- [OK] L-005 canonical event kinds: `runs.manager.CANONICAL_KINDS` (manager.py:47-52) = `_log`'s kinds + `_CANONICAL_CUSTOM`. `custom` is excluded (test_the_canonical_event_kinds_file_is_the_backend_set).
- [N/A] L-007, L-008, L-009, L-016, L-017, L-019, L-020, L-021, L-023, L-024, L-031, L-033, L-041, L-042, L-044, L-045, L-046, L-047, L-048, L-050, L-051, L-058, L-059, L-060, L-061, L-062, L-065, L-066, L-068, L-069, L-073, L-081, L-086, L-087, L-088, L-092, L-093, L-097, L-098, L-099, L-100, L-101, L-104, L-105, L-106, L-107, L-112, L-113, L-114, L-115, L-116, L-117, L-119: their surfaces are not in this diff.
- [OK] L-010 `/api` centrally: see ADR-028.
- [OK] L-011 contract drift fails a test: contract.test.ts compares `CANONICAL_EVENT_KINDS`, the `EVENT_FIXTURES` kinds and `events/canonical-kinds.json` both ways. The author's mutation (dropping `agent.prompt` from the web list) failed it. phase54-contract.test.ts uses `Exact<T>` key lists against recorded fixtures.
- [OK] L-025, L-027 pinned ruff: unchanged; `.venv/bin/ruff` is clean.
- [OK] L-026 no blocking DB on the loop: every new async route wraps store, loader and KB calls in `to_thread` (schedule_routes.py:291-447; notifications.py; custom_agents.py:80-129; chat.py:225-231).
- [OK] L-030 frontend job and the stale bundle: `web/**` changed and the bundle is fresh (diff identical).
- [OK] L-039 list = get: `listed == [got]` for agents (`used_by_map`), and the list item equals `GET /schedules/{id}` (test_list_get_and_the_schedule_shape). Run names resolve per page in one query (`ScheduleStore.names`).
- [OK] L-056, L-057: N/A (no release). The commit holds all source and tests (`git diff --stat`, 61 files).
- [OK] L-083 real value shapes: fixtures are written from real responses by `record(...)` in test_schedules_api.py and parsed through the client functions.
- [OK] L-089 bundle commit checked after the build: `git show --stat ab9a13e` = 64 files of `web/static` (author), and the reviewer's out-of-tree build is identical.
- [OK] L-090: N/A (no table layout).
- [OK] L-091 lock first, then validate: `_agent_exists` runs after `BEGIN IMMEDIATE` in `create_user` (schedule_store.py:343-344), and in `update` after `_locked`. `CustomAgentStore.delete` checks `_used_by` under its own `BEGIN IMMEDIATE` (agents/store.py:244-252). test_a_schedule_saved_after_its_agent_is_deleted_is_refused_under_the_lock covers it; the author's mutation (removing `_agent_exists`) failed it.
- [VIOLATION, minor] L-094 list every consumer: the §2 list the author will record is missing entries. See m3.
- [OK] L-096 route order: the static `/schedules/preview|pickable` are registered first, and `{id:int}` convertors stop shadowing. test_no_phase_54_route_is_shadowed_by_an_earlier_one (23 routes, index order) and test_static_paths_answer_beside_the_id_routes_and_the_catch_all_holds (404/405 table) cover it.
- [OK] L-102: N/A (no rebuild: `_add` plus a column in a `CREATE TABLE IF NOT EXISTS`).
- [OK] L-103 derived rows die with the source: unchanged (`delete_user` deletes `schedule_runs` in its own transaction).
- [OK] L-108 terminal write is a CAS: `close_fire` still returns early unless `outcome='fired'` under `BEGIN IMMEDIATE`, and `counts_toward_pause` is written in the same UPDATE.
- [OK] L-109 one home, one reader: `counts_toward_pause` is read only from the column. `describe` (backend) owns summary and cadence. `validate_sync_options`, `app_sync_per_app` and `collab_enabled` each have one home shared by the old and new routes (test_sync_status asserts `old["per_app"] == st["per_app"]`). The near-copy of `_models` is n1.
- [OK] L-110 prove by what ran: the reviewer ran every gate at `ab9a13e`.
- [OK] L-111 live acceptance open: out of scope (54-10). The report says so below.

## Findings

### Blockers
None.

### Majors
- M1 **The history's credits for a regression row are untested** (`genesis/api/schedule_routes.py:410-416`).
  What: a `schedule_runs` row with no `run_id` but an `execution_key` gets its run id through
  `executions.store.get_by_key(key)["run_id"]`. That id feeds `credits`, `provenance` and `credits_total`.
  Problem: a regression schedule's rows always take this branch. Its handler returns only
  `Started(execution_key=…)` (`runtime/schedule_targets.py:130`), so `run_id` stays NULL on every regression row.
  No test builds such a row: the only `execution_key` in test_schedules_api.py is the run-now key-set assertion, and
  the history test's rows all carry a `run_id` or nothing. Two cases go unseen: a wrong attribute (the store's
  `get_by_key` lives on `TestExecutionService.store`, an `ExecutionStore`) would 500 the History tab of every
  regression schedule, and a wrong key would silently show `credits: null`.
  Fix: in test_history_has_durations_idle_time_counts_and_metered_credits, or a sibling test:
  1. Create a `TE-` execution through `env.app.state.test_executions.store` with `run_id=<a real run>`.
  2. Open and close a row with `set_run(row, execution_key=key)` only, and append an `agent.result` with credits to
     that run.
  3. Assert that the row's `credits`/`provenance` and `credits_total` include it, and that its `run_id` stays null.

  If skipped: 54-07's history page for regression schedules rests on an unexercised lookup.

### Minors
- m1 **`describe` says "Every N hours" for a window that leaves a gap** (`genesis/runtime/schedule_model.py:330-333`).
  What: `_whole_day` treats `start == "00:00" and end >= 24-every` as the whole day and drops the window from the words.
  Problem: when `every_hours` does not divide 24 the slots are uneven. Run by the reviewer:
  `{"kind":"interval_window","every_hours":10,"start":"00:00","end":"14:00"}` gives summary `"Every 10 hours"` and line
  `"every 10 h"`, but `schedule_times` gives `['00:00', '10:00']`, a 14 h gap overnight. `every_hours: 5`, `end:
  "19:00"` gives "Every 5 hours" with slots 00/05/10/15 (a 9 h gap). The backend owns these words (L-109), so they
  must not misstate the cadence.
  Fix: `return 24 % every == 0 and schedule.get("start") == "00:00" and end >= f"{24 - every:02d}:00"`, and add the two
  cases to the `describe` parametrize.
- m2 **`PUT /schedules/{id}` `options` on application-sync silently resets values** (`schedule_routes.py:235-241`).
  What: `_options` passes `raw if isinstance(raw, dict) else {}` to `validate_sync_options`, which starts from
  `APP_SYNC_DEFAULT_OPTIONS`.
  Problem: (a) `{"options": "x"}` or `{"options": null}` answers 200 and resets all four options to their defaults.
  (b) `{"options": {"full_every_days": 3}}` after the user set `max_changed: 10` resets `max_changed` to 500. That
  contradicts this route's own contract ("Only the given fields change", the docstring at 320-321) and the
  `ScheduleUpdate.options` partial type. The old `/system/sync-settings` PUT always sent the whole set, so the
  behaviour was harmless there.
  Fix: `if not isinstance(raw, dict): raise ScheduleError("options must be an object")` and
  `validate_sync_options({**(job.options or {}), **raw})`. The existing test stays green (500 is both the default and
  the current value).
- m3 **The §2 consumer list (L-094) misses consumers that 54-07 will break.** Add the following to the As built list:
  - `tests/test_testing_api.py:701` records the `testing/schedule.json` fixture through `PUT …/testing/schedule`, and
    `web/src/test/fixtures/testing/schedule.json` is imported by `setup.test.tsx:15`.
  - `tests/test_scheduler.py:220` calls `ScheduleStore.update_settings`.
  - `tests/test_schedules_api.py:364` is new in this diff: the D39 parity assertion calls `GET /api/system/sync-settings`
    and must be dropped or rewritten when that route goes.
  - The registration `register_schedules_routes(...)` at `genesis/api/app.py:316-317`, and `api/schedules.py`'s
    imports of `app_sync_per_app`/`collab_enabled`/`validate_sync_options`.

  The reviewer's grep confirmed the author's "none" for `genesis/scripts`, fleet `gsm` and genesis-workflows (no
  `sync-settings`, `system/schedules` or `testing/schedule`), and that the copilot control server reads only named
  fields from `/runs/{id}` and `/workflows/{id}` (control_server.py:171-206).

### Nits
- n1 Kiro's model list is read by three near-copies: `_models` in `schedule_routes.py:169-175` and
  `custom_agents.py:59-67`, plus the `pickable` parse at `schedule_routes.py:270-276`. One helper (e.g. on
  `ChatManager` or in `api/_shared.py`) returning `[{id, name}] | None` would serve all three.
- n2 `web/src/types/schedules.ts:4` says the fixtures are checked by `schedules-contract.test.ts`. The file is
  `phase54-contract.test.ts`.
- n3 `ScheduleCadence` now names two different types: the string union in `types/testing.ts:84` and the interface in
  `types/schedules.ts:64`. This is like choice 6 (`ActivityItem`). Record it with the 54-07 removal of
  `RegressionSchedule`.
- n4 `CreateChatSession.mode` is typed `ChatSessionMode` (`types/chat.ts:30`), which includes the stage modes the route
  answers 422 for. `"read_only" | "copilot"` matches D37.
- n5 D38 a's "every 422 body is `{detail, field, refused?}`" holds for refusals only. FastAPI's own validation
  (`?limit=abc` on history/notifications, `agent_id: "x"`, a JSON array as a schedule body) answers
  `{detail: [...]}` with no `field`. `fieldRefusalOf` returns null for those, so the web is safe; one line in api.md
  would avoid surprise.
- n6 `credits_total` sums only the page shown (`limit` ≤ 200) while `total` counts every row (author's choice; the spec
  is silent). 54-07 should label it as the shown runs' total, or the route should sum over all rows.
- n7 `validate_schedule` (54-04) accepts a schedule that can never run (`days: [5], weekdays_only: true`), which
  `describe` renders as "Weekly on no day at 09:00" (tested as such). Refusing an empty effective day set would be
  clearer.

### The author's choices
1. `{id:int}` convertors: **OK.** Non-int ids fall through to the 54-02 catch-all (404). A wrong method on a static
   path is 405 because the int route does not match `preview` or `pickable` (route-table test). The Run route's
   `{agent_id:int}` also turns a non-int id from 422 into 404; no caller depends on the old answer.
2. `POST /custom-agents` 200: **OK**, as in §1's table (it differs from `POST /schedules` 201; both follow the spec).
3. `counts_toward_pause` null for non-failed outcomes: **OK.** It matches `close_fire` (only `failed` changes
   `failure_count`) and D36. The web type is `boolean | null`, and `_run_dict` turns the INTEGER into a bool
   (schedule_store.py:137-138).
4. Async chat create with `to_thread`: **OK** (L-026).
5. The 54-05 Run route and the runs/chat sync routes stay `def`: **OK.** The threadpool keeps blocking work off the
   loop; `schedule_names` runs there too.
6. `ActivityItem` in two places: **OK** as a nit, retired by 54-09 (cr-flow.ts imports the metrics one).

## Not checked
- Live acceptance (54-10): no fleet update, no browser, no real Kiro model list. The model list is stubbed in tests.
- The real `ScheduleRefused` message text in a browser, and how 54-07's pages use `fieldRefusalOf`/`inUseOf` (not built yet).
- `~/.genesis/genesis.db` and the fleet DBs were not opened (as instructed). The m0030 safety rests on the `ps` start
  times above.

## Verdict: NEEDS_CHANGES

All gates are green and the contract matches §1, §3a, and D36–D39 closely. The one change needed before SHIP is M1, a
test for the regression-row credits branch. m1 and m2 are small fixes worth taking in the same pass, and m3 belongs in
the As built consumer list.

---

## Re-run 1 — fix commit a6cc287 over ab9a13e (genesis-review, 2026-11-19)

What changed: `git diff ab9a13e..a6cc287` touches 7 files (+75/−27). It adds the M1 regression-row credits test, the
m1 divisor check in `_whole_day`, the m2 options merge and non-object refusal, the n1 `kiro_models` helper, and type
or comment fixes for n2, n4 and n6. HEAD = `a6cc287` and the tree is clean (`git status --short --untracked-files=all`
is empty).

### Gates (run by the reviewer at a6cc287)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` (full, no deselect, started 15:59 IST) | **2077 passed** in 664.73 s (round 1: 2073, plus the 1 new test and 3 new `describe` cases) |
| `.venv/bin/ruff check genesis tests/test_schedules_api.py` | All checks passed |
| `npm run lint` | 0 errors, 20 warnings (same as round 1) |
| `npm run typecheck` | clean |
| `npx vitest run` | **816 passed**, 70 files |
| Stale bundle: `npx vite build --outDir /tmp/54-06-r1b-static` then `diff -r /tmp/54-06-r1b-static web/static` | IDENTICAL. The web change is type and comment only, so the `ab9a13e` bundle is still current |

### Round-1 findings

- **M1: resolved.** `tests/test_schedules_api.py::test_a_regression_rows_credits_come_from_its_executions_run`
  creates a real `hello` run with credits 0.5 and None. It records the run on a `TE-` execution through
  `ExecutionStore(env.settings.db_path).create(APP, "regression", run_id=…)`, the same store the route reads
  (`executions.store.get_by_key`, `schedule_routes.py:408-409`; `ExecutionStore.get_by_key`, `testexec_store.py:1097`).
  The row carries only `execution_key`. The test asserts `run_id` null, credits 0.5 with `partial` on both the row and
  `credits_total`, and the key on `last_run`. Credits of 0.5 can only come through the execution lookup, because the
  row has no `run_id`, so a wrong attribute (a 500) or a wrong key (null credits) both fail it. The author's mutation
  (`rid = None`) was not re-run by the reviewer; the reasoning above covers it.
- **m1: resolved.** `schedule_model.py:330-335` adds `24 % every == 0`. A reviewer probe of `describe`: 10 h
  00:00–14:00 gives "Every 10 hours, 00:00–14:00"; 5 h 00:00–19:00 and 7 h 00:00–21:00 keep their windows; 6 h, 8 h,
  24 h and 1 h whole days still read "Every N hours" / "Every hour". Three parametrize cases are added
  (`test_schedules_api.py:117-123`).
- **m2: resolved.** `_options` (`schedule_routes.py:232-242`) refuses a non-object with 400 `options must be an
  object` and merges over `job.options`. application-sync is validated through `validate_sync_options({**stored,
  **raw})`. On a user row, `{}` still reaches the store's "only a system schedule has options" 400
  (`schedule_store.py:363-364`, test line 231). A user row's `options: null` used to be ignored silently (200) and is
  now 400, which is the stricter and correct answer. The test checks partial PUTs keeping 3/10/50, 400 for each of
  `null`, `"x"` and `[1]`, and that the stored value is unchanged after a refusal (`test_schedules_api.py:243-250`).
- **m3: accepted as a commitment.** 54-06's As built is still the placeholder (`54-06-http-api.md:159-161`). The list
  in the brief matches round 1's m3 entries. genesis-dev must write it there before the sub-spec closes.
- **n1: resolved.** `api/_shared.kiro_models` is the only parser. `custom_agents._models`, `schedule_routes._models`
  and `pickable.models` call it. Behaviour is unchanged: an exception or an empty list gives None. `schedule_routes`
  now also handles `chat is None`, which it did not before.
- **n2, n4, n6: resolved** (`types/schedules.ts:4`, `types/chat.ts:30-31`, `types/schedules.ts:155-157`). n6 hands
  the "this page's total" label to 54-07.
- **n3, n5, n7: deferred** as follow-ups (54-07; api.md; 54-04's validator). I agree with each.

### New findings

- n8 **The options merge reads the stored options outside the store's write lock** (`schedule_routes.py:322` and
  `:336`). `store.get` runs, then `_options` merges over `job.options`, then `store.update` takes `BEGIN IMMEDIATE`.
  Case: two PUTs at once, `{max_changed: 10}` and `{full_every_days: 3}` (two tabs, or one tab and the old
  `PUT /system/sync-settings`). Both read the same stored set, so the second write drops the first one's key. This is
  a lost update, not a validation hole: the merged set is always valid. With one user it is unlikely, and the
  `target` merge already follows the same read-then-write pattern. Fix, if wanted: pass the partial `options` to
  `ScheduleStore.update` and merge plus validate under its lock (L-091). A follow-up is enough.

### Not checked (re-run)

- The M1 and m1 mutations were not reproduced, because the reviewer cannot edit code. The test's assertions were read
  against the route code instead (above).
- As in round 1: live acceptance (54-10), the real Kiro model list, and `~/.genesis/genesis.db` (not opened).

### Verdict: SHIP

M1 has a test that fails when the regression-row lookup breaks. m1 and m2 are fixed with tests. Every gate is green at
`a6cc287`, and I reproduced each one. Two conditions remain: genesis-dev records m3's consumer list and the n3/n5/n7
(and n8) follow-ups in 54-06's As built.
