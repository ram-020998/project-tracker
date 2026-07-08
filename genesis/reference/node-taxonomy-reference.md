# Genesis — Node Taxonomy Reference

The fixed set of node factories every workflow is built from. Uniform nodes make
workflows consistent, make the reliability trio the default, and let the CI lint
reason about graph structure. All live in `genesis_core/nodes/`.

Each node created via these factories carries a `_genesis_kind` marker
(`program|agent|cli|validator|gate|subgraph`) used by the reliability lint.

---

## 1. `program_node(fn)` — deterministic step
```python
def program_node(*, name, fn) -> Node
# fn(state: PlatformState, ctx: PlatformContext) -> dict   (partial state update)
```
- Use for transforms, parsing, assembly, decisions the code can make.
- Must return a **small** partial update (pointers/decisions), not bulk data.
- No MCP, no LLM. Deterministic and unit-testable in isolation.
- **Default choice** — if a step *can* be a program, it must be (ADR-001/018).

## 2. `kiro_node(...)` — narrow agent step (Kiro via ACP)
```python
def kiro_node(*, name, prompt_fn, output_doc: str,
              mcp: list[str] = (), tools: list[str] | None = None,
              model: str | None = None, turn_timeout: float = 420) -> Node
# prompt_fn(state, ctx, out_path) -> str
```
Behaviour:
- Resolves `mcp` names via `ctx.mcp.acp_servers(...)` (per-node injection, ADR-004/005).
- Opens ONE short-lived ACP session (`kiro-agent-sdk` `collect`), trust-all-tools.
- The agent **writes its output to a pre-created blackboard doc** (`output_doc`) — it does **not** return bulk via chat (ADR-018; the lesson that fixed the ERD hang).
- Returns only `{artifacts: {output_doc: path}, _last_turn: {...}}` into state.
- **Records per-node telemetry** (`{attempts, duration_ms, tool_calls, turns, credits, retries}`) into `state.telemetry[name]` and a run aggregate — built in from Phase 1 (see `state-and-data-model.md` §1.4). `credits` is best-effort (needs SDK usage exposure).
Rules:
- Keep it **narrow** — one judgment or one data-fetch (ADR-011).
- Always paired with a validator (see §4) — enforced by CI.
- On retry, `prompt_fn` receives the validator's feedback (`state["_validation"][...]["message"]`) to self-correct.

### 2.1 kiro-agent-sdk integration (how agent nodes talk to Kiro)
`genesis_core/nodes/agent.py` is the only place that imports `kiro-agent-sdk`:
- `collect(prompt, KiroAgentOptions(...))` → runs one turn, returns `TurnResult`.
- `KiroAgentOptions(cwd, trust_all_tools=True, mcp_servers=[...], tools, model, turn_timeout)`.
- MCP servers come from `McpRegistry.acp_servers(names)` which reuses
  `kiro_agent_sdk.load_mcp_servers` semantics (`${VAR}` resolution) but reads from
  the shared `mcp-registry.json` + SecretProvider (Phase 4).
- The SDK already handles the 64 MB ACP stream buffer, fs/permission auto-answer,
  and structured events — Genesis surfaces those events to the run stream (Phase 5).

## 3. `cli_node(cmd_fn, parse_fn)` — external CLI step
```python
def cli_node(*, name, cmd_fn, parse_fn) -> Node
# cmd_fn(state, ctx) -> list[str]   (argv; binary resolved via ctx.clis)
# parse_fn(completed_process, state, ctx) -> dict   (partial state update)
```
- Wraps CLIs from `cli-registry.json` (e.g., `erd-gen`).
- Nonzero exit → raise (run fails, resumable) or route via a wrapping validator.
- Deterministic; unit-test `cmd_fn`/`parse_fn` directly.

## 4. `validator_node(...)` — deterministic check + routing
```python
def validator_node(*, name, check_fn, target_artifact: str | None = None) -> Node
# check_fn(data, state, ctx) -> ValidationResult(ok, message, normalized=None)
```
- Reads the artifact/decision a prior (usually agent) node produced.
- Writes result to `state["_validation"][name] = {ok, message}`.
- Emits a routing key `pass` | `fail`. On pass may write a `normalized` artifact.
- Pure/deterministic — this is the component that makes the *program* decide "good enough" (ADR-011).
- **Compose `check_fn` from `genesis_core.validators`** (batteries-included toolkit) — ~80% of validators are one-liners; see `reliability-standard.md` §3.1. Appian-object validators (re-read via LCP/Atlas) are deferred to the development phase (§3.2).

## 5. `hitl_gate(kind)` — human-in-the-loop pause
```python
def hitl_gate(*, name, kind, prompt_fn, options=None) -> Node
# kind: "approval" | "escalation" | "pre_mutation" | "review"
```
- Calls LangGraph `interrupt(payload)`; run pauses (status `awaiting_input`).
- Resumed via `Command(resume=decision)` (`approve` | `reject` | `{feedback}`) — see `hitl-design.md`.
- The **only** sanctioned pause classes are `approval` (author gates), `escalation` (retry exhaustion), and `pre_mutation` (before write/deploy) — everything else auto-advances (`META.auto_approve=true` default). `pre_mutation` gates are **required** before any write/deploy/data MCP node.

## 6. `subgraph_node(workflow_id)` — composition
```python
def subgraph_node(*, name, workflow_id, input_map=None, output_map=None) -> Node
```
- Embeds another installed workflow's compiled graph as a node.
- Used by the flagship `sdlc-pipeline` (Phase 8 Wave D) to compose migrated workflows.
- Maps parent state ↔ subgraph state via `input_map`/`output_map`.

## 7. `attach_reliability(...)` — the mandatory trio wiring
```python
def attach_reliability(g, *, agent, validator, retry_max, on_exhaust_gate=None, nxt=END)
```
- Wires `agent → validator`; conditional routing `pass → nxt`, `fail & retries<max → agent (retry)`, `fail & exhausted → on_exhaust_gate` (a `hitl_gate`) or `END`.
- Increments `state["retries"][agent.name]`.
- **The scaffolder emits this by default** so compliance is the path of least resistance (ADR-014).

---

## 8. Node selection decision tree (authoring guidance)

```
Does the step need a decision/output only an LLM can produce,
or data only reachable via an MCP server?
        │ no ──────────────▶ program_node  (or cli_node if an external CLI does it)
        │ yes
        ▼
   kiro_node (inject just the MCP it needs)
        │
        ▼  (MANDATORY)
   validator_node  ──fail──▶ retry (≤ retry_max) ──exhausted──▶ hitl_gate(escalation)
        │ pass
        ▼
   next step
Is a human decision required here (approve/branch)?  ──▶ hitl_gate(approval)
Is this step itself a whole existing workflow?       ──▶ subgraph_node
```

---

## 9. Invariants (checked by the reliability lint — Phase 2)

1. Every `agent` node has an immediate `validator` successor.
2. Every such validator has a retry edge back to its agent and an escalation edge.
3. No node pushes bulk data into state (state-size guard).
4. Agent nodes declare their `mcp` from the registry (no ad-hoc server defs).
