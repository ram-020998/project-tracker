Active phase: none in build — Phase 54 (schedules, custom agents) SHIPPED 2026-11-20; Phase 51/53 live acceptance still open (51-12 steps 1–27, 53-11 §5)

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 54 release, 2026-11-20)

| Repo | Tag | Branch |
|---|---|---|
| `playwright-appian` | v0.3.1 — `apwt`, own semver, GitLab npm registry (project 13864); vendored in genesis `testexec/vendor/` | main |
| `genesis` | v0.83.0 — app + `packages/genesis-core` (`CORE_MAJOR=1`), `kiro-agent-sdk`, `genesis-appian-parser` (`KB_FORMAT_VERSION=1`), all 0.83.0 | master |
| `genesis-workflows` | v0.27.0 — pins all four on `genesis.git@v0.83.0` (`#subdirectory=packages/<name>`); `agent-prompt` 0.1.0 needs genesis ≥ 0.83.0; skill `appian` 1.0.0 | master |

One shared version, one install script (ADR-080). kiro-cli: minimum and only verified version **2.37.1** (newer warns and runs).

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0030, `current_version` = **30**.
- `~/.genesis/memory.db`: migration set `mm0001` (version 1).

## Test counts at the last release

- genesis app: pytest **2122** locally; CI **2054** passed + 68 skipped; web vitest **906** (81 files)
- packages: genesis-core **124** · kiro-agent-sdk **302** · genesis-appian-parser all passed + 1 skipped
- genesis-workflows: `validate_library` **19** · `validate_skills` **5** · pytest **463**
- playwright-appian: `npm test` **1402** · agent-system: **399**

## What works today

- **Agent system:** five role agents `genesis-spec/dev/review/release/docs` (L0-core §6; `agent-system/OPERATOR_GUIDE.md`).
- **Platform:** `genesis serve` → API under `/api` + SPA at `http://127.0.0.1:8760` (version = `/openapi.json`
  `info.version`); Playwright reports on app port + 100 (ADR-085). Nav: Home · Workbench · Chat · Runs · Schedules ·
  Catalog · Documents · Memory, Settings pinned (ADR-087).
- **Kiro on v3 only (ADR-086):** `kiro-cli acp --agent-engine v3`, no trust flags, Genesis-owned `KIRO_HOME` (per run
  `<run>/_kiro/`, chat `~/.genesis/kiro-home/chat/`), nothing from `~/.kiro`; trust = a projected agent, activation
  verified, fail closed; credits metered or unavailable per turn.
- **Schedules (ADR-087):** one page for the five system schedules (editable, not deletable) and user schedules of a
  `schedulable` workflow, an agent prompt or an app's regression suite; presets + once, IANA zone, missed-slot catch-up,
  overlap skip, gate time-out, run time limit, auto-pause after failures; history with metered credits; runs carry
  `trigger`. The **bell** is a notification center (needs you, failed, auto-paused, missed).
- **Custom agents:** Catalog → Agents (instructions, managed skills, read-only MCP servers, model); used by agent-prompt
  schedules, a one-off Run (`agent-prompt` writes `output.md`) and a read-only **chat with a custom agent**.
- **Skills:** managed only (`~/.genesis/.kiro/skills/`), from Catalog → Skills; provisioned per run, front matter checked.
- **Chat:** read-only assistant, copilot run control (confirmed), eight modes, credits, steer, Stop, `session/load` resume.
- **Runs:** list + Run Detail (graph, inspector, conversation, all 3 HITL modes, credits); pause/cancel survive a
  restart.
- **Applications:** code-free Appian KB (business map, Object Wiki, incremental syncs, releases, features, Test Impact,
  Testing); five feature stages; revamped feature Overview/Activity and story Design/Implementation/Verification tabs.
- **Testing (ADR-081/082):** one Dev and at most one QA environment; execution and agent browser sessions on QA as the
  app's test users; Library, case scripts, `TE-` executions, regression suite (its schedule is a Schedules row).
- **Workbench (ADR-084):** To Do → Design → Design Review → Implementation → Code Review → Deployment → Verification → Done.
- Spec change requests, story↔spec traceability, opt-in Hub collaboration, curated + custom MCP/CLI tiers (runs load
  custom-only servers), managed-native Dev/DevOps MCP + `gws`.
- **Fleet:** `genesis-fleet` main (:8760) + userb (:8761), both v0.83.0 / DB v30 from the editable dev venv, 19
  workflows, skill `appian` 1.0.0; `gsm` at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm`.

## Known open items

- **Phase 51/53 live acceptance still open** (runs on v0.83.0; findings as v0.83.x patches): see
  `progress/phase-51-test-execution-engine.md` and `progress/phase-53-kiro-sdk-v3.md`, "Live acceptance".
- **Phase 54 rows not run (54-10 round 2):** `story-implementation`; a real paused or gated `story-verification`, the
  implementation report frame on a fresh run, a gate-waiting compose discard (need QA + a fresh implementation);
  Activity with pulled CRs and the pulled-artifact frame on real data; the app-sync export / `genesis-delta-*` path (no
  changes on Dev); n3 live.
- **Known issue m7:** a one-time schedule paused during its run and resumed afterwards gets a false "Missed" row
  (`specs/backlog/phase-54-follow-ups.md` §1).
- **For the user:** delete the release backup `/tmp/genesis-release-54-11/` (it holds your databases) once happy with
  v0.83.0, and the scratch `/tmp/colima/gr-54-11`.
- kiro-cli 3.x unverified (`specs/backlog/kiro-cli-3x-reverify.md`); agent isolation is Phase 52 (ADR-083 a–c).
- Unconfirmed from Phase 50 (user): `details.kb_format_version` = 1 on each instance; old library checkouts to `_archived/`.
- Backlog: `specs/backlog/phase-54-follow-ups.md`, `phase-53-follow-ups.md`, `phase-51-follow-ups.md`, `phase-50-follow-ups.md`.
