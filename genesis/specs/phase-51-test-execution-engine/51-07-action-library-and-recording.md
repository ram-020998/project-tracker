# 51-07 — Action Library, Record workflow and `action-capture`

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (backend), **genesis-workflows** (`action-capture` v0.1.0 +
> skill `genesis-test-authoring`), **playwright-appian** (0.3.0 from 51-03 is the base; fix recorder gaps in §4 item 4
> only if they block acceptance). Parent:
> `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D2, D3, D5.6, D13, D16, D20; F1, F5.

## 1. Goal

Manage reusable actions and data setups as code with contracts, where-used and history; let a person record a flow as
one role and get reviewed action proposals back.

## 2. The workspace helper `lib/` (TypeScript, written by Genesis, versioned with the template)

**Fixed by 51-06** (As built 1; `genesis/genesis/testexec/generator.py` `_support_ts`/`_auth_ts`/`_setup_ts`/
`_scenario_ts`). The generated specs import only `loginAs` from `lib/`. `CaseContext`, `SetupData`, `setupData`,
`saveSetupData`, `RolePages` and `authFile` live in the **generated** `suites/_support.ts`, which `lib/` and the
scripts import from (never edited by hand or by an agent). This section must match that file:

- `CaseContext = { page: Page, data: SetupData, as(role): Promise<Page> }` (from `suites/_support`). `as(role)` returns
  that role's page, opening a context with the role's saved login when needed.
- `defineAction({ key, name, area, role?, inputs, outputs }, fn)` → a function `(ctx: CaseContext, input) =>
  Promise<output>`. Inside, `fn` receives `{ ...ctx, appian: createAppianPage(ctx.page) }`; inputs/outputs are typed
  objects whose shape equals `contract_json`. Actions are imported by name (`export const createEvaluation =
  defineAction(…)`), never run directly by the generator.
- `defineSetup({ key, name, role, outputs }, fn)` → a function `(ctx: CaseContext) => Promise<outputs>`; `setups/*.ts`
  **`export default`** it. The generator saves its return value as the instance's data. The role the generator uses is
  `kb_test_setups.role_key`, not the `role` in the file: the library service keeps them equal on every save and
  refuses a save where they differ.
- `defineCase('<TC-key>', { role: '<role>' }, fn)` → a function `(ctx: CaseContext) => Promise<void>`; `cases/*.ts`
  **`export default`** it. `fn` is the When + Then of one case; it reads setup data through `ctx.data` and uses
  `expect` from `@playwright/test`. The generator reads the role from the file's text: write `role` **first** in the
  options, as a plain string literal, and put no functions in the options object (the reader stops at the first
  `async`, `function` or `=>`). A role written any other way, or missing, makes every scenario using the case **not
  automated**; the save path checks this and shows it as a warning.
- `loginAs(page, role)` — `login(page, { username, password })` from `playwright-appian` with
  `GENESIS_TEST_USER_<ROLE>`/`GENESIS_TEST_PASSWORD_<ROLE>` (role upper-cased, `-` → `_`). It does **not** navigate:
  the generated auth setup opens `SITE_URL` first. Keep its signature and these semantics; `lib/index.ts` today is a
  51-05 placeholder that this sub-spec replaces.
- `unique(prefix)` for per-run values (D8.6). `setupData` is **not** in `lib/`.
- `lib/scan-refs.mjs` — uses the workspace's TypeScript compiler API to list, for each `actions/`, `setups/`, `cases/`
  file, the action/setup keys it imports; output JSON consumed by Python to rebuild `kb_test_refs` (51-04 §2.2).
- Code stays label-based (`playwright-appian` D-04); raw locators only where its snapshot says no component covers the
  element, with a `// TODO` the report lists.

## 3. `TestLibraryService` (`genesis/genesis/testexec/library_service.py`)

Over `TestWorkspace` (51-05 §3) and `TestLibraryStore` (51-04 §3):
- **Create** (template or proposal), **save** (D16.4: write → typecheck → refuse with errors, or commit + update hash +
  rebuild refs for that file), **contract change** (D16.5: optional input added = allowed; removed/renamed input or
  output or a new required input while `where_used` is non-empty → refused with "Save as new action" offered),
  **retire/restore/delete** (D16.1 via `LifecycleService`; delete removes the file in a commit), **history** (`git log`
  for the path), **revert** (a new commit, same typecheck), **outside edits** (D16.7: `status()` finds hash mismatches;
  **Adopt** = typecheck + commit + catalog update; un-adopted changes are never executed because executions export a
  commit), **run dependents** (an ad-hoc execution of every automated scenario whose steps use the item, via
  `kb_test_refs` transitively).
- **Approval reset (D20, the 51-04 open point):** save, revert and adopt of a **Ready** item's code also move it to
  Draft through a new edge `(READY, "changed") → DRAFT` via `LifecycleService` (built in `LIBRARY_TRANSITIONS`, As built
  1; audited with action, actor and time; the commit is found from git history, D20 as amended), in the same
  workspace-locked operation as the commit. **Replay** on the item page runs the item's
  replay on QA (as for proposals, §5) and, on a pass at the current hash, approves it back to Ready. Status never gates
  executions or authoring. A metadata-only edit keeps the status.
- Every write path is serialized per workspace and runs off the event loop (L-026): use `TestWorkspace`'s existing
  `path_lock(root)`, which 51-06's `write_generated` commits also take, so a library save and an execution's
  regenerate-and-commit never interleave.
- **Save checks for the generator's contract (§2, 51-06 As built 1):** a case script whose `defineCase` role is not a
  readable literal saves but warns "scenarios using this case will not run"; a setup whose `defineSetup` role differs
  from `kb_test_setups.role_key` is refused.

## 4. Record workflow (D13)

`RecordingService` (`genesis/genesis/testexec/recording.py`, app process; human-driven, so not a workflow run):
1. `start(app_uuid, role_key, intent, start_path?)` → `readiness` → the **settled mechanism** (51-03 S8/S9, D-114 in
   `playwright-appian` 0.3.0; the recorder never holds the password):
   1. `apwt -s rec-<capture-id> open <QA site> --login --browser chromium --allow-host <QA host> --artifacts <a temp
      folder outside the workspace>` (credentials only in
      this subprocess's environment, 51-05 §4) → `apwt -s rec-<capture-id> state-save --file <ws>/.auth/<capture-id>.json`
      → `apwt -s rec-<capture-id> close`;
   2. `apwt record start --detach --browser chromium --state <ws>/.auth/<capture-id>.json --url <start page>
      --out <ws>/captures/<capture-id>/trace.json` (headed; returns `SESSION`, `TRACE_PATH`, `PID`);
   3. delete the state file and the login session's temp artifacts folder as soon as `record start` returned (the
      browser context holds the login; the login's own artifacts never reach the workspace's `output/` scratch folder).
   Creates a `kb_test_captures` row (`recording`). (`record start --cdp` cannot record signed in: the recorder opens a
   fresh, cookie-less context — 51-03 S8. The two halves were proven separately in the spike; 51-12 runs this exact
   sequence live.)
2. `stop(capture_id)` (the UI's Stop button → `apwt record stop --session <id> --json`) or the browser closing (`apwt
   record list` shows it stopped) → trace path stored under `captures/<capture-id>/` in the workspace (committed with
   the proposals' apply; the raw trace is kept, D13.7; the trace carries `start_signed_in: true`, so `generate` writes
   `await login(page)`) → starts the `action-capture` run (`analysing`).
3. One recording at a time per machine. The recorder daemon (the `PID` that `record start --detach` returns) is
   recorded with `procs.record_group` in a pid folder outside the workspace (`~/.genesis/testing/recordings/.pids`;
   markers: the workspace and the browsers folder), forgotten on a clean stop, and reaped at startup and on a stale
   recording (51-05 As built 7 and lesson candidate 1: a detached child is not in the caller's group).
   **Carried from 51-05 (review nit 12), checked live once** (a local test server is enough): during a running
   recording, reap the pid folder and show with `ps` that neither the recorder nor its Chromium (which runs in its own
   group) is left.
4. **Known recorder gaps** (51-03 findings 4–5, `playwright-appian` follow-ups): a recorded multi-select whose label the
   recorder cannot resolve becomes `// TODO: no label for multi_dropdown`; `wait --for "grid(…)"` in an agent spec
   becomes a `// TODO` (grids have no `isVisible()`). The `action-capture` agent resolves such TODOs from the snapshot
   context where it can; fix them in `playwright-appian` during this sub-spec if they block 51-12's live acceptance,
   else list them in `specs/backlog/phase-51-follow-ups.md`.

## 5. `action-capture` workflow (genesis-workflows `workflows/action-capture/`)

Inputs: `capture_id`, `app_uuid`, `role_key`, `intent`, `trace_path`, `library_path` (a read-only JSON snapshot of the
catalog: keys, names, contracts, paths) and `checkout_dir` (an export of the workspace HEAD). Nodes (agent nodes carry
the ADR-011 trio; healing tier ADR-067 on the replay check):
- `generate` (program) — `apwt generate <trace>` → the flat spec + `analyze` plan (deterministic, D-02).
- `segment` (agent, an ordinary `kiro_node` per D3c; no browser needed; skills `genesis-test-authoring` + the CLI
  `playwright-appian` skill provisioned per ADR-069; works on files inside the run folder) — writes
  `proposals.json`
  `[{kind: action|setup, match: reuse|update|new, key?, name, area, role, contract, path, code, reason}]` and the code
  files under `<run>/proposed/`. Rules in the skill: split at business boundaries (dialog opened/closed, Create/Save,
  navigation), literals → inputs, created ids → outputs, prefer reusing an existing action, label-only code.
- `v_segment` (validator, program) — JSON schema; every proposal's file typechecks inside a copy of `checkout_dir`;
  every `reuse` names an existing key; no proposal edits `lib/`.
- `replay` (program) — composes the proposals in recorded order into a temporary spec and runs it on QA as the role
  (51-06 runner, kind `adhoc`, not shown in Executions); result per proposal.
- `heal` (agent, ADR-067: patch in place ≤ 1, restart ≤ 1) on a failing replay → re-run `replay`.
- `present` — `result.json` `{status, proposals, replay}`.

`CaptureFinalizer` (app process, finalizer pattern) stores the proposals on the capture row (`ready`).

## 6. Applying proposals (D13.6)

Per item accept/reject or Accept all (`kb_test_captures.decisions_json`, CAS on `row_version`, L-091): accepted `new` →
create the item (key allocated) from its code; `update` → a save of the existing item (same contract rules, D16.5);
`reuse` → nothing to write. All accepted writes land in **one commit** with the capture id in the message, together
with the raw trace. Items whose replay passed at that code become **Ready**, others **Draft** (D16.1).

## 7. Skill `genesis-test-authoring` (genesis-workflows `skills/`)

Start from the spike's draft, `genesis/scripts/spikes/51-03/skills/genesis-test-authoring/SKILL.md` (51-03 S11 proved
an agent reads and follows it).

The workspace conventions an agent must follow (both here and in 51-09): folder layout, the `lib/` API and the
generated-spec contract of §2 (`export default` of `defineCase`/`defineSetup`, the role literal first in the options,
`CaseContext` from `suites/_support`, never edit `suites/`), contract rules,
label-only code, unique values, how to read the catalog snapshot, how to write proposals. The `playwright-appian` CLI skill is provisioned from the workspace's installed package
(`node_modules/playwright-appian/skills/playwright-appian`, exact version) by extending the `skill_source` resolver for
that id (one home for that skill, ADR-069; D3c). `genesis-test-authoring` adds the Genesis rules on top (use only the
given sessions; no `open`/`login`/`attach`/`state-save`; no other host; never print environment variables).

## 8. Tests

Save/typecheck/commit, refused breaking contract, retire refused with names, delete only if never referenced, revert,
outside edit → adopt, the §3 generator-contract checks (unreadable case role warns, setup role mismatch refused), a
`lib/` + template case + template setup that the 51-06 generator turns into a scenario that passes under the real
Playwright against a local page, a code save/revert/adopt of a Ready item demotes it to Draft through the audited `changed` edge
while a metadata-only edit does not, Replay pass re-approves at the current hash and a fail leaves it Draft (D20), refs rebuild from `scan-refs` output; recording start/stop with `apwt` stubbed (real `--json`
fixtures); `action-capture` node tests with a recorded trace fixture from the sandbox repo
(`/Users/ramaswamy.u/Documents/test/playwright-appian-test/output/traces/create-evaluation.json`), validator rejects bad
proposals, apply in one commit, Ready vs Draft; `validate_library` + `validate_skills` gates.

## Context manifest

```toml
areas    = ["workflows-library", "core-engine"]
adrs     = ["ADR-011", "ADR-012", "ADR-018", "ADR-050", "ADR-067", "ADR-069"]
lessons  = ["L-021", "L-024", "L-026", "L-041", "L-042", "L-064", "L-076", "L-083", "L-091", "L-092"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/genesis/testexec/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/skills/genesis-test-authoring/**", "genesis-workflows/skills-registry.json"]
upstream = ["51-03", "51-04", "51-05", "51-06"]
```

## As built (2026-11-03, genesis-dev)

**Task restated.** Make actions and data setups code with contracts, where-used and history, and let a person record a
flow as one role and get reviewed proposals back. In genesis: the real `lib/` (and `lib/scan-refs.mjs`) to the 51-06
generated-spec contract; `TestLibraryService` (save → checks → typecheck → one commit → catalog, contract rules, the
D20 approval reset and Replay, retire / restore / delete, history, revert, adopt, run dependents, the §3
generator-contract checks); `RecordingService` with the settled 0.3.0 sequence; the `CaptureFinalizer`; proposal
apply. In genesis-workflows: `action-capture` 0.1.0 and the `genesis-test-authoring` skill. No route (51-10), no web
change, no migration. playwright-appian unchanged: the recorder gaps did not block, so they went to the backlog.

**Applicable rules.** ADR-010/018 (pointers in state, bulk in the run folder), ADR-011 (the trio on `segment` and
`heal`), ADR-012 (the app never imports `graph.py`; Playwright and apwt via `ctx.extras['apwt']`), ADR-050 (status only
through `LifecycleService`), ADR-067 (the healing tier on the replay), ADR-069 (skills provisioned per node), ADR-021
via D22/ADR-082 (no `pre_mutation` gate for QA writes). Lessons L-021, L-024, L-026, L-041, L-042, L-064, L-076,
L-083, L-091, L-092, L-094 (the new edge), L-097 (the startup sweep), L-048 (package data).

### Commits

- **genesis** (base `ee1b77c`, local, not pushed or tagged): `bb577c4` feat(testexec,51-07) — the whole change incl.
  every review fix; a separate `git status --untracked-files=all` afterwards was empty (L-056/L-089).
- **genesis-workflows** (base `5a24d17`, local): `966c022` feat(action-capture,51-07); `git status` afterwards empty.
- **playwright-appian:** no change.
- **project-tracker:** this As built, `reviews/51-07-review.md`, `specs/backlog/phase-51-follow-ups.md` items 9–14.

### Changed (genesis)

- `testexec/templates/lib/index.ts` (replaces the 51-05 placeholder): `defineAction(meta, fn)` → `(ctx, input) =>
  Promise<output>` with `.meta`; `defineSetup(meta, fn)` and `defineCase(key, {role}, fn)` for `export default`;
  every body gets `{page, data, as, appian: createAppianPage(page)}`; `loginAs(page, role)` with
  `GENESIS_TEST_USER_/PASSWORD_<ROLE>` (no navigation); `unique(prefix)`; `CaseContext`/`SetupData` re-exported from
  the generated `suites/_support`.
- `testexec/templates/lib/scan-refs.mjs` (new): the workspace's TypeScript compiler API → one JSON document
  `{version, typescript, files: [{path, kind, defines: [{fn, export, key, name, area, role, inputs, outputs,
  dynamic}], imports: [actions/setups paths], refs: [{path, key, fn}], errors}]}`.
- `testexec/workspace.py`: a new workspace gets `lib/*` and `suites/_support.ts` (`lib_files()`, so an empty one
  typechecks); `sync_lib()`; `change(files, message, before_commit=, after_commit=, after_commit_on_noop=)` — write or
  delete several files → caller checks → `tsc` → ONE commit of exactly those paths → the catalog write, all under the
  existing `path_lock`; a refusal restores the files, a failing `after_commit` undoes the commit; a to-delete path that
  is neither present nor tracked is not staged (review n1); `scan_refs()`.
- `testexec/generator.py`: `support_ts()` public (was `_support_ts`).
- `testexec/runner.py`: `run(config=)` / `argv(config=)` → `--config` (a replay's own config); additive.
- `testexec/replay.py` (new): `replay_spec_ts(steps, role)` (open SITE_URL → `loginAs` → one `test.step` per item; a
  setup's return value is merged into `ctx.data`), `replay_config_ts()`, `replay_outcome(report, labels)`.
- `testexec/library_service.py` (new) — `TestLibraryService`:
  - `create` / `create_many` (template or given code; `ACT-NEW` / `DS-NEW` replaced by the allocated key; one commit
    for many, for proposal apply), `save` (code, or metadata only), `revert`, `adopt` (also of a change committed
    outside Genesis), `save_as_new`, `status` (`changed` / `missing` / `untracked`), `history`, `transition`
    (retire / restore / approve; `changed` refused by hand), `delete` (never used only; the file removed in a commit).
  - `_check_code` (scan-refs): exactly one define of the kind, the item's key, an action exported by name, a setup or
    case as `export default`, the setup's role = `role_key` (else refused), every `actions/`/`setups/` import a
    non-retired catalog item; a case role that the generator cannot read saves with `UNREADABLE_ROLE_WARNING` (the
    generator's own `case_role_unreadable` / `case_script_role`).
  - `breaking_changes` (D16.5) → `BreakingContractError` (with `where_used`, `save_as_new`) while used.
  - `_apply_save`: hash, contract (from the code's literal metadata, else the form's), refs, and the D20 demotion
    `(ready, changed) → draft` unless the new code already passed a replay (review m2); compensates its own writes.
  - `create_many` puts back, inside the lock, only the update items it wrote when a later step fails (re-review R-M1)
    and removes the rows it created (`TestLibraryStore.remove_uncommitted`).
  - `dependent_scenarios` (kb_test_refs transitively + scenarios naming a setup), `run_dependents` (one `adhoc`
    execution).
  - `replay(kind, id, inputs=)`: export HEAD to `<artifacts>/library-replays/<app>/<key>-<stamp>/checkout`, the replay
    spec + config, the 51-06 runner as the item's role → `record_replay` at the replayed code's hash (with the inputs,
    offered again next time) → `approve` when passed at the current hash. `reap_stale_replays()` at startup.
  - `save_case_script(case_id, code|template)` → `kb_test_case_scripts` + the case's refs.
  - Templates: `action_template`, `setup_template`, `case_template` (setups and a first case navigate: decision 5).
- `testexec/recording.py` (new) — `RecordingService`: `start` (readiness + the `genesis-test-authoring` skill
  installed; one recording per machine; open + sign in on the QA site with `--artifacts` in a temp folder → state-save
  to `<ws>/.auth/rec-<id>.json` → close → `record start --detach --browser <b> --state … --url <start page> --out
  <ws>/captures/<id>/trace.json` → the state file and the temp folder deleted in a `finally`; the recorder's pid via
  `procs.record_group` in `~/.genesis/testing/recordings/.pids`, markers the workspace and the browsers folder),
  `stop` (record stop → reap → no trace / 0 actions → `failed`; else `action-capture` via `RunManager.start(prepare=)`
  exporting HEAD to `<run>/checkout`, copying the trace and writing `library.json`), `refresh` (STOPPED / FAILED /
  STALE or gone = Stop), `discard`, `library_snapshot`, `reap_stale` (startup, under the run-owner lock; also deletes
  an interrupted capture's saved login, review n2). One `RLock` covers start / stop / refresh / discard (review M1).
- `testexec/capture_finalizer.py` (new) — `CaptureFinalizer`: live `run.final` + startup + on-read; bound run;
  CAS `analysing → ready | failed`; copies each proposal's code (≤ 200 KB) and its replayed sha256 into
  `proposals_json`; a result not `ready` fails the capture with its reason.
- `testexec/proposals.py` (new) — `ProposalService`: `decide` (CAS on `row_version`), `apply` (accept per item or
  all; new + update via `create_many` in ONE commit with `captures/<id>/trace.json`; Ready only when the replay passed
  and `sha256(code)` equals the replayed hash; reuse writes nothing; nothing accepted → a trace-only commit).
- `integrations/apwt/client.py`: `record_start`, `record_stop`, `record_list`, `generate`, `track_recorder`,
  `forget_recorder`, `ApwtRecording`. `factory.py`: `for_recording`.
- `kb/testexec_store.py`: `record_replay(inputs=)`, `restore_replay`, `remove_uncommitted`,
  `CaptureStore.set_trace_path`, `CaptureStore.set_decisions` (CAS, ready only).
- `domain/transitions.py`: `LIBRARY_TRANSITIONS` (= `TEST_TRANSITIONS` + `(READY, "changed") → DRAFT`), the `changed`
  precondition and reason, `LIBRARY_FILTERING_PRECONDITIONS`; `lifecycle.py` wires them into
  `build_library_lifecycle` only; exported.
- `runtime/context.py`: `_skill_source("playwright-appian")` → `<run>/checkout/node_modules/playwright-appian/skills/
  playwright-appian` only (`APWT_SKILL_ID`).
- `api/app.py`: `TestLibraryService`, `RecordingService`, `ProposalService`, `CaptureFinalizer` on `app.state`; the
  finalizer attached; the startup sweep (capture reconcile; recorder and replay reap under the run-owner lock).
- `scripts/spikes/51-07/live_library.py`, `live_recording.py`, `evidence/{library,recording,replay-report-1.59.1}.json`.

### Changed (genesis-workflows)

- `workflows/action-capture/` (new, 0.1.0): `generate` (raw async: `apwt generate` + `analyze --json`) → `segment`
  (`kiro_node`, skills `genesis-test-authoring` + `playwright-appian`, 900 s) → `v_segment` (raw async validator:
  `proposal_problems` + `tsc` over an overlay copy) → `attach_healing(verify=replay, heal, reassemble,
  restart_target=segment)` → `present`; `escalate` → `present`; `present` marks the result failed when `v_segment`
  never passed. `replay` composes the proposals into one spec and runs it with the 51-06 runner (`--config`). META ↔
  yaml parity, `graph:` topology, `registry.json` entry.
- `skills/genesis-test-authoring/SKILL.md` (from the 51-03 draft): layout, the lib/ API with examples, the
  generated-spec contract, contracts, label-only code, setups and first cases navigate, the proposals format, the
  session rules. `skills-registry.json` entry.

### Tests

- genesis `tests/test_testexec_library.py` (25, real git + `tsc` + scan-refs from one `npm ci --prefer-offline` per
  session; skips without node/npm): lib/ in a new workspace + `sync_lib`; scan-refs output and the refs rebuild (and
  the recorded `scan-refs-0.1.json`); create/save/commit; type error refused and restored; code checks; breaking
  contract refused while used, optional input allowed, save as new; unreadable case role warns; setup role mismatch
  refused; retire refused naming users, delete only never-used; revert; outside edit and outside commit → adopt; D20
  demotion on save / revert / adopt via the audited `changed`, metadata-only keeps Ready, `changed` not offered;
  Replay fail → Draft, pass → Ready at the current hash; `TEST_TRANSITIONS` unchanged (L-094); dependents
  transitively + `run_dependents`; **lib/ + a case + a setup → the 51-06 generator → real @playwright/test 1.59.1 +
  Chromium on a local page: 3 expected, 0 unexpected** (skips without Chromium 1217); review: the undo path (M2), a
  refused multi-item apply (m1), a concurrent save (R-M1), adopt after a green replay (m2), delete of a gone file
  (n1), parity with the workflow's replay copy (m4).
- genesis `tests/test_testexec_recording.py` (15, apwt stubbed with the real 0.3.0 outputs in
  `tests/fixtures/apwt/apwt-0.3.0-record.json`, a real detached stand-in recorder): the sequence, credentials only on
  the login, state file and temp folder gone, recorder recorded; readiness, skill and one-at-a-time refusals; stop →
  the run with export + trace + snapshot, recorder gone; nothing recorded → failed; refresh on a closed window;
  reap_stale; discard; the finalizer (ready with code, idempotent, failed run, other workflow ignored, a not-ready
  result fails); apply in one commit with the trace, Ready vs Draft, reject + reuse → trace only, stale decisions
  refused, update through the save rules; the client's record calls; the skill resolver; the stop/refresh race (M1);
  a crash's saved login removed (n2).
- genesis-workflows `workflows/action-capture/tests/` (21): the validator's rules (12 refusals), the replay spec,
  outcome and verdict on real / derived reports, heal patches, parity + the trio, parity with
  `genesis.testexec.replay` (R-n2), the whole graph with the real `ctx.extras['apwt']`, stub turns, stub apwt / npx
  (replay fails once → heal → passes; both skills provisioned; no password in state, checkpoints, events or files),
  escalation after 3 refused segmentations.
- Gates (before the re-review): genesis ruff clean, pytest **1609 passed** (1570 + 39); genesis-workflows pytest
  **343 passed**, validate_library PASSED (16), validate_skills PASSED (4). **Final (after every fix, the third
  pass re-ran them):** genesis ruff clean, pytest **1610 passed** (1570 at 51-06 + 40); genesis-workflows pytest
  **344 passed** (323 + 21), validate_library PASSED (16), validate_skills PASSED (4); web unchanged.
- Package data: the wheel lists `templates/lib/index.ts` and `scan-refs.mjs` (L-048).
- **Live (this machine, local pages, no QA):** `evidence/library.json` — the generator scenario passed under real
  Playwright; Replay → Ready; a code save → Draft (`changed` audited); Replay → Ready; no password in any report.
  `evidence/recording.json` — the full 0.3.0 sequence through `RecordingService` and the real `ApwtClient` (headed
  Chromium 1217): during a running recording, `procs.reap` of the recordings pid folder killed the recorder's group
  and `ps` 2 s later showed neither the recorder nor any Chromium process (51-05 nit 12). The reap signalled only the
  recorder's group; Chromium (its own group) exited with its parent (review n4). The saved login and the login's temp
  artifacts were gone right after `record start`; the trace says `start_signed_in: true`; no password in the
  workspace. **Not run:** a signed-in recording on the real QA site, and `action-capture` with a real Kiro agent
  (51-12).

### Review

`reviews/51-07-review.md`. First pass **NEEDS_CHANGES**: M1 (stop/refresh/discard check-then-act: two runs), M2 (no
test of the `change()` undo), m1 (a multi-item apply not atomic on the catalog), m2 (adopt after a green replay
refused), m3 (D20 audit reason), m4 (two replay copies, no parity test), m5 (item replay guards), n1–n4. Fixed: M1,
M2, m1, m2, m4, n1, n2; m3 and m5 → backlog 13 and 12; n3, n4 noted here. Re-review **NEEDS_CHANGES**: R-M1 (the m1
fix restored from a snapshot taken outside the lock and could overwrite a concurrent save) — fixed (snapshots and
restore inside `after_commit`, only items this apply wrote, `restore_replay` verbatim, R-n1) with the concurrent-save
test; R-n2 (parity test on the workflow side too) and R-n3 (the race test's gate) fixed; R-n4 recorded below.
**Third pass: SHIP.** Its nits: T-n1 (a metadata save inside a failing apply's window is overwritten by the restore)
→ decision 7, for 51-10; T-n2 (this count, a `finally` in the parity test) fixed before the commit. Release note from
the reviewer: genesis-workflows' tests import Phase 51 genesis modules, so 51-13 must move its pins to the Phase 51
genesis tag (L-057).

### Decisions / deviations

No ADR deviation. Recorded choices, **bold = affects 51-08..51-11**:
1. **`LIBRARY_TRANSITIONS`, not a new `TEST_TRANSITIONS` edge** (spec wording): test cases and scenarios share
   `TEST_TRANSITIONS` and the Phase 49 API offers and accepts its actions (L-094). `changed` is program-only and never
   in `allowed()`.
2. **Deviation from D20 (user decision): the audit row does not name the commit.** `lifecycle_transitions` (m0013) has
   no reason column. The row carries `changed`, the actor and the time; the commit message names the item. Backlog
   item 13 (an additive `detail` column + `transition(detail=)`). **The user should confirm this or ask for the
   migration.**
3. **The item-page Replay runs in the app process** (blocking, tens of seconds; 51-10 must call it off the loop) and
   writes no `TE-` row; the capture replay writes none either ("adhoc, not shown in Executions"). **51-10:** one replay
   per item, cancel and retention first (backlog 12).
4. Replay "at that code": a new proposal is replayed with its `ACT-NEW` literal; apply records the replay at the
   committed hash (only the key literal differs), and only when `sha256(code)` equals the replayed hash.
5. **Generated specs start on a blank page:** a data setup and a scenario's first case navigate themselves (found
   live). Templates and the skill say so; **51-09's verification agent must write cases that way.**
6. Proposal code is stored inline in `proposals_json` (run folders are pruned).
7. **Contracts:** the stored contract is the code's literal `inputs` / `outputs` when present, else the form's; a
   metadata-only contract edit keeps the status (D20) but still obeys D16.5. A path never changes after create (area
   and name are metadata). **51-10 forms:** `save(fields=)` accepts `name`, `area`, `role_key`, `contract`; a setup's
   role changes only with its code. A metadata save does not take the workspace lock: **51-10 must always pass the
   page's `expected_row_version`**, so a save landing inside a failing apply loses its CAS instead of being
   overwritten by the apply's restore (third pass T-n1).
8. **Recording needs the `genesis-test-authoring` skill installed** (Skills catalog) — `start` refuses without it, as
   `segment` would fail fast (ADR-069). **51-11/51-13:** readiness and onboarding should offer the install; also check
   that `action-capture` is installed (a missing workflow fails the capture, it does not 500).
9. The saved login is `<ws>/.auth/rec-<id>.json` (spec: `<capture-id>.json`; apwt session names must start with a
   letter or digit and Genesis uses `rec-<id>` for both) — review n3.
10. `RecordingService.start` signs in on the QA **site** and records from the start page (`--url`), as §4.1–2.
11. A refused apply, or a refused create of an item that referenced existing ones, leaves `ever_referenced` set on
    those targets (re-review R-n4, pre-existing in the single-create path): such an item can then only be retired.
12. Library tests run the real `tsc` (~90 s for the file); they skip on a machine without node/npm.

### Lesson candidates

- **A compensation must undo only its own writes, inside the lock that serialized them.** Restoring from a snapshot
  taken before the lock overwrote a concurrent save and re-approved code that was never replayed (51-07 re-review
  R-M1; extends L-091).
- **Playwright's generated specs start on `about:blank`:** `storageState` signs the context in, it does not navigate.
  A setup or first step that assumes the site is open fails with a 15 s locator timeout, not a navigation error.
- **A strict `tsc` in the save path catches what a stubbed typecheck hides:** half the first test edits used
  component methods that do not exist (`Link.focus`, `click({force})`), only the real compiler said so (L-083 for
  code).

### Code-map changes

For bible/03 in the "Phase 51" block: `testexec/templates/lib/{index.ts, scan-refs.mjs}`; `workspace.change` /
`sync_lib` / `scan_refs` / `lib_files`; `generator.support_ts`; `runner.run(config=)`; `testexec/replay.py`,
`library_service.py`, `recording.py`, `capture_finalizer.py`, `proposals.py`; `ApwtClient.record_*` / `generate`,
`ApwtFactory.for_recording`; `TestLibraryStore.restore_replay` / `remove_uncommitted`, `record_replay(inputs=)`,
`CaptureStore.set_trace_path` / `set_decisions`; `domain.LIBRARY_TRANSITIONS`; `runtime/context._skill_source`
(`playwright-appian`); `api/app.py` 51-07 wiring; genesis-workflows `action-capture` 0.1.0 and skill
`genesis-test-authoring` 0.1.0.
