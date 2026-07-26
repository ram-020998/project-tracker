# Phase 1 — Atlas Agent + Shared Foundation

**Goal (one session):** Create the single `atlas` agent (both MCP servers, seeding document
with full tool catalogs and action router) and the shared `atlas-data-workflow` skill that
the data-generation skills consume. After this phase, the agent loads and the MCP tools are
reachable, even though most `atlas-*` skills don't exist yet (they get added in Phases 2–4;
`resources[]` is finalized in Phase 5).

**Depends on:** nothing. **Blocks:** Phase 2 (needs `atlas-data-workflow`).

---

## Step 1.1 — Create `.kiro/agents/atlas.json`

Copy the two `mcpServers` blocks verbatim from
`ai-framework/Engineering/.kiro/powers/atlas-sql-forge/mcp.json` (it already has both Atlas
and Data Generator), and add `GITHUB_TOKEN` to the `appian-atlas` env (the UX skills fetch
Aurora/Sailwind docs via the MCP Git-content tools). Resulting config:

```jsonc
{
  "name": "atlas",
  "description": "<see §Description below>",
  "includeMcpJson": false,
  "tools":        ["read", "write", "shell", "@appian-atlas", "@appian-data-generator"],
  "allowedTools": ["read", "write", "shell", "@appian-atlas", "@appian-data-generator"],
  "resources": [
    "skill://.kiro/skills/atlas-data-workflow/SKILL.md"
    // Phase 5 appends the remaining 24 skill:// lines. Keep this list in sync as skills land.
  ],
  "mcpServers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run","--rm","-i",
        "--env","GITLAB_TOKEN","--env","ATLAS_KB_PROJECT_ID","--env","ATLAS_DATA_PREFIX","--env","GITHUB_TOKEN",
        "registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest"],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "ATLAS_KB_PROJECT_ID": "13490",
        "ATLAS_DATA_PREFIX": "ai-framework/tools/Atlas/solutions-kb/data",
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      },
      "autoApprove": ["*"]
    },
    "appian-data-generator": {
      "command": "docker",
      "args": ["run","--rm","-i",
        "--env","APPIAN_ENV_URL","--env","APPIAN_API_KEY",
        "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest"],
      "env": {
        "APPIAN_ENV_URL": "${APPIAN_ENV_URL}",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}"
      },
      "autoApprove": ["*"]
    }
  },
  "prompt": "<seeding document — Step 1.2>"
}
```

**Notes**
- `includeMcpJson: false` — matches the reference; the agent's own `mcpServers` are the only
  MCP source, so nothing else from solutions-os leaks in.
- MCP tool names are auto-approved (`"*"`) like the existing powers.
- The Data Generator MCP requires `APPIAN_ENV_URL` + `APPIAN_API_KEY` at runtime; the agent
  still loads without them but the write tools will fail until they're set (document this in
  the seeding doc's setup note).

### Description (frontmatter of the agent)
One paragraph covering all four capability areas so the agent triggers broadly:
> "Appian Atlas expert. Explores Appian applications, analyzes releases and change impact,
> writes feature specs, prototypes UX (HTML / Sailwind React / production SAIL), and
> generates or rolls back workflow-aware test data. Use for anything mentioning 'atlas', an
> Appian application by name, 'release notes', 'impact analysis', 'feature spec', 'prototype',
> 'generate SAIL', 'test data', 'generate records', 'generate SQL', 'schema', or 'rollback'."

---

## Step 1.2 — Author the seeding document (the `prompt` string)

This is the heart of the single-agent design. Structure (Markdown inside the JSON string):

### A. Identity & scope
Short intro: Atlas expert over the Appian Atlas KB + a live Appian environment. States the
two data sources and the **hard rule** (carried from the powers): *for data generation, all
application data comes from the Atlas KB and the live environment only — never read local
files for schema/workflow/business logic.*

### B. Atlas MCP tool catalog (read-only) — full detail
Document every tool with purpose + when to use. Source: the powers' `tool-reference-atlas.md`
and the PO/UX MCP tool lists.

| Category | Tool | What it does / when to use |
|----------|------|----------------------------|
| Discovery | `list_applications` | All parsed apps + feature counts. First call to confirm KB access. |
| Discovery | `get_app_overview(app)` | Full app map (counts, bundles, dependency summary). Call **once** per session. |
| Bundles | `search_bundles(app, query, bundle_type?)` | Find a feature/workflow by name. |
| Bundles | `get_bundle(app, id, detail_level/object_type, limit?)` | Feature structure + members (+SAIL at higher detail). |
| Objects | `search_objects(app, query, object_type?, limit?)` | Find objects/interfaces by name/type. |
| Objects | `get_object_detail(app, name)` | Full object metadata. |
| Objects | `get_object_code(app, name/uuid)` | SAIL code for one object (don't load a whole bundle for one object). |
| Objects | `get_dependencies(app, name)` | Direct dependencies of an object. |
| Graph | `get_dependency_path(app, from, to, direction?)` | How two things connect. |
| Graph | `get_transitive_dependencies(app, name, direction="inbound")` | "What would break?" closure. |
| Graph | `get_hub_objects(app)` | Most-connected/most-shared objects (high blast radius). |
| Version | `list_releases(app)` | Releases + change summaries. |
| Version | `get_changelog(app, release)` | Detailed diff for a release. |
| Version | `compare_releases(app, from, to)` | Diff any two releases. |
| Version | `get_object_history(app, name)` | How one object evolved. |
| Version | `get_object_at_release(app, name, release)` | Object state at a release. |
| Version | `get_release_impact(app, release)` | Which features a release affected. |
| Orphans | `list_orphans(app, object_type?, limit?)` / `get_orphan(app, …)` | Unused/unreachable components. |
| Pipeline | `refresh_knowledge_base(app_name?)` | Trigger KB re-sync (background, 1–2 min). |
| Schema | `get_record_type_map(app)` | ⭐ **First** for data work — table → RT UUID + relationships in one call. |
| Schema | `get_field_map(app)` | UPPER_SNAKE column → camelCase field names. |
| Schema | `get_reference_data(app)` | Ref-table metadata + UUIDs (query values live via DG `query_records`). |
| Schema | `get_app_schema(app, table?, classification?)` | Table defs, columns, PKs. |
| Schema | `get_schema_relationships(app, table?)` | FK graph. |
| Schema | `get_insertion_order(app)` | Topologically sorted creation order. |
| Schema | `get_schema_summary(app)` | Stats + table classification. |
| Git content | `list_git_directory(repo_url, path?, branch?)` | List files in any GitHub repo (Aurora, Sailwind…). |
| Git content | `get_git_content(repo_url, path, branch?)` | Raw file content from GitHub. |
| Git content | `search_git_content(repo_url, query, path_filter?, branch?)` | Keyword search across a repo's markdown. |

Include the efficiency rules verbatim: `get_record_type_map` once, `get_field_map` once,
`get_reference_data` once, use `table_name` filters, prefer `get_app_overview` once/session.

### C. Data Generator MCP tool catalog (write) — full detail
Source: the powers' `tool-reference-data-generator.md`.

| Tool | What it does / when to use |
|------|----------------------------|
| `get_record_properties(uuid)` | Field metadata; **call before any create/update**. `isPrimaryKey`→skip, `isCustomRecordField`→skip, `type`→value format. |
| `create_record(uuid, fields, related_records?)` | Create one record (+atomic nested children via `relationshipName`). PK auto-generated; custom fields auto-skipped. Don't put FK in children. |
| `update_record(uuid, record_id, fields)` | Partial update of specific fields. |
| `delete_record(uuid, record_id)` | Soft delete (`isActive=false`). Children before parents. |
| `query_records(uuid, filters?, paging_info?)` | Query. Operators `= <> > < >= <= in "not in" "is null" "not null" "starts with" "ends with"`. **Do not pass `selected_fields`** by default. Paging is 1-based. |
| `list_users()` | Available usernames; call **once**; use exact strings for User fields. |
| `get_session()` | All records created this session (verify / preview before rollback). |
| `rollback_session(confirm)` | `confirm:false`→preview, `confirm:true`→reverse-order soft delete of the session. |

Include type-conversion table (Text/Integer/Decimal/Boolean/Date/Datetime/User) and the
related-records JSON shape verbatim from the power.

### D. Action router (→ skills)
A table mapping request patterns to the skill to load. Cover all 25 skills. Example rows
(fill in every skill in the final write):

| Request pattern | Skill |
|-----------------|-------|
| "create records / test data / evaluation in status X", ≤50, records | `atlas-generate-records` |
| "bulk / SQL / performance data / 100+ rows / SQL script" | `atlas-generate-sql` |
| "query records / find records / verify what was created" | `atlas-query-records` |
| "rollback / undo / clean up / show session" | `atlas-rollback-session` |
| "what tables / schema / valid statuses / fields of X" | `atlas-explore-schema` |
| "what does this app do / walk me through" | `atlas-app-onboarding` |
| "how does feature X work / show me Y / find Z" | `atlas-explore-feature` |
| "what changed / release notes / what's new" | `atlas-release-review` |
| "what would break / impact of changing X / risk" | `atlas-impact-analysis` |
| "write a spec / document this feature / create a story" | `atlas-feature-spec` |
| "research X / investigate / options" | `atlas-research` |
| "how many features / most complex / breakdown" | `atlas-feature-inventory` |
| "unused / technical debt / cleanup candidates" | `atlas-technical-debt` |
| "do other apps have X / compare apps" | `atlas-cross-app-analysis` |
| "how does Appian handle X / Appian docs" | `atlas-appian-docs` |
| "HTML prototype / quick mockup" | `atlas-html-prototype` |
| "React / Sailwind prototype / high-fidelity" | `atlas-sailwind-prototype` |
| "generate SAIL / build a form/dashboard/record view" | `atlas-generate-sail-interface` |
| "edge cases / what's missing / unhandled states" | `atlas-edge-case-analysis` |
| "is this possible / feasibility / can SAIL do this" | `atlas-feasibility-check` |
| "consistency / match existing / does this fit" | `atlas-design-consistency-review` |
| "decompose / break down / reusable rules" | `atlas-component-decomposition` |
| "handoff / for developers / implementation brief" | `atlas-design-handoff` |
| "Aurora check / design-system compliance / standards" | `atlas-aurora-compliance` |

Add a short **menu** block (like the reference agent's) that lists the capability groups
(Data · Product · UX) when the user says "atlas menu" / "atlas help" / "what can you do".

### E. Cross-cutting principles (shared context, stated once)
- **Business-language translation** (for PO-type requests): the full "Atlas says → you say"
  table from `atlas-product-owner/POWER.md`. Only show technical detail when explicitly asked.
- **Data-source hard rule** (for data-gen requests): Atlas KB + live env only.
- **Efficient tool use:** `get_app_overview` once/session; `get_record_type_map`/`get_field_map`/
  `list_users` once; use graph tools for path/impact rather than manual chains.
- **Setup note:** required env vars (`GITLAB_TOKEN`, `ATLAS_KB_PROJECT_ID=13490`,
  `ATLAS_DATA_PREFIX=…solutions-kb/data`, optional `GITHUB_TOKEN`; for writes:
  `APPIAN_ENV_URL`, `APPIAN_API_KEY`).

> Keep the seeding doc focused on *routing + tool knowledge + shared rules*. The actual
> step-by-step of each action lives in its skill, not here.

---

## Step 1.3 — Create the shared `atlas-data-workflow` skill

This mirrors the reference `appian-a11y-rules` pattern: a **shared catalog/methodology**, not
a standalone action. It holds the mode-agnostic 6-step data-generation method that both
`atlas-generate-records` and `atlas-generate-sql` consume.

```
.kiro/skills/atlas-data-workflow/
├── SKILL.md
└── references/
    ├── step-0-initialize.md            # copied from the power
    ├── step-1-workflow-analysis.md     # copied
    ├── step-2-exemplar-discovery.md    # copied
    ├── step-3-data-architecture.md     # copied
    ├── step-4-data-payloads.md         # copied
    ├── step-5-validation.md            # copied
    ├── tool-reference-atlas.md         # copied (schema tools)
    └── tool-reference-data-generator.md# copied (CRUD/session tools)
```

**SKILL.md frontmatter (draft):**
```yaml
---
name: atlas-data-workflow
description: "Shared 6-step methodology for workflow-aware Appian test-data generation — initialize workspace, trace the workflow, discover an exemplar, build the data architecture (field maps, reference data, insertion order), plan payloads with field reasoning, and validate coverage/FK integrity. Not a standalone action: it is the catalog that atlas-generate-records and atlas-generate-sql both load before their mode-specific Step 6. Load when generating Appian records or bulk data-gen SQL to get the analysis steps, type-conversion rules, and related-records shape."
---
```

**SKILL.md body:** a concise index of Steps 0–5 (one paragraph each) that points to the
matching `references/step-*.md` for the full procedure, plus the type-conversion table and
the related-records JSON shape. State the mandatory file-gate model (each step must produce
its file before the next). End by directing the caller back to their mode-specific Step 6
skill (`atlas-generate-records` → execute; `atlas-generate-sql` → emit SQL).

**Source of the reference files:** copy the identical `step-0`…`step-5`, `tool-reference-atlas`,
`tool-reference-data-generator` from `atlas-sql-forge/steering/` (superset of demo-driver).
Preserve content verbatim (retention requirement) — only adjust any cross-file pointers that
referenced the old power layout.

---

## Step 1.4 — Validate

```bash
python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/atlas-data-workflow
```
Fix anything flagged. Confirm `atlas.json` is valid JSON (e.g. `python3 -m json.tool atlas.json`).

---

## Phase 1 exit criteria
- [ ] `.kiro/agents/atlas.json` exists, valid JSON, both MCP servers present, tools list is
      Atlas-only, seeding doc contains both full tool catalogs + router + shared principles.
- [ ] `.kiro/skills/atlas-data-workflow/` exists with SKILL.md + 8 reference files, content
      retained verbatim from the source power.
- [ ] `quick_validate.py` passes for `atlas-data-workflow`.
- [ ] Agent's `resources[]` at least lists `atlas-data-workflow` (rest added in Phase 5).
