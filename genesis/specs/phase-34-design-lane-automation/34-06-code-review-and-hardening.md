# 34-06 — Code review & hardening

> **Status:** ✅ SHIPPED (genesis v0.62.0 + genesis-workflows v0.16.0). · Part of Phase 34. Repos: genesis + genesis-workflows. · **Depends on:** 34-02..34-05.

## Purpose

An independent review pass over the built phase before release; apply MUST/SHOULD-FIX; record the live-
acceptance steps (headless-undrivable pieces).

## Review checklist

**Workflow (`story-design-analysis`):**
- Reliability trio on every agent node (validator + retry + escalation) — `reliability.py` lint passes.
- `resolve_inputs` fail-fast on no dev env / app not synced (Q5); read-only allowlists only (no write/deploy
  tool trusted); `save_tool_output` for large results.
- Deterministic `assemble` — one well-formed Lavish-safe doc; no stray `</body>`; per-object sections; the
  grounded critic actually re-checks against the live app + research (not self-grading); retry-reset on revise.
- **Q6 process-model rule enforced** — a ProcessModel object's block is per-node with code per node (a
  validator hint + the review confirms on a real run).
- `no from __future__ import annotations`; `recursion_limit` sufficient; `cleanup` preserves artifacts.

**Backend:**
- `StoryDesignFinalizer`: bound-run guard + idempotency + stage-match + **on-read recovery** (orphaned-worker
  §7 lesson); done→design-review via `LifecycleService` (audited, m0013); failures logged, never swallowed.
- design-start: moves to design (free) + launches; **re-run updates in place** (Q9); fail-fast 409 messages;
  friendly 409 when the workflow isn't installed.
- Card DTO `design_run_status` derived from the **runs table** (durable), so running/failed is correct even if
  a `run.final` was missed; **card lock** only while non-terminal.
- m0018 cascade correct (story→feature→app); `current_version` tests bumped; `row_version` CAS on story-stage
  writes.

**Web:**
- Drag-into-Design confirm on entry from ANY lane; Yes launches / No just moves; a running card is not
  draggable; failed = light-red (token, no hardcoded hex) + run link; the Design Review page reuses the stage
  workspace (chat + annotatable preview → agent revises); a11y (jest-axe) + dark parity + contract fixtures;
  only-nav shell edit invariant respected; `web/static` rebuilt.

**Removal (34-02):** `design-doc` gone from the library + the running app; `validate_library` count updated; no
stale functional references.

## Live-acceptance (user-driven; headless-undrivable)

Drag a groomed ticket into Design on a real board (dev env tagged + app synced) → confirm → the card shows
running + a run link → the run grounds against the live app and writes an object-level, code-level design → the
card auto-advances to Design Review → open it full-page → annotate → the agent revises the design. Failure
path: force a failure → the card goes light-red + failed + run link; re-drag into Design → re-run updates the
same design.

## Gate

Review clean; MUST-FIX applied → proceed to 34-07.
