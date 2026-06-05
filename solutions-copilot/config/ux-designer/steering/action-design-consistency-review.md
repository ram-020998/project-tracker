# Action: Design Consistency Review

Compare a new interface design against existing interfaces in the same Appian application to identify inconsistencies in patterns, spacing, styling, navigation, and component usage. The output is a consistency report with specific fixes to align the new design with established app conventions.

This action uses Atlas MCP tools to retrieve existing interfaces from the target app and Aurora Design System docs as the baseline standard.

## Prerequisites

- The new interface (SAIL code, HTML prototype, screenshots or description)
- The target app name (must exist in Atlas knowledge base)

---

## Workflow

### Step 1: Gather inputs

Ask the user for:
1. **New design** — SAIL code, file path, or interface name, screenshots or description
2. **App name** — Which application this interface belongs to
3. **Interface type** — Form, dashboard, record view, landing page, grid page, or dialog

If the user provides an interface name in Atlas:
```
search_objects(app, "interface_name", "Interface")
get_object_code(app, "interface_name")
```

### Step 2: Understand the app's existing patterns

Retrieve the app overview and identify the most-used interfaces:

```
get_app_overview(app)
get_hub_objects(app, top_n=20, object_type="Interface")
```

Then find interfaces of the SAME TYPE as the new one. For example, if the new interface is a form:
```
search_bundles(app, "create", "action")
search_bundles(app, "update", "action")
```

If it's a dashboard or page:
```
search_bundles(app, "dashboard", "page")
search_bundles(app, "summary", "page")
```

Retrieve 3-5 existing interfaces of the same type:
```
get_object_code(app, "existing_interface_1")
get_object_code(app, "existing_interface_2")
get_object_code(app, "existing_interface_3")
```

### Step 3: Load Aurora baseline standards (MANDATORY)

Fetch the Aurora docs relevant to the interface type:

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
```

Based on interface type:
- Forms → `get_git_content("appian-design/aurora", "docs/layouts/forms.md")`
- Dashboards → `get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")`
- Record views → `get_git_content("appian-design/aurora", "docs/layouts/record-views.md")`
- Grids → `get_git_content("appian-design/aurora", "docs/layouts/grids.md")`
- Landing pages → `get_git_content("appian-design/aurora", "docs/layouts/landing-pages.md")`

Also fetch component docs for components used in the new interface:
```
get_git_content("appian-design/aurora", "docs/components/buttons.md")
get_git_content("appian-design/aurora", "docs/components/cards.md")
get_git_content("appian-design/aurora", "docs/components/tags.md")
```

### Step 4: Extract patterns from existing interfaces

Analyze the retrieved existing interfaces and document the app's conventions:

**Layout patterns:**
- Top-level layout component used (`a!formLayout`, `a!headerContentLayout`, `a!sideBarLayout`)
- Column structure (single column forms? two-column dashboards?)
- Section grouping approach (cards? sections? boxes?)
- Header style (`a!headerTemplateFull` vs `a!headerTemplateSimple`, background colors)

**Component patterns:**
- Button styles and placement (primary on right? secondary as LINK?)
- Card shapes used (`ROUNDED` vs `SEMI_ROUNDED` vs `SQUARED`)
- Card border colors (consistent hex values?)
- Tag color conventions (what colors map to what statuses?)
- Grid configurations (pagination style, row headers, selection style)
- Icon usage (which icons for which actions?)

**Naming & content patterns:**
- Header/title casing (Title Case? Sentence case?)
- Button label conventions ("Create" vs "Add", "Update" vs "Save")
- Placeholder text patterns ("Select..." vs "Choose...")
- Section label sizing (`labelSize: "SMALL"` vs default?)

**Spacing & sizing patterns:**
- Margin patterns (`marginAbove`, `marginBelow` values)
- Padding on cards (`STANDARD` vs `EVEN_MORE`?)
- Column widths (specific width values used?)
- Dialog sizes (if applicable)

**Data display patterns:**
- How status is shown (tags? stamps? rich text with color?)
- How dates are formatted
- How empty states are handled
- How counts/metrics are displayed

### Step 5: Compare new interface against established patterns

For each pattern category, compare the new interface against what the app already does. Flag any deviation as:

- **🔴 Inconsistency** — The new interface does something differently from the established pattern with no apparent reason
- **🟡 Minor deviation** — Small difference that may or may not be intentional
- **🟢 Consistent** — Matches the established pattern
- **🔵 New pattern** — Something the app hasn't done before (not necessarily wrong, but should be intentional)

### Step 6: Generate the Consistency Report

**Output format:**

```markdown
# Design Consistency Review: [New Interface Name]
**App**: [App Name]
**Compared against**: [List of 3-5 existing interfaces used as reference]

## Summary
- 🟢 **Consistent**: X patterns
- 🟡 **Minor deviations**: X patterns
- 🔴 **Inconsistencies**: X patterns
- 🔵 **New patterns**: X patterns
- **Overall consistency score**: X/10

---

## Layout Structure

### [Pattern aspect]
| | App Convention | New Interface | Status |
|---|---|---|---|
| Top-level layout | `a!headerContentLayout` | `a!formLayout` | 🔴 |
| Header style | `a!headerTemplateFull` with #020A51 | `a!headerTemplateSimple` | 🟡 |
| Column structure | 2 columns (main + sidebar) | Single column | 🔴 |
| ... | ... | ... | ... |

**Recommendation**: [Specific change to align]

---

## Component Usage

### Buttons
| | App Convention | New Interface | Status |
|---|---|---|---|
| Primary style | `"SOLID"` | `"SOLID"` | 🟢 |
| Secondary style | `"LINK"` | `"OUTLINE"` | 🔴 |
| Submit label | "Create [noun]" | "Submit" | 🟡 |
| ... | ... | ... | ... |

**Recommendation**: [Specific change]

---

### Cards
| | App Convention | New Interface | Status |
|---|---|---|---|
| Shape | `"SEMI_ROUNDED"` | `"ROUNDED"` | 🔴 |
| Border color | `"#EDEEFA"` | `"#E0E0E0"` | 🔴 |
| Padding | `"STANDARD"` | `"EVEN_MORE"` | 🟡 |
| ... | ... | ... | ... |

**Recommendation**: [Specific change]

---

### Tags & Status Indicators
| | App Convention | New Interface | Status |
|---|---|---|---|
| Active/Success | POSITIVE background | ACCENT background | 🔴 |
| Pending/Warning | ACCENT background | Custom hex | 🔴 |
| Error/Failed | NEGATIVE background | NEGATIVE background | 🟢 |
| ... | ... | ... | ... |

**Recommendation**: [Specific change]

---

## Content & Naming

| | App Convention | New Interface | Status |
|---|---|---|---|
| Header casing | Title Case | Sentence case | 🟡 |
| Button verbs | "Create", "Update" | "Add", "Edit" | 🔴 |
| Placeholder text | "Select [noun]" | "Choose a [noun]" | 🟡 |
| ... | ... | ... | ... |

**Recommendation**: [Specific change]

---

## Spacing & Sizing

| | App Convention | New Interface | Status |
|---|---|---|---|
| Section margins | `marginAbove: "STANDARD"` | `marginAbove: "MORE"` | 🟡 |
| Card padding | `"STANDARD"` | `"STANDARD"` | 🟢 |
| ... | ... | ... | ... |

---

## New Patterns Introduced

### [New pattern name]
- **What it does**: [Description]
- **Why it's new**: [Not seen in existing interfaces]
- **Assessment**: [Is this a good addition? Should it be adopted app-wide?]
- **Recommendation**: [Keep as-is / Modify / Replace with existing pattern]

---

## Action Items
1. [ ] [Specific fix — highest priority]
2. [ ] [Another fix]
3. [ ] [Another fix]
...

## Existing Interfaces for Reference
- `[Interface name 1]` — [Why it's a good reference for this design]
- `[Interface name 2]` — [Why it's a good reference]
- `[Interface name 3]` — [Why it's a good reference]
```

### Step 7: Save and present

Save the report as `ux-reviews/consistency-reviews/{interface-name}-consistency-review.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. The overall consistency score
2. The most critical inconsistencies (🔴 items)
3. Which existing interfaces to reference for alignment
4. Offer to generate a corrected version of the SAIL code

---

## Rules

1. **Always retrieve 3-5 existing interfaces of the same type** — you need real comparisons, not assumptions
2. **Always load Aurora docs** — Aurora is the baseline; app conventions layer on top
3. **App conventions override Aurora when they conflict** — if the app consistently uses a non-Aurora pattern, the new interface should match the app
4. **Be specific about hex values and parameter values** — "different card style" is not useful; `"SEMI_ROUNDED" vs "ROUNDED"` is
5. **Distinguish intentional from accidental** — a new pattern might be an improvement; flag it as 🔵 not 🔴
6. **Provide the exact fix** — don't just say "make it consistent"; show the parameter change
7. **Check hub objects** — the most-depended-on interfaces are the strongest conventions
8. **Consider the interface type** — forms have different conventions than dashboards
9. **Don't flag Aurora-compliant choices as inconsistent** — if the new interface follows Aurora but the app doesn't, note it as a potential app-wide improvement
10. **Include reference interfaces** — tell the designer which existing interfaces to look at
