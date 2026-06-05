---
inclusion: manual
---

# Utility Substitution — Refactoring Step

Guidelines for how the refactor tools identify and replace inline code with calls to existing utility rules (`_UT_` / `_CO_`) during SAIL refactoring.

---

## Overview

The Utility Substitution step scans the target object's SAIL code for inline patterns that duplicate functionality already provided by existing utility rules in the application. When a match is found with high confidence, the inline code is replaced with a call to the corresponding utility rule using keyword parameter syntax.

**Pipeline position:** Step 4 — runs after Translation Substitution (step 3) and before Code Hygiene (step 5).

**Triggering:** This step is always triggered automatically during every refactoring run. Unlike Translation Substitution (which requires a Translation Set in the package), Utility Substitution has no precondition — it runs unconditionally and silently skips if no utility rules are found.

**What it does:**
1. Discover available utility rules (`_UT_` and `_CO_` naming patterns) from the application
2. Retrieve each utility rule's signature (parameters, types, description, behavior)
3. Scan the target object's SAIL code for inline patterns matching those utilities
4. Replace high-confidence matches with utility rule calls (keyword syntax)
5. Ask the user for uncertain matches
6. Report a summary of substitutions made

---

## Discovery Strategy

Before scanning the target object for substitution candidates, the agent must discover which utility rules are available in the application and retrieve their signatures.

### KB Path (Preferred)

When a Knowledge Base exists for the application:

1. Call `jarvis_search_objects` with search patterns `_UT_` and `_CO_` scoped to the **full application** (not just the exported package)
2. From the results, collect every **expression rule** or **interface** that has `_UT_` or `_CO_` anywhere in its name
3. Retrieve the signature of each discovered utility rule from the KB metadata: name, parameters (with types and descriptions), return type, and description
4. This includes both:
   - **Common utilities:** objects with `AS_CO_UT_` or `AS_CO_` in their name (shared across all applications)
   - **Application-specific utilities:** objects with `AS_<APP>_UT_` or `AS_<APP>_CO_` in their name (e.g., `AS_GAM_UT_*`, `AS_GAM_CO_*`) matching the target object's application namespace

### Live API Fallback

When no Knowledge Base exists for the application:

1. Call `list_application_objects` filtered by object type **Expression Rule** with search term `_UT_`, then again with `_CO_`
2. Repeat for object type **Interface** with the same search terms
3. Collect every object that has `_UT_` or `_CO_` anywhere in its name
4. For each discovered utility rule, call `get_appian_object` to retrieve its full SAIL definition
5. Parse the SAIL definition to extract the rule's parameters, types, and behavior

### Scope

- Search the **full application**, not just the exported package — utility rules often live in shared packages
- Include **all utility categories**: query utilities, general-purpose utilities, display/formatting utilities, null-handling utilities, type utilities, and reusable UI components
- Do not limit discovery to a predefined list — any rule matching `_UT_` or `_CO_` is a candidate

### Silent Skip

If neither the KB nor the live API returns any utility rules matching the application namespace:
- Skip the Utility Substitution step silently
- Do not prompt the user or log an error
- Proceed directly to the next refactoring step (Code Hygiene)

---

## Utility Categories

Utility rules span many categories. The agent should look for substitution opportunities across **all** of these, not just query patterns:

### Query Utilities
Wrap raw Appian query functions with consistent error handling and defaults.
- `AS_CO_UT_queryEntity` — replaces raw `a!queryEntity()` calls
- `AS_CO_UT_queryRecord` — replaces raw `a!queryRecordType()` calls

### Null-Handling & Boolean Utilities
Provide null-safe alternatives to common operations.
- `AS_CO_UT_isBlank` — replaces inline `a!isNullOrEmpty()` or custom null/empty checks
- `AS_CO_UT_not` — replaces `not()` with null-safe behavior (null returns true)

### Type & Collection Utilities
Simplify type checking and collection operations.
- `AS_CO_UT_distinct` — replaces inline deduplication logic
- `AS_CO_UT_enumForCount` — replaces `1 + enumerate(length(...))` patterns
- `AS_CO_UT_castToDictionary` — replaces inline dictionary casting
- `AS_CO_UT_typeCompare` — replaces inline type comparison logic
- `AS_CO_UT_indexWhere` — replaces inline index-lookup-by-value patterns
- `AS_CO_UT_indexPath` — replaces nested `index(index(index(...)))` chains

### String & Formatting Utilities
Handle common text operations with null safety.
- `AS_CO_UT_left` — replaces `left()` with null-safe error handling
- `AS_CO_UT_formatDate` — replaces inline date formatting patterns
- `AS_CO_UT_displayUser` — replaces inline user name formatting (e.g., `user(x, "firstName") & " " & user(x, "lastName")`)
- `AS_CO_UT_displayValue` — replaces inline `displayvalue()` with configurable defaults

### URL & Navigation Utilities
Standardize link and URL construction.
- `AS_CO_UT_urlForRecord` — replaces inline record URL construction
- `AS_CO_UT_recordSafeLink` — replaces inline safe link patterns for records
- `AS_CO_UT_getSiteUrl` — replaces inline site URL construction

### Filtering Utilities
Provide reusable filtering logic for record lists.
- `AS_<APP>_UT_Filter` / `AS_<APP>_CO_UT_Filter` — replaces inline `reject()`/`where()`/`wherecontains()` patterns for filtering record lists by field values

### Reusable UI Components (CO/UT Interfaces)

Replace raw Appian component calls with standardized CO or UT interface wrappers. These are **interfaces** (not expression rules) with `_CO_` or `_UT_` in their name that wrap standard Appian components (e.g., `a!textField`, `a!dropdownField`, `a!integerField`) with added behavior like auto-trim, default validation messages, or consistent styling.

**Critical — how to detect these candidates:**
1. During discovery, identify any interface with `_CO_` or `_UT_` in its name that has a prefix like `_INP_`, `_DSP_`, `_BTN_`, `_GRD_`, `_PCK_`, or similar UI-type prefixes
2. Read the interface's SAIL definition to determine which raw Appian component it wraps (e.g., `RS_CO_INP_textField` wraps `a!textField()`)
3. Scan the target object for **any raw call to that same Appian component** — each one is a substitution candidate
4. Map the inline parameters to the wrapper's rule inputs by name
5. **For any parameter in the raw call that the wrapper does not expose as an input:** check what value the wrapper sets internally for that parameter (or whether it omits it, defaulting to Appian's standard). If the raw call's value matches, the substitution is safe. If it differs, skip that specific call and report it to the user.

**These substitutions are automatic when parameter behavior is preserved.** CO/UT UI wrappers are the application standard. The added behavior (auto-trim, default messages, consistent styling) is intentional and desired. However, if the wrapper would produce a different value for a parameter than what the raw call explicitly sets, the substitution must be skipped to avoid silent behavioral changes.

---

## How to Match Inline Code to Utility Rules

The agent should follow this process for each discovered utility rule:

1. **Read the utility rule's description and parameters** — understand what it does
2. **Identify the inline equivalent** — what would the code look like if someone wrote it without knowing the utility exists?
3. **Scan the target object** for that inline pattern
4. **Verify semantic equivalence** — does the utility produce the same result for all valid inputs?
5. **Substitute if high confidence** — replace with the utility call using keyword syntax

### Pattern Matching Examples

| Utility Rule | Inline Pattern to Detect |
|---|---|
| `AS_CO_UT_isBlank` | `a!isNullOrEmpty(x)`, `or(isnull(x), x = "")`, custom null/empty checks |
| `AS_CO_UT_not` | `not(x)` where `x` could be null (utility returns true for null) |
| `AS_CO_UT_distinct` | `union(list, list)`, manual deduplication with `wherecontains` |
| `AS_CO_UT_enumForCount` | `1 + enumerate(length(list))` |
| `AS_CO_UT_left` | `left(text, n)` without null guard (utility adds null safety) |
| `AS_CO_UT_formatDate` | `text(dateValue, "MM/dd/yyyy")` or similar inline date formatting |
| `AS_CO_UT_displayUser` | `user(username, "firstName") & " " & user(username, "lastName")` |
| `AS_CO_UT_indexWhere` | `index(listB, wherecontains(value, listA), default)` |
| `AS_CO_UT_indexPath` | Nested `index(index(index(...)))` for deep field access |
| `AS_CO_UT_queryEntity` | Raw `a!queryEntity()` calls |
| `AS_CO_UT_queryRecord` | Raw `a!queryRecordType()` calls |
| `AS_CO_UT_urlForRecord` | Inline URL construction for record links |
| `AS_CO_UT_recordSafeLink` | Inline `a!safeLink()` construction for records |
| `AS_CO_UT_getSiteUrl` | Inline site URL construction (e.g., concatenating environment URL) |
| `AS_<APP>_UT_Filter` | Inline `reject()`/`where()` patterns filtering lists by field values |
| `<APP>_CO_INP_textField` | Raw `a!textField()` calls (CO wrapper adds trim, default validation) |
| `<APP>_CO_INP_dropdownField` | Raw `a!dropdownField()` calls |
| `<APP>_CO_INP_integerField` | Raw `a!integerField()` calls |
| Any `_CO_INP_*` or `_CO_DSP_*` | Raw calls to the Appian component that the CO interface wraps |

**Important:** This table is illustrative, not exhaustive. The agent must dynamically match based on the actual utility rules discovered during the Discovery phase. Always read the utility rule's signature and description to understand what inline pattern it replaces.

---

## Conservative Substitution Policy

The utility substitution step is conservative by design. Only substitute when there is high confidence that the utility rule is semantically equivalent to the inline code.

### When to Substitute Automatically

Perform the substitution without asking the user when ANY of the following are true:

**CO/UT UI wrappers (automatic when parameter behavior is preserved):**
- The discovered utility is a CO or UT **interface** that wraps a raw Appian component (e.g., `_CO_INP_textField` wraps `a!textField()`)
- The target object uses the raw Appian component that the wrapper replaces
- Map the inline parameters to the wrapper's rule inputs by name
- **For parameters in the raw call that the wrapper does not expose as inputs:** read the wrapper's SAIL definition to determine what value it sets internally (or whether it omits the parameter, letting Appian use its default). If the raw call's value **matches** what the wrapper produces (either explicitly set or via Appian default), the substitution is safe — that parameter is already handled correctly. If the raw call's value **differs** from what the wrapper produces, **skip the substitution entirely** and report it to the user with a message like: "Skipped substitution of `a!dropdownField()` → `RS_CO_CP_dropdownField` because the raw call sets `marginBelow: \"MORE\"` but the wrapper does not expose this parameter and internally uses the Appian default (`\"STANDARD\"`). Add `marginBelow` as a rule input to the wrapper if you want this substitution to apply."

**Expression rule utilities (high confidence required):**
All of the following must be true:
- The inline code's parameters map directly to the utility rule's parameters (same names or obvious equivalents)
- The utility rule produces identical output for all valid inputs (semantic equivalence is clear)
- The inline code has no custom error handling (`try()` wrappers, custom fallback logic)
- The inline code has no additional side effects beyond what the utility rule does
- The utility rule does not introduce additional behavior (logging, auditing) that would change observable behavior

### When to Ask the User

Present the candidate substitution to the user and ask whether to proceed when:

- **Uncertain equivalence** — The inline code's logic partially overlaps the utility rule but it's unclear whether all edge cases are handled identically
- **Custom error handling** — The inline code is wrapped in `try()` or has custom fallback logic that may need adjustment after substitution
- **Additional side effects** — The utility rule has behavior beyond what the inline code does (e.g., the utility logs errors, sends alerts, or writes audit records)
- **Missing parameters** — The utility rule requires parameters not present in the inline code, and the correct default value is not obvious
- **Application-specific utility with insufficient documentation** — The KB does not provide enough information about the utility rule's behavior to confirm semantic equivalence
- **Behavioral difference** — The utility adds null-safety or default handling that the inline code doesn't have (this changes behavior for null inputs)

**When asking the user, provide:**
1. The inline code snippet being considered for replacement
2. The proposed utility rule call
3. The specific reason for uncertainty

### When to Skip

Do NOT substitute (leave the inline code unchanged) when:

- The inline code uses parameters or logic not supported by the candidate utility rule
- The code already calls a utility rule (existing utility rule calls are left unchanged)
- The inline code has conditional logic, branching, or error handling that the utility rule does not replicate
- The inline code only partially overlaps the utility rule's functionality
- The utility rule's parameter types are incompatible with the values passed in the inline code
- The substitution would change behavior for edge cases (e.g., null handling differs)

---

## Worked Examples (Before/After)

### Example 1: CO UI Wrapper — Text Field (`RS_CO_INP_textField`)

```sail
/* Before — raw a!textField() */
a!textField(
  label: "Street Address",
  inputPurpose: "STREET_ADDRESS",
  marginBelow: "MORE"
)
```

```sail
/* After — CO wrapper with auto-trim and default validation */
rule!RS_CO_INP_textField(
  label: "Street Address",
  inputPurpose: "STREET_ADDRESS",
  marginBelow: "MORE"
)
```

**Note:** CO/UT UI wrappers are always substituted automatically. The wrapper's added behavior (auto-trim, default required message) is the application standard.

### Example 2: Null-Safe Negation (`AS_CO_UT_not`)

```sail
/* Before — not() without null safety */
local!isHidden: not(local!showEmployeeInformation)
```

```sail
/* After — null-safe negation (returns true for null input) */
local!isHidden: rule!AS_CO_UT_not(value: local!showEmployeeInformation)
```

**Note:** Only substitute if the null-safety behavior is desired. If the variable is always initialized (e.g., `local!showEmployeeInformation: false`), the standard `not()` is fine and substitution is unnecessary.

### Example 3: User Display Name (`AS_CO_UT_displayUser`)

```sail
/* Before — inline user name formatting */
local!displayName: user(local!username, "firstName") & " " & user(local!username, "lastName")
```

```sail
/* After — CO utility handles formatting and null safety */
local!displayName: rule!AS_CO_UT_displayUser(user: local!username)
```

### Example 4: Enumeration for Count (`AS_CO_UT_enumForCount`)

```sail
/* Before — manual enumeration */
local!indices: 1 + enumerate(length(local!vendors))
```

```sail
/* After — CO utility */
local!indices: rule!AS_CO_UT_enumForCount(list: local!vendors)
```

### Example 5: Index Where (`AS_CO_UT_indexWhere`)

```sail
/* Before — inline index-by-value lookup */
local!matchingLabel: index(
  local!labels,
  wherecontains(local!selectedCode, local!codes),
  "Unknown"
)
```

```sail
/* After — CO utility */
local!matchingLabel: rule!AS_CO_UT_indexWhere(
  lookupList: local!codes,
  lookupValue: local!selectedCode,
  returnList: local!labels,
  default: "Unknown"
)
```

### Example 6: Query Entity (when utility exists)

```sail
/* Before — raw query */
local!vendors: a!queryEntity(
  entity: cons!AS_GAM_ENT_VENDOR,
  query: a!query(
    filter: a!queryFilter(field: "isActive", operator: "=", value: true),
    pagingInfo: local!pagingInfo
  ),
  fetchTotalCount: true
)
```

```sail
/* After — CO query utility with consistent error handling */
local!vendors: rule!AS_CO_UT_queryEntity(
  entity: cons!AS_GAM_ENT_VENDOR,
  query: a!query(
    filter: a!queryFilter(field: "isActive", operator: "=", value: true),
    pagingInfo: local!pagingInfo
  ),
  fetchTotalCount: true
)
```

### Example 7: Non-Obvious Substitution with Comment

```sail
/* Before — nested index chain */
local!deepValue: index(index(index(local!data, "level1", {}), "level2", {}), "level3", null)
```

```sail
/* After */
/* Replaced nested index chain with CO utility */
local!deepValue: rule!AS_CO_UT_indexPath(
  value: local!data,
  path: "level1.level2.level3"
)
```

---

## False Positives (Do NOT Substitute)

The following patterns look like utility rule candidates but should NOT be substituted. Leave them unchanged.

### 1. Code with Custom Error Handling

```sail
/* DO NOT substitute — try() wrapper with custom fallback */
local!vendors: try(
  a!queryEntity(
    entity: cons!AS_GAM_ENT_VENDOR,
    query: a!query(pagingInfo: local!pagingInfo)
  ),
  a!map(data: {}, totalCount: 0, hasError: true, errorMessage: fv!error)
)
```

**Why:** The `try()` wrapper provides custom error handling that the utility rule does not replicate.

### 2. Inline Logic That Only Partially Overlaps

```sail
/* DO NOT substitute — conditional logic interleaved with the operation */
local!result: if(
  local!useArchive,
  a!queryEntity(entity: cons!AS_GAM_ENT_VENDOR_ARCHIVE, query: local!query),
  a!queryEntity(entity: cons!AS_GAM_ENT_VENDOR, query: local!query)
)
```

**Why:** The conditional logic selects between two different entities. The utility handles a single operation — it cannot replicate the branching.

### 3. Patterns Where Null-Safety Would Change Behavior

```sail
/* DO NOT substitute — code intentionally treats null differently */
local!isValid: not(local!maybeNull)
/* If local!maybeNull is null, not(null) returns null in standard SAIL */
/* AS_CO_UT_not would return true for null — different behavior */
```

**Why:** The utility's null-safety changes the semantics. Only substitute if the null-safe behavior is actually desired.

### 4. Code Already Using a Utility Rule

```sail
/* DO NOT substitute — already using the utility */
local!vendors: rule!AS_CO_UT_queryEntity(entity: cons!AS_GAM_ENT_VENDOR, query: local!query)
```

**Why:** Already using the utility. Substituting would be a no-op or could introduce errors.

### 5. Complex Aggregation or Non-Standard Usage

```sail
/* DO NOT substitute — aggregation query not supported by standard utility */
local!summary: a!queryEntity(
  entity: cons!AS_GAM_ENT_VENDOR,
  query: a!query(
    aggregation: a!queryAggregation(
      aggregationColumns: { a!queryAggregationColumn(field: "contractValue", aggregationFunction: "SUM") },
      groupings: a!grouping(field: "category", alias: "category")
    )
  )
)
```

**Why:** The utility is designed for standard data retrieval. Aggregation queries have different return structures.

### 6. CO/UT Wrapper Produces a Different Value for an Unsupported Parameter

```sail
/* DO NOT substitute — wrapper produces a different marginBelow value */
a!dropdownField(
  label: "Country",
  placeholder: "--- Select ---",
  value: 1,
  choiceLabels: { "United States" },
  choiceValues: { 1 },
  marginBelow: "MORE"
)
```

**Why:** The CO wrapper (`RS_CO_CP_dropdownField`) does not expose a `marginBelow` parameter and does not set it internally — so Appian defaults to `"STANDARD"`. The raw call explicitly sets `marginBelow: "MORE"`, which differs from what the wrapper would produce. Substituting would silently change the rendered margin. Skip the substitution and inform the user: "Skipped substitution of `a!dropdownField()` → `RS_CO_CP_dropdownField` because the raw call sets `marginBelow: \"MORE\"` but the wrapper does not expose this parameter and internally uses the Appian default (`\"STANDARD\"`). Add `marginBelow` as a rule input to the wrapper if you want this substitution to apply."

**Contrast — safe to substitute:**
```sail
/* OK to substitute — wrapper already produces the same value */
a!dropdownField(
  label: "Country",
  placeholder: "--- Select ---",
  value: 1,
  choiceLabels: { "United States" },
  choiceValues: { 1 },
  marginBelow: "STANDARD"
)
```
Here `marginBelow: "STANDARD"` matches the Appian default that the wrapper would produce, so the substitution is safe (the parameter can be omitted).

---

## Priority Ordering

When both a common (`AS_CO_*`) and an application-specific (`AS_<APP>_*`) utility rule match the same inline pattern:

- **Prefer the application-specific rule** if it provides more specific behavior (e.g., includes default filters, app-specific error handling, or domain-specific logic)
- **Prefer the common rule** if the application-specific rule is a simple wrapper with no additional behavior

**Example:** If `AS_GAM_UT_queryVendors` wraps `AS_CO_UT_queryEntity` but adds a default `isActive` filter, prefer `AS_GAM_UT_queryVendors` for vendor queries in the GAM application.

---

## Idempotency

Running the Utility Substitution step multiple times on the same target object is safe and produces consistent results.

**Already-substituted code is left unchanged:**
- If the target object already calls utility rules (e.g., `rule!AS_CO_UT_isBlank(...)`), those calls are not modified
- The step only acts on inline code that is NOT already using a utility rule

**Subsequent runs are no-ops:**
- After the first run substitutes all high-confidence matches, subsequent runs detect no new candidates and produce no changes
- The output is identical after the first successful run

**Previously declined substitutions:**
- If the user declined a substitution in a prior run (answered "no" when asked), do not re-prompt for the same pattern unless the code has changed
- If the code around the declined pattern has been modified, it is treated as a new candidate and may be re-evaluated

---

## Blank Property Removal

During utility substitution (and CO/UT UI wrapper substitution in particular), **remove any component properties that are set to blank or empty values**. These properties add visual noise without affecting behavior — Appian uses the same default when the property is omitted entirely.

### Properties to Remove

Remove a property from a component call when its value is any of:

| Value | Example |
|---|---|
| Empty string | `label: ""` |
| Empty list | `instructions: {}` |
| Null literal | `helpTooltip: null` |
| Blank text with only spaces | `label: " "` |

### Examples

```sail
/* Before — blank properties present */
rule!RS_CO_INP_textField(
  label: "",
  labelPosition: "ABOVE",
  value: local!name,
  saveInto: { a!save(local!name, save!value) },
  refreshAfter: "UNFOCUS",
  validations: {}
)
```

```sail
/* After — blank properties removed */
rule!RS_CO_INP_textField(
  labelPosition: "ABOVE",
  value: local!name,
  saveInto: { a!save(local!name, save!value) },
  refreshAfter: "UNFOCUS"
)
```

### Scope

- Applies to **all** component calls in the target object — both raw Appian components (`a!textField`, `a!dropdownField`, etc.) and CO/UT wrapper calls (`rule!RS_CO_INP_textField`, etc.)
- Applies during utility substitution **and** as a standalone cleanup pass — if a raw component already has blank properties before substitution, remove them regardless of whether the component is being substituted
- Does **not** apply to expression rule inputs or process variable assignments — only to component/interface function parameters

### When NOT to Remove

Do **not** remove a blank property when:

- The property is explicitly set to `""` to **override** a non-blank default (e.g., a wrapper that defaults `label` to a translated string — passing `""` intentionally suppresses it)
- The property is conditionally blank via an `if()` expression (e.g., `label: if(local!showLabel, "Name", "")`) — the blank branch is intentional
- Removing the property would change the component's rendered output (rare, but verify if uncertain)

When in doubt about whether a blank value is intentional, leave it in place.

---

## Rules Summary

1. **Automatic** — Utility substitution runs on every refactoring pass with no precondition. Silently skips if no utility rules are found.
2. **Broad discovery** — Search the full application for ALL rules matching `_UT_` and `_CO_` patterns — query utilities, general-purpose utilities, display utilities, type utilities, and reusable UI components. Do not limit to a predefined list.
3. **Signature-driven matching** — Read each discovered utility's parameters and description to understand what inline pattern it replaces. Match dynamically based on actual utility signatures, not a hardcoded pattern list.
4. **Keyword syntax required** — All substituted utility rule calls must use keyword parameter syntax.
5. **Conservative policy** — Only substitute when semantic equivalence is clear and confidence is high. Ask the user when uncertain. Never substitute code with custom error handling without confirmation. CO/UT UI wrappers are auto-substituted only when the wrapper produces the same behavior for all parameters. If the raw call sets a parameter to a value that differs from what the wrapper produces internally (or via Appian default), skip the substitution and inform the user that the wrapper needs the parameter added.
6. **Idempotent** — Code already using utility rules is left unchanged. Subsequent runs produce no changes. Previously declined substitutions are not re-prompted.
7. **Comment annotation** — Add a comment above the substituted call only when the substitution is non-obvious.
8. **Priority ordering** — When both a common and application-specific utility match, prefer the application-specific rule if it provides more specific behavior.
9. **Reporting** — After completing all substitutions, report a summary: count of substitutions made and which utility rules were used.
10. **Do not alter behavior** — The output for all valid inputs must remain identical after substitution. If in doubt, skip.
11. **False positives** — Do not substitute code with custom error handling, conditional branching, aggregation queries, or patterns where the utility's null-safety would change behavior.
12. **Preserve `#"..."` references** — When deploying via `refactor_and_deploy`, work with the `#"SYSTEM_SYSRULES_*"` format from the export. Only replace the specific `#"..."` references that correspond to the utility substitution (e.g., replace `#"SYSTEM_SYSRULES_textField"(...)` with `rule!RS_CO_INP_textField(...)`). Leave all other `#"..."` references untouched — do NOT convert them to human-readable function names like `a!textField()` or `a!formLayout()`, as this causes versioned function resolution errors on deploy.
13. **Remove blank properties** — Strip properties set to `""`, `{}`, `null`, or whitespace-only strings from all component calls. These are no-ops that add noise. Exception: do not remove blank values that intentionally override a non-blank default or that are part of conditional expressions.
