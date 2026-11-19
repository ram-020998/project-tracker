# Phase 54 — ADR drafts

> **Status:** DRAFT 2026-11-19 (genesis-spec). Filed by genesis-docs at the release (54-11 §3) with
> `genesis-ctx add adr --id ADR-087 … --amends ADR-047 ADR-049 --status accepted --phase 54` (one `--amends` flag, ids
> space-separated). Until then sub-spec manifests list this file in `docs` and the amended ADRs in `adrs`.
> Source of every clause: `54-01-findings.md` §8 (D-numbers) and §9 (F-numbers).

## ADR-087 (proposed) — Schedules: one user-managed schedule model for system jobs, workflows, agent prompts and regression suites

- **Status.** PROPOSED — Phase 54. Amends **ADR-047** and **ADR-049**.
- **Areas.** runs-worker, config-secrets, web-shell, workflows-library, chat, security.
- **Rule (one-liner, ≤ 220 chars).** Every schedule lives in `scheduled_jobs` and is managed on the Schedules page: system jobs editable not deletable; user schedules run a `schedulable` workflow, an agent prompt or a regression suite.
- **Context.** ADR-047 made scheduled syncs fixed and backend-defined; ADR-074 later made the app sync configurable in
  Settings → General, and Phase 51 added a per-app regression cadence in Testing → Setup. Document sync, Hub pull and
  the memory jobs had no UI. Runs recorded no trigger, gates in unattended runs waited forever, and a fire-and-forget job
  recorded `ok` for a run that later failed (54-01 §2).
- **Decision.**
  1. **One page, one model.** A **Schedules** entry in the primary navigation (after Runs) lists every schedule. System
     schedules (`application-sync`, `document-library-sync`, `kb-hub-pull`, `memory-consolidation`,
     `memory-maintenance`) are editable (frequency, on/off, their options) and resettable, never deletable; their
     options live only there (D1, D15). User schedules are created, edited, duplicated and deleted by the user.
  2. **Targets.** A user schedule runs (a) an installed workflow that declares `META.schedulable: true`, with stored
     inputs (D7); (b) an **agent prompt** through the library's `agent-prompt` workflow, which writes `output.md` into
     the run (D1, F4); or (c) an application's **regression suite** (D14; replaces the `regression-run` dispatcher).
  3. **Agent-prompt trust.** The node gets Phase 53 D9's built-ins, auto-approved, never `delete_file` (D2; ADR-083
     risks a–c accepted for unattended runs until Phase 52), and only **read-only MCP servers**: never
     `appian-dev-write` (ADR-068), `appian-dev-packages` (ADR-073), `appian-devops`, or a curated server with no
     `tool_allowlist`; a custom server only with the user's read-only mark (D3). So it is not a mutating MCP node and
     ADR-021 needs no `pre_mutation` gate. The rule has one home, `genesis_core/mcp/pickable.py`, and the node re-checks
     it against the worker's own registry before any turn (D33). Workflow runs load custom-only servers; a custom entry
     reusing a curated name is never used in a run (D32).
  4. **Custom agents** are Genesis-owned profiles (instructions, skills, read-only servers, model), maintained in
     Catalog → Agents, never read from `~/.kiro/agents` (ADR-086); usable by agent-prompt schedules, a one-off Run, and
     the read-only chat mode only (D4–D6). Genesis still projects the real agent, so the mode's or node's trust wins.
  5. **Frequency** forms: every N hours in a window, daily times, weekly days, monthly day, once; IANA time zone; next
     runs previewed; no cron (D9).
  6. **Unattended behaviour.** Missed slots: the most recent runs once within a grace window (default 12 h), older
     ones are recorded `missed` (D10). Overlap: skip and record (D10). A run at a gate raises a notice and is cancelled
     if unanswered by the next slot or the max wait (default 24 h) (D8). A schedule's result is its run's final status;
     a max run duration (default 2 h) cancels; N consecutive failures (default 3) pause it as **Paused (failing)** (D12).
  7. **Traceability.** A run started by a schedule records `trigger_json {source: "schedule", schedule_id, slot}`;
     each slot's outcome is in `schedule_runs` (F1).
  8. **Notifications** go to the top-bar notification center backed by a `notifications` table (D11).
- **Alternatives rejected.** Cron expressions (parser dependency, time-zone pitfalls); importing `~/.kiro/agents`
  (breaks ADR-086); write-capable servers in unattended agents (would gate every run, or break ADR-021 without one);
  schedule-level retries (double credits; retries stay inside the run, ADR-011); replaying every missed slot (credits).
- **Consequences.** genesis (scheduler, store, m0030, APIs, Schedules page, Catalog → Agents, chat agent picker, bell),
  genesis-core (`kiro_node` accepts callables for `skills`, `mcp`, `model`; additive, `CORE_MAJOR` 1), genesis-workflows
  (`agent-prompt` workflow, `schedulable` flags). The Settings → General sync card and the Testing → Setup schedule
  editor go. ADR-049's navigation list is updated to the code: Home · Workbench · Chat · Runs · Schedules · Catalog ·
  Documents · Memory, Settings pinned.
