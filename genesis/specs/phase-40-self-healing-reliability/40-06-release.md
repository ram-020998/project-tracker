# 40-06 — Coordinated release

> **Gate:** CI green. Parent: `../phase-40-self-healing-reliability.md`.

## Release (ADR-019 order)
- **genesis-core vX.Y.Z** (`attach_healing` + contracts; `CORE_MAJOR` unchanged) → **genesis vX.Y.0** (re-pin core; run-graph tweak; commit `web/static` if touched) → **genesis-workflows vX.Y.0** (all four workflows adopt; re-pin genesis + genesis-core consistently — the whole chain, per the §7 ResolutionImpossible lesson).
- Land **feature-breakdown first** (40-03) proven before fanning out (40-04). Bump version anchors; tag + push each repo; verify CI via `glab`. **No genesis.db migration.**
- **Docs (Definition of Done):** bible §2 (versions/counts) + §3 (codebase-map: `attach_healing`, the contracts, per-workflow heal nodes) + §4 (**ADR-067 → Accepted**, complements ADR-011) + §7 (the credit-waste lesson + the fix) + tracker §6 + a new `progress/phase-40-self-healing-reliability.md`; mirror ADR-067 in `reference/decision-log.md`. Push project-tracker (`git pull --rebase` → push).
- Report with cited CI pipeline ids + a manual-acceptance note (a real failing run is user-observed).
