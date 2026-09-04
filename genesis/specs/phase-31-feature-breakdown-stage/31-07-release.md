# 31-07 — Release

> **Status:** 📝 PLANNED — not started (gated on 31-06). · Part of Phase 31.

## Purpose

Coordinated release of the Feature Breakdown stage. **Two-repo**, no core/SDK/migration.

## Order (ADR-019)

1. **genesis** — bump `pyproject` `[project].version` + `web/src/version.ts` + `api/app.py` FastAPI version;
   rebuild + commit `web/static`; tag + push.
2. **genesis-workflows** — add the `feature-breakdown-analysis` workflow; bump `pyproject` version; **re-pin
   `genesis.git@<new tag>`**; bump the workflow META/`workflow.yaml`/`registry.json` version; tag + push.
   Keep the whole pin chain consistent (the §7 `ResolutionImpossible` lesson).

genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**.

## Gates (all green before tagging)

- genesis: pytest + ruff; web tsc + eslint(0) + vitest + build; stale-bundle guard.
- genesis-workflows: `ci/validate_library.py` (12 workflows) + `ruff` + the workflow pytest.
- CI green on both tag pipelines (`glab ci list -R ramaswamy.u/{genesis,genesis-workflows}`).

## Post-release

- `genesis install --from ../genesis-workflows` so the running app has the released workflow; restart serve if
  a server-code change needs it.
- **Docs (Definition of Done):** flip **ADR-059 → Accepted** (`reference/decision-log.md` + `bible/04`);
  update `bible/00`+`bible/01` banners + versions + test counts; `bible/03` (the new workflow + the export
  endpoint + the `feature_breakdown` binding/mode); `bible/06` any new lessons; `bible/08` §9 → mark Phase 31
  SHIPPED; `AGENT_ONBOARDING` banner; README phases row; `tracker.md` §6; a `progress/phase-31-feature-
  breakdown-stage.md` as-built. Push project-tracker.
- **Report** with CI evidence (both tag pipeline ids/status) + gate counts. Live acceptance (a real feature →
  Start with notes + a supporting doc → the run → completion chat → export → Jira import) is user-driven /
  headless-undrivable.

## Gate

CI green on both repos; docs updated; report delivered.
