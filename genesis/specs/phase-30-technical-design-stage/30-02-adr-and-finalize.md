# 30-02 — ADR & finalize (Technical Design stage)

> **Status:** 📋 DRAFT. **Docs only.** Gate: ⭐ user sign-off → build. · Part of Phase 30.

## Purpose

Lock the design and draft the ADRs. Turns 30-01's research + format study into the exact contracts 30-03/04/05
build against.

## A. Locked workflow node graph (`technical-design-analysis`)

```
START → resolve_inputs → load_inputs → plan_sections →[v_plan]→
        analyze_section →[v_analysis]→ (loop: next workstream?) → analyze_section
                                       └─(all analyzed)→ draft_section →[v_design]→
        (loop: next workstream?) → draft_section
        └─(all drafted)→ assemble →[v_doc]→ verify →[v_verify]→ route_verify
        route_verify →(ok) present → END
        route_verify →(revise, bounded MAX_VERIFY_ROUNDS) draft_section/assemble
        route_verify →(exhausted) escalate → END
        any agent exhaustion → escalate.
```

- **Looping** via a `section_index` cursor in `decisions` (mirrors `code-review`'s per-item loop); the loop
  node **resets its retry counter** each iteration (`retries[node]=0`) — the §7 lesson. Bound the workstream
  count (e.g. ≤ 12) + the total via the worker `recursion_limit` (from META).
- **Grounding split (D3, as UX):** `@genesis-kb` = structure/deps/blast-radius; `@appian-dev` = read the
  actual code. Read-only namespaced allowlists. Save-by-reference for bulk output.
- **`assemble`:** decide program vs light-agent coherence pass against a real dry-run (umbrella §14.1).

## B. Validators (deterministic)

- `v_plan` — `sections.json` is a non-empty array; each `{workstream, objective}` present.
- `v_analysis` — the current workstream's existing-state record cites ≥1 real object ref (resolvable via
  genesis-kb/appian-dev) OR is explicitly "new area, nothing exists"; no fabricated refs.
- `v_design` — the current workstream's draft has the change-groups present-or-"none" (DB/Record/Process/UI/
  Expression-rule/Integration), each change naming a real object or marked NEW.
- `v_doc` — `technical-design.html` ≥ min length; contains the skeleton sections (Overview, per-workstream
  `<h2>` ≥1, Complex Designs, Open Questions).
- `v_verify` — `verify.json` is an object with a boolean `ok` (+ `fixes` list).

## C. Inputs schema (`workflow.yaml` ↔ META parity)

`required: [feature_id, app_uuid, stage_id, spec_path, uxdesign_path]`, optional `comment` (string). No
`format:"file"` input (unlike UX) — the start endpoint passes the two artifact paths + the comment.

## D. Prerequisite gating (ADR-056 amendment)

- Frontend: `StageDescriptor.requires: StageKey[]` + `deriveAvailability(detail)`; `design.requires =
  ["spec","ux"]`; "available" iff both prerequisite stages have an artifact at `in-review`/`completed`. A
  locked card ("Complete Spec & UX Design first") + a blocked workspace state.
- Backend: the JSON start endpoint 409s if either prerequisite artifact is missing/too-early; `resolve_inputs`
  fails fast on absent `spec_path`/`uxdesign_path`.

## E. Entry + re-run

- Entry (prerequisites met): a "both artifacts are ready" panel + an **optional comment** textarea + **Start**
  → `POST /features/{id}/stages/technical_design/start` `{comment}` → launch → the shared in-progress screen.
- Re-run: `POST …/technical_design/reupload`-analog (JSON `{comment}`) → `StageStore.reset_for_reupload` +
  relaunch (confirm dialog: "replaces the current Technical Design + its chat"). From the stage header + the
  Overview card.

## F. StageFinalizer generalization

Replace the hard-coded `WORKFLOW_ID`/`_ARTIFACT`/`mode`/`_seed` with a small **binding registry**:
`{ "ux-design-analysis": {stage:"ux_design", artifact:"analysis.html", chat_mode:"ux_design", seed:_seed_ux},
   "technical-design-analysis": {stage:"technical_design", artifact:"technical-design.html",
   chat_mode:"technical_design", seed:_seed_td} }`. `_observe`/`reconcile`/`reconcile_stage`/`_finalize` look
up the binding by `rec.workflow_id`; the currently-bound-run guard (v0.56.2) is preserved. One finalizer serves
both stages.

## G. `technical_design` chat mode

A `ChatModeProfile` cloned from `ux_design` (read-only genesis-kb + appian-dev + sandboxed fs-write) with a new
`_STEERING_TD`: "You are Genesis Technical Design Analyst… a workflow drafted `technical-design.html` from the
Spec, the UX Implementation Analysis, and the live app… walk the Open Questions one at a time; as the user
answers, revise exactly that part and rewrite `technical-design.html`; re-check the live app (genesis-kb +
appian-dev) on request; you MUST ground every claim in the real app and MUST NOT assume — surface uncertainty
as an Open Question; read-only, write only inside your working directory." Add `technical_design` to the
`chat/store.py` mode whitelist.

## H. ADR drafts

- **ADR-058 (PROPOSED)** — as stated in the umbrella §10 (the grounded, workstream-decomposed Technical Design
  stage; read-only; object-level; two grounded loops + grounded critic; reuse of the Phase-29 surface;
  genesis + genesis-workflows only, no migration).
- **ADR-056 amendment** — a stage MAY declare prerequisite stages (`StageDescriptor.requires`), enforced UI +
  backend; the parallel model otherwise stands.

## Deliverable / gate

The locked graph + validators + schema + gating + entry/re-run + StageFinalizer plan + `_STEERING_TD` draft +
the two ADR drafts, signed off by the user → build (30-03).
