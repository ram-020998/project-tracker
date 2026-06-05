# Playwright + Appian Helper

## Overview

This guide covers how to use Playwright MCP to navigate, interact with, and verify accessibility issues in Appian applications. Appian is a low-code platform with a custom SAIL UI framework that requires specific interaction patterns.

---

## Environment Setup

### Target URL
- Always confirm the target environment URL with the user before starting
- Appian environments follow the pattern: `https://{env-name}.appianpreview.com/suite/`
- The Jarvis MCP may connect to a different environment than the one used for Playwright verification — don't assume they're the same

### Login
- Navigate to `https://{env}.appianpreview.com/suite/`
- Fill username and password textboxes, click "Sign In" button
- Wait 3-5 seconds after login for the redirect to complete
- Confirm login success by checking the page title changes from "GAM - DEV 2" to something meaningful

---

## Appian URL Patterns

| Type | Pattern |
|------|---------|
| Site home | `/suite/sites/{site-name}` |
| Site page | `/suite/sites/{site-name}/page/{page-name}` |
| Record view | `/suite/sites/{site-name}/page/{page-name}/record/{encoded-id}/view/{view-name}` |
| Process action | `/suite/sites/{site-name}/page/{page-name}/start-process/{encoded-id}?parameters={uuid}` |
| Designer | `/suite/design` |
| Application | `/suite/design/app/{app-id}` |

---

## Timing and Waiting

### Mandatory Waits
- **After navigation:** Always `wait_for(time: 3-4)` after `browser_navigate` or any URL change
- **After dynamic link clicks:** Wait 3-4 seconds — Appian SPAs load content asynchronously
- **After dropdown selection:** Wait 2-3 seconds for dependent fields to update (e.g., selecting Document Type enables Document Template)
- **After process actions:** Wait 5 seconds — process-driven wizards may trigger backend processes

### Signals That Content Has Loaded
- Page title changes (e.g., "GAM - DEV 2" → "Evaluations - Source Selection")
- The `main` element contains meaningful content (not just logs)
- Headings appear in the snapshot

---

## Interacting with Appian Components

### Dynamic Links (`href="#"`)
- Appian uses `href="#"` links with `saveInto` handlers for dynamic navigation
- **DO:** Use Playwright's native `.click()` via ref or role selectors
- **DON'T:** Use `page.evaluate(() => element.click())` — this doesn't trigger Appian's full event chain
- Some records may error (500) while others work — it's data-dependent. Try multiple items before concluding a feature is broken.

### Custom Comboboxes (Dropdowns)
Appian dropdowns are NOT native `<select>` elements. They use `role="combobox"` with custom rendering.

**How to select a value:**
1. Click the combobox element to open it (use ref or `getByRole('combobox', { name: '...' })`)
2. Use keyboard navigation: `ArrowDown` to move through options
3. Press `Enter` to select the highlighted option
4. Wait 2 seconds for the selection to trigger any dependent updates

**DO NOT** use `browser_select_option` — it only works with native `<select>` elements and will error.

**Alternative:** If you know the exact option text, you can try `page.evaluate` to find and click the `[role="option"]` element, but this may not trigger Appian's saveInto handlers. Keyboard navigation is more reliable.

### "More Actions" Dropdown (Record Actions)
- Click the `button "More actions"` element
- The dropdown renders as a `listbox` with `option` elements inside the button
- The button gets `[expanded]` attribute when open
- Click the desired `option` by ref or role: `getByRole('option', { name: '...' })`

### Buttons with accessibilityText
Appian buttons render with both a visible label and accessibilityText as separate child elements:
```
button "Add Task Add Task" [ref=eXXX]:
  - generic: Add Task          ← visible label
  - generic: Add Task          ← accessibilityText
```
The button's accessible name is the concatenation of both. Use the full name or just the visible label with `getByRole('button', { name: '...' })`.

### Inline Edit Views
- Clicking a record name (e.g., approach name) may replace the content area inline without changing the URL
- The heading changes (e.g., "Approaches" → "Edit Approach") confirming the view switched
- Always re-snapshot after these transitions
- If the view doesn't change, check console errors — the interface may have errored for that specific record

---

## Modal Dialogs (Record Actions, Wizards)

### Detection
- Appian record actions open as modal dialogs with `role="dialog"`
- They render OUTSIDE the `main` element
- The `main` content stays visible behind the dialog

### Snapshotting Dialogs
- Use `browser_snapshot(target: "[role='dialog']")` to capture only the dialog content
- Don't snapshot `main` — it will show the background page, not the dialog

### Multi-Step Wizards
- Wizards show "Step X of Y" text and have Back/Next/Cancel buttons
- Fill required fields on each step before clicking "Next"
- The "Next" button is `[disabled]` until required fields are filled
- After clicking "Next", wait 3-5 seconds for the next step to load (may trigger backend processes)

---

## Accessibility Tree Patterns for Appian Components

### How Appian Components Render in the Accessibility Tree

| Appian Component | Accessibility Tree Rendering |
|-----------------|------------------------------|
| `a!stampField` | `generic "value"` (no specific role) |
| `a!richTextIcon` with altText | `img "altText value"` |
| `a!richTextIcon` without altText (decorative) | `img` (no name — correct) |
| `a!cardLayout` with link | `link "concatenated text content"` |
| `a!cardLayout` with accessibilityText | Separate `generic` child with the text |
| `a!gridField` | `table` with `rowgroup`, `row`, `cell`, `columnheader` |
| `a!gridField` with rowHeader | `rowheader` element instead of `cell` for that column |
| `a!buttonWidget` | `button "label accessibilityText"` |
| `a!dropdownField` | `combobox "label"` |
| `a!textField` | `textbox "label"` with `/placeholder` attribute |
| `a!documentImage` as link | `link "altText"` containing `img "altText"` |
| `a!sectionLayout` | `region "label"` with `heading` |
| `a!formLayout` | No specific landmark — renders as generic containers |
| `a!headerContentLayout` | Generic container |
| Status badges (Active, In Progress) | `generic "status text"` |
| `labelPosition: "COLLAPSED"` | Field renders without visible label — modern Appian does NOT announce default labels like "rich text" or "stamp" |
| `a!progressBarField` | `progressbar` |
| `a!recordActionField` in dropdown | `listbox` with `option` elements |

### Identifying A11Y Issues in the Tree

| Issue | What to Look For |
|-------|-----------------|
| Decorative icon has altText | `img "text"` where the text duplicates adjacent content |
| Missing visible label | `textbox` or `combobox` with only `/placeholder` and no label text above |
| Redundant accessibilityText | `generic "Press enter to..."` as child of a `link` element |
| Duplicate button names | Multiple `button "same name"` elements with no distinguishing context |
| Image of text | `link` containing `img "text"` where the image IS the text content |
| Missing rowHeader | Grid cells that should be `rowheader` but render as `cell` |
| Duplicate icon text | `img "text"` inside a link that also contains the same text as a text node |

---

## Navigation Strategies

### Using Jarvis KB to Find Navigation Paths
Before navigating in Playwright, use Jarvis tools to understand how to reach an interface:

1. `jarvis_search_objects` — find the interface by name
2. `jarvis_get_entry_points_for_object` — find which features/clusters contain it
3. `jarvis_get_cluster` — get the full feature tree from an entry point
4. `jarvis_get_dependency_chain` — see calledBy relationships to trace the call hierarchy

### Common Navigation Flows

**Evaluation Record:**
1. Navigate to `/suite/sites/source-selection/page/evaluations`
2. Click an evaluation name link in the grid
3. Use tabs (Summary, Factors, Vendors, Tasks, etc.)

**Vendor Record:**
1. Navigate to `/suite/sites/source-selection/page/vendors`
2. Click a vendor name link in the grid
3. Use tabs (Summary, Classifications, etc.)

**Settings (Task Management):**
1. Navigate to `/suite/sites/source-selection-settings`
2. Use left rail navigation (Welcome, Phases, Tasks, Approaches, Reviews)
3. Click item names in grids to open edit views inline

**Record Actions (Wizards):**
1. Navigate to a record view
2. Click "More actions" button → select action from dropdown
3. Dialog opens with `role="dialog"`
4. Fill fields step by step, click "Next"

---

## Error Handling

### Console Errors
- Use `browser_console_messages(level: "error")` to check for server-side failures
- A 500 error with "Error Evaluating UI Expression" means the interface failed to render — it's a code/data issue, not a Playwright issue
- Try a different record if one errors — the issue may be data-specific

### Stale Refs
- After page updates (dynamic link clicks, step transitions), element refs become stale
- Always take a new snapshot before interacting with elements
- If `target: "eXXX"` fails with "ref not found", re-snapshot first

### Dynamic Content Not Appearing
- If a click doesn't produce visible changes, check:
  1. Console errors (500 errors)
  2. Whether the content loaded in a dialog (check `[role='dialog']`)
  3. Whether the content replaced inline (check for heading changes)
  4. Whether you need to wait longer (some processes take 5+ seconds)

---

## Pre-Fix Verification Checklist

When verifying an A11Y issue exists in the live UI:

1. **Navigate** to the correct page/interface
2. **Wait** for content to fully load (3-5 seconds)
3. **Snapshot** the relevant section (use `target` to limit scope)
4. **Search** the accessibility tree for the reported issue:
   - Missing labels → look for `textbox`/`combobox` without label text
   - Redundant text → look for duplicate text in `img` alt and adjacent content
   - Missing rowHeader → look for `cell` where `rowheader` should be
   - Image of text → look for `img` inside `link` where image IS the content
5. **Document** the exact element refs and text found as evidence
6. **Compare** to ticket description to confirm match

---

## Tips and Tricks

1. **Snapshot depth:** Use `depth: 3-4` for large pages to get structure without overwhelming detail, then drill into specific sections with `target`
2. **Multiple items:** If one record/approach errors, try another — data issues are common in dev environments
3. **Keyboard over mouse:** For Appian custom widgets (comboboxes, date pickers), keyboard navigation (ArrowDown + Enter) is more reliable than click
4. **Dialog detection:** Use `page.evaluate` to check for `[role="dialog"]` or `.ModalDialogLayout---modal_dialog` class
5. **Full page vs section:** Snapshot `main` for the page content, `[role='dialog']` for modals, specific refs for sections
6. **Appian site navigation:** The top nav bar has site pages as links — use these for quick navigation between major sections
