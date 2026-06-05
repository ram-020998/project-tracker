---
inclusion: auto
---

# Step 1: Workflow Analysis

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This is the MOST CRITICAL step in the entire workflow.** If you get this wrong, every subsequent step will produce incorrect data. You MUST trace the COMPLETE workflow path from start to the user's desired state, including EVERY rule, EVERY subprocess, EVERY write operation, and EVERY data transformation.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 0 is ✅ COMPLETE** — All 5 files must exist. If not, STOP and complete Step 0.
2. ✅ **UNDERSTAND THE USER'S REQUEST** — What entity? What target status/state? What conditions?
3. ✅ **PLAN YOUR QUERIES** — You will need multiple Solutions Intelligence KB queries. Plan them ALL before starting.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **ALL APPLICATION DATA COMES FROM ATLAS KB ONLY** — Do NOT read local files, folders, or documents for application context. Only use Solutions Intelligence MCP tools (search_bundles, get_bundle, solutions-intelligence.get_object_code) and Data Generator MCP tools.
- ⚠️ **EXHAUSTIVE TRACE IS MANDATORY** — You MUST trace EVERY rule, subprocess, and write node in the workflow. No shortcuts.
- ⚠️ **DO NOT ASSUME** — If you haven't read the code, you don't know what it does. Query it.
- ⚠️ **EVERY WRITE OPERATION MATTERS** — Any node that writes to a data store = a table you need data for.
- ⚠️ **FOLLOW ALL BRANCHES** — XOR gateways, conditional logic, forEach loops — trace ALL paths that lead to the target state.
- ⚠️ **RELATED RULES ARE NOT OPTIONAL** — If a process model calls a rule, READ THAT RULE. If that rule calls another rule, READ THAT TOO. Follow the chain until you hit leaf nodes.
- ⚠️ **INCOMPLETE ANALYSIS = INCOMPLETE DATA** — Every table you miss here = a missing record in execution = a broken application state.

---

## BLOCKING CHECK

Before starting, verify:
```
Step 0: Initialize                     [✅] ✅ COMPLETED
  - All 5 files exist                  [✅] ✅ VERIFIED
```

**If Step 0 is not ✅, STOP IMMEDIATELY. Go back and complete Step 0.**

---

## EXECUTION

### 1a: Identify ALL Workflows in the Chain

⚠️ **CRITICAL: You must trace the ENTIRE lifecycle from entity creation to the target state — not just the final action.**

The user wants an entity in state X. To get there, the entity passes through states 1 → 2 → ... → X. **EACH state transition has its own process model/action.** You MUST identify and read ALL of them.

**Query Solutions Intelligence KB for EVERY action/workflow in the lifecycle:**

```
search_bundles(app_name, "{entity name}")
```

From the results, identify ALL process models and record actions related to this entity — not just the one that produces the target state. Look for:
- "Create {entity}" — what happens at initial creation
- "Start {entity}" / "Submit" / "Begin" — what happens when the entity kicks off
- "Complete" / "Finish" / "Close" — intermediate completion steps
- The final target action that produces the desired state
- ANY action that transitions status between states in the chain

⚠️ **If you only read the final action, you will MISS all records created by earlier actions (tasks, assignments, reports, generated child records).**
⚠️ **Search broadly. Use multiple search terms: entity name, status names, action verbs.**

```
search_bundles(app_name, "{entity name}")
search_bundles(app_name, "{status keyword}")
search_bundles(app_name, "start")
search_bundles(app_name, "create")
search_bundles(app_name, "task")
search_bundles(app_name, "generate")
```

---

### 1b: Read EVERY Process Model in the Lifecycle Chain

For EACH process model identified in 1a (not just the final one):

```
get_bundle(app_name, bundle_id)
```

**You MUST read the PM for EVERY status transition in the chain.** If the entity goes through 4 statuses to reach the target, you read 4+ process models.

**For EACH action/transition, you MUST identify THREE parts:**

#### Part 1: PREREQUISITES (What must be true for this action to be available?)
- Read the action's **visibility rule** / **validation rule** (usually named `BL_can{Action}` or `BL_isValid{Action}`)
- What tables MUST have records before this action becomes available?
- What fields MUST be set on existing records?
- What counts/conditions are checked? (e.g., "at least 1 child record exists", "all items have assignments")
- These prerequisites tell you what data MUST be created in EARLIER steps

#### Part 2: ACTION WORK (What does this action do when executed?)

**2a: Form Analysis (if action has a form/interface):**
- Read the action's entry form interface (the UI the user fills out)
- Identify ALL fields/inputs on the form
- Identify which fields are REQUIRED (have validation rules, required=true, or submit-blocking conditions)
- Identify what data gets SUBMITTED when the form is completed
- Identify what records are CREATED or UPDATED on form submission (the saveInto/submit logic)
- **Follow the submit button's saveInto chain** — what rules does it call? What does it write?

⚠️ **The form tells you what data the user provides during this action. If you skip the form, you'll miss records that are created as part of the user's input (e.g., evaluator responses, line items, attachments).**

**2b: Process Model Work (after form submission):**
- What records are CREATED? (INSERT operations)
- What records are UPDATED? (field changes, status transitions)
- What subprocesses are triggered synchronously?
- What fields are set, and to what values?

**Document the form fields that create records:**
```markdown
**FORM FIELDS → RECORDS:**
- {Repeating section} → creates {TABLE} records (1 per item in the list)
- {Selection field} → updates {TABLE}.{field}
- {Text input} → updates {TABLE}.{field}
- {Upload section} → creates {DOCUMENT_TABLE} records
```

⚠️ **If a form has a repeating/grid section (e.g., "add items for each entry"), each row creates a record. These are commonly missed.**

#### Part 3: TRIGGERS (What happens AFTER this action completes?)
- What async processes/listeners fire on completion?
- What auto-generated records are created (tasks, notifications, audit entries)?
- What status changes cascade to child records?
- What subsequent actions become available as a result?

**Document ALL THREE for every action in the chain:**

```markdown
### Action: {Action Name} (Status {X} → {Y})

**PREREQUISITES (must exist before action is visible):**
- {TABLE_A}: ≥1 record must exist
- {TABLE_B}: ≥1 record must be configured
- {TABLE_C}: must be assigned/linked
- Visibility rule: {rule_name}

**ACTION WORK (what it does):**
- Form: {interface_name}
  - Required: {fields that must be filled to submit}
  - Creates: {records created from form input}
  - Updates: {records updated on submission}
- Updates {TABLE}.{statusField} → {new_status}
- Creates {TABLE} records ({description})

**TRIGGERS (what happens after):**
- Generates {TABLE} records (per {formula})
- Fires {subprocess/listener name}
```

⚠️ **EVERY action MUST have all 3 parts documented. If you skip prerequisites, you will miss required tables.**
⚠️ **Prerequisites are the #1 source of missed tables** — they tell you what must exist BEFORE the workflow can proceed.

Pay special attention to:
- **Script tasks that generate/create records** — these often create child records dynamically (tasks, assignments, reports, scores)
- **Conditional generation** — "if config X is true, generate Y records"
- **forEach loops** — creating N records based on a list (e.g., one task per user, one report per item×entity)

From each process model, extract:
- **All nodes** — start, end, XOR gateways, subprocess calls, script tasks, write nodes, user tasks
- **All process variables** — their types, default values, how they're populated
- **All subprocess calls** — names and UUIDs of every subprocess invoked
- **All expression/rule references** — every rule called in script tasks, gateway conditions, write inputs
- **All write-to-data-store nodes** — which tables, which fields, what values

**Document EVERY node. Do not summarize. Do not skip nodes you think are "unimportant."**

---

### 1c: Trace ALL Subprocesses (RECURSIVE)

For EVERY subprocess referenced in 1b:

```
solutions-intelligence.get_object_code(app_name, subprocess_name)
```

Extract the same information: nodes, variables, subprocess calls, rule references, write operations.

**If a subprocess calls another subprocess, trace that too. Keep going until you reach leaf nodes.**

Build a complete call tree:
```
Main Process Model
├── Subprocess A
│   ├── Rule X (writes to TABLE_1)
│   ├── Rule Y (writes to TABLE_2)
│   └── Subprocess B
│       └── Rule Z (writes to TABLE_3)
├── Subprocess C
│   └── Rule W (writes to TABLE_4)
└── Script Task (calls Rule V → writes to TABLE_5)
```

⚠️ **EVERY LEAF NODE MUST BE TRACED. If you see a rule call, read that rule. No exceptions.**

---

### 1d: Read ALL Referenced Rules

For EVERY expression rule referenced in process models and subprocesses:

```
solutions-intelligence.get_object_code(app_name, rule_name)
```

Focus on:
- **What data does this rule write?** — `a!writeRecords`, write to data store nodes
- **What data does this rule read?** — queries that inform what values to write
- **What transformations happen?** — status changes, calculations, field updates
- **What conditions determine the path?** — XOR conditions, if/else logic, null checks
- **What other rules does THIS rule call?** — follow the chain

**Build a complete picture of every table that gets written to and what field values are set.**

---

### 1e: Identify AUTO-GENERATED Records (CRITICAL)

⚠️ **Many Appian workflows GENERATE records automatically during state transitions.** These are the most commonly missed tables.

Look for these patterns in every PM and rule you've read:

| Pattern | What It Creates | Example |
|---------|----------------|---------|
| `a!writeRecords` inside `a!forEach` | N records based on a list | Tasks per user, scores per item |
| "Generate" / "Create Default" / "Initialize" in rule names | Batch record creation | Default criteria, default tasks, assignments |
| Config-driven creation (if `isX = true` then create Y) | Conditional records | Tasks only if configured, signatures only if required |
| Cross-product creation (for each A × each B, create C) | Combinatorial records | Reports = items × entities |

**For each auto-generated record type, document:**
- What triggers the generation (which PM/step)
- How many records are created (formula: count = X × Y, or count = len(list))
- What fields are set at generation time
- What config flags control whether generation happens

**Common auto-generated tables in Appian apps:**
- Task/ToDo tables — created per user per action
- Assignment/mapping tables — created per evaluator per criteria
- Report/score tables — created per entity combination
- Notification tables — created per event
- Audit tables — created per write operation

⚠️ **If you find a "Start" or "Initialize" process model, it ALMOST CERTAINLY generates records. Read it thoroughly.**

---

### 1f: Identify ALL Tables That Receive Data

From your trace in 1b-1e, compile a COMPLETE list of every table that gets data written to it during the workflow. **Tables come from THREE sources:**

1. **Prerequisites** — tables that must have records before an action is available
2. **Action work** — tables written to during the action itself
3. **Triggers** — tables created by post-action processes (auto-generated)

For each table document:

| Table | Written By | Source | Fields Set | Values/Logic |
|-------|-----------|--------|------------|--------------|
| TABLE_1 | Rule X in Subprocess A | ACTION | field1, field2, statusId | field1="from input", statusId=3 |
| TABLE_2 | Prerequisite for Start | PREREQUISITE | parentFK, name | Must exist before Start action is visible |
| TABLE_3 | Post-action listener | TRIGGER | isActive, completionDate | Auto-created after action completes |

⚠️ **If a table is written to ANYWHERE in the workflow, it MUST appear in this list.**
⚠️ **Include tables written to by conditional branches that apply to the target state.**

---

### 1f: Identify Status Transitions

Document the COMPLETE status progression from entity creation to the target state:

```
Status: Draft (1) → In Progress (2) → Review (3) → Complete (4)
```

For each transition, document:
- What triggers the transition (user action? automated? timer?)
- What data MUST exist before the transition can occur
- What data is CREATED or MODIFIED during the transition
- What validations are checked (rules that throw errors if data is missing)

---

### 1g: Identify Reference Data Dependencies

From the rules and process models, identify:
- Every reference to a **status ID**, **type ID**, **category ID**, or similar FK to a lookup table
- Every **hardcoded constant** referenced (e.g., `cons!APP_STATUS_COMPLETE = 4`)
- Every **user field** that expects a valid username
- Every **date field** that has sequencing requirements (start < due < end)

---

### 1h: Write the Analysis Document

⚠️ **WRITE THE FILE USING CHUNKED APPROACH:**

1. **First:** Use `create` command to write the header + Process Model Call Tree + Workflow Path sections
2. **Then:** Use `insert` command (no insertLine) to append: Table Inventory, Status Transitions, Reference Data, Validation Rules, Constants, User Fields, Date Sequencing, Risks

⚠️ **Do NOT use strReplace.** Use `create` for the first chunk, then `insert` to append remaining sections.
⚠️ **If total content exceeds ~3000 words, split into 2-3 append operations.**

Update `analysis.md` — **overwrite with create, then append sections with insert.**

**Required sections (ALL mandatory):**

```markdown
# Workflow Analysis

**Status:** ✅ COMPLETE
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}
**Process Models Analyzed:** {count}
**Rules Analyzed:** {count}
**Tables Identified:** {count}

---

## User Request

{Exactly what the user asked for — entity, target state, any conditions}

## Process Model Call Tree

{Complete call tree showing main PM → subprocesses → rules → leaf nodes}
{Include the tool calls you made and bundle IDs for traceability}

## Workflow Path to Target State

### Step-by-step transitions:

1. **{Action/Trigger}** → {what happens}

   **PREREQUISITES:**
   - {Table X must have ≥N records}
   - {Field Y must be set on Z}
   - Visibility rule: {rule_name}

   **ACTION WORK:**
   - Tables written: {list}
   - Fields set: {field=value, field=value}
   - Rules involved: {rule names}
   - Form: {interface name}
   - Form creates: {records created from form input}
   - Form required fields: {what must be filled to submit}

   **TRIGGERS:**
   - Auto-generates: {table × formula}
   - Fires: {subprocess/listener name}

2. **{Next action}** → {what happens}

   **PREREQUISITES:**
   - {what must exist}

   **ACTION WORK:**
   - Tables written: {list}
   - Fields set: {field=value}

   **TRIGGERS:**
   - {post-action effects}

{Continue for ALL steps from creation to target state}

## Complete Table Inventory

| # | Table | Written By | Operation | Fields Set | Values/Logic |
|---|-------|-----------|-----------|------------|--------------|
| 1 | ... | ... | INSERT/UPDATE | ... | ... |

## Status Transitions

| From | To | Trigger | Prerequisites | Data Created |
|------|-----|---------|---------------|-------------|

## Reference Data Dependencies

| Field | Lookup Table | Required Values | Source |
|-------|-------------|----------------|--------|

## Validation Rules

{Any rules that validate data completeness — these tell you what fields MUST be populated}

## Constants Referenced

| Constant | Value | Used In |
|----------|-------|---------|

## User Fields

| Table.Field | Expects | Notes |
|-------------|---------|-------|

## Date Sequencing

| Field | Must Be | Relative To |
|-------|---------|-------------|

## Risks & Edge Cases

{Anything that could cause data generation to fail — circular FKs, conditional writes, etc.}
```

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 1 as ✅, verify ALL of the following:

- [ ] Every process model in the call tree was queried and read
- [ ] Every subprocess was traced (no unread subprocess references)
- [ ] Every rule referenced in the workflow was read
- [ ] **Every action has all 3 parts documented: PREREQUISITES, ACTION WORK, TRIGGERS**
- [ ] **Every action's form/interface was read (if it has one) to identify form-created records**
- [ ] **Every prerequisite/visibility rule was read to identify required tables**
- [ ] Every table that receives a write operation is in the Table Inventory
- [ ] **Every table required as a prerequisite is in the Table Inventory (marked as PREREQUISITE)**
- [ ] Every status transition from start to target state is documented
- [ ] Every reference data dependency (status IDs, type IDs, constants) is listed
- [ ] Every user field is identified
- [ ] Every date sequencing requirement is documented
- [ ] The analysis document has been written to disk with ✅ COMPLETE status
- [ ] The analysis is detailed enough that someone with NO context could build the data from it alone

**If ANY of these are false, you are NOT done. Keep tracing.**

---

## EXECUTION TRACKER UPDATE — MANDATORY

⚠️ **After completing this step, you MUST show the full execution tracker in your response.**
⚠️ **The tracker must be shown in EVERY response during this step — not just at the end.**

Update the tracker:
- Mark Step 1 as ✅ COMPLETED
- Set CURRENT STATUS to: `Step 2 — Exemplar Discovery`
- Set NEXT REQUIRED ACTION to: `Follow step-2-exemplar-discovery steering`

```
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
  - Process models read: {count}
  - Rules traced: {count}
  - Tables identified: {count}
```

---

## COMPLETION CRITERIA

Step 1 is ✅ COMPLETE only when:

1. `analysis.md` status is changed from ⏳ PENDING to ✅ COMPLETE
2. ALL sections in the document are filled with actual data (no placeholders)
3. The quality check above passes ALL items
4. The execution tracker is updated and SHOWN in your response

**ONLY THEN may you proceed to Step 2.**

---

## COMMON FAILURES TO AVOID

| Failure | Why It's Bad | How to Prevent |
|---------|-------------|----------------|
| **Not reading visibility/prerequisite rules** | Misses tables that must exist BEFORE an action (e.g., child records required for next step) | Read EVERY BL_can*/BL_isValid* rule for each action |
| **Not reading action forms/interfaces** | Misses records created from user input (responses, line items, documents) | Read the form interface and trace its saveInto/submit logic |
| **Only reading the FINAL action PM** | Misses all records created by earlier transitions (tasks, reports, assignments) | Read PMs for EVERY status transition from creation to target |
| Only reading the main process model | Misses 60% of writes in subprocesses | Trace ALL subprocesses recursively |
| Missing auto-generated records | "Start Evaluation" creates tasks/reports — without them the app breaks | Look for forEach + writeRecords patterns in every PM |
| Skipping "utility" rules | Utilities often do the actual writes | Read EVERY rule reference |
| Assuming a table isn't needed | Assumption = missing data = broken state | If it's written to, include it |
| Not reading conditional branches | Target state may require specific branch | Trace ALL paths to target |
| Summarizing instead of documenting | Loses detail needed for payload generation | Write the actual field=value pairs |
| Stopping at first match | May miss parallel workflows or listeners | Search for ALL related PMs |
| Ignoring config-driven generation | "if isWeightedFactorsRequired then generate weights" | Check ALL boolean config flags and what they trigger |
