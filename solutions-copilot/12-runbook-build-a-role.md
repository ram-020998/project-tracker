# 12 — Runbook: Build a Role (step by step)

This is the exact, repeatable procedure to build a role agent and its skills, using the patterns
proven on the Developer role. **Read doc 11 first.** Templates below are copy-paste ready.

Paths:
- `KB=/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot`  (working repo)
- `SRC=/Users/ramaswamy.u/repo-gitlab/appian/solutions-os`           (legacy source, read-only)

> **Golden rules:** (1) preserve source workflows **verbatim** in `references/`; (2) skills **delegate**
> to sub-agents, never call MCP directly; (3) every agent needs **two files** (`.json` + `-prompt.md`);
> (4) `mcpServers` in frontmatter is **block-style YAML**; (5) validate after each step.

---

## Step 0 — Plan the role from the matrix

Open **doc 09 (traceability matrix)**. For your role (e.g. `tester`) collect:
- the role's **skill list** (the role row + the per-INV rows that target that role),
- each skill's **legacy source file(s)** (path on `solutions-os` `origin/main`, or a `dev/<branch>`),
- which **sub-agents** the role needs (atlas-intel / jarvis-intel / data-generator / integrations).

Example — **tester**: skills `test-execution` (TEA, from `.kiro/agents/qe-agent.md` + QE steering on
branch `dev/dp-test-execution-agent`), `unit-test` (←`jarvis-verify`), `a11y-audit` (shared, ←A11yAudit),
`test-data-generation` (←sql-forge data steps / data-generator). Sub-agents: atlas-intel, jarvis-intel,
**data-generator** (build it — Step 6b), integrations (Playwright/Jira).

## Step 1 — Inventory the sources (confirm sizes)

```bash
cd "$SRC"
git ls-tree -r --name-only origin/main | grep -i '<power-or-tool-path>'   # list a power's files
git show origin/main:<path>.md | wc -l                                    # size (skill vs reference?)
git show dev/<branch>:<path> | head                                       # branch-only sources
```
Record sources per skill. If a source has an elaborate Jarvis workflow AND a brief Atlas action,
plan **modes** (preserve both).

## Step 2 — Copy sources VERBATIM into each skill's references

```bash
SK="$KB/.kiro/skills/<role>/<skill>/references"
mkdir -p "$SK"
git -C "$SRC" show origin/main:<path>.md > "$SK/<descriptive-name>.md"
git -C "$SRC" show dev/<branch>:<path>.md > "$SK/<name>.md"   # branch source
wc -l "$SK"/*.md   # sanity: comparable to source
```
Do NOT edit/condense. Pure-reference files (checklists, grammars) also go here verbatim.

## Step 3 — Prepend the Delegation Protocol to tool-bearing references

```bash
cat > /tmp/dp.md <<'EOF'
> ## ⚠️ DELEGATION PROTOCOL (solutions-copilot) — READ FIRST, GOVERNS THIS ENTIRE FILE
>
> This workflow was written for an agent that called Atlas/Jarvis MCP tools directly. In
> solutions-copilot the role agent has NO Atlas/Jarvis tools. Wherever a step says to call an MCP
> tool, instead DELEGATE to the owning sub-agent via the `subagent` tool, then continue the step.
> Routing: KB/code-intelligence -> atlas-intel; live/query_sql/evaluate_sail/write/deploy -> jarvis-intel;
> record/test data -> data-generator; Jira/Google/Playwright -> integrations. Pass a focused request +
> the exact return shape needed. Preserve every other step/template/tracker/rule unchanged. If a
> needed sub-agent isn't configured yet, say so and stub only that step.
>
> ---

EOF
for f in "$SK"/*.md; do
  if grep -qE 'get_app_overview|search_objects|get_bundle|get_object_code|get_dependencies|query_sql|evaluate_sail_expression|get_object_diff|create_package|deploy_package|get_jarvis_config|create_record|get_review_checklist' "$f" \
     && ! grep -q 'DELEGATION PROTOCOL' "$f"; then
    cat /tmp/dp.md "$f" > "$f.tmp" && mv -f "$f.tmp" "$f"; echo "protocol+ $f";
  fi
done
```
Skip pure rule/grammar/SQL-generation refs (no tool calls).

## Step 4 — Write each skill's SKILL.md (thin orchestrator)

`$KB/.kiro/skills/<role>/<skill>/SKILL.md` — `name` MUST equal the folder name; `description` ≤1024,
"what + when" with trigger keywords.

**Single-source template:**
```markdown
---
name: <skill-folder-name>
description: <What it does>. Use for "<trigger 1>", "<trigger 2>", <when>.
---

# <Skill Title>

<One-line purpose.> **Load and follow `references/<file>.md` in full** — do not summarize; it contains
the authoritative multi-step workflow (and any trackers/templates/rules).

Per the Delegation Protocol in the reference, obtain data by delegating: <KB lookups> -> **atlas-intel**;
<live/write/deploy> -> **jarvis-intel** (when configured); <external> -> **integrations**. Never invent
objects/UUIDs/SAIL — use sub-agent results verbatim where exactness matters.
```

**Multi-source / modes template** (see `code-review`, `design-document`, `database-script-management`,
`i18n` for working examples): a table of Mode -> trigger -> `references/<file>.md`, plus an
"always load `<shared-reference>` first" note when one reference is shared by all modes.

## Step 5 — Create the role agent (TWO files)

### 5a. `$KB/.kiro/agents/<role>.json` (CLI)
```json
{
  "name": "<role>",
  "description": "<role one-liner: what it does + which sub-agents it uses>",
  "prompt": "file://./<role>-prompt.md",
  "tools": ["read", "write", "shell", "subagent"],
  "toolsSettings": {
    "subagent": {
      "availableAgents": ["atlas-intel", "jarvis-intel", "integrations"],
      "trustedAgents": ["atlas-intel", "integrations"]
    }
  },
  "resources": [
    "file://../steering/**/*.md",
    "skill://../skills/shared/**/SKILL.md",
    "skill://../skills/<role>/**/SKILL.md"
  ],
  "includeMcpJson": false,
  "welcomeMessage": "<role> agent ready — <short>. Type a request or '/' to pick a skill. Ask 'what can you do?' for the menu."
}
```
Set `availableAgents`/`trustedAgents` to what the role needs (e.g. tester adds `data-generator`).
Keep write-capable `jarvis-intel` OUT of `trustedAgents` (spawning it then prompts).

### 5b. `$KB/.kiro/agents/<role>-prompt.md` (IDE frontmatter + body)
Frontmatter is **v3 block-style**. Role agents have no `mcpServers` (they delegate):
```markdown
---
name: <role>
description: "<same as json>"
tools: ["read", "write", "shell", "subagent"]
toolsSettings: {"subagent": {"availableAgents": ["atlas-intel","jarvis-intel","integrations"], "trustedAgents": ["atlas-intel","integrations"]}}
resources: ["file://../steering/**/*.md", "skill://../skills/shared/**/SKILL.md", "skill://../skills/<role>/**/SKILL.md"]
includeMcpJson: false
welcomeMessage: "<role> agent ready …"
---

# <role> — <Title>

<role mission paragraph.>

## On invocation — show what you can do
When opened with no task (or asked "what can you do / help / menu"), present the Capabilities menu
below and route to the matching skill.

## Capabilities (each is a skill — auto-activates by request, or `/<skill>`)
**<Group A>**
- `<skill>` — <one line>.
...
**Shared reference knowledge** — `sail-reference`, `sail-code-hygiene`, `sail-documentation-standards`.

## Delegate for data/actions
- atlas-intel — read/KB. jarvis-intel — live + write/deploy (prompts). integrations — Jira/Google/Playwright.

## Anti-hallucination & style
Every Appian object cited comes from a sub-agent result with a real UUID; never invent. Use precise
Appian terminology.
```
> Model the menu on `developer-prompt.md`. `toolsSettings` is non-v3 but tolerated; you may omit it
> from frontmatter — the `.json` enforces it for the CLI.

## Step 6 — Sub-agents

### 6a. Reuse existing
`atlas-intel`, `jarvis-intel`, `integrations` already exist — just list them in `availableAgents`.

### 6b. Build `data-generator` (only when a role needs it; same two-file pattern)
`$KB/.kiro/agents/data-generator.json`:
```json
{
  "name": "data-generator",
  "description": "Test/demo data CRUD against a live Appian environment: record properties, create/update/delete/query records, list users, session tracking + rollback.",
  "prompt": "file://./data-generator-prompt.md",
  "mcpServers": {
    "appian-data-generator": {
      "command": "docker",
      "args": ["run","--rm","-i","--env","APPIAN_ENV_URL","--env","APPIAN_API_KEY","registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest"],
      "env": {"APPIAN_ENV_URL": "${APPIAN_ENV_URL}", "APPIAN_API_KEY": "${APPIAN_API_KEY}"}
    }
  },
  "tools": ["read", "@appian-data-generator"],
  "allowedTools": ["@appian-data-generator/get_*", "@appian-data-generator/query_*", "@appian-data-generator/list_*"],
  "includeMcpJson": false
}
```
`data-generator-prompt.md` frontmatter — **block-style** `mcpServers` (copy the shape from
`atlas-intel-prompt.md`); create/update/delete tools should prompt (omit them from any allow list).
`APPIAN_ENV_URL`/`APPIAN_API_KEY` are already in `.env.example`.

## Step 7 — Update the manifest

Edit `$KB/solutions-copilot.manifest.json`: add the role under `agents.roles`, its skills under
`skills.<role>`, any new sub-agent under `agents.intelligence`, new MCP under `mcp`; remove the role
from `planned`.

## Step 8 — Validate (do not skip)

```bash
cd "$KB"
# 1) JSON parses
for j in .kiro/agents/<role>.json solutions-copilot.manifest.json; do
  python3 -c "import json;json.load(open('$j'));print('ok',' $j')"; done
# 2) frontmatter YAML parses + exactly 2 delimiters (macOS Ruby; pyyaml not installed here)
for a in <role>; do
  echo "$a delims=$(grep -c '^---$' .kiro/agents/$a-prompt.md)";
  awk 'BEGIN{c=0}/^---$/{c++;if(c==2)exit;next}c>=1{print}' .kiro/agents/$a-prompt.md > /tmp/fm.yml;
  ruby -ryaml -e 'YAML.load_file("/tmp/fm.yml"); puts "  yaml ok"'; done
# 3) skill frontmatter: name==folder
for d in .kiro/skills/<role>/*/; do s="$d/SKILL.md"; n=$(awk -F': ' '/^name:/{print $2;exit}' "$s");
  [ "$(basename "$d")" = "$n" ] && echo "ok $(basename "$d")" || echo "MISMATCH $d ($n)"; done
# 4) agents discovered (CLI prints to stderr — merge with 2>&1)
kiro-cli agent list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "<role>|data-generator"
```

## Step 9 — IDE check (manual)

Reload the IDE; confirm the role agent appears and, when invoked, shows its capability menu. If it
**doesn't appear**, it's almost always frontmatter: re-check block-style `mcpServers`, no
`allowedTools`/`toolsSettings` parse issue, and exactly two `---` delimiters (no stray `---` in body).

## Step 10 — Record progress

Update **doc 09** (flip the role's skill statuses to done; note deviations) and the working repo
`README.md` status. Capture anything newly learned in **doc 11 §6/§9**.

---

## Appendix — Reference examples to copy from (already built)

- **Role agent w/ capability menu:** `.kiro/agents/developer-prompt.md` + `developer.json`.
- **Read-only sub-agent:** `atlas-intel-prompt.md` + `atlas-intel.json`.
- **Write/deploy sub-agent (approval posture):** `jarvis-intel-prompt.md` + `jarvis-intel.json`.
- **Multi-MCP sub-agent:** `integrations-prompt.md` + `integrations.json`.
- **Single-source skill:** `skills/developer/technical-debt/SKILL.md`.
- **Modes skill:** `skills/developer/code-review/SKILL.md`, `database-script-management/SKILL.md`.
- **Verbatim references + protocol:** `skills/developer/code-review/references/`.
- **Pure-knowledge shared skill:** `skills/shared/sail-reference/`.
