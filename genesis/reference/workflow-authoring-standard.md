# Genesis — Workflow Authoring Standard

The canonical standard every workflow must follow (successor to solutions-copilot's
skill-design-standard). The scaffolder + library CI make most of this automatic;
this doc is the "why" and the checklist. Authoring steering in
`genesis-workflows/steering/` is the hands-on companion.

---

## 1. Principles

1. **One workflow = one SDLC task.** Keep scope tight; compose larger flows via subgraphs.
2. **Determinism belongs to the graph; judgment to the agent.** If a step *can* be a program, it **must** be (ADR-001/018).
3. **Narrow agent nodes.** An agent node does one judgment or one data-fetch — never "do the whole workflow."
4. **Every agent node is validated.** Program validators decide "good enough," not the agent (hard requirement — see `reliability-standard.md`).
5. **Bulk in the blackboard, small in state.** Never push large data through chat or state (ADR-010/018).
6. **Reference MCP/CLI by name** from the shared registries; never define servers ad hoc.
7. **Gate mutations.** Any write/deploy step is preceded by a **`pre_mutation`** HITL gate. This is one of the three sanctioned pause classes (see principle 9); it is **required**, not optional.
8. **Fidelity when migrating.** Port skill references as the design source; reuse their instructions in agent prompts (Phase 8).
9. **Auto-approve by default.** `META.auto_approve = true` — validated steps auto-advance. A run pauses **only** at the three sanctioned classes: (a) author approval gates (`hitl_points`), (b) escalations (retry exhaustion), (c) pre-mutation. Gating anything else creates approver fatigue and is rejected in review/CI.

---

## 2. Required package contents (the contract — ADR-012)

```
workflows/<id>/
  workflow.yaml     # metadata (mirrors META)
  graph.py          # META (static) + build(ctx) -> CompiledStateGraph
  nodes.py          # node implementations (program/agent/cli/validator)
  prompts/          # agent-node prompt builders
  tests/            # unit + stubbed-graph tests
```

`graph.py` must expose:
- `META` — importable with **no side effects** (the app reads it for the catalog + prereq checks).
- `build(ctx: PlatformContext) -> CompiledStateGraph` — construct the graph only; no I/O.

`META` / `workflow.yaml` fields:
`id, name, version, roles[], summary, inputs_schema (JSON Schema), required_mcp[],
required_cli[], hitl_points[], auto_approve (default true), retry_defaults{max},
artifacts[], editable[]?`.

CI checks `META` ≡ `workflow.yaml` (drift fails the build).

---

## 3. Authoring workflow (steps)

1. `genesis create-workflow` → scaffold (reliability trio pre-wired).
2. Decompose the task into steps; classify **program vs agent** (default program).
3. Define state (extend `PlatformState` with a few small fields).
4. Map data flow → blackboard docs (`state.artifacts`), decisions → `state.decisions`.
5. Implement program nodes (pure, unit-tested).
6. Implement agent nodes: `kiro_node(prompt_fn, output_doc, mcp=[...])`; agent writes to `output_doc`; keep it narrow.
7. Add a validator after each agent node; wire retry + escalation via `attach_reliability` (usually already scaffolded). **Compose the validator from `genesis_core.validators`** — most validators are one-liners (`all_of([...])` of toolkit checks); hand-write a `matches_predicate` only for genuinely custom logic.
8. Add HITL approval gates at human decision points and before any mutation.
9. Add conditional edges for branches (generate/update, dry-run, etc.).
10. Write tests; run `genesis test-workflow`.
11. Open MR → library CI enforces the standard → tag/publish.

---

## 4. Prompt guidelines for agent nodes

- Tell the agent to **write its output to the exact blackboard path** provided; reply only `DONE` (no bulk in chat) — the lesson from the ERD POC.
- For data-fetch nodes: **dump raw tool output verbatim** to a file; let a program normalize it (don't ask the agent to transcribe/transform bulk data).
- For judgment nodes: ask for **compact decisions** (a mapping, a list of choices), not reconstructed bulk data.
- On retry, incorporate `state["_validation"][validator]["message"]` so the agent self-corrects.
- Keep prompts deterministic in structure; avoid open-ended "do everything."

---

## 5. Testing requirements (see `testing-strategy.md`)

- Unit tests for every program node + validator (pure functions).
- A **stubbed-graph test**: inject canned agent outputs; assert the graph reaches the right artifacts/state, hits gates, and escalates on forced validator failure.
- Optional live/integration test (marked; needs real creds).
- Local `genesis test-workflow` must pass before MR.

---

## 6. The publish checklist (enforced by CI — Phase 2)

- [ ] `graph.py` imports; `META` importable with no side effects; `META` ≡ `workflow.yaml`.
- [ ] Every agent node has a validator successor + retry edge + escalation edge (**reliability lint**).
- [ ] Every `required_mcp`/`required_cli` exists in the registries.
- [ ] No node pushes bulk into state (state-size guard).
- [ ] Mutating steps are preceded by a HITL approval gate.
- [ ] Tests pass.
- [ ] `roles`, `summary`, `inputs_schema` present (catalog quality).
- [ ] For migrations: `MIGRATION.md` row updated (skill → workflow → status).

---

## 7. Anti-patterns (rejected in review)

- ❌ An agent node that "does the whole workflow."
- ❌ Returning large data from an agent via chat / putting it in state.
- ❌ Agent output consumed without a validator.
- ❌ Ad-hoc MCP server definitions inside a workflow.
- ❌ A write/deploy step with no approval gate.
- ❌ Chaining agent nodes with no program validation between them ("telephone game").
- ❌ Over-gating: pausing on steps that are not (a) author approvals, (b) escalations, or (c) pre-mutation — this creates approver fatigue (violates `auto_approve` default).


## Self-healing (the second reliability tier — `attach_healing`, ADR-067)

Beyond the mandatory per-node reliability trio (`attach_reliability`, ADR-011), a workflow that assembles an
**artifact** and validates it with a grounded critic SHOULD use **`attach_healing`** (genesis-core) instead of
a hand-wired `verify → route → revise` loop. It replaces the wasteful "a verify failure re-does the whole
workflow" (credit-safety, ADR-032) with a bounded, cost-aware heal:

```
attach_healing(g, *, verify, heal, reassemble, restart_target, nxt, gate, retry_max,
               max_heal=1, max_restart=1)          # bounds come from META.healing
```

wires `verify(agent) → verify_route → {ok → nxt | not-ok → heal(agent) → heal_route → {patch → reassemble →
verify | one guided restart → restart_target | budgets spent → gate}}`, wrapping **both** `verify` and `heal`
with the trio. Author contract:

- **`verify`** emits a **`VerificationReport`** `{ok, summary, fixes:[{target_id, issue, reason, evidence,
  suggested_change, severity}]}` — each fix keyed to a **stable artifact item id** (e.g. `story-N-M`,
  `section-N`, `object-N`, `screen-N`). Give your granular blocks stable ids so fixes are addressable.
- **`heal`** (full context: sources + current artifact + the report) emits a **`HealDecision`**
  `{mode:"patch"|"restart", rationale, patches:[corrected items with id] | guidance}`. `patch` = local blast
  radius (correct only the flagged items); `restart` = structural (re-do from the plan).
- **`reassemble`** (a deterministic program you supply) merges the healer's `patches` into your granular
  aggregate **by id** (only the flagged items change) and re-renders the artifact → re-verify.
- **Carry-forward guidance convention:** on a restart, `attach_healing` writes `state["_healing"]["guidance"]`;
  the **restart-target's agent prompts read it via `read_guidance(state)`** (mirrors the trio's
  `state["_validation"][v]["message"]` self-correction) and prepend a "CARRY-FORWARD GUIDANCE" block only when
  non-empty. On a non-restart run it is empty (no stale injection).
- **`META.healing {max_heal, max_restart}`** (default `{1, 1}`) bounds the ladder; add `heal.json` to
  `META.artifacts` and declare the `verify/v_verify/verify_route/heal/v_heal/heal_route/reassemble` nodes +
  their edges in the `workflow.yaml` `graph:` topology (the run-detail graph renders them).
- **Credit-safety (do not regress):** the budget counters live in the reserved `_healing` state channel, which
  MUST be a **per-key-merge** reducer (never whole-dict last-writer) so a restart can't erase `heals_used` and
  loop forever. The ladder always terminates at the HITL escalation gate. See bible §7.
