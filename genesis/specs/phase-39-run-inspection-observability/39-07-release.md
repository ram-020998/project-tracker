# 39-07 — Coordinated release

> **Gate:** CI green. Parent: `../phase-39-run-inspection-observability.md`.

## Release (ADR-019 order)
- **genesis-core vX.Y.Z** (additive capture; `CORE_MAJOR` unchanged) → **genesis vX.Y.0** (re-pin core; `fold_iterations` + endpoint + web; commit `web/static`) → **genesis-workflows vX.Y.0** (descriptions + `_iteration` stamps; re-pin genesis).
- Bump the 3 genesis version anchors (`pyproject.toml`, `web/src/version.ts`, `genesis/api/app.py`); tag + push each repo; verify CI via `glab`. **No genesis.db migration.**
- **Docs (Definition of Done):** bible §2 (versions/test counts) + §3 (codebase-map: the capture events, `fold_iterations`, the summary pane + `NodeIterationsDialog`) + §4 (**ADR-066 → Accepted**) + §7 (any lesson) + tracker §6 + a new `progress/phase-39-run-inspection-observability.md`; mirror ADR-066 in `reference/decision-log.md`. Push project-tracker (`git pull --rebase` → push).
- Report with cited CI pipeline ids + a manual-acceptance note (live agent-run drill-down is user-observed).
