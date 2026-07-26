# Atlas Revamp — Powers → Single Agent + Skills

**Objective:** Convert the four Atlas Kiro *Powers* into **one Atlas agent** plus a set of
small, single-purpose *skills*, aligning exactly with the reference agent
(`.kiro/agents/a11y-expert.json`) and reference skills (`.kiro/skills/*`).

**Created:** 2026-07-21
**Status:** Planning — not yet executed

---

## 1. What we are converting

| Power | Location | Nature | Target |
|-------|----------|--------|--------|
| `atlas-demo-driver` | `ai-framework/Engineering/.kiro/powers/` | Records-only data generation (Atlas + DG MCP) | Data-generation skills |
| `atlas-sql-forge` | `ai-framework/Engineering/.kiro/powers/` | Records + bulk-SQL data generation, schema explore (Atlas + DG MCP) | Data-generation skills |
| `atlas-product-owner` | `ai-framework/Product/.kiro/powers/` | Read-only business analysis (Atlas MCP) | PO skills |
| `atlas-ux-designer` | `ai-framework/Product/.kiro/powers/` | Prototyping + design review (Atlas MCP + Git-content tools) | UX skills |

**Out of scope (do not touch / do not wire in):**
- `atlas-developer` and `sail-reference` powers — **not** part of this conversion.
- **ERD generation** — `atlas-sql-forge/steering/action-erd.md` and the `ai-framework/tools/erd-generator` tool are explicitly excluded per direction.
- Any non-Atlas solutions-os asset (Jarvis, ChatTriage, a11y skills, `appian-sail-source`, `playwright`, `chrome-devtools`, `gws`). The Atlas agent wires **only** the two Atlas MCP servers.

---

## 2. Target architecture (single agent)

```
.kiro/
├── agents/
│   └── atlas.json                     # ONE agent, both MCP servers, all atlas-* skills as resources
└── skills/
    ├── atlas-data-workflow/           # shared 6-step methodology (catalog, not a workflow)
    ├── atlas-generate-records/        # data gen → live records (DG MCP)
    ├── atlas-generate-sql/            # data gen → bulk INSERT SQL
    ├── atlas-query-records/           # query + validate records
    ├── atlas-rollback-session/        # session cleanup
    ├── atlas-explore-schema/          # schema exploration
    ├── atlas-app-onboarding/          # PO: app walkthrough
    ├── atlas-explore-feature/         # PO: feature deep-dive
    ├── atlas-release-review/          # PO: release analysis
    ├── atlas-impact-analysis/         # PO: what-would-break
    ├── atlas-feature-spec/            # PO: write a spec
    ├── atlas-research/                # PO: investigate a topic
    ├── atlas-feature-inventory/       # PO: counts + complexity
    ├── atlas-technical-debt/          # PO: orphans / unused
    ├── atlas-cross-app-analysis/      # PO: compare across apps
    ├── atlas-appian-docs/             # PO: Appian platform docs lookup
    ├── atlas-html-prototype/          # UX: Sailwind-Lite HTML
    ├── atlas-sailwind-prototype/      # UX: Sailwind React
    ├── atlas-generate-sail-interface/ # UX: production SAIL via Aurora
    ├── atlas-edge-case-analysis/      # UX: gap analysis on a mockup
    ├── atlas-feasibility-check/       # UX: platform feasibility
    ├── atlas-design-consistency-review/ # UX: match existing patterns
    ├── atlas-component-decomposition/ # UX: split into reusable rules
    ├── atlas-design-handoff/          # UX: design-to-dev brief
    └── atlas-aurora-compliance/       # UX: Aurora design-system check
```

**Placement decision:** skills go under the **repo-root** `.kiro/skills/` and the agent under
**repo-root** `.kiro/agents/`, mirroring the reference `a11y-expert` exactly (agents are
discovered there, and workspace skills there override globals). The four source powers stay
where they are until Phase 5 decides their disposition.

> Total: **25 skills** (1 shared catalog + 5 data-gen + 10 PO + 9 UX) and **1 agent**.

---

## 3. Design principles (locked)

1. **One skill = one action.** Never club two/three actions into one skill. If a power had
   N distinct actions, that becomes N skills. The `description` frontmatter is the only
   trigger — write it to fire on that action's phrasing and *not* its neighbours.
2. **Every skill name starts with `atlas-`** (kebab-case, matches its folder name).
3. **Single agent, both MCP servers.** `appian-atlas` (read-only) + `appian-data-generator`
   (write) are both configured on the one agent. Skills that only read simply never call the
   write tools.
4. **Atlas-only dependencies.** The agent's `tools`/`allowedTools` list contains only
   built-ins (`read`, `write`, `shell`) plus `@appian-atlas` and `@appian-data-generator`.
   Nothing else from solutions-os is referenced.
5. **Seeding document carries the MCP tool knowledge.** The agent `prompt` contains the full
   Atlas MCP tool catalog and the Data Generator MCP tool catalog (what each tool does + when
   to use it), the action router, and the shared cross-cutting principles. Individual skills
   assume the tools exist and focus on *their* workflow.
6. **Progressive disclosure.** `SKILL.md` bodies stay under ~500 lines; heavy step content,
   templates, and long procedures move into each skill's `references/`. The big data-gen
   step files (`step-1`…`step-5`) become the shared `atlas-data-workflow` skill's references
   and are consumed by path (the same cross-skill-by-path pattern the a11y skills use).
7. **Retain all Atlas content.** No functionality is dropped except ERD. Every action file,
   step file, and tool reference from the four powers maps to a skill or a reference file
   (see the mapping in §5). Nothing is summarised away.
8. **Validate every skill.** After writing/editing frontmatter, run the skill-creator
   preflight before calling it done:
   `python3 .kiro/skills/skill-creator/scripts/quick_validate.py <skill-folder>`.

---

## 4. The single agent — `atlas.json` shape

Modeled on `a11y-expert.json`:

```jsonc
{
  "name": "atlas",
  "description": "Appian Atlas expert — explore apps, analyze releases & impact, write specs, prototype UX (HTML/React/SAIL), and generate/rollback test data. Triggers on 'atlas', 'appian app', app names (SourceSelection, VendorManagement…), 'release notes', 'impact', 'prototype', 'generate SAIL', 'test data', 'generate records/SQL', 'rollback'.",
  "includeMcpJson": false,
  "tools":        ["read", "write", "shell", "@appian-atlas", "@appian-data-generator"],
  "allowedTools": ["read", "write", "shell", "@appian-atlas", "@appian-data-generator"],
  "resources": [
    "skill://.kiro/skills/atlas-data-workflow/SKILL.md",
    "… one skill:// line per atlas-* skill (25 total) …"
  ],
  "mcpServers": {
    "appian-atlas":          { /* prod solutions-atlas-mcp-server, project 13490, DATA_PREFIX set */ },
    "appian-data-generator": { /* solutions-atlas-dg-mcp-server, APPIAN_ENV_URL + APPIAN_API_KEY */ }
  },
  "prompt": "…seeding document (see Phase 1)…"
}
```

The two `mcpServers` blocks are copied verbatim from the existing power `mcp.json` files
(`atlas-sql-forge/mcp.json` already contains both, and adds `GITHUB_TOKEN`/`GITLAB_TOKEN`
env for the Git-content + KB access the UX skills need).

---

## 5. Power → skill mapping (retention matrix)

### Data generation (from `atlas-demo-driver` + `atlas-sql-forge`)
| New skill | Source files (retained into it) | MCP used |
|-----------|--------------------------------|----------|
| `atlas-data-workflow` (shared catalog) | `step-0-initialize`, `step-1-workflow-analysis`, `step-2-exemplar-discovery`, `step-3-data-architecture`, `step-4-data-payloads`, `step-5-validation`, `tool-reference-atlas`, `tool-reference-data-generator` | reference only |
| `atlas-generate-records` | `action-generate-data` (records mode) + `step-6-execute` | Atlas + DG |
| `atlas-generate-sql` | `action-generate-data` (sql mode) + `step-6-generate-sql` + `action-bulk-sql` | Atlas (+DG for exemplar reads) |
| `atlas-query-records` | `action-query-and-validate` | DG (+Atlas field map) |
| `atlas-rollback-session` | `action-rollback` | DG |
| `atlas-explore-schema` | `action-explore-schema` | Atlas |
| ~~ERD~~ | `action-erd` | **EXCLUDED** |

### Product Owner (from `atlas-product-owner`)
| New skill | Source action file |
|-----------|--------------------|
| `atlas-app-onboarding` | `action-onboarding` |
| `atlas-explore-feature` | `action-explore` |
| `atlas-release-review` | `action-release-review` |
| `atlas-impact-analysis` | `action-impact-analysis` |
| `atlas-feature-spec` | `action-feature-spec` |
| `atlas-research` | `action-research` |
| `atlas-feature-inventory` | `action-feature-inventory` |
| `atlas-technical-debt` | `action-technical-debt` |
| `atlas-cross-app-analysis` | `action-cross-app-analysis` |
| `atlas-appian-docs` | `guide-appian-docs` |

### UX Designer (from `atlas-ux-designer`)
| New skill | Source action file |
|-----------|--------------------|
| `atlas-html-prototype` | `action-create-html-prototype` |
| `atlas-sailwind-prototype` | `action-create-sailwind-prototype` |
| `atlas-generate-sail-interface` | `action-generate-sail` |
| `atlas-edge-case-analysis` | `action-edge-case-analysis` |
| `atlas-feasibility-check` | `action-platform-feasibility-check` |
| `atlas-design-consistency-review` | `action-design-consistency-review` |
| `atlas-component-decomposition` | `action-component-decomposition` |
| `atlas-design-handoff` | `action-design-to-dev-handoff` |
| `atlas-aurora-compliance` | `action-aurora-compliance-check` |

> The business-language translation rules (PO) and the "all data from Atlas/live only" rule
> (data-gen) are **cross-cutting** — they live in the agent seeding document, not duplicated
> in every skill.

---

## 6. Naming clarifications (avoid trigger collisions)

- `atlas-generate-sql` (bulk **data** INSERT scripts) vs `atlas-generate-sail-interface`
  (UX **SAIL UI** code) — deliberately distinct names; each description states when it does
  **not** apply and points at the other.
- `atlas-aurora-compliance` (UX design-system check) is self-contained via Aurora docs
  fetched through the Atlas MCP Git-content tools — it does **not** depend on the repo's
  `appian-a11y-rules` skill (that would violate the Atlas-only rule).

---

## 7. Phase index

Each phase is scoped to be completable in a single agent session. One document per phase.

| Phase | Document | Deliverable |
|-------|----------|-------------|
| 1 | `01-phase1-agent-and-foundation.md` | `atlas.json` agent (both MCPs, seeding doc, tool catalog) + `atlas-data-workflow` shared skill + conventions |
| 2 | `02-phase2-data-generation-skills.md` | 5 data-gen skills (records, sql, query, rollback, explore-schema) |
| 3 | `03-phase3-product-owner-skills.md` | 10 PO skills |
| 4 | `04-phase4-ux-designer-skills.md` | 9 UX skills (may run as 4a build / 4b review) |
| 5 | `05-phase5-integration-and-validation.md` | Wire all skills into agent `resources`, validate every skill, router smoke-test, decide old-power disposition |

**Dependency order:** Phase 1 → Phase 2 (needs `atlas-data-workflow`). Phases 3 and 4 are
independent of 2 and of each other. Phase 5 is last.

---

## 8. Global conventions (apply in every phase)

- **Skill folder** = `.kiro/skills/<name>/` with `SKILL.md` (required) + optional
  `references/`, `scripts/`, `assets/`. Folder name == frontmatter `name`.
- **Frontmatter** = `name` (kebab-case) + `description` (what it does + when to trigger +
  when NOT to; concrete phrases; no angle brackets; < ~1024 chars).
- **Body** = imperative instructions, explicit output templates, examples with visible
  input/output; < ~500 lines (spill to `references/`).
- **Cross-skill references** by path (e.g. `read .kiro/skills/atlas-data-workflow/references/step-3-data-architecture.md`).
- **Preflight** after every frontmatter change:
  `python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/<name>`.
- **Do not** reference local files for Appian app data in data-gen skills — Atlas KB + live
  env only (carried from the powers' CRITICAL RULES).
