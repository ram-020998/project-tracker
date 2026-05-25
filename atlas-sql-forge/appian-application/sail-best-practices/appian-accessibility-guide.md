# Appian Accessibility (A11Y) Guidelines

Comprehensive accessibility guidelines for Appian SAIL components to ensure interfaces are usable by all users, including those using screen readers and assistive technologies.

## Core Principles

1. **Always provide labels** - Every interactive component needs proper labeling
2. **Provide context** - Use accessibility text to explain purpose and behavior
3. **Keyboard navigation** - Ensure all functionality is keyboard accessible
4. **Screen reader support** - Test with screen readers (JAWS, NVDA, VoiceOver)
5. **Semantic HTML** - Use proper component types for their intended purpose

---

## Grid Components

### a!gridField()

**Purpose**: Display read-only data in tabular format

**Required Accessibility:**

1. **Always set the label parameter**
   - Labels can be collapsed if there's a heading with `a!heading()`
   
2. **Set rowHeader appropriately**
   - If a row CAN be uniquely identified by a cell: set `rowHeader: <column#>`
   - If a row CANNOT be uniquely identified: do NOT set rowHeader
   
3. **Column headers for data columns**
   - Each grid column that contains data or a single form input MUST have column header text
   - Columns with multiple controls (action menu, links, etc.) don't need headers if controls are self-explanatory

4. **Provide context (optional but recommended)**
   - Use `accessibilityText` parameter
   - Use `instructions` parameter
   
5. **Empty grid messaging**
   - Provide business context: "No Line Items Available" (not just "No Items Available")
   
6. **Selectable grids**
   - For empty selectable grids: set `selectable: false` when empty
   - If selection enables external buttons: add accessibility text like "Action buttons before the table become enabled when rows are selected"
   
7. **Buttons in grid**
   - Always set accessibility text on buttons, even when disabled
   - Example: "Move row up", "Move row down", "Delete item"

**Example:**
```sail
a!gridField(
  label: "Purchase Order Line Items",
  labelPosition: "ABOVE",
  accessibilityText: "Select line items to enable bulk actions above the table",
  data: local!lineItems,
  columns: {
    a!gridColumn(
      label: "Item Name",
      value: fv!row.itemName
    ),
    a!gridColumn(
      label: "Quantity",
      value: fv!row.quantity
    ),
    a!gridColumn(
      label: "Actions",
      value: a!buttonWidget(
        label: "Delete",
        accessibilityText: "Delete " & fv!row.itemName,
        saveInto: a!save(local!lineItems, remove(local!lineItems, fv!index))
      )
    )
  },
  rowHeader: 1,
  emptyGridMessage: "No line items have been added"
)
```

### a!gridLayout()

**Purpose**: Editable grid for data entry

**Required Accessibility:**

1. **Always set the label parameter**
   - Labels can be collapsed if there's a heading with `a!heading()`
   
2. **Set rowHeader appropriately**
   - Same rules as `a!gridField()`
   
3. **Column headers for input columns**
   - Each grid column that contains a form input MUST have column header text
   
4. **Empty grid messaging**
   - Provide business context
   
5. **"Add" link specificity**
   - Be specific: "Add Solicitation" (not just "Add Items")
   
6. **Paging on editable grids**
   - Avoid paging if possible
   - If unavoidable: place "Add" link at top, add new rows to top
   
7. **Buttons in grid**
   - Always set accessibility text, even when disabled

**Example:**
```sail
a!gridLayout(
  label: "Employee Information",
  headerCells: {
    a!gridLayoutHeaderCell(label: "First Name"),
    a!gridLayoutHeaderCell(label: "Last Name"),
    a!gridLayoutHeaderCell(label: "Email"),
    a!gridLayoutHeaderCell(label: "Actions")
  },
  rows: a!forEach(
    items: local!employees,
    expression: a!gridRowLayout(
      contents: {
        a!textField(
          label: "First Name " & fv!index,
          labelPosition: "COLLAPSED",
          value: fv!item.firstName,
          saveInto: fv!item.firstName
        ),
        a!textField(
          label: "Last Name " & fv!index,
          labelPosition: "COLLAPSED",
          value: fv!item.lastName,
          saveInto: fv!item.lastName
        ),
        a!textField(
          label: "Email " & fv!index,
          labelPosition: "COLLAPSED",
          value: fv!item.email,
          saveInto: fv!item.email
        ),
        a!buttonWidget(
          label: "Remove",
          accessibilityText: "Remove employee " & fv!item.firstName & " " & fv!item.lastName,
          saveInto: a!save(local!employees, remove(local!employees, fv!index))
        )
      }
    )
  ),
  addRowLink: a!dynamicLink(
    label: "Add Employee",
    saveInto: a!save(local!employees, append(local!employees, 'type!{...}Employee'()))
  ),
  rowHeader: 1
)
```

---

## Icon Components

### a!richTextIcon()

**Purpose**: Display icons with optional interactivity

**Required Accessibility:**

1. **Use altText instead of caption**
   - Only set `altText` when icon is enabled
   - Use `showWhen` to set null when disabled
   
2. **Exception: Use caption for non-universal icons**
   - If icon purpose may not be universally known, use `caption`
   - `altText` and `caption` should NOT be the same
   
3. **Decorative icons**
   - Decorative icons do NOT need `altText`
   
4. **Always use showWhen for visibility**
   - Never show an empty icon

**Examples:**
```sail
/* Interactive icon */
a!richTextIcon(
  icon: "trash",
  altText: if(local!canDelete, "Delete item", null),
  link: if(local!canDelete, a!dynamicLink(...), null),
  color: if(local!canDelete, "NEGATIVE", "SECONDARY")
)

/* Non-universal icon */
a!richTextIcon(
  icon: "custom-workflow",
  caption: "Workflow Status",
  altText: "View workflow details"
)

/* Decorative icon */
a!richTextIcon(
  icon: "check-circle",
  color: "POSITIVE"
  /* No altText - purely decorative */
)
```

---

## Form Input Components

### a!checkboxField()

**Required Accessibility:**

1. **Single checkbox: Do NOT set label**
   - The choice label serves as the label
   - Exception: Some contexts may require it
   
2. **Multiple checkboxes: Always set label**
   - Label describes the group

**Examples:**
```sail
/* Single checkbox */
a!checkboxField(
  choiceLabels: {"I agree to the terms and conditions"},
  choiceValues: {true},
  value: local!agreedToTerms,
  saveInto: local!agreedToTerms
)

/* Multiple checkboxes */
a!checkboxField(
  label: "Select Notification Preferences",
  choiceLabels: {"Email", "SMS", "Push Notifications"},
  choiceValues: {"email", "sms", "push"},
  value: local!preferences,
  saveInto: local!preferences
)
```

### a!radioButtonField()

**Required Accessibility:**

1. **Always set label**
   - Describes the group of options
   
2. **Provide clear choice labels**
   - Each option should be self-explanatory

**Example:**
```sail
a!radioButtonField(
  label: "Priority Level",
  choiceLabels: {"High", "Medium", "Low"},
  choiceValues: {"high", "medium", "low"},
  value: local!priority,
  saveInto: local!priority
)
```

### a!fileUploadField()

**Required Accessibility:**

1. **Always set label**
   
2. **Provide instructions**
   - Explain file requirements (size, type, etc.)
   
3. **Set maxSelections appropriately**
   - Communicate limits clearly

**Example:**
```sail
a!fileUploadField(
  label: "Upload Supporting Documents",
  instructions: "Accepted formats: PDF, DOC, DOCX. Maximum file size: 10MB. You can upload up to 5 files.",
  maxSelections: 5,
  value: local!documents,
  saveInto: local!documents
)
```

### a!dateTimeField()

**Required Accessibility:**

1. **Always set label**
   
2. **Provide format guidance**
   - Use instructions or placeholder
   
3. **Set validations with clear messages**

**Example:**
```sail
a!dateTimeField(
  label: "Appointment Date and Time",
  instructions: "Select a date and time for your appointment",
  value: local!appointmentDateTime,
  saveInto: local!appointmentDateTime,
  validations: if(
    local!appointmentDateTime < now(),
    "Appointment must be in the future",
    null
  )
)
```

---

## Layout Components

### a!stampField()

**Required Accessibility:**

1. **Set contentText for screen readers**
   - Even if using icon only
   
2. **Use appropriate colors**
   - Ensure sufficient contrast

**Example:**
```sail
a!stampField(
  icon: "check-circle",
  contentText: "Approved",
  backgroundColor: "POSITIVE",
  size: "SMALL"
)
```

### a!tagField() / a!tagItem()

**Required Accessibility:**

1. **Provide meaningful tag text**
   - Text should be self-explanatory
   
2. **For removable tags**
   - Ensure remove action is keyboard accessible

**Example:**
```sail
a!tagField(
  tags: a!forEach(
    items: local!selectedUsers,
    expression: a!tagItem(
      text: fv!item.name,
      onRemove: a!save(local!selectedUsers, remove(local!selectedUsers, fv!index))
    )
  )
)
```

### a!cardLayout()

**Required Accessibility:**

1. **Use heading parameter**
   - Provides structure for screen readers
   
2. **Set accessibilityText if needed**
   - Explain card purpose if not obvious

**Example:**
```sail
a!cardLayout(
  heading: "Project Summary",
  contents: {
    /* Card content */
  },
  accessibilityText: "View and edit project summary information"
)
```

### a!sectionLayout() / a!boxLayout() / a!formLayout()

**Required Accessibility:**

1. **Always set label**
   - Can be collapsed if using heading
   
2. **Use proper heading hierarchy**
   - Don't skip heading levels

**Example:**
```sail
a!sectionLayout(
  label: "Contact Information",
  contents: {
    a!textField(label: "Email", ...),
    a!textField(label: "Phone", ...)
  }
)
```

---

## Interactive Components

### a!buttonWidget()

**Required Accessibility:**

1. **Always set label**
   
2. **Set accessibilityText for context**
   - Especially for icon-only buttons
   - Explain what will happen
   
3. **Set even when disabled**
   - Explain why button is disabled

**Examples:**
```sail
/* Text button */
a!buttonWidget(
  label: "Submit Application",
  accessibilityText: "Submit your application for review",
  saveInto: a!submitForm()
)

/* Icon button */
a!buttonWidget(
  icon: "trash",
  accessibilityText: "Delete selected items",
  style: "DESTRUCTIVE",
  saveInto: a!save(local!items, {})
)

/* Disabled button */
a!buttonWidget(
  label: "Approve",
  accessibilityText: if(
    local!canApprove,
    "Approve this request",
    "You do not have permission to approve this request"
  ),
  disabled: not(local!canApprove)
)
```

### Links

**Required Accessibility:**

1. **Provide descriptive link text**
   - Avoid "Click here" or "Read more"
   - Text should make sense out of context
   
2. **For icon links**
   - Set accessibility text

**Examples:**
```sail
/* Good link text */
a!linkField(
  links: a!dynamicLink(
    label: "View employee profile",
    value: local!employeeId,
    saveInto: local!selectedEmployee
  )
)

/* Bad link text */
a!linkField(
  links: a!dynamicLink(
    label: "Click here",  /* ❌ Not descriptive */
    ...
  )
)
```

### a!recordActionField() / Record Actions

**Required Accessibility:**

1. **Provide clear action labels**
   - Describe what the action does
   
2. **Set accessibility text**
   - Provide additional context if needed

**Example:**
```sail
a!recordActionField(
  actions: {
    a!recordActionItem(
      action: 'recordType!{...}Case.actions.approve',
      label: "Approve Case",
      accessibilityText: "Approve this case and notify the requester"
    )
  }
)
```

---

## Charts

**Required Accessibility:**

1. **Always set label**
   
2. **Provide data table alternative**
   - Use `showDataTable: true` when possible
   
3. **Set accessibilityText**
   - Describe key insights from the chart

**Example:**
```sail
a!barChartField(
  label: "Sales by Region",
  accessibilityText: "Bar chart showing sales performance across 5 regions. North region leads with $2.5M in sales.",
  categories: local!regions,
  series: local!salesData,
  showDataTable: true
)
```

---

## Deprecated Components

### Rich Text Headers → Use a!heading()

**Old (Deprecated):**
```sail
a!richTextDisplayField(
  value: a!richTextItem(
    text: "Section Title",
    size: "LARGE",
    style: "STRONG"
  )
)
```

**New (Accessible):**
```sail
a!heading(
  text: "Section Title",
  size: "MEDIUM"
)
```

---

## General Input Field Guidelines

**All input fields should:**

1. **Have clear labels**
   - Describe what input is expected
   
2. **Provide instructions when needed**
   - Format requirements, examples, constraints
   
3. **Show clear validation messages**
   - Explain what's wrong and how to fix it
   
4. **Use required parameter**
   - Mark required fields appropriately
   
5. **Set appropriate placeholders**
   - Show example input format

**Example:**
```sail
a!textField(
  label: "Phone Number",
  instructions: "Enter your 10-digit phone number",
  placeholder: "555-123-4567",
  required: true,
  value: local!phone,
  saveInto: local!phone,
  validations: if(
    len(local!phone) <> 10,
    "Phone number must be exactly 10 digits",
    null
  )
)
```

---

## Testing Checklist

Before releasing an interface, verify:

- [ ] All interactive components have labels
- [ ] All icons have appropriate altText or caption
- [ ] Grid columns have headers
- [ ] Empty states provide context
- [ ] Buttons have accessibility text
- [ ] Links are descriptive
- [ ] Form validation messages are clear
- [ ] Keyboard navigation works throughout
- [ ] Screen reader announces all important information
- [ ] Color is not the only way to convey information
- [ ] Sufficient color contrast (WCAG AA minimum)

---

## Resources

- **WCAG 2.1 Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **Appian Accessibility Documentation**: Check Appian Docs for latest component accessibility features
- **Screen Reader Testing**: Test with JAWS, NVDA (Windows) or VoiceOver (Mac)
