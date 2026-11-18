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
| `POST /schedules/preview` | `{schedule}` | `{next: string[5], summary: string, timezone}` | 400 |
| `GET /schedules/pickable` | | `{workflows: [{id, name, inputs_schema}], servers: [{name, tier, pickable, reason?}], skills: [...], models: [...]}` | |
| `GET /custom-agents` · `GET /custom-agents/{id}` | | `CustomAgent[]` · `CustomAgent` (+ `used_by: [{schedule_id, name}]`) | 404 |
| `POST /custom-agents` · `PUT /custom-agents/{id}` | `{name, description?, instructions, skills, mcp_servers, model?}` | `CustomAgent` | 400; 409 name taken; 422 server not pickable / unknown skill |
| `DELETE /custom-agents/{id}` | | 204 | 409 in use (`used_by` in the body) |
| `POST /custom-agents/{id}/run` | `{prompt}` | `{run_id}` | 409 `agent-prompt` not installed (L-033) |
| `GET /notifications` | `?unread=true&limit=&offset=` | `{items: Notification[], unread: int}` | |
| `POST /notifications/{id}/read` · `POST /notifications/read-all` | | `{unread: int}` | 404 |
| `POST /chat/sessions` (existing) | + `agent_id?` (read-only mode only, D6) | session (+ `agent: {id, name}`) | 422 `agent_id` with another mode |
| `GET /chat/sessions/{id}` (existing) | | + `agent: {id, name} \| null` | |
| the existing chat mode-change endpoint | | unchanged | 422 for a session with a custom agent (D26, 54-08 §1.1) |
| `GET /features/{id}/activity` (existing, extended, 54-09) | `?stage=&limit=&offset=` | `{items: ActivityItem[], total}` | |
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
  label, actor?, at, link?}`.

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

_(genesis-dev fills in: commits, the consumer list for §2, tests, review verdict, decisions/deviations, Resume note.)_

## Context manifest

```toml
areas    = ["api", "runs-worker", "chat", "web-shell"]
adrs     = ["ADR-028", "ADR-032", "ADR-047", "ADR-031"]
lessons  = ["L-010", "L-011", "L-039", "L-083", "L-094", "L-096", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/genesis/api/**", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
upstream = ["54-02", "54-03", "54-04", "54-05"]
```
