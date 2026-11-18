# 52-09 — Genesis integration: workflow nodes and chat run through the sandboxed AgentProvider

> **Status:** SPEC-DRAFTED 2026-11-18. Repos: **genesis** (`genesis-core` agents, `kiro-agent-sdk` launch, chat,
> runs), **genesis-workflows** (`egress` declarations). Parent: `specs/phase-52-agent-runtime-isolation.md`.
> Decisions: D1, D6, D9, D10, D11, D21, D25, D26. Upstream: 52-06, 52-07, 52-08.

## 1. Goal

Every Kiro session Genesis starts — workflow agent nodes, every chat mode, the catalog probe — runs in a sandbox
through the AgentProvider seam, with no change to graphs, prompts or trust lists.

## 2. Design

- **`SandboxedKiroProvider`** (`genesis_core/agents/sandboxed.py`, implements the ADR-051 `AgentProvider`): for a turn
  it asks the app's policy compiler for the policy (52-06), calls the controller's `run_turn`, and runs today's
  `kiro_agent_sdk` client over the returned stdio stream instead of a local subprocess. The SDK's `launch.py` gains a
  transport option (`spawn` today, `attached` for a stream from the controller); everything above it (projection,
  activation, permission ladder, updates, usage, timeouts) is unchanged. The sandbox argv follows 52-08 §4.
- **Environment:** the sandbox gets the policy's fixed env only (`HOME`, `PATH`, `LANG`, `TMPDIR`, the proxy vars,
  `PLAYWRIGHT_BROWSERS_PATH`, `KIRO_HOME`), closing ADR-083 risk (b); the SDK's "inherit the caller's env" default is
  not used in this path.
- **`KIRO_HOME`:** workflow runs keep `<run folder>/_kiro/` (ADR-086), inside the mounted run subfolder; chat's home
  moves from `~/.genesis/kiro-home/chat/` to a per-session folder in the state volume mounted into that session's
  sandbox only.
- **MCP:** `mcpServers` lists relay entries (52-08 §3), never the real servers.
- **Workflow nodes:** `kiro_node` is unchanged in its signature; `get_agent_provider()` returns the sandboxed provider
  when the controller is configured; `permission_mode`/`TrustPolicy` stays as ADR-086 ships (D9: built-ins
  auto-approved; MCP within the cap); each turn's telemetry records `runtime`, `sandbox_id`, `policy_hash`.
- **Chat:** `chat/manager.py` builds its options through the same provider (today it bypasses it); one sandbox per chat
  session for its lifetime (D6), torn down on session close, idle timeout or server stop; read-only modes keep their
  fail-closed trust and the session sandbox folder as the only writable path (ADR-031/033/034).
- **Workers:** stay subprocesses (ADR-012), now inside the app container; pause = kill the worker and its sandbox via
  the controller; resume = a fresh worker and a fresh sandbox from the checkpoint; the worker records the intended stop
  before the kill (L-108).
- **Host path:** until 52-12's cutover the host `KiroAcpProvider` stays selectable (configuration, not a setting) so
  intermediate commits keep the gates green; 52-12 removes it from the product.
- **genesis-workflows:** add `META.egress` where 52-02 S10 and the run history show a real need (proposed:
  `story-design-analysis`, `story-implementation` → `docs.appian.com`; Phase 51 browser workflows → the QA host, taken
  from the environment at policy time rather than hard-coded); bump each changed workflow's version.

## 3. Tests

Provider unit tests with a fake controller stream replaying the SDK's v3 fixtures (same expected outputs as the
spawn transport); env allow-list test; chat session lifecycle tests (one sandbox per session, torn down on Stop-less
close, idle, server stop; L-118's shielded finalization kept); pause/resume/cancel through the controller with the
compare-and-set terminal write; a scan of every `kiro_node` in the library with the real registry and META to show the
compiled policies before the switch (L-116); every library workflow's tests green.

## Context manifest

```toml
areas    = ["core-engine", "sdk-acp", "chat", "runs-worker"]
adrs     = ["ADR-012", "ADR-031", "ADR-051", "ADR-069", "ADR-083", "ADR-086"]
lessons  = ["L-041", "L-093", "L-108", "L-113", "L-116", "L-118"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-53-kiro-sdk-v3/53-06-workflow-nodes-and-skills.md", "tracker:specs/phase-53-kiro-sdk-v3/53-07-chat-backend.md"]
code     = ["genesis/packages/genesis-core/genesis_core/agents/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/launch.py", "genesis/genesis/chat/manager.py", "genesis/genesis/runs/supervisor.py"]
upstream = ["52-06", "52-07", "52-08"]
```
