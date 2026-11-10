# Backlog — Startup stalls on a locked database when scheduled jobs catch up

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-10 from a live fleet restart on v0.81.0 / DB v28.
> · Areas: runs-worker (scheduler, RunManager), distribution (launcher), db. · Related lesson: L-026.

## 1. What the user saw

After `gsm restart`, the main instance (`http://127.0.0.1:8760`, state dir `~/.genesis`) was unreachable for about
four minutes. userb (:8761) came up normally. The user restarted again; main finally started listening at about
12:24:11 IST and has served normally since.

## 2. Timeline (main's log, `~/.genesis/run/genesis.log`, 2026-11-10 IST)

| Time | Event |
|---|---|
| 12:21:09 | pid 28242 starts; lifespan reports `Application startup complete`. The server had been down past the 12:00 slot, so the scheduler fires the due jobs together: `application-sync`, `document-library-sync`, `memory-consolidation`, `regression-run` (`scheduled_jobs.last_run_at` = 06:51:09 UTC for all four). `application-sync` starts run `r-a55a549de969` (`sync-application`), which records `run.started` and nothing after it. |
| 12:21:09 → 12:22:47 | No `Uvicorn running` line: the socket is not listening. `genesis up` gives up after 30 s; userb's restart proceeds at 12:21:43. |
| 12:22:47 | Two `Scheduler._fire()` tasks fail with `sqlite3.OperationalError: database is locked` in `mark_fired` ("Task exception was never retrieved"). Only then does `Uvicorn running on :8760` appear. |
| ~12:22:50 | The user's second restart: 28242 logs `Shutting down` with no `Finished server process`, so `genesis down` killed it. |
| 12:22:52 | pid 28386 starts. The orphaned-run sweep (`RunManager.fail_orphaned_runs`) tries to fail `r-a55a549de969` and gets `database is locked` twice: `claim_status` at 12:23:24 and the `run_events` insert at 12:23:55 (about 30 s each). |
| 12:24:11 | Startup completes; `Uvicorn running`; the site is reachable. |

## 3. Why the site was unreachable

- **Blocking SQLite calls run on the event loop.** The scheduler and the job handlers call the synchronous DB layer
  directly from async code:
  - `genesis/runtime/scheduler.py:202` and `:239`: `self._store.mark_fired(...)` in `tick()` and `_fire()`.
  - `genesis/runtime/sync_jobs.py:148`, `:157` and `:163`: `kb_store.list_applications()`, `is_sync_running()` and
    `start_sync()` inside `async def application_sync()`.
  - `sync_jobs.py:192` (`document_library_sync`) and `memory_jobs.py:79` (`_run`): `run_manager.start(...)`.
  - Only `regression_run` moves its work off the loop (`testexec/regression_job.py:139`, `asyncio.to_thread`, citing
    L-026).
- **Each blocked call can hold the loop for up to 30 s.** `genesis/db/database.py:25` and `:28` set `timeout=30` and
  `PRAGMA busy_timeout=30000`. Several such calls in a row kept the loop busy for about 100 s.
- **Uvicorn starts listening only after startup, on the same loop.** The scheduler's first tick runs as soon as
  `scheduler.start()` (`genesis/api/app.py:367`) creates its task. Because the tick blocks the loop, Uvicorn could
  not bind the port, and every request failed with connection refused.
- **`genesis up` waits only 30 s** (`genesis/runtime/launcher.py:24`, `_START_WAIT_SECONDS = 30`). A slow start reads
  as a failed start, which invites a second restart that kills the slow server in the middle of its work.
- **The startup sweep also blocks.** In 28386 the orphaned-run sweep waited about 60 s on the same lock before the
  app finished starting.

## 4. Open question: who held the lock

Not identified. When this was investigated (12:25 IST) nothing had `genesis.db` open and no Genesis worker process
was alive. Candidates:

- the `sync-application` worker of `r-a55a549de969` (spawned at 12:21:09; it never wrote a second event);
- another connection inside the server process itself: one connection holds a write transaction while a blocking
  call on the loop waits on it, so neither can finish. This is the L-026 deadlock pattern;
- a worker of the killed 28242 that outlived its parent during 28386's startup. `fail_orphaned_runs` notes that "the
  orphaned OS process is not killed (no pid is stored); it exits when its pipe closes".

**When picked up:** reproduce first. Stop main past a slot boundary so several jobs are due, start it, and capture
`lsof` on `genesis.db*` plus `py-spy dump` of the server and any worker while it hangs.

## 5. State it left behind

- Run `r-a55a549de969` (`sync-application`, created 06:51:09 UTC) is still `running` with only `run.started`.
  `ApplicationSyncService.is_sync_running` (`genesis/services/application_sync.py:44`) treats an unfinished
  `sync-application` run as busy, so the scheduled sync skips this app, and Refresh probably refuses too, until the
  run is cancelled or a later restart's sweep fails it.
- `scheduled_jobs.last_run_status` is `running` for `application-sync`, `document-library-sync`, `memory-consolidation`
  and `regression-run` because their final `mark_fired` failed. This only affects display: the in-memory `_running`
  set decides whether a job fires, and the next slots fire normally.

## 6. Directions to consider when picked up

1. Move every blocking DB call in the scheduler and job handlers off the event loop (`asyncio.to_thread`, as
   `regression_run` does). This covers `mark_fired`, `list_jobs` and the handlers' `start_sync` / `run_manager.start`
   paths. The same rule as L-026, applied to the app process.
2. Don't run catch-up jobs inside startup: delay the scheduler's first tick until the server is listening (for
   example, a short initial sleep or a post-startup hook), and/or stagger jobs that are due together.
3. Run the orphaned-run sweep off the loop too, so a locked DB delays the sweep, not the port.
4. Make the final `mark_fired` failure visible and retried: today it is an unretrieved task exception, and the job
   shows `running` for good.
5. Launcher: wait longer in `genesis up` or report "started, still initialising" instead of failing, so a slow start
   does not lead to a kill-and-restart.
6. Consider storing worker pids so a restart can reap a dead parent's workers (L-104 covers this for test runs).

Each item needs a regression test: a held write lock on a test DB while the app starts must not stop
`/api/config/health` from answering within a few seconds.
