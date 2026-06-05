# Action: Generate SAIL Interface

Generate production-ready Appian SAIL code for a new interface using the Aurora Design System as reference. The output is a `.sail` file that can be directly pasted into Appian Interface Designer.

This action uses the Git content tools to access the Aurora Design System documentation from GitHub (`appian-design/aurora`) for correct SAIL syntax, component patterns, and layout guidance.

## Aurora Design System — Repository Map

The Aurora docs live at `appian-design/aurora` on GitHub under the `docs/` directory:

```
docs/
├── SAIL_CODING_GUIDE.md          ← SAIL syntax rules, error prevention, best practices
├── index.md                       ← Design system overview
├── accessibility/
│   └── checklist.md               ← Accessibility requirements
├── branding/
│   ├── colors.md                  ← Aurora color palette (hex values, usage)
│   ├── typography.md              ← Font families, sizes, weights
│   └── icons.md                   ← Icon usage guidelines
├── components/
│   ├── buttons.md                 ← Button styles, sizes, placement rules
│   ├── cards.md                   ← Card layouts, styles, decorative bars
│   ├── tabs.md                    ← Tab patterns and usage
│   ├── tags.md                    ← Status tags, colors, sizes
│   ├── breadcrumbs.md             ← Breadcrumb navigation
│   ├── milestones.md              ← Milestone/stepper patterns
│   ├── confirmation-dialog.md     ← Dialog patterns
│   └── more-less-link.md          ← Expand/collapse patterns
├── layouts/
│   ├── forms.md                   ← Form layouts, field grouping, validation
│   ├── dashboards.md              ← Dashboard structure, KPI cards, charts
│   ├── record-views.md            ← Record summary/detail view patterns
│   ├── grids.md                   ← Grid/table patterns, pagination
│   ├── landing-pages.md           ← Landing page layouts
│   ├── pane-layouts.md            ← Pane/split layouts
│   ├── empty-states.md            ← Empty state patterns
│   └── messaging-module.md        ← Chat/messaging layouts
└── patterns/
    ├── key-performance-indicators.md ← KPI card patterns
    ├── charts.md                  ← Chart types and usage
    ├── banners.md                 ← Alert/info banner patterns
    ├── cards-as-choices.md        ← Selection card patterns
    ├── document-cards.md          ← Document display cards
    ├── pick-list.md               ← Pick list patterns
    ├── comment-thread.md          ← Comment/discussion patterns
    └── notifications.md           ← Notification patterns
```

## Workflow

### Step 1: Understand the request

**Why**: SAIL interfaces vary dramatically by type. A form, a dashboard, and a record view use completely different layout patterns. Clarifying upfront prevents rework.

Clarify what the user wants to build:
- What type of interface? (form, dashboard, record view, landing page, dialog)
- What data does it display or collect?
- What actions can the user take?
- Any specific components needed? (charts, KPIs, grids, tabs)

### Step 2: Load the SAIL Coding Guide (MANDATORY)

**Why**: This guide contains syntax rules that prevent common SAIL errors — wrong bracket types, missing commas, invalid parameter names. Skipping it leads to code that won't compile in Appian.

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
```

You MUST follow all rules in this guide. Key rules include:
- Always start with `a!localVariables`
- Use curly braces `{}` for lists, not square brackets
- Use double quotes for strings, not single quotes
- No semicolons — comma-separated only
- Use `fv!row` for grid row access

### Step 3: Load relevant Aurora layout and pattern docs

**Why**: Aurora provides exact SAIL code patterns for every interface type. Using these patterns produces interfaces that look and behave like standard Appian — inventing your own patterns produces inconsistent results.

Based on the interface type, fetch the appropriate docs:

**For a form:**
```
get_git_content("appian-design/aurora", "docs/layouts/forms.md")
get_git_content("appian-design/aurora", "docs/components/buttons.md")
```

**For a dashboard:**
```
get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")
get_git_content("appian-design/aurora", "docs/patterns/key-performance-indicators.md")
```

**For a record view:**
```
get_git_content("appian-design/aurora", "docs/layouts/record-views.md")
get_git_content("appian-design/aurora", "docs/components/cards.md")
```

**For a grid/table:**
```
get_git_content("appian-design/aurora", "docs/layouts/grids.md")
```

**If unsure which docs to load**, search first:
```
search_git_content("appian-design/aurora", "your-keyword", "docs/")
```

### Step 4: Load component-specific docs as needed

**Why**: Each component has specific parameter options, valid values, and usage rules. Using wrong values (e.g., an invalid button style) causes runtime errors in Appian.

Fetch docs for any specific components the interface uses:
```
get_git_content("appian-design/aurora", "docs/components/tabs.md")
get_git_content("appian-design/aurora", "docs/components/tags.md")
get_git_content("appian-design/aurora", "docs/patterns/banners.md")
```

### Step 5: Check existing app interfaces for consistency (OPTIONAL)

**Why**: If the user is adding to an existing Appian application, matching the naming conventions, layout patterns, and data structures already in use produces a more cohesive result.

If the user mentions an existing app:
```
solutions-intelligence.search_objects(app, "similar_name", "Interface")
solutions-intelligence.get_object_code(app, uuid)
```

### Step 6: Generate the SAIL code

**Why each rule matters:**

1. **Start with `a!localVariables`** — Appian requires this wrapper for any interface that uses local state. Always include it even if the interface seems simple — it's needed for sample data.

2. **Use sample data in local variables** — Define realistic placeholder data as `a!map()` structures so the interface renders immediately when pasted into Appian. This lets the user see the layout without connecting to real data.

3. **Follow Aurora layout patterns exactly** — Use the exact SAIL code patterns from the docs fetched in Steps 3-4. Do not invent custom layouts when Aurora provides a standard one.

4. **Use correct SAIL syntax** — Follow the SAIL Coding Guide from Step 2.

5. **Include all parameters** — Don't omit optional parameters that affect appearance (`labelPosition`, `style`, `size`, `shape`, etc.).

6. **Add comments** — Only where the logic is non-obvious. Mark where real data sources should replace sample data.

**SAIL file structure:**
```sail
a!localVariables(
  /* Sample data — replace with real queries */
  local!data: {
    a!map(id: 1, name: "Example", status: "Active"),
    a!map(id: 2, name: "Another", status: "Pending")
  },
  local!selectedItem: null,

  /* Interface */
  a!formLayout(
    label: "Interface Title",
    contents: {
      /* Layout and components here */
    },
    buttons: a!buttonLayout(
      primaryButtons: {
        a!buttonWidget(label: "Submit", style: "PRIMARY", submit: true)
      },
      secondaryButtons: {
        a!buttonWidget(label: "Cancel", style: "LINK")
      }
    )
  )
)
```

### Step 7: Validate against the coding guide (MANDATORY)

**Why**: Each item on this checklist corresponds to a real SAIL compilation error or runtime bug. Checking them prevents the user from pasting broken code into Appian.

Before presenting the output, verify:
- [ ] Wrapped in `a!localVariables()` if any local variables are used
- [ ] Top-level layout is `a!formLayout()`, `a!headerContentLayout()`, or `a!paneLayout()`
- [ ] All component names use `a!` prefix
- [ ] All parameters use named syntax (`parameter: value`)
- [ ] Lists use curly braces `{item1, item2}` (not square brackets)
- [ ] Strings use double quotes `"text"` (not single quotes)
- [ ] No semicolons — comma-separated only
- [ ] `fv!row` used for grid row access (not `item` or `row`)
- [ ] `labelPosition: "COLLAPSED"` used where labels should be hidden
- [ ] Button styles are valid: `"SOLID"`, `"OUTLINE"`, `"LINK"`
- [ ] Card shapes are valid: `"ROUNDED"`, `"SEMI_ROUNDED"`, `"SQUARED"`
- [ ] Color values are valid: `"ACCENT"`, `"POSITIVE"`, `"NEGATIVE"`, `"SECONDARY"`, or hex strings
- [ ] No invented/non-existent SAIL functions — only use functions documented in Aurora
- [ ] Sample data is realistic and matches the interface's purpose

If any item fails, fix it before presenting the output.

### Step 8: Save and present

Save the generated code as `sail-interfaces/{interface-name}.sail` in the current working directory. Create the `sail-interfaces/` folder if it doesn't exist.

Tell the user:
1. The file is saved at the specified path
2. They can copy-paste the code into Appian Interface Designer
3. They'll need to replace sample data with actual rule/query references
4. Highlight any placeholders that need to be replaced (e.g., `/* Replace with rule!MyQuery */`)

## Quick Reference: Common Tool Calls

```
list_git_directory("appian-design/aurora", "docs/")
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
get_git_content("appian-design/aurora", "docs/layouts/forms.md")
search_git_content("appian-design/aurora", "KPI", "docs/")
```

## Rules

1. **Always load SAIL_CODING_GUIDE.md first** — it's the source of truth for syntax
2. **Always load the relevant layout doc** — forms.md for forms, dashboards.md for dashboards, etc.
3. **Use Aurora patterns exactly** — don't invent your own patterns when Aurora provides one
4. **Only use documented SAIL functions** — if it's not in Aurora docs, don't use it
5. **Include sample data** — generate realistic placeholder data so the interface renders immediately
6. **One interface per file** — each `.sail` file contains one complete interface
7. **No backend logic** — don't include `rule!` or `cons!` references; use local variables with sample data instead, and add comments indicating where real data sources should go
8. **Validate before presenting** — Step 7 checklist must pass
9. **Curly braces for lists** — `{item1, item2}`, never `[item1, item2]`
10. **Double quotes for strings** — `"text"`, never `'text'`
11. **No semicolons** — SAIL uses commas to separate parameters
