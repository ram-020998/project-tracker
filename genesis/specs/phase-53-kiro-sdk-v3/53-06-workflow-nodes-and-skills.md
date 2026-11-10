# 53-06 — Workflow nodes on v3, and managed-only skills

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: **genesis** (`packages/genesis-core`, `genesis/runtime/context.py`),
> **genesis-workflows** (the `appian` skill). Parent: `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D8, D9;
> F1, F3, F6, F7, F10.

## 1. Goal

Every workflow agent turn runs on the v3 SDK with the run's own Kiro home, D9's trust, and the same events, telemetry and
blackboard behaviour as today; workflow skills come only from the managed workspace. No workflow's `graph.py` changes
(`kiro_node`'s signature is unchanged, F1; `CORE_MAJOR` stays 1, ADR-019).

## 2. `kiro_node` (`packages/genesis-core/genesis_core/nodes/agent.py`)

- **Home** (D6): `kiro_home = <ctx.workspace.root>/_kiro` (created if missing; shared by the run's turns). The run's
  artifact listing hides `_kiro/` from the documents view (it holds engine records and logs, not deliverables) but keeps
  it on disk for debugging and retention (ADR-022).
- **Trust** (D9): `TrustPolicy(builtins=("shell", "fs_read", "fs_write", "grep", "glob", "web_fetch", "web_search"),
  mcp_tools=<effective>, auto_approve=<all of them>, mode="auto_approve")`, where `<effective>` =
  `_compute_effective_trust(tools, mcp, ctx.mcp)` (`agent.py:137-166`) plus `BLACKBOARD_TOOLS`; a `None` result
  (no node list, no allowlists) becomes `@<server>` for every server in `mcp` + `@blackboard` (when the node has the
  blackboard). So a Phase 51 node (no `mcp`, no `tools`) gets D9's built-ins + `@blackboard`, and a `blackboard=False`
  node with `mcp=[]` gets built-ins only (53-01 §9.2). Never `--trust-all-tools`
  semantics: only the node's servers are reachable. `permission_mode="auto_approve"` is now explicit (52-01 D9).
- **Agent prompt:** a short fixed Genesis node prompt (role: a narrow workflow step; save large tool output with
  `save_tool_output`, L-021); the node's `prompt_fn` text stays the user prompt.
- **MCP readiness** (F3): if `mcp_status` reports a failed server, the turn ends before the prompt with
  `ResultMessage.error` classified `mcp_failed` (no credits spent); the reliability trio retries/escalates as today
  (ADR-011).
- **Events** (shapes unchanged, ADR-066, L-005): `_emit_message` (`agent.py:169-192`) reads `name` (now `@server/tool`
  → the tool name, or the built-in Genesis name), `raw_input` (now the MCP `arguments`, 53-04), `output`; `save_tool_output`
  detection (`agent.py:321-337`) keeps `raw_input["document"]` because 53-04 unwraps `arguments`; `agent.result` keeps
  `credits, context_pct, turn_duration_ms, provenance` and adds `model`, `fallback_from` when present (F6); telemetry
  keys unchanged.
- **Timeouts** (F7): `turn_timeout` stays the ceiling (default 420 s; Phase 51 nodes set 600–900 s); silent and
  tool-stall limits from the SDK defaults; a node may not raise them.
- **Environment:** the turn keeps the worker's environment plus `KIRO_HOME` (53-04; Phase 51's `npx --no-install apwt`
  needs the worker's `PATH`, 53-01 §9.3 item 2).
- **AgentProvider** (ADR-051): `KiroAcpProvider` and `_load_real` unchanged in shape; `options_cls()` returns the new
  `KiroAgentOptions`; the test hooks `set_collect_impl` / `set_agent_provider` keep working (genesis-workflows tests use
  them).

## 3. Managed-only skills (D8)

- `genesis/genesis/runtime/context.py:76-97` `_skill_source`: search **only** `settings.skills_dir`; remove the
  `~/.kiro/skills` entry (`:93`). **Keep** Phase 51's `playwright-appian` branch (`:87-92`, 51-07 §7): that skill's
  one home is the run's workspace export (`<run>/checkout/node_modules/playwright-appian/skills/`), a Genesis-owned
  source, so it stays consistent with D8. A test pins both: managed skills resolve, `playwright-appian` resolves from the
  checkout, and a skill present only in `~/.kiro/skills` does not resolve.
- `core/nodes/agent.py:106-110` error text: "skill '<id>' (declared by node '<node>') is not installed — install it in
  Settings → Catalog → Skills." (no `~/.kiro/skills` wording).
- **`appian` skill** (genesis-workflows): add `skills/appian/` (SKILL.md + references) from the user's
  `~/.kiro/skills/appian/` **with the user's confirmation of the content to publish** (it is their skill); register it
  in `genesis-workflows/skills-registry.json`; the library's skill CI gates (`validate_skills`) green. `story-implementation`
  (`workflows/story-implementation/graph.py:120-121`) is unchanged and now installs `appian` from the library.
- Workflows that declare skills: a run fails fast with the message above when the skill is not installed (as today,
  better text). Consider (backlog, not this phase): auto-installing a workflow's declared library skills at
  `genesis install`.

## 4. Tests

genesis-core: `kiro_node` builds the expected `TrustPolicy` and `kiro_home` for (no tools, a tool list, an allowlist cap,
blackboard on/off); an `mcp_failed` turn emits `agent.result` with the error and no credits; v3-shaped messages through
`_emit_message` and the tool-output store (fixtures from 53-02: MCP `arguments` nesting, `save_tool_output`); provider
hooks. genesis: `_skill_source` ignores `~/.kiro/skills` (tmp home with a same-named skill), still resolves
`playwright-appian` from the run checkout and `genesis-test-authoring` from the managed workspace;
`tests/test_workflow_skill_provisioning.py` (asserts the fallback today, `:4`, `:41`) rewritten to the managed-only rule.
genesis-workflows: `story-implementation` tests with the skill resolvable from the library fixture; the Phase 51
workflows' tests (`story-verification`, `action-capture`, `setup-composer`) still green through the provider hooks;
`validate_skills` green. Before starting, rebase on current master and re-diff genesis-workflows: Phase 51's
live-acceptance patches (v0.81.x) may have changed those three workflows (53-01 §9.3 item 8).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["core-engine", "workflows-library", "sdk-acp", "runs-worker"]
adrs     = ["ADR-011", "ADR-012", "ADR-019", "ADR-021", "ADR-022", "ADR-029", "ADR-032", "ADR-051", "ADR-066", "ADR-067", "ADR-069", "ADR-010", "ADR-018", "ADR-083"]
lessons  = ["L-002", "L-005", "L-016", "L-020", "L-021", "L-023", "L-024", "L-026", "L-042", "L-064", "L-092", "L-101", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/packages/genesis-core/genesis_core/agents/**", "genesis/packages/genesis-core/tests/**", "genesis/genesis/runtime/context.py", "genesis/tests/test_workflow_skill_provisioning.py", "genesis-workflows/skills/**", "genesis-workflows/workflows/story-implementation/**"]
upstream = ["53-04", "53-05"]
```
