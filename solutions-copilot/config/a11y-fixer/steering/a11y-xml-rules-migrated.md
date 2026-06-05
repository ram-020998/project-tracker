# A11Y XML Manipulation Rules

## Critical Context

Appian interface XML has this structure:
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<contentHaul xmlns:a="http://www.appian.com/ae/types/2009">
    <versionUuid>...</versionUuid>
    <interface>
        <name>...</name>
        <uuid>...</uuid>
        <description>...</description>
        <parentUuid>...</parentUuid>
        <visibility>...</visibility>
        <definition>... SAIL CODE HERE ...</definition>   ← ONLY MODIFY THIS
        <namedTypedValue>...</namedTypedValue>
        <preferredEditor>...</preferredEditor>
        <offlineEnabled>...</offlineEnabled>
        <isCustom>...</isCustom>
    </interface>
    <roleMap>...</roleMap>                                ← NEVER TOUCH
    <typedValue>...</typedValue>                          ← NEVER TOUCH
    <history>...</history>                                ← NEVER TOUCH
</contentHaul>
```

**You may ONLY modify content inside `<definition>...</definition>`.** Everything else must remain byte-for-byte identical.

---

## DO — Mandatory Rules

1. **Only modify inside `<definition>`** — never touch roleMap, history, versionUuid, namedTypedValue, typedValue, or any other XML section.

2. **Keep all references exactly as-is:**
   - `#"urn:appian:record-field:v1:..."` — record field references
   - `#"urn:appian:record-action:v1:..."` — record action references
   - `#"urn:appian:record-relationship:v1:..."` — record relationship references
   - `#"_a-0000..."` — rule/constant/object UUID references
   - `#"SYSTEM_SYSRULES_..."` — system function references

3. **Keep all `#"SYSTEM_SYSRULES_..."` function names exactly as-is** — only add/remove/change parameters inside their parentheses.

4. **Preserve exact formatting** — do not reformat, reindent, or change whitespace outside the immediate change area. Change only what's needed.

5. **Use proper comma placement** when adding parameters:
   - If adding after the last parameter: add comma after the previous parameter, then your new parameter (no trailing comma)
   - If adding between parameters: ensure commas separate all parameters correctly

6. **Use the bundle key pattern for user-facing text:**
   ```
   #"_a-0000e61a-f20f-8000-9ba5-011c48011c48_53662"(
     bundle: ri!i18nData,
     bundleKey: "acs_KeyName"
   )
   ```
   Note: In raw XML, the bundle lookup function appears as its UUID reference, not as `AS_GAM_CO_I18N_UT_displayLabel`.

7. **When removing a parameter**, also remove its trailing comma (or leading comma if it's the last parameter).

8. **When the fix value is a direct literal** (not needing i18n), use the appropriate type:
   - Numeric: `rowHeader: 2`
   - Boolean: `skipAutoFocus: true`
   - String enum: `labelPosition: "ABOVE"`, `linkStyle: "INLINE"`, `headingTag: "H3"`
   - String literal: `altText: "Search"` (acceptable for demo, flag for bundle key in production)

---

## DON'T — Forbidden Actions

1. **Don't reformat or reindent the definition** — change only the specific parameter being fixed.

2. **Don't rename variables** — never change `local!`, `ri!`, or `fv!` variable names.

3. **Don't restructure logic** — never move components, reorder parameters beyond the fix, or change nesting.

4. **Don't touch `saveInto`** — this is business logic, never modify it.

5. **Don't touch `showWhen`** — this is visibility logic, never modify it.

6. **Don't touch `validationGroup`** — this is form validation logic.

7. **Don't modify expressions or calculations** — never change `if()`, `and()`, `or()`, `a!match()`, or any logic expressions.

8. **Don't add new local variables** — if the fix requires a new variable (e.g., `local!isSelected`), it's Tier 3 — refuse.

9. **Don't wrap components in new parent layouts** — structural changes are Tier 3.

10. **Don't change the component type** — e.g., don't replace `#"SYSTEM_SYSRULES_richTextItem_v1"` with `#"SYSTEM_SYSRULES_headingField"` unless explicitly classified as Tier 2 pattern #45 and user has approved.

11. **Don't fix focus management issues** — these require understanding save/refresh logic and are Tier 3.

12. **Don't add `showWhen` conditions** — even for accessibility purposes, adding conditional logic is beyond safe scope.

---

## XML Syntax Reference

### How parameters appear in raw XML

In the `<definition>` section, SAIL code uses the `#"SYSTEM_SYSRULES_*"` syntax:

| SAIL Function | XML Representation |
|---|---|
| `a!gridField(...)` | `#"SYSTEM_SYSRULES_gridField_v3"(...)` |
| `a!richTextIcon(...)` | `#"SYSTEM_SYSRULES_richTextIcon"(...)` |
| `a!cardLayout(...)` | `#"SYSTEM_SYSRULES_cardLayout"(...)` |
| `a!textField(...)` | `#"SYSTEM_SYSRULES_textField"(...)` |
| `a!richTextDisplayField(...)` | `#"SYSTEM_SYSRULES_richTextDisplayField"(...)` |
| `a!documentImage(...)` | `#"SYSTEM_SYSRULES_documentImage"(...)` |
| `a!formLayout(...)` | `#"SYSTEM_SYSRULES_formLayout"(...)` |
| `a!sectionLayout(...)` | `#"SYSTEM_SYSRULES_sectionLayout"(...)` |
| `a!boxLayout(...)` | `#"SYSTEM_SYSRULES_boxLayout"(...)` |
| `a!headingField(...)` | `#"SYSTEM_SYSRULES_headingField"(...)` |
| `a!messageBanner(...)` | `#"SYSTEM_SYSRULES_messageBanner"(...)` |
| `a!pane(...)` | `#"SYSTEM_SYSRULES_pane"(...)` |
| `a!buttonWidget(...)` | `#"SYSTEM_SYSRULES_buttonWidget_v2"(...)` |
| `a!richTextItem(...)` | `#"SYSTEM_SYSRULES_richTextItem_v1"(...)` |
| `a!safeLink(...)` | `#"SYSTEM_SYSRULES_safeLink"(...)` |
| `a!recordActionField(...)` | `#"SYSTEM_SYSRULES_recordActionField_v1"(...)` |
| `a!gridColumn(...)` | `#"SYSTEM_SYSRULES_gridColumn"(...)` |
| `a!imageField(...)` | `#"SYSTEM_SYSRULES_imageField"(...)` |
| `a!stampField(...)` | `#"SYSTEM_SYSRULES_stampField"(...)` |
| `a!gaugeField(...)` | `#"SYSTEM_SYSRULES_gaugeField"(...)` |
| `a!checkboxField(...)` | `#"SYSTEM_SYSRULES_checkboxField"(...)` |
| `a!dropdownField(...)` | `#"SYSTEM_SYSRULES_dropdownField"(...)` |
| `a!paragraphField(...)` | `#"SYSTEM_SYSRULES_paragraphField"(...)` |

### Example: Adding `rowHeader: 2` to a grid

**Before:**
```
#"SYSTEM_SYSRULES_gridField_v3"(
  label: "Vendors",
  ...
  shadeAlternateRows: true,
  pagingSaveInto: ri!pagingInfo
)
```

**After:**
```
#"SYSTEM_SYSRULES_gridField_v3"(
  label: "Vendors",
  ...
  shadeAlternateRows: true,
  rowHeader: 2,
  pagingSaveInto: ri!pagingInfo
)
```

### Example: Adding `altText` to an icon

**Before:**
```
#"SYSTEM_SYSRULES_richTextIcon"(
  icon: "search",
  color: "STANDARD"
)
```

**After:**
```
#"SYSTEM_SYSRULES_richTextIcon"(
  icon: "search",
  altText: "Search",
  color: "STANDARD"
)
```

### Example: Removing a redundant label

**Before:**
```
#"SYSTEM_SYSRULES_richTextDisplayField"(
  label: "rich text",
  labelPosition: "COLLAPSED",
  value: { ... }
)
```

**After:**
```
#"SYSTEM_SYSRULES_richTextDisplayField"(
  value: { ... }
)
```

### Example: Adding `skipAutoFocus: true` to formLayout

**Before:**
```
#"SYSTEM_SYSRULES_formLayout"(
  label: "Create Evaluation",
  contents: { ... },
  buttons: ...
)
```

**After:**
```
#"SYSTEM_SYSRULES_formLayout"(
  label: "Create Evaluation",
  contents: { ... },
  buttons: ...,
  skipAutoFocus: true
)
```

---

## messageBanner Deployment Rule

When inserting `a!messageBanner`, ALWAYS use the direct function name syntax:

**✅ CORRECT:**
```
a!messageBanner(
  showWhen: ...,
  announceBehavior: "ANNOUNCE_ONLY",
  primaryText: ...
)
```

**❌ INCORRECT (may fail deployment in list-literal contexts):**
```
#"SYSTEM_SYSRULES_messageBanner"(
  showWhen: ...,
  announceBehavior: "ANNOUNCE_ONLY",
  primaryText: ...
)
```

The system reference format `#"SYSTEM_SYSRULES_messageBanner"` fails when the interface definition starts with `{` (a list literal) rather than `a!localVariables(...)`. The direct function name `a!messageBanner` works universally.

This applies ONLY to `a!messageBanner`. Other system components (`#"SYSTEM_SYSRULES_formLayout_v2"`, `#"SYSTEM_SYSRULES_headingField"`, etc.) work fine with the system reference format because they already exist in the interface — you're modifying parameters, not inserting new components.
