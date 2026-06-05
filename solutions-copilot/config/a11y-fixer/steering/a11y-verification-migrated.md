# A11Y Fix Verification

## Overview

Verification is done via the Playwright MCP as part of the main workflow:
- **Phase 4:** Pre-fix verification using `browser_navigate` + `browser_snapshot`
- **Phase 8:** Post-fix verification using `browser_navigate` + `browser_snapshot`

See `playwright-appian-helper.md` for how to navigate Appian with Playwright.

---

## Test Data Generation for Verification

Many Appian components are conditionally rendered via `showWhen`. If the target component is not visible in the browser:

### Step 1: Identify the showWhen condition

Check the interface code for `showWhen` on the target component. Common patterns:
- `showWhen: isNotNullOrEmpty(ri!selectedItems)` — needs items selected
- `showWhen: local!isUpdate` — needs to be in update mode (not create)
- `showWhen: length(local!data) > 0` — needs data in the system

### Step 2: Create test data via the UI

Use Playwright to create the required data:
1. Navigate to the relevant landing page
2. Use the "Create" action to add test records
3. Fill required fields with test values (prefix with "A11y Test")
4. Submit the form

### Step 3: Trigger the condition

After creating data:
- Select items in grids (click checkboxes)
- Open Update dialogs (which pre-populate with existing data)
- Navigate to specific wizard steps

### Step 4: Verify the component is now visible

Take a `browser_snapshot` and confirm the target component appears in the accessibility tree.

### Common scenarios requiring test data:

| Component | Condition | How to trigger |
|-----------|-----------|----------------|
| Selected items search field | Items must be selected | Select items from Available grid |
| Update dialog with data | Record must exist | Create a record first |
| Empty state message | Search must return no results | Type a non-matching search term |
| Paging controls | More items than page size | Create multiple records |

---

## Verifying announce-only messageBanners

`a!messageBanner` with `announceBehavior: "ANNOUNCE_ONLY"` does NOT render visible content or appear in the accessibility tree snapshot. It uses ARIA live regions that only screen readers detect.

### What you CAN verify via Playwright:
1. The interface renders without errors after deployment
2. The search/trigger mechanism works (search returns results or empty state)
3. The component is in the correct position in the code (via XML inspection)

### What you CANNOT verify via Playwright:
- The actual screen reader announcement text
- Whether the live region fires correctly

### Verification approach for announce-only banners:
1. Trigger the condition that should fire the banner (perform a search)
2. Confirm the interface responds correctly (shows results or empty state)
3. Confirm no errors in the interface rendering
4. Note in the Jira comment: "Banner fires announce-only live region — requires screen reader testing for full verification"

---

## Pre-Verification Access Check

Before starting Playwright verification, ensure the test user has access to the target interface.

### If a button/action is not visible:
1. Use Solutions to find the visibility rule: search for `BL_visibility` or `showWhen` + action name
2. Read the rule to understand the permission check (usually group membership)
3. Use `evaluate_sail_expression` to test if the user has access:
   ```
   a!isUserMemberOfGroup(username: "your-test-user", groupId: cons!APP_PREFIX_GRP_GROUP_NAME)
   ```
4. If false, ask the user to add the test user to the required group
5. Re-verify after access is granted

### Common access patterns across apps:
- **Admin actions** (Create, Update, Delete): Require membership in an admin or privileged group
- **Settings pages**: Require admin-level access
- **Record actions**: May be restricted by role (CO, CS, CM, etc.)
- **Site pages**: May require specific site group membership

The group names vary by app — use Solutions to search for the relevant constant (e.g., `lcp-api.searchObjects` with "GRP_" prefix).
