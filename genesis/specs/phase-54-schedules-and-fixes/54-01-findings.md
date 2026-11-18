# 54-01 — Findings: Schedules, fixes and UX revamps

> **Status:** SPEC-DRAFTED 2026-11-19 — Q&A complete: decisions D1–D20 (§8), defaults F1–F12 (§9, confirmed); D21
> added after 54-02 (§10); D22–D29 from the 54-03 mockup review (§11).
> Parent: `specs/phase-54-schedules-and-fixes.md` (written after the Q&A).
>
> What was researched and decided before the spec set is written: the request as the user stated it, the schedules
> that exist today (code-grounded), the checked bugs and observations, the UX surfaces to revamp, the external and
> KiroCrew research, the proposed design, the open questions, and every decision.

---

## 1. The request (as stated by the user, 2026-11-19)

Phase 54 is not one feature. It has three parts:

- **A. Schedules (the main feature).** A new **Schedules** entry in the primary left navigation lists every schedule in
  Genesis. The existing system schedules (application sync, document sync, memory jobs, …) are default entries: the user
  can change their frequency and turn them on or off. Today these live in several places (Settings → General, Testing
  → Setup) and some have no UI at all; they move to the one page. The user can also create and delete their own
  schedules. A new schedule has a short **name** and one of two targets:
  1. **Run a workflow:** pick an installed workflow, configure its inputs, then the frequency.
  2. **Agent prompt:** a prompt to a plain agent, optionally with skills (and "agents"; see §7). A new single-node
     workflow in the Catalog runs it; the agent's output is always a **Markdown file**, viewed from the run in Runs.
     Posting the output to a chat space or Google Workspace is a possible later requirement, not this phase.
  The user asked for research into what other scheduling and agent platforms offer, and for useful additions.
- **B. Bug fixes:** three suspected bugs from reading the code, and two observed errors (§3).
- **C. UX revamps:** the story page's Design and Implementation tabs (to match its Overview tab), and the feature page's
  Overview and Activity tabs (§4).

The user confirmed this restatement (D1).

## 2. The schedules that exist today (verified in the code, 2026-11-19)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/genesis/`; `web/` = `genesis/web/src/`.

### 2.1 Scheduler, store and model

- `runtime/scheduler.py`: an asyncio tick every 60 s (`TICK_SECONDS`, `:126`), started in the app lifespan
  (`api/app.py:365-367`). Jobs are registered at boot by `register(job_key, handler)` (`:139-141`); a job with no
  handler is skipped unmarked. One in-flight run per job key (`_running`, `:184`, in memory only). The slot is marked
  `running` before the work (`mark_fired`, `:202`) and the final `(status, detail)` written by `_fire` (`:239`); status
  is `ok | skipped | partial | error`. `run_now` (`:210-221`) does not move `last_fired_slot`.
- Schedule kinds (`:46-122`): `daily_times` (`times[]` "HH:MM") and `interval_window` (`every_hours` 1–24, `start`,
  `end`), with `weekdays_only` and `timezone` (IANA). An optional `days:[0-6]` is honoured by `due_slot` (`:113`) but
  dropped by `validate_schedule` (`:70-98`). No cron, no one-time run, no start/end date. `due_slot` fires the latest
  slot at or before now if it differs from `last_fired_slot`; a missed slot catches up within the same day only.
- `scheduled_jobs` (m0012, `db/migrations/m0012_scheduled_jobs.py:23-37`; m0023 adds `options_json`, `user_modified`):
  `id`, `job_key` UNIQUE, `name`, `enabled`, `schedule_json`, `last_fired_slot`, `last_run_at`, `last_run_status`,
  `last_run_detail`, `created_at`, `updated_at`, `options_json`, `user_modified`. `ScheduleStore`
  (`runtime/schedule_store.py`): `ensure_defaults` (`:76-119`, respects `user_modified`, L-081), `update_settings`,
  `update_option_entry` (`:132-153`, per-entry writes for dispatcher jobs).

### 2.2 The jobs

| job_key | What it does | Default (all `Asia/Kolkata`) | On by default | Editable today |
|---|---|---|---|---|
| `application-sync` (`runtime/sync_jobs.py:38-50`, handler `:133-178`) | For each tracked app, serially, `ApplicationSyncService.start_sync` → `sync-application` run; waits ≤ 1200 s per app. Options `full_every_days`, `max_changed`, `max_changed_pct`, `run_on_this_machine`. | `interval_window` every 4 h 08:00–20:00, weekdays | yes | Settings → General (`ApplicationSyncSection.tsx`), `GET/PUT /api/system/sync-settings`, `POST …/run-now` |
| `document-library-sync` (`:51-56`, `:186-195`) | `run_manager.start("sync-documents", {"scope":"library"})`, fire and forget (records `ok` even if the run later fails). | `daily_times` 08/12/16/20, weekdays | yes | no UI |
| `kb-hub-pull` (`:57-65`, `:200-219`) | In-process `collab.pull_kb_if_newer` per app (no run). | `daily_times` 06:30, weekdays | **no** | no UI |
| `memory-consolidation` (`runtime/memory_jobs.py:32-35`) | `memory-consolidation` run with `{"owner": …}`; polls to terminal ≤ 1800 s. | `daily_times` 02:00, every day | yes | no UI |
| `memory-maintenance` (`:36-40`) | `memory-maintenance` run with `{"owner": …}`. | `daily_times` 03:00, Sunday | yes | no UI |
| `regression-run` (`testexec/regression_job.py:31-39`, `:103-141`) | Dispatcher: hourly tick; per app `options.apps[<uuid>] = {cadence off\|daily\|weekly, days, time, since}`; due apps → `TestExecutionService.start_regression(trigger={"source":"schedule",…})` (a queued `TE-` execution, not a direct run). | hourly tick; every app off | job on | Testing → Setup (`features/testing/setup/ScheduleSection.tsx`), `PUT /api/applications/{uuid}/testing/schedule` |

Skip rules: app sync skips on no Dev environment, `sync-application` missing or too old, a running sync, and (with
collaboration on) `run_on_this_machine` false (`sync_jobs.py:72-81`, `:139-157`); document sync on no `sync-documents`
or `gws` not connected; memory jobs on Kiro not signed in or workflow missing, consolidation also on no new chat sessions
(`memory_jobs.py:57-103`); hub pull when collaboration is off; regression per app when the app is gone or busy.
`GET /api/system/schedules` (read-only, `api/schedules.py:84-102`) is not used by the web app.

### 2.3 Housekeeping that is not a schedule

`CollabAutoPuller` (every 10 s while collaboration is on, `runtime/collab_autopull.py:19-61`), the startup recovery
sweeps and finalizer `reconcile` calls (`api/app.py:306-363`), and retention (opt-in at start, otherwise manual,
`api/config_routes.py:193-208`). Proposed: not shown on the Schedules page.

### 2.4 Gaps a user schedule hits

1. **No run → schedule link.** `runs` (`m0001_baseline.py:19-30`) records no trigger; `RunManager.start`
   (`runs/manager.py:287-331`) records no actor. The only precedent is `kb_test_executions.trigger_json` (m0026).
2. **Jobs are fixed at boot**; user schedules need a dispatcher (the `regression-run` pattern) or dynamic registration.
3. **Gates in unattended runs.** A run at a gate waits forever (`awaiting_gate`, no timeout in `RunManager`); a waiting
   handler reports "timed out" and leaves the run there (`memory_jobs.py:85`).
4. **Skills, MCP and tools are fixed when the graph is built** (`kiro_node`, `packages/genesis-core/genesis_core/nodes/agent.py:273-312`);
   only the prompt can come from run inputs (`prompt_fn(state, ctx, out_path)`).
5. **Reliability lint** (`genesis/lint/reliability.py`, ADR-011) requires validator + retry + escalation on the
   agent-prompt node too.
6. **Workflows come only from the library** (folder + lockfile, ADR-006); there is no local authoring path.
7. **Launch form exists and is reusable:** `web/features/catalog/LaunchForm.tsx` + `launch-schema.ts:38`
   (`buildLaunchForm` from `META.inputs_schema`: text, textarea, number, boolean, select, json, file), `POST /api/runs`
   and multipart `POST /api/runs/upload` (`api/run_routes.py:75-117`).
8. **Navigation:** `web/shared/layout/nav.ts:15-23` `PRIMARY_NAV` = Home, Workbench, Chat, Runs, Catalog, Documents,
   Memory; Settings pinned below. (ADR-049's list is older than the code.)

## 3. Bugs and observations, checked in the code (2026-11-19)

| # | Item | Result | Cause | Fix direction |
|---|---|---|---|---|
| B1 | Editing a paused run's state switches it to running with no worker | **Confirmed** | `patch_state` (`runs/manager.py:593-599`) spawns an `update_state` worker without checking status; its `final` event carries the state's own `status` ("running", `runs/worker.py:103-119`, `:166-168`); `on_event` (`manager.py:240-254`) maps it and `claim_status` (`runs/store.py:126-142`) refuses only terminal states; `_spawn` resets `seen = {"final": False, "stop": None}` (`:215`), so the pause marker is lost. A `run.final{status:"running"}` is logged. `fork` is unaffected (`:615`). | An `update_state` job never writes status (ignore its `final`), or re-assert the prior non-terminal status; keep the stop marker. |
| B2 | `artifact.saved` stored as `custom` with no node | **Confirmed** | Emitted at `genesis_core/nodes/agent.py:412` (and `tool_output.recorded` at `:420`); `_CANONICAL_CUSTOM` (`runs/manager.py:41-44`) omits them, so `self._log(run_id, "custom", {"data": …})` (`:239`). `fold_turns` (`runs/steps.py:130`, added in 39-03 `af519017`) matches kind `artifact.saved` and reads `p["document"]`: dead. The web (`features/run-detail/components/NodeIterationsDialog.tsx:219-232`) renders an always-empty list. | Add both types to `_CANONICAL_CUSTOM`; optionally a fold fallback for stored `custom` rows. |
| B3 | Dead code after `return` in `collab_hub_dir` | **Confirmed** | Phase 35 (`95b86e7a`) inserted `collab_hub_dir` over the header of `def artifacts_writable(self) -> bool:` (Phase 4, `3b5abc0e`); its body (`runtime/settings.py:253-257`) is unreachable. No caller of `artifacts_writable`. | Delete the dead lines. |
| O4 | Deleting an environment: "Could not remove: Method Not Allowed" | **Confirmed by code (not reproduced)** | The web sends `DELETE /api/config/environments/{encodeURIComponent(label)}` (`web/lib/api/config.ts:46-47`); the route is `{label}` (`api/config_routes.py:98`). The user's QA label is a URL (`https://example-qa2.appianpreview.com`), its `/` (decoded from `%2F`) breaks the match, and the GET-only SPA catch-all (`api/app.py:412`) answers DELETE with 405. `POST …/{label}/dev` has the same flaw. | `{label:path}` routes (mind order, L-096), or validate labels; make the catch-all return 404 for unmatched `/api/*`. |
| O1 | Failed Compose proposals cannot be dismissed | **Confirmed** | `CapturesPanel.tsx:24-26` lists every capture not `applied`/`discarded`; Discard shows only for `recording`/`ready` (`:98`). `_CAPTURE_EDGES` (`kb/testexec_store.py:71-72`) gives `failed` no outgoing edge; `RecordingService._discard` (`testexec/recording.py:333-350`) 409s on other states. | `failed → discarded` edge, allow it in `_discard`, a Discard button on failed cards. |
| O3 | "URLs are not encrypted" | **Facts only; intent open (§7)** | Plain http on loopback (`cli/main.py:165`, ADR-026). Paths carry ids only (Appian app uuid, numeric story/feature ids, run ids, chat session ids, MCP/env names); query strings carry navigation hints (`?from=board`, `?tab=`, …). No secrets found in any URL. | Depends on the user's intent. |
| O2, O5, O6 | UX of story Design/Implementation, feature Overview, feature Activity | See §4 | | |

## 4. UX surfaces (verified in the code, 2026-11-19)

**Story page** `/applications/:appUuid/stories/:storyId` → `web/features/workbench/StoryWorkspacePage.tsx`; one query
`useStoryWorkspace` (`GET …/stories/:id/workspace`, polls 5 s while a run is active); tabs by `SegmentedControl`.
- **Overview (the model to match, `:133-193`):** 2/3 main + 1/3 sidebar grid of local `InfoCard`s (description,
  numbered acceptance criteria, dev note, questions, tests, change history; sidebar spec refs + details `dl`). Weak
  points: `InfoCard`, `Shell` (`StoryTraceCards.tsx:29`) and `Row` are page-local duplicates; the Edit button floats;
  type and epic repeat in header and sidebar; no status summary of stages and runs.
- **Design (`:196-228`):** a state machine over the run status → `RunPanel` / dashed `EmptyPanel` / an `h-[70vh]`
  iframe of the design HTML (white background in dark mode, theme read once). No stage status, no run link or time,
  re-run banner only above a finished design, a hand-styled "Edit / chat" link (L-069 bans `Button asChild`).
- **Implementation (`:230-292`):** a `SplitPane` (`h-[74vh]`) with a two-item rail (report iframe, rollback Markdown).
  `report.objects[]` (name, type, action, version, ok/healed/error) is fetched but not shown; no counts, no run
  status/link, no code-review state.
- **Verification** (`VerificationSection.tsx`) renders under every tab, as one dense card.

**Feature page** `/applications/:appUuid/features/:featureId` → `web/features/features/FeaturePage.tsx`; hand-rolled
tabs (`:94-106`) unlike the story page's `SegmentedControl`.
- **Overview (`:153-278`):** `FeatureHealthCard` (status badge + stale "M arriving in later phases"),
  `NeedsAttentionCard` (spec status only), a grid of `StageCard`s; subtitle "no stage gates another" contradicts the
  ADR-058 prerequisites; no story, epic or test counts; a "status derived from stages" label leaks implementation.
- **Activity (`ActivityFeed.tsx`):** `GET /features/:id/activity`, spec lifecycle audit only; raw action and state
  names, absolute `toLocaleString()` times, one dot style, no grouping, links or paging.

**Reusable primitives** (`web/shared/ui`, `shared/layout`, `shared/feedback`): `Card*`, `MetricCard`, `Badge`,
`StatusPill`/`statusMeta`, `ActionPill`, `KindBadge`, `Tabs`, `SegmentedControl`, `Page`, `Section`, `SplitPane`,
`EmptyState`/`ErrorState`/`LoadingState`, `RelativeTime`, `Duration`, `CreditBadge`, `MarkdownView`. Missing: a shared
section card, a definition list, a timeline, a status header.

## 5. Research (2026-11-19)

### 5.1 Other platforms

| Option | Seen in | Note |
|---|---|---|
| Presets (hourly/daily/weekly/monthly) + cron | [Claude Code scheduled tasks](https://code.claude.com/docs/en/web-scheduled-tasks), [Devin](https://docs.devin.ai/product-guides/scheduled-sessions), [n8n](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.scheduletrigger/), [Cursor Automations](https://cursor.com/docs/cloud-agent/automations) | common; Claude reads bare cron as UTC, presets as local time |
| One-time run (turns itself off) | ChatGPT [scheduled tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt), Claude, Devin | common in AI tools |
| Interval, weekdays, time window | [Prefect](https://www.prefect.io/docs/v3/concepts/schedules), [Temporal](https://docs.temporal.io/schedule), Zapier, [gh-aw](https://github.github.com/gh-aw/reference/schedule-syntax/) ("between 9:00 and 17:00") | windows are rare |
| Start/end date, max runs | Airflow, Temporal | Temporal limits the number of actions |
| Overlap policy | Temporal (skip default, buffer, cancel, terminate, allow) | KiroCrew refuses a live second run |
| Missed-run catch-up | n8n (none / most recent / per rule), Airflow `catchup`, Temporal catch-up window | matters for a laptop app |
| Pause, run now, edit, delete, run history | Claude, Devin, Temporal, Prefect | universal |
| Next-run preview | Prefect "Upcoming" | |
| Auto-pause after failures | Temporal pause-on-failure, Devin "Error" status, KiroCrew `auto_pause_after_failures` | |
| Notifications (always / on failure / never) | Devin (failure only by default), ChatGPT | |
| Per-schedule parameters | Prefect, Airflow, [LangGraph cron jobs](https://docs.langchain.com/langsmith/cron-jobs), Temporal | |
| AI-specific: model, skills/tools, repositories | Claude (model + connectors), Devin (agent + skill), Cursor (tools) | |
| AI-specific: previous run as context | Temporal last completion result; LangGraph cron on a fixed thread | prompt-level pattern |
| Per-schedule credit cap | none found | LangGraph warns forgotten crons keep spending |

Not retrievable: Airflow `max_active_runs`/SLA pages, Dagster, Make, Power Automate, Copilot Studio, Lindy, Relevance
AI, CrewAI. Content was rephrased for compliance with licensing restrictions.

### 5.2 KiroCrew (reference only; `/Users/ramaswamy.u/repo/KiroCrew`)

`src/kiro_crew/cron_service/model.py` `CronJob`: `name`, `message` (prompt), `schedule.kind` `every` (≥ 60 s) | `at`
(one shot) | `cron` (5 fields, croniter, `schedule.py`); per job `agent_id`, `model`, `approval_mode`, `timeout_secs`
(1800), `strict_schedule` (no jitter), `skip_dates`, `timezone`, `delete_after_run`, `auto_pause_after_failures` (5)
with `user_paused` kept apart from `auto_paused`, `alert_after_failures`, duplicate-result suppression. Overlap: a live
run is refused (`service/run_registry.py`, 409 on manual run). Catch-up: only a gap under 10 minutes. History: JSONL per
job (`cron_history.py`). UI: `website/src/pages/SchedulePage.tsx`, a template gallery, folders, batch actions. The
heartbeat is listed as a row on its Schedules tab
(`docs/decisions/2026-10-22-heartbeat-is-a-schedules-tab-row-not-a-goals-check-in.md`), the same idea as system
schedules here.

## 6. Proposed design (assistant draft for the Q&A; §8 decisions win where they differ)

- **Schedules page** (`/schedules`, primary nav): System and My schedules in one list (name, target, frequency in words,
  next run, last result, on/off); a detail view with the schedule's run history; New schedule wizard (target → workflow
  + inputs via `buildLaunchForm`, or prompt + skills → frequency → name).
- **One schedule model** for system and user schedules: presets, one-time, cron, the existing interval window, an IANA
  time zone; next runs previewed; Run now, Pause/Resume, Duplicate; overlap = skip and record; missed run = run the
  latest missed slot once within a grace window; per-run timeout; auto-pause after N consecutive failures (distinct
  from a user pause); failure notice in the app; optional end date / max runs.
- **Run ↔ schedule link** recorded at launch (a trigger on the run), so history and credits per schedule come from the
  real run records (metered credits, ADR-032).
- **Agent-prompt workflow** in genesis-workflows: one agent node writing `output.md` into the blackboard, a validator
  (file exists, non-empty Markdown), retry and escalation (ADR-011); skills provisioned per run from inputs (a
  genesis-core change, ADR-069).
- **ADR:** a new ADR amending ADR-047 (user-configurable and user-created schedules) and touching ADR-049 (navigation).

## 7. Open questions (asked one at a time 2026-11-19; all answered — Q1→D2, Q2→D3, Q3→D4, Q4→D5, Q5→D6, Q6→D7, Q7→D8, Q8→D9, Q9→D10, Q10→D11, Q11→D12, Q12→D13, Q13→D14 (+ D15 default), Q15→D16, Q16→D17, Q17→D18, Q18→D19, Q19→D20; the rest → §9 defaults)

1. Tool access of the unattended agent-prompt agent (shell, files, web, MCP), given ADR-083/086 and Phase 52 not built.
2. What "agents" means in the agent-prompt target, since ADR-086 loads nothing from `~/.kiro`.
3. Which workflows can be scheduled (stage-bound and story-bound workflows feed finalizers; some have gates).
4. What happens when a scheduled run reaches a gate.
5. Frequency forms in the first version (presets, one-time, cron, interval window).
6. Missed-run and overlap behaviour.
7. Failure handling and notifications.
8. Agent-prompt extras: model choice, previous run as context.
9. How per-app regression schedules appear on the page.
10. What "URLs are not encrypted" should change.
11. Direction for the UX revamps (story Design/Implementation, feature Overview/Activity).
12. Release ordering against the open Phase 51/53 live acceptance.

## 8. Decisions (locked with the user, one at a time)

| # | Decision | Reason |
|---|---|---|
| D1 | **Scope: Schedules + fixes + UX revamps, as restated in §1.** (A) a Schedules page in the primary navigation holding every system schedule (frequency and on/off editable, not deletable; their Settings → General and Testing → Setup controls move there) and user schedules (create, delete) whose target is a workflow with configured inputs or an agent prompt with optional skills that writes a Markdown file into the run; (B) bugs B1–B3 and observations O1, O4 (§3); (C) the story page's Design and Implementation tabs rebuilt to match Overview, and the feature page's Overview and Activity tabs rebuilt (§4). Housekeeping loops (§2.3) are not schedules. | User (2026-11-19): "This is right." |
| D2 | **The agent-prompt agent gets the same built-ins as every workflow agent node (Q1, option A).** Phase 53 D9's built-ins (shell `execute_bash`, file read/write, search, `web_fetch`, `remote_web_search`), auto-approved, never `delete_file`; plus MCP servers the user picks per schedule, capped at `node.tools ∩ server allowlist` (ADR-029/086). Which servers may be picked is a separate decision (D3). Risk accepted: ADR-083 risks a–c (shell, unscoped reads, inherited environment) now also apply to unattended runs on a timer, until Phase 52. | User chose A (2026-11-19). Considered: B (read-and-report: no shell, read-only MCP tools, the assistant's recommendation) and C (web + file read only). |
| D3 | **An agent-prompt schedule may pick only read-only MCP servers (Q2, option A).** Pickable: `appian-dev` (73 read tools), `genesis-kb`, `appian-atlas`, and a custom server the user marks read-only when picking it. Never pickable: `appian-dev-write` (ADR-068, `story-implementation` only), `appian-dev-packages` (ADR-073, program code only), `appian-devops` (write/deploy tools), and the curated servers with no `tool_allowlist` (`jira`, `jarvis`, `appian-data-generator`: an empty allowlist means every tool, writes included). With no write-capable server the agent-prompt node is not a mutating MCP node, so ADR-021 needs no `pre_mutation` gate and a scheduled run cannot stop to wait at one. The "read-only" mark on a custom server is the user's own claim, recorded on the schedule; Genesis does not verify it. | User chose A (2026-11-19). Considered: B (any server but the two excluded; a write-capable pick puts a `pre_mutation` gate before the agent on every run) and C (B without the gate; breaks ADR-021, needs a new ADR). |
| D4 | **Custom agents are Genesis-owned profiles, created and maintained in a new Catalog → Agents tab (Q3, the user's refinement of option B).** A custom agent is a named bundle that only configures things together: instructions (system prompt), skills (managed only, Phase 53 D7/D8), read-only MCP servers (D3) and optionally a model. It is stored by Genesis, never read from or written to `~/.kiro/agents/` (ADR-086). Genesis still projects the real Kiro agent per session, so the trust rules (D2, D3) apply whatever the profile says. An agent-prompt schedule picks a custom agent (or none) and adds its own prompt. Catalog today has Workflows and Skills tabs, URL-driven (`web/src/features/catalog/CatalogPage.tsx:37-52`, `/catalog`, `/catalog/skills`); Agents becomes the third (`/catalog/agents`, a static route before `catalog/:workflowId`, L-096). Where else an agent can be used is D5. | User (2026-11-19): "In the catalog page, can we have a new tab to create and maintain custom agents? which is just configuring things together and using them where needed." Rejected C (import `~/.kiro/agents`): breaks ADR-086. |
| D5 | **A custom agent is used in three places (Q4, option C):** (1) agent-prompt schedules; (2) a **Run** action on the Catalog → Agents tab that starts the agent-prompt workflow once with a typed prompt (Markdown output in Runs; also how an agent is tried before it is scheduled); (3) **Chat**, where a custom agent can be picked for a session. In chat the session keeps chat's read-only posture (ADR-031/034, Phase 53 F2): no shell, writes only in the per-session sandbox, read-only MCP tools only; the agent contributes its instructions, skills and (read-only) servers, not its workflow built-ins. So one agent behaves with fewer tools in chat than in a schedule; the UI says so. Which chat modes take a custom agent is D6. | User chose C (2026-11-19). Considered: A (schedules only) and B (schedules + Catalog Run, the assistant's recommendation; chat deferred because it touches every mode's trust projection). |
| D6 | **In chat, only the read-only assistant mode takes a custom agent (Q5, option A).** A new session on the Chat page may pick a custom agent: its instructions are added after the read-only assistant's own (which keep precedence), its skills and read-only MCP servers are added to the session's projected agent. Copilot and the six spec-style modes (`feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design`) are unchanged. The agent is fixed for the session (shown in the chat header); resume (`session/load`) keeps it. | User chose A (2026-11-19). Considered: B (+ Copilot) and C (every mode; a profile's instructions could conflict with a spec mode's output contract, e.g. ADR-075 clause ids). |
| D7 | **Schedulable workflows are opt-in: `META.schedulable: true` (Q6, option B).** Only installed workflows that declare it appear in the "Run a workflow" picker; the backend refuses a schedule (create and at fire time) for a workflow that does not declare it, or no longer does after an update. `schedulable` is a META key (mirrored in `workflow.yaml`, parity lint), default false; genesis-workflows sets it in this phase's release on the agent-prompt workflow and on the safe standalone ones (candidates: `sync-documents`, `generate-business-map`, `hello-appian`, `memory-consolidation`, `memory-maintenance`; final list in the library sub-spec). Stage-bound, story-bound and mutating workflows (`ux-design-analysis`, `technical-design-analysis`, breakdown, test design, `story-design-analysis`, `story-verification`, `story-implementation`, …) stay off. System schedules (D1) are not limited by the flag: their workflows are fixed by Genesis. | User chose B (2026-11-19). Considered: A (all installed workflows) and C (all except a derived exclusion list; every new binding kind must be added, L-094). |
| D8 | **A scheduled run at a gate waits, then is cancelled (Q7, option B).** When a schedule's run reaches any gate (escalation, approval), Genesis shows an in-app notice ("Scheduled run <schedule> needs you", linking to the run). While it waits, the schedule's next slot is not fired (overlap rule). If nobody answers by the schedule's next due slot or within a maximum wait (default 24 h, per schedule), Genesis cancels the run through the normal cancel path (L-108: stop intent recorded, CAS terminal write) and records the schedule run as failed with reason "gate not answered". The person may answer or fork the waiting run before then (ADR-009/025). Applies to system and user schedules alike (fixes the stuck `memory-maintenance` run pattern, state "Known open items"). | User chose B (2026-11-19). Considered: A (wait forever; the schedule stalls) and C (no gate for unattended runs; removes ADR-011's human escalation, needs an ADR change). |
| D9 | **Frequency forms: presets + one-time, no cron (Q8, option A).** (1) Hourly, or every N hours within a start–end window; (2) daily at one or more times; (3) weekly on chosen days at one or more times; (4) monthly on a day of the month (a day past the month's end fires on its last day) at a time; (5) once at a date and time, after which the schedule turns itself off. Each has an IANA time zone (default the machine's zone; system schedules keep `Asia/Kolkata`), shown with the frequency in words and the next 5 run times. Built on the existing `daily_times` / `interval_window` model (`runtime/scheduler.py:46-122`) extended with `days` (validated, today dropped by `validate_schedule`), `day_of_month` and `once`; no new dependency. The six system schedules (§2.2) map onto these forms unchanged; existing `scheduled_jobs.schedule_json` rows stay valid (L-081). | User chose A (2026-11-19). Considered: B (+ cron; needs a parser, `croniter` declared unmaintained Dec 2024 then moved to pallets-eco, [Airflow #46172](https://github.com/apache/airflow/discussions/46172); cron time-zone pitfalls) and C (only today's two kinds). |
| D10 | **Missed slots: the most recent one runs once within a grace window; overlap skips (Q9, option B).** (1) **Missed:** when a schedule is evaluated after a gap (Genesis closed, laptop asleep), the latest missed slot fires once if it is younger than the schedule's grace time (default 12 h, per schedule); every older missed slot is recorded in the schedule's history as `missed`, never run. At most one catch-up per schedule per gap. A `once` schedule missed beyond grace is recorded `missed` and turned off. Replaces today's same-calendar-day rule (`due_slot`, `runtime/scheduler.py:101-122`). (2) **Overlap:** a due slot whose schedule still has a run in flight (including one waiting at a gate, D8) is not fired and is recorded `skipped (previous run still active)`. Both rules apply to system and user schedules. | User chose B (2026-11-19); the overlap rule was stated as a default with the question. Considered: A (skip all missed) and C (today's same-day rule, odd around midnight). n8n's "run the most recent missed" is the model ([n8n Schedule Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.scheduletrigger/)). |
| D11 | **The top-bar bell becomes a real notification center (Q10, option A).** Today it is a placeholder button with no handler (`web/src/shared/layout/TopBar.tsx:59-65`); chat's `chat_notifications` covers chat sessions only. New: a `notifications` table in `genesis.db` (survives restart) with a generic shape (source, kind, title, body, link, created_at, read_at); the bell shows an unread count, a list, mark-as-read (one, all) and opens the linked item. This phase's only producer is Schedules: "needs you" (D8), "failed", "auto-paused", "missed" (D10, once per gap). Other sources may use it later. No OS desktop notification. | User chose A (2026-11-19). Considered: B (a badge on the Schedules nav entry + a page banner) and C (A + browser desktop notifications). |
| D12 | **Failure handling: results follow the run, a run timeout, auto-pause after N failures (Q11, option A).** (1) A schedule run's result is the final status of the run (or `TE-` execution) it started; every handler follows it to the end, so `document-library-sync` no longer records `ok` for a run that later fails. (2) Each schedule has a maximum run duration (default 2 h, per schedule; system defaults keep today's caps where longer, e.g. app sync's per-app 1200 s × apps); exceeding it cancels the run through the normal path (L-108) and counts as a failure. (3) Readiness skips (no Dev environment, Kiro not signed in, workflow missing or not `schedulable`, collaboration off, designated machine) are recorded `skipped` and are not failures. (4) After N consecutive failures (default 3, per schedule, 0 = never) the schedule moves to **Paused (failing)**, distinct from a user pause, and a bell notice is raised (D11); Resume clears the count. No schedule-level retry: retries stay inside the run (ADR-011). | User chose A (2026-11-19). Considered: B (notify only, keep firing) and C (A + one whole-run retry; doubles credits on a real failure). Temporal pause-on-failure, Devin's Error status and KiroCrew's `auto_pause_after_failures` are the precedents (§5). |
| D13 | **No previous-run context in this phase (Q12, option B).** An agent-prompt run does not receive any earlier run's output; each run starts from its prompt, custom agent, skills and servers only. Deferred: a per-schedule "give the agent the previous run's output" toggle (copy the last successful `output.md` into the run folder by reference). | User chose B (2026-11-19). Considered: A (per-schedule toggle, off by default; the assistant's recommendation) and C (always on). |
| D14 | **Each app's regression schedule is its own schedule row (Q13, option A).** A third schedule target, **Regression suite** (an app with a test suite), beside workflow and agent prompt; one row per app ("Regression: <app name>"), with its own frequency (D9 forms), history, failure count and auto-pause (D12). It fires `TestExecutionService.start_regression(app_uuid, trigger={"source":"schedule", "schedule_id":…, "slot":…})` as today. Created from New schedule or from a "Schedule regression" link in the app's Testing → Setup, which also shows the current row's summary and links to it (the Setup editor `ScheduleSection.tsx` goes; one home, L-109). It is a user schedule: deletable. Migration: every existing `regression-run` `options.apps[<uuid>]` entry with cadence ≠ off becomes a row with the same days, time and enabled state, once (L-081), and the `regression-run` dispatcher job is retired; `PUT /api/applications/{uuid}/testing/schedule` is removed or redirected (every consumer listed, L-094). | User chose A (2026-11-19). Considered: B (one system row with a per-app table, the assistant's recommendation) and C (stay in Testing → Setup with a read-only row). |
| D15 | **The application-sync row takes over the whole Settings card (default, stated with Q14; the user did not object).** Its detail page holds today's `ApplicationSyncSection` content (frequency, time zone, on/off, `full_every_days`, `max_changed`, `max_changed_pct`, `run_on_this_machine`, per-app last sync, Run now); Settings → General drops the card. Same rule for every system schedule: its options live only on its Schedules row (one home, L-109). | Follows D1 ("consolidate everything"). |
| D16 | **O3 "URLs are not encrypted" is dropped (Q15, option D).** No URL change: Genesis serves plain http on loopback only (ADR-026), URLs carry ids and navigation hints, no secrets (§3 O3). | User chose D (2026-11-19). Considered: A (opaque ids), B (readable URLs with story keys), C (HTTPS on localhost). |
| D17 | **UX revamps: mockups first, then build (Q16, option A).** The spec gives a layout per surface (story Design and Implementation tabs; feature Overview and Activity tabs; and the new Schedules page, Catalog → Agents tab and bell, which are new surfaces); the first UX sub-spec builds a `/dev/phase-54` mockup route with stub data (the Phase 27/29/39 pattern, `web/src/app/router.tsx:101-104`); the user reviews it in the browser and approves or changes it before the real build of those surfaces starts. Changes the user asks for are recorded as decisions in this file. | User chose A (2026-11-19). Considered: B (settle layouts in Q&A, build directly) and C (user-provided designs). |
| D18 | **Feature Activity covers every feature-level event (Q17, option A).** `GET /features/{id}/activity` (`api/features.py:667`, today the spec's audit only) returns, newest first and paged: every stage's lifecycle transitions from the append-only audit (m0013, `audit.list_for("stage", <stage id>)` for each of Spec, UX Design, Technical Design, Feature Breakdown, Test Design), each stage's runs (started, finished, failed, cancelled; linked), change requests (opened, applied, discarded; the existing CR labels), and story finalization. Each item has a type, stage, actor, time and link. The web shows a day-grouped timeline with typed icons, `RelativeTime`, links and a stage filter. Story-level events (lane moves, story runs) stay on the story page and board. | User chose A (2026-11-19). Considered: B (+ story-level events; long on big features, duplicated elsewhere) and C (lifecycle of every stage only). |
| D19 | **One release for the whole phase (Q18, option B).** All of Phase 54 (B1–B3, O1, O4, Schedules, custom agents, the bell, the UX revamps) ships together: genesis **v0.83.0**, then genesis-workflows **v0.27.0** (the agent-prompt workflow, `schedulable` flags; pinned on `genesis.git@v0.83.0`, L-057). No separate v0.82.x patch for the fixes. Phase 54 does not wait for the open Phase 51/53 live acceptance (the user runs it later). | User (2026-11-19): "ill do the live acceptance later. We can go with the one complete actual release." Considered: A (fixes as a v0.82.x patch first, the assistant's recommendation) and C (finish the open acceptance first). |
| D20 | **Phase 54 is live-accepted before v0.83.0 (Q19, option A).** "Later" covers only the open Phase 51/53 acceptance. Before the tag, the review & acceptance sub-spec runs on a separate `genesis serve`: a prompt schedule firing and writing Markdown, a workflow schedule, a regression-suite schedule, a missed slot caught up, overlap skip, a gate timing out (D8), auto-pause (D12), the bell, Catalog Run of a custom agent, chat with a custom agent, the regression and app-sync migrations, B1/B2/O1/O4 reproduced then fixed, and the real-browser width probe of the new and revamped pages (L-090). Rows needing Appian Dev (an `appian-dev` read in a prompt schedule) are skipped if Dev is down, and that is said in the release notes. | User chose A (2026-11-19). Considered: B (release before its own acceptance, "SHIPPED (live acceptance open)", L-111). |
| D21 | **No repair of runs a pre-fix state edit left stored `running` (Q20 after 54-02, option C).** Such a run keeps its `running` status and `run.final{running}` row; `reconcile_status` is unchanged; 54-04 adds no repair. The user cancels a stuck run by hand (Run Detail → Cancel). Known effect: a stuck `sync-application` run blocks that app's scheduled sync (the per-app "sync already running" skip, `runtime/sync_jobs.py:157`) until cancelled. 54-11's release notes tell users to cancel any run that shows Running with nothing happening. | User chose C (2026-11-19). Considered: A (one-time repair in m0030 + `reconcile_status` stops adopting the marker; the assistant's recommendation) and B (fix `reconcile_status` only; such runs fall to the orphan sweep and a really paused one ends failed). |
| D22 | **Schedules list layout (54-03 review, surface 1).** No Target column. Frequency = a weekday strip (M T W T F S S, run days filled) plus one short line ("every 4 h, 08:00–20:00"); monthly and once rows show a calendar icon instead of the strip; the time zone is shown only when it differs from the machine's. Last result = the status tag only, linking to the run (or `TE-` execution), with time, reason and a gate's cancel time in a tooltip. System rows carry a lock icon (tooltip "System schedule"), no System tag; above the grid: "System schedules can't be deleted. You can change when they run or turn them off." | User review of `/dev/phase-54` (2026-11-18); the wording replaces the user's "not editable", which was wrong (D1, D15). |
| D23 | **The row switch is on/off only (`enabled`); Pause/Resume live in the row menu.** `enabled` and `pause_reason` stay separate (F1): off = `enabled = 0`; Pause = `pause_reason = 'user'`. While a schedule is off, Run now and Pause/Resume are disabled in the UI and refused by the API (409 "schedule is off"). | 54-03 review m4, decided by the user (2026-11-18). |
| D24 | **New / edit schedule is a full page** (option B: a step rail and a running summary), not a dialog. Skills and MCP servers are picked with the shared **`MultiSelect`** (`web/src/shared/ui/multi-select.tsx`, built in 54-03: chips when closed; search + checkboxes when open; non-pickable servers greyed under "Can't be picked" with the reason; a custom server counts only once "This server only reads" is ticked). A picked custom agent's own skills and servers show as locked chips "from <agent>"; the schedule adds its own. The Catalog → Agents editor uses the same `MultiSelect`. | User review (2026-11-18), surfaces 2 and 4; the shared component was proposed by genesis-dev and agreed. |
| D25 | **Application-sync options on its detail page are text with an Edit button** (Edit opens the frequency step and the options), not inline inputs as in today's Settings card. | User review (2026-11-18), surface 3. |
| D26 | **A chat with a custom agent hides the Copilot toggle.** | User review (2026-11-18), surface 6; D6 left it open. |
| D27 | **Story Implementation tab: report and rollback document as tabs inside one card** (option A). | User review (2026-11-18), surface 8. |
| D28 | **Approved as mocked:** schedule detail + history (3), bell (5), story Design (7), story Verification as its own tab (9), feature Overview (10), feature Activity (11). The approved mockup in `web/src/dev/mockups/phase54/` (genesis `b09b08e`) is the layout for 54-07, 54-08 and 54-09. | User review (2026-11-18). |
| D29 | **Time fields use a 24-hour control (Q21, option B).** Every time field (schedule wizard, application-sync options, advanced end date's time) is a shared `TimeInput` in `web/src/shared/ui/` showing `HH:MM` 24-hour whatever the browser locale, matching the frequency text and next-run previews: hour and minute fields, typed digits and arrow keys, a label per field, jest-axe and a userEvent keyboard test. Replaces the native `type="time"` used in the mockup. Built in 54-07; the mockup is not revised. | User chose B (2026-11-19) after 54-03 decision 10 recorded "yes" as "no change". Considered: A (keep the native control; AM/PM on an en-US locale). |

## 9. Defaults — ✅ confirmed by the user 2026-11-19 ("yes")

| # | Default | Why |
|---|---|---|
| F1 | **Storage (migration m0030, DB v29 → v30).** `scheduled_jobs` gains `kind` (`system`\|`user`), `target_json` (`{type: "workflow", workflow_id, inputs}` \| `{type: "agent_prompt", prompt, agent_id?, skills, mcp_servers, model?}` \| `{type: "regression", app_uuid}`), `policy_json` (grace, timeout, failure limit, gate max wait, end date, max runs), `failure_count`, `pause_reason` (`user`\|`failing`\|`completed`, null = active), `runs_count`. New `schedule_runs` (one row per slot: `schedule_id`, `slot`, `outcome` `fired\|skipped\|missed\|ok\|failed\|cancelled`, `run_id` or `execution_key`, `reason`, `started_at`, `finished_at`). `runs` gains `trigger_json` (`{source: "schedule", schedule_id, slot}`; NULL for every other start). | History and credits come from the real run records (ADR-032); the `kb_test_executions.trigger_json` precedent (m0026). |
| F2 | **Scheduler evaluates the table each tick.** User rows are read on every tick and fired by one handler per target type (`workflow`, `agent_prompt`, `regression`); system rows keep their registered handlers. No boot-time registration for user schedules. | Dynamic schedules without the dispatcher's one-row-many-items model (D14). |
| F3 | **Custom agents in `custom_agents` (m0030).** `id`, `name` (unique), `description`, `instructions`, `skills_json`, `mcp_servers_json` (each `{name, read_only_mark}` for custom servers), `model` (nullable), timestamps. At launch the agent is **copied into the run's inputs** (a snapshot), so an edit never changes past runs and the worker needs no DB read. Deleting an agent used by a schedule is refused (409) and names the schedules. | Reproducible runs; ADR-012 (the worker gets everything through inputs). |
| F4 | **`agent-prompt` workflow (genesis-workflows) + an additive genesis-core change.** One `kiro_node` writes `output.md` in the blackboard; a validator checks it exists, is non-empty and decodes as UTF-8 text; 2 retries, then an escalation gate (ADR-011); `schedulable: true`; output viewed in Run Detail's documents (`/runs/:runId/docs/output.md`). genesis-core: `kiro_node` accepts `skills`, `mcp` and `model` either as today's static values or as a callable `(state, ctx) -> value` resolved when the node runs; static callers are unchanged, so `CORE_MAJOR` stays 1 (ADR-019, additive). | The only way a library workflow gets per-run skills and servers (§2.4 item 4). |
| F5 | **Model:** optional, on the custom agent or on an agent-prompt schedule without one; none = Kiro's default. The run's inputs carry the effective model. | Matches Claude Code / Devin per-task model choice (§5.1). |
| F6 | **Navigation + ADR.** `Schedules` after `Runs` in `PRIMARY_NAV` (`web/src/shared/layout/nav.ts`); route `/schedules`. **ADR-087** (proposed) amends **ADR-047** (schedules are user-configurable and user-created) and **ADR-049** (records the navigation as built). Draft in `adr-drafts.md` until the release. | One home for the rule (47-08). |
| F7 | **API.** New `/api/schedules` (list, get, create, update, delete, run-now, pause, resume, duplicate, history, preview of next runs), `/api/custom-agents` (CRUD, run), `/api/notifications` (list, unread count, mark read, mark all read). `GET/PUT /api/system/sync-settings`, `POST …/run-now`, `GET /api/system/schedules` and `PUT /api/applications/{uuid}/testing/schedule` are removed once the web no longer calls them, after listing every consumer (L-094). | One home per contract (L-109). |
| F8 | **Controls.** Run now (409 while a run of that schedule is in flight); Pause/Resume; Duplicate (user schedules); optional end date and max runs, after which the schedule turns itself off (`pause_reason = completed`); deleting a user schedule (confirm dialog) keeps its runs in Runs and their `trigger_json`; system schedules cannot be deleted but have **Reset to default**. | Research §5.1; KiroCrew `CronRowActions.tsx`. |
| F9 | **Credits per schedule.** The history table shows each run's metered credits with provenance and a total over the shown rows; nothing estimated (ADR-032). | ADR-032. |
| F10 | **Runs list badge.** A run with `trigger_json.source == "schedule"` shows "Scheduled: <name>" linking to the schedule (or "Scheduled (deleted)"). | Makes the link visible both ways. |
| F11 | **Machine scope.** User schedules run on the machine that holds them; not published to the Hub. The designated-machine rule stays app-sync only. | ADR-063 (local-first). |
| F12 | **Build order.** 54-02 fixes → 54-03 mockups (D17 gate) → 54-04 scheduler + storage → 54-05 custom agents + `agent-prompt` → 54-06 HTTP API contract → 54-07 Schedules web + bell → 54-08 chat custom agent → 54-09 UX revamps → 54-10 review + acceptance → 54-11 release + docs. | Backend before web; the mockup gate before any new or revamped surface is wired. |

## 10. After 54-02 (2026-11-19): As built folded into the later sub-specs

54-02 BUILT (genesis `ea00dfd..eed5da0`, local; review SHIP). Folded by the spec agent:
- 54-06 §3a: the web `agent.prompt` kind drift, the failed-capture `proposals` type, `state.edited` as a `custom` note,
  the environment routes as built and the catch-all's 404/405 rule.
- 54-10 A13: rewritten for the fixes as built (gated runs, the 400 on a failed edit, old runs' artifacts, the
  gate-waiting capture confirm, the new make-Dev route, 404 vs 405).
- 54-11: release-note API changes and the two stale architecture docs; 54-02's lesson candidates and code-map changes.
- Umbrella §9 Deferred: review nits n1 (no `Allow` header on 405) and n2 (failed capture with a live run cancels
  without a confirm).
- **Q20 → D21** (§8): no repair of runs a pre-fix state edit left stored `running`.

## 11. After 54-03 (2026-11-19): the mockup review folded into the later sub-specs

54-03 BUILT (genesis `eed5da0..b09b08e`, local; review SHIP at re-run 2); the user's review recorded as D22–D28.
Folded by the spec agent: 54-04 §1 (`enabled` vs `pause_reason`, D23); 54-06 (`enabled` beside `state`, 409 on a
disabled schedule); 54-07 (D22–D25, the shared `MultiSelect`, a shared row-menu primitive, time-zone canonicalisation,
no opacity modifiers on token colours); 54-08 (D26); 54-09 (D27, the shared pieces already in `shared/ui`, a compact
stat grid); 54-10 (A1 against `b09b08e`, keyboard check of `MultiSelect`). Backlog (umbrella §9): opacity modifiers on
token colours generate no CSS (54-03 As built, "Found, not fixed"). Q21 → D29: a 24-hour time control (54-03
decision 10 corrected: the user's "yes" did not mean "no change").

## Context manifest

```toml
areas    = ["runs-worker", "web-shell"]
adrs     = ["ADR-011", "ADR-021", "ADR-047", "ADR-049", "ADR-068", "ADR-073", "ADR-083", "ADR-086"]
lessons  = ["L-050", "L-081", "L-094", "L-096", "L-108"]
docs     = ["tracker:specs/phase-23-scheduled-and-full-package-syncs.md", "tracker:specs/phase-52-agent-runtime-isolation.md"]
code     = ["genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/api/schedules.py"]
upstream = []
```
