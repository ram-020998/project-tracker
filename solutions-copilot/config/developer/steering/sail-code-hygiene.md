---
inclusion: manual
---

# SAIL Code Hygiene Standards

Apply these transformations when refactoring SAIL code for readability, performance, and best practices. These rules are applied **in addition to** documentation standards.

---

## 1. Control Flow: Replace Nested `if()` with `a!match`

Nested `if()` chains with 3+ branches should be replaced with `a!match`.

**Before:**
```sail
if(ri!status = "A", "Active",
  if(ri!status = "I", "Inactive",
    if(ri!status = "P", "Pending", "Unknown")))
```

**After:**
```sail
a!match(
  value: ri!status,
  equals: "A", then: "Active",
  equals: "I", then: "Inactive",
  equals: "P", then: "Pending",
  default: "Unknown"
)
```

For threshold-based branching (score tiers, date ranges), use `value: true` pattern:
```sail
a!match(
  value: true,
  equals: local!score >= 95, then: "Platinum",
  equals: local!score >= 90, then: "Gold",
  equals: local!score >= 80, then: "Silver",
  default: "Bronze"
)
```

---

## 2. Null Safety

### Rule inputs must be null-safe
- Wrap the final return in `a!match` with a `default:` that handles null gracefully
- Use `a!defaultValue(ri!param, fallback)` for parameters that need defaults
- Never assume rule inputs will be populated

### Common patterns:
```sail
/* Null-safe return using a!match */
a!match(
  value: ri!returnType,
  equals: "count", then: length(local!results),
  equals: "top3",  then: index(local!results, 1 + enumerate(3), {}),
  default: local!results  /* handles null, empty, or unexpected values */
)

/* Null-safe parameter with default */
local!batchSize: a!defaultValue(value: ri!batchSize, default: 20),
```

### Boolean initialization
- Always initialize booleans as `true` or `false`, never `null`
- `local!isEditMode: false` not `local!isEditMode: null`

---

## 3. Type Safety

### Date interval comparisons
`today() - dateValue` returns an `Interval (Day to Second)`, not an integer. Always wrap with `tointeger()` before comparing to a number:

```sail
/* BAD — runtime error */
local!daysSince: today() - local!createdDate,
local!isRecent: local!daysSince <= 30

/* GOOD */
local!daysSince: tointeger(today() - local!createdDate),
local!isRecent: local!daysSince <= 30
```

### Strong typing for CDT variables
```sail
/* GOOD */
local!vendor: type!AS_GAM_Vendor(null),
local!vendors: cast(type!AS_GAM_Vendor, {}),

/* BAD */
local!vendor: null,
local!vendors: {},
```

### Rule input types must match actual usage
If the code calls `tointeger(ri!param)`, `todecimal(ri!param)`, or `todate(ri!param)`, the input should be declared with the correct type so the cast is unnecessary:

| Code pattern | Input should be typed as | Then remove |
|---|---|---|
| `tointeger(ri!yearsOfService)` | `int` | the `tointeger()` wrapper |
| `todecimal(ri!salary)` | `decimal` | the `todecimal()` wrapper |
| `todate(ri!startDate)` | `date` | the `todate()` wrapper |
| `todatetime(ri!timestamp)` | `datetime` | the `todatetime()` wrapper |

When using `refactor_and_deploy`, pass the `rule_inputs` parameter with correct types:
```json
"rule_inputs": [
  {"name": "yearsOfService", "type": "int"},
  {"name": "salary", "type": "decimal"},
  {"name": "terminationDate", "type": "date"}
]
```

---

## 4. Variable Naming

| Pattern | Rule |
|---------|------|
| Arrays | Use plural names: `local!vendors`, not `local!vendor` for a list |
| Booleans | Prefix with `is`, `show`, `allow`, `has`: `local!isActive` |
| Affirmative | Use `local!isActive` not `local!isNotInactive` |
| Descriptive | `local!highPerformers` not `local!x` or `local!temp` |
| Consistent | Same concept = same name across the app |

Rename cryptic variables during cleanup:
- `local!d` → `local!vendors`
- `local!x` → `local!filteredResults`
- `local!z` → `local!categoryFiltered`

---

## 5. Simplify Filter Patterns

### Combine forEach + reject into a single step
When filtering a list, use one `reject(fn!isnull, forEach(...))` instead of two separate steps:

**Before (two steps):**
```sail
local!x: a!forEach(items: local!data, expression: if(fv!item.score >= 80, fv!item, {})),
local!y: reject(fn!isnull, a!forEach(items: local!x, expression: if(a!isNullOrEmpty(fv!item), null, fv!item))),
```

**After (one step):**
```sail
local!highPerformers: reject(
  fn!isnull,
  a!forEach(items: local!data, expression: if(fv!item.score >= 80, fv!item, null))
),
```

---

## 6. Extract Repeated Logic

If the same expression appears 2+ times, extract it to a local variable:

**Before:**
```sail
if(
  and(not(isnull(ri!vendor)), ri!vendor.status = "Active", ri!vendor.approvalDate < today()),
  "Approved",
  if(
    and(not(isnull(ri!vendor)), ri!vendor.status = "Active", ri!vendor.approvalDate < today()),
    "Show Details",
    "Pending"
  )
)
```

**After:**
```sail
local!isApproved: and(
  not(isnull(ri!vendor)),
  ri!vendor.status = "Active",
  ri!vendor.approvalDate < today()
),
if(local!isApproved, "Approved", if(local!isApproved, "Show Details", "Pending"))
```

---

## 7. Simplify Boolean Expressions

### Remove redundant `if(condition, true, false)`
```sail
/* BAD */
isHighPerformer: if(fv!item.score >= 90, true, false)

/* GOOD */
isHighPerformer: fv!item.score >= 90
```

### Use `not()` instead of `= false`
```sail
/* BAD */
if(local!isActive = false, ...)

/* GOOD */
if(not(local!isActive), ...)
```

---

## 8. Extract Intermediate Variables in Complex Expressions

Break deeply nested expressions into named locals:

**Before:**
```sail
local!result: index(index(local!data, wherecontains(max(todecimal(apply(...))), todecimal(apply(...))), null), 1, {})
```

**After:**
```sail
local!numericWeights: todecimal(apply(index(local!weightMap, _, 0), local!data.similarity)),
local!maxIndices: wherecontains(max(local!numericWeights), local!numericWeights),
local!result: index(index(local!data, local!maxIndices, null), 1, {})
```

---

## 9. Use Modern SAIL Functions

| Legacy Pattern | Modern Replacement |
|---------------|-------------------|
| Versioned functions (`a!gridField_24r3`) | Current version (`a!gridField`) |
| `property(obj, "field", null)` | Dot notation: `obj.field` |
| `index(array, "field", null)` for CDTs | Dot notation: `array.field` |
| Nested `if()` (3+ branches) | `a!match()` |
| `if(condition, true, false)` | Just `condition` |
| `if(isnull(x), default, x)` | `a!defaultValue(value: x, default: fallback)` |

---

## 10. Parameter Passing

- Always use keyword syntax: `rule!myRule(vendorId: local!id)` not positional
- **All function calls must use named parameters** — this applies to built-in functions too, not just rule calls:
  ```sail
  /* BAD — positional */
  a!defaultValue(ri!batchSize, 20)
  index(local!vendors, 1, {})
  contains(local!categories, fv!item.cat)

  /* GOOD — named parameters */
  a!defaultValue(value: ri!batchSize, default: 20)
  index(data: local!vendors, index: 1, default: {})
  contains(list: local!categories, value: fv!item.cat)
  ```
- Pass full CDTs to expression rules rather than individual fields
- Use `is`, `show`, `allow` prefixes for boolean parameters
- Don't pass contextual/derivable parameters (e.g., don't pass both `vendor` and `vendorId`)

---

## 11. Query Patterns

- Use `AS_CO_UT_queryEntity()` or `AS_CO_UT_queryRecord()` over raw query functions **when available in the target application**. The Utility Substitution step (step 3.5) proactively handles this and other utility substitutions — Section 11 serves as a safety net for query patterns missed. If the application does not have these utility rules, leave raw query calls unchanged.
- Include default filter on `isActive`/`isDeleted` fields
- One query rule per entity with optional filter parameters
- Never `queryRecord` + cast to CDT — use `queryEntity` directly

---

## 12. Saves and State

- Always wrap `a!save()` in curly braces: `saveInto: { a!save(...) }`
- Use boolean locals for two-state toggles, text/integer for 3+ states
- Use `triggerRefresh` pattern for resetting form state

---

## 13. Remove Unused Rule Inputs and Local Variables

**This section applies to ALL object types: Expression Rules, Interfaces, and Decisions.**

### Unused rule inputs (`ri!`)
- If a rule input is declared but never referenced in the expression body, **remove it**
- This applies to **both expression rules AND interfaces** — interfaces commonly accumulate unused inputs over time as features are added/removed
- Check all branches (including conditional paths) before removing — an input used only in one `if()` branch is still used
- Removing unused inputs reduces confusion for callers and simplifies the object's contract

**How to identify:**
- Search the definition for each `ri!paramName`
- If zero occurrences exist in the expression body, it's unused
- Exception: if the rule input is passed through to a sub-rule via `ri!paramName` in a `rule!` call, it's still in use
- **For interfaces:** also check `saveInto` parameters — an input used only in `saveInto: ri!param` is still in use

### Unused local variables
- If a `local!` variable is assigned but never referenced after assignment, **remove it**
- Check that removing it doesn't break the evaluation order (e.g., a variable with side effects like `a!save`)

**Before:**
```sail
a!localVariables(
  local!vendors: rule!getVendors(),
  local!unusedCount: length(local!vendors),  /* never referenced below */
  local!categories: rule!getCategories(),
  local!unusedFlag: true,  /* never referenced below */

  a!gridField(data: local!vendors, ...)
)
```

**After:**
```sail
a!localVariables(
  local!vendors: rule!getVendors(),
  local!categories: rule!getCategories(),

  a!gridField(data: local!vendors, ...)
)
```

### Safety checks before removal
1. Confirm the variable/input is not referenced anywhere in the definition (including comments that reference it as documentation — those comments can be removed too)
2. For rule inputs: confirm removal won't break callers. If unsure, add a `/* TODO: Unused input — verify no callers pass this before removing */` comment instead of removing
3. For local variables: confirm the assignment has no side effects (queries with `a!save`, `a!writeRecords`, etc. must stay even if the result is unused)

### Deploying rule input changes with `remove_inputs` parameter
When using `refactor_and_deploy` or `rebuild_export_package`, always pass `remove_inputs` to remove unused inputs:
- **Remove** any `ri!` parameters not referenced in the definition
- Only include inputs in `rule_input_descriptions` that will remain after removal

```
remove_inputs: ["pizza", "unusedParam"]
rule_input_descriptions: {
  "vendor": "The vendor record with name, status, evaluations",
  "categories": "Reference data list with .code and .label fields"
}
```

For type corrections (e.g., code does `tointeger(ri!x)` but input is typed as `string`), this requires manual correction in Appian Designer — the deployment API does not support retyping existing inputs.

---

## 14. Interface-Specific Hygiene

These patterns apply only when refactoring interfaces (not expression rules).

### Keep logic minimal in interfaces
- Interfaces should handle **layout and interaction**, not business logic
- If a block of logic is more than a simple boolean switch or null check, extract it to an expression rule
- **Good:** `local!validationErrors: rule!AS_GAM_VD_validateVendor(vendor: local!vendor)`
- **Bad:** 50 lines of inline validation logic inside the interface

### Do NOT extract inline UI components into local variables
Presentational components that are only used once should stay inline where they're rendered. Do not pull `a!forEach`, `a!richTextItem`, grid columns, or similar UI building blocks into local variables just to reduce nesting depth. Structural nesting (formLayout → sectionLayout → richTextDisplayField → forEach → richTextItem) is expected and idiomatic — flattening it into variables makes the code harder to follow, not easier.

**Only extract into a local variable when:**
- The same component/expression is used 2+ times (deduplication)
- The expression involves complex business logic that benefits from a descriptive name
- The variable is used in a conditional branch (e.g., show different content based on state)

**BAD — extracting for no reason:**
```sail
local!animalItems: a!forEach(local!animals, a!richTextItem(text: fv!item)),
local!vendorItem: a!richTextItem(text: local!vendorName),

a!richTextDisplayField(value: { local!animalItems, local!vendorItem })
```

**GOOD — keep inline:**
```sail
a!richTextDisplayField(
  value: {
    a!forEach(local!animals, a!richTextItem(text: fv!item)),
    a!richTextItem(text: local!vendorName)
  }
)
```

### Use `showWhen` over conditional wrapping
```sail
/* BAD — wrapping component in if() */
if(local!isAdmin, a!buttonWidget(label: "Delete", ...), {})

/* GOOD — use showWhen parameter */
a!buttonWidget(
  label: "Delete",
  showWhen: local!isAdmin
)
```

### Saves always in curly braces
Even with a single save, wrap in `{}` for consistency and safety when adding more later:
```sail
/* BAD */
saveInto: a!save(local!value, save!value)

/* GOOD */
saveInto: {
  a!save(local!value, save!value)
}
```

### State management
| States | Pattern |
|--------|---------|
| 2 (toggle) | Boolean: `local!isEditMode: false` |
| 3+ (tabs, steps) | Text or integer: `local!currentStep: 1` |
| Reset all | `triggerRefresh` pattern with counter or boolean flip |

**Bad (multiple booleans for multi-state):**
```sail
local!showList: true,
local!showGrid: false,
local!showCalendar: false
```

**Good (single state variable):**
```sail
local!viewMode: "list",  /* "list", "grid", "calendar" */
```

### Load data at top level, pass down
- Load reference data, bundle data, and queries **once** at the top-level interface
- Pass results to child components via rule inputs — don't re-query in children

```sail
/* GOOD — load once, pass down */
a!localVariables(
  local!categories: rule!AS_GAM_REF_categories(),
  local!bundleData: rule!AS_GAM_I18N_UT_getBundleData(),

  a!formLayout(
    contents: {
      rule!AS_GAM_SCT_VendorDetails(
        categories: local!categories,
        bundleData: local!bundleData
      )
    }
  )
)
```

### Accessibility
- Every input field must have a `label` (use `labelPosition: "COLLAPSED"` to hide visually if needed, not omit the label)
- Icons and images need `accessibilityText`
- Use `a!richTextItem(text: ..., size: "MEDIUM")` over raw text for screen reader compatibility

### Parameter ordering in components
Order parameters from simple to complex for readability:
```sail
/* GOOD — simple params first, complex last */
a!gridField(
  label: "Vendors",
  labelPosition: "ABOVE",
  data: local!vendors,
  columns: { ... },
  rowHeader: 1
)
```

---

## Rules of Engagement

1. **DO NOT** change functional logic — output must remain identical for all valid inputs
2. **DO NOT** rename rule inputs (`ri!` parameters)
3. **DO NOT** change `#"..."` references (object UUIDs, system rules)
4. **DO** apply all applicable cleanup patterns from this file
5. **DO** verify type safety (especially date intervals and null comparisons)
6. **DO** test mentally that refactored code produces the same output
7. **DO** always pass `rule_inputs` with correct types when deploying — remove unused inputs, add missing ones, fix types to eliminate unnecessary casts
8. When in doubt about whether a change alters behavior, leave it and add a `/* TODO: ... */` comment
