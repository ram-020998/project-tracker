Active phase: Phase 51 (test execution engine) in build — 51-02 done 2026-11-02; next 51-03 (spike, gate)

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 50 release, 2026-11-01)

| Repo | Tag | Branch |
|---|---|---|
| `genesis` | v0.80.0 — the app + `packages/genesis-core` (`CORE_MAJOR=1`), `packages/kiro-agent-sdk`, `packages/genesis-appian-parser` (`KB_FORMAT_VERSION=1`), all 0.80.0 | master |
| `genesis-workflows` | v0.24.0 — pins all four on `genesis.git@v0.80.0` (`#subdirectory=packages/<name>` for the libraries) | master |

Shared version, one install script, no internal dependency entries: ADR-080. Repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`,
remote `git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`. The old library repos carry a "moved" README (their tags
still serve genesis ≤ v0.79.0).

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0025, `current_version` = **25**.
- `~/.genesis/memory.db` (separate, Phase 26): migration set `mm0001` (version 1).

## Test counts at the last release

- genesis app: pytest **1418**; web: vitest **467** (50 files)
- packages: genesis-core **96** · kiro-agent-sdk **79** · genesis-appian-parser **53** (+ 1 skipped: two real exports not provided)
- genesis-workflows: `validate_library` **14** (gates 1–9) + `validate_skills` 3 + pytest **317**

## What works today

- **Agent system (Phase 47):** five role agents `genesis-spec/dev/review/release/docs` (Kiro CLI V3, JSON profiles,
  `claude-opus-5.5`) installed from `project-tracker/genesis/agent-system/` (`install.sh` / `update.sh` /
  `uninstall.sh`); launch with `kiro-cli --v3 chat --agent genesis-<role>` from `~/repo-gitlab/ramaswamy.u`; context via
  `genesis-ctx` (`status` shows genesis, genesis-workflows, playwright-appian, project-tracker; an area glob matching nothing is a lint
  error); never `--trust-all-tools`.
- **Platform monorepo (Phase 50):** one clone of `genesis`; `scripts/install.sh` and the dev setup
  (`scripts/install-packages.sh --editable --dev`) install all four packages offline from the checkout; the CLI exits 1
  naming a missing library; the updater runs the target tag's install script. Installs ≤ v0.79.0 must be reinstalled,
  not updated through the banner.
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`; API under `/api`, Swagger at `/docs`, SPA history
  fallback; the running version is `/openapi.json` `info.version`.
- Primary nav: Applications · Chat · Runs · Documents (Applications is the landing); Overview + Catalog live in Settings.
- Runs list + Run Detail (graph, inspector, turn-grouped conversation, all 3 HITL modes, per-node and run-total credits).
  Stage and story finalizers complete on the live `run.final` (status stored first); a run orphaned by a server restart
  is failed at startup ("worker lost across a server restart") by the process holding `~/.genesis/run/runs.lock`.
- Chat: read-only assistant with persisted sessions, copilot run control (human-confirmed), skills, per-message credits.
- Applications: the code-free Appian KB (business map, overview, Object Wiki, syncs, releases, business artifacts,
  features, Test Impact). Tabs are URL-addressable
  (`?tab=business-map|overview|object-wiki|features|syncs|releases|business-artifacts|test-impact`). KB syncs are
  incremental; a full sync is forced only by a lower recorded `kb_format_version`.
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
- Fleet: `genesis-fleet` runs main (:8760) + userb (:8761) for two-user collaboration checks, both on v0.80.0 / DB v25
  with genesis-workflows v0.24.0 installed, from the editable dev venv; `gsm` is at
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm` (not on the agents' PATH). No managed install exists.
- Dev: `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760); design-system gallery at `/dev`.

## Known open items

- **User, after the Phase 50 release:** check the first weekday scheduled sync (Monday 2026-11-02) — newest `kb_syncs`
  row incremental with `details.kb_format_version` = 1 on each instance; archive GitLab projects 14328 / 14306 / 14520
  in the UI; move the three old checkouts to `_archived/`.
- genesis `README.md` still says "m0001–m0024 (DB v24)" (code repo; fix with the next genesis change).
- Phase 51 specs: `specs/phase-51-test-execution-engine.md` (51-01..51-13). Backlog: `specs/backlog/phase-50-follow-ups.md` §1–§6; the rest in `bible/08` §9.
