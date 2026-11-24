# 55-10 — Library adoption: the standard gate, artifact roles and memory opt-outs in every workflow

> **Status:** BUILT 2026-11-24, review **SHIP** (re-run 2; As built below). SPEC-DRAFTED 2026-11-22. Repos: genesis-workflows (`workflows/**`, `registry.json`, `ci/`), genesis
> (`genesis/cli/create_workflow.py`, the scaffolder template). Parent: `specs/phase-55-workflow-execution.md`. Built by
> **genesis-dev** against the local genesis build (55-04..55-06). Decisions: D4, D6, D8, F8, F11 (`55-01-findings.md`).

## 1. Standard escalation gate (D6, F8)

Every workflow with an agent node (16) replaces its escalate `hitl_gate` with **one shared**
`escalation_gate("escalate", extra_options=[…])` (55-06), passed as `on_exhaust_gate=` / `gate=` to every
`attach_reliability` / `attach_healing` call, with `attach_healing(artifact=<the deliverable>)` so Accept is offered
only when the deliverable exists (55-06 decision 2). Custom answers move to `extra_options`. The
`escalate → (cleanup) → END` edges go, because the gate routes accept and stop; **a workflow whose cleanup must run
on stop routes stop through it** with the gate's `stop_to=` (D21: an additive genesis-core option this sub-spec adds;
the run still ends `failed` with the reason, L-065). Turn green: `validate_library` (56 F8 violations in 16 workflows
at 55-06, listed in its As built) and the 7 library tests that run the lint (`_template`, action-capture,
agent-prompt, code-review, hello-appian, setup-composer, story-verification). Add a healing-wrapped history assertion
(55-06 review n3). Route tests: each action → its route → the stored outcome → the run status (L-106).

| Workflow | Today (55-01 §3.1) | After |
|---|---|---|
| ux-design-analysis, technical-design-analysis, feature-breakdown-analysis, test-design-analysis, story-design-analysis | escalate → (cleanup) → END; any answer = `done` | retry → the failed node / healing restart; accept → the normal path to present / cleanup (`done`, finalizer promotes); stop → cleanup → `failed` |
| story-implementation | `escalate` → cleanup → END; `escalate_reverify` [PROCEED_ANYWAY, SEND_BACK] | standard gate; `escalate_reverify`'s two options become `extra_options` of it |
| story-verification | `escalate` [send_back, accept, stop], `escalate_blocked` [retry, send_back, accept], state-built prompts | standard actions + `send_back` as an extra; the state-built wording kept (L-106) |
| setup-composer | [retry, discard] | standard retry; `discard` as an extra |
| code-review | `escalate` → END; `review_escalate` [skip, abort] | standard gate; `skip` / `abort` as extras; `verdict_gate`, `kb_gate` stay approval gates |
| agent-prompt | approve / feedback → `retry_agent`, else `give_up` (failed) | retry (guidance) → the agent; accept only with a non-empty `output.md`; stop → failed |
| generate-business-map, memory-consolidation, memory-maintenance, action-capture, erd-generation, hello-appian | approve → continue, else error / END | accept → continue; stop → failed; retry → the failed node |

Workflows with no agent node (`sync-application`, `sync-documents`, `test-execution`) are unchanged by §1. Once a
workflow adopts the gate, its Resolve tab gets the F6 facts and Fix then accept (55-09); a run of a workflow still on
the old gate keeps the old panel and the computed action map, so check one adopted and one legacy run in 55-11.

## 2. Artifact roles and labels (F11)

Every workflow (19) moves `META.artifacts` (and `workflow.yaml`) to the map form with a role and a human label per
file, from the real file lists (55-01 §4.2): e.g. technical-design-analysis `technical-design.html` output "Technical
design document", `spec.txt` input "Specification (text)", `verify.json` check "Grounded verification", `heal.json`
check "Heal decision", `sections.json` intermediate "Section plan"; story-implementation outputs
`implementation-report.html` and `rollback.md`; test-execution `results.json` + `report/*`; sync-application
`report.json`. The four stage workflows' outputs equal their `StageFinalizer` binding artifacts
(`genesis/chat/stage_finalizer.py:110-121`) — a test checks it.

Two places must accept the map form (55-05 As built): `schemas/workflow.schema.json` (`artifacts` is an array of
strings today) and the workflows' `cleanup` nodes, which do `set(META["artifacts"])`: with a map that yields the keys
but bypasses the parser and ignores globs, so route them through the same role parser (one reader, L-109; the
library cannot import genesis, so keep the rule exact-name-only there, or give each workflow a self-contained helper,
L-022/standalone `graph.py`) and test that cleanup keeps every declared file. `validate_library` passes on the map
form.

## 3. Memory opt-outs (D4) and relaunchable flags (D23)

**Relaunchable (D23):** set `META.relaunchable` (+ `workflow.yaml`) per workflow; the default is `false`, so declare
`true` only where a fresh run with the same inputs is safe. The 55-08 parity lint checks both places (a server list
must be a list). **Add the D26 lint:** every agent node's `mcp` ⊆ the workflow's `required_mcp`, so the Dev-write guard
(which reads `required_mcp` and the nodes' `mcp`) can never miss a server a node uses. Starting list (confirm each against the workflow's
bindings and side effects, record it in As built): `true` — ux-design-analysis, technical-design-analysis,
feature-breakdown-analysis, test-design-analysis (a top-up run stays refused per run), story-design-analysis,
generate-business-map, code-review, agent-prompt, hello-appian; `false` with a `relaunch_hint` — erd-generation (a
rerun publishes a second Lucidchart diagram; D32),
story-implementation ("Re-run it from the Implementation lane"; the platform also refuses it for `appian-dev-write`),
story-verification ("Drag the story into Verification again"), test-execution ("Run it again from Testing"),
setup-composer and action-capture ("Start it again from Testing → Library"), memory-consolidation and
memory-maintenance ("Use Run now on the Schedules page"), sync-application and sync-documents (no agent node; hint as
for the memory jobs).

**Memory opt-outs (D4):**
`memory-consolidation` and `memory-maintenance`: `META.memory_brief: false` (mirrored in `workflow.yaml`, parity lint).
Check first that the library schema (`schemas/`) and the parity lint accept the key (55-04 added the key on the
platform side only). Until this ships, the fleet's memory schedules stay off (D18, 55-01 §13).

## 4. Versions and scaffolder

Each changed workflow gets a minor version bump and a `registry.json` entry; the pins and `registry.json`
`genesis_core_version` move to `genesis.git@v0.84.0` at the release (55-12, L-057). The `create-workflow` scaffolder
template (`genesis/cli/create_workflow.py`, ADR-014) produces the standard gate and the map-form artifacts.

## 5. Tests

Route tests per workflow and action (§1); the validator and lint pass (`ci/validate_library.py`); every workflow's
existing tests pass; no `tests/__init__.py` collisions (L-092); one run in the CI image against the local genesis
build before 55-11 (L-112).

## 6. Gates

`cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py`; `../genesis/.venv/bin/python -m pytest -q
workflows --ignore=workflows/_fixtures`; skills validation; genesis pytest for the scaffolder.

## Context manifest

```toml
areas    = ["workflows-library", "core-engine"]
adrs     = ["ADR-006", "ADR-011", "ADR-014", "ADR-019", "ADR-021", "ADR-067", "ADR-084"]
lessons  = ["L-013", "L-020", "L-022", "L-057", "L-065", "L-092", "L-106", "L-110", "L-112"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis-workflows/workflows/**", "genesis-workflows/registry.json", "genesis-workflows/ci/**", "genesis-workflows/schemas/**", "genesis/genesis/cli/create_workflow.py", "genesis/packages/genesis-core/genesis_core/nodes/escalation.py"]
upstream = ["55-04", "55-05", "55-06"]
```

## As built

**Status:** BUILT 2026-11-24. Review round 1 **NEEDS_CHANGES** (M1, m1–m4, n1–n3) and re-run 1 **NEEDS_CHANGES**
(M2, m5, n4), all fixed or recorded below; re-run 2 **SHIP** (m6 fixed after it in `3c29e73`, not re-reviewed). Local commits on both masters (not pushed, not tagged). genesis-core additive (`CORE_MAJOR` 1), no
genesis.db migration (DB v30), no `web/**` change. The pins and `registry.json` `genesis_core_version` stay on v0.83.0
until 55-12 (L-057).

### Commits

| repo | sha | what |
|---|---|---|
| genesis | `014ef888` | core `escalation_gate(stop_to=)`, `prompt_fn` `""` fallback, `kiro_node` `_genesis_mcp`; lint `check_required_mcp` (D26); scaffolder map form + `relaunchable: false`; tests |
| genesis | `6185c905` | `genesis/testing/escalation.py` (route-test harness); `genesis test-workflow` runs the D26 check; tests |
| genesis | `4b54b737` | review M1 (healing history test through a real worker), n1 |
| genesis | `75d89b00` | `fix(55-08)`: review m1, the System-path test no longer assumes a case-insensitive filesystem (test only) |
| genesis | `361c99a6` | review re-run n4 (the 403 branch keeps the "System file" detail check; test only) |
| genesis-workflows | `60c12f3` | all 19 workflows, `registry.json`, `schemas/workflow.schema.json`, `ci/validate_library.py` |
| genesis-workflows | `1d3b9ea` | review m3 (catalog gate compares version/name/servers), m4 (first try, superseded by `4bc7168`), n2 |
| genesis-workflows | `4bc7168` | review re-run M2: the memory jobs' credit-free `skip` extra (replaces the m4 prompt text) |
| genesis-workflows | `3c29e73` | review re-run 2 m6: the consolidation skip test asserts the store cursor moves (test only) |

Bases: genesis `a09c5fbe`, genesis-workflows `9066541`.

### Changed

- **genesis-core** `nodes/escalation.py`: `escalation_gate(..., stop_to=None)` / `EscalationGate.stop_to`: the stop
  node sets `failed` + the reason and then edges to `stop_to` (else END); `routes()["stop"]` lists it. A `prompt_fn` that
  returns `""` gets the default wording. `nodes/agent.py`: `kiro_node` sets `_genesis_mcp` (a tuple of its static
  servers; `None` for a per-run callable).
- **genesis** `lint/contract.py` `check_required_mcp(compiled, meta)` (exported from `genesis.lint`); `lint/reliability.py`
  `_fn_of`; `cli/test_workflow.py` runs it; `cli/create_workflow.py` scaffolds `artifacts: {result.json: {role: output,
  label: Result}}` and `relaunchable: false` (and drops a stray string literal); `testing/escalation.py` (new):
  `gate_context`, `exhausted`, `ladder_exhausted`, `raise_gate`, `answer_gate` → `GateRun {payload, values, next,
  status, outcome}`, `gate_of`, `topology_gaps`, `declared_names`, `cleanup_losses`.
- **genesis-workflows** `ci/validate_library.py`: step 2 validates every `workflow.yaml` against
  `schemas/workflow.schema.json` and proves the schema rejects a bad role; step 3 runs `check_required_mcp` on the
  same compiled graph; step 5 compares each registry entry's `version`, `name`, `required_mcp`, `required_cli` with its
  yaml and proves it catches a drift. `schemas/workflow.schema.json`: `artifacts` = list or role map; `schedulable`,
  `relaunchable`, `relaunch_hint`, `memory_brief`. `registry.json`: the 19 versions (only those lines changed).
- **Every workflow with an agent node (16):** one `escalation_gate("escalate", …)` passed as the object to every
  `attach_reliability` / `attach_healing`; the old escalation `hitl_gate`s, their `escalate → (cleanup) → END` edges and
  the after-gate routers removed; a state-built `prompt_fn` (L-106) that returns `""` where the default words fit;
  `workflow.yaml` `graph:` carries `escalate_stop` and one edge per gate route (`topology_gaps == []` tested in each);
  `hitl_points` updated. All 19: the role map in META + yaml, `relaunchable` (+ hint), a minor version bump.
  `_template` mirrors the scaffolder.

### Per workflow (gate · outputs · other roles · relaunchable)

| workflow (version) | gate | output role | input · intermediate · check | relaunchable |
|---|---|---|---|---|
| action-capture 0.3.0 | 4 targets; stop→END | proposals.json, proposed/** | 0 · 3 · 4 | false: "Start it again from Testing → Library" |
| agent-prompt 0.2.0 | 1 target; stop→END | output.md | 0 · 0 · 0 | true |
| code-review 0.2.0 | 8 targets; stop→END; extras skip, abort (review_object only), set_verdict (propose_verdict only) | review.md | 0 · 9 · 2 | true |
| erd-generation 1.2.0 | 2 targets; stop→END | erd-input.json | 0 · 4 · 0 | **false**: "Start it again from the Catalog; give the diagram's document id to update it rather than create another" |
| feature-breakdown-analysis 0.4.0 | 5 targets (incl. the ladder); stop→cleanup | breakdown.html | 5 · 5 · 2 | true |
| generate-business-map 0.2.0 | 2 targets; stop→END | business_model.json | 0 · 4 · 0 | true |
| hello-appian 0.2.0 | 1 target; stop→END | result.json | 0 · 0 · 0 | true |
| memory-consolidation 0.2.0 | 2 targets; stop→END; extra skip (no usable output only) | report.json | 1 · 3 · 0 | false: "Use Run now on the Schedules page"; `memory_brief: false` |
| memory-maintenance 0.2.0 | 2 targets (two gates merged); stop→END; extra skip (no usable output only) | report.json | 0 · 3 · 0 | false: same hint; `memory_brief: false` |
| setup-composer 0.2.0 | 4 targets; stop→END; extra discard | compose.json, proposed/** | 0 · 2 · 4 | false: "Start it again from Testing → Library" |
| story-design-analysis 0.4.0 | 4 targets (incl. `verify_route`); stop→cleanup | design.html | 4 · 3 · 1 | true |
| story-implementation 0.2.0 | 8 targets (incl. `reverify_gap`); stop→cleanup; extras PROCEED_ANYWAY, SEND_BACK (gap only) | rollback.md, implementation-report.html | 3 · 3 · 3 | false: "Re-run it from the Implementation lane" (+ the platform's appian-dev-write guard) |
| story-verification 0.2.0 | 8 targets (incl. `open_sessions`, `decide`); stop→cleanup; extra send_back | proposals.json, verification-report.html | 0 · 5 · 2 | false: "Drag the story into Verification again" |
| sync-application 0.4.0 | — (no agent) | report.json | 1 · 2 · 0 | false: "Use Run now on the Schedules page" |
| sync-documents 0.2.0 | — | report.json | 0 · 0 · 0 | false: same |
| technical-design-analysis 0.4.0 | 7 targets; stop→cleanup | technical-design.html | 3 · 7 · 2 | true |
| test-design-analysis 0.2.0 | 5 targets; stop→cleanup; no `artifact=` | test-design.html | 6 · 9 · 2 | true (a top-up run stays refused per run by its binding) |
| test-execution 0.2.0 | — | results.json, report/** | 0 · 1 · 0 | false: "Run it again from Testing" |
| ux-design-analysis 0.3.0 | 7 targets; stop→END (no cleanup node) | analysis.html | 2 · 4 · 2 | true |

**Relaunchable confirmations (D23):** the five analysis workflows, agent-prompt, hello-appian and code-review use only
read tools (KB/Dev read allowlists, `@jira get_jira_issue`, Jarvis read-only, per-run read-only servers) and write only
their run folder; a fresh run with the same inputs is rebound to its stage or story by the platform. generate-business-map
overwrites the current (`release_label IS NULL`) map in the KB, idempotently. erd-generation deviates from the starting
list (see Decisions). The `false` ones are queue- or record-bound (ADR-081/082), schedule-started, or write Dev (ADR-068).

### Tests

- genesis-core `tests/test_escalation_gate.py` +5: stop_to runs the cleanup after the stop node set `failed` and the
  run completes failed with the reason; accept with stop_to takes the normal path (done); no stop_to skips the cleanup;
  `""` from `prompt_fn` falls back; `_genesis_mcp` for static, per-run and default `mcp`. Mutation: removing stop_to
  from TD failed 3 workflow tests.
- genesis `tests/test_lint.py` +3 (scaffold roles + relaunch + parity + D26; D26 fails a missing server and passes
  subsets; per-run skipped, a string list refused); `tests/test_gate_harness.py` (new, 4: the harness drives stop /
  retry / an extra through the real gate; `topology_gaps`; `cleanup_losses`; `test-workflow` reports the D26
  violation); `tests/test_run_actions.py` +1 (M1: a healing-wrapped workflow through a real subprocess worker — history
  `[verify, heal, verify, restart, verify]` with the critic's summary on each verify line; mutation: dropping the
  summary fails it); `tests/test_phase55_api.py` (m1, case-sensitive filesystems).
- genesis-workflows: per workflow, through the real compiled graph with `answer_gate` (seeded exhausted validator or
  `heal_route`): the gate's targets / stop_to / extras + `topology_gaps`; retry (next node, budget reset, guidance);
  accept (successor; run to `done` where the path is program-only); accept refused without the output; stop and the
  legacy reject (`failed`, reason, cleanup ran where there is one); each extra and its availability both ways; a
  healing-wrapped case in every healing workflow; `cleanup_losses == []` in the five with a sync cleanup; roles (the
  four stage outputs equal `StageFinalizer._BINDINGS`; story-design `design.html` = `StoryDesignFinalizer.ARTIFACT`;
  story-implementation = `REPORT` + rollback); `parse_relaunch`; `memory_brief` false on both sides; the memory jobs'
  `skip` read through the real gate payload (offered and named only without a usable output, refused with one; run to
  `done` with nothing written; mutation: dropping its availability rule fails 2 tests). Each worker mutation-checked its stop_to / extra / accept wiring (each
  killed, restored). Tests rewritten to the new gate: TD none; test-design 1 (topology reachability skips gate routes);
  story-implementation 1 (reverify proceed/send-back); story-verification 4 (route functions gone → real graph); code-review
  1 (`skip` answer); setup-composer 2, action-capture 3 (comments/seeds); agent-prompt 3 (approve/feedback → retry).
- **Gates:** genesis-workflows `ci/validate_library.py` **PASSED, 0 violations** (19; the 56 F8 violations of 55-06
  gone; the 7 lint-calling tests green); `pytest -q workflows --ignore=workflows/_fixtures` **678 passed** at 4bc7168
  (672 at 1d3b9ea; at 60c12f3:
  668 = the sum of the 20 per-folder runs, L-092; no `tests/__init__.py`); `ci/validate_skills.py` 5 passed. genesis full
  pytest **2387 passed, 4 skipped** at 6185c905 (scratch `GENESIS_STATE_DIR`; the reviewer reproduced it), +1 at
  4b54b737 (`test_run_actions.py` 25 passed), `ruff check genesis` clean; genesis-core **157 passed**, ruff clean. Library
  ruff (CI runs none): no new finding in the touched files.
- **CI-image run (L-112)**, colima arm64 `python:3.13`, git archives under `/tmp/colima/gr-55-10b` (genesis `75d89b00` +
  genesis-workflows `1d3b9ea`), genesis installed with `scripts/install-packages.sh --dev --no-model`, the library
  `--no-deps` (its pins name v0.83.0; the archive's genesis was used, not the pins): validate_library PASSED,
  validate_skills PASSED, library pytest **672 passed**, genesis-core **157 passed**, genesis full **2331 passed, 58
  skipped, 3 failed**: `test_sail_cli.py` ×2 (known arm64-only, 54-11) and
  `test_document_records.py::test_a_run_records_every_write_with_its_step_execution_and_attempt`, which passed 3/3 alone
  and the whole file 2/2 in the same image. 55-10 touches neither `genesis/runs/` nor that test, so it is carried, but
  it is **not proven a flake** (review m5): only the last 6 lines were logged, so no assertion message exists, and the
  worker's change snapshot keys on `(st_size, st_mtime_ns)` (`runs/writes.py:87`), so a same-size rewrite inside one
  timestamp tick on Linux would be a real recording gap. Owner: 55-12 (below). The library at 4bc7168 was not re-run in
  the image (one workflow pair changed after it; the local gates above are green).
  The first image run (`/tmp/colima/gr-55-10`, 5 genesis suites) found the 55-08 case-sensitivity test failure, fixed in
  `75d89b00`. colima was stopped afterwards.

### Review

`reviews/55-10-review.md`, round 1 **NEEDS_CHANGES**: M1 (no healing history assertion), m1 (pre-existing 55-08 test,
Linux), m2 (CI image ran only 5 genesis suites), m3 (catalog ids-only), m4 (memory jobs cannot skip a window), n1–n3.
Fixed: M1, n1 (`4b54b737`), m1 (`75d89b00`), m2 (the full CI-image run above), m3, n2 (`1d3b9ea`); n3 recorded below.
Re-run 1 **NEEDS_CHANGES**: M2 (the m4 prompt named Fix then accept, which the gate refuses when the output is missing),
m5 (the CI-image failure's mechanism not shown), n4. Fixed: M2 (`4bc7168`, a `skip` extra), n4 (`361c99a6`); m5 carried
to 55-12. Re-run 2 **SHIP**: m6 (the skip test did not assert the store cursor) fixed in `3c29e73` after the verdict
(test only, library 678 passed, not re-reviewed); n5 for a later phase: no genesis test covers `RunManager._check_answer`
refusing an unavailable *extra* (the reviewer probed it: `skip` is refused with a usable output).

### Decisions / deviations

No ADR deviation. Choices the spec did not cover:
1. **The gate test harness lives in genesis** (`genesis/testing/escalation.py`, beside `scan_recording`, test support
   only), so a workflow's tests stay inside its folder and installed workflows' tests still run (`genesis test-workflow`).
2. **story-implementation:** `escalate_reverify` is gone; a gap is a registered target `reverify_gap` (retry → reverify,
   accept → `prepare_rollback`), with PROCEED_ANYWAY / SEND_BACK as extras offered only for the gap (upper-case ids, so an
   older client's bare option string still routes). A bare `reject` now **stops** (cleanup → failed, no writes) where it
   used to send back.
3. **story-verification:** both gates merged. `open_sessions` and `decide` are registered targets (retry → open_sessions
   / execute; accept → a new `accept_as_passed` node → propose, today's blocked Accept); `send_back` is an extra (a new
   `send_back` node, always offered); `_decide` does not loop back after a ladder accept; `propose` accept keeps Done and
   drops the proposals (the old wording); stop → cleanup → render_report → present, which now keeps `failed`, with
   `result.json` decision "stopped" (the card stays in Verification; the execution records `error` with the stop
   detail). `proposals.json` is a second output (the Proposals review reads it).
4. **code-review:** `verdict_gate` is an approval gate reached by the `set_verdict` extra; `_next_object` empties
   `object_review.md` so an Accept never records the previous object's text; `obj/*` declared.
5. **story-design-analysis:** `_verify_route` registers `verify_route` (retry → design, accept → present) and treats
   `verify.accepted_unverified` as present.
6. **test-design-analysis** passes no `attach_healing(artifact=)`: the deliverable is `test-design.html` or `topup.html`
   by mode, and a static artifact would refuse Accept on every top-up (the ladder runs only after verify read the
   assembled file). n3: in top-up mode `topup.html` is labelled intermediate, so a top-up run's Documents shows no output
   (a per-mode role is a later change).
7. **No stop_to** for ux-design-analysis (no cleanup node), code-review, agent-prompt, hello-appian, erd, the business
   map, the memory jobs, setup-composer and action-capture (nothing must run on a stop: both replays remove their
   `.auth` before they return and the platform reaps `.pids`).
8. **action-capture got no `discard`** (it never had one; Stop covers it). setup-composer's discard keeps "no proposal".
9. **erd-generation `relaunchable: false`** against §3's starting list: a rerun without `document_id` publishes a second
   Lucidchart diagram. The reviewer agreed. Your call if you want it true.
10. **Memory jobs: a credit-free `skip` extra** replaces the old "approve with no output = skip this pass" (Accept now
    needs the output). It is offered only when the escalated step wrote no usable output: consolidation → `advance_cursor`
    (the empty-day path: the cursor moves on, nothing written), maintenance → `recompute_communities` (the program upkeep
    with nothing from the agent passes applied). Without it a scheduled job would stop on the same window every night
    until it auto-paused. (Fix then accept cannot do this: the gate refuses it whenever Accept is refused.)
11. **Globs** only where no root-deleting cleanup exists (`pages/*`, `obj/*`, `proposed/**`, `report/**`); `cleanup_losses`
    fails on any glob it is given.
12. registry.json's erd-generation was already drifted (1.0.0 vs META 1.1.0) → 1.2.0; the catalog gate now catches it.
13. `_template` mirrors the scaffolder; schema validation runs in `validate_library` (jsonschema is a genesis dependency).

### Live effect before the release

The fleet installs workflows from library releases, so **nothing in genesis-workflows reaches it until 55-12**, and the
fleet's memory schedules stay off (D18). Through the editable dev venv, new fleet workers import the new genesis-core:
`stop_to` defaults to END and the `""` fallback only changes a `prompt_fn` that returned an empty string (none in
v0.27.0), and `_genesis_mcp` is an inert attribute, so v0.27.0 runs behave as before. The dev venv's CLI is live:
`genesis create-workflow` scaffolds the role map + `relaunchable: false`, and `genesis test-workflow` adds the D26 check.
Nothing was restarted; no live run, no Appian, no credits.

### Lesson candidates

1. **A route test can seed the checkpoint instead of driving agents:** `aupdate_state(as_node=<exhausted validator>)`
   + `ainvoke(None)` raises the real gate, and `interrupt_before=[node]` stops right after the route, so every answer is
   tested through the compiled graph with no agent turn.
2. **A test that passes on macOS can be asserting the filesystem, not the code:** `_KIRO/…` resolved to `_kiro/…` on
   case-insensitive APFS (55-08); only the Linux image showed it. Run the full suite in the CI image, not a subset (m2).
3. **A catalog check that compares only ids lets every other field drift** (erd-generation's version was stale for a
   release).

### Code-map changes (for genesis-docs, bible/03)

- genesis-core `nodes/escalation.py`: `stop_to`, the empty-prompt fallback; `nodes/agent.py`: `_genesis_mcp`.
- genesis `lint/contract.py` `check_required_mcp`; `lint/reliability.py` `_fn_of`; `testing/escalation.py` (new);
  `cli/test_workflow.py` D26; `cli/create_workflow.py` the map + `relaunchable`.
- genesis-workflows `ci/validate_library.py` (schema check, D26, catalog fields); `schemas/workflow.schema.json`; every
  workflow's gate wiring, role map and relaunch flags (table above); story-verification `accept_as_passed`, `send_back`;
  story-implementation `reverify_gap`.

### For 55-11+

- **55-11:** check one adopted and one legacy run in Resolve (55-09); a live stop through cleanup on a stage workflow
  (failed, files kept) and on story-verification (sessions closed, card stays); Accept on an exhausted ladder (the
  StageFinalizer promotes); the story-implementation gap answers; review this As built's unreviewed fixes.
- **55-12:** move the pins and `genesis_core_version` to v0.84.0 (L-057); re-run the full genesis suite in the CI image
  at the release commit and **capture** `test_document_records`'s failing assertion if it fails (`-x`, keep the `E `
  lines): name its timing mechanism in the test, or open a 55-05 follow-up if it is the same-size, same-tick case
  (review m5; "passed on a re-run" is not enough); turn the fleet's
  memory schedules back on after the library release (D18); release notes: the D23 list, erd-generation false, the
  memory jobs' Skip, story-implementation's `reject` now stops.
- **Backlog:** action-capture's `.auth` removal is not in a `finally` (pre-existing; setup-composer has one since 51);
  a per-mode role for test-design's `topup.html` (n3).
- Scratch to delete when done: `/tmp/gr-55-10/`, `/tmp/colima/gr-55-10/`, `/tmp/colima/gr-55-10b/` (copies of the two
  repos' trees, no secrets).
