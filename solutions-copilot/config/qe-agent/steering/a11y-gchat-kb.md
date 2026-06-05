---
inclusion: auto
---

# A11y Team Knowledge Base (from GChat)

Last synced: 2026-05-05
Total entries: 47
Source: Solutions Ask A11y [External] GChat group

> This file is auto-generated from the team's GChat discussions.
> During audits, reference these team decisions when flagging issues.
> To refresh: say 'sync a11y knowledge base' before an audit.

> **⚠️ Attribution Notice:** All entries in this KB were AI-extracted and AI-processed
> from GChat discussions. They do NOT represent direct personal responses from any
> individual. When using this KB to answer questions in the GChat space, clearly
> identify the content as AI-generated — do not attribute it to the A11y Lead or
> any named team member.

## Cards & Panes

- **Q:** Quick question on zoom testing - does the browser matter for 200% and 400% testing?
  **A:** Browser doesn't matter for zoom testing. For 200% zoom, test maximized. For 400% zoom, set viewport to 1280px width. Important: pane layouts are excluded from 400% zoom tickets - they have known platform limitations.
  *(AI-extracted from GChat discussion, 2025-05-12)*

## Color & Contrast

- **Q:** The Select and Upload Cards seen here become disabled after clicking one of them. However, color alone is used to indicate this. What would be the remediation for this accessibility issue.
  **A:** Because these were links when they were applicable and are no longer links when they aren't applicable, we have no option other than to use a flimsy workaround. When styling is used to convey both/either aren't applicable, set accessibilityText on the card of Function unavailable. Do not use disabled in the a11y text.
  *(AI-extracted from GChat discussion, 2026-03-23)*

- **Q:** Is there a color contrast requirement for disabled controls? What about read-only controls?
  **A:** No color contrast requirement for disabled controls - WCAG explicitly exempts them. However, there IS a contrast requirement for read-only controls. Read-only controls are still perceivable and convey information, so they must meet the standard 4.5:1 contrast ratio for text.
  *(AI-extracted from GChat discussion, 2025-11-03)*

- **Q:** For record action links in a list, how do we differentiate them visually? They all look the same and fail the link differentiation check.
  **A:** Several options for link differentiation: 1) Use linkStyle: INLINE which adds underline, 2) Add an icon before the link, 3) Use bold or italic styling, 4) Place each link on a different line. The key is that links must be distinguishable from surrounding non-link text by more than just color.
  *(AI-extracted from GChat discussion, 2025-07-01)*

## Error Handling

- **Q:** As per this a11y requirement it's important we use a!messageBanner for error validation. However, for forms we're using the OOTB form validation which means we can't use the albeit better component because this error validation is hooked up directly to the form. Is this permissible or will we get flagged for this in an audit?
  **A:** The requirement in your screenshot is for dynamic messaging such as toast messages, it's not aimed at error messaging. The requirement for error messaging is that OOTB error handling needs to be used.
  *(AI-extracted from GChat discussion, 2026-04-21)*

## Form Inputs & Labels

- **Q:** We have an interface with multiple 'Show all' links, so we added a label parameter to the a!dynamicLink which is set to 'Show all for <date and time>'. When testing this with VoiceOver on Safari, only 'Show all' is getting announced. Does anything stand out in our implementation here? Or are you aware of any platform bugs that could be causing the label to not get announced?
  **A:** For dynamic links, the platform also puts the label text above and outside of the link. Then an invalid method is used to associate that label with the link itself. So I would bet you can read the label but only using the arrow keys, reading directly before the link. This is not considered to be fully accessible. It is the same as setting accessibility text on the rich text display field. It works, but it's not fully accessible, it's only available to one mode of navigation.
  *(AI-extracted from GChat discussion, 2026-05-05)*

- **Q:** We need to build a toggle switch and a tab component. Are there accessible SAIL components for these now, or do we still need workarounds?
  **A:** Great news - use a!toggleField (available in 26.2) for switches and a!tabField (available in 26.1) for tabs. No more workarounds needed! These are native SAIL components with built-in accessibility support. The toggle has proper role='switch' and the tab has proper role='tab' with aria-selected.
  *(AI-extracted from GChat discussion, 2026-03-24)*

- **Q:** Found a VoiceOver bug with dynamic instructions on a!textField. When instructions change dynamically, VoiceOver doesn't update the programmatically associated content. Is this a known platform issue?
  **A:** Yes, this is a known VoiceOver bug. VoiceOver doesn't update programmatically associated content when it changes dynamically. This is a platform-level issue, not something you can fix in SAIL. File it as a platform bug.
  *(AI-extracted from GChat discussion, 2025-05-19)*

- **Q:** When should we use accessibilityText on components? I've been adding it to everything but the auditor says some are wrong.
  **A:** accessibilityText should NEVER include text that is already visible onscreen. It replaces the visible label for screen readers, so duplicating visible text creates redundant announcements. Use accessibilityText ONLY for unique context that isn't visible - like distinguishing between multiple 'Edit' buttons by adding row context.
  *(AI-extracted from GChat discussion, 2025-12-15)*

- **Q:** For validation messages, do we always need to include the field label? Even for format validations like 'Invalid email format'?
  **A:** Validation messages should include the visible field label in MOST cases. 'Invalid email format' should be 'Email Address: Invalid email format'. Screen reader users may not know which field the error belongs to without the label. **UPDATED (2026-05-12):** However, there are exceptions — validations for exceeding character counter limits and decimal field format validations cannot always include the field label due to platform constraints. The blanket "ALWAYS" rule does not apply.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** Is it OK to use rich text as a visible label for an input field? And when should we use accessibilityText vs label parameter?
  **A:** Rich text as a visible label is OK IF you also set the label parameter to the same string with position: COLLAPSED. This creates the programmatic label association. The rich text provides the visual label, and the collapsed label provides the programmatic one. Important: accessibilityText should NEVER duplicate the label. Use accessibilityText only for additional context not visible on screen.
  *(AI-extracted from GChat discussion, 2025-08-20)*

- **Q:** Can a heading or rich text serve as the visible label for an input field below it?
  **A:** Yes, a heading or rich text can serve as the visible label for an input field. But you MUST also set the label parameter on the input to the same string with position: COLLAPSED. The heading/rich text provides the visual label, and the collapsed label parameter creates the programmatic association that screen readers need.
  *(AI-extracted from GChat discussion, 2026-02-03)*

- **Q:** Can we put a link inside a clickable card? We need both the card click and a separate link action.
  **A:** No, you cannot nest inputs or links inside clickable cards. This creates a 'link inside link' or 'button inside link' pattern which is invalid HTML and causes major screen reader issues. The nested interactive element either becomes unreachable or creates confusing announcements. Choose one: either the card is clickable OR it contains links, not both.
  *(AI-extracted from GChat discussion, 2026-02-10)*

- **Q:** What counts as a valid visible label for an input? Can it be a heading above the field, or does it have to be the label parameter?
  **A:** Any visible text can serve as the visible label - heading, rich text, or the label parameter itself. However, the label parameter must ALWAYS be set as the programmatic label. If you use a heading as the visible label, set label to the same text with position: COLLAPSED. The programmatic label (label param) is non-negotiable.
  *(AI-extracted from GChat discussion, 2026-02-18)*

- **Q:** We use validationGroup which removes the default required asterisk. Is it OK to hardcode the asterisk in the label text?
  **A:** Yes, it's OK to hardcode the asterisk when validationGroup removes the default one. But keep required=TRUE on the field - the hardcoded asterisk is just visual, the required parameter is what provides the programmatic 'required' state to screen readers.
  *(AI-extracted from GChat discussion, 2026-02-25)*

## General A11y

- **Q:** We have a wizard with multiple steps. Some steps have no required fields. Is it OK to still show the asterisk legend 'Required fields are marked with an asterisk' on those steps?
  **A:** Yes, it's OK to keep the required field asterisk legend on wizard steps that don't have required fields. It's a consistent pattern across the form and removing it per-step would be more confusing. Consistency is important for accessibility.
  *(AI-extracted from GChat discussion, 2025-09-18)*

## Grid & Tables

- **Q:** Hi Kurt, I have a grid question for you. In one of our interfaces, we changed a!gridField_26r2 to a!gridField, and I realized that this latest version of gridField now shows of many in the pagination, instead of the total number of grid items. There is also no more first page / last page pagination. Out of curiosity, does this cause any a11y issues?
  **A:** I have not seen this before. It technically does not cause an a11y issue because it's basically the same poor experience for all users. What it is, however, is extremely poor design.
  *(AI-extracted from GChat discussion, 2026-04-14)*

- **Q:** We have duplicated controls (like multiple 'Edit' buttons) in a grid. The a11y checklist says we need accessibilityText for context. What's the best approach?
  **A:** Per the checklist, duplicated controls need unique accessibilityText to provide context. For example, instead of just 'Edit' on every row, use accessibilityText like 'Edit Vendor ABC' or 'Edit row 1'. Each control must be distinguishable by screen readers.
  *(AI-extracted from GChat discussion, 2025-06-10)*

- **Q:** Should we set rowHeader on editable grids? Also question about heading hierarchy in box layouts.
  **A:** Do NOT set rowHeader on editable grids for two reasons: 1) Values in editable grids are not unique (users can type the same value in multiple rows), and 2) Setting rowHeader on a dropdown column causes extreme verbosity - the screen reader announces the full dropdown options list as the row header for every cell in that row. For box layout heading hierarchy, use labelHeadingTag to set the correct heading level.
  *(AI-extracted from GChat discussion, 2025-07-22)*

- **Q:** In an editable grid, do the column headers serve as labels for the input fields in each column?
  **A:** ~~Yes! Editable grid column headers ARE the visible and programmatic labels for the inputs in that column.~~ **CORRECTED (2026-05-12):** Editable grid column headers do NOT automatically serve as programmatic labels for inputs in that column. Each input in an editable grid still needs its own `label` parameter set (with `labelPosition: "COLLAPSED"` if the column header serves as the visible label). The column header provides visual context but does NOT create a programmatic label association.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** Having issues with reading order in column layouts. We have a 3-column layout and screen readers are reading across rows instead of down columns. How do we fix this?
  **A:** ~~Reading order in column layouts follows the DOM order, which goes left-to-right across columns.~~ **CORRECTED (2026-05-12):** Reading order in Appian column layouts reads DOWN each column, not across rows. The DOM order in Appian `a!columnsLayout` outputs all content in column 1, then all content in column 2, then column 3. Screen readers follow this DOM order. The previous advice to "restructure to 2 columns" was incorrect.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** Questions about grids and zoom: Are grids excluded from 400% zoom scrolling requirements? Also, does target sizing apply to grid action buttons? And what about custom pagination links?
  **A:** ~~Yes, grids are excluded from 400% zoom horizontal scrolling requirements - they're complex data tables that inherently need horizontal space.~~ **CORRECTED (2026-05-12):** Appian grids are NOT "complex data tables" in the WCAG sense. Complex data tables have multiple levels of row/column headers, merged cells, or nested header structures — Appian grids do not support these patterns. Therefore, Appian grids are NOT exempt from 400% zoom horizontal scrolling requirements. They are standard data tables and must meet the same reflow requirements as other content. Target sizing (24x24px minimum) applies to any adjacent actionable controls, including grid action buttons. Custom pagination links are common a11y failures - make sure they have proper labels and meet target size requirements.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** Do grid action columns need column headers? We have columns with just action menus or download buttons. The a11y checklist mentions column headers are required.
  **A:** Grid action columns don't need column headers if the purpose is obvious from the controls themselves. An actions menu column, a download button column, or a delete button column - these are self-explanatory. The checklist rule about column headers applies to data columns and input columns, not action columns where the control label is sufficient.
  *(AI-extracted from GChat discussion, 2025-12-01)*

- **Q:** For selected state on tabs/cards, we're using bold text instead of color change. Does bold text bypass the color contrast requirement for selected state?
  **A:** Yes, bold text is an acceptable way to indicate selected state and it bypasses the color contrast requirement. WCAG says the selected state indicator just needs to be perceivable by means other than color alone. Bold text, underline, border, icon change - all are acceptable alternatives to color-only indication.
  *(AI-extracted from GChat discussion, 2025-07-15)*

- **Q:** In an editable grid, some fields become required conditionally based on other field values. How do we communicate this to screen reader users? Setting accessibilityText on each input seems excessive.
  **A:** For conditional required fields in grids, use grid-level accessibilityText or the instructions parameter instead of per-input accessibilityText. Something like 'When Status is Active, Name and Date are required'. This gives context once at the grid level rather than repeating on every input.
  *(AI-extracted from GChat discussion, 2026-01-15)*

- **Q:** Hi Kurt, in this grid, the first column has a profile image that links to the user. Right now, the screen reader just says link image for the first column and then reads the user's name in the second column. Is the current way correct, or should the link in the first column also announce the user's name?
  **A:** Because the image is the only thing used in the link, it must have a text alternative set on the image. Otherwise, a non-sighted user doesn't know what the link is for or what it does. If you can set the altText parameter on the image, it should be set to the user name. The other alternative is to put the avatar into the same cell as the user name and NOT provide a text alternative for the image (because the adjacent user name provides that information already). Some don't like doing this approa
  *(AI-extracted from GChat discussion, 2026-04-08)*

- **Q:** Hi Kurt, we have an interface with this Document Builder section, which is automatically refreshed every 30 seconds, and upon record action. We have a message banner that's supposed to be announced each time the refresh happens. Currently, it's only getting announced when the refresh happens every 30s. It's not getting announced if the refresh happens on record action. On record action, the whole page reloads, so the screen reader announces a generic Finished working instead. Is this current imp
  **A:** If the user is taken to an entirely different screen, the message banner for only a screen reader shouldn't be used. The message banner is for things that occur dynamically within an interface, such as adding content, adding content into another pane, etc. For non-sighted users, it is specifically for anything they aren't aware of that happens on a page.
  *(AI-extracted from GChat discussion, 2026-03-24)*

## Headings

- **Q:** Is it problematic to use a!headingField for things that aren't technically heading anything? Is it okay to use it for visual design purposes or would non-sighted users find it confusing / annoying?
  **A:** The component is defined as a heading by default. If a headingTag parameter is not provided or set, the text is an H3 heading and that cannot be changed or manipulated unless a different heading level is chosen. Therefore, the heading component shouldn't be used for text that is technically not a heading. It would cause confusion.
  *(AI-extracted from GChat discussion, 2026-04-10)*

- **Q:** Are heading levels subjective? We have Filters as H3 but the auditor says they should be H4. Who's right?
  **A:** Heading levels are somewhat subjective, but they must follow a logical hierarchy. If your page has H1 for the page title, H2 for main sections, then Filters as a subsection should be H3 or H4 depending on nesting. If Filters is a subsection under an H3, it should be H4. The rule is: don't skip levels and maintain logical nesting.
  *(AI-extracted from GChat discussion, 2025-07-08)*

- **Q:** In this Create Document from Template Task form, the title uses simpleHeader (red), which I believe effectively functions as an H1 tag. The various steps (purple) in the form are currently set as H2 tags. My question concerns the Selected Template heading (green). I've set it as an H3 tag because I believe that reflects its priority relative to the other headings. However, since it doesn't directly fall under an H2 heading and is followed by other H2 headings, would this cause any issues?
  **A:** That isn't a problem. Heading levels do not need to be in sequential order - they just need to make sense based on the content structure on the given page. It is preferred that the levels be in order, but it's not a hard requirement, it's a best practice. The reason that it is a best practice is if it were a requirement it would force all web pages to have to follow the same structural pattern, which is not a realistic expectation.
  *(AI-extracted from GChat discussion, 2026-03-26)*

## Links

- **Q:** Hi Kurt, for the links in this screenshot which have the same link text, do we need to add accessibilityText to differentiate them? We already plan to update the linkStyle to INLINE.
  **A:** If there is absolutely nothing that can be used for uniqueness, then there is nothing technically that can be done to provide a differentiation. So, don't use accessibility text...it is what it is. As far as links using the inline linkstyle...don't do it, it'll kill the design and the dreams of UXDs everywhere, and will cause me great pain in my joints. Instead, can you simply bold the text in the links to cushion the blow?
  *(AI-extracted from GChat discussion, 2026-04-23)*

## Screen Reader

- **Q:** Can we use accessibilityText to provide dynamic status updates? Like changing the a11y text when data loads?
  **A:** No! accessibilityText is NOT dynamically evaluated - it's static information only. Screen readers read it once when they encounter the element. For dynamic announcements, use a!messageBanner with announceBehavior: ANNOUNCE_ONLY. Position the banner at the bottom of the interface to avoid layout shifts.
  *(AI-extracted from GChat discussion, 2026-03-03)*

- **Q:** I've been adding a!messageBanner everywhere for announcements - on form load, after every save, for status updates, for OOTB validation errors. Is this the right approach?
  **A:** DO NOT overuse a!messageBanner! It's not for static messages, not for OOTB validation (which already has its own announcement mechanism), and not for every status update. Overcompensating with messageBanner actually DEGRADES accessibility - screen reader users get bombarded with announcements and can't focus on their task. Use it only for: page-level error summaries, critical status changes, and wizard navigation errors.
  *(AI-extracted from GChat discussion, 2026-04-07)*

- **Q:** How should we handle error messaging in wizards? We need to show errors when the user tries to advance without completing required fields.
  **A:** Use a!messageBanner with announceBehavior: DISPLAY_AND_ANNOUNCE for wizard error messaging. Position the banner at the bottom of the interface, not the top. ANNOUNCE_ONLY can leave residual visual artifacts. DISPLAY_AND_ANNOUNCE shows the banner AND announces it to screen readers.
  *(AI-extracted from GChat discussion, 2026-01-06)*

- **Q:** Can we use a!messageBanner or rich text for validation messages? We want to show errors in a custom way.
  **A:** Message banners and rich text must NOT be used for field-level validations. Use the built-in validation parameters on form fields. The platform is working on live region support in 25.3 which will improve dynamic announcements. For now, OOTB validation is the only accessible way to show field errors.
  *(AI-extracted from GChat discussion, 2025-08-12)*

- **Q:** What should the accessibilityText on a pane describe? The pane content or what happens when you select something?
  **A:** **CORRECTED (2026-05-12):** Pane `accessibilityText` should describe the PURPOSE/CONTENT of the pane region — it serves as the accessible name for the landmark. It should NOT describe what happens when you interact with content inside it. Example: 'Vendor details' is correct. 'Select a vendor to view details' is incorrect because that describes an action, not the region's identity. For dynamic announcements when pane content changes, use `a!messageBanner` — but that is a separate concern from the pane's accessible name.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** What's the recommended pattern for error messaging across a complex form? We have page-level, section-level, and field-level errors.
  **A:** Three-level error messaging pattern: 1) Page-level: a!messageBanner with DISPLAY_AND_ANNOUNCE - shows and announces a summary like '3 errors found', 2) Section-level: a!messageBanner with DISPLAY_ONLY - visual indicator near the section with errors, no announcement (to avoid noise), 3) Field-level: OOTB validation messages on each field. This layered approach gives users both the big picture and specific details.
  *(AI-extracted from GChat discussion, 2026-03-17)*

- **Q:** For a!pickerField with maxSelections, should we use the instructions parameter to indicate the selection limit?
  **A:** Yes, use the instructions parameter on the picker field to indicate the maximum number of selections allowed. Something like 'Select up to 3 items'. This gives screen reader users the context they need before interacting with the picker.
  *(AI-extracted from GChat discussion, 2025-06-02)*

- **Q:** For pane layout images, should we include 'pane' in the altText? Like 'Vendor Details pane'? Also what about decorative images in empty states?
  **A:** Remove 'pane' from altText - users don't know what a pane is in the Appian context. Just describe the content, like 'Vendor Details'. For decorative images in empty states, they should have no altText at all (empty string or null). Decorative images that don't convey information should be hidden from screen readers.
  *(AI-extracted from GChat discussion, 2025-10-06)*

- **Q:** Does anyone have a good reference for VoiceOver keyboard shortcuts? I keep forgetting the commands.
  **A:** Best reference is dequeuniversity.com - they have comprehensive VoiceOver keyboard shortcut guides. Also remember: always use VoiceOver with Safari, not Chrome. Chrome has known compatibility issues with VoiceOver.
  *(AI-extracted from GChat discussion, 2025-09-25)*

- **Q:** Found a platform bug: tooltip on the first card in a pane layout conflicts with VoiceOver and NVDA. The tooltip text overrides the card content announcement.
  **A:** Known platform bug with tooltip conflict on cards in pane layouts. The fix is to use caption on icons instead of tooltip on cards. Caption provides the same visual hover text but doesn't interfere with the screen reader announcement of the card content.
  *(AI-extracted from GChat discussion, 2025-10-15)*

- **Q:** Found a platform bug: when you set accessibilityText on a rich text link, the a11y text is positioned BEFORE the link in the DOM. It's only announced in Browse mode, not Focus mode.
  **A:** This is a known platform bug. The accessibilityText on rich text links gets positioned before the link element in the DOM, so it's only picked up in Browse mode (reading through the page) but not in Focus mode (tabbing to interactive elements). File it as a platform issue. For now, make sure the visible link text itself is descriptive enough.
  *(AI-extracted from GChat discussion, 2025-08-05)*

- **Q:** Getting some weird screen reader announcements: 'clickable' on non-interactive elements, primary button announced twice, and rich text editor content announced as readonly. Are these platform issues?
  **A:** **CORRECTED (2026-05-12):** 1) 'clickable' announced on non-interactive elements is a modern web behavior in general (not specific to Appian) — it occurs because of how event delegation works in modern JavaScript frameworks. This is NOT a platform-specific bug and no bug should be filed. 2) Primary button announced twice is also a general web rendering behavior, not an Appian-specific defect. No bug should be filed. 3) Rich text editor readonly content is expected when the editor is in display mode — this is by design.
  *(AI-extracted from GChat discussion, corrected 2026-05-12)*

- **Q:** For card links, should we add instructions like 'Click to view details' in the accessibilityText?
  **A:** No! Card link text already implies its purpose - don't add 'click to' instructions. Never provide activation instructions in accessibilityText. Screen reader users know how to activate links and buttons. Adding 'click to view' is redundant and patronizing. The link text itself should describe the destination or action.
  *(AI-extracted from GChat discussion, 2025-12-10)*

- **Q:** How do disabled controls behave with screen readers? Do they get announced at all?
  **A:** Yes, screen readers announce disabled controls in Browse mode as 'disabled', 'unavailable', or 'dimmed' depending on the screen reader. They also announce the current value. Users can read them but not interact. This is the expected WCAG behavior - disabled controls should be perceivable but not operable.
  *(AI-extracted from GChat discussion, 2025-09-02)*

- **Q:** What should the altText be for the sparkle/AI icon? We're using it to indicate AI-generated content.
  **A:** **UPDATED (2026-05-12):** The sparkle icon altText should be 'AI'. Modern screen readers handle 'AI' correctly now. If a non-sighted user prefers 'artificial intelligence', they can configure that mapping in their own screen reader user settings. The previous advice to use 'artificial intelligence' is no longer recommended.
  *(AI-extracted from GChat discussion, updated 2026-05-12)*

- **Q:** In the document smart search card in Case Management, PDF is set as the text parameter in the stamp field, which the screen reader reads aloud. Could you confirm whether the .pdf extension should also be appended to the document name displayed in the title on the right?
  **A:** Use the extension in one place or the other, not both, otherwise the info would be redundant. In your case here, having it set on the stamp is sufficient. If you were to add the extension to the document name, then it would need to be removed from the stamp. It's better to have it on the stamp because it's an image and...you can keep the same design without a need to change anything.
  *(AI-extracted from GChat discussion, 2026-04-22)*
