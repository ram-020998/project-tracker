# Phase 54 — Schedules, custom agents, fixes and UX revamps

> **Status:** 🚢 **SHIPPED 2026-11-20** — genesis **v0.83.0** (`9617e06`) → genesis-workflows **v0.27.0** (`9066541`),
> CI green; m0030 (DB v30); **ADR-087 Accepted** (amends ADR-047, ADR-049, ADR-029). Live-accepted before the release (54-10 SHIP,
> round 2; the not-run rows are in the release notes, 54-11 As run). Known issue m7 (backlog §1). Progress:
> `progress/phase-54-schedules-and-fixes.md`; follow-ups: `specs/backlog/phase-54-follow-ups.md`.
> Spec-drafted 2026-11-19 (genesis-spec). Q&A complete: decisions D1–D20, defaults F1–F12; build rulings D21–D52
> (`phase-54-schedules-and-fixes/54-01-findings.md` §8–§9).
> Sub-specs: `phase-54-schedules-and-fixes/54-01..54-12`. ADR draft (filed): `phase-54-schedules-and-fixes/adr-drafts.md`.
> Repos: **genesis** (scheduler, store, migration m0030, APIs, web, chat, `packages/genesis-core` `kiro_node`),
> **genesis-workflows** (the `agent-prompt` workflow, `schedulable` flags), **project-tracker** (ADR-087, areas).
> Builds on genesis v0.82.0. Does not wait for the open Phase 51/53 live acceptance (D19); Phase 52 stays deferred.

## 1. Why this phase exists

Genesis runs six scheduled jobs, configured in two places (Settings → General, Testing → Setup), and four of them have
no UI at all (54-01 §2.2). The user cannot schedule their own work. Runs do not record what started them, a run at a
gate waits forever, and one job records `ok` for runs that later fail (§2.4). Alongside this, the user found two broken
actions (environment delete, failed Compose proposals) and three code defects (§3), and wants four pages redesigned
(§4).

## 2. Goal

1. **Schedules page** in the primary navigation: every schedule in one list, system ones editable and user ones
   created, edited, duplicated and deleted (D1, D15).
2. **Three user targets:** a `schedulable` workflow with stored inputs (D7), an agent prompt that writes Markdown
   (D1–D3), an application's regression suite (D14).
3. **Custom agents** in Catalog → Agents, used by schedules, a one-off Run and the read-only chat (D4–D6).
4. **Reliable unattended runs:** presets + once (D9), missed-slot catch-up and overlap skip (D10), gate time-out (D8),
   result follows the run, run time-out, auto-pause after failures (D12), notices in a real notification center (D11).
5. **Fixes:** B1–B3, O1, O4 (§3).
6. **UX revamps** of the story Design and Implementation tabs and the feature Overview and Activity tabs, mockups first
   (D17, D18).

## 3. Decisions (locked with the user, 2026-11-19 — detail and rationale in `54-01-findings.md` §8–§9)

| # | Decision |
|---|---|
| D1 | Scope: Schedules + fixes (B1–B3, O1, O4) + UX revamps; housekeeping loops are not schedules. |
| D2 | Agent-prompt agent: Phase 53 D9 built-ins (shell included), auto-approved; ADR-083 risks accepted for unattended runs. |
| D3 | Only read-only MCP servers pickable (`appian-dev`, `genesis-kb`, `appian-atlas`, custom with the user's mark); no `pre_mutation` gate. |
| D4 | Custom agents = Genesis-owned profiles in a new Catalog → Agents tab; never `~/.kiro/agents`. |
| D5 | Used in agent-prompt schedules, a Catalog Run, and Chat (read-only posture kept). |
| D6 | In chat, only the read-only assistant mode takes a custom agent; fixed for the session. |
| D7 | Schedulable workflows opt in with `META.schedulable: true`. |
| D8 | A scheduled run at a gate: notice; cancelled if unanswered by the next slot or 24 h (per schedule). |
| D9 | Frequency: every N hours in a window, daily, weekly, monthly, once; IANA zone; next 5 runs; no cron. |
| D10 | Missed: latest missed slot once within 12 h grace, older ones `missed`; overlap: skip and record. |
| D11 | The top-bar bell becomes a real notification center (`notifications` table). |
| D12 | Result = run's final status; max run duration (2 h); readiness skips are not failures; auto-pause after 3 failures. |
| D13 | No previous-run context this phase. |
| D14 | Each app's regression schedule is its own row (target "Regression suite"); the `regression-run` dispatcher retires. |
| D15 | System schedules' options live only on their Schedules row (the Settings sync card goes). |
| D16 | "URLs not encrypted" dropped: loopback http, no secrets in URLs. |
| D17 | Mockups first (`/dev/phase-54`), user approval before the real build of new or revamped surfaces. |
| D18 | Feature Activity covers every feature-level event (all stages' lifecycle, stage runs, CRs, finalization). |
| D19 | One release: genesis v0.83.0 → genesis-workflows v0.27.0. |
| D20 | Phase 54 live-accepted before its release. |
| D21 | No repair of runs a pre-fix state edit left stored `running`; the user cancels them by hand (after 54-02). |
| D22–D29 | From the 54-03 mockup review: list layout (weekday strip, status tag, lock icon), switch = on/off only with Pause in the menu, full-page wizard with the shared `MultiSelect` and locked agent picks, app-sync options as text + Edit, no Copilot toggle with a custom agent, Implementation documents as tabs in one card, the rest approved as mocked, a 24-hour time control. |
| D30 | A regression run with red tests is `failed` with a notice but does not count toward auto-pause (during 54-04). |
| D31 | Gate and paused time does not count toward a run's max duration; a hand-paused run is never auto-cancelled (during 54-04). |
| D32–D35 | During 54-05: workflow runs load custom-only MCP servers; the D3 rule lives in `genesis_core/mcp/pickable.py` and the node re-checks it; `schedulable` on `agent-prompt`, `sync-documents`, `generate-business-map`, `hello-appian`; a model change is refused while the model list is unreadable. |
| D36–D39 | During 54-06: `counts_toward_pause` and the chat-session snapshot column added to the unreleased m0030 in place (the fleet must not apply m0030 before the release); chat `agent_id` answers 409 until 54-08; the API defaults (422 body, run-now answer, `?limit=0` unread count); `GET /schedules/{id}/sync-status` for the app-sync detail. |
| D40 | A second regression schedule for the same app is refused (spec reading of D14; after 54-06). |
| D41 | The Agents Run dialog shows an Open run link (as mocked); D40 also refuses Duplicate of a regression schedule (after 54-07). |
| D42 | The zone picker shows and stores current IANA names (`Asia/Kolkata`, not `Asia/Calcutta`); built in 54-09 §0. |
| D43–D44 | In chat a custom server with no tool allowlist adds no tools (ADR-031); each custom agent has its own Kiro agent id, and an explicit model wins over the agent's (after 54-08). |
| D45 | 54-09's ten data-source and layout points (CR items from the CR store, honest run history, no invented actors or rows, `summary` + `run_status` on the feature read, gated Re-run design, lane-derived code-review wording, no blob-URL report). |
| D46 | 54-10 runs on a copy of the user's real home (SQLite online backup, collaboration and other system schedules off on the copy, deleted afterwards); the fleet stays at v29 until the release. |
| D47 | 54-10 live permissions: colima CI-image run, a QA regression, an app-sync Run now on Dev, a design re-run on story 74 (no `story-implementation`), 5–10 credits; A13's "reproduced" half is 54-02's fail-first tests; the fleet stays down until 54-11. |
| D48 | The 54-10 fix pass also closes three older agent-HTML paths: the pulled stage artifact's frame (sandboxed, annotation checked live), the CR document and the spec-clause link (CSP + nosniff). |
| D49 | B1 is in this release: program steps run off the worker's event loop (genesis-core `program_node`, API unchanged) and the scheduler survives "database is locked" without losing slots or recording false outcomes; A2, A7, A9 re-run live after the fix. |
| D50 | A1 verdict: everything matches the mockup except six changes (Runs-page filters, search and grid on Schedules; no line above the grid; whole row clickable; Remove / Clear read for read notices; one Edit on app sync; search on Catalog → Agents). |
| D51 | The 54-10 round-1 fixes and the D50 changes are one new sub-spec, 54-12, built before 54-10's re-review. |
| D52 | 54-10 round 2: A1 matches; A14 and A8 finished on the copy; A9 passes without an export; m7 and the parser's order-dependent bundle count go to the backlog (`specs/backlog/phase-54-follow-ups.md`), m7 named in the release notes; then the release. |

## 4. Current state (code-grounded — full detail in `54-01-findings.md` §2–§4)

- Scheduler: 60 s asyncio tick, two schedule kinds, boot-registered handlers, `scheduled_jobs` (m0012 + m0023), same-day
  catch-up only, no trigger on runs (§2.1, §2.4).
- Six jobs (§2.2); web editors only for app sync and per-app regression.
- Agent nodes fix skills/MCP/model at graph build (§2.4 item 4); the launch form is reusable (`buildLaunchForm`).
- Bugs confirmed in code (§3); UX surfaces mapped (§4).

## 5. Design overview

| Concern | Sub-spec |
|---|---|
| Findings, research, decisions | 54-01 |
| Fixes B1–B3, O1, O4 | 54-02 |
| Mockups of every new and revamped surface (approval gate) | 54-03 |
| Schedule model, store, m0030, scheduler engine, unattended rules, system + regression migration, notifications backend | 54-04 |
| Custom agents store, `kiro_node` callables, `agent-prompt` workflow, `schedulable` flags | 54-05 |
| HTTP API | 54-06 |
| Web: Schedules page, Catalog → Agents, bell, Settings/Testing moves, Runs badge | 54-07 |
| Chat with a custom agent | 54-08 |
| UX revamps: story Design/Implementation, feature Overview/Activity (+ activity backend) | 54-09 |
| Review, hardening, live acceptance | 54-10 |
| Fix pass after 54-10's round 1 (review findings + the user's A1 changes) | 54-12 |
| Release + docs write-back | 54-11 |

## 6. Session plan

S1 = 54-02 → S2 = 54-03 (**gate:** the user approves the mockups; requested changes are recorded as decisions in
54-01 §8 and folded into 54-07/54-08/54-09 before they start) → S3 = 54-04 → S4 = 54-05 (genesis + genesis-workflows)
→ S5 = 54-06 (each backend sub-spec adds its routes; 54-06 owns the contract table, web types and fixtures) → S6 =
54-07 → S7 = 54-08 → S8 = 54-09 → S9 = 54-10 round 1 (genesis-review) → S9b = 54-12 (genesis-dev, the fix pass) → S9c
= 54-10 re-review and remaining live rows → S10 = 54-11 (genesis-release, then genesis-docs). One at
a time: they share the genesis checkout. Every intermediate commit keeps the gates green; the old sync-settings and
testing-schedule endpoints stay until 54-07 moves the web off them.

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 54-01 | project-tracker | Findings, research, decisions D1–D20, defaults F1–F12 |
| 54-02 | genesis | B1 paused-run state edit, B2 `artifact.saved` events, B3 dead code, O1 discard failed captures, O4 environment labels with `/` + honest 404 for unmatched `/api/*` — **BUILT** (genesis `ea00dfd..eed5da0`, local; review SHIP, `reviews/54-02-review.md`) |
| 54-03 | genesis (`web/src/dev/`) | `/dev/phase-54` mockups with stub data: Schedules list/detail/wizard, Catalog → Agents + Run, bell, chat agent picker, story Design + Implementation, feature Overview + Activity — **BUILT** (genesis `eed5da0..b09b08e`, local; review SHIP; user review D22–D28) |
| 54-04 | genesis (`runtime/`, `db/`, `testexec/regression_job.py`) | m0030; schedule model (D9); scheduler engine (F2, D10, D8, D12); system rows + regression migration (D14, D15); `runs.trigger_json`; `schedule_runs`; notifications store; ADR-087 draft kept current — **BUILT** (genesis `b09b08e..9a365c0`, local; review SHIP; `9a365c0` unreviewed, carried to 54-10) |
| 54-05 | genesis (`packages/genesis-core`, `runs/`, new `agents/`), genesis-workflows | `custom_agents` store; `kiro_node` callables (F4); `agent-prompt` workflow; `schedulable` META key + parity lint; read-only server rule (D3) enforced at launch and in the node — **BUILT** (genesis `9a365c0..9f63fc2`, genesis-workflows `d0c0f53..7b35f8a`, local; review SHIP) |
| 54-06 | genesis (`api/`, `web/src/types`, `web/src/lib/api`) | Contract table: `/schedules*`, `/custom-agents*`, `/notifications*`, chat `agent_id`, activity items; removals (F7); fixtures — **BUILT** (genesis `9f63fc2..a6cc287`, local; review SHIP); the removals moved to 54-07 |
| 54-07 | genesis (`web/`) | Schedules page, wizard, detail + history; Catalog → Agents tab + Run; bell; Settings → General card removed; Testing → Setup link; Runs badge; nav entry — **BUILT** (genesis `a6cc287..41971a0`, local; review SHIP; with the F7 removals and the 54-06 review fixes) |
| 54-08 | genesis (`chat/`, `api/chat.py`, `web/src/features/chat/`) | Read-only chat session with a custom agent (D6) — **BUILT** (genesis `41971a0..8f8b1a1`, local; review SHIP; live no-prompt probe PASS) |
| 54-09 | genesis (`web/src/features/workbench/`, `web/src/features/features/`, `api/features.py`, `shared/`) | Story Design + Implementation tabs; feature Overview + Activity (+ activity endpoint, D18); shared section card / definition list / timeline — **BUILT** (genesis `8f8b1a1..2ad1c50`, local; review SHIP; with D42) |
| 54-10 | all | Review + gates + live acceptance (D20) — **SHIP** (round 2, genesis `9980b0c`; `reviews/54-10-review.md`; not-run rows listed there for 54-11) |
| 54-11 | genesis, genesis-workflows, project-tracker | Releases + docs write-back (ADR-087, lessons, areas, state, progress) — **SHIPPED** (genesis v0.83.0 `9617e06`, genesis-workflows v0.27.0 `9066541`; fleet on v0.83.0 / DB v30; write-back 2026-11-20) |
| 54-12 | genesis (genesis-core, runtime, api, web) | Fix pass: 54-10 round-1 findings (B1, M1, M2, m1–m6, nits; D48, D49) and the user's A1 changes (D50); built between 54-10's round 1 and its re-review (D51) — **BUILT** (genesis `2ad1c50..9980b0c`, local; review SHIP at round 2; no migration change) |

API sub-spec: **54-06**.

## 8. Release plan

One release (D19), after 54-10 = SHIP with its live acceptance done (D20): **genesis v0.83.0** (m0030, DB v29 → v30;
app + three packages at one shared version, ADR-080; genesis-core change additive, `CORE_MAJOR` 1), then
**genesis-workflows v0.27.0** (`agent-prompt` workflow, `schedulable` flags; pins on `genesis.git@v0.83.0`, L-057).
Users: Settings → General's sync card moved to Schedules; per-app regression cadences are migrated into schedule rows;
install `agent-prompt` from the Catalog to use agent-prompt schedules (L-033).

## 9. Scope

**In:** §2. **Out:** cron expressions; event or webhook triggers; posting agent output to chat spaces or Google
Workspace; previous-run context (D13); per-schedule credit caps; schedule-level retries; templates, folders, tags;
Hub-shared schedules (F11); custom agents in Copilot or spec-style chat modes (D6); write-capable MCP servers in
agent-prompt schedules (D3); URL changes (D16); multi-user anything (ADR-026). **Deferred to the backlog**
(`specs/backlog/phase-54-follow-ups.md`, created at write-back): previous-run context (D13), cron, output destinations,
credit caps, schedule templates, custom agents in more chat modes; m7 (a paused-then-resumed `once` gets a false "missed" row) and
the parser's bundle count depends on filesystem order (54-10 round 2), both already filed in
`specs/backlog/phase-54-follow-ups.md` (D52); from 54-02's review: the 405 answer has no `Allow`
header (n1), and Discard on a failed capture whose run is still live cancels it without a confirm (n2, rare); from
54-03: opacity modifiers on token colours (`bg-primary/10` …) generate no CSS because `tailwind.config.ts` maps colours
to bare `var()`; 8 existing source files use them (e.g. `VerificationSection.tsx`, `TopBar.tsx`); from 54-04: in the
repeated hour when clocks go back, a schedule edited inside that hour could re-fire a slot (`slot_key` drops `fold`,
one hour a year); `memory_jobs._kiro_ready` / `_installed` and `start_sync` inside the serial app sync still run on the
event loop (pre-existing, L-026); review nits n1 (a third copy of the `_installed` / `_kiro_ready` helpers) and n4 (a
few-bytecode window between the open row's commit and `_mine.add`), accepted; from 54-05: review n4 (an earlier gate
round's Feedback stays in later `agent-prompt` prompts) and n5 (a hand-sent non-string Feedback), and the pre-existing
L-106 pattern in `memory-consolidation` / `memory-maintenance`, whose escalation routes every non-approve answer,
Feedback included, to the reject path; from 54-07: a sync-option range refusal (such as 150 %) is a field-less 400
shown as the general message, not on its field; the pre-existing opacity-modifier files it listed (`TopBar.tsx`,
`RunDetailPage.tsx`, `RunsTable.tsx`, `LaunchForm.tsx`, `SetupView.tsx`, `Badge`'s primary tone); from 54-09: feature
Activity pages by offset, so an item arriving between "Load more" clicks can repeat once (a cursor would fix it); a
stage card's "Last run" shows only the status (the stage row stores no run time); from 54-12's round-2 review: an
unused `isAttention` in `web/src/features/runs/hooks.ts`, no test for the Clear read error message, and in the pause
corner case (the worker dies during the retried status write) the 503 text still says "still running" after the run
has failed; from 54-10: provisioned skill files appear in a run's documents list (n5).

## 10. Defaults

F1–F12 in `54-01-findings.md` §9 (confirmed 2026-11-19).

## 11. Risks

| Risk | Mitigation |
|---|---|
| An unattended agent with a shell misbehaves on a timer (D2, ADR-083) | Read-only servers only (D3); run time-out (D12); auto-pause; the prompt and agent are visible on the row; Phase 52 closes the isolation gap |
| A custom server marked read-only by the user has write tools (D3) | The mark is the user's recorded claim, shown on the schedule; ADR-087 states it is not verified |
| The scheduler change regresses app sync (L-050 serialization, designated machine) | 54-04 keeps app sync's handler and skip rules; acceptance runs a real app sync from its row |
| Migration loses user edits to app sync or regression cadences (L-081) | 54-04 migrates once, with tests from real stored rows; respects `user_modified` |
| Removing old endpoints breaks a caller (L-094) | 54-06 lists every consumer (backend, web, tests, copilot tools) before removal |
| Laptop sleep makes due times drift | D10 grace + `missed` records; acceptance step simulates a gap |
| The open Phase 51/53 acceptance ships v0.82.x patches during this build | Each sub-spec rebases on current master before it starts |
| A fleet restart applies the in-progress m0030, after which further in-place edits (D36, D37) would never reach it | Do not restart the fleet's `genesis serve` before the release; any sub-spec that edits m0030 re-checks process start times first; if the fleet has applied it, use a new migration |
| Mockup review delays the web work | 54-04..54-06 (backend) proceed while the user reviews 54-03 |

## 12. ADR summaries

- **ADR-087 (Accepted 2026-11-20; `genesis-ctx adr ADR-087`) — Schedules.** Every schedule lives in `scheduled_jobs` and is managed on the Schedules page;
  system schedules are editable, not deletable; user schedules run a `schedulable` workflow, an agent prompt (read-only
  servers, D9 built-ins) or a regression suite; custom agents are Genesis-owned profiles; missed, overlap, gate and
  failure rules as D8/D10/D12; runs record their trigger. Amends **ADR-047** (no longer fixed and backend-defined) and
  **ADR-049** (navigation as built, with Schedules). Draft in `adr-drafts.md`.

## Context manifest

```toml
areas    = ["runs-worker", "web-shell", "workflows-library"]
adrs     = ["ADR-011", "ADR-019", "ADR-021", "ADR-029", "ADR-031", "ADR-032", "ADR-047", "ADR-049", "ADR-069", "ADR-083", "ADR-086"]
lessons  = ["L-050", "L-081", "L-094", "L-108", "L-109", "L-111"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py"]
upstream = []
```
