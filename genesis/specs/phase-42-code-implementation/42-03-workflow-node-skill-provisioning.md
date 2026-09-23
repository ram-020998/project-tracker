# 42-03 — Workflow-node skill provisioning (inject a Kiro skill into a workflow agent session)

> **Status:** 🟡 DRAFTED. Repo: **genesis** (worker) ± **genesis-core** (an optional `kiro_node(skills=…)` primitive). Implements **ADR-069** (extends ADR-034 beyond chat). Parent: `specs/phase-42-code-implementation.md`.

## 1. Goal

Let a workflow agent node "be spun up with a skill." The implement/verify/heal nodes of `story-implementation` must have the **`appian`** skill (domain rules) available; the implement node additionally the **`appian-object-generation`** skill.

## 2. Mechanism (code-grounded)

- `kiro_node` runs with `cwd = ctx.workspace.root` (the run blackboard). kiro-cli auto-discovers skills from `<cwd>/.kiro/skills/`. → **Provision the declared skill(s) into `ctx.workspace.root/.kiro/skills/<id>/`** before the agent turn; kiro-cli then auto-loads them (auto-activation by `description` + `/name`).
- **Source of the skill files:** the managed skills workspace (`~/.genesis/.kiro/skills/<id>` — already provisioned for chat, ADR-034) and/or the installed genesis-workflows **skills library** (`SkillInstaller`/`skill_catalog`). The worker copies the skill directory tree (SKILL.md + `references/`/`scripts/`/`assets/`) into the run's `.kiro/skills/`.
- **Declaration:** a workflow declares per-node skills. Two options (42-03 picks one):
  - **(A) genesis-only:** the worker reads a `META.node_skills` map (or the node injects skills via a small helper) and provisions before launching the node's turn — no genesis-core change.
  - **(B) genesis-core primitive:** `kiro_node(name, …, skills=["appian", "appian-object-generation"])` — the node factory records the skills; the worker/`AgentProvider` provisions them into cwd before the turn. Additive, `CORE_MAJOR` unchanged. **Recommended** (clean, reusable by any future author/write workflow).

## 3. Constraints

- **Do NOT set `KIRO_HOME`** (the §7 lesson — it relocates the user's agents/sessions/auth). Provision into the run's `<cwd>/.kiro/skills/` only.
- Idempotent + cleaned with the blackboard (the run's `.kiro/skills` is disposable like the rest of the workspace).
- No new write authority — a skill is instruction context (SKILL.md + reference files the agent reads on demand); the object writes come from the `appian-dev-write` MCP tools (42-02), not the skill.
- Skills must be present to provision — a missing skill (library not installed) → a clear, fail-fast error at launch (mirrors the "workflow not installed" 409), not a silent run without the domain rules.

## 4. Tests

- A worker/provider test: declaring `skills=["appian"]` writes `SKILL.md` into the run workspace's `.kiro/skills/appian/` before the turn; a missing skill fails fast.
- (If B) a genesis-core `kiro_node(skills=…)` unit test (records the skills; provider provisions them; behavior-preserving when `skills=[]`).

## 5. Out of scope

Running a skill's bundled `scripts/` (ADR-034 keeps that deferred); chat-side skills (unchanged); a skills marketplace.
