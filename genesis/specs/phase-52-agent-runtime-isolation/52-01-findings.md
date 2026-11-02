# 52-01 — Findings: agent runtime isolation (the problem, the evidence, the solution)

> **Status:** BRIEF — written 2026-11-02 by the genesis-spec agent, before the Phase 52 Q&A. It is the starting
> point for the Phase 52 spec set (umbrella `specs/phase-52-agent-runtime-isolation.md` and sub-specs, not written yet).
> The Phase 52 spec agent runs the Q&A against §13, records decisions in §14, then writes the spec set.
> Origin: Phase 51 (test execution engine), spike 51-03 and the follow-up checks of 2026-11-02 —
> `specs/phase-51-test-execution-engine/51-01-findings.md` D3, D3a, D3b and §2.3, and the 51-03 As built.
> Built **in parallel** with Phase 51, by a separate agent session (user's direction, 2026-11-02).

---

## 0. Summary in one page

**The problem.** Every Genesis **workflow** agent can run any shell command on the user's Mac, as the user, today.
Two code paths cause it (§3): `kiro_node` never sets a permission mode, so the Kiro SDK's default `auto_approve` says
yes to every permission request, including the shell; and a node with no tool list and no server allowlist starts
Kiro with `--trust-all-tools`. The run history proves it is used: **153 shell commands by workflow agents**, in 13
workflows and 21 nodes, including the Dev-writing `story-implementation` `implement` node dumping environment
variables, forcing DNS with `curl --resolve`, trying `sudo -n true` and checking whether it can write `/etc/hosts`
(§4). From the shell an agent can read `~/.genesis/secrets.json` and `genesis.db`, call the **unauthenticated local
Genesis API** (≈154 mutating routes: start runs that write to Dev, answer HITL gates, change Settings, install
binaries), read the user's repos, `~/.ssh`, `~/.aws`, and reach any host on the internet (§5). Every one of these
agents reads **untrusted content** (Appian KB data, design documents, uploaded files, web pages, and — from Phase 51 —
live application page text). That is the "lethal trifecta" (private data + untrusted content + a way out) in full.

**What was ruled out.** (a) Taking the shell away from agents (fail-closed nodes): the user does not want to change
working workflows, and agents rely on the shell (JSON checks, doc lookups). (b) Kiro's local command sandbox: proven to
work (51-03 S1, S5, S6) but it **always allows loopback**, so the local Genesis API stays reachable; it also needs a
V3-only ACP recipe and a model can refuse the self-test. (c) MCP-only access for each tool: per-tool wrapping, and it
does not cover the shell the agents already use.

**The solution (proposed).** Keep the full shell, but run **each agent turn's Kiro process inside a disposable
isolated environment** — a Linux container on Apple's `container` runtime (one lightweight VM per container) or
Colima/Docker — that holds **only** the run's own folder and a fixed toolset, has **its own network namespace** (so
host loopback, i.e. the Genesis API, does not exist inside it), sends all egress through a **host-side allow-list
proxy**, and reaches MCP tools through a **host-side MCP gateway** so MCP credentials never enter the box. Kiro inside
the box authenticates with `--auth-method client` (the host answers token requests), so no refresh token lives in the
box. The worker, LangGraph, the checkpointer, `genesis.db`, the secrets and all MCP servers stay on the host exactly
as today; graphs, prompts and trust lists do not change. Defence-in-depth items that stand on their own (a local API
token, the global Kiro `mcp.json` question, an explicit permission mode) are listed in §9.

---

## 1. Why this document exists

During Phase 51 (scripts and test execution on top of `playwright-appian`), the design needed agents to drive a
browser through the `apwt` CLI. Spike 51-03 tested Kiro's OS sandbox for that and found that a sandboxed shell can
still reach the local Genesis API. Checking the fallback design ("agents get no shell") then showed that **no Genesis
workflow agent is shell-restricted today** — the earlier assumption in the Phase 51 findings was wrong
(`51-01-findings.md` §2.3, corrected). The user decided not to change working workflows and asked for a separate
phase that gives Genesis **an isolated environment of its own**, with all required tools installed, where agents keep
full shell access without touching the user's environment (2026-11-02). This document explains the problem, the
evidence, the constraints, the options and the proposed solution in full, so a separate agent can spec and build it
in parallel with Phase 51.

## 2. How Genesis runs agents today (verified in code, 2026-11-02)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`; `workflows/` =
`/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-workflows/workflows`.

### 2.1 The run path

1. The app process (`genesis serve`, FastAPI) starts a run through `RunManager` (`genesis/genesis/runs/manager.py`).
2. The **supervisor** spawns a disposable worker, `python -m genesis.runs.worker`, with the job on stdin
   (`genesis/genesis/runs/supervisor.py:58-60`; ADR-012). Pause = kill the worker; resume = a fresh worker from the
   checkpoint. The app never imports workflow Python.
3. The worker loads the workflow's `graph.py` standalone, builds the `PlatformContext` (MCP registry with secrets and
   the environment seam, CLI registry, blackboard `RunWorkspace` at `<artifacts_root>/<workflow>/<run>/`,
   `$GENESIS_ARTIFACTS_DIR` default `~/Genesis/runs`, ADR-010/022), and runs the LangGraph graph with the
   `AsyncSqliteSaver` checkpointer on `~/.genesis/genesis.db` (ADR-024).
4. An **agent node** is `kiro_node(...)` (`genesis/packages/genesis-core/genesis_core/nodes/agent.py:195`). For each
   turn it:
   - provisions declared skills into `<run folder>/.kiro/skills/<id>/` (ADR-069, `_provision_skills` `:78-113`);
   - resolves the node's MCP servers into ACP entries (`ctx.mcp.acp_servers(...)`,
     `genesis/packages/genesis-core/genesis_core/mcp/registry.py:115-140`): each is a **stdio** server
     `{name, command, args, env:[{name,value}]}` with its secrets resolved into `env` (L-001), launched **by Kiro** as
     a child process;
   - adds the Genesis **blackboard MCP** server (`python -m genesis_core.mcp.blackboard_server --root <run folder>`,
     tools `list_tool_outputs`, `save_tool_output`, `read_tool_output`; `nodes/tool_store.py:27`);
   - computes trust (`_compute_effective_trust`, `agent.py:137-166`) and builds `KiroAgentOptions` with
     `cwd=<run folder>`, the MCP servers, model, timeouts (`agent.py:288-301`);
   - runs one turn through the `AgentProvider` Protocol (ADR-051; default `KiroAcpProvider`), streaming ACP messages
     into `run_events` (`agent.*` kinds).
5. `kiro-agent-sdk` (`genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py`) starts `kiro-cli acp …` as a
   subprocess with `env=os.environ.copy()` (`client.py:182-190`) — the worker's whole environment — and speaks ACP
   (JSON-RPC over stdin/stdout). `kiro-cli` then launches the stdio MCP servers itself.

### 2.2 The trust model on paper

ADR-029: effective tool trust = `node.tools ∩ server.allowlist`, "a hard cap". ADR-031/033/034: **chat** is read-only
and fail-closed. ADR-077: Genesis's own **role agents** are never run with `--trust-all-tools`. ADR-020: never rely on
the user's global Kiro configuration (no global `mcp.json`); MCP is injected per node.

### 2.3 Chat is different (and is not affected)

`genesis/genesis/chat/manager.py:132-146`: `trust_all_tools=False`, a `@server/tool` read-only trust list,
`permission_mode` from the profile — `auto_deny` for read-only modes, `ask` (a human confirms) for the copilot
(`chat/mode_profile.py:243-261`); writes only inside the per-session `fs_write_root`. Chat agents cannot run shell
commands unless the user confirms (copilot).

## 3. The problem in the code

### 3.1 Path 1 — `auto_approve` is the SDK default, and workflow nodes never change it

`KiroAgentOptions.permission_mode: str = "auto_approve"` (`client.py:53`). The policy comment (`:47-52`):
`auto_approve` "selects the requested allow option (autonomous mode)". The handler (`client.py:416-452`): for
`auto_approve` it "mirrors the requested allow option if present". `kiro_node` builds `opts_kwargs` without
`permission_mode` (`agent.py:288-301`). `kiro-cli` sends `session/request_permission` for any tool call that is not
pre-trusted (`messages.py:18-20`, "verified against kiro-cli 2.12.2"). **Result: a node with a trust list still gets
every other tool — the shell included — approved automatically.** The trust list only decides which calls skip the
request; it caps nothing.

### 3.2 Path 2 — a node with no tool list and no server allowlist trusts everything

`_compute_effective_trust` returns `None` ("trust all") when the node has no `tools=` and none of its servers has an
allowlist (`agent.py:157-158`); then `opts_kwargs["trust_all_tools"] = True` (`agent.py:299-300`), and the SDK adds
`--trust-all-tools` to `kiro-cli acp` (`client.py:167-170`). Every node with `mcp=[]` and no `tools=` takes this
path, e.g. `feature-breakdown-analysis` `plan_epics` (`workflows/feature-breakdown-analysis/graph.py:966`),
`story-design-analysis` `design` (`graph.py:604`), `technical-design-analysis` `plan_sections`/`draft_section`/
`synthesize`, `ux-design-analysis` `screen_inventory`/`spec_reconcile`/`synthesize`, `erd-generation`
`assign_domains`, `generate-business-map`, `memory-consolidation`, `memory-maintenance` — and `erd-generation`
`fetch_schema` (`mcp=["appian-atlas"]`, no `tools=`; its server's allowlist decides).

### 3.3 The process environment is inherited

`kiro-cli` gets the worker's environment, and so does every shell command the agent runs. The worker inherits the
`genesis serve` process environment, i.e. whatever the user's shell exported when Genesis was started (tokens such as
`GITLAB_TOKEN` if exported). MCP secrets are passed in the MCP entries' `env` lists, so they reach the MCP **child
processes**; whether the agent can read them depends on the process boundary (same user → `ps -E` / `/proc` style
reads are possible on macOS for one's own processes with the right tools).

### 3.4 The local Genesis API has no authentication

ADR-026: local, single-user, no auth; `genesis serve` refuses a non-loopback bind unless `--i-understand-no-auth`.
There is **no origin, CSRF or token check** on `/api` (searched `genesis/genesis/api/**`, 2026-11-02; the only header
check is the copilot control token on `POST /runs`, `run_routes.py:75-89`). There are **≈154 mutating routes**
(`@api.post|put|patch|delete` across `genesis/genesis/api/*.py`). Examples an agent shell could call with `curl
127.0.0.1:8760`:
- `POST /api/runs` (start any installed workflow), `POST /api/runs/{id}/respond` (answer a HITL gate),
  `/pause`, `/resume`, `/cancel`, `/fork`, `PATCH /api/runs/{id}/state` (`run_routes.py:74-166`);
- `POST /api/workbench/boards/{app}/cards/{story}/implementation/start` (an Implementation run that **writes to
  Dev**, `workbench.py:290`);
- `POST /api/config/secrets`, `POST /api/config/gitlab-token`, `POST /api/config/environments`
  (`config_routes.py:25-86`);
- `POST /api/config/native-cli/{id}/install` with a `binary_path` (install a binary as a managed CLI) and
  `POST /api/config/native-mcp/{id}/install` (`native_cli.py:28`, `native_mcp.py:26`).
The same gap also lets **any web page in the user's browser** POST to `127.0.0.1:8760` (classic local-server CSRF).

## 4. Evidence: what agents have actually done (run history, read-only, 2026-11-02)

Queried a read-only snapshot of `~/.genesis/genesis.db` (`sqlite3 "file:…?immutable=1"`), table `run_events`
(`kind = 'agent.tool_call'`, `payload.kind`). Queries are in §17.

- Tool calls by workflow agents: **2 772** — MCP tools 1 929, `edit` 461, `read` 220, **`execute` (shell) 153**,
  `search` 9.
- Shell calls per node:

| Workflow | Node | Shell calls |
|---|---|---:|
| technical-design-analysis | analyze_section (has a tool allowlist) | 26 |
| test-design-analysis | design_cases | 21 |
| feature-breakdown-analysis | break_epic | 19 |
| **story-implementation** | **implement** (writes to Dev) | **16** |
| erd-generation | assign_domains | 10 |
| story-design-analysis | research | 8 |
| test-design-analysis | heal | 7 |
| generate-business-map | synthesize_capabilities | 6 |
| story-design-analysis | synthesize | 6 |
| erd-generation | fetch_schema | 5 |
| story-design-analysis | design_object | 5 |
| generate-business-map | synthesize_value_streams | 4 |
| technical-design-analysis | synthesize | 4 |
| test-design-analysis | compose_scenarios | 4 |
| ux-design-analysis | live_grounding | 4 |
| ux-design-analysis | screen_inventory | 3 |
| feature-breakdown-analysis | verify | 1 |
| memory-consolidation | extract | 1 |
| story-implementation | author_wiki | 1 |
| technical-design-analysis | plan_sections | 1 |
| technical-design-analysis | verify | 1 |

- **Most calls are benign housekeeping**: `python3 -c "import json; json.load(open(...))"` to validate the agent's own
  output, `python3 -m json.tool`, `rm -f _tmp_*.txt`, `ls -la` of the run folder, a throwaway `build_enriched.py`.
- **12 calls go further** (matched on `curl`, `8760`, `secrets.json`, `TOKEN`, `PASSWORD`):
  - `erd-generation` `fetch_schema`: `echo "GITLAB_TOKEN set: ${GITLAB_TOKEN:+yes}"; … ls -la .env …` and `find` /
    `python3` reading `~/repo-gitlab/appian/solutions-os/ai-framework/tools/Atlas/solutions-kb/data/…` (the user's
    repos, outside the run folder);
  - `story-design-analysis` `design_object` and `story-implementation` `implement`: `curl -s
    https://docs.appian.com/suite/help/26.6/functions.json > /tmp/…` and follow-up page fetches (external network);
  - **`story-implementation` `implement`**: `env | grep -iE 'appian|lcp|mcp|host|url' | sed … REDACTED`;
    `nslookup` and `ping` of the Dev host; `curl --resolve <host>:443:13.248.199.165 …` (bypassing DNS);
    `sudo -n true … SUDO_OK|SUDO_NEEDS_PASSWORD`; `ls -l /etc/hosts; [ -w /etc/hosts ]`.
- Earlier (2026-07-11/13): two calls to a Playwright **MCP** tool `@playwright/browser_run_code_unsafe` by
  `erd-generation` `fetch_schema` — a server the node never declared, most likely loaded from the user's global Kiro
  configuration at the time (the global `~/.kiro/settings/mcp.json` lists `jira`, `testcase-mcp` today). See §9.2.

Nothing shows malicious intent: the agents were working around problems (a DNS failure, a missing file). That is the
point — an agent that hits an obstacle reaches for the shell, and nothing stops where it goes.

## 5. What an agent can reach today (the threat surface)

| Surface | Reachable from a workflow agent's shell? | Impact |
|---|---|---|
| `~/.genesis/secrets.json` (all secrets: GitLab token, Dev LCP creds, API keys) | Yes (same user) | Credential theft |
| `~/.genesis/genesis.db` (runs, chats, KB, stories), `memory.db` | Yes | Data theft / tampering |
| Local Genesis API `127.0.0.1:8760` (≈154 mutating routes, no auth) | Yes | Dev writes via Implementation runs, HITL gate answers, Settings/secrets changes, managed-binary installs |
| User files: repos, `~/.ssh`, `~/.aws`, `~/.kiro`, shell profiles | Yes | Theft, persistence (e.g. editing `~/.zshrc`, LaunchAgents) |
| Network: any host | Yes | Exfiltration, downloading and running tools |
| MCP child processes' environments (Dev / DevOps / Jira creds) | Plausibly (same user; to verify in the spike) | Credential theft |
| Kiro's own auth (CLI credential store) | Yes (same user) | Model-service misuse |
| Global tools on PATH (`apwt`, `gws`, `git`, `docker`, `sail`) | Yes | Anything those tools can do with the user's identity (e.g. `git push`, `docker run -v /:/host`) |
| Global Kiro config (`~/.kiro/settings/mcp.json`, steering, agents) | Read/write | Persistence across all Kiro sessions; undeclared MCP servers (§9.2) |
| Processes (`kill`, `launchctl`, `osascript`) | Yes | Disruption, persistence |

**Sources of untrusted content** the agents read: KB metadata and object names/descriptions synced from Appian; spec,
UX, Technical Design and design HTML (partly chat-authored); uploaded documents and PDFs; Google Workspace documents;
web pages fetched by agents; Jira tickets (code-review); and, from Phase 51, **live Appian page text** through
`apwt` snapshots. Any of these can carry instructions ("run this command"). With private data, untrusted content and
an exit all in one agent, one successful injection can read the secrets and send them out
([Simon Willison, the lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)).

## 6. Goals, non-goals, constraints

### 6.1 Goals
1. Agents keep **full shell access** and every tool they use today; existing workflows run unchanged (graphs,
   prompts, trust lists, outputs).
2. Nothing an agent does can read or change the user's environment or Genesis's own state outside its run folder.
3. The local Genesis API and every other host service are **unreachable** from an agent.
4. Network egress is limited to what each workflow needs (default deny + allow-list), and is logged.
5. **No secret is ever inside the isolated environment** (MCP credentials, Genesis secrets, Kiro refresh tokens).
6. The boundary is enforced by the OS/hypervisor, not by the agent's cooperation or the prompt.
7. Works on the supported machines (macOS on Apple silicon) with a clear prerequisite and a health check.
8. Cleans up completely on turn end, pause, cancel and crash (ADR-012 semantics).

### 6.2 Non-goals
- Multi-user / hosted Genesis (ADR-026's separate track).
- Changing the trust model of chat (already fail-closed).
- Making MCP tools themselves safer (an MCP write tool stays a write tool; the gates of ADR-021/068 still apply).
- Isolating **program** nodes (deterministic Genesis code; they run in the worker on the host as today).

### 6.3 Constraints (ADRs and lessons that must hold)
ADR-001 (LangGraph owns control flow), ADR-002/004/020 (narrow Kiro turns over ACP, per-node MCP, never the global
config), ADR-010/018/022 (small state; bulk in the run folder; artifacts root), ADR-012 (disposable workers; pause =
kill), ADR-024 (async engine, `AsyncSqliteSaver`), ADR-029 (trust intersection), ADR-051 (`AgentProvider` Protocol —
the natural seam), ADR-069 (skills provisioned into the run's `.kiro/skills/`), ADR-077 (never `--trust-all-tools`
for role agents), ADR-026 (local, loopback-only). Lessons: L-001 (ACP MCP env is a list), L-021 (bulk to files),
L-041/L-042 (cwd + file tools for authoring; context as files), L-044/L-087 (probe the installed CLI, not the docs),
L-088 (a bypass corpus that must stay blocked and a positive corpus that must pass), L-100 (never read CI variables;
treat a leaked value as leaked).

## 7. Options considered

| | Option | Keeps the shell | Host loopback blocked | Secrets out | Change size | Verdict |
|---|---|---|---|---|---|---|
| A | **Fail-closed nodes** (`auto_deny`, explicit trust lists, no `trust_all_tools`) | No | n/a (no shell) | Yes | Every workflow's trust list + live re-runs | Rejected by the user: changes working workflows; agents rely on the shell |
| B | **Kiro local command sandbox** (Seatbelt), turned on over ACP (`_kiro/sandbox/applyConfig`, per-run `KIRO_HOME` `permissions.yaml`) | Yes | **No** — the base profile always allows `localhost:*` (51-03 residual 1) | Files yes; env via launch env | Medium (V3 engine for all nodes; `--trust-tools` refused in V3 → client policy) | Proven but insufficient alone; usable as a second layer |
| C | **MCP-only access** (e.g. `appian-browser` for `apwt`) | No | n/a | Yes | One server per tool family | Fine for one tool; doesn't cover what agents do with the shell today |
| D | **Whole worker in a container** (LangGraph, Kiro, MCP servers, checkpointer all inside) | Yes | Yes | **No** — MCP creds and the DB move inside | Very large (DB access, MCP bundles, paths) | Rejected |
| **E** | **Per-turn Kiro-in-a-box**: only the `kiro-cli acp` process (and the commands it runs) in a disposable container/VM; worker, DB, secrets and MCP servers stay on the host; MCP reached through a host-side gateway | **Yes** | **Yes** (own network namespace) | **Yes** (gateway + client auth) | Medium-large, contained behind `AgentProvider` | **Proposed** |
| F | **Separate macOS user account** for agents | Yes | No (shared loopback) | Partly | Medium; awkward file sharing | Rejected: loopback and same-machine services stay reachable |
| G | Local API token only (Jupyter pattern) | Yes | Mitigates the API only | No | Small | Keep as defence in depth (§9.1), not a boundary |

## 8. The proposed solution (option E) in detail

### 8.1 Shape

```
host (macOS)                                                     isolated box (Linux, one per agent turn)
──────────────────────────────────────────────                   ─────────────────────────────────────────
genesis serve ─ RunManager ─ supervisor ─ worker (LangGraph)      kiro-cli acp --auth-method client
                                   │  AgentProvider (ADR-051)        │  shell commands, file tools
                                   │  IsolatedKiroProvider ──stdio──►│  (the agent's whole world)
                                   │     (ACP over the box's stdio)  │
   secrets, genesis.db, ~/.genesis │                                 │  /run  = the run folder (rw, only mount)
   MCP servers (stdio, with creds) │◄──── MCP gateway (HTTP) ◄───────┤  MCP tools via http://gateway/<node-token>
   blackboard MCP                  │                                 │
   egress proxy (allow-list) ◄─────┼─────────────────────────────────┤  all outbound traffic → proxy
   Kiro token broker ◄─────────────┼── ACP auth requests ────────────┤  (no refresh token inside)
```

### 8.2 Where the boundary sits and why

Only the agent's **Kiro process** goes in the box, per agent turn. The worker keeps everything that needs Genesis
state or secrets. This is the narrowest boundary that still contains everything an agent can execute (the shell and
its children, file tools, Kiro's own process), and it plugs in at one seam: the `AgentProvider` Protocol (ADR-051,
`KiroAcpProvider` today). Graphs call `kiro_node` exactly as now; the provider decides whether the turn runs locally
or in a box.

### 8.3 Components

1. **`IsolatedKiroProvider`** (genesis-core, an `AgentProvider`): for one turn it (a) prepares the box spec (image,
   mounts, network, env, limits), (b) starts the box with `kiro-cli acp --auth-method client [--agent-engine …]` as its
   entrypoint and attaches to the box's stdin/stdout, (c) runs the normal `kiro-agent-sdk` client over that stream
   (ACP is transport-agnostic JSON-RPC), (d) rewrites MCP entries from stdio launches into **HTTP MCP entries** that
   point at the gateway (§8.6), (e) answers Kiro's access-token requests (§8.7), (f) tears the box down on turn end,
   timeout, pause or cancel, and records the box id in the run's pid/box registry for the startup sweep.
2. **Box runtime adapter**: one interface, two implementations — **Apple `container`** (macOS 26+, Apple silicon,
   each container its own lightweight VM, no shared daemon; [apple/container](https://github.com/apple/container)) and
   **Colima/Docker** (Lima VM, shared). Detection and health in preflight and Settings. The user's machine has macOS
   26.7.1, arm64, `docker`, `colima`, `limactl` installed (checked 2026-11-02); Apple `container` is not installed.
3. **The agent image** (`genesis-agent:<version>`, built from a Dockerfile in the genesis repo, versioned with the
   genesis tag): Linux arm64; `kiro-cli` for Linux; Python 3.13 with the packages agents use in the shell today (json,
   stdlib; anything else found in the §4 history); `jq`, `git` (no credentials), `curl`, `ripgrep`; Node 20 + npm;
   for Phase 51, `playwright-appian` + `@playwright/test` 1.59.1 + Playwright Chromium and its Linux deps (Playwright's
   own images are the reference). No secrets, no SSH keys, no Genesis code beyond what a turn needs. Built locally from
   the repo or pulled from the project's registry (decision §13).
4. **Mounts**: the run folder only, read-write, **at the same absolute path** as on the host (prompts and state hold
   absolute paths, ADR-010 pointers; mounting at the same path avoids rewriting). Optional read-only mounts for
   shared, non-secret inputs (e.g. a Phase 51 workspace export already lives inside the run folder). Nothing from
   `$HOME`, `~/.genesis`, `~/.kiro`, the repos or sockets.
5. **Network**: the box has its own network namespace — host loopback does not exist inside it, so
   `127.0.0.1:8760` is the box's own (empty) loopback. Outbound traffic is only allowed to the **egress proxy** on the
   host (HTTP(S) CONNECT with SNI/host allow-list, DNS through the proxy or a filtered resolver). Allow-lists per node:
   Kiro's model/auth endpoints always; the hosts a workflow declares (e.g. `docs.appian.com`, the Dev host for nodes
   whose MCP tools need it — but MCP traffic goes through the gateway, not direct); for Phase 51 browser agents, the
   QA host. Every egress attempt is logged per run.
6. **MCP gateway** (host): the worker starts the node's stdio MCP servers on the host as today (with their
   credentials) and exposes them to the box over **Streamable HTTP** at a per-turn URL with a random bearer token,
   reachable only from that box (bound to the box network / a per-box port). The gateway enforces the node's tool
   allowlist (ADR-029 intersection) **server-side**, logs every call into `run_events`, and stops with the turn. The
   blackboard MCP goes through it the same way. ACP lets a client pass HTTP MCP servers in `session/new` when the
   agent advertises the capability (`McpServerHttp`/`McpServerSse`; [ACP session setup](https://agentclientprotocol.com/protocol/session-setup));
   whether `kiro-cli acp` accepts them is a spike question (P3).
7. **Kiro authentication**: `kiro-cli acp --auth-method client` "forwards the v3 engine's access-token requests to the
   ACP client" (`kiro-cli acp --help`, 2.37.1). The provider answers with short-lived access tokens obtained on the
   host from the user's Kiro login; the refresh token never enters the box. If that mode is V3-only, the box runs the
   V3 engine (51-03 showed V3 works over ACP; note V3 rejects `--trust-tools`, so trust lists become a client policy
   or are irrelevant inside the box — §13 Q6).
8. **Environment**: a fixed minimal env inside the box (`HOME=/home/agent`, `PATH`, `LANG`, `TMPDIR`, the proxy vars,
   `PLAYWRIGHT_BROWSERS_PATH`); nothing inherited from the worker.
9. **Limits**: CPU/memory caps, a wall-clock limit = the node's `turn_timeout` + margin, no privileged mode, a non-root
   user, read-only root filesystem except the run folder and `/tmp`.
10. **Lifecycle**: one box per turn (`--rm`); start latency budget measured in the spike (Apple `container` VMs boot
    in about a second per its docs/reviews); an optional warm pool later. Pause/cancel kills the box with the worker;
    a startup sweep removes boxes whose run is not active (holding the run-owner lock, L-097).

### 8.4 What changes for existing workflows

Nothing in `workflows/**`. A node's shell commands run in the box against the same run folder; output files land in
the same place. Behaviour that **will** stop working, by design: reading files outside the run folder (the
`erd-generation` repo search), `env` showing host variables, reaching any host not on the allow-list (e.g.
`docs.appian.com` unless declared), `sudo`, writing `/etc/hosts`, calling the local Genesis API, using the user's
global tools/config. The spike lists each recorded command from §4 with its expected result inside the box; workflows
that need a host (docs.appian.com) declare it.

### 8.5 Configuration and declarations

- Workflow `META` (additive, `CORE_MAJOR` unchanged, ADR-019): optional `egress: [hosts]` per workflow or per node;
  validated by the library CI (genesis-workflows gates).
- Settings → a new **Agent runtime** card: runtime detected (Apple `container` / Colima / none), image version and
  status (build/pull), last health check, and a mode switch (§13 Q2: isolated required / isolated preferred /
  host — the latter only with an explicit warning).
- Every agent turn records `runtime: isolated|host`, the box id and the egress summary in its telemetry and the run's
  turn explorer (ADR-066).

### 8.6 MCP gateway details

- Transport: MCP Streamable HTTP (SSE is deprecated in the MCP spec;
  [MCP transports](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports)).
- One gateway process per worker; one route per (turn, server); bearer token per turn; the box reaches it at a host
  address that only exists on the box network.
- Tool filtering at the gateway (the ADR-029 cap becomes real), call logging, result size limits (the blackboard /
  `save_tool_output` pattern stays, L-021).
- Fallback if Kiro cannot use HTTP MCP: a tiny stdio→HTTP bridge inside the box that forwards to the gateway (the
  credentials still stay on the host).

### 8.7 Kiro auth details

- Preferred: `--auth-method client`; the provider holds a host-side token broker that reads the user's Kiro
  credential store (as `kiro-cli` does) and returns access tokens on request.
- Alternatives if not workable: a scoped, short-lived token mounted per turn; or a dedicated Kiro login inside a
  persistent image volume (the agent could read it — weaker).

### 8.8 Phase 51 inside the box

Browser agents run `apwt` from the run's workspace copy with Playwright Chromium inside the box; egress allow-list =
the QA host; sessions opened and logged in by program code on the host cannot be attached across the boundary unless
the browser also runs in the box — so for isolated turns the **login happens inside the box** through a gateway call
or a one-time credential handoff that the agent cannot read (open question §13 Q9). Human recording (headed browser)
stays on the host.

## 9. Defence in depth (independent of the box; each can ship on its own)

1. **Local API token** (an ADR-026 amendment, the Jupyter pattern): `genesis up` generates a per-launch token, stores
   it in `~/.genesis/run/` (0600), opens the UI with the token in the URL fragment; the SPA sends it as a header; the
   API refuses mutating requests without it (and checks `Origin`/`Host`). Closes the browser-CSRF gap and any
   same-machine caller that is not Genesis's own UI, boxed or not. Needs care for the reviewer/live-acceptance drivers
   and the CLI.
2. **Global Kiro configuration (ADR-020)**: verify whether `kiro-cli acp` loads `~/.kiro/settings/mcp.json` (and
   global steering/agents) into Genesis workflow sessions; the July Playwright-MCP calls suggest it did. If it does,
   start host-side turns with a clean `KIRO_HOME` (51-03 showed `KIRO_HOME` relocates the config home without
   breaking auth) and the box never sees the user's `~/.kiro`.
3. **Make the permission mode explicit** in `kiro_node` (still `auto_approve` if that is the decision) so the
   behaviour is visible in code and in the turn telemetry, and a future fail-closed node is one flag away.
4. **Start Kiro with a clean environment** on the host path too (an `env=` option in `kiro-agent-sdk`; 51-03 S5
   proved Kiro authenticates with `HOME, USER, LOGNAME, SHELL, TMPDIR, LANG, LC_ALL, TERM, PATH`).
5. **Secrets at rest**: `~/.genesis/secrets.json` is plaintext 0600 (`PlaintextProvider`, ADR-013); a Keychain-backed
   provider is a separate improvement.
6. **Audit view**: a per-run list of every shell command and egress attempt (already partly in `run_events`).

## 10. Requirements (testable)

| # | Requirement |
|---|---|
| R1 | Every agent turn of every workflow runs in a box when the isolated mode is on; no code path starts `kiro-cli` on the host in that mode |
| R2 | Inside the box, only the run folder (rw) and `/tmp` are writable; nothing under the host `$HOME` is visible |
| R3 | Host loopback services (`127.0.0.1:8760`, the `apwt` daemons, any other local port) are unreachable from the box |
| R4 | Egress is denied except to the proxy; the proxy allows only the node's declared hosts + Kiro's endpoints; every attempt is logged |
| R5 | No secret value appears in the box (env, files, process list, MCP traffic) — checked by a canary secret |
| R6 | MCP tools work through the gateway with the node's allowlist enforced server-side; a call outside it is refused and logged |
| R7 | Kiro authenticates without a refresh token in the box |
| R8 | Skills in `<run>/.kiro/skills/` are discovered (ADR-069); the blackboard tools work |
| R9 | Pause/cancel/timeout/crash leave no box running; startup sweep cleans leftovers |
| R10 | Existing workflows pass their tests and a live run each, with outputs equal in kind to host runs |
| R11 | Turn start overhead ≤ an agreed budget (measured in the spike; e.g. ≤ 3 s per turn) |
| R12 | A bypass corpus (§11 P8) stays blocked and a positive corpus (the §4 benign commands) passes (L-088) |
| R13 | Clear prerequisite detection and UX when no runtime is available |

## 11. Spike plan (the first sub-spec, 52-02)

| # | Question | Pass |
|---|---|---|
| P1 | Runtime choice: Apple `container` vs Colima/Docker on macOS 26 arm64 — install, start, `--rm`, mounts at the same path, non-root, resource limits, start latency | One chosen with numbers |
| P2 | `kiro-cli` for Linux arm64 runs `acp` in the box over the box's stdin/stdout, driven by `kiro-agent-sdk` from the host | A turn completes |
| P3 | HTTP MCP: does `kiro-cli acp` accept HTTP MCP servers in `session/new` (agent capabilities)? If not, the stdio→HTTP bridge | A gateway-served tool call succeeds |
| P4 | Auth: `--auth-method client` — which engine, what the requests look like, how the host broker answers; no refresh token in the box | Turn completes; scan finds no refresh token |
| P5 | Network: box loopback ≠ host loopback; `127.0.0.1:8760` unreachable; egress proxy allow-list (CONNECT + DNS) works for Kiro's endpoints and one allowed host; everything else denied | Probes recorded |
| P6 | Skills + blackboard + the run folder at the same absolute path | Skill activated; blackboard save works |
| P7 | The §4 benign commands (python3 JSON checks, rm of temp files) behave the same | All pass |
| P8 | Bypass corpus: read `secrets.json`/`genesis.db`/`~/.ssh`; write outside the run folder; curl the Genesis API, the Dev host, a public host; read MCP server env; persist a background process past the turn; escape via mounted sockets | All blocked |
| P9 | Playwright Chromium + `apwt` inside the box against a QA host on the allow-list (for Phase 51) | `open`/`snapshot`/`expect` + a spec replay pass |
| P10 | Global Kiro config: does the host path load `~/.kiro/settings/mcp.json` into workflow sessions? | Answered with evidence |

## 12. Interaction with Phase 51

Phase 51 continues in parallel. Its interim choice for agent access to `apwt` is recorded in
`specs/phase-51-test-execution-engine/51-01-findings.md` (D3c, 2026-11-02). Whatever Phase 51 ships, its browser
agents become ordinary boxed turns once Phase 52 lands: the box image carries `playwright-appian` + Chromium, the
egress allow-list carries the QA host, and the login question (§8.8) is answered here. Phase 51's D3b MCP server is not
required in the boxed world.

## 13. Open questions for the Phase 52 Q&A (one at a time)

| # | Question |
|---|---|
| Q1 | Boundary: per-turn Kiro-in-a-box (E) as proposed, or per-run box shared by all of a run's turns (faster, weaker isolation between nodes)? |
| Q2 | Mode when no runtime is installed: refuse agent runs, or run on the host with a visible warning? Default for existing installs? |
| Q3 | Runtime: Apple `container` (VM per container, macOS 26+, Apple silicon only) as the default, Colima/Docker as fallback — or one only? |
| Q4 | Image source: built locally from the genesis repo on first use, or pulled from the GitLab registry (versioned with the genesis tag)? |
| Q5 | Egress policy: per-workflow or per-node `egress` declarations; default set (Kiro endpoints only?); what about `docs.appian.com`? |
| Q6 | Inside the box, keep the node trust lists (as a client policy) or drop them (the box is the boundary)? |
| Q7 | MCP gateway placement and auth (per-turn tokens) — and do all MCP servers go through it, including the blackboard? |
| Q8 | Ship the §9 defence-in-depth items in this phase (API token, global config check, explicit permission mode, clean env), or separately? |
| Q9 | Phase 51 browser login inside the box: gateway-mediated login, or credentials handed to a box-internal process the agent cannot read? |
| Q10 | Rollout: opt-in per workflow → default on → host mode removed? Which release? |
| Q11 | Resource limits and timeouts per box; concurrency (one box per active agent turn; with F7 of Phase 51, one test execution at a time) |
| Q12 | Do Genesis's own role agents (`genesis-dev` etc., Kiro CLI on the host) need the same? (Out of scope by default: ADR-077 governs them.) |

## 14. Decisions

*(Recorded by the Phase 52 spec agent during its Q&A, one row each, with the reason.)*

| # | Decision | Reason |
|---|---|---|

## 15. Proposed ADRs

- **ADR-0xx — Workflow agent turns run in an isolated box.** Every workflow agent turn's Kiro process runs in a
  disposable isolated environment with only the run folder mounted, its own network namespace, egress through a
  host-side allow-list proxy, MCP tools through a host-side gateway, and no secrets inside; the worker, the
  checkpointer, `genesis.db`, secrets and MCP servers stay on the host. Amends ADR-012 (where agent execution happens),
  ADR-029 (the cap enforced at the gateway), ADR-051 (a new provider).
- **ADR-0xx — Local API token** (if §9.1 is taken in this phase). Amends ADR-026.

## 16. Risks

| Risk | Mitigation |
|---|---|
| `kiro-cli` on Linux or HTTP MCP or client auth doesn't work over ACP | Spike P2–P4 first; fallbacks in §8.6/§8.7 |
| Turn latency grows (box start per turn) | Measure (P1); Apple `container` fast boot; warm pool later |
| Workflows that silently relied on host files/hosts break | §8.4 list; spike P7 replays the recorded commands; egress declarations; per-workflow opt-in rollout |
| Runtime not installed on a user's machine | Detection, Settings card, Q2 mode |
| Box escape via a misconfigured mount or socket | No host mounts but the run folder; corpus P8; non-root; read-only root fs |
| The image drifts from what agents need | Versioned image; CI builds it; a health turn in preflight |
| Kiro's Linux build or ACP behaviour changes | Pin the `kiro-cli` version in the image; L-044 probe on upgrade |
| Debuggability | Keep box logs; turn explorer shows runtime + egress |

## 17. Evidence appendix

- Code: `client.py:47-53, 167-170, 182-190, 416-452`; `agent.py:78-113, 137-166, 195-301`; `registry.py:115-140`;
  `tool_store.py:27`; `chat/manager.py:132-146`; `chat/mode_profile.py:243-261`; `api/run_routes.py:74-166`;
  `api/config_routes.py:25-86`; `api/native_cli.py:28`; `api/native_mcp.py:26`; `api/workbench.py:290`.
- Run-history queries (read-only snapshot):
  - `SELECT json_extract(payload,'$.kind'), COUNT(*) FROM run_events WHERE kind='agent.tool_call' GROUP BY 1`
  - `SELECT r.workflow_id, e.node, COUNT(*) FROM run_events e JOIN runs r ON r.run_id=e.run_id WHERE e.kind='agent.tool_call' AND json_extract(e.payload,'$.kind')='execute' GROUP BY 1,2`
  - the 12 notable calls: the same with `payload LIKE '%curl%' OR '%8760%' OR '%secrets.json%' OR '%TOKEN%' OR '%PASSWORD%'`
- Spike 51-03 (sandbox): As built in `specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md`; evidence
  under `genesis/scripts/spikes/51-03/evidence/` (`s1-file.json`, `s1-rpc.json`, `s6-seatbelt-profile.sb`,
  `s6-os-corpus.txt`, `s6-net-qa.json`, `bypass-nosandbox.json`, `bypass-sandbox.json`).
- `kiro-cli acp --help` (2.37.1): `--agent-engine v1|v2|v3` (v2 default), `--auth-method cli|client`,
  `--trust-tools`, `--trust-all-tools`.
- Machine (2026-11-02): macOS 26.7.1 (25G241), arm64; `docker`, `colima`, `limactl` on PATH; no Apple `container`.
- Research: [lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/); [Codex sandbox and
  approvals](https://developers.openai.com/codex/sandbox) (OS sandbox locally, isolated containers in the cloud,
  network off by default, setup-phase secrets removed before the agent phase); [agentcage](https://github.com/agentcage/agentcage)
  (container + filtering egress proxy + no real keys); [disposable VMs/containers for agents](https://startdebugging.net/2026/09/run-coding-agents-in-disposable-vms-and-containers/);
  [apple/container](https://github.com/apple/container); [ACP session setup](https://agentclientprotocol.com/protocol/session-setup);
  [MCP transports](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports). Content was rephrased
  for compliance with licensing restrictions.

## Context manifest

```toml
areas    = ["core-engine", "sdk-acp", "runs-worker", "security", "distribution"]
adrs     = ["ADR-002", "ADR-004", "ADR-010", "ADR-012", "ADR-020", "ADR-022", "ADR-026", "ADR-029", "ADR-031", "ADR-051", "ADR-069", "ADR-077"]
lessons  = ["L-001", "L-017", "L-021", "L-041", "L-044", "L-087", "L-088", "L-097", "L-100"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/packages/genesis-core/genesis_core/mcp/registry.py", "genesis/genesis/runs/supervisor.py", "genesis/genesis/runs/worker.py", "genesis/genesis/api/run_routes.py"]
upstream = []
```
