# Appian Design Best Practices

Comprehensive best practices for designing maintainable, scalable, and reusable Appian applications. Focus on code maintainability, consistency, and readability.

## Table of Contents

1. [General SAIL Principles](#general-sail-principles)
2. [Data Types (CDTs)](#data-types-cdts)
3. [Record Types](#record-types)
4. [Constants](#constants)
5. [Expression Rules](#expression-rules)
6. [Interfaces](#interfaces)
7. [Process Models](#process-models)
8. [Reference Data](#reference-data)
9. [Internationalization](#internationalization)
10. [Database Design](#database-design)

---

## General SAIL Principles

### Commenting

**Best Practices:**
- Comment where code is potentially confusing
- Comment on separate lines above the code (enables Ctrl+/ shortcut)
- Comment above local variables whose purpose isn't obvious
- Use `TOBEDONE` (no spaces) for items needing completion before release

**Example:**
```sail
a!localVariables(
  /* Calculate total price including tax and discounts */
  local!subtotal: sum(local!items.price),
  local!taxAmount: local!subtotal * local!taxRate,
  local!finalPrice: local!subtotal + local!taxAmount - local!discount,
  
  local!finalPrice
)
```

### Code Reusability

**Principles:**
1. **Reuse objects whenever possible** - Search for existing rules before creating new ones
2. **Pass parameters to alter behavior** - Use parameters instead of duplicating code
3. **Don't over-parameterize** - If >5 behavioral parameters, consider creating a new object
4. **Reduce scope for reusability** - Break complex objects into smaller, reusable pieces
5. **Use local variables to avoid duplicating logic** - Store repeated logic once

**Example:**
```sail
/* Reusable validation rule */
rule!validateEmail(
  email: ri!userEmail,
  required: true,
  customMessage: "Please enter a valid company email"
)
```

### Formatting

**Standards:**
1. **Use Appian-standard formatting** - Ctrl+Shift+F before saving
2. **Include full-gap carriage returns** - Distinguish between variable types
3. **Place smaller parameters above larger ones** - `contents` parameter goes last

**Example:**
```sail
a!columnLayout(
  width: "NARROW",
  contents: {
    /* Large expression here */
  }
)
```

### Object Scope

**Critical Rules:**
1. **Scope matches purpose** - Object does exactly what its name says
2. **Inputs align with scope** - Only take inputs absolutely needed
3. **Outputs align with scope** - Return only what the name implies
4. **Break down into smaller scope** - Easier testing, debugging, maintaining
5. **Saves always within {}** - Proper scoping for save operations

**Examples:**
```sail
/* Good scope - does one thing */
rule!createDocumentFolder(record: ri!record)

/* Bad scope - does too much */
rule!createDocumentFolderAndStartProcess(record: ri!record, processInputs: ri!inputs)

/* Good - separate concerns */
rule!createDocumentFolder(record: ri!record)
rule!startProcessAfterFolderCreation(folderId: ri!folderId, inputs: ri!inputs)
```

### Variable & Parameter Naming

**Conventions:**
1. **Name by type** - `selectedTask` for single object, `selectedTasks` for array
2. **Use plural for arrays** - `field` vs `fields`
3. **Consistent names across application** - Same concept = same name
4. **Use affirmative naming** - `isExisting` not `isNotNew`
5. **Match variable names to rule inputs** - Helps with find & replace

**Examples:**
```sail
local!selectedCustomer      /* Single object */
local!selectedCustomers     /* Array */
local!isActive             /* Boolean - affirmative */
local!refData              /* Consistent across app */
```

### Passing Parameters

**Best Practices:**
1. **Use keyword syntax** - Allows reordering inputs without breaking
2. **Pass full objects** - Don't pass individual fields
3. **Use prefixes for behavioral parameters:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `is` | Controls state | `isAdding`, `isEditing` |
| `show` | Controls visibility | `showDescription`, `showDetails` |
| `allow` | Controls access | `allowEditing`, `allowDelete` |

4. **Boolean parameters have proper defaults** - `null` = default behavior
5. **Don't pass contextual parameters** - Use behavioral parameters instead

**Examples:**
```sail
/* Good - keyword syntax */
rule!sortData(
  array: local!customers,
  ascending: true,
  field: "name"
)

/* Good - behavioral parameters */
rule!displayCustomerForm(
  customer: local!customer,
  isEditing: local!isEditMode,
  showAdvancedOptions: false,
  allowDelete: local!hasDeletePermission
)

/* Bad - contextual parameter */
rule!displayForm(
  isOnboardingRecord: true  /* ❌ Too contextual */
)

/* Good - behavioral parameters */
rule!displayForm(
  readOnly: false,
  showHeader: true,
  allowSave: true
)
```

### Maintaining State

**Patterns:**
1. **Use local variables of data** - State based on data presence
2. **Use boolean for two states** - `isEditing` for edit vs view
3. **Use text/integer for 3+ states** - `selectedActionId` for multiple options
4. **Use `triggerRefresh` paradigm** - Easy state reset

**Example:**
```sail
a!localVariables(
  /* State based on data */
  local!selectedItem: a!refreshVariable(
    value: null,
    refreshOnVarChange: local!triggerRefresh
  ),
  
  /* Boolean for two states */
  local!isEditing: false,
  
  /* Text for multiple states */
  local!currentView: "list",  /* "list", "detail", "edit" */
  
  /* Display based on state */
  if(
    not(isnull(local!selectedItem)),
    rule!displayItemDetails(...),
    rule!displayItemList(...)
  )
)
```

### Local Variables

**Rules:**
1. **Strongly-typed when possible** - Always specify type, even when null
2. **Initialize as null with type** - Use proper initialization
3. **Boolean variables are true/false** - Never null
4. **Don't duplicate concepts** - Use `selectedTasks.taskId` not separate `selectedTaskIds`

**Examples:**
```sail
a!localVariables(
  /* Strongly typed */
  local!selectedCustomer: cast('type!Customer', null),
  
  /* Boolean - never null */
  local!isActive: true,
  local!showDetails: false,
  
  /* Don't duplicate */
  local!selectedTasks: {},  /* ✅ Use this */
  /* local!selectedTaskIds: {},  ❌ Don't create this */
  
  /* Access IDs via dot notation */
  local!taskIds: local!selectedTasks.taskId
)
```

### Indexing into Objects

**Best Practice:**
- **Use dot-notation or bracket-notation** - Not `index()` function
- Ensures intentional errors if indexing incorrectly
- Creates strong-tie for saving functionality

**Examples:**
```sail
/* Good - dot notation */
local!customer.firstName
local!tasks.taskId

/* Good - bracket notation */
local!customer["firstName"]

/* Bad - index() function */
index(local!customer, "firstName", null)  /* ❌ Can return false negative */
```

---

## Data Types (CDTs)

### CDT Naming

**Conventions:**
1. **Prefix with namespace** - `APP_`
2. **Use sub-prefix by purpose:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| (none) | Runtime/transactional | `APP_Task` |
| `R_` | Reference data | `APP_R_Locale` |
| `T_` | Template data | `APP_T_Template` |
| `A_` | Audit tables | `APP_A_Task` |
| `V_` | Views | `APP_V_Account` |
| `CONF_` | Configuration data | `APP_CONF_Settings` |
| `UNMAPPED_` | Not mapped to database | `APP_UNMAPPED_TempData` |

3. **Use singular names** - `Request` not `Requests`
4. **Child CDTs append to parent** - `Task_Precedent` for child of `Task`

**Examples:**
```
APP_Customer                /* Runtime table */
APP_R_Country              /* Reference data */
APP_V_CustomerSummary      /* View */
APP_Task_Attachment        /* Child of Task */
```

### Field Naming

**Conventions:**
1. **Primary keys:** `<cdtName>Id` - e.g., `customerId`
2. **Foreign keys:** Same name as related primary key
3. **Auditing fields:** `<action>By` and `<action>Datetime`
4. **Primitive field suffixes:**
   - `Id` for integer identifiers - `ruleId`
   - `Code` for varchar identifiers - `statusCode`
   - `Name` for names - `customerName`
   - `Desc` for descriptions - `taskDesc`
5. **Boolean fields:** Prefix with `is` - `isActive`
6. **Nested CDTs:** camelCase without prefixes
   - Single: `taskPrecedent`
   - Array: `taskPrecedents`

**Example CDT:**
```
APP_Task
├── taskId (PK)
├── taskName
├── taskDesc
├── statusCode (FK)
├── isActive
├── createdBy
├── createdDatetime
├── modifiedBy
├── modifiedDatetime
└── taskAttachments (nested array)
```

### Nesting CDTs

**Rules:**
1. **Child only used in parent context:** Nest with `Cascade=ALL`
2. **Reference data fields:** Nest with `Cascade=REFRESH`
3. **Query child by parent:** Nest parent in child with `Cascade=REFRESH`
4. **Avoid >2 levels of One-to-Many nesting**

**Example:**
```
APP_Task
├── taskCategoryRef (Cascade=REFRESH, reference data)
└── taskAttachments (Cascade=ALL, child only used here)
```

### Views

**When to Use:**
1. **Prefer CDT nesting over views** - Most use cases covered by nesting
2. **Prefer query aggregation over views** - Aggregation in queries when possible
3. **No application logic in views:**
   - Don't cast datetimes to dates (do in SAIL)
   - Don't concatenate fields (do in SAIL)
   - Don't apply WHERE conditions (use query filters)
   - Don't use codes in JOINs (do logic in SAIL)

### Database Mapping

**Standards:**
1. **Custom table/column names** - Modify in XSD
2. **Uppercase table names** - Match CDT name, max 30 characters
3. **Uppercase column names** - Match field name, max 30 characters
4. **No length on VARCHAR** - Let database default to 255

**Example:**
```
CDT: APP_Customer
Table: APP_CUSTOMER
Columns: CUSTOMER_ID, CUSTOMER_NAME, EMAIL_ADDRESS
```

---

## Record Types

### Naming

**Conventions:**
1. **Create record for every CDT with actions**
2. **Name:** `<CDT>_RecordType`
3. **One record per table/concept**

**Examples:**
```
APP_Customer → APP_Customer_RecordType
APP_Task → APP_Task_RecordType
```

### Relationships

**Best Practices:**
1. **Add UNIQUE constraint for 1:1 relationships** - In database
2. **Name relationships same as nested CDT fields** - Enables casting
3. **Add all relationships** - No downside, helps with queries
4. **Relationships are one-way** - Child can reference parent

### Security

**Configuration:**
1. **Administrators:** Appian Administrators group
2. **Viewers:** Business Users group + Security Groups group
3. **Record-level security:** Configure row-level access rules

### Record Actions

**Types:**
1. **Record List Actions** - No identifier needed (Create)
2. **Related Actions** - Require identifier (Edit, Delete)

**Best Practices:**
- Don't hardcode IDs in list actions
- Optimize visibility for performance (evaluated on page load)
- Use record relationships in visibility when possible

---

## Constants

### Naming

**Conventions:**
1. **Prefix with namespace** - `APP_`
2. **Use sub-prefix by type:**

| Prefix | Type | Example |
|--------|---------|---------|
| `BOL_` | Boolean | `APP_BOL_ENABLE_FEATURE` |
| `CS_` | Connected System | `APP_CS_EXTERNAL_API` |
| `DEC_` | Decimal | `APP_DEC_TAX_RATE` |
| `DOC_` | Document | `APP_DOC_TEMPLATE` |
| `ENT_` | Data Store Entity | `APP_ENT_CUSTOMER` |
| `ENUM_` | Enumeration | `APP_ENUM_STATUS_ACTIVE` |
| `FLD_` | Folder | `APP_FLD_UPLOADS` |
| `GRP_` | Group | `APP_GRP_APPROVERS` |
| `INT_` | Integer | `APP_INT_PAGE_SIZE` |
| `PM_` | Process Model | `APP_PM_CREATE_ORDER` |
| `RT_` | Record Type | `APP_RT_CUSTOMER` |
| `REF_TYPE_` | Reference type | `APP_REF_TYPE_STATUS` |
| `REF_CODE_` | Reference code | `APP_REF_CODE_STATUS_ACTIVE` |
| `TXT_` | Text | `APP_TXT_DEFAULT_LOCALE` |

### Appropriate Use

**When to Use Constants:**
1. **Traceability** - Need to find all usages via dependency checker
2. **Consistency** - Used in 2+ places
3. **Configurability** - Potentially configurable values
4. **Reference types/codes** - Easy identification of usage

**When NOT to Use:**
1. **Internationalized text** - Use bundle files instead
2. **Arrays** - Use expression rules for constant lists

**Example:**
```sail
/* Good - single values */
APP_INT_DEFAULT_PAGE_SIZE: 20
APP_REF_TYPE_STATUS: "taskStatus"
APP_REF_CODE_STATUS_ACTIVE: "active"

/* Bad - array */
APP_ARRAY_STATUS_CODES: {"active", "pending", "closed"}  /* ❌ */

/* Good - expression rule for lists */
rule!APP_CONS_STATUS_CODES() → {"active", "pending", "closed"}  /* ✅ */
```

---

## Expression Rules

### Naming

**Conventions:**
1. **Prefix with namespace** - `APP_`
2. **Use sub-prefix by purpose:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `BL_` | Business Logic | `APP_BL_calculateDiscount` |
| `CDT_` | CDT Constructors | `APP_CDT_createCustomer` |
| `REC_` | Record Constructors | `APP_REC_createCustomer` |
| `CONS_` | Constant Lists | `APP_CONS_STATUS_CODES` |
| `QE_` | Query Entity | `APP_QE_getCustomer` |
| `QR_` | Query Record | `APP_QR_getCustomer` |
| `UI_` | UI Components | `APP_UI_displayStatusIcon` |
| `VD_` | Validations | `APP_VD_validateEmail` |

3. **Be descriptive** - Purpose should be clear from name

### Return Types

**Best Practice:**
- **Wrap in cast()** - Ensure consistent return type
- Returns same type regardless of inputs
- Consistent with Appian functions

**Example:**
```sail
cast(
  'type!Text',
  if(
    isnull(ri!value),
    "N/A",
    tostring(ri!value)
  )
)
```

### Test Cases

**Requirements:**
1. **Cover all functional outcomes**
2. **Include null input test** - Ensure proper null handling
3. **Use assertion types:**
   - "Assertion evaluates to true"
   - "Test Output matches asserted output"
4. **Avoid hard-coded internationalization**
5. **Avoid environment-specific data** - Construct CDTs in expression

**Example Test Cases:**
```
Test_validateEmail_ValidEmail → true
Test_validateEmail_InvalidEmail → false
Test_validateEmail_NullInput → false
Test_validateEmail_EmptyString → false
```

### Queries

**Best Practices:**
1. **One query rule per entity** - With optional filters
2. **Name format:** `QE_get<Object>` or `QR_get<Object>`
3. **Pass filters as parameters** - `ignoreFiltersWithEmptyValues: true`
4. **Apply default filters for isActive/isDeleted**

**Example:**
```sail
rule!APP_QE_getCustomers(
  customerIds: ri!customerIds,
  statusCodes: ri!statusCodes,
  isActive: ri!isActive,
  returnType: "datasubset"
)
```

### Constant Lists

**Purpose:**
- Logical groupings of constants
- All codes for a reference type
- Status groups (ACTIVE_STATUSES, CLOSED_STATUSES)

**Example:**
```sail
rule!APP_CONS_ACTIVE_STATUS_CODES() → {
  cons!APP_REF_CODE_STATUS_ACTIVE,
  cons!APP_REF_CODE_STATUS_PENDING,
  cons!APP_REF_CODE_STATUS_IN_PROGRESS
}
```

---

## Interfaces

### Naming

**Conventions:**
1. **Prefix with namespace** - `APP_`
2. **Use sub-prefix by component type:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `CPS_` | Various components | `APP_CPS_manageCustomers` |
| `FM_` | Form layout | `APP_FM_editCustomer` |
| `SCT_` | Section layout | `APP_SCT_customerDetails` |
| `COL_` | Column layout | `APP_COL_taskHeader` |
| `CRD_` | Card layout | `APP_CRD_customerCard` |
| `BOX_` | Box layout | `APP_BOX_summary` |
| `INP_` | Input field | `APP_INP_emailField` |
| `DSP_` | Display field | `APP_DSP_statusBadge` |
| `BTN_` | Buttons | `APP_BTN_actionButtons` |
| `LNK_` | Links | `APP_LNK_navigationLinks` |
| `GRD_` | Grid | `APP_GRD_customersGrid` |
| `CHT_` | Chart | `APP_CHT_salesChart` |

3. **Use common prefix for related interfaces** - Easy identification

**Example:**
```
APP_SCT_ManageCustomers
├── APP_CPS_ManageCustomersFilters
├── APP_GRD_ManageCustomersGrid
└── APP_BTN_ManageCustomersActions
```

### Default Inputs

**Requirements:**
1. **Save default inputs** - Behavior visible at a glance
2. **Avoid environment-specific data** - Construct CDTs in expression
3. **Load bundles and ref data** - Display correctly in all environments

### Logic

**Best Practices:**
1. **Minimize logic in forms** - Keep clean and readable
2. **Compartmentalize complex logic** - Use rules even if not reused

---

## Process Models

### Naming

**Conventions:**
1. **Process name:** `APP <descriptive name> <SF if start form>`
2. **Subprocess labels:** Match process name
3. **Instance naming:** Use display name rule

**Examples:**
```
APP Create Customer SF
APP Update Customer Folders
```

### Security

**Critical Rules:**
1. **Entry points:** Specific security group per process
2. **Backend processes:** All Security Groups group
3. **Lane assignment:** Process initiator

**Example:**
```
Entry Point: APP Create Customer PM
Security Group: APP Create Customer PM Access
Members: Contracting Manager, Requestor
```

### Configuration

**Standards:**
1. **Alerts:** Process alerts group
2. **Archiving:**
   - Major processes: Archive after 3 days
   - Utility processes: Delete after 1 day
3. **User tasks:** Quick tasks with exception timeout
4. **Document upload:** Delete on cancel

---

## Reference Data

### Structure

**Tables:**
1. **Shared reference table** - Cross-application data
2. **Application-specific table** - App-only data
3. **Same structure** - Changes reflected across both

### Naming

**Conventions:**
1. **Unique codes** - Within table and ideally across tables
2. **Unique types** - Across all tables
3. **Explicit and readable** - `type = "taskStatuses"`, `code = "status_active"`

### Querying

**Pattern:**
1. **Internal queries** - One per table
2. **Combined query** - Calls both internal queries
3. **Load at top level** - Pass as `ri!refData`
4. **Filter before display** - Handle deactivated entries

**Example:**
```sail
rule!APP_QE_getRefDataByType(
  type: "taskStatuses",
  isActive: {true}
)
```

---

## Internationalization

### General Principles

**Requirements:**
1. **All display text internationalized** - Labels, validations, captions, etc.
2. **Load at top level** - Pass as `i18nData`
3. **Display using utility rule** - With argument support

### Bundle Files

**Organization:**
1. **Separate by functional area** - One bundle per feature
2. **Common bundle** - Shared terms and words

### Label Key Naming

**Prefixes:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `acs_` | Accessibility text | `acs_PressSpaceToSelect` |
| `btn_` | Button label | `btn_Cancel` |
| `cpt_` | Caption | `cpt_RemoveItem` |
| `hlp_` | Help tooltip | `hlp_SelectMultiple` |
| `ins_` | Instructions | `ins_ClickToEdit` |
| `lbl_` | Label | `lbl_CustomerName` |
| `plc_` | Placeholder | `plc_EnterEmail` |
| `txt_` | General text | `txt_NoItemsFound` |
| `vld_` | Validation | `vld_EmailRequired` |

**Best Practices:**
1. **Pascal case** - `lbl_CustomerName`
2. **Separate label per instance** - Don't concatenate in SAIL
3. **Use arguments for dynamic text** - `[%1]`, `[%2]`

**Example:**
```sail
/* Load bundles */
local!i18nData: rule!APP_loadBundleByNames({"CustomerManagement", "General"}),

/* Display label */
rule!APP_displayLabel(
  i18nData: local!i18nData,
  key: "lbl_CustomerName"
)

/* With arguments */
rule!APP_displayLabel(
  i18nData: local!i18nData,
  key: "txt_ItemsSelected",  /* "You have selected [%1] items" */
  arguments: {length(local!selectedItems)}
)
```

---

## Database Design

### Maintainability

**Best Practices:**
1. **Reduce views** - Calculate in process when possible
2. **Update original scripts** - Unless interferes with hotfixes
3. **Include comments** - For tables and columns
4. **Avoid triggers** - When possible
5. **Keep logic-free** - Logic belongs in SAIL

### Scalability

**Considerations:**
1. **Avoid calculated columns in views** - Depending on complexity
2. **Data archival framework** - For rapidly growing tables
3. **Add indexes** - High cardinality columns frequently queried

### Auditing

**Standards:**
1. **Auto-increment for large ref tables** - Over 10k/100k rows
2. **Specify IDs for ref data** - When inserting
3. **Add comments** - On creation
4. **Add indexes** - High cardinality, heavily queried columns
5. **Specify AFTER** - When adding columns

---

## Quick Reference: Common Patterns

### Null-Safe Operations

```sail
/* Safe indexing */
if(
  isnull(local!customer),
  "N/A",
  local!customer.name
)

/* Safe array access */
if(
  a!isNullOrEmpty(local!items),
  {},
  local!items.id
)

/* Default value */
a!defaultValue(local!input, "Default")
```

### State Management

```sail
a!localVariables(
  /* Trigger refresh pattern */
  local!triggerRefresh: 0,
  
  local!data: a!refreshVariable(
    value: rule!loadData(),
    refreshOnVarChange: local!triggerRefresh
  ),
  
  /* Reset state */
  a!buttonWidget(
    label: "Reset",
    saveInto: a!save(
      local!triggerRefresh,
      local!triggerRefresh + 1
    )
  )
)
```

### Query with Filters

```sail
rule!APP_QE_getCustomers(
  customerIds: local!selectedIds,
  statusCodes: if(
    local!showActiveOnly,
    rule!APP_CONS_ACTIVE_STATUS_CODES(),
    null
  ),
  isActive: {true},
  returnType: "datasubset"
)
```

### Validation Pattern

```sail
a!textField(
  label: "Email Address",
  value: local!email,
  saveInto: local!email,
  validations: {
    if(
      and(
        not(isnull(local!email)),
        not(rule!APP_VD_isValidEmail(local!email))
      ),
      "Please enter a valid email address",
      null
    )
  }
)
```

### Grid with Actions

```sail
a!gridField(
  label: "Customers",
  data: local!customers,
  columns: {
    a!gridColumn(
      label: "Name",
      value: fv!row.name
    ),
    a!gridColumn(
      label: "Actions",
      value: a!buttonArrayLayout(
        buttons: {
          a!buttonWidget(
            label: "Edit",
            accessibilityText: "Edit " & fv!row.name,
            size: "SMALL",
            saveInto: a!save(local!selectedCustomer, fv!row)
          ),
          a!buttonWidget(
            label: "Delete",
            accessibilityText: "Delete " & fv!row.name,
            size: "SMALL",
            style: "DESTRUCTIVE",
            saveInto: {
              a!save(local!customers, remove(local!customers, fv!index))
            }
          )
        },
        align: "START"
      )
    )
  },
  rowHeader: 1
)
```

---

## Design Checklist

Before releasing code:

**SAIL Code:**
- [ ] All code formatted (Ctrl+Shift+F)
- [ ] Comments added where needed
- [ ] Local variables properly typed
- [ ] No duplicate logic (use local variables)
- [ ] Proper null handling
- [ ] Saves within {}

**Naming:**
- [ ] Consistent naming conventions
- [ ] Descriptive names
- [ ] Proper prefixes used
- [ ] Affirmative boolean names

**Reusability:**
- [ ] Checked for existing rules
- [ ] Proper scope (not too broad/narrow)
- [ ] Appropriate parameters
- [ ] Not over-parameterized

**Testing:**
- [ ] Test cases for all expression rules
- [ ] Null input tests
- [ ] No environment-specific data
- [ ] Default inputs saved for interfaces

**Data:**
- [ ] CDT naming conventions
- [ ] Proper nesting with cascade settings
- [ ] Database comments added
- [ ] Indexes on queried columns

**Internationalization:**
- [ ] All display text in bundles
- [ ] Proper label key naming
- [ ] Arguments for dynamic text

**Performance:**
- [ ] Queries optimized
- [ ] Proper indexing
- [ ] Minimal view usage
- [ ] Efficient data loading

---

## Additional Resources

- **Appian Documentation**: https://docs.appian.com
- **Appian Community**: https://community.appian.com
- **Appian Playbook**: https://community.appian.com/w/the-appian-playbook
