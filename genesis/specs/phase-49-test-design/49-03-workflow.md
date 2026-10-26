# 49-03 — The `test-design-analysis` workflow

> **Status:** SPEC-DRAFTED 2026-10-26. Repo: **genesis-workflows**. Parent: `specs/phase-49-test-design.md`.
> Decisions: 49-01 D1–D3, D11, D14; F1, F3; R3. New workflow `test-design-analysis` **v0.1.0**.

## 1. Goal

A deterministic LangGraph workflow (ADR-001) that turns a feature's finalized stories (+ Spec, UX analysis, Technical
Design, the KB) into a test design: reusable test cases per story, ordered test scenarios that reference them, and the
canonical JSON + a reader-first HTML document. A second **top-up** mode proposes additions for chosen stories against an
existing suite (D11). Read-only against Appian (F3). Clone the shape of `feature-breakdown-analysis`
(`workflows/feature-breakdown-analysis/graph.py`, `workflow.yaml`).

## 2. Inputs (`inputs_schema`)

Required: `feature_id`, `app_uuid`, `stage_id`, `stories_path` (JSON written by genesis, §4.1), `spec_path`,
`uxdesign_path`, `techdesign_path`. Optional: `mode` ∈ `design` (default) · `topup`; `existing_path` (top-up only: the
current suite tree, §4.3); `target_story_keys` (top-up only, JSON array of `GNS_` keys); `notes`; `doc1..doc3`
(`format: file`, ADR-035; F1). `required_mcp: [genesis-kb, appian-dev]`; read-only namespaced allowlists
(`@genesis-kb/search_objects`, `get_object_detail`, `get_dependencies`, `get_bundle`, `search_bundles`,
`get_entry_points_for_object`; `@appian-dev/` read tools only for the critic's spot-checks). `auto_approve: true`,
`hitl_points: [escalate]`, `healing: {max_heal: 1, max_restart: 1}`, `execution: {recursion_limit: 300}` (L-020).

## 3. Topology (+ a `graph:` block whose ids match the node names, L-006)

```
resolve_inputs → load_inputs → plan_epics (program) → next_epic ⇄ design_cases[v_cases] → advance_epic
   → compose_scenarios[v_scenarios] → assemble (program) → verify[v_verify] → verify_route
   → (ok) present → cleanup → END
   → (heal) heal[v_heal] → heal_route → patch: reassemble → verify | restart: plan_epics | escalate (gate)
```

| Node | Kind | Does |
|---|---|---|
| `resolve_inputs` | program | Fail fast on missing inputs, an empty `stories_path`, a top-up without `existing_path`/targets. |
| `load_inputs` | program | Materialize spec/UX/TD (HTML → text), stories, existing suite, notes, docs into the blackboard as **files** (L-042). |
| `plan_epics` | program | Group stories by epic (the breakdown's epics = TD workstreams). Top-up: keep only target stories' epics. Builds the epic queue. **No agent** — the grouping already exists. |
| `next_epic` / `advance_epic` | program | Queue-pop loop; stamps the iteration label; resets the loop node's retry counter per iteration. |
| `design_cases` | agent | For ONE epic: write the test cases for each of its **Story**-type stories from their Gherkin acceptance criteria (positive, negative, boundary as the AC warrant), each with `stories` (`GNS_` keys) and `objects` (`{uuid?, name, type}` resolved via `@genesis-kb/search_objects`; NEW objects named as in the TD, no UUID). Tasks get no own cases (D14). Untestable AC → `openQuestions` / `storySuggestions`. Top-up: sees the existing cases and must not duplicate them. |
| `v_cases` | validator | Per case: non-empty title; ≥ 1 `when` and ≥ 1 `then`; valid `type`/`priority`; ≥ 1 story key that is in this epic; objects have name + type. Every Story of the epic has ≥ 1 case. |
| `compose_scenarios` | agent | ONE turn over the whole case pool (+ existing scenarios in top-up): build ordered scenarios = end-to-end flows as **ordered case refs**; may add a few `end-to-end` cases a flow needs (same fields). Emits mostly refs (L-064). |
| `v_scenarios` | validator | Every ref resolves (to a new case `ref` or an existing `TC-` key in top-up); each scenario ≥ 2 steps or explicitly single-step with a reason; every new case used by ≥ 1 scenario (top-up: by a new or an existing scenario). |
| `assemble` | program | Build canonical `test-design.json` (§4.2) and render `test-design.html` (§5). Top-up: build `proposals.json` (§4.3) instead and a short `topup.html` summary. Self-check invariants. |
| `verify` | agent | Grounded coverage critic: every Story's AC covered by ≥ 1 case; expected results observable; no invented scope vs Spec/TD; object names plausible (spot-check genesis-kb). Emits a VerificationReport keyed by case/scenario ref. |
| `heal` / `reassemble` | agent / program | `attach_healing` (ADR-067): patch only flagged cases/scenarios in place → re-verify; else one guided restart; else escalate. |
| `present` / `cleanup` | program | `result.json`; delete tool-output scratch, keep declared artifacts. |

Every agent node wears the ADR-011 trio (`attach_reliability`); blocking writes off the loop (L-026); large tool
results saved by reference (L-021); outputs parsed defensively (L-023). `graph.py` self-contained, no
`from __future__ import annotations` with reducer keys (L-022).

## 4. Contracts (the genesis side — 49-04 — depends on these exactly; L-011)

### 4.1 `stories.json` (written by genesis)

`{"feature": {"id", "name"}, "epics": [{"id", "key", "title", "workstream"}], "stories": [{"id", "key": "GNS_000123",
"epic_id", "title", "story_type": "Story"|"Task", "description", "acceptance_criteria": [str], "dev_note_ref",
"appian_part"}]}` — only non-deleted finalized stories, in position order.

### 4.2 `test-design.json` (design mode; also embedded in the HTML)

```json
{"metadata": {"featureId": 7, "featureName": "…", "sources": ["spec", "ux", "td", "stories"], "mode": "design"},
 "cases": [{"ref": "case-1", "epicId": 3, "title": "…",
            "gherkin": {"given": ["…"], "when": ["…"], "then": ["…"]},
            "type": "positive|negative|boundary|end-to-end", "priority": "high|medium|low",
            "stories": ["GNS_000123"],
            "objects": [{"uuid": "…|null", "name": "…", "type": "Interface"}]}],
 "scenarios": [{"ref": "scn-1", "title": "…", "description": "…", "steps": ["case-3", "case-1"]}],
 "openQuestions": ["…"],
 "storySuggestions": [{"story": "GNS_000123", "note": "…"}]}
```

`ref`s are run-local and positional (renumbered on re-run); real ids are allocated only at Finalize (D4, F10).

### 4.3 Top-up: `existing.json` in, `proposals.json` out

`existing.json` = the genesis suite tree (`{cases: [{key, title, gherkin, stories, status}], scenarios: [{key, title,
steps: [case keys]}]}`, non-retired only). `proposals.json`:
`{"items": [{"ref": "p-1", "kind": "new_case", "case": {…as 4.2…}},
{"ref": "p-2", "kind": "new_scenario", "scenario": {"title", "description", "steps": ["TC-000004", "p-1"]}},
{"ref": "p-3", "kind": "add_step", "scenario": "TS-000002", "case": "p-1|TC-…", "position": 3}]}`. A `new_scenario`
or `add_step` that references a `new_case` proposal depends on it; genesis rejects the dependant when the user rejects
its dependency (49-04 §6).

## 5. The HTML artifact (`test-design.html`)

Lavish-safe like the breakdown (ADR-043, ADR-059): a summary header (counts by type/priority, stories covered /
uncovered, open questions); a **Scenarios** view (each scenario a `<details>` card listing its steps in order, each step
showing `ref` · title · Given/When/Then); a **Cases** view grouped by epic → story (cases used by several scenarios show
"used in N scenarios"); a CSS-only view toggle — **no JavaScript**; the canonical JSON in
`<script id="genesis-test-design" type="application/json">`. Open questions and story suggestions in their own section.

## 6. Tests (workflow `tests/`)

META ↔ `workflow.yaml` parity (`validate_library`); topology test (every node reachable; graph ids = node names);
validators accept good / reject each bad shape (a case with no `then`, a scenario ref that doesn't resolve, an
uncovered Story, a Task-only epic producing zero cases is OK); `assemble` produces JSON + HTML with the embedded block,
zero `<script>` other than it, stable ordering; top-up mode produces only `proposals.json` and never re-emits existing
cases; healing bounds from META. Use real story shapes (Gherkin AC strings, `GNS_` keys) in fixtures (L-083).

## 7. Registry

`registry.json` entry `{id: test-design-analysis, name: "Test Design Analysis", version: 0.1.0, roles: [developer,
tester, product-owner], required_mcp: [genesis-kb, appian-dev], …}`; run label "Test Design Preparation".

## Context manifest

```toml
areas    = ["workflows-library", "core-engine", "features-stages"]
adrs     = ["ADR-001", "ADR-010", "ADR-011", "ADR-018", "ADR-021", "ADR-035", "ADR-037", "ADR-043", "ADR-059", "ADR-067", "ADR-069"]
lessons  = ["L-006", "L-011", "L-013", "L-020", "L-021", "L-022", "L-023", "L-026", "L-042", "L-064", "L-075", "L-076", "L-083"]
code     = ["genesis-workflows/workflows/test-design-analysis/**", "genesis-workflows/workflows/feature-breakdown-analysis/**",
            "genesis-workflows/registry.json"]
docs     = ["tracker:specs/phase-49-test-design/49-01-findings.md"]
upstream = []
```
