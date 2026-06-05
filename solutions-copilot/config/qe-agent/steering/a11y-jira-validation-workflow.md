---
inclusion: manual
---

# Workflow E: Validate Jira A11y Bugs Against Current Code

## Purpose

Systematically validate open a11y Jira bugs against the current SAIL code to determine which bugs are still valid, which have been fixed, and which reference interfaces that no longer exist or have been significantly redesigned.

## Trigger Phrases

- "Validate Jira a11y bugs"
- "Validate open a11y bugs"
- "Check if Jira bugs are still valid"
- "Validate GAMS-XXXX" (single bug validation)
- Option 10 from the a11y menu

## Modes

### Mode A: Bulk Validation (all open bugs)
Triggered by: "Load [App] and validate all open a11y Jira bugs"

### Mode B: Single Bug Validation
Triggered by: "Load [App] and validate GAMS-XXXX"

---

## Workflow Steps

### Step 1: Load Application
- Call `load_application` with the app name/UUID (use `force_refresh=true` if user requests fresh code)
- Confirm: "Loaded [App] — [N] objects. Starting Jira bug validation."

### Step 2: Pull Jira Bugs

**For Bulk Validation (Mode A):**
Pull all open a11y bugs using the team-specific JQL from the external config file.

⚠️ **NEVER use `ORDER BY` in any JQL query — it causes 403 errors.**

**Config file:** Read `config/jira-team-config.json` (`#[[file:config/jira-team-config.json]]`) to get the correct team mapping. Match the interface prefix or app name to find the right team entry, then use its queries.

**Resolution order:**
1. If user provided inline JQL override → use that
2. If matched team has `custom_jql_override` set (not null) → use that
3. Otherwise use default queries below

**JQL execution order (default):**
1. Use `queries.open_only` from the matched team entry (filters by team UUID + labels + status != Done)
2. If that 403s, use `queries.primary` (team UUID + labels, no status filter) and filter out Done/Closed in post-processing
3. If that 403s, use `queries.with_squad_label` (adds Squad-Level-A11y to label filter)

**For Single Bug Validation (Mode B):**
Call `get_jira_issue` with the issue key and `expand: ["renderedFields"]` to get the full description with HTML formatting.

### Step 3: Extract Bug Pattern for Each Bug

For each Jira bug, extract these fields from the issue:

| Field | Where to Find | Purpose |
|-------|--------------|---------|
| **Summary** | `fields.summary` | Quick description of the bug |
| **Interface location** | `fields.description` — look for "Interface:", "Interface Impacted:", or "Interfaces:" | Which interface(s) the bug affects |
| **Bug pattern** | `fields.description` — look for "OBSERVATION" section | What the actual problem is |
| **Remediation** | `fields.description` — look for "REMEDIATION" section | What SAIL parameter to check |
| **Aurora rule** | `fields.customfield_10227` | The specific Aurora checklist rule |
| **Affected version** | `fields.versions[].name` | Which release the bug was filed against |
| **Status** | `fields.status.name` | Current Jira status |
| **Labels** | `fields.labels` | Severity labels (A11Y-H, A11Y-M) |
| **Comments** | `fields.comment.comments` | May contain "this is outdated" or "screens have changed" hints |

### Step 4: Identify the Interface(s)

This is the critical step. Use these strategies in order:

**Strategy 1: Direct name match**
If the description contains an Appian interface name (e.g., `AS_GSS_FM_addVendors`, `AS_GSS_GRD_vendorList`):
- Call `search_objects(query="[interface_name]")` to verify it exists

**Strategy 2: Feature path to interface mapping**
If the description uses a feature path (e.g., "Consensus dialog - Ratings & Comments step"):
- Extract keywords: "consensus", "ratings", "comments"
- Call `search_objects(query="consensus", object_type="Interface")` to find candidates
- Look for FM_ (form) interfaces first — these are the entry points
- Use naming conventions: FM_ = form, GRD_ = grid, CRD_ = card, CPS_ = component, SEC_ = section, BTN_ = button

**Strategy 3: SAIL pattern search**
If the bug mentions specific SAIL parameters or components:
- Call `search_objects(query="[parameter_or_component]")` to find interfaces containing that pattern
- Example: bug says "skipAutoFocus" → search for "focusOnFirstInput"
- Example: bug says "grid missing label" → search for "gridField"

**Strategy 4: Cannot determine**
If none of the above strategies identify the interface:
- Flag the bug as "CANNOT VALIDATE — interface not identifiable from bug description"
- Include the bug in the report with a recommendation to manually identify the interface

### Step 5: Validate Each Bug Against Current Code

For each bug where the interface was identified:

1. **Check if interface exists:** Call `search_objects` with the interface name
   - If NOT found → verdict: **INTERFACE REMOVED**

2. **Pull SAIL code:** Call `get_sail_code` for the interface

3. **Check the specific bug pattern:**

   Map common bug patterns to SAIL checks:

   | Bug Pattern | What to Check in SAIL |
   |------------|----------------------|
   | "missing label" on input | Check `label` parameter exists and is not null |
   | "missing label" on grid | Check `label` parameter on `a!gridField` |
   | "pane has no label" | Check `accessibilityText` on `a!pane` |
   | "heading defined as rich text" | Check for `a!headingField` with `headingTag` |
   | "icon has no text alternative" | Check `altText` or `caption` on `a!richTextIcon` |
   | "focus moved past content" | Check `focusOnFirstInput` is set to `false` |
   | "dynamic content unknown" | Check for `a!messageBanner` with `announceBehavior` |
   | "duplicate control names" | Check `accessibilityText` on repeated controls |
   | "color contrast" | Flag as NEEDS MANUAL VERIFICATION (can't test from code) |
   | "touch target size" | Flag as NEEDS MANUAL VERIFICATION |
   | "content overlaps at zoom" | Flag as NEEDS MANUAL VERIFICATION |
   | "grid instructions not associated" | Check `instructions` parameter on grid |
   | "row header not set" | Check `rowHeader` parameter on grid |
   | "card choice missing label" | Check `label` on `a!cardChoiceField` |
   | "section missing labelHeadingTag" | Check `labelHeadingTag` on `a!sectionLayout` |

4. **Check comments for hints:**
   - If a comment says "outdated", "screens changed", "should close" → factor into verdict
   - If a comment says "still present", "confirmed" → factor into verdict

5. **Assign verdict:**

   | Verdict | Criteria |
   |---------|----------|
   | ✅ **FIXED** | The SAIL code now has the correct parameter/pattern. Bug can be closed. |
   | ❌ **STILL VALID** | The bug pattern is still present in the current SAIL code. Bug remains open. |
   | 🔄 **NEEDS RE-EVALUATION** | Interface exists but has been significantly redesigned. Original bug scenario may no longer apply, but the root cause pattern may still be present. Needs manual re-test. |
   | 🗑️ **INTERFACE REMOVED** | The interface no longer exists in the application. Bug is obsolete. |
   | 🔍 **NEEDS MANUAL VERIFICATION** | Bug pattern cannot be validated from SAIL code alone (e.g., color contrast, zoom, touch targets). |
   | ⚠️ **CANNOT VALIDATE** | Interface not identifiable from bug description. Needs human input. |

### Step 6: Generate Validation Report

Generate a Markdown report with this structure:

```markdown
# Jira A11y Bug Validation Report — [App Name]

**Date:** [date]
**Application:** [app name]
**Total Bugs Analyzed:** [N]
**Source:** Jira project GAMS, component "GSS: Accessibility"

## Summary

| Verdict | Count |
|---------|-------|
| ✅ FIXED (can close) | X |
| ❌ STILL VALID (remains open) | X |
| 🔄 NEEDS RE-EVALUATION | X |
| 🗑️ INTERFACE REMOVED (obsolete) | X |
| 🔍 NEEDS MANUAL VERIFICATION | X |
| ⚠️ CANNOT VALIDATE | X |

## ✅ FIXED — Recommend Closing

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Status:** [jira status]
**Interface:** [interface name]
**Original Bug:** [one-line description of the bug pattern]
**Current Code:** [what the code looks like now — the fix]
**Verdict:** ✅ FIXED — [parameter] is now correctly set.
**Recommendation:** Close this bug.

## ❌ STILL VALID — Remains Open

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Status:** [jira status]
**Interface:** [interface name]
**Original Bug:** [one-line description]
**Current Code:** [what the code still shows — the problem]
**Verdict:** ❌ STILL VALID — [parameter] is still missing/incorrect.
**Recommendation:** Fix [specific SAIL change needed].

## 🔄 NEEDS RE-EVALUATION

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Status:** [jira status]
**Interface:** [interface name]
**Original Bug:** [one-line description]
**Current Code:** [what changed]
**Verdict:** 🔄 NEEDS RE-EVALUATION — Interface redesigned since [version]. Original scenario may not apply. [Root cause pattern] is [still present / no longer present].
**Recommendation:** Manual re-test needed. [Specific thing to check].

## 🗑️ INTERFACE REMOVED — Obsolete

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Interface:** [interface name from bug]
**Verdict:** 🗑️ INTERFACE REMOVED — Interface no longer exists in the application.
**Recommendation:** Close as obsolete.

## 🔍 NEEDS MANUAL VERIFICATION

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Interface:** [interface name]
**Why:** [Cannot validate from SAIL code — requires browser/screen reader testing]
**Recommendation:** [Specific manual test to perform]

## ⚠️ CANNOT VALIDATE

### GAMS-XXXX: [summary]
**Filed:** [version] ([date])
**Why:** Interface not identifiable from bug description.
**Bug Description Excerpt:** [relevant excerpt]
**Recommendation:** Manually identify the interface and re-run validation.
```

### Step 7: Push to Google Docs (MANDATORY)

Same as all other workflows — call `import_to_google_doc` with the Markdown report.
- `file_name`: "Jira A11y Bug Validation — [App Name] — [Date]"
- `source_format`: "md"
- `folder_id`: Use `GOOGLE_DRIVE_FOLDER_ID` from MCP config

### Step 8: Summary to User

After the Google Doc is created, provide a brief summary:
- Total bugs analyzed
- Breakdown by verdict
- Link to the Google Doc
- Highlight the "FIXED" bugs that can be closed immediately

---

## Batching Strategy (for Bulk Validation)

If there are more than 20 open bugs:
1. Process in batches of 10 bugs
2. For each batch: pull bug details, identify interfaces, pull SAIL code, validate
3. Accumulate results across batches
4. Generate one combined report at the end

If context gets tight, checkpoint to `a11y-jira-validation-checkpoint.md` after each batch.

---

## Edge Cases

- **Bug references multiple interfaces:** Validate each one separately, report per-interface
- **Bug has no description:** Flag as CANNOT VALIDATE
- **Bug is a sub-task:** Pull parent epic for additional context
- **Interface name changed:** Search by keywords from the bug description, note the name change in the report
- **Bug is about a process model, not an interface:** Flag as CANNOT VALIDATE (this workflow only validates SAIL interfaces)
