# 30-03 — The `technical-design-analysis` workflow (genesis-workflows)

> **Status:** ✅ BUILT LOCALLY (2026-09-03; genesis-workflows master, unreleased) — gates green: validate_library 11 + ruff + workflows pytest 126 (19 new). Gate: independent review = SHIP (30-06). · Part of Phase 30. Repo: **genesis-workflows**.

## Purpose

Build the deterministic `technical-design-analysis` LangGraph workflow — the meat of the phase. Clone the
`ux-design-analysis` skeleton; the flow, prompts, and validators follow 30-02.

## Deliverables

- `workflows/technical-design-analysis/graph.py` — the graph, prompts, validators, pure helpers (self-contained;
  reach the platform only via `ctx`).
- `workflows/technical-design-analysis/workflow.yaml` — META mirror (parity lint).
- `workflows/technical-design-analysis/tests/test_workflow.py` — validator + prompt + graph-shape tests
  (stub agents; assert against the real artifact shapes — the §7 "stub hid the contract" rule).
- `registry.json` entry + a managed `genesis-kb` mcp-registry entry (already added for UX — reuse); META
  `required_mcp: ["genesis-kb","appian-dev"]`.

## Graph (per 30-02 §A)

`resolve_inputs → load_inputs → plan_sections →[v_plan]→ analyze_section (loop) →[v_analysis]→
draft_section (loop) →[v_design]→ assemble →[v_doc]→ verify →[v_verify]→ route_verify →(ok) present`;
`route_verify →(revise, bounded) draft_section/assemble`; `→(exhausted) escalate`.

- **Constants:** `MAX_WORKSTREAMS` (≈12), `MAX_VERIFY_ROUNDS` (2), read-only allowlists `KB_RO` (get_app_overview,
  search_objects, get_object_detail, get_dependencies, get_dependents_batch, get_precedents_batch,
  get_transitive_dependencies, get_dependency_path, get_hub_objects, get_shared_objects,
  get_entry_points_for_object, get_object_code) + `DEV_RO` (listApplicationObjects, getRecordType,
  getInterface, getExpressionRule, getProcessModel, getConstant, getSite, getWebApi, getObjectDependents,
  listRecordTypes, listInterfaces, listExpressionRules) — namespaced `@server/tool`.
- **Program nodes:** `resolve_inputs` (require spec_path + uxdesign_path present [the prerequisite]; dev env +
  KB sync fail-fast — reuse the UX helper), `load_inputs` (spec.txt + uxdesign.txt via `_strip_html` +
  comment.txt), `route_verify` (verdict + retry-reset + round bump), `present` (result.json + decisions).
- **Loop cursor:** `decisions.section_index` + `decisions.section_count`; `analyze_section`/`draft_section`
  read the current workstream from `sections.json`; a program router advances the index until done, resetting
  the loop node's retry counter each iteration.
- **Agents (reliability trio each):** `plan_sections` (mcp=[]), `analyze_section` (genesis-kb+appian-dev),
  `draft_section` (mcp=[] — designs off the accumulated grounding; may re-query if a gap is found — 30-06
  decides whether draft gets live tools), `assemble` (agent, mcp=[] — coherence pass), `verify` (genesis-kb+appian-dev,
  grounded critic).

## Prompts (intent — finalized against a dry-run in 30-06)

- **`plan_sections`** — "Read the SPEC, the UX Implementation Analysis, and the user's COMMENT. Decompose the
  work into functional WORKSTREAMS (the feature's scope items — e.g. 'Add Vendor', 'SLG support'), in a
  sensible build order. Output a JSON array `[{workstream, objective, scope_notes}]`. Do not invent scope not
  implied by the inputs."
- **`analyze_section`** — "For workstream «{name}», ground in the LIVE Appian app. Use @genesis-kb for
  structure/dependencies/blast-radius and @appian-dev to READ the actual records/tables/process models/
  interfaces/expression rules involved. Describe precisely **what already exists and how it is configured**
  for this area (name the real objects). Output `{workstream, existing:[{object, kind, what_it_does_today}],
  notes}`. Save large tool output BY REFERENCE. Do not fabricate — if nothing exists yet, say so."
- **`draft_section`** — "For workstream «{name}», using the SPEC + UX analysis + the EXISTING-STATE analysis,
  write the technical design as HTML. Group the changes: DB Changes (data-model table for new tables),
  Record Changes, Process Changes, UI Changes, Expression Rule Changes, Integrations. Each change MUST name a
  real existing object (from the existing-state analysis) or be marked **NEW**. Add a Complex designs note and
  numbered Open Questions for anything you are unsure of — do NOT assume. Output the workstream's HTML block."
- **`assemble`** (agent) — stitch the per-workstream blocks into the full `technical-design.html` per the 30-01 skeleton (Overview + per-workstream sections + global Complex Designs + Open Questions): a coherence pass (dedup, consistent headings/ordering, the global roll-up), reader-first — not a mechanical concat.
- **`verify`** — "Grounded critic. Re-check `technical-design.html` against the SPEC + UX + EXISTING-STATE and
  spot-check the live app (@genesis-kb/@appian-dev). Flag: ungrounded/assumed changes, object names that don't
  exist (and aren't marked NEW), missing change-groups, missing per-workstream/global sections, and Open
  Questions that are actually answerable by grounding (should have been researched). Output `{ok:bool, fixes:[…]}`."

## Validators

`check_plan`, `check_analysis`, `check_design`, `check_doc`, `check_verify` per 30-02 §B — each defensively
`_coerce_json` (real tool output varies — §7).

## Tests

Stub the agents to emit canned artifacts; assert each validator accepts the good shape + rejects the failure
shapes; assert the graph compiles + the loop advances + `route_verify` branches; assert `resolve_inputs`
fail-fast on a missing prerequisite/dev-env/KB-sync. Target parity: `ci/validate_library.py` (11 workflows) +
the workflow's own pytest.

## Gate

Independent review = SHIP: read-only allowlists correct, reliability trio on every agent, loop retry-reset,
grounded critic, save-by-reference, validators mirror real shapes.
