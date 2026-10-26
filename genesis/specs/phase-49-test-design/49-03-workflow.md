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

## As built (genesis-dev, 2026-10-26)

**Status:** ✅ DONE. Review **SHIP**, then SHIP again on the fix delta (`reviews/49-03-review.md`, incl. its "Re-review"
section). Committed locally only: not pushed, not tagged (49-09).

### Commits (genesis-workflows, base `a19153a`)

| Commit | Message |
|---|---|
| `325cc23` | feat(test-design-analysis): 0.1.0 - new workflow (Phase 49-03, ADR-078 proposed) |

No other repo changed (no genesis, genesis-core or SDK change; `heal_check` already exists in genesis-core v0.9.8).

### Changed

- `workflows/test-design-analysis/graph.py` (new): `META` (v0.1.0), `TDState(PlatformState)` (`epics`, `epic_queue`,
  `current_epic`), program nodes `_resolve_inputs`, `_load_inputs`, `_plan_epics`, `_next_epic`, `_advance_epic`,
  `_assemble`, `_reassemble`, `_present`, `_cleanup`; agent prompts `design_cases_prompt`, `compose_scenarios_prompt`,
  `verify_prompt`, `heal_prompt`; validators `check_cases` (v_cases), `check_scenarios` (v_scenarios), `check_heal`
  (v_heal, passed as `attach_healing(heal_check=)`), `check_suite`, `check_html`; normalizers `_norm_stories`,
  `_norm_existing`, `_norm_case`, `_tidy_suite`, `_normalize_suite`, `_apply_patches`; renderers `_build_test_design`,
  `_build_proposals`, `_build_document`, `_build_topup_document`. Topology exactly as §3; node names = `graph:` ids.
- `workflows/test-design-analysis/workflow.yaml` (new): mirrors META + the `graph:` block (every node described).
- `workflows/test-design-analysis/tests/test_workflow.py` (new) + `tests/fixtures/*.json` (8 golden files).
- `registry.json`: the `test-design-analysis` entry (§7).

Blackboard artifacts: `stories.json`, `existing.json`, `spec.txt`, `uxdesign.txt`, `techdesign.txt`, `notes.txt`,
`epics.json`, `case_pool.json`, `scenarios.json`, `suite.json` (the granular aggregate), `test-design.json` +
`test-design.html` (design) or `proposals.json` + `topup.html` (top-up), `verify.json`, `heal.json`, `result.json`
(+ the per-epic scratch `epic_cases.json`, kept by cleanup).

### Tests

- 75 tests in `workflows/test-design-analysis/tests/test_workflow.py`: input validation (design + top-up, epic cap,
  schema accepts the genesis launch shapes); program plan (Task-only epic skipped, top-up keeps target epics, orphan
  stories group); loop pump + retry resets; `v_cases` good + each bad shape §6 names (no `then`, no `when`, bad
  type/priority, unknown/other-epic story, object without type, uncovered Story, Task-only epic with zero cases OK,
  top-up duplicate of an existing case); `v_scenarios` (unresolved ref, unused case, single step without reason,
  e2e cases, top-up TC-/add-steps); assemble (JSON contract, HTML has exactly one `<script>` = the embedded JSON,
  no JS, stable ordering, escaping of agent text, uncovered stories, dangling steps dropped); top-up produces only
  `proposals.json` and never re-emits existing cases; heal patches (in-place, new case wired into a scenario, remove,
  add-step patches with clamped positions, `check_heal` rejects each bad patch); healing bounds from META; META ↔
  yaml parity; registry entry = META; topology (graph ids = node names, declared edges = compiled edges, every node
  reachable, every node described); build compiles. **Golden contract tests** drive `resolve_inputs` +
  `load_inputs` over `tests/fixtures/stories.json` / `existing.json` and assert `test-design.json` / `proposals.json`
  equal the fixture files exactly (L-011).
- Gates: `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures` → **331 passed** (256 + 75);
  `python ci/validate_library.py` → **PASSED (14 workflows)**; `ruff check workflows/test-design-analysis` → clean.

### Review

`genesis-review` SHIP on the first pass (no blockers/majors). Fixed before commit: **m1** (the heal patch path could
emit a case/scenario the validators reject → `check_heal` simulates the patch against the strengthened
`check_suite`), **m2** (on-disk golden fixtures), **n1** (`MAX_EPICS` 16 = breakdown cap 15 + orphan group), **n4**
(add-step position clamped to `len(steps)+1`), **n5** (binary upload placeholder names its path), **n6** (L-021 line in
every prompt), **n7** (top-up heal test), **r2** (replacement patches with unknown story keys or dangling steps are
rejected, not silently pruned). Re-review: SHIP. Left open: r1 (see Decisions 9), r3 (the wiring test reads the source
of `build`), n2/n3 (below), P1/P2 (lesson candidates).

### Decisions / deviations (spec refinements; no ADR deviation)

1. **Task-only epics get no agent turn.** `plan_epics` skips epics with no Story in scope (reported in
   `decisions.skipped_epics`); `v_cases` still accepts zero cases for one (§6). The HTML cases view still lists them.
2. **`suite.json` is the program-owned aggregate** for both modes, with run-local refs `case-N` / `scn-N` / `add-N`.
   verify/heal target those refs or a `GNS_` key (uncovered story); heal adds items as `new-case-N` / `new-scn-N` /
   `new-add-N` and drops them with `"remove": true`.
3. **proposals.json (for 49-04):** a `new_case` item's `case.ref` is its own `p-N`; a `new_scenario` step or an
   `add_step.case` that uses a new case names that `p-N` (the dependency). Additive top-level keys beside `items`:
   `metadata` (as 4.2, `mode: "topup"`), `openQuestions`, `storySuggestions`. `add_step.position` is 1-based and at most
   `len(existing steps)+1`.
4. **test-design.json (for 49-04):** exactly the §4.2 shape. `metadata.sources` gains `"uploaded-docs"` when docs were
   attached (n3; don't assert an exact list). A scenario's single-step reason is folded into `description` as
   `"Single step: …"` (no extra key). Case refs may have gaps after a heal removed a case; they are unique, not
   necessarily contiguous.
5. **Embedded block** is literally `<script id="genesis-test-design" type="application/json">` (id first, as §5
   writes it; the breakdown's parser regex is type-first, so 49-04 must match this order or be order-agnostic). Every
   `<` in the JSON is written as `\u003c`, so the page has exactly one `<script` even when agent text contains one;
   plain `json.loads` reads it.
6. **Bulk context as files (L-042):** spec/UX/TD/notes/all stories are named by blackboard path; the epic's stories +
   AC, the case-pool index, the suite and the report are inline. This is the first workflow that relies on agents
   opening files instead of inlined text — 49-08 should confirm `fs_read` calls in the turn explorer.
7. **Tools:** `design_cases`, `compose_scenarios` and `heal` get the six genesis-kb read tools of §2; only `verify`
   also gets the read-only appian-dev tools.
8. **Inputs:** `mode` is `type: string, enum [design, topup]` (no null — the web launch form renders an enum as a select);
   `target_story_keys` accepts an array, a JSON-array string or a CSV string; unknown/Task targets are ignored (recorded in
   `decisions.ignored_targets`), none valid → fail fast. `result.json.status` is `in-review` (design) or `proposed`
   (top-up).
9. **recursion_limit stays 300** as §2 says. The reviewer estimates the absolute worst case (every agent call at every
   epic exhausting its retries in both passes, at 16 epics) at ~300–320 supersteps (r1); raising it to 400 is free if a
   live run ever hits `GraphRecursionError`.
10. **No run-label mechanism exists** in genesis or the web app (§7's "Test Design Preparation" is stale, n2); the
    registry name is "Test Design Analysis".

### Lesson candidates

- **A `tests/__init__.py` in two workflow packages makes pytest import both as `tests.test_workflow`, so one file's
  tests run twice and the other's never run** (P1, pre-existing): in the CI full-library command,
  `generate-business-map`'s 11 tests are replaced by `feature-breakdown-analysis`'s 37. Fix (separate item): delete both
  `tests/__init__.py` files and add a CI guard on duplicate test module names. 49-03 ships without one.
- **A heal patch must be validated against the same invariants as the agent turn it corrects** — a generic
  HealDecision shape check lets a patch produce what `v_cases`/`v_scenarios` would reject. Simulate the patch on a copy
  and run the program invariants in a workflow `heal_check`.
- P2 (genesis-core follow-up): `attach_healing` never resets the verify/heal retry counters across a restart; after a
  patch + restart, a pass-2 verify failure still pays for a heal turn that can only escalate.

### Code-map changes

- Add under `genesis-workflows/`: `workflows/test-design-analysis/` — `graph.py` (META v0.1.0; program epic plan →
  per-epic `design_cases` loop → one `compose_scenarios` turn → deterministic `assemble` (suite.json → test-design.json
  + test-design.html, or proposals.json + topup.html) → `verify` + `attach_healing` with `check_heal`), `workflow.yaml`,
  `tests/fixtures/` (golden §4.1–4.3 contracts shared with genesis 49-04).
- `registry.json`: + `test-design-analysis` 0.1.0.
