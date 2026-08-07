# Phase 17-06 — Validation, quality & acceptance

> **Status:** DRAFT · **Repos:** genesis-workflows (+ genesis) · **Depends on:** 17-03 (workflow), 17-05 (web)
> **Goal:** Make the Business Map **trustworthy and good**. Harden the evidence-grounding / coverage / business-language
> validators, lock quality with golden fixtures + guardrails, wire the human review gate, and run the manual live-acceptance
> against the real synced application. This is the "does it actually explain the business, and can we trust it?" phase.

---

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
