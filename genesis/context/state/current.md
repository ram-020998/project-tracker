Active phase: none in build — Phase 53 (kiro-agent-sdk v3) SHIPPED 2026-11-15 with live acceptance open (53-11 §5; Phase 51's 51-12 steps 1–27, D20)

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 53 release, 2026-11-15)

| Repo | Tag | Branch |
|---|---|---|
| `playwright-appian` | v0.3.1 — `apwt`, own semver, GitLab npm registry (project 13864); vendored into genesis (`testexec/vendor/`) | main |
| `genesis` | v0.82.0 — the app + `packages/genesis-core` (`CORE_MAJOR=1`), `packages/kiro-agent-sdk`, `packages/genesis-appian-parser` (`KB_FORMAT_VERSION=1`), all 0.82.0 | master |
| `genesis-workflows` | v0.26.0 — pins all four on `genesis.git@v0.82.0` (`#subdirectory=packages/<name>`); skill `appian` 1.0.0 | master |

One shared version, one install script (ADR-080). Repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`. kiro-cli: minimum
and only verified version **2.37.1** (newer warns and runs).

## Databases

- `~/.genesis/genesis.db` (SQLite, WAL): migrations m0001–m0029, `current_version` = **29**.
- `~/.genesis/memory.db`: migration set `mm0001` (version 1).

## Test counts at the last release

- genesis app: pytest **1943** locally (2 deselected: the readiness probe that hangs with Docker, and the D27 clock
  test, run alone); CI **1884** passed + 61 skipped; web vitest **764** (66 files)
- packages: genesis-core **109** · kiro-agent-sdk **302** · genesis-appian-parser all passed + 1 skipped
- genesis-workflows: `validate_library` **18** · `validate_skills` **5** · pytest **432**
- playwright-appian: `npm test` **1402** · agent-system: **399**

## What works today

- **Agent system:** five role agents `genesis-spec/dev/review/release/docs` (L0-core §6; `agent-system/OPERATOR_GUIDE.md`).
- **Platform:** `genesis serve` → API under `/api` + SPA at `http://127.0.0.1:8760` (Swagger `/docs`; version =
  `/openapi.json` `info.version`); Playwright reports on a second loopback origin, app port + 100 (ADR-085). Nav:
  Applications · Chat · Runs · Documents; Overview + Catalog in Settings. Dev: `npm run dev` in `genesis/web` (:5173).
- **Kiro on the v3 engine only (ADR-086):** every session is `kiro-cli acp --agent-engine v3`, with no trust flags, under a
  Genesis-owned `KIRO_HOME` (`<run>/_kiro/` per workflow run, `~/.genesis/kiro-home/chat/` for chat); nothing loads from
  `~/.kiro` (MCP servers, skills, steering, agents). Trust is a projected custom agent (explicit tool list + allow
  rules), activation verified, fail closed, with a Genesis allowlist backstop on every permission request. Workflow
  nodes: D9's built-ins auto-approved, MCP = `node.tools ∩ allowlist`, never `delete_file`. Credits from
  `turn_completion`, metered or unavailable per turn. Preflight has `kiro-cli` (required) and `kiro-cli-verified`
  (warning) items; Settings → General shows the version.
- **Skills:** managed only (`~/.genesis/.kiro/skills/`), installed and updated from Settings → Catalog → Skills (Update
  button); read-only chat and copilot reach them through their cwd, the six spec-style modes through the agent's
  `resources`; workflow skills are provisioned per run with front matter checked (playwright-appian from the run's
  export).
- **Chat:** read-only assistant, copilot run control (human-confirmed), eight modes, per-message credits; resume with
  `session/load` (preamble replay as fallback); Send during a turn steers it (an unread steer is re-sent after the
  turn); Stop keeps the session and the next prompt starts with the fixed cancelled-request note (D15); the `/` palette
  offers `/clear`, `/compact` and the managed skills, sent as `Use the <id> skill.` (D21, D25); MCP start failures show
  a notice; "answered by <model>" on a model fallback.
- **Runs:** list + Run Detail (graph, inspector, conversation, all 3 HITL modes, credits); pause/cancel survive a restart.
- **Applications:** code-free Appian KB (business map, Object Wiki, incremental syncs, releases, features, Test Impact,
  Testing). Feature stages Spec, UX Design, Technical Design, Feature Breakdown, Test Design; finalized stories.
- **Testing (ADR-081/082):** one Dev and at most one QA environment; all test execution and agent browser sessions on
  QA as the app's test users. Testing tab: Library (`ACT-`/`DS-` code in a per-app git workspace, Record workflow,
  Compose with AI), case scripts, program-only `TE-` executions, per-app regression suite and schedule, Run impacted
  tests. Update testing runtime installs playwright-appian 0.3.1.
- **Workbench (ADR-084):** To Do → Design → Design Review → Implementation → Code Review → Deployment → Verification →
  Done; Deployment → Verification runs `story-verification`.
- Spec change requests, story↔spec traceability, opt-in collaboration via the Genesis Hub; durable SQLite data plane;
  curated + custom MCP/CLI tiers; managed-native Dev/DevOps MCP + `gws`.
- **Fleet:** `genesis-fleet` main (:8760) + userb (:8761), both v0.82.0 / DB v29 from the editable dev venv, 18
  workflows, skill `appian` 1.0.0 installed; main's test workspace on apwt 0.3.1; `gsm` at
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm` (not on the agents' PATH).

## Known open items

- **Phase 53 live acceptance is partly open (D24, D26):** 4 of 15 agent-node workflows were accepted on v3 before the
  release. After it (53-11 §5): A1 for the other 8 Appian workflows when Dev is up (`story-implementation` only with the
  user's go-ahead), A2's remaining modes, A8, A9(a); and, with **Phase 51's postponed live acceptance (D20)**, which now
  runs on v3 with playwright-appian 0.3.1: `story-verification`, `action-capture`, `setup-composer` on QA, the
  cancelled-run `apwt` reap check and 51-12 steps 1–27. Findings ship as v0.82.x patches.
- **kiro-cli 3.x** is unverified (D22): `specs/backlog/kiro-cli-3x-reverify.md`.
- The v0.82.0 test fix `00e8078` (one test line, fail-first evidence) was not re-reviewed by genesis-review.
- userb's scheduled `memory-maintenance` run waits at its escalation gate ("could not load the list of models"); if it
  recurs on 0.82.0 it is a v3 finding.
- Agent isolation (shell, unscoped reads, inherited environment) is Phase 52 (ADR-083 risks a–c).
- Unconfirmed from Phase 50 (user): the first weekday sync's `details.kb_format_version` = 1 on each instance; moving
  the three old library checkouts to `_archived/`.
- Backlog: `specs/backlog/phase-53-follow-ups.md`, `phase-51-follow-ups.md` §1–§27, `phase-50-follow-ups.md` §1–§6.
