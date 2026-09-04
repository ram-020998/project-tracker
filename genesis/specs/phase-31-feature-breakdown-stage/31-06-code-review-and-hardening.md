# 31-06 — Code review & hardening

> **Status:** 📝 PLANNED — not started (gated on 31-03/31-04/31-05). · Part of Phase 31.

## Purpose

An independent, critical review of the built workflow + platform + export against the spec, before release.
Prefer a genuinely independent sub-agent auditor (a fresh context inspecting the work product); fall back to a
rigorous self-review if the auditor is unavailable (note which — the Phase-30 caveat).

## Checklist

**Workflow (`feature-breakdown-analysis`):**
- Read-only allowlists only (no write/deploy tools on any node); `required_mcp` correct.
- Reliability trio on every agent; the `break_epic` loop resets its retry counter per epic.
- `assemble` is a **program** node (no giant-HTML agent emission — the Phase-30 timeout lesson); `check_html`
  self-check present; the embedded JSON round-trips to `backlog.json`.
- The grounded `verify` critic checks **coverage** (every Spec scope item + every TD "What changes" item →
  ≥1 story) and is bounded → escalate; validators mirror real tool-output shapes (`_coerce_json`).
- **Gherkin AC** enforced on Stories; **Story vs Task = front-end testability** applied correctly; Tasks may
  lack AC; `devNoteRef`s point at real TD workstreams (not rewritten detail).
- Appian breakdown rules honored on a dry-run: form vs process-model split; entry-point splitting;
  clarity-over-volume (no gratuitous splitting).

**Platform:**
- Three-way prerequisite gating agrees **frontend↔backend** (locked card ⇄ 409); `resolve_inputs` fail-fast.
- Multipart start guards: ≤3 files, allowlist + size (ADR-035); 409 on already-finalized OR in-progress
  (the Phase-30 lifecycle-guard lesson); friendly 409 when the workflow isn't installed.
- The StageFinalizer binding finalizes a `done` run into `feature_breakdown` (bound-run + stage-match +
  idempotency guards intact); the `feature_breakdown` chat mode is read-only + sandboxed.
- Reuse clean: **no shell edits** (the ADR-056 invariant); a11y (jest-axe green on the new entry surface +
  the clickable card), dark-parity, no hardcoded brand hex; contract fixtures.

**HTML output — Lavish annotation compatibility (the user's one hard requirement):**
- `breakdown.html` renders correctly inside the sandboxed annotatable iframe; the **CSS-only** card/table
  interactions do **not** break the Lavish annotation layer; validate against Lavish's golden postMessage
  fixture (ADR-043); confirm a highlight→comment round-trip still flows into the chat. (This is the spike-worthy
  risk — if pure-CSS interactivity is at all fragile with Lavish, fall back to a fully static card layout.)

**Export:**
- The CSV imports into Jira as epics + stories/tasks (manual verification — headless-undrivable); Issue ID →
  Parent ID linkage correct; Gherkin AC + Labels map; reads the freshest (chat-edited) artifact.

## Deliverables

- Findings + applied SHOULD-FIX (this doc's changelog).
- Live-acceptance notes: the manual end-to-end (a real feature with Spec+UX+TD → Start with notes + a
  transcript → the run → the completion chat → export → Jira import) is user-driven / headless-undrivable.

## Gate

Review clean (all MUST-FIX resolved) → 31-07 release.
