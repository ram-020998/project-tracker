# 54-12 — Fix pass: 54-10 review round 1 and the user's A1 changes

> **Status:** BUILT 2026-11-20, review SHIP (round 2; see As built). Repos: genesis (`packages/genesis-core`, `genesis/runtime/`, `genesis/api/`,
> `web/`), genesis-workflows only if a nit needs it. Parent: `specs/phase-54-schedules-and-fixes.md`. Built by
> **genesis-dev** between 54-10's round 1 (`reviews/54-10-review.md`, NEEDS_CHANGES) and its re-review (D51). Decisions:
> D48, D49, D50 (`54-01-findings.md` §8). Each item gets a regression test that fails on the old code. Afterwards
> genesis-review re-reviews the diff and re-runs the affected 54-10 live rows on the copy (D46), then 54-11.

## 1. Review findings (`reviews/54-10-review.md` round 1)

1. **B1 (D49) — a blocking program step holds `genesis.db`'s write lock.**
   - genesis-core `program_node` (`packages/genesis-core/genesis_core/nodes/program.py`) runs the step off the worker's
     event loop, so no write transaction stays open across a blocking call. Public API unchanged, `CORE_MAJOR` 1
     (ADR-019); every existing workflow's tests pass unchanged. Test: a 5 s blocking step while a second connection
     writes; the write succeeds within its timeout (L-026).
   - The scheduler survives a busy database: its connections use a `busy_timeout`, and a write that still meets
     "database is locked" is retried with a bounded wait. A busy write never becomes a lost slot, a false `missed`
     "Genesis was not running", a pause answered 200 that did not take (m5), or a run stored `running` after it failed.
     One test per outcome, with the lock held by a second connection (L-091, L-107, L-108).
2. **M1 (D48) — three older paths run agent-written HTML on the app's origin.**
   - A teammate's pulled stage artifact: its annotation frame gets `sandbox="allow-scripts"` without
     `allow-same-origin`. The sandboxed frames already throw a `localStorage` `SecurityError`; if the annotation SDK
     (ADR-043, L-043) cannot work in that sandbox, **stop and ask** (fallback: the risk named in the release notes).
   - The change-request document and the spec-clause link: served with `Content-Security-Policy: script-src 'none'`
     and `X-Content-Type-Options: nosniff`. The read-only spec's own clause scripts stop running: the `#clause` jump
     keeps working, the highlight does not. Keep the highlight without a script in the document (for example drawn by
     the host page), or **ask** before recording it as a known limit.
3. **M2 —** the story Objects changed table's type column ("Record Type Relationships") overlaps the Action tag at
   1280, 1440 and 1920 px, both themes. Fix from a real-browser probe (L-090) with real story 74's data.
4. **m1 —** Resume of a hand-paused `once` past its time leaves it Active forever. Apply 9a365c0's rule on Resume too:
   record `missed` and mark it completed.
5. **m2 —** a workflow-type schedule that targets `agent-prompt` skips the read-only server check at save. Route it
   through `check_picks` (D33), or refuse `agent-prompt` as a workflow-type target and point to the agent-prompt
   target; say which in As built.
6. **m3 —** idle time is lost when a run leaves a gate and finishes between two ticks (a real 18-minute wait recorded
   as 0). Compute it from stored state (D31).
7. **m4 —** after m0030 every system schedule shows "Never run" although its last run is stored. Carry the stored
   `last_run_*` into `last_run` with one reader (L-109): a data step in the unreleased m0030 (re-check the fleet is
   still at v29 first, D36) or a read fallback; say which.
8. **m5 —** Pause answers 200 when its status write fails: answer the failure (with item 1).
9. **m6 —** the application-sync detail's table headers wrap at 1280 and 1440 px. Fix from the probe.
10. **Nits** in the report: take or defer each, and list the deferred ones in As built.

## 2. The user's A1 changes (D50)

The user compared the built pages with the approved mockup (54-10 A1): every surface matches except these.
1. **Schedules filters and search:** reuse the Runs page's filter pills and search box (the same components, not a
   copy). Filters stay All · System · Mine · Paused · Failing; search matches the schedule name and its target's name.
2. **Schedules grid:** reuse the Runs table's grid style. Remove the line above the grid ("System schedules can't be
   deleted…"); the lock icon and its "System schedule" tooltip stay (amends D22).
3. **Whole row clickable:** a row opens its schedule, as on the Runs page. The on/off switch, the last-result tag link
   and the row menu keep their own actions and do not open the row. The row is keyboard-reachable and Enter opens it.
4. **Remove read notifications:** each read notice has a **Remove** (×) control and the panel has **Clear read**; an
   unread notice cannot be removed. Backend: `DELETE /notifications/{id}` (409 for an unread notice, 404 unknown) and
   `POST /notifications/clear-read` → `{removed, unread}`. Add both to 54-06's contract table, the web client and a
   fixture.
5. **Application sync detail:** remove the Edit button from the Sync options card; the top Edit stays (D25).
6. **Catalog → Agents search:** the same search box as the Workflows and Skills tabs, matching name and description.

## 3. Tests and checks

Each item above has a test that fails on the old code (record the fail-first evidence). Web: Vitest with fixtures in
real shapes (L-083); jest-axe on the changed views (L-014); a userEvent keyboard test for the clickable row (the
switch and menu must not open it). Real-browser probe (L-090) at 1280 / 1440 / 1920, light and dark, on a throwaway
home (never the fleet, and not the 54-10 copy while genesis-review uses it), for: the Schedules list, the application-
sync detail, the Objects changed table, the bell with Remove / Clear read, and Catalog → Agents. Screenshots under
`specs/phase-54-schedules-and-fixes/evidence/54-12/`.

## 4. Gates

genesis-core pytest + ruff (item 1 touches it); genesis pytest + ruff (record whether the run fell in 00:00–02:00
IST); genesis-workflows `validate_library` + pytest (`program_node` is used by every workflow); web lint, typecheck,
test; `npm run build`, then commit `web/static/` in its own step, checked with `git show --stat <sha> -- web/static`
after the build has settled (L-089). Do not restart the fleet (D36).

## 5. After the build (genesis-review, 54-10)

Re-review this diff; re-run on the copy: A2, A7 (pause of a running run, D31), A9, A12 (bell Remove / Clear read),
A14 (Objects table), A15, A17, and A1 for the six D50 changes; then the rows still waiting on the user's go-ahead
(D47). 54-10's verdict then decides 54-11. **The copy's server must be restarted first** (`/tmp/g5410/serve.sh`, with
no run active): the one on :8790 has run since before 54-12 and holds the old code in memory. 54-12 changed no
migration (m4 is a read fallback), so the copy's v30 database stays valid. **The copy's server must be restarted first** (`/tmp/g5410/serve.sh`, with
no run active): the one on :8790 has run since before 54-12 and holds the old code in memory. 54-12 changed no
migration (m4 is a read fallback), so the copy's v30 database stays valid.

## As built

**Status:** BUILT 2026-11-20, review **SHIP** (round 2). Repo genesis, branch master, base `2ad1c50`, head `9980b0c`,
13 local commits (not pushed, not tagged). genesis-workflows unchanged. Next: genesis-review's 54-10 live re-run on the
copy (§5, D46), with the user's go-ahead at each HITL gate.

**Loaded before writing code** (full text): lessons L-014, L-026, L-043, L-069, L-081, L-083, L-089, L-090, L-091, L-093,
L-094, L-096, L-097, L-102, L-103, L-107, L-108, L-109; ADRs ADR-019, ADR-027, ADR-028, ADR-043, ADR-055 (pack).

### Commits (genesis)

| sha | what |
|---|---|
| `076604e` | B1 (D49) + m5: `program_node` off the loop; `retry_when_busy`; honest missed reason; terminal reconcile; strict pause (503) |
| `3a4e0c2` | B1 regression test through a real worker |
| `235e4bc` | M1 (D48): pulled frame sandbox; CSP + nosniff on the three read-only routes; scriptless clause highlight |
| `8c7522e` | m1, m2, m3, m4, n1, n2, n4 |
| `411d74b` | D50 1–6 (web + the two notification routes), M2, m6, n3 (source) |
| `15a9124` | from the real-browser probe: Objects changed Type column sizes; the probe script and seed |
| `bdac951` | web/static for `15a9124` |
| `294b322` | `DELETE /notifications/{id}` answers 204, as 54-06 §1 already said (it answered `{unread}`) |
| `34b3e69` | web/static for `294b322` (review round 1 at this head) |
| `2ee4cb9` | review round 1: M-1, m-1, n-1 … n-5 |
| `90d6122` | web/static for `2ee4cb9` |
| `5c50bab` | Runs rows keep no tint on the shared table; the probe covers Runs |
| `9980b0c` | web/static for `5c50bab` (review round 2: SHIP) |

### Changed

- **B1, genesis-core** `nodes/program.py`: the step runs with `await asyncio.to_thread(fn, state, ctx)`. Signature,
  return and telemetry unchanged; `CORE_MAJOR` 1. `to_thread` copies context variables, so LangGraph's config
  (`interrupt()`, stream writer) still reaches the step. Checked that no program step needs the running loop: every
  workflow `graph.py` grepped for `asyncio`/`get_running_loop`/`interrupt(`; the ones that use asyncio already wrap
  their own sync work in `to_thread`; `ctx.extras` members open no connection at build time; `kb/dev_mcp.py` uses
  `asyncio.run`, which works only off the loop. `runs/worker.py` `_emit` now writes each line under a lock (steps may
  call `ctx.emit` from a thread).
- **B1, the busy database** `db/database.py`: `Database(busy_timeout_s=30)` and `retry_when_busy` (re-runs one whole
  transaction on "database is locked/busy", `BUSY_RETRIES`=3, wait 1 s doubling). Applied to every `ScheduleStore`
  write (14 methods), every `NotificationStore` write and `RunStore.claim_status`.
  - `Scheduler.tick` keeps `_up_since` (ticks continuous while each starts within 3 tick periods of the previous
    end): a slot missed while Genesis kept ticking is recorded "Genesis was running but could not start it in time",
    and the notice says so; after a real gap (sleep, stop) it still says "Genesis was not running".
  - `RunManager.reconcile_status` adopts a TERMINAL `run.final` even while the run's worker is tracked (only a
    non-terminal marker is left to the worker), so a failed terminal status write no longer leaves a run `running`.
- **m5** `RunManager.pause`: the status is stored FIRST, then the worker's stop is marked, then it is killed (review
  M-1: marking first dropped every worker event while the write retried, so a worker that died then left a ghost
  `running` run). A write that still fails raises `RunStopNotStored` without marking or killing; `POST
  /runs/{id}/pause` answers 503 "…the run is still running. Try again." Cancel keeps its announce-anyway path.
- **M1** `StageBuilderPage.tsx` `PulledStageView`: `sandbox="allow-scripts"`. `api/_shared.READ_ONLY_HTML_HEADERS`
  (CSP `script-src 'none'; object-src 'none'` + nosniff) on `annotate=0` of `GET /features/{id}/spec/artifact`,
  `GET /features/{id}/stages/{stage}/artifact` and `GET /features/{id}/change-requests/{cr}/document`; the design
  artifact and verification report now use the same constant. **Clause highlight kept without a script**:
  `spec_clauses.overlay_labels` adds a render-only `<a class="gn-anchor" data-gn-anchor id="c-…">` per block (not when
  the block already carries that id) and a `:target` / `:has(> .gn-anchor:target)` rule; `genesis-clause-focus-js` is
  removed (the overlay badge script stays, only with coverage badges). The vendored SDK uses no `localStorage`
  (grepped), so the frames' `SecurityError` seen in 54-10 is not the SDK's.
- **m1** `ScheduleStore.set_pause(…, None)`: a once whose time passed records a `missed` row "the schedule was paused
  at its time" and is completed (an already-completed one records nothing).
- **m2** refused, not routed: `_check_workflow` answers 422 `target.workflow_id` "schedule an agent prompt with the
  agent prompt target, not as a workflow"; `agent-prompt` left out of `/schedules/pickable` workflows (fixture
  `schedule-pickable.json` re-recorded). One path checks agent-prompt servers (D33).
- **m3** `_follow`: closing a terminal row whose `idle_since` is set first adds `now − idle_since` (the same rule as
  a run still in flight: up to one tick of running time can count as idle; the engine never mixes its clock with
  stored run timestamps, D27).
- **m4** read fallback (m0030 untouched, so no fleet re-check was needed): `_last_run` returns the row's
  `last_run_at/status/detail` (`slot: null`) when there is no history row, through `scheduler.status_outcome` (the
  engine's own status → outcome rule). Web `ScheduleLastRun.slot` is `string | null`.
- **D50** (web): shared `SearchInput` (`shared/ui/input.tsx`) used by Runs, Schedules, Workflows, Skills, Agents;
  shared `DataTable`/`DataTableHead`/`DataTableHeader`/`DataTableCell`/`DataTableRow` (`shared/ui/data-table.tsx`),
  `RunsTable` moved onto it (Runs rows are now keyboard-reachable too; the attention tint is `bg-warning-subtle`, no
  opacity modifier). Schedules: `SegmentedControl` filters, search on name and target name, the line above the grid
  removed, name is text (the row opens). Bell: Remove (×) on read notices, Clear read (disabled when none read), focus
  goes to the panel heading after a removal. `DELETE /notifications/{id}` → `{unread}` (409 unread, 404) and
  `POST /notifications/clear-read` → `{removed, unread}`. `DELETE` answers **204** as 54-06 §1 says (`294b322`;
  the bell re-reads the count after it). `notificationsApi.remove/clearRead`, type `ClearReadResult`, fixture
  `notifications/notification-cleared.json`; the bell toasts a refused Remove / Clear read (review n-2). The schedule
  name stays a named link inside its clickable row (review m-1). App-sync Sync options card has no Edit. Agents
  search on name and description. Runs rows lost their attention tint: the old `bg-warning-subtle/30` never applied
  (Tailwind cannot put an opacity on a `var()` token), so the approved page had none, and the shared table's plain
  `bg-warning-subtle` would have been a visible change (`5c50bab`).
- **M2** Objects changed Type cell: a narrowing flex box whose text wraps between words (`whitespace-normal
  break-words`), not an `inline-flex` that never narrowed. Column from the probe: 9.5rem (128 px box) below 2xl, where
  "Database Table" (132 px one line) and "Record Type Relationships" (204 px) wrap in their own column, and 14.5rem from
  2xl (208 px box: every type on one line). 11rem was tried and rejected: it broke story 74's object names into four
  lines at 1280. **m6** per-app sync headers and the last-full cell `whitespace-nowrap` (no header wraps in the probe).
- **Review round 1 (`2ee4cb9`)** besides M-1 and m-1: n-1 `overlay_labels(interactive=False)` for `annotate=0` keeps
  the story badges and drops their click script (the CSP would only block it); n-3 `create_user` retries only its INSERT
  (`_insert_user`), so a busy read-back can no longer duplicate a schedule; n-5 `Scheduler.start` seeds once through
  `ensure_defaults.__wrapped__` (boot never waits out the bounded retry on the event loop).

### Tests (fail-first evidence: each failed on the old code, then passed)

- genesis-core `tests/test_program_off_loop.py` (4): a 5 s blocking first step with the real `AsyncSqliteSaver` —
  old: every probe write "database is locked" (1.05 s waits); the loop heartbeat — old: 0 ticks during a 1 s step.
  (A blocking SECOND step passed on the old code: the earlier checkpoint had committed; the test uses the first.)
- genesis `tests/test_busy_database.py` (11), lock held by a second connection, 0.2 s busy timeout:
  slot fired in its tick (old: 0 runs, "could not evaluate"); close under the lock keeps "failed: database is locked"
  (old: "interrupted before its result was recorded"); missed while ticking (old: "Genesis was not running"); a real
  gap still "not running"; pause stored after the lock (old: stays `running`); pause that cannot be stored raises,
  worker not killed (old: no `RunStopNotStored`); route 503 (old: 200 `running`); finalize under the lock stores
  `failed` (old: `running` + OperationalError); reconcile adopts terminal `run.final` with a tracked worker (old:
  `running`); a gate marker is not adopted; a real worker with a 5 s step leaves the lock free (old: every sample
  locked).
- `tests/test_read_only_html_headers.py` (5): headers on the three routes (old: none), anchors + `:target`, no
  duplicate id. Updated: `test_story_trace.py` fragment test, `test_spec_clauses.py` overlay regex (the anchor is new).
- `test_scheduler.py`: m1, m3 (old: idle_s 0), n1 (old: UTC ISO); the gate-notice assertion updated to the zone text.
- `test_schedules_api.py`: m2 (old: 201), m4 (old: `None`), n4 (old: 400), n2 (old: Duplicate Operation ID warning),
  D50 4 routes (old: 404/405); route count 23 → 25 and the static-before-id order for `clear-read`.
- Web: `features.test.tsx` pulled frame sandbox (old: `null`); `schedules.test.tsx` list (6 tests failed against the
  old `SchedulesPage`: no line above the grid, filter tabs, search, row click and userEvent Enter, switch/link/menu
  keep their actions, jest-axe), detail (D50 5, n3: 2 failed on the old page), wizard (agent-prompt not offered);
  `bell.test.tsx` Remove/Clear read by keyboard + jest-axe (old: no Remove button); `agents.test.tsx` search + jest-axe
  (old: no box); `phase54-contract.test.ts` the two routes from the recorded fixtures; `StoryWorkspacePage.test.tsx`
  M2 pin (no `.truncate`; a wrapping type cell).
- Review round 1 additions (each failed on the code before it): `test_a_worker_that_dies_while_its_pause_cannot_be_stored_still_fails_its_run`
  (old order: `running`; the reviewer also proved it on an exported copy), `test_a_busy_read_after_create_never_creates_the_schedule_twice`
  (old: DID NOT RAISE, a duplicate), `test_the_read_only_spec_keeps_its_story_badges_without_their_dead_script`, the bell's
  refused-Remove toast and the schedule-name link (both failed against the previous files); `test_a_mixed_gap_notice_says_both`
  (coverage for n-4, passed when written).
- **Final gates at `9980b0c`:** genesis pytest **2122 passed** (16:29–16:41 IST, outside 00:00–02:00); `ruff check genesis`
  clean; genesis-core **124** + ruff clean (unchanged since `076604e`); genesis-workflows `validate_library` 19 PASSED
  + pytest **463 passed**; web lint 0 errors (20 old warnings), typecheck clean, vitest **906 passed (81 files)**; each
  bundle commit checked with `git show --stat` and a fresh out-of-tree `vite build` IDENTICAL to `web/static`.
- **Earlier gates:** genesis pytest **2118 passed** (14:41–14:53 IST, outside 00:00–02:00, nothing deselected) at
  `411d74b`; `ruff check genesis` clean; genesis-core pytest **124 passed** + `ruff check genesis_core` clean (core
  unchanged after `076604e`); genesis-workflows `validate_library` PASSED (19) + pytest **463 passed** with the new
  `program_node`; web lint 0 errors (20 old warnings), typecheck clean, vitest **905 passed (81 files)**. Added web
  lines: no hex, opacity modifier or `asChild` (diff grep).

### Screenshots (real browser, L-090)

`scripts/probes/phase54-12-probe.mjs` on two throwaway homes (`/tmp/p5412/a` = `phase54-seed.py` on :8794, `/tmp/p5412/b`
= `phase54-ux-seed.py` with story 74's real objects and a pulled spec on :8795; never the fleet, never `~/.genesis`,
not `/tmp/g5410`). Final run on the final bundle: **60 views clean** at 1280/1440/1920 × light/dark (Schedules list,
search and focused row; application-sync detail; Catalog → Agents and its search; Objects changed; Runs list and
focused row; the bell with Remove and Clear read): no sideways scroll, no header wrap, no cell content past its box.
Once: the pulled frame is `sandbox="allow-scripts"`, origin `null`, the SDK loads and posts `lavish:layoutDiagnostics`
and `lavish:reviewState` to the host, the frame cannot read the parent; the read-only spec's `#c-…` link answers CSP
`script-src 'none'` + nosniff, `:target` is the anchor, the clause gets the 2 px outline and is scrolled into view, 0
scripts, no CSP console error; the bell's Remove and Clear read by keyboard leave focus on the panel heading. Evidence:
`evidence/54-12/` (`*.jpg`, `probe-result.json`, `probe-output.txt`). The `localStorage` `SecurityError` 54-10 saw came
from the probe's own theme init script running in sandboxed frames; it is guarded now (the vendored SDK uses no
`localStorage`).

### Review

`reviews/54-12-review.md`.
- **Round 1 (at `34b3e69`), NEEDS_CHANGES:** M-1 (pause marked the stop before its retried write, dropping a dying
  worker's events), m-1 (unnamed focusable rows; the schedule name lost its link), nits n-1 … n-5; not checked: Runs
  in a real browser.
- **Round 2 (at `9980b0c`), SHIP:** all fixed; the reviewer re-proved M-1's test fails on the old order; Runs probed.
- **Not taken (optional round-2 nits, deferred so the shipped head is the reviewed one):** r2-n1 `isAttention` in
  `web/src/features/runs/hooks.ts` has no caller left; r2-n2 the Clear read error toast has no test; r2-n3 the 503
  pause text says "still running" in the M-1 corner case where the run has just failed.

### Decisions / deviations

No ADR deviation. `DELETE /notifications/{id}` answers 204, as 54-06 §1 (the spec agent's row) says; my first cut
answered `{unread}` and was aligned before review round 1 closed. Within the spec: m1 records missed + completed on Resume (the spec's words; 9a365c0 refuses on
"turn on"); m2 refuse; m4 read fallback; the clause highlight is kept with CSS `:target` (no known limit to record).
New wording: the missed reason "Genesis was running but could not start it in time". Nits: **taken** n1, n2, n3, n4;
**deferred** n5 (`.kiro/` provisioned skill files in the run documents list; pre-Phase 54, the fix belongs in the
manifest or the route, a separate decision) and n6 (ADR-087 draft lacks D30/D31: genesis-docs).

### Lesson candidates

- A fail-first test for "a blocking step holds the lock" must block the FIRST node: the in-flight write is the input
  checkpoint's; with the step second the earlier write had committed and the old code passed (L-026 corollary).
- A probe thread that waits on an asyncio event cannot observe a loop-blocking bug; drive it from a thread event.
- `display:inline-flex` never narrows below its content, so `truncate` inside it does nothing in a fixed column (M2).
- An opacity modifier on a `var()` token colour (`bg-warning-subtle/30`) silently renders nothing in this Tailwind setup;
  moving such a class to a shared component without the modifier is a visible change, so probe the old page too.
- A stop flag that silences a worker's events must be set only after the write it guards succeeded: marking first and
  then retrying a slow write turned a dying worker into a ghost `running` run (review M-1; L-108 corollary).
- Playwright init scripts run in every frame; one that touches `localStorage` throws in a sandboxed frame and reads like
  an app error.

### Code-map changes (for genesis-docs, bible/03)

`db/database.py` `retry_when_busy`, `BUSY_*`, `busy_timeout_s`; `runs/store.RunStopNotStored`; `api/_shared.
READ_ONLY_HTML_HEADERS`; `runtime/scheduler.status_outcome`, `MISSED_UP/DOWN`; `runtime/notifications.
NotificationUnread`, `remove`, `clear_read`; `api/notifications.py` two routes; `kb/spec_clauses._ANCHOR`;
`web/src/shared/ui/data-table.tsx`, `SearchInput`; genesis-core `program_node` runs off the loop;
`kb/spec_clauses.overlay_labels(interactive=)`; `ScheduleStore._insert_user`; `scripts/probes/phase54-12-probe.mjs`.

### Resume note

None: the sub-spec is complete. Open: the 54-10 live re-run on the copy (§5), then 54-11.

## Context manifest

```toml
areas    = ["runs-worker", "core-engine", "web-shell", "web-runs"]
adrs     = ["ADR-019", "ADR-027", "ADR-028", "ADR-031", "ADR-043", "ADR-055"]
lessons  = ["L-014", "L-026", "L-043", "L-069", "L-083", "L-089", "L-090", "L-091", "L-094", "L-107", "L-108", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/reviews/54-10-review.md", "tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/program.py", "genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/api/**", "genesis/web/src/features/schedules/**", "genesis/web/src/features/catalog/**"]
upstream = ["54-04", "54-06", "54-07", "54-09"]
```
