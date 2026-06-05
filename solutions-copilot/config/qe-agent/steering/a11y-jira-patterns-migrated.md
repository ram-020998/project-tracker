---
inclusion: manual
---

# A11y Jira Bug Patterns (Cross-App Reference)

> **Auto-generated from Jira a11y bugs across all applications.**
> These are real bugs found by the Appian Accessibility team during audits.
> Every pattern here can occur in ANY application — check all of them during every audit.
>
> Last synced: 2026-05-20 | Total patterns: 265
> Projects: CC, CMS, GAMS, PSS, SI

## How to Use During Audits

When auditing SAIL code, check for these patterns IN ADDITION to the Aurora checklist rules.
The rules in `a11y-sail-rules.md` tell you WHAT must be done. These patterns tell you
HOW bugs actually manifest in real Appian apps — with specific Jira references.

If you find a match, cite the Jira key in your finding for traceability.

---

## Accessibility Text Misuse

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Misuse of accessibility text | Critical | Misuse of accessibility text | PSS-3315, GAMS-8333, GAMS-5556, CMS-4250, GAMS-6167 |
| Content lacks accessibility text | High | Content lacks accessibility text - Create New Document | GAMS-8282 |
| Incorrect accessibility text used for satisfied ru | Medium | Incorrect accessibility text used for satisfied rules | GAMS-6856 |
| Incorrect use of accessibility text | High | Incorrect use of accessibility text | CMS-4249 |

## Cards & Selection State

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| The state of the currently selected card is indica | High | The state of the currently selected card is indicated only by visual styling | PSS-2267, GAMS-7472, GAMS-8562, CMS-4263, CMS-4236, CMS-4234 |
| Currently selected text item card link indicated b | Medium | Currently selected text item card link indicated by color alone | SI-582 |
| Card links conveyed as tabs | High | Card links conveyed as tabs | GAMS-7467 |
| Insufficient color contrast between selected and u | Medium | Insufficient color contrast between selected and unselected card states | GAMS-8563 |
| A11y issues with vendor document cards | Medium | A11y issues with vendor document cards | GAMS-8550 |
| Card uses color or visual styling to convey inform | High | Card uses color or visual styling to convey information | CMS-4239 |
| Card link has invalid control nesting | Critical | Card link has invalid control nesting | GAMS-6174 |

## Color Contrast

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Text has insufficient color contrast | Medium | Text has insufficient color contrast | PSS-3266, GAMS-6649, CMS-4241 |
| Tag color options have insufficient color contrast | Medium | Tag color options have insufficient color contrast | PSS-3264 |
| GCA/GCW Integration | Medium | GCA/GCW Integration - Text has insufficient color contrast | GAMS-2729 |
| Currently selected Text and Background colors indi | High | Currently selected Text and Background colors indicated by color alone | GAMS-2711 |
| MODULE | Medium | MODULE - Text has insufficient color contrast - file type/size | CMS-4287 |

## Custom Pagination

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Custom pagination controls not defined | High | Custom pagination controls not defined | SI-579 |
| Insufficient target size for adjacent active pagin | Medium | Insufficient target size for adjacent active pagination controls | GAMS-7376 |

## DateTime Component

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Date & Time component is used | High | Date & Time component is used - Update Due Date | CMS-4247, CMS-4242 |

## Dynamic Content & Announcements

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Dynamic content change is unknown to non | High | Dynamic content change is unknown to non-sighted users | PSS-2380, PSS-2346, GAMS-6683, GAMS-8331, GAMS-8283, GAMS-7461, GAMS-8561 (+12 more) |
| Dynamic status message is unknown to non | High | Dynamic status message is unknown to non-sighted users - Generate Outline | PSS-3267, PSS-3259, PSS-2348, PSS-2263, GAMS-5005, GAMS-6166 |
| Wizard/process steps are unknown to non | High | Wizard/process steps are unknown to non-sighted users - Create Document from ... | GAMS-8287, GAMS-8278 |
| Result of search is unknown to non | High | Result of search is unknown to non-sighted users | GAMS-8560, GAMS-4996 |
| Extraction process unknown to non | Medium | Extraction process unknown to non-sighted users | GAMS-6195 |
| Dynamic interface content is not easily perceivabl | Low | Dynamic interface content is not easily perceivable | GAMS-2721 |
|  | Medium | - ASCII character screen reader interpretation is confusing | GAMS-2709 |
| Text in Create Clause confirmation screen has insu | Medium | Text in Create Clause confirmation screen has insufficient color contrast | GAMS-2707 |
| Dynamic confirmation screen is unknown to non | High | Dynamic confirmation screen is unknown to non-sighted users | CMS-4273 |
| Dynamic message not announced by screen readers | High | Dynamic message not announced by screen readers | GAMS-6452 |
| VM: A11y | High | VM: A11y - Newly-added content unknown to non-sighted users - For Application | GAMS-6377 |

## Focus Management

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| No indication of link keyboard focus | High | No indication of link keyboard focus - Document Chat | GAMS-7464, GAMS-7228, CMS-4261, GAMS-7064 |
| Content added in illogical reading sequence | High | Content added in illogical reading sequence - misc. app areas | PSS-2192, PSS-2079 |
| Focus is lost after button activation | High | Focus is lost after button activation | PSS-3269 |
| Incorrect focus order in Insert Link dialog | Medium | Incorrect focus order in Insert Link dialog | GAMS-2727 |
| Search button not in a logical tab order | High | Search button not in a logical tab order | GAMS-7378 |

## Form Inputs & Labels

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Duplicate input names are present | High | Duplicate input names are present | PSS-3270, PSS-2467, PSS-2466, PSS-2349, GAMS-8285, GAMS-7463, GAMS-7226 (+9 more) |
| Card group layout has no label | Critical | Card group layout has no label | PSS-3265, PSS-1936, CMS-4262, GAMS-8276, GAMS-7477, CMS-4269, CMS-4268 |
| Field name not included in numeric validation mess | Medium | Field name not included in numeric validation message | GAMS-6288, GAMS-3912, GAMS-2712, CMS-4258, CMS-4245, GAMS-6286, GAMS-6173 |
| Pane layouts have no label | High | Pane layouts have no label | GAMS-7476, CMS-4248, GAMS-6647, GAMS-5000, GAMS-2715 |
| Instructions not associated with grid | High | Instructions not associated with grid | GAMS-8335, GAMS-8284, GAMS-6646, GAMS-2720 |
| Keyboard focus set on form input in dialog | High | Keyboard focus set on form input in dialog | GAMS-2724, CMS-4264, CMS-4255, CMS-4240 |
| Pane layout has incorrect label | High | Pane layout has incorrect label - Search Results | PSS-3319, PSS-3316, GAMS-5002 |
| Legend not present for form having required fields | Medium | Legend not present for form having required fields with asterisk | PSS-2264, GAMS-2718, GAMS-6172 |
| Input fields do not have a persistently visible la | High | Input fields do not have a persistently visible label | PSS-3268, CMS-4267 |
| Search input has no label parameter value | High | Search input has no label parameter value | GAMS-8288, GAMS-8555 |
| GCA/GCW Integration | Medium | GCA/GCW Integration - Form input has no visually persistent label | GAMS-2728, GAMS-2717 |
| Paragraph field has no label | High | Paragraph field has no label | SI-583 |
| Grids have no label | High | Grids have no label | PSS-3271 |
| Instructions not associated with the form input | High | Instructions not associated with the form input | PSS-2378 |
| Instructions not associated with the form input (P | High | Instructions not associated with the form input (Procurement/FAR) | PSS-2345 |
| Instructions not associated with chat prompt input | High | Instructions not associated with chat prompt input | GAMS-6682 |
| Inputs do not maintain focus | Critical | Inputs do not maintain focus | GAMS-8334 |
| Document Selection Dropdown has no programmatic la | Critical | Document Selection Dropdown has no programmatic label | GAMS-8332 |
| Checkboxes have no programmatic label | Critical | Checkboxes have no programmatic label | GAMS-7557 |
| Progress bars have no programmatic label | Critical | Progress bars have no programmatic label | CC-738 |
| Search field does not have a persistently visible  | High | Search field does not have a persistently visible label | GAMS-8559 |
| Non | High | Non-standard checkbox operation unavailable to non-sighted users | GAMS-6648 |
| Instructions not associated with Upload button | High | Instructions not associated with Upload button | GAMS-5003 |
| Control label does not match visible label | Medium | Control label does not match visible label | GAMS-4998 |
| Single checkbox indicated as a checkbox group with | Medium | Single checkbox indicated as a checkbox group with redundant label | GAMS-4997 |
| File Upload has incorrect label | High | File Upload has incorrect label | GAMS-8329 |
| Checkbox has incorrect label | High | Checkbox has incorrect label | GAMS-7564 |
| Dynamic radio button instructions not associated w | High | Dynamic radio button instructions not associated with the form input | GAMS-6197 |
| Radio button component has no label | Medium | Radio button component has no label | GAMS-6196 |
|  | Medium | - Legend not present for form having required fields with asterisk | CMS-4286 |
| Input purpose is incorrect | Medium | Input purpose is incorrect | CMS-4271 |
| Invalid error messaging, input not marked as inval | Critical | Invalid error messaging, input not marked as invalid | CMS-4257 |
| Form input field not programmatically indicated as | Critical | Form input field not programmatically indicated as being required | CMS-4256 |
| Grid has no label | High | Grid has no label - Documents | CMS-4251 |
| Search field has no label parameter value, only pl | High | Search field has no label parameter value, only placeholder text is used | GAMS-7377 |
| Placeholder text is used to convey information for | Medium | Placeholder text is used to convey information for a form input | GAMS-7375 |
| Grid column has no label and column header (resear | Critical | Grid column has no label and column header (research) | GAMS-6449 |
| Search, Bot Type and Date inputs have no visible a | Critical | Search, Bot Type and Date inputs have no visible and programmatic label | GAMS-6448 |
| Item Type dropdown has no visible and programmatic | Critical | Item Type dropdown has no visible and programmatic label | GAMS-6447 |
| Search input field has incorrect programmatic labe | High | Search input field has incorrect programmatic label | GAMS-6177 |
| Misuse of hidden label | High | Misuse of hidden label - Save to Requirement | GAMS-6169 |
| Incorrect indication of required input | High | Incorrect indication of required input | GAMS-6165 |
| Invalid labeling | High | Invalid labeling | GAMS-8616 |

## Forms & Validation

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Redundant, non | High | Redundant, non-descript error messaging | PSS-3274 |
| Validation messaging is not accessible | Critical | Validation messaging is not accessible | PSS-3273 |
| Prescription Text and Clause Text form fields are  | High | Prescription Text and Clause Text form fields are not programmatically indica... | GAMS-2710 |

## Grids & Tables

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Grid row header defined on incorrect cell | High | Grid row header defined on incorrect cell - Template Listing | PSS-3262, PSS-3248, GAMS-8281, GAMS-4968, GAMS-6291 |
| Grid column has no column header | Critical | Grid column has no column header | GAMS-6450, GAMS-6446 |
| Content is in an illogical sequence, simulated gri | High | Content is in an illogical sequence, simulated grid layout used - settle claim | CC-759 |
| Form controls above grid become enabled behind use | Medium | Form controls above grid become enabled behind user's perspective | GAMS-7223 |
| Grid row drag and drop does not have a single | High | Grid row drag and drop does not have a single-pointer alternative | GAMS-5192 |
| Text in shaded grid rows has insufficient color co | Medium | Text in shaded grid rows has insufficient color contrast | GAMS-6857 |
| Duplicate grid names are present | Medium | Duplicate grid names are present | GAMS-2725 |
| Text has insufficient color contrast | Medium | Text has insufficient color contrast - selected grid row | CMS-4252 |
| Grid row header not defined | High | Grid row header not defined | GAMS-6168 |

## Headings

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Headings are defined as rich text | High | Headings are defined as rich text | PSS-3320, PSS-3253, PSS-3252, GAMS-7561, GAMS-8286, GAMS-7466, GAMS-8549 (+8 more) |
| Headings use incorrect heading levels | High | Headings use incorrect heading levels - Template Preview | PSS-3251, GAMS-8275 |
| Heading uses incorrect heading level | Medium | Heading uses incorrect heading level - Cases landing | CMS-4266, CMS-4260 |
| MODULE | High | MODULE - Headings are defined as rich text | CMS-4327 |
| Heading issues with Vendor Analysis page | High | Heading issues with Vendor Analysis page | GAMS-8553 |
| Condition group headings are defined as tags | High | Condition group headings are defined as tags | GAMS-6855 |
| Smart Search | Medium | Smart Search - A11Y: a!headingField missing headingTag causing improper seman... | CMS-4342 |
| Main page heading uses incorrect heading level | Medium | Main page heading uses incorrect heading level - portal sign in | CMS-4270 |
| Two H1 headings present on the same page | Medium | Two H1 headings present on the same page | GAMS-7383 |

## Icons & Images

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Icon used as the only element in a button has no t | Critical | Icon used as the only element in a button has no text alternative | PSS-3317, PSS-2275, CC-752, GAMS-7221, GAMS-7559, GAMS-8620 |
| Icon used with text in a link has incorrect text a | Critical | Icon used with text in a link has incorrect text alternative - FAR chat | PSS-2347, GAMS-8551, GAMS-8546, GAMS-2722, CMS-4238 |
| Linked image has no text alternative | High | Linked image has no text alternative | SI-580, GAMS-7381, GAMS-8622 |
| Standalone icon that conveys information has no te | Critical | Standalone icon that conveys information has no text alternative | CMS-4265, GAMS-7558, CMS-4294 |
| Link text/icon text alternative not descriptive | High | Link text/icon text alternative not descriptive | PSS-3272, GAMS-7066 |
| Icon that conveys information has insufficient col | Medium | Icon that conveys information has insufficient color contrast | GAMS-6292, GAMS-7566 |
| Decorative icon has a text alternative | High | Decorative icon has a text alternative | GAMS-7560, CMS-4233 |
| GSS | Medium | GSS - Keyboard focus set to icon and link text individually | GAMS-6831 |
| Document image used with text in a link conveys in | Critical | Document image used with text in a link conveys information and has no text a... | GAMS-8543 |
| Pagination link icons have redundant text alternat | Low | Pagination link icons have redundant text alternatives | GAMS-7379 |

## Keyboard Interaction

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Tooltip set on a disabled button | Critical | Tooltip set on a disabled button | PSS-3260 |
| Toolbar button tooltips not keyboard accessible | Medium | Toolbar button tooltips not keyboard accessible | GAMS-2726 |

## Links & Navigation

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Misuse of accessibility text on a link | Medium | Misuse of accessibility text on a link - View/Hide Details | GAMS-7556, GAMS-7552 |
| Link purpose is unclear | High | Link purpose is unclear | PSS-3261 |
| Link indicated only by color | Medium | Link indicated only by color | GAMS-8564 |
| Insufficient target size for adjacent active links | Medium | Insufficient target size for adjacent active links | GAMS-5424 |
| Insert Link dialog Close button has incorrect role | High | Insert Link dialog Close button has incorrect role | GAMS-2719 |
| Color alone identifies link | Medium | Color alone identifies link | CMS-4272 |

## Other

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Insufficient target size for active, adjacent cont | High | Insufficient target size for active, adjacent controls | GAMS-7065, GAMS-6176 |
| Group information unavailable to non | High | Group information unavailable to non-sighted users | PSS-3263 |
| Vendor Evaluation Task Form missing A11y Legend in | Medium | Vendor Evaluation Task Form missing A11y Legend in GSS | GAMS-6864 |
| Dialog not apparent to non | High | Dialog not apparent to non-sighted users | GAMS-7553 |
| Opportunity chat is inaccessible | Critical | Opportunity chat is inaccessible | GAMS-6681 |
| ASCII character renders incorrectly | Medium | ASCII character renders incorrectly | GAMS-8552 |
| Incomplete/non | Medium | Incomplete/non-descriptive page names | GAMS-4880 |
| LPTA task form and complete Factor/evaluation form | High | LPTA task form and complete Factor/evaluation form- a11y bugs | GAMS-3704 |
| Incorrect use of message banner | High | Incorrect use of message banner | GAMS-8330 |
| Relationships in content not apparent to non | Medium | Relationships in content not apparent to non-sighted users | GAMS-2723 |
|  | Medium | - Insert Text buttons have duplicate names | GAMS-2714 |
| Disclosure elements defined incorrectly | Medium | Disclosure elements defined incorrectly | CMS-4259 |
| Content added to the interface behind the user's p | Medium | Content added to the interface behind the user's perspective | GAMS-7380 |
| A11y bugs | High | A11y bugs - Attachments section in Create opportunity screen | GAMS-8649 |

## Zoom & Reflow

| Pattern | Severity | Description | Jira Keys |
|---------|----------|-------------|-----------|
| Content requires both vertical and horizontal scro | Medium | Content requires both vertical and horizontal scrolling at 400% zoom | PSS-2352, GAMS-4971 |
| Content overlaps and requires two | High | Content overlaps and requires two-way scrolling at 400% zoom | GAMS-5001, CMS-4235 |
| Content is removed with 400% browser zoom | High | Content is removed with 400% browser zoom | CMS-4244, CMS-4243 |
| Content overlaps and is truncated at 400% zoom | High | Content overlaps and is truncated at 400% zoom | PSS-3250 |
| Content in pane layout is removed from interface a | Critical | Content in pane layout is removed from interface at 400% zoom | GAMS-310 |
| Content is unavailable at 400% zoom | Medium | Content is unavailable at 400% zoom - Register as a Vendor | GAMS-4884 |
| Content requires vertical and horizontal scrolling | Medium | Content requires vertical and horizontal scrolling when magnified 400% | GAMS-2716 |

---

## Applications Covered

| Application | Project Key | Patterns |
|-------------|-------------|----------|
| GAMS | GAMS | 165 |
| CMS | CMS | 50 |
| PSS | PSS | 43 |
| SI | SI | 4 |
| CC | CC | 3 |

> **Generated by `refresh_jira_patterns_steering` on 2026-05-20**
> Re-run this tool anytime after ingesting new bugs to update the steering file.
