# Backlog — Phase 54 follow-ups (Schedules, custom agents, fixes and UX revamps)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-20 by the spec agent with the two items found in 54-10's
> round 2 (D52). Appended 2026-11-20 at the Phase 54 write-back (genesis-docs): §3 the umbrella §9 deferred scope, §4
> the build findings, §5 the flaky reap test, §6 write-back findings, §7 the release leftovers.

## 1. m7 — a one-time schedule paused during its run gets a false "missed" row on Resume (54-10 round 2)

- **Case:** a `once` schedule fires; while its run is still in flight the user pauses the schedule; after the run ends
  the user resumes it. Resume records a second row, `missed`, for the slot that already ran, and the Schedules list then
  shows the schedule's last result as **Missed**.
- **Repro:** `/tmp/54-10-probe/once_resume2.py` (genesis-review, 2026-11-20; the script is not in a repo, rebuild it
  from this description if it is gone).
- **Cause:** `ScheduleStore.set_pause` (`genesis/runtime/schedule_store.py`) applies 54-12's m1 rule (a past `once`
  resumed → `missed`, completed) without checking whether that slot already fired.
- **Fix direction:** in `set_pause`, record `missed` only when the slot has no `schedule_runs` row that fired;
  otherwise mark the schedule completed with no new row. Regression test from the repro.
- **Why deferred:** the user's choice (D52): shipped as a known issue, named in the 54-11 release notes.

## 2. The parser's bundle count depends on filesystem order (54-10 round 2, python:3.13 run)

- **Symptom:** `test_parse_returns_populated_result` finds 179 bundles instead of 174 when the suite runs in
  `python:3.13` under colima; on macOS and in the amd64 CI it finds 174.
- **Cause (reviewer's reading):** the parser walks the unzipped package with `os.walk` (`packages/genesis-appian-parser`),
  whose order depends on the filesystem; bundle assembly is order-sensitive.
- **Why it matters:** the same package can produce a different KB on different machines (a correctness bug, not only an
  ordering nit). It predates Phase 54; the parser has not changed since v0.82.0.
- **Fix direction:** sort the walk (directories and files) and any set iteration that feeds bundle assembly; add a test
  that parses one package with two different walk orders and expects identical bundles. Check whether `KB_FORMAT_VERSION`
  needs a bump if stored bundles change.

## 3. Deferred scope (umbrella §9, D3, D6, D13)

Not built in Phase 54, by decision:
- previous-run context for agent prompts (D13: a per-schedule toggle that copies the last successful `output.md` into
  the run by reference);
- cron expressions (D9);
- event or webhook triggers;
- output destinations (posting agent output to chat spaces or Google Workspace);
- per-schedule credit caps;
- schedule-level retries (retries stay inside the run, ADR-011);
- schedule templates, folders, tags;
- Hub-shared schedules (F11: user schedules stay on the machine that holds them);
- custom agents in Copilot or the spec-style chat modes (D6);
- write-capable MCP servers in agent-prompt schedules (D3; would need a `pre_mutation` gate per run, ADR-021);
- URL changes (D16).

## 4. Found during the build, not fixed (54-02..54-12 As built, the umbrella §9 list, 54-10 round 2)

Backend:
- **Fall-back hour (54-04):** `slot_key` drops `fold`, so a schedule edited inside the repeated hour when clocks go back
  could re-fire a slot from that hour's first pass (one hour a year; reasoned by the reviewer, not reproduced).
- **Blocking calls on the loop, pre-existing (54-04, L-026):** `memory_jobs._kiro_ready` / `_installed` and
  `start_sync` inside the serial app sync still run on the event loop.
- **Accepted nits (54-04 review):** n1, a third copy of the `_installed` / `_kiro_ready` helpers; n4, a few-bytecode
  window between the open row's commit and `_mine.add`.
- **agent-prompt feedback (54-05 review n4, n5):** feedback from an earlier gate round stays in later prompts
  (`decisions` merges); a hand-sent non-string Feedback makes `build_prompt`'s `.strip()` raise (the UI always sends a
  string).
- **L-106 pattern in the memory workflows (54-05, pre-existing):** `memory-consolidation` and `memory-maintenance` route
  every non-approve answer, Feedback included, to their reject path.
- **`agent-prompt` needs genesis ≥ 0.83.0 (54-05, 54-11):** nothing enforces it; the major-only gate (ADR-019) lets a
  0.82 app load it, and the run fails at its first node.
- **Runs left `running` by a pre-fix state edit (54-02, D21):** not repaired; `reconcile_status` keeps adopting their
  `run.final{running}` marker. Users cancel them by hand (release notes); a stuck `sync-application` run blocks that
  app's scheduled sync.
- **Catch-all 405 has no `Allow` header (54-02 review N2).** No client reads it.
- **Discard of a failed capture whose run is still live (54-02 review N3)** cancels the run in one click, without the
  confirm the gate-waiting card has (rare: a finalizer fails a capture only on a terminal `run.final`).
- **A sync-option range refusal (such as 150 %) is a field-less 400 (54-07 decision 10)**, shown as the general message
  on Review, not on its field.
- **Feature Activity (54-09):** pages by offset over a newest-first list, so an item arriving between "Load more"
  clicks repeats once (page by the oldest `at` shown instead); a re-run overwrites `kb_feature_stages.run_id`, so
  older runs of a stage are not listed; stage status writes outside `LifecycleService` (the deprecated
  `PATCH …/spec/status`, the re-run/re-upload resets in `api/features.py`, `StageFinalizer`'s fallback `set_status`)
  leave no audit row and are not shown; a stage card's "Last run" shows only the status (the stage row stores no run
  time).
- **The pause 503 corner case (54-12 review r2-n3):** when the worker dies during the retried status write, the 503
  text still says "the run is still running" although the run has just failed.

Web:
- **Opacity modifiers on token colours that still render nothing (54-03, 54-07; L-123):** `TopBar.tsx`
  (`bg-surface-1/70`), `RunDetailPage.tsx` (`bg-surface-1/70`), `LaunchForm.tsx` (`border-warning/30`,
  `border-info/30`, `border-danger/40`), `SetupView.tsx` (`border-warning/40`), `Badge`'s `primary` tone
  (`bg-primary/15`), the run-inspection mockup. Either replace them with `*-subtle` tokens or define the colours with
  `<alpha-value>` in `tailwind.config.ts`; check each page in a real browser, since some were approved without the tint.
- **54-12 review r2-n1, r2-n2:** `isAttention` in `web/src/features/runs/hooks.ts` has no caller left; the Clear read
  error toast has no test.
- **Provisioned skill files in a run's documents (54-10 n5):** an agent-prompt run lists its `.kiro/skills/**` files;
  the fix belongs in the manifest or the route.
- **Application-sync detail (54-10 n7):** the header says "Last result OK" (the m4 fallback) while History says "No runs
  yet" until the first run after m0030; optionally a line under History, "Last run before schedules were added: <time>".

Probes:
- `scripts/probes/phase54-ux-pages.mjs` waits for seed-only text ("Design stage") and its init script reads
  `localStorage` in sandboxed frames (54-10 round 2); `phase54-12-probe.mjs` guards this, the older probe does not.

## 5. Flaky on Linux: `test_reap_kills_a_recorded_group_that_is_still_ours` (54-11 As run)

- `tests/test_testexec_procs.py::test_reap_kills_a_recorded_group_that_is_still_ours` failed on genesis `master`
  **#7429033** (2026-11-15, `ea00dfd`) with `assert [] == [6524]`, and passed in #7514744, #7515740 and #7516285.
- **Reading (genesis-release):** reap probably reads `ps` before the long-lived child has exec'd with its marker, so the
  group is not yet recognised as ours.
- **Fix direction (genesis-dev):** have the test wait until `ps -ww` shows the child's marker before calling reap, or
  have reap re-read once; reproduce under load in the CI image first (L-104, L-112).

## 6. Found at the write-back (2026-11-20, genesis-docs; code at v0.83.0)

- `POST /custom-agents/{id}/run` answers a refused server as 422 `{detail}` with no `field` or `refused`, against the
  54-06 `{detail, field, refused?}` convention (`genesis/api/custom_agents.py`, `HTTPException(422, str(e))`).
- The Agents editor's Name field allows 120 characters (`AgentsTab.tsx` `maxLength={120}`); the store allows 60, so a
  longer name is refused with a 400 on save.
- `ChatSession._clear` (`genesis/chat/manager.py`) recomputes the MCP notice without the refused custom-agent picks, so
  after `/clear` on a live client they are not reported again.
- Stale code comments: `web/src/lib/api/chat.ts` still says a valid agent answers 409 "until 54-08"; the
  `scheduler.py`, `schedule_store.py`, `api/app.py` and m0030 docstrings say "ADR-087 draft"; `memory_jobs.py` says
  consolidation runs "before the 07:00 app-sync" (the first slot is 08:00); `validate_sync_options`'s docstring calls
  the current route "the old `PUT /schedules/{id}`"; `ScheduleStore.regression_for` says it returns "the oldest" row
  (D40 allows only one).

## 7. Release leftovers for the user (54-11 As run)

- The CI branch `ci/phase-54-pre-release` was deleted from origin by the user (2026-11-20).
- Delete `/tmp/genesis-release-54-11/` (it holds the user's databases in `backup/`; keep it until v0.83.0 is trusted),
  `/tmp/colima/gr-54-11` and `/tmp/genesis-release-54-11/img1` (copies of public repo trees).
