# 25-10 — `reliable_agent_step()` Workflow Helper

- **Status:** ◑ CORE BUILT (2026-08-19, genesis-core commit `679ee73`; **SHIPPED genesis-core v0.9.5**) — `reliable_agent_step()` + `add_reliable_step()` shipped in genesis-core with +4 tests. **Workflow adoption + steering + LOC proof DEFERRED** (user 2026-08-19: "look at using this later") — and release-gated (genesis-workflows pins an older genesis-core without the helper; adoption needs a genesis-core release + repin). · **Review items:** §F, §28, §31 · **Roadmap:** Phase 2 · **Repos:** genesis-core, genesis-workflows · **Depends on:** nothing (composes with 25-05)

## As built (genesis-core, commit `679ee73`; 80 pytest [+4] + ruff green)
- **`genesis_core/nodes/reliable.py`:** `reliable_agent_step(...)` bundles `kiro_node` agent + `validator_node` + retry/escalation into a `ReliableStep` (the ADR-011 trio **by construction**); `add_reliable_step(g, step, nxt=, on_exhaust_gate=)` wires it via the unchanged `attach_reliability`. Supports `validator_name`/`target_artifact` so an existing step's exact node name + artifact are preserved on adoption. Exported from `genesis_core`.
- **Tests:** structural (trio kinds/retry/gate) + stubbed-collect **end-to-end** (retry-on-fail → escalate-on-exhaustion, retry-then-pass) via the 25-05 provider seam — no real Kiro.
- **Purely additive:** the primitives + the CI reliability lint (`genesis/lint/reliability.py`) are unchanged.

## Deferred (to a later release)
- **Workflow adoption + LOC proof.** Verified constraint: every workflow uses **bespoke validator names + `target_artifact`s** and `design-doc` has **non-uniform routing** (KB-freshness/mockup→i18n/open-questions branches) — the spec's §7 "unusual topology → keep the primitives" case, so a `design-doc` retrofit is high-risk / marginal-LOC. Recommendation at release: adopt in **hello-appian** (1 clean trio) as the concrete proof, or steering-only + opportunistic migration. **Also release-gated** (needs genesis-core shipped with the helper + genesis-workflows repin).

## 1. Goal
Provide a composition helper that bundles the **reliability trio** (agent node + validator + retry + escalation) into a single call, cutting the hand-wired boilerplate every workflow repeats — without changing the CI-enforced invariant or the node model.

## 2. Why (review evidence)
- **§F "New agent step":** rated **Easy–Medium** because it's *hand-wired per workflow* — `design-doc/graph.py` wires **11 `kiro_node` + 11 `validator_node` + `attach_reliability`** triples by hand (~880 LOC). The ergonomics tax scales with every new workflow/stage.
- **§28 Open/Closed / §31 duplication:** the trio is duplicated structurally across all 7 workflows. A helper reduces the surface where a mistake omits a validator/escalation (ADR-011 is CI-enforced, but the helper makes the *right* thing the *easy* thing).

## 3. Current state (cited)
- `genesis-core/nodes/`: `kiro_node`, `validator_node`, `hitl_gate`, `attach_reliability` — all factory functions returning `Node` (good composition).
- Every workflow's `build(ctx)` manually creates the agent node, its validator, an escalation gate, and calls `attach_reliability(...)` + wires edges. `genesis-workflows/steering/` documents the pattern but doesn't reduce it.

## 4. Design
### 4.1 The helper (`genesis-core/nodes/reliable.py` — NEW)
```python
def reliable_agent_step(
    *, name, prompt_fn, output_doc, mcp=(), tools=(),
    check_fn, target_artifact,
    retries=2, escalation_gate="escalate",
    turn_timeout=420, startup_timeout=120,
) -> ReliableStep:  # returns the agent node + validator node + the wiring metadata
```
- Returns a small `ReliableStep` bundle (agent node, validator node, and the edges/retry/escalation config) that `build(ctx)` adds with one `graph.add_reliable_step(step)` convenience (or the workflow adds the returned nodes/edges).
- Encodes the ADR-011 trio **by construction** — you cannot get an agent step without its validator + escalation.
- **Purely additive:** existing `kiro_node`/`validator_node`/`attach_reliability` stay; workflows adopt the helper incrementally. The reliability **lint** (`genesis/lint/reliability.py`) is unchanged and still the enforcement authority.

### 4.2 Adopt in one workflow as proof
- Refactor `design-doc` (the worst offender at ~880 LOC) to use `reliable_agent_step` for its 11 agent steps; measure the LOC reduction; the workflow's behavior + contract (`workflow.yaml`↔META) unchanged.

## 5. Files touched
- **New:** `genesis-core/nodes/reliable.py`, `genesis-core/tests/test_reliable_step.py`.
- **Edit:** `genesis-core/nodes/__init__.py` (export), `genesis-workflows/workflows/design-doc/graph.py` (adopt), `genesis-workflows/steering/*` (document the helper as the recommended pattern).

## 6. Tests
- The helper produces a node set that passes `genesis/lint/reliability.py` (trio present).
- A stubbed-collect graph test runs a `reliable_agent_step` end-to-end (retry on validator fail → escalate on exhaustion), reusing `set_collect_impl`/the 25-05 provider seam.
- `design-doc` contract/parity + existing workflow tests pass unchanged.

## 7. Risks & mitigations
- **Risk:** the `from __future__ import annotations` + standalone-load reducer-key gotcha (bible §7). **Mitigation:** the helper lives in genesis-core (not in a workflow `graph.py`), so the standalone-import annotation trap doesn't apply; workflows still import it normally.
- **Risk:** over-generalizing. **Mitigation:** the helper covers the common trio only; unusual topologies keep using the primitives directly.

## 8. Out of scope
Rewriting all 7 workflows (adopt design-doc as proof; others migrate opportunistically); changing the reliability lint.

## 9. Definition of Done
`reliable_agent_step` shipped in genesis-core; `design-doc` adopts it with a measured LOC drop and unchanged behavior; reliability lint still green; genesis-core + genesis-workflows releases CI-green; steering docs + `bible/03` updated; progress doc.
