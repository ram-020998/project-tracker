# Backlog — Phase 55 follow-ups (memory brief, agent-assisted escalation, Documents, run liveness)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-23 by the spec agent with the two items deferred from
> 55-09's review (D27). The Phase 55 write-back (55-12 §3, genesis-docs) appends the umbrella §9 deferred scope and the
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
