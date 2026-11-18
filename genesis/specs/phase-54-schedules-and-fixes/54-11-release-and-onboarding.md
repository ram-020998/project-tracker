# 54-11 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-19. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-54-schedules-and-fixes.md`. After 54-10 = SHIP **and its live acceptance passed** (D20).
> **genesis-release** asks before every tag and push; then **genesis-docs** does the write-back.

## 1. Release order (one release, D19)

1. **genesis v0.83.0** (assuming no v0.82.x patch moves the minor; otherwise the next minor): version in the
   `pyproject.toml` files of the app and the three packages (one shared version, ADR-080), `create_app`,
   `web/src/version.ts`; m0030 (DB v29 → v30); `npm run build` + commit `web/static/` as separate steps (L-089); verify
   the release commit holds every changed file (L-056), including web fixtures and migration; one CI run before the
   release commit (L-112); tag; push on the user's go-ahead; CI green (packages, genesis, frontend, clean-install).
   If no web file changed in a follow-up tag, force the frontend job with a real `web/**` touch (L-030).
2. **genesis-workflows v0.27.0**: `agent-prompt` 0.1.0, `schedulable` flags (54-05 §5), `registry.json` entries; pins on
   `genesis.git@v0.83.0` (`#subdirectory=packages/<name>`, L-057); CI green.
3. Never read CI variables through the API (L-100).
4. Rows of 54-10 §3 that could not run (Dev or QA down) are named in the release notes, README row and state (L-111).

## 2. Deploy

Never restart while a run is active. Fleet: `gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`;
install `agent-prompt` and update the flagged workflows from Catalog on each instance (L-033); check `/openapi.json`
`info.version` and DB version 30; open Schedules and confirm the system rows and migrated regression rows. User checklist
in the release notes:
- Schedules is a new page; the application-sync settings moved there from Settings → General, the regression schedule
  from Testing → Setup (existing cadences were migrated).
- Agent-prompt schedules and Catalog → Agents need the `agent-prompt` workflow installed.
- Unattended agent-prompt runs have Kiro's shell (ADR-083 risks until Phase 52) and only read-only MCP servers; a
  custom server's "read-only" mark is your own claim.
- API changes for anyone scripting: new `/schedules*`, `/custom-agents*`, `/notifications*`; removed
  `/system/sync-settings*`, `/system/schedules`, `PUT /applications/{uuid}/testing/schedule`; `runs` items gained
  `trigger`; catalog items gained `schedulable`; `POST /chat/sessions` accepts `agent_id`.

## 3. Docs write-back (genesis-docs)

- **ADR-087** from `adr-drafts.md` via `genesis-ctx add adr --id ADR-087 --title … --areas runs-worker,config-secrets,web-shell,workflows-library,chat,security --rule … --amends ADR-047 ADR-049 --status accepted --phase 54 --body-file …` (one `--amends` flag, ids space-separated).
- **Lessons** from the As built sections (candidates expected: a fire-and-forget handler reports success for a run that
  later fails; an op-specific worker must not write run status; an event type missing from the canonical list is
  stored but invisible).
- **Areas:** add the new paths (`genesis/genesis/agents/**`, `web/src/features/schedules/**`,
  `web/src/features/catalog/agents/**`, the notifications module, `runtime/memory_jobs.py`, `runtime/sync_jobs.py`,
  `genesis-workflows/workflows/agent-prompt/**`) to the right areas so `check` routes them; keep no area glob empty.
- **Architecture docs** (`genesis/docs/architecture/`): scheduler, notifications, custom agents, the `agent-prompt`
  workflow, `kiro_node` callables, the navigation.
- `context/state/current.md` (versions, DB v30, test counts, what works: Schedules, custom agents, bell; known open
  items unchanged from Phase 51/53 plus any skipped 54-10 rows), code map, `progress/phase-54-schedules-and-fixes.md`,
  `changelog.md`, README row 54 → SHIPPED, tracker §6, `specs/backlog/phase-54-follow-ups.md` (umbrella §9 Deferred +
  build findings). `genesis-ctx index && lint` green.

## As built

_(genesis-docs fills in.)_

## As run

_(genesis-release fills in: versions, CI pipelines, what happened, release notes, deferred items.)_

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-030", "L-033", "L-048", "L-056", "L-057", "L-089", "L-100", "L-111", "L-112"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-doc-writeback/SKILL.md"]
code     = ["genesis/pyproject.toml", "genesis/web/src/version.ts", "genesis-workflows/registry.json", "genesis-workflows/workflows/agent-prompt/**"]
upstream = ["54-10"]
```
