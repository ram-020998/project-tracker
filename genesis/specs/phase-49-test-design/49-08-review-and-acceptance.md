# 49-08 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-10-26. Repos: genesis, genesis-workflows. Parent: `specs/phase-49-test-design.md`.
> Run by **genesis-review** (read-only on code) after 49-02..49-07 are BUILT; report in
> `specs/phase-49-test-design/reviews/49-08-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed by genesis-dev
> before release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **Stage plug-in only** — `test_design` added via `VALID_STAGES`, `ArtifactKind`, one `_Binding`, one
   `ChatModeProfile`, one `STAGE_DEFS` row + `gate`, one registry entry; no shell edits (ADR-056).
2. **Gate on both sides** — start/re-run/top-up 409 before stories are finalized; the card is locked (L-063).
3. **Finalize once** — `finalized_at` guard; ids allocated inside the tx in document order; re-run/Reopen refused after
   (R5); a garbled document → 422, never a partial suite.
4. **Ids** — `TC-`/`TS-` from `kb_sequences`, never reused/renumbered (D4).
5. **Lifecycle** — every status change through `LifecycleService` (ADR-050); retire-while-referenced refused;
   hard delete only Draft + unreferenced (D15).
6. **Links** — no FK to `wiki_object_pages`; no stub wiki pages created (D5, ADR-070); a hallucinated UUID can't become
   resolved (R3); derived states computed on read (R2).
7. **D7 linker** — deterministic, idempotent, never blocks the implementation lane move; startup reconcile (L-058).
8. **Impact** — stores no impact data, no Hub call (it may resolve pending links first, R8); current edges only; no 200
   cap; depth clamp; retired excluded; R1 honoured.
9. **Workflow** — reliability trio on every agent node (ADR-011, `validate_library`); healing bounds; read-only
   allowlists; no giant emission (L-064); per-epic map + single scenario turn (L-076); JSON contract = 49-03 §4.
10. **Chat** — read-only + sandboxed fs only (ADR-031/045); `_STEERING_TEST` keeps JSON ↔ HTML in sync.
11. **Web** — existing primitives/tokens only (ADR-027/055), no `<Button asChild>` (L-069), `/api` central (ADR-028),
    types = contract fixtures (L-011), jest-axe clean, `aria-sort` on sortable headers.
12. **Naming** — no new `test_*.py` / `*_test.py` modules outside test folders (R6).
13. **No Hub / collab change** (D12); collab columns present. The `test_design` stage artifact is refused on publish,
    left out of the bulk publish of existing work, and skipped on pull (49-04 As built) — check all three paths.

### 1.1 Hardening (built by **genesis-dev** before the review runs; the reviewer checks it like the rest)

- **H1 — record the terminal status before announcing `run.final` (49-01 D17).** Today `RunManager._finalize`
  (`genesis/genesis/runs/manager.py:122-142`) calls `self._log(run_id, RUN_FINAL, …)`, which notifies every observer,
  and only then `self.store.set_status(…)`. Every finalizer that checks `rec.status == "done"` on the event returns
  early: `StageFinalizer` (UX, Technical Design, Breakdown, Test Design), `StoryDesignFinalizer` and
  `StoryImplementationFinalizer`. Those stages finish only on the next level-triggered read or at restart (L-058 masked it).
  1. In `_finalize`, call `store.set_status(run_id, status, …)` **before** `_log(run_id, RUN_FINAL, …)`. Keep the
     idempotency guard at the top as is. If `set_status` raises, still emit `run.final` and close the bus (never leave a
     run without its terminal event), and log loudly.
  2. Same order in the non-terminal `final` branch of `_spawn.on_event` (gate / pause): `set_status` first, then the
     `run.final` marker.
  3. Grep every observer registration (`_observers`) and confirm none relies on the old order (record the list in As
     built).
  4. Tests: a regression test with a real `RunManager` and a fake worker event stream, where an observer reads
     `store.get(run_id).status` at the moment it receives `run.final` → `done` (fails before the fix); a live-path test per
     finalizer family (stage, story design, story implementation) that does **not** set `done` by hand first; fix the
     existing tests that pre-set `done` so they no longer hide the order (a stub must mirror reality).
  5. Keep the level-triggered recoveries (`reconcile*`, 49-06's `reconcile_stage` on reads) as the safety net.
  6. Own genesis commit; gates `pytest` + `ruff`; As built in this sub-spec; lesson candidate for genesis-docs
     ("announce a terminal event only after the state it describes is stored").

#### H1 — As built (genesis-dev, 2026-10-22)

**Commits:** genesis `d62ae03`, "fix(runs): 49-08 H1 — store the run status before announcing run.final (terminal +
gate/pause paths)" (base `73b3bd3`, the 49-06 commit). 9 files; `git status` clean after the commit (L-056). Local only;
nothing pushed or tagged. No other repo changed.

**Changed**
- `genesis/runs/manager.py`: new `_store_status(run_id, status, *, detail=None)` wraps `store.set_status(…, enforce=False)`;
  a failure is logged at ERROR (`exc_info`) and swallowed so the caller still announces. `_finalize`: guard unchanged →
  optional `error` event → `_store_status` → `run.final` → bus close → tool-store purge. The gate/pause branch of
  `_spawn.on_event`: `_store_status` → `run.final` marker; bus stays open. Module logger added; docstring updated.
- `genesis/chat/supervisor.py` (review M1): `ChatRunSupervisor.reconcile`'s terminal branch now back-fills a note only
  when `eventlog.latest(run_id, "run.final")` exists **and** its payload status equals the record's; the dedup seq comes
  from that event (the seq-0 fallback is gone). Without this, a notification-stream connect landing in the new
  one-write gap (status stored, `run.final` not yet appended) would key the note differently from the live one and post
  "finished" twice.
- `genesis/services/testdesign_stage.py`: `settle_topup` docstring only (the store now holds the status when observers
  run; settling on the payload status still works and was kept).

**Observer audit (H1.3).** Six observers are registered on the app `RunManager`, all in `api/app.py`:
`ChatRunSupervisor` (:101, payload status + `rec.workflow_id`), `StageFinalizer` (:106, needs `rec.status == "done"`),
`SyncLinkObserver` (:142, payload status + `rec.workflow_id`/`inputs`), `TopupRunObserver` (:149, payload status),
`StoryDesignFinalizer` (:164, needs `done`) and `StoryImplementationFinalizer` (:170, needs `done`). The recovery-only
`StageFinalizer` in `api/features.py:349` is never attached. The only bus subscriber is `api/run_routes.py`
`events_stream` (bus + durable log only). No live observer relied on the old order; the three `done`-checking finalizers
were broken by it. One **level-triggered** path did interact with the new order (`ChatRunSupervisor.reconcile`, fixed above).

**Tests** (genesis **1355 passed**, base 1346 + 9 new; `ruff check genesis` clean;
`ruff check .` shows the same 28 pre-existing errors in `tests/`/`scripts/` as the base):
- `tests/test_runs.py` +5: a `_ScriptedSupervisor` replays real worker event shapes (incl. the trailing `worker_exit` on a
  non-zero exit) through the **real** `RunManager.on_event/on_exit`, with an observer that reads `store.get(run_id).status`
  on `run.final` — done, failed (`error` + `worker_exit`, `detail` not clobbered, L-008), gate (`awaiting_input:gate`,
  `pending_gate` works, bus open), and a failing status write (one `run.final`, bus closed, ERROR logged); plus a
  real-subprocess-worker variant.
- Live-path tests per finalizer family that no longer hand-set `done` (the run is created `running` and ended with
  `rm._finalize(run_id, "done")`, so `run.final` reaches the attached finalizer): stage — `test_features_api.py` UX, TD
  and Breakdown finalizer tests and `test_test_design_stage.py::test_finalizer_binds_a_design_run_and_ignores_a_topup_run`
  (also drives the top-up skip through the live path); story design —
  `test_story_design.py::test_finalizer_live_run_final_moves_to_review` (real `RunManager`); story implementation —
  `test_story_implementation.py::test_finalizer_live_run_final_advances_to_code_review` (real `RunManager`).
- `tests/test_supervisor.py` +2: reconcile back-fills a missed terminal and the live event dedups; reconcile in the gap
  (no `run.final` yet / only the earlier gate marker) creates no note.
- Before-fix evidence: with the base `manager.py`, all 5 new `test_runs` tests and the 6 live-path tests fail (e.g.
  `[('failed', 'running')] != [('failed', 'failed')]`); with the base `supervisor.py`, the gap test fails (2 duplicate
  notes). The reviewer reproduced both in a `/tmp` copy.
- Kept on purpose: the `_FakeRM`-based direct `_finalize` unit tests (finalize logic, not the live path) and the
  reconcile/self-heal tests that legitimately use a `done` run (H1.5 — `reconcile*`, `reconcile_stage` untouched).

**Review:** genesis-review, `reviews/49-08-H1-review.md`. Round 1 **SHIP** with M1–M3, N1–N3. Fixed M1 (supervisor
reconcile), N1 (stale comment in `_ready_topup`) and N3 (scripted `worker_exit`). Re-review **SHIP**, nothing new. M2 =
this commit + As built. N2 (tests read the private `EventBus._closed`, as existing `test_runs.py` style does) left as is.

**Decisions / deviations** (no ADR deviation):
1. A failed status write still emits `run.final` and closes the bus (never leave a run without its terminal event). The
   record then stays non-terminal in this process until a restart, when `reconcile_status` adopts the durable
   `run.final` (it skips runs whose worker is still tracked here).
2. M1 trade-off (accepted by the reviewer): a terminal run with **no** matching durable `run.final` is no longer
   back-filled by chat reconcile. That happens only after retention reclaimed its events (the old seq-0 key would have
   re-posted a stale duplicate), for legacy pre-07-02 runs, or when `eventlog.append` itself raised (then the live
   observers never ran either). Every normal terminal write appends a `run.final` with the same status.
3. 49-04 As built decision 2 ("`_finalize` calls the observers before it writes the run status") is superseded; top-ups
   keep settling on the payload status, which remains correct.

**Lesson candidates (for genesis-docs)**
- "Announce a terminal event only after the state it describes is stored" — observers re-read the store on the event;
  announce-then-store made every live finalizer a silent no-op that L-058's recoveries masked for months.
- Corollary: when you reorder store vs announce, audit the **level-triggered** readers too — a reconcile keyed on the
  event (dedup by seq) can now see the state without the event and must wait for the event.

**Follow-ups (backlog, not built):** review M3 — `_finalize`'s idempotency guard is check-then-act with no lock; a
`cancel()` and a worker-exit finalize can still both pass it (window narrowed by H1 to one write). A per-run lock or a
conditional `UPDATE … WHERE status NOT IN (terminal)` would close it.

**Code-map changes:** `runs/manager.py` — `_store_status` (stop-status write ahead of `run.final`; logged, never blocks
the announcement); stop paths are now store → announce. `chat/supervisor.py` — `reconcile` back-fills a terminal note only
from a durable `run.final` whose status matches the record.

- **H2 — feature roll-up status: Draft only when nothing has started (49-01 D18).** Change `deriveFeatureStatus`
  (`genesis/web/src/features/features/stages.ts:139-145`), the only roll-up (used by `FeaturePage.tsx`; no backend copy):
  over the **available** stages — **Completed** if every one is `completed`; **Draft** if every one is `not-started` or
  `draft`; otherwise **In progress** (this includes `in-progress`, `in-review`, `under-change`, and any mix of completed
  with not-started). Keep the existing tones (success / neutral / info) and the function signature.
  Tests in `stages.test.ts`: all completed → Completed; all not-started → Draft; all draft → Draft; four completed +
  Test Design not-started → In progress (the case that showed Draft); Spec completed + rest not-started → In progress;
  any under-change → In progress; a not-available stage is ignored. Gates: `npm run lint && npm run typecheck && npm test`,
  then `npm run build` and commit `web/static/` as a separate sequential step, then rebuild and confirm an empty
  `git status` (L-089). Own genesis commit; As built under this item.

#### H2 — As built (genesis-dev, 2026-10-26)

**Commits:** genesis `f0df126`, "fix(web): 49-08 H2 — feature roll-up is Draft only when no stage has started (49-01
D18); any partial progress is In progress; tests; rebuilt web/static" (base `45be579`). 63 files: the 2 source files +
`web/static` (new `index-tAipGU80.js`, `index.html`, and the 55 lazy mermaid chunks whose hashes follow the index chunk).
Local only; nothing pushed or tagged. No other repo changed.

**Changed**
- `web/src/features/features/stages.ts` `deriveFeatureStatus`: over the available stages, Completed if every one is
  `completed` (unchanged); then **Draft** if every one is `not-started` or `draft`; otherwise **In progress** (tone
  `info`). The old order defaulted to Draft unless some stage was `in-progress`/`in-review`, so a mix of completed and
  not-started stages, and `under-change`, showed Draft. Signature and tones unchanged; docstring updated. The only caller
  is `FeaturePage.tsx:72` (no backend copy, as the spec says).

**Tests** (`stages.test.ts`, the old `deriveFeatureStatus` block replaced by 8 tests that cover all 7 listed cases plus
in-progress/in-review): all completed → Completed/success; all not-started → Draft/neutral; all draft (and draft +
not-started) → Draft; four completed + Test Design not-started → In progress/info; Spec completed + rest not-started →
In progress; under-change with the rest completed, and with the rest not-started → In progress; a `available: false`
stage with status `not-available` is ignored (all-not-started + it → Draft, all-completed + it → Completed).
- Before-fix evidence: with the base `stages.ts` (stashed), 3 of the new tests fail (`expected { label: 'Draft' … } to
  deeply equal { label: 'In progress' … }` for the four-completed case, the Spec-completed case and the under-change case).
- Gates: `npm run lint` 0 errors (20 warnings, all in files this change does not touch; `eslint` on the two changed files
  is clean); `npm run typecheck` clean; `npm test` **49 files / 450 tests passed**.
- Bundle (L-089): `npm run build` ran as its own call after the edits; the built `index-tAipGU80.js` contains
  `every(o=>o==="not-started"||o==="draft")?{label:"Draft"…}:{label:"In progress"…}`; committed; then a fresh
  `npm run build` followed by a separate `git status --short --untracked-files=all` → empty (0 lines).

**Review:** not run separately. The user asked for H2 without the 49-08 review, and §1.1 has the 49-08 reviewer check
the hardening items with the rest.

**Decisions / deviations:** none; no ADR deviation. With zero available stages the roll-up is still Draft (same as before).

**Lesson candidates:** none new. Process note for genesis-docs: twice this session the agent batched a read-only
`git status` with `npm run build` in one parallel call (L-089's pattern). No commit was affected because each status
was re-run alone before it was relied on. L-089 could say explicitly that the proof's `git status` must also run in a
separate call after the build.

**Code-map changes:** `features/stages.ts` `deriveFeatureStatus`: Completed (all completed) → Draft (none started) →
else In progress.

- **H3 — fixes for the 49-08 live acceptance (49-01 D19; findings in `reviews/49-08-review.md` §4).** Built by
  genesis-dev in one session, own genesis commit(s); As built under this item. Then genesis-review re-reviews H3 and
  re-runs §3 rows **6, 15, 16 and 18** (the width scripts are in `/tmp/genesis-review/row15-*.js`).
  1. **M1 — Cases table Title collapses (row 15a).** `web/src/features/test-design/CasesTable.tsx:73-83`: the seven fixed
     columns (808 px) don't fit the 647–754 px container at 1280/1440. Give **Title** no fixed width and a floor
     (`min-w-[16rem]`); narrow the other columns to what their content needs (measure); and below `2xl` stack the Story
     coverage panel **under** the table instead of beside it, so the table gets the full width. Acceptance: Title
     ≥ 240 px and no horizontal scroll at 1280, 1440 and 1920, light and dark; keep a class-level pin test (L-090).
  2. **M2 — controls spill out of the five stage cards (row 15c).** `FeaturePage.tsx:168` `xl:grid-cols-5` gives
     187–261 px cards. Use `xl:grid-cols-3 2xl:grid-cols-5` **and** make the card footer actions wrap (`flex-wrap`,
     `FeaturePage.tsx:269`). Acceptance: no control past its card edge at 1280, 1440, 1920, both themes.
  3. **M3 — a run orphaned by a restart stays `running` forever (row 16).** In genesis's run layer: at app startup,
     after the stores are open and **before** the finalizers' and `TestDesignStageService`'s startup reconciles run,
     sweep every run whose status needs a live worker (`running`, and any pre-running state) and that has no durable
     `run.final` — a fresh process tracks no workers, so each such run is orphaned — and finalize it through
     `RunManager._finalize(run_id, FAILED, detail="worker lost across a server restart", error=…)`. Never touch
     `paused` / `awaiting_gate` runs (they have no worker by design, ADR-012) or terminal runs. Startup only — not on
     read (a read could race a run that is still spawning). The orphaned OS process is not killed here (no pid is
     stored; it exits when its pipe closes) — record that in As built. Tests: a real `RunManager` with a recorded
     `running` run, no worker, no `run.final` → startup sweep → `failed` + one `run.final`; a `paused` and an
     `awaiting_gate` run untouched; a `running` run **with** a durable `run.final` adopts it (existing
     `reconcile_status`), not failed; `TestDesignStageService` startup reconcile then settles the top-up `failed` and a
     new top-up is allowed. List every other feature that benefits (stage / story finalizers, chat supervisor) in As
     built.
  4. **m1 — "Publish to team" on the Test Design workspace.** Add `localOnly: true` to the `test-design` `STAGE_DEFS` row
     and have `StageArtifactWorkspace.tsx:211-218` skip `PublishToTeamButton` for local-only stages; Vitest with collab
     enabled.
  5. **m2 — Reopen refusal after test Finalize names the spec.** Make the reopen refusal reason stage-aware: for
     `test_design` → "the test design is finalized — its records are authoritative; use Generate tests for uncovered
     stories" (R5). Extend `test_rerun_and_reopen_are_refused_after_finalize` to assert `detail.reason`.
  6. **m3 — running stage pages don't refresh themselves.** `useFeature` (`web/src/features/features/hooks.ts:30-36`)
     polls every ~5 s while any stage row has a `run_id` and no `chat_session_id` (UX, Technical Design, Breakdown and
     Test Design all share this), and stops otherwise — the same pattern as the busy change-request poll
     (`hooks.ts:384`). Vitest with fake timers (polls while running, stops after).
  7. **m4 — Test Impact Key wraps.** `whitespace-nowrap` on the key cells (`TestImpactTab.tsx:200`) and size the column
     to fit `TC-000000` at 1440.
  8. **n1** fix the two pre-H1 comments (`api/testdesign.py:224-226`, `tests/test_test_design_stage.py:4-5`); **n2** add
     the R8 `_resolve` to `GET /test-scenarios/{id}`; **n3** the retired-step refusal names the case key (`TC-000018`), not
     `#18`; **n4** the case page's story picker offers Story-type stories only (D14), and the API refuses a Task link with
     422.
  Gates: genesis `pytest` + `ruff`; web `lint` + `typecheck` + `vitest`; `npm run build` and commit `web/static/` as
  separate sequential steps, then a fresh build + empty `git status` (L-089).

#### H3 — As built (genesis-dev, 2026-10-31)

**Commits** (genesis only; base `f0df126` = H2; local, nothing pushed or tagged; `git status` empty after each):
- `9324a76` backend: M3, m2, n1–n4 + tests.
- `b4a9f09` web: M1, M2, m1, m3, m4 + tests + rebuilt `web/static`.
- `3dacbf5` backend, review round 1: MJ1 run-owner lock, mi2 adopt rule, tests.
- `d138078` web, review round 1: mi1 pickers, ni1 + tests + rebuilt `web/static`.

Ship all four together (release is 49-09).

**Changed**
- **M3**: `runs/manager.py` `RunManager.fail_orphaned_runs()`.
  - Startup only, wired first in the `_bind_supervisor` startup hook (`api/app.py`, after `bind_loop`, via
    `asyncio.to_thread`). So it runs before the supervisor, stage and story reconciles and before
    `_reconcile_test_links` / `reconcile_topups`; FastAPI runs startup hooks in registration order.
  - It first takes an exclusive non-blocking `flock` on `state_dir/run/runs.lock` (`_hold_run_owner_lock`) and holds
    it for the process lifetime. If a live peer holds the lock, it does nothing and logs a WARNING (review MJ1).
  - It then looks at every `pending`/`running` run with no worker tracked in this process:
    - latest `run.final` terminal, or an `awaiting_input:gate` marker that is the run's last event → adopted via
      `reconcile_status`;
    - anything else (no `run.final`, a gate marker followed by later events = resumed then lost, or a non-terminal
      `running` stop, review mi2) → `_finalize(FAILED, detail=error="worker lost across a server restart")`. That
      writes `error` → the stored status → `run.final` → bus close (the H1 order).
  - Paused, awaiting-gate and terminal runs are never listed. A run that fails to sweep is logged at ERROR and does not
    stop the sweep; the list of failed ids is logged at WARNING.
  - `ORPHANED_DETAIL` constant.
- **m2**: `domain/transitions.py` — `SPEC_PRECONDITION_REASONS[(COMPLETED,"reopen")]` is now a callable,
  `_reopen_locked_reason`. For `ctx["stage"] == "test_design"` it returns `TEST_DESIGN_REOPEN_REASON` ("the test
  design is finalized — its records are authoritative; use Generate tests for uncovered stories"); otherwise the
  spec's message, unchanged. `services/spec_change.py` `stage_ctx` adds `"stage"`.
- **n1**: comments in `api/testdesign.py` (`_heal_stage`) and `tests/test_test_design_stage.py` (module docstring).
- **n2**: `GET /test-scenarios/{id}` runs `_resolve(app_uuid)` first (R8).
- **n3**: `kb/testdesign.py` `_check_step_cases` refusals name the case key: "test case TC-000018 is retired — remove
  its step first". A row that doesn't exist still says `#id`.
- **n4**: `kb/testdesign.py` `_suite_stories(…, keep=)` refuses a NEW Task link ("GNS_000124: Tasks get no own test
  cases — link Stories" → 422) on `create_case` and `set_case_stories`. Links the case already has are exempt. Web
  (review mi1): the case page story picker (`TestCasePage.tsx`) offers `state !== "task"` stories plus any Task the
  case already links, so it can be unticked. The Tests tab **Add case** dialog (`TestsTab.tsx`) offers Stories only.
- **M1**:
  - `CasesTable.tsx`: columns sized from a real-browser probe of their widest content (header, one badge, or one key
    per line). Key 96, Type 108, Priority 88, Status 80, Stories 92, Scenarios 100, Review 136 px; the narrow columns
    use `px-2`.
  - Title has no width. Its 16rem floor is the table's `min-w-[956px]` (= 700 + 256), because a cell `min-width` is
    ignored under `table-fixed`.
  - Story and scenario keys render one per line (`KeyList`). The comma-joined list had wrapped a lone "," onto its
    own line.
  - `TestsTab.tsx`: below `2xl` the coverage panel stacks under the views. From `2xl` it sits in a fixed 16rem column
    (`2xl:grid-cols-[minmax(0,1fr)_16rem]`). When stacked, the coverage list is a `md:2 / xl:3` grid.
- **M2**:
  - `FeaturePage.tsx` stage grid: `sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-5`; the card footer is `flex-wrap`.
  - `SpecChangedBanner.tsx` compact chip: actions wrap, and "CR-01" and the date are `whitespace-nowrap` (they had
    broken as "CR- / 01").
- **m1**: `stages.ts` `StageDescriptor.localOnly` (`true` on the `test-design` row) and `isLocalOnlyStage(kind)`.
  `StageArtifactWorkspace.tsx` renders no `PublishToTeamButton` for a local-only stage.
- **m3**: `stages.ts` `stageRunInFlight(detail)` (some stage row has `run_id` and no `chat_session_id`) and
  `STAGE_RUN_POLL_MS = 5000`. `features/hooks.ts` `useFeature` uses `refetchInterval` while that is true and stops
  otherwise.
- **m4**: `TestImpactTab.tsx` Key header `w-[120px]`; the key cell is `whitespace-nowrap` (indent `pl-9` + `TC-000000`
  = 113 px).

**Who else benefits from the M3 sweep** (each used to wait forever on an orphaned `running` run):
- `TopupRunObserver` / `reconcile_topups`: the top-up settles `failed` and a new top-up is allowed. This was row 16.
- `StageFinalizer` (UX, Technical Design, Breakdown, Test Design bindings): the orphaned stage run shows `failed`. The
  stage stays in-progress, so the user can re-run it.
- `StoryDesignFinalizer` / `StoryImplementationFinalizer`: the card's run is no longer "running" forever.
- `ChatRunSupervisor`: a copilot-linked run gets its "finished: failed" note.
- `ApplicationSyncService.is_sync_running`: an orphaned `sync-application` run no longer blocks every new sync
  (409 "already running") or the KB auto-pull.
- Retention: the run becomes terminal, so it is reclaimable. The Runs list has no permanent "running" rows.

**Not done by the sweep (recorded on purpose)**
- The orphaned OS process is not killed: no pid is stored, and it exits when its pipe closes (about 2 min, live row 16).
- Its `_toolcalls/` scratch store is purged at finalize, so tool captures from that window are lost (review ni2;
  diagnostics only, the run is already failed).
- The lock decides who sweeps, not who runs workers (review mi4). A second `genesis serve` that fails to get the lock
  still starts and spawns workers. If the lock holder then restarts while the second server has a run in flight, the
  new holder fails that run. This needs two servers on one home at once. The full fix would be to refuse to start
  without the lock (follow-up).

**Tests**
- genesis **1366 passed** (base 1355 + 11); `ruff check genesis` clean. `ruff check .` shows the same 28 pre-existing
  errors in tests/scripts.
- web: lint 0 errors (the same 20 pre-existing warnings, none in changed files); typecheck clean; vitest **50 files /
  459 passed** (base 49 / 450).
- `tests/test_runs.py` +6 (real `RunManager`):
  - an orphaned `running` and a `pending` run → `failed`, with exactly one `error` and one `run.final{failed}`;
    observers read the stored FAILED; idempotent;
  - paused / awaiting-gate / terminal / tracked-worker runs are untouched;
  - a stale `running` record with a durable `run.final{done}` is adopted (real worker), not failed;
  - a last gate marker is adopted, a resumed-then-lost run is failed;
  - a last non-terminal `running` stop is failed (mi2);
  - a live peer holding the lock blocks the sweep; it runs after the peer releases it, and is re-entrant for the
    holder (MJ1).
- `tests/test_test_design_stage.py` +2 and 1 extended:
  - row 16 end to end: a `running` top-up → the real app startup hooks (`with TestClient`) → run `failed` with the
    detail, top-up `failed`, a new top-up allowed;
  - the level-triggered half alone: a sweep by a bare `RunManager`, then `reconcile_topups` settles it;
  - `test_rerun_and_reopen_are_refused_after_finalize` now asserts `detail.reason` (m2).
- `tests/test_test_design_api.py` +2:
  - the scenario read resolves a planned object after a KB sync (n2);
  - a new Task link is a 422 on the story edit and on create, nothing is written, and an existing Task link survives an
    edit (n4).
- `tests/test_test_design_store.py`: the set-steps refusals assert the key text (n3).
- `tests/test_domain_transitions.py` +1: the reason callable for spec, test design and default (m2).
- Web:
  - `testDesign.test.tsx` +6 and 1 extended:
    - Cases layout pin: Title has no width class; table min-w = Σ fixed + 256; the 2xl grid template; no
      comma-joined keys;
    - stage-grid pin: `2xl:grid-cols-5`, not `xl:`; the footer is `flex-wrap`;
    - no "Publish to team" on a completed Test Design with collab on (waits for the config read; jest-axe);
    - the Add case dialog offers Stories only;
    - the case-page picker offers Stories plus an already-linked Task;
    - the Test Impact test now pins the key `nowrap` + `w-[120px]`.
  - `stages.test.ts` +2: `isLocalOnlyStage`, `stageRunInFlight`.
  - New `useFeaturePoll.test.tsx` (fake timers): it polls every 5 s while a run is in flight, stops once the chat
    exists, and does not poll when idle.
- Before-fix evidence: with the source stashed and the tests kept, 11 backend + 5 web (round 0) and 2 + 2 (round 1) of
  the new or changed tests fail. All pass with the fix.
- Bundle (L-089): each `npm run build` ran as its own call after the edits and before its commit. After each commit, a
  fresh build followed by a separate `git status --short --untracked-files=all` gave 0 lines. The reviewer's
  `vite build` into `/tmp` is identical to `web/static`.

**Width re-measure (M1/M2, L-090)**
- Method: the reviewer's `/tmp/genesis-review/row15-*.js`, copied to `/tmp/genesis-h3/row15-*.js` with `BASE` and
  `WIDTHS` taken from the environment and output going to `/tmp/genesis-h3/row15/`.
- Dev server: `/tmp/genesis-h3/with-dev-server.mjs` starts a short-lived Vite dev server (:5199) over the web working
  tree, proxying `/api` to main :8760 (GET reads plus the impact Analyze POST, feature 6). It `chdir`s to `web/`;
  without that, Tailwind finds no config and the CSS has no utilities, so the measurements are wrong.
- Results, light = dark:
  - **Cases table** at 1280 / 1440 / 1920: table = container 982 / 1142 / 1074 px, no scroll, Title **282 / 442 / 374**
    px (was 0 / 0 / 85). At 1536 / 1600: Title 262 / 326. No badge, key or header wraps (`badge-wrap.js`). Column
    widths are as listed above.
  - **Stage cards** 320 / 373 / 261 px at 1280 / 1440 / 1920 (238 / 251 at 1536 / 1600). No control is past its card
    edge at 1280 / 1440 / 1536 / 1600 / 1760 / 1920 (`row15-footer.js`, `row15-spill.js`). The probe's
    `clipped: true` on the UX and TD cards is an `sr-only` "(opens in a new tab)" span, a false positive (the reviewer
    confirmed it).
  - **Test Impact** Key is 120 px with `TC-000007` on one line; no scroll.
  - **Case Objects** table: no scroll.
- The formal row-15 re-acceptance stays with the 49-08 re-review.

**Review:** genesis-review, `reviews/49-08-H3-review.md`.
- Round 1 **NEEDS_CHANGES**: MJ1 (the sweep failed a live peer server's runs); mi1 (picker half of n4 not built); mi2;
  mi3; ni1; ni2.
- Fixed MJ1, mi1 (plus the Add case dialog), mi2 and ni1.
- Round 2 **SHIP**, with mi4 and ni3 as notes. mi3, ni2 and mi4 are recorded here. ni3 (a discarded `RunManager`
  keeps its lock fd) is harmless: production has one manager per process.

**Decisions / deviations** (no ADR deviation)
1. **M1 coverage column at 2xl**: a fixed 16rem column instead of the spec's literal 2/3 split. At 1920 the 2/3 column
   is 893 px, below the table's 956 px minimum, so the split cannot meet the spec's own acceptance (Title ≥ 240, no
   scroll at 1920). Accepted by the reviewer.
2. **M1 column widths**: the narrow columns use `px-2` cells (−8 px each) so that 700 + 256 fits the stacked 980 px
   container at 1280. Keys are one per line.
3. **n4 `keep=` rule**: a Task link the case already has (pre-fix data, e.g. live TC-000003 → GNS_000001) is not
   refused on a story edit and stays in the picker, so it can be removed. New Task links are refused everywhere.
   Finalize and top-up link through `_link_story` directly, so an agent-authored Task link can't 422 a Finalize.
4. **MJ1**: a home-level `flock`, not a documented one-process-per-home constraint. Known limit: mi4 above.
5. **mi3 (follow-up for genesis-spec)**: the m3 poll keeps the spec's predicate, so it never stops on a stage whose run
   failed or escalated without a draft. That stage keeps its `run_id` and gets no chat, so the open page re-reads
   `GET /features/{id}` every 5 s. Stopping on a terminal bound run needs the run status in the feature detail (a
   contract + fixture change) or extra run reads.
6. **Small extras inside the touched UI**: the compact spec-changed chip's `nowrap` label/date (M2) and the stacked
   coverage grid (M1).

**Lesson candidates (for genesis-docs)**
- "A startup sweep that reads 'no worker tracked here' as 'orphaned' must first prove it is the only live owner of the
  DB (an exclusive lock), or it fails a live peer's runs. A recovery that writes a terminal state is not harmless the
  way an adopt-only reconcile is." (MJ1, mi4)
- L-090 corollary: a dev-server probe started from outside `web/` measures CSS with no Tailwind utilities. Run it
  with cwd = `web/` and check that a known class resolves before you trust any number.
- L-089 corollary (seen again this session): a read-only `git status` or `grep` issued in the same turn as `npm run
  build` can report the pre-build tree. Re-run the proof alone after the build has finished.

**Code-map changes**
- `runs/manager.py`: `fail_orphaned_runs` (startup orphaned-run sweep behind the `state_dir/run/runs.lock` run-owner
  `flock`; adopt terminal or last-gate, else fail with `ORPHANED_DETAIL`), `_hold_run_owner_lock`,
  `_run_owner_lock_path`.
- `api/app.py`: the sweep is the first step of the `_bind_supervisor` startup hook.
- `domain/transitions.py`: stage-aware reopen reason `_reopen_locked_reason` / `TEST_DESIGN_REOPEN_REASON`;
  `stage_ctx` carries `stage`.
- `kb/testdesign.py` `_suite_stories(keep=)`: the Task-link refusal.
- `web/features/features/stages.ts`: `localOnly`, `isLocalOnlyStage`, `stageRunInFlight`, `STAGE_RUN_POLL_MS`.
- `features/hooks.ts` `useFeature` polls while a stage run is in flight.
- `test-design/CasesTable.tsx` `KeyList`.

- **H4 — Story coverage as a donut chart (49-01 D20).** Built by genesis-dev after the 49-08 SHIP and before 49-09;
  own genesis commit(s); As built under this item; then a short genesis-review of H4 only (static review + gates + the
  width probe below). Web only, no API change: the data is `tree.coverage.stories` (49-06 §3).
  1. Replace the per-story list in `CoveragePanel` (`web/src/features/test-design/TestsTab.tsx:196-227`) with:
     - **Donut** (plain SVG, no chart library — L-015; colours from design tokens, not raw palette classes — ADR-027/055;
       light and dark) over **Story-type** stories, three mutually exclusive slices: **Covered** (`state` covered and
       `needs_review == 0`), **Needs review** (covered and `needs_review > 0`), **Not covered** (`state` uncovered). A
       zero-count slice is not drawn. Pointer click on a slice opens its dialog.
     - **Centre text:** the covered percentage, where Covered + Needs review count as covered, and "n of m stories".
     - **Legend:** one `<button>` per slice (colour swatch, label, count, percentage), keyboard-reachable; plus a
       separate **Tasks** line ("N Tasks — covered through objects or scenarios", D14) that is also a button. Rows with
       0 stories are shown disabled. The SVG itself is `aria-hidden`; the legend carries the accessible names.
     - **Dialog** (existing `Dialog` primitive) titled "<Category> (n)" listing each story: key, title, case count (not
       for Tasks), *Needs review* badge where relevant, each linked to the canonical story page (ADR-071). **No**
       generate/top-up button (D20).
     - Empty states: no finalized stories → the current "No finalized stories." text; Tasks only → no donut, the Tasks
       line only.
  2. Layout: at 2xl the panel stays in its 16rem column (donut above the legend); below 2xl, where it stacks under the
     test list, donut and legend sit side by side. The panel's height no longer grows with the number of stories.
  3. Tests (Vitest + RTL + jest-axe): slice counts for a mixed fixture (real shapes, L-083) incl. a covered story with
     needs-review cases counted only under Needs review; Tasks excluded from the donut and the percentage; each legend
     button opens the dialog with exactly its stories; zero-count rows disabled; links point at the story page;
     jest-axe clean with the dialog open.
  4. Width probe (L-090) in a real browser at 1280, 1440, 1920, light and dark: the panel and the dialog fit, no text
     clipped, legend labels don't wrap mid-word; record the measured sizes.
  Gates: web `lint` + `typecheck` + `vitest`; `npm run build` and commit `web/static/` as separate sequential steps, then
  a fresh build + empty `git status` (L-089).

#### H4 — As built (genesis-dev, 2026-10-31)

**Commits:** genesis `5da9916`, "feat(web): 49-08 H4 — Story coverage as an SVG donut …" (base `d138078` = H3 head). It
holds the source, the tests and the rebuilt `web/static` (67 files). Local only; nothing pushed or tagged. No other repo
changed. Ships with H1–H3 in 49-09.

**Changed** (web only, no API, type or fixture change; the data is `tree.coverage.stories`)
- New `web/src/features/test-design/CoveragePanel.tsx`. It replaces the per-story list that was in `TestsTab.tsx`.
  - `Donut`: plain SVG with one `<circle pathLength=100>` per slice, sized by `strokeDasharray`/`strokeDashoffset`,
    starting at 12 o'clock. A 0.8 % gap separates slices when more than one is drawn. A zero-count slice is not drawn.
    Colours are `stroke-success` / `stroke-warning` / `stroke-danger`, i.e. `var(--success|warning|danger)`, so both
    themes follow. The SVG is `aria-hidden`. Each circle has `onClick`; the stroke is the hit area, the hole is not.
    The centre is an HTML overlay: the covered % and "n of m stories".
  - Legend: one `<button aria-haspopup="dialog">` per slice (swatch, label, count, %). Its accessible name is
    "Covered: 2 stories, 33%". It is disabled at 0. Below the legend, a separate Tasks line button ("14 Tasks — covered
    through objects or scenarios").
  - `CategoryDialog` (the existing `Dialog`): titled "<Category> (n)", with a short description. It lists each
    story's key, title, *Needs review* badge and case count (no count for Tasks). Each story links to
    `storyPath(app, id, feature)` (ADR-071). No generate or top-up button (D20).
  - Empty states: no stories → "No finalized stories."; Tasks only → only the Tasks line (no donut, no legend).
  - Layout: `flex flex-wrap … 2xl:flex-col`. Below 2xl the donut sits left-aligned beside a `sm:max-w-sm` legend. In
    the 2xl 16rem column the donut is centred above the legend.
- `logic.ts`: `coverageSliceOf` (Task → none, uncovered → Not covered, covered with `needs_review > 0` → Needs review
  only, else Covered), `sharePct` and `coverageBreakdown` (three slices in a fixed order, Tasks, total, covered,
  coveredPct). `sharePct` never rounds a partial share to 0 % or 100 %, so 199 of 200 shows as 99 %.
- `TestsTab.tsx`: drops the old panel and its imports and passes `tree.coverage.stories`.

**Tests:** web lint 0 errors (the same 20 pre-existing warnings, none in `features/test-design`); typecheck clean;
vitest **50 files / 467 passed** (base 459, +8).
- `logic.test.ts` +3:
  - exclusive slices on the fixture plus one uncovered story, with GNS_000123 (covered, 3 needs-review cases)
    counted only under Needs review; Tasks excluded; 67 %;
  - zero-count, Tasks-only and empty inputs;
  - `sharePct` edges.
- `testDesign.test.tsx` +5 (`Tests tab → Story coverage donut`):
  - slice counts from the circles' `data-count`, the centre "67%" / "2 of 3 stories", the legend names; no link and no
    generate button in the panel;
  - each legend button opens a dialog with exactly its stories' hrefs; case counts but none for Tasks; no
    generate/top-up button; jest-axe clean with the Needs review dialog open; a dialog link navigates to the story page;
  - a slice click opens its dialog; a zero-count slice is not drawn and its row is disabled;
  - Tasks-only and no-stories empty states;
  - a layout pin.
- Two existing tests now find the panel by its region name: the after-Finalize test (which now asserts the legend) and
  the H3 M1 layout pin.
- Before-fix evidence: with the source stashed (and `CoveragePanel.tsx` moved away) and the tests kept, 10 tests fail
  (the 8 new ones plus the 2 updated ones). All pass with the change.
- Bundle (L-089):
  - `npm run build` ran as its own call, after the edits and before the commit.
  - After the commit, a fresh build, then a separate `git status --short --untracked-files=all` → 0 lines. The first
    proof had shared a batch with the build, so I re-ran it alone.
  - The reviewer's out-of-tree `vite build` is identical to `web/static`.

**Width probe (L-090, spec item 4)**
- Method: `/tmp/genesis-h4/coverage-probe.js`, adapted from `/tmp/genesis-h3/row15-probe.js`. It runs through
  `/tmp/genesis-h4/with-dev-server.mjs` (Vite :5199 with cwd `web/`, `/api` → serve v0.78.0 :8760).
  - It is read-only: the feature-6 suite GET is rewritten in the browser to 2 Covered, 2 Needs review, 2 Not covered
    and 14 Tasks. Real long titles.
  - The 4-width record is the reviewer's re-run, `/tmp/genesis-h4-review/out/probe.json` (review mi1). My own 4-width
    run gave the same numbers, but a later 2-width screenshot re-run overwrote its `/tmp/genesis-h4/out/probe.json`.
- Results: light and dark give the same numbers; the computed strokes differ per theme.

  | Width | Layout | Panel w×h | Donut | Legend w | Tasks line |
  |---|---|---|---|---|---|
  | 1280 | side by side | 984×215 | 144 | 384 | 1 line |
  | 1440 | side by side | 1144×215 | 144 | 384 | 1 line |
  | 1536 | stacked (2xl) | 256×395 | 144 | 214 | 2 lines, breaks at a space |
  | 1920 | stacked (2xl) | 256×395 | 144 | 214 | 2 lines, breaks at a space |

- At every width:
  - Slice labels stay on one line (`whitespace-nowrap`). No element overflows the panel, none sits outside it, and
    the page has no horizontal scroll.
  - Centre text 48 px ("67%") and 70 px ("4 of 6 stories") wide, inside the 98 px hole.
  - Dialogs are 576 px wide: Tasks 576×666 (the list scrolls), Needs review 576×286, both inside the 900 px viewport.
    No key wraps and no badge or count goes past its row. The only "clipped" element is the close button's `sr-only`
    label.
  - A real pointer click on the Not covered arc opens "Not covered (2)".
- The panel height no longer depends on the story count: 215 or 395 px with 20 stories.
- One probe-driven fix before the commit: the first run showed the donut centred in the free space at 1280/1440 (donut at
  x=484, legend at x=851). `sm:mx-0 2xl:mx-auto` puts it beside the legend.

**Review:** genesis-review, `reviews/49-08-H4-review.md`, **SHIP** (no blockers, no majors).
- mi1 (the probe file) and mi2 (this As built) are closed here.
- n1 (the area-map gap) is for genesis-docs.
- n2 and n3 are not done (below).

**Decisions / deviations** (no ADR deviation)
1. **Slice colours:** Covered = success, Needs review = warning, Not covered = danger. The spec names no colours. The
   existing `NeedsReviewBadge` is warning-toned and the `Uncovered` badge is warning too, so reusing the badge tones
   would make two slices the same colour. Accepted by the reviewer.
2. **Label "Not covered"** follows the spec. The `CoverageBadge` elsewhere (top-up dialog) still says "Uncovered"
   (review n2). Aligning them would touch other screens, so it is left for a later pass.
3. **Centre text is HTML** over the aria-hidden SVG, so screen readers also get the % and "n of m stories".
4. **`sharePct`** clamps partial shares to 1–99 %, so the centre never reads 100 % while a story is uncovered.
5. Review n3 (the `find(...)!` lookups in `CoveragePanel`) is not done. The lookups are safe, and changing them would
   need another rebuild and review for no behaviour change.

**Lesson candidates (for genesis-docs)**
- L-090 corollary: a probe output file is evidence. Write each run to its own path (or name it by run), or a narrower
  re-run overwrites the full one. Also wait out a dialog's open animation before measuring it; mid-zoom it read as
  outside the viewport.
- L-089 recurrence: once again a `git status` proof was batched with the build it proves. Re-run it alone.

**Code-map changes**
- `web/features/test-design/CoveragePanel.tsx` (new): the Tests tab Story coverage panel (`Donut`, `LegendButton`,
  `CategoryDialog`).
- `test-design/logic.ts`: `coverageSliceOf`, `sharePct`, `coverageBreakdown` (`CoverageSlice`, `CoverageBreakdown`).
- For genesis-docs (review n1): `web/src/features/test-design/**` maps to no area in `context/areas.toml`.

## 2. Gates

genesis: `pytest` + `ruff`; fresh DB migrates to **v25**, a v24 DB upgrades with rows preserved. web: `lint`,
`typecheck`, `vitest` (incl. jest-axe), `npm run build` byte-identical to the committed `web/static`.
genesis-workflows: `validate_library` + `pytest workflows`.

## 3. Live acceptance (local `genesis serve` :8760, the new workflow installed with `genesis install`, a real tracked app)

| # | Step | Expected |
|---|---|---|
| 1 | Open a feature whose stories are **not** finalized | Test Design card locked "Stories must be finalized"; `POST …/test_design/start` → 409 |
| 2 | Feature with finalized stories → Start (notes + 1 doc) | Run starts ("Test Design Analysis"); graph shows the per-epic loop + scenario node; in the turn explorer the `design_cases` / `compose_scenarios` agents **open the input files** (spec/UX/TD/stories) rather than answering without them (first workflow to pass all inputs only as files — 49-03 As built). Note the run's superstep count against `recursion_limit: 300`; raise to 400 if it is hit. |
| 3 | Run completes | Stage in-review; completion chat opens with `test-design.html`; document shows scenarios + cases + embedded JSON |
| 4 | Ask the chat to add a negative case and move it into a scenario | Visible cards **and** embedded JSON both updated |
| 5 | Mark completed → **Finalize tests** | `TC-`/`TS-` ids in document order; Tests tab shows the tree; dropped keys reported (if any) |
| 6 | Re-run / Reopen after Finalize | Both refused with the R5 message |
| 7 | Case page: edit Gherkin, change stories, add a planned object by name, retire a case used by a scenario | Edit saved; retire refused naming the scenario; remove from scenario → retire OK; Restore keeps the key |
| 8 | Edit a linked story's acceptance criteria | Its cases show **Needs review** on the case page, story page and Tests tab; Mark reviewed clears it |
| 9 | Implement a linked story through the Workbench (or replay an implementation fixture run) | Its cases gain the changed objects (origin implementation); matching unresolved links resolve |
| 10 | Run a KB sync after a manual change to a linked object in Appian | Test Impact → KB sync source lists that object as modified and its cases as direct hits; indirect hits at 2 hops; depth 1 removes them |
| 11 | Test Impact → Objects source with an interface many cases depend on | Direct-first ordering, Via paths shown, totals correct |
| 12 | Object Wiki page of an implemented object | Tests section lists its cases; "Check test impact" pre-picks it |
| 13 | Generate tests for uncovered stories (add a story manually first) | Proposals list; reject a new case → its dependent step auto-rejected; Apply creates Ready records with new ids |
| 14 | Export CSV | Opens in a spreadsheet: one row per case, multi-line Gherkin intact |
| 15 | **Real-browser width probe (L-090):** at 1280, 1440, 1920 px, light and dark — (a) the Tests tab Cases table, (b) the Test Impact table, (c) the feature Overview's **5-card stage grid**, (d) the case page's **Objects** table | No clipped key/title columns, no horizontal scroll at ≥ 1280, the five stage cards wrap cleanly; record measured column widths and card widths |
| 16 | Restart `serve` mid top-up run (no active design run) | Top-up row reconciles to ready/failed on startup (L-058) |
| 17 | The extra live checks listed in the **49-07 As built** (e.g. a scenario with a step whose case is retired can't be reordered until that step is removed; a Tasks-only feature's Test Design start page shows why it is locked) | Each behaves as the As built describes |
| 18 | H1 live: start any stage run (UX / TD / Breakdown / Test Design) and **stay on the page** until it finishes | The stage reaches in-review without a reload or restart (D17) |

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "runs-worker"]
adrs     = ["ADR-011", "ADR-012", "ADR-031", "ADR-045", "ADR-050", "ADR-056", "ADR-060", "ADR-067", "ADR-070", "ADR-072"]
lessons  = ["L-005", "L-011", "L-058", "L-061", "L-063", "L-064", "L-069", "L-076", "L-089", "L-090"]
code     = ["genesis/genesis/kb/testdesign.py", "genesis/genesis/services/testimpact.py", "genesis/genesis/runs/manager.py"]
docs     = ["tracker:specs/phase-49-test-design.md"]
upstream = ["49-02", "49-03", "49-04", "49-05", "49-06", "49-07"]
```
