Active phase: none in build — Phase 51 (test execution engine) SHIPPED 2026-11-08 with live acceptance open (51-12 steps 1–27 on QA, D38)

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 51 release, 2026-11-08)

| Repo | Tag | Branch |
|---|---|---|
| `playwright-appian` | v0.3.0 — `apwt`, own semver, GitLab npm registry (project 13864); vendored into genesis (`testexec/vendor/`) | main |
| `genesis` | v0.81.0 — the app + `packages/genesis-core` (`CORE_MAJOR=1`), `packages/kiro-agent-sdk`, `packages/genesis-appian-parser` (`KB_FORMAT_VERSION=1`), all 0.81.0 | master |
| `genesis-workflows` | v0.25.0 — pins all four on `genesis.git@v0.81.0` (`#subdirectory=packages/<name>` for the libraries) | master |

Shared version, one install script, no internal dependency entries: ADR-080. Repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`,
remote `git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`. The old library repos carry a "moved" README.

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0028, `current_version` = **28**.
- `~/.genesis/memory.db` (separate, Phase 26): migration set `mm0001` (version 1).

## Test counts at the last release

- genesis app: pytest **1832** locally (1 deselected: the readiness probe that hangs with Docker installed); CI **1778**
  passed + 61 skipped; web: vitest **726** (62 files)
- packages: genesis-core **96** · kiro-agent-sdk **79** · genesis-appian-parser **53** (+ 1 skipped)
- genesis-workflows: `validate_library` **18** (gates 1–9) + `validate_skills` 4 + pytest **428**
- playwright-appian: `npm test` **1399** · agent-system: **389**

## What works today

- **Agent system:** five role agents `genesis-spec/dev/review/release/docs` (L0-core §6; `agent-system/OPERATOR_GUIDE.md`).
  `genesis-ctx status` shows genesis, genesis-workflows, playwright-appian and project-tracker; the digests carry no
  area tags (`genesis-ctx area <name>` lists an area's rules).
- **Platform monorepo:** one clone of `genesis`; `scripts/install.sh` and the dev setup
  (`scripts/install-packages.sh --editable --dev`) install all four packages offline from the checkout.
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`; API under `/api`, Swagger at `/docs`; the running
  version is `/openapi.json` `info.version`. Playwright reports are served from a second loopback origin (app port
  + 100, e.g. :8860): static report files only, no `/api` (ADR-085).
- Primary nav: Applications · Chat · Runs · Documents (Applications is the landing); Overview + Catalog live in Settings.
- Runs list + Run Detail (graph, inspector, conversation, all 3 HITL modes, credits). Pause keeps a run paused, also
  across a restart; cancel ends it cancelled with one `run.final`. A run orphaned by a server restart is failed at
  startup by the process holding `~/.genesis/run/runs.lock`.
- Chat: read-only assistant with persisted sessions, copilot run control (human-confirmed), skills, per-message credits.
- Applications: the code-free Appian KB (business map, overview, Object Wiki, syncs, releases, business artifacts,
  features, Test Impact, **Testing**). Tabs are URL-addressable (`?tab=…|test-impact|testing`). KB syncs are
  incremental; a full sync is forced only by a lower recorded `kb_format_version`. Object Wiki: searchable object table
  → one history page per object with story links and a Tests section.
- Feature workspace: Spec, UX Design, Technical Design, Feature Breakdown and Test Design stages; finalized stories.
  Test Design (local only): `TC-`/`TS-` records, Tests tab, case and scenario pages, CSV export, Test Impact.
- **Environment types (ADR-082):** Settings → Environments has a Type (Dev, QA, UAT, Production, Other): exactly one
  Dev (KB sync, Implementation, core MCP credentials) and at most one QA, on its own host. All test execution and agent
  browser sessions run on QA only, as the application's test users.
- **Testing tab (ADR-081)** — Library · Regression · Executions · Setup (`?view=`):
  - **Setup:** QA site path, test users by role (passwords in the SecretProvider only), the regression schedule
    (off / daily / weekly; off by default), runtime (Node ≥ 20 and Chromium are per machine; Install Chromium, Create
    workspace and Update testing runtime run as background jobs). Code lives in a per-app git workspace under
    `~/.genesis/testing/apps/<app>/`; the catalog is in `genesis.db`.
  - **Library:** `ACT-` actions and `DS-` data setups as code (contract declared in the code, CodeMirror editor,
    typecheck + one commit per save, history, revert, adopt outside edits, Draft → Ready → Retired). A setup becomes
    Ready by a passing Replay, an action by passing in use (Run dependents). Setups may span several roles.
  - **Record workflow:** a signed-in Chromium on QA as one role → `action-capture` → reviewed proposals, optionally also
    a data setup. **Compose with AI:** pick library items and describe the end state → `setup-composer` writes, checks
    and replays one setup, or names the missing step.
  - **Case scripts** for `TC-` cases (Edit, Remove script); scenario specs generated from the Phase 49 tables.
  - **Executions:** program-only `TE-` runs of committed code (ad-hoc, impact, regression, verification), one at a
    time per machine; results per scenario and step, flaky badge, execution page with View run and Open report.
  - **Regression:** per-app suite of feature-scenario references and own cross-feature scenarios; plan preview, Run
    now, change notes, pass-rate trend; the `regression-run` job runs due apps one at a time.
  - **Run impacted tests** from Test Impact.
- **Workbench (ADR-084):** lanes To Do → Design → Design Review → Implementation → Code Review → Deployment →
  Verification → Done. Dragging Deployment → Verification (after confirming QA has the changes) runs
  `story-verification`: pass → Done, product defect → Implementation with a defect report, blocked → a gate; report and
  proposals on the story page. A queued card reads Queued; dragging it out asks, then cancels the queued run.
- Spec change requests + story↔spec traceability; collaboration (opt-in, off by default) via the Genesis Hub.
- Data plane: durable SQLite (checkpoints, runs/events, chat sessions persist across restart; retention available).
- Credits: real metered Kiro credits per agent turn and chat message, with honest provenance.
- Integrations: curated + custom MCP/CLI tiers with per-node injection; managed-native Dev/DevOps MCP + `gws`.
- Fleet: `genesis-fleet` runs main (:8760, reports :8860) + userb (:8761, reports :8861), both on v0.81.0 / DB v28
  from the editable dev venv, each with test-execution 0.1.1, action-capture 0.2.2, setup-composer 0.1.1,
  story-verification 0.1.0 and the skill genesis-test-authoring 0.3.0; `gsm` is at
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm` (not on the agents' PATH). No managed install.
- Dev: `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760); gallery at `/dev`.

## Known open items

- **Phase 51 live acceptance is open (D38):** 51-12 steps 1–27 on QA on v0.81.0 when QA is back; findings ship as
  v0.81.x patches. The first patch also takes backlog `phase-51-follow-ups.md` §23 (N1, the case-script hint when the
  scanner cannot run) and §24 (P1 the compose dialog in the width probe, P2 the picker layout).
- The `backup/phase-51-2026-11-04` branches (local + origin, all three code repos) are redundant; delete on the user's
  go-ahead (backlog §26).
- Unconfirmed from Phase 50 (user): the first weekday sync's `details.kb_format_version` = 1 on each instance; moving
  the three old library checkouts to `_archived/`.
- Agent isolation for every workflow agent is Phase 52 (ADR-083 accepted risks).
- Backlog: `specs/backlog/phase-51-follow-ups.md` §1–§27 (§27 = the L-089 guard spike), `phase-50-follow-ups.md`
  §1–§6; the rest in `bible/08` §9.
