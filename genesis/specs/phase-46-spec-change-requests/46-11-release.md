# 46-11 — Release

> **Status:** 🟡 DRAFTED 2026-10-14. Repos: genesis, genesis-workflows (+ the Hub additions, already live from 46-09).
> Parent: `specs/phase-46-spec-change-requests.md`. Release only after the user's go-ahead.

## 1. Order (ADR-019)

1. **Hub:** confirm the 46-09 contract addition is built and the harness is green on the dev-env Hub.
2. **genesis v0.77.0** — bump `pyproject` `[project].version`, FastAPI `create_app` version, `web/src/version.ts`;
   rebuild + commit `web/static`; m0024 (DB **v24**); `beautifulsoup4==4.15.0` pinned directly. genesis-core
   (v0.9.8), kiro-agent-sdk (v0.7.1) and genesis-appian-parser (v0.3.0) pins unchanged. Tag, push, CI green
   (master + tag: genesis + frontend + clean-install).
3. **genesis-workflows v0.22.0** — re-pin genesis v0.77.0 (core v0.9.8 unchanged); `feature-breakdown-analysis`
   0.3.0, `spec-story-linking` 0.1.0 (new; `registry.json` entry), `story-design-analysis` 0.3.1,
   `story-implementation` 0.1.1; `validate_library` count +1. Tag, push, CI green.

## 2. Deploy

Never restart the fleet while a run is active (check `GET /api/runs?status=running` on :8760 and :8761 first).
`gsm provision --all --no-mcp --no-env --force` then `gsm restart --all`; verify both instances report 0.77.0, the
catalog lists `spec-story-linking`, and a fresh DB is at v24.

## 3. Docs (Definition of Done)

ADR-075/076 → **Accepted** in `reference/decision-log.md` and appended to `bible/04`; `bible/01` (state, tag table,
tests, "what works"), `bible/03` (new modules: `kb/spec_clauses.py`, `kb/spec_diff.py`, `kb/spec_changes.py`,
`kb/cr_document.py`, `kb/backlog_doc.py`, `services/spec_change.py`, the CR API, web components, the new workflow),
`bible/06` (lessons from the build), `bible/08` §9 (SHIPPED), banners in `AGENT_ONBOARDING.md` + `bible/00`, README
phase row, `tracker.md` §6, `progress/phase-46-spec-change-requests.md` (as-built), every sub-spec's as-built section.
