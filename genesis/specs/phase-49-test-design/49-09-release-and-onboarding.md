# 49-09 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-10-26. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-49-test-design.md`. After 49-08 = SHIP. **genesis-release** asks before every tag and push; then
> **genesis-docs** does the write-back.

## 1. Release order

1. **genesis v0.79.0** (minor; m0025, DB 24 → 25). Bump `pyproject.toml` `[project].version`, the `create_app`
   version, `web/src/version.ts`; `npm run build` + commit `web/static/` (separate sequential steps, L-089). Pins
   unchanged: genesis-core v0.9.8, kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0. Without the new workflow the
   stage start returns the friendly "not installed" 409 (L-033).
2. **genesis-workflows v0.23.0**: new `test-design-analysis` v0.1.0 + `registry.json` entry; move its genesis **dev pin**
   to v0.79.0 and keep `genesis-core@v0.9.8` (L-057).
3. For each: verify the release commit contains every changed file (L-056); tag; push on the user's go-ahead; CI green
   (genesis: genesis, frontend, clean-install; workflows: validate + pytest).

## 2. Deploy

Never restart while a run is active (`GET /api/runs?status=running` per instance). Fleet update as usual
(`gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`), then `genesis install` of
`test-design-analysis` on each instance; verify `/openapi.json` `info.version` = 0.79.0, DB v25, and
`GET /api/features/<id>/test-suite` answers.

## 3. Docs write-back (genesis-docs)

- **ADRs:** add **ADR-078** (Test Design stage + test model; amends ADR-056) and **ADR-079** (test traceability +
  test impact analysis) from the umbrella §12 via `genesis-ctx add adr`; tag areas `features-stages,
  stories-workbench, workflows-library` / `stories-workbench, kb-sync, features-stages`.
- **Areas:** add the new code paths to `context/areas.toml` so path routing finds them
  (`genesis/genesis/kb/testdesign.py`, `services/testdesign_stage.py`, `services/testimpact.py`, `api/testdesign.py`
  → features-stages + stories-workbench; `web/src/features/test-design/**` → features-stages;
  `genesis-workflows/workflows/test-design-analysis/**` is already under workflows-library). Consider a new
  `testing` area if Part 2 is next.
- `context/state/current.md` (versions, DB v25, test counts, "what works": Test Design stage, Tests tab, case/scenario
  pages, Test Impact tab); code map; `progress/phase-49-test-design.md`; `changelog.md`; README row 49 → SHIPPED;
  tracker §6; `bible/08` §9 pointer to `specs/backlog/phase-49-follow-ups.md`; lessons from the build via
  `genesis-ctx add lesson`. `genesis-ctx index && lint` green.

## 4. As run

*(filled by genesis-release / genesis-docs)*

## Context manifest

```toml
areas    = ["release-ci", "distribution", "db"]
adrs     = ["ADR-019", "ADR-046", "ADR-077"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-089"]
code     = ["genesis/pyproject.toml", "genesis/web/src/version.ts", "genesis-workflows/pyproject.toml", "genesis-workflows/registry.json"]
docs     = ["tracker:specs/phase-49-test-design.md", "tracker:specs/backlog/phase-49-follow-ups.md"]
upstream = ["49-08"]
```
