# Action: Create HTML Prototype

Generate a standalone, browser-viewable HTML prototype of an Appian interface using the Sailwind design token system. The output must visually match the real Appian application — including the site chrome (header, navigation, page background).

The output is one or more `.html` files that open directly in any browser — no npm, no React, no build step.

## ⚠️ CRITICAL: Strict Sequential Workflow

This action has **two phases** that MUST execute in strict order. **Phase 1 MUST complete fully before Phase 2 begins.** Do NOT fetch design tokens, do NOT fetch Aurora docs, and do NOT generate any HTML until Phase 1 is complete and the consolidated specification file has been written.

---

## PHASE 1: Fetch, Flatten & Annotate SAIL Code (Atlas MCP only)

**Goal**: Retrieve the complete SAIL code for the interface, recursively resolve ALL custom rule references, produce individual annotated files for each section, then consolidate into a single specification file. This phase does NOT generate any HTML.

All output files go into `{project}/atlas-files/{task-name}/` where `{project}` is the sailwind-starter project path and `{task-name}` is a kebab-case name derived from the interface being prototyped (e.g., `evaluation-summary`, `document-review`).

### Step 1.1: Locate the interface and retrieve top-level SAIL code

Ask the user which interface/dashboard to prototype. Use Atlas MCP tools:
- `search_objects(app, query, "Interface")` to find by name
- `search_bundles(app, query, "action")` to find by feature
- `get_bundle(app, bundle_id, "full")` or `get_object_code(app, uuid)` to retrieve code

Also resolve the site context:
- Call `get_dependencies(app, object_name)` — follow `called_by[]` up to the Site
- Extract: site name, pages/tabs, active page, how the interface is triggered

Create the output directory: `{project}/atlas-files/{task-name}/`

### Step 1.2: Identify all sub-interfaces and sections

From the top-level SAIL code, identify every `rule!` reference. Save as `{project}/atlas-files/{task-name}/rule-tree.md`.

### Step 1.3: Flatten and annotate EACH section individually

For EACH `rule!` reference identified in Step 1.2:

1. **Retrieve its code**: `search_objects(app, rule_name, "Interface")` → `get_object_code(app, uuid)`
2. **Recursively resolve** any nested `rule!` references until only basic Appian components remain
3. **Write an individual file** in `{project}/atlas-files/{task-name}/sections/`

Each file MUST contain:
- The flattened SAIL code (basic components only)
- A **BEHAVIOR & LOGIC** block documenting: what it displays, conditional logic, user interactions, data shape, dynamic behavior

**Basic Appian components** (stop resolving when you reach these):
`a!sideBarLayout`, `a!headerContentLayout`, `a!columnsLayout`, `a!sectionLayout`, `a!cardLayout`, `a!richTextDisplayField`, `a!textField`, `a!stampField`, `a!tagField`, `a!progressBarField`, `a!milestoneField`, `a!gridField`, `a!buttonWidget`, `a!buttonLayout`, `a!tabsField`, `a!imageField`, `a!linkField`, `a!forEach`, `a!localVariables`, `a!if`

### Step 1.4: Consolidate into a single specification file

After ALL individual section files are written, create `{project}/atlas-files/{task-name}/consolidated-spec.sail` that:

1. Starts with a **DATA SUMMARY** listing all data entities and their fields
2. Contains the **complete page-level layout** with all `rule!` calls replaced by their flattened content
3. Preserves **ALL behavior descriptions** from every individual section file as inline comments
4. Includes the **site context** (site name, nav items, active page) at the top

**Phase 1 is complete when:**
- `{project}/atlas-files/{task-name}/rule-tree.md` exists
- All individual section files exist in `{project}/atlas-files/{task-name}/sections/`
- `{project}/atlas-files/{task-name}/consolidated-spec.sail` exists
- Tell the user Phase 1 is done and summarize what was resolved

---

## PHASE 2: HTML Prototype Generation

**Goal**: Read the `atlas-files/{task-name}/` folder from Phase 1, fetch design tokens and Aurora docs, and generate the HTML prototype. This phase MUST NOT call Atlas MCP tools for SAIL code — all SAIL data comes from the atlas-files.

### Step 2.1: Read the atlas-files folder

Read the entire `{project}/atlas-files/{task-name}/` folder:
1. `rule-tree.md` — understand the page structure
2. `sections/*.sail` — understand each section's components and behavior
3. `consolidated-spec.sail` — the complete flattened page with all behavior descriptions

### Step 2.2: Fetch the sailwind-mock skill (MANDATORY)

```
get_git_content("pglevy/agent-skills", "sailwind-mock/SKILL.md")
```

Read this file completely. It contains the exact rules for generating HTML mockups using Sailwind design tokens. You MUST follow ALL rules from this file.

### Step 2.3: Fetch design tokens (MANDATORY)

Fetch the live token file as instructed by the sailwind-mock skill:
```
https://cdn.jsdelivr.net/gh/pglevy/sailwind@main/public/tokens.json
```

Do NOT hardcode token values. Resolve all token aliases to actual values.

### Step 2.4: Fetch Aurora docs for every component type found (MANDATORY)

From the consolidated spec, identify every unique basic Appian component type. Fetch the relevant Aurora doc for each:

| Component types found | Aurora doc to fetch |
|---|---|
| `a!cardLayout` | `get_git_content("appian-design/aurora", "docs/components/cards.md")` |
| `a!buttonWidget`, `a!buttonLayout` | `get_git_content("appian-design/aurora", "docs/components/buttons.md")` |
| `a!tagField` | `get_git_content("appian-design/aurora", "docs/components/tags.md")` |
| `a!tabsField` | `get_git_content("appian-design/aurora", "docs/components/tabs.md")` |
| `a!milestoneField` | `get_git_content("appian-design/aurora", "docs/components/milestones.md")` |
| `a!gridField` | `get_git_content("appian-design/aurora", "docs/layouts/grids.md")` |
| `a!headerContentLayout` | `get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")` |
| `a!stampField` | `get_git_content("appian-design/aurora", "docs/patterns/key-performance-indicators.md")` |
| Charts | `get_git_content("appian-design/aurora", "docs/patterns/charts.md")` |

Also always fetch:
```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
get_git_content("appian-design/aurora", "docs/branding/colors.md")
```

### Step 2.5: Build visual translation table (MANDATORY)

For every component in the consolidated spec, create a translation entry mapping SAIL parameters to CSS properties using token values. Present this table before generating HTML.

### Step 2.6: Generate the HTML files

Following the sailwind-mock SKILL.md rules:
- Each file must be fully self-contained (no external CSS files)
- Derive ALL styles from token values
- No CSS frameworks (no Tailwind, no Bootstrap)
- Font Awesome for icons, never emoji
- Chart.js if charts are needed

Use the behavior descriptions from the atlas-files to implement:
- Conditional rendering
- Dynamic styling based on values
- Correct site chrome (header, sidebar nav, page background)

Save files in `html-prototypes/` in the current working directory. Create the folder if it doesn't exist.

### Step 2.7: Verify completeness (MANDATORY)

Cross-check against the consolidated spec:
- [ ] Every SAIL component from the spec is present in the HTML
- [ ] All behavior descriptions are implemented
- [ ] Site chrome matches (header, sidebar, active page)
- [ ] All colors, spacing, typography from tokens
- [ ] Font Awesome icons (no emoji)
- [ ] HTML files are self-contained
- [ ] Realistic data from the spec's DATA SUMMARY

---

## Rules

1. **STRICT SEQUENTIAL EXECUTION** — Phase 1 must complete fully before Phase 2 begins. No exceptions.
2. **No parallel work** — Do NOT fetch design tokens or Aurora docs while still resolving SAIL code.
3. **Individual files first, then consolidate** — Each section gets its own annotated file before the consolidated file.
4. **Behavior descriptions are mandatory** — Every section file MUST document conditional logic, interactions, data shape, and dynamic behavior.
5. **atlas-files folder is the handoff** — Phase 2 reads SAIL data ONLY from `atlas-files/{task-name}/`.
6. **Resolve ALL rule references** — Chase every `rule!` down to basic Appian components.
7. **sailwind-mock SKILL.md is the authority** — fetch it, follow it for HTML generation rules.
8. **Tokens are the source of truth for styles** — fetch `tokens.json`, resolve aliases, never hardcode.
9. **No CSS frameworks** — derive styles from tokens only.
10. **Fetch Aurora docs for every component type** — mandatory, do not skip.
11. **Build visual translation table** — mandatory before writing HTML.
12. **Every component and behavior in the spec must appear in the HTML** — don't drop components or skip logic.
13. **Font Awesome icons** — never emoji.
14. **Skip backend logic** — ignore `saveInto`, `a!save`, but keep UI components and describe what they would do.
