# 55-07 — The Resolve agent: a run-bound chat that explains an escalation and proposes actions

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/chat/`, `genesis/mcp/`, `genesis/runtime/notifications.py`).
> Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. Decisions: D6, D7, D9, D12–D15, F7
> (`55-01-findings.md`). ADR draft: ADR-089 (`adr-drafts.md`). Routes are added here and listed in 55-08; the Resolve
> tab is 55-09.

## 1. Chat mode `run_resolve`

- A new mode in `genesis/chat/store.py:25-33`, hidden from the Chat page like the stage modes (`store.py:29`), with a
  `ChatModeProfile` (`genesis/chat/mode_profile.py`): `cwd_sandbox=True`, built-ins `fs_read` and `fs_write` confined to
  the session sandbox (`fs_write_root`, ADR-034), no shell, `auto_deny` for anything else (ADR-031); the chat default
  model (F7). Kiro is started as today (ADR-086): a projected agent whose activation is verified, fail closed (L-113).
- MCP: the read-only introspection server (`genesis/mcp/introspection_server.py`) and a new run-scoped
  **`genesis-resolve`** server (`genesis/mcp/resolve_server.py`, launched with the run id; reads through `/api` like
  `control_server.py` or a read-only DB connection):
  - read: `get_escalation()` (the pending gate payload with its F6 fields and `allowed`, 55-06),
    `get_run_documents()` (55-05), `get_run_events(kinds?, node?, limit)` (bounded), `get_node_iterations(node)`;
  - **`propose_action(action, params, rationale)`** — the only tool with an effect: it validates `action` (one of
    the mockup's keys `retry`, `accept`, `fix_accept`, `relaunch`, `restart_from`, `stop`, or an extra option, D12
    item 10) against the gate's current `allowed` and `params` against the action's schema (guidance text for retry;
    **instructions** text for relaunch, D13 — never changed inputs; `as_node` + optional `values` for restart_from;
    `path` + `source_file` for fix_accept, the source inside the sandbox's `drafts/`; a reason for stop), stores a
    **proposal** and returns its id. It applies nothing.
  - Trust = exactly these tools + the sandboxed fs built-ins; tested on the real projection with a negative control
    (L-116, L-117).
- No tool answers a gate, relaunches, forks or stops (ADR-033: the agent never answers a gate; the user's Confirm does).

## 2. Proposals

- Stored in `copilot_actions` as `proposed` (source `resolve`, the session, the run, the gate occurrence, action,
  params, rationale). Emitted on the session stream as a `resolve.proposal` event so the panel renders a card (55-09).
  A newer proposal for the same action supersedes the older one. Dismiss → `dismissed`.
- **Confirm** (the user, via 55-08's route) re-validates against the run's current gate payload (stale → 409 with the
  reason) and calls the 55-06 operation; the outcome (for relaunch and restart_from: the new run id, the old run
  `cancelled`, the stage / story moved, D13, D15) is written back to the row and posted to the session as a system
  note, so the agent knows what happened, and shown in the Resolve tab (D14).
- When the run leaves the gate (answered elsewhere, cancelled, ended), open proposals become `stale`.

## 3. Session lifecycle

- Created on the user's first open of Resolve (D7; no credits for an unopened escalation): create the session, copy
  the run's files into `<sandbox>/run/` (everything but System; take the list from `manager.documents(run_id)` and
  roles from `genesis.runs.artifact_roles.roles_of`, one reader, L-109, 55-05; `_toolcalls/` included while it exists, D9; `_prompts/`
  included), then `enqueue_system_turn` with a seed: workflow name and summary, the failed step and reason, the
  validator messages, the retry / heal history, the documents list with categories, the available actions, and the
  memory brief path if any. Steering: explain what went wrong in plain words, point to the files that show it, then
  propose one to three actions with reasons; say which facts come from the run and which are guesses; never claim an
  action was applied.
- One session per run, continued across later escalations of the same run; on a new escalation (a new gate
  occurrence) the sandbox copy is refreshed and a system note gives the new failure.
- The link run → session is stored by 55-08 (a dedicated table; `chat_run_links` keeps its one copilot session per
  run).
- Credits are metered per turn (ADR-032) and summed for the panel.

## 4. Notifications

- A `RunManager` event observer: every `gate.awaiting` of kind `escalation` (any run, not only scheduled) writes a
  `needs_you` notification (`genesis/runtime/notifications.py`) with the run name, the failed step and the link
  `/runs/<id>/resolve` (D12 item 8; opening the notice does not start the agent, opening Resolve does); deduped on (run, gate seq) so a scheduled run's existing notice (`runtime/scheduler.py:398`)
  is not doubled; marked read when the gate is resolved. Store the notification before announcing anything that refers
  to it (L-093); a level-triggered reconcile covers a missed live event (L-058).

## 5. Tests

- Profile: no shell; writes only in the sandbox; only the listed tools trusted; activation verified; a write outside the
  sandbox and an unlisted MCP tool are refused (negative controls).
- `propose_action`: each action valid and invalid; unavailable action refused; source file outside `drafts/` refused;
  supersede; stale after the gate is answered elsewhere.
- Seed content from a real escalated run's payload (shape from 55-06's real payload, L-083).
- Notification: once per escalation, not doubled for scheduled runs, cleared on resolve, recovered after a restart.

## 6. Gates

genesis pytest + ruff; kiro-agent-sdk pytest (if touched).

## Context manifest

```toml
areas    = ["chat", "runs-worker", "sdk-acp"]
adrs     = ["ADR-001", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-086"]
lessons  = ["L-017", "L-041", "L-042", "L-058", "L-083", "L-093", "L-113", "L-116", "L-117", "L-118"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/genesis/chat/mode_profile.py", "genesis/genesis/chat/store.py", "genesis/genesis/chat/manager.py", "genesis/genesis/mcp/introspection_server.py", "genesis/genesis/mcp/control_server.py", "genesis/genesis/runtime/notifications.py"]
upstream = ["55-02", "55-05", "55-06"]
```
