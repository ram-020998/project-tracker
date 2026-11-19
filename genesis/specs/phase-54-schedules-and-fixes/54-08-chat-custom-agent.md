# 54-08 — Chat: a read-only session with a custom agent

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`genesis/chat/`, `genesis/api/chat.py`, `web/src/features/chat/`).
> Parent: `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev** after 54-03's approval. Decisions: D5, D6
> (`54-01-findings.md` §8).

## 1. Backend

1. `POST /chat/sessions` accepts `agent_id` only with `mode == "read_only"` (422 otherwise, 54-06). **54-06 already
   added** the `mode` field, the validation, the `chat_sessions` snapshot column (in m0030) and a 409 stub for a valid
   read-only `agent_id` (D37); 54-08 stores the snapshot, projects it, and removes the 409. The session stores
   the agent's **snapshot** (`custom_agents.snapshot`, 54-05 §1) in the column 54-06 added to `chat_sessions`. The agent is fixed
   for the session: `set_session_mode` (`chat/manager.py:937`) to another mode is refused (422) for a session with an
   agent (the toggle is hidden, D26).
2. The read-only profile (`chat/mode_profile.py:226`, `ChatModeProfile`) is unchanged for every other session. For a
   session with an agent:
   - instructions: the read-only assistant's own prompt first, then a delimited block "Additional instructions from the
     custom agent <name>" (the assistant's rules keep precedence: ADR-031);
   - skills: the agent's skills, if installed, are listed to the model; they are reached through the chat cwd as today
     (Phase 53, managed skills only);
   - MCP: the agent's servers are validated with `check_picks(config.merged_mcp_registry(), picks)` (D33; 54-05 As
     built) and added to the session's servers, each still capped to its **read-only** allowlist in
     the projected agent and backed by the permission ladder's `auto_deny` (ADR-031, L-017); a custom server marked
     read-only by the user is added with the same fail-closed treatment (no tool is trusted beyond the read-only
     allowlist build, L-116);
   - built-ins: none beyond the read-only mode's (no shell, no writes outside the sandbox, ADR-034);
   - model: the agent's model, if set, is the session's starting model (the user can still change it as today).
3. Resume (`session/load`, Phase 53) rebuilds the same agent from the stored snapshot.
4. Trust is verified as for every chat session (activation checked, fail closed, L-113); add one live probe in
   acceptance (54-10).

## 2. Web

New-chat control with an optional custom agent picker (read-only mode only), the agent name in the chat header, and
a short note that in chat the agent keeps chat's read-only tools (D5), as in the approved mockup
(`web/src/dev/mockups/phase54/bell-chat.tsx`, genesis `b09b08e`). **A chat with a custom agent hides the Copilot
toggle (D26)**; the backend still refuses a mode change to copilot for such a session (§1.1).

## 3. Tests

Backend: the projected agent for a session with an agent contains only read-only tools and the agent's skills; a
copilot session with `agent_id` → 422; resume keeps the agent; deleting the agent while a chat uses it is allowed (F3
refuses only when a schedule uses it) and the chat keeps its stored snapshot. Web: picker, header, a11y.

## 4. Gates

SDK, genesis pytest + ruff; web lint, typecheck, test; build + commit `web/static/` separately (L-089).

## As built

_(genesis-dev fills in: commits, changes, tests, review verdict, decisions/deviations, lesson candidates, Resume note.)_

## Context manifest

```toml
areas    = ["chat", "sdk-acp", "config-secrets"]
adrs     = ["ADR-029", "ADR-031", "ADR-034", "ADR-045", "ADR-086"]
lessons  = ["L-017", "L-024", "L-089", "L-113", "L-116", "L-117"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-54-schedules-and-fixes/54-05-custom-agents-and-agent-prompt.md"]
code     = ["genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/web/src/features/chat/**"]
upstream = ["54-03", "54-05", "54-06"]
```
