# Phase 6 — ERD Reference Workflow

> **Goal:** Port the already-validated ERD generation workflow onto Genesis as
> the **canonical reference workflow** — the template every other workflow copies.
> It exercises the full stack: MCP injection, program/agent split, the blackboard,
> the reliability trio, a HITL gate, a CLI node, and durable/resumable runs.

Prereq: Phases 1–5. Related prior art: `project-tracker/kiro-agent-sdk/tracker.md`
(the ERD workflow already runs end-to-end imperatively: 37 tables, 174 rels).

---

## 1. Objective & success statement

`erd-generation` is installable from `genesis-workflows`, runnable via Genesis
(Studio), and produces a Lucidchart ERD (or, in dry-run, a validated
`erd-input.json`) for a given Appian app — with a HITL gate to approve domain
assignments, full reliability trio on both agent nodes, and resumable state. It
becomes the reference implementation cited by the authoring steering.

---

## 2. Scope

**In scope:** the `erd-generation` workflow package (graph, nodes, prompts,
tests, `workflow.yaml`), using Genesis primitives; the `erd-gen` CLI in the CLI
registry; the `appian-atlas` server in the MCP registry; a domain-approval gate.
**Out of scope:** other workflows (Phase 8); live Lucid publish is optional
(dry-run acceptable if Lucid token absent, as today).

---

## 3. Decisions applied

All — this is the integration proof. Especially Q2 (MCP injection), Q8 (blackboard),
Q9 (trio on both agent nodes), Q7 (approval gate), Q10 (contract), Q13 (ERD first).

---

## 4. Detailed design

### 4.1 State
```python
class ErdState(PlatformState):
    scope: str                 # "business" | "full"
    document_id: str | None    # update vs generate
```

### 4.2 Graph (nodes & edges)
Mirrors the validated pipeline, now as Genesis nodes:

| Node | Type | Detail |
|---|---|---|
| `preflight` | program/cli | ensure `erd-gen` + Lucid token (via CLI registry / health) |
| `fetch_schema` | **agent** (`kiro_node`, mcp=`appian-atlas`) | dump raw `get_app_schema` + `get_schema_relationships` verbatim → `raw_schema.json`, `raw_relationships.json` |
| `validate_fetch` | validator | both docs non-empty + parseable; else retry/escalate |
| `normalize` | program | raw Atlas shapes → `schema.json` (unified) |
| `assign_domains` | **agent** (`kiro_node`, no MCP) | read `schema.json`, write per-table domain + field decisions → `enriched.json` |
| `validate_enriched` | validator | every table present, valid domain, PK first; else retry/escalate |
| `approve-domains` | **hitl_gate** | show domain distribution; approve / reject / feedback (feedback re-runs `assign_domains`) |
| `assemble` | program | merge relationships + inject domain color palette → `erd-input.json` |
| `run_erdgen` | **cli** (`erd-gen generate|update`) | conditional on `document_id`; parse doc id + URL |
| `report` | program | Lucidchart summary block |

Edges: `preflight→fetch_schema`; reliability trio on `fetch_schema`
(`validate_fetch`) and on `assign_domains` (`validate_enriched`); `validate_enriched.pass →
approve-domains`; gate approve → `assemble`; gate feedback → `assign_domains`;
`assemble → run_erdgen` (conditional generate/update; dry-run short-circuits to
`report`); `run_erdgen → report → END`.

### 4.3 Reuse of existing code
Port the proven functions from the current `erd_workflow.py`:
`normalize_atlas_schema`, `build_erd_document` (+ `DOMAIN_PALETTE`),
`build_erdgen_command`, `parse_erdgen_output`, and the two agent prompts. These
drop into `nodes.py`/`prompts/` largely unchanged; the orchestration becomes the
LangGraph graph instead of the imperative `run()`.

### 4.4 `workflow.yaml` / `META`
```yaml
id: erd-generation
name: ERD Generation
version: 1.0.0
roles: [documentation, developer]
inputs_schema:
  type: object
  required: [app]
  properties:
    app: {type: string}
    scope: {type: string, enum: [business, full], default: business}
    document_id: {type: [string, "null"], default: null}
    dry_run: {type: boolean, default: false}
required_mcp: [appian-atlas]
required_cli: [erd-gen]
hitl_points: [approve-domains]
retry_defaults: {max: 2}
artifacts: [raw_schema.json, raw_relationships.json, schema.json, enriched.json, erd-input.json]
```

### 4.5 Tests (`tests/`)
- Unit: `normalize_atlas_schema` (real shapes), `build_erd_document`, `parse_erdgen_output` (json+text), validators.
- Graph test with **stubbed agent nodes** (inject canned `enriched.json`/schema) → assert `erd-input.json` correctness + gate reached + escalation on forced validator failure.
- Optional live/integration test (marked, needs `GITLAB_TOKEN`): full run in dry-run against `SourceSelection`.

---

## 5. Task breakdown

1. Create `genesis-workflows/workflows/erd-generation/` via `create-workflow`; fill `workflow.yaml`.
2. Register `appian-atlas` in `mcp-registry.json`; `erd-gen` in `cli-registry.json`.
3. Port pure functions (normalize/build/parse) into `nodes.py`; port prompts.
4. Implement `fetch_schema`/`assign_domains` as `kiro_node`s with the verbatim-dump + decisions-to-file patterns.
5. Wire reliability trios on both agent nodes (validators + retry + escalation gate).
6. Implement `approve-domains` gate (distribution summary + approve/reject/feedback).
7. Implement conditional `run_erdgen` (generate/update/dry-run) + `report`.
8. Tests (unit + stubbed-graph + optional live).
9. Publish through library CI (must pass the reliability lint).
10. Install via Genesis (Phase 3) + run in Studio (Phase 5): dry-run against `SourceSelection`; then a live publish if Lucid token present.

---

## 6. Acceptance criteria

- [ ] `erd-generation` passes library CI (contract + reliability lint + tests).
- [ ] Installable via Genesis; prereq check flags missing `appian-atlas`/`erd-gen`.
- [ ] Dry-run against `SourceSelection` reproduces the known-good result (≈37 tables, 174 relationships; audit cols excluded; domains colored) — parity with the pre-Genesis run.
- [ ] The `approve-domains` gate pauses the run; feedback re-runs `assign_domains`; approve proceeds.
- [ ] Forced validator failure retries `retry_max` times then escalates to the gate.
- [ ] Kill + resume mid-run continues from the last checkpoint.
- [ ] (If Lucid configured) a real Lucidchart document is produced with id + URL in the report.

---

## 7. Risks

- **`generate-erd` skill overlap:** solutions-copilot's `generate-erd` produced a
  *spec* but left Lucid unwired; Genesis's `erd-generation` completes it via the
  `erd-gen` CLI. Keep the field-selection/domain rules consistent with that skill's references.
- **Atlas payload size:** already handled (64 MB ACP buffer in `kiro-agent-sdk`);
  keep verbatim-dump-to-file (not chat) — the lesson that fixed the original hang.
- **Lucid availability:** dry-run is the default acceptance path; live publish gated on token.

---

## 8. Deliverables

- `erd-generation` workflow in `genesis-workflows`, CI-passing.
- Reference documentation in authoring steering pointing to it as the template.
- Verified Genesis run (dry-run parity; live publish if configured).
