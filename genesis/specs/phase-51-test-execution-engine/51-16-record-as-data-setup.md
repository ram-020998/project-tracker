# 51-16 — A recording can also produce a data setup

> **Status:** SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`
> 0.2.0, skill `genesis-test-authoring`). Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D33,
> D34 (and D13, D27, D28). One migration **m0028** (DB 27 → 28), shared with 51-17. Built after 51-15.

## 1. Goal

A person who records "get an evaluation into In Progress" gets, besides the reusable actions, **one data setup** that
runs those actions in order and returns the ids the flow created — reviewed and accepted like any proposal.

## 2. Migration m0028 `capture_request`

`ALTER TABLE kb_test_captures ADD COLUMN request_json TEXT` (nullable): what the person asked a capture to produce.
Recording: `{"setup": {"name": "…", "end_state": "…"}}` or NULL; 51-17 stores its composer request here too. Module
and `Migration` names must not start with `test_` (L-092). Tests: fresh DB → v28; v27 with data → v28 unchanged.

## 3. Record dialog and API (D34)

- The Record dialog gains a checkbox **Also make a data setup from this recording**; when ticked, two required
  fields: **Setup name** and **End state** ("what the data looks like when the setup is done, and which ids it should
  output"). The setup runs as the recording's role (D13).
- `POST …/testing/recordings` body gains `setup: {name, end_state} | null` (51-10 contract table + a fixture); stored
  in `request_json`; the recording bar shows "… + data setup".
- `RecordingService.stop` passes `setup_request` to the `action-capture` run's inputs.

## 4. `action-capture` 0.2.0

- **Input** `setup_request` (optional).
- **`segment` prompt + skill §5:** when `setup_request` is present, also propose exactly **one** `setup` proposal,
  `match: "new"`, `path: setups/<slug>.ts`, the recording's role, that calls the recording's actions (reused and new,
  by import) in recorded order. Literals that must differ per run use `unique(prefix)` (D8.6); the values the end
  state names become **outputs** (outputs only, D27); `export default defineSetup(…)`. The proposal lists the action
  proposals it uses (`uses: ["P1", "P2", …]`).
- **`v_segment`:** with a request, exactly one setup proposal; it imports only actions that are in this proposal set
  or the library; its `uses` matches its imports; outputs only; role = the recording's; `export default`; the
  typecheck covers it. Without a request, no setup proposal is required (today's behaviour).
- **`replay`:** when a setup proposal exists, replay **the setup** (it calls the actions) instead of the loose action
  sequence; a pass marks the setup **and every action it used** as replayed at that code (so both are Ready on apply,
  51-07 §6 + D28). Without one, the replay is unchanged. Healing (≤ 1 patch, ≤ 1 restart) works on the setup and its
  actions alike.
- Version 0.2.0; `workflow.yaml` mirrors `META` (parity lint); `validate_library` green; `heal` timeout as 51-15 m4.

## 5. Applying proposals

`ProposalService.apply` creates the setup with a real `DS-` key after the actions it uses (one commit, the actions'
real keys and paths substituted in the setup's imports). **Dependency rule:** accepting the setup requires accepting
(or reusing) every action it uses; a decision set that rejects one is refused with "the data setup uses P2 — accept
it or reject the setup" (409 `problems`). The proposals panel (51-11) shows the setup proposal with "uses P1, P2, …",
its outputs and its replay result, and disables Accept for it while a used action is rejected.

## 6. Tests

m0028; the dialog (checkbox, required fields, jest-axe); the API field + fixture; `segment`/`v_segment` with and without
a request (refusals: two setups, a setup importing an unknown action, inputs on a setup, wrong role); the replay picks
the setup and marks its actions; apply order, key substitution in imports, and the dependency refusal; a recorded
trace fixture from the sandbox repo for the node tests (as 51-07). Gates as 51-15 §5. Live: 51-12 re-run step 26.

## Context manifest

```toml
areas    = ["workflows-library", "core-engine", "db", "stories-workbench"]
adrs     = ["ADR-011", "ADR-012", "ADR-050", "ADR-067", "ADR-069"]
lessons  = ["L-011", "L-020", "L-022", "L-042", "L-076", "L-083", "L-089", "L-091", "L-092", "L-093"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-07-action-library-and-recording.md"]
code     = ["genesis/genesis/db/migrations/**", "genesis/genesis/testexec/recording.py", "genesis/genesis/testexec/proposals.py", "genesis/genesis/testexec/capture_finalizer.py", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/api/testing.py", "genesis/web/src/features/testing/**", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/skills/genesis-test-authoring/**"]
upstream = ["51-07", "51-10", "51-11", "51-15"]
```
