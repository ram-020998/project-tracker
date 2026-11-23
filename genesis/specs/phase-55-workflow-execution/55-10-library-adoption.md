# 55-10 — Library adoption: the standard gate, artifact roles and memory opt-outs in every workflow

> **Status:** SPEC-DRAFTED 2026-11-22. Repos: genesis-workflows (`workflows/**`, `registry.json`, `ci/`), genesis
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
generate-business-map, code-review, erd-generation, agent-prompt, hello-appian; `false` with a `relaunch_hint` —
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
