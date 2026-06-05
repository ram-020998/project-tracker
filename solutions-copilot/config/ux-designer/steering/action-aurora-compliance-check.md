# Action: Aurora Compliance Check

Validate a SAIL mockup or interface against the Aurora Design System standards — checking button styles, form field patterns, card usage, tag conventions, content style (voice & tone), accessibility basics, and layout rules. The output is a pass/fail report with specific fixes for every violation.

This action fetches the relevant Aurora Design System documentation from GitHub and the official Appian SAIL documentation, then systematically checks the interface against every applicable rule.

## Reference Sources

- **Aurora Design System**: `https://appian-design.github.io/aurora/` (design standards, patterns, accessibility checklist)
- **Appian SAIL Components**: `https://docs.appian.com/suite/help/26.4/SAIL_Components.html` (official component reference)
- **SAIL Design System Guidelines**: `https://docs.appian.com/suite/help/26.4/sail/guidance.html` (usability best practices)

## Prerequisites

- A SAIL mockup or interface code (pasted, file path, or Atlas interface name)
- Optionally: the app name (to check app-specific conventions on top of Aurora)

---

## Workflow

### Step 1: Gather the interface

Ask the user for:
1. **SAIL code** — Pasted code, file path, or interface name in Atlas
2. **Interface type** — Form, wizard, dashboard, record view, grid page, dialog, or landing page
3. **App name** (optional) — For additional context

If retrieving from Atlas:
```
search_objects(app, "interface_name", "Interface")
get_object_code(app, "interface_name")
```

### Step 2: Load ALL relevant Aurora docs (MANDATORY)

This action requires loading multiple Aurora docs to check against. Always load:

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
get_git_content("appian-design/aurora", "docs/components/buttons.md")
get_git_content("appian-design/aurora", "docs/components/cards.md")
get_git_content("appian-design/aurora", "docs/components/tags.md")
get_git_content("appian-design/aurora", "docs/branding/colors.md")
get_git_content("appian-design/aurora", "docs/branding/typography.md")
get_git_content("appian-design/aurora", "docs/content-style-guide/voice-and-tone.md")
get_git_content("appian-design/aurora", "docs/accessibility/checklist.md")
```

Then load the layout doc specific to the interface type:
- Form/Wizard → `get_git_content("appian-design/aurora", "docs/layouts/forms.md")`
- Dashboard → `get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")`
- Record view → `get_git_content("appian-design/aurora", "docs/layouts/record-views.md")`
- Grid page → `get_git_content("appian-design/aurora", "docs/layouts/grids.md")`
- Landing page → `get_git_content("appian-design/aurora", "docs/layouts/landing-pages.md")`
- Pane layout → `get_git_content("appian-design/aurora", "docs/layouts/pane-layouts.md")`

Load additional component docs based on what's in the interface:
- Tabs → `get_git_content("appian-design/aurora", "docs/components/tabs.md")`
- Milestones → `get_git_content("appian-design/aurora", "docs/components/milestones.md")`
- Breadcrumbs → `get_git_content("appian-design/aurora", "docs/components/breadcrumbs.md")`
- KPIs → `get_git_content("appian-design/aurora", "docs/patterns/key-performance-indicators.md")`
- Charts → `get_git_content("appian-design/aurora", "docs/patterns/charts.md")`
- Banners → `get_git_content("appian-design/aurora", "docs/patterns/banners.md")`
- Empty states → `get_git_content("appian-design/aurora", "docs/layouts/empty-states.md")`

### Step 3: Run the compliance checks

Systematically check the interface against each Aurora category. For each rule, determine:
- **PASS** ✅ — The interface follows the rule
- **FAIL** ❌ — The interface violates the rule
- **N/A** ➖ — The rule doesn't apply to this interface

#### Category 1: SAIL Syntax (from SAIL_CODING_GUIDE.md)

| Rule | Check |
|---|---|
| Wrapped in `a!localVariables()` | Top-level wrapper present if local vars used |
| Top-level layout is valid | `a!formLayout`, `a!headerContentLayout`, `a!sideBarLayout`, or `a!paneLayout` |
| All components use `a!` prefix | No invented function names |
| Named parameter syntax | All params use `parameter: value` format |
| Lists use curly braces | `{item1, item2}` not `[item1, item2]` |
| Strings use double quotes | `"text"` not `'text'` |
| No semicolons | Comma-separated only |
| `fv!row` for grid row access | Not `item` or `row` |
| Valid button styles | Only `"SOLID"`, `"OUTLINE"`, `"LINK"` |
| Valid card shapes | Only `"ROUNDED"`, `"SEMI_ROUNDED"`, `"SQUARED"` |
| Valid color values | `"ACCENT"`, `"POSITIVE"`, `"NEGATIVE"`, `"SECONDARY"`, or hex |
| No invented SAIL functions | Only documented functions used |

#### Category 2: Forms (from forms.md)

| Rule | Check |
|---|---|
| Use `a!formLayout()` for single-step forms | Not `a!headerContentLayout` in dialogs |
| Use `a!wizardLayout()` for multi-step | Not manual step management |
| Header verb matches submit button | "Create Case" header → "Create" button |
| Use "Update" not "Edit" for modifications | Button and header labels |
| Required field instructions present | "Mandatory fields are marked with an asterisk (*)" |
| Single column for form fields | Not multi-column inputs in dialogs |
| `labelPosition: "ABOVE"` for form fields | Not COLLAPSED without alternative |
| Placeholder uses "Select" for dropdowns | Not "Choose" or "---" |
| Placeholder uses "Search" for pickers | Not "Find" or "Type to search" |
| Field-level validation used | Not disabled buttons for validation |
| Validation messages include field name | "[Field name] requires a value" format |
| Character limits shown for paragraph fields | 500, 1000, 2000, or 4000 |
| Confirmation dialog on submission | Success feedback provided |
| `skipAutoFocus: true` in dialogs | When important info precedes first field |
| Milestone for 3+ step wizards | Progress indicator present |
| Review step for 3+ step wizards | Read-only summary before submit |

#### Category 3: Buttons (from buttons.md)

| Rule | Check |
|---|---|
| Primary button is `"SOLID"` style | Not `"OUTLINE"` for primary action |
| Secondary button is `"LINK"` style | Consistent with app pattern |
| Submit button label matches header verb | "Create Case" → "Create" |
| No large/small buttons in wizards | Regular size only alongside Next/Back |
| Buttons don't stack unintentionally | Width accommodates all buttons |
| Solid accent reserved for Next/Submit | Other primary buttons use different style |
| Fixed button footer in record action dialogs | `isButtonFooterFixed: true` |

#### Category 4: Cards (from cards.md)

| Rule | Check |
|---|---|
| Cards with links have no nested controls | No buttons/inputs inside linked cards |
| No label on card links | `label: null` on card link |
| Selected cards use accessibilityText "Selected" | When color indicates selection |
| Decorative bar usage is consistent | Same style across similar cards |
| Card shape matches app convention | Consistent `shape` parameter |

#### Category 5: Tags (from tags.md)

| Rule | Check |
|---|---|
| Tag colors are semantically consistent | Same status = same color everywhere |
| POSITIVE for success/active states | Not ACCENT for success |
| NEGATIVE for error/failed states | Consistent usage |
| ACCENT for informational/pending | Not for success states |
| Tag size is appropriate | SMALL in grids, MEDIUM in headers |

#### Category 6: Content & Voice (from voice-and-tone.md)

| Rule | Check |
|---|---|
| Sentence case for labels | Not Title Case (except proper nouns) |
| No verbs in field labels | "Customer" not "Search Customer" |
| Concise button labels | Action verbs: "Create", "Update", "Delete" |
| No jargon in user-facing text | Plain language |
| Consistent terminology | Same concept = same word throughout |
| Instructions use `instructions` parameter | Not `a!richTextDisplayField` for instructions |

#### Category 7: Accessibility Basics (from checklist.md)

| Rule | Check |
|---|---|
| All inputs have labels | `label` parameter set (not null) |
| Labels are persistently visible | `labelPosition` not COLLAPSED without alternative |
| Required fields marked with `required: true` | Not just visual asterisk |
| Grid has a label | `label` parameter on `a!gridField` |
| Grid columns have headers | `label` on each `a!gridColumn` |
| No empty grid columns for spacing | Every column has content |
| Headings use semantic heading components | `a!headingField` or `labelHeadingTag` |
| Icons have alt text when standalone | `altText` on informational icons |
| Decorative icons have no alt text | `altText: null` on decorative icons |
| Color not sole indicator | Additional visual cue (icon, text, shape) |
| Progress bars have labels | `label` parameter set |
| Expandable sections have labels + heading tags | Both `label` and `labelHeadingTag` |

#### Category 8: Layout Standards

| Rule | Check |
|---|---|
| Appropriate layout for context | Form in dialog uses `a!formLayout` |
| Dialog size matches content | Not LARGE for sparse forms |
| `contentsWidth: "FULL"` in record action dialogs | For forms and wizards |
| Responsive considerations | `a!isPageWidth()` for breakpoint handling |
| Consistent spacing | `marginAbove`/`marginBelow` values match pattern |
| Section labels use `labelSize: "SMALL"` | When inside cards (per app convention) |

### Step 4: Generate the Compliance Report

**Output format:**

```markdown
# Aurora Compliance Check: [Interface Name]

## Summary
- **Total rules checked**: X
- ✅ **Pass**: X (Y%)
- ❌ **Fail**: X (Y%)
- ➖ **N/A**: X
- **Compliance score**: X%

### By Category
| Category | Pass | Fail | Score |
|---|---|---|---|
| SAIL Syntax | X | X | X% |
| Forms | X | X | X% |
| Buttons | X | X | X% |
| Cards | X | X | X% |
| Tags | X | X | X% |
| Content & Voice | X | X | X% |
| Accessibility | X | X | X% |
| Layout | X | X | X% |

---

## ❌ Failures

### [Category]: [Rule Name]
- **Rule**: [What Aurora requires]
- **Current**: [What the interface does]
- **Fix**: [Exact change to make]
- **Location**: [Line/section in the code]
- **Severity**: Critical / Major / Minor

```sail
/* Before */
a!buttonWidget(label: "Edit", style: "OUTLINE")

/* After */
a!buttonWidget(label: "Update", style: "LINK")
```

### [Category]: [Rule Name]
...

---

## ✅ Passes (Summary)

| Category | Rules Passed |
|---|---|
| SAIL Syntax | Curly braces ✓, Double quotes ✓, Named params ✓, ... |
| Forms | Form layout ✓, Validation messaging ✓, ... |
| Buttons | Primary style ✓, Label conventions ✓, ... |
| ... | ... |

---

## Recommendations

### Critical Fixes (Must fix before implementation)
1. [ ] [Fix description]
2. [ ] [Fix description]

### Major Fixes (Should fix)
1. [ ] [Fix description]
2. [ ] [Fix description]

### Minor Fixes (Nice to have)
1. [ ] [Fix description]
2. [ ] [Fix description]

---

## Auto-Fixed Version

[If requested, provide the corrected SAIL code with all fixes applied]
```

### Step 5: Save and present

Save the report as `ux-reviews/aurora-compliance/{interface-name}-aurora-compliance.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. The overall compliance score
2. How many critical failures need immediate attention
3. The most common category of failures
4. Offer to generate a corrected version of the SAIL code with all fixes applied

---

## Severity Classification

- **Critical** — Will cause a SAIL compilation error or runtime failure (syntax issues, invalid parameter values)
- **Major** — Violates a core Aurora standard that will be caught in design review (wrong button style, missing validation, accessibility failure)
- **Minor** — Deviates from Aurora best practice but won't block implementation (spacing inconsistency, non-ideal label casing)

---

## Rules

1. **Load ALL relevant Aurora docs before checking** — don't check from memory
2. **Check every applicable rule** — be exhaustive, not selective
3. **Provide exact fixes** — show the before/after code change
4. **Include line/section location** — devs need to find the issue
5. **Classify severity** — not all failures are equal
6. **N/A is valid** — don't force-fail rules that don't apply
7. **Aurora is the authority** — if Aurora says it, it's the rule
8. **Accessibility rules are always Major or Critical** — never Minor
9. **Syntax rules are always Critical** — they prevent compilation
10. **Offer the fixed version** — don't just report problems, solve them
11. **Check content/voice rules** — label text and messaging matter
12. **Be specific about color semantics** — "POSITIVE for success" is a real rule
