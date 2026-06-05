---
inclusion: manual
---

# Refactor & Redeploy Workflow

## Overview

This workflow exports an Appian object, refactors its SAIL code (adding comments, improving readability, extracting variables), and redeploys the cleaned-up version — all with minimal tool calls.

**Common Triggers:**
- "Refactor and redeploy {object name}"
- "Clean up the code in package {UUID}"
- "Export, refactor, and reimport {object}"
- "Add comments to {expression rule} and redeploy"

---

## Quick Path (4 steps)

If the user already has an export ZIP in the `exports/` folder:

```
1. extract_sail_from_export(export_zip_path="exports/export-<uuid>.zip")
2. DISCOVER UTILITIES:
   a. lcp-api.searchObjects(searchTerm="_UT_", typeIds=["Expression Rule"], appPrefix="<APP>")
   b. lcp-api.searchObjects(searchTerm="_CO_UT_", typeIds=["Expression Rule"])
   c. Retrieve signatures for matches relevant to the extracted code
3. [AI refactors the SAIL code — applying utility substitutions from step 2]
4. refactor_and_deploy(original_zip_path="exports/export-<uuid>.zip", new_definition="<refactored code>")
```

That's it. `refactor_and_deploy` handles rebuild → version bump → inspect → deploy → cleanup automatically.

---

## Full Path (from package URL or object name)

```
1. get_package_contents_from_url(package_url="...") — identify objects in the package
2. export_package(package_uuid="<UUID>")
3. get_export_results(export_uuid="...") → downloads ZIP
4. extract_sail_from_export(export_zip_path="exports/export-<uuid>.zip")
5. DISCOVER UTILITIES (MANDATORY — do NOT skip):
   a. lcp-api.searchObjects(searchTerm="_UT_", typeIds=["Expression Rule"], appPrefix="<APP>")
   b. lcp-api.searchObjects(searchTerm="_CO_UT_", typeIds=["Expression Rule"])
   c. For each discovered utility: read its signature (inputs, types) via lcp-api.getInterface
   d. Identify which inline patterns in the extracted SAIL match discovered utilities
6. [AI refactors the SAIL code — applying ALL steps including utility substitutions from step 5]
7. refactor_and_deploy(original_zip_path="...", new_definition="<refactored code>", ...)
```

**⚠️ Step 5 is NON-NEGOTIABLE.** The utility discovery MUST happen before writing the refactored code. Without it, the refactored code will contain inline patterns that should be utility calls. This is the most common refactoring failure mode.

**Finding the package UUID:**
- If user provides a package URL: extract the base64 ID from the URL path
- If user provides an object name: use `solutions-intelligence.search_objects` to find it, then ask the user which package it belongs to (the Deployment API only exports packages, not individual objects)

---

## Multi-Object Packages

**CRITICAL: Do NOT re-export the package between objects.** The original export ZIP is NOT consumed by `refactor_and_deploy` — only the intermediate `-refactored.zip` is cleaned up. The original ZIP remains on disk for subsequent calls.

When a package contains multiple refactorable objects (Expression Rules, Interfaces, Decisions):

```
1. export_package(package_uuid="<UUID>")
2. get_export_results(export_uuid="...") → downloads ZIP
3. extract_sail_from_export(export_zip_path="...") — extract ALL objects to see what's there
4. DISCOVER UTILITIES (once for the whole package):
   a. lcp-api.searchObjects(searchTerm="_UT_", typeIds=["Expression Rule"], appPrefix="<APP>")
   b. lcp-api.searchObjects(searchTerm="_CO_UT_", typeIds=["Expression Rule"])
   c. Retrieve signatures for matches relevant to the extracted code
5. [AI refactors ObjectA — applying utility substitutions from step 4]
6. refactor_and_deploy(original_zip_path="...", object_name="ObjectA", new_definition="<refactored>", ...)
7. [AI refactors ObjectB — applying utility substitutions from step 4]
8. refactor_and_deploy(original_zip_path="...", object_name="ObjectB", new_definition="<refactored>", ...)
```

Utility discovery happens **once** and applies to all objects. All objects are deployed from the **same original ZIP** — one export, multiple deploys. Each `refactor_and_deploy` call targets a specific object via the `object_name` filter.

---

## Tool Reference

| Tool | Purpose | When to use |
|------|---------|-------------|
| `extract_sail_from_export` | Read SAIL code from export ZIP | Always — to get the current code before refactoring |
| `rebuild_export_package` | Inject new SAIL + bump version → new ZIP | When you want manual control over inspect/deploy |
| `refactor_and_deploy` | Rebuild + inspect + deploy in one shot | **Preferred** — handles everything automatically |

### Key behavior of `refactor_and_deploy`:
- Automatically bumps the version UUID (so Appian accepts the import)
- Runs inspection first; aborts if inspection finds errors
- Polls both inspection and deployment until complete
- Cleans up the intermediate ZIP file (but **preserves the original export ZIP**)
- Returns a step-by-step log
- Supports `remove_inputs` parameter to delete unused rule inputs from the XML
- Supports `rule_input_descriptions` parameter to add/update descriptions on rule inputs

### Removing unused rule inputs

Use the `remove_inputs` parameter to delete rule inputs that are not referenced in the SAIL code:

```
refactor_and_deploy(
  original_zip_path="...",
  object_name="RD_BL_calculateVendorScore",
  new_definition="<refactored code>",
  remove_inputs: ["pizza", "unusedParam"],
  rule_input_descriptions: {"vendor": "The vendor record", "categories": "Reference data list"}
)
```

This removes the `<namedTypedValue>` XML elements entirely — the deployed object will no longer have those inputs.

### Suppressing false-positive analyzer warnings

The `solutions-intelligence.get_object_detail` tool may report warnings that are **not actionable**. Do NOT present these to the user as "remaining issues":

| False Positive | Why it's wrong |
|---|---|
| "Interface should be wrapped in a!localVariables()" | Fires on any object — even those already using `a!localVariables()`. Ignore. |
| "Deep nesting detected (N levels)" for interfaces | Structural nesting from `formLayout > sectionLayout > columnsLayout > columnLayout > field` is normal and expected. Only flag nesting in **logic** (nested `if()` chains, deeply nested `a!forEach`). |

**Rule:** After refactoring, do NOT run `solutions-intelligence.get_object_detail` again just to report "remaining warnings." The refactoring is complete when the code changes are deployed. Only run analysis if you need to discover issues *before* refactoring.

### CRITICAL — `#"SYSTEM_SYSRULES_*"` format for deployment

⚠️ **THIS IS THE #1 CAUSE OF DEPLOYMENT ISSUES. READ CAREFULLY.**

When providing `new_definition` to `refactor_and_deploy` or `rebuild_export_package`, you MUST use the `#"SYSTEM_SYSRULES_*"` format from the export for all Appian component functions. **Do NOT use `a!functionName()` syntax** — this causes Appian to pin the function to a release-specific version (e.g., `a!formLayout_17r1`, `a!dropdownField_20r2`) which creates upgrade issues.

**Correct approach:**
1. Run `extract_sail_from_export` to get the current code
2. Note the exact `#"SYSTEM_SYSRULES_*"` names used in the export (e.g., `#"SYSTEM_SYSRULES_formLayout_v2"`, `#"SYSTEM_SYSRULES_sectionLayout_v1"`)
3. Use those exact names in your `new_definition` — preserve them as-is
4. Only change the parts you're actually refactoring (variable names, logic, comments, etc.)

**What goes wrong if you use `a!formLayout()` instead:**
- Appian resolves it to the current release version: `a!formLayout_17r1`
- When the environment upgrades to 17r2, the object is stuck on the old version
- The object must be manually re-saved to pick up the new version
- This is visible in the screenshot as `a!formLayout_17r1` instead of `a!formLayout`

**Common mappings (use the `_v1`/`_v2` suffix from the export, not release versions):**

| Export format (correct) | What it resolves to in Designer |
|---|---|
| `#"SYSTEM_SYSRULES_formLayout_v2"` | `a!formLayout()` |
| `#"SYSTEM_SYSRULES_sectionLayout_v1"` | `a!sectionLayout()` |
| `#"SYSTEM_SYSRULES_columnsLayout"` | `a!columnsLayout()` |
| `#"SYSTEM_SYSRULES_columnLayout"` | `a!columnLayout()` |
| `#"SYSTEM_SYSRULES_textField"` | `a!textField()` |
| `#"SYSTEM_SYSRULES_dropdownField_v1"` | `a!dropdownField()` |
| `#"SYSTEM_SYSRULES_paragraphField"` | `a!paragraphField()` |
| `#"SYSTEM_SYSRULES_dateField"` | `a!dateField()` |
| `#"SYSTEM_SYSRULES_ButtonLayout"` | `a!buttonLayout()` |
| `#"SYSTEM_SYSRULES_buttonWidget_v1"` | `a!buttonWidget()` |
| `#"SYSTEM_SYSRULES_headerTemplateSimple"` | `a!headerTemplateSimple()` |
| `#"SYSTEM_SYSRULES_forEach"` | `a!forEach()` |

**Rule:** Always copy the exact `#"..."` references from the export output. Different environments or Appian versions may use different suffixes. Never guess — use what the export gives you.

---

## Refactoring Guidelines

⚠️ **NON-NEGOTIABLE: Remove unused rule inputs.** If a `ri!` parameter is not referenced anywhere in the SAIL definition, pass it in `remove_inputs` when deploying. Do NOT mark it DEPRECATED. Do NOT ask the user for permission. Unused inputs are dead weight — remove them unconditionally. This applies to ALL object types (Expression Rules, Interfaces, Decisions). If dependents exist that pass the removed input, warn the user (e.g., "Note: removing `ri!pizza` — 2 callers pass this parameter and will need updating") but still proceed with the removal.

When refactoring SAIL code, apply **all applicable steps** from the checklist below. Do not stop after one category — work through each in order:

1. **Documentation** — Add header comment block, section comments, explain non-obvious patterns (see standards below)
2. **Readability** — Extract intermediate variables, improve formatting
3. **Translation substitution** — Replace hardcoded strings with `translation!` references if Translation Map is available. **This applies to BOTH interfaces AND expression rules that return display labels** (see Translation Substitution section below)
4. **Utility substitution** — Replace inline code with calls to existing `_UT_`/`_CO_` utility rules (see Utility Substitution section below)
5. **Code hygiene** — Apply code hygiene standards including **removing ALL unused rule inputs and local variables from ALL object types** (see standards below)
6. **Best practices** — Fix any issues flagged by the SOLUTIONS Design Best Practices Checklist (naming, strong typing, etc.)

**CRITICAL REMINDERS (common mistakes):**
- **DO NOT include the object name or INPUTS in the header comment block.** Only PURPOSE, OUTPUT, and ALGORITHM. The name and inputs are already visible in Appian Designer.
- **DO NOT use `a!functionName()` syntax in `new_definition`.** You MUST preserve the exact `#"SYSTEM_SYSRULES_*"` references from the export. Using `a!formLayout()` causes Appian to pin it to a release-specific version (e.g., `a!formLayout_17r1`).

Apply the documentation and code hygiene standards below:

#[[file:sail-documentation-standards.md]]

#[[file:sail-code-hygiene.md]]

#[[file:refactor-step-utility-substitution.md]]

---

## Translation Substitution

A refactoring step that replaces hardcoded user-facing strings with `translation!` references from an existing Appian Translation Set. **This step is applied automatically when the export ZIP contains translation data.**

**When to apply (automatic — no user trigger needed):**
- The export ZIP contains `translationSet/` and `translationString/` directories
- The `extract_sail_from_export` output includes a Translation Map section

**Also triggered explicitly by:**
- "internationalize"
- "translate"
- "i18n"
- "substitute translations"

**How it works:**
1. The `extract_sail_from_export` tool automatically parses Translation Set and Translation String XML files from the export ZIP and returns a **Translation Map** section in its output.
2. The AI agent uses the Translation Map to substitute matching hardcoded strings with their `translation!` references during the refactoring step.
3. If no Translation Map is present in the output, skip this step entirely.

**Detailed substitution rules:** See `refactor-step-translation.md` for the full set of rules governing which strings are safe to substitute, which must be preserved, and the correct reference syntax.

---

## Utility Substitution

A refactoring step that replaces inline code patterns with calls to existing utility rules (`_UT_` / `_CO_` naming convention) from the same application. **This step is always applied — no precondition is required** (unlike Translation Substitution which requires a Translation Set in the package).

**When to apply (always — automatic on every refactoring run):**
- This step runs on every refactoring pass regardless of package contents
- No special files or conditions need to be present in the export ZIP

**How it works:**
1. **Discovery** — The AI agent discovers available utility rules by querying the Knowledge Base (`solutions-intelligence.search_objects` with `_UT_` and `_CO_` patterns) or falling back to the live Appian API (`lcp-api.listApplications` + `lcp-api.getInterface`) if no KB exists. Both common utilities (`AS_CO_UT_*`) and application-specific utilities (`AS_<APP>_UT_*`) are searched across the full application scope.
2. **Matching** — The AI agent scans the target object's SAIL code for inline patterns that match known utility rule functionality (e.g., raw query calls, inline null checks, manual user name formatting, nested index chains, inline deduplication). Parameters are compared to verify semantic equivalence.
3. **Substitution** — High-confidence matches are substituted automatically using keyword parameter syntax. Uncertain matches are presented to the user for confirmation. Patterns that don't match or have custom error handling are left unchanged.
4. **Summary** — The AI agent reports a summary of substitutions made (count and which utility rules were used) in the refactoring output.

**Silent skip:** If no utility rules are found for the application (neither via KB nor live API), this step is silently skipped without error.

**Detailed substitution rules:** See `refactor-step-utility-substitution.md` for the full set of rules governing discovery strategy, substitution patterns, conservative policy, false positives, and worked examples.

**⚠️ CRITICAL:** In the `new_definition` passed to `refactor_and_deploy`, discovered utility rules MUST be referenced using `#"<UUID>"(params)` format — NOT `rule!AS_CO_UT_displayUser(params)`. The deployment XML requires UUID references. The discovery step provides both the rule name (for matching) and the UUID (for code generation).

---

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| Inspection fails | SAIL syntax error or XML escaping issue | Fix the SAIL code and retry |
| Deployment skips object | Version UUID not bumped | Already handled automatically by the tools |
| "Invalid uuid for deployment type" | Tried to export an object UUID instead of package UUID | Need the package UUID, not the object UUID |
| No `<definition>` in XML | Object is a Record Type, Constant, etc. | Only Expression Rules, Interfaces, and Decisions have SAIL definitions |

---

## Supported Object Types

| Type | Supported | Notes |
|------|-----------|-------|
| Expression Rules | ✅ | Has `<definition>` element |
| Interfaces | ✅ | Has `<definition>` element |
| Decisions | ✅ | Has `<definition>` element |
| Record Types | ❌ | No SAIL definition |
| Process Models | ❌ | Different XML structure |
| Constants | ❌ | No SAIL code |
| Connected Systems | ❌ | No SAIL code |

---

## Refactoring Summary Format

After deploying refactored objects, present a summary to the user. The summary should focus on **what changed from the user's perspective** — not internal implementation mechanics.

**Include:**
- Changes to variable names (before → after)
- Removed dead code (unused variables, unused rule inputs)
- Logic improvements (nested if → a!match, duplicate logic consolidated)
- Comments/documentation added (brief mention, not exhaustive)
- Warnings about callers affected by removed inputs

**Do NOT include:**
- "All `#"..."` system references untouched" — this is an internal constraint, not a user-facing change
- "Translation set unchanged" — unless translations were actually modified
- "Test case preserved" — unless test cases were modified or added
- Any statement about what was *not* changed that the user wouldn't expect to change
- Internal deployment details (version bumps, XML format, inspection results)
