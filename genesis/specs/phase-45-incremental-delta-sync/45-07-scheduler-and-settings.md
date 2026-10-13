# 45-07 — Scheduler, sync settings API, Settings card, Refresh / Full sync

> **Status:** ✅ SHIPPED 2026-10-13 (see the as-built section). Repo: **genesis** (backend + web). Amends **ADR-047**. Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. Scheduler

- New schedule kind **`interval_window`**: `{kind, every_hours, start:"HH:MM", end:"HH:MM", weekdays_only, timezone}`.
  Expanded to fixed slots (`start, start+N, … ≤ end`) and evaluated by the existing `due_slot` logic, so restart-safety
  and no-double-fire are unchanged. Validation: `1 ≤ every_hours ≤ 24`, `start < end`, valid IANA timezone.
- `daily_times` unchanged (the "fixed times" mode).
- `api/schedules._next_due` handles both kinds.
- **`ensure_defaults` fix:** skip `schedule_json`/`options_json` updates when `user_modified = 1` (m0023).

## 2. Job: `application-sync`

- Default: enabled, `interval_window` every 4 h 08:00–20:00, weekdays only, Asia/Kolkata; options
  `{full_every_days: 7, max_changed: 500, max_changed_pct: 25, run_on_this_machine: false}`.
- Handler (`runtime/sync_jobs.py`): if collaboration is enabled and `run_on_this_machine` is false →
  `("skipped", "scheduled syncs run on another machine")`. Otherwise for each tracked app, serially:
  `start_sync(app, mode="auto", options=…)`, wait terminal (existing cap). Summary counts incremental / full / empty.

## 3. API

- `GET /api/system/sync-settings` → `{enabled, schedule, options, collab_enabled, last_run_*, next_due,
  per_app: [{app_uuid, name, last_sync_kind, last_sync_at, last_full_at, last_status}]}`.
- `PUT /api/system/sync-settings` `{enabled, schedule, options}` → validates, writes, sets `user_modified=1`.
  400 on invalid schedule.
- `POST /api/system/sync-settings/run-now` → fires the job immediately (409 if already running).
- Existing read-only `GET /system/schedules` unchanged.

## 4. Settings → General → "Application sync" card

Placed after Appearance. Uses existing shared primitives (`Switch`, `Select`, `Input`, `Button`, `Card`); design tokens
only; accessible labels; jest-axe.

- **Enable scheduled sync** switch.
- **Frequency:** segmented control **Every N hours** (hours, window start, window end) | **Fixed times** (add/remove
  `HH:MM` chips).
- **Weekdays only** switch. **Time zone** select (default Asia/Kolkata).
- **Full sync every** N days (default 7).
- **Advanced** (collapsed): fall back to full above **N changed objects** (500) / **N %** (25).
- **Run scheduled syncs on this machine** switch — only when collaboration is enabled; helper text explains one
  machine should run the schedule and others auto-pull.
- **Status:** next run, last run (result + summary), per-app last sync kind/time and last full sync; **Run now**.
- Save button (dirty-state aware); toast on save; server validation errors inline.

## 5. Application page

- **Refresh** → `POST /applications/{uuid}/sync {mode:"auto"}` (delta with auto rules; label unchanged).
- New **Full sync** action (button dropdown next to Refresh) → `{mode:"full"}` with a confirm ("Re-exports the whole
  application").
- **Syncs tab:** show kind (Incremental / Full / Baseline / Hub pull), changed count, fallback reason, skipped
  objects (expandable), and the published Hub version.

## 6. Tests

Backend: `due_slot` for `interval_window` (slot expansion, window bounds, weekends, restart catch-up);
`ensure_defaults` respects `user_modified`; API validation + `user_modified`; handler skip when not the designated
machine; serial run. Web: card renders both modes, saves, validation errors, collaboration-only switch; Refresh sends
`auto`, Full sync confirms and sends `full`; Syncs tab shows kind + fallback. Update `settings.test.tsx` and
`applications.test.tsx`.

## 7. As built (2026-10-13, genesis `dad4433`, local) — deviations from §1–§6

- **Scheduler:** `schedule_times(schedule)` expands `interval_window` to fixed slots; `due_slot` + `_next_due` use
  it (restart catch-up / no double fire unchanged). `validate_schedule` (1 ≤ every_hours ≤ 24, `HH:MM`, start < end,
  IANA zone; `daily_times` non-empty + deduped/sorted). **`Scheduler.run_now(job)`** (Run now) does NOT move
  `last_fired_slot` (`mark_fired(slot=None)` keeps it) — otherwise a manual run would re-arm today's last slot.
- **`ensure_defaults`:** `user_modified=1` → only `name` refreshed. A default carrying `options` is **adopted once**
  (schedule + options + `enabled`) by a row with `options_json` NULL and `user_modified=0` (the pre-45 07:00 row,
  which was disabled → becomes **enabled** every 4 h). Otherwise as before (definition refreshed, `enabled` kept).
- **Handler:** collaboration on and `run_on_this_machine` off → `skipped`; else `start_sync(mode=None → auto,
  options={full_every_days, max_changed, max_changed_pct})`; the summary appends kinds, e.g.
  `"2 apps: 2 ok, 0 skipped, 0 error (1 empty, 1 incremental)"`.
- **API:** `GET/PUT /api/system/sync-settings` (+ `user_modified`, `running`, `per_app[].last_changed_count /
  last_fallback_reason`); options validated (full_every_days 1–365, max_changed ≥ 0, max_changed_pct 0–100);
  `POST …/run-now` → 409 when running (async route: it schedules on the event loop).
- **Web:** the card sits after Appearance; **Full sync** is a separate ghost button next to Refresh (not a button
  dropdown) with a confirm dialog; Refresh sends `{mode:"auto"}`. Syncs tab: "No changes" for an empty incremental,
  "N changed in Appian", "Full sync because …", export warnings, expandable skipped objects, "Hub v N" (45-08).
  The card's axe test is scoped to the card region (the General tab has a pre-existing heading-order issue in
  KiroSection, out of scope).

**Evidence:** genesis pytest **914** + ruff; web tsc + eslint (0 errors, 19 pre-existing warnings), vitest **298**
(+7), build committed. Not yet live: the fleet still runs the pre-45-07 server code (no restart this sub-phase).
- **Review follow-up (`9a2afa8`):** the scheduled job **skips** ("the installed sync-application predates incremental
  sync …") when the installed workflow's mode enum lacks `incremental` — otherwise an old library (0.2.x) would turn
  every 4-hourly slot into a full re-export. Manual Refresh / Full sync still work. Review: **SHIP**.
