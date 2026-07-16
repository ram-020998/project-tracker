# Spike — Kiro Skills over ACP (priority: Chat sessions; workflows later)

> **Status:** COMPLETE — spike proven ✅ (2026-07-16) · **Author:** Genesis agent · **Repos touched:** none (throwaway spike)
> **Question:** Can we use **Kiro Skills** in ACP mode — the way Genesis drives kiro-cli — and specifically inside a **Chat session** (priority 1), with workflow nodes as a later follow-up?
> **Answer:** **Yes.** Skills load and activate over ACP. They are a **filesystem convention** (`.kiro/skills/`), not an ACP wire parameter — so unlike MCP servers (which Genesis injects via `session/new.mcpServers`), a skill is "provided" by **writing its `SKILL.md` folder into a directory kiro-cli reads** (the session `cwd` for workspace scope, or `~/.kiro/skills/` for global). Both **auto-activation (by description)** and **explicit `/skill-name` invocation** fire over ACP.

---

## 1. What Kiro Skills are (from https://kiro.dev/docs/skills/)

A **skill** is a portable instruction package following the open [Agent Skills standard](https://agentskills.io) — a folder containing a required `SKILL.md` plus optional `scripts/`, `references/`, `assets/`:

```
my-skill/
├── SKILL.md          # required — YAML frontmatter + instructions (markdown body)
├── scripts/          # optional executable code
├── references/       # optional docs loaded on demand
└── assets/           # optional templates
```

`SKILL.md` frontmatter: **`name`** (must match the folder; lowercase/hyphens, ≤64 chars), **`description`** (when to use it; Kiro matches this against the user's request, ≤1024 chars), plus optional `license` / `compatibility` / `metadata`.

**Progressive disclosure** (why skills scale better than dumping everything into steering):
1. **Discovery** — at startup Kiro loads only each skill's *name + description*.
2. **Activation** — when a request matches the description, Kiro loads the *full* `SKILL.md`.
3. **Execution** — scripts/reference files are loaded only as needed.

**Scope (filesystem):**
- **Workspace** — `./.kiro/skills/` (relative to the working directory), project-specific.
- **Global** — `~/.kiro/skills/`, available in every workspace. Workspace **overrides** global on name conflict.

**Invocation:** auto-activated when the request matches the `description`, **or** explicitly by typing `/skill-name` (skills appear as slash-commands; trailing text is passed as context).

**How it differs from neighbours (Kiro's own framing):**
- **Steering** = Kiro-specific context that shapes behaviour (`always`/`auto`/`fileMatch`/`manual`). Genesis already uses steering. Not portable, no scripts, no on-demand progressive disclosure.
- **Powers** = bundle **MCP tools + knowledge + workflows**, activate dynamically. The docs *recommend Powers over skills for MCP integrations*.
- **Skills** = portable instruction/script packages, load on-demand, sharable across tools.

---

## 2. The key architectural finding: skills ≠ MCP mechanism

This was the crux of the original question ("can we send skills the same way we pass an MCP to ACP?"). The answer is **no — the mechanisms are fundamentally different**:

| | MCP servers | Skills |
|---|---|---|
| How kiro-cli receives them | **Pushed over the ACP wire** — the `mcpServers` array on the `session/new` request (the SDK populates it from `KiroAgentOptions.mcp_servers`) | **Discovered from the filesystem** — `.kiro/skills/<name>/SKILL.md` |
| Genesis's lever | build the MCP entry list per node/session (already done) | **write files into the session `cwd`** (workspace) or `~/.kiro/skills/` (global); optionally point `KIRO_HOME` at a Genesis-managed dir |
| Loading | connected as a tool server for the session | progressive disclosure (name+desc → full on activation) |
| Invocation | the agent calls the tool | auto by `description` match, or explicit `/skill-name` |
| SDK / protocol change needed | n/a (already supported) | **none** — pure file placement + prompt convention |

There is **no `skills` parameter on `session/new`**. You never "send" a skill over ACP; you place it where kiro-cli looks and it auto-discovers it — the same *class* of mechanism as **steering**.

### Evidence it's supported in our build (kiro-cli 2.12.2)
`--help` shows no skill flag (skills aren't a flag — they're convention), but the binary's own baked-in changelog strings confirm first-class support:
- *"Skills from `.kiro/skills/` and `~/.kiro/skills/` are now automatically available to the default agent"*
- *"Invoke `.kiro/skills` as `/skill-name` slash commands"*
- *"Pass trailing text as context when invoking a skill slash command whose body has no `$ARGUMENTS`/`${N}` placeholders"*
- *"`KIRO_HOME` … overrides the `~/.kiro` directory used for global agents, prompts, **skills**, steering, settings, and sessions"*
- *"Custom agents now inherit default resources (steering, **skills**, AGENTS.md) like built-in agents"*

`~/.kiro/skills/` already exists on this machine.

---

## 3. The spike (proof over real ACP)

**Method.** Wrote a marker skill to a temp workspace's `.kiro/skills/spike-marker/SKILL.md`, pointed a real kiro-cli 2.12.2 ACP session's `cwd` at that workspace (via `kiro_agent_sdk.collect`), and checked whether the skill's signature marker (`SPIKE_SKILL_OK_7f3a9c`) appeared. Three cases:

The marker `SKILL.md`:
```markdown
---
name: spike-marker
description: Use this skill whenever the user asks to run the spike marker check, the skill spike, or asks for the secret handshake token. It defines the exact required response.
---
## Instructions
When this skill is active, the FIRST line of your reply MUST be exactly:
SPIKE_SKILL_OK_7f3a9c
Then add one short sentence confirming the spike-marker skill was loaded.
```

**Results:**

| Test | Drives | Observed | Verdict |
|---|---|---|---|
| **1 — Auto-activation** | prompt matching the `description` ("run the spike marker check / secret handshake token"), `cwd` = workspace with the skill | reply: `SPIKE_SKILL_OK_7f3a9c\n\nThe spike-marker skill loaded successfully…` | **PASS** |
| **2 — Explicit `/spike-marker`** | the slash-command sent as the ACP `session/prompt` text | reply: `SPIKE_SKILL_OK_7f3a9c\nThe spike-marker skill was loaded successfully.` | **PASS** |
| **3 — Control (no skill)** | identical prompt in an empty `cwd` | reply: *"The current directory appears to be empty…"* — **no marker** | **PASS** (no false positive) |

All three turns completed with `error=None`. **Verdict: `auto_activation=True, slash_invocation=True, control_clean=True` → skills work over ACP on both invocation paths.** The spike scripts were throwaway (`/tmp/skill_spike/`, removed).

Notable: the explicit `/skill-name` path — which was the one residual uncertainty (slash-commands are usually a chat-UI feature) — **also works over the raw ACP `session/prompt` channel**, because kiro-cli's agent core interprets it.

---

## 4. Applying this to Genesis **Chat** (PRIORITY 1)

### How chat runs today (grounded in code)
- `ChatManager` runs each session **in-process** with one persistent `KiroACPClient`; in `_ensure_started` the options set **`cwd = str(settings.state_dir)`** (i.e. `~/.genesis`) for both `read_only` and `copilot` modes.
- Capabilities are assembled by `build_chat_mcp` (Atlas + introspection MCP, + the control server in copilot). Behaviour is shaped by a steering preamble (`_STEERING` / `_STEERING_COPILOT`) sent as the first prompt.

### What this means for skills in chat
Because a chat session's `cwd` is `~/.genesis`, kiro-cli will **already auto-discover**:
- **workspace skills** at **`~/.genesis/.kiro/skills/`** (relative to the chat `cwd`), and
- **global skills** at **`~/.kiro/skills/`** (the user's personal ones).

So enabling skills for chat needs **no SDK/protocol change** — only a decision about *where Genesis writes the skill packages* and *how the user manages them*.

### Two provisioning options (recommendation below)
1. **Genesis-managed workspace dir (`~/.genesis/.kiro/skills/`).** Genesis owns this folder; skills placed here are auto-available to every chat session (cwd = state_dir) and are isolated from workflow run workspaces. Simple; leaves the user's personal `~/.kiro/skills/` untouched and *also* available.
2. **`KIRO_HOME` per chat session.** Set `KIRO_HOME=~/.genesis` (or a dedicated dir) for the chat subprocess so Genesis fully controls the skills/steering/agents surface. Cleaner isolation, but it **hides the user's personal `~/.kiro`** skills/agents from chat — probably *not* what we want for an assistant the user personalizes.

**Recommendation for P1:** **Option 1** — a Genesis-managed **`~/.genesis/.kiro/skills/`**, so Genesis-curated skills and the user's own global `~/.kiro/skills/` both apply, with workspace winning on name conflict. No `KIRO_HOME` override.

### Management surface (mirrors MCP/Steering in Settings)
A "Skills" section (Settings, or a Chat side-panel) that lets the user:
- **list** discovered skills (name + description) from `~/.genesis/.kiro/skills/` (and optionally show read-only which global `~/.kiro/skills/` ones are active),
- **create/edit** a `SKILL.md` (name + description + body; optional scripts),
- **import** from a GitHub URL or local folder (Kiro supports this natively), and
- **enable/disable** (move in/out of the skills dir, or a manifest).
This is the same shape as the existing MCP/CLI/steering management (`ResourceManager` + `ResourceFormDialog`), so it fits the app's patterns.

### UX interaction to resolve — the `/` collision (IMPORTANT)
Genesis Chat's composer already intercepts **`/`** to show the **workflow-launch palette** (Phase 13-05). Kiro skills are *also* invoked with **`/skill-name`**, but that is interpreted by the **agent** when the prompt text reaches kiro-cli — a different layer. If a user types `/deploy-check`, today the Genesis palette treats it as a *workflow filter*, and the text may never reach the agent as a skill invocation. Options to reconcile:
- Have the `/` palette list **both** launchable workflows **and** discovered skills (unified command menu), routing a skill pick to send `/skill-name` as the turn text.
- Or reserve a different prefix for skills.
- Or rely on **auto-activation by description** in chat (no explicit slash needed) and keep `/` for workflows. Auto-activation alone is proven and needs no palette change.
**Recommendation:** start with **auto-activation** (zero UX conflict, proven), then optionally fold skills into the `/` palette as a unified command menu.

### Mode / safety fit
Skills are **instruction/context packages** — they carry no inherent mutation power (any *tools* they invoke are still gated by the session's trust/permission model). So skills are safe in **read-only chat** and compatible with the copilot permission model unchanged. A skill that says "run `deploy.sh`" still can't execute anything the session isn't allowed to. Skills that ship `scripts/` would run under the session's existing fs/tool policy — worth a note when we let users import arbitrary skills (supply-chain caution, same as any imported instruction).

### Interaction with the existing steering preamble
Chat already injects a steering preamble on the first prompt. Skills are complementary (on-demand vs always-on). Watch the binary's dedup note — *"Steering files and skills are deduplicated when the working directory equals home"* — our chat `cwd` (`~/.genesis`) is **not** home, so no dedup edge case, but keep it in mind if `cwd` ever changes.

---

## 5. Applying this to Workflows (LATER — priority 2)

Workflow agent nodes run in the **subprocess worker** with `cwd` = the run workspace (blackboard root). So **node-scoped skills** = write `.kiro/skills/<name>/SKILL.md` into that run workspace before the agent turn; kiro-cli auto-discovers them. This is directly analogous to how the reliability/steering context is provided, and would let a workflow ship reusable instruction packs (e.g. the code-review checklist as a `SKILL.md`) rather than inlining everything into the prompt. Deferred per the user's priority; revisit with the **skill-migration backlog** (some legacy solutions-copilot "skills" may map to Kiro `SKILL.md` packages instead of full LangGraph workflows).

---

## 6. Open questions / decisions before building (Chat, P1)

1. **Provisioning dir** — confirm `~/.genesis/.kiro/skills/` (Option 1) vs `KIRO_HOME` isolation. *(Recommend Option 1.)*
2. **Management UX** — Settings "Skills" section vs a Chat side-panel; reuse `ResourceManager` pattern.
3. **Invocation UX** — auto-activation only (v1) vs unifying skills into the `/` composer palette.
4. **Curated vs user skills** — does Genesis ship any built-in skills, or is it purely user-managed to start?
5. **Import trust** — if we expose GitHub/local import, how do we surface that an imported skill can carry `scripts/` (and are those ever executed under chat's policy)?
6. **Discovery/refresh** — kiro-cli discovers skills at **session start**; a live chat session won't pick up a newly-added skill until its client is rebuilt (we already rebuild the client on mode toggle — a "reload skills" affordance may be needed).

---

## 7. Recommendation

Skills are a **low-risk, high-leverage** addition to Chat and require **no SDK/protocol change** — just file provisioning + a management surface. Recommended P1 slice:
- A Genesis-managed **`~/.genesis/.kiro/skills/`** dir + a Settings "Skills" manager (list/create/edit/import/enable).
- Rely on **auto-activation** first (proven, no `/`-palette conflict); consider a unified command palette later.
- Keep global `~/.kiro/skills/` also active (personalization), workspace-wins on conflict.
- Add a "reload skills" affordance since discovery is at session start.

Not started — this document is the exploration record. Next step (if approved): a short Chat-skills spec + phased plan.
