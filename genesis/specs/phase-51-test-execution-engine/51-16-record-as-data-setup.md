# 51-16 — A recording can also produce a data setup

> **Status:** BUILT 2026-11-05 (genesis-review SHIP, delta SHIP — `reviews/51-16-review.md`). SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`
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

**From 51-15 (As built):** a code save is refused unless the contract is declared literally (`outputs` in
`defineSetup`), so the setup proposal must declare them; save results carry `changed`; reuse
`promote_proven_actions` for "the actions it used are proven at that code" instead of a second rule, `report_url`
(the reports origin, D26) for the replay's report link, the grid helpers (`web/src/features/testing/grid.tsx`,
`grid-logic.ts`) for any list, and `FakeRunner(evidence=True)` (`tests/test_testing_api.py`) in tests that need report
files.

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

## As built (2026-11-05, genesis-dev)

**Task restated.** When the person ticks "Also make a data setup from this recording" in the Record dialog and gives
a setup name and an end state, the recording produces one data setup proposal besides the action proposals. The
setup calls the recorded actions in order and returns the ids the end state names. It is replayed on QA in place of
the loose action sequence, and it is reviewed and applied like any proposal: actions first, real keys and paths, and
the dependency rule. Without the tick, a recording behaves as before (one exception, Decision 6). Applicable rules:
ADR-011 (the trio on `segment` and `heal`), ADR-012 (the app reads only META; `graph.py` stays self-contained),
ADR-050 (status only through `LifecycleService`), ADR-067 (healing unchanged, works on the setup and its actions),
ADR-069 (skills provisioned per node), D8.6 (`unique()`), D13, D27 (literal `outputs`), D28 (actions proven in use),
D34. Lessons: L-011/L-083 (fixtures from real responses and a real scan), L-020, L-022, L-042, L-053 (app ↔ workflow
version skew), L-076 (setup written in the same `segment` turn), L-089, L-091, L-092, L-093, L-099.

### Commits

Base: genesis `521910b`, genesis-workflows `daf3612`. Local only, not pushed or tagged.

| Repo | Commit | What |
|---|---|---|
| genesis | `8dd7b6b` | m0028, recording `setup`, ProposalService (order, imports, dependency rule, proof), finalizer `uses`, web source, tests, contract fixtures |
| genesis | `f80dde1` | `web/static` for `8dd7b6b`. A rebuild followed, then `git status --short --untracked-files=all` was empty (checked in its own call). |
| genesis | `b4402ca` | review m-2 (stale reuse keeps the setup Draft), n-1 (version gate re-checked at Stop) |
| genesis | `4f6f283` | delta review dm-1 / dn-1 (any META error at Stop fails the capture with the reason) |
| genesis-workflows | `9970714` | action-capture 0.2.0, skill genesis-test-authoring 0.2.0, registry entries, tests, real scan-refs fixture |
| genesis-workflows | `f6b9397` | review m-1 (docstring + two graph tests without a request), n-2 (call order note) |
| project-tracker | this commit | this As built, `reviews/51-16-review.md`, the 51-10 contract table rows (review m-3) |

### Changed (genesis)

- **`db/migrations/m0028_capture_request.py`** (new): `kb_test_captures.request_json TEXT`, nullable. The `ADD COLUMN`
  is guarded by `PRAGMA table_info`, so a re-run is a no-op. `current_version` goes 27 → 28. The existing tests that
  pinned 27 now say 28, and the two m0027 tests migrate `MIGRATIONS[:27]`.
- **`kb/testexec_store.py`**: `CaptureStore.create(request=)`; `_dto` returns `request` (parsed) for both `get` and `list`.
- **`testexec/recording.py`**:
  - `setup_request()` checks the request. A missing name or end state, a wrong type, or more than 120 / 2000
    characters is refused with a 400 field error.
  - `start(setup=)` stores `{"setup": {name, end_state}}`. It refuses with a 409 when the installed action-capture
    `META.version` is below `SETUP_WORKFLOW_VERSION` (0.2.0), because an older workflow would silently ignore the
    input (L-053).
  - `_analyse` adds `setup_request` to the run's inputs only when the person asked for it. It re-checks the version,
    and any error reading the workflow's META then fails the capture with the reason (n-1, dm-1).
- **`testexec/proposals.py`**:
  - **Dependency rule.** `ProposalDependencyError` (409 `problems`). `dependency_problems` refuses an accepted setup
    whose used action is rejected; at apply it also refuses one that is undecided. A rejected `reuse` never blocks,
    because the library item exists either way. `decide` and `apply` both check the rule before anything is stored.
  - **Apply order.** Accepted proposals are sorted actions-before-setups, so the setup's `DS-` key is allocated after
    the actions' `ACT-` keys, all in one commit.
  - **Imports.** `rewrite_imports` writes each new action's real path into the setup's imports. `create_many` may cut a
    slug to 60 characters, which changes the path.
  - **Result.** A setup's result row carries `uses` as library keys. The apply result gains `proven`.
  - **Proof.** `_prove_used_actions` → `promote_proven_actions(app, commit, [("setup", DS-…)],
    execution_key="capture #N")` runs when the setup's replay passed at its code.
  - **Staleness guard.** `_stale_reuses` flags a reused action whose current `content_hash` differs from the hash
    the replay ran. That action is not proven, and the setup that ran it stays Draft (m-2).
- **`testexec/capture_finalizer.py`**: keeps `uses` when present.
- **`api/testing.py`**: `RecordingBody.setup: Optional[dict]`; `ProposalDependencyError` → 409.
- **web**:
  - `RecordDialog.tsx`: the checkbox, then **Setup name** and **End state** (both required; Start stays disabled until
    both are filled; the checkbox has `aria-describedby` to its hint).
  - `RecordingBar.tsx` and `CapturesPanel.tsx`: "+ data setup “name”".
  - `ProposalsReview.tsx`:
    - shows "uses P1, P2" and "outputs vendorId", and "replay passed in P3" on an action that ran inside the setup;
    - disables Accept on the setup while a used non-reuse action is rejected, with `aria-describedby` pointing at the
      reason.
  - `logic.ts`: `proposalUses`, `setupBlockedBy`, `contractOutputs`.
  - `types/testing.ts`: `SetupRequest`, `CaptureRequest`, `Capture.request`, `CaptureProposal.uses`/`replay`,
    `CaptureApplyResult.proven`, `items[].uses`.
  - `lib/api/testing.ts`: `startRecording(…, setup?)`.

### Changed (genesis-workflows)

- **`workflows/action-capture/graph.py`** 0.2.0:
  - **Input and prompts.** `setup_request_of` (a half request is an input error). The `segment` prompt asks for the
    setup only when there is a request; the `heal` prompt says that the replay ran the setup.
  - **Document rules.** `proposal_problems(setup_request=)` → `_setup_rules`: exactly one setup, `match: new`, named as
    asked, and `uses` = every action proposal in recorded order.
  - **Code rules.** `setup_code_problems` works on the workspace's own `lib/scan-refs.mjs` output. `scan_refs` runs it
    in the typecheck overlay, in its own process group through `ctx.extras['apwt'].run_bounded`. The rules: one
    `export default defineSetup`, the recording's role as a literal, no `inputs`, literal `outputs` equal to
    `contract.outputs` (D27), imports only of proposals or library items (not retired), actions only, `uses` = imports.
  - **Replay.** `replay_plan` runs the setup alone; its step result covers the setup and every action in `uses`
    (`via`). A reuse's replay carries the hash of the checkout's library file (`replay.code_sha256`), and its top-level
    `code_sha256` is null. `result.replay.mode` is `setup` or `sequence`.
  - `workflow.yaml` mirrors META; `registry.json` is updated.
- **`skills/genesis-test-authoring/SKILL.md`** 0.2.0 §5 "A data setup from the recording": the proposal shape, an
  example setup, the rules (recording's role, `export default`, `key: 'DS-NEW'`, every action in recorded order,
  outputs only and literal, `unique()`, navigate first), and the replay and heal behaviour. `skills-registry.json` is
  updated.
- **Fixture** `tests/fixtures/setup-scan/`: sample files plus `scan-refs-0.1.json`, the **real** output of
  `lib/scan-refs.mjs` (TypeScript 5.9.3, byte-identical to the Genesis template) over a good setup, one with inputs,
  dynamic outputs, a wrong role with a named export, and unknown imports.

### Tests

- **genesis**: full pytest **1745 passed** (1727 at base + 18); `ruff check genesis` clean. New tests in
  `test_testexec_recording.py`:
  - m0028: a fresh DB reaches v28 and a re-run is a no-op; a populated v27 database upgrades with every row unchanged.
  - Recording start/stop: the request is stored and passed to the run; a plain recording sends no `setup_request`.
  - Refusals: four half-request 400s; the 0.2.0 gate at Start; a downgrade at Stop; a META error at Stop (two cases).
  - The finalizer keeps `uses`.
  - Real workspace (git + tsc + scan-refs): the setup is created after its actions; a 72-character slug is cut to 60
    and the setup's import is rewritten to match; the reused Draft action is proven by the setup (`proven`, with
    evidence "capture #N"); a stale reuse keeps the setup and the reused action Draft.
  - The dependency rule: refused in decide and in apply, with nothing stored and no commit; a rejected reuse is
    allowed; rejecting the setup frees its action. Plus the pure dependency and import-rewrite helpers.

  `test_testexec_library.py`: action-capture's `scan_refs` + `setup_code_problems` read setups with the **real**
  scanner exactly as Genesis's `_check_code` does; both refuse a dynamic `outputs`. This test is skipped without the
  sibling genesis-workflows checkout (n-4). `test_testing_api.py`: the half-request 400, `request` on the recording,
  `setup_request` reaching the run, the dependency 409, `uses` and `proven` on apply. The fixtures `recording`,
  `capture`, `captures`, `capture-apply`, `capture-discard` and `verification-apply` were re-recorded with
  `GENESIS_WRITE_CONTRACT_FIXTURES=1`, and `capture-setup` and `error-dependency` are new. Fixtures whose only change
  was regenerated values were reverted.
- **genesis-workflows**: `validate_library` PASSED (17), `validate_skills` PASSED (4), pytest **387 passed** (363 at
  base + 24). The action-capture suite has 48 tests:
  - Document rules: refusals for no setup, two setups, a missing or unknown action in `uses`, wrong order, no `uses`,
    a wrong name, a wrong role, inputs.
  - Code rules on the real scan: inputs, dynamic outputs, a wrong role or named export, an unknown file or a setup
    import, a mismatch between `uses` and the imports, a retired import, outputs that differ from the contract.
  - Helpers: the half-request input error, `replay_plan`, the prompt only on request, `scan_refs` errors.
  - Graph runs:
    - a setup run where the first replay fails inside the setup's step and the heal patches P2 (an action the setup
      calls); the second replay passes; only the setup was replayed both times; P1/P2/P3 are passed with `via`; no
      password stored;
    - with a request, an unknown import refused by `v_segment` up to the gate;
    - without a request, a free setup read by the scanner and replayed in sequence, and one with inputs refused (m-1).

  `ruff check workflows/action-capture ci` (the CI scope) is clean. A repo-wide `ruff check .` shows 20 errors that
  were already there at base.
- **web**: tsc clean; eslint 0 errors / 20 warnings (the base count); vitest **707 passed (61 files)** (698 at base +
  9).
  - `library.test.tsx`: the option sends `setup` and is jest-axe clean when ticked; unticking it sends none; the bar
    shows "+ data setup"; the panel shows uses and outputs, Accept is disabled with a description and jest-axe clean; a
    rejected reuse does not block; the 409 is shown in place.
  - `logic.test.ts`: the three helpers, run on the recorded fixture.
  - `contract.test.ts`: checks for `capture-setup` and `error-dependency`, `request` / `proven` keys, and the
    `recording.request.setup` shape.
- **Bundle**: `f80dde1` is web/static only. A rebuild followed, then an empty `git status --short --untracked-files=all`
  in its own call. The reviewer's out-of-tree build was identical. The fixes after `f80dde1` touch no web file.

### Review

`reviews/51-16-review.md`. First pass **SHIP** (no blocker or major). It agreed with decisions (a)–(f) below and raised
m-1 to m-3 and n-1 to n-4. Fixed:

- m-1: the docstring now states the change, with two graph tests;
- m-2: a stale reuse keeps the setup Draft;
- m-3: the 51-10 table rows for POST `…/recordings` and decisions / apply;
- n-1: the gate is re-checked at Stop;
- n-2: the skill and docstring say the call order is proven by the replay.

n-3 (the UI does not prevent rejecting a used action once the setup is accepted; the server's 409 shows in place)
and n-4 (the scanner parity test skips without the sibling checkout; the workflow repo's real-scan fixture covers the
other side) are accepted as they are. The delta re-review of `b4402ca` / `f6b9397` was **SHIP**, with dm-1 (a compat or
YAML error at the new Stop check left the capture "recording") and dn-1 (wording). Both were fixed in `4f6f283`; its
test fails without the fix. The dev note in the report records this.

### Decisions / deviations

No ADR deviation.

1. **(a) Version gate.** A setup request needs action-capture ≥ 0.2.0. It is checked at Start (409) and again at Stop
   (the capture fails with the reason). An older workflow's schema accepts the extra input and would ignore it.
2. **(b) Staleness guard.** A reused action is proven by the setup only while its library code is still the code the
   replay ran. Otherwise neither it nor the setup becomes Ready at apply. This goes beyond D20's own-hash rule for the
   setup (m-2), because the setup never passed with the code it now calls.
3. **(c)** A rejected `reuse` never blocks the setup.
4. **(d) Setup-first replay.** With a requested setup, the replay runs **only** the setup. New and updated actions take
   its step result at their own hash, so they are Ready on apply when it passed (D28's recording clause). Reused
   actions are proven through `promote_proven_actions`.
5. **(e)** The requested setup's `uses` must list **every** action proposal in recorded order: an action left out of
   it would never be replayed.
6. **(f) Scanner reading.** `v_segment` reads every proposed new or updated setup with the workspace's
   `lib/scan-refs.mjs` (needs `node`; a workspace without it refuses the setup). This includes a free setup in a
   recording with no request, so the only change without a request is that such a setup meets Genesis's save rules
   in `v_segment` instead of at apply.
7. The setup's call order in the code is not read; the replay proves it (n-2).
8. The request text is bounded (name ≤ 120, end state ≤ 2000 characters) because it goes into the agent prompt and
   the run state.

### Lesson candidates

- **A guard added late in a flow inherits the error handling of the code that used to fail there.** Moving a check
  ahead of a `try/except` that "must not leave the capture recording" let a compat or YAML error escape (delta dm-1).
  When you add a read in front of a protected call, give it the same protection.
- **Two readers of one contract must be the same reader.** v_segment uses the workspace's own scanner, not a second
  parser, so the workflow and Genesis's save check cannot disagree; a cross-repo test with the real scanner proves it
  (L-083 for code).
- L-089 held: every build, commit and verifying `git status` in this session ran as separate calls.

### Code-map changes

- `genesis/db/migrations/m0028_capture_request.py` (new; DB v28).
- `genesis/testexec/recording.py`: `setup_request`, `SETUP_WORKFLOW_VERSION`, `_version`, `start(setup=)`.
- `genesis/testexec/proposals.py`: `ProposalDependencyError`, `setup_uses`, `dependency_problems`, `rewrite_imports`,
  `_stale_reuses`, `_prove_used_actions`; the apply result's `proven`.
- `genesis/kb/testexec_store.py`: `CaptureStore.create(request=)`, the capture's `request`.
- `genesis/web/src/features/testing/logic.ts`: `proposalUses`, `setupBlockedBy`, `contractOutputs`.
  `types/testing.ts`: `SetupRequest`, `CaptureRequest`.
- genesis-workflows `action-capture` 0.2.0: `setup_request_of`, `setup_uses`, `requested_setup`, `_setup_rules`,
  `setup_code_problems`, `scan_refs`, `_bounded`, `replay_plan`. Skill `genesis-test-authoring` 0.2.0.

### For 51-17 and the 51-12 re-run

- **51-17:**
  - m0028 `request_json` is in place; store the composer's request as `{"compose": …}` beside `setup`.
    `CaptureStore.create(request=)` and `Capture.request` already carry it.
  - Reuse `dependency_problems` and `setup_uses`: a composed setup's `uses` names library keys, not proposal ids, so
    extend the rule rather than fork it.
  - Reuse action-capture's `setup_code_problems` / `scan_refs` pattern for the composer's validator: same scanner,
    same rules.
  - D36's `roles: [...]` will need `setup_code_problems` to accept the extra literal and stop requiring a single role.
  - The `proven` path (`promote_proven_actions` from a passing setup) is the D28 route for the composed setup too.
- **51-12 re-run step 26:**
  - Install action-capture 0.2.0 (`genesis install`) and skill genesis-test-authoring 0.2.0 first; Record refuses a
    setup request otherwise. Then `genesis db upgrade` (back up `genesis.db` first: 27 → 28), and restart `serve` with
    no run active (L-061).
  - Expect, live:
    - one segment turn that also writes `setups/<slug>.ts`;
    - replay labels showing only `P<n> <setup name>`;
    - the panel showing "uses …", "replay passed in P<n>" and the outputs;
    - on Accept all, one commit with the actions' `ACT-` keys before the setup's `DS-` key;
    - the setup Ready, with the reused Draft actions Ready through "capture #N".
  - Not verified here: a real Kiro `segment` turn and a QA replay of a setup.
