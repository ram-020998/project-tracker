# 30-06 — Code review & hardening (Technical Design stage)

> **Status:** 📋 DRAFT. Gate: review clean. · Part of Phase 30.

## Purpose

An independent review pass (a fresh sub-agent auditor, no shared build context) + a real dry-run of the
workflow, before the coordinated release. Apply MUST-FIX/SHOULD-FIX; record live-acceptance notes.

## Review checklist

- **Grounding correctness** — `analyze_section`/`draft_section`/`verify` use read-only `@genesis-kb`/
  `@appian-dev` allowlists only; every "what changes" cites a real object or is marked NEW; the critic
  re-checks against external truth (not self-graded); save-by-reference for bulk output.
- **Reliability trio** — every agent node wrapped (validator + retry + escalation); the loop node resets its
  retry counter per workstream; `recursion_limit` covers the worst-case workstream count.
- **Read-only posture (ADR-036/037)** — no write/deploy tools anywhere in the workflow or the
  `technical_design` chat mode; the chat mode's fs-write stays sandboxed.
- **Prerequisite gating** — enforced BOTH frontend (locked card + blocked workspace) AND backend (start 409 +
  `resolve_inputs` fail-fast); the two sources agree.
- **StageFinalizer generalization** — the binding registry finalizes both workflows; the v0.55.2 logging +
  reconcile-stage recovery + the v0.56.2 currently-bound-run guard still hold for both; a `technical-design`
  run never finalizes a `ux_design` stage and vice-versa.
- **Reuse cleanliness** — `StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage`/the in-progress
  screen reused, not re-built; the only new agent prompt is `_STEERING_TD`.
- **UX refinements (30-05)** — clickable card is accessible (no nested interactive-in-link; keyboard + jest-axe
  clean); locked cards not navigable; openable artifacts route correctly (generated → preview; reference →
  viewer).
- **Contract/format** — the generated doc matches the locked 30-01 skeleton (workstream flow, data-model
  tables, Complex Designs + Open Questions); validators mirror the real artifact shapes (the §7 "stub hid the
  contract" rule); dark-parity + no hardcoded brand hex on new web.

## Dry-run (live acceptance — user-driven)

Against a synced real app + a feature with a completed Spec + UX Design: Start → observe the run (plan →
per-workstream analyze → per-workstream draft → assemble → verify) in Runs → read the finished
`technical-design.html` (is it grounded, reader-first, questions genuine?) → open the completion chat, answer
a question, confirm the doc revises + the annotation bridge works → Mark complete. Kiro/live-env steps are
headless-undrivable — record the manual check here.

## Gate

Review clean (MUST-FIX applied); a real dry-run produced a grounded, reader-first document with genuine open
questions; all gates green → 30-07 release.
