# 28-05 — Code Review & Hardening

> **Status:** 📋 **PLANNED** (after 28-04). · **Type:** review / hardening (no release) · **Phase:** 28 (Feature Revamp) · **Gate:** review clean (all MUST/SHOULD-FIX resolved) → 28-06.

---

## Goal

Independently review the built framework for architecture soundness, extensibility (does a future stage
*actually* plug in cleanly?), code quality, and Genesis-convention adherence — then harden.

## Scope

**In:** an independent architecture + code review (subagent `tao-architect`, **blocking, READ-ONLY**) of the
28-04 build; the full a11y/quality sweep; applying fixes. **Out:** new features; scope creep.

## Review focus

- **Extensibility (the whole point):** the stage-container contract is genuinely reusable — a future stage
  (e.g. UX Design) can be added with only its inner surface + a `LifecycleService` transition row + an
  `ArtifactKind`, with **no** edits to the shell/rail/overview. Prove this with a written "how UX Design would
  plug in" walkthrough.
- **Parallelism correctness:** no hidden sequential gating; stages advance independently; m0014 CAS holds for
  concurrent stage/artifact writes; allowed-actions come from the table (no `if/elif` state logic).
- **Lifecycle integrity (ADR-050):** every transition flows through `LifecycleService` + is audited (m0013);
  illegal/precondition → 409; no last-write-wins status setter reintroduced.
- **Convention/quality:** coding-standards §1 floor (ruff/tsc/eslint/vitest/contract fixtures/stale-bundle);
  data-access layering (hooks → api → client); tokens-not-hex; heavy libs lazy; secrets untouched.
- **a11y + parity:** jest-axe on every mountable surface; keyboard nav across the workspace/tabs/dialogs;
  text-not-color-only status; dark parity.
- **Reserved plug-points:** Stories slot + read-only-now future-write slots are clean and inert (no dead
  scaffolding, no gating).

## Work

1. Run the full gate set; capture results.
2. Independent review (blocking, read-only) → MUST-FIX / SHOULD-FIX / NICE list.
3. Apply MUST-FIX + agreed SHOULD-FIX; re-run gates; commit LOCAL.
4. Record the review + resolutions in the progress doc.

## Acceptance / DoD

- Independent review completed; all MUST-FIX + agreed SHOULD-FIX resolved (deferrals recorded with rationale).
- The extensibility walkthrough demonstrates a clean future-stage plug-in.
- All gates green; a11y/parity clean; no hardcoded hex; contract fixtures pass.
- Progress/tracker updated. Still **no tag/push** (that's 28-06).

## Gate

Review clean → **28-06 release**.
