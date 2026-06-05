# Action: Edge Case Analysis

Analyze a feature spec and SAIL mockup to surface all edge cases, unhandled states, and developer questions that the UX designer hasn't addressed. The output is a structured document that preempts the "what do we show when...?" questions that arise during development.

This action uses Solutions Intelligence MCP tools to understand what's possible in SAIL and the Aurora Design System docs to recommend standard patterns for handling each edge case.

## Prerequisites

- A feature spec or description (provided by the user — text, doc, or pasted content)
- A SAIL mockup or interface code (provided by the user — `.sail` file, pasted code, or an existing interface name in Solutions Intelligence)
- Optionally: the app name if the interface exists in Solutions Intelligence

---

## Workflow

### Step 1: Gather inputs

Ask the user for:
1. **Feature spec or description** — What is this feature supposed to do? What's the user journey?
2. **SAIL mockup** — Either:
   - Pasted SAIL code
   - A `.sail` file path
   - An interface name + app name (to retrieve from Solutions Intelligence)
3. **Target app** (optional) — If this is for an existing app, knowing the app name lets us check existing patterns

If the user provides an interface name, retrieve it:
```
solutions-intelligence.search_objects(app, "interface_name", "Interface")
solutions-intelligence.get_object_code(app, "interface_name")
```

### Step 2: Load Aurora reference docs (MANDATORY)

Fetch the relevant Aurora docs based on the interface type to understand what standard patterns exist for handling edge cases:

```
get_git_content("appian-design/aurora", "docs/layouts/empty-states.md")
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
```

Also reference the official Appian SAIL documentation for component capabilities:
- **Component reference**: `https://docs.appian.com/suite/help/26.4/SAIL_Components.html`
- **SAIL patterns**: `https://docs.appian.com/suite/help/26.4/sail/introduction.html`

Also fetch docs specific to the components used in the mockup e.g.:
- Forms → `get_git_content("appian-design/aurora", "docs/layouts/forms.md")`
- Grids → `get_git_content("appian-design/aurora", "docs/layouts/grids.md")`
- Dashboards → `get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")`
- Record views → `get_git_content("appian-design/aurora", "docs/layouts/record-views.md")`

### Step 3: Analyze the mockup for implicit assumptions

Read through the SAIL code and identify every assumption the designer made. For each component, ask:

**Data assumptions:**
- What if this data field is null/empty?
- What if the list has 0 items? 1 item? 1000 items?
- What if text content exceeds the expected length?
- What if a date is in the past? Far in the future?
- What if numeric values are 0? Negative? Extremely large?

**Permission assumptions:**
- What if the user doesn't have permission to see this data?
- What if the user's role changes mid-session?

**State assumptions:**
- What if the record is in a different status than shown?
- What if the process is cancelled/paused/errored?
- What if the user navigates back after submitting?

**Interaction assumptions:**
- What if the user clicks a button twice rapidly?
- What if a save/submit fails?
- What if a dependent dropdown has no options?
- What if the user leaves required fields empty and tries to proceed?

### Step 4: Cross-reference with SAIL platform capabilities

For each identified edge case, determine:
1. **Does SAIL have a built-in way to handle this?** (e.g., `a!gridField` has built-in empty state messaging)
2. **Is there an Aurora pattern for this?** (e.g., empty states pattern, validation messaging)
3. **Is this a known SAIL limitation?** (e.g., no native infinite scroll, no drag-and-drop in grids)

Use Solutions Intelligence to check how similar interfaces in the same app handle these cases:
```
solutions-intelligence.search_objects(app, "similar_pattern", "Interface")
solutions-intelligence.get_object_code(app, "similar_interface_name")
```

### Step 5: Check existing app patterns (if app name provided)

If the user specified an app, look at how that app handles common edge cases:
```
search_bundles(app, "empty", "page")
solutions-intelligence.search_objects(app, "noData", "Interface")
solutions-intelligence.search_objects(app, "error", "Interface")
```

This helps ensure recommendations are consistent with the app's existing approach.

### Step 6: Generate the Edge Case Report

Produce a structured document organized by category. For each edge case:
- **Scenario**: What happens
- **Current mockup behavior**: What the mockup shows (or doesn't show)
- **Recommended handling**: How to handle it in SAIL
- **Aurora pattern**: Reference to the relevant Aurora pattern (if applicable)
- **Priority**: Critical (will break) / High (will confuse users) / Medium (polish) / Low (rare scenario)

**Output format:**

```markdown
# Edge Case Analysis: [Feature Name]

## Summary
- **Total edge cases identified**: X
- **Critical**: X | **High**: X | **Medium**: X | **Low**: X
- **Mockup coverage**: X% of identified cases are handled

---

## 1. Empty & Null States

### 1.1 [Specific scenario]
- **Scenario**: [Description]
- **Current mockup**: [What happens now — likely nothing/undefined]
- **Recommendation**: [What to show — use Aurora empty state pattern]
- **SAIL approach**: [Specific SAIL pattern — e.g., showWhen, a!if with isnull()]
- **Priority**: [Critical/High/Medium/Low]

---

## 2. Data Boundary Conditions

### 2.1 [Specific scenario]
...

---

## 3. Permission & Security States

### 3.1 [Specific scenario]
...

---

## 4. Error & Failure States

### 4.1 [Specific scenario]
...

---

## 5. Concurrent & Timing Issues

### 5.1 [Specific scenario]
...

---

## 6. Responsive & Context Variations

### 6.1 [Specific scenario]
...

---

## Action Items for Designer
1. [ ] [Specific thing to add/change in the mockup]
2. [ ] [Another thing]
...

## Questions for Product/Stakeholders
1. [Decision needed that neither design nor dev can make alone]
2. [Another decision]
...
```

### Step 7: Save and present

Save the report as `ux-reviews/edge-case-analysis/{feature-name}-edge-cases.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. How many edge cases were found by category
2. Which ones are critical (will definitely come up during dev)
3. Which ones need product decisions (not just design fixes)
4. Offer to generate updated SAIL mockups that handle the critical cases

---

## Edge Case Categories Reference

Use this as a checklist when analyzing any interface:

### Data States
- Null/empty values for every displayed field
- Empty lists (0 items in grids, card groups, dropdowns)
- Single item in a list (pluralization, layout)
- Maximum items (pagination, scrolling, performance)
- Text overflow (long names, descriptions, addresses)
- Special characters in text (quotes, HTML entities, unicode)
- Numeric extremes (0, negative, very large, decimal precision)
- Date edge cases (past dates, far future, timezone differences)
- File/document states (no file, large file, unsupported format)

### User Permission States
- No access (entire interface hidden)
- Read-only access (view but can't edit)
- Partial access (some fields visible, others hidden)
- Role-based variations (admin vs. standard user)
- Group-based visibility (different teams see different things)

### Process & Workflow States
- Record in unexpected status
- Process paused/cancelled/errored
- Task already completed by another user
- Task reassigned while viewing
- Deadline passed
- Approval rejected (what does the user see next?)

### Interaction Edge Cases
- Double-click on submit
- Form submission failure (network, validation, server error)
- Dependent field with no options
- Required field left empty
- Back navigation after submission
- Browser refresh mid-form
- Session timeout during long form

### Responsive & Context
- Tablet landscape vs. portrait
- Phone breakpoint
- Dialog context vs. site page context
- Embedded in a record view vs. standalone
- Narrow browser window

### SAIL Platform Constraints
- No client-side-only interactions (everything round-trips to server)
- No custom animations or transitions
- No drag-and-drop (except grid row reordering with links)
- No hover-only interactions (must work with keyboard)
- No infinite scroll (pagination only)
- No custom modals (only `a!dialogLayout` patterns)
- Grid limitations (no inline editing of arbitrary cells, no column resize)
- 4000 character limit on paragraph fields
- File upload size limits
- No vertical tabs (use sidebar navigation)
- No slider/range input (use numeric field)
- No real-time push updates (no WebSocket — requires page refresh)
- Billboard layout only at page top (not arbitrary placement)
- Pane layout limited to 2-3 panes with independent scroll

---

## Rules

1. **Always load empty-states.md** — it's the standard pattern for null/empty data
2. **Always load SAIL_CODING_GUIDE.md** — it defines what's syntactically possible
3. **Categorize every edge case** — don't just list them, group them logically
4. **Prioritize** — Critical means "dev will be blocked without an answer"
5. **Provide SAIL-specific solutions** — don't just say "show an error," say which SAIL pattern to use
6. **Reference Aurora patterns** — link to the specific Aurora doc when one exists
7. **Separate designer actions from product decisions** — some edge cases need stakeholder input
8. **Check existing app patterns** — if the app already handles similar cases, recommend consistency
9. **Don't invent SAIL capabilities** — only recommend what SAIL can actually do
10. **Be exhaustive but practical** — cover everything, but clearly mark what's low priority
