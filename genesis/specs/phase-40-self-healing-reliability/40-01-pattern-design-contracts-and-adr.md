# 40-01 — Pattern design, contracts & ADR

> **Gate:** ⭐ user sign-off before any build. **Docs only.** Parent: `../phase-40-self-healing-reliability.md`.

## Deliverables
1. **`attach_healing` signature** (genesis-core) — finalize params: `verify, heal, reassemble, restart_target, nxt, gate, retry_max, max_heal=1, max_restart=1, verdict_artifact, guidance_key` and the exact wiring (verify→route→heal→{patch→reassemble→verify | restart→guidance→restart_target}→gate). Confirm `verify` + `heal` are each internally wrapped by `attach_reliability` (ADR-011 holds for both).
2. **Contracts** — `VerificationReport {ok, summary, fixes:[{target_id, issue, reason, evidence, suggested_change, severity}]}`; `HealDecision {mode: patch|restart, rationale, guidance}`; typed validators (mirroring `genesis_core.validators`) so every workflow's verify/heal output is checked the same way.
3. **Carry-forward-guidance convention** — `state[guidance_key]["guidance"]` written on restart, read by the restart-target's `prompt_fn` (mirrors the trio's `_validation` message). Document it in the workflow-authoring standard.
4. **`META.healing {max_heal, max_restart}`** parsing + the **escalation ladder** (1 heal + 1 guided restart → gate).
5. **Reliability-lint rule** — a terminal grounded `verify` feeding a route SHOULD pair with a `heal` (decide **warn vs error**).
6. **`HealDecision` "small vs large" guidance** wording for the healer prompt; the **stable-id scheme** for TD/story-design section/object blocks.
7. **ADR-067** drafted (Proposed) + mirrored to `reference/decision-log.md`; the workflow plug-in contract documented (the umbrella §6 table).

## Not in this sub-phase
No genesis-core/workflow code — the construct lands in 40-02, adoption in 40-03/04.
