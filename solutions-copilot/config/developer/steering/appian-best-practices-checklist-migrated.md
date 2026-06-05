# Appian SOLUTIONS Design Best Practices Checklist

Use this checklist during code review. Not every item applies to every object — focus on what's relevant to the object type being reviewed.

## Quick Reference: Checklist by Object Type

**For Interfaces (FM, CPS, SCT, GRD, etc.):** Focus on sections 1, 6, 9  
**For Expression Rules (BL, QE, QR, UT etc.):** Focus on sections 1, 5  
**For Process Models (PM):** Focus on sections 1, 7  
**For Constants:** Focus on section 4  
**For Record Types:** Focus on section 3  
**For CDTs/Data Types:** Focus on section 2  

---

## 1. General SAIL Principles

### A. Latest Features and CO Rules

**Purpose:** As a Solution, our applications should showcase and utilize the most up-to-date Appian features and functionality. CO (Common Objects) rules enhance the Appian product with consistent functionality and UX.

**Checklist Items:**

- [ ] **Uses most up-to-date Appian features**
  - Move to the latest version of Appian as soon as possible after the product is stable
  - Leverage new functions and components introduced in recent versions
  - Example: Use `a!forEach()` instead of deprecated looping patterns

- [ ] **Old version of functions not used**
  - Avoid version-specific function calls like `a!gridField_24r3()`
  - Use the current version without version suffix: `a!gridField()`
  - These versioned functions indicate legacy code that should be updated
  - **AUTOMATED CHECK AVAILABLE** ✓

- [ ] **Uses CO (Common Objects) rules whenever possible**
  - CO rules provide consistent functionality and UX across the application
  - Examples: `AS_CO_UT_queryEntity()`, `AS_CO_UT_processDisplayName()`, `AS_CO_I18N_UT_displayLabel()`
  - Check if a CO rule exists before creating custom logic
  - Reuse CO components for common UI patterns
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect CO rule usage patterns)

- [ ] **CO rules are not modified after deployment**
  - Once a CO rule is created and deployed, changes should be limited
  - CO rules are shared across multiple applications
  - Modifications can have unintended side effects on other consumers
  - If changes are needed, consider creating a new version or application-specific variant

### B. Commenting

**Purpose:** Comments help future developers (including customers) understand potentially confusing code. Good commenting is essential for Solutions that will be handed off to multiple development teams.

**Checklist Items:**

- [ ] **Comments exist for potentially confusing code**
  - Add comments wherever logic is not immediately obvious
  - Explain the "why" behind complex decisions, not just the "what"
  - Example: `/* Calculate prorated amount based on partial month usage */`
  - Don't comment obvious code like `/* Set variable to true */`

- [ ] **Comments are on separate lines above the code**
  - Place comments on their own line, not inline at the end of code
  - **Good:**
    ```
    /* Filter out inactive vendors before displaying */
    local!activeVendors: a!queryEntity(...)
    ```
  - **Bad:**
    ```
    local!activeVendors: a!queryEntity(...) /* Filter out inactive vendors */
    ```

- [ ] **Comments above any local variable whose purpose isn't obvious**
  - If a variable name doesn't fully explain its purpose, add a comment
  - Example:
    ```
    /* Tracks whether user has made any changes to trigger save validation */
    local!isDirty: false
    ```
  - Variables with clear names may not need comments:
    ```
    local!selectedVendorId: null /* No comment needed - name is self-explanatory */
    ```

- [ ] **TOBEDONE (no spaces) used to mark things needing attention before release**
  - Use the exact phrase `TOBEDONE` (no spaces) for searchability
  - Include description of what needs to be done
  - Example: `/* TOBEDONE: Replace hardcoded group with constant after security groups are created */`
  - Search for `TOBEDONE` before releasing to ensure nothing is missed
  - **AUTOMATED CHECK AVAILABLE** ✓ (can scan for TOBEDONE markers)

### C. Code Reusability

**Purpose:** Reusable code reduces duplication, improves maintainability, and ensures consistency across the application. Solutions should be designed for easy customization by customer teams.

**Checklist Items:**

- [ ] **Objects are reused whenever possible**
  - Before creating new logic, check if similar functionality already exists
  - Reuse existing interfaces, expression rules, and components
  - Example: Use existing `AS_GAM_FM_VendorPicker` instead of creating a new vendor selection interface

- [ ] **Parameters passed to reusable objects to alter behavior**
  - Make objects flexible by accepting parameters that control behavior
  - Example: Pass `showInactive: true/false` to control whether inactive records are displayed
  - This allows one object to serve multiple use cases
  - **Good:**
    ```
    rule!AS_GAM_QE_getVendors(
      showInactive: false,
      filterByCategory: "Technology"
    )
    ```

- [ ] **Not over-parameterized (no more than ~5 behavioral parameters per object)**
  - Too many parameters make objects difficult to use and maintain
  - If an object needs more than ~5 behavioral parameters, consider creating a new specialized object
  - **Warning sign:** Object has 8+ boolean parameters controlling different behaviors
  - **Better approach:** Create `AS_GAM_FM_ActiveVendorGrid` and `AS_GAM_FM_AllVendorGrid` instead of one grid with many toggles

- [ ] **Object scope reduced to create reusability**
  - Break down large objects into smaller, focused components
  - Smaller scope = easier to reuse in different contexts
  - Example: Instead of one large `AS_GAM_FM_VendorManagement` form, create:
    - `AS_GAM_SCT_VendorDetails` (section for vendor info)
    - `AS_GAM_SCT_VendorContacts` (section for contacts)
    - `AS_GAM_GRD_VendorDocuments` (grid for documents)

- [ ] **Local variables used to avoid duplicating logic**
  - Calculate values once and store in local variables
  - **Bad (duplicated logic):**
    ```
    if(
      and(
        not(isnull(ri!vendor)),
        ri!vendor.status = "Active",
        ri!vendor.approvalDate < today()
      ),
      "Approved",
      if(
        and(
          not(isnull(ri!vendor)),
          ri!vendor.status = "Active",
          ri!vendor.approvalDate < today()
        ),
        "Show Details",
        "Pending"
      )
    )
    ```
  - **Good (using local variable):**
    ```
    local!isApproved: and(
      not(isnull(ri!vendor)),
      ri!vendor.status = "Active",
      ri!vendor.approvalDate < today()
    ),
    if(local!isApproved, "Approved", if(local!isApproved, "Show Details", "Pending"))
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect duplicate code patterns)

- [ ] **CO namespace used for globally reusable objects**
  - Objects intended for use across multiple applications should use CO namespace
  - Examples: `AS_CO_UT_queryEntity`, `AS_CO_I18N_UT_displayLabel`
  - Application-specific objects use app namespace: `AS_GAM_`, `AS_GSS_`
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify namespace usage patterns)

### D. Formatting

**Purpose:** Consistent formatting improves code readability and makes it easier for customer teams to understand and maintain the code. Appian provides built-in formatting tools that should be used consistently.

**Checklist Items:**

- [ ] **Code formatted for legibility (Appian-standard formatting: Ctrl+Shift+F)**
  - Use Appian's built-in auto-formatter (Ctrl+Shift+F on Windows, Cmd+Shift+F on Mac)
  - This ensures consistent indentation, spacing, and line breaks
  - Apply formatting before saving any object
  - **Before formatting:**
    ```
    a!localVariables(local!data:a!queryEntity(entity:cons!AS_GAM_ENT_VENDOR,query:a!query(pagingInfo:a!pagingInfo(startIndex:1,batchSize:100))),local!count:length(local!data.data),if(local!count>0,local!data.data,{}))
    ```
  - **After formatting (Ctrl+Shift+F):**
    ```
    a!localVariables(
      local!data: a!queryEntity(
        entity: cons!AS_GAM_ENT_VENDOR,
        query: a!query(
          pagingInfo: a!pagingInfo(
            startIndex: 1,
            batchSize: 100
          )
        )
      ),
      local!count: length(local!data.data),
      if(
        local!count > 0,
        local!data.data,
        {}
      )
    )
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect unformatted code patterns)

- [ ] **Full-gap carriage returns where appropriate**
  - Add blank lines between logical sections of code
  - Separate local variable definitions from the main expression body
  - **Good:**
    ```
    a!localVariables(
      /* Data loading */
      local!vendors: rule!AS_GAM_QE_getVendors(),
      local!categories: rule!AS_GAM_QE_getCategories(),
      
      /* State management */
      local!selectedVendorId: null,
      local!showInactive: false,
      
      /* UI Definition */
      a!formLayout(
        label: "Vendor Management",
        contents: {...}
      )
    )
    ```
  - Improves readability by visually grouping related code

- [ ] **Parameters with smaller definitions placed above those with larger definitions**
  - Order parameters from simple to complex
  - This makes it easier to scan the code and find specific parameters
  - **Good:**
    ```
    a!gridField(
      label: "Vendors",
      labelPosition: "ABOVE",
      data: local!vendors,
      columns: {
        a!gridColumn(
          label: "Name",
          value: fv!row.name
        ),
        a!gridColumn(
          label: "Status",
          value: fv!row.status
        )
      },
      rowHeader: 1
    )
    ```
  - **Bad:**
    ```
    a!gridField(
      columns: {
        a!gridColumn(
          label: "Name",
          value: fv!row.name
        ),
        a!gridColumn(
          label: "Status",
          value: fv!row.status
        )
      },
      data: local!vendors,
      rowHeader: 1,
      labelPosition: "ABOVE",
      label: "Vendors"
    )
    ```
  - Simple parameters (label, labelPosition) should come before complex ones (columns)

### E. Object Scope

**Purpose:** Objects should have a clear, focused purpose that aligns with their name, description, inputs, and outputs. Proper scope makes objects easier to understand, test, and reuse.

**Checklist Items:**

- [ ] **Scope of every object matches its purpose, name, and description**
  - The object should do exactly what its name and description say it does
  - **Good:** `AS_GAM_QE_getActiveVendors` returns only active vendors
  - **Bad:** `AS_GAM_QE_getActiveVendors` returns all vendors and also calculates summary statistics
  - If an object's actual behavior doesn't match its name, either rename it or refactor it

- [ ] **Inputs align with scope**
  - Rule inputs should be necessary for the object's stated purpose
  - Don't accept inputs that aren't used or are outside the object's scope
  - **Good:** `AS_GAM_VD_validateVendorEmail` accepts `email` as input
  - **Bad:** `AS_GAM_VD_validateVendorEmail` accepts entire `vendor` CDT when it only needs the email field
  - Pass only what's needed: `rule!AS_GAM_VD_validateVendorEmail(email: ri!vendor.email)`

- [ ] **Output aligns with scope**
  - The object should return exactly what its name and description promise
  - **Good:** `AS_GAM_QE_getVendorCount` returns an integer count
  - **Bad:** `AS_GAM_QE_getVendorCount` returns a dictionary with count, list of vendors, and summary stats
  - If you need multiple outputs, consider whether the scope is too broad

- [ ] **Objects broken down into smaller scope where appropriate**
  - Large objects should be split into smaller, focused components
  - Each component should have a single, clear responsibility
  - **Example - Too broad:**
    - `AS_GAM_FM_VendorManagement` (1000+ lines handling create, edit, delete, search, export)
  - **Better - Focused scope:**
    - `AS_GAM_FM_VendorForm` (create/edit form)
    - `AS_GAM_GRD_VendorSearch` (search and display)
    - `AS_GAM_BL_deleteVendor` (deletion logic)
    - `AS_GAM_BL_exportVendors` (export logic)
  - **AUTOMATED CHECK AVAILABLE** ✓ (can flag objects over certain line count thresholds)

- [ ] **Saves are always within a `{}`**
  - Wrap all `a!save()` operations in curly braces for consistency and safety
  - This prevents issues when adding multiple save operations later
  - **Good:**
    ```
    a!buttonWidget(
      label: "Save",
      saveInto: {
        a!save(local!vendor, save!value)
      }
    )
    ```
  - **Bad:**
    ```
    a!buttonWidget(
      label: "Save",
      saveInto: a!save(local!vendor, save!value)
    )
    ```
  - Even with a single save, use `{}` for consistency
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect saves not wrapped in braces)

### F. Variable & Parameter Naming

**Purpose:** Consistent, descriptive naming makes code self-documenting and easier to understand. Good naming conventions reduce the need for comments and help developers quickly grasp the code's intent.

**Checklist Items:**

- [ ] **Complex variables/parameters named by their type**
  - Use the type name (or abbreviated type) in the variable name
  - This makes it clear what kind of data the variable holds
  - **Good examples:**
    - `local!vendorCdt` or `local!vendor` (for AS_GAM_Vendor CDT)
    - `local!vendorList` or `local!vendors` (for array of vendors)
    - `local!categoryDict` (for dictionary/map)
    - `local!pagingInfo` (for a!pagingInfo)
  - **Bad examples:**
    - `local!data` (too generic - what kind of data?)
    - `local!temp` (what does it contain?)
    - `local!x` (meaningless)

- [ ] **Plural names for array variables**
  - Arrays should always have plural names
  - Singular names indicate a single item
  - **Good:**
    ```
    local!vendors: rule!AS_GAM_QE_getVendors(),  /* Array of vendors */
    local!selectedVendor: local!vendors[1]        /* Single vendor */
    ```
  - **Bad:**
    ```
    local!vendor: rule!AS_GAM_QE_getVendors(),   /* Confusing - sounds like one vendor */
    local!vendors: local!vendor[1]                /* Backwards - plural for single item */
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect array variables with singular names)

- [ ] **Same names for variables and rule inputs**
  - When passing a variable to a rule input, use matching names
  - This creates clear traceability and reduces confusion
  - **Good:**
    ```
    local!vendorId: 123,
    rule!AS_GAM_QE_getVendor(
      vendorId: local!vendorId  /* Names match */
    )
    ```
  - **Bad:**
    ```
    local!id: 123,
    rule!AS_GAM_QE_getVendor(
      vendorId: local!id  /* Names don't match - confusing */
    )
    ```

- [ ] **Same variable name for the same concept across the application**
  - Use consistent naming for the same concept throughout the app
  - **Good (consistent):**
    - `local!selectedVendorId` used everywhere for the selected vendor's ID
    - `local!isActive` used everywhere for active status
  - **Bad (inconsistent):**
    - `local!selectedVendorId` in one interface
    - `local!chosenVendor` in another interface
    - `local!vendorSelection` in a third interface
  - Pick one name and stick with it across all objects

- [ ] **Affirmative naming (e.g., `isExistingCategory` not `isNotNewCategory`)**
  - Use positive/affirmative boolean names
  - Avoid double negatives which are confusing
  - **Good:**
    ```
    local!isActive: true,
    local!isExistingCategory: false,
    local!hasPermission: true
    ```
  - **Bad:**
    ```
    local!isNotActive: false,        /* Double negative: not-not-active = active? */
    local!isNotNewCategory: true,    /* Confusing: not-not-new = old? */
    local!lacksPermission: false     /* Double negative: lacks-not = has? */
    ```
  - If you find yourself writing `not(local!isNotActive)`, your naming is backwards
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect "isNot" or "lacks" patterns in variable names)

### G. Passing Parameters

**Purpose:** Consistent parameter passing makes code more readable and maintainable. Proper parameter design ensures objects are flexible, testable, and easy to use.

**Checklist Items:**

- [ ] **Parameters passed with keyword-syntax**
  - Always use named parameters (keyword syntax) when calling rules
  - Never rely on positional parameters
  - **Good:**
    ```
    rule!AS_GAM_QE_getVendors(
      showInactive: false,
      categoryFilter: "Technology"
    )
    ```
  - **Bad:**
    ```
    rule!AS_GAM_QE_getVendors(
      false,           /* What does false mean? */
      "Technology"     /* What is this filtering? */
    )
    ```
  - Keyword syntax makes code self-documenting
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect positional parameter usage)

- [ ] **Full objects passed into expression rules**
  - Pass complete CDTs/objects rather than individual fields
  - This makes rules more flexible and easier to extend
  - **Good:**
    ```
    rule!AS_GAM_VD_validateVendor(
      vendor: local!vendor  /* Pass entire CDT */
    )
    ```
  - **Bad:**
    ```
    rule!AS_GAM_VD_validateVendor(
      vendorName: local!vendor.name,
      vendorEmail: local!vendor.email,
      vendorPhone: local!vendor.phone,
      vendorAddress: local!vendor.address
      /* If we need another field, we have to add another parameter */
    )
    ```
  - Exception: If the rule truly only needs one field, it's okay to pass just that field

- [ ] **Prefix used for behavioral parameters**
  - Use standard prefixes to indicate parameter purpose:
    - **`is`** - Controls state or condition
    - **`show`** - Controls visibility
    - **`allow`** - Controls access/permissions
  - **Good examples:**
    ```
    rule!AS_GAM_GRD_VendorGrid(
      vendors: local!vendors,
      isReadOnly: true,           /* State: read-only mode */
      showInactive: false,         /* Visibility: hide inactive vendors */
      allowDelete: local!hasPermission  /* Access: can user delete? */
    )
    ```
  - **Bad examples:**
    ```
    rule!AS_GAM_GRD_VendorGrid(
      vendors: local!vendors,
      readOnly: true,              /* Missing 'is' prefix */
      displayInactive: false,      /* Should be 'show' prefix */
      canDelete: local!hasPermission  /* Should be 'allow' prefix */
    )
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect boolean parameters without proper prefixes)

- [ ] **Ensure all boolean parameters have proper default behavior**
  - Boolean parameters should have sensible defaults
  - The default should represent the most common use case
  - **Good:**
    ```
    /* Rule definition */
    rule!AS_GAM_QE_getVendors(
      showInactive: false  /* Default: hide inactive (most common case) */
    )
    
    /* Calling with default */
    rule!AS_GAM_QE_getVendors()  /* Uses default: showInactive = false */
    
    /* Calling with override */
    rule!AS_GAM_QE_getVendors(showInactive: true)
    ```
  - Document the default behavior in the rule input description

- [ ] **Do not pass contextual parameters**
  - Don't pass parameters that can be derived from other parameters
  - Avoid redundant parameters that create maintenance burden
  - **Bad:**
    ```
    rule!AS_GAM_BL_processVendor(
      vendor: local!vendor,
      vendorId: local!vendor.id,        /* Redundant - can get from vendor */
      vendorName: local!vendor.name,    /* Redundant - can get from vendor */
      isNewVendor: isnull(local!vendor.id)  /* Redundant - can derive from vendor.id */
    )
    ```
  - **Good:**
    ```
    rule!AS_GAM_BL_processVendor(
      vendor: local!vendor  /* All other info can be derived from this */
    )
    
    /* Inside the rule: */
    local!vendorId: ri!vendor.id,
    local!isNewVendor: isnull(ri!vendor.id)
    ```

- [ ] **Rule input descriptions provided**
  - Every rule input should have a clear description
  - Describe what the parameter is, what format it expects, and any constraints
  - **Good:**
    ```
    Rule Input: vendorId
    Description: "The unique identifier of the vendor to retrieve. Must be a valid integer greater than 0."
    
    Rule Input: showInactive
    Description: "When true, includes inactive vendors in the results. Defaults to false."
    ```
  - **Bad:**
    ```
    Rule Input: vendorId
    Description: "vendor id"  /* Too vague */
    
    Rule Input: showInactive
    Description: ""  /* No description */
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect rule inputs without descriptions)

### H. Maintaining State

**Purpose:** Proper state management is crucial for interactive interfaces. State should be maintained in a clear, predictable way that makes the interface behavior easy to understand and debug.

**Checklist Items:**

- [ ] **When possible, use local variables of data to maintain state**
  - Store the actual data rather than just IDs or flags when feasible
  - This reduces the need for additional queries and simplifies logic
  - **Good:**
    ```
    local!selectedVendor: null,  /* Store the entire vendor CDT */
    
    /* When user selects a vendor */
    a!save(local!selectedVendor, fv!row)
    
    /* Display selected vendor details */
    local!selectedVendor.name
    ```
  - **Bad:**
    ```
    local!selectedVendorId: null,  /* Only store ID */
    
    /* When user selects a vendor */
    a!save(local!selectedVendorId, fv!row.id),
    
    /* Have to query again to get vendor details */
    local!selectedVendor: rule!AS_GAM_QE_getVendor(
      vendorId: local!selectedVendorId
    ),
    local!selectedVendor.name
    ```
  - Exception: If the data is large or changes frequently, storing just the ID may be more appropriate

- [ ] **Boolean local variables to maintain state between two options**
  - Use boolean variables when there are exactly two states
  - Name them clearly with `is`, `show`, or `allow` prefix
  - **Good examples:**
    ```
    local!isEditMode: false,        /* Edit mode vs view mode */
    local!showInactive: false,      /* Show inactive vs hide inactive */
    local!isExpanded: false         /* Expanded vs collapsed */
    ```
  - **When to use:**
    - Toggle between two views (edit/view, expanded/collapsed)
    - Show/hide sections
    - Enable/disable features

- [ ] **Text or integer local variables to maintain state between three or more options**
  - Use text or integer variables when there are 3+ states
  - Text is more readable; integers are more compact
  - **Good (text):**
    ```
    local!viewMode: "list",  /* Options: "list", "grid", "calendar" */
    
    choose(
      local!viewMode,
      "list", rule!AS_GAM_GRD_VendorList(),
      "grid", rule!AS_GAM_GRD_VendorGrid(),
      "calendar", rule!AS_GAM_CAL_VendorCalendar()
    )
    ```
  - **Good (integer with constants):**
    ```
    local!currentStep: 1,  /* Options: 1, 2, 3, 4 */
    
    choose(
      local!currentStep,
      rule!AS_GAM_FM_Step1_VendorInfo(),
      rule!AS_GAM_FM_Step2_ContactInfo(),
      rule!AS_GAM_FM_Step3_Documents(),
      rule!AS_GAM_FM_Step4_Review()
    )
    ```
  - **Bad (multiple booleans for multi-state):**
    ```
    local!showList: true,
    local!showGrid: false,
    local!showCalendar: false
    /* Confusing - what if multiple are true? What if all are false? */
    ```

- [ ] **triggerRefresh paradigm used for resetting state**
  - Use a refresh variable to easily reset all state to initial values
  - This is cleaner than manually resetting each variable
  - **Good:**
    ```
    a!localVariables(
      local!refreshCounter: 0,
      
      /* All state variables depend on refreshCounter */
      local!vendor: if(
        local!refreshCounter = 0,
        null,
        local!vendor
      ),
      local!selectedCategory: if(
        local!refreshCounter = 0,
        null,
        local!selectedCategory
      ),
      local!isEditMode: if(
        local!refreshCounter = 0,
        false,
        local!isEditMode
      ),
      
      /* Reset button increments counter, triggering refresh */
      a!buttonWidget(
        label: "Reset",
        saveInto: a!save(local!refreshCounter, local!refreshCounter + 1)
      )
    )
    ```
  - **Alternative pattern (boolean trigger):**
    ```
    local!reset: false,
    
    local!vendor: if(local!reset, null, local!vendor),
    local!selectedCategory: if(local!reset, null, local!selectedCategory),
    
    a!buttonWidget(
      label: "Reset",
      saveInto: {
        a!save(local!reset, true),
        a!save(local!reset, false)
      }
    )
    ```
  - This pattern makes it easy to reset the entire form with one action
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect forms with many state variables but no reset mechanism)

### I. Local Variables

**Purpose:** Proper local variable initialization and typing prevents runtime errors and makes code behavior predictable. Strong typing helps catch errors early and improves code maintainability.

**Checklist Items:**

- [ ] **Objects are strongly-typed when possible**
  - Use type constructors to initialize variables with their proper type
  - This prevents type mismatch errors and makes the code's intent clear
  - **Good:**
    ```
    local!vendor: type!AS_GAM_Vendor(null),  /* Strongly typed as AS_GAM_Vendor CDT */
    local!vendors: cast(type!AS_GAM_Vendor, {}),  /* Strongly typed empty array */
    local!pagingInfo: a!pagingInfo(startIndex: 1, batchSize: 10)  /* Typed by constructor */
    ```
  - **Bad:**
    ```
    local!vendor: null,      /* Untyped - could be anything */
    local!vendors: {},       /* Untyped array */
    local!pagingInfo: null   /* Untyped - what structure does this have? */
    ```
  - Strong typing helps Appian provide better autocomplete and error detection
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect untyped CDT variables initialized as null)

- [ ] **Local variables initialized as null with their type**
  - When a variable will be populated later, initialize it as null with its type
  - This establishes the variable's type from the start
  - **Good:**
    ```
    local!selectedVendor: type!AS_GAM_Vendor(null),
    local!categoryList: cast(type!AS_GAM_Category, null),
    local!documentId: tointeger(null)
    ```
  - **Bad:**
    ```
    local!selectedVendor: null,  /* What type is this? */
    local!categoryList: null,
    local!documentId: null
    ```
  - Exception: Simple types (text, integer) where the type is obvious from usage may not need explicit typing

- [ ] **Boolean local variables initialized as true or false**
  - Never initialize boolean variables as null
  - Always use explicit true or false values
  - **Good:**
    ```
    local!isEditMode: false,
    local!showInactive: false,
    local!hasPermission: true
    ```
  - **Bad:**
    ```
    local!isEditMode: null,      /* Null is not a boolean value */
    local!showInactive: null,
    local!hasPermission: null
    ```
  - Null booleans cause confusing behavior in if() statements
  - **Why this matters:**
    ```
    /* With null boolean */
    local!isEditMode: null,
    if(local!isEditMode, "Edit", "View")  /* Returns "View" - is that correct? */
    
    /* With explicit false */
    local!isEditMode: false,
    if(local!isEditMode, "Edit", "View")  /* Returns "View" - clearly correct */
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect boolean variables initialized as null)

- [ ] **No duplicate concepts in multiple local variables**
  - Don't store the same information in multiple variables
  - This creates maintenance burden and potential inconsistencies
  - **Bad:**
    ```
    local!selectedVendorId: 123,
    local!selectedVendor: rule!AS_GAM_QE_getVendor(vendorId: 123),
    local!selectedVendorName: local!selectedVendor.name,
    local!selectedVendorStatus: local!selectedVendor.status
    /* Why store the ID separately when it's in the vendor CDT? */
    /* Why store name and status separately when they're in the vendor CDT? */
    ```
  - **Good:**
    ```
    local!selectedVendor: rule!AS_GAM_QE_getVendor(vendorId: 123),
    /* Access fields directly: local!selectedVendor.id, .name, .status */
    ```
  - **Exception:** It's okay to extract frequently-used nested values for readability:
    ```
    local!vendor: rule!AS_GAM_QE_getVendor(vendorId: 123),
    local!primaryContact: local!vendor.contacts[1],  /* OK - simplifies repeated access */
    local!primaryContactEmail: local!primaryContact.email  /* OK if used many times */
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect variables that duplicate data from other variables)

### J. Indexing into Objects

**Purpose:** Proper indexing syntax makes code more readable and maintainable. Using dot-notation and bracket-notation appropriately helps prevent errors and makes field access clear.

**Checklist Items:**

- [ ] **Dot-notation or bracket-notation used for CDT/complex object fields**
  - Use dot-notation (`.`) for accessing CDT fields and dictionary keys
  - Use bracket-notation (`[]`) for accessing array indices
  - **Good (dot-notation for CDT fields):**
    ```
    local!vendor: rule!AS_GAM_QE_getVendor(vendorId: 123),
    local!vendorName: local!vendor.name,
    local!vendorEmail: local!vendor.email,
    local!primaryContact: local!vendor.contacts[1].name
    ```
  - **Bad (using index() function):**
    ```
    local!vendor: rule!AS_GAM_QE_getVendor(vendorId: 123),
    local!vendorName: index(local!vendor, "name", null),
    local!vendorEmail: index(local!vendor, "email", null)
    /* index() is verbose and error-prone */
    ```
  - **Good (bracket-notation for arrays):**
    ```
    local!vendors: rule!AS_GAM_QE_getVendors(),
    local!firstVendor: local!vendors[1],
    local!lastVendor: local!vendors[length(local!vendors)]
    ```
  - **Good (bracket-notation for dynamic field access):**
    ```
    local!fieldName: "name",
    local!value: local!vendor[local!fieldName]  /* Dynamic field access */
    ```
  - **When to use each:**
    - **Dot-notation:** Static field names known at design time
    - **Bracket-notation:** Array indices or dynamic field names
    - **index():** Only when you need the default value parameter for null safety
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect unnecessary property() usage where dot-notation would work)

### K. Appian Design Guidance

**Purpose:** Appian's built-in Design Guidance tool identifies potential issues with performance, maintainability, and best practices. Reviewing and addressing these items ensures high-quality code.

**Checklist Items:**

- [ ] **Navigate to the Monitor tab of your application package**
  - Open the application package in Appian Designer
  - Click the "Monitor" tab at the top
  - This shows the Design Guidance grid

- [ ] **Review the Appian Design Guidance grid**
  - The grid lists all objects with design guidance items
  - Each item shows:
    - Object name and type
    - Guidance category (Performance, Maintainability, etc.)
    - Severity (High, Medium, Low)
    - Description of the issue
  - Sort by severity to prioritize high-impact items

- [ ] **For any objects in the grid, make the decision to update the object to address the guidance, or dismiss the guidance**
  - **Option 1: Fix the issue**
    - Update the object to address the guidance
    - Re-save the object
    - Verify the guidance item disappears
  - **Option 2: Dismiss with reason**
    - If the guidance doesn't apply or can't be fixed, dismiss it
    - Provide a clear reason for dismissal
    - Example reasons:
      - "Performance acceptable for expected data volume"
      - "Legacy pattern required for backward compatibility"
      - "False positive - code is correct as-is"
  - **Never ignore guidance items** - either fix or explicitly dismiss
  - Common guidance items:
    - Queries without executeWhen
    - Deep nesting (>6 levels)
    - Large number of local variables (>30)
    - Synchronous process calls
    - Missing null safety
  - **AUTOMATED CHECK AVAILABLE** ✓ (can retrieve and report design guidance items via API)

---

## 2. Data Types

### A. CDT Naming
- [ ] Application namespace appended to default namespace (e.g., `urn:com:appian:types:ASFS`)
- [ ] CDTs prefixed with application namespace (e.g., `AS_IO_`)
- [ ] Sub-prefix based on purpose:
  - [ ] (runtime) - No prefix for transactional tables
  - [ ] R - Reference data tables
  - [ ] T - Template tables (copied to runtime)
  - [ ] A - Auditing tables
  - [ ] V - Views
  - [ ] CONF - Configuration CDTs
  - [ ] UNMAPPED - Not mapped to database
- [ ] Singular CDT names
- [ ] Views use same singular name as primary table
- [ ] Child CDTs append child name to parent CDT name

### B. Field Naming
- [ ] Primary keys: `<cdtName>Id`
- [ ] Foreign keys: same name as related CDT's primary key
- [ ] Auditing fields: `<action>By` and `<action>Datetime`
- [ ] Boolean fields prefixed with `is`
- [ ] Nested non-array CDTs: camelcase name without prefixes
- [ ] Nested array CDTs: plural name

### C. Nesting CDTs
- [ ] Child only used within parent context: nest with Cascade=ALL
- [ ] Reference data fields: nest with Cascade=REFRESH
- [ ] Query child by parent: nest parent inside child with Cascade=REFRESH

### D. Views
- [ ] CDT nesting used instead of views when possible
- [ ] Query aggregation used instead of views when possible
- [ ] No application logic in underlying SQL for views

---

## 3. Record Types

**Purpose:** Record Types are the modern way to work with data in Appian. They provide a data-centric approach with built-in relationships, security, and actions. Proper record configuration is essential for building maintainable, scalable applications.

### A. Setup

**Purpose:** Proper record setup ensures data is accessible and manageable throughout the application.

**Checklist Items:**

- [ ] **Record created for every CDT with actions**
  - If users will perform actions on data (create, update, delete, view), create a record
  - Records provide a consistent interface for data operations
  - **Example:** If you have `AS_GAM_Vendor` CDT with vendor management actions, create `AS_GAM_Vendor_RecordType`

- [ ] **Named with `_RecordType` appended**
  - Consistent naming makes records easy to identify
  - **Good:** `AS_GAM_Vendor_RecordType`, `AS_GSS_Contract_RecordType`
  - **Bad:** `AS_GAM_VendorRecord`, `AS_GAM_Vendor_RT`, `VendorRecordType`
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify record naming convention)

- [ ] **Limit one record per database table or per concept**
  - Don't create multiple records for the same underlying data
  - Each business concept should have one primary record
  - **Good:** One `AS_GAM_Vendor_RecordType` for the vendor table
  - **Bad:** `AS_GAM_ActiveVendor_RecordType` and `AS_GAM_InactiveVendor_RecordType` for the same table
  - Use record views or filters instead of creating separate records

### B. Data Model/Relationships

**Purpose:** Relationships between records mirror real-world data connections and enable powerful querying and navigation capabilities.

**Checklist Items:**

- [ ] **Relationships set up between all related records**
  - Define relationships for all foreign key connections
  - This enables record navigation and related record queries
  - **Example relationships:**
    - Vendor → Contracts (one-to-many)
    - Contract → Vendor (many-to-one)
    - Contract → Documents (one-to-many)
  - Relationships should be bidirectional when appropriate

- [ ] **Relationship names are concise and accurate**
  - Use clear, business-friendly names
  - **Good:** `contracts`, `vendor`, `primaryContact`, `documents`
  - **Bad:** `relatedContracts`, `vendorRelationship`, `fk_vendor_id`
  - The name should describe what you're getting, not the technical relationship

- [ ] **Relationship names match nested CDT field names (if parallel)**
  - If you have both CDT nesting and record relationships, use the same names
  - This creates consistency between data access patterns
  - **Example:**
    ```
    /* CDT structure */
    AS_GAM_Contract CDT has field: vendor (nested AS_GAM_Vendor)
    
    /* Record relationship */
    AS_GAM_Contract_RecordType has relationship: vendor (to AS_GAM_Vendor_RecordType)
    ```
  - Developers can use `local!contract.vendor` whether working with CDT or record

### C. Security

**Purpose:** Record security controls who can view and manage records. Proper security configuration prevents unauthorized access while enabling appropriate users to work with data.

**Checklist Items:**

- [ ] **Appian Administrators as Administrator**
  - Always set Appian Administrators group as record Administrator
  - This ensures system admins can manage the record configuration
  - **Standard configuration:**
    - Administrator: Appian Administrators

- [ ] **Business Users Group and Security Groups Group as Viewer**
  - Set appropriate groups as Viewer for record visibility
  - **Standard configuration:**
    - Viewer: Business Users Group, [App] Security Groups Group
  - Example: For GAM application, add "GAM Security Groups Group" as Viewer

- [ ] **Record-level security configured as needed**
  - Use record-level security (RLS) to control access to individual records
  - **Common patterns:**
    - User can only see their own records: `rv!record.createdBy = loggedInUser()`
    - User can see records for their department: `rv!record.department = user(loggedInUser(), "department")`
    - User can see records they're assigned to: `contains(rv!record.assignedUsers, loggedInUser())`
  - Test RLS thoroughly with different user roles
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify security groups are configured)

### D. Record Actions

**Purpose:** Record actions provide consistent entry points for users to interact with data. Proper action configuration ensures actions appear in the right context with appropriate visibility.

**Checklist Items:**

- [ ] **Action type decided (Record List vs Related)**
  - **Record List Action:** Appears on record list views (e.g., "Create New Vendor")
  - **Related Action:** Appears on individual record views (e.g., "Edit Vendor", "Delete Vendor")
  - Choose based on where the action makes sense contextually

- [ ] **Action name and key defined**
  - Use clear, action-oriented names
  - **Good names:** "Create Vendor", "Edit Contract", "Upload Document", "Approve Request"
  - **Bad names:** "Vendor Form", "Contract Process", "Document", "Approve"
  - Key should be unique and descriptive: `createVendor`, `editContract`

- [ ] **Process model and context defined (avoid passing rv!record directly)**
  - Pass only the data the process needs, not the entire record
  - **Good:**
    ```
    Process Model: AS GAM Create Vendor SF
    Context: {
      vendorId: rv!record.id,
      vendorName: rv!record.name
    }
    ```
  - **Bad:**
    ```
    Process Model: AS GAM Create Vendor SF
    Context: {
      record: rv!record  /* Don't pass entire record */
    }
    ```
  - Passing specific fields makes the process more testable and maintainable

- [ ] **Visibility defined and optimized for performance**
  - Use visibility rules to show/hide actions based on context
  - Keep visibility logic simple to avoid performance issues
  - **Good (simple visibility):**
    ```
    Visibility: rv!record.status = "Draft"
    ```
  - **Bad (complex visibility with queries):**
    ```
    Visibility: contains(
      rule!AS_GAM_QE_getUserPermissions(userId: loggedInUser()).actions,
      "editVendor"
    )
    /* This queries on every record - performance issue! */
    ```
  - For complex visibility, calculate once at the list level and pass as context
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect queries in visibility expressions)

### E. Query Rules

**Purpose:** Efficient querying patterns ensure good performance and maintainability. Modern Appian development favors direct record queries over legacy patterns.

**Checklist Items:**

- [ ] **No antipattern of queryRecord + cast to CDT (use queryEntity instead)**
  - Don't query as record then cast to CDT - this is inefficient
  - **Bad (antipattern):**
    ```
    local!vendors: cast(
      type!AS_GAM_Vendor,
      a!queryRecordType(
        recordType: recordType!AS_GAM_Vendor_RecordType,
        fields: {}
      ).data
    )
    ```
  - **Good (use queryEntity):**
    ```
    local!vendors: a!queryEntity(
      entity: cons!AS_GAM_ENT_VENDOR,
      query: a!query(...)
    ).data
    ```
  - Or query as record and work with record data directly (don't cast)
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect queryRecord + cast pattern)

- [ ] **Specify which related records to return**
  - When querying records with relationships, explicitly specify which related data to fetch
  - This prevents over-fetching and improves performance
  - **Good:**
    ```
    a!queryRecordType(
      recordType: recordType!AS_GAM_Contract_RecordType,
      relatedRecordData: {
        recordType!AS_GAM_Vendor_RecordType,  /* Fetch related vendor */
        recordType!AS_GAM_Document_RecordType  /* Fetch related documents */
      }
    )
    ```
  - **Bad:**
    ```
    a!queryRecordType(
      recordType: recordType!AS_GAM_Contract_RecordType
      /* No relatedRecordData specified - might fetch everything or nothing */
    )
    ```
  - Only fetch the related records you actually need

---

## 4. Constants

**Purpose:** Constants provide a centralized way to manage configuration values, enable dependency tracing, and ensure consistency across the application. Proper constant usage makes applications easier to configure and maintain.

### A. Naming

**Purpose:** Consistent naming conventions make constants easy to identify, understand, and manage. The prefix system helps developers quickly understand what type of value a constant holds.

**Checklist Items:**

- [ ] **Prefixed with application namespace**
  - All constants must start with the application namespace
  - **Good:** `AS_GAM_INT_MAX_VENDORS`, `AS_GSS_TXT_DEFAULT_STATUS`, `CCM_CTA_GRP_ALERT_GROUP`, `CMGT_PM_UPDATE_CASE`
  - **Bad:** `MAX_VENDORS`, `DEFAULT_STATUS`, `INT_MAX_VENDORS`
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify constant naming convention)

- [ ] **Use a sub-prefix based on the type:**
  - The sub-prefix indicates the constant's data type
  - **Type Prefixes:**
    - **BOL** = Boolean (true/false)
    - **CS** = Connected System
    - **DEC** = Decimal (floating point numbers)
    - **DOC** = Document
    - **ENT** = Data Store Entity
    - **ENUM** = Enumeration (custom data type)
    - **FLD** = Folder
    - **GRP** = Group
    - **INT** = Integer (whole numbers)
    - **PM** = Process Model
    - **RP** = Report
    - **RT** = Record Type
    - **REF_TYPE** = Reference Data Type
    - **REF_CODE** = Reference Data Code
    - **TM** = Time
    - **TXT** = Text (string)
  
  - **Examples:**
    ```
    AS_GAM_INT_MAX_UPLOAD_SIZE: 10485760
    AS_GAM_TXT_DEFAULT_STATUS: "Active"
    AS_GAM_BOL_ENABLE_NOTIFICATIONS: true
    CCM_CTA_GRP_ALERT_GROUP: [Group reference]
    AS_GAM_ENT_VENDOR: [Data Store Entity reference]
    AS_GAM_RT_VENDOR: recordType!AS_GAM_Vendor_RecordType
    AS_GAM_DOC_TERMS_AND_CONDITIONS: [Document reference]
    AS_GAM_FLD_VENDOR_DOCUMENTS: [Folder reference]
    CMGT_PM_UPDATE_CASE: [Process Model reference]
    ```
    
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify type prefix matches constant value type)

### B. Appropriate Use

**Purpose:** Constants should be used strategically for values that need traceability, consistency, or configurability. Overuse or misuse of constants can make the application harder to maintain.

**Checklist Items:**

- [ ] **Constants used for dependency tracing**
  - Use constants for Appian objects (groups, folders, documents, process models, etc.)
  - This allows dependency checker to find all references
  - **Good:**
    ```
    cons!AS_GAM_GRP_VENDOR_ADMINS  /* Can trace where this group is used */
    cons!AS_GAM_PM_CREATE_VENDOR   /* Can trace where this process is called */
    cons!AS_GAM_DOC_TEMPLATE       /* Can trace where this document is used */
    ```
  - **Bad:**
    ```
    12345  /* Hard-coded group ID - can't trace dependencies */
    "AS GAM Create Vendor SF"  /* Hard-coded process name - can't trace */
    ```

- [ ] **Constants used for consistency between two or more places**
  - If a value is used in multiple places, use a constant
  - This ensures consistency and makes updates easier
  - **Good:**
    ```
    cons!AS_GAM_INT_MAX_UPLOAD_SIZE  /* Used in multiple upload forms */
    cons!AS_GAM_TXT_DEFAULT_CATEGORY  /* Used in multiple vendor forms */
    ```
  - **When NOT to use:** If a value is only used once, it doesn't need to be a constant
  - **Exception:** Even single-use values may warrant constants if they're likely to be configured per environment

- [ ] **Constants used for potentially configurable functionality**
  - Use constants for values that might need to be changed per environment or customer
  - **Good examples:**
    ```
    AS_GAM_INT_SESSION_TIMEOUT: 30  /* Might vary by customer */
    AS_GAM_BOL_ENABLE_EMAIL_NOTIFICATIONS: true  /* Might be disabled in some environments */
    AS_GAM_TXT_SUPPORT_EMAIL: "support@example.com"  /* Different per environment */
    AS_GAM_INT_MAX_SEARCH_RESULTS: 100  /* Might be tuned for performance */
    ```
  - Think about what customers might want to configure

- [ ] **No constants for text that should be internationalized**
  - Don't use constants for user-facing text
  - User-facing text should be in i18n bundles, not constants
  - **Bad:**
    ```
    AS_GAM_TXT_WELCOME_MESSAGE: "Welcome to Vendor Management"
    AS_GAM_TXT_SAVE_BUTTON: "Save"
    AS_GAM_TXT_ERROR_MESSAGE: "An error occurred"
    ```
  - **Good (use i18n instead):**
    ```
    rule!AS_GAM_I18N_UT_displayLabel(
      bundleData: local!bundleData,
      key: "lbl_welcomeMessage"
    )
    ```
  - Constants are not translatable; i18n bundles are

- [ ] **No array constants (use expression rules instead)**
  - Don't create constants that hold arrays
  - Arrays in constants can't be easily maintained or extended
  - **Bad:**
    ```
    AS_GAM_TXT_VALID_STATUSES: {"Active", "Inactive", "Pending"}
    /* Can't add/remove items easily, can't add logic */
    ```
  - **Good (use expression rule):**
    ```
    rule!AS_GAM_CONS_validStatuses()
    /* Returns: {"Active", "Inactive", "Pending"} */
    /* Can add logic, filtering, or dynamic behavior */
    ```
  - Expression rules provide more flexibility for list management
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect array constants)

---

## 5. Expression Rules

**Purpose:** Expression rules are the building blocks of reusable logic in Appian. Proper naming, testing, and query patterns ensure rules are maintainable, reliable, and performant.

### A. Naming

**Purpose:** Consistent naming conventions help developers quickly understand what a rule does and where it fits in the application architecture.

**Checklist Items:**

- [ ] **Prefixed with application namespace**
  - All expression rules must start with the application namespace
  - **Good:** `AS_GAM_BL_calculateTotal`, `CMGT_QE_getContracts`
  - **Bad:** `calculateTotal`, `getContracts`, `BL_calculateTotal`
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify rule naming convention)

- [ ] **Use a sub-prefix based on the purpose:**
  - The sub-prefix indicates the rule's functional category
  - **Purpose Prefixes:**
    - **BL** = Business Logic (calculations, validations, transformations)
    - **CDT** = CDT Constructors (functions that build CDT objects)
    - **REC** = Record Constructors (functions that build record objects)
    - **CONS** = List of Constants (returns arrays of constant values)
    - **QE** = Query Entity (queries data store entities)
    - **QR** = Query Record (queries record types)
    - **QPA** = Query Process Analytics (queries process data)
    - **REF** = Immutable Reference Data List (returns reference data)
    - **UI** = UI Components (reusable interface components)
    - **VD** = Validations (validation logic)
  
  - **Examples:**
    ```
    AS_GAM_BL_calculateVendorScore
    AS_GAM_CDT_vendor (constructs AS_GAM_Vendor CDT)
    AS_GAM_CONS_validStatuses (returns list of status constants)
    AS_GAM_QE_getVendors (queries vendor entity)
    AS_GAM_QR_getContracts (queries contract records)
    AS_GAM_REF_categories (returns category reference data)
    AS_GAM_UI_vendorCard (reusable vendor card component)
    AS_GAM_VD_validateEmail (validates email format)
    ```
  
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify purpose prefix matches rule behavior)

### B. Test Cases

**Purpose:** Test cases ensure expression rules work correctly and continue to work as the application evolves. Comprehensive testing is essential for maintainable code.

**Checklist Items:**

- [ ] **Every expression rule has proper test case coverage**
  - All expression rules should have test cases
  - Test both happy path and edge cases
  - **Minimum coverage:**
    - Valid inputs producing expected outputs
    - Null/empty inputs
    - Boundary conditions
    - Error conditions
  - **Example test cases for `AS_GAM_BL_calculateDiscount`:**
    - Test 1: Standard discount (10% off $100 = $10)
    - Test 2: Null amount returns null
    - Test 3: Zero amount returns zero
    - Test 4: Negative amount returns null (invalid)
    - Test 5: Maximum discount cap applied correctly

- [ ] **Assertions use 'evaluates to true' or 'matches asserted output'**
  - Use proper assertion types for reliable testing
  - **Good (evaluates to true):**
    ```
    Test: Discount calculation
    Expression: rule!AS_GAM_BL_calculateDiscount(amount: 100, rate: 0.1) = 10
    Assertion: Evaluates to true
    ```
  - **Good (matches asserted output):**
    ```
    Test: Get vendor by ID
    Expression: rule!AS_GAM_QE_getVendor(vendorId: 1)
    Assertion: Matches asserted output
    Asserted Output: type!AS_GAM_Vendor(id: 1, name: "Test Vendor", ...)
    ```
  - **Bad:**
    ```
    Test: Discount calculation
    Expression: rule!AS_GAM_BL_calculateDiscount(amount: 100, rate: 0.1)
    Assertion: No assertion (just runs the rule)
    ```
  - Tests without assertions don't verify correctness

- [ ] **No hard-coded internationalization labels in assertions**
  - Don't assert against translated text in test cases
  - Text may change or be translated differently
  - **Bad:**
    ```
    Test: Format status
    Expression: rule!AS_GAM_BL_formatStatus(status: "A")
    Assertion: Matches asserted output
    Asserted Output: "Active"  /* Will break if label changes */
    ```
  - **Good:**
    ```
    Test: Format status
    Expression: rule!AS_GAM_BL_formatStatus(status: "A")
    Assertion: Evaluates to true
    Expression: not(isnull(rule!AS_GAM_BL_formatStatus(status: "A")))
    /* Or test the logic, not the label */
    ```

- [ ] **Avoid environmentally-specific data in test cases**
  - Don't use IDs, groups, or data that only exist in one environment
  - Tests should be portable across environments
  - **Bad:**
    ```
    Test: Get vendor
    Expression: rule!AS_GAM_QE_getVendor(vendorId: 12345)
    /* Vendor ID 12345 might not exist in all environments */
    ```
  - **Good:**
    ```
    Test: Get vendor
    Expression: rule!AS_GAM_QE_getVendor(vendorId: 1)
    /* Use mock data or create test data in the test itself */
    ```
  - Or use test data that's guaranteed to exist (like reference data)

### C. Queries

**Purpose:** Standardized query patterns ensure consistency, maintainability, and proper use of Appian's query utilities. Using CO query utilities provides additional benefits like error handling and logging.

**Checklist Items:**

- [ ] **Uses AS_CO_UT_queryEntity() and AS_CO_UT_queryRecord(), NOT Query Rules**
  - Use CO utility rules instead of creating custom Query Rules
  - CO utilities provide consistent error handling and logging
  - **Good:**
    ```
    rule!AS_CO_UT_queryEntity(
      entity: cons!AS_GAM_ENT_VENDOR,
      query: a!query(
        filter: a!queryFilter(field: "isActive", operator: "=", value: true)
      )
    )
    ```
  - **Bad:**
    ```
    /* Creating a Query Rule in Appian Designer */
    Query Rule: AS_GAM_QR_getVendors
    /* Query Rules are legacy and harder to maintain */
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect Query Rule usage vs CO utility usage)

- [ ] **Named QE_get<Object> or QR_get<Object>**
  - Query expression rules should follow this naming pattern
  - **Good:**
    ```
    AS_GAM_QE_getVendors (queries vendor entity)
    AS_GAM_QE_getVendor (queries single vendor by ID)
    AS_GAM_QR_getContracts (queries contract records)
    AS_GAM_QR_getContract (queries single contract by ID)
    ```
  - **Bad:**
    ```
    AS_GAM_BL_vendorQuery (wrong prefix - should be QE)
    AS_GAM_QE_vendors (missing "get" verb)
    AS_GAM_QE_queryVendors (redundant "query" - QE already indicates query)
    ```

- [ ] **Single expression rule per data store entity with optional filters**
  - Create one query rule per entity with flexible filtering
  - Don't create separate rules for each filter combination
  - **Good (one flexible rule):**
    ```
    rule!AS_GAM_QE_getVendors(
      showInactive: false (optional),
      categoryFilter: null (optional),
      searchText: null (optional)
    )
    /* Handles all vendor queries with optional filters */
    ```
  - **Bad (separate rules for each case):**
    ```
    rule!AS_GAM_QE_getActiveVendors()
    rule!AS_GAM_QE_getInactiveVendors()
    rule!AS_GAM_QE_getVendorsByCategory(category)
    rule!AS_GAM_QE_searchVendors(searchText)
    /* Too many rules - hard to maintain */
    ```
  - Use optional parameters to make one rule handle multiple scenarios

- [ ] **Default filter on isActive or isDeleted**
  - Most queries should filter out inactive/deleted records by default
  - Make it opt-in to see inactive records
  - **Good:**
    ```
    rule!AS_GAM_QE_getVendors(
      showInactive: false  /* Default: hide inactive */
    )
    
    /* Inside the rule: */
    local!filters: if(
      ri!showInactive,
      {},  /* No filter - show all */
      {a!queryFilter(field: "isActive", operator: "=", value: true)}
    )
    ```
  - This prevents accidentally displaying deleted/inactive data
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect query rules without isActive/isDeleted filters)

---

## 6. Interfaces

**Purpose:** Interfaces are the visual components users interact with. Proper naming, default inputs, and logic separation ensure interfaces are maintainable, testable, and reusable.

### A. Naming

**Purpose:** Consistent naming conventions help developers quickly identify interface types and their purposes in the application architecture.

**Checklist Items:**

- [ ] **Prefixed with application namespace**
  - All interfaces must start with the application namespace
  - **Good:** `AS_GAM_FM_VendorForm`, `AS_GSS_GRD_ContractGrid`
  - **Bad:** `VendorForm`, `ContractGrid`, `FM_VendorForm`
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify interface naming convention)

- [ ] **Use a sub-prefix based on the purpose:**
  - The sub-prefix indicates the interface's UI component type
  - **Purpose Prefixes:**
    - **CPS** = Components (reusable UI components)
    - **FM** = Form layout (full forms for create/edit)
    - **SCT** = Section layout (sections within forms)
    - **COL** = Column layout (column-based layouts)
    - **CRD** = Card layout (card-based displays)
    - **BOX** = Box layout (boxed content areas)
    - **BLB** = Billboard layout (prominent display areas)
    - **INP** = Input field (custom input components)
    - **DSP** = Display field (custom display components)
    - **BTN** = Buttons (button components)
    - **LNK** = Links (link components)
    - **GRD** = Grid (data grids/tables)
    - **CHT** = Chart (charts and visualizations)
    - **PCK** = Picker (picker components)
    - **TAG** = Tag field (tag/badge components)
    - **HCL** = Header content layout (page headers)
  
  - **Examples:**
    ```
    AS_GAM_FM_VendorForm (full vendor create/edit form)
    AS_GAM_SCT_VendorDetails (vendor details section)
    AS_GAM_GRD_VendorList (vendor data grid)
    AS_GAM_CRD_VendorCard (vendor card display)
    AS_GAM_PCK_CategoryPicker (category picker)
    AS_GAM_DSP_StatusBadge (status display badge)
    AS_GAM_BTN_SaveButton (custom save button)
    AS_GAM_CHT_VendorMetrics (vendor metrics chart)
    ```
  
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify purpose prefix matches interface type)

### B. Default Inputs

**Purpose:** Default inputs allow interfaces to be tested and previewed in isolation without requiring external data. This improves development efficiency and makes interfaces more maintainable.

**Checklist Items:**

- [ ] **Every interface has default inputs saved**
  - Set default values for all rule inputs in the interface
  - This allows the interface to be viewed and tested without external data
  - **How to set defaults:**
    1. Open the interface in Appian Designer
    2. Click "Test" in the top right
    3. Provide sample values for all inputs
    4. Click "Save as Default Inputs"
  - **Example defaults:**
    ```
    Rule Input: vendor
    Default: type!AS_GAM_Vendor(
      id: 1,
      name: "Sample Vendor",
      status: "Active",
      category: "Technology"
    )
    
    Rule Input: isReadOnly
    Default: false
    
    Rule Input: showInactive
    Default: false
    ```

- [ ] **Avoid environmentally-specific data**
  - Don't use IDs, groups, or data that only exist in one environment
  - Use generic sample data that works across all environments
  - **Bad:**
    ```
    Rule Input: vendorId
    Default: 12345  /* This ID might not exist in all environments */
    
    Rule Input: approverGroup
    Default: [Group:54321]  /* This group might not exist everywhere */
    ```
  - **Good:**
    ```
    Rule Input: vendorId
    Default: 1  /* Generic ID */
    
    Rule Input: approverGroup
    Default: null  /* Or use a constant that exists everywhere */
    ```
  - Use constants for groups, folders, and other environment-specific objects

### C. Logic

**Purpose:** Interfaces should focus on presentation and user interaction. Complex business logic should be extracted to expression rules for better testability and reusability.

**Checklist Items:**

- [ ] **Forms contain minimal logic**
  - Interfaces should primarily handle UI layout and user interaction
  - Keep logic simple: boolean switches, basic conditionals, data display
  - **Good (minimal logic in interface):**
    ```
    a!formLayout(
      label: "Vendor Form",
      contents: {
        if(
          ri!isReadOnly,
          rule!AS_GAM_DSP_VendorDetails(vendor: local!vendor),
          rule!AS_GAM_SCT_VendorEditForm(vendor: local!vendor)
        )
      }
    )
    ```
  - **Bad (complex logic in interface):**
    ```
    a!formLayout(
      label: "Vendor Form",
      contents: {
        /* 50+ lines of complex validation logic */
        local!errors: if(
          isnull(local!vendor.name),
          append(local!errors, "Name is required"),
          if(
            len(local!vendor.name) < 3,
            append(local!errors, "Name must be at least 3 characters"),
            if(
              /* ... many more validation rules ... */
            )
          )
        ),
        /* More complex calculations and transformations */
      }
    )
    ```

- [ ] **If there is logic much beyond boolean switches, compartmentalize it in a rule**
  - Extract complex logic to expression rules
  - This makes the logic testable, reusable, and easier to maintain
  - **Good (logic extracted to rule):**
    ```
    /* In interface: */
    local!validationErrors: rule!AS_GAM_VD_validateVendor(vendor: local!vendor),
    local!discountAmount: rule!AS_GAM_BL_calculateDiscount(
      amount: local!orderTotal,
      vendorTier: local!vendor.tier
    ),
    
    a!formLayout(
      label: "Vendor Form",
      contents: {
        /* Simple UI logic only */
        if(length(local!validationErrors) > 0, 
          rule!AS_GAM_DSP_ErrorMessages(errors: local!validationErrors),
          {}
        )
      }
    )
    ```
  - **When to extract logic:**
    - Validation logic (more than 2-3 simple checks)
    - Calculations (anything beyond basic arithmetic)
    - Data transformations (mapping, filtering, sorting)
    - Business rules (discount calculations, eligibility checks)
  - **What can stay in the interface:**
    - Simple boolean switches (`if(ri!isReadOnly, ..., ...)`)
    - Basic null checks (`if(isnull(local!vendor), ..., ...)`)
    - Simple visibility logic (`showWhen: local!isExpanded`)
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect interfaces with high complexity/nesting)

---

## 7. Process Models

**Purpose:** Process models orchestrate workflows and business processes. Proper naming, security, and configuration ensure processes are maintainable, secure, and performant.

### A. Naming

**Purpose:** Consistent naming conventions help identify process types and their purposes. Proper naming also improves process monitoring and troubleshooting.

**Checklist Items:**

- [ ] **Processes named: AS <solution acronym> <descriptive name> <SF if start form>**
  - Follow the standard naming pattern for all process models
  - **Format:** `AS <app> <description> <SF>`
  - **Examples:**
    ```
    AS GAM Create Vendor SF (has start form)
    AS GAM Update Vendor Status (no start form - backend process)
    AS GSS Process Contract Approval SF (has start form)
    AS GSS Send Notification Email (no start form - utility process)
    ```
  - **SF suffix:** Add "SF" only if the process has a start form
  - **Bad examples:**
    ```
    CreateVendor (missing namespace)
    AS_GAM_CreateVendor (underscores instead of spaces)
    AS GAM Vendor (not descriptive enough)
    AS GAM Create Vendor Form (use "SF" not "Form")
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify process naming convention)

- [ ] **Process instance naming uses rule!AS_CO_UT_processDisplayName()**
  - Use the CO utility rule for consistent process instance names
  - This provides standardized naming across all processes
  - **How to configure:**
    1. Open the process model
    2. Go to the "General" tab
    3. In "Process Display Name" field, use:
       ```
       =rule!AS_CO_UT_processDisplayName(
         processName: "Create Vendor",
         identifier: pv!vendorName
       )
       ```
  - **Result:** Process instances appear as "Create Vendor - [Vendor Name]" in monitoring
  - **Benefits:**
    - Consistent naming format across all processes
    - Easy to identify specific process instances
    - Improved monitoring and troubleshooting
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect processes not using CO display name utility)

### B. Security

**Purpose:** Proper security configuration ensures processes are accessible to the right users while protecting sensitive workflows from unauthorized access.

**Checklist Items:**

- [ ] **Entry point processes have own security group**
  - Each user-facing process should have its own security group
  - This allows fine-grained access control
  - **Example:**
    ```
    Process: AS GAM Create Vendor SF
    Security Group: GAM Create Vendor Users
    
    Process: AS GAM Approve Contract SF
    Security Group: GAM Contract Approvers
    ```
  - **Why:** Different processes may need different user access
  - Don't use a single "All Users" group for all processes

- [ ] **Backend processes: Viewers = All Security Groups Group**
  - Utility and backend processes should be visible to all security groups
  - **Configuration:**
    - Viewers: [App] Security Groups Group (e.g., "GAM Security Groups Group")
    - Initiators: (specific groups or process models that call this process)
  - **Example:**
    ```
    Process: AS GAM Send Notification Email
    Viewers: GAM Security Groups Group
    Initiators: (only called by other processes, not users)
    ```
  - This allows monitoring without allowing direct user initiation

- [ ] **Lane assignment to process initiator**
  - Assign the first lane to the process initiator when appropriate
  - **Configuration:**
    - Lane: "Submit Request" or "Initiate Process"
    - Assignment: Process Initiator
  - **Why:** The user who starts the process should complete the initial steps
  - **Exception:** Some processes may route to a different user/group immediately

### C. Alerts

**Purpose:** Centralized alert management ensures process issues are routed to the right team for resolution.

**Checklist Items:**

- [ ] **All alerts go to process alerts group for the application**
  - Configure all process alerts to go to a dedicated alerts group
  - **Configuration:**
    1. Open process model
    2. Go to "Alerts" tab
    3. Set "Alert Assignees" to: [App] Process Alerts Group
  - **Example:**
    ```
    Process: AS GAM Create Vendor SF
    Alert Assignees: GAM Process Alerts Group
    
    Process: AS GAM Update Vendor Status
    Alert Assignees: GAM Process Alerts Group
    ```
  - **Why:**
    - Centralized monitoring of all process issues
    - Consistent alert handling
    - Easy to manage alert recipients
  - **Don't:** Send alerts to individual users or multiple different groups
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify alert group configuration)

### D. Archiving and Deleting

**Purpose:** Proper data retention policies keep the system performant while maintaining necessary audit trails. Different process types have different retention needs.

**Checklist Items:**

- [ ] **Major processes archive after 3 days**
  - User-facing processes with forms should archive after completion
  - **Configuration:**
    - Auto-Archive: Enabled
    - Archive Delay: 3 days after completion
  - **Applies to:**
    - Processes with start forms (SF)
    - Approval workflows
    - User-initiated processes
  - **Example:**
    ```
    Process: AS GAM Create Vendor SF
    Auto-Archive: Yes
    Archive Delay: 3 days
    ```
  - **Why:** Maintains audit trail while keeping active process list clean

- [ ] **Utility/backend processes delete after 1 day**
  - Background processes without user interaction should auto-delete
  - **Configuration:**
    - Auto-Delete: Enabled
    - Delete Delay: 1 day after completion
  - **Applies to:**
    - Email notification processes
    - Data synchronization processes
    - Scheduled batch processes
    - Integration processes
  - **Example:**
    ```
    Process: AS GAM Send Notification Email
    Auto-Delete: Yes
    Delete Delay: 1 day
    ```
  - **Why:** These processes don't need long-term audit trail and can clutter the system
  - **Exception:** If audit requirements mandate keeping all process history, archive instead of delete
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify archiving/deletion configuration)

---

## 8. Reference Data

**Purpose:** Reference data represents relatively static, non-user-editable data like categories, statuses, types, and lookup values. Proper reference data management ensures consistent data display and efficient querying.

### A. General

**Purpose:** Reference data should be loaded efficiently and displayed consistently throughout the application. Following these patterns improves performance and maintainability.

**Checklist Items:**

- [ ] **Non-user-editable data stored as reference data**
  - Data that doesn't change frequently should be stored as reference data
  - **Examples of reference data:**
    - Status codes (Active, Inactive, Pending, Approved)
    - Categories (Technology, Services, Manufacturing)
    - Types (Vendor Type, Contract Type, Document Type)
    - Countries, states, currencies
    - Priority levels (High, Medium, Low)
  - **Not reference data:**
    - Transactional data (orders, invoices, contracts)
    - User-editable master data (vendors, customers, products)
  - **Storage pattern:**
    - Database tables with `R_` prefix (e.g., `AS_GAM_R_CATEGORY`)
    - CDTs with `R` prefix (e.g., `AS_GAM_R_Category`)

- [ ] **Reference data loaded at top level to avoid multiple queries**
  - Load all necessary reference data once at the top-level interface
  - Pass it down to child components rather than querying repeatedly
  - **Good (load once at top):**
    ```
    a!localVariables(
      /* Load all reference data once */
      local!categories: rule!AS_GAM_REF_categories(),
      local!statuses: rule!AS_GAM_REF_statuses(),
      local!vendorTypes: rule!AS_GAM_REF_vendorTypes(),
      
      /* Pass to child components */
      a!formLayout(
        contents: {
          rule!AS_GAM_SCT_VendorDetails(
            vendor: local!vendor,
            categories: local!categories,  /* Pass reference data */
            statuses: local!statuses
          ),
          rule!AS_GAM_GRD_VendorList(
            vendors: local!vendors,
            categories: local!categories,  /* Reuse same data */
            vendorTypes: local!vendorTypes
          )
        }
      )
    )
    ```
  - **Bad (query multiple times):**
    ```
    a!formLayout(
      contents: {
        rule!AS_GAM_SCT_VendorDetails(
          vendor: local!vendor
          /* This component queries categories internally */
        ),
        rule!AS_GAM_GRD_VendorList(
          vendors: local!vendors
          /* This component also queries categories - duplicate query! */
        )
      }
    )
    ```
  - **Why:** Reduces database queries and improves performance
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect multiple reference data queries in same interface tree)

- [ ] **filterRefDataForSelection used before displaying reference data**
  - Filter reference data to show only active/valid options before displaying
  - Use a standard filtering rule for consistency
  - **Good:**
    ```
    a!dropdownField(
      label: "Category",
      choiceLabels: rule!AS_GAM_REF_filterForSelection(
        refData: local!categories
      ).label,
      choiceValues: rule!AS_GAM_REF_filterForSelection(
        refData: local!categories
      ).code
    )
    ```
  - **What the filter does:**
    - Removes inactive/deleted reference data items
    - Sorts by display order or label
    - Applies any business rules for visibility
  - **Why:** Prevents users from selecting inactive/deprecated options
  - **Exception:** When editing existing data, you may need to show the currently selected value even if it's inactive

- [ ] **Reference data displayed using rule AS_<app>_I18N_UT_displayLabel**
  - Use the internationalization utility to display reference data labels
  - This ensures labels are translated and formatted consistently
  - **Good:**
    ```
    a!textField(
      label: "Status",
      value: rule!AS_GAM_I18N_UT_displayLabel(
        bundleData: local!bundleData,
        key: "ref_status_" & local!vendor.statusCode
      ),
      readOnly: true
    )
    ```
  - **Also good (using reference data label field):**
    ```
    /* If reference data table has label field */
    local!statusLabel: index(
      rule!AS_GAM_REF_statuses(),
      wherecontains(local!vendor.statusCode, rule!AS_GAM_REF_statuses().code),
      {}
    ).label
    ```
  - **Bad (hard-coded labels):**
    ```
    a!textField(
      label: "Status",
      value: if(
        local!vendor.statusCode = "A",
        "Active",
        if(
          local!vendor.statusCode = "I",
          "Inactive",
          "Unknown"
        )
      )
    )
    ```
  - **Why:** Centralized label management, supports internationalization, easier to maintain
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect hard-coded reference data labels)

---

## 9. Internationalization

**Purpose:** Internationalization (i18n) enables applications to support multiple languages and locales. Proper i18n implementation ensures all user-facing text can be translated without code changes.

### A. General

**Purpose:** All user-facing text must be externalized to translation bundles. This allows customers to translate the application into their preferred language without modifying code.

**Checklist Items:**

- [ ] **All display text internationalized**
  - Every piece of user-facing text must come from i18n bundles
  - **User-facing text includes:**
    - Labels, buttons, links
    - Instructions, help text, tooltips
    - Validation messages, error messages
    - Captions, placeholders
    - Column headers, section titles
  - **Not user-facing (doesn't need i18n):**
    - Log messages
    - Technical error codes
    - Database field names
    - Object names (rule names, constant names)
  - **Good:**
    ```
    a!textField(
      label: rule!AS_GAM_I18N_UT_displayLabel(
        bundleData: local!bundleData,
        key: "lbl_vendorName"
      ),
      placeholder: rule!AS_GAM_I18N_UT_displayLabel(
        bundleData: local!bundleData,
        key: "plc_enterVendorName"
      )
    )
    ```
  - **Bad:**
    ```
    a!textField(
      label: "Vendor Name",  /* Hard-coded English text */
      placeholder: "Enter vendor name"
    )
    ```
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect hard-coded text strings in interfaces)

- [ ] **Bundle data loaded in top-level parent interface and passed down**
  - Load i18n bundle data once at the top level
  - Pass it to all child components to avoid repeated queries
  - **Good (load once at top):**
    ```
    a!localVariables(
      /* Load bundle data once */
      local!bundleData: rule!AS_GAM_I18N_UT_getBundleData(
        locale: user(loggedInUser(), "locale")
      ),
      
      /* Pass to all child components */
      a!formLayout(
        label: rule!AS_GAM_I18N_UT_displayLabel(
          bundleData: local!bundleData,
          key: "lbl_vendorManagement"
        ),
        contents: {
          rule!AS_GAM_SCT_VendorDetails(
            vendor: local!vendor,
            bundleData: local!bundleData  /* Pass bundle data */
          ),
          rule!AS_GAM_GRD_VendorList(
            vendors: local!vendors,
            bundleData: local!bundleData  /* Reuse same bundle data */
          )
        }
      )
    )
    ```
  - **Bad (load multiple times):**
    ```
    a!formLayout(
      contents: {
        rule!AS_GAM_SCT_VendorDetails(
          vendor: local!vendor
          /* This component loads bundle data internally */
        ),
        rule!AS_GAM_GRD_VendorList(
          vendors: local!vendors
          /* This component also loads bundle data - duplicate query! */
        )
      }
    )
    ```
  - **Why:** Reduces queries and ensures consistent locale across all components
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect multiple bundle data loads in same interface tree)

- [ ] **Display bundle data using rule AS_<app>_I18N_UT_displayLabel**
  - Use the standard utility rule to retrieve translated labels
  - This provides consistent error handling and fallback behavior
  - **Good:**
    ```
    rule!AS_GAM_I18N_UT_displayLabel(
      bundleData: local!bundleData,
      key: "lbl_vendorName"
    )
    ```
  - **Bad (direct bundle access):**
    ```
    index(local!bundleData, "lbl_vendorName", "Vendor Name")
    /* No error handling, inconsistent fallback */
    ```
  - **What the utility does:**
    - Looks up the key in the bundle data
    - Returns the translated text for the user's locale
    - Falls back to default locale if translation missing
    - Logs missing keys for translation team
    - Returns the key itself if no translation found (for debugging)

### B. Bundle Key Naming Prefixes

**Purpose:** Consistent key naming makes bundles easier to manage and helps developers quickly identify the type of text they're looking for.

**Checklist Items:**

- [ ] **Correct prefixes used:**
  - Use standard prefixes for all bundle keys
  - **Prefix Standards:**
    - **acs** = Accessibility text (screen reader text, ARIA labels)
    - **btn** = Button label
    - **cpt** = Captions (image captions, chart titles)
    - **hlp** = Help tooltip (help text, info icons)
    - **ins** = Instruction text (form instructions, guidance)
    - **lbl** = Label (field labels, section headers)
    - **plc** = Placeholder (input field placeholders)
    - **txt** = General text (body text, descriptions)
    - **vld** = Validation message (error messages, warnings)
  
  - **Examples:**
    ```
    lbl_vendorName: "Vendor Name"
    btn_save: "Save"
    btn_cancel: "Cancel"
    plc_enterVendorName: "Enter vendor name"
    ins_vendorFormInstructions: "Complete all required fields to create a new vendor"
    hlp_vendorCategory: "Select the primary business category for this vendor"
    vld_vendorNameRequired: "Vendor name is required"
    vld_emailInvalid: "Please enter a valid email address"
    acs_expandSection: "Expand vendor details section"
    txt_noVendorsFound: "No vendors found matching your search criteria"
    cpt_vendorMetricsChart: "Vendor Performance Metrics - Last 12 Months"
    ```
  
  - **Bad (no prefix or wrong prefix):**
    ```
    vendorName: "Vendor Name"  /* No prefix */
    label_vendorName: "Vendor Name"  /* Wrong prefix format */
    saveButton: "Save"  /* No prefix */
    ```
  
  - **AUTOMATED CHECK AVAILABLE** ✓ (can verify bundle keys follow prefix conventions)

### C. Bundle Files

**Purpose:** Organized bundle files make translations easier to manage and reduce the risk of key conflicts. Proper file organization also improves performance.

**Checklist Items:**

- [ ] **Separate bundle files by area of functionality**
  - Create separate bundle files for different functional areas
  - Don't put all labels in one giant file
  - **Good structure:**
    ```
    AS_GAM_I18N_Vendor.properties (vendor-related labels)
    AS_GAM_I18N_Contract.properties (contract-related labels)
    AS_GAM_I18N_Common.properties (shared labels used everywhere)
    AS_GAM_I18N_Validation.properties (all validation messages)
    ```
  - **Bad structure:**
    ```
    AS_GAM_I18N.properties (all 500+ labels in one file)
    ```
  - **Benefits:**
    - Easier to find and update labels
    - Reduces merge conflicts in version control
    - Translators can work on different files simultaneously
    - Smaller files load faster

- [ ] **Separate label for each instance of display text**
  - Don't reuse the same label key for different contexts
  - Each piece of text should have its own key
  - **Good:**
    ```
    lbl_vendorName: "Vendor Name"
    lbl_contractVendorName: "Vendor Name"  /* Different context */
    btn_saveVendor: "Save Vendor"
    btn_saveContract: "Save Contract"
    ```
  - **Bad:**
    ```
    lbl_name: "Name"  /* Used for vendor name, contract name, user name - ambiguous */
    btn_save: "Save"  /* Used everywhere - what is being saved? */
    ```
  - **Why:** Different contexts may need different translations in some languages
  - **Exception:** Truly generic labels like "Yes", "No", "OK", "Cancel" can be shared

- [ ] **No concatenation of multiple labels in SAIL code**
  - Don't build sentences by concatenating multiple label keys
  - Create complete sentence labels instead
  - **Bad:**
    ```
    rule!AS_GAM_I18N_UT_displayLabel(bundleData: local!bundleData, key: "txt_youHave")
    & " " 
    & local!count 
    & " " 
    & rule!AS_GAM_I18N_UT_displayLabel(bundleData: local!bundleData, key: "txt_vendors")
    /* Results in: "You have 5 vendors" */
    /* Problem: Word order varies by language! */
    ```
  - **Good:**
    ```
    rule!AS_GAM_I18N_UT_displayLabel(
      bundleData: local!bundleData,
      key: "txt_vendorCount",
      substitutions: {local!count}
    )
    /* Bundle: txt_vendorCount: "You have {0} vendors" */
    /* Translators can reorder words as needed for their language */
    ```
  - **Why:** Different languages have different word orders and grammar rules
  - **Use substitution parameters** for dynamic values within sentences
  - **AUTOMATED CHECK AVAILABLE** ✓ (can detect label concatenation patterns)

---

## 10. Database

### A. Maintainability
- [ ] Minimal views
- [ ] Comments on tables and columns
- [ ] Avoid triggers
- [ ] Database logic-free

### B. Scalability
- [ ] No calculated/concatenated columns in views
- [ ] Data archival framework considered
- [ ] Indexes on frequently queried columns (high cardinality)

---

## 11. Deprecation

**Purpose:** Proper deprecation practices ensure backward compatibility for existing customers while allowing the application to evolve. Clear deprecation markers help customers understand what's changing and plan their upgrades.

### A. Objects

**Purpose:** Deprecated objects must be handled differently depending on whether customers are already using them. This prevents breaking existing customer implementations.

**Checklist Items:**

- [ ] **If no customer: Unreferenced objects removed**
  - If the solution has not been deployed to any customers yet, remove unused objects
  - Clean up before first customer deployment
  - **What to remove:**
    - Unreferenced expression rules
    - Unused interfaces
    - Orphaned constants
    - Test objects not needed in production
  - **How to identify:**
    - Use Appian's "Find Usages" / Dependency Checker
    - Look for objects with zero dependents
    - Check for objects marked "TOBEDONE" or "TEST"
  - **Why:** Reduces clutter and maintenance burden
  - **AUTOMATED CHECK AVAILABLE** ✓ (can identify unreferenced objects)

- [ ] **If customer exists: Objects marked DEPRECATED and kept in package**
  - Once customers are using the solution, don't delete objects
  - Mark them as deprecated instead
  - **How to mark as deprecated:**
    1. Add "DEPRECATED" to the object name:
       - `AS_GAM_BL_calculateDiscount` → `AS_GAM_BL_calculateDiscount DEPRECATED`
    2. Update the description:
       ```
       DEPRECATED: This rule is deprecated as of version 2.5.0.
       Use rule!AS_GAM_BL_calculateVendorDiscount instead.
       Reason: New rule provides more accurate calculations.
       Migration: Replace all calls with new rule, parameters are compatible.
       ```
    3. Add a comment at the top of the code:
       ```
       /* DEPRECATED: Use AS_GAM_BL_calculateVendorDiscount instead */
       ```
    4. Keep the object in the package for backward compatibility
  
  - **Why:** Customers may be using the object in their customizations
  - **Customer migration path:**
    - Customers see "DEPRECATED" in the name
    - Description tells them what to use instead
    - They can migrate at their own pace
    - Old object continues to work until they're ready
  
  - **When to remove:** Only remove deprecated objects in a major version upgrade (e.g., 2.x → 3.0) after giving customers advance notice
  
  - **AUTOMATED CHECK AVAILABLE** ✓ (can identify objects marked DEPRECATED)

### B. Database

**Purpose:** Database changes require extra caution because they can cause data loss or application errors. Different database objects have different deprecation rules.

**Checklist Items:**

- [ ] **No dropped tables/columns if customer exists**
  - Never drop database tables or columns once customers are using the solution
  - Customers may have customizations that depend on these structures
  - **Instead of dropping:**
    1. Stop using the table/column in application code
    2. Add deprecation comment to the database object
    3. Document in release notes that the table/column is deprecated
    4. Leave the table/column in place
  
  - **Example:**
    ```sql
    -- Table: AS_GAM_VENDOR_OLD
    -- DEPRECATED: This table is deprecated as of version 2.5.0.
    -- Use AS_GAM_VENDOR instead.
    -- This table will be removed in version 3.0.0.
    ```
  
  - **Why:** Dropping tables/columns can cause:
    - Data loss for customers
    - Errors in customer customizations
    - Failed deployments
    - Rollback difficulties

- [ ] **Deprecation comments added to database objects**
  - Add clear deprecation comments to database objects
  - Include version, reason, and migration path
  - **Comment format:**
    ```sql
    COMMENT ON TABLE AS_GAM_VENDOR_OLD IS 
    'DEPRECATED as of v2.5.0. Use AS_GAM_VENDOR instead. 
    Reason: New table structure supports additional vendor types.
    Will be removed in v3.0.0.';
    
    COMMENT ON COLUMN AS_GAM_VENDOR.old_status_code IS
    'DEPRECATED as of v2.5.0. Use status_code instead.
    Reason: Standardized status code format.
    Will be removed in v3.0.0.';
    ```
  
  - **Benefits:**
    - DBAs can see deprecation warnings
    - Customers know what's changing
    - Clear migration timeline

- [ ] **Views can be dropped (just a query)**
  - Views are safe to drop because they don't store data
  - Views are just saved queries
  - **Safe to drop:**
    - Database views
    - Materialized views (after verifying no data loss)
  
  - **Before dropping a view:**
    1. Verify no application code references it
    2. Check for customer customizations using it
    3. Document the removal in release notes
    4. Provide alternative query or new view
  
  - **Why views are different:**
    - No data loss risk (views don't store data)
    - Easy to recreate if needed
    - Less impact on customers
  
  - **Still recommended:** Mark views as deprecated for one release before dropping, to give customers warning

---

## Notes

This checklist is based on the SOLUTIONS Design Best Practices & Guidance document. It represents the standards for Appian Solutions development with focus on code maintainability, consistency, and readability for handoff to customer development teams.

**Key Principles:**
- Design with the mindset of someone who has never seen the application
- Ensure code is understandable and customizable without reaching back to the original team
- Balance performance, scalability, usability with maintainability and readability

**Automation Summary:**

Throughout this checklist, items marked with **AUTOMATED CHECK AVAILABLE** ✓ can be detected programmatically by the Solutions Intelligence code analyzer. These automated checks help catch common issues early and ensure consistent code quality.

**Categories of Automated Checks:**
1. **Naming Conventions** - Verify objects follow namespace and prefix standards
2. **Code Patterns** - Detect antipatterns, duplicate code, and inefficient queries
3. **Best Practices** - Flag missing null safety, hard-coded text, deprecated functions
4. **Complexity** - Measure nesting depth, local variable count, object size
5. **Configuration** - Verify security groups, process settings, record configuration
