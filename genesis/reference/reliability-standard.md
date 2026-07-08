# Genesis — Reliability Standard (the Hard Requirement)

This is the differentiator and the structural fix for solutions-copilot's failure
("agents kept missing steps"). It is a **hard requirement** (ADR-011, Q9),
enforced by library CI at publish time.

> **Rule:** Every agent node MUST be immediately followed by a program
> **validator**; on failure the agent **retries** (configurable count) with the
> validator's feedback; on exhaustion it **escalates to a HITL gate**. No agent
> output is ever consumed unchecked.

---

## 1. Why this exists

LangGraph guarantees the *sequence* runs deterministically — but an individual
agent node can still under-perform on its sub-task (wrong format, missing fields,
hallucinated values). Reliability = **narrow agent nodes + program validators +
retry + escalation**. The *program* decides "good enough," not the model. This is
what makes Genesis reliable where the agent-orchestrator was not.

---

## 2. The trio (pattern)

```
        ┌─────────────┐      ┌───────────────┐   pass    ┌────────┐
   ───▶ │ agent node  │ ───▶ │ validator     │ ────────▶ │  next  │
        │ (kiro_node) │      │ (program)     │           └────────┘
        └─────────────┘      └───────────────┘
              ▲                     │ fail
              │ retry (feedback)    ├── retries < max ──┐
              └─────────────────────┘                   │
                                    │ retries == max     ▼
                                    └────────────▶ hitl_gate(escalation)
```

- **Agent node** — narrow; writes output to a blackboard doc.
- **Validator** — deterministic checks on that artifact; returns `ValidationResult(ok, message, normalized?)`; routes `pass`/`fail`.
- **Retry** — re-runs the agent node with `state["_validation"][validator]["message"]` injected into the prompt so it self-corrects. Count from `META.retry_defaults.max` (or a per-node override).
- **Escalation** — on exhaustion, route to `hitl_gate(kind="escalation")`: a human sees the failures + last output and can edit state (HITL mode 3) and resume, approve-as-is, or abort.

Wired via `attach_reliability(g, agent=..., validator=..., retry_max=..., on_exhaust_gate=...)` — scaffolded by default.

---

## 3. What a validator checks (guidance)

- **Structural:** JSON parses; matches an expected schema; required keys/fields present.
- **Referential:** ids/UUIDs exist; foreign keys resolve; counts are plausible (e.g., #tables > 0).
- **Business rules:** domain ∈ allowed set; PK listed first; audit columns excluded; no empty required outputs.
- **Cross-artifact:** consistency with a prior artifact (e.g., every table in the schema appears in the enriched output).
- **For write-path (deferred):** confirm the mutation actually happened (re-read via LCP/Atlas/Jarvis). See §3.2.

Validators are **pure/deterministic** and unit-tested independently.

### 3.1 Validator toolkit — `genesis_core.validators` (batteries-included)

**The trio's only real authoring cost is writing a validator per agent node.** To
keep that from becoming the reason nobody authors workflows, the common library
ships a toolkit so that **~80% of validators are one-liners**. Authors compose
these instead of hand-writing checks. Each returns a `check_fn` (or a ready
`validator_node`) compatible with `attach_reliability`.

Generic validators (ship in Phase 1):
| Helper | Checks |
|---|---|
| `non_empty(artifact)` | the artifact doc exists and is non-empty |
| `parses_json(artifact)` | valid JSON |
| `json_schema(schema, artifact)` | matches a JSON Schema |
| `required_keys(keys, artifact)` | object contains all keys |
| `values_in_set(path, allowed, artifact)` | field value(s) ∈ allowed set (e.g., domain enum) |
| `count_between(path, min, max, artifact)` | list/number plausibility (e.g., #tables ≥ 1) |
| `first_field_is(path, name, artifact)` | ordering rules (e.g., PK listed first) |
| `excludes(path, names, artifact)` | forbidden items absent (e.g., audit columns) |
| `referential_integrity(child, parent, fk, pk)` | every FK in one artifact resolves to a PK in another |
| `all_items_present(source, target, key, artifacts)` | cross-artifact completeness (e.g., every source table appears in the enriched output) |
| `matches_predicate(fn, artifact)` | escape hatch for a custom deterministic check |

Composition:
| Helper | Behaviour |
|---|---|
| `all_of([...])` | pass only if all pass; aggregates failure messages (fed back on retry) |
| `any_of([...])` | pass if any passes |

Each helper produces an actionable failure `message` (e.g., "domain 'Foo' not in
allowed set; allowed: …") that is injected into the agent prompt on retry.

Example — a full validator in one line:
```python
attach_reliability(g, agent=assign_domains, retry_max=2, on_exhaust_gate="escalate",
  validator=validator_node(name="v_enriched", target_artifact="enriched.json",
    check_fn=all_of([
      parses_json("enriched.json"),
      all_items_present(source="schema.json", target="enriched.json", key="name"),
      values_in_set("tables[].domain", DOMAIN_NAMES, "enriched.json"),
      first_field_is("tables[].fields", "PK", "enriched.json"),
    ])))
```

### 3.2 Appian-object validators — DEFERRED to the development phase
Validators that confirm an Appian mutation by **re-reading** via LCP/Atlas/Jarvis
— e.g. `record_type_exists`, `fields_match`, `sail_compiles` — are **out of scope
for now**. They are added when we take on the actual Appian-object development
piece (Phase 8, write-path / Wave C), alongside the LCP-authoring unlock (OD-1).
Until then, write-path validators are not needed; the generic toolkit (§3.1)
covers all read/generation workflows.

---

## 4. Retry semantics

- `retries[agent.name]` increments each failed attempt.
- The agent prompt on retry must include the validator's `message` (actionable feedback: "add a WHERE clause", "domain X is not in the allowed set", "table Y missing").
- Retries are **bounded** (`retry_max`); never infinite.
- Idempotency: because the agent rewrites its blackboard doc each attempt and state carries only the pointer, retries are safe.

---

## 5. Escalation semantics

- Escalation is a **HITL gate** (`hitl-design.md` mode 1, `kind="escalation"`).
- The gate payload includes: the failing validator messages, the path to the last output artifact, and the retry history.
- Human options: **edit state/artifact + resume**, **approve as-is** (override), or **abort** the run.
- Escalation is preferred over silent failure or over producing unchecked output.

---

## 6. CI enforcement (Phase 2 — `genesis.lint.check_reliability`)

At publish time, the lint walks the compiled graph and asserts, for every node
with `_genesis_kind == "agent"`:
1. an immediate successor with `_genesis_kind == "validator"`;
2. a conditional edge from that validator back to the agent (retry);
3. a conditional edge from that validator to a `hitl_gate` or `END` (escalation).

Missing any ⇒ **build fails** — the workflow cannot be tagged/released. A
deliberately non-compliant fixture is kept in the library to prove the gate fails.

---

## 7. Configuration

- **Retry count** is configured per workflow (`META.retry_defaults.max`) and may
  be overridden per node. Chosen at authoring time (Q9).
- **Escalation target** defaults to a shared `escalation` gate but can be a
  workflow-specific gate with a tailored prompt.

---

## 8. Interaction with other guarantees

- **Durability:** each attempt is checkpointed; a crash mid-retry resumes correctly.
- **HITL:** escalation *is* HITL mode 1; the human may use mode 3 (state edit) at the gate.
- **Blackboard:** validators read the artifact from the blackboard, not from chat.
- **Observability:** validator results + retries stream to the UI (Phase 5) so the user sees why a node is retrying.
