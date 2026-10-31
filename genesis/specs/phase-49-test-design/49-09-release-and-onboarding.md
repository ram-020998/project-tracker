# 49-09 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-10-26. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-49-test-design.md`. After 49-08 = SHIP. **genesis-release** asks before every tag and push; then
> **genesis-docs** does the write-back.

## 1. Release order

What ships (49-08 = SHIP 2026-10-30, `reviews/49-08-review.md`; H4 = SHIP, `reviews/49-08-H4-review.md`): **genesis**
`b9e9487..5da9916` — **15** commits ahead of `origin/master` (49-02, 49-05, 49-04, 49-06, H1, 49-07 ×4, H2, H3 ×4,
H4 `5da9916`); **genesis-workflows** `325cc23` + `9cb061f` — 2
commits (49-03 and the duplicate-test-module fix, `specs/bugs/workflows-duplicate-test-module-names.md`). All are
local only; GitLab has a backup copy on `backup/phase-49-wip` (genesis at `d62ae03`, genesis-workflows at `9cb061f`).

1. **genesis v0.79.0** (minor; m0025, DB 24 → 25). Bump `pyproject.toml` `[project].version`, the `create_app`
   version, `web/src/version.ts`; `npm run build` + commit `web/static/` (separate sequential steps, L-089). Pins
   unchanged: genesis-core v0.9.8, kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0. Without the new workflow the
   stage start returns the friendly "not installed" 409 (L-033).
2. **genesis-workflows v0.23.0**: new `test-design-analysis` v0.1.0 + `registry.json` entry (already committed in
   `325cc23`); move its genesis **dev pin** to v0.79.0 and keep `genesis-core@v0.9.8` (L-057).
3. For each: verify the release commit contains every changed file (L-056); tag; push on the user's go-ahead; CI green
   (genesis: genesis, frontend, clean-install; workflows: validate + pytest — its full-library count is now **305**, down
   from 331, because the duplicate-module fix stopped double-running 37 tests and started 11 that never ran).
4. After both `master` pushes and green CI, delete the backup branches (`git push origin --delete
   backup/phase-49-wip` + `git branch -D backup/phase-49-wip` in each repo) — ask first.

## 2. Deploy

State before deploy: **main** already runs the `d138078` checkout with its DB at **v25** (migrated during 49-08; v24
backup at `/tmp/genesis-review/backup/genesis-v24.db`); **userb** still runs v0.78.0 on DB v24 and migrates on its
first v0.79.0 start. Main holds 49-08 acceptance data on features 4 and 6 (the user decides whether to keep it).

Never restart while a run is active (`GET /api/runs?status=running` per instance). Fleet update as usual
(`gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`), then `genesis install` of
`test-design-analysis` on each instance (from the released library, replacing main's `--from ../genesis-workflows`
local install); verify `/openapi.json` `info.version` = 0.79.0, DB v25, and `GET /api/features/<id>/test-suite` answers.

## 3. Docs write-back (genesis-docs)

- **ADRs:** add **ADR-078** (Test Design stage + test model; amends ADR-056) and **ADR-079** (test traceability +
  test impact analysis) from the umbrella §12 via `genesis-ctx add adr`; tag areas `features-stages,
  stories-workbench, workflows-library` / `stories-workbench, kb-sync, features-stages`.
- **Areas:** add the new code paths to `context/areas.toml` so path routing finds them
  (`genesis/genesis/kb/testdesign.py`, `services/testdesign_stage.py`, `services/testimpact.py`, `api/testdesign.py`
  → features-stages + stories-workbench; **`genesis/genesis/domain/**`** — unmapped today, so `genesis-ctx check` misses
  ADR-050 on lifecycle changes (49-02 As built) → features-stages + stories-workbench; `services/testimpact.py` and the
  already-unmapped `kb/_graph_reads_mixin.py` → **kb-sync** too (49-05 As built: `check` missed the kb-sync rules);
  `web/src/features/test-design/**` → features-stages (still unmapped after H4 — H4 review n1);
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
