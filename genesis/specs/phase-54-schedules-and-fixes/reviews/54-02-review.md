# Review 54-02 — base ea00dfd, head 3c61494 (genesis-review, 2026-11-18)

What this change does: editing a paused or gated run's state (HITL mode 3) no longer stores `running` or logs
`run.final`. The edit runs through a separate `RunManager._spawn_edit` that logs a `custom` `state.edited` note and turns
a worker failure into `StateEditError` (400). `artifact.saved` and `tool_output.recorded` become canonical event kinds
(with node), and the per-turn fold also reads old `custom` rows. The commits also remove the dead lines in
`runtime/settings.py`, let failed captures and captures waiting at a gate be discarded (a still-live run is cancelled
first), and accept environment labels containing `/` (`DELETE {label:path}`, make-Dev moves to
`POST /config/environments/dev {label,is_dev}`). The SPA catch-all now answers every method: 404 JSON for an unmatched
`/api/*` path, 405 for a method mismatch.

Commits reviewed (all exist, `git log --oneline ea00dfd..HEAD`): 86baf74 B1, 7d1a55c B2, d8ee04c B3, 938504d + 959d002 O1,
f150a4a O4, 3c61494 web/static. 24 source/test files, +586/−44, plus 63 files in `web/static` (bundle commit only).

## Gates (run by the reviewer)

- `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` →
  **1965 passed, 1 deselected** in 585 s (started 14:52 IST, outside the D27 window).
- `.venv/bin/ruff check genesis` → All checks passed.
- web `npm run lint` → 0 errors, 20 warnings (pre-existing); `npm run typecheck` → clean; `npm test` → **66 files / 770
  tests passed**.
- Stale bundle: `npx --no-install vite build --outDir /tmp/54-02-static` then `diff -rq /tmp/54-02-static web/static`
  → identical. `git status --porcelain` empty. `git show --stat 3c61494 -- web/static` → 63 files; the earlier six
  commits touch no `web/static` file (L-089).
- Fail-first: the HEAD test files run against the base `genesis/` package (`git archive ea00dfd`, `PYTHONPATH`
  pointing at it) → **19 of the new tests fail** (all B1, B2, B3, O1 and O4 tests in `test_runs.py`, `test_api.py`,
  `test_testexec_recording.py`, `test_testexec_store.py`, `test_runtime_settings.py`), 14 old ones pass. Caveat: the
  base extract has no `web/static`, so the two catch-all tests in `test_api.py` would fail there for that reason too.
  The fail-first evidence for the stop-marker test is not meaningful; see M1.

## Checklist

### ADRs
- [OK] ADR-001 — LangGraph owns control flow. The edit is still `aupdate_state` in the worker (`runs/worker.py:166-168`); no agent orchestration added.
- [N/A] ADR-002 — no agent-step or ACP change.
- [N/A] ADR-004 — no MCP injection change.
- [N/A] ADR-005 — registry untouched.
- [OK] ADR-008 — one app; the SPA fallback is still served by the same app (`api/app.py:415-427`).
- [OK] ADR-009 — mode 3 now keeps the run's status. Covered by `test_edit_state_of_a_paused_real_run_then_resume_runs_the_edited_state`, `test_edit_state_at_a_real_gate_keeps_the_gate` and `test_api_edit_state_of_a_paused_or_gated_run_keeps_its_status`, all with the real worker. Pause/resume/gate paths are unchanged.
- [N/A] ADR-010 — the state shape is unchanged; the `state.edited` note carries key names only (`manager.py:624`).
- [N/A] ADR-011 — no agent node added.
- [OK] ADR-012 — the edit still runs in a subprocess worker (`supervisor.spawn`); the app imports no workflow code.
- [N/A] ADR-013 — no config-UI ownership change.
- [N/A] ADR-018 — no inter-node data handoff change.
- [N/A] ADR-019 — genesis-core untouched (`git diff --stat` has no `packages/` path); `CORE_MAJOR` unchanged.
- [N/A] ADR-020 — no Kiro config touched.
- [N/A] ADR-021 — no gate policy change.
- [N/A] ADR-022 — no artifacts-root change; B3 deleted unreachable code only.
- [OK] ADR-023 — FastAPI embedding; the catch-all is a plain FastAPI `api_route`.
- [OK] ADR-024 — the worker is unchanged and still async.
- [OK] ADR-025 — `fork` is unchanged (`manager.py:630+`); `patch_state` edits in place, as before.
- [OK] ADR-026 — no new bind or exposure; the routes stay loopback-only.
- [OK] ADR-027 — CapturesPanel reuses `Button` and the existing mutation hook; the error line uses tokens (`text-danger`).
- [OK] ADR-028 — the new route sits under `/api`. The client keeps prepending `/api` centrally (`lib/api/config.ts:51` passes `/config/environments/dev`). An unmatched `/api/*` path is now 404 JSON for every method (`test_api_unmatched_api_paths_answer_404_json_for_every_method`).
- [N/A] ADR-029 — no trust or registry change.
- [OK] ADR-030 — SQLite; no new store.
- [N/A] ADR-031 — chat untouched. `patch_state` has no chat or copilot caller (grep shows only `run_routes.py:156`).
- [N/A] ADR-032 — no credit change.
- [OK] ADR-033 — copilot run tools are unchanged; the new discard→cancel path is a human click in the Testing tab.
- [N/A] ADR-034 — no skills change.
- [N/A] ADR-035 — no file-input change.
- [N/A] ADR-036 / ADR-037 / ADR-038 / ADR-040 — KB and managed installs untouched.
- [N/A] ADR-041 — no document change.
- [N/A] ADR-043 — no Lavish change.
- [N/A] ADR-045 — no chat surface change.
- [N/A] ADR-046 / ADR-047 — no shipping or schedule change.
- [OK] ADR-048 — the dev tag is still single-select through `config.set_dev_environment(label)`; only the label moved into the body (`config_routes.py:86-98`). No credential handling changed.
- [N/A] ADR-049 — no nav change.
- [N/A] ADR-050 — capture status is not SDLC lifecycle state; the store's `_CAPTURE_EDGES` stays the single edge table (`kb/testexec_store.py:71-72`).
- [N/A] ADR-054 / ADR-055 / ADR-061 / ADR-062 / ADR-063 / ADR-065 — untouched areas.
- [OK] ADR-066 — `artifact.saved` now reaches the per-iteration inspector: `test_artifact_saved_and_tool_output_recorded_are_stored_with_their_kind_and_node` and `test_an_old_custom_artifact_saved_row_folds_into_its_turn`; the web dialog test lists the artifacts.
- [N/A] ADR-068 / ADR-069 / ADR-071 / ADR-073 / ADR-074 / ADR-076 / ADR-077 / ADR-078 — untouched.
- [N/A] ADR-080 — no version or package change in this sub-spec.
- [OK] ADR-081 — discard writes only catalog status; no workspace file is written for a failed or gated capture (`recording.py:356-358`).
- [OK] ADR-082 — no execution or QA-session change; cancelling a gated compose run goes through `RunManager.cancel`, which reaps the run's processes.
- [N/A] ADR-083 / ADR-084 — untouched.
- [OK] ADR-085 — the report origin is a separate app; the every-method catch-all is registered only on the main app (`api/app.py:415`).
- [N/A] ADR-086 — no Kiro launch change.

### Lessons
- [N/A] L-001 / L-002 — no ACP options change.
- [OK] L-003 — a non-terminal edit no longer logs `run.final{running}`, which used to close a live `useRunNodeStream` (`hooks.ts:120`). The bus is never closed by an edit.
- [OK] L-004 — SQLite only.
- [OK] L-005 — no new event kind is invented. The two promoted kinds already existed as `ctx.emit` types in core (`agent.py:412,420`). The edit note uses the existing `custom` kind (decision 1, which the spec allowed).
- [N/A] L-006 — no topology change.
- [OK] L-007 — the transcript is unchanged; the contract test asserts `buildTranscript([saved, recorded]) == []` (`contract.test.ts:49-57`).
- [OK] L-008 — `_spawn_edit` keeps the specific `error` over a later `worker_exit` (`manager.py:625`, guarded on `outcome["error"] is None`). Covered by `test_a_failed_state_edit_is_refused_and_never_fails_the_run` (error then exit 1).
- [N/A] L-009 — no sync/async change.
- [OK] L-010 — `/api` prefix kept; non-JSON answers for unmatched `/api/*` are gone (404 JSON).
- [OK] L-011 — `CANONICAL_EVENT_KINDS`, the golden `EVENT_FIXTURES` and the `RunEvent` comment gained both kinds with the backend's top-level payload keys; the contract test pins them. Pre-existing drift (`agent.prompt` absent from the web list) is noted by the author for As built.
- [N/A] L-012 / L-013 / L-015 — untouched.
- [N/A] L-016 — no credit change.
- [N/A] L-017 — no trust change.
- [N/A] L-018 — SSE framing untouched.
- [N/A] L-019 — no secret writes.
- [N/A] L-020 / L-021 / L-022 / L-023 — untouched.
- [OK] L-025 / L-027 — ruff is pinned and clean.
- [OK] L-026 — the `state.edited` `_log` runs on the supervisor reader thread, not inside an async node.
- [N/A] L-028 / L-029 / L-031 / L-033 / L-034 / L-039 / L-044 / L-045 / L-049 / L-050 / L-053 / L-054 — untouched.
- [OK] L-030 — this is a web change and `web/**` is touched, so the frontend CI job will run.
- [OK] L-048 — the SPA ships as package data; WEB_STATIC resolution is unchanged.
- [N/A] L-051 / L-056 / L-057 — no release in this sub-spec (54-11).
- [OK] L-058 — the gated-discard path relies on the finalizer seeing `run.final{cancelled}`, and it also fails the capture itself when no finalizer did (`recording.py:368-375`, `test_a_gated_compose_is_discarded_even_with_no_finalizer_listening`).
- [N/A] L-059 / L-060 — untouched.
- [OK] L-061 — `CaptureFinalizer.finalize_run` still scopes to the capture bound to that run (`capture_finalizer.py:165-176`); the discard path does not sweep.
- [OK] L-062 — no new binding is needed: discard reuses the existing compose/recording finalizers.
- [OK] L-065 — a gate run that is discarded reaches `cancelled` (terminal) through `cancel`.
- [OK] L-066 — `node_iterations` still filters one node's events; `event_node` is O(1) per row (`steps.py:106-108`).
- [N/A] L-067 — untouched.
- [OK] L-068 — `GET /some/spa/route` still serves `index.html` with `no-cache, must-revalidate` (asserted in `test_api_unmatched_api_paths_answer_404_json_for_every_method`).
- [OK] L-069 — no `asChild`.
- [N/A] L-070 — untouched.
- [OK] L-081 — labels stay free text, with no new validation (`DevEnvBody.label: str`). An older open SPA tab that posts to the removed `…/{label}/dev` route gets a 405, and a reload fixes it because `index.html` is no-cache (decision 4; see nit N2).
- [N/A] L-087 / L-088 — agent-system untouched.
- [OK] L-089 — the bundle commit 3c61494 is separate, and a second build left the tree clean (verified above).
- [N/A] L-090 — no table columns.
- [OK] L-091 — capture writes are CAS (`set_status(..., expected_status=...)`), and discard runs under `RecordingService._lock` (class-level `RLock`, `recording.py:131`). The finalizer's own CAS handles the race (`StaleWriteError` caught, `recording.py:372`).
- [OK] L-092 — the new `tests/test_runtime_settings.py` has a unique name; no `__init__.py` was added.
- [VIOLATION — minor m2] L-093 — the B1 paths are tested through the real `RunManager` and the real worker. The new O1 cancel→finalizer→discard bridge is tested only with `FakeRunManager.cancel` (`test_testexec_recording.py:135-144`), not with the real `RunManager.cancel` → `_announce_final` → observers.
- [OK] L-094 — event-kind consumers were checked by grep (backend: `fold_steps` `steps.py:31`, `fold_transitions`, `metrics.py:57`, `introspection_server.py:179`, `reconcile_status`; web: `node-states.ts:50-90`, `buildTranscript`, `useRunNodeStream`/`STREAM_KINDS`). A node now set on `artifact.saved` does not change any node status: these events always fall inside a turn whose node already has `agent.*` rows. No code outside genesis calls the environment routes (grep of genesis-workflows, genesis-fleet and playwright-appian/src). Missed docs line: `docs/architecture/modules/api.md:245` (N1).
- [OK] L-096 — `test_api_environment_routes_beside_their_literal_siblings` checks behaviour (the `missing` field only the check handler sets; envs named `dev` and `dev/check` deleted through `{label:path}`). `test_api_the_catch_all_comes_after_the_api_router` checks route order, and the existing whole-table test `test_no_route_is_shadowed_by_an_earlier_path_parameter_route` (`test_testing_api.py:557`) still passes.
- [OK] L-097 — no startup sweep change.
- [N/A] L-098 / L-099 / L-100 / L-101 — untouched.
- [N/A] L-103 / L-104 / L-105 — untouched; the cancel path reuses `_reap_run_processes`.
- [N/A] L-106 — no gate prompt change.
- [OK] L-107 — every discard path ends terminal: a failed capture → `discarded`, a gated one → `failed` → `discarded` (with or without a finalizer), and a refusal is a 409 with the capture unchanged (`test_an_analysing_capture_whose_run_is_working_is_still_refused`). A failed edit raises and leaves the run status untouched.
- [VIOLATION — major M1] L-108 — the code is right: `_spawn_edit` never touches `_worker_state`/`_workers` (`manager.py:613-628`). But the test written for §1.3 does not fail if that regresses.
- [OK] L-109 — one edge table, and the web `discardable` mirrors the service's rule (`recording`/`failed`/analysing-at-gate). `ready` keeps its own Discard elsewhere.
- [OK] L-110 — the claims were proven by the gates above at head 3c61494.
- [OK] L-111 — live acceptance is deferred to 54-10, as stated.
- [N/A] L-112 — no release in this sub-spec.
- [N/A] L-113 / L-115 / L-116 / L-117 / L-118 / L-119 — untouched.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` (api, browser-testing, config-secrets, runs-worker) — 1965 passed, 1 deselected.
- [OK] `cd genesis && .venv/bin/ruff check genesis` (all four areas) — clean.
- [OK] `cd genesis/web && npm run lint && npm run typecheck && npm test` (browser-testing, config-secrets, web-runs) — 0 errors, tsc clean, 770 passed.
- [OK] `cd genesis/web && npm run build # then commit web/static/` (three areas) — fresh build identical to the committed tree.
- [N/A] `genesis-workflows` pytest and `ci/validate_library.py` — repo untouched (status: dirty 0, ahead 0).
- [N/A] `playwright-appian` lint/typecheck/test/build — repo untouched (dirty 0, ahead 0).

## Findings

### Blockers
None.

### Majors
- M1 **The §1.3 "stop marker kept" test does not test the stop marker** (`tests/test_runs.py:984-1004`,
  `test_a_state_edit_keeps_the_paused_workers_stop_marker`). What: it pauses a scripted run, edits it, then sends the
  paused worker's late `worker_exit`/`node` through `events[0]` and asserts they are dropped. Problem: those events are
  dropped by the paused worker's own closure `seen` (`manager.py:217-224`), whatever `_worker_state[run_id]` holds. So
  if `_spawn_edit` again replaced `self._worker_state[run_id]` and `self._workers[run_id]` (the old `_spawn` behaviour
  that §1.3 removes), the test would still pass. On the base it fails only because of the stored status. The hazard
  §1.3 removes has no test. Concrete case: a `running` run (Edit state is offered on running runs, decision 2) is
  edited and then cancelled. With the old wiring, `cancel` marks and kills the already-exited edit worker
  (`manager.py:394-399`). The real worker keeps running and spending turns after `cancelled`, logging `node.completed`
  until it finishes. Fix: one test. Spawn a scripted *running* run whose worker records `kill()`, call `patch_state`,
  assert `mgr._workers[rid]` is still the run's worker and `mgr._worker_state[rid]` is the same dict, then `cancel` and
  assert the run's worker (not the edit's) was killed. Rename or extend the existing test to match what it proves.
  If skipped: the edit-then-pause/cancel path on a running run can regress without any red test.

### Minors
- m1 **Discard on a gated capture cancels its run with one click, with no confirm** (`web/src/features/testing/CapturesPanel.tsx:92-95`).
  What: on an analysing capture whose run waits at its escalation gate, Discard calls the service, which cancels the run
  (`recording.py:365-366`). Problem: cancelling a run is irreversible, and the Run Detail Cancel asks first
  (`HitlBar.tsx:175,216`, `confirmCancel`). The user can lose a run they could have retried with one misclick on
  this card. The spec only asked to reuse "the existing confirm if Discard has one", and it has none, so this is not a
  spec violation. Fix: for `gated` only, open the existing `Dialog` confirm ("Discard and cancel its run?") before
  `discard.mutate`. If skipped: the Testing tab cancels a run with less protection than the Runs page does.
- m2 **The gated-discard bridge is tested only against a fake `cancel`** (`tests/test_testexec_recording.py:135-144,
  339-348`). What: `FakeRunManager.cancel` sets the status and calls the observers by hand. Problem: L-093's rule is to
  test run→app bridges through the real `RunManager`. The real order (CAS `cancelled`, then `_announce_final` → `_log`
  → observers → `ComposeFinalizer._fail`, all on the calling thread while `RecordingService._lock` is held) is only
  argued, not run. Fix: one test with a real `RunManager` (the `mgr` fixture style): a run recorded at
  `awaiting_input:gate`, a compose capture bound to it, `ComposeFinalizer(mgr, …).attach()`, then
  `RecordingService.discard`. Assert the run is `cancelled` with one `run.final` and the capture is `discarded` with the
  finalizer's reason.

### Nits
- N1 **Two docs lines still describe the old routes**: `docs/architecture/modules/configuration-and-secrets.md:589-590`
  (the author already noted it) and also `docs/architecture/modules/api.md:245` ("`/config/environments/dev/check`
  before the `{label}` routes"). Both belong to the docs agent; add the second to the As built hand-off.
- N2 **The catch-all's 405 has no `Allow` header** (`api/app.py:423,425`). RFC 9110 §15.5.6 requires one, and
  Starlette's own 405 sends it. No Genesis client reads it. Fix if wanted: compute the methods from the PARTIAL
  matches and add `headers={"Allow": ", ".join(...)}`.

### Decisions (as asked)
1. `custom` + `data.type: "state.edited"`: OK. The spec allows it, it adds no new kind (L-005), and the note holds key names only.
2. `patch_state` statuses unchanged: OK, and it matches `HitlBar.tsx:9` ("any non-terminal run"). The backend still
   accepts a terminal run (as before). That is not a regression, but M1's running-run case is why the worker wiring
   needs a test.
3. A failed edit raises `StateEditError` → 400: OK. The run is untouched and the error text reaches the dialog. A
   60 s `proc.wait` timeout still surfaces as a 500 (`supervisor.py:41`), which predates this change.
4. Old `POST /config/environments/{label}/dev` removed: OK. There are no callers outside the web client (grepped), and a
   stale tab only needs a reload (L-068 no-cache shell).
5. 405 via `Match.PARTIAL`: correct. Starlette prefers the catch-all's FULL match over an earlier PARTIAL one, so the
   check is needed, and `PUT /api/config/environments` → 405 proves it. One side effect: with `{label:path}`, any
   `GET /api/config/environments/<anything>` is now a 405 rather than a 404, which is accurate.
6. SSE kind lists unchanged: OK. `useRunNodeStream` feeds only the live conversation, and artifacts come from the
   `node_iterations` query (`hooks.ts:105-135`).

## Not checked
- Live behaviour on the fleet (Edit state on a paused/gated run in the browser, Discard on a real failed Compose, deleting the user's `https://example-qa2.appianpreview.com` environment) — deferred to 54-10; fleet not touched.
- Whether old DB rows already damaged by B1 (a gated run edited before the fix, now stored `running` with a `run.final{running}` marker) need repair — outside 54-02's scope; `reconcile_status` would keep adopting that marker after a restart.
- The base-code fail-first run of the two catch-all tests is confounded by the missing `web/static` in the extract.

## Verdict: NEEDS_CHANGES

M1 is required: add a test that fails if the edit replaces the run's worker or its worker state (running run → edit →
cancel kills the run's own worker). m1 and m2 are recommended in the same pass. N1 goes into the As built hand-off. All gates are green
and the code changes themselves look correct.

---

## Re-run 1 — head eed5da0 (previous head 3c61494), genesis-review, 2026-11-18

New commits (`git log --oneline 3c61494..eed5da0`): 3e28d28 (review round 1: `tests/test_runs.py`,
`tests/test_testexec_recording.py`, `web/src/features/testing/CapturesPanel.tsx`, `library.test.tsx`; +88/−17) and
eed5da0 (`web/static` only). No file under `genesis/` changed, so the round-1 code checklist stands as written; only
the lines below are re-answered.

### Gates (run by the reviewer at eed5da0)

- `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` →
  **1966 passed, 1 deselected** in 615 s (15:19–15:29 IST). That is round 1's 1965 plus the new m2 test.
- `.venv/bin/ruff check genesis tests/test_runs.py tests/test_testexec_recording.py` → All checks passed.
- web `npm run lint` → 0 errors, 20 warnings (pre-existing); `npm run typecheck` → clean; `npm test` → **66 files /
  770 passed** (the m1 assertions extend an existing test, so the count is unchanged).
- Stale bundle: `npx --no-install vite build --outDir /tmp/54-02-r2-static --emptyOutDir`, then
  `diff -rq /tmp/54-02-r2-static web/static` → identical. `git show --stat eed5da0 -- web/static` → 63 files;
  3e28d28 touches no `web/static` file (L-089). `git status --short --untracked-files=all` is empty after the full run.

### Round-1 findings

- **M1: resolved.** `test_a_state_edit_keeps_the_runs_own_worker_and_its_stop_marker` (`tests/test_runs.py:985-1022`)
  edits a scripted *running* run. It asserts `mgr._workers["r-run"] is worker` and `mgr._worker_state["r-run"] is
  state`. It then cancels and asserts `killed == ["run"]` and `state["stop"] == S.CANCELLED`. A paused run keeps its
  `stop == PAUSED` dict across an edit, and its late `worker_exit` logs no `run.final`. I ran two mutation probes of
  my own on a `git archive eed5da0` copy in `/tmp/54-02-r2b`, with `PYTHONPATH` pointing at it. The repo was not
  touched.
  - (a) `_spawn_edit` writes `self._worker_state[run_id] = {"stop": None}`. The test **fails** on the identity assert
    (`{'stop': None} is {'final': False, 'stop': None}`).
  - (b) `_spawn_edit` writes `self._workers[run_id] = w`. The test **fails** (the `_Worker` objects differ).

  So each half of the §1.3 wiring has its own red test. Together with the author's combined probe, this covers the
  regression round 1 described.
- **m2: resolved.** `test_a_gated_compose_discard_through_the_real_run_manager` (`tests/test_testexec_recording.py:942-963`)
  uses the real `RunManager` (the `mgr` fixture from `test_runs`) and an attached `ComposeFinalizer`. It asserts the
  run is `cancelled`, the `run.final` statuses are exactly `["awaiting_input:gate", "cancelled"]` (one new final), and
  the capture is `discarded` with proposals `{"error": "the setup-composer run was cancelled"}`. That string comes only
  from the finalizer (`capture_finalizer.py:173`). The service's own fallback writes a different one,
  `"discarded: its run was cancelled"` (`recording.py:371`). So the test proves that the real cancel →
  `_announce_final` → observer path ran, and that the fallback did not mask it (L-093). Importing only the `mgr`
  fixture adds no tests to the module's namespace, so L-092 is not affected.
- **m1: resolved.** `CapturesPanel.tsx:95` opens a `Dialog` only when `gated`. "Discard and cancel its run?" offers
  Keep waiting / Yes, discard (`variant="danger"`, `loading={discard.isPending}`). Yes calls `discard.mutate` with the
  same `onError: fail`, and the dialog closes `onSettled`. The dialog reuses the shared `Dialog` primitives and design
  tokens (ADR-027), with no `asChild` (L-069). `library.test.tsx:431-441` checks the first case: Keep waiting closes
  the dialog and sends no `/discard`. It checks the second: Yes sends it. It runs jest-axe on the open dialog.
- **N1: open, deferred to the docs hand-off as agreed.** The 54-02 sub-spec has no As built yet (a grep of
  `54-02-fixes.md` finds neither `api.md` nor `configuration-and-secrets.md`). The As built must list both
  `docs/architecture/modules/configuration-and-secrets.md:589-590` and `docs/architecture/modules/api.md:245`.
- **N2: not taken.** Acceptable for a nit: no Genesis client reads `Allow`.

### New findings

- N3 (nit, optional) **A failed capture whose run is still live discards, and so cancels that run, in one click**
  (`CapturesPanel.tsx:95` confirms only `gated`; `recording.py:356-357` cancels the bound run for `failed` too). The
  author names this case and calls it rare. A finalizer fails a capture only on a terminal `run.final`, so the run is
  normally already terminal. Fix if wanted: confirm whenever the card's run is non-terminal, not only when gated.
  No action is required for SHIP.

No other new findings. The changed lines add no new ADR or lesson exposure. The re-answered rows:
- L-093 → **OK** (m2 above).
- L-108 → **OK** (M1 above).
- ADR-027 and L-069 → OK (m1).
- L-089 → OK.
- L-092 → OK.

### Not checked (re-run 1)

- Live behaviour: the confirm dialog in a real browser, and a real gated setup-composer discard. Both are deferred to
  54-10. The fleet was not touched.
- The round-1 "Not checked" items still stand: old rows already damaged by B1, and the confounded fail-first of the
  catch-all tests.

## Verdict (re-run 1): SHIP

M1, m1 and m2 are fixed, and each fix has a test that fails without it (my mutation probes cover M1). All gates are
green at eed5da0. N1 is open: the 54-02 As built must carry both docs lines for genesis-docs. N2 and N3 are optional
nits.
