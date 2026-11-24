# Backlog — Phase 55 follow-ups (memory brief, agent-assisted escalation, Documents, run liveness)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-23 by the spec agent with the two items deferred from
> 55-09's review (D27); §3 from 55-10's As built; §4 from 55-11's fix-pass re-review (D38). The Phase 55 write-back (55-12 §3, genesis-docs) appends the umbrella §9 deferred scope and the
> build findings.

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
