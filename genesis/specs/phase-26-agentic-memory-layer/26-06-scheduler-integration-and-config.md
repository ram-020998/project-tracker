# 26-06 — Scheduler integration & configuration

> **Status:** 📋 DRAFT · **Repo:** genesis · **Depends on:** 26-03 (consolidation), 26-04 (maintenance), Phase-23 scheduler · **Unblocks:** 26-07 (release) · **Proposed ADR:** ADR-053 (extends ADR-047)
> **Goal:** Fire the two memory workflows automatically on the **existing Phase-23 scheduler** (no new engine), add the
> **named-user** setting that owns personal memory, and expose a **read-only status** endpoint. Reuses `runtime/scheduler.py` +
> `runtime/schedule_store.py` + **m0012 `scheduled_jobs`** (ADR-047) exactly like `application-sync`/`document-library-sync`.

## 1. Current state (grounded)
- `runtime/scheduler.py` — 60 s asyncio tick; per enabled job computes the due slot (TZ/weekday/daytime), fires as a background
  task, marks `last_fired_slot` before work (restart-safe). `runtime/sync_jobs.py` — `DEFAULT_JOBS` + `register_sync_jobs` +
  handler functions calling `run_manager.start(...)`. `ScheduleStore` over m0012 (`ensure_defaults` idempotent, `mark_fired`).
- Handlers call the same `RunManager.start(workflow_id, inputs)` a human clicks (ADR-001/033 lineage; `auto_approve`, no HITL).
- `config/` holds settings; `api/schedules.py` exposes read-only `GET /api/system/schedules`.

## 2. Design

### 2.1 Two new scheduled jobs (m0012 rows via `ensure_defaults`)
- **`memory-consolidation`** — nightly, default **02:00 IST**, weekdays+weekends (chats happen any day; but keep it after the
  day's activity and **before** the 07:00 `application-sync`). `schedule_json = {"kind":"daily_times","times":["02:00"],
  "weekdays_only":false,"timezone":"Asia/Kolkata"}`.
- **`memory-maintenance`** — weekly, default **Sun 03:00 IST**. Expressed via the existing `daily_times` kind gated by a
  `weekdays`/day filter, or a minimal `weekly` extension to the schedule spec if cleaner (build-time; the table is the config
  seam). 
- Both seeded by `ensure_defaults` (idempotent; never clobbers `enabled`/last-run). **Enabled by default** unless we mirror the
  Phase-23 v0.48.3 caution (ship the heavier job disabled-by-default) — decision at build; lean: consolidation **on**, maintenance
  **on** weekly (both are local + reversible).

### 2.2 Handlers (`runtime/sync_jobs.py` or a new `runtime/memory_jobs.py`)
- `run_memory_consolidation(...)` → `run_manager.start("memory-consolidation", {})` → poll to terminal (single run; no
  serialization needed) → `mark_fired(status, detail=counts)`.
- `run_memory_maintenance(...)` → `run_manager.start("memory-maintenance", {})` → poll → mark.
- **Preflight skips** (logged, `status='skipped'`, never a 500): skip if **Kiro isn't signed in** (`kiro_auth` status — the jobs
  need the agent), if the **workflow isn't installed** (`genesis install` not run — the §7 "install first" lesson), or (for
  consolidation) if there are **no new sessions** since the cursor.

### 2.3 Named-user setting (personal-memory owner)
- Add a **`memory_owner_username`** setting (Settings → General, or a small `config/memory.py`) — the named user personal
  memories are tagged with (decision §11.6). Defaults to the OS user / a `"local"` fallback if unset. Threaded to: the
  consolidation workflow (as an input, so extraction tags `owner`), and the `genesis-memory` MCP (`--owner`, so personal reads are
  scoped). Single-user today; the seam is the future multi-user split.

### 2.4 Read-only status
- `GET /api/system/memory` → `{owner, memory_db_version, counts:{entities, memories_by_type, relationships, communities},
  last_consolidation_at, last_maintenance_at, embedding_status_counts}` — local introspection for a future Settings "Memory"
  panel (no config/write in v1; mirrors the Phase-23 read-only schedules endpoint).

## 3. Files & tests
- **New/edit (genesis):** `runtime/memory_jobs.py` (or extend `sync_jobs.py`) + `DEFAULT_JOBS` rows; `config` memory-owner
  setting; `api/system`/`api/schedules` status; boot wiring (the scheduler already starts in the lifespan). `genesis db upgrade`
  upgrades **both** DBs (26-01). Tests.
- **Tests:** reuse the Phase-23 **fake-clock** due-slot units for the new slots (nightly 02:00; weekly Sun 03:00; restart-safe,
  no cross-day re-fire); preflight-skip units (no Kiro / workflow-not-installed / no-new-sessions) with mocked
  `RunManager`/`kiro_auth`/`chat_read`; the owner setting is threaded to the workflow input + MCP `--owner`; `GET /system/memory`
  shape. Full suites green.

## 4. Acceptance criteria
1. `memory-consolidation` (nightly) + `memory-maintenance` (weekly) are registered on the existing scheduler, preflight-skip when
   unconfigured, and record `last_run_*`.
2. Personal memory is owned by the configured named user, threaded to both the write path and the MCP read path.
3. `GET /api/system/memory` returns local status; no user-facing config beyond the username in v1.
4. genesis pytest + ruff green; the schedules/config additions don't regress Phase-23 tests.

## 5. Out of scope
- A schedule-config UI + a memory-browser (follow-ups); per-user schedules (multi-user track).
