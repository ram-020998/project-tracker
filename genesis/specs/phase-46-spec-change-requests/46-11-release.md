# 46-11 — Release

> **Status:** ✅ BUILT + SHIPPED (genesis v0.77.0 / genesis-workflows v0.22.0, 2026-10-15; as-built in `progress/phase-46-spec-change-requests.md`) — drafted 2026-10-14. Repos: genesis, genesis-workflows (+ the Hub additions, already live from 46-09).
> Parent: `specs/phase-46-spec-change-requests.md`. Release only after the user's go-ahead.

## 1. Order (ADR-019)

1. **Hub:** confirm the 46-09 contract addition is built and the harness is green on the dev-env Hub.
2. **genesis v0.77.0** — bump `pyproject` `[project].version`, FastAPI `create_app` version, `web/src/version.ts`;
   rebuild + commit `web/static`; m0024 (DB **v24**); `beautifulsoup4==4.15.0` pinned directly. genesis-core
   (v0.9.8), kiro-agent-sdk (v0.7.1) and genesis-appian-parser (v0.3.0) pins unchanged. Tag, push, CI green
   (master + tag: genesis + frontend + clean-install).
3. **genesis-workflows v0.22.0** — re-pin genesis v0.77.0 (core v0.9.8 unchanged); `feature-breakdown-analysis`
   0.3.0, `story-design-analysis` 0.3.1, `story-implementation` 0.1.1 (no new workflow; `validate_library` count
   unchanged at 13). Tag, push, CI green.

## 2. Deploy

Never restart the fleet while a run is active (check `GET /api/runs?status=running` on :8760 and :8761 first).
`gsm provision --all --no-mcp --no-env --force` then `gsm restart --all`; verify both instances report 0.77.0, the
catalog lists `feature-breakdown-analysis` 0.3.0, and a fresh DB is at v24.

## 3. Docs (Definition of Done)

ADR-075/076 → **Accepted** in `reference/decision-log.md` and appended to `bible/04`; `bible/01` (state, tag table,
tests, "what works"), `bible/03` (new modules: `kb/spec_clauses.py`, `kb/spec_diff.py`, `kb/spec_changes.py`,
`kb/cr_document.py`, `kb/backlog_doc.py`, `services/spec_change.py`, the CR API, web components),
`bible/06` (lessons from the build), `bible/08` §9 (SHIPPED), banners in `AGENT_ONBOARDING.md` + `bible/00`, README
phase row, `tracker.md` §6, `progress/phase-46-spec-change-requests.md` (as-built), every sub-spec's as-built section.

## 4. As run (2026-10-15, on the user's go-ahead)
1. Hub: the 46-09 addition built + live-validated 41/41 (`progress/phase-36-genesis-hub-appian-app.md`).
2. genesis **v0.77.0** — release commit `d6ee6cd`, tag `v0.77.0`; CI #7087827 (master) + #7087831 (tag) green — jobs genesis, frontend, clean-install all success; pytest 1105, vitest 332.
3. genesis-workflows **v0.22.0** — release commit `a19153a`, tag `v0.22.0` (genesis pin v0.77.0; the parity test runs
   unconditionally); CI #7087975 + #7087976 green.
4. Deploy: no active runs on :8760 / :8761 → `gsm provision --all --no-mcp --no-env --force` → `gsm restart` both; both report 0.77.0 (`/openapi.json`), the catalog lists feature-breakdown-analysis 0.3.0 / story-design-analysis 0.3.1 / story-implementation 0.1.1, a fresh DB migrates to v24.
5. Docs: decision log (ADR-075/076 Accepted + as built), bible 00/01/03/04/05/06/08, `AGENT_ONBOARDING.md`, README,
   `tracker.md` §6, the progress doc, every sub-spec status, the Phase 36 contract index, the backlog file.
