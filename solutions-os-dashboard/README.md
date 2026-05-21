# Solutions OS Dashboard

**Status:** Research / Architecture Analysis
**Inspiration:** Tao Dashboard (localhost:3773)

## Vision

A standalone web application that serves as the primary interface to Solutions OS — providing session management, agent selection, change tracking, and task tracking without requiring Kiro IDE.

---

## Tao Dashboard Architecture Analysis

### What Is Tao

Tao is an agent orchestration system written in Go (backend) with React/TypeScript (frontend). It manages AI agent sessions with full lifecycle control — from problem decomposition to task execution to review.

**Source:** `~/repo/springfield/institutions/tao/`
**Installation:** `/usr/local/lib/tao/`
**Config:** `~/.tao/`

### System Binaries

| Binary | Size | Purpose |
|--------|------|---------|
| `tao-dashboard` | 58MB | Main app: HTTP server, session mgmt, execution, checkpointing |
| `session-controller` | 25MB | Manages a single planning session (agent selection, bead tracking) |
| `agent-runner` | 22MB | Lifecycle of a single task execution (Architect → Executor → Reviewer) |
| `bead-devil-trigger` | 22MB | Provides agent-runners to open tasks, manages lifecycle; runs in tmux |
| `post-commit-hook` | 22MB | Git hook for tracking changes |
| `agent-selector` | 17MB | Assigns best agent to a task given input |
| `tao-categorize-agents` | 12MB | Categorizes available agents |
| `session-summary` | 12MB | Generates session summaries |
| `tool-registry` | 11MB | Manages tool/capability registration |
| `session-daemon-manager` | 6MB | Daemon for session lifecycle |
| `tao` | 17KB | CLI wrapper (bash) for start/stop/status/setup/capabilities |

### Architecture Pattern: A → E → R Pipeline

Every task (bead) goes through three AI personas:
1. **Architect** — READ-ONLY reconnaissance, design reasoning, verification plan
2. **Executor** — Implements the design briefing
3. **Reviewer** — Validates the implementation against the verification plan

This is enforced by the `agent-runner` binary which manages the handoff between personas.

### Data Storage

**SQLite databases:**

`sessions.db` — Core session state:
```sql
sessions (id, goal, status, start_time, agent, provider, model, working_repo, trust_mode, ...)
execution_log (session_id, bead_id, status, phase, round, review_outcome, transcript_ref)
touched_files (session_id, bead_id, path, change_type, diff_text, baseline_hash)
attachments (session_id, filename, path, size, sent)
metrics (session_id, component, event, bead_id, duration_ms, data)
```

`metrics.db` — Performance tracking

### Capability Registry

Located at `~/.tao/capabilities/index.json` — a registry of available tools/capabilities:

```json
{
  "beads": {
    "description": "Issue tracking and task management",
    "signals": ["bead", "task", "issue", "plan"],
    "methods": {
      "cli": { "command": "bd" },
      "mcp": { "command": "uvx", "args": ["beads-mcp"] }
    },
    "preferred": "mcp"
  },
  "github": {
    "description": "GitHub repository operations",
    "signals": ["github", "pull request", "pr"],
    "methods": {
      "cli": { "command": "gh" },
      "mcp": { "command": "docker", "args": [...] }
    }
  }
}
```

Each capability has:
- `signals` — keywords that trigger this capability
- `methods` — multiple ways to invoke (CLI, MCP, builtin)
- `preferred` — which method to use by default
- `credentials` — required env vars

### Agent System

Agents are JSON manifests stored at `~/.tao/agents/` with sections:
- `role` — who the agent is
- `workflow` — step-by-step process
- `output_contract` — required output format
- `constraints` — boundaries

Agents can be "projected" to different providers: `~/.kiro/agents/`, `~/.gemini/agents/`

### Configuration

`~/.tao/config.json`:
```json
{
  "dashboard_url": "http://localhost:3773",
  "default_provider": "kiro",
  "fast_model": "claude-sonnet-4.6",
  "max_agents": 10,
  "models": {
    "kiro": ["claude-opus-4.6", "claude-sonnet-4.6", "claude-haiku-4.5"],
    "gemini": ["gemini-2.5-pro", "gemini-2.5-flash"]
  }
}
```

### Dashboard UI Features (from snapshot)

- **Session list** — Active sessions with names, timestamps, project tags
- **Config selectors** — Repo, Agent, Model, Trust level dropdowns
- **Interactive terminal** — Embedded shell for kiro-cli interaction
- **Task panel** — Tasks (beads) with completion tracking
- **Changes panel** — Files modified in current session
- **Skill injection** — Button to inject specialized skills mid-session

### Key Design Decisions in Tao

1. **Go for all binaries** — performance, single binary deployment, strong typing
2. **SQLite for persistence** — lightweight, no external DB needed, WAL mode for concurrency
3. **tmux for agent execution** — isolated terminal sessions per task
4. **Beads (bd) for task tracking** — tasks are first-class entities with their own lifecycle
5. **Capability registry** — dynamic tool discovery, multiple invocation methods per capability
6. **Provider-agnostic** — same session can use kiro, claude-code, cursor, or gemini
7. **Post-commit hook** — automatically tracks file changes per session
8. **Health checks** — `tao capabilities list` shows green/yellow/red status per capability

---

## What We Want for Solutions OS Dashboard

### Must-Have (MVP)

1. **Session management** — Start, resume, list sessions. Each session tied to a product/agent
2. **Agent selection** — Pick orchestrator or specialist (developer, PO, UX, QE, sql-forge)
3. **Kiro CLI integration** — Spawn and interact with kiro-cli sessions
4. **Change tracking** — Files modified during a session, viewable diffs
5. **Task tracking** — Tasks created/completed within a session
6. **Unified MCP status** — Show which planes are active (Cloud, Live, Data Gen)

### Nice-to-Have (v2)

7. **Multi-provider support** — Switch between kiro, gemini, claude-code
8. **Capability health dashboard** — Green/yellow/red for each MCP tool
9. **Session history & search** — Find past sessions by product, date, or content
10. **Team visibility** — See what others are working on (shared sessions)
11. **Skill injection** — Load specialized knowledge mid-session
12. **Metrics** — Time per task, tool usage patterns, agent effectiveness

### Architectural Decisions to Make

| Decision | Options | Leaning |
|----------|---------|---------|
| Language | Go (like Tao) vs Node.js vs Python | TBD — Go gives binary simplicity, Node gives faster UI iteration |
| Frontend | React (like Tao) vs Svelte vs plain HTML | React — proven in Tao, good ecosystem |
| Persistence | SQLite (like Tao) vs Postgres | SQLite — zero-config, sufficient for local use |
| Agent execution | tmux (like Tao) vs pty vs direct process | TBD — depends on how kiro-cli handles sessions |
| Distribution | Binary (like Tao) vs Docker vs npm package | Binary preferred — single install, no deps |
| Task system | Beads vs custom vs Jira integration | Needs discussion — Jira integration may be more natural for Solutions teams |

---

## Next Steps

1. [ ] Explore Tao source code at `~/repo/springfield/institutions/tao/` for deeper implementation details
2. [ ] Prototype: minimal Go server + React UI that spawns a kiro-cli session
3. [ ] Define the session data model for Solutions OS context
4. [ ] Design the unified MCP health check API
5. [ ] Decide on task tracking approach (beads vs Jira vs hybrid)
