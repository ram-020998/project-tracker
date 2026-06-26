# 16 — Dashboard / Command Center

**Status:** Proposed (design) · **Builds on:** doc 13 (config app) + doc 14 (plan) · **Surface:** Kiro
IDE extension · **Last updated:** 2026-06-26

> Evolves the one-time installer into a **command center** people open daily: see installed agents
> and their status **scoped to the current workspace or Global**, browse each agent's skills, check
> for updates, and review recent agent activity. The install wizard becomes the **Catalog / Add**
> flow inside this dashboard.

---

## 1. Why
The installer answers "set me up once." A command center answers the recurring questions: *What
agents do I have here? Are they current? What have they been doing? What else can I add?* This is
what turns the extension into a tool, not a setup step.

---

## 2. Scope model (Global vs Workspace) — central concept
Agents/skills can be installed **globally** (`~/.kiro`, available in every project) or **per
workspace** (`<folder>/.kiro`, only that project). The dashboard is **scope-aware**:

- A **scope selector** (dropdown) in the header with two options: **Workspace** and **Global**.
- **Default:** if the dashboard is opened with a folder open, default to **Workspace** (the open
  folder's `.kiro`); if no folder is open, default to **Global** and disable Workspace.
- The selected scope determines **everything the dashboard shows and acts on**:
  - **Installed inventory + status** are read from that scope's `.kiro`.
  - **Install / update / configure** target that scope.
  - **Recent activity** is filtered to that scope (Workspace = sessions whose `cwd` is within the
    workspace folder; Global = all sessions).
- Switching scope re-renders without reopening. Multi-root workspaces use the first folder in v1
  (a per-folder picker is a later enhancement).

```
┌ Solutions Copilot ───────────────  [ Scope: ▼ Workspace (…/gam) ]  [↻ Check updates] ┐
│  Overview · Agents · Catalog · Environments · Connections · Status                    │
```

---

## 3. Surfaces (information architecture)
- **Overview** — for the active scope: installed agents at a glance, an "**N updates available**"
  badge, a recent-activity feed, environment + MCP health summary, and quick actions
  (Add agents, Check updates, Open an agent).
- **Agents** — list of agents **installed in this scope** (+ a hint of what's available to add). Each
  opens an **Agent detail**:
  - **Skills** — the agent's skills with descriptions; installed vs available; per-skill update flag.
  - **Status** — up-to-date / update available (with "what changed").
  - **Recent interactions** — sessions attributed to this agent in scope (metadata; see §6).
  - **Actions** — open the agent, update, configure its MCP secrets / environments.
- **Catalog / Add** — browse everything installable and run the install wizard (doc 13 §5.2 steps)
  targeting the active scope.
- **Environments** · **MCP Connections** · **Status** — as in doc 13.

---

## 4. Installed inventory (per scope)
Read directly from the scope's `.kiro`:
- **Agents** — `*.json` files under `<kiroDir>/agents/` (basename, minus `-prompt.md` siblings);
  classify role vs sub-agent by cross-referencing the manifest.
- **Skills** — directories under `<kiroDir>/skills/<role>/<skill>/` and `skills/shared/<skill>/`.
- **Provenance** — the per-scope **lockfile** `<kiroDir>/.solutions-copilot/installed.lock.json`
  (ref, installedAt, roles, sub-agents, per-file git-blob sha). Written on every install/update.

The dashboard works **offline** for installed inventory (disk only). Remote enrichment (what's
*available* to add, and update status) appears once connected to GitLab.

---

## 5. Update detection
- **Coarse (always):** compare the lockfile `ref` to the latest release tag → "update available."
- **Per-object (preferred):** GitLab's tree API returns each file's **git blob id (sha)**. Compute
  the git-blob sha of each installed file locally and compare to the remote tree's id for the same
  path at the target ref. Differences → exactly which agents/skills changed — **no content download
  needed**. Drives per-skill/agent "update" flags and a "what changed" list.
- Updates re-fetch + regenerate **content only**; secrets and the environment registry are preserved
  (doc 13 §9).

---

## 6. Recent interactions (feasibility confirmed, with caveats)
Kiro persists session history locally — **readable**:
- **CLI:** `~/.kiro/sessions/cli/<uuid>.json` (metadata: `session_id`, `cwd`, `created_at`,
  `updated_at`, `title`) + `<uuid>.jsonl` (transcript).
- **IDE:** under `~/Library/Application Support/Kiro/...` (read in a later slice).

Design decisions:
- **Privacy — metadata only by default.** Show *when*, *which workspace* (`cwd`), and the *title*;
  never surface transcript content unless the user explicitly opens a transcript.
- **Scope filter.** Workspace = sessions whose `cwd` is within the workspace folder; Global = all.
- **Per-agent attribution — discovery item.** The session `.json` has no top-level `agent` field;
  the agent likely lives in `session_state` or the `.jsonl`. v1 ships a **scope-level activity feed**
  (recent sessions in scope); **per-agent** attribution lands after a short spike to locate that
  field. Until then, the Agent-detail "recent interactions" shows scope activity with a note.
- **Robustness.** This is an **undocumented internal format**; parse defensively and degrade
  gracefully (missing/changed fields → hide the feed, never crash).

---

## 7. Data the host computes (per scope)
A single `dashboard` payload powers Overview + Agents:
```ts
interface DashboardData {
  scope: "global" | "workspace";
  kiroDir: string;
  connected: boolean;                 // GitLab manifest loaded?
  agents: Array<{
    name: string;
    kind: "role" | "sub-agent" | "unknown";
    installed: boolean;
    skills: Array<{ name: string; installed: boolean; updatable?: boolean }>;
    status: "up-to-date" | "update-available" | "unknown";
  }>;
  available: string[];                // catalog agents not installed in this scope
  updates: { available: boolean; installedRef?: string; latestTag?: string | null; changed: string[] };
  activity: Array<{ when: string; cwd: string; title: string | null }>;
}
```

---

## 8. Decisions (resolving the open questions)
- **DB1 — Interaction privacy:** **metadata only** by default; explicit opt-in to open a transcript.
- **DB2 — Session source order:** **CLI sessions first** (`~/.kiro/sessions`), IDE sessions later.
- **DB3 — Scope default:** **Workspace when a folder is open**, else Global; selector always present.
- **DB4 — Multi-root:** first folder in v1; per-folder selection later.
- **DB5 — Per-agent attribution:** scope-level activity in v1; per-agent after a session-format spike.

---

## 9. Custom authoring (point 8 — implemented)
Users can extend their setup with **custom** objects, tracked in `<kiroDir>/.solutions-copilot/custom.json`
(the source of truth) and generated into the scoped `.kiro`:
- **Create custom agent** — writes `agents/<name>.json` + `<name>-prompt.md` (dual-surface, v3
  block-style frontmatter) from a template, marked `"x-source": "solutions-copilot-custom"`. Owns its
  own skills group `skills/<name>/`.
- **Add skill (new)** — scaffolds `skills/<agent>/<skill>/SKILL.md`; auto-included via the agent's
  skills glob.
- **Add skill (existing)** — links a catalog skill (`shared/<s>` or `<role>/<s>`) by adding a
  `skill://` resource to the custom agent.
- **Add MCP server** — adds an entry to the custom agent's `mcpServers` (+ `@server` tool + block-style
  frontmatter), with literal `env` values.
- **Survives updates** — `applyCustom()` re-asserts all custom agents/skills after any install/update.
- **Dashboard** — custom agents appear tagged **custom**, included in the inventory (not treated as
  foreign), with their skills.

**v1 scope:** custom skills/MCP attach to **custom agents** (user-owned, safe to regenerate). Adding
overlays onto *managed* agents (so they survive regeneration on both surfaces) is the next increment.

## 10. Relationship to other docs
Extends doc 13 (the wizard becomes Catalog/Add) and doc 14 (adds the dashboard phases, §below).
Update detection relies on the `installed.lock.json` specced in doc 13 §6.4. CI/packaging unchanged
(doc 15).
