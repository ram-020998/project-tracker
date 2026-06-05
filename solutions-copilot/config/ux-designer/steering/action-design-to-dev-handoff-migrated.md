# Action: Design-to-Dev Handoff Document

Generate a comprehensive handoff document from a finalized SAIL mockup and feature spec that gives developers everything they need to implement — data model requirements, query needs, validation rules, permission logic, navigation flows, and all the "designer decisions" not visible in the mockup.

This action uses Solutions Intelligence MCP tools to understand the app's existing data model, process patterns, and integration points, then produces a structured document that eliminates back-and-forth between design and dev.

## Prerequisites

- A finalized SAIL mockup (code or file)
- A feature spec or description
- The target app name (must exist in Solutions Intelligence knowledge base)
- The feature/bundle context (what part of the app this belongs to)

---

## Workflow

### Step 1: Gather inputs

Ask the user for:
1. **SAIL mockup** — The finalized interface code (pasted, file path, or Solutions Intelligence interface name)
2. **Feature spec** — What this feature does, the user story, acceptance criteria
3. **App name** — Which application this is for
4. **Context** — Is this a new feature or modification of existing? What bundle/flow does it belong to?
5. **Any known constraints** — Performance requirements, security considerations, integration points

If retrieving from Solutions Intelligence:
```
solutions-intelligence.search_objects(app, "interface_name", "Interface")
solutions-intelligence.get_object_code(app, "interface_name")
```

### Step 2: Analyze the app's existing architecture

Understand the app's data and process patterns:

```
solutions-intelligence.get_app_overview(app)
get_hub_objects(app, top_n=20)
```

Find related bundles to understand the surrounding context:
```
search_bundles(app, "related_feature", "action")
search_bundles(app, "related_feature", "process")
```

If the interface is part of an existing flow, trace its dependencies:
```
solutions-intelligence.get_dependencies(app, "parent_interface_or_process")
get_transitive_dependencies(app, "entry_point", max_hops=2)
```

### Step 3: Load Aurora reference for standards (MANDATORY)

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
get_git_content("appian-design/aurora", "docs/layouts/forms.md")
```

This ensures validation rules and form behavior recommendations align with Aurora standards.

### Step 4: Extract implementation requirements from the mockup

Analyze the SAIL mockup and extract everything a developer needs to know:

**Data requirements:**
- What CDTs/record types are needed?
- What fields does each entity need?
- What are the relationships between entities?
- What queries are needed (and with what filters)?
- What's the expected data volume?

**Process/workflow requirements:**
- What happens on form submission?
- What process model(s) need to be triggered?
- Are there approval flows?
- What notifications should be sent?
- What audit trail is needed?

**Validation requirements:**
- Required fields
- Field-level validation rules (format, range, length)
- Cross-field validation (field A depends on field B)
- Business rule validation (e.g., "can't submit if total > budget")
- When to validate (on change? on submit? on step transition?)

**Permission requirements:**
- Who can see this interface?
- Who can edit vs. view-only?
- Are there field-level permissions?
- Are there action-level permissions (who can click which buttons)?
- What security groups/roles are involved?

**Navigation requirements:**
- How does the user get here? (site page, record action, task, link)
- Where does the user go after submission?
- What about cancel? Back? Close?
- Are there deep links needed?
- What URL parameters are expected?

**Integration requirements:**
- External system calls needed?
- Document generation?
- Email/notification triggers?
- Third-party plugins?

### Step 5: Identify "designer decisions" not in the mockup

These are the implicit decisions that designers make but don't document — the things devs always ask about:

- **Loading behavior**: What shows while data loads? Is there a loading state?
- **Save behavior**: Auto-save? Save on submit only? Draft support?
- **Error handling**: What if the save fails? Network error? Timeout?
- **Pagination**: Server-side or client-side? Page size? Sort defaults?
- **Search/filter**: Debounce timing? Minimum characters? Case sensitivity?
- **File handling**: Max file size? Allowed types? Multiple files?
- **Date/time**: What timezone? Relative or absolute display?
- **Confirmation**: Is there a confirmation step before destructive actions?
- **Undo**: Can the user undo after submission?
- **Refresh**: Does the page auto-refresh? When does stale data become a problem?

### Step 6: Check existing patterns in the app

For each requirement identified, check if the app already has a pattern:

```
solutions-intelligence.search_objects(app, "validation", "Expression Rule")
solutions-intelligence.search_objects(app, "permission", "Expression Rule")
solutions-intelligence.search_objects(app, "query", "Expression Rule")
search_bundles(app, "similar_feature", "process")
```

Reference existing implementations where possible — devs should follow established patterns.

### Step 7: Generate the Handoff Document

**Output format:**

```markdown
# Design-to-Dev Handoff: [Feature Name]
**App**: [App Name]
**Designer**: [User name if provided]
**Date**: [Current date]
**Interface**: [Interface name / file reference]

---

## 1. Feature Overview

### User Story
[The user story or feature description]

### Acceptance Criteria
1. [Criterion 1]
2. [Criterion 2]
...

### User Flow
```
[Entry point] → [This interface] → [Next step on submit]
                                  → [Next step on cancel]
```

---

## 2. Data Model

### Entities Required

#### [Entity Name] (CDT/Record Type)
| Field | Type | Required | Notes |
|---|---|---|---|
| id | Integer | Auto | Primary key |
| name | Text (255) | Yes | Display name |
| status | Text (50) | Yes | Enum: Active, Pending, Closed |
| createdBy | User | Auto | Audit field |
| createdOn | DateTime | Auto | Audit field |
| ... | ... | ... | ... |

#### [Another Entity]
| Field | Type | Required | Notes |
|---|---|---|---|
| ... | ... | ... | ... |

### Relationships
- [Entity A] → [Entity B]: One-to-many via `entityA_id` foreign key
- [Entity B] → [Entity C]: Many-to-many via junction table

### Existing entities to reuse
- `[Existing CDT name]` — already has fields X, Y, Z that this feature needs
- `[Existing Record Type]` — can extend with new fields

---

## 3. Queries & Data Access

### Required Queries

#### Query 1: [Purpose]
- **Input**: recordId (Integer)
- **Returns**: Single [Entity] record with related data
- **Filters**: Active records only, user has permission
- **Sort**: N/A
- **Pagination**: No
- **Existing rule to reference**: `rule!APP_getRecordById` (if exists)

#### Query 2: [Purpose]
- **Input**: filters (Map), pagingInfo (PagingInfo)
- **Returns**: DataSubset of [Entity] records
- **Filters**: [List specific filters]
- **Sort**: Default by createdOn DESC
- **Pagination**: Yes — 20 per page
- **Existing rule to reference**: [If exists]

---

## 4. Validation Rules

### Field-Level Validation

| Field | Rule | Error Message | When |
|---|---|---|---|
| Email | Valid email format | "Email must be a valid email address" | On blur / submit |
| Start Date | Must be today or future | "Start Date must be today or later" | On submit |
| Amount | Must be > 0 and ≤ Budget | "Amount must be between $1 and $[budget]" | On submit |
| Name | Required, max 255 chars | "Name is required" | On submit |
| ... | ... | ... | ... |

### Cross-Field Validation

| Rule | Fields Involved | Error Message | Displayed On |
|---|---|---|---|
| End date must be after start date | startDate, endDate | "End Date must be after Start Date" | endDate field |
| At least one contact method | email, phone | "Provide at least an email or phone number" | Form-level |
| ... | ... | ... | ... |

### Business Rule Validation

| Rule | Condition | Error Message | When |
|---|---|---|---|
| Budget check | totalAmount > availableBudget | "Total exceeds available budget of $[X]" | On submit |
| Duplicate check | name already exists | "[Name] already exists. Use a unique name." | On submit |
| ... | ... | ... | ... |

---

## 5. Permissions & Security

### Interface Access
- **Who can see this page**: [Group/role]
- **Who can trigger this action**: [Group/role]

### Field-Level Permissions
| Field/Section | View | Edit | Condition |
|---|---|---|---|
| Status field | All users | Managers only | `isUserMemberOfGroup(user, "Managers")` |
| Budget section | Finance + Managers | Finance only | Role-based |
| Delete button | Admins only | Admins only | `isUserMemberOfGroup(user, "Admins")` |
| ... | ... | ... | ... |

### Action Permissions
| Action | Who Can Do It | Additional Condition |
|---|---|---|
| Submit | Creator + Assignee | Record status = "Draft" |
| Approve | Manager | Record status = "Pending Approval" |
| Delete | Admin | Record status ≠ "Completed" |
| ... | ... | ... |

---

## 6. Process & Workflow

### On Submit
1. Save data to [Entity] table
2. Update record status to "[New Status]"
3. Trigger process: [Process name]
   - Send notification to [role/user]
   - Create task for [role/user]
   - Update related records
4. Navigate to [destination]

### On Cancel
- Discard unsaved changes
- Navigate back to [source page]
- No process triggered

### On Save as Draft (if applicable)
- Save current state
- Status remains "Draft"
- No notifications

### Error Handling
- **Save failure**: Show banner "Unable to save. Please try again."
- **Network timeout**: Show banner "Connection lost. Your changes are not saved."
- **Concurrent edit**: Show banner "[User] has updated this record. Refresh to see changes."

---

## 7. Navigation & Context

### Entry Points
| From | How | URL Parameters |
|---|---|---|
| Record list page | Click record link | `recordId` |
| Related action button | "Create New" button | `parentId` (optional) |
| Task inbox | Complete task | `taskId`, `recordId` |
| ... | ... | ... |

### Exit Points
| Action | Destination | Behavior |
|---|---|---|
| Submit (success) | Record summary page | Show success banner |
| Cancel | Previous page | `a!back()` or close dialog |
| Save as Draft | Stay on page | Show success banner |
| ... | ... | ... |

### Deep Linking
- URL format: `/page/[pageName]?recordId=[id]`
- Required params: `recordId`
- Optional params: `tab` (default: "overview")

---

## 8. UI Behavior Specifications

### Loading States
- **Initial load**: Show full-page loading indicator until data returns
- **Grid pagination**: Show grid-level loading (built-in)
- **Save/submit**: Disable buttons, show "Saving..." label

### Empty States
- **No records in grid**: Show "[Entity type] will appear here once created"
- **No search results**: Show "No results found for '[query]'"
- **No permission**: Show "You don't have access to view this content"

### Responsive Behavior
- **Desktop**: [Default layout as designed]
- **Tablet**: [Columns stack, sidebar collapses]
- **Phone**: [Single column, simplified navigation]
- **Implementation**: Use `a!isPageWidth()` with `showWhen`

### Confirmation Dialogs
| Action | Confirmation Required? | Message |
|---|---|---|
| Delete | Yes | "Are you sure you want to delete [name]? This cannot be undone." |
| Submit | No | Direct submit |
| Cancel (with unsaved changes) | Yes | "You have unsaved changes. Discard?" |
| ... | ... | ... |

---

## 9. Existing Rules & Components to Reuse

| Need | Existing Rule/Component | Notes |
|---|---|---|
| Status tag display | `rule!APP_SHARED_statusTag` | Pass status text, returns styled tag |
| User avatar | `rule!APP_SHARED_userAvatar` | Pass username |
| Permission check | `rule!APP_canUserEdit` | Pass recordId, returns boolean |
| ... | ... | ... |

---

## 10. Open Questions

| # | Question | For | Impact |
|---|---|---|---|
| 1 | [Question that needs product decision] | Product | Blocks [section] |
| 2 | [Technical question] | Tech Lead | Blocks [section] |
| ... | ... | ... | ... |

---

## 11. Implementation Notes

### Suggested Build Order
1. Data model (CDTs, record types)
2. Queries (expression rules)
3. Validation rules (expression rules)
4. Sub-interfaces (leaf components first)
5. Main interface
6. Process model
7. Integration testing

### Performance Considerations
- [Any large data sets that need pagination]
- [Any expensive queries that need caching]
- [Any operations that should be async]

### Testing Notes
- [Key scenarios to test]
- [Edge cases to verify]
- [Permission combinations to check]
```

### Step 8: Save and present

Save the document as `ux-reviews/dev-handoffs/{feature-name}-handoff.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. Summary of what's covered
2. Any open questions that need answers before dev can start
3. Any existing rules/components identified for reuse
4. Offer to generate the component decomposition plan as a companion document

---

## Rules

1. **Always check existing app patterns** — reference existing rules devs should reuse
2. **Always include validation rules** — this is the #1 thing devs ask about
3. **Always include permission logic** — who can see/do what is critical
4. **Always specify error handling** — what happens when things fail
5. **Always specify navigation** — where users come from and go to
6. **Be explicit about "designer decisions"** — document the implicit choices
7. **Include data types and constraints** — Text(255) not just "text"
8. **Separate "what" from "how"** — describe behavior, not SAIL implementation details
9. **Flag open questions** — if something needs a product decision, call it out
10. **Reference existing rules by name** — use Solutions Intelligence to find real rule names
11. **Include build order** — help devs plan their work
12. **Keep it scannable** — tables over paragraphs, clear headers, no walls of text
