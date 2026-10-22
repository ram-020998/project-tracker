Active phase: none — Phase 48 complete (2026-10-21); no next phase specced yet

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 48 release, 2026-10-21)

| Repo | Tag | Branch |
|---|---|---|
| `genesis` | v0.78.0 | master |
| `genesis-core` | v0.9.8 (`CORE_MAJOR=1`) | master |
| `genesis-workflows` | v0.22.0 | master |
| `kiro-agent-sdk` | v0.7.1 | main |
| `genesis-appian-parser` | v0.3.0 | main |

Dependency chain (git-pinned by tag): `genesis → genesis-core@v0.9.8 → kiro-agent-sdk@v0.7.1` (+ `genesis-appian-parser@v0.3.0`);
`genesis-workflows → genesis-core@v0.9.8` (runtime) + `genesis@v0.77.0` (dev pin — intentionally not moved to v0.78.0:
genesis-workflows was not released in Phase 48 and needs nothing from it). The parser is a stdlib-only leaf.
All repos are at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, remote `git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`.

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0024, `current_version` = **24**.
- `~/.genesis/memory.db` (separate, Phase 26): migration set `mm0001` (version 1).

## Test counts at the last release

- genesis: pytest **1187**; web: vitest **380** (46 files)
- genesis-workflows: `validate_library` **13** + pytest **256** (unchanged since v0.22.0)
- genesis-core: **91** · kiro-agent-sdk: **93** (unchanged since v0.9.8 / v0.7.1)
- genesis-appian-parser: all pass (no count recorded at the last release)

## What works today

- **Agent system (Phase 47; piloted end to end on Phase 48):** five role agents `genesis-spec/dev/review/release/docs`
  (Kiro CLI V3, JSON profiles, `claude-opus-5.5`) installed from `project-tracker/genesis/agent-system/` (`install.sh` /
  `update.sh` / `uninstall.sh`); launch with `kiro-cli --v3 chat --agent genesis-<role>` from `~/repo-gitlab/ramaswamy.u`;
  context via `genesis-ctx`; never `--trust-all-tools`.
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`; API under `/api`, Swagger at `/docs`, SPA history
  fallback; the running version is `/openapi.json` `info.version`.
- Primary nav: Applications · Chat · Runs · Documents (Applications is the landing); Overview + Catalog live in Settings.
- Runs list + Run Detail (graph, inspector, turn-grouped conversation, all 3 HITL modes, per-node and run-total credits).
- Chat: read-only assistant with persisted sessions, copilot run control (human-confirmed), skills, per-message credits.
- Applications: the code-free Appian KB (business map, overview, Object Wiki, syncs, releases, business artifacts,
  features). Application tabs are URL-addressable (`?tab=business-map|overview|object-wiki|features|syncs|releases|business-artifacts`).
- **Object Wiki tab (Phase 48):** a searchable, filterable (type, latest change), sortable table of the app's documented
  objects → one page per object (`/applications/:appUuid/wiki/:objectUuid`): current summary + newest-first change history
  with a Business / Technical / Both switch, the change reason ("Why: …") on every entry, and story links to the canonical
  story page. Read-only over the local wiki tables (teammates' pulled entries included); `GET /api/applications/{app}/wiki[/{object}]`.
- Feature workspace: Spec, UX Design, Technical Design and Feature Breakdown stages; finalized stories; Workbench boards.
- Spec change requests + story↔spec traceability (Phase 46): clause ids, coverage, CR → impact analysis → apply / discard.
- Collaboration (opt-in, off by default): Genesis Hub sync of KB, identity/teams, the SDLC entities and the Object Wiki.
- Data plane: durable SQLite (checkpoints, runs/events, chat sessions persist across restart; retention available).
- Credits: real metered Kiro credits per agent turn and chat message, with honest `metered`/`partial`/`unavailable` provenance.
- Integrations: curated (MR-governed) + custom MCP/CLI tiers with per-node injection; managed-native Dev/DevOps MCP + `gws`.
- Fleet: `genesis-fleet` runs main (:8760) + userb (:8761) for two-user collaboration checks; `gsm` is at
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm` (not on the agents' PATH).
- Dev: `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760); design-system gallery at `/dev`.

## Known open items

- `bible/08` §9 "Deferred items (pointers)": the 17 `specs/backlog/` files + 8 deferred items from shipped phases.
- `bible/08` §9 "Open follow-ups (may be assigned)" (stale list — the docs agent reviews it).
