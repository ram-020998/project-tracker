# Phase 54 — Schedules, custom agents, fixes and UX revamps — as built

> **Status:** 🚢 SHIPPED 2026-11-20 · genesis **v0.83.0** (`9617e06` = release commit on the reviewed head `9980b0c`;
> the app and the three packages at 0.83.0, `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged) → genesis-workflows
> **v0.27.0** (`9066541`; `agent-prompt` 0.1.0; `schedulable` on `agent-prompt`, `sync-documents` 0.1.1,
> `generate-business-map` 0.1.1, `hello-appian` 0.1.1; all internal pins on `genesis.git@v0.83.0`) · playwright-appian
> unchanged at v0.3.1 · m0030 (DB 29 → 30; memory.db v1) · **ADR-087** Accepted (amends ADR-047, ADR-049).
> Live-accepted before the release (D20): 54-10 SHIP at round 2, with the rows named under "Live acceptance" not run.
> Spec: `specs/phase-54-schedules-and-fixes.md` + `54-01..54-12` (each with its As built; 54-11 has the As run).
> Reviews: `specs/phase-54-schedules-and-fixes/reviews/`. Follow-ups: `specs/backlog/phase-54-follow-ups.md`.
> CI: genesis pre-release branch #7514744, master #7515740, tag #7516285 (all six jobs green, 2054 passed + 68 skipped);
> genesis-workflows master #7517025 + tag #7517189.

## What changed

- **For a user:** a **Schedules** page (after Runs) holds every schedule. The five system schedules (application sync,
  document library sync, Hub KB pull, memory consolidation, memory maintenance) are editable and resettable, not
  deletable; the application-sync settings moved there from Settings → General and each app's regression cadence from
  Testing → Setup (migrated once). User schedules run a `schedulable` workflow, an agent prompt or an app's regression
  suite, with five frequency forms, missed-slot catch-up, overlap skip, gate time-out, a run time limit and auto-pause
  after failures. The top-bar bell is a real notification center. **Catalog → Agents** holds custom agents, which an
  agent-prompt schedule, a one-off Run and a read-only chat can use. The story Design / Implementation / Verification
  tabs and the feature Overview / Activity tabs were rebuilt from approved mockups. Fixes: editing a paused or gated
  run's state keeps its status (B1); saved artifacts show per turn (B2); failed captures can be discarded (O1);
  environments whose label contains `/` can be made Dev and deleted, and an unmatched `/api/*` path answers 404 JSON
  (O4). A blocking program step no longer locks `genesis.db` (D49); agent-written HTML opened read-only cannot script
  the app's origin (D48).
- **For a developer:** m0030 (`scheduled_jobs` columns, `schedule_runs`, `notifications`, `custom_agents`,
  `runs.trigger_json`, `chat_sessions.agent_json`); `runtime/schedule_model.py`, `scheduler.py` (rewritten),
  `schedule_store.py` (rewritten), `schedule_targets.py`, `notifications.py`; `genesis/agents/`; routes `/schedules*`,
  `/custom-agents*`, `/notifications*`; removed `/system/sync-settings*`, `/system/schedules`,
  `PUT /applications/{uuid}/testing/schedule`, `api/schedules.py` and `testexec/regression_job.py`; `db/database.py`
  `retry_when_busy`. genesis-core (additive): `kiro_node` per-run callables for `skills`, `mcp`, `model`;
  `mcp/pickable.py` (the D3 read-only server rule); `McpRegistry` tiers; `program_node` off the loop. Shared web
  primitives: `SectionCard`, `DefinitionList`, `StatusHeader`, `Timeline`, `MultiSelect`, `RowMenu`, `TimeInput`,
  `StatGrid`, `DataTable`, `SearchInput`. Code map: `bible/03` "Phase 54" block. Architecture docs: genesis
  `bd99ee7` (local).
- **For the agent system:** areas route the new paths (below); no skill changed.

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 54-01 | Findings; decisions D1–D52 (Q&A and build rulings); defaults F1–F12 | — |
| 54-02 | B1 `_spawn_edit`, B2 two canonical kinds + old-row fold, B3 dead code, O1 discard of failed and gated captures, O4 `{label:path}` + `POST /config/environments/dev` + every-method catch-all; review SHIP (re-run 1) | genesis `ea00dfd..eed5da0` (9) |
| 54-03 | `/dev/phase-54` mockups of 11 surfaces; shared `SectionCard`, `DefinitionList`, `StatusHeader`, `Timeline`, `MultiSelect`; probe 162 entries clean; user review D22–D29; review SHIP (re-run 2) | genesis `eed5da0..b09b08e` (10) |
| 54-04 | m0030, schedule model, store, engine (F2, D8, D10, D12, D30, D31), target handlers, notifications store, `runs.trigger_json`, regression dispatcher retired; review SHIP (re-run 2) | genesis `b09b08e..9a365c0` (4) |
| 54-05 | `kiro_node` per-run callables, `McpRegistry` tiers, `mcp/pickable.py` (D33), custom-agents store + inputs builder, worker custom-only registry (D32), `schedulable` + lint + catalog, Run route; `agent-prompt` 0.1.0 + three `schedulable` flags; review SHIP (re-run 1) | genesis `9a365c0..9f63fc2` (2); workflows `d0c0f53..7b35f8a` (2) |
| 54-06 | The HTTP contract (`/schedules*`, `/custom-agents` CRUD, `/notifications*`, chat `mode`/`agent_id`, runs `trigger`, `schedulable`), m0030 edited in place (D36, D37), web types, clients, fixtures; review SHIP (re-run 1) | genesis `9f63fc2..a6cc287` (3) |
| 54-07 | Schedules list, detail and wizard; Catalog → Agents; the bell; `RowMenu`, `TimeInput`; the F7 removals; Setup pointer, Runs badge; D40; review SHIP (re-run 2) | genesis `a6cc287..41971a0` (13) |
| 54-08 | Read-only chat with a custom agent (D6, D26, D43, D44); zero-credit live probe PASS; review SHIP | genesis `41971a0..8f8b1a1` (4) |
| 54-09 | D42 zone names; feature Activity endpoint + `summary` + `run_status`; feature Overview/Activity and story Design/Implementation/Verification tabs; CSP + nosniff on the design artifact; review SHIP (re-run 1) | genesis `8f8b1a1..2ad1c50` (7) |
| 54-10 | Whole-phase review + live acceptance on a copy of the real home (D46): round 1 NEEDS_CHANGES (B1, M1, M2, m1–m6), **round 2 SHIP**; 9.88 credits metered in round 2 | — (review only) |
| 54-12 | Fix pass: B1/D49 (`program_node` off the loop, `retry_when_busy`, honest missed reason, terminal reconcile, pause 503), M1/D48 (HTML headers, sandboxed pulled frame, `:target` clause highlight), M2, m1–m6, D50's six changes (`SearchInput`, `DataTable`, row click, bell Remove / Clear read, one Edit, Agents search); review SHIP (round 2) | genesis `2ad1c50..9980b0c` (13) |
| 54-11 | Release (As run): genesis v0.83.0 after a pre-release CI branch run (L-112); genesis-workflows v0.27.0 after a CI-image run; fleet backed up, provisioned and started on v0.83.0 / DB v30; this write-back | genesis `9617e06`; workflows `9066541` |

Test counts at the release: genesis app pytest 2122 locally, CI 2054 passed + 68 skipped; web vitest 906 (81 files);
genesis-core 124; kiro-agent-sdk 302; parser all passed + 1 skipped; genesis-workflows pytest 463,
`validate_library` 19, `validate_skills` 5.

## Deploy (54-11 §2, 2026-11-20 22:15–22:30 IST)

The fleet had been down since the 01:15 IST reboot (`gsm status` said "running" from stale pid files, L-125). Both
`genesis.db` (main v29, 497 runs; userb v29, 153 runs) and both `memory.db` were backed up with SQLite's online backup
to `/tmp/genesis-release-54-11/backup/20261120-222649/`, integrity ok. `gsm provision --all --no-mcp --no-env --force`
installed 19 workflows on each instance from the library at `9066541` (replacing the Catalog install step);
`gsm start --all` → main pid 24383, userb 24429. After: `/openapi.json` 0.83.0 and schema v30 on both; `/api/catalog`
lists `agent-prompt` 0.1.0 and the three 0.1.1 workflows as `schedulable`; five system rows on each instance, main's
`application-sync` kept its edit (`user_modified=1`), no regression row (main's only entry was off; userb has no
workspace). First-tick catch-up: main `application-sync` `ok` (1 app, empty), `document-library-sync` `ok` on both,
userb `application-sync` `skipped` (not the designated machine), earlier slots `missed`; no Traceback, ERROR or
"database is locked" in either log. The Schedules page was checked through its API, not in a browser.

## Live acceptance (54-10, D20, D46, D47, D52)

Ran on a copy of the user's real home (online backup, collaboration and other system schedules off on the copy).
Round 2 (on `9980b0c`): A1 (the user's verdict, D52), A2 (an agent-prompt once fired while a 180 s blocking step ran,
0 of 210 lock samples locked), A4 (a QA regression via its schedule, `TE-000013` passed), A6, A7, A8 (a red regression
`failed` and not counted, D30), A9 (app-sync Run now on Dev `ok`, empty), A10–A11 (chat-agent probe PASS), A12, A13,
A14 (a real `story-design-analysis` re-run on story 74), A15–A17 PASS. **Not run** (named in the release notes, L-111):
`story-implementation` (D47); a real paused or gated `story-verification`, the implementation report frame on a fresh
run, a gate-waiting compose discard (QA + a fresh implementation); A14 Activity with pulled CRs and the pulled-artifact
frame on real data (no pulled data on the copy; 54-12's probe covers the frame); the app-sync export and
`genesis-delta-*` package path (no changes on Dev, D52 4); n3 live. Phase 51 (51-12 steps 1–27) and Phase 53 (53-11 §5)
acceptance stay open.

## Decisions and deviations

- **ADR-087** filed Accepted from `adr-drafts.md`, brought up to date first (54-10 review n6): D22 as amended by D50,
  D30, D31, D36–D43, D48, D49. It also records that the worker's registry refines ADR-029 for runs (D32: custom-only
  names, a custom entry never replaces a curated one in a run); no formal amendment link was added (the release named
  only ADR-047 and ADR-049). ADR-047's and ADR-049's one-liners and Status lines now point to ADR-087.
- D36/D37: m0030 was edited in place twice before the release, safe because neither fleet database had applied it
  (process start times checked each time); the fleet stayed down until 54-11.
- D52: m7 shipped as a known issue at the user's choice; the parser's filesystem-order bundle count is backlog §2 (it
  passed on amd64 in all three genesis pipelines).
- 54-11 §3b risks did not recur at the tag. An older red pipeline, genesis master #7429033 (`ea00dfd`,
  `test_reap_kills_a_recorded_group_that_is_still_ours`), passed in all three pipelines today: filed as flaky.
- No ADR deviation in any sub-spec.

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| A fire-and-forget handler records `ok` for a run that later fails (54-01 §2.4, D12) | **Added L-120** |
| An op reusing the run's stop path is read as a stop (54-02 B1) + a "marker kept" test must fail when the wiring regresses (54-02 M1) | **Added L-121** (merged) |
| A kind missing from the canonical list is stored but invisible (54-02 B2) + give a list contract test the backend's own list (54-06) | **Added L-122** (merged); L-005 and L-011 point to it |
| Opacity modifiers on `var()` colours generate no CSS (54-03) + moving one into a shared component is a visible change (54-12) | **Added L-123** (merged) |
| Level-triggered state must live on the durable row (54-04 B1) + a close-time decision is stored with its row (54-06 D36) + one clock for the scheduler (54-04, D27 flake) | **Added L-124** (merged) |
| Copy a live WAL database with `.backup` (D46, 54-11) + `gsm status` trusts a stale pid file (54-11) | **Added L-125** (merged) |
| A blocking program step holds the write lock (54-10 B1, D49) + block the first node in the fail-first test + a probe waiting on an asyncio event cannot see it (54-12) | **Extended L-026** (also corrects its "`program_node` is sync-only") |
| Set a stop flag only after the write it guards (54-12 M-1) | **Extended L-108** |
| A guard for a row "just opened" must be lifted on every exit (54-04 M1) | **Extended L-107** |
| GET-only catch-all → 405 (54-02) + a free-text path segment breaks at `/` (54-02) + typed `{id:int}` convertors (54-06) | **Extended L-096** |
| Feedback is an answer to every gate (54-05 M1) | **Extended L-106** |
| Recompute a rule at the executor (54-05) + a worker's rebuilt registry dropped the custom tier (54-05) | **Extended L-116** |
| A new link to an agent-HTML route is a new exposure (54-09 M1, D48) + an init script's `localStorage` throws in a sandboxed frame (54-12) | **Extended L-043** |
| A frame's `theme=` reaches only what the route themes (54-09) + `inline-flex` never narrows (54-12 M2) + `<wbr>` at identifier boundaries (54-09) | **Extended L-090** |
| jest-axe misses dropped focus and a label not in the name (54-03 m5/m6) + an open Popover needs a name (54-07) | **Extended L-014** |
| Regenerating golden fixtures churns timestamps and ids (54-07) | **Extended L-011** |
| A probe seed wrote invalid front matter (54-07) | **Extended L-115** |
| A partial update over a defaults-first validator resets fields (54-06 m2, n8) | **Extended L-091** |
| Carry a dispatcher's covered floor into the new rows (54-04) | **Extended L-080** |
| `awaiting_input` is two states (54-09 M2) | **Extended L-094** |
| Split a whole-list validator → carry its cross-item rules (54-08) | **Extended L-109** |
| colima shares only `$HOME` and `/tmp/colima` (54-11) | **Extended L-112** |
| A tool-launched background command killed at the default timeout (54-11) | **Extended L-110** |
| jest-axe per frame for two options of one surface; mockup dates relative to page load (54-03) | **Dropped**: mockup-only, recorded in 54-03's As built |
| The browser names the zone by an alias (54-03, 54-07) | **Dropped** as a lesson: its home is D42 (`zones.ts` `ZONE_RENAMES`) |
| A hidden field kept in a shared form slot leaks across forms (54-07 M1); a data-driven poll for "the id arrives later" (54-07) | **Dropped**: specific to the wizard and recorded in 54-07's As built |
| A test holding an element reference misses a re-render; say a weaker capability where the user picks it (54-08) | **Dropped**: common testing-library practice; the second is D43's UI note |

## Architecture documents (genesis `bd99ee7`, local)

Rewritten: `modules/scheduler-and-jobs.md` (now "Module: Schedules"). New: `modules/custom-agents.md`. Updated:
`api.md` (new and removed routes, environment routes, the every-method catch-all, the 422 `{detail, field, refused?}`
convention and FastAPI's own field-less 422s), `configuration-and-secrets.md`, `runs-and-workers.md`,
`core-engine.md` (per-run `kiro_node`, `pickable.py`, `program_node` off the loop), `workflow-library.md`
(`agent-prompt`, `schedulable`), `web-app.md`, `chat-and-skills.md`, `features-and-stages.md`,
`stories-and-workbench.md`, `data-and-migrations.md` (m0030, `retry_when_busy`), `knowledge-base.md`, `testing.md`,
`memory.md`, `distribution.md`, `documents.md`, `collaboration-hub.md`, `observability-and-credits.md`, the numbered
documents, the glossary and the README. Reviewed, header only: `kiro-agent-sdk.md`, `appian-parser.md`. No module
document is "planned". The grep for `regression_job`, `sync-settings`, `system/schedules`, `testing/schedule` and
`{label}/dev` finds only sentences that say Phase 54 removed them. The module edits were drafted by three genesis-docs
sub-agents with disjoint files and checked here.

## Agent-system notes

1. Areas: `runs-worker` gains `runtime/schedule_*.py`, `sync_jobs.py`, `memory_jobs.py`, `notifications.py`,
   `api/schedule_routes.py`, `api/notifications.py`, `genesis/agents/**`, `api/custom_agents.py` and
   `genesis-workflows/workflows/agent-prompt/**` (the deleted `api/schedules.py` is gone); `chat` gains the custom-agent
   paths and `web/src/features/catalog/agents/**`; `config-secrets` gains `genesis_core/mcp/pickable.py` and
   `genesis/agents/**`; `kb-sync` gains `sync_jobs.py`; `features-stages` gains `services/feature_activity.py`;
   `web-shell` gains `features/schedules/**` and `features/notifications/**`; `web-runs` gains `features/schedules/**`.
2. No skill changed, so `update.sh` is not needed.
3. **L0 is at ~23,970 / 24,000 tokens.** ADR-087, six lessons and two one-liners pushed it to ~24,280; the state
   snapshot was tightened to fit (no rule dropped). The next phase will not fit without a compression; proposed to the
   user, not applied.
4. ADR-087's body and the lesson bodies were written from scratch files (`context/.packs/`, git-ignored); every
   `genesis-ctx add` ran alone.
