# Review 55-03 — base d0aa1b2 (genesis-review, 2026-11-22)

Commits reviewed: genesis `793c04b6` (source, tests, probe) and `d4f99d84` (web/static only); both resolve.

What this change does: the worker adds LangGraph's `tasks` stream and the manager logs a canonical `node.started`, so
program steps and loop re-entries show as running. A new incremental server fold (`runs/snapshot.py`) serves
`GET /runs/{id}/snapshot` (version = highest seq, `active_edges` with running/waiting). `GET /runs/{id}/live` sends
lifecycle hints only. The bus and its subscribers are bounded. The Run Detail graph now renders from the snapshot only,
with an honest Live badge and a Refresh control.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `pytest -q -p no:warnings` (full) | **2158 passed** in 699 s |
| `ruff check genesis tests/test_run_liveness.py` (0.15.20) | All checks passed |
| web `npm run lint` | 0 errors, 20 warnings (baseline) |
| web `npm run typecheck` | clean |
| web `npm test` | 83 files, **961 passed** |
| stale bundle: `npx vite build --outDir /tmp/review-55-03-static` then `diff -rq` against `web/static` | IDENTICAL; `git status` clean; `git show --stat d4f99d84 -- web/static` = 66 files; `793c04b6` has no web/static |
| genesis-workflows / playwright-appian gates listed by `check` | N/A: no file in those repos changed (the probe script `scripts/probes/phase55-run-graph.mjs` is in genesis and maps to browser-testing by path only) |

## Live check (scratch serve :8790, fleet untouched)

I ran a new `liveness-probe` run `r-c9c63ce3caa4` with `curl -N …/live` open the whole time:
- Frames came as `id: <seq>` / `event: <kind>` / `data: {seq,node,kind}`, hints only. Seqs 98–115 were all lifecycle
  kinds, with a `: ping` comment at 15 s. The stream ended by itself after `run.final {status: done}` (curl exited).
- Loop re-entry snapshot (v103): `active_edges = [check→work running]`. The edges were `prepare->work:1, work->check:1`
  with no `prepare→work` lit (D12 item 3).
- Gate (v109): `approve` read `awaiting`, `active_edges = [check→approve waiting]` (D12 item 2), and the gate
  `node.started` was re-emitted after the answer (seq 111).
- Reconnects: `Last-Event-ID: 101` gave a single `resync` frame (id 109) and no replay. `?after=109` gave nothing.
- The real agent run `r-86a0a8e446bc` snapshot showed credits 0.3118 on `make_result` (metered) and `legacy: false`.
- Earlier runs on the same serve match the §0 spike claims: a pause and resume re-emits `node.started work` (seqs 8, 9),
  and the failed run reads `work failed, entered_from check`.

## Checklist

ADRs
- [OK] ADR-001 LangGraph owns control flow: the change only observes `astream` (`worker.py:194`); no routing change.
- [OK] ADR-009 all 3 HITL modes: gate + resume (`test_a_gate_waits…`), pause/resume (`test_a_paused_node…`); fork untouched.
- [OK] ADR-010/018 small state, no bulk in events: `_task_start` drops `input` (`worker.py:127-139`); `node.started` payload is `{task_id}` only (test asserts `set(payload) == {"task_id"}`).
- [OK] ADR-012 subprocess worker: the app still never imports workflow Python; the kill+resume case uses real workers.
- [OK] ADR-024 async-first: `/live` and `/events/stream` await `asyncio.Queue`; blocking reads go through `asyncio.to_thread`; `/snapshot` is a sync route (thread pool).
- [OK] ADR-026 no auth / loopback: no new bind or origin.
- [OK] ADR-027 / ADR-055 web stack + tokens: `EDGE_COLOR` uses `var(--primary|--warning|--success|--fg-subtle)`; shared `Badge`/`Button` used.
- [OK] ADR-028 `/api` prefix: new routes are on the `/api` router; `runsApi.live` builds `/api/...` inside `src/lib/api/` (the same as `chat.ts`'s stream), not in a component.
- [OK] ADR-032 credits metered only: `RunFold.apply` sums only numeric `agent.result.credits`; `partial` flag logic unchanged (`RunDetailPage.tsx`).
- [OK] ADR-066 per-turn capture: `node_iterations` / inspector paths untouched; `node.started` does not enter `buildTranscript` (contract test).
- [N/A] ADR-003, 007, 008, 011, 013, 019, 021, 022, 023, 025, 029, 030, 031, 033, 034, 035, 037, 041, 043, 045, 046, 047, 049, 050, 054, 060, 061, 062, 063, 065, 068, 069, 071, 073, 074, 075, 076, 077, 078, 080, 081, 082, 083, 084, 085, 086, 087: listed by area mapping. The diff touches no registry, chat, trust, KB, feature/story, collaboration, test-execution, Kiro launch, schedule, release or distribution code, and adds no DB migration (ADR-030: SQLite, no schema change).

Lessons
- [OK] L-003 bus open until terminal, client closes on terminal: a gate keeps `/live` open (frame `run.final awaiting_input:gate` then more frames, live check); `useRunLive` sets `finished` on a terminal `run.final` and opens nothing when inactive (`liveness.test.tsx` "stops on a terminal final").
- [OK] L-005 canonical kinds: `NODE_STARTED` added to `CANONICAL_KINDS` (`manager.py:56`); lesson text to be updated at write-back (55-12).
- [OK] L-006 / L-013 / L-034 / L-067 topology and layout: layout still keyed on topology; only `NODE_H` 84→104 (`layout.ts:4`); probe reports 0 layout problems.
- [OK] L-007 transcript fold unchanged.
- [OK] L-008 `worker_exit` vs `error`: the order is unchanged; `test_worker_stderr_is_drained…` sees both.
- [OK] L-009 async saver unchanged.
- [OK] L-010 `/api` routes.
- [OK] L-011 / L-122 contract parity: kinds in `canonical-kinds.json`, `CANONICAL_EVENT_KINDS` and a fixture (`events.ts` seq 18). Snapshot and live fixtures are recorded from real route answers (`record("snapshot-gate"…)`, `record("live-frames"…)`), and the shapes are checked against typed values (`contract.test.ts`).
- [OK] L-018 CRLF: the server test asserts `\r\n\r\n`; the client test "parses sse-starlette's CRLF frames".
- [OK] L-021 / L-023 no tool output inlined.
- [OK] L-025 / L-027 ruff pinned (0.15.20).
- [OK] L-030 / L-048 / L-068 bundle: fresh and committed (see Gates).
- [OK] L-056 commit completeness: `git status` clean; source and bundle commits hold what they claim.
- [VIOLATION→M1] L-059 loop re-entry display: running is fixed, but a stopped re-entry loses its round count (M1).
- [OK] L-060 / L-066 no client fold of the capped log: the graph reads the server snapshot. The fold reads only `FOLD_KINDS` after `last_seq` (`test_a_30k_event_run_folds_once…`: one read after the held version, < 0.5 s).
- [OK] L-065 terminal status on gate→END: unchanged.
- [OK] L-069 no `<Button asChild>`.
- [OK] L-081 n/a defaults: no new default turns a job on.
- [OK] L-089 separate bundle commit and post-commit proof (see Gates); this review issued no batched mutate+verify.
- [OK] L-090 layout geometry: probe at 1280/1440/1920 in both themes (evidence/55-03).
- [OK] L-091 / L-097 / L-108 concurrency: late events of a stopped worker are still dropped before `task_start` (`manager.py:250`). The terminal write is unchanged (CAS in `_finalize`). The snapshot version is the shared seq, and two caches agree (`test_two_readers…`).
- [OK] L-093 store before announce: `note_progress` now runs before `node.completed` (`manager.py:262-268`, `test_the_cursor_is_stored_before…`).
- [OK] L-094 consumers: removed `deriveNodeStates`, `useRunSteps`, `useRunTransitions`, `useRunStream`, `runningNode` and the sync `EventBus.subscribe` have no remaining callers (grep). The observers in chat/finalizers filter by kind (`chat/supervisor.py:58`). `fold_steps` / `node_iterations` are unaffected by the extra kind. `manager.events` was fixed (it called a non-existent `self.bus`). One consumer was missed: m1.
- [OK] L-104 / L-107 background thread terminates: the stderr drainer is a daemon joined with a 5 s timeout. A grandchild that holds the pipe cannot hang `on_exit`, which the old `proc.stderr.read()` could.
- [OK] L-110 / L-117 real mechanism: worker cases use real subprocess workers with the §0 payloads copied from the spike.
- [OK] L-111 live acceptance: a real-browser probe plus my live API pass; full Phase 55 acceptance is later.
- [OK] L-118 cancelled task group: `test_a_cancelled_stream_releases_its_subscriber` (both endpoints) cancels an anyio task group; `Subscription.release()` is synchronous.
- [OK] L-123 no opacity modifier on var() tokens in new classes (`border-warning/50` was removed, `NodeCard.tsx`).
- [OK] L-124 level-triggered decisions from the durable row: the snapshot reads the stored status on every build (`RunFold.view`).
- [N/A] L-004, 012, 014–017, 019, 020, 022, 026, 031, 033, 039, 043–045, 050, 051, 055, 057, 058, 061, 062, 087, 088, 092, 096, 098–101, 103, 105, 106, 109, 112, 113, 115, 116, 119–121, 125: no code in their areas changed. L-092: the new test module has no `tests/__init__.py`; L-112: no CI-image assumption added.

## Findings

### Blockers
None.

### Majors
- M1 **A paused or failed loop re-entry loses its round count and shows the wrong time** (`web/src/features/run-detail/node-states.ts:39-41`, `graph/NodeCard.tsx:42-44`).
  - What: `runs = executions + (status === "running" ? 1 : 0)`, `round` is set only while running, and a non-running
    node shows `duration_s` (the sum of completed executions).
  - Problem: this does not match the approved 55-02 states and your own decision ("↻ shows runs including the current
    one"). In the mockup's **paused** state `draft_section` reads ↻3 with the stopped execution's 6 m 02 s, and in the
    **failed** state `analyze_section` reads ↻3 with "900 s". The build shows ↻2 for both, while the incoming edge reads
    ×3 (`edgeState` counts the unfinished hop).
  - Your own evidence shows it: `paused-1440-light.jpg` has Work paused in round 2 (`check→work ×1`) with no ↻ and
    "13s", which is round 1's time. `failed-1440-dark.jpg` has Work failed on round 2 with no ↻ and "205ms", which is
    the first execution only.
  - `node-states.test.ts` "matches the mockup" checks statuses and edges but never `runs` for paused or failed, so it
    cannot catch this.
  - Fix: count the unfinished execution for every unfinished status: `s.executions + (["running","paused","failed","cancelled"].includes(s.status) ? 1 : 0)`.
    For a stopped node, show the stopped execution's time from `started_at` to the run's `ended_at` (or the record's
    `updated_at` for a pause) rather than the completed sum. Add `runs` assertions for `paused` (3) and `failed` (3) to
    the graph-states test.
  - If skipped: on a paused or failed loop the node's count disagrees with its own incoming edge, and the shown time
    hides how long the failing round ran.

### Minors
- m1 **The node dialog's live tail stops silently after a `/events/stream` resync** (`genesis/api/run_routes.py:439-442`, `web/src/features/run-detail/hooks.ts:110-131`).
  - What: `/events/stream` can now end mid-run with a `resync` frame. Before, it ended only at terminal.
  - Problem: `useRunNodeStream` registers no `resync` listener, and its `onerror` closes the EventSource. If more than
    1,000 live events queue while the replay is still being written, the open node dialog stops tailing and never
    reconnects. `useRunNodeEvents`' 2.5 s poll keeps the content updating, so nothing is lost.
  - The only route test, `test_events_stream_still_replays_then_tails_without_duplicates`, runs on an already-finished
    run, so it covers neither the tail nor the resync.
  - Fix: on `resync` (or on an error while active), invalidate `qk.runs.nodeEvents(runId,node)`. Make the route test
    produce events while the stream is open, plus one overflow case.
- m2 **A node that never starts is shown with no time** (`NodeCard.tsx:42`).
  - Problem: a failed node on its first execution gets `duration_s = 0`, so `doneMs` is null and no time shows. A
    `turn_timeout` failure is exactly the case where the time matters.
  - Fix: covered by the M1 fix (time of the stopped execution).

### Nits
- n1 `_announce_final` pops the bus before it records `_finished` (`manager.py:187-188`). If the status write failed
  (the `_claim_status` returns-True path), a `/live` connect between the two lines creates a fresh open bus that never
  closes. Swap the two lines.
- n2 A fresh run reads `legacy: true` until its first `node.started`. The web ignores `legacy`, so nothing is visible.
  Note it in the ADR-090 text, or derive `legacy` from `run.started` without a following `node.started` only for runs
  created before the upgrade.

## Not checked
- The As built section of 55-03 is not written yet. The §0 spike scripts exist only in `/tmp/spike-55-03/`. Record the
  payloads and conclusions in As built before they are lost.
- Two `serve` processes viewing one live run: I checked only the fold's version agreement (unit test), not a real second process's `/live` (it gets no hints and relies on the 3 s poll by design).
- Parallel fan-out branches: `entered_from` / edge counting for concurrent tasks follow the old consecutive-completion
  rule. Neither the tests nor the probe cover them.
- I did not open screenshots beyond paused and failed; the loop, gate and agent states were checked by API on the live run only.

## Verdict: NEEDS_CHANGES

Fix M1 (count and time of a stopped re-entry, plus the missing test assertions). m1 should go in the same change. The
rest of the change is sound: every gate is green, the real streams behave as the spec says, and the fixes that came out
of the spike (`__interrupt__`, stderr hang, `manager.events`) each have a regression test.

---

## Re-run 1 (genesis-review, 2026-11-23)

Commits reviewed: genesis `1576a229` (fixes and tests, 12 files, no web/static) and `2647574b` (web/static only, 66
files). `genesis-ctx check --since 793c04b6` maps the change to the same areas as round 1 (runs-worker, web-runs).

### Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `pytest -q -p no:warnings` (full) | **2159 passed** in 701 s (round 1: 2158; +1 is the new overflow test) |
| `ruff check genesis tests/test_run_liveness.py` | All checks passed |
| web `npm run lint` | 0 errors, 20 warnings (baseline) |
| web `npm run typecheck` | clean |
| web `npm test` | 83 files, **963 passed** |
| stale bundle: `npx --no-install vite build --outDir /tmp/review-55-03-r1-static` then `diff -rq` against `web/static` | IDENTICAL; `git status` clean; `git show --stat 1576a229 -- web/static` is empty |

### Round-1 findings

- **M1: fixed.** `node-states.ts:42-48` counts the unfinished execution for running, paused, failed and cancelled
  (`UNFINISHED`), and sets `stoppedMs` from `started_at` to `ended_at` for a stopped one. `NodeCard.tsx:42-43` shows
  `stoppedMs` before the completed sum. On the server, `snapshot.py:181-184` gives a stopped execution
  (`running_since_start`, no `ended_at`) the terminal `run.final` ts, else `rec.updated_at`. Both timestamps come
  from `datetime.now(timezone.utc).isoformat()` (`store.py:46`, `eventlog.py:28`), so `Date.parse` compares like with
  like. `updated_at` is written by `update_status`, `claim_status` and `note_progress`; the stopped worker's late
  events are dropped before `note_progress` (round 1, `manager.py:250`), so a pause's `updated_at` stays the pause time.
  Tests: `node-states.test.ts` "a paused or failed re-entry keeps its round count…" (runs = 3 for both, failed runs
  equal to the `next_analysis→analyze_section` edge count), and `test_the_approved_graph_states_fold_to_the_mockups_edges`
  (paused `ended_at == updated_at`, failed `ended_at ==` the run.final ts).
  Live: in `paused-1440-light.jpg` Work reads Paused ↻2 with two incoming hops (prepare→work ×1, check→work ×1), so
  the count now matches its edges. The scratch run `r-606a36cfdc4b` shows round 1 of `work` lasted 13.58 s
  (seq 119→120) and round 2 started at 20:22:19.623 (seq 123). The pause came after the six loop-reentry shots
  (probe lines 109-113), so a 13 s stopped execution is plausible. I could not re-read the paused snapshot because
  the run has finished since. `failed-1440-dark.jpg` reads Failed ↻2 with 211 ms.
- **m2: fixed** by the same code. A failed first execution has `running_since_start` and gets `ended_at`, so it shows
  a time. No dedicated test (see n3).
- **m1: fixed.** `hooks.ts:117-120,134-135`: `resync` and `onerror` close the stream and invalidate
  `qk.runs.nodeEvents(runId,node)`. The caller (`NodeIterationsDialog.tsx:52-53`) derives `after` from that query, so
  a refetch that brings newer node events reopens the tail from the new seq. A persistent error does not loop,
  because the same `after` opens nothing new. Tests: `liveness.test.tsx` "re-reads the node's events and closes…"
  (fake EventSource, both paths); `test_events_stream_still_replays_then_tails_without_duplicates` now logs while
  subscribed (kinds `node.started, agent.thought, node.completed, run.final`); `test_events_stream_overflow_sends_resync_and_ends`
  (`SUBSCRIBER_MAX = 0` → one `resync` frame, subscriber released).
- **n1: fixed.** `manager.py:187-188`: `_finished` is recorded before `_cbuses.pop`.
- **n2: fixed.** `snapshot.py:169`: `legacy = not self.has_started and bool(self.nodes)`. The test checks a fresh run
  (`run.started` only) reads `legacy: False`, and the old-run cases still read legacy.

Checklist delta: L-059 moves from VIOLATION to **OK**. L-003 (the node tail still closes on `run.final`,
`hooks.ts:128`), L-089 (separate bundle commit, verified after the build exited), L-093 (n1 order) and L-118 (the
overflow test releases the subscriber) are re-checked and **OK**. Every other round-1 line is unchanged by this diff.

### New findings

Blockers, majors, minors: none.

Nits:
- n3 The M1 web test asserts only `stoppedMs > 0`. In the failed fixture the stopped execution's time (10:00:19 →
  10:00:21 = 2000 ms) equals `duration_s` 2.0, so a regression back to the completed sum would still pass for
  `failed`. Assert exact values (`paused` 3 599 000 ms, `failed` 2000 ms) and add a failed-on-first-execution case
  (`executions: 0`) for m2.
- n4 The `agent-*` screenshots in `evidence/55-03/` are dated 01:26, before `1576a229` (01:50). The probe's 36 shots
  are 01:53. No visible change is expected for the agent states, but the evidence is from the earlier build.

### Not checked (re-run 1)
- The cancelled path of M1 (status `cancelled`, ended at the run.final): the code path is shared with `failed`, but
  no test or probe covers it.
- A state edit or fork side operation (L-121) on a paused run: if one writes `updated_at`, the paused node's time
  would grow. I found no such write in `store.py`, but I did not trace every side-op caller.
- Round-1 open items stand: 55-03 As built and the §0 spike payloads, two `serve` processes on one live run, and
  parallel fan-out edge counting.

## Verdict (re-run 1): SHIP

M1, m1, m2, n1 and n2 are fixed, each with a test. My gates are green (2159 pytest, 963 vitest, ruff, lint,
typecheck, bundle identical). n3 and n4 are optional.
