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
