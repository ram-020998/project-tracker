# Genesis ↔ solutions-copilot — Relationship & Reuse

Genesis is the **successor** to solutions-copilot and the realization of its
**deferred (doc-19) orchestration** vision. This doc records the positioning, what
is reused, and what is retired — so the lineage is explicit.

---

## 1. Positioning

- **solutions-copilot** = a Kiro **agents + skills** platform with a VS Code
  installer. It tried to use an **LLM agent as orchestrator** of multi-step
  skills. That failed structurally (agents skipped steps / didn't follow the
  skill). Its `19-workflows-orchestration-deferred.md` concluded durable external
  orchestration was needed and named **LangGraph**.
- **Genesis** = that orchestrator. Control flow moves into LangGraph; each skill
  becomes a **workflow** (program + narrow agent nodes). **solutions-copilot is
  retired** (ADR-013); Genesis fully replaces it.

Genesis dissolves solutions-copilot's blocking constraints:
- Its spike found Kiro-native orchestration crippled (blocking-only `agent_crew`,
  no session resume, **no nesting**) → an orchestrator agent couldn't spawn role
  agents as workers. **Genesis doesn't use Kiro to orchestrate at all** — LangGraph
  nests/loops/resumes externally; Kiro is invoked per node via ACP.

---

## 2. What Genesis REUSES (reimplemented natively)

| solutions-copilot asset | Genesis equivalent | Notes |
|---|---|---|
| Manifest → Catalog projection | `registry.json` (aggregated from `workflow.yaml`) → catalog | same "single source of truth" idea, retargeted to workflows |
| Lockfile + update detection | `installed.lock.json` + tag-based updates | Phase 3 |
| GitLab REST client | `dist/gitlab.py` | Phase 3 |
| SecretProvider (`scope/VAR`, plaintext→keychain) | `config/secrets.py` | Phase 4 |
| Credential-free env registry + label resolution | `config/environments.py` | Phase 4 |
| MCP wiring (template, `${VAR}`, owner/env-key classification) | `mcp-registry.json` + `McpRegistry` | but **per-node injection**, no global mcp.json (ADR-020) |
| `.kiro/analysis/*.md` loss-free handoff | `RunWorkspace` blackboard | ADR-018 |
| Role grouping (engineering/product/full) | `roles` tags + `bundles.json` | Q5 |
| Webview stack (Preact, design system, message gateway) | Phase 7 custom workbench | reuse UI primitives |
| The **45 skills** (SKILL.md + ~35,900 lines of references) | migration source for workflows | Phase 8; port references as design source |

---

## 3. What Genesis RETIRES

- **Agent-as-orchestrator** — replaced by LangGraph.
- **"Powers/agents/skills" packaging** — replaced by workflow packages.
- **The VS Code installer extension** — replaced by the Genesis local web app + its own config UI (ADR-013).
- **Global-installed MCP-owning sub-agents** — replaced by per-node MCP injection (ADR-004).

---

## 4. doc-19 → Genesis requirements traceability

solutions-copilot's `19-workflows-orchestration-deferred.md` is effectively
Genesis's requirements doc. Mapping:

| doc-19 element | Genesis realization |
|---|---|
| Multi-step flow definition (steps, per-step agent, per-step steering) | Workflow = LangGraph graph; nodes pick MCP + prompt (Phases 2/6) |
| Human-approval-required steps | HITL mode 1 approval gates (Phase 5, hitl-design.md) |
| Durable, resumable state | SQLite checkpointer; pause/resume/edit/fork (Phase 5) |
| Deterministic control flow + defined handoff artifacts | LangGraph edges + blackboard (ADR-010/018) |
| Example dev SDLC pipeline (Jira→design→approve→implement→review→deploy→test) | Flagship `sdlc-pipeline` composed via subgraphs (Phase 8 Wave D) |
| "Real blocker": no reliable agent path to author Appian objects | **`lcp` MCP** authoring node (OD-1 spike; Phase 8 Waves C/D) |
| Constraint: no nesting / lean role agents | N/A — LangGraph orchestrates externally; Kiro per-node only |

---

## 5. Migration source detail (for Phase 8)

The 45 skills, grouped, become the initial workflow backlog:
- **developer (15):** appian-explore, impact-analysis, technical-debt, code-review, design-document, implementation, implementation-summary, feature-breakdown, spike-research, refactor-redeploy, expression-test-generation, knowledge-query, i18n, a11y-fix, database-script-management.
- **tester (3):** test-execution, unit-test, test-data-generation.
- **product-owner (9):** onboarding, explore, feature-inventory, feature-spec, research, cross-app-analysis, feature-impact-analysis, release-review, chat-triage.
- **ux-designer (10):** aurora-compliance, branding-compliance, design-consistency-review, edge-case-analysis, component-decomposition, platform-feasibility-check, create-html-prototype, create-sailwind-prototype, generate-sail, design-to-dev-handoff.
- **devops (4):** pipeline-check, package-management, deployment, promote.
- **documentation (7):** doc-fip, doc-tech-design, doc-adr, doc-perf-review, doc-security-review, doc-arch-overview, generate-erd.
- **shared (5):** sail-reference, sail-code-hygiene, sail-documentation-standards, a11y-audit, guide-appian-docs.

Each skill's `references/` are the authoritative step logic — port them as the
workflow's design source; reuse their instructions in agent-node prompts (fidelity
rule). Tracked in `genesis-workflows/MIGRATION.md`.

---

## 6. Net
Genesis keeps the *content and the proven infrastructure patterns* of
solutions-copilot, discards the *agent-orchestrator and Kiro-IDE packaging*, and
adds the durable LangGraph engine + reliability standard that make the deferred
orchestration finally reliable — plus the LCP-authoring unlock that removes its
stated blocker.
