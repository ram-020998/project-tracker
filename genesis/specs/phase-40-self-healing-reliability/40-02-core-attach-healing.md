# 40-02 — genesis-core: the `attach_healing` construct

> **Gate:** independent review = SHIP. Additive; `CORE_MAJOR` unchanged. Parent: `../phase-40-self-healing-reliability.md`.

## Scope (`genesis-core/genesis_core/`)
- **`nodes/healing.py::attach_healing(...)`** — wires verify → route_verify(program) → heal → {patch→reassemble→verify | restart→guidance→restart_target} → gate, bounded by `META.healing`. Internally wraps `verify` and `heal` with `attach_reliability` (validator + retry + escalation). Emits canonical events: `verify.result`, `heal.decision{mode}`, `heal.applied`, `workflow.restart{pass}`.
- **Contracts + validators** — `VerificationReport` / `Fix` / `HealDecision` typed helpers + `check_verification_report`/`check_heal_decision` (in/near `validators.py`), so a workflow's verify/heal artifacts are shape-checked (the "stub hid the contract" lesson).
- **Guidance convention** — a small helper to read/write `state[guidance_key]["guidance"]` + `pass` bookkeeping (shared with Phase 39's `_iteration.pass`).
- **`META` parsing** — `healing: {max_heal, max_restart}` with defaults; exported for the reliability lint.
- Re-export `attach_healing` + the contracts from `genesis_core/__init__.py`.

## Tests (fake verify/heal agents via `set_agent_provider`/stubbed nodes)
- **patch path:** verify fails → heal `mode=patch` → reassemble → verify ok → nxt. (1 heal used.)
- **restart path:** heal `mode=restart` → guidance set in state → restart_target re-entered → pass increments.
- **budget exhaustion:** patch fails re-verify + restart fails re-verify → `gate` (escalate); no further loops.
- guidance is readable by a downstream prompt_fn; events emitted; `META.healing` bounds respected.
