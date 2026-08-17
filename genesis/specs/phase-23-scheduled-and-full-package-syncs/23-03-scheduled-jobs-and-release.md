# 23-03 — Scheduled jobs (app-sync + document-library) + preflight + release

> **Status:** ✅ SHIPPED (2026-08-17) — released **genesis v0.48.0** (`3fb8f08`, tag `v0.48.0`), CI green (pipeline
> **#6588951**: genesis + frontend + clean-install). · **Phase:** 23 · **Repo:** genesis (+ project-tracker) ·
> **Depends on:** 23-01, 23-02

## Goal

Register the two concrete scheduled jobs on the 23-02 engine, wire their preflight skips, seed their rows, and ship the phase
as **genesis v0.48.0** (with m0012).

## Jobs

### `application-sync` — weekday 07:00 IST, all tracked apps, **serialized**
- **Preflight:** if `config`'s `EnvironmentRegistry` has **no dev-tagged environment** → return `('skipped', 'no dev
  environment configured')` (no runs kicked). If `sync-application` isn't installed in the library → `('skipped', 'workflow not
  installed')` (never a 500).
- **Work:** `apps = kb_store.list_applications()`. For each app, **serially**:
  - skip if a `sync-application` run for that app is already non-terminal (reuse the 23-01 guard) → count `skipped(running)`;
  - pick mode: `baseline` if no `baseline_sync_id`, else `delta`;
  - `run_id = run_manager.start("sync-application", {app_uuid, app_name, mode})`;
  - **wait for terminal:** poll `run_manager.reconcile_status(run_id)` / `.get(run_id).status ∈ TERMINAL` every ~5 s, capped
    (e.g. 20 min per app → then count `error(timeout)` and move on);
  - tally ok / modified-counts / error.
- **Why serialized:** the Appian Deployment REST export permits **one export at a time** (HTTP 409 "a deployment is already in
  progress" — the workflow treats it as transient). Parallel exports would 409-storm the env and spike local subprocess load.
- **Return:** `('ok'|'partial', 'N apps: X ok, Y skipped, Z error')`.

### `document-library-sync` — weekday 08:00 / 12:00 / 16:00 / 20:00 IST
- **Preflight:** skip (`'skipped', 'gws not connected'`) if the `gws` connector isn't connected (reuse the existing readiness
  check used by `api/documents` `_gws_ready()` / `ConfigService`); skip if `sync-documents` isn't installed.
- **Work:** a single `run_manager.start("sync-documents", {"scope": "library"})`. No serialization (one run). Return
  `('ok', 'library sync started: <run_id>')` (fire-and-forget is acceptable here; the run self-reports in Runs).

## Seed rows (via `ScheduleStore.ensure_defaults`)

```
application-sync        enabled=1  {"kind":"daily_times","times":["07:00"],"weekdays_only":true,"timezone":"Asia/Kolkata"}
document-library-sync   enabled=1  {"kind":"daily_times","times":["08:00","12:00","16:00","20:00"],"weekdays_only":true,"timezone":"Asia/Kolkata"}
```

## Optional read-only surface

`GET /api/system/schedules` → the two jobs' definitions + `last_fired_slot`/`last_run_*`/`next_due` (drives a future Settings
panel; **no POST** this phase). If a small Settings "Scheduled syncs (read-only)" card lands, `npm run build` + commit
`web/static`.

## Acceptance

- With a dev env configured + apps tracked, forcing the 07:00 slot (or temporarily seeding a near-future time) fires
  `application-sync` **once**, runs apps **one at a time**, records `last_run_*`, and each app's KB reflects the refresh.
- The doc job fires on a daytime slot, starts one `scope=library` `sync-documents` run, and **does not** fire overnight or on
  weekends.
- No dev env → app-sync records `skipped`; no gws → doc-sync records `skipped`; neither errors the app or blocks boot.

## Tests

- App-sync job (mocked `RunManager`/`kb_store`/`config`): serialization order (start→wait→next), per-app mode selection,
  skip-running, skip-when-no-dev-env, partial/error tallying, per-app timeout path.
- Doc-sync job: single library run; skip-when-no-gws; skip-when-not-installed.
- (Optional) `GET /api/system/schedules` shape.

## Release

- **genesis v0.48.0** (bump `pyproject.toml` + `api/app.py` FastAPI version); tag + push; CI green (the clean-install job's
  `genesis db upgrade` exercises m0012). genesis-workflows / core / sdk / parser unchanged.
- **ADR-047 → Accepted**; append to `reference/decision-log.md`.
- Refresh the bible (`AGENT_ONBOARDING.md`): header ⭐ + latest tag v0.48.0; §2 tag row + m0012/`current_version=12` +
  `runtime/scheduler.py`/`schedule_store` + the `application-sync`/`document-library-sync` jobs + the refresh unblock; §4 map
  (runtime scheduler + db migration + `api/system/schedules`); §5 **ADR-047**; §7 lesson (Appian export is serialized → 409;
  "delta" is a full re-export + local diff, not an env patch); §9 Phase-23 SHIPPED block; test counts. Update `tracker.md`
  §3/§6 + a `progress/phase-23-scheduled-and-full-package-syncs.md`.

## Notes

- Live acceptance of the *actual* morning/4-hourly firing is observed over time (schedule-driven); the fake-clock unit tests +
  a forced-slot manual run are the pre-release evidence.
