# 39-06 — Code review & hardening

> **Gate:** review clean. Parent: `../phase-39-run-inspection-observability.md`.

## Independent review checklist
- **No bulk in the event log** — prompts/artifacts are blackboard files + pointers only (ADR-010/018).
- **Prompt-file size + retention** honored; **no secret leakage** in captured prompts (redaction per 39-01).
- **Adaptive-tree degeneracy** — correct for single-turn, retries-only, MAP-loop, and +heal-pass; no empty levels.
- **New-runs-only** is honest in the UI (old runs show "capture unavailable for this run", not a broken modal).
- Per-turn metrics reconcile with `fold_steps` totals (sum of turns == node totals).
- a11y (jest-axe, keyboard tree), dark parity, no hardcoded brand hex, contract fixtures updated.
- Apply SHOULD-FIX; record live-acceptance notes (a real new run: open a node → summary → drill a turn → prompt/artifacts/conversation/output/metrics).
