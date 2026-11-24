# Backlog — Phase 55 follow-ups (memory brief, agent-assisted escalation, Documents, run liveness)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-23 by the spec agent with the two items deferred from
> 55-09's review (D27); §3 from 55-10's As built; §4 from 55-11's fix-pass re-review (D38); §5 (the umbrella §9
> deferred scope) and §6 (build findings) appended by the Phase 55 write-back (genesis-docs, 2026-11-24).

## 1. m4 — the validator step's "OK · check failed N times" label (D12 n3, deferred by D27)

- **What the approved mockup shows:** a validator step whose check failed reads "OK · check failed N times" on the run
  graph's node card and in Documents (`/dev/phase-55`, genesis `d0aa1b2`).
- **Why it is missing:** neither `GET /runs/{id}/snapshot` nor `GET /runs/{id}/documents` reports how many times a
  check failed; 55-09 built everything else of the step (55-09 As built; review m4, non-blocking). The failures still
  show in the step's events and in Resolve's escalation findings.
- **Fix direction:** count each validator's failed `validator.result` events in the snapshot fold
  (`genesis/runs/snapshot.py`, add the kind to `FOLD_KINDS`; incremental, L-066) as a node field, and render the line
  on `NodeCard` (and the Documents step header if wanted); one test per state that the node and its incoming edge use
  the same rule (55-03 lesson candidate 3).
- **Why deferred:** the user's choice (D27): a convenience label whose facts are one click away; not worth a review
  cycle on the Phase 55 critical path.

## 2. n2 — `test_run_liveness` reconnect test flakes under full-suite load (55-09 review)

- **Symptom:** one `/live` reconnect timing test in `genesis/tests/test_run_liveness.py` failed once in the reviewer's
  full-suite run and passes alone.
- **Fix direction:** replace the wall-clock wait with an event the test can await (the subscriber's registration or
  the resync frame), or widen only that bound with a comment; run the file 50× under load to prove it.

## 3. action-capture: removing saved logins is not in a `finally` (55-10, pre-existing)

- **Symptom:** in `genesis-workflows/workflows/action-capture/graph.py`, the step that removes the saved QA logins after
  a capture runs only on the success path; an exception before it leaves them in the capture's folder (55-10 As built).
- **Fix direction:** move the removal into a `finally` (or a cleanup node every route reaches, as story-verification's
  stop now does), and test it with a capture that raises; L-107 (every error path reaches its terminal step).
- **Why deferred:** it predates Phase 55 and is outside 55-10's scope.

## 4. 55-11 fix-pass re-review findings (deferred by D38)

All four are reached only after an earlier failure; none is reachable through normal use (`reviews/55-11-review.md`,
the fix-pass re-review; genesis `e8096f71`).

- **m5 — the stage rebind is two separate writes.** In a relaunch or restart_from, moving a stage / story binding to
  the new run is two writes; if the second fails, the stage reads "in progress" with no run behind it. Recovery today:
  re-run the stage. Fix direction: one transaction (take the write lock first, L-091), or record the rebind as one
  compare-and-set row; test with the second write forced to fail.
- **m6 — Resume on a run waiting at a gate has no compare-and-set.** No UI path reaches it today (gates are answered,
  not resumed). Fix direction: reuse 55-11's `RunStore.claim_transition` in `RunManager.resume` for the gate state.
- **n3 — a brief cut off mid-write leaves `_memory/brief.md.part`.** Harmless (Documents never lists `*.part`, no
  `brief.md` is written). Fix direction: remove the `.part` file in the prefetch's `finally`.
- **n4 — a write failing after a gate claim leaves the run "running" with no worker** until the next startup, whose
  sweep fails it (L-097). Fix direction: give the claim back (as fix-and-accept does) when a later step before the spawn
  fails; test with that step forced to fail (L-107).

## 5. Deferred scope (umbrella §9, appended at the write-back 2026-11-24)

- **An agent-written memory brief** (D2's upgrade path, ADR-088 alternatives): an agent turn that queries memory and
  writes `_memory/brief.md`, for better relevance than the program prefetch. Costs one turn and 30–90 s per run and
  needs an ADR-011 exception or its own validator. Measure against the program brief on the same runs first.
- **Versions of run files** (D9): today a document keeps only its latest write and a write count; tool-output files are
  purged at the run's end. Keeping old versions needs a storage and retention decision.
- **Memory-usage feedback into ranking** (`mark_used`): record which brief entries an agent used (or searched for) and
  feed it into `HybridRetriever`'s recency/importance; today `last_used_at` is set only by chat reads.
- **Anchor normalization in consolidation:** memories carry inconsistent entity anchors (55-01 §2), which weakens the
  brief's entity hints; normalize anchors when memories are consolidated.

## 6. Found during the build, not fixed (55-02..55-14 As built; write-back 2026-11-24)

Memory brief (55-04):
- **Ranking:** no similarity floor (a run with no application context gets the 12 nearest memories however weak,
  decision 3); the full description is the semantic query with the steps last, which ranks context-only matches lower
  (decision 6); #27 is missing from the feature-4 brief (deviation 2). Tune on real runs; A1–A14 judge it live.
- **Offline model load proven on macOS only**; the live negative control (a session without the brief) was not run.

Escalation and run actions (55-06, 55-07, 55-08, 55-10):
- **m1 (55-06): a run's launch environment is not stored**, so a relaunch (and already a resume) uses the active
  environment. Store it on the run and reuse it.
- **n4 (55-06):** if a fork's process exits before its reader thread applies the final event, the fork reads PENDING
  and is taken as seeded. **n5:** `_iteration.pass` is not reset in the fork seed (cosmetic).
- **55-08:** a crash between the cancel and the `run.relaunched` log loses `_replacing`, and the schedule row then
  closes as cancelled; followers other than the scheduler (a copilot chat's run links) do not follow a replacement;
  the snapshot's and `GET /runs/{id}`'s `gate.allowed.relaunch` / `restart_from` are the raised-time values (safe:
  apply re-checks; the Resolve tab reads the live map).
- **55-07 n3:** an off-thread Resolve refresh still copying when the run ends can put `run/_toolcalls/` back (retention
  removes it later). **n4:** a cold-start turn racing a stored note could give the agent that note twice.
- **55-10 n3:** in top-up mode `topup.html` is labelled `intermediate`, so a top-up run's Documents shows no output; a
  per-mode role is needed. **n5:** no genesis test covers `RunManager._check_answer` refusing an unavailable extra
  option (the reviewer probed it by hand).
- **`reliable_agent_step` still takes the gate's name**, not an `EscalationGate`, so it uses the pre-Phase-55 string
  wiring the lint refuses; no library workflow uses it. Either accept an `EscalationGate` or deprecate it.
- **`schemas/workflow.schema.json` (genesis-workflows) does not list `models` / `default_model`**; they pass only
  because the schema allows extra keys. Add them with their types.

Documents and write records (55-05, 55-14):
- Over 1 MiB, a same-size in-place rewrite within one ctime tick is missed, and a chmod reads as a write; up to 1 MiB a
  rewrite with identical bytes reads unchanged; a filesystem stamping from a clock more than 3 s behind can let the
  memo reuse a stale hash (`writes.py` docstring).
- A task killed before its finish (pause, crash) leaves no record of what it wrote; a fan-out is attributed
  `_parallel` with no per-branch split; the fan-out start order is not spiked.

Web and probes (55-13):
- The graph's legend panel overlaps the leftmost card at 1440 px on `hello-appian`
  (`evidence/55-13/agent/agent-fallback-inspector-1440-light.jpg`).
- Not checked in a browser: the selection ring on each card tint; a `cancelled` card live; a fallback to a *listed*
  next model candidate; a fan-out sharing one model-list read.

Release and docs (55-12 As run, the write-back):
- **The genesis-workflows steering does not document the Phase 55 `META` keys** (`artifacts` role map,
  `relaunchable` / `relaunch_hint`, `memory_brief`, `models` / `default_model`) or the standard gate:
  `steering/02-node-taxonomy-and-reliability.md` and `05-hitl-gates.md` still name `hitl_gate` as the escalation
  target, and `07-workflow-yaml-reference.md` lacks the keys. genesis-docs cannot write genesis-workflows; the text to
  copy is `reference/workflow-authoring-standard.md` §2.1 and `reference/reliability-standard.md` §5 (project-tracker).
  A genesis-dev change for the next library release.
- **`gsm provision` does not run `scripts/install-packages.sh`** (genesis-fleet): a release that adds a Python
  dependency or a state-dir asset needs the script run by hand with the fleet stopped, plus `genesis memory
  fetch-model` / `reembed` per non-default instance (now in the genesis-release skill). Option: `gsm provision` grows
  that step.
- **L-112 for the library:** the colima image run could not install from PyPI at 55-12 (41 kB/s, read timeouts); keep
  a pip cache or a pre-built image under `/tmp/colima`.
- **L0 budget:** the always-loaded layer is at ~23,996 / 24,000 tokens after this write-back; the next phase needs a
  compression (proposed in `progress/phase-55-workflow-execution.md`, "Agent-system notes").
