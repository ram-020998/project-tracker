# 50-09 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-10-31. Agents: **genesis-release** (asks before every tag, push, archive and move),
> then **genesis-docs**. Repos: genesis, genesis-workflows, project-tracker; GitLab projects genesis-core,
> kiro-agent-sdk, genesis-appian-parser. Parent: `specs/phase-50-platform-monorepo.md`. After 50-08 = SHIP.
> Decisions: D3, D7, D8, D13.

## 1. Release order

1. **genesis v0.80.0.** On `phase-50-monorepo`: bump all four `pyproject.toml` versions, the parser `__version__`,
   the `create_app` version and `web/src/version.ts` to 0.80.0 (the version-sync test proves it); `npm run build` +
   commit `web/static/` only if web changed (separate sequential steps, L-089). `git status` clean after the commit
   (L-056). Fast-forward `master` to the branch; tag `v0.80.0`; push `master` + tag (ask). CI green on both.
2. **genesis-workflows v0.24.0.** Its 50-07 commits on `master` (pins already name v0.80.0); bump the version; tag;
   push (ask). CI green — the first run that resolves the subdirectory pins against GitLab.
3. Delete the scratch branches locally and on `origin` (ask).

## 2. Reinstall (D3)

- No run active on either fleet instance. The dev venv was rebuilt in 50-03; reinstall it once more from `master`
  (`scripts/install-packages.sh --editable --dev`).
- Any managed install (`~/.genesis/dist.json` present): fresh `scripts/install.sh`. No in-place update from ≤ v0.79.0.
- Fleet: `gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`, `genesis install` of genesis-workflows
  v0.24.0 on each instance. Verify `/openapi.json` `info.version` = 0.80.0 and an incremental sync stays incremental.

## 3. Archive the old repos (D13) — ask before each project

Only after §1 step 2 is green. For each of genesis-core, kiro-agent-sdk, genesis-appian-parser:

1. In the old local checkout, one commit replacing `README.md` with: "Moved into the genesis repo at
   `packages/<name>/` (history preserved) as of genesis v0.80.0. This repository is archived; old tags remain for
   installs of genesis ≤ v0.79.0." Push it (ask).
2. Archive the GitLab project (ask): `glab api -X POST projects/<id>/archive` (ids: genesis-core 14328,
   kiro-agent-sdk 14306, genesis-appian-parser 14520). Confirm `archived: true`.
3. Move the local checkout to `~/repo-gitlab/ramaswamy.u/_archived/<name>` (ask). Confirm `genesis-ctx status` and
   `agent-system/update.sh` still work (50-04 removed the dependency on them).

## 4. Docs write-back (genesis-docs)

- **ADR-080** from the umbrella §12 via `genesis-ctx add adr --amends ADR-019,ADR-046`, areas `distribution,
  release-ci, core-engine, sdk-acp, parser`.
- `context/L0-core.md` §2 (repo list: genesis with `packages/`, genesis-workflows; the old repos archived) — within
  the ≤ 4K-token budget.
- `context/state/current.md`: one platform row (genesis v0.80.0, packages at 0.80.0, `CORE_MAJOR=1`) + genesis-workflows
  v0.24.0; the new dependency chain; test counts per package; "what works" line for the monorepo.
- Code map (already moved in 50-04) — add `scripts/install-packages.sh`, `tests/test_version_sync.py`, the preflight
  item. `progress/phase-50-platform-monorepo.md`; `changelog.md`; README row 50 → SHIPPED; tracker §6.
- Lessons from the build via `genesis-ctx add lesson`. `genesis-ctx index && lint` green.

## 5. Acceptance

- [ ] genesis v0.80.0 and genesis-workflows v0.24.0 tagged, CI green (pipeline ids recorded).
- [ ] Fleet on 0.80.0; incremental sync still incremental.
- [ ] Three projects archived with the pointer commit; local checkouts in `_archived/`.
- [ ] ADR-080 recorded; docs write-back done; lint green.

## 6. As run

*(filled by genesis-release / genesis-docs)*

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library", "security"]
adrs     = ["ADR-016", "ADR-019", "ADR-046", "ADR-077"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo.md", "tracker:specs/phase-50-platform-monorepo/50-08-review-and-acceptance.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/**", "genesis-workflows/pyproject.toml", "genesis-workflows/registry.json"]
upstream = ["50-07", "50-08"]
```
