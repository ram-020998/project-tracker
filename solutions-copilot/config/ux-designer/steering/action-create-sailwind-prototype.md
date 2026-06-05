# Action: Create Sailwind React Prototype

Generate a high-fidelity React prototype of an Appian interface using the Sailwind component library inside a [sailwind-starter](https://github.com/pglevy/sailwind-starter) project.

## ⚠️ CRITICAL: Strict Sequential Workflow

This action has **two phases** that MUST execute in strict order. **Phase 1 MUST complete fully before Phase 2 begins.** Do NOT read AGENTS.md, do NOT touch the sailwind-starter project code, and do NOT generate any React code until Phase 1 is complete and the consolidated specification file has been written.

---

## PHASE 1: Fetch, Flatten & Annotate SAIL Code (Atlas MCP only)

**Goal**: Retrieve the complete SAIL code for the interface, recursively resolve ALL custom rule references, produce individual annotated files for each section, then consolidate into a single specification file. This phase does NOT generate any React code.

All output files go into `{project}/atlas-files/{task-name}/` where `{task-name}` is a kebab-case name derived from the interface being prototyped (e.g., `evaluation-summary`, `document-review`).

### Step 1.1: Locate the interface and retrieve top-level SAIL code

Ask the user which interface/dashboard to prototype. Use Atlas MCP tools:
- `search_objects(app, query, "Interface")` to find by name
- `search_bundles(app, query, "action")` to find by feature
- `get_bundle(app, bundle_id, "full")` or `get_object_code(app, uuid)` to retrieve code

Create the output directory: `{project}/atlas-files/{task-name}/`

### Step 1.2: Identify all sub-interfaces and sections

From the top-level SAIL code, identify every `rule!` reference. Each `rule!` is a sub-interface or section of the page. Create a list and save it as `{project}/atlas-files/{task-name}/rule-tree.md`:

```markdown
# Rule Tree: [Interface Name]

## Top Level
- rule!AS_GSS_TMG_CPS_evaluationSummary

## Sub-interfaces
1. rule!AS_GSS_TMG_CPS_evaluationHeader
2. rule!AS_GSS_TMG_CPS_detailsBar
3. rule!AS_GSS_TMG_CPS_vendorsSection
4. rule!AS_GSS_TMG_CPS_evaluationFactors
5. rule!AS_GSS_TMG_CPS_activeTasks
6. rule!AS_GSS_TMG_CPS_settingsPanel
7. rule!AS_GSS_TMG_CPS_descriptionPanel
8. rule!AS_GSS_TMG_CPS_personnelPanel
9. rule!AS_GSS_TMG_CPS_phasesPanel
```

### Step 1.3: Flatten and annotate EACH section individually

For EACH `rule!` reference identified in Step 1.2:

1. **Retrieve its code**: `search_objects(app, rule_name, "Interface")` → `get_object_code(app, uuid)`
2. **Recursively resolve** any nested `rule!` references within it, until only basic Appian components remain
3. **Write an individual file** in `{project}/atlas-files/{task-name}/sections/`

Each file should be named after the section (e.g., `sections/vendors-section.sail`) and MUST contain:

```
/* =============================================================
 * Section: Vendors
 * Source rule: rule!AS_GSS_TMG_CPS_vendorsSection
 * =============================================================
 *
 * BEHAVIOR & LOGIC:
 * - Displays a list of vendors associated with this evaluation
 * - Each vendor card shows: vendor name, sync status tag, CAGE code,
 *   submission date, and task completion percentage with progress bar
 * - Sync status uses a!tagField with conditional styling:
 *   - "Synced" → ACCENT background
 *   - "Not Synced" → NEGATIVE background
 * - Progress bar color is conditional:
 *   - 100% → POSITIVE
 *   - 50-99% → ACCENT
 *   - <50% → WARN
 * - Clicking a vendor card navigates to the vendor detail page
 * - The section header shows the count of vendors in parentheses
 *
 * DATA:
 * - vendors: array of { name, syncStatus, cageCode, submissionDate,
 *   tasksCompleted, totalTasks }
 * ============================================================= */

a!cardLayout(
  contents: {
    ...flattened basic Appian components only...
  }
)
```

**The BEHAVIOR & LOGIC section is critical.** For each section file, document:
- **What it displays** — purpose of this section
- **Conditional logic** — if/else conditions that affect visibility, styling, or content
- **User interactions** — what happens on click, hover, or other actions
- **Data shape** — what data fields this section needs and their types
- **Dynamic behavior** — sorting, filtering, pagination, or state changes

**Basic Appian components** (stop resolving when you reach these):
`a!sideBarLayout`, `a!headerContentLayout`, `a!columnsLayout`, `a!sectionLayout`, `a!cardLayout`, `a!richTextDisplayField`, `a!textField`, `a!stampField`, `a!tagField`, `a!progressBarField`, `a!milestoneField`, `a!gridField`, `a!buttonWidget`, `a!buttonLayout`, `a!tabsField`, `a!imageField`, `a!linkField`, `a!forEach`, `a!localVariables`, `a!if`

### Step 1.4: Consolidate into a single specification file

After ALL individual section files are written, create `{project}/atlas-files/{task-name}/consolidated-spec.sail` that:

1. **Starts with a DATA SUMMARY** listing all data entities and their fields
2. **Contains the complete page-level layout** with all `rule!` calls replaced by their flattened content
3. **Preserves ALL behavior descriptions** from every individual section file as inline comments

```
/* =============================================================
 * CONSOLIDATED PROTOTYPE SPECIFICATION
 * Page: [Page Name]
 * Source: [app name] / [interface name]
 * Generated: [timestamp]
 *
 * DATA SUMMARY:
 * - evaluation: { id, title, contractNumber, status, ... }
 * - vendors: [{ name, syncStatus, cageCode, ... }]
 * - factors: [{ name, dueDate, progress, ... }]
 * - tasks: [{ title, assignee, factor, dueDate, status }]
 * - settings: { onTheSpotConsensus, reportSignatures, weightedFactors }
 * - personnel: [{ role, name, avatar }]
 * - phases: [{ name, dateRange, status }]
 * - navItems: [{ label, icon, isActive }]
 * - tabs: [{ label, isActive }]
 * ============================================================= */

a!sideBarLayout(
  /* BEHAVIOR: Left sidebar navigation. Active item highlighted.
   * Clicking navigates to that section. */
  sideBarContent: { ... },
  mainContent: {
    a!headerContentLayout(
      /* BEHAVIOR: Page header with contract number + title.
       * Action buttons on right trigger modals. */
      header: { ... },
      contents: {
        a!tabsField(
          /* BEHAVIOR: Tab bar for page-level navigation.
           * Only active tab content is rendered. */
          tabs: { ... }
        )
      }
    )
  }
)
```

**Phase 1 is complete when:**
- `{project}/atlas-files/{task-name}/rule-tree.md` exists
- All individual section files exist in `{project}/atlas-files/{task-name}/sections/`
- `{project}/atlas-files/{task-name}/consolidated-spec.sail` exists
- Tell the user Phase 1 is done and summarize: how many sections were resolved, how many rule references were flattened, and any unresolved rules

---

## PHASE 2: React Prototype Generation (sailwind-starter only)

**Goal**: Read AGENTS.md, read the entire `atlas-files/{task-name}/` folder from Phase 1, and generate the React prototype. This phase MUST NOT call Atlas MCP tools.

### Step 2.1: Read AGENTS.md (MANDATORY — do this FIRST)

Read `{project}/AGENTS.md` completely. This file contains ALL component knowledge, conventions, and patterns needed to translate SAIL components into Sailwind React components.

Also read `{project}/.kiro/steering/sail-components.md` if it exists.

### Step 2.2: Read the atlas-files folder

Read the entire `{project}/atlas-files/{task-name}/` folder:
1. `rule-tree.md` — understand the page structure
2. `sections/*.sail` — understand each section's components and behavior
3. `consolidated-spec.sail` — the complete flattened page with all behavior descriptions

Use the SAIL-to-Sailwind mapping from AGENTS.md to translate each basic Appian component. Use the behavior descriptions to implement conditional rendering, dynamic styling, click handlers, and data filtering.

### Step 2.3: Create the data layer

Create files in `{project}/src/db/` based on the DATA SUMMARY from the consolidated spec:
- One file per entity (e.g., `evaluation.ts`, `vendors.ts`, `tasks.ts`)
- TypeScript interfaces matching the documented field shapes
- Seed data using values from the SAIL code
- Async getter functions

### Step 2.4: Generate the page

Create `{project}/src/pages/{page-name}.tsx`.

**Follow ALL rules from AGENTS.md.** The atlas-files tell you WHAT to build and HOW it should behave; AGENTS.md tells you HOW to build it with Sailwind components.

### Step 2.5: Register routes

Add the page to both:
1. `{project}/src/App.tsx` — route registration
2. `{project}/src/pages/home.tsx` — navigation link

### Step 2.6: Build and verify

```bash
cd {project} && pnpm run build
```

Fix any errors. Do NOT present the prototype until the build passes with zero errors.

### Step 2.7: Report results

Tell the user:
- What was created (page file, data files, route registrations)
- How to preview: `cd {project} && pnpm run dev` → open the page URL
- Any unresolved components or behaviors that couldn't be implemented

---

## Prerequisites

- Node.js 20.19+ or 22.12+ (check with `node -v`)
- pnpm (check with `pnpm -v`; install with `corepack enable`)
- Ask the user for their sailwind-starter project path before starting

---

## Rules

1. **STRICT SEQUENTIAL EXECUTION** — Phase 1 must complete fully before Phase 2 begins. No exceptions.
2. **No parallel work** — Do NOT read AGENTS.md while fetching SAIL code. Do NOT generate React code while still resolving rule references.
3. **Individual files first, then consolidate** — Each section gets its own annotated file in `sections/` before the consolidated file is created.
4. **Behavior descriptions are mandatory** — Every section file MUST document conditional logic, interactions, data shape, and dynamic behavior.
5. **atlas-files folder is the handoff** — Phase 2 reads from `atlas-files/{task-name}/` and AGENTS.md only. It does NOT call Atlas MCP.
6. **Resolve ALL rule references** — Chase every `rule!` down to basic Appian components. If a rule can't be resolved, mark it as `/* UNRESOLVED */` with a description of what it likely does.
7. **AGENTS.md is the authority on Sailwind components** — do not duplicate its guidance in this file.
8. **Every component and behavior in the spec must appear in the prototype** — don't drop components or skip logic.
9. **Data in `src/db/`** — never inline data in page components.
10. **Build must pass** — zero errors required before declaring complete.
11. **Use pnpm** — not npm.
12. **Skip backend logic** — ignore `saveInto`, `a!save`, process model calls, but keep the UI components that trigger them and describe what they would do in comments.
