# 31-03 — The `feature-breakdown-analysis` workflow (genesis-workflows)

> **Status:** ✅ SHIPPED (2026-09-04; genesis v0.59.0 + genesis-workflows v0.15.0, CI green). · Part of Phase 31. Repo: **genesis-workflows**.

## Purpose

Build the deterministic `feature-breakdown-analysis` LangGraph workflow — the core of the phase. Clone the
`technical-design-analysis` skeleton; the flow, prompts, and validators follow 31-02.

## Deliverables

- `workflows/feature-breakdown-analysis/graph.py` — the graph, prompts, validators, pure helpers (self-contained;
  reach the platform only via `ctx`; **no `from __future__ import annotations`** — the custom-state-key lesson).
- `workflows/feature-breakdown-analysis/workflow.yaml` — META mirror + the UI-only `graph:` topology (parity lint).
- `workflows/feature-breakdown-analysis/tests/test_workflow.py` — validator + prompt + graph-shape tests
  (stub agents; assert against the real artifact shapes — the "stub hid the contract" rule).
- `registry.json` entry; reuse the managed `genesis-kb` mcp-registry entry (already present);
  META `required_mcp: ["genesis-kb","appian-dev"]`.

## Graph (per 31-02 §A)

`resolve_inputs → load_inputs → plan_epics →[v_epics]→ start_breakdown → next_epic →(break) break_epic
→[v_stories]→ advance_epic → next_epic └─(done)→ assemble →[v_backlog]→ verify →[v_verify]→ route_verify
→(ok) present → cleanup → END`; `route_verify →(revise, bounded) break_epic; →(exhausted) escalate → cleanup → END`.

- **Constants:** `MAX_EPICS` (≈15), `MAX_VERIFY_ROUNDS` (2), read-only allowlists `KB_RO` + `DEV_RO`
  (reuse the TD set — namespaced `@server/tool`).
- **State:** `FBState(PlatformState, total=False)` with `epics: list`, `break_queue: list`, `current_epic: dict`.
- **Program nodes:** `resolve_inputs` (require spec_path + uxdesign_path + techdesign_path present [the 3-way
  prerequisite]; dev env + KB sync fail-fast — reuse the TD helpers), `load_inputs`
  (spec.txt/ux.txt/technical-design.txt via `_strip_html` + notes.txt + `attachments/<name>.txt` for each
  uploaded doc), `start_breakdown` (seed `break_queue` from `epics.json`), `next_epic`/`advance_epic` (map
  cursor; reset the loop node's retry counter each iteration), `assemble` (**deterministic** — build
  `backlog.json` from the per-epic `epic_stories.json` aggregate, then render `breakdown.html`; self-check
  invariants), `route_verify`, `present` (result.json + register artifact), `cleanup`.
- **Agents (reliability trio each):** `plan_epics` (mcp=[]), `break_epic` (genesis-kb+appian-dev, light
  spot-check), `verify` (genesis-kb+appian-dev, grounded critic). **`assemble` is a PROGRAM node** (no agent
  emits the big HTML).

## Prompts (intent — finalized against a dry-run in 31-06)

- **`plan_epics`** — "Read the SPEC, the UX Implementation Analysis, the TECHNICAL DESIGN, the user NOTES, and
  any ATTACHMENTS. The Technical Design is already decomposed into **functional workstreams** — derive the
  epics **1:1 from those workstreams** (reconcile with Spec scope + UX screens; don't invent scope). Output a
  JSON array `[{id, title, workstreamRef, summary}]`."
- **`break_epic`** — "For epic «{title}» (TD workstream «{workstreamRef}»), break it into Appian
  stories/tasks. RULES: a **form** → one story (split by section only when complex); a **process model** →
  a **separate** story; split by **entry point**; separate happy-path vs error; explicit edge-case,
  state/status stories; integration/config/operational stories; group notifications; flag nice-to-haves.
  Clarity over volume. Each item: `storyType` = **Story** (front-end testable) or **Task** (a backend/data-model/
  appref/process-only change a tester cannot validate from the UI); `description` = As-a/I-want/So-that;
  `acceptanceCriteria` = **Gherkin** Given/When/Then (a Task may have none); `devNoteRef` = a ONE-LINE pointer
  to this TD workstream (do NOT rewrite the technical detail — it's in the TD); `questions` = open questions;
  `category` = core|nice-to-have; `appianPart`; `labels`. Do a light @genesis-kb/@appian-dev spot-check only
  if a scope detail is genuinely unclear. Output the epic's stories as JSON."
- **`verify`** — "Grounded coverage critic. Re-check `backlog.json` against the SPEC scope + every Technical
  Design 'What changes' item: every one must map to ≥1 story/task; nothing invented; the form/process-model
  split is correct; Gherkin AC are testable + implementation-free; `devNoteRef`s point at real TD workstreams;
  nice-to-haves flagged; the uploaded docs' asks are represented; open questions surfaced. Output
  `{ok:bool, fixes:[…]}`."

## Validators

`check_epics`, `check_stories` (Gherkin AC on Stories; Task AC optional), `check_backlog`, `check_html`,
`check_verify` per 31-02 §C — each defensively `_coerce_json` (real tool output varies — the §7 lesson).

## `assemble` (deterministic) — the HTML + embedded JSON

Build `backlog.json` (validated, de-duplicated, ordered, sequential ids), then render `breakdown.html`:
summary header + `<details>` story cards grouped by epic + a CSS-only card↔table toggle (**no JS**) + the
embedded `<script type="application/json" id="genesis-backlog">`. `check_html` self-check in the node; fail
loudly on invariant violation (the TD `check_doc` lesson).

## Tests

Stub the agents to emit canned artifacts; assert each validator accepts the good shape + rejects the failure
shapes (esp. a Story with a non-Gherkin AC, a missing TD-workstream coverage); assert the graph compiles + the
epic loop advances + `route_verify` branches; assert `resolve_inputs` fail-fast on a missing prerequisite/
dev-env/KB-sync; assert `assemble` produces a well-formed HTML whose embedded JSON round-trips to `backlog.json`.
Target: `ci/validate_library.py` (12 workflows) + the workflow's own pytest.

## Gate

Independent review = SHIP: read-only allowlists correct, reliability trio on every agent, loop retry-reset,
grounded critic, deterministic assemble (no giant agent HTML), validators mirror real shapes, Gherkin AC +
Story/Task rule enforced.
