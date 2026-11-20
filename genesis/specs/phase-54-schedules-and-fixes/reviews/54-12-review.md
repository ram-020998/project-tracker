# Review 54-12 — base 2ad1c50, head 34b3e69 (genesis-review, 2026-11-20)

What this change does: the fix pass for 54-10 round 1 and the user's six D50 A1 changes. genesis-core
`program_node` runs its step on a worker thread (B1). The scheduler, notification store and run stop status retry a
busy database, and `reconcile_status` adopts a terminal `run.final` even while a worker is tracked. A pause that
cannot be stored answers 503 (m5). Agent-written read-only HTML gets `script-src 'none'` + nosniff, and the clause
highlight moves to CSS `:target` (M1). The minors m1–m4 and m6 are fixed, plus nits n1–n4. On the web: a shared
`SearchInput` and `DataTable` (Runs and Schedules), the bell's Remove / Clear read with two new routes, and the
Objects changed Type column sized from a real-browser probe (M2).

Repo genesis only (genesis-workflows unchanged). The 9 commits named in the brief exist: `076604e` … `34b3e69`.
`genesis-ctx check --since 2ad1c50 --repo genesis` lists 117 files, of which 52 are outside `web/static`.

## The six points asked for

1. **B1: no program step relies on the event loop. OK.** `program_node` is used in 112 places across both repos.
   - No program fn calls `interrupt(`. The only one is `gate.py`, its own node.
   - None calls `get_event_loop`/`get_running_loop`/`create_task`. `kb/dev_mcp.py`'s `asyncio.run` and its private
     loop thread work from any thread.
   - Every async step in the workflows already wraps its sync work in `to_thread`.
   - No connection is shared across threads. Every `sqlite3.connect` opens per call: `db/database.py:73`,
     `memory/vector.py:57,222,235`, and the MCP servers' read-only connections.
   - `get_stream_writer()` is thread-safe: LangGraph's async stream puts through `aioloop.call_soon_threadsafe`
     (`langgraph/pregel/main.py:3160`). `ctx.emit` → `worker._emit` is now under `_EMIT_LOCK` (`runs/worker.py:41-50`).

   **`retry_when_busy`: it wraps a single transaction, with one exception.** Every decorated method is one
   `with self._db.tx()` and is never called inside another transaction. `claim_status` is a CAS `UPDATE` (re-run
   safe). The exception: `create_user`, `update`, `reset_system` and `set_pause` read `self.get(...)` after their
   transaction, inside the retried function. See n-3.
2. **Reconcile of a terminal `run.final` with a tracked worker. OK.** `_finalize` stores the status before it
   announces (L-093), and `_resumable` refuses a terminal run. So a terminal marker beside a non-terminal record means
   only "the status write failed". A gate marker with a tracked worker is still left alone (`manager.py:469-474`).
   Tests: `test_a_run_whose_terminal_status_was_never_stored_is_reconciled_from_its_run_final` and
   `test_a_gate_marker_is_not_adopted_while_the_runs_worker_is_tracked`.
3. **Missed reason from tick continuity. OK.**
   - Startup, a sleep longer than 3 tick periods, or a clock that went backwards resets `_up_since`.
   - A failed tick still sets `_last_tick_end` in the `finally`, so it does not break continuity.
   - A non-owner server never ticks. So after taking over, its first tick resets `_up_since`, and slots the peer
     owned read "not running". That is acceptable.
   - Tests cover all-up and a real gap. The mixed notice text (`scheduler.py:334-336`) has no test (nit n-4).
4. **m1 records missed + completes on Resume, while 9a365c0 refuses turn-on. OK, consistent.** An off schedule was
   never due. A paused one was due and held, so recording the slot missed is accurate, and Resume's "covered up to
   now" already drops paused slots of recurring schedules.
   - A Resume inside the grace window also counts as missed rather than firing. That matches the recorded reason
     "the schedule was paused at its time".
   - A completed once that is resumed stays completed and records nothing (`schedule_store.py:465`).
   - Test: `test_54_12_m1_resuming_a_paused_once_after_its_time_records_it_missed_and_completes_it`.
5. **M1 scriptless highlight. OK.** The anchor is render-only, and it is skipped when the block or its host already
   carries the id (`spec_clauses.py:578`; `test_an_existing_id_equal_to_the_clause_id_is_not_duplicated`). The probe
   proves CSP is on, 0 scripts, `:target` outline and the scroll (`evidence/54-12/probe-output.txt`, m1-clause-link).
   The stage artifacts lose no behaviour: the workflows' only `<script>` blocks are `type="application/json"` data
   blocks, which the CSP does not touch. The pulled frame's SDK loads and posts `lavish:` messages from origin `null`.
   `PulledStageView` listens to nothing, so no origin check breaks. Nit n-1 concerns the badge script.
6. **DataTable own-action/portal rule and Runs on it. OK, with an a11y minor.**
   - `ownAction` (`shared/ui/data-table.tsx:37-42`) skips anything a portal rendered: React bubbles portal events, and
     `!row.contains(target)` catches them. It also skips any `a`, `button`, `input`, `[role=switch|menuitem|…]`
     inside the row.
   - Enter opens the row only when the row itself has focus.
   - Runs keeps its Copy/Pause/Cancel/Open buttons, and a click in an Actions-cell gap now opens the row, which D50 3
     asks for.
   - The attention tint `bg-warning-subtle/30` was a no-op: Tailwind cannot apply an opacity modifier to a `var()`
     colour. The new `bg-warning-subtle` is a visible change on Runs that was not probed (Not checked).
   - Minor m-1: the rows have no role or name.

## Checklist

ADRs
- [OK] ADR-001 — no control flow moved to an agent. `program_node` is still a LangGraph node (`program.py:26-34`).
- [N/A] ADR-002, ADR-004, ADR-020 — no ACP/MCP injection change.
- [N/A] ADR-003, ADR-007, ADR-008, ADR-013 — no distribution/role/config-UI change.
- [OK] ADR-009 — pause/resume kept. Pause now refuses honestly (503) when it cannot be stored (`run_routes.py:176-183`).
- [OK] ADR-010, ADR-018, ADR-022 — no state or blackboard change. `program_node` still returns the small partial update.
- [OK] ADR-011 — reliability lint passes in `validate_library` ("reliability lint correctly fails the non-compliant fixture").
- [OK] ADR-012 — the step runs in the worker subprocess, and the app imports no workflow Python. The real-worker test is
  `test_a_real_worker_whose_program_step_blocks_5_s_leaves_the_write_lock_free`.
- [OK] ADR-017 — Python only.
- [OK] ADR-019 — public signature unchanged (`program_node(*, name, fn)`), `CORE_MAJOR` 1, additive behaviour. All 463
  workflow tests run on the new node (1 load-flaky test, see Gates).
- [N/A] ADR-021, ADR-025, ADR-062, ADR-068 — no gate, fork or mutation-lane change.
- [N/A] ADR-023 — still embedded FastAPI.
- [OK] ADR-024 — async-first kept: `AsyncSqliteSaver` unchanged, and the sync step leaves the loop via `to_thread`.
- [OK] ADR-026 — no auth or bind change.
- [OK] ADR-027 / ADR-055 — shared primitives (`SearchInput`, `DataTable`, `SegmentedControl`) and tokens only. Grep
  of the added web lines finds no hex, no opacity modifier and no `asChild`.
- [OK] ADR-028 — the new routes are under `/api` (`/notifications/{id}` DELETE, `/notifications/clear-read`). The client
  adds no prefix in components (`lib/api/notifications.ts:18-21`).
- [N/A] ADR-029, ADR-031, ADR-033, ADR-034, ADR-045, ADR-086 — no trust, chat or skills change. m2 keeps agent-prompt
  server checks on one path (`schedule_routes.py:189-194`).
- [OK] ADR-030 — still SQLite. The repository signatures are unchanged apart from added methods.
- [N/A] ADR-032, ADR-035, ADR-036, ADR-037, ADR-039, ADR-041, ADR-042, ADR-044, ADR-046, ADR-049, ADR-050, ADR-051,
  ADR-053, ADR-054, ADR-056–ADR-061, ADR-063–ADR-067, ADR-069–ADR-074, ADR-076–ADR-084 — untouched by this diff
  (no credits, KB, stage-lifecycle, story, Hub, test-exec, memory or packaging logic changed).
- [OK] ADR-043 — the SDK still runs in the annotatable frames. The pulled frame is now `sandbox="allow-scripts"`, and
  the probe shows the SDK loading and posting.
- [OK] ADR-047 — the system schedules stay backend-defined. m4 is a read fallback only.
- [OK] ADR-075 — `data-cid` untouched. The anchor is a render-only child; the stored HTML is unchanged.
- [OK] ADR-085 — reports origin untouched. The verification report keeps its headers via the constant
  (`workbench.py:523`).

Lessons
- [OK] L-026 — the core of B1. `test_a_blocking_program_step_does_not_hold_the_write_lock` fails on the old code
  (evidence in As built).
- [OK] L-091 — `NotificationStore.remove` and `set_pause` validate under `BEGIN IMMEDIATE` / `_locked`
  (`notifications.py:101`).
- [OK] L-093 — terminal store-then-announce is kept. The reconcile relies on it.
- [VIOLATION] L-107 / L-108 — a pause that fails to store leaves the worker's events dropped, so a run that dies in that
  window never reaches a terminal state (Major M-1).
- [OK] L-109 — `status_outcome` is the one status → outcome rule, used by the engine and by the m4 fallback
  (`scheduler.py:73`, `schedule_routes.py:145`).
- [OK] L-096 — `clear-read` is registered before `{id:int}`, and the route-order test is updated
  (`test_schedules_api.py`).
- [OK] L-094 — callers of the changed functions were grepped: `reconcile_status` (10 callers, all read-time and
  tolerant), `claim_status` (4), `program_node` (112), `_last_run` (list + detail).
- [OK] L-083 — the fixtures come from real responses (`notification-cleared.json`, re-recorded `schedule-pickable.json`).
  The probe seeds story 74's real objects.
- [OK] L-090 — the column widths come from a real-browser probe at 1280/1440/1920 in both themes (48 views clean). I
  checked `story74-objects-1280-light.jpg`: no overlap.
- [OK] L-089 — the `web/static` commits are separate (`bdac951`, `34b3e69`). My out-of-tree build is IDENTICAL.
- [OK] L-014 — jest-axe on the changed views (schedules, bell, agents), with no new ambient typings.
- [OK] L-069 — no `asChild` added. The Tooltip's internal `TooltipTrigger asChild` is the Radix primitive, not `Button`.
- [OK] L-010 / L-028-family — the client handles 204 (an empty body parses as null, `client.ts:66`).
- [OK] L-011 — `phase54-contract.test.ts` covers the two new routes from the fixtures.
- [OK] L-043 — postMessage host reuse; no SDK server.
- [OK] L-068 — `index.html` is still `no-cache`; n2 only hides the catch-all from OpenAPI (`app.py:443`).
- [OK] L-030 — the diff touches `web/**`, so the frontend CI job runs.
- [OK] L-020, L-022, L-065 — no graph state or recursion change.
- [N/A] L-001, L-002, L-005–L-009, L-012, L-013, L-015–L-019, L-021, L-023, L-025, L-027, L-031, L-033, L-034, L-039,
  L-041, L-042, L-044, L-045, L-048, L-050, L-051, L-055–L-064, L-066, L-067, L-071–L-076, L-081, L-082, L-084–L-088,
  L-092, L-095, L-097–L-106, L-110–L-119 — untouched area or no release in this sub-spec. One exception: L-111 applies
  and is honoured by D46's re-run on the copy (not part of this code review).

Gates (run by me at 34b3e69)
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **2118 passed** in 721 s, 15:55–16:08 IST
  (outside 00:00–02:00).
- [OK] `ruff check genesis` → All checks passed.
- [OK] genesis-core pytest → **124 passed**. `ruff check genesis_core` → clean.
- [OK] genesis-workflows `validate_library.py` → PASSED (19).
- [OK] genesis-workflows pytest → 462 passed + 1 failed under load, which **passes alone** (2 passed). The failure was
  `action-capture …::test_a_typecheck_timeout_kills_the_whole_group[True]`, run while the genesis pytest ran. It
  calls `ac.typecheck` directly with a 1 s timeout, not through `program_node`, so it is unrelated to this diff.
- [OK] web `npm run lint` → 0 errors (20 old warnings). `npm run typecheck` → clean. vitest → **905 passed (81 files)**.
- [OK] stale bundle: `vite build --outDir /tmp/r5412-static` then `diff -r … web/static` → IDENTICAL.
- [N/A] playwright-appian gates — repo not changed.

## Findings

### Blockers
None.

### Majors
- M-1 **A pause that cannot be stored drops the worker's events, so a run that dies meanwhile stays `running`
  forever** (`genesis/runs/manager.py:385-393`, with `on_event`/`on_exit` at `:216-220`, `:279-280`).
  - What: `pause()` marks `seen["stop"]=PAUSED` first, then calls `store.claim_status`, which now retries for up to
    4 × 30 s busy timeout + 1 + 2 + 4 s ≈ 127 s. Only after that does it clear the mark on failure. While the mark is
    set, `on_event` and `on_exit` return early for **every** worker event.
  - Problem: a lock held long enough to defeat every retry also defeats the worker's own checkpoint write. Its
    `AsyncSqliteSaver` has `busy_timeout=30000` (`runtime/checkpoint.py:32`), so after about 30 s the worker raises
    "database is locked", prints `error` and exits non-zero.
  - All three of those events land inside the window and are dropped. Then `pause` raises `RunStopNotStored`, the
    route answers 503 "the run is still running", and the record stays `running`. No worker and no `run.final` remain,
    and `reconcile_status` has nothing to adopt. The run is lost until a restart's `fail_orphaned_runs`, or a schedule
    time limit cancels it.
  - This is the outcome 54-12 §1.1 lists to prevent ("a run stored `running` after it failed"). Lost `node.completed`
    events also leave gaps in the timeline even when the worker survives.
  - The m5 tests use `_FakeWorker`, which emits nothing, so they cannot see this.
  - Fix: store first, then mark, then kill: `claim_status(PAUSED)` → `_intend_stop(PAUSED)` → `kill()`. On failure,
    raise without marking. The mark still precedes the kill (L-108). A terminal event that races the claim then goes
    through `_finalize`'s CAS, which overwrites `paused` as it should. Add a test: hold the lock past the retries,
    feed an `error` event and `worker_exit` through the spawned handlers during the claim, then assert one
    `run.final{failed}` and status `failed` once the lock is released (or `reconcile_status` adopts it).
  - If skipped: under the busy database B1 is about, a pause can turn a failing run into a permanent ghost `running`
    run, and the API reports it as still running.

### Minors
- m-1 **Clickable rows have no accessible role or name, and Schedules lost its only link** (`shared/ui/data-table.tsx:46-63`,
  `SchedulesPage.tsx:55`).
  - What: the schedule name was a `<Link>` and is now plain text. The row is a `<tr tabIndex=0>` with no `role` and
    no `aria-label` (neither caller passes one).
  - Problem: a screen-reader user tabbing through Schedules lands on an unnamed, roleless focus stop with nothing
    saying it opens anything. Before, they reached a named link. jest-axe does not flag a focusable `tr`, so the tests
    stay green.
  - Fix (smallest): keep the name as the `<Link to=/schedules/:id>`. `ownAction` already lets an `a` handle its own
    click, so the whole row and Enter still work. Alternatively, pass `aria-label={s.name}` / the run id to
    `DataTableRow`.
  - If skipped: an a11y regression on a page that had none.

### Nits
- n-1 **The read-only spec still injects the coverage badge script, which its own CSP then blocks**
  (`spec_clauses.py:590`, `features.py:711`). `annotate=0` keeps `coverage=1` by default, so a spec with stories gets
  `genesis-clause-overlay-js` and a CSP console error on every load. The probe's spec had no coverage
  (`"scripts":0`). Fix: call `_with_overlay(…, coverage if annotate else 0)`, or leave the script out when
  `annotate=0`; the badges then render without a dead handler.
- n-2 **The bell has no error feedback** (`NotificationBell.tsx:57-60`). A failed Remove or Clear read (a 409 race, a
  busy 500) does nothing visible. Fix: `onError: (e) => toast.error(…)`, as other mutations in the app do.
- n-3 **Some retried methods read after their write** (`schedule_store.py` `create_user`/`update`/`reset_system`/`set_pause`).
  The trailing `self.get()` sits inside the retried function. A busy error on that read (rare under WAL) would re-run
  a committed write, and for `create_user` that creates a duplicate schedule. Fix: decorate an inner `_write()`
  holding only the `with tx()` block, or return the row from inside the transaction.
- n-4 **No test for the mixed missed notice** ("Genesis was not running, or could not start it…"). It is the
  `any(up) and not all(up)` branch at `scheduler.py:334-336`.
- n-5 **`Scheduler.start()` runs the retried `ensure_defaults` on the event loop** (`scheduler.py:156`). With retries,
  startup can block for about 127 s on a locked database (it was 30 s). Fix: `await asyncio.to_thread(...)` from an
  async start, or call it undecorated there (its failure is already caught and logged).

The deferred nits n5 (provisioned `.kiro/` files in the run documents list) and n6 (ADR-087 draft) are listed in
As built. I agree they are out of scope here.

## Not checked
- The Runs page in a real browser after it moved to `DataTable`: the attention tint now applies (the old `/30` class
  was a no-op), and the `overflow-hidden` → `overflow-x-auto` change. The probe covered Schedules, app-sync, Objects,
  the bell and Agents, not Runs.
- The 54-10 live rows on the copy (D46: A1 for the six D50 changes, A2, A7, A9, A12, A14, A15, A17). This report is
  the code review. The live re-run comes after M-1 is fixed, on `/tmp/g5410` :8790, with the user's go-ahead at each
  HITL gate.
- A real 2-minute lock against a real worker, to show M-1 end to end. The finding follows from the code paths and
  `checkpoint.py:32`; I did not run it.

## Verdict: NEEDS_CHANGES
Fix M-1: in `pause()`, store the pause before marking the stop, and add the regression test described. Also fix m-1
(keep the name link, or give the row a name). The nits are optional. Every gate is green at 34b3e69; the
genesis-workflows failure is a load-timing flake that passes alone.

---

# Round 2 — 34b3e69 → 9980b0c (genesis-review, 2026-11-20)

The four commits named in the brief exist (`2ee4cb9`, `90d6122`, `5c50bab`, `9980b0c`); HEAD is `9980b0c` and the
tree is clean. `genesis-ctx check --since 34b3e69 --repo genesis` lists 78 files, 13 of them outside `web/static`:
`api/features.py`, `kb/spec_clauses.py`, `runs/manager.py`, `runtime/schedule_store.py`, `runtime/scheduler.py`, the
probe, two test files, and five web files. Areas: api, browser-testing, features-stages, release-ci, runs-worker,
security, web-runs. `packages/` is unchanged since 34b3e69.

## The round-1 findings

- **M-1: fixed and proven.** `pause()` now calls `store.claim_status(PAUSED)` first, and calls `_intend_stop(PAUSED)`
  and `kill()` only after the claim succeeds (`runs/manager.py:385-398`). If the claim fails, the run is never marked,
  so the worker's `error`, `worker_exit` and `on_exit` still go through `_finalize`.
  - The mark still comes before the kill (L-108), so a SIGTERM exit after a successful pause is still ignored.
  - In the window after the claim succeeds and before the mark, each worker event still has a correct outcome:
    - A terminal `final` or `error`: `_finalize`'s CAS (`store.py:139-155`, `status NOT IN terminal`) overwrites `paused`.
    - A death: `worker_exit` fails the run. `on_exit` sees `paused` rather than `running` and does nothing, which is
      correct.
    - A `node` event: `note_progress` leaves `paused` in place.
    - A gate `final`: the run moves to the gate status. That is a real stop, and the gate answer resumes it.
  - `pause()` has one caller (`api/run_routes.py:180`).
  - **Fail-first check I ran myself.** I exported 9980b0c to `/tmp/r5412-old` (outside the repo) and put back the
    old order (mark → claim → unmark on failure). With `PYTHONPATH` pointed at that copy,
    `test_a_worker_that_dies_while_its_pause_cannot_be_stored_still_fails_its_run` **fails**
    (`assert … == S.FAILED`, got `running`). On HEAD it passes. It feeds the events through the real `_spawn`
    handlers and asserts exactly one `run.final{failed}`. This is the regression test round 1 asked for.
- **m-1: fixed.** The schedule name is a `<Link to=/schedules/:id>` again (`SchedulesPage.tsx:56-58`). `ownAction`
  leaves an `a` to handle its own click. `schedules.test.tsx` asserts the link's name and `href="/schedules/6"`.
- **n-1: fixed.** `overlay_labels(…, interactive=False)` keeps the `gn-cov` badges and drops `_OVERLAY_SCRIPT`
  (`spec_clauses.py:592`). Both `annotate=0` paths pass `interactive=bool(annotate)` (`features.py:712`, `:1542`).
  `test_the_read_only_spec_keeps_its_story_badges_without_their_dead_script` asserts that the badges are present and
  `<script` is absent read-only, and that the script is still present in the annotatable copy.
- **n-2: fixed.** Remove and Clear read both call `toast.error` on failure (`NotificationBell.tsx:60`, `:91`). The new
  bell test covers Remove only (nit r2-n2).
- **n-3: fixed where it mattered.** Only `_insert_user`'s transaction is retried, and the read-back sits outside the
  retry (`schedule_store.py:354-378`). The test fails the first `get()` and asserts one schedule. `update`,
  `reset_system` and `set_pause` still read back inside their retry. A re-run of those writes is idempotent:
  - `update` writes the same values.
  - `set_pause` on a once that is already completed skips its insert (`:475`).
  So that remainder is acceptable.
- **n-4: fixed.** `test_a_mixed_gap_notice_says_both` asserts both recorded reasons and the notice text.
- **n-5: fixed.** `Scheduler.start` calls `ensure_defaults.__wrapped__` once (`scheduler.py:156-160`).
  `retry_when_busy` uses `functools.wraps` (`db/database.py:46`), so `__wrapped__` exists. Every `Scheduler(...)` in
  the app and the tests gets a real `ScheduleStore`, and a failure is still caught and logged.
- **Round-1 Not-checked: Runs page on `DataTable`. Now checked.** `5c50bab` removes the row tint, so the page matches
  the approved one: the old `/30` class never applied. The probe now covers `runs-list` and `runs-row-focus` at
  1280/1440/1920 in both themes, and all 12 views are OK (`evidence/54-12/probe-output.txt` lines 7–58). I viewed
  `runs-list-1440-light.jpg` and `runs-row-focus-1440-dark.jpg`. The rows are untinted, the focus ring is visible on
  the focused row, Review/Stop/Open stay in the Actions column, and nothing overlaps.

## Checklist (round 2 delta; every other line stands as answered in round 1)

- [OK] ADR-009 — pause and resume are kept. The order change keeps "pause = kill, resume = fresh worker". A pause that
  fails to store still answers 503 (`run_routes.py:181-183`).
- [OK] ADR-012 — no workflow import in the app; the worker is untouched.
- [OK] ADR-027 / ADR-055 — the Link uses tokens only (`text-fg hover:text-primary`). The removed tint takes away a class
  and adds none. `toast` is the shared primitive.
- [OK] ADR-028 — no new routes or URLs. The bell's errors come from the existing hooks.
- [OK] ADR-043 — the annotatable copy keeps the SDK and the overlay script. The probe's pulled frame still posts
  `lavish:` messages.
- [OK] ADR-075 — `data-cid` is untouched. `interactive` only changes the injected `<script>`.
- [OK] ADR-047 — the system defaults are still seeded at boot, now in one attempt.
- [N/A] ADR-001, 008, 010, 011, 018, 019, 021–026, 029–035, 037, 041, 042, 044–046, 049, 050, 054, 056–069, 071–078 and
  the remaining ids the check lists — no logic in their area changed in 34b3e69..9980b0c.
- [OK] L-108 — the stop is marked before the kill, and every terminal write is still the CAS. Regression test above.
- [OK] L-107 — the round-1 violation is cleared: a run whose worker dies during a failing pause reaches `failed` with one
  `run.final`.
- [OK] L-093 — store-then-announce is unchanged (`_finalize` → `_claim_status` → `_announce_final`).
- [OK] L-091 — `_insert_user` still validates under `BEGIN IMMEDIATE` (`schedule_store.py:370-372`).
- [OK] L-094 — the callers were grepped: `pause` (1, `run_routes.py:180`), `overlay_labels`/`_with_overlay` (the two
  annotate paths plus the default), `create_user` (routes and `duplicate`, both use the return value),
  `ensure_defaults` (boot plus tests), `isAttention` (no callers left, see r2-n1).
- [OK] L-089 — the bundle commits are separate (`90d6122`, `9980b0c`).
- [OK] L-090 — the Runs view is now probed in a real browser at 3 widths × 2 themes.
- [OK] L-014 — jest-axe still runs on the bell and schedules tests; no new ambient types.
- [OK] L-030 — the diff touches `web/**`.
- [N/A] the other lessons — same as round 1.

## Gates (run by me at 9980b0c)

- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **2122 passed** in 688 s, 16:51–17:03 IST.
- [OK] `ruff check genesis` → All checks passed.
- [OK] `tests/test_busy_database.py` + `tests/test_read_only_html_headers.py` → 20 passed.
- [OK] web `npm run lint` → 0 errors (the same 20 old warnings). `npm run typecheck` → clean. vitest → **906 passed
  (81 files)**.
- [OK] stale bundle: `vite build --outDir /tmp/r5412b-static`, then `diff -r … web/static` → no differences.
- [N/A] genesis-core — `packages/` is unchanged since 34b3e69 (124 passed in round 1).
- [N/A] genesis-workflows — that repo is unchanged, and nothing it calls changed in this round (463 per the author;
  462 + 1 load flake by me in round 1).

## Findings (round 2)

### Blockers
None.

### Majors
None.

### Minors
None.

### Nits
- r2-n1 **`isAttention` is now dead** (`web/src/features/runs/hooks.ts:16-18`). Its only caller was the removed tint, so
  `git grep isAttention` finds only its definition. `noUnusedLocals` does not catch an unused export. Fix: delete it.
- r2-n2 **Only the Remove toast is tested** (`bell.test.tsx`, "review n-2"). The Clear read `onError`
  (`NotificationBell.tsx:91`) has no test. Fix: add a second case that answers `/api/notifications/clear-read` with
  a 500 and asserts `toast.error` with "Could not clear".
- r2-n3 **The 503 text can be wrong in the M-1 corner case** (`run_routes.py:182`). When the worker dies during the
  failing pause, the run is now `failed`, but the 503 still says "the run is still running". The UI refetches the run,
  so the page soon shows the truth. Fix (optional): word it as "the pause was not recorded (the database is busy). Try
  again."

## Not checked
- The 54-10 live rows on the copy (D46): A1 for the six D50 changes, A2, A7, A9, A12, A14, A15, A17. That is the live
  re-run on `/tmp/g5410` :8790, with the user's go-ahead at each HITL gate. Per the brief, it is not part of this round.
- A real two-minute lock against a real worker. The fix is proven through the real `_spawn` handlers with the claim
  failing, not end to end.
- The throwaway probe homes `/tmp/p5412/a,b`. I did not restart them; I relied on the committed evidence and two
  screenshots I viewed.

## Verdict: SHIP
M-1 is fixed in the right order, and its regression test fails on the old code (I checked this myself). m-1 and n-1
to n-5 are fixed, and the Runs page has now been checked in a real browser. Every gate is green at 9980b0c. The three
nits are optional.
