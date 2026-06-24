# Powers to Kiro Agents Migration Plan

## Overview

Migrate the **Jarvis** and **Appian Atlas** powers to native Kiro agents, skills, and knowledge bases. This replaces the legacy "powers" system with Kiro's built-in orchestration — enabling multi-agent pipelines, on-demand skill loading, and semantic knowledge retrieval.

**Goals:**

- Reduce context window consumption (large steering files → chunked knowledge base)  
- Enable multi-agent orchestration (parallel research \+ consolidation)  
- Clear separation of concerns (each agent has a focused role)  
- Declarative configuration (JSON configs, no custom framework)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   dev-orchestrator                        │
│   Routes tasks, decomposes work, consolidates results    │
├───────────────┬───────────────┬──────────────┬──────────┤
│    jarvis     │  appian-atlas │   converge   │ coding-  │
│               │               │              │implementer│
│ KB + Live API │ Versioned     │ Synthesizes  │ Writes   │
│ Best practices│ Graph         │ parallel     │ code     │
│ Design docs   │ UUIDs/SAIL    │ outputs      │          │
│ Pipeline      │ Version diffs │              │          │
└───────────────┴───────────────┴──────────────┴──────────┘
```

### Routing Logic

| Task Type | Route To | Pattern |
| :---- | :---- | :---- |
| Spike research | jarvis | Direct |
| Implementation (create objects) | jarvis | Direct |
| Pipeline monitoring | jarvis | Direct |
| KB exploration (architecture, clusters, patterns) | jarvis | Direct |
| Feature breakdown | jarvis | Direct |
| Technical debt audit | appian-atlas | Direct |
| Version history / cross-release diff | appian-atlas | Direct |
| Code review | jarvis \+ appian-atlas | Parallel → converge |
| Design document | jarvis \+ appian-atlas | Parallel research → jarvis writes |
| Impact analysis | jarvis \+ appian-atlas | Parallel → converge |

---

## Agent Definitions

### jarvis

Appian Development Assistant — pre-computed Knowledge Base, live API, best practices, design docs, implementation.

```json
{
  "name": "jarvis",
  "description": "Appian Development Assistant — code review, spike research, implementation, design docs, pipeline monitoring. Powered by pre-computed Knowledge Base.",
  "prompt": "file://~/.kiro/skills/jarvis-menu/SKILL.md",
  "tools": ["read", "write", "shell", "grep", "glob", "code", "web_search", "web_fetch", "knowledge"],
  "allowedTools": ["read", "grep", "glob", "code", "@jarvis"],
  "resources": [
    "skill://~/.kiro/skills/jarvis-*/SKILL.md",
    "skill://~/.kiro/skills/appian-conventions/SKILL.md",
    {
      "type": "knowledgeBase",
      "source": "file://~/.kiro/skills/jarvis-appian-best-practices/content.md",
      "name": "Appian Best Practices",
      "indexType": "best",
      "autoUpdate": true
    }
  ],
  "mcpServers": {
    "jarvis": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--env", "APPIAN_BASE_URL", "--env", "APPIAN_API_KEY", "registry.gitlab.appian-stratus.com/appian/prod/solutions-os/jarvis:latest"],
      "env": {
        "APPIAN_BASE_URL": "$APPIAN_BASE_URL",
        "APPIAN_API_KEY": "$APPIAN_API_KEY"
      }
    }
  }
}
```

**Skills (converted from steering files):**

| Skill | Source | Description |
| :---- | :---- | :---- |
| `jarvis-menu` | `jarvis-menu.md` | Main action router — classifies requests |
| `jarvis-code-review` | `code-review-workflow.md` | Best practices review with execution tracker |
| `jarvis-design-doc` | `design-doc-workflow.md` | KB-first design document creation |
| `jarvis-spike-research` | `spike-research-workflow.md` | Deep-dive investigation with report |
| `jarvis-implementation` | `implementation-workflow.md` | Object creation from design docs |
| `jarvis-implementation-summary` | `implementation-summary-workflow.md` | Package change summary |
| `jarvis-knowledge-query` | `knowledge-query-workflow.md` | Codebase exploration via KB |
| `jarvis-pipeline-check` | `pipeline-check-workflow.md` | CI/CD failure investigation |
| `jarvis-feature-breakdown` | `feature-breakdown-workflow.md` | Feature decomposition |
| `jarvis-t-retriever` | `t-retriever-navigation.md` | T-retriever navigation |
| `jarvis-workspace-rules` | `workspace-rules.md` | Workspace conventions |

**Knowledge Base (large reference material):**

| Entry | Source | Index Type | Why KB |
| :---- | :---- | :---- | :---- |
| Appian Best Practices | `appian-best-practices-checklist.md` (86K) | Semantic (`best`) | Too large for context; only relevant chunks needed per query |

---

### appian-atlas

Appian Atlas Developer — versioned graph traversal, UUIDs, SAIL code, dependency paths, version history.

```json
{
  "name": "appian-atlas",
  "description": "Appian Atlas Developer — technical deep-dive with UUIDs, SAIL code, dependencies, version history, and impact analysis across releases.",
  "prompt": "file://~/.kiro/skills/atlas-explore/SKILL.md",
  "tools": ["read", "write", "shell", "grep", "glob", "code", "knowledge"],
  "allowedTools": ["read", "grep", "glob", "code", "@appian-atlas"],
  "resources": [
    "skill://~/.kiro/skills/atlas-*/SKILL.md",
    "skill://~/.kiro/skills/appian-conventions/SKILL.md"
  ],
  "mcpServers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--env", "GITLAB_TOKEN", "--env", "ATLAS_KB_PROJECT_ID", "--env", "ATLAS_PIPELINE_TRIGGER_TOKEN", "registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest"],
      "env": {
        "GITLAB_TOKEN": "$GITLAB_TOKEN",
        "ATLAS_KB_PROJECT_ID": "13671",
        "ATLAS_PIPELINE_TRIGGER_TOKEN": "$ATLAS_PIPELINE_TRIGGER_TOKEN"
      }
    }
  }
}
```

**Skills (converted from steering files):**

| Skill | Source | Description |
| :---- | :---- | :---- |
| `atlas-explore` | `action-explore.md` | Object exploration, SAIL code, dependencies |
| `atlas-design-document` | `action-design-document.md` | MCP-only design document research |
| `atlas-impact-analysis` | `action-impact-analysis.md` | Dependency graph traversal, blast radius |
| `atlas-code-review` | `action-code-review.md` | SAIL inspection, metrics, coupling |
| `atlas-technical-debt` | `action-technical-debt.md` | Orphaned objects, circular deps, tech debt |
| `atlas-tool-reference` | `tool-reference.md` | MCP tool usage guide |

---

### dev-orchestrator

Coordinates multi-agent workflows — routes tasks, runs parallel research, consolidates outputs.

```json
{
  "name": "dev-orchestrator",
  "description": "Orchestrates Appian development workflows with Jarvis (KB + live API) and Atlas (versioned graph). Routes, parallelizes, and consolidates.",
  "prompt": "You coordinate Appian development tasks. Route based on data needs:\n\n- Pre-computed intelligence (architecture, clusters, patterns, blast radius) → jarvis\n- Live graph traversal (UUIDs, SAIL code, version history, dependency paths) → appian-atlas\n- Best practices validation → jarvis\n- Technical debt analysis → appian-atlas\n- Implementation (create objects) → jarvis\n- Pipeline monitoring → jarvis\n\nFor code review, design docs, and impact analysis: run jarvis and appian-atlas in parallel for complementary perspectives, then consolidate with converge.\n\nDecompose complex tasks into: research → design → implement → review.\nAlways research before implementing. Always review after implementing.\nNever ask one agent to do what the other specializes in.",
  "tools": ["read", "grep", "glob", "subagent"],
  "allowedTools": ["read", "grep", "glob", "subagent"],
  "toolsSettings": {
    "crew": {
      "availableAgents": ["jarvis", "appian-atlas", "converge", "coding-implementer"],
      "trustedAgents": ["jarvis", "appian-atlas", "converge"]
    }
  }
}
```

---

### converge

Synthesizes parallel outputs into a single unified recommendation. Pre-existing skill — no migration needed.

```json
{
  "name": "converge",
  "description": "Universal Synthesis — compares multi-source proposals, surfaces conflicts, and produces one coherent recommendation.",
  "prompt": "file://~/.kiro/skills/converge/SKILL.md",
  "tools": ["read", "grep", "glob", "code"],
  "allowedTools": ["read", "grep", "glob"]
}
```

Full SKILL.md content (click to expand) 

```
---
name: "converge"
description: "Universal Synthesis and Convergence for multi-source proposal comparison, conflict surfacing, decision analysis, and one coherent final recommendation."
---
# Converge — Multi-Source Synthesis, Conflict Surfacing, and Final Recommendation

## Purpose
Use this capability when multiple sources, drafts, plans, or AI outputs overlap, disagree, or compete and the caller needs one coherent recommendation rather than a shallow summary or a Frankenstein merge.

## Primary Objective
Turn overlapping or conflicting material into one defensible recommendation with explicit trade-offs, surfaced conflicts, muted ideas, and a clear rationale for what survived.

## Agent Operating Contract
When emitted as an agent, this capability remains advisory and synthesis-focused.

Mission:
- ingest the provided sources and map overlap, conflict, and gaps
- compare alternatives rigorously instead of collapsing them into vague consensus
- produce one coherent recommendation with explicit decision logic

Responsibilities:
- extract assumptions, strengths, risks, and dependencies per source
- surface material conflicts as decision points
- apply comparison methods such as SWOT, MCDA, and scenarios when useful
- recommend one converged proposal with muted or rejected ideas called out explicitly

## Tool Boundaries
- allowed: inspect source material, compare options, produce synthesis artifacts, and ask for user steering when taste or judgment is required
- forbidden: pretending incompatible ideas fit together cleanly, inventing missing user preferences, or claiming orchestration or runtime-control authority
- escalation: if the conflict is fundamentally about taste, ownership, or policy, stop and ask for the user's choice instead of guessing

## Output Directory
When file output is requested, default to:
- reports/converge/<timestamp>-overlap-map.md
- reports/converge/<timestamp>-decision-analysis.md
- reports/converge/<timestamp>-final-proposal.md

## Invocation Hints
Use this capability when the user asks for any of the following:
- compare these ideas and pick one
- synthesize these documents into one proposal
- converge on the best plan
- tell me what to keep, what to reject, and why
- surface the real conflicts before we decide

## Required Inputs
- a short intent statement
- the source set to compare
- decision criteria and weights when known
- explicit constraints, audience, or success metrics when available

## Required Output
Every substantial response must include:
- Executive Summary
- Overlap Map
- Decision Analysis
- Final Converged Proposal
- Decision Rationale
- Muted / Rejected Ideas
- Risks + Next Experiments
- Open Questions when user steering is still required

## Constraints
- Do not create a Frankenstein merge.
- Do not invent missing preferences.
- Do not hide major conflicts behind bland synthesis language.
- Do not skip the rationale for rejected ideas.
- Do not claim execution authority beyond synthesis and recommendation.

## Core Principles
- Additive, not aggregative: strengthen the proposal instead of gluing everything together.
- Simple made easy: preserve clarity without diluting power or outcomes.
- Human-in-the-loop: the user provides intent, judgment, review, and taste.
- Explicit trade-offs: conflicts are surfaced, not hidden.
- Convergence, not consensus: the best idea wins based on evidence, criteria, and future robustness.

## What Good Looks Like
A strong convergence result should:
- make agreement and disagreement visible
- tell the user what the real decision points are
- choose one coherent path instead of preserving every idea equally
- explain why the final answer is stronger than the discarded pieces
- leave no confusion about what still needs user steering
```

---

### coding-implementer (Template)

Writes Appian SAIL code and objects following project standards. Refine as needed.

```json
{
  "name": "coding-implementer",
  "description": "Writes Appian SAIL code and creates objects following SOLUTIONS coding standards and naming conventions.",
  "prompt": "You are an Appian implementation agent. Write SAIL code and create objects following:\n- SOLUTIONS naming conventions (AS_GSS_, CMGT_, etc.)\n- One object per step, confirm with user before proceeding\n- Reference the design document for structure\n- Use proper error handling and null checks\n- Follow CDT and record type best practices",
  "tools": ["read", "write", "shell", "grep", "glob", "code", "knowledge"],
  "allowedTools": ["read", "grep", "glob", "code"],
  "resources": [
    "skill://~/.kiro/skills/appian-conventions/SKILL.md",
    "skill://~/.kiro/skills/jarvis-implementation/SKILL.md"
  ]
}
```

---

## Shared Skill: Appian Conventions

Referenced by all agents. Contains naming prefixes, bundle structure, and response format standards.

```
---
name: appian-conventions
description: Appian SOLUTIONS naming conventions, object prefixes, bundle structure, and response formatting. Use when writing, reviewing, or discussing Appian objects.
---

# Appian SOLUTIONS Conventions

- Object prefixes: AS_GSS_, CMGT_, QE_, QR_, BL_, FM_, GRD_, CPS_
- Type indicators in names (e.g., _CDT, _RT, _PM, _ER, _INT)
- Bundle naming matches feature/ticket
- Descriptions required on all objects
- Response format: include UUIDs, show dependency direction
```

---

## Pipeline Examples

**Note:** These pipelines are constructed by the `dev-orchestrator` agent at runtime. You do not write this JSON — you give the orchestrator a natural language request (e.g., "Code review for GAMS-1234") and it produces the stage decomposition automatically based on its routing logic.

### Code Review (Parallel \+ Consolidate)

```json
{
  "task": "Code review for GAMS-1234",
  "stages": [
    {
      "name": "review-practices",
      "role": "jarvis",
      "prompt_template": "Review package objects for GAMS-1234 against best practices. Focus on naming, patterns, complexity, and checklist compliance from KB."
    },
    {
      "name": "review-technical",
      "role": "appian-atlas",
      "prompt_template": "Review code quality for GAMS-1234. Focus on SAIL code inspection, dependency coupling, enrichment metrics, and version changes."
    },
    {
      "name": "consolidate",
      "role": "converge",
      "prompt_template": "Consolidate two code review reports for GAMS-1234 into a single unified review. De-duplicate findings, resolve conflicts, assign severity, provide final verdict.",
      "depends_on": ["review-practices", "review-technical"]
    }
  ]
}
```

### Design Document (Parallel Research → Single Writer)

```json
{
  "task": "Design document for GAMS-5678",
  "stages": [
    {
      "name": "research-kb",
      "role": "jarvis",
      "prompt_template": "Research phase only for GAMS-5678. Use KB for architecture, clusters, patterns, impact analysis. Output raw research findings. Do NOT write the design doc."
    },
    {
      "name": "research-history",
      "role": "appian-atlas",
      "prompt_template": "For GAMS-5678, provide version history of affected objects, previous patterns for similar changes, and cross-release dependency evolution."
    },
    {
      "name": "write-design",
      "role": "jarvis",
      "prompt_template": "Write the final design document for GAMS-5678 using research from both sources. Follow design-doc-workflow format. Export to Google Drive.",
      "depends_on": ["research-kb", "research-history"]
    }
  ]
}
```

### Full Feature Lifecycle

```json
{
  "task": "Implement GAMS-9999: Add vendor approval workflow",
  "stages": [
    {
      "name": "research-kb",
      "role": "jarvis",
      "prompt_template": "Research existing vendor patterns, data model, and architecture for {task}"
    },
    {
      "name": "research-deps",
      "role": "appian-atlas",
      "prompt_template": "Trace dependencies for vendor-related objects, version history, and impact for {task}"
    },
    {
      "name": "design",
      "role": "jarvis",
      "prompt_template": "Write design document for {task} using all research. Follow design-doc-workflow.",
      "depends_on": ["research-kb", "research-deps"]
    },
    {
      "name": "implement",
      "role": "coding-implementer",
      "prompt_template": "Implement {task} following the design document.",
      "depends_on": ["design"]
    },
    {
      "name": "review-practices",
      "role": "jarvis",
      "prompt_template": "Review implementation of {task} against best practices.",
      "depends_on": ["implement"]
    },
    {
      "name": "review-impact",
      "role": "appian-atlas",
      "prompt_template": "Run impact analysis on new objects created for {task}.",
      "depends_on": ["implement"]
    },
    {
      "name": "final-report",
      "role": "converge",
      "prompt_template": "Consolidate review findings for {task} into final quality report.",
      "depends_on": ["review-practices", "review-impact"]
    }
  ]
}
```

---

## Usage Patterns

### Pattern 1: Targeted Agent Invocation

Switch directly to the agent that matches your current need. Best when you know exactly what you want and from which data source.

| Goal | Command | Example Prompt |
| :---- | :---- | :---- |
| Research via KB | `/agent jarvis` | "How does the vendor approval flow work in GSS? Show architecture and dependencies." |
| Research via graph | `/agent appian-atlas` | "Trace all dependencies of AS\_GSS\_FM\_addVendors and show version history." |
| Design doc | `/agent jarvis` | "Start design for GAMS-5678" |
| Impact analysis (live) | `/agent appian-atlas` | "What breaks if I change AS\_GSS\_ER\_getVendorStatus?" |
| Code review (practices) | `/agent jarvis` | "Do code review for GAMS-1234" |
| Code review (technical) | `/agent appian-atlas` | "Review code quality for the objects in bundle GAMS-1234" |
| Technical debt | `/agent appian-atlas` | "Find orphaned objects in GSS" |
| Pipeline check | `/agent jarvis` | "Check pipeline alerts" |
| Implementation | `/agent jarvis` | "Implement GAMS-5678" |

**When to use this pattern:**

- Single-focus task (just research, just review, just explore)  
- You want interactive back-and-forth with one agent  
- You already know which data source has what you need  
- Quick lookups or ad-hoc questions

---

### Pattern 2: Orchestrated Multi-Step Flow

Switch to the orchestrator and describe the end goal. It decomposes, parallelizes, and consolidates automatically.

```
/agent dev-orchestrator
```

| Goal | Example Prompt | What Happens |
| :---- | :---- | :---- |
| Full code review | "Code review for GAMS-1234" | jarvis \+ atlas run in parallel → converge consolidates |
| Design with full context | "Design document for GAMS-5678" | Both research in parallel → jarvis writes final doc |
| Feature lifecycle | "Implement vendor approval workflow for GAMS-9999" | research → design → implement → review (full pipeline) |
| Impact assessment | "What's the full impact of refactoring the billing module?" | jarvis KB blast radius \+ atlas live graph → converge |

**When to use this pattern:**

- Multi-step tasks that span research → action → review  
- You want both data sources (KB \+ graph) contributing to one output  
- You want a consolidated deliverable without manually switching agents  
- Complex tasks where forgetting a step (like impact analysis) would be costly

---

### Choosing Between Patterns

```
Do I need one thing from one source?
  → Yes → Targeted invocation (/agent jarvis or /agent appian-atlas)
  → No  → Do I need multiple perspectives consolidated?
            → Yes → Orchestrator (/agent dev-orchestrator)
            → No  → Do I need a multi-step workflow?
                      → Yes → Orchestrator
                      → No  → Targeted invocation
```

Both patterns use the same agent configs. The difference is only in how you invoke them — directly (you drive) or via orchestrator (it drives).

---

## Migration Tasks

| \# | Task | Description | Depends On |
| :---- | :---- | :---- | :---- |
| 1 | Enable knowledge base | `kiro-cli settings chat.enableKnowledge true` | — |
| 2 | Create shared skill | Write `~/.kiro/skills/appian-conventions/SKILL.md` | — |
| 3 | Convert Jarvis steering → skills | 11 steering files → `~/.kiro/skills/jarvis-*/SKILL.md` with name \+ description frontmatter | — |
| 4 | Convert Atlas steering → skills | 6 steering files → `~/.kiro/skills/atlas-*/SKILL.md` with name \+ description frontmatter | — |
| 5 | Migrate large skill to KB | Best practices checklist (86K) → `knowledgeBase` resource with semantic index | 3 |
| 6 | Set environment variables | `APPIAN_BASE_URL`, `APPIAN_API_KEY`, `GITLAB_TOKEN`, `ATLAS_KB_PROJECT_ID`, `ATLAS_PIPELINE_TRIGGER_TOKEN` in shell profile | — |
| 7 | Create jarvis agent | Write `~/.kiro/agents/jarvis.json` | 3, 5, 6 |
| 8 | Create appian-atlas agent | Write `~/.kiro/agents/appian-atlas.json` | 4, 6 |
| 9 | Create dev-orchestrator agent | Write `~/.kiro/agents/dev-orchestrator.json` | 7, 8 |
| 10 | Create coding-implementer agent | Write `~/.kiro/agents/coding-implementer.json` | 2 |
| 11 | Validate agents | Switch to each agent, verify MCP loads, test skill triggering, test KB search | 7, 8, 9, 10 |
| 12 | Test orchestration | Run a code review pipeline end-to-end through dev-orchestrator | 11 |
| 13 | Remove powers | Delete `~/.kiro/powers/installed/jarvis/` and `~/.kiro/powers/installed/power-appian-atlas-developer/`, update `installed.json` | 12 |

---

## Overlap Resolution Reference

| Capability | Jarvis Strength | Atlas Strength | Resolution |
| :---- | :---- | :---- | :---- |
| Code Review | Best practices checklist, KB patterns | SAIL inspection, coupling metrics, enrichment | Parallel → converge |
| Design Document | KB-first research, live SQL, Drive export | Version history, cross-release deps | Parallel research → jarvis writes |
| Impact Analysis | Pre-computed blast radius (1-3 calls) | Live graph traversal, transitive deps | Parallel → converge |
| Exploration | High-level (clusters, architecture, dead code) | Low-level (UUIDs, SAIL code, bundles) | Route by depth needed |

---

## Secrets Management

Kiro resolves `$ENV_VAR` references in agent configs from the shell environment at runtime. There is no built-in vault or keychain integration — secrets must exist as environment variables when the agent loads.

### Recommended Setup: OS Keychain \+ Shell Profile

Store secrets in your OS keychain (encrypted at rest), pull them into the environment at shell startup.

#### Step 1: Store secrets in Keychain (one-time)

**macOS:**

```shell
security add-generic-password -a "$USER" -s "APPIAN_API_KEY" -w "your-key-here"
security add-generic-password -a "$USER" -s "APPIAN_BASE_URL" -w "https://your-instance.appiancloud.com"
security add-generic-password -a "$USER" -s "GITLAB_TOKEN" -w "glpat-xxxx"
security add-generic-password -a "$USER" -s "ATLAS_PIPELINE_TRIGGER_TOKEN" -w "your-token"
```

**Linux (GNOME Keyring):**

```shell
secret-tool store --label="APPIAN_API_KEY" service kiro key APPIAN_API_KEY <<< "your-key-here"
secret-tool store --label="GITLAB_TOKEN" service kiro key GITLAB_TOKEN <<< "glpat-xxxx"
```

**Windows (PowerShell):**

```
Install-Module -Name CredentialManager
New-StoredCredential -Target "APPIAN_API_KEY" -UserName "kiro" -Password "your-key-here"
New-StoredCredential -Target "GITLAB_TOKEN" -UserName "kiro" -Password "glpat-xxxx"
```

#### Step 2: Load secrets in shell profile

Add to `~/.zshrc` (macOS/Linux) or `$PROFILE` (Windows):

**macOS (`~/.zshrc`):**

```shell
export APPIAN_BASE_URL=$(security find-generic-password -a "$USER" -s "APPIAN_BASE_URL" -w 2>/dev/null)
export APPIAN_API_KEY=$(security find-generic-password -a "$USER" -s "APPIAN_API_KEY" -w 2>/dev/null)
export GITLAB_TOKEN=$(security find-generic-password -a "$USER" -s "GITLAB_TOKEN" -w 2>/dev/null)
export ATLAS_PIPELINE_TRIGGER_TOKEN=$(security find-generic-password -a "$USER" -s "ATLAS_PIPELINE_TRIGGER_TOKEN" -w 2>/dev/null)
export ATLAS_KB_PROJECT_ID="13671"
```

**Linux (`~/.zshrc` or `~/.bashrc`):**

```shell
export APPIAN_API_KEY=$(secret-tool lookup service kiro key APPIAN_API_KEY 2>/dev/null)
export GITLAB_TOKEN=$(secret-tool lookup service kiro key GITLAB_TOKEN 2>/dev/null)
```

**Windows (`$PROFILE`):**

```
$env:APPIAN_API_KEY = (Get-StoredCredential -Target "APPIAN_API_KEY").GetNetworkCredential().Password
$env:GITLAB_TOKEN = (Get-StoredCredential -Target "GITLAB_TOKEN").GetNetworkCredential().Password
```

#### How it works end-to-end

```
Shell starts
  → ~/.zshrc pulls secrets from Keychain into env vars
    → Kiro agent starts, reads $APPIAN_API_KEY from env
      → Docker container receives the secret via --env flag
```

#### Benefits

- Secrets encrypted at rest (OS keychain)  
- Not stored in plain text in dotfiles (only the retrieval command is in the profile)  
- Available in every terminal session automatically  
- No additional tools required beyond the OS-native keychain

---

## Key Principles

- **Skills are cheap, agents are expensive** — skills load on demand; agents spin up Docker containers and full sessions  
- **Parallel over sequential** — when both agents add value, run them simultaneously and consolidate  
- **Single source of truth** — shared conventions live in one skill, not duplicated across agents  
- **Knowledge base for large reference** — anything over 10K that's only partially relevant per query goes in the KB  
- **Trust boundaries** — jarvis and appian-atlas are trusted sub-agents (read-focused); coding-implementer requires approval (writes code)  
- **Environment variables over secrets in config** — all credentials via `$ENV_VAR` references

