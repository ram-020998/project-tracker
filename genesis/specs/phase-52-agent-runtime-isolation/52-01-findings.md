# 52-01 — Findings: agent runtime isolation (the problem, the evidence, the solution)

> **Status:** Q&A IN PROGRESS (research session started 2026-11-02; decisions in §14, research in §18).
> Originally a BRIEF written 2026-11-02 by the genesis-spec agent, before the Phase 52 Q&A. It is the starting
> point for the Phase 52 spec set (umbrella `specs/phase-52-agent-runtime-isolation.md` and sub-specs, not written yet).
> The Phase 52 spec agent runs the Q&A against §13, records decisions in §14, then writes the spec set.
> Origin: Phase 51 (test execution engine), spike 51-03 and the follow-up checks of 2026-11-02 —
> `specs/phase-51-test-execution-engine/51-01-findings.md` D3, D3a, D3b and §2.3, and the 51-03 As built.
> Built **in parallel** with Phase 51, by a separate agent session (user's direction, 2026-11-02).

---

## 0. Summary in one page

> **Decided approach (Q&A, 2026-11-02; details and reasons in §14 D1–D17, research in §18):** Genesis runs entirely
> in containers inside a Genesis-owned Linux VM (Colima on macOS and Linux, a WSL2 distribution on Windows), set up
> by a small `uv`-installed launcher and updated by pulling CI-built images. Each agent turn (and each chat session)
> runs in its own hardened sandbox container beside the app container, holding only its run folder, with no secrets,
> egress through a default-deny host-name proxy, MCP tools through a gateway in the app container that enforces each
> node's allowlist, and Kiro tokens from a broker (V3 engine, `--auth-method client`). The API gets a per-launch
> token. Data lives in VM volumes with backup/restore. One phase, two releases: macOS first, then Linux and Windows.
> The original brief below is kept as the problem statement and evidence; where it proposes otherwise, §14 wins.

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

> **Superseded where it differs (2026-11-02 Q&A):** Genesis itself moves into a container too, so the "host" side
> below becomes the app container inside a Genesis-owned VM (§14 D1–D17). The components (provider, gateway, proxy,
> token broker, image, mounts, limits) keep their roles; §14 is the authority.

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
| D1 | **Everything moves into containers (2026-11-02, user).** Genesis itself (app, workers, LangGraph, checkpointer, `genesis.db`, secrets, MCP servers, managed tools, all prerequisites) runs in a Genesis-owned **app container** from one versioned image, inside a **Genesis-owned Linux VM** (not the user's own Docker VM). Agent turns run in **separate sandbox containers alongside it in the same VM** (siblings, not Docker-in-Docker), created from a fixed template by a small controller; the sandboxes get no Docker socket. The brief's option E (Genesis on the host, only Kiro boxed) is replaced. | The user wants a clean, reproducible environment with every prerequisite installed by the image instead of on the Mac, and agents that cannot touch the user's environment. With Genesis inside the VM, the proxy, the MCP gateway and the sandboxes share one private network, which is simpler than bridging host and VM. Sibling containers created by a controller are the standard shape (OpenHands, Kubernetes `agent-sandbox`); real nesting needs privileged mode and weakens the outer box (§18.3). Costs accepted for the spec to solve: the Mac-coupled features in §18.4. |
| D2 | **On macOS the VM is a Genesis-owned Colima instance (2026-11-02, user).** Genesis installs Colima at a pinned version and owns a dedicated profile (not the user's `default`), configured with no home-folder mount, fixed CPU/memory, `vmType: vz`, and the Mac-loopback block (`networkOpts.hostLoopback: false`) once the pinned Lima supports it (spike). Genesis talks to the engine only through the standard Docker API, so Docker Desktop / OrbStack / a hosted backend can be added later behind the same interface. | Free and open source (MIT); already installed; a thin layer over Lima. Docker Desktop and OrbStack need paid seats at Appian's size; Apple `container` runs each container as its own VM on the Mac, so the app container could not create sandboxes from inside the VM (breaks D1); Podman's Compose support is rougher (§18.5). |
| D3 | **Genesis must run on macOS, Windows and Linux (2026-11-02, user).** Everything inside the VM is identical on every OS: the app image and the sandbox image are Linux, built for both `arm64` and `amd64`. Only the layer that provides the Genesis-owned VM and its Docker engine differs per OS (an "environment provider": Colima on macOS per D2; Linux and Windows per D4). | Moving Genesis into containers (D1) is what makes this practical: Kiro CLI ships for Linux on x86_64 and ARM64 (glibc 2.34+), so the host OS no longer matters to the app. Today Genesis is macOS-only (ADR-046 install path, `xattr`, the launcher), so this amends ADR-046. |
| D4 | **Linux and Windows environment providers (2026-11-02, user).** Linux: a Genesis-owned Colima VM (QEMU/KVM), not Docker directly on the host. Windows: a Genesis-owned WSL2 distribution (`genesis`) running Docker Engine, with `C:\` automount and Windows interop switched off in its `/etc/wsl.conf`. Linux and Windows need a real test machine for the spike and acceptance (the spec session's machine is a Mac). | Linux: Docker on the host would make agent containers share the user's real kernel and make the controller root on the user's computer; a VM keeps the same boundary as macOS and one setup. Windows: WSL2 is what Docker Desktop, Rancher Desktop and Podman all use; WSL2 distributions share one kernel, accepted because the agent sandboxes sit on their own private network inside it. Prerequisites: KVM (nested virtualization when the Linux host is itself a VM); WSL2/Hyper-V allowed by IT policy. |
| D5 | **Agent sandboxes are hardened ordinary containers for now (2026-11-02, user).** Standard Docker runtime (`runc`) with: a non-root user, all Linux capabilities dropped, `no-new-privileges`, Docker's default seccomp profile, a read-only root filesystem (writable: the run folder and `/tmp` only), no Docker socket, no host mounts, CPU/memory/process limits, and a private internal network (proxy and MCP gateway only). The runtime is a field of the sandbox template, so gVisor (`runsc`) or a microVM runtime can be switched on later without other changes. | User's choice: simplest and fastest, and works on every OS and chip. **Residual risk accepted:** the sandboxes share the VM's Linux kernel with the app container, so an agent that exploits a kernel bug could reach the app container's secrets and `genesis.db`. Considered: gVisor (works on every OS, slower I/O, some compatibility work) and a microVM per sandbox (needs nested virtualization: M3+ Macs only). Keep the VM's kernel patched (it ships with the pinned Colima/WSL2 image). |
| D6 | **One sandbox per agent turn; one per chat session for chat (2026-11-02, user).** A fresh sandbox is created for each `kiro_node` turn and deleted when the turn ends (completion, timeout, pause, cancel or crash); a chat session gets one sandbox for its lifetime. A paused run holds no sandbox (ADR-012 semantics). Resource controls, all settings with defaults chosen from the spike's measurements: the VM's CPU/memory/disk size (the hard ceiling for the host), per-sandbox CPU/memory/process limits, a **concurrency cap** in the controller (extra turns queue), reserved memory for the app container so a sandbox is stopped first under pressure, size-capped container logs, and a startup sweep that removes leftover sandboxes (holding the run-owner lock, L-097). A warm pool of pre-started, never-used sandboxes may be added later without changing the model. | No state (processes, `/tmp`, installed packages) carries over between nodes except the run folder; Genesis already starts a fresh `kiro-cli acp` per turn, so a container per turn adds little (≈1 s expected, measured in the spike). Sandboxes exist only while an agent works, so a run waiting at a gate for days holds none. User asked about load on the host: the VM size bounds it; today agent turns run on the host with no limits at all. Considered: per run (leftovers leak between nodes; a paused run would hold a live box) and a long-lived pool (runs leak into each other). |
| D7 | **All MCP servers run behind an MCP gateway in the app container (2026-11-02, user).** The gateway starts the node's MCP servers on the trusted side with their credentials, exactly as today (stdio, `env` as a list, L-001), and exposes them to the sandbox over MCP Streamable HTTP at a per-turn address with a random per-turn token, reachable only from the sandbox network and revoked when the turn ends. The gateway enforces the node's ADR-029 cap (`node.tools ∩ server.allowlist`) as a real hard limit (a call outside it is refused and logged), logs every call into `run_events`, and keeps the save-to-blackboard pattern for large results (L-021). The blackboard MCP goes through the gateway too. If `kiro-cli acp` does not accept HTTP MCP servers in `session/new` (spike P3), the fallback is a small stdio relay inside the sandbox that Kiro launches as an ordinary MCP server and that forwards every call to the gateway. | No MCP credential ever enters the sandbox, in either variant. Today the trust list only decides which calls skip the approval prompt (§3.1); at the gateway the cap becomes enforceable. One path for all tools. The same shape as Docker Sandboxes' host-side MCP gateway and KiroCrew's in-process gateway (§18.1–18.2). MCP servers that read the run folder still work: the app container sees the same run folder. |
| D8 | **Kiro auth through a token broker in the app container (2026-11-02, user).** The user signs in to Kiro once, inside the app container (Genesis's existing in-app device-code sign-in, `genesis/runtime/kiro_auth.py`); the login lives on the app container's persistent volume. Sandboxed turns start `kiro-cli-chat acp --agent-engine v3 --auth-method client` directly (not the `kiro-cli` launcher, which checks its own login first), with no `KIRO_API_KEY` in the sandbox env (it would take precedence over the callback). The engine's `_kiro/auth/getAccessToken` requests reach Genesis's ACP client, which answers with a short-lived access token (`expiresAt` > now + 3 min) and never the refresh token. Token source, chosen by the spike: (a) read and refresh the `kiro-cli` login stored in the app container, else (b) Genesis performs the Kiro OIDC login and refresh itself (KiroCrew's documented contract). Fallback only with the user's explicit OK: copy the login into the sandbox (the agent could then read the refresh token). | A stolen access token expires within hours; a refresh token gives lasting use of the user's account and credits. `--auth-method client` exists in the installed `kiro-cli` 2.37.1 and applies to the V3 engine only (`kiro-cli acp --help`). Evidence for the launcher and API-key points: KiroCrew `docs/system-specs/modules/kas-auth.md` (measured on kiro-cli 2.25.0) and `src/kiro_crew/acp/kas_host_auth.py`. **Consequences for the spike:** V3 for every sandboxed turn (Genesis uses V2 today; 51-03 showed V3 works over ACP; V3 rejects `--trust-tools`, see the next decision), and V3 must still report metered credits per turn (ADR-032). |
| D9 | **Inside the sandbox, Kiro's built-in tools (shell, file read/write, web fetch) are all approved (2026-11-02, user).** `kiro_node` sets `permission_mode="auto_approve"` explicitly instead of relying on the SDK default (brief §9.3), and each turn's telemetry records that it ran sandboxed with auto-approve. Node trust lists keep their meaning for MCP tools only (enforced at the gateway, D7); for built-ins they no longer apply. Every shell command and file write stays recorded in `run_events`; the proxy adds egress attempts (brief §9.6). **Chat is unchanged:** read-only and fail-closed (ADR-031/033: `auto_deny`, or human-confirm for the copilot), now also inside its own sandbox (D6). | The sandbox is the boundary (run folder and `/tmp` only, egress through the proxy, no secrets), the same position Docker Sandboxes takes (its FAQ: the isolation layers replace approval prompts). Enforcing trust lists for built-ins would break working nodes (e.g. `technical-design-analysis` `analyze_section` has a trust list and ran 26 shell commands, §4), and V3 rejects `--trust-tools` (D8). Today trust lists do not restrict built-ins anyway (§3.1). Considered: a Genesis-owned command deny check (KiroCrew's pattern); rejected as easy to get around and of little value with nothing secret in the box. |
| D10 | **Sandbox egress: default deny, filtered by host name, three allow-list layers (2026-11-02, user).** The sandbox network has no route out except the egress proxy and no DNS of its own (the proxy resolves names, which also closes DNS as an exfiltration path); a tool that ignores the proxy fails. The proxy filters by host name (HTTP `Host` / CONNECT target / TLS SNI), without decrypting HTTPS (method- or path-level rules would need TLS interception: later, if ever). Every attempt, allowed or blocked, is logged per run and shown in Run Detail. Layers: (1) **base**, always on: Kiro's service endpoints only (exact list from the spike's proxy logs); (2) **per workflow, optionally per node**: a new optional `META.egress` list (e.g. `docs.appian.com` for `story-design-analysis` and `story-implementation`, the QA host for Phase 51 test runs), validated by the genesis-workflows CI, additive so `CORE_MAJOR` is unchanged (ADR-019); (3) **user additions** in Settings, shown with a warning and logged. Not allowed by default: the Appian Dev host (agents reach Dev only through the MCP gateway, D7), package registries (PyPI, npm) and code hosts (GitHub): any allowed host is an upload path with an attacker's own token. The app container (trusted) keeps normal network access (GitLab, Appian, Google, the Hub, Kiro). | Breaks the "way out" leg of the lethal trifecta (§5). Host-name allow-lists are the common practice (Claude Code devcontainer firewall, GitHub Copilot's agent firewall, Docker Sandboxes; §18.2). The sandbox image carries the tools agents need, so registries are not needed at run time; a workflow that does need one declares it. The recorded `curl --resolve` to the Dev host and the `docs.appian.com` fetches (§4) are the expected blocked and declared cases. |
| D11 | **Genesis's data lives in Docker volumes inside the VM (2026-11-02, user).** Volumes hold `genesis.db`, `memory.db`, secrets, the Kiro login (D8), managed MCP/CLI installs, skills and run artifacts; the app container mounts them. Ways in and out: (1) **backup and restore**: `genesis backup` and a Settings button write one archive (consistent SQLite copies, secrets, Kiro login, artifacts) to a folder the user picks on the host, a matching restore, optionally a scheduled daily backup; (2) **artifact export**: run artifacts downloadable from the UI plus an "Export run folder" action; (3) **one-time import** on first start of the existing `~/.genesis/` and `~/Genesis/runs/` (DB at m0025), originals left untouched. Each sandbox mounts only its own run's subfolder of the artifacts volume (Docker `volume-subpath` mount, Docker ≥ 26), at the same absolute path the app container uses, so absolute paths in prompts and state keep working (ADR-010). | Fast and safe for SQLite (its locking is unreliable on host-shared folders, worst on Windows); secrets stop being a plain file any host program can read; identical on all three OSes; keeps D2's no-home-mount and D4's no-`C:\`-mount. Cost accepted: data is not visible in Finder/Explorer and is lost with the VM unless backed up, hence backup/restore. Considered: a host folder shared into the VM (visible, survives VM rebuild, but slower, SQLite-unsafe, and weakens the VM boundary). |
| D12 | **Images are built by CI and pulled from the GitLab container registry (2026-11-02, user).** On every genesis tag, CI builds the app image and the sandbox image for `arm64` and `amd64` and pushes them as `registry.gitlab.appian-stratus.com/ramaswamy.u/genesis/app:<tag>` and `…/sandbox:<tag>`. Update = pull the new tag's images and recreate the containers; data volumes stay (D11); DB migrations run on app start (as `genesis db upgrade` does today). An automatic backup (D11) is taken before every update, because migrations are forward-only; rollback = the previous tag plus that backup. The in-app update banner stays and triggers an image update instead of a git checkout. Registry access: on first install, the VM's Docker signs in with a GitLab personal access token with `read_registry` scope only, stored in the VM, not in Genesis's secrets. The Kiro CLI version inside the images is pinned and upgraded deliberately (probe the new version first, L-044). Developers keep the editable checkout plus a dev mode that builds images locally from the working tree (decided separately). Amends ADR-046 (clone + venv + git-tag self-update) and touches ADR-080 (one tag = one version, now also the image tag). | Every user runs exactly the image CI tested; installs and updates are a download; no source, Python or git needed on the user's machine. Considered: building images locally on first use (needs git + SSH on the host, takes minutes, uses VM resources, and images can differ between machines). |
| D13 | **The host launcher is a small Python package installed with `uv` (2026-11-02, user).** The user installs `uv` (one binary, one-line install on every OS), then `uv tool install genesis-launcher`; `uv` provides its own private Python. The launcher installs or checks the host prerequisites with the user's consent (macOS: Homebrew, Colima, Docker CLI; Linux: Colima, QEMU, KVM access, `sudo` once; Windows: WSL2 via `wsl --install`, admin once, then the Genesis distribution), creates the Genesis VM, signs it in to the registry (D12), pulls the images, starts the stack (app, controller, proxy), waits for health and opens the browser; commands: start, stop, status, logs, update, backup, restore, uninstall. It is a separate package and can update itself independently of the images. It is the only Genesis component outside the VM; it replaces `scripts/install.sh` and `genesis up` for users (amends ADR-046). | One language and one test setup (ADR-017; pytest; the same agents maintain it); reuses the existing launcher logic (`genesis/runtime/launcher.py`); the launcher only drives Colima / WSL / Docker commands, so it need not be tiny or fast. Considered: a Go binary (the usual choice for VM tools such as Colima, Lima and `sbx`, but a new language and toolchain) and per-OS shell scripts (two languages doing the same job, hard to test). |
| D14 | **The Genesis API requires a per-launch access token, plus Origin and Host checks (2026-11-02, user).** Each launch generates a random token inside the VM; the launcher reads it and opens the browser with it (URL fragment); the SPA keeps it for the session and sends it as a header on every `/api` call (added centrally, ADR-028). The API refuses every request without it, except the health check and the static SPA files, and checks `Origin` and `Host` against an allow-list (blocks other web pages and DNS rebinding). The CLI and the review agents' live-acceptance drivers get the token from the launcher (e.g. `genesis token`). The copilot's existing header check (`genesis/genesis/api/run_routes.py:75-89`) moves onto the same mechanism. Amends ADR-026: still single-user with no login screen; the token proves a request comes from the user's own session. | Sandboxes cannot reach the API (D1, D10), but the port is forwarded to the host's `127.0.0.1:8760`, so any host program or web page could still call ≈154 unauthenticated mutating routes (§3.4), including Implementation runs that write to Dev and secret changes; a web page doing it is classic cross-site request forgery. The Jupyter pattern; KiroCrew does the same (§18.1). Cost accepted: every API caller changes (SPA in one place, CLI, test and acceptance drivers); bookmarks open through the launcher. |
| D15 | **Phase 51's browsers in the boxed world: sign in on the trusted side, browsers get only a saved login (2026-11-02, user).** (1) **Sign-in** runs in the app container (headless Chromium) with the test users' passwords from the secret store and writes one Playwright saved-login file (`storageState`) per role into the run folder. (2) **Agent browser sessions** run inside the agent's sandbox, headless, opened with `apwt open --storage-state <role file>`. (3) **Test execution** (`playwright test`) runs in a sandbox too (same image and rules), because it executes agent-written scripts (51-01 D12 step 2); tests load the saved-login files instead of calling `loginAs` with a password. (4) **Human recording** runs in a sandbox, headed on a virtual display (Xvfb), shown to the user through noVNC inside the Genesis UI, started with `apwt record start --state <role file>`. All three: sandbox egress = the QA host only (D10). Passwords never enter any sandbox. Changes to Phase 51 (`loginAs` → saved login; session-opening program steps → the app container; recording → noVNC): whether Phase 51 ships its interim D3c design first and Phase 52 changes it, or adopts the saved-login pattern now, is a cross-phase item for the user to decide later. | Playwright's recommended auth pattern (an auth setup step produces `storageState`, tests reuse it; [Playwright auth](https://playwright.dev/docs/auth)); `apwt` already supports it (`open --storage-state`, `record start --state`: `playwright-appian/src/cli/agent/commands.ts:690-691`, `src/cli/index.ts:126`). **Accepted risk:** the saved-login file holds the test user's QA session cookie, readable by the agent; it gives nothing beyond what the agent already has (it drives that user's browser on QA), works only on the QA host (the only host it can reach) and expires. Running agent-written test code with passwords in its environment would let that code read them. |
| D16 | **Development uses a dev stack in its own VM, built from the working tree (2026-11-02, user).** A separate Colima profile `genesis-dev` runs the same stack with a Compose dev override: the checkout mounted into the app container, code auto-reload, images built locally from the tree (`genesis-launcher dev up`); sandboxes, gateway, proxy and the API token are all real. The dev VM mounts only the repo folder (a deliberate exception to D2, dev profile only). Unit tests and linters (pytest, vitest, ruff, tsc) stay on the host venv; a test-only "local" sandbox provider lets unit tests run without containers and cannot be selected in the product. Live acceptance runs against the dev stack, with the API token from the launcher (D14). The fleet becomes two stacks in the dev VM (8760 / 8761, separate data volumes); `genesis-fleet` and `gsm` change accordingly. The five role agents keep running on the host (ADR-077); boxing them is out of scope (brief Q12). | What is tested is what ships: the sandbox, gateway, proxy and token paths run in every live acceptance. Considered: keeping host-native dev (fastest loop, but dev would never exercise the isolation paths and dev agent turns would stay unboxed). Cost accepted: a slower first start (image build). |
| D17 | **One phase, two releases (2026-11-02, user).** Release 1: macOS, the complete design and the cutover for today's users (all on Macs), with the per-OS environment layer built as an interface from day one. Release 2: the Linux and Windows environment providers, each with its own spike and acceptance sub-specs in this phase, run on real machines (the user has or can get a Linux and a Windows test machine). The cutover follows the v0.80.0 model: existing host installs keep working until the user reinstalls through the launcher and imports their data (D11, D13). Phase 52 begins with a spike gate (the brief's P1–P10 re-cut for D1–D16). Release 1 follows Phase 51's release; D15's changes to Phase 51 land then. | The security fix reaches current users first; Linux and Windows are additive because everything inside the VM is identical (D3). Considered: one release for all three OSes (blocked on test machines, longest wait for current users) and a separate Phase 53 for Linux/Windows (splits one design across two spec sets, against one home per fact). |
| — | **Brief questions resolved:** Q1 → D6; Q2 (mode with no runtime) is moot: Genesis cannot run without its VM and the launcher installs it (D13); Q3 → D2, D4; Q4 → D12; Q5 → D10; Q6 → D9; Q7 → D7; Q8 → D14, with the other §9 items resolved by D1 (no user `~/.kiro`, clean environment in containers), D9 (explicit permission mode), D11 (secrets no longer a host file) and D10 (egress audit); Q9 → D15; Q10 → D17; Q11 → D6; Q12 → D16 (out of scope). | Recorded so §13 has one place that says where each answer lives. |

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

## 18. Research (Phase 52 spec session, 2026-11-02)

Sources: read-only studies of the two reference repos the user named (shallow clones of
`github.com/kirodotdev/KiroCrew` at `4d8b628c` and `appian/prod/friday` at `4b355ff`), a Genesis host-dependency
inventory, and web research. File and line citations for the repo claims are in the session's sub-agent reports;
the points that drive decisions are kept here.

### 18.1 Reference repos

| | Friday | KiroCrew |
|---|---|---|
| Agent isolation | None: `kiro-cli chat --trust-all-tools` on the host (`backend/app/services/kiro_stage_runner.py:142-180`); the ACP path approves every permission request (`backend/app/services/acp_client/session.py:307-340`) | An operating-system sandbox around every `kiro-cli` launch: Seatbelt on macOS (`src/kiro_crew/sandbox_seatbelt.py`), user + mount namespaces, seccomp and capability drop on Linux (`src/kiro_crew/sandbox_launcher.py`) |
| Containers | Packaging only, and an unapplied plan (`docs/DOCKERIZATION_PLAN.md:8-9`); a host-side ACP bridge runs `kiro-cli` back on the host (`backend/scripts/acp_bridge_daemon.py`); plugin containers started through a mounted `docker.sock` with no limits | Optional: the whole gateway in one container (`docker/Dockerfile`, non-root uid 1000), the same namespace sandbox inside it (`docker/compose.yaml:49-57`) |
| Secrets | Host `~/.kiro`, `~/.aws`, `~/.ssh` mounted read-write in the plan | Kiro token broker: the agent gets short-lived access tokens over an ACP host-auth callback, never the refresh token (`src/kiro_crew/acp/kas_host_auth.py:13-17`); credential env scrubbed at launch |
| Local API | Token check commented out (`backend/app/middleware/pipeline_auth.py:40-73`) | Signed tokens, Origin and Host allow-lists (`docs/architecture/security-deep-dive.md:522-578`) |
| Egress | Not restricted | Not restricted by default; documented as a known gap (`security-deep-dive.md:699-706`) |

Take from KiroCrew: the token broker, the authenticated local API, a platform-owned permission check evaluated before
any auto-approve. Take nothing from Friday's container design (it runs the agent back on the host).

### 18.2 Industry practice

Products that give agents a full shell converge on: a trusted control plane separate from untrusted execution
sandboxes; a real boundary (operating-system sandbox < container with gVisor < microVM per sandbox); default-deny
egress through a proxy outside the sandbox, which can inject credentials so they never enter it; MCP servers on the
trusted side behind a gateway; short-lived sandboxes with optional warm pools; never the Docker socket inside a
sandbox. Examples: Claude Code `sandbox-runtime` (Seatbelt/bubblewrap + host proxy,
[repo](https://github.com/anthropic-experimental/sandbox-runtime)) and its devcontainer firewall; OpenAI Codex
(network off by default, [security](https://developers.openai.com/codex/security)); Docker Sandboxes (microVM, host
proxy with credential injection, host-side MCP gateway, its own Docker engine,
[architecture](https://docs.docker.com/ai/sandboxes/architecture/), [security](https://docs.docker.com/ai/sandboxes/security/));
OpenHands (a container per session, [docs](https://docs.openhands.dev/usage/runtimes/docker)); Kubernetes
`agent-sandbox` (a controller delegating to gVisor or Kata, [repo](https://github.com/kubernetes-sigs/agent-sandbox)).
Docker Sandboxes has a Kiro kit ([docs](https://docs.docker.com/ai/sandboxes/agents/kiro/)) but needs a Docker
account sign-in, sends telemetry and targets interactive sessions. Content was rephrased for compliance with
licensing restrictions.

### 18.3 Containers, VMs and nesting

On a Mac every Linux container runs inside a Linux VM (Colima, Docker Desktop, OrbStack); Apple `container` and
Docker Sandboxes give each container its own small VM. Containers in one VM share its kernel, so a kernel escape
reaches the whole VM; a VM boundary is enforced by the hypervisor. Docker-in-Docker needs privileged mode; a mounted
`docker.sock` is root-equivalent on the VM ([Docker Engine security](https://docs.docker.com/engine/security/)).
The standard shape for an orchestrator is a controller that creates sandbox containers from a fixed template.

### 18.4 Findings that shape the design

- **Lima exposes the Mac's loopback to the VM.** The host's `127.0.0.1` services are reachable from the guest as
  `host.lima.internal`; blocking it needs `networkOpts.hostLoopback: false`, Lima ≥ 2.3, `vmType: vz`
  ([Lima user-mode network](https://lima-vm.io/docs/config/network/user/)). Installed: Lima 1.0.7, Colima 0.8.1.
- **Apple `container` "internal" networks still reach the host gateway**, so any host service bound to all
  interfaces is reachable ([apple/container#1320](https://github.com/apple/container/issues/1320)).
- **Machine:** Apple M3 Pro, 36 GiB, 11 cores (M3 supports nested virtualization); macOS 26.7.1; Colima VM
  `default` running (3 CPUs, 8 GiB, docker 27.4.0); `kiro-cli` 2.37.1.
- **Genesis is portable to a Linux container:** pure Python with a prebuilt SPA, every state path overridable by
  environment variable (`genesis/runtime/settings.py`). Mac-coupled items the spec must solve: Kiro device-flow
  login, gws OAuth redirect, opening the browser (`genesis/runtime/launcher.py:128-133`), the git-tag self-update
  (`genesis/runtime/updater.py`, ADR-046), SSH to GitLab for `genesis install`, `uv` for managed MCP installs,
  registry MCP servers launched with `docker`, the `xattr` quarantine strip (macOS only), the fleet (8760/8761),
  and the non-loopback bind guard (ADR-026) once the port is published.
- **Chat bypasses the `AgentProvider` seam** (`genesis/chat/manager.py:105-146` builds `KiroAgentOptions` itself);
  it needs the same treatment as workflow nodes.
- **The `genesis` GitLab project (id 14327, private) has its container registry enabled**, image prefix
  `registry.gitlab.appian-stratus.com/ramaswamy.u/genesis` (checked 2026-11-02). Pulling from a private project
  needs a credential with `read_registry` scope (a personal access token or a deploy token).
  *Lesson candidate:* the full `GET /projects/:id` response, read as the project owner, includes the project's
  runner registration token in clear; query only the fields you need (L-100 family).
- **A headed browser can run in a container** on a virtual display (Xvfb) viewed in the user's browser through
  noVNC (the pattern of Selenium's browser images and Anthropic's computer-use reference container); KasmVNC or
  WebRTC streaming are smoother variants. Linux arm64 has Playwright Chromium and Firefox, not branded Chrome or
  Edge. Human recording is trusted; agent-driven browsers stay inside the sandbox and run headless.

### 18.5 VM runtimes per operating system

| Runtime | Hosts | Licence | Notes |
|---|---|---|---|
| Colima | macOS, Linux | MIT | Lima VM + Docker engine; Linux hosts use QEMU/KVM ([README](https://github.com/abiosoft/colima)) |
| Lima | macOS, Linux; Windows experimental | Apache-2.0 | `vmType: wsl2` is experimental and the Windows default driver moved to QEMU ([experimental features](https://lima-vm.io/docs/releases/experimental/), [breaking changes](https://lima-vm.io/docs/releases/breaking/)) |
| Docker Desktop | all three | Paid above 250 staff | Uses WSL2 on Windows |
| OrbStack | macOS | Paid for commercial use | |
| Podman machine | all three | Apache-2.0 | WSL2 or Hyper-V on Windows |
| Rancher Desktop | all three | Apache-2.0 | WSL2 on Windows, Lima on macOS/Linux |
| WSL2 | Windows | Built in | A lightweight Hyper-V VM; distros share one kernel; by default mounts `C:\` at `/mnt/c` and can launch Windows programs (both switchable off in `/etc/wsl.conf`) |
| Apple `container` | macOS 26+ | Apache-2.0 | One VM per container on the Mac |

Kiro CLI: macOS, Windows 11, and Linux (glibc 2.34+ or musl) on x86_64 and ARM64
([installation](https://kiro.dev/docs/getting-started/installation/)).

## Context manifest

```toml
areas    = ["core-engine", "sdk-acp", "runs-worker", "security", "distribution", "api", "chat", "config-secrets", "workflows-library", "browser-testing", "web-shell"]
adrs     = ["ADR-002", "ADR-004", "ADR-010", "ADR-012", "ADR-017", "ADR-019", "ADR-020", "ADR-022", "ADR-026", "ADR-028", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-046", "ADR-051", "ADR-069", "ADR-077", "ADR-080"]
lessons  = ["L-001", "L-017", "L-021", "L-041", "L-044", "L-087", "L-088", "L-097", "L-100"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/packages/genesis-core/genesis_core/mcp/registry.py", "genesis/genesis/runs/supervisor.py", "genesis/genesis/runs/worker.py", "genesis/genesis/api/run_routes.py"]
upstream = []
```
