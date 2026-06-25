# 01 — Approved Approach & Decisions

## 1. Background

The *Solutions OS Revamp Plan* proposed four large changes: (a) merge Atlas + Jarvis into one
read-only Intelligence MCP, (b) introduce a single orchestrator agent, (c) restructure the repo,
and (d) a global `setup.sh` bootstrap. After review, a **reduced, de-risked subset** was approved
for immediate build under a new repo, `solutions-copilot`.

## 2. The approved subset

1. **Keep Atlas and Jarvis MCP separate** (defer the merge). The merge was the highest-coordination,
   highest-risk item — it required two owners to commit to a unified tool namespace and a routing
   layer. Deferring it unblocks everything else. A routing layer can be added later without
   re-architecting.
2. **Agents + Skills, no powers.** Move fully to the agents model. Every existing power becomes one
   or more **skills** that an agent uses to complete tasks.
3. **New repo for working tooling.** `solutions-copilot` holds agents, skills, configuration, steering,
   and MCP wiring. `solutions-os` becomes documentation + product knowledge only.
4. **Role-based agents.** One agent per role: **Product Owner, UX Designer, Developer, Tester**.
   Each role's individual functionalities become **skills** linked to that agent.
5. **MCP sub-agents.** For Atlas, Jarvis, and Data Generator, build **dedicated sub-agents** that own
   the MCP server. Role agents delegate an information-gathering activity to the relevant sub-agent;
   the sub-agent uses the MCP and returns the result.
6. **Both surfaces:** Kiro CLI and IDE.
7. **Orchestrator deferred.**
8. **Lossless migration.**

## 3. Rationale and one standards-based correction

The model above is consistent with current multi-agent best practice (Anthropic, "Building
multi-agent systems: When and how to use them", Jan 2026), **with one important nuance**:

- **Role agents are correct as *specialization*** (distinct system prompts + tool/skill sets) and as
  **independent entry points the user selects**. ✅
- **Anti-pattern to avoid:** chaining role agents into a sequential pipeline for the *same* feature
  (Developer → Tester → PO hand-offs). Anthropic's experiment found role-split sequential agents
  *"spent more tokens on coordination than on actual work"* (the "telephone game"). Decompose by
  **context boundaries, not by problem type**. Each role agent owns its slice end-to-end.
- **The MCP sub-agent idea is textbook-justified** — but for the right reason: **context protection +
  tool-set specialization**. Anthropic's guidance: an agent with **20+ tools degrades at tool
  selection**. Atlas (~30) and Jarvis (~42) each exceed this, so isolating them behind sub-agents
  keeps 70+ tool schemas out of every role agent. **Data Generator (8 tools) is below the threshold**
  — attach its MCP directly to the agent(s) that need it rather than paying sub-agent coordination cost.
- **Tester maps to the "verification sub-agent" pattern** — the one role-based decomposition Anthropic
  says consistently works, because verification needs minimal context transfer.
- **Mitigate lossy hand-off:** when a role needs full-fidelity output (e.g. Developer needs verbatim
  SAIL, not a paraphrase), the sub-agent must use a strict **return contract** ("return verbatim
  object code + dependency list"). Context isolation only works when extract criteria are well-defined.

## 4. What "no powers" means concretely

- No `POWER.md` files, no `.kiro/powers/` in `solutions-copilot`.
- Existing powers in `solutions-os` (`atlas-developer`, `atlas-sql-forge`, `atlas-ux-designer`,
  `atlas-product-owner`, `atlas-demo-driver`, `jarvis`, etc.) are **decomposed into skills** and
  attached to the appropriate role agent(s).
- A power that bundled an `mcp.json` loses it; the MCP now lives in a dedicated sub-agent.

## 5. Follow-up decisions (2026-06-25, after inventory)

Resolving the open confirmations from the inventory:

1. **`jarvis-smt`** = Database Script Management (SMT). Explores schemas, generates idempotent SQL
   scripts, tracks Change Requests by JIRA ticket, queries app registry/releases/dependency order
   (MariaDB/Oracle/SQL Server/Postgres). **No MCP of its own** — uses Jarvis `query_sql`.
   → becomes a **DevOps** skill (`database-script-management`) delegating to `jarvis-intel`.
2. **`jarvis-verify`** = Automated Test Case Verification. Reads test cases (JIRA/design docs),
   plans via Jarvis KB, executes in the browser via Playwright, verifies at UI + DB layers.
   **No MCP of its own** — orchestrates Jarvis + Playwright.
   → becomes the **Tester** skill **`unit-test`**. Labeled `unit-test` to distinguish it from
   **TEA** (the existing Test Execution Agent = `qe-agent`/INV-A01), which is the Tester role's
   end-to-end `test-execution` capability.
3. **Data Generator → dedicated sub-agent** (`data-generator`), consistent with Atlas/Jarvis.
4. **New DevOps role agent** (5th role) — owns deployment, package management, promotion, pipeline
   checks, and `jarvis-smt` database script management. Deploy/package capability is reached via
   `jarvis-intel` (Jarvis server already has deployment/package handlers); a standalone deploy MCP
   is a later option.
5. **CLI tools deferred** — `erd-generator`, `playwright-deploy`, `fix_table_borders.py`, and the
   `QE-Agent` CI shell are **not migrated now**. Recorded in the matrix as `DEFER`.

Net: **5 role agents** (product-owner, ux-designer, developer, tester, devops) + **3 sub-agents**
(atlas-intel, jarvis-intel, data-generator). No new MCP servers are required for smt/verify.

## 6. Open items (tracked, not blocking)

- Standalone deploy MCP vs. reuse Jarvis deploy handlers (deferred; v1 uses jarvis-intel).
- Orchestrator design (deferred).
- `setup.sh` bootstrap shape for dual-surface (CLI + IDE) install.
- Eventual home for the deferred CLI tools (this repo vs. a separate tools repo).
- Where the actual MCP/CLI *server source* ultimately lives (this repo vs. a separate tools repo).
