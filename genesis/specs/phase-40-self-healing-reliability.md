# Phase 40 — Self-Healing Reliability (grounded verification → targeted heal → bounded restart)

> **Status:** 🟡 **DRAFT — spec only; awaiting user sign-off at 40-01 before any build.** ADR-067 (Proposed). Umbrella + `phase-40-self-healing-reliability/40-01..40-06`. · **Author:** Genesis agent (2026-09-10)
> **Type:** multi-repo — **genesis-core** (a new, first-class **`attach_healing` reliability construct** + the `VerificationReport`/`HealDecision` contracts + a carry-forward-guidance convention + `META.healing` bounds + a reliability-lint extension), **genesis-workflows** (adopt it in **all four** analysis workflows — `verify` emits structured fixes; a new `heal` node; the deterministic re-assemble + restart wiring). genesis (minor: render the new nodes on the run graph). kiro-agent-sdk / genesis-appian-parser **unchanged**. · **Depends on:** ADR-011 (the reliability trio — this is its **second tier**), Phase 30/31/34 (the four workflows with `verify → route_verify → escalate`), Phase 09 (blackboard artifacts), Phase 39's `_iteration`/pass convention (shared "pass" label).

---

## 1. Why this phase exists

When a workflow's grounded critic (`verify`) fails the assembled artifact, **the fix today is wasteful**. Grounded
in the code:
- **`feature-breakdown-analysis`:** `_route_verify` **resets the aggregate and re-queues ALL epics** → the entire
  per-epic MAP loop re-runs from scratch (≈N agent turns) even if **one story in one epic** failed. The critic's
  fixes *are* passed to `break_epic`, but as a **coarse global list applied to every epic**, so correct epics are
  regenerated too — burning credits to reproduce the same output.
- **`technical-design-analysis`** and **`story-design-analysis`:** revise routes back to **`synthesize`** only —
  but the per-section/per-object blocks are **frozen** in `design_sections.json`/`design_objects.json`, so a fix
  that targets a specific section's content **cannot be applied** by re-running synthesize → it re-runs, the
  critic fails again, and it escalates. Wasteful *and* ineffective.
- **`ux-design-analysis`:** revise → `synthesize` re-authors the whole HTML in one turn.

None of them do the sensible thing: **look at the specific validation failures and correct only those**, redoing
everything **only as a genuine last resort**. Credits are a first-class cost in Genesis (ADR-032) and this is the
single largest avoidable waste in the platform.

**This phase adds a second reliability tier — grounded verification + cost-aware self-healing — as a solid,
reusable genesis-core construct** that all four workflows adopt. The existing per-node **reliability trio
(ADR-011)** stays exactly as-is (node-output validation + retry + escalation). The new tier operates on the
**assembled artifact**: a grounded critic emits **structured, sourced fixes**; a **healer agent** judges the blast
radius and either **patches the flagged items in place** (cheap) or, when the damage is large, **restarts the
workflow once with carry-forward guidance** so the second full pass gets it right; a bounded ladder ends at the
**HITL escalation gate**. This is the established **generate → critique → refine (reflection)** pattern with an
**LLM-as-judge** and a **cost-aware local-repair-vs-regenerate** policy.

---

## 2. Goal

1. **A first-class genesis-core reliability construct — `attach_healing(...)`** — a sibling of `attach_reliability`
   that wires the verify → heal → (patch | restart) → re-verify → escalate loop, with bounded budgets. Both the
   `verify` and `heal` nodes are agent nodes that themselves wear the ADR-011 trio (so healing sits **alongside**
   the trio, satisfying it).
2. **A structured verification contract.** `verify` stops emitting free-text and emits a **`VerificationReport`**:
   `{ok, summary, fixes:[{target_id, issue, reason, evidence, suggested_change, severity}]}` — each fix keyed to a
   specific artifact item (a story id, a section id, an object id, a screen id).
3. **A healer agent that judges blast radius.** Runs after `verify` with the **full context** (the source inputs +
   the current artifact + the fixes). It decides:
   - **small** relative to the artifact → **patch only the flagged items in place** → deterministic re-assemble →
     re-verify. The healer patches **at most once**; if it still fails → restart.
   - **large / structural** → **do not patch**; **restart the whole workflow once**, injecting **carry-forward
     guidance** (distilled from the fixes) into the restarting agents' prompts so the second full pass is correct.
4. **A bounded, credit-safe ladder** ending at the human: `verify fail → heal`: `patch once → re-verify`; if still
   failing **or** the healer judged *large* → `one guided restart → re-verify`; if it **still** fails → **escalate
   to the HITL gate**. At most **1 in-place heal + 1 guided restart**, then a human.
5. **Adopt it in all four** analysis workflows (`feature-breakdown`, `technical-design`, `story-design`,
   `ux-design`), each supplying its own verify prompt, heal prompt + artifact-patch method, deterministic
   re-assemble, and restart re-entry + guidance injection.

**Success = a `verify` failure on 2 stories of a 40-story backlog is fixed by a single cheap healer turn that edits
just those 2 stories and re-verifies green — instead of re-breaking all 10 epics — and a genuinely broken plan
escalates to a human after exactly one guided full restart, never looping.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-10)

1. **A `healer` node runs after `verify`** and does the correcting; the verifier produces a **rich structured
   fixes document** (reasons + sources), not free text.
2. **The healer is an agent** with the **complete context** (source inputs + current artifact + fixes) — it is the
   intelligence that decides and repairs.
3. **The healer judges blast radius itself** (agent judgment, with explicit guidance): small → heal in place;
   large → restart the whole workflow.
4. **Heal in place at most once.** If a single in-place heal + re-verify still fails → restart the workflow.
5. **On restart, the healer injects carry-forward guidance** (from the fixes) into the restarting agents so the
   second full pass does it right.
6. **Bounded ladder:** 1 in-place heal + 1 guided full restart → then **escalate to the HITL gate** (Q2a).
7. **This is a core concept → it lives in genesis-core**, built solid and reusable, **as part of / alongside the
   reliability trio** (a second tier). Each workflow plugs in its content (Q2d).
8. **All four workflows** adopt it (Q2c/scope).

---

## 4. Current state (what we build on) — code-grounded

- **The reliability trio (`genesis-core/nodes/reliability.py::attach_reliability`).** `agent → validator →
  (pass→nxt | retry→agent [retries[agent] ≤ max] | escalate→gate)`; the wrapped validator increments
  `retries[agent]` and emits `validator.result`/`retry.scheduled`; on retry the agent's `prompt_fn` reads
  `state["_validation"][v]["message"]`. **This is the model the new tier mirrors** (a graph-wiring helper +
  a state-carried feedback convention). It stays unchanged.
- **The four workflows share a shape:** `… → assemble (deterministic program) → verify (grounded critic agent,
  trio-wrapped, writes verify.json {ok, fixes}) → v_verify → route_verify (program) → {ok→present, revise→<loop
  or synthesize>, escalate→gate}`. `MAX_VERIFY_ROUNDS = 2`. `verify.json` is already `{ok, fixes:[strings]}` and
  the revise prompt already appends the fixes — so the **contract upgrade to structured fixes + a heal node** is
  an evolution of an existing seam, not a greenfield.
- **feature-breakdown** `_route_verify` re-queues `list(state["epics"])` (full redo); **TD/story-design** revise →
  `synthesize` (frozen blocks); **ux-design** revise → `synthesize`. Each has an `escalate` `hitl_gate` already.
- **Artifacts are addressable:** `backlog.json` has `epic-N` / `story-N-M` ids; TD/story-design per-section/object
  blocks live in `design_sections.json`/`design_objects.json` (need stable ids added). Deterministic re-assemble
  from the granular JSON already exists (`_assemble`/`_build_document`).
- **`META`** already carries `retry_defaults:{max}` + `execution:{recursion_limit}` — `healing:{max_heal,
  max_restart}` slots in the same way.

**Takeaway:** genesis-core gains `attach_healing` + the two contracts + a `guidance` state convention +
`META.healing` + a lint rule; each workflow (a) upgrades `verify` to emit a `VerificationReport`, (b) adds a
`heal` agent (trio-wrapped) with a heal prompt + an artifact-patch method, (c) keeps its deterministic
re-assemble, (d) declares its restart re-entry node + how guidance is injected. Replaces the current
`route_verify → revise` wiring.

---

## 5. The genesis-core construct (finalized in 40-01/02)

- **`genesis_core/nodes/healing.py::attach_healing(g, *, verify, heal, reassemble, restart_target, nxt, gate,
  retry_max, max_heal=1, max_restart=1, verdict_artifact="verify.json", guidance_key="_healing")`** wires:
  ```
  <assemble> → verify(agent, trio) → v_verify → route_verify(program)
     ok        → nxt (present)
     not ok    → heal(agent, trio): emit HealDecision →
                   mode=patch  (heals_used < max_heal)   → reassemble(program) → verify
                   mode=restart (restarts_used < max_restart) → set guidance → restart_target
     budgets exhausted / still failing → gate (escalate)
  ```
  `verify` and `heal` are `Node`s the caller builds with `kiro_node`; `attach_healing` internally wraps **each**
  with `attach_reliability` (validator + retry + escalation) so ADR-011 holds for both. Deterministic
  `reassemble` is a program node the caller supplies. Bounds come from `META.healing`.
- **Contracts (`genesis_core/`):** `VerificationReport = {ok:bool, summary:str, fixes:[Fix]}`;
  `Fix = {target_id:str, issue:str, reason:str, evidence:str, suggested_change:str, severity:str}`;
  `HealDecision = {mode:"patch"|"restart", rationale:str, guidance:str|None}`. Provided as typed helpers +
  validators (mirroring `genesis_core.validators`), so every workflow's `verify`/`heal` output is checked the same
  way (the "stub hid the contract" lesson — validate the real shape).
- **Carry-forward guidance convention:** on a restart, `route`/`heal` writes `state[guidance_key]["guidance"]`; the
  restart-target's agents read it in their `prompt_fn` (exactly like the trio's `_validation` message). Documented
  in the workflow-authoring standard.
- **Reliability lint (extension):** `genesis/lint/reliability.py` — a workflow whose terminal grounded `verify`
  feeds a route SHOULD pair it with a `heal` (warn/optional — decided in 40-01) so the pattern is enforced, not
  ad-hoc.
- **Observability:** emit canonical events (`verify.result`, `heal.decision{mode}`, `heal.applied`,
  `workflow.restart{pass}`) so Phase 39's turn explorer labels the pass correctly (shared `pass` counter).

---

## 6. Per-workflow adoption (finalized in 40-03/04)

Each workflow supplies four things to `attach_healing`:

| Workflow | verify (structured fixes over…) | heal patch target | deterministic re-assemble | restart re-entry (+ guidance) |
|---|---|---|---|---|
| **feature-breakdown** | `backlog.json` epics/stories (ids exist) | edit the flagged `story-N-M` / `epic-N` in the per-epic aggregate | `_assemble` (backlog.json + breakdown.html) | `plan_epics` (guidance in `plan_epics_prompt`/`break_epic_prompt`) |
| **technical-design** | `design_sections.json` (add stable section ids) | edit the flagged section block | the deterministic `assemble` | `plan_sections` (guidance in the plan/draft prompts) |
| **story-design** | `design_objects.json` (add stable object ids) | edit the flagged object block | the deterministic `assemble` | `plan_objects` (guidance in the plan/design prompts) |
| **ux-design** | `analysis.html` per-screen (screen ids) | edit the flagged screen section | (re-render if structured; else heal edits HTML) | `screen_inventory` (guidance in synthesize prompt) |

The healer prompt is uniform in shape (given the artifact + the `VerificationReport`, decide patch-vs-restart, and
if patch, return the corrected granular items) but workflow-specific in its artifact vocabulary.

---

## 7. ADR

- **ADR-067 (PROPOSED — this phase): Grounded artifact verification & cost-aware self-healing — the second
  reliability tier.** Complements **ADR-011**: the per-node trio validates a single turn's output; this tier
  validates the **assembled artifact** and **corrects it cheaply**. A genesis-core **`attach_healing`** construct
  wires `verify (grounded critic) → heal (agent judges blast radius) → {patch-in-place → re-verify | one guided
  restart} → escalate`, bounded by `META.healing {max_heal:1, max_restart:1}`; `verify`/`heal` are agent nodes
  each wearing the trio. A **`VerificationReport`** (item-keyed, sourced fixes) + a **`HealDecision`** contract +
  a **carry-forward-guidance** state convention are core primitives; a reliability-lint rule keeps a terminal
  verify paired with a heal. All four analysis workflows adopt it, replacing the wasteful "revise re-runs
  everything." Credit-safety (ADR-032) is the motivating constraint. Mirror in `reference/decision-log.md` +
  (on Accept) `bible/04`.

---

## 8. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **40-01** | Pattern design, contracts & ADR | Lock the `attach_healing` signature + the `VerificationReport`/`HealDecision` contracts + the guidance convention + `META.healing` bounds + the escalation ladder + the lint rule; draft **ADR-067**; document the workflow plug-in contract. **Docs only.** | ⭐ user sign-off → build |
| **40-02** | genesis-core: the construct | `nodes/healing.py::attach_healing` + the contracts/validators + the guidance convention + `META.healing` parsing + the reliability-lint extension; unit tests with fake verify/heal agents (patch path, restart path, budget exhaustion → gate). Additive; `CORE_MAJOR` unchanged. | independent review = SHIP |
| **40-03** | feature-breakdown adoption | Upgrade `verify` → `VerificationReport`; add the `heal` agent (patch flagged stories/epics) + heal prompt; deterministic re-assemble reused; `plan_epics`/`break_epic` read carry-forward guidance; rewire via `attach_healing`; tests (2-story-failure → single heal turn; large → 1 restart → gate). | independent review = SHIP |
| **40-04** | technical-design + story-design + ux-design adoption | Add stable section/object/screen ids; upgrade each `verify`; add each `heal` (patch the flagged block) + guidance-on-restart; rewire via `attach_healing`; tests each. | independent review = SHIP |
| **40-05** | Code review & hardening | Independent review (credit-safety — no unbounded loops; the 1-heal/1-restart ladder; structured-fixes contract validated; heal-agent context completeness; each artifact's patch correctness; the ADR-011 trio still wraps verify+heal; run-graph renders the new nodes/passes; live-acceptance notes on a real failing run). Apply SHOULD-FIX. | review clean |
| **40-06** | Coordinated release | genesis-core vX.Y.Z → genesis vX.Y.0 (re-pin; run-graph tweak) → genesis-workflows vX.Y.0 (all four adopt); tags; CI green; docs (bible §2/§3/§4/§7 + tracker + progress + ADR-067 → Accepted). | CI green |

**Suggested order:** 40-01 → 40-02 → 40-03 (prove on the worst case) → 40-04 (fan out) → 40-05 → 40-06.

---

## 9. Release plan

Multi-repo, ADR-019 order: **genesis-core → genesis → genesis-workflows**. genesis-core is additive
(`CORE_MAJOR` unchanged; `attach_healing` sits beside `attach_reliability`). No genesis.db migration. Per
sub-phase: build → gates (genesis-core pytest+ruff; genesis-workflows `validate_library` + pytest; genesis
pytest+web if the graph tweak lands) → local commit → independent review → docs; **no tag/push until 40-06** on
the user's go-ahead. Land the pattern on **feature-breakdown first** (the worst case) before fanning out.

---

## 10. Scope

**In scope:** the genesis-core `attach_healing` construct + `VerificationReport`/`HealDecision` contracts +
carry-forward-guidance convention + `META.healing` bounds + the reliability-lint extension + healing events; the
adoption in all four analysis workflows (structured verify, a heal agent per workflow, deterministic re-assemble,
guided single restart); a minor run-graph render of the new nodes/passes.

**Out of scope:** changing the per-node reliability trio (ADR-011 unchanged); more than one in-place heal or more
than one guided restart (bounded by design); healing non-analysis workflows (hello-appian/erd/code-review/sync —
they have no grounded-artifact verify tier); auto-tuning the blast-radius threshold with telemetry (future);
multi-artifact cross-workflow healing.

---

## 11. Open questions

None blocking — the approach is approved (2026-09-10): a genesis-core second-tier `attach_healing`; a healer
agent that judges blast radius; 1 in-place heal + 1 guided restart → escalate; all four workflows. Detail
decisions for 40-01: the exact `HealDecision` "small vs large" guidance wording; whether the reliability-lint rule
is warn vs error; the stable-id scheme for TD/story-design section/object blocks.
