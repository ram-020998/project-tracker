# Phase 54 — ADR drafts

> **Status:** FILED 2026-11-20 (genesis-docs, 54-11 §3) as **ADR-087 — Accepted** in `reference/decision-log.md`
> (`genesis-ctx adr ADR-087`); the decision log is the one home from now on. Drafted 2026-11-19 (genesis-spec); brought
> up to date with what was built before filing (54-10 review n6: D22 as amended by D50, D30, D31, D36–D43, D48, D49).
> Source of every clause: `54-01-findings.md` §8 (D-numbers) and §9 (F-numbers).

## ADR-087 (filed) — Schedules: one user-managed schedule model for system jobs, workflows, agent prompts and regression suites

- **Status.** ACCEPTED 2026-11-20 — Phase 54, genesis v0.83.0 + genesis-workflows v0.27.0. Amends **ADR-047**, **ADR-049**
  and (added at the write-back, the user's call) **ADR-029**.
- **Areas.** runs-worker, config-secrets, web-shell, workflows-library, chat, security.
- **Rule (one-liner, ≤ 220 chars).** Every schedule lives in `scheduled_jobs` and is managed on the Schedules page: system jobs editable not deletable; user schedules run a `schedulable` workflow, an agent prompt or a regression suite.
- **Context.** ADR-047 made scheduled syncs fixed and backend-defined; ADR-074 later made the app sync configurable in
  Settings → General, and Phase 51 added a per-app regression cadence in Testing → Setup, run by one hourly
  `regression-run` dispatcher row. Document sync, Hub pull and the memory jobs had no UI. Runs recorded no trigger, a
  gate in an unattended run waited forever, `document-library-sync` recorded `ok` for a run that later failed, and the
  user could not schedule their own work (`specs/phase-54-schedules-and-fixes/54-01-findings.md` §2). Source of every
  clause: `54-01-findings.md` §8 (D-numbers) and §9 (F-numbers). Built in 54-04..54-09 and 54-12, reviewed and
  live-accepted in 54-10 (SHIP, round 2).
- **Decision.**
  1. **One page, one model.** A **Schedules** entry in the primary navigation (after Runs) lists every schedule; every
     schedule is a row of `scheduled_jobs` (`kind` `system` | `user`). System schedules (`application-sync`,
     `document-library-sync`, `kb-hub-pull`, `memory-consolidation`, `memory-maintenance`) are editable (frequency,
     on/off, run policy, their options) and resettable, never renamed, retargeted or deleted; their options live only on
     their row (D1, D15; the Settings → General sync card and the Testing → Setup editor are gone). User schedules are
     created, edited, duplicated and deleted. The list reuses the Runs page's filters, search box and grid, the whole row
     opens the schedule, system rows carry a lock icon, and there is no line above the grid (D22 as amended by D50). The
     row switch is on/off only (`enabled`); Pause and Resume are row-menu actions stored as `pause_reason` (D23).
  2. **Targets.** A user schedule runs (a) an installed workflow that declares `META.schedulable: true` (a literal
     `true`, mirrored in `workflow.yaml`), with stored inputs and no file input (D7); (b) an **agent prompt** through the
     library's `agent-prompt` workflow, which writes `output.md` into the run (D1, F4); or (c) one application's
     **regression suite** (D14). An application has at most one regression schedule; a second one, or a Duplicate of
     one, is refused with 409 naming the existing schedule (D40, D41). The `regression-run` dispatcher is retired and
     m0030 migrated each enabled cadence into its own row once (L-081).
  3. **Agent-prompt trust.** The node gets Phase 53 D9's built-ins, auto-approved, never `delete_file` (D2; ADR-083
     risks a–c accepted for unattended runs until Phase 52), and only **read-only MCP servers**: never
     `appian-dev-write` (ADR-068), `appian-dev-packages` (ADR-073), `appian-devops`, or a curated server with no
     `tool_allowlist`; a custom server only with the user's read-only mark, which Genesis records but does not verify
     (D3). So it is not a mutating MCP node and ADR-021 needs no `pre_mutation` gate. The rule has one home,
     `genesis_core/mcp/pickable.py`, and the node re-checks the picks against the worker's own registry before any skill
     is provisioned or any turn starts; it never trusts a flag in its inputs (D33). Workflow runs load custom-only MCP
     servers; a custom entry reusing a curated name is never used in a run and is never pickable (D32).
  4. **Custom agents** are Genesis-owned profiles (instructions, managed skills, read-only servers, model), maintained in
     Catalog → Agents, never read from `~/.kiro/agents` (ADR-086); usable by agent-prompt schedules, a one-off Run (which
     shows an Open run link, D41) and the read-only chat mode only (D4–D6). A run or a chat carries a snapshot of the
     profile, so an edit or a delete never changes it (F3); deleting a profile a schedule uses is refused. A model change
     is refused while Kiro's model list cannot be read (D35). Genesis still projects the real agent, so the mode's or
     node's trust wins: in chat a picked server contributes only its read-only allowlisted tools, a custom server with
     no allowlist contributes none (D43, ADR-031), each profile has its own engine agent id `genesis-chat-agent-<id>`,
     and a model named when the chat is created wins over the profile's (D44).
  5. **Frequency** forms: every N hours in a window, daily times, weekly days, monthly day (clamped to the month's last
     day), once; an IANA time zone (the picker shows and stores current names such as `Asia/Kolkata`, D42); the
     frequency in words and the next 5 runs come from the backend; times use a 24-hour control; no cron (D9, D29).
  6. **Unattended behaviour.** Missed slots: the most recent runs once within a grace window (default 12 h), older ones
     are recorded `missed`, with a reason that says whether Genesis was down or running but could not start it (D10,
     D49). Overlap: skip and record (D10). A run at a gate raises a notice and is cancelled if unanswered by the next
     slot or the max wait (default 24 h) (D8). Time at a gate or paused does not count toward the max run duration
     (default 2 h), a run paused by hand is never auto-cancelled, and the idle time is stored on the history row (D31). A
     schedule's result is its run's final status (D12). N consecutive failures (default 3) pause it as **Paused
     (failing)**; readiness skips are not failures, and a regression run whose tests fail is `failed` with a notice but
     does not count (D30). Whether a failure counted is stored on the row (`counts_toward_pause`), the one value the
     history shows (D36). No schedule-level retry: retries stay inside the run (ADR-011).
  7. **Traceability.** A run started by a schedule records `trigger_json {source: "schedule", schedule_id, slot}`; each
     slot's outcome is a `schedule_runs` row, with metered credits per run in the history (F1, F9, ADR-032).
  8. **Notifications** go to the top-bar notification center backed by a `notifications` table: unread count, mark
     read, and Remove / Clear read for read notices only (D11, D50).
  9. **API contract.** `/schedules*`, `/custom-agents*` and `/notifications*` under `/api`; a refusal the user can fix
     is 422 `{detail, field, refused?}` naming the field; the application-sync detail reads
     `GET /schedules/{id}/sync-status` (D38, D39). Removed: `/system/sync-settings*`, `/system/schedules` and
     `PUT /applications/{uuid}/testing/schedule` (F7).
  10. **A blocking step must not stall the schedules.** genesis-core's `program_node` runs its step off the worker's
      event loop, so a blocking program step no longer holds `genesis.db`'s write lock (L-026); scheduler, notification
      and run-status writes retry a busy database with a bounded wait, and a pause that could not be stored answers 503
      instead of 200 (D49).
  11. **Agent-written HTML opened read-only cannot script the app's origin.** Every read-only route that serves
      agent-authored HTML (spec, stage artifact, change-request document, design artifact, verification report) sends
      `Content-Security-Policy: script-src 'none'` and `nosniff`, and a pulled stage artifact's annotation frame is
      sandboxed (`allow-scripts`, no `allow-same-origin`; the annotation SDK keeps working over `postMessage`, ADR-043)
      (D48).
- **Alternatives rejected.** Cron expressions (a parser dependency, time-zone pitfalls); importing `~/.kiro/agents`
  (breaks ADR-086); write-capable servers in unattended agents (would gate every run, or break ADR-021 without one);
  schedule-level retries (double credits; retries stay inside the run, ADR-011); replaying every missed slot (credits);
  one system row with a per-app regression table (D14 B); trusting the user's read-only mark in chat too (D43 B, a
  deviation from ADR-031); deriving `counts_toward_pause` at read time from reason text (D36 C, a second reader of the
  rule); shipping with schedules that lose slots while app sync exports (D49 B, C).
- **Consequences.** genesis v0.83.0: migration m0030 (DB v29 → v30: `scheduled_jobs` columns, `schedule_runs`,
  `notifications`, `custom_agents`, `runs.trigger_json`, `chat_sessions.agent_json`); `runtime/schedule_model.py`,
  `scheduler.py`, `schedule_store.py`, `schedule_targets.py`, `notifications.py`; `genesis/agents/`; the
  `/schedules*`, `/custom-agents*` and `/notifications*` routes; the Schedules page, Catalog → Agents, the bell and the
  chat agent picker; `db/database.py` `retry_when_busy`. genesis-core (additive, `CORE_MAJOR` 1): `kiro_node` accepts
  per-run callables for `skills`, `mcp` and `model`; `mcp/pickable.py`; `McpRegistry` tiers; `program_node` off the
  loop. genesis-workflows v0.27.0: the `agent-prompt` workflow and `schedulable` on `agent-prompt`, `sync-documents`,
  `generate-business-map` and `hello-appian` (not the memory workflows, whose cursor has no concurrency guard, D34);
  `agent-prompt` needs genesis ≥ 0.83.0, which the major-only gate (ADR-019) does not enforce. Known issue shipped:
  a one-time schedule paused during its run and resumed afterwards gets a false `missed` row (m7, D52,
  `specs/backlog/phase-54-follow-ups.md` §1). Amends ADR-029: in a workflow run the worker's registry adds the custom-only
  names and never lets a custom entry replace a curated one of the same name (D32); chat and Settings keep the override. Amends ADR-047: scheduled jobs are no longer fixed and
  backend-defined in the UI sense; the system jobs stay backend-seeded but are user-editable rows on the Schedules page,
  and users create their own schedules. Amends ADR-049: the primary navigation as built is Home · Workbench · Chat ·
  Runs · Schedules · Catalog · Documents · Memory, with Settings pinned.
