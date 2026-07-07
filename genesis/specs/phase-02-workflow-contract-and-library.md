# Phase 2 — Workflow Contract & Library System

> **Goal:** Define the contract every workflow implements, the structure of the
> `genesis-workflows` library, the shared registries, the authoring scaffolder +
> test harness, the authoring **steering** docs, and the **CI enforcement** of
> the Q9 hard-requirement. At the end of Phase 2 anyone can scaffold, author,
> locally test, and publish a workflow that the platform can load via a stable
> contract.

Prereq: `specs/00-architecture-overview.md`, Phase 1 (`common/` + node factories).

---

## 1. Objective & success statement

Produce (a) the **`build()` + `META` contract**; (b) the **`genesis-workflows`**
repo skeleton with `registry.json`, `mcp-registry.json`, `bundles.json`,
`common/`, `steering/`; (c) a **`genesis create-workflow`** scaffolder that emits
a correct package (reliability trio pre-wired); (d) a **local test harness**; (e)
**library CI** that validates every workflow (contract present, `META` valid,
every agent node has a validator + retry/escalation, tests pass) so broken
workflows never reach users.

---

## 2. Scope

**In scope:** contract definition; library repo skeleton + registries; scaffolder;
authoring steering; publish-time CI validation; a "hello" example workflow.
**Out of scope:** GitLab pull/install/lockfile from the *platform* side (Phase 3);
config/secrets UI (Phase 4); run/HITL surfacing (Phase 5); ERD (Phase 6).

---

## 3. Decisions applied

Q3 (MCP registry), Q4 (packaging + `registry.json`), Q5 (roles as tags +
bundles), Q9 (hard requirement enforced in CI), Q10 (`build()`+`META`, CI at
publish), Q12 (scaffolder + agent-assisted authoring + authoring steering; open
contribution).

---

## 4. Detailed design

### 4.1 The workflow contract
Each workflow package must expose, in `graph.py`:
```python
from genesis_common import PlatformContext
from langgraph.graph import StateGraph

META: dict = {
  "id": "erd-generation",
  "name": "ERD Generation",
  "version": "1.2.0",
  "roles": ["documentation", "developer"],     # Q5 filter tags
  "summary": "Generate + publish an ERD for an Appian app.",
  "inputs_schema": { ... JSON Schema ... },     # validated before run
  "required_mcp": ["appian-atlas"],             # names into mcp-registry
  "required_cli": ["erd-gen"],
  "hitl_points": ["approve-domains"],           # node names that may interrupt
  "retry_defaults": {"max": 2},                 # Q9 configurable
  "artifacts": ["raw_schema.json","schema.json","enriched.json","erd-input.json"],
}

def build(ctx: PlatformContext) -> "CompiledStateGraph":
    g = StateGraph(ErdState)
    ...
    return g.compile(checkpointer=ctx.checkpointer)
```
- `META` is **static, importable without side effects** (the app reads it to
  render the catalog and check prerequisites without running the graph).
- `build()` receives the `PlatformContext` (Phase 1 §4.2) and returns a compiled
  graph. It must not perform I/O beyond graph construction.

### 4.2 `workflow.yaml` (mirror of `META` for tooling)
A YAML twin of `META` so the scaffolder/CI/catalog can read metadata without
importing Python. CI asserts `workflow.yaml` ≡ `META` (drift check).
```yaml
id: erd-generation
name: ERD Generation
version: 1.2.0
roles: [documentation, developer]
summary: Generate + publish an ERD for an Appian app.
inputs_schema: {…}
required_mcp: [appian-atlas]
required_cli: [erd-gen]
hitl_points: [approve-domains]
retry_defaults: {max: 2}
```

### 4.3 `mcp-registry.json` (Q3) — shared
```json
{
  "version": 1,
  "servers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run","--rm","-i","--env","GITLAB_TOKEN","--env","ATLAS_KB_PROJECT_ID",
               "--env","ATLAS_DATA_PREFIX","<atlas-image>"],
      "env": {"GITLAB_TOKEN":"${GITLAB_TOKEN}","ATLAS_KB_PROJECT_ID":"13490",
              "ATLAS_DATA_PREFIX":"ai-framework/tools/Atlas/solutions-kb/data"},
      "mode": "read-only",
      "secretKeys": ["GITLAB_TOKEN"],
      "publicKeys": ["ATLAS_KB_PROJECT_ID","ATLAS_DATA_PREFIX"]
    },
    "jarvis": {"…": "read-write-deploy"},
    "appian-data-generator": {"…": "read-write-data"},
    "lcp": {"…": "appian object authoring"},
    "jira": {"…": "integrations"}
  }
}
```
Classification (`secretKeys`/`publicKeys`) drives the Phase-4 config UI. `mode`
drives safety posture (write/deploy servers get stricter defaults).

### 4.4 `registry.json` (catalog) — Q4
```json
{
  "version": 1,
  "workflows": [
    {"id":"erd-generation","name":"ERD Generation","version":"1.2.0",
     "roles":["documentation","developer"],"summary":"…",
     "path":"workflows/erd-generation","required_mcp":["appian-atlas"],
     "required_cli":["erd-gen"]}
  ]
}
```
Generated/validated by CI from each `workflow.yaml` (single source of truth =
the per-workflow `workflow.yaml`; `registry.json` is the aggregated projection,
like solutions-copilot manifest→catalog).

### 4.5 `bundles.json` (Q5c curated role bundles)
```json
{"bundles":{
  "developer":{"title":"Developer set","workflows":["erd-generation","code-review","implementation"]},
  "tester":{"title":"Tester set","workflows":["test-execution","unit-test","test-data-generation"]}
}}
```

### 4.6 Library repo skeleton
```
genesis-workflows/
  registry.json
  mcp-registry.json
  cli-registry.json
  bundles.json
  common/                     # genesis_common package (shared node lib + state + RunWorkspace)
  steering/                   # AUTHORING GUIDES (Q12)
    01-authoring-overview.md
    02-node-taxonomy-and-reliability.md   # the mandatory trio, examples
    03-state-and-blackboard-rules.md
    04-mcp-and-cli-usage.md
    05-hitl-gates.md
    06-testing-and-publishing.md
    07-workflow-yaml-reference.md
  workflows/
    _template/                # what the scaffolder copies
      workflow.yaml
      graph.py                # build() + META with a reliability trio wired
      nodes.py
      prompts/
      tests/test_workflow.py
    hello-appian/             # example
  .gitlab-ci.yml              # publish-time validation
  pyproject.toml
```

### 4.7 Scaffolder — `genesis create-workflow` (Q12a)
CLI in the platform that generates a new package from `_template/`:
- prompts: id, name, roles, required_mcp, required_cli, hitl points.
- emits `graph.py` with a **pre-wired reliability trio** (agent → validator →
  retry/escalate) so the hard-requirement is the default path.
- emits `workflow.yaml`, `nodes.py`, `prompts/`, `tests/`.
- registers the workflow in `registry.json`.

### 4.8 Agent-assisted authoring (Q12c)
A meta-workflow `author-workflow` (built in the library like any other) that:
reads the authoring steering, interviews the user about the steps, and scaffolds
+ drafts `graph.py`/prompts. Ships after the primitives are stable but designed
here so the steering docs double as its knowledge base.

### 4.9 Local test harness (Q12)
`genesis test-workflow <path>`: loads the package, validates `META`/`workflow.yaml`
parity, runs the workflow's `tests/` via `genesis.testing.harness` (mock MCP/CLI
where needed), and runs the **structural lint** (§4.10) locally.

### 4.10 CI enforcement (Q9, Q10) — `.gitlab-ci.yml`
Publish-time gates (a workflow cannot be tagged/released unless all pass):
1. **Schema:** every `workflow.yaml` valid; `registry.json` matches; ids unique.
2. **Contract:** `graph.py` imports; `META` importable with no side effects; `META`≡`workflow.yaml`.
3. **Reliability lint (HARD, Q9):** static analysis of the compiled graph — every
   `kiro_node`/agent node has (a) an immediate `validator_node` successor and (b)
   a retry edge back to itself and (c) an escalation edge to a gate/END. Missing
   any ⇒ **fail the build**.
4. **MCP/CLI refs:** every `required_mcp`/`required_cli` exists in the registries.
5. **Tests:** each workflow's `tests/` pass.
6. **State-size guard:** static/dynamic check that nodes don't push bulk into state.

### 4.11 Structural lint implementation note
Provide `genesis.lint.check_reliability(compiled_graph, meta)` that walks the
graph's nodes/edges (LangGraph exposes the graph structure) and asserts the trio.
Agent nodes are identified by a marker set on nodes created via `kiro_node`
(e.g., a `node._genesis_kind == "agent"` attribute).

---

## 5. Task breakdown

1. Define + document the contract (`build()`+`META`) and `PlatformContext` expectations.
2. `genesis-common` package (from Phase 1 `common/`) published/importable by the library.
3. Author `mcp-registry.json`, `cli-registry.json`, `registry.json`, `bundles.json` schemas + JSON-Schema validators.
4. Build `genesis-workflows` skeleton + `_template/` + `hello-appian` example.
5. Write the 7 **authoring steering** docs (the Q12 guide set).
6. Implement `genesis create-workflow` scaffolder.
7. Implement `genesis test-workflow` local harness.
8. Implement `genesis.lint.check_reliability` + `META`/`workflow.yaml` drift check + state-size guard.
9. Write `.gitlab-ci.yml` with all six gates.
10. Prove the reliability lint by adding a **deliberately non-compliant** example under a `tests/fixtures/` and asserting CI fails it.
11. Draft the `author-workflow` meta-workflow design (implement later).

---

## 6. Acceptance criteria

- [ ] `genesis create-workflow` produces a package that passes `genesis test-workflow` and CI out of the box.
- [ ] The generated package's agent node already has validator + retry + escalation (trio) with no author effort.
- [ ] CI **fails** a fixture workflow whose agent node lacks a validator (proves Q9 enforcement).
- [ ] `META` and `workflow.yaml` drift is detected and fails CI.
- [ ] `registry.json` is regenerated/validated from `workflow.yaml`s; unknown MCP/CLI refs fail CI.
- [ ] The 7 authoring steering docs exist and are sufficient for a new engineer to build `hello-appian` unaided (dry-run with a colleague).

---

## 7. Risks

- **`common` versioning:** platform and library must agree on `genesis-common`
  version. Pin it; CI checks compatibility. (Ties to Phase 1 §7.)
- **Static reliability lint completeness:** conditional/dynamic edges (`Send`)
  may obscure structure. Mitigation: require agent nodes to be declared via
  `kiro_node`/`attach_reliability` (the sanctioned path) and lint against that
  marker rather than arbitrary graph shapes.
- **Authoring friction:** Python workflows are harder than markdown skills.
  Mitigation: strong scaffolder + steering + (later) agent-assisted authoring.

---

## 8. Deliverables

- `genesis-workflows` repo skeleton (registries, `_template`, `hello-appian`, steering, CI).
- Contract spec + `genesis-common` package boundary.
- `create-workflow` + `test-workflow` CLIs + reliability lint.
- CI that enforces the Q9 hard-requirement, proven by a failing fixture.
