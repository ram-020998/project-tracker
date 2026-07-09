# Genesis — Phase 2 Implementation Record

> As-built record of Phase 2 (Workflow Contract & Library System). Companion to
> `specs/phase-02-workflow-contract-and-library.md`. The master `tracker.md` links here.

**Date:** 2026-07-09 · **Milestone:** M2 (Authoring works) · **Status:** ✅ COMPLETE — 25 tests green, ruff clean, library validation gate passing, all repos pushed.

---

## 1. Summary

Phase 2 delivered the **workflow contract, the shared library, the authoring
tooling, and the CI enforcement of the Q9 hard requirement**. The keystone is the
**reliability lint** — static analysis of a compiled graph that fails any workflow
whose agent node lacks the validator + retry + escalation trio — proven by a
deliberately non-compliant fixture that the gate correctly rejects. A third repo,
**`genesis-workflows`**, was created, populated, validated, and pushed.

---

## 2. Repos & tags after Phase 2

| Repo | Tag | Notes |
|---|---|---|
| `genesis-core` | **v0.2.0** | +`PlatformContext.checkpointer`; validator kind-marker propagated in `attach_reliability` (so the lint can see wrapped validators) |
| `genesis` | **v0.2.0** | +`genesis.lint` (reliability + contract), +`genesis.cli` (create-workflow/test-workflow), `genesis` console script |
| `genesis-workflows` | **v0.1.0** | NEW — registries, `_template`, `hello-appian`, non-compliant fixture, 7 steering docs, CI validation gate |

Git-pin chain updated: `genesis-workflows → genesis-core@v0.2.0` (runtime) + `genesis@v0.2.0` (dev); `genesis → genesis-core@v0.2.0`.

---

## 3. What was built

### 3.1 Platform (`genesis`)
```
genesis/lint/
  reliability.py    # check_reliability(compiled) -> LintResult  (THE Q9 gate)
  contract.py       # load_meta (side-effect-free), check_meta_yaml_parity, check_hitl_posture
  __init__.py
genesis/cli/
  main.py           # `genesis` dispatcher (create-workflow | test-workflow)
  create_workflow.py# scaffolder — emits a package with the reliability trio pre-wired
  test_workflow.py  # local gate: contract + reliability lint + package tests
```
- **Reliability lint mechanics:** recovers node kind from the `_genesis_kind`
  marker via `compiled.builder.nodes[n].runnable.func|afunc`; reads normal edges
  from `builder.edges` and conditional targets/keys from `builder.branches[n].ends`.
  For each agent node it asserts: an immediate validator successor; a retry edge
  back to the agent; and an escalation path (a gate-node target **or** an
  `escalate`-named branch key). A plain `pass→END` does **not** satisfy escalation.
- **Contract lint:** imports `graph.py` for `META` without calling `build()`;
  compares against `workflow.yaml` (drift check); checks the `auto_approve` posture.
- **Scaffolder:** `genesis create-workflow <id> --name … --roles … --mcp …` emits
  `graph.py` (+`META`), `workflow.yaml`, `nodes.py`, `tests/` — trio pre-wired,
  passes `test-workflow` out of the box.

### 3.2 Library (`genesis-workflows`)
```
registry.json  mcp-registry.json  cli-registry.json  bundles.json  MIGRATION.md
schemas/       registry.schema.json  mcp-registry.schema.json  workflow.schema.json
steering/      01..07 (authoring overview, node/reliability, state/blackboard,
                       mcp/cli, hitl gates, testing/publishing, workflow.yaml ref)
ci/validate_library.py   # the publish-time gate runner
workflows/
  _template/             # scaffolder source
  _fixtures/noncompliant # agent-without-validator — proves the lint FAILS it
  hello-appian/          # minimal example (passes all gates)
.gitlab-ci.yml           # validate stage (gate) + test stage (per-workflow tests)
```
- **`mcp-registry.json`** seeded with the known catalog: `appian-atlas` (read-only),
  `jarvis` (read-write-deploy), `appian-data-generator` (read-write-data), `lcp`
  (read-write — the OD-1 authoring unlock), `jira` (integration).
- **`ci/validate_library.py`** runs 7 gates: registries parse; per-workflow
  contract+drift; reliability lint; registry-ref existence; catalog aggregation
  matches `registry.json`; the non-compliant fixture must fail; (tests run in a
  separate CI stage).

---

## 4. Verification (evidence)

| Check | Result | Evidence |
|---|---|---|
| genesis-core units | **15 passed** | unchanged suite |
| genesis units + lint | **8 passed** | `tests/test_smoke.py` (5) + `tests/test_lint.py` (3) |
| Reliability lint: compliant passes | ✓ | `test_compliant_graph_passes` |
| Reliability lint: agent w/o validator **fails** | ✓ | `test_agent_without_validator_fails` |
| Reliability lint: validator w/o escalation **fails** | ✓ | `test_validator_without_escalation_fails` |
| Scaffolder → package passes out of the box | ✓ | `genesis create-workflow` then `genesis test-workflow` → OK |
| Library validation gate | ✓ | `ci/validate_library.py` → "LIBRARY VALIDATION PASSED (1 workflow)" |
| Non-compliant fixture rejected by gate | ✓ | "reliability lint correctly fails the non-compliant fixture" |
| Per-workflow tests | **2 passed** | hello-appian + _template stubbed-graph tests |
| ruff (all packages) | clean | — |

---

## 5. Decisions & fixes during implementation
- **Lint introspection path:** `_genesis_kind` lives on `runnable.afunc` for async
  nodes; the lint checks both `func`/`afunc`. Conditional-edge structure is read
  from `builder.branches[node].ends` (route-key → target).
- **Escalation detection refined:** END-as-target is ambiguous (a legit `pass→END`
  would satisfy it), so escalation requires a **gate-node target or an
  `escalate`-named branch key**, not merely END in the successor set.
- **Marker propagation bug fixed:** `attach_reliability` wrapped the validator in a
  new closure that lost `_genesis_kind`; now re-stamped so the lint detects it.
- **Contract needs `PlatformContext.checkpointer`** so `build(ctx)` can
  `g.compile(checkpointer=ctx.checkpointer)` per ADR-012; added (None for lint/tests).
- **pytest collection:** restricted platform collection to `tests/` (the CLI's
  `test_workflow()` function was being collected); library uses
  `--import-mode=importlib` and the generated test loads `graph.py` by a unique
  module name to avoid cross-workflow collisions.

---

## 6. Deferred (per spec)
- `author-workflow` meta-workflow (agent-assisted authoring) — designed in the spec,
  implemented after primitives stabilize.
- JSON-Schema *enforcement* in CI is currently programmatic in `validate_library.py`;
  the `schemas/*.json` are provided for reference and can be wired to `jsonschema` later.
- Real migrated workflows → Phase 8; only `hello-appian` + `_template` exist now.

---

## 7. Next: Phase 3 — Distribution (GitLab pull, selective install, lockfile, loader)
`genesis/dist/`: GitLab REST client, catalog fetch/filter, install/update/remove +
`installed.lock.json`, and the **loader** (yaml `META` read + genesis-core
major-compat gate + spawn — ADR-012/019). See `specs/phase-03-distribution-install-lockfile.md`.
