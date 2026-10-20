Active phase: none — Phase 47 complete (2026-10-20); next real phase = Phase 48 (also the agent-system pilot)

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 46 release, 2026-10-15)

| Repo | Tag | Branch |
|---|---|---|
| `genesis` | v0.77.0 | master |
| `genesis-core` | v0.9.8 (`CORE_MAJOR=1`) | master |
| `genesis-workflows` | v0.22.0 | master |
| `kiro-agent-sdk` | v0.7.1 | main |
| `genesis-appian-parser` | v0.3.0 | main |

Dependency chain (git-pinned by tag): `genesis → genesis-core@v0.9.8 → kiro-agent-sdk@v0.7.1` (+ `genesis-appian-parser@v0.3.0`);
`genesis-workflows → genesis-core@v0.9.8` (runtime) + `genesis@v0.77.0` (dev pin). The parser is a stdlib-only leaf.
All repos are at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, remote `git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`.

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0024, `current_version` = **24**.
- `~/.genesis/memory.db` (separate, Phase 26): migration set `mm0001`.

## Test counts at the last release

- genesis: pytest **1105**; web: vitest **332**
- genesis-workflows: `validate_library` **13** + pytest **256**
- genesis-core: **91** · kiro-agent-sdk: **93** (unchanged since v0.9.8 / v0.7.1)
- genesis-appian-parser: all pass (no count recorded at the last release)

## What works today

- **Agent system (Phase 47):** five role agents `genesis-spec/dev/review/release/docs` (Kiro CLI V3, JSON profiles, `claude-opus-5.5`)
  installed from `project-tracker/genesis/agent-system/` (`install.sh` / `update.sh` / `uninstall.sh`); launch with
  `kiro-cli --v3 chat --agent genesis-<role>` from `~/repo-gitlab/ramaswamy.u`; context via `genesis-ctx`; never `--trust-all-tools`.
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`; API under `/api`, Swagger at `/docs`, SPA history fallback.
- Primary nav: Applications · Chat · Runs · Documents (Applications is the landing); Overview + Catalog live in Settings.
- Runs list + Run Detail (graph, inspector, turn-grouped conversation, all 3 HITL modes, per-node and run-total credits).
- Chat: read-only assistant with persisted sessions, copilot run control (human-confirmed), skills, per-message credits.
- Applications: the code-free Appian KB (business map, overview, syncs, releases, business artifacts, features).
- Feature workspace: Spec, UX Design, Technical Design and Feature Breakdown stages; finalized stories; Workbench boards.
- Spec change requests + story↔spec traceability (Phase 46): clause ids, coverage, CR → impact analysis → apply / discard.
- Collaboration (opt-in, off by default): Genesis Hub sync of KB, identity/teams and the SDLC entities.
- Data plane: durable SQLite (checkpoints, runs/events, chat sessions persist across restart; retention available).
- Credits: real metered Kiro credits per agent turn and chat message, with honest `metered`/`partial`/`unavailable` provenance.
- Integrations: curated (MR-governed) + custom MCP/CLI tiers with per-node injection; managed-native Dev/DevOps MCP + `gws`.
- Dev: `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760); design-system gallery at `/dev`.

## Known open items

- `bible/08` §9 "Deferred items (pointers)": the 14 `specs/backlog/` files + 8 deferred items from shipped phases.
- `bible/08` §9 "Open follow-ups (may be assigned)" (stale list — the docs agent reviews it).
