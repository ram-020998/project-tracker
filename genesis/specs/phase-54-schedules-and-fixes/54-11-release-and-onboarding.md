# 54-11 — Release and onboarding

> **Status:** DONE 2026-11-20 — §1–§2 released and deployed (As run, genesis-release); §3 written back (As built,
> genesis-docs). Spec-drafted 2026-11-19. Repos: genesis, genesis-workflows, project-tracker. Parent:
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
3b. **Known CI risks at the tag (54-10 round 2):** `test_parse_returns_populated_result` counts bundles in filesystem
   order (backlog `phase-54-follow-ups.md` §2) and could go red if the runner's file order differs; the two
   `test_sail_cli` failures seen in `python:3.13` under colima are arm64-only. If either goes red at the tag, stop and
   ask the user; do not re-tag or skip the test on your own.
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
- **Known issue (D52, m7):** pausing a one-time schedule while its run is still going and resuming it afterwards adds a
  false "Missed" row, and the list shows Missed as its last result; the run itself is unaffected
  (`specs/backlog/phase-54-follow-ups.md` §1).
- Name every 54-10 row recorded "not run" or "export path not exercised" (A9) in the release notes (L-111).
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
  build findings). `genesis-ctx index && lint` green. The backlog file already exists (created 2026-11-20 with m7 and
  the parser bundle-order bug, D52): append to it, do not replace it.

## As built

**§3 done 2026-11-20 (genesis-docs).** Detail and the lesson decisions: `progress/phase-54-schedules-and-fixes.md`.
- **ADR-087** filed Accepted (`genesis-ctx add adr … --amends ADR-047 ADR-049 --status accepted --phase 54`), after
  bringing `adr-drafts.md` up to date (n6: D22 as amended by D50, D30, D31, D36–D43, D48, D49). ADR-047's and ADR-049's
  Status lines and one-liners point to it.
- **Lessons:** added L-120–L-125; extended L-005, L-011, L-014, L-026, L-043, L-080, L-090, L-091, L-094, L-096,
  L-106, L-107, L-108, L-109, L-110, L-112, L-115, L-116 (fingerprints refreshed).
- **Areas:** the new paths routed (`runs-worker`, `chat`, `config-secrets`, `kb-sync`, `features-stages`, `web-shell`,
  `web-runs`); the deleted `api/schedules.py` glob removed; no empty glob.
- **Code map:** `bible/03` "Phase 54" block + `tags/codemap.toml`.
- **State, history:** `context/state/current.md` overwritten (v0.83.0 / v0.27.0 / v0.3.1, DB v30, the As run's test
  counts); changelog, tracker §6, README row 54 → SHIPPED, `bible/08`, umbrella status.
- **Backlog:** `specs/backlog/phase-54-follow-ups.md` §3–§7 appended (§1–§2 kept).
- **Architecture docs:** genesis `bd99ee7` (local, not pushed; ships with the next release).
- **L0:** ~23,970 / 24,000 tokens after tightening the state snapshot; a compression is proposed to the user.
- `genesis-ctx index` + full `lint`: green.

## As run (2026-11-20, genesis-release)

**§1 and §2 are done; §3 is genesis-docs'.** Live acceptance (54-10) passed with SHIP at round 2. The rows it could not
run are named in the release notes below (L-111). Every push and every tag below was asked for and confirmed by the
user, one at a time, and so was the fleet start. Everything ran between 14:06 and 17:05 UTC, outside the D27 window
(18:30–20:30 UTC).

### Versions

| Repo | Version | Tag | Tagged commit |
|---|---|---|---|
| genesis | 0.83.0 (the app and the three packages; `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged; m0030, DB v30) | `v0.83.0` | `9617e06` (release commit on the reviewed head `9980b0c`) |
| genesis-workflows | 0.27.0 (`agent-prompt` 0.1.0; `schedulable` on `agent-prompt`, `sync-documents` 0.1.1, `generate-business-map` 0.1.1, `hello-appian` 0.1.1 from `e384914`/`7b35f8a`) | `v0.27.0` | `9066541` |
| playwright-appian | not released (unchanged at 0.3.1) | — | — |

### CI pipelines

| Repo | Pipeline | Ref / sha | Result |
|---|---|---|---|
| genesis | #7514744 | branch `ci/phase-54-pre-release` = `9980b0c` (L-112 pre-release run) | green, all six jobs; `genesis` 2054 passed, 68 skipped |
| genesis | #7515740 | `master` `9617e06` | green, all six jobs; `genesis` 2054 passed, 68 skipped |
| genesis | #7516285 | tag `v0.83.0` (`9617e06`) | green, all six jobs; `genesis` 2054 passed, 68 skipped |
| genesis-workflows | #7517025 | `master` `9066541` | green: library-validate, skills-validate, workflow-tests (463 passed); pip installed genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser 0.83.0 and genesis-workflows 0.27.0 |
| genesis-workflows | #7517189 | tag `v0.27.0` (`9066541`) | green |

The 54-11 §3b risks did not recur on the amd64 runner: `test_parse_returns_populated_result` (parser bundle order) and
the two arm64-only `test_sail_cli` tests passed in all three genesis pipelines.

### What happened, in order

0. **Preconditions.** genesis `9980b0c` and genesis-workflows `7b35f8a` matched the handoff; both trees clean; `git
   fetch` showed `origin/master` at `ea00dfd` / `d0c0f53`. An older red pipeline was found: genesis `master`
   **#7429033** (2026-11-15, `ea00dfd`), one test, `test_testexec_procs.py::test_reap_kills_a_recorded_group_that_is_still_ours`
   (`assert [] == [6524]`). It passed in all three pipelines today, so it looks flaky on Linux (follow-up below).
1. **genesis v0.83.0.**
   - Bump: 0.83.0 in the root and the three `packages/*/pyproject.toml`, the parser `__version__`, `create_app` and
     `web/src/version.ts` (`test_version_sync` 6 passed). README: the status heading and paragraph name Phase 54, the
     not-run rows and the m7 known issue; the migrations line reads m0001–m0030 (DB v30). The remaining `0.82.0`
     strings are lockfile pins in test fixtures and a probe seed (`tests/test_custom_agents.py`,
     `tests/test_schedules_api.py`, `scripts/probes/phase54-seed.py`). They are not version sources, so they stay.
   - m0030 was already in the tree (`41d4d0e`, unchanged since 54-10). A throwaway state dir migrated 1…30.
   - `npm run build` (117 bundle files changed by the version constant), each step in its own message (L-089).
   - **Local gates on the bumped tree:** app pytest **2122 passed** (11:07, nothing deselected); genesis-core **124**;
     kiro-agent-sdk **302**; parser all passed + 1 skipped; ruff clean in all four; web lint 0 errors (the 20 old
     warnings), typecheck clean, vitest **906 passed (81 files)**. (A first background pytest was killed by the
     tool's 2-minute limit at 23% and re-run in the foreground; the killed one counts for nothing.)
   - **L-112:** the reviewed head `9980b0c` was pushed to the branch `ci/phase-54-pre-release` (user's go-ahead) →
     #7514744 green, all six jobs, before the release commit.
   - **Release commit `9617e06`:** 8 source files (the 7 version sources + README) and 64 `web/static` files (`git
     show --stat -- web/static`). A fresh `npm run build` afterwards left `git status --short --untracked-files=all`
     empty (own message). Package data (L-048): the 0.83.0 wheel holds `genesis/db/migrations/m0030_schedules.py`
     and `genesis/web_static/index.html` (73 `web_static/` files).
   - `master` pushed → #7515740 green; tag `v0.83.0` created on `9617e06` (`rev-list` checked in its own message),
     pushed → #7516285 green.
2. **genesis-workflows v0.27.0.**
   - **Release commit `9066541`:** `pyproject.toml` 0.27.0; all four pins on `genesis.git@v0.83.0`
     (`genesis-core`, `kiro-agent-sdk`, dev `genesis-appian-parser` with `#subdirectory=packages/<name>`, dev
     `genesis` without; L-057); `registry.json` `genesis_core_version` 0.83.0, `genesis_core_major` stays 1. The
     workflow content was already in `e384914`/`7b35f8a` (54-05), reviewed in 54-10.
   - **CI-image run (L-112), before the commit:** colima (arm64) `python:3.13`. The genesis packages came from a
     `git archive 9617e06` and were installed with `scripts/install-packages.sh --dev`. The library was installed
     `--no-deps` (its pins name a tag that did not exist yet). Gate 9 PASSED, `genesis_core.mcp.pickable` imports,
     `validate_library` PASSED (19), `validate_skills` PASSED (5), pytest **463 passed**. Log:
     `/tmp/genesis-release-54-11/ci-image-workflows.txt` (not evidence; nothing secret in it). Colima was stopped
     afterwards. The same gates passed locally against the dev venv.
   - `master` pushed → #7517025 green; tag `v0.27.0` on `9066541`, pushed → #7517189 green.
3. **Deploy (§2, user's go-ahead), 22:15–22:30 IST (16:45–17:00 UTC).**
   - **Before:** the fleet had been down since the 01:15 IST reboot. `gsm status` said "running" only because the old
     pid files were stale. Neither pid existed, nothing listened on :8760/:8761, and `genesis up` checks the pid
     before it starts. Read-only (`?immutable=1`): main `genesis.db` v29, 497 runs; userb v29, 153 runs; no
     non-terminal run on either (the userb gate `r-9e903a4e5a0e` from 53-12 had already ended); both `memory.db` v1.
   - **Backup** `/tmp/genesis-release-54-11/backup/20261120-222649/` (`/tmp/genesis-release-54-11/backup.py`; SQLite
     online backup from an immutable source): main genesis.db integrity ok, v29, 497 runs; userb ok, v29, 153 runs;
     both memory.db ok, v1; plus each `installed.lock.json` and `.kiro/skills`.
   - `gsm provision --all --no-mcp --no-env --force` while down: 19 workflows on each instance from the checkout at
     `9066541` (ref `local`), including `agent-prompt` 0.1.0 and `hello-appian` / `generate-business-map` /
     `sync-documents` 0.1.1. This replaces the Catalog install/update step (same library, same versions).
   - `gsm start --all`: main pid **24383**, userb **24429**; `gsm status` healthy on both.
   - **After:**
     - `/openapi.json` `info.version` **0.83.0** on both;
     - `gsm exec <name> -- db status`: schema **v30**, nothing pending, memory.db v1, on both;
     - `/api/catalog` on both lists `agent-prompt` 0.1.0 and the three 0.1.1 workflows with `schedulable: true`;
     - **Schedules** (`GET /api/schedules`): five system rows on each instance and no user rows. Main's
       `application-sync` kept its edited schedule and `user_modified=1`. The `regression-run` dispatcher is gone
       on both. Main's only regression entry was `off` (54-10 §1.4), and userb has no testing workspace, so no
       regression row was created;
     - catch-up at the first tick, as announced to the user:
       - main `application-sync` 20:00 slot → `r-ea9479eee17e` `ok`, "1 apps: 1 ok, 0 skipped, 0 error (1 empty)";
       - `document-library-sync` 20:00 → `ok` on both (`r-5205362c6d9e`, `r-d6837fb362ff`);
       - userb `application-sync` → `skipped`, "scheduled syncs run on another machine (collaboration is on and
         this machine is not designated)";
       - the earlier slots → `missed` "Genesis was not running";
       - `memory-consolidation` 02:00 → `missed` (past its grace);
       - three bell notices on each instance;
     - 0 `Traceback`/`ERROR`/"database is locked" lines in either log since startup; 0 running runs afterwards;
     - The Schedules page was checked through its API (`/api/schedules`, `/schedules/{id}/history`), not in a browser.
     - userb's Memory maintenance row shows "Last result: failed". That is the m4 fallback reading the stored result
       of the 53-12 gate run, not this release.

### Release notes (the user checklist)

- **Versions:** genesis **v0.83.0** (DB v30, m0030 runs on the first start), genesis-workflows **v0.27.0**.
  `agent-prompt` needs genesis ≥ 0.83.0. The major-only gate (ADR-019) does not stop a 0.82 app from loading it, and
  there it fails at its first node.
- **Schedules is a new page.** The application-sync settings moved there from Settings → General, and the regression
  schedule moved there from Testing → Setup; existing cadences were migrated. On the first start Genesis catches up
  the latest missed slot of each system schedule within its grace, records the rest as Missed, and posts a bell notice.
- Agent-prompt schedules and Catalog → Agents need the `agent-prompt` workflow installed.
- Workflow runs now see your custom MCP servers when a workflow names them (D32). A custom server with the same name
  as a curated one is never used in a run.
- Unattended agent-prompt runs have Kiro's shell (ADR-083 risks until Phase 52) and only read-only MCP servers. A
  custom server's "read-only" mark is your own claim.
- In chat, a custom agent keeps chat's read-only tools. A custom server with no tool allowlist adds no tools there;
  give it an allowlist in Settings → MCP to use it in chat (D43).
- A run whose state was edited before v0.83.0 may still show **Running** with nothing happening (54-02 fixed the
  cause, not old runs, D21): cancel it from Run Detail. A stuck `sync-application` run blocks that app's scheduled
  sync until you do.
- **Known issue (D52, m7):** pausing a one-time schedule while its run is still going and resuming it afterwards adds
  a false "Missed" row, and the list shows Missed as its last result. The run itself is unaffected
  (`specs/backlog/phase-54-follow-ups.md` §1).
- **Not run in live acceptance (54-10 round 2, L-111):**
  - `story-implementation` (D47: no).
  - A real paused or gated `story-verification`, the implementation report frame on a fresh run, and a gate-waiting
    compose discard. These need QA plus a fresh `story-implementation`.
  - A14's Activity with pulled change requests, and M1's pulled-artifact frame on real data. The copy had no pulled
    artifact and collaboration was off; 54-12's throwaway-home probe covers the frame.
  - **A9: the application-sync export path and the `genesis-delta-*` package path were not exercised.** The Run now
    on Dev was `ok` but found no changes (D52 4).
  - n3 live (a gated scheduled run's Outcome); it is covered by the detail-page test.
  - Phase 51 (51-12 steps 1–27, D20) and Phase 53 (53-11 §5) live acceptance stay open as before.
- **API changes for anyone scripting:**
  - New: `/schedules*`, `/custom-agents*`, `/notifications*` (including `DELETE /notifications/{id}` → 204 and
    `POST /notifications/clear-read`).
  - Removed: `/system/sync-settings*`, `/system/schedules`, `PUT /applications/{uuid}/testing/schedule`.
  - Changed fields: `runs` items gained `trigger`; catalog items gained `schedulable`; `POST /chat/sessions` accepts
    `agent_id`.
  - Moved: make-Dev went from `POST /config/environments/{label}/dev` to `POST /config/environments/dev {label,
    is_dev}`; environment delete takes a label with `/`.
  - `POST /runs/{id}/pause` answers 503 when the pause could not be stored.
  - An unmatched `/api/*` path answers 404 JSON for every method (54-02).

### Deferred / follow-ups

- **The CI branch `ci/phase-54-pre-release` is still on origin.** Deleting it is a push; it waits for the user's
  go-ahead (or the GitLab UI).
- **Flaky Linux test:** `test_testexec_procs.py::test_reap_kills_a_recorded_group_that_is_still_ours` failed on
  `master` #7429033 (2026-11-15, `ea00dfd`) and passed in #7514744, #7515740 and #7516285. This is a candidate for
  `phase-54-follow-ups.md` (genesis-dev): reap probably reads `ps` before the long-lived child has exec'd with its
  marker.
- Backlog unchanged by this release: m7 (§1), parser bundle order (§2, green on amd64 at every pipeline today),
  D27 m1 (the clock test; CI kept outside 18:30–20:30 UTC), 54-12's deferred nits r2-n1…r2-n3, n5, n7.
- Scratch left in `/tmp/colima/gr-54-11` and `/tmp/genesis-release-54-11/img1` (copies of public repo trees, no
  secrets); the agent's `rm -rf` is denied, so the user may delete them. The backup in
  `/tmp/genesis-release-54-11/backup/` holds the user's databases: keep it until the user is happy with v0.83.0, then
  delete it.
- **For genesis-docs (§3):**
  - `context/state/current.md`: genesis v0.83.0, genesis-workflows v0.27.0, playwright-appian v0.3.1 (unchanged);
    DB v30 (m0001–m0030), memory.db v1.
  - Fleet: main + userb on v0.83.0 / DB v30 from the editable dev venv, 19 workflows (`agent-prompt` 0.1.0 new),
    `appian` 1.0.0 unchanged.
  - Test counts: app **2122** local / CI **2054 passed + 68 skipped**; genesis-core **124**; kiro-agent-sdk **302**;
    parser all passed + 1 skipped; web **906 (81 files)**; workflows pytest **463**, `validate_library` **19**,
    `validate_skills` **5**.
- **Lesson candidates:**
  - colima shares only `$HOME` and `/tmp/colima` into containers. A bind mount of another `/tmp` path shows up empty
    inside, and the run fails with "No such file or directory".
  - `gsm status` reports "running" from a stale pid file after a reboot: the `running` field is `healthy or pid is not
    None` (`genesis_fleet/manager.py:307`). Check the port, or the pid with `ps`, before trusting it.
  - A tool-launched background command can be killed at the tool's default timeout: run long gates in the
    foreground with an explicit timeout, and treat a log with no exit line as not run.
- **Process:** no L-089 batching of dependent steps: bump, build, commit, rebuild and status, tag and `rev-list`,
  push and `ci list`, backup and listing, provision, start and checks each went in their own message.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-030", "L-033", "L-048", "L-056", "L-057", "L-089", "L-100", "L-111", "L-112"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-doc-writeback/SKILL.md"]
code     = ["genesis/pyproject.toml", "genesis/web/src/version.ts", "genesis-workflows/registry.json", "genesis-workflows/workflows/agent-prompt/**"]
upstream = ["54-10"]
```
