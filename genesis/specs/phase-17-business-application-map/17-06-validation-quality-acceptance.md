# Phase 17-06 — Validation, quality & acceptance

> **Status:** ✅ SHIPPED — friendly 409 (genesis v0.39.0) + coverage recalibration 0.6→0.3 (genesis-workflows v0.9.1); live-accepted. · **Repos:** genesis-workflows (+ genesis) · **Depends on:** 17-03 (workflow), 17-05 (web)
> **Goal:** Make the Business Map **trustworthy and good**. Harden the evidence-grounding / coverage / business-language
> validators, lock quality with golden fixtures + guardrails, wire the human review gate, and run the manual live-acceptance
> against the real synced application. This is the "does it actually explain the business, and can we trust it?" phase.

---

## 0. Live findings (2026-08-07 — first real generation)

The first live generation (against the 2,763-object **"AS GSS Full Application"**) **passed the acceptance intent**:
the agent produced a coherent, business-language model (domain *"Procurement source selection and proposal
evaluation"*; **10 capabilities, 10 entities, 5 actors, a 14-stage value stream** with two real decision branches;
6.07 credits) with **no technical vocabulary**. It surfaced concrete hardening work for this sub-phase:

1. **Friendly "workflow not installed" error.** `POST …/business-map/generate` returned a raw **500** when the
   `generate-business-map` workflow wasn't yet in the local library (it must be `genesis install`-ed after release).
   Fix: the endpoint catches the loader failure and returns a **409/400** with actionable guidance ("install the
   workflow library"), not a 500.
2. **Recalibrate coverage.** The (genuinely good) map scored coverage **0.355** vs the `COVERAGE_MIN = 0.6` gate, so it
   correctly routed to the **review** gate (approved). But 0.355-for-a-good-map means the metric likely **over-counts**
   the denominator (`significant = entities ∪ activities`, capped) relative to what a *readable* map should reference.
   Re-tune: either lower the default threshold, or narrow the denominator to truly central objects, or count a stage's
   capability/entity coverage rather than raw object uuids. Keep the human review gate as the backstop.
3. **Rendering acceptance = separate from data acceptance.** The model was rich but the first render (v0.36.0) was
   unreadable; readability shipped in **v0.37.0/v0.38.0** (see `progress/phase-17-business-application-map.md` + the two
   §7 lessons in `AGENT_ONBOARDING.md`). Acceptance must check *both* the model quality and the rendered readability.

## 1. Current state (grounded)
- 17-03 ships the workflow with the `v_*` validators and a `review` gate; 17-05 ships the view. The contract's validation
  rules live in `business-model-contract.md` §4. A real synced app (`AiDocumentCenter`) is available for acceptance. Live
  Kiro/agent runs can't be driven headlessly — acceptance is a documented manual checklist (bible §8).

## 2. Design / work
- **Harden the validators** (`business-model-contract.md` §4): evidence integrity via a batch `KbStore` existence check (not
  per-UUID round-trips); coverage computed by `compose_model` (un-gameable); the business-language banned-token guard as a
  shared, tested predicate; DAG well-formedness (reachability, no dangling/cycle, decision branch labels); sanity-bound
  warnings surfaced to `review`.
- **Golden fixtures (determinism/quality).** Capture a real evidence pack from the synced app → commit as a fixture; a test
  feeds it through the composition/validation with a **recorded** agent output and asserts a schema-valid, well-formed,
  fully-grounded `BusinessModel` (guards drift the way Phase-16 golden contract fixtures do). Negative fixtures: hallucinated
  UUID, banned token, dangling `next`, low coverage → each fails the expected validator.
- **Review-gate UX** (if not fully in 17-05): the approval card shows the summary, coverage, sanity warnings, and any
  escalation reason; accept persists, request-changes loops with feedback.
- **Quality guardrails** (soft, tunable): capability count 3–12, ≤ ~25 stages/stream, prefer ≤ 3 value streams — warn, don't
  hard-fail; documented for the human reviewer.
- **Manual live-acceptance checklist** (documented, run once): sync `AiDocumentCenter` → generate → verify the map reads as a
  coherent **business** story (a non-technical reader understands what the app does), no technical vocabulary leaks, coverage
  is reasonable, decision branches make business sense, credits are metered and shown, regenerate + stale both work. Record
  the outcome in `progress/phase-17-*`.

## 3. Definition of Done
- All validators enforce the contract §4 rules with tests (positive golden + the four negative fixtures); shared
  language-guard predicate unit-tested; coverage math tested.
- Determinism test green (fixture pack + recorded agent → stable structural model). genesis-workflows + genesis pytest green;
  `ruff`/`tsc`/`eslint` clean; CI green.
- The manual live-acceptance checklist is executed against the real app and its outcome recorded in the progress doc; Phase 17
  marked shipped in `tracker.md` §6, the specs' status headers, README, and `AGENT_ONBOARDING.md` (§2/§9).
