# 54-02 — Fixes: paused-run edit, artifact events, dead code, failed captures, environment labels

> **Status:** BUILT 2026-11-18 (genesis `86baf74`..`eed5da0`, local, review SHIP; see As built). SPEC-DRAFTED 2026-11-19. Repo: genesis. Parent: `specs/phase-54-schedules-and-fixes.md`. Built by
> **genesis-dev**; each fix starts with a failing test that reproduces it (bible §8 step 2), then the fix.
> Evidence for every cause: `54-01-findings.md` §3.

## 1. B1 — Editing a paused run's state must not make it "running"

**Today:** `RunManager.patch_state` (`genesis/runs/manager.py:593-599`) spawns an `update_state` worker; the worker's
`final` event carries the state's own `status` (`runs/worker.py:103-119`, `:166-168`); `on_event` (`manager.py:240-254`)
claims it through `RunStore.claim_status` (`runs/store.py:126-142`), which refuses only terminal statuses; `_spawn`
resets `seen = {"final": False, "stop": None}` (`:215`). A paused run becomes `running` with no worker and a
`run.final{status:"running"}` is logged.

**Change:**
1. An `update_state` job never writes run status and never logs `run.final`: `_spawn` takes the job's op, and for
   `update_state` its `on_event` records the edit (a `state.edited` note on the existing event path, or the current
   event kind used for edits if one exists; no new event kind unless 54-06 adds it to the contract, L-005/L-011) and
   ignores `final`.
2. Which statuses `patch_state` accepts stays as it is today (read the code and the web's edit control; record the
   set in As built). If it accepts a `running` run, keep that, and the edit still never touches the stored status.
3. The stop marker of a paused run is not reset by a spawn for another op (keep `seen["stop"]` when the run has one).
4. After the edit the run's stored status is exactly what it was before (paused stays paused; awaiting gate stays
   awaiting gate). Resume continues from the edited state (ADR-009 mode 3).

**Tests:** paused run → `PATCH /api/runs/{id}/state` → status still `awaiting_input:paused`, no `run.final` logged,
resume runs the edited state; the same for a run at a gate. Test through the real `RunManager`
paths (L-093), with a fake worker whose `final` carries `status: "running"`.

## 2. B2 — `artifact.saved` and `tool_output.recorded` reach the per-turn inspector

**Today:** emitted by `kiro_node` (`packages/genesis-core/genesis_core/nodes/agent.py:412`, `:420`) through `ctx.emit`;
`_CANONICAL_CUSTOM` (`runs/manager.py:41-44`) omits them, so they are stored as kind `custom` with no node
(`:239`); `fold_turns` (`runs/steps.py:130`) matches kind `artifact.saved` and `p["document"]` and never fires.

**Change:**
1. Add `artifact.saved` and `tool_output.recorded` to `_CANONICAL_CUSTOM`, so they are stored with their own kind,
   `node` set and the payload fields at top level (same lifting as the other canonical types).
2. Add both kinds to the canonical event list wherever it is declared (backend constant, `web/src/types` event union,
   golden fixtures; L-005, L-011), and check the event-kind consumers listed by grep (L-094): the run timeline, the
   conversation fold, the SSE client, and any filter that drops unknown kinds.
3. `fold_turns`: also read old stored rows, kind `custom` with `payload.data.type == "artifact.saved"`, so runs stored
   before the fix show their artifacts.

**Tests:** a fixture event stream from a real run shape (`ctx.emit({"type":"artifact.saved","node":…,"document":…,
"ref":…})`) folds into `turn.artifacts`; an old `custom` row folds the same; the web `NodeIterationsDialog` renders
the list (existing test extended).

## 3. B3 — Dead code in `runtime/settings.py`

Delete the unreachable lines after `return` in `collab_hub_dir` (`genesis/runtime/settings.py:253-257`, the body of the
old `artifacts_writable`, Phase 4 `3b5abc0e`, header lost in Phase 35 `95b86e7a`). Nothing calls `artifacts_writable`
(grep `genesis/`, `tests/`, `web/src`). Ruff stays green; no behaviour change.

## 4. O1 — Failed Compose (and Recording) captures can be discarded

**Today:** `web/src/features/testing/CapturesPanel.tsx:24-26` keeps every capture not `applied`/`discarded` in the
"Proposals to review" list; Discard shows only for `recording`/`ready` (`:98`); `_CAPTURE_EDGES`
(`genesis/kb/testexec_store.py:71-72`) gives `failed` no outgoing edge; `RecordingService._discard`
(`genesis/testexec/recording.py:333-350`) 409s on other states.

**Change:**
1. `_CAPTURE_EDGES`: `failed → discarded`. `_discard` accepts `failed`; for a failed capture it writes only the status
   (no recorder to stop; if a bound run is still non-terminal, cancel it first through the normal path, L-108).
2. Web: a **Discard** button on failed cards (the same `discard.mutate`, with the existing confirm if Discard has one);
   discarded captures leave the list.
3. A compose capture whose run waits at its escalation gate keeps its "Open run" link and also gets Discard (cancels
   the run, then discards).

**Tests:** store edge test; API `POST …/captures/{id}/discard` on a failed capture → 200 and status `discarded`; web
test: a failed card shows Discard and disappears after it.

## 5. O4 — Environment labels containing `/`, and an honest 404 for unmatched `/api/*`

**Today:** the web sends `DELETE /api/config/environments/{encodeURIComponent(label)}` (`web/src/lib/api/config.ts:46-47`);
the route is `{label}` (`genesis/api/config_routes.py:98`); the user's QA label is a URL
(`https://example-qa2.appianpreview.com`), the decoded `/` breaks the match, and the GET-only SPA catch-all
(`genesis/api/app.py:412`) answers DELETE with 405. `POST /config/environments/{label}/dev` has the same flaw.

**Change:**
1. Every environment route that takes a label accepts a label with `/`: declare `{label:path}` for the delete route;
   for `…/{label}/dev` (and any other `{label}/<suffix>` route, found by grep) use a form that cannot be confused with
   the delete route, such as moving the label to the request body or query (`POST /config/environments/dev
   {label}`), updating the web client in the same commit. Register specific routes before generic ones and prove the
   order by a test (L-096). Settings detail routes in the web (`/settings/:tab/:id`, `SettingsPage.tsx:39`) already
   encode; check they open a `/`-label environment.
2. Labels keep being free text (existing environments must keep working); no new validation that would reject a
   stored label.
3. The SPA catch-all returns **404 JSON** for any `/api/...` path that matched no route, for every method, instead of
   405 or the SPA HTML (ADR-028, L-010).

**Tests:** create an environment labelled `https://example-qa2.appianpreview.com`, make it Dev, delete it (200 each);
`DELETE /api/does-not-exist` → 404 JSON; `GET /some/spa/route` still serves `index.html` with `Cache-Control: no-cache`
(L-068).

## 6. Gates

`cd genesis && .venv/bin/python -m pytest -q -p no:warnings`, `.venv/bin/ruff check genesis`, genesis-core pytest +
ruff (B2 touches only the app unless the event list lives in core), web `npm run lint && npm run typecheck && npm test`,
`npm run build` and commit `web/static/` in its own step (L-089).

## As built

**Status:** BUILT 2026-11-18, review **SHIP** (re-run 1). Repo genesis, branch master, base `ea00dfd`, head `eed5da0`,
9 local commits (not pushed, not tagged). 24 source/test files +659/−46, plus `web/static` in two build commits.

### Commits (genesis)

| sha | what |
|---|---|
| `86baf74` | B1: `patch_state` runs the edit through `RunManager._spawn_edit` |
| `7d1a55c` | B2: `artifact.saved` and `tool_output.recorded` become canonical kinds; old `custom` rows are folded too; web fixtures |
| `d8ee04c` | B3: dead lines removed from `runtime/settings.py` |
| `938504d` | O1: `failed → discarded` edge; `_discard` handles a failed capture and one waiting at its gate; Discard button in CapturesPanel |
| `959d002` | O1: test typing fix (a failed capture's real `{error}` proposals shape) |
| `f150a4a` | O4: `{label:path}` delete, make-Dev moved to `POST /config/environments/dev`, catch-all for every method |
| `3c61494` | `web/static` build for the commits above (63 files) |
| `3e28d28` | review round 1: M1 test, m2 real-RunManager test, m1 confirm dialog |
| `eed5da0` | `web/static` build for 3e28d28 (63 files) |

Bundle proof (L-089): each bundle commit was checked with `git show --stat <sha> -- web/static` (63 files each). A
rebuild made in a later message left `git status --short --untracked-files=all` empty. The reviewer's out-of-tree
build was identical to the committed `web/static` both times.

### Changed

- **B1** `genesis/runs/manager.py`: `patch_state` now uses a new `_spawn_edit` instead of `_spawn`.
  - On `final`, `_spawn_edit` only logs a `custom` row `{"data": {"type": "state.edited", "keys": [...]}}`. This goes
    through the existing event path; no new canonical kind (L-005).
  - It never writes run status and never logs `run.final` or `gate.awaiting`.
  - An `error` or abnormal exit raises `StateEditError`, which the route already maps to 400. The run is never failed.
    The first error wins over a later `worker_exit` (L-008).
  - The edit worker is not registered in `_workers` or `_worker_state`. The run's own worker and its stop marker
    (51-15) are therefore untouched (§1.3), and pause/cancel still kill the run's real worker.
- **§1 item 2, statuses `patch_state` accepts, unchanged:** the backend checks none. Any run status is accepted, as
  before, including terminal ones. The web offers **Edit state** on every non-terminal run (`HitlBar.tsx`: hidden when
  `done|failed|cancelled`), i.e. `pending`, `running`, `awaiting_input:gate`, `awaiting_input:paused`. The stored status
  is never touched by an edit.
- **B2** `genesis/runs/manager.py` `_CANONICAL_CUSTOM` gains `artifact.saved` and `tool_output.recorded`. They are now
  stored with their own kind, `node`, and the payload lifted to the top level: `{document, ref}` and
  `{ref, tool, bytes}`.
  - `genesis/runs/steps.py`: new `event_node(e)` and `_legacy_custom(e)`. `fold_iterations` maps an old `custom` row
    with `payload.data.type == "artifact.saved"` to the new shape.
  - `RunManager.node_iterations` selects a node's events with `event_node`, so old rows (node NULL, `data.node` set)
    reach the fold.
  - Web: both kinds are added to `CANONICAL_EVENT_KINDS` and `EVENT_FIXTURES` (`web/src/test/fixtures/events.ts`) and
    to the `RunEvent.kind` comment (`web/src/types/event.ts`). The contract test pins their payload keys and checks
    that `buildTranscript` ignores them.
- **B2 event-kind consumers checked (L-094):**
  - Backend: `fold_steps` (counts only `agent.*`/retry/completed/gate/error; the new rows sit inside an agent turn of
    the same node), `fold_transitions` (`node.completed` only), `fold_iterations` (changed), `introspection_server`
    `get_run_events` (lists any kind), `chat/supervisor.py` and the stage/story/capture/test-execution finalizers
    (`run.final`/`gate.*` only), `reconcile_status`/`fail_orphaned_runs` (`run.final`/`node.completed`).
  - Web: `node-states.ts` (ignores non-`agent.*` kinds), `conversation.ts` `buildTranscript` (`TRANSCRIPT_KINDS`
    switch), and the SSE `STREAM_KINDS`/`NODE_STREAM_KINDS` in `run-detail/hooks.ts`. The SSE lists are **unchanged**:
    no handler acts on the two kinds, and the per-turn artifacts come from the `node_iterations` query, which polls
    every 2.5 s while live. `NodeIterationsDialog` already rendered `turn.artifacts`.
- **B3** `genesis/runtime/settings.py`: the 5 unreachable lines after `collab_hub_dir`'s `return` are deleted.
  `artifacts_writable` has no caller in `genesis/`, `tests/`, `web/src` or `packages/`.
- **O1**
  - `genesis/kb/testexec_store.py`: `_CAPTURE_EDGES` gains `"failed": ("discarded",)`.
  - `genesis/testexec/recording.py` `_discard` now accepts `recording`, `ready`, `failed`, and `analysing` when the
    bound run is `awaiting_input:gate`. Anything else is still a 409 `RecordingError`.
  - For `failed`/gated, `_cancel_bound_run` cancels a still non-terminal run through `RunManager.cancel` (its CAS and
    one `run.final`, L-108). The capture's finalizer fails the capture on that `run.final`; if no finalizer did, the
    service fails it itself (`"discarded: its run was cancelled"`). The capture is then discarded. The whole sequence
    runs under the service lock (L-091).
  - The API docstring is updated.
  - Web `CapturesPanel.tsx`: **Discard** shows on `recording`, `failed` and gate-waiting cards. **View run** is kept.
    Discard on a gate-waiting card asks first ("Discard and cancel its run?", Keep waiting / Yes, discard; review m1).
    A refused Discard shows the server's detail in place. Discarded captures move to "Earlier captures".
- **O4 routes changed** (`genesis/api/config_routes.py`, `_shared.py`, `app.py`, `web/src/lib/api/config.ts`):
  - `DELETE /config/environments/{label}` → `DELETE /config/environments/{label:path}`.
  - `POST /config/environments/{label}/dev {is_dev}` → `POST /config/environments/dev {label, is_dev}`. `DevEnvBody`
    gains `label`. The old route is removed, and the web client changed in the same commit.
  - Unchanged: `GET /config/environments`, `POST /config/environments` (label in body), and
    `GET /config/environments/dev/check`. No other route takes an environment label in its path (grep of
    `genesis/api` for `{label`/`{env`). Labels stay free text, with no new validation.
  - The SPA catch-all `/{full_path:path}` now answers `GET HEAD POST PUT PATCH DELETE OPTIONS` (`_FALLBACK_METHODS`):
    - an `/api/...` (or `/assets/...`) path that matched no route → **404 `{"detail":"Not Found"}`**;
    - a path another route serves with a different method (`Match.PARTIAL`) → 405 JSON;
    - a non-GET to a browser route → 405;
    - GET still serves `index.html` with `no-cache, must-revalidate` (L-068).
  - Web Settings: the Environments tab does not route by `:id` (`EnvironmentsSection` selects in place), so
    `/settings/:tab/:id` has nothing to open for an environment. The web test opens `/settings/environments` with a URL
    label.

### Tests (fail-first evidence)

- **B1** `tests/test_runs.py`:
  - `test_a_state_edit_whose_worker_reports_running_keeps_the_stored_status[paused|gate]` (scripted worker whose
    `final` carries `"running"`, through the real `RunManager` event path).
  - `test_a_failed_state_edit_is_refused_and_never_fails_the_run`.
  - `test_a_state_edit_keeps_the_runs_own_worker_and_its_stop_marker` (review M1: running run → edit → cancel kills the
    run's own worker; paused run keeps its marker).
  - `test_edit_state_of_a_paused_real_run_then_resume_runs_the_edited_state` and
    `test_edit_state_at_a_real_gate_keeps_the_gate` (real subprocess worker, L-093).
  - `tests/test_api.py::test_api_edit_state_of_a_paused_or_gated_run_keeps_its_status` (PATCH route; gate → pause →
    edit → resume → approve → `final == "PAUSED-EDIT"`).
  - Fail-first: before the fix, 6 of the 8 `-k "state_edit or edit_state"` tests failed, e.g.
    `assert 'running' == 'awaiting_input:paused'` and, for the real gate run, `'running' == 'awaiting_input:gate'`.
    The API test failed with `('running' == 'awaiting_input:gate')` with `manager.py` stashed. A real gated run edited
    on the old code also turned `running`.
  - The M1 test fails under a mutation probe that re-registers the edit worker (identity assert). The reviewer's two
    single-half probes fail it too.
- **B2** `tests/test_runs.py`:
  - `test_artifact_saved_and_tool_output_recorded_are_stored_with_their_kind_and_node`: the event stream is in
    `kiro_node`'s real `ctx.emit` shapes (L-083).
  - `test_an_old_custom_artifact_saved_row_folds_into_its_turn`.
  - Fail-first: `assert 'custom' not in {...}` and `[] == ['w3/snapshot.txt']`.
  - Web: `contract.test.ts` (new case) and the `NodeIterationsDialog.test.tsx` artifacts list.
- **B3** `tests/test_runtime_settings.py`: an AST check that no function in `settings.py` has a statement after its
  `return`, plus `collab_hub_dir` behaviour. Fail-first: `['collab_hub_dir (line 253)'] == []`.
- **O1**
  - `tests/test_testexec_store.py::test_a_failed_capture_can_be_discarded_and_nothing_else`.
  - `tests/test_testexec_recording.py` (FakeRunManager gains a `cancel` that announces `run.final` like the real one):
    - failed;
    - failed with a running run (cancelled first);
    - gated with the ComposeFinalizer attached;
    - gated with no finalizer;
    - a working run still refused;
    - `test_a_gated_compose_discard_through_the_real_run_manager` (review m2, L-093).
  - `tests/test_testing_api.py`: `POST …/captures/{id}/discard` on a failed compose → 200 `discarded`, then 409.
  - Web `library.test.tsx`:
    - a failed card shows Discard and leaves the list;
    - a gate card keeps View run, and its confirm is checked (Keep waiting sends nothing, Yes discards, jest-axe);
    - a refused Discard shows the detail.
  - Fail-first: the service tests raised `RecordingError: capture #1 is failed: only a recording or ready proposals can
    be discarded`, and the web tests could not find a "Discard" button.
- **O4**
  - `tests/test_api.py`:
    - `test_api_an_environment_labelled_with_a_url_can_be_made_dev_and_deleted` (`https://example-qa2.appianpreview.com`:
      create, make Dev, untag, delete, 200 each);
    - `test_api_environment_routes_beside_their_literal_siblings` (L-096 by behaviour: `dev/check` answers `missing`,
      `POST dev` answers `dev_env`, environments named `dev` and `dev/check` are deleted through `{label:path}`);
    - `test_api_unmatched_api_paths_answer_404_json_for_every_method` (DELETE/POST/PUT/PATCH/GET → 404 JSON;
      `PUT /api/config/environments` → 405; SPA GET → `index.html` no-cache; POST to a browser route → 405);
    - `test_api_the_catch_all_comes_after_the_api_router` (route table order).
  - The existing whole-table `test_no_route_is_shadowed_by_an_earlier_path_parameter_route` still passes.
  - Old tests moved to the new make-Dev form: `test_api_dev_environment_toggle` and `test_api_type_round_trip`.
  - Web `settings.test.tsx`: a URL label → Set as dev posts `{label, is_dev}` to `/api/config/environments/dev`; Delete
    sends `DELETE /api/config/environments/https%3A%2F%2Fexample-qa2.appianpreview.com`.
  - Fail-first:
    - `DELETE /api/does-not-exist` → `405 == 404`;
    - the URL-label make-Dev → `405 == 200`;
    - `POST /api/config/environments/dev` → `{'detail': 'Method Not Allowed'}`;
    - web: the old client sent `POST /api/config/environments/https%3A%2F%2Fexample-qa2.appianpreview.com/dev`
      (unhandled), `expected [] to deep equally contain {method: 'POST', …}`.
- **Gates (head `eed5da0`):**
  - genesis `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe`:
    **1966 passed, 1 deselected**. This is the reviewer's run, 15:19–15:29 IST; mine at `3c61494` was 1965 passed at
    14:35 IST. Neither run fell in the D27 00:00–02:00 IST window, and
    `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` passed.
  - `.venv/bin/ruff check genesis`: clean.
  - Web `npm run lint`: 0 errors, 20 pre-existing warnings, none in changed files. `npm run typecheck`: clean.
    `npm test`: **66 files / 770 passed**.
  - genesis-core not touched, so its gates were not needed.

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-02-review.md`.
- **Round 1: NEEDS_CHANGES.**
  - M1: the stop-marker test did not test the marker.
  - m1: Discard of a gated capture cancelled its run with no confirm.
  - m2: the gated bridge was tested only through a fake `cancel`.
  - N1: docs lines (see below).
  - N2: no `Allow` header on the catch-all's 405.
- **Fixed in `3e28d28`/`eed5da0`:** M1, m1 and m2.
- **Re-run 1: SHIP.**
- **Not taken:**
  - N2: no client reads `Allow`, and the methods of an `_IncludedRouter` partial match would need a walk of the
    wrapped routes.
  - N3, optional (re-run 1): a failed capture whose run is still live also cancels that run in one click. This is rare
    because a finalizer fails a capture only on a terminal `run.final`.

### Decisions / deviations

No ADR deviation.
1. The edit note is kind `custom` with `data.type: "state.edited"` and the edited key names, on the existing path.
   No new canonical kind; 54-06 adds none.
2. A failed edit raises `StateEditError` (400) instead of failing the run. The spec says an `update_state` job never
   writes run status.
3. The old `POST /config/environments/{label}/dev` route is removed, not kept for compatibility. Its only caller was
   the web client. A stale open tab gets 405 until reloaded, and the shell is no-cache (L-068).
4. The catch-all keeps an honest 405 for a real route hit with the wrong method, by checking `Match.PARTIAL` on the
   other routes. Side effect: any `GET /api/config/environments/<x>` is now 405, not 404, because the `{label:path}`
   DELETE matches the path.
5. SSE kind lists are not extended for the two new kinds (see Changed).
6. O1 §4.3 is implemented as cancel → finalizer fails → discard, so `analysing → discarded` needs no new edge. The
   confirm dialog covers only the gate-waiting card.

### Found, not fixed (out of scope; for follow-up)

- `agent.prompt` is a canonical kind (`_CANONICAL_CUSTOM`) but is missing from the web `CANONICAL_EVENT_KINDS` and
  `EVENT_FIXTURES` (pre-existing L-011 drift).
- The web `Capture["proposals"]` type requires a `proposals` list, but a failed capture stores `{error}` only. The O1
  test casts the real shape through `failedProposals`.
- Runs edited before this fix may be stored `running` with a `run.final{running}` row. `reconcile_status` keeps
  adopting that marker after a restart. Nothing repairs them.
- **Docs hand-off (genesis-docs, review N1):** two docs still describe the old routes:
  - `docs/architecture/modules/configuration-and-secrets.md:589-590` lists `POST /config/environments/{label}/dev` and
    `DELETE /config/environments/{label}`.
  - `docs/architecture/modules/api.md:245` mentions "the `{label}` routes".
  
  Both should give the new forms and note the catch-all's 404/405 behaviour.

### Lesson candidates

1. **A GET-only SPA catch-all turns every unmatched non-GET `/api` call into a 405.** Starlette prefers a later FULL
   match over an earlier PARTIAL one and answers a lone PARTIAL with 405. So the catch-all must take every method,
   answer 404 for unmatched `/api/*`, and keep 405 only for a real PARTIAL (O4).
2. **A free-text value in a path segment breaks at the first `/`.** `encodeURIComponent`'s `%2F` is decoded before
   routing. Use `{x:path}` for a trailing segment, or put the value in the body, and test with the user's real value
   (a URL).
3. **An op that reuses the run's stop path is read as a stop.** `update_state`'s `final` went through the run
   lifecycle handler and stored `running`. Give non-stop ops (edit, read) their own event handler, and never let them
   replace the run's tracked worker (B1).
4. **A test of "marker kept" must fail when the wiring regresses, not only when the outcome does.** The paused
   worker's closure dropped its late events whatever `_worker_state` held. Prove such a test with a mutation probe
   (L-108 corollary, review M1).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runs/manager.py`:
  - `RunManager._spawn_edit(job) -> (Worker, outcome)`: the `update_state` path (no status write, a `custom`
    `state.edited` note, `StateEditError` on failure, not registered as the run's worker).
  - `patch_state` uses `_spawn_edit`.
  - `_CANONICAL_CUSTOM` gains the two kinds.
  - `node_iterations` filters by `steps.event_node`.
- `genesis/runs/steps.py`: `event_node(e)` and `_legacy_custom(e)`; `fold_iterations` reads old `custom`
  `artifact.saved` rows.
- `genesis/kb/testexec_store.py`: `_CAPTURE_EDGES["failed"] = ("discarded",)`.
- `genesis/testexec/recording.py`: `_discard` accepts failed and gate-waiting captures; new `_cancel_bound_run`.
- `genesis/api/config_routes.py`: `POST /config/environments/dev {label,is_dev}` and
  `DELETE /config/environments/{label:path}`. `_shared.DevEnvBody.label`.
- `genesis/api/app.py`: `_FALLBACK_METHODS`; the every-method `spa_fallback` (404/405 JSON for `/api/*`) and
  `_other_method_matches`.
- Web:
  - `web/src/lib/api/config.ts` `setDevEnvironment` posts `{label, is_dev}` to `/config/environments/dev`.
  - `web/src/features/testing/CapturesPanel.tsx`: the `discardable`/`gated` rule and the Discard-and-cancel confirm.
  - `web/src/test/fixtures/events.ts`: two more canonical kinds.

## Context manifest

```toml
areas    = ["runs-worker", "config-secrets", "browser-testing", "web-runs", "api"]
adrs     = ["ADR-009", "ADR-025", "ADR-028", "ADR-066", "ADR-081"]
lessons  = ["L-005", "L-010", "L-011", "L-068", "L-089", "L-093", "L-094", "L-096", "L-107", "L-108"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md"]
code     = ["genesis/genesis/runs/manager.py", "genesis/genesis/runs/worker.py", "genesis/genesis/runs/store.py", "genesis/genesis/runs/steps.py", "genesis/genesis/runtime/settings.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/testexec/recording.py", "genesis/genesis/api/config_routes.py", "genesis/genesis/api/app.py", "genesis/web/src/features/testing/CapturesPanel.tsx", "genesis/web/src/lib/api/config.ts", "genesis/web/src/features/run-detail/**"]
upstream = []
```
