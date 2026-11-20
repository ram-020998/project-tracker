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
2. **genesis-workflows v0.27.0**: `agent-prompt` 0.1.0; `schedulable` on `agent-prompt`, `sync-documents`,
   `generate-business-map`, `hello-appian` (the last three 0.1.1, D34); `registry.json` entries. The pins **and**
   `registry.json` `genesis_core_version` move to `genesis.git@v0.83.0` together (`#subdirectory=packages/<name>`,
   L-057): until then the library's CI cannot import `genesis_core.mcp.pickable`. Give it a CI-image run before the
   release commit (L-112). CI green. Release note: `agent-prompt` needs genesis ≥ 0.83.0; the major-only gate
   (ADR-019) does not stop a 0.82 app from loading it, where it fails at its first node.
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
- Workflow runs now see your custom MCP servers when a workflow names them (D32); a custom server with the same name
  as a curated one is never used in a run.
- Unattended agent-prompt runs have Kiro's shell (ADR-083 risks until Phase 52) and only read-only MCP servers; a
  custom server's "read-only" mark is your own claim.
- In chat, a custom agent keeps chat's read-only tools; a custom server with no tool allowlist adds no tools there
  (give it an allowlist in Settings → MCP to use it in chat, D43).
- A run whose state was edited before v0.83.0 may still show **Running** with nothing happening (54-02 fixed the cause,
  not old runs, D21): cancel it from Run Detail. A stuck `sync-application` run blocks that app's scheduled sync until
  you do.
- API changes for anyone scripting: new `/schedules*`, `/custom-agents*`, `/notifications*`; removed
  `/system/sync-settings*`, `/system/schedules`, `PUT /applications/{uuid}/testing/schedule`; `runs` items gained
  `trigger`; catalog items gained `schedulable`; `POST /chat/sessions` accepts `agent_id`; make-Dev moved from
  `POST /config/environments/{label}/dev` to `POST /config/environments/dev {label, is_dev}`; environment delete takes
  a label with `/`; an unmatched `/api/*` path answers 404 JSON for every method (54-02).

## 3. Docs write-back (genesis-docs)

- **ADR-087** from `adr-drafts.md`; first bring the draft up to date with what was built (54-10 review n6: D22's
  amended list line (D50), D30, D31, D36–D43, D48, D49) via `genesis-ctx add adr --id ADR-087 --title … --areas runs-worker,config-secrets,web-shell,workflows-library,chat,security --rule … --amends ADR-047 ADR-049 --status accepted --phase 54 --body-file …` (one `--amends` flag, ids space-separated).
- **Lessons** from the As built sections (candidates expected: a fire-and-forget handler reports success for a run that
  later fails; an op-specific worker must not write run status; an event type missing from the canonical list is
  stored but invisible).
- **Areas:** add the new paths (`genesis/genesis/agents/**`, `web/src/features/schedules/**`,
  `web/src/features/catalog/agents/**`, the notifications module, `runtime/memory_jobs.py`, `runtime/sync_jobs.py`,
  `genesis-workflows/workflows/agent-prompt/**`) to the right areas so `check` routes them; keep no area glob empty.
- **Architecture docs** (`genesis/docs/architecture/`): scheduler, notifications, custom agents, the `agent-prompt`
  workflow, `kiro_node` callables, the navigation; and the 54-02 hand-off: `modules/configuration-and-secrets.md:589-590`
  and `modules/api.md:245` still give the old environment routes; write the new forms and the catch-all's 404/405 rule.
  From 54-04: `modules/scheduler-and-jobs.md` still names `regression_job.py`, the dispatcher and the old job keys;
  `api.md:539`, `data-and-migrations.md` (m0030, the `scheduled_jobs` columns, `:296`) and
  `knowledge-base.md:532/573/762` need the same update. From 54-06 (its "§2 consumer list", Docs): `api.md:475,539`
  plus every new route and the note that FastAPI's own validation 422s carry no `field` (review n5);
  `scheduler-and-jobs.md:429-439,526-552,654,683`; `testing.md:753`; `web-app.md:142`.
- **54-02 to 54-06 candidates:** the lesson candidates and code-map changes in each As built.
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
