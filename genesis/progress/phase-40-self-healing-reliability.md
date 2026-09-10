# Phase 40 — Self-Healing Reliability — AS-BUILT (✅ SHIPPED)

> **Status (2026-09-10):** ✅ **SHIPPED** — genesis-core **v0.9.7** + genesis **v0.70.0** + genesis-workflows **v0.17.0**, released together with Phase 39. ADR-067 **Accepted**. Umbrella: `../specs/phase-40-self-healing-reliability.md`.

## What shipped

The **second reliability tier** beside the ADR-011 per-node trio: where the trio validates a single agent turn, this tier validates the **assembled artifact** and corrects it **cheaply**, replacing the wasteful "a verify failure re-does the whole workflow / can't touch frozen blocks."

**40-02 — genesis-core `attach_healing` (additive; `CORE_MAJOR` unchanged).**
- `genesis_core/nodes/healing.py::attach_healing(g, *, verify, heal, reassemble, restart_target, nxt, gate, retry_max, max_heal=1, max_restart=1, verdict_artifact="verify.json", heal_artifact="heal.json", guidance_key="_healing", verify_check=check_verification_report, heal_check=check_heal_decision)` — wires `verify(agent,trio) → verify_route → {ok→nxt | not-ok→heal(agent,trio) → heal_route → {patch (heals_used<max_heal) → reassemble → verify | one guided restart (restarts_used<max_restart) → set guidance + pass → restart_target | budgets spent → gate}}`. Internally wraps **both** `verify` and `heal` with `attach_reliability` (ADR-011 holds for both); emits `verify.result` / `heal.decision{mode}` / `heal.applied` / `workflow.restart{pass}`. `healing_bounds(META)` + `read_guidance(state)` helpers.
- `genesis_core/contracts.py` — `VerificationReport{ok, summary, fixes:[Fix]}` / `Fix{target_id, issue, reason, evidence, suggested_change, severity}` / `HealDecision{mode:patch|restart, rationale, guidance, patches}` typed helpers + `check_verification_report` / `check_heal_decision` (the same `check_fn` shape as `genesis_core.validators`) so verify/heal outputs are shape-checked (the "stub hid the contract" lesson).
- `genesis_core/state.py` — a reserved **`_healing`** channel `Annotated[dict, _merge]` (shallow per-key merge) so a `patch` write `{heals_used:n+1}` and a `restart` write `{restarts_used:n+1, guidance}` preserve each other → **the budget can't be clobbered** → the ladder is provably bounded (1 patch + 1 restart → escalate). `__init__` re-exports. +6 tests (`tests/test_healing.py`: patch / restart / budget-exhaustion / contracts / bounds).

**40-03/04 — adoption in all four analysis workflows** (each: `verify` emits a `VerificationReport`; a new `heal` agent judges blast radius; a deterministic `_reassemble` merges the healer's corrected items into the granular aggregate + re-renders; rewired via `attach_healing`; guidance injected into the restart-target's prompts via `read_guidance`; retired `MAX_VERIFY_ROUNDS`/`route_verify`/`_pick_verify`/`check_verify`):
- **feature-breakdown-analysis v0.2.0** — patches the flagged `story-N-M` / `epic-N` in `epic_stories.json`; restart → `plan_epics`.
- **technical-design-analysis v0.3.0** — rendered workstream sections get stable `section-N` ids; patches the flagged `design_sections.json` block; restart → `plan_sections`.
- **story-design-analysis v0.2.0** — `object-N` ids; patches the flagged `design_objects.json` block; restart → `plan_objects`.
- **ux-design-analysis v0.2.0** — `synthesize` wraps each screen in `<section id="screen-N">`; heal patches the flagged screen sections directly in `analysis.html` (regex replace; full-doc fallback); restart → `screen_inventory`.
- `META.healing {max_heal:1, max_restart:1}` on each; the pass counter tracks `_healing.restarts_used` (shared with Phase 39's `_iteration.pass`); `workflow.yaml` graph topologies gained `heal`/`v_heal`/`heal_route`/`verify_route`/`reassemble` nodes + `heal.json` artifact.

**40-05 — independent review & hardening.** A sub-agent auditor verified the whole tier: **NO MUST-FIX.** Credit-safety confirmed (the `_merge` reducer preserves `heals_used`/`restarts_used` across the loop → bounded, no unbounded loop; `new_state` sets `_healing={}` only at run start and no node writes a full `_healing` dict). Contract validation, per-artifact patch byte-stability, guidance carry-forward, ADR-011-trio-on-verify+heal, and `_iteration.pass` all verified. Applied the SHOULD-FIX/NIT doc-hygiene (4 module-flow docstrings + 4 escalate-gate descriptions reworded to the heal ladder).

## Verification (all green at release)
- genesis-core `pytest` **91** + ruff.
- genesis `pytest` **790** + ruff; web **vitest 270** + build (Phase-39 UI; no Phase-40 genesis code change).
- genesis-workflows `ci/validate_library.py` clean (12 workflows, reliability lint) + `pytest` **185**.
- CI green: genesis-core #6781318 (v0.9.7); genesis (v0.70.0) + genesis-workflows (v0.17.0) — see tracker §6 for pipeline ids.

## Release
ADR-019 order: **genesis-core v0.9.7 → genesis v0.70.0 (re-pin core) → genesis-workflows v0.17.0 (re-pin core + genesis — the whole chain, ResolutionImpossible lesson).** No DB migration. Released together with Phase 39. **Live acceptance** (a real failing analysis run → a small failure fixed by one heal turn; a large one → one guided restart → escalate) is user-observed. **PHASE 40 COMPLETE.**

## Out of scope (future)
More than 1 heal / 1 restart (bounded by design); healing the non-analysis workflows (no grounded-artifact verify tier); auto-tuning the blast-radius threshold from telemetry; multi-artifact cross-workflow healing.
