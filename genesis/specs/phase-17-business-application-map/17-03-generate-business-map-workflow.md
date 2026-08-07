# Phase 17-03 — `generate-business-map` workflow (the core)

> **Status:** ✅ SHIPPED (genesis-workflows v0.9.0) · **Repos:** genesis-workflows (pins the genesis tag carrying 17-01/17-02/17-04) · **Depends on:**
> 17-01 (persistence), 17-02 (evidence pack), 16-05 (`genesis-kb` MCP)
> **Goal:** The heart of Phase 17 — a **deterministic LangGraph workflow** that reads the KB, has narrow **agent** nodes
> synthesize the business model (B then A), enforces **evidence-grounding + coverage + business-language** guards, takes a
> **human review** gate, and **persists** the `BusinessModel v1`. This is the "workflow which creates the diagram."

---

## 1. Current state (grounded)
- Workflows are LangGraph graphs loaded standalone (`graph.py` self-contained; `META` static; `workflow.yaml` mirrors META;
  parity + reliability lints in CI). Agent nodes = `kiro_node` (per-node `mcp=` + `tools=`; effective trust =
  `node.tools ∩ server.allowlist`); the **reliability trio** (validator + retry + escalation) is mandatory + CI-enforced
  (ADR-011). Precedents: `sync-application` (deterministic program-only) and `design-doc` (dual-source research →
  synthesized Markdown) — this workflow is the synthesis pattern applied to the KB.
- The `genesis-kb` MCP (16-05) serves read-only KB tools; `KbStore` (17-01) persists the map; `build_evidence_pack` (17-02)
  builds the input.
- **Blocking `genesis.db` writes inside an async worker must run via `asyncio.to_thread`** (16-03 deadlock lesson).

## 2. Design
**Topology** (program plain, agent 🤖, validators `v_*`; reliability trio wraps each agent node):
```
resolve_inputs → extract_evidence → v_evidence
  → 🤖 synthesize_capabilities → v_capabilities
  → 🤖 synthesize_value_streams → v_value_streams
  → compose_model → v_model → review → persist_map → present
```
- **`resolve_inputs`** — inputs `{app_uuid|app_name, release_label?, review_mode?}`; require a completed baseline sync; pick
  `source_sync_id`; fail fast if unsynced.
- **`extract_evidence`** — call `build_evidence_pack` (17-02); write `evidence.json` to the blackboard (ADR-010/018 — bulk
  never inlined into state).
- **`v_evidence`** — schema + ≥1 entity + ≥1 activity.
- **`synthesize_capabilities`** 🤖 — MCP `[genesis-kb]`, read-tool allowlist only. Prompt: from the evidence pack, produce
  `summary`, `domain`, `entities`, `capabilities` (+ `capability_relations`), `actors`, each with `evidence.object_uuids`;
  **business language only**; may call `genesis-kb` to drill for specifics. Output persisted by reference (Phase-9 pattern) →
  `capabilities.json`.
- **`v_capabilities`** — JSON-schema + **evidence integrity** (every UUID exists in KB, via a `KbStore` batch existence
  check exposed to the workflow) + **coverage ≥ threshold** + **business-language guard** (banned tokens). (Rules =
  `business-model-contract.md` §4.)
- **`synthesize_value_streams`** 🤖 — MCP `[genesis-kb]`. Prompt: using the capabilities/entities + the activity flows,
  produce `value_streams` (ordered `stages` with `kind` + branches + `capability`/`entities`/`actor` + evidence). → `value_streams.json`.
- **`v_value_streams`** — schema + DAG well-formedness + decision-branch labels + evidence integrity + language guard.
- **`compose_model`** — program: assign stable ids, merge into `BusinessModel v1`, compute `coverage` (17-02 denominator +
  distinct evidence UUIDs), cross-ref integrity. → `business_model.json`.
- **`v_model`** — full-contract validation + coverage gate + cross-refs.
- **`review`** — HITL **approval** gate (ADR-021): human accepts or requests changes; validator escalations surface here with
  the specific failure. `META.auto_approve`/`review_mode` allows unattended regeneration.
- **`persist_map`** — **raw async node**: `await asyncio.to_thread(kb_store.upsert_business_map, …)` with `status='ready'`,
  `source_sync_id`, `run_id`, metered `credits`, `coverage`. (Store injected via `ctx.extras['kb_store']` — same wiring as
  `sync-application`.)
- **`present`** — summary + pointer + coverage + credits.

**Reliability:** validators feed retry (reset `retries[node]=0` semantics per the Phase-12 loop lesson if any node re-enters)
→ escalation to `review`. **Credits** are real (ADR-032) — only the two agent nodes cost credits; surfaced per-node + total.
**MCP:** only read-only `genesis-kb`; no env/write tools. **State small** (pointers + decisions), bulk in blackboard.

**Prompts/steering:** node prompts live in `graph.py` (self-contained) + a steering doc; they encode the KB→business
derivation guidance (contract §3) and the business-language rule. Tests **stub `genesis-kb` tool outputs with the REAL
`genesis-kb` shapes** (Phase-12 "stub hid the contract" lesson), and feed a captured evidence pack.

## 3. Definition of Done
- `META`/`workflow.yaml` parity + reliability-trio lint pass; `ci/validate_library.py` green; catalog `registry.json` entry
  added (with `graph:` topology for the catalog preview).
- Workflow tests (stubbed agent + real-shape tool stubs + a fixture evidence pack): happy path yields a schema-valid
  `BusinessModel`; an injected hallucinated UUID **fails** `v_capabilities`; a banned token **fails** the language guard; a
  dangling `next` **fails** `v_value_streams`; low coverage escalates; `persist_map` writes one `ready` row.
- Determinism: same evidence pack + stubbed agent → stable structural output. genesis-workflows pytest green.
- Manual live-acceptance (17-06): a real run against the synced app produces a sensible business map (human-eyeballed).
