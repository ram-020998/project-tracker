# 25-12 — AI Cost & Performance Pass

- **Status:** ⏸ BACKLOG (moved 2026-08-19) — data-driven cost pass; its measured-reduction core needs REAL run telemetry (headless-undrivable) + benefits from the 25-13 metrics substrate. Revisit with live credit data.
- _(orig)_ 📝 DRAFTED · **Review items:** §31 (Performance), §32 (Cost Efficiency) · **Roadmap:** Phase 5 · **Repos:** genesis-workflows, genesis · **Depends on:** nothing (can slot anytime; benefits from 25-13 metrics)

## 1. Goal
A measured pass to cut avoidable LLM spend and latency: replace LLM calls that should be deterministic code, trim oversized/duplicated context, and identify parallelizable agent steps — using Genesis's **real** credit data (ADR-032) as the evidence base.

## 2. Why (review evidence)
- **§31:** review flags large prompts, context duplication, synchronous long-running ops, unnecessary model calls.
- **§32:** "recommend where deterministic code should replace an LLM"; identify redundant calls, oversized contexts, expensive models for simple tasks.
- Genesis already **meters real per-turn credits** (ADR-032) — so this pass is *data-driven*, not guesswork.

## 3. Current state (cited)
- Credits are captured per turn (`agent.result` → `run_events` → `aggregate_credits`) and per chat message — the measurement substrate exists.
- Some agent nodes do work that is arguably deterministic (bible §7 Phase-12 lesson notes `_coerce_json`/`flatten_checklist` parsing already moved to code — good precedent). Candidate LLM-where-code-suffices spots: app matching (`design-doc` `_match_app` is already program — verify), JSON coercion, naming validation.
- Prompts embed context (research reconciliation, evidence packs) that may duplicate across turns.

## 4. Design (measure → target → verify)
### 4.1 Instrument & baseline
- Using the existing credit/telemetry data, produce a per-workflow, per-node **credit + context-% + duration** report (a one-off analysis script under `spike/` or a `genesis` report command). Rank nodes by cost.

### 4.2 Targeted reductions (only where measured)
- **Deterministic replacements:** any agent node whose job is parse/normalize/match/validate over structured tool output → move to a `program_node` (extends the Phase-12 `_coerce_json`/`flatten_checklist` precedent). Each replacement must preserve the validator contract.
- **Context trimming:** de-duplicate context injected every turn (e.g. evidence-pack excerpts, `./context/` files already on disk in feature_spec — don't also inline them); enforce bounded excerpt sizes in `build_evidence_pack`.
- **Model right-sizing:** where a node does a trivial transformation, use the cheapest capable model (per-node model hint) rather than the session default.
- **Parallelism:** independent research nodes (e.g. `design-doc` jarvis vs atlas research) that don't depend on each other → run concurrently in the graph (LangGraph supports parallel branches) where safe.

### 4.3 Guardrails
- A regression check that a targeted workflow's **credit total does not increase** (a soft budget assertion in the workflow test, tolerant band) — so future changes don't silently balloon cost.

## 5. Files touched
- **New:** an analysis script (`spike/2026-2X-cost-baseline.md` + script), optional `genesis` cost-report command; per-workflow credit-budget test assertions.
- **Edit:** targeted workflow `graph.py` nodes (agent→program where justified; parallel branches); `kb/*.build_evidence_pack` (bounded/de-duped context).

## 6. Tests
- Deterministic replacements: unit-tested pure functions (no LLM) with the same validator contract.
- Context-size test: evidence pack / prompt context stays under the bounded size.
- Budget guard: targeted workflow credit total within the expected band (stubbed credits).

## 7. Risks & mitigations
- **Risk:** replacing an LLM step with brittle parsing (bible §7 — real tool shapes vary). **Mitigation:** only replace where the shape is stable + validated against real captured artifacts; keep the validator.
- **Risk:** premature optimization (review §40 — don't optimize what doesn't need it). **Mitigation:** **measure first**; only touch nodes the data ranks as expensive.

## 8. Out of scope
Embeddings/pgvector (ADR-030 trigger); a full cost dashboard (25-13 surfaces metrics; this is targeted reductions).

## 9. Definition of Done
A credit/latency baseline report exists; the top measured offenders are reduced (deterministic replacement / context trim / right-sized model / parallelized) with unchanged validator contracts; per-workflow credit-budget guards added; releases CI-green; progress doc records the before/after credit delta.
