# 4. Container view (C4 level 2)

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 sections 3–5

In C4, a **container** is anything that runs or stores data on its own: a process, a database, a folder of files
with its own owner. This document lists every container in a running Genesis, what starts it, how long it lives
and how it talks to the others.

The most important idea on this page: **the app process never runs workflow code.** Workflow graphs run in a
short-lived worker process. The worker, in turn, starts one Kiro CLI process per agent step. Kiro starts the MCP
servers that step needs. So a single run is a small tree of processes that can be killed at any level without
harming the app.

## 4.1 Container diagram

```mermaid
flowchart TB
    browser(["Browser<br/>React SPA"])

    subgraph app["Genesis app process — genesis serve (uvicorn)"]
        api["FastAPI /api<br/>+ SPA files"]
        rm["RunManager"]
        chatm["ChatManager"]
        fin["Finalizers and observers<br/>(run → domain records)"]
        sched["Scheduler + collab auto-pull"]
        reports["Reports origin<br/>(second listener, port + 100)"]
    end

    subgraph worker["Run worker — python -m genesis.runs.worker (one per run operation)"]
        graph["Workflow graph.py<br/>+ genesis-core nodes"]
    end

    kiroW["kiro-cli acp<br/>(one per agent step)"]
    kiroC["kiro-cli acp<br/>(one per live chat session)"]
    mcpW["MCP servers for the step<br/>blackboard, appian-dev, genesis-kb, …"]
    mcpC["Chat MCP servers<br/>genesis-kb, genesis-memory,<br/>genesis, appian-dev, genesis-control"]
    browserTest["apwt / Playwright / Chromium<br/>(test runs only)"]

    db[("genesis.db<br/>SQLite WAL")]
    memdb[("memory.db<br/>SQLite")]
    art[["Artifacts root<br/>~/Genesis/runs/&lt;workflow&gt;/&lt;run&gt;/"]]
    state[["State folder ~/.genesis/<br/>library, lockfile, secrets,<br/>stage artifacts, testing workspaces"]]

    browser -- "HTTP /api + SSE" --> api
    browser -- "report pages" --> reports
    api --> rm & chatm
    rm -- "spawn, JSON job on stdin;<br/>JSONL events on stdout" --> worker
    graph -- "ACP stdio" --> kiroW
    kiroW -- "MCP stdio" --> mcpW
    chatm -- "ACP stdio" --> kiroC
    kiroC -- "MCP stdio" --> mcpC
    graph -- "program steps" --> browserTest
    rm & fin & chatm --> db
    graph -- "checkpoints" --> db
    graph --> art
    mcpC --> db & memdb
    reports --> art
    rm & fin --> state
```

The browser talks only to the app process. The app's RunManager starts a worker for each run operation. The
worker loads the workflow's `graph.py`, runs it, and writes LangGraph checkpoints into `genesis.db` and bulk
files into the run's artifacts folder. Each agent step in the graph starts its own `kiro-cli acp`, which starts
that step's MCP servers. Chat is different: it keeps one `kiro-cli` per live chat session inside the app process,
with a fixed read-only set of MCP servers. Test workflows also start browser processes from program steps.

## 4.2 The containers

### Processes

| Container | Started by | Lives for | Technology | Job |
|---|---|---|---|---|
| **Browser SPA** | The user opening `http://127.0.0.1:8760` | The browser tab | React 18 + TypeScript, built by Vite into `web/static/` | All UI. Reads and writes only through `/api`. Follows a run live through Server-Sent Events (SSE). |
| **App process** | `genesis serve` (foreground) or `genesis up` (background, PID file under `~/.genesis/run/`) | Until stopped | Python 3.13, FastAPI on uvicorn | Serves `/api` and the SPA files. Owns run control (`RunManager`), chat (`ChatManager`), the bridges that turn finished runs into domain records (finalizers), the scheduler, the collaboration auto-pull loop and the test-execution queue. Holds the run-owner lock `~/.genesis/run/runs.lock`. |
| **Reports origin** | `genesis serve`, before the app starts | The app process | Python `ThreadingHTTPServer` on its own port (app port + 100, so 8860 by default) | Serves Playwright HTML reports as static files. No `/api`, GET and HEAD only, `Host` checked, no directory listing, no path traversal (ADR-085). A report page cannot reach the app's API because it is on another origin. |
| **Run worker** | `RunManager` through `Supervisor.spawn` | One operation: run, resume, get_state, update_state or fork | `python -m genesis.runs.worker` | The only process that imports workflow Python. Builds the graph, streams it, writes checkpoints, prints events as JSON lines, exits. Killing it is how pause works (ADR-012). |
| **Kiro CLI for an agent step** | `kiro_node` inside the worker, through `kiro-agent-sdk` | One agent turn | `kiro-cli acp` | Runs one narrow agent turn with the step's prompt, working folder (the run's artifacts folder), MCP servers and trusted tools. |
| **Kiro CLI for chat** | `ChatManager` in the app process | A live chat session; closed after 30 idle minutes by default | `kiro-cli acp` | Answers chat turns read-only. Its working folder is `~/.genesis`, so the managed skills under `~/.genesis/.kiro/skills/` are found; a feature-spec chat works in its own output folder instead. |
| **MCP servers** | The Kiro CLI that received them in `session/new` | That Kiro session | Mostly `python -m …` stdio servers; the Appian servers run from their own installed Python environments | Give the agent tools. See 4.3 for the list. |
| **Browser test processes** | Program steps of test workflows, through `apwt` | A test run, a recording or a replay | Node.js 20+, Playwright, Chromium | Drive the QA site as a test user. Their process ids are recorded under `<run>/.pids` so they are stopped when the run ends, pauses or is cancelled (L-104). |
| **Background jobs** | The app's scheduler and the Testing tab | One job | Async tasks and threads in the app process, or launched workflow runs | Scheduled KB syncs, document syncs, Hub pulls, memory jobs, regression runs, Chromium installs, workspace updates. |

### Data stores

| Container | Path (defaults) | Owner | What it holds |
|---|---|---|---|
| **genesis.db** | `~/.genesis/genesis.db` | `genesis/db/` migrations | Runs and their durable event log, LangGraph checkpoints, chat sessions and messages, the code-free Appian knowledge base, documents index, features and stages, stories and boards, test catalog and executions, schedules, collaboration bookkeeping. SQLite in WAL mode so the checkpointer and the app can write side by side. |
| **memory.db** | `~/.genesis/memory.db` | `genesis/memory/` migrations | Personal and shared memories, entities, relationships and their vectors (ADR-054). Separate file, separate migrations. |
| **Artifacts root** | `~/Genesis/runs/<workflow_id>/<run_id>/` (`GENESIS_ARTIFACTS_DIR`) | The run (its worker and agents) | The run's *blackboard*: every bulk file a run produces or receives. Uploaded inputs (`uploads/`), agent outputs, captured prompts (`_prompts/`), the tool-output store (`_toolcalls/`, removed when the run ends), provisioned skills (`.kiro/skills/`), test checkouts, reports. |
| **State folder** | `~/.genesis/` (`GENESIS_STATE_DIR`) | The app | `library/` (installed workflows and registries), `installed.lock.json`, `secrets.json` (mode 0600), `environments.json`, custom MCP/CLI tiers, `.kiro/skills/` (the managed skills workspace), `skill-output/<session>/` (chat write sandbox), `kb-documents/`, `feature-stage-artifacts/`, `story-stage-artifacts/`, `mcp-servers/` and `cli-tools/` (managed installs), `testing/` (Chromium and one git workspace per application), `run/` (PID file, run-owner lock, logs). |

Bulk content never goes into the database or into LangGraph state. The database stores a path and usually a
content hash; the file holds the bytes (ADR-010, ADR-018, ADR-022).

## 4.3 MCP servers by who uses them

| Server | Launched as | Used by | Tools |
|---|---|---|---|
| `blackboard` | `python -m genesis_core.mcp.blackboard_server --root <run folder>` | Every workflow agent step (unless it opts out) | `list_tool_outputs`, `save_tool_output`, `read_tool_output`: save a big tool result into a run file without the bytes passing through the model (L-021) |
| `genesis-kb` | `python -m genesis.mcp.kb_server --db genesis.db` | Chat; workflow steps that declare it | Read-only search over the local knowledge base; live object code through the Dev MCP |
| `genesis-memory` | `python -m genesis.mcp.memory_server` | Chat | Read-only memory search, entities, relationships |
| `genesis` (introspection) | `python -m genesis.mcp.introspection_server` | Chat | Read-only runs, steps, events, failures, workflows, health, stats |
| `genesis-control` | `python -m genesis.mcp.control_server --base-url <app>/api` | Chat in copilot mode only | Read tools (trusted) and `start_run`, `respond_to_gate`, `cancel_run` (never trusted, so each call asks the user, ADR-033) |
| `appian-dev`, `appian-dev-write`, `appian-dev-packages` | The managed Dev MCP install for the Dev environment | Chat (read), design and implementation workflows, program code for packages (ADR-073) | Appian object reads; writes only for Implementation; package tools only from Genesis program code |
| `appian-devops` | The managed DevOps MCP install | KB sync workflow | Application export |
| Docker-launched entries (for example `jira`) | `docker run …` from the curated registry | Workflows that declare them | Varies |

A workflow agent step receives the servers it lists, plus `blackboard`. Its trusted tool set is the step's own
tool list capped by each server's allowlist (ADR-029). Two limits apply in v0.81.0 (ADR-083, accepted until agent
isolation ships): Kiro also loads the user's global `~/.kiro/settings/mcp.json` servers into every workflow turn,
and the SDK approves permission requests for workflow agents, so the trusted set is not a hard limit there.
Chat sessions do enforce their trusted list.

## 4.4 How the containers communicate

| From | To | Mechanism | Notes |
|---|---|---|---|
| Browser | App | HTTP JSON under `/api`; SSE at `/api/runs/{id}/events/stream` | The client prepends `/api` centrally and refuses non-JSON answers (L-010) |
| Browser | Reports origin | HTTP GET of static report files | Opened in a new tab from an execution page |
| App | Worker | Spawn with a JSON job on stdin; the worker prints one JSON event per stdout line | Reader thread per worker; non-zero exit without a final event fails the run |
| Worker | genesis.db | `AsyncSqliteSaver` (checkpoints) and plain SQLite writes from program nodes | WAL plus a 30 s busy timeout, so writers wait instead of failing |
| App | genesis.db | `genesis.db.Database` connection factory, one short connection per call | Blocking writes from async code run off the event loop (L-026) |
| Worker or app | Kiro CLI | ACP: JSON-RPC 2.0 over stdio, through `kiro-agent-sdk` | `initialize`, `session/new` with the MCP list, `session/prompt`; Kiro asks back for permissions and file reads/writes |
| Kiro CLI | MCP servers | MCP over stdio | Started and stopped by Kiro with the session |
| Chat MCP `genesis-control` | App | HTTP to `/api` with a per-session control token | The only path by which chat can change a run, and every such call is confirmed by the user |
| App | Genesis Hub | HTTPS to the Hub Web API | Opt-in; publish and pull |
| Worker program steps | Appian, Google, QA | Through MCP clients, `gws`, `sail`, `apwt` | Credentials resolved at launch from the SecretProvider and the environment registry |

## 4.5 What happens when a container dies

| Container dies | Effect | Recovery |
|---|---|---|
| A run worker | The run is marked `failed` with the worker's error, unless the user had paused or cancelled it | A failed run is terminal and cannot be resumed; fork it from its last checkpoint. A paused run resumes from its checkpoint. Completed steps are not repeated in either case |
| A Kiro CLI during a turn | The SDK ends the turn with an error. The step returns normally, its output file is empty or invalid, the validator fails, and the reliability trio retries the step | Automatic retry, then an escalation gate where a person decides |
| A Kiro CLI that cannot start (missing binary, start-up timeout, an MCP variable that does not resolve) | The step raises, so the worker reports an error and the run fails | Fix the cause, then fork the run from its last checkpoint or start it again |
| The app process | Workers it started lose their parent. On the next start, the process that takes the run-owner lock fails every run left `running` with "worker lost across a server restart" and leaves paused and gated runs alone (L-097) | The user resumes or re-runs; finalizers catch up on runs that finished while the app was down (L-058) |
| The reports origin | Report links stop opening | Restart `genesis serve` |
| genesis.db locked by another writer | The writer waits up to the busy timeout | Automatic |
