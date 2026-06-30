# 03 — Target Architecture

Three layers, each justified by a named multi-agent principle.

```
┌─ ENTRY: ROLE AGENTS (specialization by prompt + skills) ──────────────┐
│  product-owner    ux-designer    developer    tester                  │
│  • user selects one; each owns its slice end-to-end                   │
│  • carries: role prompt + linked skills + the `subagent` tool         │
│  • carries NO heavy MCP schemas                                       │
└───────────────┬───────────────────────────────────────────────────────┘
                │ delegate via `subagent` tool (isolated context)
                ▼
┌─ INTELLIGENCE: MCP SUB-AGENTS (context protection + tool spec.) ──────┐
│  atlas-intel         jarvis-intel          data-generator (optional)  │
│  owns Atlas MCP      owns Jarvis MCP       owns Data-Gen MCP           │
│  ~30 read tools      ~42 tools             8 tools (or attach direct)  │
│  returns DISTILLED findings via the `summary` tool, per return contract│
└───────────────────────────────────────────────────────────────────────┘
┌─ SHARED KNOWLEDGE (reused across all agents) ─────────────────────────┐
│  skills/shared/ (sail-reference, aurora-design-system, a11y-audit, …) │
│  + steering/ (source-routing guidance, conventions)                   │
└───────────────────────────────────────────────────────────────────────┘
```

## 3.1 Role agents (6)

| Agent | Role | Example skills (one purpose each) | Tools |
|---|---|---|---|
| `product-owner` | Product | feature-spec, feature-inventory, release-review, onboarding, cross-app-analysis, impact-analysis, research, chat-triage | read, write, subagent |
| `ux-designer` | UX | aurora-compliance, component-decomposition, edge-case-analysis, create-html-prototype, generate-sail, branding-compliance | read, write, subagent |
| `developer` | Engineering | explore, impact-analysis, design-document, code-review, implementation, refactor-redeploy, expression-tests, sail-to-sql, i18n-*, **a11y-fix** (←Jarvis-A11yFixer), **database-script-management** (←jarvis-smt) | read, write, shell, subagent |
| `tester` | QE / verification | test-execution (TEA), unit-test (←jarvis-verify), a11y-audit (shared), test-data-generation | read, write, shell, subagent |
| `devops` | DevOps | deployment, package-management, promote, pipeline-check | read, write, shell, subagent |
| `documentation` | Documentation | doc-fip, doc-tech-design, doc-perf-review, doc-security-review, doc-arch-overview, doc-adr (←feature-docgenie), **generate-erd** (←erd-generator) | read, write, subagent |

Rules:
- Each role agent's `resources` links `skills/shared/**` + `skills/<role>/**` via `skill://`.
- Role agents carry the `subagent` tool with `availableAgents` limited to the sub-agents.
- Role agents do **not** call each other for sequential phases of one feature.
- `jarvis-smt` (→ Developer `database-script-management`) and `jarvis-verify` (→ Tester `unit-test`)
  have **no MCP of their own**; they delegate SQL/eval to `jarvis-intel` (+ Playwright for unit-test).
- TEA (`test-execution`) and `unit-test` are distinct Tester skills — TEA runs end-to-end execution,
  `unit-test` verifies test cases/ACs.
- `atlas-demo-driver` is **dropped** (no demo-driver capability).

## 3.2 Sub-agents

| Sub-agent | Owns MCP | Mode | Model | Notes |
|---|---|---|---|---|
| `atlas-intel` | Atlas (Cloud KB) | read-only | cheap (e.g. haiku) | versioned/offline code intelligence |
| `jarvis-intel` | Jarvis (live env) | read + write/eval | cheap/standard | real-time state, `query_sql`, `evaluate_sail`, deploy/package handlers |
| `data-generator` | Data-Gen | read/write data | standard | **dedicated sub-agent** (decision 2026-06-25) |

- Each owns its MCP via **`.kiro/settings/mcp.json`** (declared there; the sub-agent sets
  `includeMcpJson: true` with `tools`/`allowedTools` scoped to that server). *(Corrected 2026-06-30:
  embedded per-agent `mcpServers` don't reach spawned sub-agents in the Kiro IDE — see doc 11 §6.5.)*
- Returns via the `summary` tool with a **return contract** defined in its prompt.
- Deploy/package capability currently lives in the Jarvis server (deployment/package handlers), so
  `devops` reaches it via `jarvis-intel`. A standalone deploy MCP is a later option (not v1).

## 3.3 Shared knowledge

- `skills/shared/` — any skill used by 2+ roles lives here once (no duplication). Linked by each
  agent that needs it.
- `steering/` — always-on guidance, notably source-routing (when to ask Atlas vs Jarvis), naming
  conventions, and security posture (read-only vs write).

## 3.4 Delegation flow (example)

```
User → developer agent: "What breaks if I change rule X in GSS?"
  → developer activates skill: impact-analysis
  → developer calls subagent(atlas-intel, "transitive dependents of X in GSS; return list + risk")
      → atlas-intel queries Atlas MCP, returns distilled summary
  → developer composes the answer (full context preserved on the role agent)
```

## 3.5 Why not one agent with all MCPs

A single agent holding Atlas + Jarvis + Data-Gen would carry 80+ tool schemas — well past the
~20-tool degradation threshold — bloating every session and harming tool selection. Sub-agents
isolate that cost. (For the 8-tool Data-Gen, the cost/benefit is marginal, hence "optional".)
