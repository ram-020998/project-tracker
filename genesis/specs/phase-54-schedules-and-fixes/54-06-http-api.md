# 54-06 — HTTP API: schedules, custom agents, notifications, chat agent, feature activity

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`genesis/api/`, `web/src/types/`, `web/src/lib/api/`). Parent:
> `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev**. Each backend sub-spec (54-04, 54-05, 54-08,
> 54-09) adds its routes; this sub-spec owns the contract table, the web types, the client functions, the golden
> fixtures and the removals (F7). All routes under `/api` (ADR-028); the client prepends `/api` centrally (L-010).

## 0. From 54-04's As built (read it: "For 54-05 / 54-06")

- **Wiring:** `app.state.scheduler`, `app.state.schedule_store`, `app.state.notifications`. Every `ScheduleStore` call
  is blocking: call it off the event loop (L-026).
- **Store calls the routes use:** `list(kind)`, `get(id)`, `get_by_key(job_key)`, `regression_for(app_uuid)`,
  `create_user(...)`, `update(id, ...)` (a system row accepts only schedule, enabled, options, policy), `delete_user`,
  `duplicate` (off, "<name> (copy)"), `reset_system(job_key)`, `set_pause(id, "user" | None)` (None resumes and clears
  the failure count), `history(id, limit, offset) -> (rows, total)`, `open_fire_for(id)`.
- **Engine:** Run now = `await scheduler.run_now(id) -> row_id` (the run id lands on the row once the handler starts
  it; the route answers the row id and the run id when known); preview = `next_runs(schedule, now, 5)`;
  `gate_cancel_at` = make `Scheduler._gate_cancel_at` public and use it for `last_run.gate_cancel_at` (§1 shape).
- **Errors → HTTP:** `ScheduleError` 400, `ScheduleNotFound` 404, `ScheduleForbidden` 403, `ScheduleConflict` 409.
  The 409 messages are fixed: "schedule is off", "a run of this schedule is still active", "another Genesis process on
  this machine runs the schedules", "this schedule has nothing to run in this build". Add the third to §1's run-now
  and pause rows.
- **History rows** (`schedule_runs`): `{id, schedule_id, slot ("YYYY-MM-DDTHH:MM" | "manual:<utc>Z"), outcome, run_id,
  execution_key, reason, started_at, finished_at, gate_opened_at, idle_since, idle_s}`; §1's `ScheduleRun` adds
  `duration_ms`, `idle_s` (D31) and credits from the run. A recovered stale row reads "interrupted before its result was
  recorded" (outcome `failed`, not counted toward failures). A red regression run is `failed` with a notice but not
  counted (D30); expose `counts_toward_pause: bool` on the row so the web can say so.
- **Notifications:** `NotificationStore(db).add/list/unread_count/mark_read(id) -> bool/mark_all_read() -> int`; source
  `schedules`; kinds `needs_you`, `failed`, `auto_paused`, `missed`; links `/runs/<id>` or `/schedules/<id>`.
- **Runs:** `RunRecord.trigger` is `{source:"schedule", schedule_id, slot}` or None; add it to `api/_shared.py`'s run
  dict (with `schedule_name` resolved, null if the schedule is gone).
- **Removals (§2), consumers known today:** `api/schedules.py` (3 routes and `_next_due`); `api/testing.py:101-104`
  (the setup's `schedule` key, replaced by the pointer); `testexec/regression_service.py` (`schedule_view`,
  `save_schedule`, `_cadence_of`, `get/set_schedule`, `SCHEDULE_NOTE`, `CADENCES`); `PUT …/testing/schedule`; the web
  callers. Re-grep before removing (L-094).

## 0b. From 54-05's As built (read it: "For 54-06 / 54-07 / 54-08")

- **Custom agents store** (`app.state.custom_agents`, `genesis.agents.CustomAgentStore`; blocking, call through
  `asyncio.to_thread`): `list()`, `get(id)`, `used_by(id)`, `create(data, *, models=None)`, `update(id, data, *,
  models=None)` (only the given fields; unknown fields 400), `delete(id)`; `to_dict()` = `{id, name, description,
  instructions, skills, mcp_servers: [{name, read_only_mark}], model, created_at, updated_at}`. Pass `models=` the ids
  from `ChatManager.available_models()["models"]` (None when the probe fails) only when the model changes (D35).
- **Errors → HTTP:** map `CustomAgentRefused` (422: server not pickable, skill not installed, unknown model, model list
  unavailable) **before** its parent `CustomAgentError` (400); `CustomAgentNotFound` 404; `CustomAgentConflict` 409
  (name taken, or in use with `.used_by`). A 422 can come from an unchanged field (a skill since uninstalled): the body
  names the blocking field so the web can show it.
- **Routes:** put the CRUD in `api/custom_agents.py` beside the existing Run route
  (`register_custom_agent_routes(api, *, agents, run_manager, registry)`); static paths before
  `/custom-agents/{agent_id}` (L-096). The Run route exists: `200 {run_id}`; 400 prompt empty or > 20 000; 404; 409
  `agent-prompt` not installed; 422 a server no longer pickable.
- **Schedule save with an agent (54-05 review n1):** `POST/PUT /schedules` with an `agent_prompt` target that names an
  `agent_id` must check the agent exists inside the same `BEGIN IMMEDIATE` as the write (L-091); today
  `ScheduleStore.create_user` checks only the type.
- **`GET /schedules/pickable` `servers`** = `pickable_servers(config.merged_mcp_registry())`: sorted `{name, tier:
  "curated" | "custom" | null, pickable, needs_read_only_mark, reason}`; validate picks with `check_picks(registry,
  picks)` → normalized picks or `NotPickableError(.refused=[{name, reason}])` (422 with the list). One home: D33.
- **`schedulable`:** `InstalledWorkflowInfo.schedulable` / `schedulable_of(meta)`; `/api/catalog` items already carry
  it; the file-input rule is `runtime.schedule_targets.file_inputs(meta, stored)` (use it for `pickable.workflows`).

## 0c. Decided during the build (D36–D39, `54-01-findings.md` §8)

- **D36:** `schedule_runs.counts_toward_pause` is added to the unreleased m0030 in place; the scheduler writes it, the
  history reads only it.
- **D37:** `POST /chat/sessions` gains `mode`; `agent_id` rules as D37; the `chat_sessions` snapshot column is added to
  m0030 in place; a valid read-only `agent_id` answers 409 until 54-08.
- **D38:** the 422 body, `ScheduleRefused`, model check, pause vs owner lock, run-now answer, pickable models/skills,
  `?limit=0` for the unread count, `ActivityItem` type only. Where §1's table differs (a separate unread-count route,
  the run-now answer), D38 wins.
- **D39:** `GET /schedules/{id}/sync-status` → `{collab_enabled, per_app[]}`, `per_app` items in today's
  `/system/sync-settings` shape (last sync kind, time, status, changed count, fallback reason, last full sync,
  published version); 404 for any schedule other than `application-sync`. Only the application-sync detail page calls
  it (D15, D25); `Schedule` keeps one shape for every row. Covered by the route-table test.
- **Both in-place m0030 edits** hold only while the fleet has not applied m0030 (D36's condition): before editing,
  re-check that neither fleet `genesis serve` restarted since 2026-11-18 18:48 (`ps -ww -eo pid,lstart,command`), read
  only.

## 1. Contract table

| Method + path | Body / query | Answer | Errors |
|---|---|---|---|
| `GET /schedules` | `?kind=system\|user`, `?state=active\|paused\|failing` | `{items: Schedule[]}` | |
| `GET /schedules/{id}` | | `Schedule` | 404 |
| `POST /schedules` | `{name, target, schedule, policy?, enabled?}` | `Schedule` (201) | 400 invalid schedule / target; 422 server not pickable (D3); 422 workflow not `schedulable` (D7) or has file inputs |
| `PUT /schedules/{id}` | user: any field; system: `schedule`, `enabled`, `options`, `policy` | `Schedule` | 400; 403 field not editable on a system row |
| `DELETE /schedules/{id}` | | 204 | 403 system row |
| `POST /schedules/{id}/run-now` | | `{run_id \| execution_key}` | 409 in flight; 409 not ready (reason); 409 schedule is off (D23) |
| `POST /schedules/{id}/pause` · `/resume` | | `Schedule` | 409 schedule is off (D23) |
| `POST /schedules/{id}/duplicate` | | `Schedule` (201, name "<name> (copy)", disabled) | 403 system row |
| `POST /schedules/{id}/reset` | | `Schedule` | 403 user row |
| `GET /schedules/{id}/history` | `?limit=50&offset=` | `{items: ScheduleRun[], total, credits_total: {credits, provenance}}` | |
| `GET /schedules/{id}/sync-status` | | `{collab_enabled, per_app: [...]}` (today's `/system/sync-settings` per-app shape, D39) | 404 for any schedule other than `application-sync` |
| `POST /schedules/preview` | `{schedule}` | `{next: string[5], summary: string, timezone}` | 400 |
| `GET /schedules/pickable` | | `{workflows: [{id, name, inputs_schema}], servers: [{name, tier, pickable, needs_read_only_mark, reason}], skills: [...], models: [...]}` | |
| `GET /custom-agents` · `GET /custom-agents/{id}` | | `CustomAgent[]` · `CustomAgent` (+ `used_by: [{schedule_id, name}]`) | 404 |
| `POST /custom-agents` · `PUT /custom-agents/{id}` | `{name, description?, instructions, skills, mcp_servers, model?}` | `CustomAgent` | 400; 409 name taken; 422 server not pickable / unknown skill |
| `DELETE /custom-agents/{id}` | | 204 | 409 in use (`used_by` in the body) |
| `POST /custom-agents/{id}/run` | `{prompt}` | `{run_id}` | 400 prompt empty or > 20 000; 404; 409 `agent-prompt` not installed (L-033); 422 server no longer pickable (built in 54-05) |
| `GET /notifications` | `?unread=true&limit=&offset=` | `{items: Notification[], unread: int}` | |
| `POST /notifications/{id}/read` · `POST /notifications/read-all` | | `{unread: int}` | 404 |
| `DELETE /notifications/{id}` (54-12, D50) | | 204 | 404 unknown; 409 unread |
| `POST /notifications/clear-read` (54-12, D50) | | `{removed: int, unread: int}` | |
| `POST /chat/sessions` (existing) | + `agent_id?` (read-only mode only, D6) | session (+ `agent: {id, name}`) | 422 `agent_id` with another mode |
| `GET /chat/sessions/{id}` (existing) | | + `agent: {id, name} \| null` | |
| the existing chat mode-change endpoint | | unchanged | 422 for a session with a custom agent (D26, 54-08 §1.1) |
| `GET /features/{id}/activity` (existing, extended, 54-09) | `?stage=&limit=&offset=` | `{items: ActivityItem[], total}` | |
| `GET /features/{id}` (existing, extended, 54-09, D45) | | + `summary: {stories, epics, test_cases, stories_with_open_questions, stories_not_on_board, last_activity_at}`; each stage row + `run_status` (also on every other read returning stage rows, L-039) | |
| `GET /catalog`, `GET /workflows/{id}` (existing) | | + `schedulable: bool` | |
| `GET /runs`, `GET /runs/{id}` (existing) | | + `trigger: {source, schedule_id, schedule_name \| null, slot} \| null` | |

Shapes (`web/src/types/schedules.ts`, `customAgents.ts`, `notifications.ts`, additions to `run.ts`, `chat.ts`,
`features.ts`):

- `Schedule {id, key?, kind, name, enabled, state: "active"|"paused"|"failing"|"completed", pause_reason, target,
  schedule, summary, cadence: {days: number[] | null, line: string}, timezone, next_runs: string[], last_run: {slot,
  outcome, reason?, run_id?, execution_key?, at, gate_cancel_at?} | null, policy, options?, failure_count, runs_count,
  editable_fields: string[]}`. `enabled` is the on/off switch and `state` the pause state, kept apart (D23).
  `cadence` feeds the list's weekday strip and short line (D22; `days` null for monthly and once); the backend builds
  it, the web does not compute it (L-109). `target` is the F1 union with `workflow_name`, `agent_name`, `app_name`
  added for display.
- `ScheduleRun {slot, outcome, reason?, run_id?, execution_key?, started_at?, finished_at?, duration_ms?, credits?,
  provenance?}`; credits only from the run's metered usage (ADR-032), never estimated.
- `CustomAgent {id, name, description, instructions, skills, mcp_servers: [{name, read_only_mark}], model, used_by,
  created_at, updated_at}`.
- `Notification {id, source, kind: "needs_you"|"failed"|"auto_paused"|"missed", title, body, link, created_at, read_at}`.
- `ActivityItem {type: "lifecycle"|"run"|"change_request"|"finalization", stage, action, from_state?, to_state?,
  label, actor?, at, link?}`. As built in 54-09: `stage` is the backend stage key (`spec`, `ux_design`,
  `technical_design`, `breakdown`, `test_design`); additive `cr_label?` on change_request items and `run_id?`,
  `run_status?` on run items.

## 2. Removals (F7, after 54-07 moves the web)

`GET/PUT /system/sync-settings`, `POST /system/sync-settings/run-now`, `GET /system/schedules`,
`PUT /applications/{uuid}/testing/schedule` (and the `schedule` part of the testing setup GET, replaced by a
`schedule: {id, summary, next_run} | null` pointer to the app's regression row). Before removing, list every consumer
(web callers and hooks, copilot tool definitions, scripts in `genesis/scripts/`, tests, fleet `gsm`) in As built
(L-094). Static routes such as `/schedules/preview` and `/schedules/pickable` are registered before
`/schedules/{id}` and the order is proven by a test (L-096).

## 3. Fixtures and tests

Golden JSON fixtures for each new shape from real responses of a test app (L-011, L-083); web tests parse them through
the same client functions the pages use (L-109). Backend route tests for every row of §1, including each error.

## 3a. Carried from 54-02's As built (this sub-spec owns the web contract)

1. **Event kinds drift:** `agent.prompt` is canonical in the backend (`_CANONICAL_CUSTOM`) but missing from the web
   `CANONICAL_EVENT_KINDS` and `EVENT_FIXTURES` (`web/src/test/fixtures/events.ts`). Add it; the contract test must
   fail on any kind present in one list only (L-011).
2. **Capture type:** `Capture["proposals"]` requires a `proposals` list, but a failed capture stores `{error}` only.
   Make the type a union of the real stored shapes and drop the test cast (`failedProposals` in the O1 test).
3. A state edit is logged as kind `custom` with `data.type: "state.edited"` (54-02 decision 1); 54-06 adds no event
   kind for it.
4. Environment routes as built in 54-02: `DELETE /config/environments/{label:path}`, `POST /config/environments/dev
   {label, is_dev}`; the old `…/{label}/dev` is gone. Unmatched `/api/*` → 404 JSON for every method; a real route
   with the wrong method → 405 (so `GET /config/environments/<x>` is 405). New routes in §1 must keep the catch-all's
   behaviour: add a route-table test for `/schedules/*`, `/custom-agents/*`, `/notifications/*`.

## 4. Gates

`cd genesis && .venv/bin/python -m pytest -q -p no:warnings`, `ruff check genesis`; web `npm run lint && npm run
typecheck && npm test`.

## As built

**Status:** BUILT 2026-11-19, review **SHIP** (re-run 1). Repo genesis, branch master, base `9f63fc2`, head
`a6cc287`, 3 local commits (not pushed, not tagged). Source, tests and fixtures: 61 files, +3013/−122. `web/static`:
64 files in its own commit. m0030 was edited in place (D36, D37); DB stays **v30**. The §2 removals were not done
(54-07 does them).

### Commits (genesis)

| sha | what |
|---|---|
| `9895cdb` | the contract: `/schedules*`, `/custom-agents` CRUD, `/notifications*`, chat `mode`/`agent_id`, runs `trigger`, `schedulable`; the m0030 in-place columns; `ScheduleRefused`; the n1 lock check; §3a; web types, client functions, fixtures, tests |
| `ab9a13e` | `web/static` build for `9895cdb` (64 files; `git show --stat ab9a13e -- web/static` after the build settled; a later rebuild left `git status --short --untracked-files=all` empty) |
| `a6cc287` | review round 1: M1 test, m1, m2, n1, n2, n4, n6 (web change is type-only; a rebuild left the tree clean, so `ab9a13e` is still the bundle) |

### Changed

- **m0030 in place** (D36, D37). Before the edit, `ps -ww -eo pid,lstart,command` showed main started 2026-11-18 16:32:16
  and userb 2026-11-15 03:33:19, both before `41d4d0e`. The reviewer re-checked this twice.
  - `schedule_runs.counts_toward_pause INTEGER`. `ScheduleStore.close_fire` writes 1 or 0 on a `failed` row and NULL
    for any other outcome. `_run_dict` reads it as `bool | None`.
  - `chat_sessions.agent_json TEXT` (NULL everywhere). `ChatSessionRecord.agent` reads it; nothing writes it yet.
- **`runtime/schedule_model.py`**: `describe(schedule) -> {summary, cadence: {days, line}}` and `run_days`. The wording
  follows the 54-03 mockup ("Every 4 hours, 08:00–20:00, weekdays", "Weekly on Sunday at 03:00", "Monthly · day 1 ·
  07:00"). An interval window drops its hours from the text only when it covers the whole day evenly (review m1).
- **`runtime/schedule_store.py`**:
  - `ScheduleRefused(ScheduleError)` with `.field` and `.refused`.
  - `_agent_exists` runs inside the write's own `BEGIN IMMEDIATE` in `create_user` (which now starts with
    `BEGIN IMMEDIATE`) and in `update` (n1, L-091).
  - `last_runs()` reads in one grouped query. `names(ids)` resolves run triggers.
- **`runtime/scheduler.py`**: `gate_cancel_at` is public.
- **`runtime/sync_jobs.py`**: `validate_sync_options` moved here from `api/schedules.py`, so both PUTs share one home.
- **`runs/manager.py`**: `RUN_STARTED` and `CANONICAL_KINDS` (the kinds `_log` writes plus `_CANONICAL_CUSTOM`;
  `custom` is not canonical).
- **`api/schedule_routes.py`** (new): the 14 `/schedules*` routes of §1 plus D39's `sync-status`.
  - Static `preview` and `pickable` are registered first, and the id routes use `{schedule_id:int}`.
  - Errors map as in §0 and D38 a: 422 `{detail, field, refused?}`; 400, 403, 404 and 409 as `{detail}`.
  - Target checks run before the write:
    - workflow: not installed, not schedulable, or needs a file input → 422 (`target.workflow_id` /
      `target.inputs`); `validate_inputs` failing → 400;
    - agent prompt: a skill not installed → 422 `target.skills`; a server refused by `check_picks` → 422
      `target.mcp_servers` with `refused`; a changed model follows D35 → `target.model`;
    - regression: an app that is not tracked → 422 `target.app_uuid`.
  - A system row's `options` merge over the stored ones. A non-object is 400 (review m2).
  - `app_sync_per_app` and `collab_enabled` are shared with the old `/system/sync-settings` GET.
- **`api/notifications.py`** (new): list, `limit=0` returning the count only, `read-all`, and `{id:int}/read` (404).
- **`api/custom_agents.py`**: the CRUD beside the 54-05 Run route.
  - `CustomAgentRefused` now carries `.field` (`skills` | `mcp_servers` | `model`) and `.refused`, and is mapped
    before its parent.
  - A delete conflict returns 409 `{detail, used_by}`.
  - The list fills `used_by` in one query (`CustomAgentStore.used_by_map`, L-039).
  - The model list is read only when the model changes.
  - The Run route is unchanged except for `{agent_id:int}`.
- **`api/_shared.py`**:
  - `_record(rec, schedule_names)` adds `trigger` (`schedule_name` is null once the schedule is deleted).
  - `schedule_ids_of` collects the ids to resolve.
  - `kiro_models(chat)` is the one reader of Kiro's model list (review n1).
- **`api/run_routes.py`**: list, get, pause and cancel carry `trigger`; names are resolved per page in one query.
  `register_run_routes(..., schedule_names=)`.
- **`api/catalog_routes.py`**: `GET /workflows/{id}` always carries `schedulable` (`schedulable_of`).
- **`api/chat.py`** (D37, D26):
  - `CreateSession.mode` accepts `read_only` | `copilot`; anything else is 422 `mode`.
  - `agent_id` with copilot is 422 `agent_id`. An unknown agent is 422. A valid one is **409 "custom agents in chat
    are not available in this build yet"** and nothing is stored.
  - Creating a copilot session honours the kill-switch (400).
  - The answer is the session dict plus `agent`.
  - The mode route returns 422 `mode` for a session with an agent.
  - `register_chat_routes(..., custom_agents=getter)`, because the store is built after the chat routes in
    `create_app`.
- **`api/app.py`**: wires the three new route modules and the getter.
- **Web types**:
  - `types/schedules.ts` (new): `Schedule`, `ScheduleTarget` and `ScheduleTargetInput`, `ScheduleRun`,
    `ScheduleHistory`, `SchedulePreview`, `SchedulePickable` (and its items), `ScheduleSyncStatus`/`AppSyncStatus`,
    `RunNowResponse`, `FieldRefusal`.
  - `types/customAgents.ts` and `types/notifications.ts` (new).
  - `run.ts`: `RunTrigger`.
  - `chat.ts`: `agent`, `ChatSessionAgent`, `CreateChatSession`.
  - `features.ts`: `ActivityItem` and `FeatureActivityPage`, type only (D38 g).
  - `catalog.ts`: comments.
  - `testing.ts`: `CaptureProposals = RecordingResult | ComposeResult | CaptureFailure | null` (§3a.2).
- **Web client**:
  - `lib/api/schedules.ts` (`schedulesApi`, `fieldRefusalOf`), `customAgents.ts` (`customAgentsApi`, `inUseOf`) and
    `notifications.ts` (`notificationsApi`), all exported from `lib/api/index.ts`.
  - `chatApi.createSession(title, model, {mode, agent_id})` now returns `ChatSession`.
  - `features/testing/logic.ts`: `captureProposalsOf` and `captureErrorOf`. `CapturesPanel.tsx` uses them, and
    `composeResultOf` narrows without a cast.
- **§3a.1**:
  - `agent.prompt` is in `CANONICAL_EVENT_KINDS` and `EVENT_FIXTURES`. Its payload is the real `kiro_node` shape:
    `{prompt_ref, model, mcp, tools, image_docs, iteration, attempt}`.
  - `contract.test.ts` fails when a kind is in only one of three lists: `CANONICAL_EVENT_KINDS`, the fixtures' kinds,
    and `events/canonical-kinds.json` (written from `CANONICAL_KINDS`).

### Tests

- `tests/test_schedules_api.py` (new, 38 tests) covers every row of §1 and each of its errors:
  - `describe` (13 cases);
  - list, get and filters (L-039: a list item equals the get);
  - create refusals with their `field`;
  - display names;
  - the D35 model rule;
  - user and system updates (403, options merge, 400s);
  - delete, duplicate, reset, pause and resume (D23: 409 "schedule is off");
  - run now: the answer, 409 while in flight or off, 404, and the owner-lock 409;
  - history: `duration_ms`, `idle_s`, `counts_toward_pause`, metered credits with provenance, `credits_total`, paging,
    404;
  - a regression row's credits through its `TE-` run (review M1);
  - `last_run.gate_cancel_at`;
  - preview and pickable (models null when unavailable);
  - sync-status, plus parity with the old GET (D39);
  - n1: the agent is deleted between the route checks and the write;
  - the custom-agents CRUD, `used_by`, 409/422/400/404, an unchanged field that now blocks, and the model rule;
  - notifications (`limit=0`, unread filter, 404, read-all);
  - runs `trigger` with the name, and null after the schedule is deleted;
  - `schedulable` on workflows;
  - chat: create with mode and agent (422/409/400), and an agent session refusing a mode change;
  - the canonical-kinds file;
  - the route table: no phase-54 route is shadowed (23 routes, statics before `{id}`), plus behaviour checks for the
    statics and the 54-02 catch-all (404 for unmatched paths and 405 for a wrong method, under `/schedules`,
    `/custom-agents` and `/notifications`).
- Extended:
  - `test_scheduler.py`: D36 values for a red regression run and for a recovered "interrupted" row. A fixture agent
    row was added for n1.
  - `test_schedule_migration.py`: the two new columns.
  - `test_chat_store.py`: `agent_json` is NULL on old rows.
  - The Phase 53 chat fixtures `session-steered` and `session-stopped` were re-recorded (they gain `agent`).
- **Golden fixtures** were written from real responses (`GENESIS_WRITE_CONTRACT_FIXTURES=1`, L-011, L-083):
  - `schedules/` (10 files): `schedule-list`, `-refused`, `-agent-prompt`, `-regression`, `-run-now`, `-history`,
    `-gate-waiting`, `-preview`, `-pickable`, `-sync-status`;
  - `agents/`: `agent-list`, `agent-in-use`, `agent-refused`;
  - `notifications/notification-list`, `runs/run-scheduled`, `chat/session-created`, `events/canonical-kinds`.
- **Web** `test/fixtures/phase54-contract.test.ts` (new, 7 tests): MSW serves each fixture at its exact method and path
  (`onUnhandledRequest: "error"`). The fixture is parsed through the client function the pages will use (L-109) and
  checked with `Exact<T>` key lists.
- Web tests extended:
  - `contract.test.ts`: kind parity, and `agent.prompt` is not rendered by `buildTranscript`.
  - `logic.test.ts`: every `CaptureProposals` arm.
  - `library.test.tsx`: the cast is dropped.
  - `phase53-contract.test.ts`: `agent` added to the session keys.
- **Mutation evidence.** Each of these made its tests fail:
  - `_agent_exists` removed (2 tests);
  - `counts_toward_pause` always NULL (3);
  - `agent.prompt` removed from the web list (1);
  - the execution lookup replaced with `rid = None` (M1 test);
  - `_whole_day` without the divisor check (2).
- **Gates at `a6cc287`:**
  - `.venv/bin/python -m pytest -q -p no:warnings`: **2077 passed**, 15:46–15:57 IST, outside the 00:00–02:00 D27
    window, nothing deselected. At `9895cdb` it was 2073 (15:03–15:14 IST). The reviewer re-ran both.
  - `.venv/bin/ruff check genesis`: clean.
  - Web: `npm run lint` 0 errors (20 warnings, all pre-existing, none in changed files), `npm run typecheck` clean,
    `npm test` **816 passed** in 70 files.
  - genesis-core and the other packages were not touched.

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-06-review.md`.
- **Round 1 (`ab9a13e`), NEEDS_CHANGES.**
  - M1: a regression row's credits branch was untested.
  - m1: `describe` gave "Every N hours" for an uneven window.
  - m2: a PUT of `options` reset unspecified options, and accepted a non-object.
  - m3: the §2 list was missing entries.
  - Nits n1–n7.
- **Re-run 1 (`a6cc287`), SHIP.** M1, m1, m2, n1, n2, n4 and n6 are fixed with tests; m3 is the list below.
  - Deferred, with the reviewer's agreement: n3, n5, n7, and the new nit n8 (see Follow-ups).
  - The reviewer found all six of my choices OK.

### Decisions / deviations

No ADR deviation. Decided by the user in this session: **D36** (`counts_toward_pause` in m0030 in place), **D37**
(chat `mode`/`agent_id`, the snapshot column, 409 until 54-08), **D38** (a)–(g) and **D39** (`sync-status`).
Recorded in 54-01 §8 and 54-06 §0c.

Mine:
1. **`{id:int}` path convertors** on every new id route and on the Run route. A non-int id falls to the catch-all
   (404), and a wrong method on a static path is 405 rather than an int-validation 422.
2. **`POST /custom-agents` answers 200** (§1's table gives no 201; `POST /schedules` and `/duplicate` answer 201).
3. **`counts_toward_pause` is null** for every outcome other than `failed`.
4. **Schedule history credits:** a row's run is its `run_id`, or else its `TE-` execution's `run_id`. `credits_total`
   covers **this page's rows only** (`limit` ≤ 200; review n6; 54-07 labels it so). A row with no run has
   `credits: null, provenance: null`.
5. **Run now** answers `{row_id, run_id, execution_key}` with the ids from the open row at that moment, usually null
   (D38 d).
6. **Validation beyond §1:**
   - a workflow target's inputs go through `validate_inputs` (400);
   - a regression target's app must be tracked (422);
   - `kind` and `state` filters outside their sets are 400;
   - create bodies with unknown fields are 400 (the bodies are `dict`, so every invalid value is the route's 400,
     never a FastAPI 422 without `field`).
7. **Options** on a system row merge over the stored ones (review m2). For non-app-sync rows the store only checks
   that the result is an object.
8. **`Schedule.key` and `options`** are present on system rows only. `target` is null on system rows.
9. **`ActivityItem`** in `types/features.ts` uses the spec's name; `lib/api/metrics.ts` has an older `ActivityItem`,
   which 54-09 retires.
10. **The web's `ChatSession.agent` is optional**, like `mode`, so the existing stubs still compile. The contract test
    requires it on real responses.
11. **The 54-05 Run route and the runs/chat sync routes stay `def`** (threadpool). Every new async route runs its
    blocking calls through `asyncio.to_thread` (L-026).

### §2 consumer list — what 54-07 must change when it removes the old routes (L-094; re-grepped at `a6cc287`)

Grep: `git grep -nE 'sync-settings|system/schedules|testing/schedule|getSyncSettings|putSyncSettings|runSyncNow|
syncSettings|saveSchedule|ScheduleSection|update_settings'` in genesis, plus the fleet and genesis-workflows.

- **Routes and backend:**
  - `genesis/api/schedules.py`: `GET /system/schedules`, `GET/PUT /system/sync-settings`,
    `POST /system/sync-settings/run-now`, `_next_due`, `SyncSettingsBody`, `APP_SYNC_JOB`. It imports
    `validate_sync_options` (keep it, in `sync_jobs`) and `app_sync_per_app`/`collab_enabled` (keep them, in
    `schedule_routes`).
  - `genesis/api/app.py:316-317`: `register_schedules_routes(...)`.
  - `genesis/runtime/schedule_store.py`: `ScheduleStore.update_settings` (only that PUT uses it).
  - `genesis/api/testing.py:455`: `PUT /applications/{uuid}/testing/schedule`, and the setup GET's `schedule` key
    (`:104`). The key becomes the pointer `schedule: {id, summary, next_run} | null`, read through
    `ScheduleStore.regression_for` and `describe`/`next_runs`.
  - `genesis/testexec/regression_service.py`: `schedule_view`, `save_schedule`, `_cadence_of`, `get/set_schedule`,
    `SCHEDULE_NOTE`, `CADENCES`.
  - `genesis/runtime/sync_jobs.py:7`: a docstring that names the old PUT.
- **Web:**
  - `lib/api/system.ts:24,81-83`: the `SyncSettings` types, `getSyncSettings`, `putSyncSettings`, `runSyncNow`.
  - `lib/query/keys.ts:22`: `qk.config.syncSettings`.
  - `features/settings/hooks.ts:433-455`: `useSyncSettings`, `useSaveSyncSettings`, `useRunSyncNow`.
  - `features/settings/components/ApplicationSyncSection.tsx` and its `syncSchedule.ts` (`windowSlots`), and its mount
    in `SettingsPage.tsx`.
  - `lib/api/testing.ts:64`: `saveSchedule`.
  - `features/testing/setup/ScheduleSection.tsx`, mounted in `SetupView.tsx:7,52`.
  - `types/testing.ts`: `RegressionSchedule` and `ScheduleCadence`, which clashes by name with
    `types/schedules.ts`'s `ScheduleCadence` (review n3), and the two `schedule: RegressionSchedule` fields
    (`:105`, `:547`).
  - `features/testing/contract.test.ts:18,58-61,142,217`: the `SCHEDULE` keys and the setup's `schedule`.
- **Tests and fixtures:**
  - `tests/test_sync_jobs.py:190-317`: `/system/schedules`, sync-settings GET/PUT/run-now and `per_app`.
  - `tests/test_testexec_regression.py:687-689`: `PUT …/testing/schedule`.
  - `tests/test_testing_api.py:701`: records `web/src/test/fixtures/testing/schedule.json` through that PUT. The
    fixture is imported by `features/testing/setup.test.tsx:15`, and `setup.test.tsx:215` mocks the PUT.
  - `tests/test_scheduler.py:220`: `update_settings`.
  - `tests/test_schedules_api.py` (new here): the D39 parity check calls `GET /api/system/sync-settings`. Drop that
    line with the route.
  - `features/settings/settings.test.tsx:179-188,531,547`: MSW handlers for the three sync-settings routes.
- **Replacement map for 54-07:**
  - the sync-settings GET's `per_app` and `collab_enabled` → `GET /schedules/{id}/sync-status` (D39);
  - `running` → `last_run.outcome == "fired"`;
  - `enabled`, `schedule`, `options`, `user_modified`, `last_run_*` and `next_due` → `GET /schedules/{id}`
    (`options`, `last_run`, `next_runs[0]`);
  - the PUT → `PUT /schedules/{id}` with `{schedule, enabled, options}`;
  - run-now → `POST /schedules/{id}/run-now`;
  - `/system/schedules` → `GET /schedules?kind=system`;
  - the regression PUT → `POST/PUT /schedules` with a `regression` target.
- **Checked, nothing to change:**
  - The copilot control MCP (`genesis/mcp/control_server.py`) has no schedule tool. `get_run_status` and
    `get_workflow_inputs_schema` read named fields only, so they get `trigger` and `schedulable` additively.
  - `genesis/scripts`: no caller. `scripts/probes/phase54-mockups.mjs` drives only the `/dev/phase-54` mockup.
  - Fleet `gsm` (`genesis-fleet/bin/gsm`): no caller.
  - genesis-workflows: no caller.
- **Docs, for genesis-docs:** `docs/architecture/modules/api.md:475,539`, `knowledge-base.md:532,573,762`,
  `scheduler-and-jobs.md:429-439,526-552,654,683`, `testing.md:753`, `web-app.md:142`. `api.md` also needs the new
  routes, plus the review n5 note that FastAPI's own 422s carry no `field`.

### For 54-07 / 54-08 / 54-09

- **Client functions** (`@/lib/api`):
  - `schedulesApi.{list({kind,state}), get, create, update, remove, runNow, pause, resume, duplicate, reset,
    history(id,{limit,offset}), preview(schedule), pickable, syncStatus}`;
  - `fieldRefusalOf(e)`: `{detail, field, refused?}` or null; show `detail` on `field`;
  - `customAgentsApi.{list, get, create, update, remove, run}` and `inUseOf(e)`: `{detail, used_by}` or null;
  - `notificationsApi.{list({unread,limit,offset}), unreadCount, markRead, markAllRead}`;
  - `chatApi.createSession(title, model, {mode, agent_id})` returns `ChatSession`.
- **Hooks to build** (none exist yet; query keys go in `lib/query/keys.ts`):
  - 54-07: `useSchedules`, `useSchedule`, `useScheduleHistory`, `useSchedulePreview` (debounced while editing),
    `usePickable`, `useSyncStatus`, the schedule mutations, `useCustomAgents` and its mutations, `useNotifications`
    and `useUnreadCount` (poll `unreadCount`), `useMarkRead`.
  - Invalidate the schedule after Run now. Its run link appears once the handler sets it (D38 d).
- **Fixtures to reuse in page tests:** `schedules/*`, `agents/*`, `notifications/notification-list`,
  `runs/run-scheduled` (F10 badge), `chat/session-created`.
- **Field names a 422 can carry:**
  - schedules: `target.workflow_id`, `target.inputs`, `target.agent_id`, `target.skills`, `target.mcp_servers`
    (+ `refused`), `target.model`, `target.app_uuid`;
  - custom agents: `skills`, `mcp_servers` (+ `refused`), `model`;
  - chat: `mode`, `agent_id`.
- **54-07 must also:**
  - label `credits_total` as the total of the shown runs;
  - show `counts_toward_pause: false` as "doesn't count toward auto-pause";
  - show `idle_s` beside the duration;
  - compare time zones after canonicalising through `Intl` (54-03 decision 11);
  - for system rows, edit only `editable_fields`. PUT `options` sends only the changed keys; the server merges them.
- **54-08 still owes (D37):**
  - store the snapshot (`custom_agents.snapshot`) in `chat_sessions.agent_json` on `POST /chat/sessions` and remove the
    409 (`api/chat.py` `CHAT_AGENT_NOT_BUILT`; the test `test_chat_session_create_with_mode_and_agent` asserts it and
    must change);
  - build the projection: instructions after the read-only prompt, skills, servers through `check_picks`, the model;
  - rebuild it on resume.
  
  Already built: `ChatSessionRecord.agent`, `agent` in every session answer, and the D26 422 on mode change. The web
  hides Copilot when `session.agent` is set.
- **54-09:** extend `GET /features/{id}/activity` to `{items: ActivityItem[], total}` (`types/features.ts`), and
  retire `lib/api/metrics.ts`'s `ActivityItem` and `FeatureActivity` with their callers (`cr-flow.ts`,
  `ActivityFeed.tsx`, `features/hooks.ts`).

### Follow-ups (not fixed)

- **Review n8:** `PUT /schedules/{id}` merges `options` (and the old target's model, for D35) from a read made before
  the store's write lock. Two concurrent saves of different option keys can drop one of them. The merged set is
  always valid. The fix is to merge and validate inside `ScheduleStore.update` under `BEGIN IMMEDIATE` (L-091).
- **Review n7:** 54-04's `validate_schedule` accepts a schedule with no effective day (`days: [5]` +
  `weekdays_only`), which reads "Weekly on no day at 09:00".
- **Review n3:** the duplicate `ScheduleCadence` name; it goes with `RegressionSchedule` in 54-07.
- **Review n5:** api.md should say that FastAPI's own validation 422s carry no `field`.
- **D14 "one row per app":** nothing stops a second regression schedule for the same app. `regression_for` returns
  the oldest. The spec does not say to refuse it.
- **Live acceptance (54-10):** none of this ran against a real Kiro model list, a browser or the fleet.

### Lesson candidates

1. **Give a list contract test the backend's own list.** `agent.prompt` was canonical in the backend for a phase,
   but the web's list and fixtures never had it, and "one fixture per listed kind" could not see a kind missing from
   both. Write the backend set to a fixture and compare all three lists in both directions (L-011).
2. **A decision the engine makes at close time must be stored with the row if a reader shows it.** `counts` was only
   an argument to `close_fire`. Deriving it later from reason text and TE status would have been a second reader of
   the rule (D36, L-109).
3. **A partial-update route over a validator that starts from defaults resets every field it leaves out.**
   `validate_sync_options` was written for a PUT that always sent the whole set; reused for a partial PUT, it reset
   the other options to their defaults (review m2). Merge over the stored value, inside the write lock (n8).
4. **Use typed path convertors (`{id:int}`) for id routes beside static siblings.** The route then cannot match
   `preview`, so ordering no longer decides correctness, and a wrong method on the static path is an honest 405
   (L-096).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/api/schedule_routes.py` (new): `register_schedule_routes`, `app_sync_per_app`, `collab_enabled`,
  `USER_EDITABLE`.
- `genesis/api/notifications.py` (new): `register_notification_routes`.
- `genesis/api/custom_agents.py`: the CRUD; `register_custom_agent_routes(..., chat=)`.
- `genesis/api/_shared.py`: `_record(rec, schedule_names)`, `schedule_ids_of`, `kiro_models`.
- `genesis/api/run_routes.py`: `register_run_routes(..., schedule_names=)`.
- `genesis/api/chat.py`: `CreateSession.mode`/`agent_id`, `CHAT_AGENT_NOT_BUILT`, `_session_agent`,
  `register_chat_routes(..., custom_agents=)`.
- `genesis/api/catalog_routes.py`: `schedulable` on `/workflows/{id}`.
- `genesis/runtime/schedule_model.py`: `describe`, `run_days`.
- `genesis/runtime/schedule_store.py`: `ScheduleRefused`, `_agent_exists`, `last_runs`, `names`; `close_fire` writes
  `counts_toward_pause`.
- `genesis/runtime/scheduler.py`: `gate_cancel_at` is public.
- `genesis/runtime/sync_jobs.py`: `validate_sync_options` (moved here).
- `genesis/runs/manager.py`: `RUN_STARTED`, `CANONICAL_KINDS`.
- `genesis/agents/store.py`: `CustomAgentRefused(field=, refused=)`, `used_by_map`.
- `genesis/chat/store.py`: `ChatSessionRecord.agent`.
- `genesis/db/migrations/m0030_schedules.py`: `schedule_runs.counts_toward_pause` and `chat_sessions.agent_json`
  (still v30).
- Web: `types/{schedules,customAgents,notifications}.ts`, `lib/api/{schedules,customAgents,notifications}.ts`,
  `test/fixtures/phase54-contract.test.ts`, and fixture folders `schedules/`, `agents/`, `notifications/`, `runs/`,
  `events/`.

## Context manifest

```toml
areas    = ["api", "runs-worker", "chat", "web-shell"]
adrs     = ["ADR-028", "ADR-032", "ADR-047", "ADR-031"]
lessons  = ["L-010", "L-011", "L-039", "L-083", "L-094", "L-096", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/genesis/api/**", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
upstream = ["54-02", "54-03", "54-04", "54-05"]
```
