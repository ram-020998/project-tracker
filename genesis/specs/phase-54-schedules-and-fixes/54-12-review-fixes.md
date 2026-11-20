# 54-12 — Fix pass: 54-10 review round 1 and the user's A1 changes

> **Status:** SPEC-DRAFTED 2026-11-20. Repos: genesis (`packages/genesis-core`, `genesis/runtime/`, `genesis/api/`,
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
(D47). 54-10's verdict then decides 54-11.

## As built

_(genesis-dev fills in: commits, changes, tests with fail-first evidence, screenshots, review verdict,
decisions/deviations, nits taken or deferred, lesson candidates, code-map changes, Resume note.)_

## Context manifest

```toml
areas    = ["runs-worker", "core-engine", "web-shell", "web-runs"]
adrs     = ["ADR-019", "ADR-027", "ADR-028", "ADR-031", "ADR-043", "ADR-055"]
lessons  = ["L-014", "L-026", "L-043", "L-069", "L-083", "L-089", "L-090", "L-091", "L-094", "L-107", "L-108", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/reviews/54-10-review.md", "tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/program.py", "genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/api/**", "genesis/web/src/features/schedules/**", "genesis/web/src/features/catalog/**"]
upstream = ["54-04", "54-06", "54-07", "54-09"]
```
