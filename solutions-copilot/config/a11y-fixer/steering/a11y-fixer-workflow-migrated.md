# A11Y Fixer Workflow

## Response Style

Keep all user-facing messages **short and actionable**:
- Lead with the finding (one line)
- One sentence of context (why)
- Numbered options for the user to pick
- No walls of text, no verbose explanations, no technical dumps

When presenting options, always use this format:
```
[emoji] **[Finding title]**

[One sentence context]

**Options:**
1. [Action A]
2. [Action B]
3. [Action C]

Which one?
```

## FIRST ACTION — Before Anything Else

When a user asks to fix a ticket, your VERY FIRST response must be the tracker initialized. Do NOT call any tools before printing this:

**A11Y FIXER — GAMS-XXXX**

| Phase | Step | Status |
|-------|------|--------|
| 1 | Understand Ticket | ⏳ |
| 2 | Locate Interface | — |
| 3 | PRE-FIX (Playwright) | — |
| 4 | Get & Analyze XML | — |
| 5 | Apply Fix | — |
| 6 | Deploy | — |
| 7 | POST-FIX (Playwright) | — |
| 8 | Close Out | — |

Then proceed with Phase 1. Update and reprint the table after each phase completes.

## MANDATORY: Phase Order

**NEVER skip Phase 3 (Pre-Fix Verification).** Before touching any XML or deploying anything, you MUST:
1. Navigate to the live interface using Playwright MCP
2. Take a `browser_snapshot` of the target component
3. Confirm the issue exists in the accessibility tree
4. Present findings to the user

If you find yourself about to get XML or apply a fix without having done a Playwright verification first — STOP and go back to Phase 3.

## MANDATORY: Execution Tracker — NEVER SKIP

The tracker MUST be printed:
- At the START of every ticket (initialized)
- After EVERY phase completion (updated)
- Even for simple Tier 1 fixes
- Even when the fix is identical to a previous ticket

If you find yourself about to start a new phase without having printed the tracker after the previous phase — STOP and print it.

The tracker is not optional. It is the user's primary way of understanding where you are in the workflow. Skipping it breaks trust and makes it impossible to audit the work.

## Batch Processing: Multiple Tickets for Same Interface

When processing multiple tickets, check if any target the same interface. If so:

1. **Read all related tickets first** before making any changes
2. **Apply all fixes to the same XML** in a single deployment
3. **Use a combined deployment name**: `GAMS-8859 GAMS-8850 Multiple a11y fixes to InterfaceName`
4. **Verify all fixes together** in a single Playwright session

This reduces:
- Number of deployments (fewer version bumps)
- Risk of version conflicts between sequential deploys
- Total verification time (one navigation instead of many)

## Trigger

User provides a Jira ticket number (e.g., "Fix GAMS-8543", "A11Y fix for GAMS-524").

---

## Phase 1: Understand the Ticket

### Step 1.1: Read the Jira ticket

Call `get_jira_issue` with the ticket key. Extract:
- **Summary** — what's the issue
- **Description** — detailed remediation steps
- **Interface mentioned** — which interface/form/dialog
- **Component** — which specific element (grid, icon, field, card, pane)
- **Remediation** — what parameter to add/change/remove and what value

### Step 1.2: Classify the fix type

Match the ticket's remediation against the taxonomy in `a11y-fix-patterns.md`. Identify:
- **Pattern ID** (e.g., #5 "Add icon altText")
- **Tier** (1, 2, or 3)
- **Required property** (e.g., `altText`, `rowHeader`, `accessibilityText`)
- **Value type** — numeric, boolean, enum string, text (needs bundle key?), or expression

### Step 1.3: Gate check

- **If Tier 1** → proceed
- **If Tier 2** → warn user: "This requires inserting a new component. It's medium risk. Proceed?"
- **If Tier 3** → STOP. Tell user: "This fix requires structural refactoring that I cannot safely automate. Here's what needs to be done manually: [explain from ticket]"

### Step 1.4: Present summary to user

Use this conversational format:

```
📋 **GAMS-XXXX** — [ticket summary]

**The problem:** [Plain-language explanation of what's wrong and who it affects — focus on the user impact, not the technical detail]

**The fix:** [What parameter will be added/changed/removed and why it solves the problem]

**Risk:** [🟢 Low (Tier 1) / 🟡 Medium (Tier 2)] — [brief justification: "single parameter change" / "new component insertion"]

**Interface:** `[interface name from ticket or best guess]`

Shall I proceed?
```

Guidelines for this summary:
- Lead with the human impact ("screen readers can't announce...") not the technical gap ("rowHeader is missing")
- Keep "The fix" to one sentence — what changes and what it achieves
- Always end with a clear question asking for approval
- Do NOT include pattern IDs, tier numbers, or taxonomy references — those are internal

Wait for user confirmation before proceeding.

---

## Phase 2: Locate the Interface

### Step 2.1: Get Solutions config

Call `solutions-intelligence.list_applications` to get the app registry. Identify which app the interface belongs to based on the ticket's component or prefix (AS_GSS_, AS_VM_, AS_GCW_, etc.).

### Step 2.2: Search by name

Use `solutions_search_objects` with the interface name from the ticket. If the ticket mentions a specific object name (e.g., "AS_GSS_GRD_EvaluationVendors"), search for it directly.

### Step 2.3: If not found by name, use semantic search

Use `lcp-api.searchObjects` with descriptive terms from the ticket (e.g., "evaluation vendor grid", "select awardees form").

### Step 2.4: Handle wrapper interfaces

If the found interface is a wrapper (delegates to child components via rule references), search deeper:
- Look at the ticket description for more specific component details
- Search for child interfaces matching the specific UI element (grid, card, form section)
- Use `solutions_get_object_content` to inspect the wrapper's calls and identify the child

### Step 2.5: Confirm with user

Present the identified interface conversationally:

```
🔍 **Found it** — `[interface name]` (confidence: high)

[Description from Solutions]. This matches the "[component name]" mentioned in the ticket.

Shall I pull the XML and apply the fix?
```

If confidence is lower (e.g., found via semantic search, not exact name match):

```
🔍 **Best match** — `[interface name]` (confidence: medium)

[Description from Solutions]. This looks like it could be the "[component name]" from the ticket, but I'm not 100% certain.

Is this the right interface, or should I keep searching?
```

Wait for user confirmation.

---

## Phase 3: Plan Navigation (Solutions → Playwright)

Before opening the browser, use Solutions to build a navigation plan. The agent needs to know exactly where to go.

### Step 3.1: Get site URLs

Call `solutions-intelligence.list_applications` → find the app's `siteUrlList`. Pick the primary site URL (usually the first one, not settings/migration sites).

### Step 3.2: Get entry points

Call `solutions_get_entry_points_for_object` with the interface name → returns which clusters/features contain it. This tells you which site page or record view leads to the interface.

### Step 3.3: Build the navigation plan

Using the entry point info, construct a step-by-step plan:

```
Navigation Plan for AS_GSS_GRD_EvaluationVendors:
1. Site: https://soma-dev.appianpreview.com/suite/sites/source-selection
2. Click: "Evaluations" in left nav (or go to /page/evaluations)
3. Click: First evaluation record link in the grid
4. Click: "Vendors" tab
5. Target: The Vendors grid should be visible
```

Include:
- Which site URL to navigate to
- Which nav links/tabs to click
- Whether you need to open a record (and which one — use test data)
- Which tab or section contains the target component
- Any filters or actions needed to make the component visible

### Step 3.4: Present plan to user

```
🗺️ **Navigation plan to reach the interface:**

1. Go to [site URL]
2. Click [nav item / record / tab]
3. Target: [what we're looking for in the accessibility tree]

Proceeding to open browser...
```

If the navigation is unclear (interface is deep in a wizard or requires specific data), ask the user for guidance.

---

## Phase 4: Pre-Fix Verification (Playwright MCP)

Before modifying anything, verify the issue actually exists in the live interface.

### Reusing existing browser state

If you already have the target interface open from a previous ticket's verification:
1. Check if the current `browser_snapshot` shows the target component
2. If yes, use the existing snapshot as your pre-fix baseline — no need to re-navigate
3. If no (different page/dialog needed), navigate fresh

This saves significant time when fixing multiple tickets in the same interface.

### Step 3.1: Navigate to the interface

Using the Playwright MCP:
1. `browser_navigate` to the Appian site
2. Login if needed (fill form, click Sign In)
3. Navigate to the specific page/tab where the interface renders
4. `browser_snapshot` the target component

### Step 3.2: Confirm the issue exists

Check the accessibility tree for the reported problem:
- Missing `rowheader`? → The table snapshot should show no `rowheader` element
- Missing alt text? → The `img` element should have no name
- Missing label? → The input should have no accessible name
- Wrong heading level? → The heading should show the incorrect level

If the issue is NOT present (already fixed or ticket is stale):
```
🔍 **Pre-fix check: Issue not found in live UI**

[One sentence explaining why — e.g., "The icons are in dead code no longer called by any live interface."]

**Options:**
1. Fix anyway (code hygiene)
2. Skip — move to next ticket
3. Investigate further

Which one?
```

### Step 3.3: Capture baseline

Record what the accessibility tree shows BEFORE the fix. This becomes the "before" for comparison after deployment.

---

## Phase 5: Get and Analyze XML

### Step 3.1: Get raw XML

Call `solutions_get_object_xml` with the confirmed interface name.

### Step 3.2: Locate target component

In the `<definition>` section, find the specific component that needs fixing:
- For icons: look for `#"SYSTEM_SYSRULES_richTextIcon"` with matching `icon:` value
- For grids: look for `#"SYSTEM_SYSRULES_gridField_v3"` 
- For text fields: look for `#"SYSTEM_SYSRULES_textField"` with matching context
- For cards: look for `#"SYSTEM_SYSRULES_cardLayout"` with matching context
- For images: look for `#"SYSTEM_SYSRULES_documentImage"` 

Use surrounding context (nearby parameters, variable names, labels) to confirm you have the right component when multiples exist.

### Step 3.3: Verify match

Confirm the component matches the ticket description:
- Does the icon name match? (e.g., `icon: "search"`)
- Does the grid label match? (e.g., `label: "Vendors"`)
- Is it in the right section of the interface?

If ambiguous (multiple matching components), ask the user.

---

## Phase 6: Apply the Fix

### Step 4.1: Check if bundle key is needed

If the fix adds user-facing text (label, accessibilityText, caption, altText with descriptive text):

1. Query existing bundle keys:
   ```sql
   SELECT keyname, enuslabel FROM Appian.BND_Key 
   WHERE bundleid = [app_bundle_id] AND keyname LIKE 'acs_%' 
   AND enuslabel LIKE '%[relevant_term]%' LIMIT 10
   ```

2. If a suitable key exists → use it with the bundle pattern
3. If no key exists → use a literal string value and note: "Bundle key creation needed for production"

### Step 4.2: Construct the fix

Based on the pattern type:

**Adding a parameter:**
- Find the closing parenthesis of the target component
- Insert the new parameter before the last parameter (with proper comma)
- Or add after the last existing parameter (with comma before)

**Changing a parameter value:**
- Find the exact parameter line
- Replace the value

**Removing a parameter:**
- Find the exact parameter line (including trailing comma if present)
- Remove it

### Step 4.3: Follow XML rules

Load and follow ALL rules from `a11y-xml-rules.md`. Critical:
- ONLY modify inside `<definition>...</definition>`
- Keep ALL `#"urn:appian:record-field:v1:..."` references exactly as-is
- Keep ALL `#"_a-..."` references exactly as-is
- Keep ALL `#"SYSTEM_SYSRULES_..."` function names exactly as-is
- Do NOT reformat or reindent
- Do NOT touch saveInto, showWhen, or business logic

### Step 4.4: Present the change

Show the user a clear, conversational before/after:

```
✏️ **Here's the change:**

In `[interface name]`, I'll change:

BEFORE:
  [2-3 lines of surrounding context]
  [line being changed]
  [2-3 lines of surrounding context]

AFTER:
  [2-3 lines of surrounding context]
  [modified line]
  [2-3 lines of surrounding context]

This is a single [parameter addition/value change/parameter removal] — nothing else in the interface is touched.

Deploy this fix?
```

Wait for user approval.

---

## Phase 7: Deploy

### Rule: Deploying Modified Objects

**JUST PASS THE XML.** Do NOT:
- Write Python scripts to modify XML
- Save XML to temp files
- Use shell commands to process XML
- Create helper scripts
- Overthink the size

Take the full XML string from `solutions_get_object_xml`, make your changes directly in the string (find and replace the specific lines), and pass the entire modified XML to `deploy_modified_object` in one tool call. MCP handles 100KB+ strings. The XML is 5-20KB.

**If you find yourself writing a script or saving to a file — STOP. You're overcomplicating it.**

### Step 6.1: Deploy

Call `deploy_modified_object` with:
- `objectXml`: the full modified XML string (with your changes applied)
- `appUuid`: from `solutions-intelligence.list_applications`
- `deploymentName`: "GAMS-XXXX [brief description of fix]"

### Deployment Name Rules

The deployment name CANNOT include:
- Line breaks
- Any of these characters: `/ \ ; : ? ' < > *`

Use hyphens or spaces instead:
- ❌ `GAMS-8781 Fix Create/Update User dialog`
- ✅ `GAMS-8781 Fix Create Update User dialog`
- ✅ `GAMS-8781 Fix Create-Update User dialog`

### Step 6.2: Handle result

- **If inspection fails** → report the error. Do NOT retry with different XML without user guidance.
- **If deployment succeeds** → proceed to verification.

### Retrying after deployment failure

If a deployment fails with `COMPLETED_WITH_IMPORT_ERRORS`:

1. **Always re-fetch the XML** via `solutions_get_object_xml` before retrying
2. The failed deployment may have updated the `versionUuid` even though the object content didn't change
3. Use the fresh `versionUuid` from the re-fetched XML
4. Diagnose the root cause before retrying:
   - Check if you used a system reference that should be a direct function call (see `a11y-xml-rules.md` messageBanner rule)
   - Check for syntax errors in the inserted code
   - Check parameter names are correct for the component
5. Do NOT retry more than 2 times with the same approach — try a fundamentally different approach on the 3rd attempt

---

## Phase 8: Post-Fix Verification

### Step 7.1: Re-fetch XML

Call `solutions_get_object_xml` again. Confirm the fix parameter is present in the live XML.

### Step 7.2: Playwright verification (compare to baseline)

Using the Playwright MCP, navigate to the same interface as Phase 3 and take a `browser_snapshot`.

Compare the accessibility tree to the baseline captured in Phase 3:
- **Before:** [what the tree showed before the fix]
- **After:** [what the tree shows now]

The fix is verified if the accessibility tree now reflects the expected behavior (e.g., `rowheader` present, `img` has name, heading at correct level).

### Step 7.3: Report result

```
✅ **Done!** Fix deployed and verified for GAMS-XXXX.

**What changed:** [plain language — e.g., "Added rowHeader to the Vendors grid so screen readers announce the vendor name when navigating cells"]
**Interface:** `[name]`
**Deployment:** Successful
**Verification:** XML confirmed ✓ [| Screen reader confirmed ✓]
```

---

## Phase 9: Close Out

### Step 7.1: Jira comment

Present the comment text for the user to post (or post via Jira MCP if write access available):

```
Fixed via A11Y Fixer.
Interface: [name]
Change: [description of what was added/changed/removed]
Pattern: [pattern name from taxonomy]
Deployment: [deployment name]
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Ticket has no clear remediation steps | Ask user for clarification |
| Interface not found in Solutions KB | Ask user for the exact interface name |
| Multiple matching components in XML | Present options, ask user to pick |
| Deployment inspection fails | Report error, do not retry without guidance |
| Fix requires bundle key that doesn't exist | Use literal value, flag for follow-up |
| Ticket is Tier 3 | Refuse, explain what manual work is needed |
