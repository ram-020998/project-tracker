# 11 — Implementation Status & Handoff (read me first)

**Purpose:** get a brand-new agent/engineer fully caught up on the `solutions-copilot` build —
what we're doing, why, exactly what exists today, the hard-won conventions, what's left, and how to
continue. Read this top to bottom, then use **doc 12 (runbook)** to build the next role.

**Last updated:** 2026-06-25 · **Author of this session's work:** (AI pair session with Ram)

---

## 0. The two repositories (don't confuse them)

| Repo | Path | What it is |
|---|---|---|
| **Working repo** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot` | The actual Kiro **agents + skills + config** we are building. This is the product. |
| **Tracker (this repo)** | `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot` | **Documentation only** — approach, decisions, inventory, matrix, this handoff. No code. |
| **Source of legacy assets** | `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os` | The existing repo we migrate FROM (powers/tools across many branches). Read-only source. |

Nothing has been committed or pushed in either repo yet (per session) unless you do it.

---

## 1. What we are building (one paragraph)

`solutions-copilot` is a new repo that holds the working AI tooling for Appian Solutions teams as
**Agents + Skills** (Kiro **CLI and IDE**), with **no "powers"** concept. We migrate everything from
the legacy `solutions-os` repo into: **role agents** (the specialists a user picks), **skills**
(one capability each, owned by a role), and **sub-agents** that own the heavy MCP servers and are
called by role agents. The existing `solutions-os` repo is reduced to documentation/product
knowledge only.

## 2. Architecture (the model)

```
ENTRY: ROLE AGENTS (user picks one)          product-owner · ux-designer · developer ·
  • specialization by prompt + linked skills   tester · devops · documentation
  • carry the `subagent` tool, NO heavy MCP
        │ delegate via `subagent` tool (focused request + explicit return contract)
        ▼
SUB-AGENTS (own the MCP servers)             atlas-intel (read KB) · jarvis-intel (live+write/deploy)
  • isolate big tool schemas from role agents  · data-generator (planned) · integrations (Jira/Google/Playwright)
        │
SHARED KNOWLEDGE                             skills/shared/* (sail-reference, …) + steering/*
```

**Why sub-agents?** Anthropic's multi-agent guidance: an agent with 20+ tools degrades at tool
selection. Atlas (~30 tools) and Jarvis (~42) each exceed that, so we isolate them behind sub-agents
(context protection + tool specialization). Role agents stay lean and delegate.

**Why this is "standard":** verified against official Kiro docs (agents, skills, subagent tool, v3
markdown format) and Anthropic's "Building multi-agent systems" guidance. See doc 02 and 01.

## 3. Locked decisions (full list in doc 01)

1. **Do NOT merge Atlas + Jarvis MCP** (kept separate; revisit later).
2. **Agents + Skills only — no powers.**
3. New repo `solutions-copilot` for tooling; `solutions-os` = docs only.
4. **Six role agents:** product-owner, ux-designer, developer, tester, devops, documentation.
5. **Dedicated sub-agents** own MCP; role agents delegate.
6. **Both surfaces** (CLI + IDE).
7. **Orchestrator deferred.**
8. **Lossless migration** — every legacy artifact is traced (doc 09) and nothing is paraphrased away.
9. `jarvis-smt` → Developer skill; `jarvis-verify` → Tester `unit-test` skill (distinct from TEA).
10. CLI tools (`playwright-deploy`, `fix_table_borders.py`, `QE-Agent` CI) deferred. `atlas-demo-driver` dropped.
11. `data-generator` is a dedicated sub-agent. `erd-generator` → Documentation skill.
12. `a11y-fix`, `database-script-management` → Developer.

## 4. CURRENT STATE — what exists today (verified)

### 4.1 Agents (in `solutions-copilot/.kiro/agents/`) — each is TWO files (see §5.1)

| Agent | Kind | MCP it owns | Status |
|---|---|---|---|
| `developer` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `tester` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `product-owner` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `ux-designer` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `devops` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `documentation` | **role** | none (delegates) | ✅ complete, full capability menu, loads in CLI **and** IDE |
| `atlas-intel` | sub-agent | Atlas (read-only KB) | ✅ loads CLI+IDE |
| `jarvis-intel` | sub-agent | Jarvis (live, **read+write/deploy**) | ✅ loads CLI+IDE |
| `data-generator` | sub-agent | Data Generator (live, **read+write data**) | ✅ built, loads CLI+IDE (live run needs creds/Docker) |
| `integrations` | sub-agent | Jira · Google Workspace · Playwright | ✅ loads CLI+IDE |

### 4.2 Skills

- **Developer (15):** `appian-explore`, `impact-analysis`, `technical-debt`, `code-review`,
  `design-document`, `implementation`, `implementation-summary`, `feature-breakdown`,
  `spike-research`, `refactor-redeploy`, `expression-test-generation`, `knowledge-query`, `i18n`,
  `a11y-fix`, `database-script-management`.
- **Shared (5):** `sail-reference`, `sail-code-hygiene`, `sail-documentation-standards`, `a11y-audit`,
  `guide-appian-docs`.
- **Tester (3):** `test-execution` (TEA, end-to-end ticket QE), `unit-test` (test-case/AC verification,
  ←jarvis-verify), `test-data-generation` (sql-forge 6-step data pipeline). Uses shared `a11y-audit`.
- **Product-owner (9):** `onboarding`, `explore`, `feature-inventory`, `feature-spec`, `research`,
  `cross-app-analysis`, `feature-impact-analysis` (renamed from PO `impact-analysis` to avoid clashing
  with the developer technical skill), `release-review`, `chat-triage` (←ChatTriage). Uses shared
  `guide-appian-docs`.
- **UX-designer (10):** `aurora-compliance`, `branding-compliance` (←Jarvis), `design-consistency-review`,
  `edge-case-analysis`, `component-decomposition`, `platform-feasibility-check`, `create-html-prototype`,
  `create-sailwind-prototype`, `generate-sail`, `design-to-dev-handoff`. Uses shared `a11y-audit` +
  `sail-reference`.
- **DevOps (4):** `pipeline-check` (←Jarvis pipeline-check-workflow, verbatim), `package-management`,
  `deployment`, `promote` (the last three are **authored orchestration** over the Jarvis MCP deploy/
  package handlers — no standalone source workflow existed). `acli-usage` added to `.kiro/steering/`.
- **Documentation (7):** `doc-fip`, `doc-tech-design`, `doc-adr`, `doc-perf-review`, `doc-security-review`,
  `doc-arch-overview` (←feature-docgenie INV-E04; E06 deduped), `generate-erd` (←erd-generator INV-T05).
  Each doc skill carries its workflow + markdown template; shared `document.css` in
  `skills/documentation/_assets/`. Uses shared `sail-documentation-standards` + `guide-appian-docs`.
- **~35,900 lines** of source workflow preserved **verbatim** in skill `references/` (105 reference
  files): developer 37 + tester/a11y 30 + product-owner/shared 12 + ux-designer 10 + devops 1 +
  documentation 15.
- **74 reference files** carry the **Delegation Protocol** header (developer 21 + tester/a11y 24 +
  product-owner 10 + ux-designer 9 + devops 1 + documentation 9).

### 4.3 Config / scaffold (repo root)

- `README.md`, `.gitignore`, `.env.example` (all env keys for atlas/jarvis/integrations/data-gen),
  `environments.json` (empty registry stub), `solutions-copilot.manifest.json` (v0.2.0).
- Steering: `.kiro/steering/source-routing.md`, `.kiro/steering/naming-conventions.md`.

### 4.4 What actually works right now

- **CLI:** `kiro-cli agent list` shows all four agents. Run `kiro-cli --agent developer`.
- **IDE:** all four agents load (fixed the v3 frontmatter — see §6).
- **Functional (read):** `developer` → `atlas-intel` works given `GITLAB_TOKEN` + Docker.
- **Functional (write/live):** needs `APPIAN_BASE_URL`/`APPIAN_API_KEY` + Docker for `jarvis-intel`;
  Jira/Google creds for `integrations`. Skills that need these **explicitly stub** those steps until
  configured (search the SKILL.md for "when configured").
- **NOT yet validated:** a live end-to-end run through jarvis-intel (no live env/creds in session).

## 5. THE CONVENTIONS THAT MATTER (hard-won — follow exactly)

### 5.1 Dual-surface agent files (CLI vs IDE) — CRITICAL

The **CLI reads `.json`**; the **IDE reads a Markdown file with YAML frontmatter** (Kiro **v3**
format). They are NOT the same schema. **Each agent therefore needs BOTH files**, as siblings in
`.kiro/agents/`:

- `<name>.json` — CLI config (`prompt` points to `file://./<name>-prompt.md`).
- `<name>-prompt.md` — YAML frontmatter (for IDE) + system-prompt body.

**v3 frontmatter rules (getting these wrong = agent silently doesn't load in the IDE):**
- `mcpServers` **must be block-style YAML** (NOT single-line JSON-flow). `args` may be an inline
  array; `env` values use `"${VAR}"`.
- **`allowedTools` and `toolsSettings` are NOT v3 keys.** Use `tools` (tags: `read`, `write`,
  `shell`, `subagent`, `@mcp`, `@server`, …) and `permissions` (capability-based: `builtin`/`shell`/
  `filesystem`, effect `allow`/`deny`/`ask`; default `ask`). Per-tool auto-approve does not carry
  from the `.json` — omitting `permissions` means the IDE prompts (safe).
- `name` in frontmatter overrides the filename. Other keys: `description`, `model`, `resources`,
  `includeMcpJson`, `welcomeMessage`.
- The `.json` keeps the full CLI config (incl. `allowedTools`/`toolsSettings`). **Keep `.json` and
  frontmatter in sync.** (A future `setup.sh` should generate one from the other.)

Full detail + the example block: **doc 02 §2.1** (the boxed "Dual-surface discovery" note).

### 5.2 Skill migration pattern — LOSSLESS (follow for every skill)

A legacy power/workflow becomes a skill via:
1. **Copy each source workflow VERBATIM** into the skill's `references/` using
   `git show <ref>:<path> > references/<file>.md`. **Never paraphrase or condense** detailed
   multi-step workflows (some are 800–1000+ lines). A 35-line skill replacing an 863-line workflow is
   a defect.
2. **Prepend the Delegation Protocol** (the boxed block — see doc 05 §5.8 / the existing references)
   to every reference that contains MCP tool calls. Pure-knowledge refs (checklists, grammar, rule
   lists) get no protocol.
3. **Write a thin `SKILL.md`** = frontmatter (`name` == folder, `description` = "what + when",
   ≤1024 chars) + which reference(s) to load + "follow it exactly" + a small tooling-adaptation note.
4. **Consolidate multiple sources as MODES** (e.g. `code-review` = full package review + KB review),
   not by picking one.

Standard + rationale: **doc 05** (esp. §5.8) and **doc 06 §4a**.

### 5.3 The delegation principle — skills NEVER call MCP directly

Role agents have **no Atlas/Jarvis tools**. Every data lookup or mutation in a skill/workflow is a
**delegation to a sub-agent** (`subagent` tool) with a focused request + explicit return contract.
The Delegation Protocol header (in each tool-bearing reference) maps original tool calls →
sub-agent: Atlas/KB → `atlas-intel`; live/SQL/eval/write/deploy → `jarvis-intel`; record data →
`data-generator`; Jira/Docs/browser → `integrations`.

**Single complete delegation + document hand-off (2026-06-29).** Role agents (`developer`, `tester`,
and per doc 12 every future role) **delegate the COMPLETE objective in ONE `subagent` call** — plan all
questions first, pass the real KB **application name** (not an object prefix like `AS_GSS_`) + a return
contract — rather than bouncing per hop. The **analysis sub-agents** (`atlas-intel`, `jarvis-intel`)
run the whole investigation in a single spawn and **write a full analysis document to `.kiro/analysis/`**
(`<agent>-<topic>-<timestamp>.md`), returning its path; the role agent **reads that document** for
loss-free detail (the chat summary is only an orientation). They carry a **scoped `write` tool**
(`toolsSettings.write.allowedPaths: ["./.kiro/analysis/**"]`); `.kiro/analysis/` is gitignored.
`data-generator`/`integrations` return results directly — no document.

### 5.4 Validation commands (use these every time)

```bash
cd /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot
# JSON valid:
python3 -c "import json; json.load(open('.kiro/agents/<name>.json')); print('ok')"
# frontmatter YAML valid (macOS Ruby; pyyaml not installed here):
awk 'BEGIN{c=0} /^---$/{c++; if(c==2)exit; next} c>=1{print}' .kiro/agents/<name>-prompt.md > /tmp/fm.yml
ruby -ryaml -e 'p YAML.load_file("/tmp/fm.yml")'
# exactly 2 frontmatter delimiters (no stray --- in body):
grep -c '^---$' .kiro/agents/<name>-prompt.md
# SKILL.md frontmatter (name==folder, desc length):
# agents discovered (CLI prints to stderr — merge with 2>&1):
kiro-cli agent list 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
```

## 6. Mistakes made this session (so you don't repeat them)

1. **Condensed skills instead of preserving them.** First pass turned an 863-line code-review
   workflow into 35 lines. Fix: verbatim `references/` + thin orchestrator (§5.2). Re-audit any skill
   whose line count is far below its source.
2. **Skills called MCP tools directly.** They must delegate to sub-agents (§5.3). Fixed via the
   Delegation Protocol header on every tool-bearing reference.
3. **IDE agents didn't load.** Cause: `mcpServers` written as single-line JSON-flow + non-v3 keys
   (`allowedTools`) in frontmatter. Fix: block-style YAML `mcpServers`, drop `allowedTools`/
   `toolsSettings` from frontmatter (§5.1).
4. **Prompt files were in a `prompts/` subfolder** — moved to siblings of the `.json` so the IDE
   scans them and relative `file://`/`skill://` paths still resolve.

## 7. What is NOT done (remaining work, roughly prioritized)

1. **Role agents — ALL 6 COMPLETE** ✅ `developer`, `tester`, `product-owner`, `ux-designer`, `devops`,
   `documentation`. Sub-agents `atlas-intel`, `jarvis-intel`, `data-generator`, `integrations` all built.
   The full Agents+Skills role set is in place. Remaining work is hardening/validation (below), not new roles.
2. **Live end-to-end validation** of `jarvis-intel`, `data-generator` + `integrations` (needs creds/Docker).
4. **`setup.sh`** global install (symlink/copy `.kiro/*` → `~/.kiro/*`, write creds, profiles) +
   keep `.json`↔frontmatter in sync.
5. **Environment & secrets registry (BL-1)** and **installer web app (BL-2)** — see doc 10.
6. **Re-audit existing developer skills' descriptions/permissions** if you add v3 `permissions` for
   IDE auto-approve (optional polish).
7. **Decide:** standalone deploy MCP vs. reusing Jarvis deploy handlers (v1 uses jarvis-intel).
8. **Orchestrator** (deferred).

## 8. Next steps (how, briefly — full runbook in doc 12)

To build a role (e.g. `tester`):
1. From **doc 09** get the role's skill list and each skill's legacy source(s).
2. For each skill: `git show` the source(s) → `references/` (verbatim) → prepend Delegation Protocol
   → write thin `SKILL.md` (modes if multi-source).
3. Create the role agent's **two files** (`tester.json` + `tester-prompt.md` with block-style v3
   frontmatter and a capability menu like `developer-prompt.md`).
4. Set the role's `subagent.availableAgents` to the sub-agents it needs.
5. Update `solutions-copilot.manifest.json`.
6. Validate (§5.4) → confirm in IDE.
**Reuse the existing sub-agents** (atlas-intel, jarvis-intel, integrations) — only build
`data-generator` when a role needs it (tester does).

## 9. Open questions / pending decisions

- `i18n` was consolidated to **one skill with 3 modes** (vs 3 skills in the matrix) — confirm OK.
- Jira/Google MCP **package names** (`@anthropic-ai/jira-mcp-server`, `…/google-workspace-mcp-server`)
  came from the team's QE config and look placeholder — **verify they resolve** before relying on them.
- IDE auto-approve: we omitted per-tool approval in frontmatter (default prompt). Add `permissions`
  if the team wants read-only sub-agents to run without prompts.
- `.json` ↔ frontmatter duplication: decide whether `setup.sh` generates one from the other.

## 10. Key file map

**Tracker (`project-tracker/solutions-copilot/`):** README, 01 decisions, 02 Kiro primitives
(+dual-surface note), 03 architecture, 04 repo structure, 05 skill standard (+§5.8 fidelity/
delegation), 06 migration methodology, 07 sequencing, 08 inventory, 09 traceability matrix
(+build-progress), 10 backlog (registries/installer), **11 this doc**, **12 runbook**.

**Working repo (`solutions-copilot/`):** `.kiro/agents/{developer,atlas-intel,jarvis-intel,
integrations}.{json,-prompt.md}`, `.kiro/skills/{developer,shared}/<skill>/SKILL.md(+references/)`,
`.kiro/steering/{source-routing,naming-conventions}.md`, `solutions-copilot.manifest.json`,
`environments.json`, `.env.example`, `README.md`.

## 11. Source-of-truth pointers

- **What goes where:** doc 09 (traceability matrix) is authoritative for skill→role placement.
- **How to build a skill/agent:** doc 05 (skill standard) + doc 02 (primitives) + doc 12 (runbook).
- **Why:** doc 01 (decisions) + doc 03 (architecture).
- **Legacy source:** `solutions-os` on `origin/main` (+ branch-only adds noted in doc 08).
