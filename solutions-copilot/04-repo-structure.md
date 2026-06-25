# 04 — `solutions-copilot` Repository Structure

Targets both Kiro **CLI and IDE** (shared `.kiro/` model). Source-of-truth files live in the repo;
`setup.sh` symlinks them into `~/.kiro/` (global) for cross-project use.

```
solutions-copilot/
├── README.md
├── setup.sh                          # symlinks agents/skills/steering into ~/.kiro; writes MCP creds
├── solutions-copilot.manifest.json   # declarative: what setup.sh installs (single source of truth)
├── environments.json                 # environment URLs only (creds live in .env, gitignored)
├── .env.example
├── CODEOWNERS
├── .gitlab-ci.yml                    # validates manifest + skill/agent shape
│
├── agents/
│   ├── roles/                        # the 5 entry-point role agents
│   │   ├── product-owner.json
│   │   ├── ux-designer.json
│   │   ├── developer.json
│   │   ├── tester.json
│   │   ├── devops.json
│   │   └── documentation.json
│   ├── intelligence/                 # MCP-owning sub-agents
│   │   ├── atlas-intel.json
│   │   ├── jarvis-intel.json
│   │   └── data-generator.json
│   └── orchestrator.json             # DEFERRED (placeholder; not built in v1)
│
├── prompts/                          # system prompts referenced via file:// from agent configs
│   ├── roles/                        # product-owner.md, ux-designer.md, developer.md, tester.md, devops.md, documentation.md
│   └── intelligence/                 # atlas-intel.md, jarvis-intel.md, data-generator.md
│
├── skills/
│   ├── shared/                       # reused across roles — single home, no duplication
│   │   ├── sail-reference/SKILL.md
│   │   ├── aurora-design-system/SKILL.md
│   │   └── a11y-audit/SKILL.md
│   ├── product-owner/
│   ├── ux-designer/
│   ├── developer/
│   ├── tester/
│   ├── devops/
│   └── documentation/                # each: <skill-name>/SKILL.md (+ optional references/)
│
├── steering/                         # always-on: source-routing, conventions, security posture
├── mcp/                              # optional global mcp.json template (servers normally per sub-agent)
└── docs/
    └── adr/                          # repo-scoped architecture decision records
```

## Conventions

- **Agent filename = agent name.** Keep names tool-agnostic (`developer`, not `atlas-developer`).
- **Skill folder name = `name` in frontmatter.** One purpose per skill.
- **Heavy MCPs are embedded in their owning sub-agent**, not in role agents and not (by default) in
  the global `mcp.json`. Role agents set `includeMcpJson: false`.
- **Secrets never committed.** `.env.example` shows the shape; real values in `.env` (gitignored).
- **Dual surface:** the same `agents/`, `skills/`, `steering/` work in CLI and IDE because both read
  the `.kiro/` model and the open Agent Skills format. `setup.sh` handles install for both.

## Manifest (sketch)

`solutions-copilot.manifest.json` declares what is installable, enabling one-command setup and
CI validation that every referenced path exists:

```jsonc
{
  "version": "0.1.0",
  "agents": {
    "roles": ["product-owner", "ux-designer", "developer", "tester", "devops", "documentation"],
    "intelligence": ["atlas-intel", "jarvis-intel", "data-generator"]
  },
  "skills": { "shared": ["sail-reference", "aurora-design-system", "a11y-audit"], "developer": ["..."] },
  "mcp": {
    "atlas":  { "env_keys": ["GITLAB_TOKEN"] },
    "jarvis": { "env_keys": ["APPIAN_ENV_URL", "APPIAN_API_KEY"] },
    "data-generator": { "env_keys": ["APPIAN_ENV_URL", "APPIAN_API_KEY"] }
  },
  "profiles": {
    "engineering": ["developer", "tester", "devops"],
    "product": ["product-owner", "ux-designer", "documentation"],
    "full": "*"
  }
}
```
