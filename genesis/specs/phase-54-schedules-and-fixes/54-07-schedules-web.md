# 54-07 — Web: Schedules page, Catalog → Agents, notification bell, moves out of Settings and Testing

> **Status:** BUILT 2026-11-19 (review SHIP at re-run 2, genesis `41971a0`). Repo: genesis (`web/`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built
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

**Status:** BUILT 2026-11-19. Review **SHIP** at re-run 2, head `41971a0`. Repo genesis, branch master, base `a6cc287`.
There are 13 local commits (not pushed, not tagged). Source, tests and fixtures: 68 files, +4062/−1028. `web/static` is
in five build commits. No migration: the DB stays **v30**, and the fleet was not restarted (D36).

### Commits (genesis)

| sha | what |
|---|---|
| `b94a976` | §0 backend follow-ups n8, n7 and D40, each with a fail-first test |
| `23661ed` | shared `RowMenu` and `TimeInput` with tests; the query keys; `features/schedules/hooks.ts` |
| `491ad0b` | `web/static` for `23661ed` |
| `9fe47ee` | Schedules page (list, detail, wizard); `LaunchFields`; nav, routes and breadcrumbs |
| `5881557` | Catalog → Agents tab and the notification bell |
| `ce3f418` | the §5 moves and the F7 removals (backend and web), with n3 |
| `a3a4371` | `web/static` for `ce3f418` |
| `63e88f6` | real-browser probe findings, plus the probes `phase54-seed.py` and `phase54-pages.mjs` |
| `fb6982f` | `web/static` for `63e88f6` |
| `efba8db` | review round 1: m1, m2, m3, n1, n2, n3 |
| `d9c68b0` | `web/static` for `efba8db` |
| `5672ad1` | review re-run 1: M1, n4, n5 |
| `41971a0` | `web/static` for `5672ad1` |

Every bundle commit was checked with `git show --stat <sha> -- web/static` in its own call after the build had
settled, and `git status --short --untracked-files=all` was empty each time (L-089). The reviewer's fresh build
matched `web/static` at `fb6982f`, `d9c68b0` and `41971a0`.

### Changed

**Backend (§0).**
- **n8.** `ScheduleStore.update(..., options_check=, target_check=)` (`runtime/schedule_store.py`):
  - `options` are merged over the row read after `BEGIN IMMEDIATE`. `options_check(merged)` then validates them
    (`validate_sync_options` for application-sync).
  - `target_check(stored, new)` decides D35's "the model changed" against that same row.
  - In `api/schedule_routes.py`, `_checked_target` returns `(target, target_check)`. Kiro's model list is read
    (async) only when the model differs from the route's pre-read. A change that only the store sees is refused
    (422 `target.model`, "not available; try again"), never accepted unchecked. A create checks at once.
  - The route's old `_options` is gone. A non-object `options` is still 400.
- **n7.** `validate_schedule` (`runtime/schedule_model.py`) refuses `run_days(out) == []` with "this schedule runs on no
  day: pick a weekday or turn off weekdays only". That is 400 on create, update and preview.
- **D40.** `_one_regression_per_app` runs inside the write's `BEGIN IMMEDIATE` in `create_user` and `update`, so
  Duplicate is covered too. It raises `ScheduleConflict(existing={id, name})`, and `_error` answers 409
  `{detail, existing}`. A row may re-save its own target.

**Web, shared** (`shared/ui`, exported from `index.ts`).
- `row-menu.tsx` `RowMenu {label, items: {label, onSelect, icon?, danger?, disabled?, disabledReason?}[]}`, over Radix
  DropdownMenu. The trigger is a native button under Radix's own `asChild`, never `Button asChild` (L-069).
- `time-input.tsx` `TimeInput {value "HH:MM", onChange, label, id?, disabled?}` (D29):
  - a `group` of two spinbuttons, "<label> hour" and "<label> minute";
  - focus selects the field, two hour digits (or one above 2) move on to the minute, and ArrowUp/ArrowDown step and
    wrap;
  - a partial value is padded on blur.
  - It replaces every native `type="time"`: the three in `ApplicationSyncSection` and one in `ScheduleSection`, both
    now removed, and the wizard uses only `TimeInput`. The test asserts that no `input[type=time]` is left.

**Web, data.**
- `lib/query/keys.ts` gains `qk.schedules.*`, `qk.customAgents.*` and `qk.notifications.*`. `qk.config.syncSettings`
  is removed.
- `features/schedules/hooks.ts`: `useSchedules`, `useSchedule`, `useScheduleHistory(id, offset)`, `useSyncStatus`,
  `usePickable`, `useSchedulePreview` (debounced 300 ms), `useCreateSchedule`, `useUpdateSchedule` and
  `useScheduleAction`.
- **D38 d:** the polling is driven by the data. A query refetches every 2 s while its newest slot row is `fired` with no
  run link (`awaitingRunLink`), and every 10 s while a run is in flight. So the run link appears after Run now and also
  after a reload.
- `features/catalog/agents/hooks.ts` and `features/notifications/hooks.ts` hold the other hooks. The unread count is
  polled every 30 s and on window focus.

**Schedules page** (`features/schedules/`, built from the approved mockup).
- `SchedulesPage.tsx` (D22, D23):
  - filter chips, the lock line, and a lock icon with a tooltip on system rows;
  - the weekday strip and the backend's `cadence.line`, with a calendar icon for monthly and once;
  - the zone only when it differs from the machine's;
  - Last result as an `OutcomeBadge` that links to the run or `TE-` execution, with time, reason and gate cancel time
    in its tooltip;
  - the switch writes `enabled` only;
  - `ScheduleRowMenu` holds Run now, Pause/Resume, Edit, Duplicate, Delete or Reset to default. Run now and
    Pause/Resume are disabled with a reason while the schedule is off, and Run now also while a run is in flight;
  - a Paused (failing) row is tinted `bg-danger-subtle`;
  - an empty Mine shows its empty state.
- `useScheduleActions.tsx`: the actions and their `ConfirmDialog`s. Delete says the runs stay in Runs, marked
  "Scheduled (deleted)" (F8).
- `ScheduleDetailPage.tsx` (D15, D25, D30, D31, D39, F9):
  - a `StatusHeader` with State, Next run, Last result and Failures in a row, plus Run now, Pause/Resume, Edit and a
    "More actions" menu;
  - banners for Paused (failing), with Resume, and for waiting at a gate, with Open run;
  - the history: slot, outcome with its reason, "Doesn't count toward auto-pause" when `counts_toward_pause` is
    false, the run link (or "Starting…"), the duration with "incl. N at a gate or paused" from `idle_s`, and metered
    credits per row;
  - a footer "Total of the N shown slots (M with runs)" with the provenance note, and Newer/Older paging over 50;
  - side cards for Target, Frequency, Run policy and, for application-sync, Sync options as text with an Edit button;
  - application-sync also gets "Last sync per application" from `GET /schedules/{id}/sync-status`: kind, time, changed
    count, a non-succeeded status, fallback reason, Hub version and last full sync. Every field of the old card is kept.
- `ScheduleWizardPage.tsx` (D24, D29, D35, D38 e):
  - a full page with a step rail and a running summary. A user row has four steps (Target, Configure, Frequency,
    Name & review). A system row has two ("Frequency & options", Review) and sends only its `editable_fields`, with
    only the option keys that changed.
  - The workflow step reuses `LaunchFields`, which was extracted from `LaunchForm` without changing its behaviour.
    Workflows come from `pickable.workflows`, which excludes file inputs, and no file widget renders without `files`.
  - The agent step has the custom agent `Select`, the prompt, `SkillPicker` and `ServerPicker` over `MultiSelect`, and
    `ModelPicker`:
    - the agent's own picks show as locked chips "from <agent>";
    - a server with `needs_read_only_mark` needs "This server only reads" ticked before Next;
    - a pick that is no longer available is named with a Remove button;
    - `ModelPicker` says "Model list unavailable: keeping …" when `pickable.models` is null.
  - The regression step disables an app that already has a schedule, with a link to it (D40). The name defaults to
    "Regression: <app>".
  - The frequency step has the five D9 forms with `TimeInput`, the zone picker, the backend preview (summary and next 5
    runs, or its error), Advanced (grace, max duration, gate wait, failures, end date plus `TimeInput`, max runs) and,
    for app-sync, the sync options.
  - A 422 from `fieldRefusalOf` opens its field's step (`stepOfField`) and shows the message on the field
    (`data-field`), including `refused`. A 409 with `existing` links to that schedule.
- `wizard-model.ts`: `freqOf`/`toSpec` map stored schedules to and from the forms. An hourly window's `days` and a
  weekly row's `weekdays_only` are kept apart from the form's own fields (review m1 and M1). Also here: `toPolicy`,
  `draftOf`, `createBody`, `updateBody`, `serverPicks` and `stepOfField`.
- `zones.ts`: `canonicalZone`, `sameZone`, `machineZone`, `zoneOptions(keep)` (the stored spelling replaces its
  alias), `pickZoneOption`, `formatInZone` (an unknown id falls back to UTC, never throws), `slotText` and `endAtText`.
- `logic.ts`: `stateOf`, `matchesFilter`, `daysInWords`, `OUTCOME`, `resultHref`, `historyNotes`, `targetLabel`,
  `SYSTEM_RUNS`, `serverOptions` and `needsMark`.
- `components.tsx` (`Cadence`, `OutcomeBadge`, `LastResult`, `StateBadge`, `ScheduleRowMenu`), `pickers.tsx` and
  `ScheduledBadge.tsx`.

**Nav and routes.**
- `PRIMARY_NAV` gets Schedules (`CalendarClock`) after Runs. The command palette picks it up.
- `router.tsx` adds `schedules`, `schedules/new`, `schedules/:id`, `schedules/:id/edit` and `catalog/agents`. Each
  static route is registered before its param route (L-096).
- `breadcrumbs.ts` adds `/schedules`, `/new`, `/:id` (the label is set by the detail and wizard pages), `/:id/edit` and
  `/catalog/agents`.

**Catalog → Agents** (`features/catalog/agents/AgentsTab.tsx`; `CatalogPage` has a third URL-driven tab).
- Cards show skills, servers, model and "Used by N schedules".
- The editor dialog has name, description, instructions, the shared skill and server pickers, the model, and the
  schedule-versus-chat tools note. A 422 shows on its field, and a 409 name clash on Name.
- The Run dialog starts the agent once and shows "Started run … Open run".
- Delete asks for confirmation. A 409 opens "Can't delete <agent>", which links each schedule that uses it.

**Bell** (`features/notifications/NotificationBell.tsx`, which replaces the `TopBar` placeholder).
- The unread badge reads "99+" above 99.
- A popover labelled by its heading lists notices with an icon per kind, an sr-only kind label, the body and the
  relative time.
- Opening a notice marks it read and follows its link. Each notice has a mark-read control, and the panel has Mark all
  read and an empty state.

**Moves (§5).**
- Testing → Setup: `setup/SchedulePointer.tsx` replaces `ScheduleSection`. It shows the summary and next run with Open
  schedule, or Schedule regression, which opens `/schedules/new?target=regression&app=<uuid>`.
- `ScheduledBadge` appears on `RunsTable` and the `RunDetailPage` header (F10). The link stops the row's own click.
- `WorkflowDetail` shows a "Schedulable" badge and a Schedule action, which opens
  `/schedules/new?target=workflow&workflow=<id>`, for installed workflows with `schedulable: true`.

**Removals (F7, n3).** Each one was re-grepped first (L-094).
- Backend:
  - `api/schedules.py` is deleted (`/system/schedules`, `/system/sync-settings` GET/PUT/run-now, `_next_due`,
    `SyncSettingsBody`), together with its registration in `api/app.py`.
  - `ScheduleStore.update_settings` is removed.
  - `PUT /applications/{uuid}/testing/schedule` and `ScheduleBody` are removed.
  - In `testexec/regression_service.py`, `schedule_view`, `save_schedule`, `_cadence_of`, `_validate_schedule`,
    `get_schedule`, `set_schedule`, `SCHEDULE_NOTE` and `CADENCES` are replaced by `regression_pointer(store, app_uuid)`
    → `{id, summary, next_run} | null`. The testing setup GET/PUT and the regression suite GET both use it (L-109).
  - Two docstrings in `sync_jobs.py` are updated.
  - Kept: `validate_sync_options`, `app_sync_per_app` and `collab_enabled`.
- Web:
  - `ApplicationSyncSection.tsx`, `syncSchedule.ts` and `ScheduleSection.tsx` are deleted, along with the mount in
    `SettingsPage.tsx`.
  - Also removed: `systemApi` `getSyncSettings`, `putSyncSettings` and `runSyncNow` with their `Sync*` types;
    `useSyncSettings`, `useSaveSyncSettings` and `useRunSyncNow`; `testingApi.saveSchedule`.
  - `types/testing.ts` `RegressionSchedule` and `ScheduleCadence` (n3) become `RegressionSchedulePointer`, so one
    `ScheduleCadence` is left (`types/schedules.ts`).
  - `test/fixtures/testing/schedule.json` is deleted. `testing/setup.json` and `regression.json` had only their
    `schedule` key edited to `null`: a full regeneration churned 28 unrelated fixtures (timestamps, ids), and I
    restored those. `testing/schedule-pointer.json` is new and was recorded from a real response.
- Grep proof, at `ce3f418` and again by the reviewer: no import or call of any removed name is left in genesis,
  genesis-workflows, playwright-appian or `genesis-fleet/bin`. What remains is a docstring, unrelated functions named
  `get_schedule`/`reset_schedule`, a migration-test docstring, and the tests that assert the old routes now 404.

**Probes** (`scripts/probes/`).
- `phase54-seed.py` prepares and seeds a throwaway Genesis home. It refuses `~/.genesis`, and it quotes SKILL.md
  descriptions (L-115: an unquoted ": " made the managed skill silently vanish on the first try).
- `phase54-pages.mjs` covers the pages and portals at three widths × two themes, with `timezoneId: "Asia/Calcutta"`.
  It checks that the zone cells show only the UTC row.

### Tests

- **Backend** (`tests/`):
  - **New:** `test_two_saves_of_different_options_keep_both_n8`,
    `test_a_model_changed_by_another_save_is_checked_against_the_stored_one_n8`,
    `test_a_schedule_with_no_effective_day_is_refused_n7` and `test_a_second_regression_schedule_for_an_app_is_refused_d40`.
    All four failed at `a6cc287` for the right reason: options `(3, 500) != (3, 77)`, the model race answered 200, n7
    answered 201, and D40 answered 201.
  - **Rewritten for the pointer:** `test_the_schedule_pointer_is_the_apps_own_regression_row` and
    `test_the_old_schedule_route_is_gone_and_the_setup_read_points_to_the_row` (records `schedule-pointer`).
  - **`test_sync_jobs.py`:** the system rows now come through `GET /api/schedules?kind=system`, and the per-app status
    through `/schedules/{id}/sync-status`. The sync-settings GET/PUT and run-now tests are removed; `test_schedules_api`
    covers those paths.
  - **`test_schedules_api.py`:** the D39 parity line is now 404 checks for the four removed routes.
  - **`test_scheduler.py`:** expects merged options and D40 on duplicate.
- **Web:**
  - `shared/ui/row-menu-time-input.test.tsx` (5): RowMenu and TimeInput by keyboard, with jest-axe.
  - `features/schedules/zones.test.ts` (5): uses the Asia/Calcutta alias.
  - `features/schedules/wizard-model.test.ts` (10): a 7-shape round trip, the M1 form switch, system-row updates and
    `stepOfField`.
  - `features/schedules/schedules.test.tsx` (12):
    - list: lock icons, strip names, line text, gate state and jest-axe;
    - the switch writes `enabled` only, and the Mine filter and its empty state;
    - the row menu by keyboard: disabled while off, Delete confirms that runs stay, Reset to default for system rows;
    - the zone shown only for UTC with `TZ=Asia/Calcutta`;
    - detail: app-sync options as text with Edit, per-app status, D30/D31 notes, the credits total and jest-axe;
    - Run now refreshes until the link appears (D38 d);
    - wizard: locked picks, "model list unavailable", the server MultiSelect by keyboard, no `type=time`, the backend
      preview, and the 422 on `target.mcp_servers` with jest-axe;
    - a system-row edit sends only the changed options;
    - a cleared sync option is refused;
    - the regression auto-name follows the app;
    - D40 "Already scheduled", and launch-form reuse.
  - `features/schedules/moves.test.tsx` (3): the F10 badges from `runs/run-scheduled`, and the Schedulable badge and
    Schedule action.
  - `features/catalog/agents/agents.test.tsx` (4): list and jest-axe; the editor's server and skill pickers by keyboard,
    a blocked server disabled with its reason, jest-axe open, and a 422 on `mcp_servers`; Run; the in-use delete.
  - `features/notifications/bell.test.tsx` (4): count, kinds and jest-axe open; mark one read and all read; open a
    notice; empty. jest-axe found a real bug here: the popover was a dialog with no name, and is now
    `aria-labelledby` its heading.
  - **Changed:** `testing/setup.test.tsx` (pointer and Schedule regression; the old schedule editor tests are removed),
    `testing/contract.test.ts` (`Exact<RegressionSchedulePointer>` against the recorded fixture, `null` in setup and
    regression), and `settings/settings.test.tsx` (General shows no Application sync and makes no sync-settings call;
    the old card tests and MSW handlers are removed).
- **Mutation and fail-first:**
  - the old `wizard-model.ts` fails 3 of the m1 cases and the M1 case;
  - the old `ScheduleWizardPage.tsx` fails n1 and n2/n5;
  - the reviewer reproduced each in a scratch export.
- **Gates:**
  - genesis `pytest -q -p no:warnings`: **2079 passed** at `ce3f418`, 17:09–17:20 IST, which is **outside** the
    00:00–02:00 window, with nothing deselected. The reviewer re-ran it at `fb6982f` (17:45–17:56 IST, 2079 passed). No
    backend file changed after that. `ruff check genesis` is clean.
  - Web at `5672ad1`: `npm run lint` 0 errors and 20 warnings, the same 20 as before with none in a new file;
    `npm run typecheck` clean; `npm test` **855 passed** in 77 files (816 at `a6cc287`).

### Screenshots (real browser, L-090)

- **Setup:** a separate Genesis server on loopback 8790 (reports origin 8890) with the throwaway home `/tmp/p54-b1`
  (checked through the process environment), seeded by `scripts/probes/phase54-seed.py`. The fleet was not used or
  restarted, and the real `~/.genesis` was not touched. The server was stopped afterwards.
- **Run:** `scripts/probes/phase54-pages.mjs` at 1280/1440/1920 × light/dark, browser zone `Asia/Calcutta`. On the
  final bundle (`41971a0`): **96 entries, all clean**, meaning:
  - no sideways page scroll and no overflow;
  - no table that scrolls or has a header that wraps;
  - portals inside the viewport, and Tailwind and theme resolved;
  - the zone cells show only "UTC".
- **Finding fixed:** the first run found the history table scrolling at 1280 (`min-w-[680px]`). `63e88f6` fixed it:
  `min-w-[560px]`, no duration on skipped/missed rows, and the gate/paused note moved under the policy card.
- **Folder:** `specs/phase-54-schedules-and-fixes/evidence/54-07/` (7 MB, JPEG q70) plus `result.json`. Names are
  `<name>-<width>-<theme>.jpg`, 6 files per name:

| surface | names |
|---|---|
| Schedules list | `schedules-list`, `portal-row-menu`, `portal-last-result-tooltip` |
| Detail and history | `schedule-detail-agent` (agent prompt; ok, failed, missed, skipped; credits total), `schedule-detail-app-sync` (sync options, per-app), `schedule-detail-failing` (Paused (failing) banner) |
| Wizard | `schedule-wizard-1-target`, `-2a-workflow`, `-2b-agent`, `-2c-regression`, `-3-frequency`, `schedule-wizard-system-edit`, `portal-server-multiselect` (locked "from KB explorer", "Can't be picked") |
| Catalog → Agents | `catalog-agents`, `portal-agent-editor` |
| Bell | `portal-bell-popover` |

Not probed live: a run waiting at a gate. The seed's open row with no live run is closed "interrupted" by the server's
recovery sweep, which is correct behaviour. The fixture tests cover the gate state.

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-07-review.md`.
- **Round 1 (`fb6982f`): SHIP**, with m1 (the wizard dropped stored `days`/`weekdays_only` it does not show), m2 (no
  keyboard pick for every MultiSelect use), m3 (dead `errorFor`) and n1–n3. All were fixed in `efba8db`.
- **Re-run 1 (`d9c68b0`): NEEDS_CHANGES.** M1: my m1 fix let Daily/Hourly's "Weekdays only" leak into the Weekly form.
  Also n4 and n5. Fixed in `5672ad1`.
- **Re-run 2 (`41971a0`): SHIP** with no findings. The reviewer ran each new test against the old code.
- The reviewer agreed with all nine of my decisions below, and asked that decision 3 be recorded as a deviation.

### Decisions / deviations

No ADR deviation. Mine:
1. **D40 also refuses Duplicate** of a regression row (409), since the copy would be a second schedule for the app. The
   message names the existing schedule, not the app (the store does not read app names). The 409 body adds
   `existing: {id, name}`, which the wizard links to.
2. **n8 model race fails closed.** If the store's locked read shows a model change the route did not see, the save is
   refused ("model list not available; try again") rather than checked against a list it never read. A retry passes.
3. **Deviation from §3's wording:** the agent Run dialog shows the started run with an **Open run** link, as in the
   approved mockup, instead of navigating on its own.
4. **The regression step lists the tracked apps** without a per-app suite case count (no cheap API). An app that
   already has a schedule is disabled with a link to it. A new row is named "Regression: <app>" unless a name was
   typed.
5. **The wizard has no "Schedules › New" subtitle**, because the breadcrumb shows it. A system row gets a one-line
   subtitle instead.
6. **The agent editor's skills come from `GET /schedules/pickable`** (`skills.list()`, the same installed managed list
   §3 names), so the editor and the wizard read one list.
7. **One pointer reader:** `regression_pointer` serves the testing setup GET/PUT and the regression suite GET. The
   suite's `schedule` key became the pointer too, since it had the same old shape. Its only web reader was the
   contract test.
8. **`LaunchFields`** was extracted from `LaunchForm` without changing its behaviour, so the wizard reuses the widgets.
   File widgets render only when the caller passes `files`.
9. **`policy.end_at` is sent as a local `YYYY-MM-DDTHH:MM`.** The scheduler reads it in the schedule's zone
   (`scheduler.py:298`, `parse_instant(end_at, tz)`).
10. **A sync-option range refusal** (such as 150 %) stays a field-less 400, shown as the general message on Review. A
    blank option is refused on the frequency step, inside the Sync options fieldset (review n1, n4).
11. **Zone picker:** the options are `Intl.supportedValuesOf("timeZone")`, which on this Mac lists `Asia/Calcutta` and
    not `Asia/Kolkata`. A stored id replaces its alias in the list, and a new schedule defaults to the machine's zone
    mapped onto the list. So a new schedule on this Mac stores "Asia/Calcutta", which Python's tzdata accepts as a link.
    Comparisons are canonical everywhere.

### Lesson candidates

1. **A fix that keeps a hidden field must keep it in its own slot.** Review m1 asked the wizard to keep a stored
   `weekdays_only` the Weekly form does not show. Putting it back into the shared form field let a value the user set
   on another form leak into Weekly (re-run 1 M1). Store a value the form does not show in a field only the loader
   sets, and test a form switch, not only a round trip.
2. **Regenerating golden fixtures rewrites every timestamp and id they hold.** `GENESIS_WRITE_CONTRACT_FIXTURES=1` on
   two test files churned 30 fixtures to change one key in two of them. Restore the unrelated files and edit only the
   key that changed. The shape check (`record`) still proves the result matches the real response.
3. **A seeded SKILL.md with ": " in a plain description vanishes silently** (L-115 again, this time in a probe seed).
   The skill was missing and the API answered 422 "skills not installed". Quote generated front matter
   (`json.dumps`) in every writer, scripts included.
4. **A data-driven poll beats a mutation-driven one for "the id arrives later"** (D38 d). Polling while the newest row
   is `fired` without a run link also covers a reload and another tab, and needs no state of its own.
5. **jest-axe on an open Radix Popover finds a dialog with no name.** Pass `aria-labelledby` to `PopoverContent` with
   the panel's heading id. The mockup's per-frame axe run never opened the popover.

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runtime/schedule_store.py`:
  - `ScheduleStore.update(..., options_check=, target_check=)` (both run under the write lock);
  - `_one_regression_per_app`;
  - `ScheduleConflict.existing`;
  - `update_settings` is removed.
- `genesis/runtime/schedule_model.py`: `validate_schedule` refuses a schedule with no effective day.
- `genesis/api/schedule_routes.py`: `_checked_target` returns `(target, target_check)`; `_options_check`; `_model_of`;
  the 409 body carries `existing`.
- `genesis/api/schedules.py`: **deleted**, along with its registration in `api/app.py`.
- `genesis/api/testing.py`: `PUT …/testing/schedule` and `ScheduleBody` are removed; the setup's `schedule` is the
  pointer.
- `genesis/testexec/regression_service.py`: `regression_pointer` replaces `schedule_view`, `save_schedule`,
  `get/set_schedule`, `SCHEDULE_NOTE` and `CADENCES`.
- Web, `shared/ui`: `row-menu.tsx` `RowMenu`, `time-input.tsx` `TimeInput`.
- Web, `features/schedules/` (new):
  - pages: `SchedulesPage`, `ScheduleDetailPage`, `ScheduleWizardPage`;
  - logic: `hooks.ts`, `logic.ts`, `zones.ts`, `wizard-model.ts`;
  - pieces: `components.tsx`, `useScheduleActions.tsx`, `pickers.tsx`, `ScheduledBadge.tsx`.
- Web, catalog:
  - `features/catalog/agents/` (new): `AgentsTab`, `hooks.ts`;
  - `features/catalog/LaunchFields.tsx` (new, used by `LaunchForm` and the wizard);
  - `CatalogPage` has an Agents tab.
- Web, `features/notifications/` (new): `NotificationBell`, `hooks.ts`, mounted in `shared/layout/TopBar.tsx`.
- Web, testing: `features/testing/setup/SchedulePointer.tsx` replaces `ScheduleSection.tsx`.
- Web, removed: `features/settings/components/ApplicationSyncSection.tsx` and `syncSchedule.ts`.
- Web, types: `types/testing.ts` `RegressionSchedulePointer` replaces `RegressionSchedule`/`ScheduleCadence`.
- Web, nav: `shared/layout/nav.ts` (Schedules), `breadcrumbs.ts`, and `app/router.tsx` (the four `schedules` routes and
  `catalog/agents`).
- `scripts/probes/phase54-seed.py` and `phase54-pages.mjs` (new).
- Docs that still describe the removed routes (54-06's list, for genesis-docs): `docs/architecture/modules/api.md`,
  `knowledge-base.md`, `scheduler-and-jobs.md`, `testing.md` and `web-app.md`.

### For 54-08 / 54-09 / 54-10

- **54-08 (chat custom agent):**
  - reuse `useCustomAgents` (`features/catalog/agents/hooks.ts`) for the new-session agent picker;
  - the tools note wording is in `AgentsTab`'s editor;
  - `ScheduledBadge` is a model for a small linked badge if the chat header needs one;
  - `RowMenu` is shared now.
- **54-09 (UX revamps):**
  - `RowMenu`, `TimeInput`, `SectionCard`, `DefinitionList` and `StatusHeader` are in `shared/ui`;
  - the bell is the first consumer of a labelled Popover (see lesson candidate 5);
  - pre-existing opacity modifiers on token colours (backlog) are still in `TopBar.tsx` (`bg-surface-1/70`),
    `RunDetailPage.tsx` (`bg-surface-1/70`), `RunsTable.tsx` (`bg-warning-subtle/30`), `LaunchForm.tsx`
    (`border-warning/30`, `border-info/30`, `border-danger/40`), `SetupView.tsx` (`border-warning/40`) and `Badge`'s
    `primary` tone (`bg-primary/15`); 54-07 added none and changed none of them.
- **54-10 (review and acceptance), live rows not covered here:**
  - a scheduled run actually waiting at a gate (row tint, banner, Open run, the tooltip's cancel time);
  - Run now on a real run, with the link appearing;
  - the row menu → ConfirmDialog hand-off for Delete and Reset in a real browser;
  - Kiro's real model list in the wizard and agent editor (only `models: null` and the fixture list were exercised);
  - the regression and app-sync migrations seen on the Schedules page;
  - the bell with real notices from the scheduler;
  - the Schedules screens after m0030 on the fleet (D36: only at the release).
  - `scripts/probes/phase54-pages.mjs` can be re-run against the release candidate's own throwaway server.
- **Follow-ups (not fixed):**
  - the zone picker shows ICU's alias names (`Asia/Calcutta`), because `Intl.supportedValuesOf` lists those;
  - a preferred-name map would be a small addition if the user wants "Asia/Kolkata" shown;
  - a sync-option range refusal is not shown on its field (decision 10).

## Context manifest

```toml
areas    = ["web-shell", "config-secrets", "browser-testing", "web-runs", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-032", "ADR-049", "ADR-055"]
lessons  = ["L-011", "L-014", "L-069", "L-089", "L-090", "L-091", "L-094", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/web/src/shared/layout/**", "genesis/web/src/app/router.tsx", "genesis/web/src/features/catalog/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/testing/**", "genesis/web/src/features/runs/**", "genesis/web/src/features/run-detail/**", "genesis/genesis/api/schedules.py", "genesis/genesis/runtime/schedule_store.py"]
upstream = ["54-03", "54-04", "54-05", "54-06"]
```
