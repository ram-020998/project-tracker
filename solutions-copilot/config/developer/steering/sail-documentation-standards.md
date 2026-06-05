---
inclusion: manual
---

# SAIL Documentation Standards

Guidelines for adding comments, descriptions, and documentation to SAIL code during refactoring.

---

## Header Comment Block

Every expression rule, interface, or decision should have a header block:

```sail
/*
 * =============================================================================
 * PURPOSE: {what this rule does}
 * OUTPUT:  {return value type and description}
 * ALGORITHM:
 *   1. {Step 1}
 *   2. {Step 2}
 * =============================================================================
 */
```

**NEVER include the object name, object type, or INPUTS list in the header block.** The object name and inputs are already visible in Appian Designer's UI and in the rule input descriptions — repeating them in the comment is redundant noise. The header contains ONLY: PURPOSE, OUTPUT, and ALGORITHM.

---

## Section Comments

Use section dividers to separate logical steps:

```sail
  /* ─────────────────────────────────────────────────────────────────────────────
   * STEP N: {Description}
   * ───────────────────────────────────────────────────────────────────────────── */
```

---

## Extract Intermediate Variables

Break complex nested expressions into named locals for readability:

```sail
/* BAD */
local!result: index(index(local!data, wherecontains(max(todecimal(apply(...))), todecimal(apply(...))), null), 1, {})

/* GOOD */
local!numericWeights: todecimal(apply(index(local!weightMap, _, 0), local!data.similarity)),
local!maxIndices: wherecontains(max(local!numericWeights), local!numericWeights),
local!result: index(index(local!data, local!maxIndices, null), 1, {})
```

---

## Explain Non-Obvious Patterns

Add inline comments for SAIL idioms that aren't self-explanatory:

```sail
/* union(x, x) is used as a distinct/unique operation in SAIL */
local!uniqueIds: union(local!data.id, local!data.id),
```

---

## Mark TODOs

Flag incomplete or questionable logic for future attention:

```sail
/* TODO: Map all SBA type codes correctly. Currently only A9 (WOSB) is mapped. */
```

---

## Rule Input Descriptions

When using `refactor_and_deploy` or `rebuild_export_package`, always populate `rule_input_descriptions` with a clear one-liner for each parameter:

```json
{
  "searchText": "Free-text search query to filter results",
  "batchSize": "Maximum number of results to return (default: 20)"
}
```

---

## Object Description

Always set `object_description` to a concise summary of what the rule does, its primary use case, return type, and output format. Keep it under 2 sentences.

**Example:**
```
"Classifies a person into a role/tier label based on type, status, department, tenure, and salary. Returns a single Text string (e.g., 'Senior Engineer - High Comp', 'Junior Sales')."
```

---

## Rules

- **DO NOT** change functional logic — output must be identical
- **DO NOT** rename rule inputs (ri! parameters)
- **DO NOT** change `#"..."` references (object UUIDs, system rules)
- **DO** add comments, extract variables, improve formatting
- **DO** fix typos in variable names or comments
- **DO** use `tointeger()` when comparing date intervals to numbers
- **DO** prefer `a!match` over nested `if()` chains for multi-branch logic
- **DO** handle null inputs gracefully (use `a!match` default or `a!defaultValue`)
