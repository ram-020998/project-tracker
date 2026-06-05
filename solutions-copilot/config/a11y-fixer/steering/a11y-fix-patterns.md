# A11Y Fix Pattern Taxonomy

## How to Use This File

When classifying a Jira ticket's fix, match the remediation description against the patterns below. The pattern ID, tier, and fix details tell you exactly what to do.

---

## Tier 1: Parameter Addition/Change (Safe — No structural change)

These fixes add, change, or remove a single parameter inside an existing component. Low risk, fully automatable.

### Grid Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 1 | Add grid rowHeader | `rowHeader: N` | Numeric | No |
| 2 | Change grid rowHeader | `rowHeader: N` | Numeric | No |
| 3 | Remove grid rowHeader | Remove `rowHeader` | N/A | No |
| 25 | Add grid label (collapsed) | `label: "text", labelPosition: "COLLAPSED"` | Text | Yes |
| 26 | Add grid instructions | `instructions: "text"` | Text | Yes |
| 15 | Add grid accessibilityText | `accessibilityText: "text"` | Text | Yes |

### Icon Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 4 | Add icon caption | `caption: "text"` | Text | Yes |
| 5 | Add icon altText | `altText: "text"` | Text | Yes |
| 6 | Remove icon altText (decorative) | Remove `altText` | N/A | No |
| 7 | Remove icon caption (redundant) | Remove `caption` | N/A | No |
| 8 | Switch caption → altText | Replace `caption` with `altText` | Text | No (reuse value) |
| 9 | Switch altText → caption | Replace `altText` with `caption` | Text | No (reuse value) |
| 41 | Change icon name | `icon: "new-icon-name"` | String enum | No |

### Image Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 10 | Add image altText | `altText: "text"` | Text | Yes |
| 23 | Remove label from imageField (decorative) | Remove `label` | N/A | No |

### Link Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 11 | Add linkStyle INLINE | `linkStyle: "INLINE"` | String enum | No |

### AccessibilityText Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 12 | Add card accessibilityText | `accessibilityText: "text"` | Text | Yes |
| 13 | Add pane accessibilityText | `accessibilityText: "text"` | Text | Yes |
| 14 | Add button accessibilityText | `accessibilityText: "text"` | Text | Yes |
| 16 | Add richText accessibilityText | `accessibilityText: "text"` | Text | Yes |
| 17 | Remove redundant accessibilityText | Remove `accessibilityText` | N/A | No |
| 18 | Change accessibilityText value | `accessibilityText: "new text"` | Text | Yes |
| 40 | Set accessibilityText = placeholder | `accessibilityText: "same as placeholder"` | Text | No (copy existing) |
| 42 | Change word in accessibilityText | e.g., "grid" → "table" | Text | No (modify existing) |

### Label Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 19 | Add field label | `label: "text"` | Text | Yes |
| 20 | Change field label text | `label: "new text"` | Text | Yes |
| 21 | Remove redundant label | Remove `label` or set null | N/A | No |
| 22 | Remove label from richTextDisplayField | Remove `label` | N/A | No |
| 24 | Change labelPosition | `labelPosition: "ABOVE"` | String enum | No |

### Heading Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 27 | Add/change headingTag | `headingTag: "H3"` | String enum | No |
| 28 | Add/change labelHeadingTag | `labelHeadingTag: "H4"` | String enum | No |

### Form Layout Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 29 | Set skipAutoFocus true | `skipAutoFocus: true` | Boolean | No |
| 30 | Set focusOnFirstInput false | `focusOnFirstInput: false` | Boolean | No |

### Color/Contrast Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 31 | Change color hex (contrast) | Change hex value | String | No |

### Miscellaneous Patterns

| # | Pattern | Parameter | Value Type | Bundle Key? |
|---|---------|-----------|-----------|-------------|
| 32 | Remove preventWrapping | Remove `preventWrapping: true` | N/A | No |
| 33 | Change refreshAfter | `refreshAfter: "KEYPRESS"` | String enum | No |
| 34 | Add/change announceBehavior | `announceBehavior: "ANNOUNCE_ONLY"` | String enum | No |
| 35 | Remove accessibilityText from stamp | Remove `accessibilityText` | N/A | No |
| 36 | Remove accessibilityText from gaugeField | Remove `accessibilityText` | N/A | No |
| 37 | Change card tooltip | `tooltip: "Expand"` / `"Collapse"` | Text | Yes |
| 38 | Add label to cardGroupLayout | `label: "text", labelPosition: "COLLAPSED"` | Text | Yes |
| 39 | Add field name to validation message | Modify validation text | Text | Yes |

---

## Tier 2: Component Insertion/Replacement (Medium — Structural change)

These fixes insert new components or replace one component type with another. Require user approval and careful placement.

| # | Pattern | What to Do | Risk |
|---|---------|-----------|------|
| 43 | Add required fields legend | Insert `a!richTextDisplayField` with "Required fields are marked with an asterisk (*)" at top of form `contents` | Medium |
| 44 | Add messageBanner (announce only) | Insert `#"SYSTEM_SYSRULES_messageBanner"(announceBehavior: "ANNOUNCE_ONLY", primaryText: "...")` | Medium |
| 45 | Replace richTextItem with headingField | Swap `#"SYSTEM_SYSRULES_richTextItem_v1"(text: "...", style: "STRONG")` → `#"SYSTEM_SYSRULES_headingField"(value: "...", headingTag: "HN")` | Medium |
| 46 | Replace ASCII character with icon | Remove `char(NNNN)`, add `#"SYSTEM_SYSRULES_richTextIcon"(icon: "icon-name")` without altText | Medium |
| 47 | Move icon into existing link | Merge two adjacent links (icon link + text link) into single link containing both | Medium |
| 48 | Replace image of text with real text link | Remove documentImage, add richTextItem with link text | Medium |

---

## Tier 3: Structural Refactoring (Unsafe — Agent MUST NOT attempt)

If the ticket's remediation matches any of these, STOP and explain to the user why it requires manual work.

| # | Pattern | Why Unsafe |
|---|---------|-----------|
| 49 | Restructure content into grid | Major layout change, affects all child components |
| 50 | Replace cards with expandable section layouts | Component type swap affecting entire hierarchy |
| 51 | Fix zoom/reflow at 400% | Layout restructuring across multiple nested components |
| 52 | Fix focus management (complex) | Requires understanding save/refresh logic and process flow |
| 53 | Add drag-and-drop alternatives | Requires new UI components and interaction patterns |
| 54 | Remove nested controls (link inside link) | Restructures component hierarchy and event handling |
| 55 | Add custom pagination with proper spacing | Layout and logic changes across multiple components |
| 56 | Hide disabled input fields conditionally | Requires understanding business logic and showWhen conditions |

---

## Quick Reference: No Bundle Key Needed

These patterns use direct values (numeric, boolean, enum) — no i18n bundle lookup required:

- #1, #2, #3 (rowHeader — numeric)
- #6, #7 (remove parameters)
- #8, #9 (swap existing values)
- #11 (linkStyle — enum)
- #17, #21, #22, #23 (remove parameters)
- #24 (labelPosition — enum)
- #27, #28 (headingTag — enum)
- #29, #30 (boolean)
- #31 (hex color)
- #32 (remove parameter)
- #33 (refreshAfter — enum)
- #34 (announceBehavior — enum)
- #35, #36 (remove parameters)
- #40 (copy existing placeholder value)
- #41 (icon name — enum)
- #42 (modify existing text)

## Quick Reference: Bundle Key Needed

These patterns add user-facing text that should use the i18n bundle pattern in production:

- #4, #5 (icon caption/altText)
- #10 (image altText)
- #12, #13, #14, #15, #16 (accessibilityText)
- #18 (change accessibilityText)
- #19, #20 (field label)
- #25 (grid label)
- #26 (grid instructions)
- #37 (tooltip)
- #38 (cardGroupLayout label)
- #39 (validation message)

For demo purposes, literal string values are acceptable. Flag for bundle key creation in production.

---

## Shared Component Modification Pattern

When a fix requires changing a shared/utility component (used by multiple interfaces):

### Safe approach: Add parameter with default value

1. **Add a new input parameter** to the shared component (e.g., `headingTag`)
2. **Use `a!defaultValue`** in the component to preserve existing behavior:
   ```
   headingTag: a!defaultValue(ri!headingTag, "H6")
   ```
3. **Deploy the shared component first**
4. **Then deploy each caller** that needs to pass the new value:
   ```
   headingTag: "H3"
   ```
5. **Callers that don't pass the parameter** continue working with the default

### Deployment order matters:
1. Deploy shared component (with new parameter + default) — FIRST
2. Deploy caller A (passing new value) — SECOND
3. Deploy caller B (passing new value) — THIRD

If you deploy a caller before the shared component, the deployment will fail because the parameter doesn't exist yet.

### Example: Adding headingTag to a heading display component

```
/* Shared component — BEFORE */
a!headingField(
  text: ri!labelToDisplay,
  size: "EXTRA_SMALL",
  fontWeight: "BOLD"
)

/* Shared component — AFTER */
a!headingField(
  text: ri!labelToDisplay,
  size: "EXTRA_SMALL",
  headingTag: a!defaultValue(ri!headingTag, "H6"),
  fontWeight: "BOLD"
)
```
