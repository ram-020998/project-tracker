# Review 49-08 H3 — base f0df126 (genesis-review, 2026-10-31)

Focused review of hardening item **H3** only (spec `49-08-review-and-acceptance.md` §1.1 H3; findings it fixes:
`reviews/49-08-review.md` §4 M1–M3, m1–m4, n1–n4). This is **not** the 49-08 re-review. §3 live rows 6/15/16/18 were
not re-run as acceptance, no fleet instance was touched, nothing was written to main's data. The width probes were
re-run read-only against a throwaway Vite dev server (:5199) that proxies `/api` to main's GETs (see "Width re-probe").

- Repo `genesis`, diff `git diff f0df126..b4a9f09` (22 source/test files + rebuilt `web/static`).
- Commits (local, unpushed): `9324a76` backend, `b4a9f09` web + bundle. HEAD = `b4a9f09`; the tree is clean.
- Checklist: `genesis-ctx check --since f0df126 --repo genesis` (areas api, features-stages, runs-worker, release-ci,
  security).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1364 passed** (217 s) |
| `.venv/bin/ruff check genesis` | All checks passed |
| `npm run lint` | 0 errors, 20 warnings. None of the warnings is in a changed file: `eslint src/features/features src/features/test-design` flags only `AnnotatablePreviewDialog.tsx`, which H3 does not touch. |
| `npm run typecheck` | clean |
| `npm test` | **50 files / 457 passed** |
| Stale bundle: `npx vite build --outDir /tmp/49-08-H3-static` + `diff -r … web/static` | **IDENTICAL** |

I did not re-run the before-fix stash (11 backend / 5 web tests failing). That claim is the author's. Each new test
asserts the new behaviour directly (messages, statuses, classes), so it would fail on the base.

## Spec conformance per sub-item

| Item | Verdict | Evidence |
|---|---|---|
| **M3** orphaned run | Built as specced. Two findings: **MJ1** and **mi2**. | `runs/manager.py:366-404` `fail_orphaned_runs`, wired at `api/app.py:237` as the first step of `_bind_supervisor` (after `bind_loop`, before `supervisor.reconcile` / `stage_finalizer.reconcile` / `story_design_finalizer.reconcile`, and before the later `_reconcile_test_links` hook that runs `reconcile_topups`). `_start_scheduler` and `_start_collab_autopull` are registered after it, so nothing in this process spawns a run before the sweep, and uvicorn accepts no request until startup ends. It goes through `_finalize` (`:398`), so the order is error → stored FAILED → `run.final` → bus close (H1). Paused, awaiting-gate and terminal runs are skipped because the sweep lists only `PENDING`/`RUNNING`. Every spec-required test exists: `test_startup_sweep_fails_an_orphaned_running_run` (exactly one `run.final{failed}` and one `error`; observers see the stored FAILED; idempotent), `…never_touches_paused_gated_terminal_or_tracked_runs`, `…adopts_a_durable_run_final_instead_of_failing` (real worker), `…adopts_a_last_gate_marker_but_fails_a_resumed_then_lost_run`, and the end-to-end `test_a_topup_orphaned_by_a_restart_fails_at_startup_and_unblocks_a_new_one`, which runs the real app startup hooks via `with env.client`. The edge rule is right: `respond()` logs `gate.resolved` before it respawns, so a gate marker followed by later events means the run was resumed and then lost, and failing it is correct. |
| **m2** stage-aware Reopen reason | OK | `domain/transitions.py:79-91` holds the callable. `lifecycle.py:163-165` already called a callable reason (the test-case maps use one), so no consumer needed to change. `spec_change.py:204` adds `"stage"` to the ctx. `test_rerun_and_reopen_are_refused_after_finalize` now asserts `detail.reason`. `test_reopen_refusal_reason_is_stage_aware` covers the spec/default branch. |
| **n1** comments | OK | `api/testdesign.py:225-226`, `tests/test_test_design_stage.py:5`. |
| **n2** R8 resolve on the scenario read | OK | `api/testdesign.py:385-386`; `test_scenario_read_resolves_unresolved_links`. |
| **n3** case key in the refusal | OK | `kb/testdesign.py:670-674`. It falls back to `#id` only when no such row exists. `test_set_steps_replaces_and_refuses_cross_suite_retired_and_stale` asserts both messages. |
| **n4** Task links | API half OK; picker half **not built** (**mi1**). The `keep=` exemption is a sound choice (see below). | `kb/testdesign.py:677-697` and `:710`. The rule matches the existing Task check (`testdesign_stage.py:576`: anything other than `"Story"` is a Task). Finalize and top-up link through `_link_story` directly, so agent-authored links cannot 422 a Finalize. `test_case_stories_refuse_a_new_task_link` covers edit, create and the kept old link. |
| **M1** Cases table | OK, deviation accepted. One nit: **ni1**. | Fixed columns 96+108+88+80+92+100+136 = 700 px, plus the 256 px floor = `min-w-[956px]` (`CasesTable.tsx:88`). `KeyList` puts one key per line. The pin test is `Cases view layout pin`. |
| **M1** coverage at 2xl (deviation) | Accepted | The spec's acceptance requires Title ≥ 240 px with no scroll at 1920. A 2/3 column at 1920 is 893 px, below the table's 956 px minimum, so the literal 2/3 split cannot meet the acceptance. A fixed `16rem` coverage column at ≥ 2xl keeps the table at container width: Title 374 px at 1920 and 262 px at 1536 (the author's measurement). The deviation serves the acceptance criterion. The added `md:2 xl:3 2xl:1` coverage list grid is a small, sensible extra. Record it in As built. |
| **M2** stage grid + footer | OK | `FeaturePage.tsx:169` `lg:grid-cols-3 2xl:grid-cols-5`; `:270` `flex-wrap`; `SpecChangedBanner.tsx:50-53`. Pin test: `layout pin (49-08 H3 M2, L-090)`. |
| **m1** Publish to team | OK | `stages.ts:47-55` + `:88`; `StageArtifactWorkspace.tsx:212`. The Vitest waits for the collab config read before asserting absence and runs jest-axe. |
| **m3** poll while a stage run is in flight | Built to the spec's literal predicate. One finding: **mi3**. | `hooks.ts:36-39`, `stages.ts:62-64`; `useFeaturePoll.test.tsx` uses fake timers (polls, then stops once the chat exists; no poll when idle). |
| **m4** Test Impact key | OK | `TestImpactTab.tsx:200-201`, `:246`; pinned in the Test Impact test. |

### n4: the `keep=` exemption
I agree with it. Without the exemption, any case that already carries a Task link from before this rule (live: TC-000003 →
GNS_000001) could not have its other stories edited until the user worked out which link the 422 means. The exemption
does not weaken D14 going forward: a *new* Task link is still refused on edit and on create, and the old link can still
be removed. Note it in As built as a deliberate rule.

### Width re-probe (read-only, the author's scripts)
`WIDTHS=1280,1440,1920 node /tmp/genesis-h3/with-dev-server.mjs /tmp/genesis-h3/row15-probe.js`, light and dark
(`/tmp/genesis-h3/row15/probe.json`, regenerated 2026-10-31 11:48):

- Cases table = container 982 / 1142 / 1074 px; no container scroll; Title **282 / 442 / 374** px; no header wraps; no
  clipped cell; no page h-scroll.
- Test Impact Key column 120 px at all widths; no clipped cell.
- Stage cards 320 / 373 / 261 px. `row15-footer.js` at 1280 and 1920: no control is clipped or past its card edge.
  `probe.json` marks the UX and Technical Design cards `clipped: true`. I identified the element with
  `/tmp/genesis-h3-review/clipped-id.js`: an `sr-only` "(opens in a new tab)" span, which is a false positive of the
  probe's overflow test, not a visual clip.
- Light and dark give identical numbers.

The formal row-15 re-acceptance stays with the 49-08 re-review.

## Checklist

### ADRs
- [OK] ADR-001 — no agent orchestration added; the sweep is program code in the run layer.
- [N/A] ADR-008 — no change to the app/engine bundling.
- [OK] ADR-009 — HITL modes kept. Paused (mode 2) and awaiting-gate (mode 1) runs are never touched
  (`test_startup_sweep_never_touches_paused_gated_terminal_or_tracked_runs`). A gate marker that is the last event is
  adopted as `awaiting_gate`, not failed (`…adopts_a_last_gate_marker…`).
- [OK] ADR-010 / ADR-018 / ADR-022 — no state or blackboard shape change. The sweep's `_finalize` runs the usual
  `_purge_tool_store` (see ni2).
- [N/A] ADR-011 — no agent node changed.
- [OK] ADR-012 — the app still never imports workflow Python. The sweep encodes ADR-012's own consequence (a worker is
  a child of the process that spawned it, so after a restart this process tracks none). Its assumption that exactly one
  app process uses the DB is not enforced: **MJ1**.
- [OK] ADR-021 — gates unchanged.
- [OK] ADR-023 — FastAPI startup hook; no LangGraph server.
- [OK] ADR-024 — the blocking sweep runs via `asyncio.to_thread` (`api/app.py:237`).
- [N/A] ADR-025 — no fork change.
- [OK] ADR-026 — no new network surface.
- [OK] ADR-027 / ADR-055 — Tailwind utilities on existing primitives and tokens only; no raw palette, no new deps.
- [OK] ADR-028 / L-010 — the only new client call reuses `featuresApi.get`; no `/api` literal in a component.
- [OK] ADR-030 — SQLite; the store change is one extra column in a `SELECT`.
- [N/A] ADR-031 / ADR-033 / ADR-034 / ADR-045 — chat not touched.
- [OK] ADR-032 / L-016 — no credit figures touched.
- [N/A] ADR-035, ADR-037, ADR-041, ADR-043, ADR-047, ADR-049, ADR-054, ADR-057, ADR-058, ADR-059, ADR-060, ADR-061,
  ADR-062, ADR-064, ADR-066, ADR-067, ADR-068, ADR-069, ADR-071, ADR-072, ADR-073, ADR-074 — not touched by H3.
- [OK] ADR-042 / ADR-044 / ADR-056 — each stage keeps its own lifecycle; `localOnly` is a per-stage descriptor flag.
- [OK] ADR-050 — no status write bypasses `LifecycleService.transition`. The Reopen refusal still comes from it, with
  a stage-aware reason. The run status is a run-store field, not an SDLC entity.
- [OK] ADR-063 / ADR-065 — collab gates unchanged. m1 only hides a button the server already refuses
  (`collab/service.py:343-344`).
- [OK] ADR-075 / ADR-076 — the spec keeps its change-request reason (`test_reopen_refusal_reason_is_stage_aware`).
- [OK] ADR-077 — this review used `genesis-ctx check`; no bulk docs read.

### Lessons
- [OK] L-003 — `_finalize` closes the bus of each swept run (`mgr.cbus(rid)._closed` asserted).
- [OK] L-004 — the data plane is SQLite.
- [OK] L-005 — canonical kinds only (`error`, `run.final`).
- [OK] L-008 — the sweep writes one specific `error` ("worker lost across a server restart") and nothing generic
  overwrites it.
- [N/A] L-009, L-018, L-019, L-020, L-021, L-023, L-031, L-033, L-041, L-042, L-043, L-048, L-050, L-059, L-064, L-071,
  L-072, L-073, L-075, L-076, L-082, L-084, L-086, L-087, L-088 — areas not touched.
- [OK] L-017 / L-045 — no trust change.
- [OK] L-025 / L-027 — ruff pin unchanged; `ruff check genesis` clean.
- [OK] L-026 — sweep off the event loop.
- [N/A] L-030 / L-051 / L-056 / L-057 — no release in H3 (local commits). At release, check that both commits ship
  together.
- [OK] L-039 — the scenario read now resolves the way the suite and case reads do (n2).
- [OK] L-058 — level-triggered recovery now closes the orphaned-run gap: the sweep writes a terminal record and a
  `run.final` before `reconcile_topups` and the finalizer reconciles run
  (`test_the_startup_topup_reconcile_settles_a_run_the_sweep_failed`, `…orphaned_by_a_restart…`). This resolves the
  49-08 VIOLATION. Logging is loud: ERROR per failed run, WARNING with the list of ids.
- [OK] L-060 / L-066 — the poll re-reads `/features/{id}` only, not the event log.
- [OK] L-061 / L-062 — finalizers still scope to the stage's bound run. A swept run is `failed`, so `StageFinalizer`
  leaves its stage in-progress, as documented.
- [OK] L-063 — the Test Design gate is unchanged.
- [OK] L-065 — the gate→END path is untouched. The sweep never fails a run whose last event is a terminal `run.final`.
- [OK] L-068 — index.html serving unchanged.
- [OK] L-069 — no `<Button asChild>` added.
- [OK] L-074 / L-085 — no board, pull or publish hook change; m1 removes a dead-end button.
- [OK] L-081 — the sweep is a new startup default that never touches paused/gated runs (user-held state).
- [OK] L-083 — fixtures use real shapes (`TC-\d{6}` keys, `GNS_000124` with `story_type: "Task"`).
- [OK] L-089 — the bundle is fresh (`diff -r` identical) and the tree is clean.
- [OK] L-090 — widths sized from a real-browser probe, class-level pin tests kept, re-probed at 1280/1440/1920 in both
  themes (above).

### Gates
- [OK] pytest (api / features-stages / runs-worker) — 1364 passed.
- [OK] ruff — clean.
- [OK] web lint + typecheck + test — 0 errors / clean / 457 passed.
- [OK] web build — committed `web/static` is identical to a fresh build.

## Findings

### Blockers
- none.

### Majors
- **MJ1 — A second Genesis process on the same `genesis.db` fails every live run of the first.**
  `fail_orphaned_runs` (`runs/manager.py:366-404`) treats every `pending`/`running` run that *this* process does not
  track as orphaned. It cannot tell "my predecessor died" from "another live server owns this run". Nothing stops a
  second app process on the same home: `genesis up` checks its pidfile (`runtime/launcher.py:141-143`), but plain
  `genesis serve` (`cli/main.py:105-125`) has no single-instance guard. uvicorn 0.51.0 runs the lifespan startup
  *before* it binds the socket (`uvicorn/server.py:93` → `:104`). So even a second `genesis serve` on the same port,
  which then dies with "address already in use", first runs the sweep and marks the live server's runs `failed`. On a
  different port, both processes keep running.

  The damage is silent. The first server's workers keep running, but when they finish, `_finalize(DONE)` is a no-op
  because the record is already terminal (`manager.py:139-141`). A completed UX / TD / Breakdown / Test Design run
  never reaches its stage, a top-up ends `failed`, and chat gets a false failure note. The author's own test shows the
  mechanism: `test_the_startup_topup_reconcile_settles_a_run_the_sweep_failed` builds a second
  `RunManager(env.settings)` over the same DB and fails a run the first manager owns. Before H3, a stray second
  process was harmless to runs, because every startup reconcile is adopt-only. This is a new way to lose a run's
  outcome, so I rate it major rather than minor.

  Fix (small): give the sweep an ownership check that a live peer defeats. The simplest is an exclusive
  `fcntl.flock` on a file under the state dir (for example `run/serve.lock`), taken in `create_app`'s startup before
  the sweep. If another live process holds it, skip the sweep with a WARNING, or refuse to start. Add a test: with
  the lock held by another holder, `fail_orphaned_runs` (or the hook) fails nothing.

  If you and the user decide that one process per home is an accepted, documented constraint, this can drop to a
  minor. That is a product decision; the code does not enforce it today. Record it in As built either way.

### Minors
- **mi1 — n4's picker half is not built: the case page still offers Tasks.** The spec says "the case page's story
  picker offers Story-type stories only (D14), and the API refuses a Task link with 422". `TestCasePage.tsx:237`
  (`const all = tree?.coverage.stories ?? []`) still lists every coverage story, Tasks included. A user who ticks one
  now gets a 422 toast via `useTdMutation` (`test-design/hooks.ts:33-36`) instead of never being offered it. Fix:
  filter `all` to `s.state !== "task"`, keeping any Task the case already links (so it can be unticked, matching the
  `keep=` rule), plus a Vitest. You did not mention this deviation.
- **mi2 — The sweep adopts *any* `run.final` that is the last event, not only a gate marker.** `manager.py:394-397`:
  `final_status in TERMINAL or final.seq >= last_seq` → `reconcile_status`. The docstring says "gate/pause marker".
  But a non-terminal stop can also carry another status: `worker._snapshot` passes the state's own `status` through
  when the graph stops with `next` set and no interrupt (`runs/worker.py:109-119`). That status maps to `RUNNING` or
  to nothing in `_STATUS_MAP`, so `reconcile_status` leaves the record `running`, the M3 bug class again. Pause
  writes no `run.final` at all, so "pause marker" never occurs. It is rare today because gates use `interrupt()`.
  Fix: adopt only when `final_status in TERMINAL or (final_status == AWAITING_GATE and final.seq >= last_seq)`, and
  fail otherwise. Add one test case: a last `run.final{"status":"running"}` → failed.
- **mi3 — The m3 poll never stops on a stage whose run failed.** `stageRunInFlight` (`stages.ts:62-64`) is "bound run
  and no chat", the spec's literal predicate. `StageFinalizer` leaves a failed or escalated stage in-progress with
  its `run_id` and no `chat_session_id` (`chat/stage_finalizer.py:14-15`, `:123`). So any feature with a failed stage
  run polls `GET /features/{id}` every 5 s for as long as the page is open, and M3 now turns every orphaned stage run
  into such a row. One local GET every 5 s is cheap, but the poll no longer means "a run is in flight". Fix options:
  stop when the bound run is terminal (the runs list or `useRun` status is already available client-side), or have
  the feature detail carry the bound run's status. Since this is the spec's predicate, a note in As built is also
  acceptable if genesis-spec agrees.

### Nits
- **ni1 — `min-w-[16rem]` on the Title `th` does nothing in a `table-fixed` table.** CSS leaves `min-width` on table
  cells undefined, and Chromium ignores it under fixed layout. The real floor is the table's `min-w-[956px]`
  (`CasesTable.tsx:88`), which the comment and the pin test already state (`fixed + 256`). The class is harmless but
  misleading; drop it, or rephrase the comment so the table min width is named as the mechanism.
- **ni2 — The sweep purges `_toolcalls/` while the orphaned worker may still be alive.** `_finalize` →
  `_purge_tool_store` (`manager.py:151`) runs at startup, but the old worker can live on for about 2 minutes (live
  row 16: pid 11364 exited within about 2 minutes). Its tool captures for that window are lost. The run is already
  failed, so this costs only diagnostics. Mention it next to "the orphaned OS process is not killed" in As built.

### Notes for the H3 As built (spec requirements, not yet written)
The spec asks the As built to record these:
- the orphaned process is not killed (no pid stored);
- which features benefit: `StageFinalizer` (UX), the TD / Breakdown / Test Design bindings, the
  `StoryDesign/ImplementationFinalizer`, `ChatRunSupervisor` notes, `reconcile_topups`;
- the 2xl coverage-column deviation;
- the n4 `keep=` rule.

Add the MJ1 decision and the mi1–mi3 outcomes.

## Verdict: NEEDS_CHANGES

Every gate is green and every H3 sub-item except n4's picker is built and tested. The M1 2xl deviation is justified,
and the n4 `keep=` exemption is sound. The verdict is NEEDS_CHANGES because of one major, **MJ1**: the startup sweep
fails the live runs of any other Genesis process on the same DB, and `genesis serve` has no guard. Fix it with a
home-level lock plus a test, or have the user accept and document a one-process-per-home constraint, which drops it to
a minor. Also fix **mi1** (picker offers Tasks, a spec item not built). **mi2** and **mi3** should change. They are
small and can ride along.

---

## Re-review (round 2) — base b4a9f09 (genesis-review, 2026-10-31)

Scope: `git diff b4a9f09..d138078` in `genesis` (`3dacbf5` backend, `d138078` web + rebuilt `web/static`). Focused
code review of the round-1 findings only. No live rows, no fleet action, nothing written to main's data. HEAD resolves
to `d138078`; `git status --short --untracked-files=all` gives 0 lines.

### Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1366 passed** (188 s) |
| `.venv/bin/ruff check genesis` | All checks passed |
| `npm run lint` | 0 errors, 20 warnings; `npx eslint src/features/test-design` is clean (none in changed files) |
| `npm run typecheck` | clean |
| `npm test` | **50 files / 459 passed** |
| `npx vite build --outDir /tmp/49-08-H3r2-static` + `diff -r … web/static` | **IDENTICAL** |

I did not re-run the before-fix runs (2 backend / 2 web tests failing on the old code). Each new test asserts the new
behaviour directly, so it would fail on the base. The width re-probe is the author's; ni1 removes a class that had no
layout effect, so I did not re-run it.

### Round-1 findings

| Finding | Outcome | Evidence |
|---|---|---|
| **MJ1** second process fails a live peer's runs | **Fixed** | `runs/manager.py` `_hold_run_owner_lock`: `os.open` + `fcntl.flock(LOCK_EX | LOCK_NB)` on `state_dir/run/runs.lock`, fd kept on the instance; `fail_orphaned_runs` returns `[]` with a WARNING when the lock is held elsewhere. The lock path is right: `db_path = state_dir / "genesis.db"` (`runtime/settings.py:237`), so one lock per DB. `flock` conflicts per open file description, so the test's second `os.open` models another process faithfully. The fd does not leak to workers: `os.open` fds are non-inheritable (PEP 446) and nothing in `genesis/` passes `pass_fds` or `set_inheritable`, so an orphaned worker cannot keep the lock alive after its server dies. `genesis down` SIGTERMs, waits, then SIGKILLs (`runtime/launcher.py:183-197`), so a restart through the launcher does not race a dying holder. `fail_orphaned_runs` has one caller, the app startup (`api/app.py`). Test: `test_startup_sweep_skips_everything_while_a_live_peer_holds_the_run_owner_lock` (blocked with the peer holding the lock, no `run.final`, the WARNING text; runs after the peer releases it; re-entrant for the holder). |
| **mi2** adopts a non-terminal `run.final` | **Fixed** | Condition is now `final_status in TERMINAL or (final_status == AWAITING_GATE and final.seq >= last_seq)`; docstring updated (the "pause marker" wording is gone). Test: `test_startup_sweep_fails_a_run_whose_last_stop_is_a_non_terminal_running_marker`. The round-1 gate tests (`…adopts_a_last_gate_marker_but_fails_a_resumed_then_lost_run`, `…adopts_a_durable_run_final_instead_of_failing`) still pass. |
| **mi1** case-page picker offers Tasks | **Fixed**, plus the Add case dialog | `TestCasePage.tsx:237-240` filters `state !== "task"` but keeps a Task the case already links (matches the API `keep=` rule). `TestsTab.tsx:241` filters the Add case dialog; create has no `keep=`, so a plain filter is right. Tests: `Add case dialog offers Stories only — no Task links` and `story picker offers Stories only, plus a Task the case already links` (the second also asserts an unlinked Task, GNS_000126, stays hidden). |
| **mi3** poll does not stop on a failed stage run | **Accepted as a recorded follow-up** | Unchanged by decision. It is the spec's literal predicate, and changing it needs either a contract + fixture change or extra run reads. I said in round 1 that a note is acceptable; it must appear in the H3 As built as a follow-up for genesis-spec. |
| **ni1** inert Title `min-w-[16rem]` | **Fixed** | Class dropped (`CasesTable.tsx:93`); comment names the table min width as the floor; the pin test now asserts no `w-[` / `min-w-[` on Title and `table min-w = fixed + 256`. |
| **ni2** `_toolcalls/` purged under a live orphan | **Documented only** (acceptable for a nit) | To be recorded in As built next to "the orphaned OS process is not killed". |

### Checklist (`genesis-ctx check --since b4a9f09 --repo genesis`; areas runs-worker, release-ci, security)

ADRs
- [OK] ADR-001 — the lock and sweep are program code in the run layer; no agent orchestration.
- [N/A] ADR-008 — bundling unchanged.
- [OK] ADR-009 — paused and awaiting-gate runs are still never touched; a last gate marker is still adopted (mi2 narrows adoption only for non-gate stops).
- [OK] ADR-010 / ADR-018 / ADR-022 — no state or blackboard change; `runs.lock` is under `state_dir`, not the artifacts root.
- [N/A] ADR-011 — no agent node changed.
- [OK] ADR-012 — the app still imports no workflow Python. The lock now enforces the sweep's "my workers only" assumption against a live peer.
- [N/A] ADR-021 — gates unchanged.
- [OK] ADR-023 — still a FastAPI startup hook.
- [OK] ADR-024 — the sweep (now including the `flock`, which is non-blocking) still runs via `asyncio.to_thread`.
- [N/A] ADR-025 — no fork change.
- [OK] ADR-026 — no network surface; the lock file is `0o600`.
- [OK] ADR-027 / ADR-055 — the web diff removes one Tailwind class and filters two lists; no new primitives, colors or deps.
- [OK] ADR-028 — no new client call.
- [OK] ADR-030 — SQLite unchanged.
- [N/A] ADR-031 / 032 / 033 / 034 / 035 / 037 / 041 / 045 / 047 / 054 / 063 / 065 / 066 / 068 / 069 / 073 / 074 / 076 — not touched.
- [OK] ADR-077 — `genesis-ctx check` used; no bulk docs read.

Lessons
- [OK] L-003 — swept runs still go through `_finalize`, which closes the bus.
- [OK] L-004 — SQLite data plane; the lock is a coordination file, not data.
- [OK] L-005 — canonical kinds only.
- [OK] L-008 — the specific orphan `error` is unchanged.
- [N/A] L-009 / L-016 / L-018 / L-020 / L-021 / L-023 / L-033 / L-050 / L-059 / L-060 / L-066 / L-087 / L-088 — not touched.
- [OK] L-017 / L-045 — no trust change.
- [OK] L-025 / L-027 — ruff pin unchanged; clean.
- [OK] L-026 — off the event loop.
- [N/A] L-030 / L-051 / L-056 / L-057 — no release here. At release, ship `3dacbf5` and `d138078` together with the round-1 commits.
- [OK] L-058 — level-triggered recovery kept, and it can no longer misfire against a live peer.
- [OK] L-061 / L-062 — finalizer scoping unchanged.
- [OK] L-065 — a terminal `run.final` is still adopted, never failed.
- [OK] L-081 — the startup default now also respects a peer's live runs.
- [OK] L-089 — bundle fresh (`diff -r` identical), tree clean.

Gates
- [OK] pytest — 1366 passed.
- [OK] ruff — clean.
- [OK] web lint / typecheck / vitest / build — 0 errors / clean / 459 passed / identical.

### Findings (round 2)

Blockers: none. Majors: none.

Minors
- **mi4 — The lock decides who sweeps, not who runs workers.** A second `genesis serve` that fails to get the lock
  still starts and spawns its own workers. If the lock holder (A) then restarts while the second server (B) is
  still up with a run in flight, the new A takes the freed lock and fails B's live run. This is the MJ1 failure
  again, narrowed to two concurrent servers on one home plus a restart of the first. It comes from the "skip the
  sweep with a WARNING" option I offered in round 1, so I do not ask for a code change in H3. Record it in As built
  as a known limitation. The full fix, if wanted later, is for a server that cannot get the lock to refuse to start,
  or to take the lock before it spawns any worker.

Nits
- **ni3 — The lock fd is never closed when a `RunManager` is discarded.** That is correct in production, where there
  is one manager per process. In the test suite each manager that sweeps keeps one fd until the process exits. It is
  harmless at the current scale; it does not need a change.

### Verdict: **SHIP**

MJ1, mi1, mi2 and ni1 are fixed and each has a regression test. I re-ran every gate and all are green, and the
bundle is fresh. mi3 and ni2 are accepted as notes. Before 49-08 closes, the H3 As built must record: mi3 as a
genesis-spec follow-up, ni2 and mi4 next to "the orphaned OS process is not killed", the run-owner lock
(`state_dir/run/runs.lock`), and the round-1 notes (2xl coverage deviation, the n4 `keep=` rule, which features
benefit from the sweep).
