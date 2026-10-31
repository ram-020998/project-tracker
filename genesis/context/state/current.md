Active phase: none in build — Phase 49 complete (2026-10-31); Phase 50 (platform monorepo) is spec-drafted, not started

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 49 release, 2026-10-31)

| Repo | Tag | Branch |
|---|---|---|
| `genesis` | v0.79.0 | master |
| `genesis-core` | v0.9.8 (`CORE_MAJOR=1`) | master |
| `genesis-workflows` | v0.23.0 | master |
| `kiro-agent-sdk` | v0.7.1 | main |
| `genesis-appian-parser` | v0.3.0 | main |

Dependency chain (git-pinned by tag): `genesis → genesis-core@v0.9.8 → kiro-agent-sdk@v0.7.1` (+ `genesis-appian-parser@v0.3.0`);
`genesis-workflows → genesis-core@v0.9.8` (runtime) + `genesis@v0.79.0` (dev pin). The parser is a stdlib-only leaf.
All repos are at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, remote `git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`.

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0025, `current_version` = **25**.
- `~/.genesis/memory.db` (separate, Phase 26): migration set `mm0001` (version 1).

## Test counts at the last release

- genesis: pytest **1366**; web: vitest **467** (50 files)
- genesis-workflows: `validate_library` **14** + `validate_skills` 3 + pytest **305**
- genesis-core: **91** · kiro-agent-sdk: **93** (unchanged since v0.9.8 / v0.7.1)
- genesis-appian-parser: all pass (no count recorded at the last release)

## What works today

- **Agent system (Phase 47):** five role agents `genesis-spec/dev/review/release/docs` (Kiro CLI V3, JSON profiles,
  `claude-opus-5.5`) installed from `project-tracker/genesis/agent-system/` (`install.sh` / `update.sh` /
  `uninstall.sh`); launch with `kiro-cli --v3 chat --agent genesis-<role>` from `~/repo-gitlab/ramaswamy.u`; context via
  `genesis-ctx`; never `--trust-all-tools`.
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`; API under `/api`, Swagger at `/docs`, SPA history
  fallback; the running version is `/openapi.json` `info.version`.
- Primary nav: Applications · Chat · Runs · Documents (Applications is the landing); Overview + Catalog live in Settings.
- Runs list + Run Detail (graph, inspector, turn-grouped conversation, all 3 HITL modes, per-node and run-total credits).
  Stage and story finalizers complete on the live `run.final` (status stored first); a run orphaned by a server restart
  is failed at startup ("worker lost across a server restart") by the process holding `~/.genesis/run/runs.lock`.
- Chat: read-only assistant with persisted sessions, copilot run control (human-confirmed), skills, per-message credits.
- Applications: the code-free Appian KB (business map, overview, Object Wiki, syncs, releases, business artifacts,
  features, Test Impact). Tabs are URL-addressable
  (`?tab=business-map|overview|object-wiki|features|syncs|releases|business-artifacts|test-impact`).
- **Object Wiki tab (Phase 48):** searchable, filterable, sortable table of the app's documented objects → one page per
  object (`/applications/:appUuid/wiki/:objectUuid`) with newest-first history, the change reason on every entry, story
  links, and (Phase 49) a Tests section with "Check test impact".
- Feature workspace: Spec, UX Design, Technical Design, Feature Breakdown and **Test Design** stages; finalized
  stories; Workbench boards. Feature roll-up: Completed / Draft (nothing started) / In progress.
- **Test Design (Phase 49, ADR-078/079; local only, not synced to the Hub):** the stage unlocks after stories are
  finalized; `test-design-analysis` drafts a suite → completion chat → **Finalize tests** into `TC-`/`TS-` records
  (Given/When/Then, type, priority, Draft → Ready → Retired); top-up "Generate tests" proposals; CSV export. Feature →
  **Tests** tab (summary, scenarios, cases table, coverage donut), case and scenario pages, story Tests section. Cases
  link to stories (Needs review on change) and objects (resolved via implementation, KB syncs and on read). Application
  → **Test Impact**: from picked objects, a story or a KB sync → affected suites → scenarios → cases, direct and
  indirect (1–5 hops, default 2).
- Spec change requests + story↔spec traceability (Phase 46): clause ids, coverage, CR → impact analysis → apply / discard.
- Collaboration (opt-in, off by default): Genesis Hub sync of KB, identity/teams, the SDLC entities and the Object Wiki.
- Data plane: durable SQLite (checkpoints, runs/events, chat sessions persist across restart; retention available).
- Credits: real metered Kiro credits per agent turn and chat message, with honest `metered`/`partial`/`unavailable` provenance.
- Integrations: curated (MR-governed) + custom MCP/CLI tiers with per-node injection; managed-native Dev/DevOps MCP + `gws`.
- Fleet: `genesis-fleet` runs main (:8760) + userb (:8761) for two-user collaboration checks, both on v0.79.0 / DB v25
  with `test-design-analysis` 0.1.0 installed; `gsm` is at
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm` (not on the agents' PATH).
- Dev: `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760); design-system gallery at `/dev`.

## Known open items

- Next phase: **Phase 50** (`specs/phase-50-platform-monorepo.md`, proposed ADR-080) — its start gate (Phase 49
  released) is now met; not started.
- `bible/08` §9 "Deferred items (pointers)": the 18 `specs/backlog/` files + 8 deferred items from shipped phases.
- `bible/08` §9 "Open follow-ups (may be assigned)" (stale list — the docs agent reviews it).
