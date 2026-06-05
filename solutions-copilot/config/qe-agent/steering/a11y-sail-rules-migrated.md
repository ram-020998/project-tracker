---
inclusion: manual
---

# Appian A11y SAIL Rules — Implementation Mapping Guide

⚠️ **This file is NOT the source of truth for a11y rules.** The authoritative rules come from the **Aurora Design System checklist**, fetched live via `get_a11y_checklist`. This file is a **mapping guide** that tells the agent:

- **Rule IDs** — Consistent identifiers (RULE-GR-01, RULE-FI-01, etc.) for use in audit reports
- **SAIL parameter mapping** — Which specific SAIL parameter to inspect for each rule
- **Component-to-rule mapping** — Which rules apply to which Appian components
- **Severity classification** — MUST FIX / VERIFY / WATCH OUT

Always fetch the Aurora checklist first. Use this file to map Aurora rules to SAIL code inspection logic.

---

## ⚠️ Critical Principle: "Omit" ≠ "Set to Empty String"

**NEVER recommend setting a parameter to an empty string (`""`) as a fix.** In Appian SAIL:

- A parameter that is **not provided** = `null` = the platform's default behavior (usually: element is ignored by assistive technology)
- Setting a parameter to `""` (empty string) = **unnecessary code** that achieves the same result as omitting it

**When the correct fix is to REMOVE a parameter, say "Remove/Omit the parameter" — NOT "Set it to empty string."**

This applies to ALL of these parameters:
- `altText: ""` → WRONG. Just omit `altText` entirely.
- `accessibilityText: ""` → WRONG. Just omit `accessibilityText` entirely.
- `caption: ""` → WRONG. Just omit `caption` entirely.
- `label: ""` on links → WRONG. Just omit `label` entirely.
- `tooltip: ""` → WRONG. Just omit `tooltip` entirely.
- `helpTooltip: ""` → WRONG. Just omit `helpTooltip` entirely.

**Context-aware detection:** Before flagging a missing parameter as a violation, check if the element is in a **decorative context** where omitting the parameter IS the correct behavior:
1. Icon inside a `a!cardLayout` with `accessibilityText` → icon is decorative, no `altText` needed
2. Icon adjacent to text that conveys the same info → icon is redundant, no `altText` needed
3. Icon inside a link that already has descriptive text → icon is decorative, no `altText` needed
4. Non-applicable pagination element → no `accessibilityText` needed
5. Stamp with info that should be visible text → remove `tooltip`, don't set to `""`

---

## SAIL-Testable Rules

### Form Inputs
- RULE-FI-01: Every enabled/disabled input MUST have `label` parameter set (not null). Applies to: a!textField, a!paragraphField, a!integerField, a!floatingPointField, a!dropdownField, a!multipleDropdownField, a!dateField, a!dateTimeField, a!pickerField, a!userPickerField, a!groupPickerField
- RULE-FI-02: Each checkbox/radio MUST have `choiceLabels` set (not null). Applies to: a!checkboxField, a!radioButtonField
- RULE-FI-03: Checkbox/radio with multiple options MUST have `label` set. Applies to: a!checkboxField, a!radioButtonField
- RULE-FI-04: Text fields for personal info MUST have `inputPurpose` set. Applies to: a!textField. ⚠️ **Always output as "Needs Inspection" or "Warning" — NEVER as a Boolean pass/fail.** The AI cannot determine whether the user is entering their own personal information or data on behalf of another person (e.g., a user creating a vendor record where the user is not the vendor). This requires human judgment based on the business context of the form.
- RULE-FI-05: Duplicated controls with same name MUST have `accessibilityText` or be in labeled section/box layout. Scan for multiple instances of the same input component type (e.g., two `a!textField` components) that share the same `label` value. If duplicates are found and neither has `accessibilityText` set, and they are not inside separately labeled `a!sectionLayout` or `a!boxLayout`, flag it. **⚠️ EXCLUSION: Inputs inside grid columns (`a!gridField`, `a!gridLayout`, `a!gridColumn`) MUST be excluded from duplicate name detection.** Grids inherently repeat the same input type with the same label across rows — this is expected behavior and the column header serves as the distinguishing context.

- RULE-FI-10: Custom search components (common object patterns like `a!localVariables` wrapping a text field with search behavior) MUST have the `label` parameter set — NOT just `accessibilityText` and `placeholder`. The `accessibilityText` parameter provides a DESCRIPTION, not a programmatic LABEL. The `placeholder` parameter is not reliably interpreted as a label by Windows screen readers after input is provided. Scan for: (1) text fields or custom components with `placeholder` containing "search" AND `accessibilityText` set BUT `label` not set or null, (2) any input where `accessibilityText` is used AS the label (i.e., no `label` parameter exists). Flag as MUST FIX: "Input uses accessibilityText/placeholder instead of label parameter. Set `label` to the search field purpose (e.g., 'Search Vendors') and make it persistently visible."

  **⚠️ ADDED 2026-05-07 from gap analysis (GAMS-7748, GAMS-8555, GAMS-8559):**
  This is a common pattern in Appian apps where teams create reusable search components that use `accessibilityText` as a workaround. It is NOT accessible. The `label` parameter is the ONLY way to provide a proper programmatic label.

### Validations
- RULE-VA-01: Required inputs MUST have `required: true`
- RULE-VA-02: Use OOTB validation: `validations`, `validationGroup`, `validationMessage` parameters

### Instructions
- RULE-IN-01: Visible form instructions MUST use `instructions` parameter on the input

### Grids
- RULE-GR-01: Every grid MUST have `label` set. Applies to: a!gridField, a!gridLayout
- RULE-GR-02: Each data/input column MUST have `label` on a!gridColumn or a!gridLayoutHeaderCell. **⚠️ EXCEPTION: Action columns containing self-describing controls (e.g., Edit buttons, Delete buttons, action menus) where the control's label/purpose is inherently clear do NOT require a column header label.** This exception applies to controls only — data columns and input columns still require labels. When an action column is detected, mark as VERIFY rather than MUST FIX.
- RULE-GR-03: Set `rowHeader` when a cell uniquely identifies the row. ⚠️ **Output as VERIFY, not Boolean pass/fail.** The AI analyzes cell content to determine which column contains values that uniquely identify each row (e.g., names, IDs, titles). However, this determination is inherently subjective. Flag for manual inspection with the AI's reasoning about which column it believes should be the rowHeader, so the auditor can confirm or override.
- RULE-GR-04: Empty grid columns MUST NOT be used for spacing
- RULE-GR-05: Grid instructions MUST use `instructions` parameter (not external text). Do not use "grid" in text, use "table"
- RULE-GR-06: Selectable grids MUST have `accessibilityText` warning about controls above grid. Do not use "grid", use "table"

### Headings
- RULE-HD-01: Text headings MUST use `a!headingField` or layout with `labelHeadingTag`. Scan for `a!richTextItem(style: "STRONG")` or `a!richTextItem(style: "EMPHASIS")` appearing as the first element in a section/box/column layout — this is a fake heading and MUST be replaced with `a!headingField`. Also flag `a!richTextDisplayField` with STRONG-styled text used as a visual heading.

  **⚠️ ENFORCEMENT (added 2026-05-07 from gap analysis — GAMS-8549, 8553):**

  **Do NOT just check if `a!headingField` exists somewhere in the interface and mark PASSING.** You MUST actively scan for ALL instances of `a!richTextItem(style: "STRONG")` or `a!richTextDisplayField` with bold text that LOOKS like a section label. Common patterns that are fake headings:
  - Bold text at the start of a card/section that labels the content below it (e.g., "Highlights", "Documents", "Summary", "Vendor Details")
  - `a!richTextItem(text: "Section Title", style: "STRONG")` followed by content
  - Text inside `a!forEach` that labels each repeated item (e.g., document names used as section headers)

  **The presence of SOME correct headings does NOT mean ALL headings are correct.** Check every bold/strong text element.

  **⚠️ BROADENED DETECTION (updated 2026-05-12 per Kurt Bunge feedback):**

  **Do NOT limit detection to only STRONG/bold styling.** Not all text that should be headings uses a strong font weight. Identify potential fake headings based on:
  1. **Position** — first element in a section/box/column layout that appears to label/introduce content below it
  2. **Visual prominence** — any styled text (size, color, weight, emphasis) that appears to serve as a section title
  3. **Context** — text that functions as a heading regardless of whether it uses bold, emphasis, larger font, or any other styling

- RULE-HD-02: Heading levels must be appropriate via `headingTag` or `labelHeadingTag`. Do not skip levels. Validate that `headingTag` values follow a logical hierarchy (e.g., H1 → H2 → H3, never H1 → H3). When multiple `a!headingField` components exist in an interface, check that their `headingTag` levels are sequential and don't skip levels.

  **⚠️ ENFORCEMENT (added 2026-05-07 from gap analysis — GAMS-8550, 8553):**

  **After identifying all headings, build the heading tree and validate the hierarchy:**
  1. List all headings in document order with their levels
  2. Check: Does the first heading after the page title use H2? (not H3 or H4)
  3. Check: Does each subsequent heading use the correct child level? (H2 → H3 → H4, never H2 → H4)
  4. Check: Are headings inside repeated content (forEach) at the correct level relative to their parent?

  Example failure: Page has H2 "Factor Analysis", then inside each factor card the factor name uses H3 — but the subfactor names jump to H5 instead of H4. Flag as MUST FIX.

- RULE-HD-03: Context headings in wizard steps or multi-section forms MUST use `a!headingField`, not `a!richTextDisplayField` with bold/strong styling. Check step headings, section titles, and panel headings.

  **⚠️ BROADENED DETECTION (updated 2026-05-12 per Kurt Bunge feedback):**

  Text that should be headings don't necessarily always use bolded text. Scan for ANY `a!richTextDisplayField` or `a!richTextItem` used as a visual heading regardless of styling (not just STRONG/bold). Use correct terminology: "headings" for semantic heading elements, not "headers".

### Lists
- RULE-LI-01: Visual lists MUST use `a!richTextBulletedList` or `a!richTextNumberedList`

### Pane Layout
- RULE-PL-01: Each `a!pane` MUST have `accessibilityText`. Do not use: pane, main, navigation, section, form, search, header, footer, article

### Section/Box Layout
- RULE-SB-01: Expandable `a!sectionLayout` MUST have `label` AND `labelHeadingTag`
- RULE-SB-02: Expandable `a!boxLayout` MUST have `label` AND `labelHeadingTag`

### Cards
- RULE-CA-01: Cards with `link` parameter MUST NOT contain other controls/inputs inside
- RULE-CA-02: Cards with `link` MUST NOT have `label` on the link. The fix is to REMOVE the `label` parameter from the link entirely — do NOT set it to an empty string (`label: ""`). Labels are rarely needed for links; if a label is needed, the design of or text within the link should be reconsidered.
- RULE-CA-03: Selected cards MUST have `accessibilityText: "Selected"` set dynamically on the card itself (removed when deselected). NOTE: Using `a!messageBanner` with `ANNOUNCE_ONLY` alone is NOT sufficient — it only announces at the moment of selection. The card needs `accessibilityText` so screen readers announce "Selected" when users navigate BACK to the card later.

  **⚠️ ENFORCEMENT (added 2026-05-07 from gap analysis):**

  A `a!messageBanner` with `announceBehavior: "ANNOUNCE_ONLY"` that announces selection is **NOT SUFFICIENT** on its own. The card MUST ALSO have `accessibilityText: "Selected"` set directly on the `a!cardLayout`. Why: the messageBanner only fires ONCE at the moment of selection. If a user navigates away and comes back to re-read the card, the messageBanner won't re-announce — only the card's `accessibilityText` will be read.

  **Detection logic:** If a `a!cardLayout` changes visual style based on a selection variable (e.g., different `style` or `backgroundColor` in an `if()`) AND a `a!messageBanner` announces the selection, check that the card ALSO has `accessibilityText: "Selected"` set conditionally. If only the messageBanner exists without card accessibilityText → **MUST FIX**.

### Links
- RULE-LK-01: Rich text links MUST be visually distinguishable from surrounding non-link text without relying solely on color. `linkStyle: "INLINE"` (underline) is one way; other visual differentiation also satisfies this rule.

  **⚠️ CRITICAL: `linkStyle` NOT SPECIFIED ≠ VIOLATION (updated 2026-05-13)**

  When `linkStyle` is omitted (not provided), Appian defaults to `"STANDALONE"`. **The absence of an explicit `linkStyle` parameter is NOT automatically a finding.** The tool MUST evaluate the link's visual context before flagging. Do NOT flag a link simply because `linkStyle` was not explicitly set.

  **⚠️ INTERPRETATION GUIDE (added 2026-05-07, updated 2026-05-13):**

  The Aurora rule says "linkStyle: INLINE **or other differentiation**." This means NOT every link without `linkStyle: "INLINE"` is a bug — whether `linkStyle` is explicitly set to `"STANDALONE"` OR simply omitted (defaulting to STANDALONE). Apply this decision tree consistently:

  **🔴 MUST FIX — always flag:**
  - Text-only link (no icon, no `style: "STRONG"`, no other visual cue) that is **embedded within surrounding non-link text** AND uses STANDALONE (whether explicit or default)
  - Example: `a!richTextItem(text: "More", link: ...)` with no icon adjacent, sitting inside a paragraph of text

  **🟡 VERIFY — flag for manual check:**
  - Link with `style: "STRONG"` (bold) as the **only** differentiation from surrounding text
  - Link with a small/ambiguous icon where it's unclear if the icon provides sufficient differentiation
  - Example: Vendor name in grid with `style: "STRONG"` and no explicit `linkStyle`

  **✅ PASS — do NOT flag:**
  - Link that is **isolated** (not embedded in surrounding text) — e.g., standalone navigation link on its own line, link in a grid cell, link as the only content in a column/card
  - Link with a clearly informational icon providing visual differentiation (e.g., external-link icon, download icon, arrow-left icon, chevron icon)
  - Link inside a grid column (grid context inherently differentiates links)
  - Link that is the sole content of a `a!cardLayout`, `a!boxLayout`, or similar container
  - Example: `a!richTextItem(text: {a!richTextIcon(icon: "arrow-left"), " Back to Vendors"}, link: ...)` — the arrow icon differentiates it regardless of `linkStyle`
  - Example: A link in a grid cell showing a record name — it's isolated in its cell, not embedded in prose text

  **Key principle:** The question is NOT "is `linkStyle: INLINE` set?" but "can a user who cannot perceive color distinguish this link from surrounding non-link text?" If the link is isolated, has an icon, or has bold text making it visually distinct, it passes — regardless of whether `linkStyle` was explicitly specified.

- RULE-LK-02: Selected rich text links: use icon `altText: "Selected"` (prefer over accessibilityText on richTextDisplayField)

### Breadcrumbs
- RULE-BC-01: Breadcrumbs MUST have `accessibilityText` identifying breadcrumb and current page. Example: "Breadcrumbs, corporate is the current page"

### Icons
- RULE-IC-01: Standalone icon in link MUST have `altText` or `caption` (prefer altText)
- RULE-IC-02: Icon with text in link: `altText` MUST be set if the icon conveys information that the link text does NOT already convey. Common pattern: icons like `file-text-o`, `file-pdf-o`, `file-word-o`, `folder`, `globe`, `external-link` often indicate a CATEGORY or CONTEXT (e.g., "this is a document", "this is external") that the link text alone may not communicate. In these cases, set `altText` to the context the icon provides (e.g., `altText: "Document"`). HOWEVER, if the link text already makes the context clear (e.g., "Download Summary Document" — the word "Document" is in the text), the icon is redundant and should NOT have `altText`. The same icon can be decorative in one context and informational in another — always compare what the icon conveys vs what the link text already says. Scan for `a!richTextIcon` with `icon` names suggesting category/type context (file-*, folder-*, globe, external-link, lock, shield, database, cloud) inside links — flag as VERIFY: "Does the link text already convey what this icon indicates? If not, add altText."

  **⚠️ ENFORCEMENT (added 2026-05-07 from gap analysis — GAMS-8546):**

  **Do NOT assume an icon is decorative just because adjacent text exists.** The critical question is: "Does the LINK TEXT alone convey the same information as the icon?" If the answer is NO, the icon is INFORMATIONAL and needs `altText`.

  Example that FAILS: `a!richTextIcon(icon: "file-text-o")` next to a link with text "Section 3.2 Requirements". The icon conveys "this is within a document" — the link text does NOT say that. The icon needs `altText: "Document"`.

  Example that PASSES: `a!richTextIcon(icon: "download")` next to a link with text "Download the Report". The word "Download" is already in the text — the icon is redundant/decorative.

  **During audits, for EVERY icon inside a link, explicitly ask:** "If I remove this icon, does the link text alone tell the user everything the icon was conveying?" If NO → needs altText.

- RULE-IC-03: Standalone icon in button MUST have `accessibilityText` or `tooltip` on button
- RULE-IC-04: Icon with text in button: `accessibilityText` only if button label doesn't convey icon info
- RULE-IC-05: Standalone icon conveying info MUST have `altText` or `caption`. Use `caption` (not `altText`) when the icon's meaning is NOT universally clear from its appearance — caption provides a visible tooltip for ALL users, while altText is screen-reader only.
- RULE-IC-06: Decorative/redundant icons MUST NOT have `altText` or `caption`. Do NOT set these parameters at all — not even to an empty string (`altText: ""`). When an icon appears alongside text that conveys the same information (e.g., a magic wand icon next to "Validate" text), the icon is redundant and the correct fix is to OMIT the `altText` and `caption` parameters entirely. Setting `altText: ""` is unnecessary — Appian already treats icons without `altText`/`caption` as decorative. If `altText` or `caption` IS currently set on a decorative/redundant icon, the fix is to REMOVE the parameter, not set it to empty string.

### Document Images
- RULE-DI-01: `a!documentImage` inside a link (card link, richTextItem link) that conveys information beyond what the link text provides MUST have `altText` set. Scan for `a!documentImage` without `altText` inside `a!cardLayout` with `link` or `a!richTextItem` with `link`. If the image conveys additional context (e.g., AI-generated indicator, document type), it needs `altText`. If purely decorative, omitting `altText` is correct.
- RULE-DI-02: ASCII characters or special Unicode characters used as visual indicators MUST be tested across browsers (Chrome, Edge, Firefox) to ensure they render correctly. If they don't render consistently, replace with an Appian icon or rich text. Scan for `char()` function calls or Unicode escape sequences in SAIL code — flag for manual cross-browser verification.

### Charts
- RULE-CH-01: Charts MUST have `label` parameter set

### Progress Bar
- RULE-PB-01: `a!progressBarField` MUST have `label`

### File Upload
- RULE-FU-01: `a!fileUploadField` MUST have `label`
- RULE-FU-02: `a!fileUploadField` MUST have `instructions`

### Stamp
- RULE-ST-01: `a!stampField` MUST NOT use `helpTooltip` for important info. The fix is to REMOVE the `helpTooltip` parameter and move the information to visible text — do NOT set it to an empty string. (Note: `tooltip` was removed from this rule per platform update — tooltip on stamps is now accessible.)

### Date & Time
- RULE-DT-01: `a!dateTimeField` MUST NOT be used

### Card Choice / Card Group
- RULE-CC-01: `a!cardChoiceField` with multiple cards MUST have `label`
- RULE-CG-01: `a!cardGroupLayout` with multiple cards MUST have `label`
- RULE-CG-02: When multiple `a!cardLayout` components with `link` appear in sequence within the same parent layout (e.g., inside a `a!columnsLayout` or `a!forEach`), they SHOULD be wrapped in `a!cardGroupLayout` with a `label`. Scan for 2+ adjacent `a!cardLayout` with `link` parameter that are NOT inside a `a!cardGroupLayout`.

### Keyboard Interaction
- RULE-KB-01: When a button's `disabled` state depends on input in a preceding field, the field MUST use `refreshAfter: "KEYPRESS"` to ensure the button is enabled before keyboard focus leaves the field. Scan for patterns where a `a!textField` or `a!paragraphField` has default `refreshAfter` (UNFOCUS) and a subsequent button has `disabled` controlled by a condition referencing that field's value. Flag as: "Button may not be enabled in time for keyboard users."
- RULE-KB-02: When a control adds a row to a grid (e.g., via `a!save` that appends to a list), keyboard focus SHOULD move to the newly added row. Flag `a!buttonWidget` or `a!buttonLayout` that modify grid list variables (append/insert) without a corresponding focus management mechanism. **⚠️ SCOPE (updated 2026-05-12 per Kurt Bunge feedback): In Appian, focus management (moving focus to newly added content) applies ONLY when adding a row to a grid. Do NOT flag other content additions (e.g., showing/hiding sections, adding items to lists outside of grids) as requiring focus movement.**

### Error Messaging
- RULE-VA-03: **⚠️ REMOVED (2026-05-12 per Kurt Bunge feedback).** This rule was incorrect. The Appian platform already provides OOTB mechanisms for live screen reader announcements of validation errors. The `a!messageBanner` component should only be used for error messaging in very specific instances (e.g., page-level error summaries in wizards), not as a general pattern for form validation failures. Use OOTB validation parameters instead.
- RULE-VA-04: When multiple instances of the same error exist (e.g., "Section exceeds 10 questions" repeated for 3 sections), a single consolidated screen reader announcement SHOULD be used with `announceBehavior: "ANNOUNCE_ONLY"`, while individual visual banners use `announceBehavior: "DISPLAY_ONLY"`. Flag when the same `a!messageBanner` text appears in a `a!forEach` loop without differentiation. **⚠️ CONTEXT NOTE (updated 2026-05-12 per Kurt Bunge feedback): This rule was derived from a specific PSE use case where identical error messages repeated across multiple sections. Do NOT generalize this to all forEach loops with messageBanners. Only flag when the EXACT same error text is repeated without differentiation AND the repetition creates screen reader noise. Mark as VERIFY, not MUST FIX.**

### Confusing AT Information
- RULE-AT-01: When interactive elements become non-interactive conditionally (e.g., `a!cardLayout` with `link` in one branch and without `link` in another branch of an `if()`), the non-interactive state MUST either hide the element or set `accessibilityText` indicating the function is unavailable. Scan for `if()` expressions where one branch has `a!cardLayout(link: ...)` and the other has `a!cardLayout` without `link`. **⚠️ CONTEXT WARNING (updated 2026-05-12 per Kurt Bunge feedback): This rule is context-specific. Only flag when the conditional non-interactive state would genuinely confuse users (e.g., a card that was previously clickable becomes inert without explanation). Do NOT flag standard conditional rendering patterns where elements are simply hidden/shown based on application state. Mark as VERIFY, not MUST FIX, and require manual inspection.**

### Link Text Quality
- RULE-LK-03: Links used as toggles MUST have text that describes the action the link will perform, not the current state. Flag link text like "Preview Mode On" or "Preview Mode Off" — prefer "Turn on Preview Mode" / "Turn off Preview Mode", or better yet use `a!toggleField` (Appian 26.2+).

### Custom Pagination
- RULE-CP-01: Inactive pagination links MUST NOT have accessibilityText indicating "disabled". The fix is to REMOVE the `accessibilityText` parameter entirely from non-applicable pagination elements — do NOT set it to an empty string (`accessibilityText: ""`). Non-applicable pagination elements should simply have no text alternative. **⚠️ PREFERRED FIX (updated 2026-05-12 per Kurt Bunge feedback): Replace pagination links with `a!buttonWidget` components that use the `disabled` parameter when the pagination action does not apply. Buttons are the semantically correct control for pagination actions — links should not be used for this purpose. The accessibilityText removal guidance above applies as an interim fix if buttons cannot be implemented immediately.**
- RULE-CP-02: Adjacent active pagination links MUST have 24x24px target size or non-overlapping circles

### Dynamic Content
- RULE-DC-01: Dynamic status messages MUST use `a!messageBanner` with `announceBehavior`. NOTE: This covers announcing the ACTION (e.g., "vendor selected"). If the action causes content to load in a DIFFERENT pane/region, that content change needs its own announcement (see RULE-DC-07).. Scan for conditional text display patterns: `showWhen` conditions that show/hide text, `if()` expressions that output status text, or `a!richTextDisplayField` with `showWhen` toggling visibility. If the displayed text conveys a status change and there is no nearby `a!messageBanner` with `announceBehavior`, flag it.
- RULE-DC-02: When document/record status changes dynamically (e.g., "Drafting" → "Draft Generated"), the change MUST be announced via `a!messageBanner` with `announceBehavior: "ANNOUNCE_AND_DISPLAY"` or `"ANNOUNCE_ONLY"`. Scan for local variables that hold status values and are displayed in the UI — if the variable can change without page reload, an announcement is required.
- RULE-DC-03: AI-generated content or long-running async operations that update the UI MUST announce completion via `a!messageBanner`. Scan for patterns where a button triggers a process/integration and the UI updates after completion.

### Simulated Grid
- RULE-SG-01: Data visually output as grid but not using grid MUST have `accessibilityText` on each cell with column header and row header text

### Modal Dialog
- RULE-MD-01: Focus MUST NOT move to input when important info precedes it. Set `focusOnFirstInput: false`

### Forms
- RULE-FM-01: Focus MUST NOT move to input when important info precedes it. Set `focusOnFirstInput: false`
- RULE-FM-02: Info user must re-enter MUST be auto-populated or available to select

## Visual/Manual Rules (Flag When Components Detected)

- RULE-VM-01: Placeholder text alone MUST NOT convey important info
- RULE-VM-02: Every input MUST have persistently visible label (flag when labelPosition: COLLAPSED)
- RULE-VM-03: Required fields MUST have asterisk legend at form start
- RULE-VM-04: Focus MUST NOT move past important info on form/dialog init
- RULE-VM-05: Color MUST NOT be only means of identification
- RULE-VM-06: Text contrast: 4.5:1 regular, 3:1 large (18pt or 14pt bold)
- RULE-VM-07: Icon/image contrast: 3:1
- RULE-VM-08: Content readable at 200% zoom (CTRL+"+", 5 times) and 400% zoom (8 times) at 1280px width
- RULE-VM-09: Touch targets: 24x24px minimum or non-overlapping 24px circles
- RULE-VM-10: Signature component MUST have keyboard alternative
- RULE-VM-11: Tooltips MUST be keyboard accessible
- RULE-VM-12: Images of text MUST NOT be used (except logos)
- RULE-VM-13: Validation error messages MUST include input name
- RULE-VM-14: Grid row drag-and-drop MUST have single-click alternative (up/down links)
- RULE-VM-15: Workflow Visualization plugin MUST have alternative view
- RULE-VM-16: `accessibilityText` MUST NOT include activation instructions (e.g., "click to select", "press to choose", "tap to pick"). Screen reader users already know how to operate controls. `accessibilityText` should describe WHAT the control does or its current state, not HOW to activate it. Flag for manual review when action verbs like "select", "click", "choose", "pick" are detected in `accessibilityText` values.
- RULE-VM-17: `altText` on icons in repeating contexts (`a!forEach`) SHOULD include a unique identifier. Flag single-word `altText` values like "Expand", "Collapse", "Edit", "Delete" when the icon is inside a `a!forEach` loop — should be "Expand [item name]" instead.
- RULE-VM-18: When `labelPosition: "COLLAPSED"` is set on an input, verify a visible label exists elsewhere adjacent to the input. If no `a!richTextDisplayField` or `a!headingField` with matching text is found in the same parent layout, escalate to a stronger warning.

---

## Rules Added from Accessibility Training Modules (2.0–2.3)

### Form Legend
- RULE-FL-01: Every form containing required inputs indicated by a visible asterisk MUST have a rich text legend positioned at the top of the form, prior to the first input, with text "Required fields are marked with an asterisk (*)". Scan for `a!formLayout` that contains any input with `required: true` — check if a `a!richTextDisplayField` or `a!richTextItem` with text containing "asterisk" or "required fields" exists before the first input component. If missing, flag it. **⚠️ ADDITIONAL CHECK (updated 2026-05-12 per Kurt Bunge feedback): Also flag when `a!richTextIcon(icon: "asterisk")` is used adjacent to an input label BUT the input does NOT have `required: true` set.** In this case, the visual asterisk is misleading because the platform will not enforce the required state or provide the programmatic 'required' indicator to assistive technology.

### Placeholder Text
- RULE-IN-02: The `placeholder` parameter MUST NOT be used to convey important information such as input formats, valid ranges, or instructions. Scan for any input component (`a!textField`, `a!integerField`, `a!floatingPointField`, `a!paragraphField`) that has `placeholder` set but does NOT also have `instructions` set with equivalent information. Flag when `placeholder` contains format hints (e.g., "MM/DD/YYYY", "6-digit", "alphanumeric", "enter your") without a corresponding `instructions` parameter.
- RULE-IN-03: `a!dropdownField`, `a!multipleDropdownField`, `a!pickerField`, `a!userPickerField`, and `a!groupPickerField` MUST NOT rely on `placeholder` as the only label. These are widgets (not native HTML inputs), so placeholder text does not provide a programmatic label. Scan for these components where `labelPosition: "COLLAPSED"` is set and `placeholder` is set but no adjacent visible label exists.

### Label in Name
- RULE-FI-06: When a `a!richTextDisplayField` or `a!headingField` is used as a visible label for an input (with the input using `labelPosition: "COLLAPSED"`), the input's `label` parameter value MUST contain at least the same/exact string as the visible label text. Scan for patterns where `a!richTextItem` text OR `a!headingField` text is followed by an input with `labelPosition: "COLLAPSED"` — compare the visible label string to the input's `label` value. If they don't match, flag it. **⚠️ BROADENED (updated 2026-05-12 per Kurt Bunge feedback): Rich text is not the only possible way of providing a visible label. Also check for `a!headingField` used as the visible label for an input.**

### Single Checkbox/Radio
- RULE-FI-07: When only ONE checkbox or radio button is present (single `choiceValues`/`choiceLabels` entry), the `label` parameter SHOULD NOT be used as a group label. The `choiceLabels` parameter must still be set on the individual control. Scan for `a!checkboxField` or `a!radioButtonField` where `choiceLabels` has exactly one item — if `label` is also set, flag for review.

### Error Messaging
- RULE-VA-05: Error messages for form inputs MUST use OOTB Appian validation parameters (`validations`, `validationGroup`, `requiredMessage`) — NOT `a!messageBanner` or `a!richTextDisplayField` positioned near the input. Scan for patterns where a `a!messageBanner` or `a!richTextDisplayField` with conditional `showWhen` appears immediately after an input and contains error-like text (e.g., "required", "invalid", "error", "must be", "cannot be"). Flag these as inaccessible error messaging.

### Required Inputs
- RULE-VA-06: Required inputs MUST use the `required: true` parameter — NOT a `a!richTextIcon(icon: "asterisk")` placed adjacent to the input label. Scan for `a!richTextIcon` with `icon: "asterisk"` appearing near input components. If found and the adjacent input does NOT have `required: true`, flag it.

### Selected States — Buttons
- RULE-CA-04: When buttons are used as toggle/selection controls (e.g., view switchers) and visual styling indicates the selected state, the selected button MUST have `accessibilityText: "Selected"` on `a!buttonWidget`. When more than one button is present, the `accessibilityText` must be updated dynamically as different buttons are selected. Do NOT use the `tooltip` parameter to indicate selected state. **⚠️ PREFERRED FIX (updated 2026-05-12 per Kurt Bunge feedback): Use `a!toggleField` (available in Appian 26.2+) which provides the correct programmatic role of 'switch'. Using `accessibilityText: "Selected"` on buttons is a workaround — it provides a description but does NOT convey the correct programmatic role. Always recommend `a!toggleField` first; only fall back to the accessibilityText workaround if the application is on a version prior to 26.2. Accessibility text is a programmatic description — it is not a programmatic role.**

### Expand/Collapse States
- RULE-EC-01: When a `a!richTextIcon` is used in a link to expand/collapse content, the `altText` parameter MUST indicate the action that will be performed ("Expand" or "Collapse"), NOT the current state. The `altText` must be updated when the icon changes between expanded/collapsed states. Do NOT use `accessibilityText` on `a!richTextDisplayField` for this purpose (known product bug).
- RULE-EC-02: When a text-only link (no icon) is used to expand/collapse content, the link text itself MUST indicate the action ("Show More Contract Details" / "Hide Contract Details", or "Expand All" / "Collapse All"). Do NOT set `accessibilityText` on `a!richTextDisplayField` to convey this — it is not fully accessible.
- RULE-EC-03: When showing and hiding content, prefer `a!sectionLayout` (with `isCollapsible`) or expandable box layouts over custom show/hide patterns using `showWhen` or `if()` with links. The OOTB expandable components manage expanded/collapsed states by default. Scan for `a!richTextIcon` with `link` that toggles a local variable controlling `showWhen` on adjacent content — flag as "Consider using a!sectionLayout with isCollapsible instead for automatic expand/collapse state management."

### Inaccessible Components
- RULE-NA-01: The following components MUST NOT be used in accessible Appian solutions: Document Browser, Document and Folder Browser, Group Browser, Hierarchy Browser, Hierarchy Browser Tree, User Browser, User and Group Browser, Video, Web Video, `a!dateTimeField`. Scan for any of these component names in SAIL code. (Note: `a!dateTimeField` added 2026-05-12 per Kurt Bunge feedback — also covered by RULE-DT-01 but included here for a consolidated forbidden list.)

### Icon altText vs caption
- RULE-IC-07: When setting a text alternative on a `a!richTextIcon` used in a link, use `altText` (not `caption`) if the icon purpose IS universally known (e.g., search magnifying glass, edit pencil). Use `caption` (not `altText`) if the icon purpose IS NOT universally known. Do NOT set BOTH `altText` and `caption`. Do NOT use `tooltip` or `accessibilityText` on the link as a text alternative for the icon.
- RULE-IC-08: When a `a!richTextIcon` is used inside a link, setting the `caption` parameter causes the icon to enter the tab order, creating two tab stops for the same link. Prefer `altText` over `caption` for icons in links unless the icon purpose is not universally known. Scan for `a!richTextIcon` with `caption` set AND a `link` parameter — flag for review.
- RULE-IC-09: Do NOT use the `tooltip` parameter on `a!richTextDisplayField` to provide a text alternative for standalone images whose purpose may not be universally known. Tooltips are not available to all users. Use the `caption` parameter on the icon instead, or better yet, use a universally known image or regular text. Scan for `a!richTextDisplayField` with `tooltip` set that contains a `a!richTextIcon` without `altText` or `caption`.

### Charts
- RULE-CH-02: Chart `label` values MUST NOT include the chart type (e.g., "Pie Chart of Issue Types"). The platform already provides the chart type to assistive technology. Scan for chart components where the `label` value contains words like "pie chart", "bar chart", "line chart", "column chart".

### Links — Focus
- RULE-LK-04: Avoid the combination of `linkStyle: "STANDALONE"` on a link AND `style: "UNDERLINE"` on `a!richTextItem`. This combination causes the link to look the same in both focused and unfocused states, failing the visible focus requirement. Use `linkStyle: "INLINE"` with no underline on `a!richTextItem` instead. Scan for `a!richTextItem` with both `style: "UNDERLINE"` and a link using `linkStyle: "STANDALONE"`.

### Grids — Additional
- RULE-GR-07: When conveying information about a grid for accessibility purposes (in `accessibilityText`, `instructions`, or `a!messageBanner` text), the word "table" MUST be used instead of "grid". Appian grids are HTML tables, and assistive technology identifies them as tables. Scan for `accessibilityText` or `instructions` parameters on grid components that contain the word "grid" — flag and suggest replacing with "table".
- RULE-GR-08: When grid row drag and drop is used (`a!gridLayout` with drag-and-drop reordering), single-click move up/move down controls (links or buttons) MUST also be provided as an alternative. The platform does not provide a single-click option for drag and drop. Scan for `a!gridLayout` with `addRowLink` or reorder-related parameters — flag if no up/down button/link pattern is detected in the row cells.
- RULE-GR-09: Controls used to move grid rows up and down MUST have a target size of at least 24x24 pixels. Use `a!buttonWidget` (which meets this by default) instead of `a!richTextIcon` links for move up/down controls. Links do not meet this requirement by default. **⚠️ CONDITION (updated 2026-05-12 per Kurt Bunge feedback): This rule only applies when TWO or more ACTIVE/ENABLED adjacent controls are present.** If one control is active and the adjacent control is inactive/disabled (e.g., Move Up is inactive on the first row, Move Down is active), the target size requirement does not apply because there is no risk of accidental activation of an adjacent active target.


## Rules Added from Accessibility Training Modules (2.4–2.5)

### Charts — Adjacent Element Contrast
- RULE-CH-03: Chart elements (pie slices, bars, lines) MUST have at least a 3:1 color contrast ratio between the element color and the chart background AND between colors used for adjacent elements. When custom `colorScheme` or `seriesColor` values are set on chart components (`a!pieChartField`, `a!barChartField`, `a!lineChartField`, `a!columnChartField`, `a!scatterChartField`), flag for manual verification of adjacent-element contrast. The more chart elements there are, the harder this is to meet. Scan for chart components with `colorScheme` or `seriesColor` parameters — flag with: "Verify that adjacent chart element colors have at least 3:1 contrast ratio against each other AND against the chart background."

### Selected State Color Contrast
- RULE-VM-19: When color or a decorative bar is used to indicate a selected state on cards or other controls, the color used for the selected state MUST have at least a 3:1 color contrast ratio against the same area of an adjacent, unselected element. If a background color change indicates selected state, the text within MUST also have at least a 4.5:1 contrast ratio against the new background. Scan for `a!cardLayout` with `decorativeBarPosition` or `decorativeBarColor` parameters, or `style` changes controlled by selection variables — flag for manual contrast verification: "Verify selected state color has 3:1 contrast against unselected state, and text maintains 4.5:1 contrast against any changed background."

### Appian Secondary Text Color
- RULE-VM-20: Appian's secondary text color (`"SECONDARY"` style) provides sufficient color contrast ONLY when used on a pure white background. When `a!richTextItem(style: "SECONDARY")` or text with `color: "SECONDARY"` is used inside a `a!cardLayout`, `a!boxLayout`, or any component with a non-white `backgroundColor`, flag for manual contrast verification: "Appian secondary text color only meets contrast requirements on a pure white background. Verify contrast on this non-white background."

### Alternate Grid Row Shading
- RULE-VM-21: When grids use alternate row shading (via `shadeAlternateRows: true` on `a!gridField`), text color contrast MUST be verified against BOTH the white row background AND the shaded row background. Scan for `a!gridField` with `shadeAlternateRows: true` — flag: "Verify text contrast meets 4.5:1 ratio against both white and shaded row backgrounds."

### Screen Magnification
- RULE-VM-22: Screen magnification testing (200% and 400%) MUST be performed in a web browser, NOT in Appian Designer. At 200% zoom, all text must be readable, functional, and not overlap. At 400% zoom (at 1280px browser width), content must not require both vertical and horizontal scrolling, and no loss of content or functionality may occur. Grids and complex images are exempt from the 400% requirement.

### Pane Layout — Magnification
- RULE-PL-02: Using more than one `a!pane` in a `a!paneLayout` typically fails the 400% magnification requirement. Scan for `a!paneLayout` containing 2 or more `a!pane` components — flag: "Multiple panes on a single page typically fail the 400% magnification requirement. Verify content stacks correctly and does not require horizontal scrolling at 400% zoom."

### Section/Box Layout — Non-Expandable Heading Tags
- RULE-SB-03: Even when a `a!boxLayout` is NOT expandable (`isCollapsible: false` or not set), if a `label` parameter IS set, the `labelHeadingTag` parameter SHOULD also be set to an appropriate heading level. The heading level defaults to H3 if no `labelHeadingTag` is set. Scan for `a!boxLayout` with `label` set but `labelHeadingTag` NOT set — flag: "Box layout has a label but no explicit labelHeadingTag. Defaults to H3 — verify this is the correct heading level for the content hierarchy."
- RULE-SB-04: Even when a `a!sectionLayout` is NOT expandable (`isCollapsible: false` or not set), if a `label` parameter IS set, the `labelHeadingTag` parameter SHOULD also be set to an appropriate heading level. The heading level defaults to H2 if no `labelHeadingTag` is set. Scan for `a!sectionLayout` with `label` set but `labelHeadingTag` NOT set — flag: "Section layout has a label but no explicit labelHeadingTag. Defaults to H2 — verify this is the correct heading level for the content hierarchy."
- RULE-SB-05: Expandable/collapsible layouts (`a!sectionLayout` with `isCollapsible: true` or `a!boxLayout` with `isCollapsible: true`) are "disclosure widgets". The control that expands and collapses content MUST always be defined as a heading using the `labelHeadingTag` parameter. The label should summarize the content in the expandable area. Scan for `a!sectionLayout` or `a!boxLayout` with `isCollapsible: true` but WITHOUT `labelHeadingTag` — flag as MUST FIX: "Expandable layout is a disclosure widget and MUST have labelHeadingTag set. The expand/collapse control must be a semantic heading."

### Cards — Nested Controls Detail
- RULE-CA-05: Nesting controls within cards that are defined as links results in invalid HTML, which hinders screen readers from identifying nested controls correctly AND can remove keyboard access entirely. Scan for `a!cardLayout` with `link` parameter set that also contains any of: `a!buttonWidget`, `a!linkField`, `a!richTextItem` with `link`, `a!textField`, `a!dropdownField`, `a!checkboxField`, `a!radioButtonField`, or any other input/control component in its `contents`. Flag as MUST FIX: "Card is defined as a link but contains interactive controls inside. This creates invalid HTML that breaks screen reader identification and may remove keyboard access."

### Tooltips
- RULE-TT-01: The `tooltip` parameter MUST NOT be set on `a!richTextDisplayField` (text components). Tooltips on text are not keyboard accessible. Scan for `a!richTextDisplayField` with `tooltip` parameter set — flag: "Tooltip on rich text is not keyboard accessible. Move important information to visible text or use a different component."
- RULE-TT-02: The `tooltip` parameter MUST NOT be set on disabled buttons or disabled inputs. Disabled elements cannot receive keyboard focus, so their tooltips are inaccessible. Scan for `a!buttonWidget` with `disabled: true` AND `tooltip` set, or any input component with `disabled: true` AND `tooltip` set — flag: "Tooltip on a disabled control is not keyboard accessible. Remove the tooltip or provide the information through other means."
- RULE-TT-03: When an icon is used in a link, do NOT use the `tooltip` parameter on `a!richTextDisplayField` to provide additional context. Instead, set the `caption` parameter directly on the `a!richTextIcon`. The tooltip on `a!richTextDisplayField` is not readily available to non-sighted users. Scan for `a!richTextDisplayField` containing a `a!richTextIcon` inside a link where `tooltip` is set on the `a!richTextDisplayField` but `caption` is NOT set on the icon — flag: "Use caption on the icon instead of tooltip on the richTextDisplayField. Tooltip is not available to non-sighted users."

### Card Group Layout — Label Position
- RULE-CG-03: When a semantic heading is output above a `a!cardGroupLayout` that explains the grouping, use `labelPosition: "COLLAPSED"` on the card group layout. The label must still be set — it just won't be visually displayed. Scan for `a!cardGroupLayout` with `label` set where a `a!headingField` or `a!richTextDisplayField` with STRONG styling appears immediately before it in the same parent layout — suggest: "Consider using labelPosition: COLLAPSED since a visible heading already describes this card group."

### File Upload — Instructions Content
- RULE-FU-03: The `instructions` parameter on `a!fileUploadField` MUST include supported file formats/types (e.g., ".DOCX, .XLSX, .PNG, .JPG"). Scan for `a!fileUploadField` with `instructions` set — if the instructions text does NOT contain file extension patterns (e.g., strings matching `\.\w{2,4}`) or words like "supported", "file type", "format", flag: "File upload instructions should include supported file types/formats."

### Signature Component — Keyboard Alternative
- RULE-SG-02: The keyboard alternative for `a!signatureField` MUST require the user to physically make a selection or provide a value — the alternative option MUST NOT default to a pre-selected value. Acceptable alternatives include: `a!checkboxField` (unchecked by default), `a!radioButtonField` (no default selection), or `a!dropdownField` (with placeholder, no default). The alternative can be contained in a collapsible `a!sectionLayout` that is collapsed by default. Scan for `a!signatureField` — check if a `a!checkboxField`, `a!radioButtonField`, or `a!dropdownField` exists nearby. If found, verify the alternative does not have a pre-selected default value.

### Dynamic Status Messages — announceBehavior Values
- RULE-DC-04: When using `a!messageBanner` for dynamic status messages, the `announceBehavior` parameter MUST be set to `"DISPLAY_AND_ANNOUNCE"` (to both show and announce) or `"ANNOUNCE_ONLY"` (to announce without visual display). Scan for `a!messageBanner` that does NOT have `announceBehavior` set, or has it set to `"DISPLAY_ONLY"` when it's the only banner for that message — flag: "messageBanner should use announceBehavior: DISPLAY_AND_ANNOUNCE to ensure screen readers announce the message."

### Redundant Form Sections — Appian 25.4+
- RULE-FI-08: As of Appian 25.4, box and section layouts are defined as semantic regions, providing the necessary semantic context for multiple inputs having the same name/label. When duplicated form sections exist, the PREFERRED approach is to wrap each repeated section in a `a!sectionLayout` or `a!boxLayout` with a unique `label` (e.g., "Contact 1", "Contact 2"). When using this approach, do NOT also set `accessibilityText` on each input — the layout label provides sufficient context. Scan for patterns where inputs inside a labeled `a!sectionLayout` or `a!boxLayout` also have `accessibilityText` set to the same value as the layout label — flag: "Remove accessibilityText from inputs inside a labeled section/box layout. The layout label already provides the semantic context (Appian 25.4+)."

### Custom Pagination — Non-Applicable Icons
- RULE-CP-03: Icons representing non-applicable/disabled pagination elements (e.g., "first page" and "previous page" when already on page 1) MUST NOT have `altText` or `caption` set. The fix is to REMOVE the `altText`/`caption` parameters entirely from `a!richTextIcon` components that represent non-applicable pagination states — do NOT set them to empty strings. Do NOT use `accessibilityText` to indicate "disabled" state. Scan for pagination patterns where `a!richTextIcon` (with icons like "angle-double-left-bold", "angle-left-bold", "angle-right-bold", "angle-double-right-bold") has `altText` containing "disabled" or "inactive" — flag: "Remove altText from non-applicable pagination icons. Do not announce disabled state for pagination elements." **⚠️ PREFERRED FIX (updated 2026-05-12 per Kurt Bunge feedback): Replace pagination links with `a!buttonWidget` components that use the `disabled` parameter when the pagination action does not apply. Buttons are the semantically correct control for pagination actions. Links should not be used for pagination as that is not their purpose.**


### Rules added from audit gap analysis (2026-04-22)

#### Icon-Only Links (strengthened IC-01)
- RULE-IC-10: When a `a!richTextIcon` with a `link` parameter appears as the ONLY element inside a `a!richTextItem` (no adjacent text), and the icon has no `altText` or `caption`, this creates a completely empty link — a CRITICAL violation. Scan for `a!richTextIcon` with `link` that is NOT accompanied by text content in the same `a!richTextItem`. Flag as CRITICAL: "Icon-only link has no text alternative — screen readers announce an empty link."
- RULE-IC-11: When a `a!richTextIcon` with a `link` appears immediately adjacent to a `a!richTextItem` with text that has its OWN separate `link`, this creates two tab stops for what appears to be one action. Scan for patterns where an icon link and a text link appear side-by-side pointing to the same destination. Flag as MUST FIX: "Icon and text are separate links to the same destination — merge into a single link containing both the icon and text. Remove the link from the icon and place both icon and text inside one `a!richTextItem` with a single `link`. **After merging, REMOVE `altText` and `caption` from the icon entirely** — the adjacent text already conveys the icon's purpose, making the icon decorative within the combined link."

#### Grid Selection State Changes (strengthened GR-06)
- RULE-GR-10: When a button or control ABOVE a selectable grid has its `disabled` state controlled by grid selection (e.g., `disabled: length(local!selectedRows) < 2`), the user MUST be informed of the relationship between grid selection and button availability. **⚠️ REWRITTEN (2026-05-12 per Kurt Bunge feedback):** Use EITHER: (1) `accessibilityText` on the grid warning users that selecting rows will enable controls above the table (PREFERRED — provides upfront context without repeated announcements), OR (2) `a!messageBanner` with `announceBehavior` AFTER the button becomes enabled. Do NOT use both simultaneously, and do NOT fire a messageBanner on every row selection. The grid accessibilityText approach is preferred as it provides upfront context without repeated announcements that can overwhelm users who select multiple rows.
- RULE-GR-11: Instructional text above a selectable grid that describes how to use the grid (e.g., "Select 2 or more rows to enable Create Awards") MUST be programmatically associated with the grid via the grid's `instructions` parameter, NOT placed as a separate `a!richTextDisplayField` above the grid. Scan for `a!richTextDisplayField` appearing before a `a!gridField` where the text contains words like "select", "row", "check" — flag: "Move instructional text into the grid's `instructions` parameter so it is programmatically associated with the table."

#### Record Action Scope Detection
- RULE-RA-01: When an interface contains `a!recordActionField` or `a!recordActionItem`, the record action form it triggers is a CHILD INTERFACE that MUST be included in the audit scope. The triggered form may have its own a11y issues (focus management, heading structure, etc.). Flag as VERIFY: "This interface triggers a record action form — ensure the target form interface is included in the audit scope and checked for RULE-FM-01 (focusOnFirstInput) and RULE-MD-01."

#### Dynamic Content Lifecycle (strengthened DC-01)
- RULE-DC-05: When a `a!messageBanner` with `announceBehavior: "ANNOUNCE_ONLY"` is used to announce a temporary status (e.g., "sources are loading"), the REMOVAL or COMPLETION of that status MUST ALSO be announced via a separate `a!messageBanner`. Scan for `a!messageBanner` with `showWhen` conditions — if the banner disappears when a condition changes (e.g., loading completes), check that a SECOND `a!messageBanner` announces the completion state. Flag as MUST FIX: "Temporary status message announces appearance but not removal/completion. Add a second `a!messageBanner` with `announceBehavior: 'ANNOUNCE_AND_DISPLAY'` or `'ANNOUNCE_ONLY'` to announce when the operation completes."
- RULE-DC-06: When AI-generated content or custom async operations update the UI progressively (e.g., chat responses streaming in, document scanning), BOTH the start AND end of the operation MUST be announced. Scan for patterns with `a!messageBanner` that has `showWhen` tied to a loading/processing variable — if only one banner exists for the loading state, flag: "Async operation announces start but not completion. Add announcement for when the operation finishes." **⚠️ EXCLUSION (updated 2026-05-12 per Kurt Bunge feedback): Components using Appian's built-in async loading (e.g., `a!localVariables` with `a!refreshVariable` or `asyncRefresh` patterns) are EXCLUDED from this rule.** The platform already provides automatic live screen reader announcements for these. This rule only applies to custom async operations like AI chat streaming or manual polling where the platform does NOT provide automatic announcements.

#### Duplicate Names in forEach (strengthened VM-17)
- RULE-VM-23: When `a!richTextIcon` with `altText` appears inside a `a!forEach` loop, the `altText` MUST include a unique identifier from the loop context — even if the altText is multi-word. Scan for `a!richTextIcon` with `altText` inside `a!forEach` where the `altText` value does NOT reference a loop variable (e.g., `fv!item.name`, `fv!item.title`, `fv!item.id`). Flag as MUST FIX: "Icon altText in forEach loop is static — all iterations will have identical screen reader text. Include a unique identifier: e.g., `altText: 'Expand ' & fv!item.promptHeading` instead of `altText: 'Expand Source Text'`."
- RULE-FI-09: When links (not just icons) appear inside a `a!forEach` loop and share the same link text across iterations, each link MUST include a unique identifier. Scan for `a!richTextItem` with static `text` and `link` inside `a!forEach` — flag: "Link text is identical across forEach iterations. Screen reader users cannot distinguish between repeated links. Include unique context in the link text."

#### Link Focus Visibility (new detection for LK-04 + preventWrapping)
- RULE-LK-05: When `preventWrapping: true` is set on a `a!richTextDisplayField` that contains links, the link may lose visible focus indicators. Scan for `a!richTextDisplayField` with `preventWrapping: true` that contains `a!richTextItem` with `link` — flag as VERIFY: "preventWrapping: true on a richTextDisplayField containing links may cause visible focus indicators to be clipped or hidden. Test with keyboard navigation to confirm focus is visible."
- RULE-LK-06: The combination of `linkStyle: "STANDALONE"` on a link AND `preventWrapping: true` on the containing `a!richTextDisplayField` is especially problematic — STANDALONE links rely on color alone, and preventWrapping can clip the focus outline. Flag as MUST FIX when both conditions are detected together.


### Rules added from audit gap analysis (2026-04-23)
- RULE-SYNC-01: PORTAL: Buttons incorrectly identified as tabs. Recurring in 1 apps (GAM). SAIL components: unknown. SAIL params to check: unknown. Category: general.


### Rules added from audit gap analysis (2026-05-07)
- RULE-IC-07: Document image in card link missing altText. Source: GAMS-8013-01. SAIL components: a!documentImage, a!cardLayout. SAIL params to check: accessibilityText, altText. Detection: a!documentImage inside a card link (a!cardLayout with link parameter) has no altText. Screen reader only announces the link text but not that the content is AI-generated or document-related. The altTe
- RULE-IC-08: Icon in link missing altText when icon conveys document context. Source: GAMS-8013-02. SAIL components: a!richTextIcon. SAIL params to check: altText, caption. Detection: a!richTextIcon (file-text-o) inside a link conveys that the linked item is a document, but has no altText or caption. The link text alone (section name) doesn't convey the document context. When an ic
- RULE-IC-09: Icon altText used when caption should be used (icon meaning not universally clear). Source: GAMS-8013-03. SAIL components: a!richTextIcon. SAIL params to check: altText, caption. Detection: a!richTextIcon uses altText: 'Findings' but the icon (search) doesn't universally convey 'findings'. When an icon's meaning is not universally understood based on its appearance alone, the caption par
- RULE-HD-04: Document card headings at wrong level + duplicate link names without context. Source: GAMS-8013-05. SAIL components: a!cardGroupLayout. SAIL params to check: label, accessibilityText. Detection: Document cards in a forEach loop have: (1) heading at wrong hierarchical level (H3 when it should be H5 based on page structure), and (2) repeated 'View' links with no distinguishing context. When car
- RULE-FI-06: Search/filter field using accessibilityText instead of label parameter. Source: GAMS-8013-06. SAIL components: a!textField. SAIL params to check: label, accessibilityText, placeholder. Detection: Search text field (a!textField or custom search component) uses accessibilityText and placeholder instead of the label parameter. accessibilityText provides a description, not a label. Placeholder tex
- RULE-FI-07: Search field with only placeholder text - no persistent visible label. Source: GAMS-8013-07. SAIL components: unknown. SAIL params to check: label, labelPosition, placeholder. Detection: Search/filter text field uses only placeholder text with labelPosition: COLLAPSED and no visible label nearby. Placeholder disappears on input, leaving users with low vision or cognitive impairment un
- RULE-DC-07: Dynamic content loaded in adjacent pane not announced. Source: GAMS-8013-08. SAIL components: a!messageBanner. SAIL params to check: accessibilityText, instructions. Detection: When a user action (e.g., selecting a vendor card) causes content to load in a different pane/region, non-sighted users are not informed of the content change. A messageBanner ANNOUNCE_ONLY for the se
- RULE-DC-08: Search results count not announced to screen readers. Source: GAMS-8013-09. SAIL components: a!messageBanner. SAIL params to check: announceBehavior. Detection: After a search/filter action, the number of results returned is not announced to screen readers. Users must navigate extensively to discover the outcome. A a!messageBanner with announceBehavior: ANNOU
- RULE-CA-04: Card selection state requires accessibilityText on card itself, not just messageBanner. Source: GAMS-8013-10. SAIL components: unknown. SAIL params to check: accessibilityText. Detection: When a card uses color/style to indicate selection, messageBanner ANNOUNCE_ONLY alone is NOT sufficient. The card itself MUST have accessibilityText: 'Selected' set dynamically when selected (and remo
- RULE-VM-16: Selected card color contrast insufficient (below 3:1). Source: GAMS-8013-11. SAIL components: unknown. SAIL params to check: unknown. Detection: The color used to indicate a card as selected has insufficient contrast against adjacent unselected cards. The contrast ratio between the selected card background and an adjacent unselected card backg
- RULE-LK-03: Duplicate link names in repeated cards without distinguishing context. Source: GAMS-8013-12. SAIL components: a!cardGroupLayout, a!boxLayout, a!sectionLayout. SAIL params to check: label, accessibilityText. Detection: Multiple cards in a forEach loop contain links with identical text (e.g., 'View') without any distinguishing context for screen reader users. Each link must be uniquely identifiable. Fix options: (1)
