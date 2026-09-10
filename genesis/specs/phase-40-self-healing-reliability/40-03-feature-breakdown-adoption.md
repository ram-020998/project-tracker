# 40-03 — feature-breakdown adoption (the worst case first)

> **Gate:** independent review = SHIP. Parent: `../phase-40-self-healing-reliability.md`.

## Scope (`genesis-workflows/workflows/feature-breakdown-analysis/graph.py`)
- **`verify` → `VerificationReport`**: emit `{ok, summary, fixes:[{target_id (story-N-M / epic-N), issue, reason, evidence, suggested_change, severity}]}` (the ids already exist in `backlog.json`). Update `check_verify` → `check_verification_report`.
- **New `heal` agent** (trio-wrapped) with full context (spec/ux/td + `backlog.json` + the report): returns a `HealDecision`; on `patch` it emits the **corrected granular items only** (the flagged stories/epics), which a program merges into the per-epic aggregate → the existing deterministic `_assemble` re-renders `backlog.json` + `breakdown.html`.
- **Rewire** `assemble → verify → route → heal → {patch→assemble→verify | restart→plan_epics} → escalate` via `attach_healing` (replaces `_route_verify`'s re-queue-all-epics + the `revise` edge). `MAX_VERIFY_ROUNDS` retired in favor of `META.healing {max_heal:1, max_restart:1}`.
- **Guidance on restart:** `plan_epics_prompt` / `break_epic_prompt` read `state["_healing"]["guidance"]` (replaces the current global-fixes append).

## Tests
- 2 flagged stories in 1 epic → **one heal turn edits just those** → re-verify ok (assert the other epics/stories are **not** regenerated — the credit-waste regression).
- healer judges **large** → one guided `plan_epics` restart → re-verify → (still fail) → escalate gate.
- `VerificationReport`/`HealDecision` shape validated; `_iteration.pass` increments on restart.
