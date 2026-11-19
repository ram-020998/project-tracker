# 54-07 — Web: Schedules page, Catalog → Agents, notification bell, moves out of Settings and Testing

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`web/`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built
> by **genesis-dev** after the 54-03 mockups are approved; **the approved mockup is the layout** (read 54-03's As built
> and any decisions it added to 54-01 §8 first). Contract: 54-06.

## 0. From 54-06's As built (read it first: "§2 consumer list" and "For 54-07 / 54-08 / 54-09")

- **Removals (F7):** 54-07 removes the old routes. Work from 54-06's re-grepped consumer list and its replacement map
  (backend routes and store methods, web clients, hooks and components, tests and fixtures); re-grep before each
  removal (L-094). Keep `validate_sync_options`, `app_sync_per_app` and `collab_enabled`; the testing setup GET's
  `schedule` key becomes the pointer `{id, summary, next_run} | null`.
- **Client functions** (`schedulesApi`, `customAgentsApi`, `notificationsApi`, `fieldRefusalOf`, `inUseOf`), the 16
  golden fixtures and the 422 field names are listed in 54-06's As built; write the TanStack Query hooks over them.
- **Backend follow-ups from 54-06's review, fixed here** (each with a fail-first test):
  1. **n8:** `PUT /schedules/{id}` merges `options` (and the old target's model, D35) from a read taken before the
     store's write lock, so two concurrent saves of different keys can drop one. Merge and validate inside
     `ScheduleStore.update` under `BEGIN IMMEDIATE` (L-091).
  2. **n7:** `validate_schedule` accepts a schedule with no effective day (e.g. `days: [5]` + `weekdays_only`, "Weekly
     on no day at 09:00"); refuse it (400 / the D38 422 on `schedule`).
  3. **D40:** a second regression schedule for an app that already has one is refused (409 naming the existing
     schedule); the Testing → Setup link opens the existing one.
  4. **n3:** remove the old `ScheduleCadence` / `RegressionSchedule` from `types/testing.ts` with the testing schedule
     editor, leaving one `ScheduleCadence` (`types/schedules.ts`).

## 1. Navigation and routes

- `PRIMARY_NAV` (`web/src/shared/layout/nav.ts:15-23`): add **Schedules** (`/schedules`, a clock/calendar icon from
  `shared/ui/icons.ts`) after Runs; the command palette picks it up (`CommandPalette.tsx:59`).
- Routes (`web/src/app/router.tsx`): `/schedules`, `/schedules/new`, `/schedules/:id`, `/schedules/:id/edit`,
  `/catalog/agents` (static, registered before `catalog/:workflowId`, as `catalog/skills` is at `:69-70`), and the
  breadcrumbs for each (`shared/layout/breadcrumbs.ts`).

## 2. Schedules page (`web/src/features/schedules/`, new)

The layout is the approved mockup (`web/src/dev/mockups/phase54/schedules.tsx`, genesis `b09b08e`; D22–D25, D28):
build the real page from it and its shared pieces (`SectionCard`, `DefinitionList`, `StatusHeader`, `MultiSelect` in
`shared/ui`), not from 54-03 §2's starting text. In short:
- **List (D22):** no Target column; Frequency = weekday strip + short line from `cadence` (54-06), a calendar icon for
  monthly and once; zone only when it differs from the machine's; Last result = status tag linking to the run or
  `TE-` execution, tooltip with time, reason and a gate's cancel time; lock icon on system rows and the line "System
  schedules can't be deleted. You can change when they run or turn them off."
- **Switch and menu (D23):** the switch writes `enabled` only; Pause / Resume, Run now, Duplicate, Delete or Reset to
  default are in the row menu; Run now and Pause/Resume are disabled while a schedule is off.
- **Row menu:** add a shared menu primitive in `shared/ui` (over `@radix-ui/react-dropdown-menu`, already a
  dependency) and use it here; the mockup's `RowMenu` is dev-only (54-03 decision 4).
- **New / edit (D24):** a full page (`/schedules/new`, `/schedules/:id/edit`) with the step rail and running summary;
  skills and servers through `MultiSelect`; a picked custom agent's skills and servers as locked chips "from <agent>".
- **Application-sync detail (D25, D39):** options shown as text with an Edit button; the per-app last sync and
  `collab_enabled` come from `GET /schedules/{id}/sync-status`.
- **Time fields (D29):** a new shared `TimeInput` in `shared/ui` (24-hour `HH:MM` whatever the locale; hour and minute
  fields, typed digits and arrow keys, a label per field) replaces every native `type="time"`; jest-axe and a userEvent
  keyboard test.

Rules:
- the frequency summary and next runs come from the backend (`summary`, `next_runs`, `POST /schedules/preview` while
  editing); the web never computes slots (one home, L-109; `settings/components/syncSchedule.ts` is removed with its
  card);
- the workflow step reuses `buildLaunchForm` (`features/catalog/launch-schema.ts:38`) and `LaunchForm` widgets; file
  widgets are not offered (54-05 §5);
- servers, skills, models and workflows come from `GET /schedules/pickable`; a non-pickable server is shown disabled
  with its `reason` (D3); a server with `needs_read_only_mark` needs the "this server only reads" checkbox before it
  counts;
- a 422 on save names the blocking field (it can be an unchanged one, such as a skill since uninstalled or a server
  since removed, 54-05 review n3); show it on that field, in the schedule wizard and the agent editor;
- system rows show only their editable fields (`editable_fields`), no Delete, a **Reset to default**;
- the `application-sync` detail holds everything today's `ApplicationSyncSection.tsx` shows (D15), then that component
  and its mount in `SettingsPage.tsx:68` are removed;
- history shows outcome pills (including `missed` and `skipped` with the reason), run links, duration, credits with
  provenance (ADR-032) and the total; a row that does not count toward auto-pause (`counts_toward_pause: false`: a red
  regression run, D30, or an "interrupted" recovered row) says so; a run's gate or paused time (`idle_s`, D31) is shown
  beside its duration;
- Paused (failing) and waiting-at-gate states are visible on the row and the detail, with Resume / Open run;
- **Run now (D38 d):** the answer's `run_id` / `execution_key` are usually null; refresh the schedule (or its open
  history row) to show the run link once the handler sets it.
- **Models (D38 e):** `pickable.models` null means Kiro's model list cannot be read: show "model list unavailable" and
  keep the current model; a change is refused then (D35).
- delete asks for confirmation and says the runs stay in Runs (F8);
- **time zones (54-03 decision 11):** browsers may name the machine's zone by an alias ("Asia/Calcutta" for
  "Asia/Kolkata" on this Mac). Compare zone ids only after canonicalising both through `Intl` (`resolvedOptions()`),
  map the machine's zone onto the picker's option values when defaulting to it, and validate a stored id before
  formatting (an unknown id throws `RangeError`); test with the alias;
- **no opacity modifiers on token colours** (`bg-primary/10`, `border-warning/40`, …): with colours mapped to bare
  `var()` they generate no CSS (54-03 As built). Use the `*-subtle` tokens or `grad-brand-soft`.

## 3. Catalog → Agents (`web/src/features/catalog/agents/`, new)

Third tab beside Workflows and Skills (`CatalogPage.tsx:37-52`, URL-driven): list, editor, Run dialog, in-use delete
message, as in the approved mockup (`web/src/dev/mockups/phase54/agents.tsx`); the editor picks skills and servers
with the shared `MultiSelect` (D24). Skills from the installed managed list; servers from
`GET /schedules/pickable`. Run opens the new run in Run Detail.

## 4. Notification bell (`shared/layout/TopBar.tsx:59-65`)

Replace the placeholder with the popover of the approved mockup (`bell-chat.tsx`, D28): `GET /notifications` polled (30 s) or refreshed
on focus; unread badge; mark read / all; each item links to its schedule or run.

## 5. Moves

- **Testing → Setup** (`features/testing/SetupView.tsx:52`): `ScheduleSection.tsx` is replaced by a one-line summary of
  the app's regression schedule (from the setup GET's `schedule` pointer, 54-06 §2) with **Open schedule**, or
  **Schedule regression** (opens `/schedules/new` with target = this app) when none exists (D14).
- **Runs list and Run Detail:** a "Scheduled: <name>" badge for runs with `trigger.source == "schedule"`, linking to the
  schedule; "Scheduled (deleted)" when the schedule is gone (F10).
- **Catalog workflow detail:** a "Schedulable" badge and a **Schedule** action on workflows with `schedulable: true`.

## 6. Tests

Vitest + Testing Library per page with fixtures from 54-06 (L-011); jest-axe on the list, wizard, detail, Agents tab
and bell (L-014); a userEvent keyboard test for each `MultiSelect` use and the row menu (jest-axe sees neither focus
loss nor a label/name mismatch, 54-03 review m5/m6); the removed components' tests deleted with them, and a grep that no import of
`ApplicationSyncSection`, `syncSchedule` or `ScheduleSection` remains (L-094).

## 7. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test`; `npm run build` then commit `web/static/` in a
separate step and verify the commit with `git show --stat <sha> -- web/static` after the build has settled (L-089).

## As built

**Status:** IN PROGRESS. Session 1 stopped at a clean boundary (context past ~60%). Repo genesis, branch master, base
`a6cc287`, head `491ad0b`, 3 local commits (not pushed, not tagged). Not yet reviewed.

### Commits (genesis), session 1

| sha | what |
|---|---|
| `b94a976` | §0 backend follow-ups: n8, n7, D40 (each with a fail-first test) |
| `23661ed` | shared `RowMenu` and `TimeInput` (+ tests); `qk.schedules`/`customAgents`/`notifications`; `features/schedules/hooks.ts` |
| `491ad0b` | `web/static` for `23661ed` (65 files; checked with `git show --stat 491ad0b -- web/static` after the build settled, tree clean) |

### Done so far

- **n8** (`runtime/schedule_store.py`, `api/schedule_routes.py`):
  - `ScheduleStore.update(..., options_check=, target_check=)` merges `options` over the row read after
    `BEGIN IMMEDIATE`, then runs `options_check(merged)` (`validate_sync_options` for application-sync).
  - `target_check(stored_target, new_target)` decides D35's "the model changed" against that same row. The route
    reads Kiro's model list (async) only when the model differs from its own pre-read. If the store sees a change
    the route did not, the save is refused (422 `target.model`, "model list is not available; try again"), never
    accepted unchecked.
  - The route's `_options` helper is gone. `_checked_target` now returns `(target, target_check)`; a create runs the
    check at once.
- **n7** (`runtime/schedule_model.py` `validate_schedule`): `run_days(out) == []` is a `ValueError`, "this schedule
  runs on no day: pick a weekday or turn off weekdays only". That is 400 on create, update and preview. `describe` is
  unchanged, so a raw dict can still read "Weekly on no day" in its unit test.
- **D40** (`_one_regression_per_app`, inside the write's `BEGIN IMMEDIATE` in `create_user` and `update`): a second
  regression schedule for an app is a `ScheduleConflict` with `.existing = {id, name}`. The answer is 409 `{detail,
  existing}`; `_error` adds `existing` to the body. The check also applies to `duplicate` (it goes through
  `create_user`), and a row may re-save its own target.
- **Tests:** `tests/test_schedules_api.py` has 4 new tests (`…_n8` ×2, `…_n7`, `…_d40`). All 4 failed at `a6cc287`
  for the right reason: options `(3, 500) != (3, 77)`, the model race answered 200, n7 answered 201, and D40
  answered 201. `tests/test_scheduler.py`: the adopt-default test now expects merged options, and the duplicate test
  expects D40's 409 on a regression row (a workflow row is duplicated instead).
  `pytest tests/test_schedules_api.py tests/test_scheduler.py tests/test_schedule_migration.py tests/test_sync_jobs.py
  tests/test_testexec_regression.py`: 147 passed. `ruff check genesis`: clean. **The full genesis pytest has not been
  run yet.**
- **Web, shared:**
  - `shared/ui/row-menu.tsx` `RowMenu {label, items: {label, onSelect, icon?, danger?, disabled?, disabledReason?}[]}`:
    a native trigger with Radix's own `asChild` (not `Button asChild`, L-069).
  - `shared/ui/time-input.tsx` `TimeInput {value "HH:MM", onChange, label, id?, disabled?}`: a `group` of two
    spinbuttons, "<label> hour" and "<label> minute". Focus selects the field. Two hour digits, or one above 2, move
    on to the minute. ArrowUp/ArrowDown step and wrap. A partial value is padded on blur (read from the DOM, not the
    stale state).
  - Both are exported from `shared/ui/index.ts`. `shared/ui/row-menu-time-input.test.tsx` (5 tests): userEvent
    keyboard paths and jest-axe. Axe runs with `region` off for the portalled menu, a page-level rule.
- **Web, data:**
  - `lib/query/keys.ts`: `qk.schedules.{all, list, detail, history, syncStatus, preview, pickable}`,
    `qk.customAgents`, `qk.notifications`.
  - `features/schedules/hooks.ts`: `useSchedules`, `useSchedule`, `useScheduleHistory(id, offset)`
    (`HISTORY_PAGE` 50), `useSyncStatus(id, enabled)`, `usePickable`, `useSchedulePreview(spec)` (debounced 300 ms),
    `useCreateSchedule`, `useUpdateSchedule`, `useScheduleAction` (runNow, pause, resume, duplicate, reset, remove).
  - **D38 d:** a query polls every 2 s while its newest slot row is `fired` with no `run_id`/`execution_key`
    (`awaitingRunLink`), and every 10 s while a run is in flight, so the run link appears after Run now and after a
    reload.
- Web gates at `23661ed`: `npm run typecheck` clean, eslint clean on the changed files, `npm test` **821 passed** in
  71 files (816 before).

### Resume note — what is next (in this order)

1. **Schedules page** `features/schedules/` from `dev/mockups/phase54/schedules.tsx` (read the whole file; it is the
   layout):
   - the list (`SchedulesTable`, `Cadence`, `LastResult`, filter chips, the lock line, empty Mine);
   - the full-page wizard (`FullPageWizard`, step rail, summary, `RadioCards`, the four steps);
   - the detail (`StatusHeader`, history with `credits_total` labelled "total of the shown runs", Sync options as
     text + Edit, per-app table from `useSyncStatus`).

   Replace the mock's local `canonicalZone`/`MACHINE_ZONE` with a tested helper that validates the id
   (try/catch `RangeError`) and maps the machine zone onto the picker's values. Use `TimeInput` for every time,
   `RowMenu` for the row menu, `MultiSelect` for skills and servers (locked "from <agent>"; `requiresConfirm` for
   `needs_read_only_mark`), and `buildLaunchForm` + `LaunchForm` with no file widgets. Show "model list unavailable"
   when `pickable.models` is null. Put a 422 on its field via `fieldRefusalOf`. Delete needs a confirm that says the
   runs stay (F8). A system row gets `editable_fields` only and Reset to default. Show the D30/D31 history notes.
2. Nav (`PRIMARY_NAV` after Runs, an icon from `icons.ts`), routes (`/schedules`, `/new`, `/:id`, `/:id/edit`,
   `/catalog/agents` before `catalog/:workflowId`) and breadcrumbs.
3. Catalog → Agents (`features/catalog/agents/`, from `mockups/phase54/agents.tsx`) and the bell (`TopBar.tsx`,
   from `bell-chat.tsx`, polling `unreadCount` every 30 s and on focus).
4. Moves (§5): Testing → Setup pointer and "Schedule regression" (`/schedules/new?target=regression&app=<uuid>`;
   when the pointer exists, Open schedule, per D40); the Runs list and Run Detail badge from `run.trigger` (fixture
   `runs/run-scheduled`); the Catalog workflow detail's Schedulable badge and Schedule action.
5. **Removals (F7)** from 54-06's "§2 consumer list", re-grepped before each one. The backend setup GET's
   `schedule` becomes `{id, summary, next_run} | null` (`regression_for` + `describe` + `next_runs`). Drop
   `ScheduleStore.update_settings` and its test line, the D39 parity line in `test_schedules_api.py`, the old
   `ScheduleCadence`/`RegressionSchedule` (n3) and `testing/schedule.json`. Finish with the grep proof.
6. Gates (full pytest, recording whether the run fell in 00:00–02:00 IST; ruff; web lint, typecheck, test, build,
   then a separate `web/static` commit), the real-browser probe (1280/1440/1920, light and dark; screenshots to
   `evidence/54-07/`), `genesis-review`, then the full As built and the "For 54-08 / 54-09 / 54-10" note.

Open problems: none. Decisions so far, for the final As built:
1. D40 also refuses Duplicate of a regression row (409), since the copy would be a second schedule for the app.
2. D40's message names the existing schedule, not the app (the store does not read app names). The 409 body adds
   `existing: {id, name}` so the web can link to it.

## Context manifest

```toml
areas    = ["web-shell", "config-secrets", "browser-testing", "web-runs", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-032", "ADR-049", "ADR-055"]
lessons  = ["L-011", "L-014", "L-069", "L-089", "L-090", "L-091", "L-094", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/web/src/shared/layout/**", "genesis/web/src/app/router.tsx", "genesis/web/src/features/catalog/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/testing/**", "genesis/web/src/features/runs/**", "genesis/web/src/features/run-detail/**", "genesis/genesis/api/schedules.py", "genesis/genesis/runtime/schedule_store.py"]
upstream = ["54-03", "54-04", "54-05", "54-06"]
```
