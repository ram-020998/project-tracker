# 51-07 — Action Library, Record workflow and `action-capture`

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (backend), **genesis-workflows** (`action-capture` v0.1.0 +
> skill `genesis-test-authoring`), **playwright-appian** (0.3.0 from 51-03 is the base; fix recorder gaps in §4 item 4
> only if they block acceptance). Parent:
> `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D2, D3, D5.6, D13, D16, D20; F1, F5.

## 1. Goal

Manage reusable actions and data setups as code with contracts, where-used and history; let a person record a flow as
one role and get reviewed action proposals back.

## 2. The workspace helper `lib/` (TypeScript, written by Genesis, versioned with the template)

- `defineAction({ key, name, area, role?, inputs, outputs }, fn)` — `fn(ctx, input) → output`; `ctx = { page, appian:
  createAppianPage(page), as(role) }`; inputs/outputs are typed objects whose shape equals `contract_json`.
- `defineSetup({ key, name, role, outputs }, fn)` — an ordered list of action calls; returns its outputs.
- `defineCase('<TC-key>', { role? }, fn)` — the When + Then of one case; reads setup data through `ctx.data`; uses
  `expect` from `@playwright/test`.
- `loginAs(page, role)` — `login(page, { username, password })` from `playwright-appian` with
  `GENESIS_TEST_USER_<ROLE>`/`GENESIS_TEST_PASSWORD_<ROLE>`; `setupData(instance)`; `unique(prefix)` for per-run values
  (D8.6).
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
  Draft through a new `TEST_TRANSITIONS` edge `(READY, "changed") → DRAFT` via `LifecycleService` (audited; the reason
  names the commit), in the same workspace-locked operation as the commit. **Replay** on the item page runs the item's
  replay on QA (as for proposals, §5) and, on a pass at the current hash, approves it back to Ready. Status never gates
  executions or authoring. A metadata-only edit keeps the status.
- Every write path is serialized per workspace (a lock) and runs off the event loop (L-026).

## 4. Record workflow (D13)

`RecordingService` (`genesis/genesis/testexec/recording.py`, app process; human-driven, so not a workflow run):
1. `start(app_uuid, role_key, intent, start_path?)` → `readiness` → the **settled mechanism** (51-03 S8/S9, D-114 in
   `playwright-appian` 0.3.0; the recorder never holds the password):
   1. `apwt -s rec-<capture-id> open <QA site> --login --browser chromium --allow-host <QA host>` (credentials only in
      this subprocess's environment, 51-05 §4) → `apwt -s rec-<capture-id> state-save --file <ws>/.auth/<capture-id>.json`
      → `apwt -s rec-<capture-id> close`;
   2. `apwt record start --detach --browser chromium --state <ws>/.auth/<capture-id>.json --url <start page>
      --out <ws>/captures/<capture-id>/trace.json` (headed; returns `SESSION`, `TRACE_PATH`, `PID`);
   3. delete the state file as soon as `record start` returned (the browser context holds the login).
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

The workspace conventions an agent must follow (both here and in 51-09): folder layout, the `lib/` API, contract rules,
label-only code, unique values, how to read the catalog snapshot, how to write proposals. The `playwright-appian` CLI skill is provisioned from the workspace's installed package
(`node_modules/playwright-appian/skills/playwright-appian`, exact version) by extending the `skill_source` resolver for
that id (one home for that skill, ADR-069; D3c). `genesis-test-authoring` adds the Genesis rules on top (use only the
given sessions; no `open`/`login`/`attach`/`state-save`; no other host; never print environment variables).

## 8. Tests

Save/typecheck/commit, refused breaking contract, retire refused with names, delete only if never referenced, revert,
outside edit → adopt, a code save/revert/adopt of a Ready item demotes it to Draft through the audited `changed` edge
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
