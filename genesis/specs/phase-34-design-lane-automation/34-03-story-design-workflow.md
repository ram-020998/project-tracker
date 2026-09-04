# 34-03 — The `story-design-analysis` workflow ("Appian Ticket Design")

> **Status:** ✅ SHIPPED (genesis v0.62.0 + genesis-workflows v0.16.0). · Part of Phase 34. Repo: **genesis-workflows**. · **Depends on:** 34-01 (I/O contract), ADR-058 (`technical-design-analysis` — the template), ADR-011 (reliability trio), ADR-036/037 (read-only grounding), ADR-057 (grounding split genesis-kb=structure / appian-dev=code).

## Purpose

The ticket-level, object-level, **code-grounded** design workflow. Mirrors `technical-design-analysis`'s proven
map-reduce shape but scoped to **one story** with **object-level detail + actual code** (Q6). Every agent node
wears the reliability trio; a grounded critic verifies; assembly is deterministic (the Phase-30 "don't emit a
huge doc in one turn" lesson).

## Graph

```
START → resolve_inputs → load_inputs
  → gather_context   [agent] → v_context
  → plan_objects     [agent] → v_plan → start_objects → next_object
       ├─(object) design_object [agent, @genesis-kb+@appian-dev RO] → v_object → advance_object → next_object
       └─(all)     → synthesize [agent] → v_synth
  → assemble  [program, DETERMINISTIC]
  → verify    [agent, @genesis-kb+@appian-dev RO] → v_verify → route_verify
  route_verify →(ok) present → cleanup → END
               →(revise ≤2) synthesize ; →(exhausted) escalate → cleanup → END
```

Reuse the TD file's helpers verbatim where possible: `_coerce_json`, `_read`, `_strip_html`, `_read_html_file`,
`_esc`, `_sanitize_block`, `_build_document`-style deterministic assembly, `cleanup`, the retry-reset on
`route_verify`, `resolve_inputs` fail-fast. **No `from __future__ import annotations`** (custom state keys —
the §7 loader lesson). `META['execution']['recursion_limit']` raised (~250) for the object loop.

## Nodes

- **`resolve_inputs`** (program) — require `story_id, feature_id, app_uuid, story_stage_id, spec_path,
  uxdesign_path, techdesign_path, story`; **fail-fast** if no dev-tagged env (`ctx.environments.dev_environment()`)
  or the app is not synced (`ctx.extras['kb_store'].get_application(app_uuid)`), with a clear message (Q5).
- **`load_inputs`** (program) — materialize `spec.txt`, `uxdesign.txt`, `techdesign.txt` (HTML→text via
  `_read_html_file`) + `story.json` (the ticket fields).
- **`gather_context`** (agent, no MCP) → `research.json` — read the three docs + the story; extract **ONLY**
  what THIS ticket needs: the relevant spec requirements, the UX behavior, and the **Technical Design excerpts**
  the story's `dev_note_ref` points into. Output `{relevant_spec:[], relevant_ux:[], relevant_td:[],
  objects_hint:[]}`. `v_context` = non-empty, names at least the TD anchor(s).
- **`plan_objects`** (agent, no MCP) → `objects.json` — the list of Appian objects to create/modify for this
  ticket: `[{object:<real or proposed name>, kind:<RecordType|Interface|ExpressionRule|ProcessModel|Constant|
  Integration|CDT|Table|…>, change_type:"NEW"|"UPDATE", why:<one line, grounded in research>}]`. `v_plan` =
  non-empty; each has object+kind+change_type∈{NEW,UPDATE}. Bound the count (e.g. ≤ 20).
- **`design_object`** (agent, `@genesis-kb`+`@appian-dev` read-only) → `design_object.html` (one block) — for
  the current object: ground the **actual current code** (`@appian-dev` getters) + structure/impact
  (`@genesis-kb`); write the block:
  - `<section>` with `<h2>{object}</h2>` + a `<span class="tag">NEW</span>`/`<span class="tag">UPDATE</span>`.
  - **What exists today** (for UPDATE — from the real code; NEW says so).
  - **What changes** — granular; **and the CODE** for every code-level change/addition in `<pre><code>`
    (expression-rule SAIL, interface SAIL, DDL for tables/columns, constant values, integration config).
  - **Process models (Q6 — mandatory, NOT summarized):** for a ProcessModel object, a **per-node** list —
    each node: what it does + the code for any node that needs code (script-task expression, sub-process
    inputs, gateway conditions). Never collapse a process model into a paragraph.
  - **Open questions** (`[Gap]/[Assumption]/[Decision]/[Cross-Story]`).
  - GROUND every claim; never assume — surface uncertainty as an Open Question. Save large tool output
    **by reference** (`save_tool_output`). `v_object` = block present, has the tag + a code block or an explicit
    "no code change", + an Open-questions subsection.
- **`synthesize`** (agent, no MCP) → `synthesis.json` — bounded cross-cutting only: `overview_html` (how the
  objects fit together for this ticket) + `sequencing_html` (build/deploy order, cross-object risks, shared
  objects). Small output. `v_synth` = non-empty `overview_html`.
- **`assemble`** (program, DETERMINISTIC) → `design.html` — stitch each `design_object` block (verbatim,
  sanitized, once, in plan order, each in its own `<section id="objN">`), wrap the Overview + Sequencing +
  a consolidated global Open Questions; one well-formed **Lavish-safe** HTML doc (no JS). Self-check structural
  invariants (exactly one skeleton; the sections present; per-object sections) and raise on violation.
- **`verify`** (agent, `@genesis-kb`+`@appian-dev` RO) → `verify.json` `{ok, fixes:[]}` — grounded critic:
  flags an object/code that references something not in the live app and not marked NEW; ungrounded/assumed
  code that should be an Open Question; a planned object missing from the doc; missing per-node detail on a
  process model; answerable Open Questions. `ok` only if no material problem.
- **`route_verify`** (program) — ok → present; else revise (≤ `MAX_VERIFY_ROUNDS`=2, resetting `synthesize`/
  `verify` retries) → synthesize; else escalate.
- **`present`** (program) → `result.json` `{artifact:'design.html', story_id, story_stage_id,
  status:'in-review', object_count, verify_verdict}`; `status='done'`.
- **`cleanup`** (program) — delete `_toolcalls/` + non-artifact scratch; preserve `META['artifacts']`.
- **`escalate`** (hitl_gate, kind `escalation`) — grounded critic couldn't confirm after 2 rounds.

## META (workflow.yaml + META mirror)

`id: story-design-analysis` · `name: "Appian Ticket Design"` · `version: 0.1.0` · `roles:[developer,architect]`
· `required_mcp:[genesis-kb, appian-dev]` · `hitl_points:[escalate]` · `auto_approve:true` ·
`retry_defaults:{max:2}` · `execution:{recursion_limit:250}` · `artifacts:[spec.txt, uxdesign.txt,
techdesign.txt, story.json, research.json, objects.json, design_object.html, design_objects.json,
synthesis.json, design.html, verify.json, result.json]` · `editable:[inputs, decisions]`. Read-only allowlists
reused from TD (`KB_RO` + `DEV_RO`, namespaced `@server/tool`). `registry.json` gains the entry.

## Tests

`tests/test_workflow.py` (stubbed agents; no real Kiro/MCP), mirroring the TD suite: the graph builds; the
object map loop + retry-reset; the deterministic `assemble` produces one well-formed doc from stub blocks
(no stray `</body>`; per-object sections; NEW/UPDATE tags); `check_*` validators (plan/object/synthesis/verify/
doc) reject the bad shapes; `resolve_inputs` fail-fast on no dev env / not synced. `validate_library` green.

## Gate

`validate_library` + workflows pytest green; independent review = SHIP → proceed to 34-04.
