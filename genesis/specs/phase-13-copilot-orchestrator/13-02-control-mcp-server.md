# Phase 13-02 — Genesis Control MCP Server (+ ADR-033)

> **Status:** ✅ SHIPPED (Phase 13 complete — 13-01..06; see `progress/phase-13-copilot-orchestrator.md`) · **Repo:** genesis · **Depends on:** 13-01 (for confirmed mutations)
> **Goal:** A write-capable stdio MCP server — the sibling of the read-only introspection server (10-02) —
> that exposes **run-management** as tools by **proxying the existing `/api` surface**, so `RunManager`
> remains the single source of truth. Plus **ADR-033**, which records the copilot boundary.

---

## 1. Why a thin HTTP-proxy MCP server (not direct DB/RunManager access)

The introspection server (10-02) opens `genesis.db` read-only and answers queries directly. **Control cannot
do that** — starting a run needs input validation against `META.inputs_schema`, the subprocess supervisor,
lockfile/loader compat checks, and gate-from-checkpoint logic, all of which live in `RunManager` + the API
inside the app process. Duplicating them in a separate subprocess would fork the source of truth.

**Decision:** the control server is a **thin MCP→HTTP facade** over `/api` (Codex-as-MCP-server pattern). It
holds no run logic; each tool is one authenticated HTTP call to `127.0.0.1:<port>/api/...`. `RunManager`
stays authoritative; the control server is trivially testable (mock the HTTP client).

Launched like the introspection server, with the base URL + an auth token passed as args:
```
python -m genesis.mcp.control_server --base-url http://127.0.0.1:8760 --token <per-process-token>
```

## 2. Tool surface (run-management only)

| Tool | Args | Proxies | Kind | Trusted? |
|---|---|---|---|---|
| `list_launchable_workflows` | — | `GET /api/catalog` (installed + prereqs) | read | ✅ trusted |
| `get_workflow_inputs_schema` | `workflow_id` | `GET /api/workflows/{id}` (META.inputs_schema + required_mcp/cli) | read | ✅ |
| `check_launch_readiness` | `workflow_id` | `GET /api/workflows/{id}` + `/api/config/health` (missing secrets, MCP up) | read | ✅ |
| `start_run` | `workflow_id`, `inputs` (obj), `environment?` | `POST /api/runs` | **mutate** | ❌ untrusted → confirm |
| `get_run_status` | `run_id` | `GET /api/runs/{id}` (status, cursor, verdict/report ptrs) | read | ✅ |
| `get_run_steps` | `run_id` | `GET /api/runs/{id}/steps` (per-node summary, brief) | read | ✅ |
| `get_pending_gate` | `run_id` | `GET /api/runs/{id}` → `.gate` (GateDescriptor: node, kind, prompt, options, context_refs) | read | ✅ |
| `respond_to_gate` | `run_id`, `decision` (`approve`\|`reject`\|`{feedback}`) | `POST /api/runs/{id}/respond` | **mutate** | ❌ → confirm |
| `cancel_run` | `run_id`, `reason?` | `POST /api/runs/{id}/cancel` | **mutate** | ❌ → confirm |
| `list_session_runs` | — (session scoped via token) | `GET /api/chat/runs?session=…` (13-03 link table) | read | ✅ |

Explicitly **excluded** (never exposed): anything under `/api/config/*` (secrets, MCP/CLI registry,
environments), `/api/library/*` (install/update/delete workflows), fork/patch-state, and any deploy path.
The server's **authority is its tool set** (ADR-029): it is structurally incapable of config/registry/deploy
mutations.

Tool results are compact JSON summaries (never bulk); large artifacts stay referenced by path (the agent can
point the user to the Run-Detail Documents drawer). `respond_to_gate` normalizes the decision to the
`RunManager` contract (`"approve"` / `"reject"` / `{"feedback": "..."}`) and validates it against the
gate's advertised `options` before proxying (fail fast on an invalid decision).

## 3. Auth (localhost, single-user — ADR-026)

`/api/runs` etc. are already reachable on localhost. To ensure only the co-launched control server (not any
random local process) can drive mutations, add a **per-process shared token**: the app generates a random
token at startup, passes it to the control server via `--token`, and the control-mutation endpoints require
`X-Genesis-Control-Token`. Read endpoints already exist and are unchanged. (This is defense-in-depth on a
single-user box, not multi-tenant auth.)

## 4. ADR-033 — Chat Copilot boundary (drafted here, finalized in 13-06)

> **ADR-033 — The Chat copilot may operate runs at the run-management layer, with human-confirmed
> mutations, but never owns workflow control flow.**
>
> **Context.** Phase 10 made Chat strictly read-only (ADR-031). Users want a copilot that starts and
> supervises runs. ADR-001 forbids agents from orchestrating control flow.
>
> **Decision.** Chat may act as a **run operator** via the Genesis Control MCP server, subject to:
> 1. **Run-management layer only** — start / read status / read + answer gates / cancel. It calls the same
>    `RunManager` API a human operator uses. It does **not** decide which node runs next, alter graph edges,
>    retries, or gates — LangGraph still owns all of that (ADR-001 intact).
> 2. **Every mutation is human-confirmed** — `start_run` via the schema-driven launch dialog; `respond_to_gate`
>    and `cancel_run` via a per-call permission confirm card (ACP `session/request_permission`, 13-01). The
>    copilot cannot auto-approve or bypass a workflow's own HITL gate — it only relays the human's decision.
> 3. **No config / secrets / registry / workflow-definition / deploy access** — the control tool set excludes
>    all of these (ADR-029 authority-by-tool-set).
> 4. **Auditable** — every agent-initiated action is logged with the confirming user event (13-06).
> 5. **Read-only remains the default** — a session is `read_only` until the user launches/toggles copilot.
>
> **Consequences.** ADR-031 is refined (chat is read-write at the run-management layer, human-gated), ADR-001
> is preserved (agent ≠ workflow engine). The copilot is a *supervised operator*, not an autonomous agent.

## 5. Files & tests

- `genesis/mcp/control_server.py` — argparse (`--base-url`, `--token`), an stdlib stdio MCP loop (mirror
  `introspection_server.py`), an httpx client, one function per tool, decision normalization/validation.
- `genesis/api/app.py` — the control-token dependency on the mutation endpoints; a `GET /api/chat/runs`
  placeholder (filled by 13-03); `GET /api/workflows/{id}` already returns META.
- `tests/test_control_server.py` — mock the HTTP client; assert each tool maps to the right endpoint +
  payload; `respond_to_gate` rejects a decision not in the gate's options; excluded tools absent;
  token required on mutations.

## 6. Acceptance criteria
1. The control server exposes exactly the §2 tools (no config/registry/deploy tools).
2. Each tool proxies the correct `/api` endpoint; mutations require the control token; `respond_to_gate`
   validates against the gate options.
3. `RunManager` remains the only writer of run state (the server adds no DB writes).
4. ADR-033 committed to `reference/decision-log.md`.

## 7. Out of scope
- Wiring the server into a chat session + the permission bridge (13-03).
- The supervision bridge (13-03/13-04) and UI (13-05).
