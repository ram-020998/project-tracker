# 54-02 — Fixes: paused-run edit, artifact events, dead code, failed captures, environment labels

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis. Parent: `specs/phase-54-schedules-and-fixes.md`. Built by
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

_(genesis-dev fills in: commits, changes, tests, review verdict, decisions/deviations, lesson candidates, code-map
changes, Resume note.)_

## Context manifest

```toml
areas    = ["runs-worker", "config-secrets", "browser-testing", "web-runs", "api"]
adrs     = ["ADR-009", "ADR-025", "ADR-028", "ADR-066", "ADR-081"]
lessons  = ["L-005", "L-010", "L-011", "L-068", "L-089", "L-093", "L-094", "L-096", "L-107", "L-108"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md"]
code     = ["genesis/genesis/runs/manager.py", "genesis/genesis/runs/worker.py", "genesis/genesis/runs/store.py", "genesis/genesis/runs/steps.py", "genesis/genesis/runtime/settings.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/testexec/recording.py", "genesis/genesis/api/config_routes.py", "genesis/genesis/api/app.py", "genesis/web/src/features/testing/CapturesPanel.tsx", "genesis/web/src/lib/api/config.ts", "genesis/web/src/features/run-detail/**"]
upstream = []
```
