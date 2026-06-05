---
inclusion: manual
---

# Translation Substitution — Refactoring Step

Guidelines for how the refactor tools handle translation references during SAIL refactoring.

---

## Overview

When a package contains a Translation Set, the refactor tools (`refactor_and_deploy`, `rebuild_export_package`) automatically handle internationalization:

1. Parse the existing Translation Set and Translation Strings from the export ZIP
2. Scan the SAIL definition for translatable strings in label parameters
3. Create new translation string entries for any strings NOT already in the Translation Map
4. Substitute ALL translation references (existing + newly created) in the SAIL code
5. Add the new translation string XML files to the export package
6. Skip the deploy entirely if no changes are needed (idempotent)

If no Translation Set exists in the package, this step is silently skipped.

---

## Translation Reference Syntax

The correct syntax for a translation reference is a **single-quoted string** containing the `translation!` keyword:

```
'translation!{<set-uuid>}<Set Name>.{<entry-uuid>}<Entry Text>'
```

**CRITICAL:** Translation references MUST be wrapped in single quotes (`'...'`). This is how Appian stores them internally in the XML export format. Using bare (unquoted) `translation!` references will cause import failures.

**Example:**

```sail
/* Before */
label: "Submit Request",

/* After */
label: 'translation!{a1b2c3d4-e5f6-7890-abcd-ef1234567890}My Translation Set.{f9e8d7c6-b5a4-3210-fedc-ba0987654321}Submit Request',
```

---

## Parameterized Translations (Dynamic Strings)

When a translatable string contains dynamic content (e.g., a variable name, count, or user-provided value), use **translation parameters** instead of string concatenation. This keeps the full sentence structure available to translators while injecting runtime values.

### Syntax

```
'translation!{<set-uuid>}<Set Name>.{<entry-uuid>}<Entry text with {paramName}>'('translation!{<set-uuid>}<Set Name>.{<entry-uuid>}<Entry text with {paramName}>.translationvariables.{<variable-uuid>}paramName': <SAIL expression>)
```

**Structure breakdown:**

1. **Translation reference** — the entry text contains placeholders in curly braces: `{paramName}`
2. **Parameter bindings** — immediately after the closing single quote, parentheses contain key-value pairs
3. **Parameter key** — the full translation path extended with `.translationvariables.{<variable-uuid>}paramName`
4. **Parameter value** — any SAIL expression that resolves to the dynamic value

### Example

```sail
/* Before (concatenation — BAD for i18n) */
text: "Animal: " & fv!item,

/* After (parameterized translation — GOOD) */
text: 'translation!{fa247119-ddfc-4173-9980-1451d2c04d5b}RS Translations.{cdd633b0-477b-47d1-8890-2ea44596592d}Animal: {animalName}'('translation!{fa247119-ddfc-4173-9980-1451d2c04d5b}RS Translations.{cdd633b0-477b-47d1-8890-2ea44596592d}Animal: {animalName}.translationvariables.{388abe24-78d4-4ba2-b4cc-caf259002413}animalName': fv!item),
```

### Multiple Parameters

A single translation entry can have multiple parameters:

```sail
/* Entry text: "Showing {count} results for {query}" */
label: 'translation!{set-uuid}App Translations.{entry-uuid}Showing {count} results for {query}'(
  'translation!{set-uuid}App Translations.{entry-uuid}Showing {count} results for {query}.translationvariables.{var-uuid-1}count': local!totalCount,
  'translation!{set-uuid}App Translations.{entry-uuid}Showing {count} results for {query}.translationvariables.{var-uuid-2}query': local!searchText
),
```

### When to Use Parameterized Translations

Use parameterized translations when a label parameter contains:
- String concatenation with a dynamic value (e.g., `"Total: " & local!count`)
- An `if()` that builds a sentence with embedded variables
- A `concat()` or `&` combining static text with runtime data

**Do NOT use** parameterized translations for:
- Fully static strings (use regular translation references)
- Strings that are entirely dynamic with no static text (don't translate at all)
- System values or non-label parameters

### Detection Pattern

The refactor tools detect candidates for parameterized translation by looking for:
- `"static text" & <expression>` in a label parameter
- `concat("static text", <expression>)` in a label parameter
- `"text " & variable & " more text"` patterns
- `"static A" & "static B"` — pure static concatenation (see below)
- `if(condition, "text A", "text B")` — conditional static strings (see below)

---

## Concatenated Static Strings

When a label parameter contains **only static strings** joined by `&` or `concat()`, the tool must first resolve the concatenation into a single string, then create a single translation entry for the combined result.

### Example: Pure Static Concatenation

```sail
/* Before — concatenated static strings */
a!textField(
  label: "Vendor" & " " & "Name"
)
```

```sail
/* After — single translation entry for the resolved string */
a!textField(
  label: 'translation!{set-uuid}App Translations.{entry-uuid}Vendor Name'
)
```

**Rule:** If ALL segments of a concatenation are string literals (no variables, no function calls), collapse them into one string and translate the result as a single entry.

### Example: Mixed Static + Dynamic Concatenation

```sail
/* Before — static text concatenated with dynamic value */
a!richTextItem(
  text: "Total: " & "$" & local!amount
)
```

```sail
/* After — parameterized translation with collapsed static prefix */
a!richTextItem(
  text: 'translation!{set-uuid}App Translations.{entry-uuid}Total: ${amount}'('translation!{set-uuid}App Translations.{entry-uuid}Total: ${amount}.translationvariables.{var-uuid}amount': local!amount)
)
```

**Rule:** Collapse adjacent static segments first (`"Total: " & "$"` → `"Total: $"`), then treat remaining dynamic parts as parameters.

---

## Function-Wrapped Translatable Strings

When a label parameter's value is wrapped in a function (e.g., `if()`, `choose()`, `a!match()`), the tool must look **inside** the function for translatable string literals and substitute each one individually. The function structure itself is preserved.

### Example: `if()` with Static Strings

```sail
/* Before — if() selecting between two static labels */
a!textField(
  label: if(local!isNew, "Create Vendor", "Edit Vendor")
)
```

```sail
/* After — each branch translated independently, if() preserved */
a!textField(
  label: if(
    local!isNew,
    'translation!{set-uuid}App Translations.{entry-uuid-1}Create Vendor',
    'translation!{set-uuid}App Translations.{entry-uuid-2}Edit Vendor'
  )
)
```

### Example: `if()` with Concatenation Inside a Branch

```sail
/* Before — if() with concatenation in one branch */
a!richTextItem(
  text: if(
    local!count > 0,
    local!count & " items found",
    "No items found"
  )
)
```

```sail
/* After — parameterized translation in first branch, regular translation in second */
a!richTextItem(
  text: if(
    local!count > 0,
    'translation!{set-uuid}App Translations.{entry-uuid-1}{count} items found'('translation!{set-uuid}App Translations.{entry-uuid-1}{count} items found.translationvariables.{var-uuid}count': local!count),
    'translation!{set-uuid}App Translations.{entry-uuid-2}No items found'
  )
)
```

### Example: `choose()` with Multiple Static Strings

```sail
/* Before */
a!textField(
  label: choose(local!step, "Personal Info", "Address", "Review")
)
```

```sail
/* After — each choice translated independently */
a!textField(
  label: choose(
    local!step,
    'translation!{set-uuid}App Translations.{entry-uuid-1}Personal Info',
    'translation!{set-uuid}App Translations.{entry-uuid-2}Address',
    'translation!{set-uuid}App Translations.{entry-uuid-3}Review'
  )
)
```

### Example: Nested `if()` with Mixed Content

```sail
/* Before */
a!textField(
  label: if(
    local!isAdmin,
    "Admin: " & local!sectionName,
    if(local!isManager, "Manager View", "Standard View")
  )
)
```

```sail
/* After */
a!textField(
  label: if(
    local!isAdmin,
    'translation!{set-uuid}App Translations.{entry-uuid-1}Admin: {sectionName}'('translation!{set-uuid}App Translations.{entry-uuid-1}Admin: {sectionName}.translationvariables.{var-uuid}sectionName': local!sectionName),
    if(
      local!isManager,
      'translation!{set-uuid}App Translations.{entry-uuid-2}Manager View',
      'translation!{set-uuid}App Translations.{entry-uuid-3}Standard View'
    )
  )
)
```

### Rules for Function-Wrapped Strings

1. **Preserve the function structure** — do not flatten or remove `if()`, `choose()`, `a!match()`, or other control-flow functions
2. **Translate each string literal independently** — each branch/option gets its own translation entry
3. **Apply concatenation rules within branches** — if a branch contains `"text" & variable`, use parameterized translation for that branch
4. **Recurse into nested functions** — if an `if()` contains another `if()`, process both levels
5. **Skip non-string branches** — if a branch returns a variable, null, or non-string expression, leave it unchanged
6. **Skip entirely dynamic expressions** — if the function returns only variables with no static text, do not translate

### When NOT to Translate Inside Functions

Do not translate strings inside functions when:
- The function is NOT in a label parameter (e.g., it's in `value`, `saveInto`, or `data`)
- The string is a system value (e.g., `if(condition, "ABOVE", "BELOW")`)
- The entire expression resolves to a non-display value (e.g., field names, operator values)
- The function is `text()`, `tostring()`, or a formatting function operating on data (not display text)

---

### Rules for Parameter Names

- Use **camelCase** names that describe the dynamic value: `vendorName`, `totalCount`, `statusLabel`
- Keep names short but descriptive
- Each parameter gets its own UUID (generated automatically by the tool)

---

## Safe Parameters (Label_Parameters)

Only strings in these parameters are candidates for translation:

| Parameter | Description |
|-----------|-------------|
| `label` | Field and component labels |
| `placeholder` | Input placeholder text |
| `placeholderLabel` | Dropdown/picker placeholder text |
| `instructions` | Field instruction text |
| `title` | Section and layout titles |
| `secondaryText` | Secondary display text |
| `text` | Rich text item display text |
| `buttonLabel` | Button display text |
| `confirmButtonLabel` | Confirmation button text |
| `cancelButtonLabel` | Cancel button text |
| `emptyGridMessage` | Message shown in empty grids |
| `headerTitle` | Header title text |
| `tooltip` | Tooltip text |
| `helpTooltip` | Help tooltip text |
| `accessibilityText` | Accessibility/screen reader text |
| `choiceLabels` | Dropdown/radio choice display text |

---

## Expression Rules Returning Display Labels

When an expression rule returns user-facing display text (status labels, tier names, category labels, summary strings, etc.), those hardcoded strings are **also candidates for translation** — even though they don't appear in a label parameter directly.

### How to identify

An expression rule needs translation coverage when:
- It returns a map/dictionary with fields like `statusLabel`, `tierLabel`, `summary`, `displayName`, or similar
- It contains hardcoded display strings in arrays (e.g., `{"Active", "Inactive", "Pending"}`)
- It builds user-facing text via concatenation (e.g., `local!catLabel & " Vendor"`)
- Its output is consumed by an interface in a `label`, `value`, or `text` parameter that is displayed to users

### What to translate

| Pattern in expression rule | Action |
|---|---|
| `local!statusLabels: {"Active", "Inactive", "Pending"}` | Translate each array element |
| `local!tier: "Platinum"` / `"Gold"` / `"Silver"` / `"Bronze"` | Translate each tier string |
| `local!summary: local!catLabel & " Vendor"` | Use parameterized translation |
| `"Unknown"` as a fallback label | Translate |
| `"Uncategorized Vendor"` | Translate |

### What NOT to translate in expression rules

| Pattern | Reason |
|---|---|
| Status codes: `"A"`, `"I"`, `"P"`, `"S"` | System values, not display text |
| Field names in maps: `vendorName:`, `score:` | Structural keys, not display text |
| Values used in comparisons: `ri!vendor.status = "I"` | Logic, not display text |

### Deployment behavior

When a Translation Set exists in the package and the expression rule contains translatable display strings:
1. The tool creates translation entries for each display string
2. Substitutes `translation!` references in the SAIL code
3. Deploys both the updated expression rule AND the new translation entries

**This ensures that ALL objects in a package get consistent translation coverage** — not just interfaces.

---

## System Values — Never Substitute

The following string values represent system constants, style tokens, field names, or operator values. They are NEVER translated, even if they appear in a label parameter:

### Style and Layout Constants

```
"ABOVE", "BELOW", "ADJACENT", "COLLAPSED", "JUSTIFIED"
"LEFT", "CENTER", "RIGHT"
"PRIMARY", "SECONDARY", "ACCENT", "POSITIVE", "NEGATIVE", "LINK"
"STANDARD", "SHORT", "TALL", "AUTO"
"SMALL", "MEDIUM", "LARGE", "EXTRA_LARGE"
"FIT", "NARROW", "MEDIUM_PLUS", "WIDE"
"ICON", "SOLID", "OUTLINE"
```

### Data Type and Format Constants

```
"INTEGER", "DECIMAL", "TEXT", "DATE", "DATETIME", "BOOLEAN"
"SEARCH", "EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN"
"STARTS_WITH", "ENDS_WITH", "CONTAINS", "BETWEEN", "IN"
"ASC", "DESC"
```

### Identification Patterns

- Field names (e.g., `"vendorId"`, `"status"`, `"createdDate"`)
- Record field references (e.g., `"recordType!{...}..."`)
- Operator values used in `a!queryFilter`
- Values used in `choiceValues` parameters
- Values used in `value` parameters of `a!queryFilter`

---

## Idempotency

Running the refactor tools multiple times on the same package is safe:
- First run: creates entries and substitutes strings → deploys
- Subsequent runs: detects no changes needed → returns `"✅ No changes needed"` without deploying

---

## Manual Refactoring (AI-generated SAIL)

When the AI refactors SAIL code directly (providing `new_definition`), the translation step runs AFTER the new definition is set. This means:

- If the refactored code introduces new hardcoded strings in label parameters, they will be automatically translated
- If the refactored code already uses `translation!` references, they are left alone
- The AI does NOT need to manually substitute translations — the tool handles it

---

## Worked Examples

### Automatic Translation Creation

Given an interface with no existing translations:

```sail
/* Input SAIL */
a!textField(
  label: "Vendor Name",
  placeholder: "Enter vendor name",
  value: local!vendor.name,
  readOnly: true
)
```

The tool automatically:
1. Creates translation string entries for "Vendor Name" and "Enter vendor name"
2. Produces:

```sail
a!textField(
  label: 'translation!{set-uuid}App Translations.{entry-uuid-1}Vendor Name',
  placeholder: 'translation!{set-uuid}App Translations.{entry-uuid-2}Enter vendor name',
  value: local!vendor.name,
  readOnly: true
)
```

### System Values Left Unchanged

```sail
/* System values are never translated */
a!textField(
  label: 'translation!{...}Vendor Name',
  labelPosition: "ABOVE",
  value: local!vendor.name
)
```

### Non-Label Parameters Left Unchanged

```sail
/* Only label parameters are translated */
a!dropdownField(
  label: 'translation!{...}Status',
  choiceLabels: {'translation!{...}Active', 'translation!{...}Inactive'},
  choiceValues: {"ACTIVE", "INACTIVE"},
  value: local!status
)
```

### Parameterized Translation (Dynamic String)

Given a label that concatenates static text with a dynamic value:

```sail
/* Input SAIL */
a!richTextItem(
  text: "Welcome, " & local!userName & "!"
)
```

The tool automatically:
1. Detects the concatenation pattern in a label parameter
2. Creates a parameterized translation entry with placeholder: `Welcome, {userName}!`
3. Generates a translation variable UUID for `userName`
4. Produces:

```sail
a!richTextItem(
  text: 'translation!{set-uuid}App Translations.{entry-uuid}Welcome, {userName}!'('translation!{set-uuid}App Translations.{entry-uuid}Welcome, {userName}!.translationvariables.{var-uuid}userName': local!userName)
)
```

### Parameterized Translation in a!forEach

```sail
/* Input SAIL */
a!forEach(
  local!items,
  a!richTextItem(
    text: "Item: " & fv!item
  )
)
```

Produces:

```sail
a!forEach(
  local!items,
  a!richTextItem(
    text: 'translation!{set-uuid}App Translations.{entry-uuid}Item: {itemName}'('translation!{set-uuid}App Translations.{entry-uuid}Item: {itemName}.translationvariables.{var-uuid}itemName': fv!item)
  )
)
```

---

## Rules Summary

1. **Automatic** — if a Translation Set exists in the package, translations are always handled
2. **Only label parameters** are candidates (see table above) plus `choiceLabels`
3. **Never substitute** system values regardless of context
4. **Creates new entries** for any translatable string not already in the Translation Map
5. **Exact match** — existing entries are matched case-sensitively
6. **Idempotent** — safe to run multiple times; no-op if nothing changed
7. **Do not modify** strings in non-label parameters (`value`, `choiceValues`, `saveInto`, `data`, etc.)
8. **AI does not need to handle translations manually** — the tool does it automatically during rebuild
9. **Dynamic strings use parameters** — when a label contains concatenation with runtime values, use parameterized translations instead of splitting into multiple entries
10. **Never concatenate translations** — use a single parameterized entry rather than `translation! & variable & translation!`
11. **Collapse static concatenation** — when all segments of a `&` or `concat()` are string literals, resolve them into a single string and create one translation entry for the result
12. **Translate inside functions** — when a label parameter is wrapped in `if()`, `choose()`, or similar control-flow functions, preserve the function structure and translate each string literal branch independently
13. **Recurse into nested functions** — process all levels of nesting (e.g., `if()` inside `if()`) and apply concatenation/parameterization rules within each branch
