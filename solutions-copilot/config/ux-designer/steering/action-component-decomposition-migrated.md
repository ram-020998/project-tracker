# Action: Component Decomposition Plan

Analyze a complex interface mockup and produce a recommended breakdown into reusable SAIL rules or sub-interfaces — with naming conventions matching the app's existing patterns, shared vs. page-specific classification, and a dependency tree.

This action uses Solutions Intelligence MCP tools to analyze how similar interfaces in the target app are structured and decomposed, then recommends a structure that follows those conventions.

## Prerequisites

- A complex interface (SAIL code, HTML prototype, or detailed description)
- The target app name (must exist in Solutions Intelligence knowledge base)
- The feature/bundle this interface belongs to (or will belong to)

---

## Workflow

### Step 1: Gather inputs

Ask the user for:
1. **Interface mockup** — SAIL code, file path, or detailed description, screenshots
2. **App name** — Which application this will be built in
3. **Feature name** — What feature/bundle this belongs to (e.g., "Evaluation Summary", "Case Creation")
4. **Reusability intent** — Are any parts expected to be reused across multiple features?

### Step 2: Analyze the app's existing decomposition patterns

First, understand how the app currently structures its interfaces:

```
solutions-intelligence.get_app_overview(app)
```

Find a complex interface in the same app to use as a structural reference:
```
search_bundles(app, "summary", "page")
search_bundles(app, "dashboard", "page")
```

Pick 2-3 bundles that are similar in complexity to the user's interface:
```
solutions-intelligence.get_bundle(app, bundle_id, object_type="Interface")
```

For each bundle, examine the entry-point interface and its dependencies:
```
solutions-intelligence.get_object_code(app, "entry_point_interface")
solutions-intelligence.get_dependencies(app, "entry_point_interface")
get_transitive_dependencies(app, "entry_point_interface", max_hops=2)
```

### Step 3: Extract the app's naming conventions

From the retrieved interfaces, document:

**Naming patterns:**
- Prefix convention (e.g., `AS_GSS_TMG_CPS_` for app/module/feature)
- Suffix patterns (e.g., `_header`, `_section`, `_card`, `_grid`, `_dialog`)
- Shared component naming (e.g., `SHARED_` prefix or `_common_` infix)
- Expression rule naming for UI helpers

**Structural patterns:**
- How deep is the nesting? (1 level? 2 levels? 3 levels?)
- What size warrants its own rule? (>50 lines? >100 lines? Any section?)
- Are grids always their own rule?
- Are dialogs always their own rule?
- Are headers/footers extracted or inline?

**Dependency patterns:**
- Do sub-interfaces receive data via rule inputs or query their own data?
- Are there shared "display" rules (e.g., a status tag rule used across features)?
- How are constants/CDTs referenced?

### Step 4: Load Aurora structural guidance (MANDATORY)

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
```

Also fetch the relevant layout doc for structural best practices:
```
get_git_content("appian-design/aurora", "docs/layouts/record-views.md")
get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")
```

### Step 5: Decompose the interface

Analyze the user's interface and identify natural decomposition boundaries:

**Decomposition triggers** (when to extract into a separate rule):
1. **Logical section** — A visually distinct section with its own header/purpose
2. **Reusable pattern** — Something that appears multiple times (in this interface or others)
3. **Complexity threshold** — A section with >200 lines of SAIL or >5 nested components
4. **Independent data** — A section that queries/displays its own data set
5. **Conditional block** — A large `showWhen` block that renders a complete sub-view
6. **Dialog content** — Any dialog body should be its own rule
7. **Grid configuration** — Complex grids with custom columns are typically their own rule
8. **Tab content** — Each tab's content is typically its own rule

**Keep inline when:**
- The section is <50 lines
- It's a simple display (single rich text, single stamp)
- It's tightly coupled to the parent's local variables
- Extracting it would require passing >5 rule inputs

### Step 6: Generate the Decomposition Plan

**Output format:**

```markdown
# Component Decomposition Plan: [Feature Name]
**App**: [App Name]
**Reference bundles**: [Existing bundles used as structural reference]

## Naming Convention

Based on the app's existing patterns, all rules for this feature should follow:

```
[PREFIX]_[MODULE]_[FEATURE]_[component]
```

Example: `AS_GSS_TMG_CPS_evaluationSummary`

- **Prefix**: `[extracted from app]`
- **Module**: `[extracted from app]`
- **Feature abbreviation**: `[recommended]`

---

## Decomposition Tree

```
[FEATURE]_main (Entry Point — Site Page / Record View)
├── [FEATURE]_header
│   └── [FEATURE]_statusTag (SHARED — used in grids too)
├── [FEATURE]_detailsBar
├── [FEATURE]_tabContent_overview
│   ├── [FEATURE]_kpiCards
│   ├── [FEATURE]_activityGrid
│   └── [FEATURE]_timelineSection
├── [FEATURE]_tabContent_details
│   ├── [FEATURE]_formSection_basic
│   └── [FEATURE]_formSection_advanced
├── [FEATURE]_tabContent_history
│   └── [FEATURE]_historyGrid
└── [FEATURE]_dialog_edit (Dialog — triggered by edit button)
    └── [FEATURE]_editForm
```

---

## Component Details

### 1. [FEATURE]_main
- **Type**: Entry point interface
- **Layout**: `a!headerContentLayout` / `a!sideBarLayout` / `a!formLayout`
- **Responsibility**: Page-level layout, tab switching, top-level data loading
- **Rule inputs**: `recordId` (Integer)
- **Local variables**: Tab state, top-level data queries
- **Calls**: All child rules listed below
- **Estimated size**: ~40-60 lines (orchestration only)

### 2. [FEATURE]_header
- **Type**: Section component
- **Responsibility**: Page title, status indicator, action buttons
- **Rule inputs**: `title` (Text), `status` (Text), `recordId` (Integer)
- **Reusable**: No — specific to this feature
- **Estimated size**: ~30-50 lines

### 3. [FEATURE]_statusTag
- **Type**: Shared display component
- **Responsibility**: Render a status tag with conditional color
- **Rule inputs**: `status` (Text)
- **Reusable**: YES — can be used in grids, cards, headers across the app
- **Estimated size**: ~15-20 lines
- **Similar existing rule**: `[reference from app if found]`

### 4. [FEATURE]_activityGrid
- **Type**: Grid component
- **Responsibility**: Display activity/history in a paginated grid
- **Rule inputs**: `recordId` (Integer), `pageSize` (Integer, default 10)
- **Reusable**: No — specific data shape
- **Estimated size**: ~60-80 lines
- **Notes**: Grid should be its own rule per app convention

...

---

## Shared Components (Reusable Across Features)

| Component | Purpose | Used By |
|---|---|---|
| `[FEATURE]_statusTag` | Status tag with conditional color | This feature + potentially others |
| `[SHARED]_userAvatar` | User avatar display | Multiple features (if exists) |
| ... | ... | ... |

**Check if these already exist in the app:**
```
solutions-intelligence.search_objects(app, "statusTag", "Interface")
solutions-intelligence.search_objects(app, "avatar", "Interface")
```

---

## Rule Inputs Summary

| Rule | Inputs | Types |
|---|---|---|
| `[FEATURE]_main` | recordId | Integer |
| `[FEATURE]_header` | title, status, recordId | Text, Text, Integer |
| `[FEATURE]_activityGrid` | recordId, pageSize | Integer, Integer |
| ... | ... | ... |

---

## Data Flow Diagram

```
[FEATURE]_main
  │
  ├─ Queries: rule!APP_getRecordData(recordId)
  │           rule!APP_getActivityData(recordId)
  │
  ├─ Passes to [FEATURE]_header:
  │     title = local!recordData.title
  │     status = local!recordData.status
  │
  ├─ Passes to [FEATURE]_activityGrid:
  │     recordId = ri!recordId
  │     (grid queries its own paginated data)
  │
  └─ Passes to [FEATURE]_dialog_edit:
        recordId = ri!recordId
        (dialog queries fresh data on open)
```

---

## Implementation Order

Recommended build sequence (dependencies first):

1. **Shared components** — `[FEATURE]_statusTag` (if new)
2. **Leaf components** — Grids, simple display sections
3. **Section components** — Tab contents, form sections
4. **Dialogs** — Edit/create dialogs
5. **Entry point** — `[FEATURE]_main` (orchestrates everything)

---

## Comparison with App Conventions

| Aspect | App Convention | This Plan | Match? |
|---|---|---|---|
| Nesting depth | 2 levels max | 2 levels | ✅ |
| Grid extraction | Always separate rule | Separate rule | ✅ |
| Dialog extraction | Always separate rule | Separate rule | ✅ |
| Naming prefix | `AS_GSS_TMG_` | `AS_GSS_TMG_` | ✅ |
| Rule input style | Minimal — pass IDs, let child query | Same | ✅ |
| ... | ... | ... | ... |
```

### Step 7: Save and present

Save the plan as `ux-reviews/decomposition-plans/{feature-name}-decomposition.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. Total number of rules recommended
2. Which ones are shared/reusable
3. The recommended build order
4. Any existing shared components they should reuse instead of creating new ones
5. Offer to generate the SAIL skeleton for each rule (interface signature + comments)

---

## Rules

1. **Always analyze 2-3 existing bundles first** — decomposition must match app conventions
2. **Always extract naming conventions from the app** — don't invent a new naming scheme
3. **Respect the app's nesting depth** — if the app uses 2 levels, don't recommend 4
4. **Identify shared components** — check if they already exist before recommending new ones
5. **Include rule inputs for every component** — devs need to know the interface contract
6. **Show the data flow** — where data is queried vs. passed down
7. **Recommend build order** — dependencies first, entry point last
8. **Keep entry points thin** — orchestration only, no business logic
9. **Extract grids and dialogs** — these are almost always their own rules in Appian apps
10. **Size estimates help planning** — include approximate line counts
11. **Don't over-decompose** — a 15-line section doesn't need its own rule
12. **Consider testability** — smaller rules are easier to test in Interface Designer
