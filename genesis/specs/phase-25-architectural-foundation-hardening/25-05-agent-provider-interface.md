# 25-05 — AgentProvider Interface

- **Status:** 📝 DRAFTED · **Review items:** E-3, §F (new LLM provider), §5 (agent architecture) · **Roadmap:** Phase 2 · **Repos:** genesis-core, genesis · **Proposed ADR:** ADR-051 · **Depends on:** nothing

## 1. Goal
Formalize a named **`AgentProvider`** interface (Protocol) for the agent/LLM runtime so Kiro-CLI-over-ACP becomes *one implementation behind an interface* rather than the only, hard-wired provider. Adding a second provider (or a fake for tests) becomes an **additive adapter**, not a cross-cutting edit.

## 2. Why (review evidence)
- **E-3 / §F "New LLM provider":** rated **Hard** — a single provider; ACP/Kiro assumptions (skills-from-filesystem, `_kiro.dev/*` extensions, `KiroAgentOptions`) leak into `genesis-core/nodes/agent.py` and `genesis/chat/`.
- The `set_collect_impl(...)` test seam (`nodes/agent.py`) **already proves the call site is interceptable** — this sub-phase promotes that ad-hoc seam to a first-class interface.
- Review §5 wants a clean `Agent → Reasoning → Workflow → Tool → External` separation; a provider interface is the boundary between "an agent turn" (Genesis's concept) and "how Kiro executes it" (the runtime).

## 3. Current state (cited)
- `genesis-core/nodes/agent.py`: module-level `_COLLECT_IMPL`/`_OPTIONS_CLS`/`_STREAM_IMPL` lazily bound to `kiro_agent_sdk`; `set_collect_impl(...)` overrides for tests; `KiroAgentOptions` constructed inline (cwd, trust_tools, model, mcp_servers, timeouts, images…).
- `genesis/chat/manager.py`: builds ACP options directly; consumes `_kiro.dev/*` catalog/commands; permission bridge (`permission_mode="ask"` + `on_permission`).
- genesis-core already imports the SDK **lazily** (imports clean without it) — the layering is half-there.

## 4. Design
### 4.1 The interface (`genesis-core/agents/provider.py` — NEW)
A `Protocol` (structural, no inheritance) capturing exactly what Genesis needs:
```python
class AgentProvider(Protocol):
    async def collect(self, options: AgentTurnOptions) -> TurnResult: ...
    async def collect_streaming(self, options) -> AsyncIterator[AgentEvent]: ...
    async def capabilities(self) -> AgentCapabilities: ...   # models, commands, image support
    # permission bridge shape (ask/deny + on_permission callback) declared here
```
- `AgentTurnOptions` / `TurnResult` / `AgentEvent` / `AgentCapabilities` are **provider-neutral** dataclasses (cwd, trust_tools, mcp_servers, model, fs_write_root, images, timeouts, usage/credits, permission_mode) — the union of what `agent.py` + `chat/` need, named without `Kiro`/ACP terms.
- **Credits/usage stay first-class** on `TurnResult` (ADR-032 — the metering contract is provider-neutral: `{value, unit:"credit", provenance}`).

### 4.2 The Kiro implementation (`genesis-core/agents/kiro.py` — NEW; wraps today's code)
- `KiroAcpProvider` implements `AgentProvider` over `kiro_agent_sdk` — the current `collect`/`collect_streaming`/`KiroAgentOptions`/catalog/permission logic moves here **verbatim** (behavior-preserving).
- `nodes/agent.py` + `chat/manager.py` depend on `AgentProvider`, obtained from a provider registry/factory; the default is `KiroAcpProvider`.
- `set_collect_impl(...)` is reframed as "install a test `AgentProvider`" (keep the old function as a thin shim for one release so existing tests pass).

### 4.3 Provider selection
- A single `get_agent_provider(settings)` factory (default Kiro). Provider choice is a settings value; only Kiro exists today — the point is the seam, not a second provider (review §36: don't build what isn't needed, but make the boundary clean).

## 5. Files touched
- **New:** `genesis-core/agents/{__init__,provider,kiro}.py`, `genesis-core/tests/test_agent_provider.py`.
- **Edit:** `genesis-core/nodes/agent.py` (depend on provider; keep `set_collect_impl` shim), `genesis/chat/manager.py` (obtain provider via factory), `pyproject` (no new runtime dep — Kiro SDK still the only impl). genesis-core `CORE_MAJOR` unchanged (additive, ADR-019).

## 6. Tests
- A `FakeAgentProvider` drives a full workflow agent node + a chat turn **without kiro-agent-sdk present** (proves the abstraction).
- Capability advertisement + credits/usage flow through `TurnResult` unchanged (ADR-032 regression).
- Existing agent/chat tests pass through the shim.

## 7. Risks & mitigations
- **Risk:** leaking ACP concepts into the "neutral" types. **Mitigation:** name types by intent; a review checklist that the Protocol has no `kiro`/`_kiro.dev` identifiers.
- **Risk:** scope creep into a second provider. **Mitigation:** explicitly none built here.

## 8. Out of scope
Building a non-Kiro provider (OpenAI/Anthropic); model-routing policy.

## 9. Definition of Done
`AgentProvider` Protocol + `KiroAcpProvider` shipped; core/chat depend on the interface; fake-provider tests green (no SDK needed); ADR-051 → Accepted + mirrored to `bible/04`; genesis-core + genesis releases CI-green; progress doc.
