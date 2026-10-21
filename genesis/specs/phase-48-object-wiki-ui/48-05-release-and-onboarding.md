# 48-05 — Release and onboarding

> **Status:** 🟡 SPEC-DRAFTED 2026-10-21. Repos: genesis, project-tracker. Parent: `specs/phase-48-object-wiki-ui.md`.
> After 48-04 = SHIP. **genesis-release** asks before every tag and push; then **genesis-docs** does the write-back.

## 1. Release — genesis v0.78.0 only

1. Bump `pyproject.toml` `[project].version`, the FastAPI `create_app` version and `web/src/version.ts` to **0.78.0**;
   `npm run build` and commit `web/static/`.
2. Pins unchanged: genesis-core **v0.9.8**, kiro-agent-sdk **v0.7.1**, genesis-appian-parser **v0.3.0**. No migration
   (DB **v24**). genesis-workflows is not released (its genesis dev pin may stay at v0.77.0).
3. Verify the release commit contains every changed file (L-056); tag `v0.78.0`; push (on the user's go-ahead); CI green
   on master + tag (genesis, frontend, clean-install).

## 2. Deploy

Never restart while a run is active (`GET /api/runs?status=running` on each instance first). Then the usual fleet
update (`gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`); verify each instance reports 0.78.0 and
`GET /api/applications/<app>/wiki` answers.

## 3. Docs write-back (genesis-docs)

`context/state/current.md` (genesis v0.78.0, test counts, "what works" + the Object Wiki tab); code map (new
`kb/object_types.py`, `api/object_wiki.py`, `ObjectWikiStore.list_objects/get_object`, `web/src/features/object-wiki/`,
`shared/ui/appian-object-types.ts`, URL-addressable app tabs); `progress/phase-48-object-wiki-ui.md`; `changelog.md`;
README row 48 → SHIPPED; tracker §6; `bible/08` §9 pointer to `specs/backlog/wiki-story-cross-link.md`; lessons from
the build via `genesis-ctx add lesson`; note on the agent-system pilot (Phase 48 was its first real phase) in the
operator guide if anything changed. `genesis-ctx index && lint` green.

## 4. As run

_(filled by genesis-release / genesis-docs)_

## Context manifest

```toml
areas    = ["release-ci"]
adrs     = ["ADR-019"]
lessons  = ["L-030", "L-056", "L-057", "L-068"]
docs     = ["tracker:specs/phase-48-object-wiki-ui.md",
            "tracker:specs/phase-48-object-wiki-ui/48-04-review-and-acceptance.md"]
code     = ["genesis/pyproject.toml", "genesis/genesis/api/app.py", "genesis/web/src/version.ts",
            "genesis/web/static/**"]
upstream = ["48-04"]
```
