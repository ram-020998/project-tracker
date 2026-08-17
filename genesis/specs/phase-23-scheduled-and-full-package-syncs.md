# Phase 23 — Scheduled & Full-Package Syncs (umbrella)

> **Status:** 📝 **DRAFT — planning (awaiting approval to build).** · **Author:** Genesis agent · **Date:** 2026-08-17
> **Goal:** Keep the local Appian KB and Document Library **fresh automatically** without a human clicking sync. Two
> capabilities: **(1)** make the application sync **re-runnable as a full-package refresh** (re-export the whole app → parse →
> diff against the DB → write only the changes) — exposing the already-built delta-merge that today is blocked at the API; and
> **(2)** a **backend scheduler** that runs those syncs on a fixed cadence (all applications once each weekday morning; the
> document library every 4 hours during weekday daytime), with the schedule persisted in a DB table so it becomes
> user-configurable later.
> **Repos:** **genesis only** — an API unblock + a per-app guard (`api/applications.py`), a new `runtime/scheduler.py`, a new
> `ScheduleStore` + **migration m0012**, and startup/shutdown wiring. genesis-core / kiro-agent-sdk / genesis-appian-parser /
> **genesis-workflows: unchanged** (the `sync-application` delta mode and the `sync-documents` library scope already exist and
> already do the work). **Schema change: yes — m0012 `scheduled_jobs`** (a table per the resolved decision §11.2).
> **Non-negotiable framing:** stays **local single-user** (ADR-026). Scheduled syncs are **read-only against Appian** (the
> Deployment REST export) + **local** KB/document writes, `auto_approve`, **no HITL gates** — they call the same `RunManager`
> API a human clicks (ADR-033 "operator at the run-management layer" lineage; ADR-001 preserved — LangGraph still owns each
> sync's control flow).

---

## 0. TL;DR

The `sync-application` workflow **already** supports a full-package refresh (`mode=delta`, shipped 16-07 "Option A"): a **full
re-export** of the entire application → parse → **diff against current KB rows by `diff_hash`** → open new / close+reopen
modified / close removed / diff edges / recompute bundles (`KbStore._apply_delta`). Despite the name, this is **not** an
environment "delta patch" — it re-fetches the whole app and computes the delta locally. The only reason it feels
"not re-runnable" is a stale guard in `api/applications.py` (`_start_sync` raises `400 "delta not supported yet"`, and
re-running baseline errors "already has a baseline"). Likewise `sync-documents` already has a `scope="library"` refresh
(`POST /api/documents/sync`). **So this phase exposes + automates existing engines; it does not build a compare-and-write
engine from scratch.**

1. **Full-package refresh app sync (23-01)** — unblock the delta path in the API, add a per-app "already running" guard, run
   **baseline** for a tracked app that has none yet and **delta** otherwise, and (optional) a **Refresh** action on the app
   detail page. genesis only, no schema.
2. **Scheduler foundation + schedule table (23-02)** — **m0012 `scheduled_jobs`** + a `ScheduleStore`, and a lightweight
   **asyncio minute-tick scheduler** (`runtime/scheduler.py`) started in the app's `startup` event: TZ-aware (IST), weekdays
   only, daytime slots, **idempotent across restarts** via a persisted `last_fired_slot`. **ADR-047.**
3. **Scheduled jobs + release (23-03)** — register two jobs: **`application-sync`** (once each weekday at **07:00 IST**, all
   tracked apps, **serialized**) and **`document-library-sync`** (each weekday at **08:00 / 12:00 / 16:00 / 20:00 IST**,
   `scope=library`), with **preflight skips** (no dev env → skip app sync; `gws` not connected → skip doc sync). Release + docs.

**No new workflow, no new MCP, no agent.** New runtime code = one API unblock + a scheduler engine + a schedule store/table.

---

## 1. Motivation & context

Requirement (user, 2026-08-17): the application sync isn't re-runnable — it expects a delta patch, but **fetching a delta
package from the environment isn't available on the platform**, and we need to **refresh applications every day**. So the sync
must support **full packages**: pull the entire app, parse it, compare with what we already have, and write the changes.
Separately, we want **scheduled** application syncs (all apps, once a day in the morning) and **document-library** syncs (every
4 hours during the day, not at night / off-hours) — **maintained in the backend now, exposed as user config later**.

**What already exists (so scope is small):**
- `sync-application` **`mode=delta`** (genesis-workflows v0.2.2, 16-07 Option A) = full re-export + `KbStore.apply(mode='delta')`
  (`_apply_delta`: diff by `diff_hash`, open new / close+reopen modified / **close removed inferred from the re-parse** / diff
  edges / recompute bundles / mark the derived Business Map stale). **This is exactly the requested "full-package, compare,
  write-changes" behavior** — the true *incremental* delta (export only changed objects, needs the Appian changed-objects API
  Genesis doesn't have) stays deferred and **is not needed here**.
- `POST /api/applications/{uuid}/sync` already accepts `body.mode` and threads it to the workflow.
- `sync-documents` `scope="library"` + `POST /api/documents/sync` already refresh the whole library.
- `RunManager.start(workflow_id, inputs, *, environment=None)` is **synchronous** (kicks a subprocess worker, returns a
  run_id) — callable from a background task; `RunManager.list(status=, workflow_id=)` + `.get(run_id)` + `.reconcile_status()`
  support "is a sync already running?" and "wait for terminal."
- App lifecycle: `create_app()` builds `run_manager` / `kb_store` / `config` on `app.state` and has `@app.on_event("startup")`
  / `shutdown` hooks — the scheduler's start/stop home.

**The blockers:** (a) `api/applications.py._start_sync` hard-rejects any non-baseline mode; re-running baseline errors. (b)
There is **no scheduler** anywhere in the codebase (grep-confirmed).

---

## 2. The two capabilities (decided shape)

### A. Full-package refresh (re-runnable app sync) — 23-01
- **Reuse `mode=delta`** (rename the *action* to **"Refresh"** for users; keep the internal `KbStore` mode `delta`, which
  accurately names the *merge*). Accept `mode ∈ {baseline, delta}` at the API and add `refresh` as a **user-facing alias → delta**.
- **Auto-pick the mode:** a tracked app with no `baseline_sync_id` → `baseline`; otherwise → `delta`. (The workflow already
  fails fast if you ask for baseline on a baselined app or delta on an un-baselined one, so the API picks correctly.)
- **Per-app "already running" guard:** if a `sync-application` run for this app is non-terminal, return **409** (manual) or
  **skip** (scheduler) rather than starting a second export — the Appian Deployment API rejects concurrent exports (see §7).
- **(Optional) Web Refresh action** on the app detail page (Overview / Syncs) → `POST …/sync` with the auto-picked mode.

### B. Backend scheduler — 23-02 / 23-03
- **In-process asyncio minute-tick loop** (no new dependency; APScheduler is the fallback if we later want cron strings). Ticks
  every 60 s, asks each enabled job "are you due now?", fires due jobs as separate tasks, records the outcome.
- **Schedule persisted in a DB table** (`scheduled_jobs`, m0012) so it's inspectable and **user-configurable later** with no
  rework; seeded with the two default jobs on boot (`ensure_defaults()`, idempotent — preserves `enabled`/last-run if present).
- **TZ-aware (Asia/Kolkata), weekdays only, daytime slots**, idempotent across restarts (a `last_fired_slot` key includes the
  local date + time so a missed slot can catch up **within the same day** but never re-fires across days).
- **Two jobs:**
  - **`application-sync`** — weekdays **07:00 IST**; iterate `kb_store.list_applications()`; per app kick a **refresh** (delta,
    or baseline if none), **serialized** (start → wait for terminal → next); skip an app whose sync is already running; skip the
    whole job if **no dev-tagged environment** is configured.
  - **`document-library-sync`** — weekdays **08:00 / 12:00 / 16:00 / 20:00 IST**; one `sync-documents` `scope=library` run; skip
    the job if the **`gws` connector isn't connected**.

---

## 3. Sub-phases & build order

| # | Sub-phase | What ships |
|---|---|---|
| **23-01** | **Full-package refresh app sync** | Unblock delta in `api/applications.py._start_sync`; auto-pick baseline/delta; add the `refresh` alias; per-app already-running **409** guard; (optional) a web **Refresh** action. Tests. genesis, no schema. |
| **23-02** | **Scheduler foundation + schedule table** | **m0012 `scheduled_jobs`** + `ScheduleStore`; `runtime/scheduler.py` (minute-tick engine, TZ/weekday/daytime "due" logic, `last_fired_slot` persistence, `ensure_defaults()`); startup/shutdown wiring in `api/app.py`. Fake-clock unit tests. **ADR-047.** |
| **23-03** | **Scheduled jobs + preflight + release** | Register `application-sync` (07:00 IST weekdays, all apps, serialized) + `document-library-sync` (08/12/16/20 IST weekdays, `scope=library`); preflight skips (no dev env / no gws); seed the two rows; release genesis **v0.48.0** + CI + ADR-047 Accepted + bible/tracker/progress. |

**Suggested order:** 23-01 (immediately usable: manual re-runnable refresh) → 23-02 (engine + table, no jobs firing yet) →
23-03 (wire the two jobs + release). All genesis-only; one coordinated **v0.48.0** release at 23-03 (the code may be held for
release like Phase 21/22, or shipped incrementally — decided at build time).

---

## 4. Data model — m0012 `scheduled_jobs`

A single forward-only migration adds **one table** (schema `current_version` 11 → 12). Code-free, no domain data — it holds
the schedule definition + last-run bookkeeping so the scheduler is restart-safe and later user-editable.

```
kb-independent table: scheduled_jobs
  id               INTEGER PRIMARY KEY
  job_key          TEXT NOT NULL UNIQUE      -- 'application-sync' | 'document-library-sync'
  name             TEXT NOT NULL             -- human label
  enabled          INTEGER NOT NULL DEFAULT 1
  schedule_json    TEXT NOT NULL             -- structured spec (see §5); the only "config" surface
  last_fired_slot  TEXT                       -- e.g. '2026-08-17T12:00' (local date+time slot key; NULL = never)
  last_run_at      TEXT                       -- ISO-8601 UTC of the last execution
  last_run_status  TEXT                       -- 'ok' | 'skipped' | 'partial' | 'error'
  last_run_detail  TEXT                       -- short summary, e.g. '12 apps: 11 ok, 1 skipped(running)'
  created_at       TEXT NOT NULL
  updated_at       TEXT NOT NULL
```

`ScheduleStore` (over `genesis.db`, DB-agnostic signatures per ADR-030): `list_jobs()`, `get(job_key)`,
`ensure_defaults(defaults)` (idempotent upsert of definitions — never clobbers `enabled`/last-run), `mark_fired(job_key, slot,
status, detail, at)`, and (for the future config UI) `set_enabled`/`update_schedule`. **Per-app sync history is NOT duplicated
here** — each sync is already a first-class `sync-application` run in `run_events`; the scheduler just records its own last-fire
per job. (A `scheduled_job_runs` history table is deferred — §9.)

---

## 5. Schedule definition (fixed now; the future config payload)

`schedule_json` uses **one uniform kind — `daily_times`** (fixed local times, optionally weekday-only), which expresses both
jobs cleanly ("every 4 hours in daytime" = the explicit list 08→20):

```json
// application-sync
{ "kind": "daily_times", "times": ["07:00"],
  "weekdays_only": true, "timezone": "Asia/Kolkata" }

// document-library-sync
{ "kind": "daily_times", "times": ["08:00", "12:00", "16:00", "20:00"],
  "weekdays_only": true, "timezone": "Asia/Kolkata" }
```

- **Timezone:** `Asia/Kolkata` (IST) — resolved via the stdlib `zoneinfo` (no new dep). All slot math is done in the job's TZ;
  `last_run_at` is stored UTC.
- **Weekdays only:** Mon–Fri (skip Sat/Sun) — decision §11.4.
- **Daytime / off-hours:** encoded directly as the explicit `times` list (no separate "night" flag needed) — the doc job's
  latest slot is 20:00 and there is none overnight; decision §11.1.

---

## 6. API / CLI contracts

**Changed (23-01) — `api/applications.py`:**
- `POST /api/applications/{uuid}/sync` `{mode?: "baseline"|"delta"|"refresh"}` → **remove the `_start_sync` non-baseline guard**;
  resolve the effective mode (`refresh`→`delta`; auto-pick baseline vs delta from `baseline_sync_id` when `mode` is omitted);
  **409** if a `sync-application` run for this app is already non-terminal. Returns `{sync_run_id}` (unchanged shape).

**New (optional, read-only) — scheduler introspection (`api/system` or a small `api/schedules`):**
- `GET /api/system/schedules` → `[{job_key, name, enabled, schedule, last_fired_slot, last_run_at, last_run_status,
  last_run_detail, next_due}]`. Read-only; drives a future Settings panel. (No POST in this phase — "no user config now".)

**CLI (optional, handy for ops):** `genesis sync-now [--app <uuid>|--all] [--documents]` — a thin manual trigger over the same
paths (nice-to-have; not required for the phase). No new scheduler CLI — the scheduler runs inside `genesis serve`.

**No change** to the `sync-application` / `sync-documents` workflows, their inputs, or `genesis-workflows`.

---

## 7. Scheduler engine design (23-02)

- **Home:** `genesis/runtime/scheduler.py` — a `Scheduler` object built in `create_app()` (given `run_manager`, `kb_store`,
  `config`, `ScheduleStore`), started in `@app.on_event("startup")` (`asyncio.create_task(self.run())`) and cancelled in
  `shutdown`. Never blocks boot (all work is in the task; exceptions are caught + logged).
- **Tick loop:** every **60 s** → `for job in store.list_jobs() if job.enabled` → compute the **latest due slot** for *today* in
  the job's TZ (the newest `time` ≤ now); if today is a weekday, now ≥ that slot, and `last_fired_slot != slot` → fire.
  **Restart-safe:** the slot key embeds the local date, so a process that was down at 12:00 and returns at 12:30 still fires the
  12:00 slot, but a return the next day does not re-fire yesterday's slot.
- **Overlap guard:** an in-memory "running jobs" set + the persisted `last_fired_slot` (marked *before* the async work starts)
  prevent a long job from double-firing on the next tick.
- **App-sync job (serialized — critical):** the Appian Deployment REST export is **serialized on the server** — the workflow's
  `_fetch_package_zip` treats **HTTP 409 "a deployment is already in progress"** as transient. So the job kicks apps **one at a
  time**: `run_manager.start("sync-application", {app_uuid, app_name, mode})` → poll `run_manager.get(run_id).status` (via
  `reconcile_status`) every ~5 s until TERMINAL (per-app cap, e.g. 20 min) → next app. Runs in its own task so the tick loop is
  never blocked. Records a per-job summary (`'N apps: X ok, Y skipped, Z error'`).
- **Doc-library job:** a single `run_manager.start("sync-documents", {"scope": "library"})` (no serialization needed — one run).
- **Preflight skips (decision §11.3):** app-sync no-ops with `status='skipped'` if `config`'s `EnvironmentRegistry` has no
  dev-tagged environment; doc-sync no-ops if the `gws` connector isn't connected (reuse the existing readiness checks). Both
  also skip the `sync-documents`/`sync-application` workflow-not-installed case with a logged skip (never a 500).
- **Testability:** the "which slot is due at time T given `last_fired_slot`?" and "which apps to sync / which mode?" functions
  are pure and unit-tested with a fake clock + a fake store; the firing wrapper stays thin.

---

## 8. Security & ADR posture (stated explicitly)

Local single-user, localhost-only (ADR-026). Scheduled syncs are **read-only against Appian** (Deployment REST export) + local
KB/document writes, **`auto_approve`, no HITL gates**, and go through the **same `RunManager.start` a human/copilot uses** — the
ADR-033 "operator at the run-management layer" precedent (ADR-001 intact: LangGraph still owns each sync's control flow). The
new `api/system/schedules` read is local introspection only. **No auto-*apply*** of anything beyond these read-only-source
syncs; sync writes are SCD-2 (reversible history), not destructive. This is recorded as **ADR-047** (§10).

---

## 9. Non-goals / deferred

- **True incremental delta** (export only changed objects) — needs the Appian changed-objects API Genesis doesn't have; stays
  deferred (backlog §1.3). The full-package refresh makes it unnecessary for daily freshness.
- **User-facing schedule config UI** — out of this phase by request; the table + read-only `GET …/schedules` are built so a
  Settings panel drops in later with no schema rework.
- **A `scheduled_job_runs` history table** / per-run audit beyond `last_run_*` — deferred (each sync is already a `sync-application`
  run in `run_events`).
- **Per-application schedules / cron expressions / catch-up-across-days / retries-with-backoff at the scheduler layer** — out;
  `daily_times` + within-day catch-up is enough now.
- **Document sync scheduling per-app** (vs the whole library) — out; the job syncs `scope=library`.
- **A distributed/multi-process scheduler** — N/A (single uvicorn process; ADR-026).

---

## 10. Decision record (ADR-047 — to be added to the decision log on approval)

- **ADR-047 (PROPOSED) — Genesis runs fixed, backend-defined scheduled maintenance syncs.** An in-process asyncio scheduler
  (started with `genesis serve`) runs the Appian **application sync** (all tracked apps, weekday mornings) and the **document
  library sync** (weekday daytime, every 4 h) on a fixed cadence held in a DB table (**m0012 `scheduled_jobs`**), so the
  schedule is inspectable and **user-configurable later** with no rework. These jobs are **read-only against Appian** (the
  Deployment REST export) + local KB/document writes, **`auto_approve` with no HITL gates**, and call the same `RunManager` API
  a human clicks — preserving **ADR-001** (LangGraph owns each sync's control flow) and extending the **ADR-033** "operator at
  the run-management layer" posture to a **non-interactive** actor. **App exports are serialized** (the Appian Deployment API
  permits one export at a time → HTTP 409). Scheduling is **TZ-aware (IST), weekdays only, daytime slots**, and **restart-safe**
  (a persisted per-slot marker). Bounded by local single-user (ADR-026); no network exposure. Also unblocks the existing
  **full-package refresh** app sync (`mode=delta`) at the API — a full re-export + local SCD-2 diff, **not** an environment
  delta-patch (which remains deferred). genesis **v0.48.0** (+ migration m0012).

---

## 11. Decisions (resolved 2026-08-17)

1. **Cadence / TZ.** App sync **07:00 IST**; document sync **08:00 / 12:00 / 16:00 / 20:00 IST** (every 4 h, daytime; none
   overnight). Timezone **Asia/Kolkata**.
2. **Persistence → a DB table** (`scheduled_jobs`, **m0012**) — not a JSON marker. Holds the schedule definition + last-run
   bookkeeping; seeded with the two jobs; the seam for later user config.
3. **Preflight skips → yes.** App sync skips (logged) when no dev-tagged environment is configured; document sync skips when the
   `gws` connector isn't connected.
4. **Weekends → skip.** Jobs run Mon–Fri only.
5. **No user config now** — schedule is backend-fixed; only a read-only `GET …/schedules` introspection is exposed this phase.

---

## 12. Release & test plan

- **Repos:** genesis only. genesis-core / kiro-agent-sdk / genesis-appian-parser / genesis-workflows unchanged.
- **Schema:** **m0012 `scheduled_jobs`** (`current_version` 11 → 12) — the migration + a round-trip test; `genesis db upgrade`
  in the CI clean-install job covers the forward migration.
- **Version:** genesis **v0.48.0** (minor; additive + one migration).
- **Tests:** (23-01) API tests — delta/refresh unblock, auto-pick baseline vs delta, the 409 already-running guard. (23-02)
  fake-clock unit tests for the due-slot logic (weekday/daytime/last-fired-slot, restart catch-up within a day, no cross-day
  re-fire) + `ScheduleStore` round-trip + `ensure_defaults` idempotency. (23-03) app-sync serialization + mode-selection +
  preflight-skip units (mocked `RunManager`/`kb_store`/`config`); doc-sync single-run + skip-when-no-gws. Full existing suites
  stay green; ruff/eslint/tsc clean; `web/static` rebuilt + committed if the optional Refresh action / schedules panel lands.
- **Acceptance (user-driven / observed):** manually `POST …/sync` on a baselined app → a delta run completes and the KB reflects
  changes; leave `genesis serve` running across a scheduled slot (or temporarily set a near-future time) → the app-sync job
  fires once, runs apps serially, and records `last_run_*`; the doc job fires on its 4-hour slots and skips overnight/weekends.
  (Real morning/4-hourly firing is observed over time, as usual for schedule-driven behavior.)
