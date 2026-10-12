# 45-07 — Scheduler, sync settings API, Settings card, Refresh / Full sync

> **Status:** 🟡 DRAFTED. Repo: **genesis** (backend + web). Amends **ADR-047**. Parent: `specs/phase-45-incremental-delta-sync.md`.

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
