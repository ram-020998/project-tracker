# 02 — Kiro Primitives Reference (verified)

All facts below are confirmed against official Kiro CLI documentation (kiro.dev/docs) as of
2026-06-25. Both Kiro CLI and IDE share the `.kiro/` configuration model.

## 2.1 Agent (custom agent)

- **Format:** JSON file. **Filename (without `.json`) = the agent name.**
- **Locations:** `.kiro/agents/` (workspace) or `~/.kiro/agents/` (global). Local takes precedence.

> ### ⚠️ Dual-surface discovery (CLI vs IDE) — VERIFIED 2026-06-25
> The Kiro **CLI** discovers agents from the **`.json`** file only. The **IDE** discovers agents from
> a **Markdown file with YAML frontmatter** (the **v3 agent format**, kiro.dev/docs/cli/v3/agent-config).
> Confirmed: `kiro-cli` does **not** list a `.md`-only agent. **To appear on both surfaces, each agent
> needs both files** (the proven `project-tracker` pattern): a `.json` whose `prompt` points to a
> sibling `<name>-prompt.md`, and that `-prompt.md` carries the frontmatter (for the IDE) + the
> system-prompt body. Put the `-prompt.md` as a **sibling** of the `.json` in `.kiro/agents/`.
>
> **The IDE (v3) frontmatter is NOT identical to the CLI JSON schema — getting this wrong makes the
> agent silently not load:**
> - `mcpServers` **must be block-style YAML** (not single-line JSON-flow). `args`/`env` use the
>   documented sub-form; `${VAR}` env values expand at runtime:
>   ```yaml
>   mcpServers:
>     appian-atlas:
>       command: docker
>       args: ["run", "--rm", "-i", "...", "<image>"]
>       env:
>         GITLAB_TOKEN: "${GITLAB_TOKEN}"
>   ```
> - **`allowedTools` and `toolsSettings` are NOT v3 frontmatter keys.** v3 uses `tools` (category
>   tags: `read`, `write`, `shell`, `web`, `subagent`, `knowledge`, `@mcp`, `@builtin`, `*`, plus
>   `@server`) and **`permissions`** (capability-based: `builtin`/`shell`/`filesystem`, effect
>   `allow`/`deny`/`ask`, default `ask`). Per-tool auto-approve from the CLI `.json` does not carry
>   over; replicate it with `permissions` if needed (omitting = `ask`/prompt, which is safe).
> - Other v3 keys: `description`, `model`, `resources`, `includeMcpJson`, `welcomeMessage`. `name`
>   in frontmatter overrides the filename (else name = filename without extension).
> - **Symptom that flagged this:** only `developer` (no `mcpServers`) showed in the IDE; the three
>   sub-agents (JSON-flow `mcpServers` + `allowedTools`) did not — fixed by converting to block-style.
>
> Keep the `.json` and the frontmatter in sync (a future `setup.sh` should generate one from the other).

- **Fields** (from the Agent Configuration Reference):

| Field | Purpose |
|---|---|
| `name` | Identifier (optional; derived from filename). |
| `description` | Human-readable purpose. |
| `prompt` | System prompt. Supports inline text **or** `file://./prompt.md` (relative to the config file). |
| `mcpServers` | MCP servers this agent can access (`command`, `args`, `env`, `timeout`, `oauth`). |
| `tools` | Tools available. `"read"`, `"@server"`, `"@server/tool"`, `"*"`, `"@builtin"`. |
| `toolAliases` | Remap tool names to resolve collisions. |
| `allowedTools` | Tools usable **without** a permission prompt. Supports glob patterns. No `"*"`. |
| `toolsSettings` | Per-tool config (e.g. `write.allowedPaths`, `subagent.availableAgents`). |
| `resources` | Context resources: `file://`, `skill://`, or a `knowledgeBase` object. |
| `hooks` | Lifecycle commands (see 2.4). |
| `includeMcpJson` | Whether to also load servers from `~/.kiro/settings/mcp.json` / workspace `mcp.json`. |
| `model` | Model ID (e.g. `claude-sonnet-4`); falls back to default if unavailable. |
| `keyboardShortcut` | Quick-switch shortcut (e.g. `ctrl+d`). |
| `welcomeMessage` | Shown on switching to the agent. |

- **CRITICAL:** Custom agents **do not auto-load skills**. You must add them via `resources` with the
  `skill://` scheme. (Only the default agent auto-loads skills.)
- `/agent generate` can scaffold a config interactively.

## 2.2 Skill

- **Format:** a folder containing **`SKILL.md`** (required) + optional `references/` folder.
- **Locations:** `.kiro/skills/<name>/` (workspace) or `~/.kiro/skills/` (global).
- **`SKILL.md` frontmatter** (only two fields, both required):

```markdown
---
name: impact-analysis
description: Analyze blast radius of a change to an Appian object. Use when asked "what breaks if I change X", for refactoring risk, or pre-change review.
---

## Workflow
... actionable instructions ...
```

| Field | Rules |
|---|---|
| `name` | Lowercase letters, numbers, hyphens only. Max 64 chars. Must match folder name. |
| `description` | "What it does **and** when to use it." Max 1024 chars. Drives auto-activation. |

- **Progressive disclosure (3 tiers):** only `name`+`description` load at startup (~cheap); the full
  `SKILL.md` body loads when the skill is triggered; files in `references/` load only when the body
  directs the agent to them. Keep `SKILL.md` short and actionable; put bulk reference material in
  `references/`.
- **Activation:** automatically when a request matches the `description`, or manually as a slash
  command (`/skill-name`). Supports `$ARGUMENTS` / `${N}` placeholders.
- **Standard:** follows the open Agent Skills spec (agentskills.io) — portable across Claude Code,
  Kiro, Gemini CLI, etc. This is what makes the same skills usable on **both** Kiro surfaces.

## 2.3 Sub-agents (the `subagent` built-in tool)

- **Mechanism:** the built-in **`subagent`** tool (alias `use_subagent`). Confirmed in the Built-in
  Tools reference.
- **Enabling in custom agents:** add `"subagent"` to the agent's `tools` array (or include via
  `"@builtin"`). It is on by default only for the default agent.
- **Config** via `toolsSettings.subagent`:

```json
{
  "tools": ["read", "write", "subagent"],
  "toolsSettings": {
    "subagent": {
      "availableAgents": ["atlas-intel", "jarvis-intel", "data-generator"],
      "trustedAgents": ["atlas-intel", "jarvis-intel"]
    }
  }
}
```

| Setting | Meaning |
|---|---|
| `availableAgents` | Whitelist of agent **names** that can be spawned. Supports globs (`docs-*`). |
| `trustedAgents` | Subset allowed to run **without** a permission prompt. Supports globs. |

- **Behavior:** up to **4 sub-agents in parallel**, each with its **own isolated context**. A
  sub-agent references another agent config **by name**, inherits that config's tools/permissions,
  and returns findings via the **`summary`** tool. This is exactly the context-isolation boundary we
  use to keep Atlas/Jarvis tool schemas off the role agents.

## 2.4 Steering & Hooks

- **Steering:** always-on markdown in `.kiro/steering/`. Use for cross-cutting directives (e.g.,
  source-routing guidance: "prefer Atlas Cloud for history, Jarvis for live state").
- **Hooks** (agent `hooks` field): `agentSpawn`, `userPromptSubmit`, `preToolUse`, `postToolUse`,
  `stop`. `pre/postToolUse` use a `matcher` on internal tool names (`fs_read`, `fs_write`,
  `execute_bash`, `use_aws`).

## 2.5 Tool Search (alternative to sub-agents for "too many tools")

- Built-in **`tool_search`** tool loads MCP tools **on demand** instead of sending every schema
  upfront — documented ~**85% token reduction**. A lighter complement/alternative to wrapping a
  large MCP in a sub-agent. We may use it for medium MCPs; sub-agents remain preferred for the
  largest (Atlas/Jarvis) where full context isolation is wanted.

## 2.6 MCP configuration

- Servers can be embedded per-agent (`mcpServers`) or declared globally in
  `~/.kiro/settings/mcp.json` / workspace `.kiro/settings/mcp.json` (loaded when `includeMcpJson:true`).
- **Our convention (corrected 2026-06-30):** each heavy MCP server is declared in
  **`.kiro/settings/mcp.json`**, and its **owning sub-agent** is set `includeMcpJson: true` with
  `tools` scoped to just that server (e.g. `@appian-atlas`). **Role agents stay `includeMcpJson: false`
  and carry no MCP** — they delegate to the sub-agents.
  > ⚠️ **Why not embed the server in the sub-agent's own `mcpServers` block?** Verified empirically in
  > the Kiro IDE: **MCP servers embedded in an agent config do NOT start when that agent is spawned as
  > a *sub-agent*** (they only start when the agent is run directly). Servers declared in `mcp.json`
  > *do* reach spawned sub-agents. So MCP-owning sub-agents must source their server from `mcp.json`
  > (workspace-scoped works) + `includeMcpJson:true`, not from an embedded block. See doc 11 §6.5.

## Sources
- Agent configuration reference — kiro.dev/docs/cli/custom-agents/configuration-reference/
- Agent Skills — kiro.dev/docs/cli/skills/
- Built-in tools (subagent, tool_search) — kiro.dev/docs/cli/reference/built-in-tools/
- Subagents — kiro.dev/docs/cli/chat/subagents/
- Steering — kiro.dev/docs/cli/steering/
- Agent Skills open spec — agentskills.io/specification
- Anthropic, "Building multi-agent systems: When and how to use them" (2026-01-23)
