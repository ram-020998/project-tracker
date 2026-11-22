# 55-12 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-22. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-55-workflow-execution.md`. After 55-11 = SHIP **and its live acceptance passed** (D11).
> **genesis-release** asks before every tag and push; then **genesis-docs** does the write-back.

## 1. Release order (one release)

1. **genesis v0.84.0** (or the next minor if a v0.83.x patch moved it): the version in the `pyproject.toml` files of
   the app and the three packages (one shared version, ADR-080), `create_app`, `web/src/version.ts`; m0031 if 55-08
   built it (DB v30 → v31); fastembed as a core dependency and the pinned model checksum; `npm run build` + commit
   `web/static/` as separate steps (L-089); verify the release commit holds every changed file (L-056), fixtures and
   migration included; one CI run before the release commit (L-112); tag; push on the user's go-ahead; CI green
   (packages, genesis, frontend, clean-install). If no web file changed in a follow-up tag, force the frontend job with
   a real `web/**` touch (L-030).
2. **genesis-workflows v0.28.0:** every adopted workflow's bump (55-10); the pins **and** `registry.json`
   `genesis_core_version` move to `genesis.git@v0.84.0` together (`#subdirectory=packages/<name>`, L-057); a CI-image
   run before the release commit (L-112); CI green. Release note: the adopted workflows need genesis ≥ 0.84.0 (the
   major-only gate, ADR-019, does not stop an older app from loading them, where the escalation gate fails).
3. Never read CI variables through the API (L-100).
4. Name every 55-11 row recorded "not run" in the release notes, README row and state; also state that the Phase
   51 / 53 / 54 live acceptance is still open (D11, L-111).

## 2. Deploy

Never restart while a run is active. Fleet: `gsm provision --all --no-mcp --no-env --force` (it runs the install
script, which fetches the embedder model and back-fills memories), `gsm restart --all`; update every workflow from
Catalog on each instance (L-033); check `/openapi.json` `info.version`, the DB version and the embedder state. User
checklist in the release notes:
- Each run with an agent step now starts with a memory brief (`_memory/brief.md`, listed under Inputs); your personal
  memories are included for your own runs and never published to the Hub.
- Escalations: open the **Resolve** tab on the run; the agent explains and proposes, you confirm. Rerun and Restart
  from a step move the feature stage (or story) to the new run and end the old run Cancelled. Reject at an old
  gate now ends the run **failed**, not done.
- The Documents tab is reorganized by step and type; tool-output files are still removed at the end of a run.
- The run graph shows the node that is really running; **Live / Reconnecting / Polling** shows the connection.

## 3. Write-back (genesis-docs)

File ADR-088, ADR-089 and ADR-090 from `adr-drafts.md` into `reference/decision-log.md` (amendment links on ADR-011,
ADR-031, ADR-033, ADR-053, ADR-054); update L-005 (`node.started` canonical) and add the phase's lesson candidates from
the As builts; areas (`context/areas.toml`: new paths such as `genesis/genesis/runs/snapshot.py`,
`genesis/genesis/runs/documents.py`, `genesis/genesis/memory/brief.py`, `genesis/genesis/mcp/resolve_server.py`,
`packages/genesis-core/genesis_core/nodes/escalation.py`); code map; `context/state/current.md`; progress
`progress/phase-55-workflow-execution.md`; changelog; README row; tracker §6; backlog
`specs/backlog/phase-55-follow-ups.md` (55 umbrella §9 deferred items). `genesis-ctx lint` green.

## Context manifest

```toml
areas    = ["release-ci", "distribution"]
adrs     = ["ADR-019", "ADR-046", "ADR-080"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-089", "L-100", "L-111", "L-112"]
docs     = ["tracker:specs/phase-55-workflow-execution/adr-drafts.md", "tracker:specs/phase-54-schedules-and-fixes/54-11-release-and-onboarding.md"]
code     = ["genesis/pyproject.toml", "genesis/scripts/install-packages.sh", "genesis-workflows/registry.json"]
upstream = ["55-11"]
```
