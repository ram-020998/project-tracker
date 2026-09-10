# 40-05 — Code review & hardening

> **Gate:** review clean. Parent: `../phase-40-self-healing-reliability.md`.

## Independent review checklist
- **Credit-safety (the whole point):** the ladder is bounded — **1 in-place heal + 1 guided restart → escalate**; no path loops; assert on a real failing run that a small failure costs ~1 heal turn, not a full re-break.
- **Structured-fixes contract** validated in every workflow (verify + heal outputs shape-checked); no free-text regressions.
- **Heal-agent context completeness** — it receives source inputs + current artifact + the full report.
- **Per-artifact patch correctness** — patch edits only flagged items; deterministic re-assemble unchanged; the other items are byte-stable.
- **ADR-011 intact** — `verify` and `heal` each still wear the trio (validator + retry + escalation).
- **Run-graph** renders the new `heal` node + the pass loop (Phase-39 pass labels align).
- Apply SHOULD-FIX; live-acceptance notes on a genuinely failing real run (small → heal; large → restart → escalate).
