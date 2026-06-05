# Action: Platform Feasibility Check

Evaluate a design mockup against Appian SAIL platform capabilities to determine what's directly achievable, what requires workarounds, and what's not possible — with SAIL-native alternatives for every "not possible" item.

This action uses Aurora Design System docs and the official Appian SAIL documentation for understanding SAIL component capabilities and Atlas MCP tools to find real-world examples of how similar patterns are implemented in existing Appian solutions.

## Reference Sources

- **Aurora Design System**: `https://appian-design.github.io/aurora/` (design patterns, standards, accessibility)
- **Appian SAIL Documentation**: `https://docs.appian.com/suite/help/26.4/sail/home.html` (official component reference, guidelines, patterns)
- **SAIL Component Reference**: `https://docs.appian.com/suite/help/26.4/SAIL_Components.html` (complete list of all available components)

## Prerequisites

- A design mockup (one or more of the following):
  - HTML prototype file
  - Figma description or screenshot
  - SAIL code (existing or generated)
  - Written description of the desired interaction/layout
- Optionally: the target app name (to check existing patterns)

---

## Workflow

### Step 1: Gather the design input

Ask the user for their design mockup. Accept any format:
- **HTML prototype** — read the file and analyze the UI patterns used
- **Screenshot/image** — analyze the visual layout and interactions described
- **SAIL code** — analyze the components and interactions
- **Text description** — parse the described interactions and layouts
- **Figma link/description** — work from the described design

Also ask:
- What interactions does the user expect? (hover effects, drag-and-drop, animations, real-time updates, etc. although only some are possible in SAIL )
- Is this for a dialog, site page, record view, or task form?
- Target app name (optional, for consistency checking)

### Step 2: Load SAIL platform reference (MANDATORY)

Fetch the SAIL Coding Guide to understand the full scope of what's possible:

```
get_git_content("appian-design/aurora", "docs/SAIL_CODING_GUIDE.md")
```

Also fetch component-specific docs based on what the design uses:
```
get_git_content("appian-design/aurora", "docs/layouts/forms.md")
get_git_content("appian-design/aurora", "docs/layouts/grids.md")
get_git_content("appian-design/aurora", "docs/layouts/dashboards.md")
get_git_content("appian-design/aurora", "docs/components/cards.md")
get_git_content("appian-design/aurora", "docs/components/tabs.md")
```

### Step 3: Identify every UI pattern in the design

Break down the design into individual UI patterns/interactions:
- Layout structure (columns, sidebars, headers, panes)
- Navigation patterns (tabs, breadcrumbs, sidebar nav, pagination)
- Data display (grids, cards, KPIs, charts, timelines)
- Form inputs (fields, pickers, uploads, rich text editors)
- Interactions (click, hover, drag, expand/collapse, inline edit)
- Feedback (toasts, banners, progress indicators, loading states)
- Dynamic behavior (conditional visibility, real-time updates, animations)

### Step 4: Classify each pattern

For each identified pattern, classify into one of three categories:

**✅ DIRECTLY ACHIEVABLE** — SAIL has a native component or pattern that does exactly this.
- Map to the specific SAIL component
- Reference the Aurora doc that shows how

**⚠️ ACHIEVABLE WITH WORKAROUND** — SAIL can do this, but not in the obvious way. Requires a creative approach.
- Describe the workaround
- Note any trade-offs (performance, maintainability, accessibility)
- Provide a SAIL code snippet showing the approach

**❌ NOT POSSIBLE IN SAIL** — The platform fundamentally cannot do this.
- Explain why (architectural limitation, not a component limitation)
- Provide the closest SAIL-native alternative
- Rate how close the alternative gets (80% match? 50%?)

### Step 5: Check existing implementations (if app provided)

For patterns classified as "workaround" or "not possible," search Atlas for how existing apps handle similar needs:

```
search_objects(app, "relevant_keyword", "Interface")
get_object_code(app, "found_interface_name")
```

Also check across all apps for common patterns:
```
search_bundles("CaseManagementStudio", "relevant_feature", "page")
search_bundles("ConnectedClaimsManagement", "relevant_feature", "page")
```

### Step 6: Generate the Feasibility Report

Use the following output format for the report:

    # Platform Feasibility Check: [Design Name]

    ## Summary
    - **Total patterns identified**: X
    - ✅ **Directly achievable**: X (Y%)
    - ⚠️ **Achievable with workaround**: X (Y%)
    - ❌ **Not possible**: X (Y%)
    - **Overall feasibility score**: X/10

    ---

    ## ✅ Directly Achievable

    ### [Pattern Name]
    - **Design intent**: [What the designer wants]
    - **SAIL component**: `a!componentName()`
    - **Aurora reference**: `docs/[path]`
    - **Notes**: [Any configuration details]

    ---

    ## ⚠️ Achievable with Workaround

    ### [Pattern Name]
    - **Design intent**: [What the designer wants]
    - **Why it's not straightforward**: [The gap between design and native SAIL]
    - **Workaround approach**: [How to achieve it]
    - **SAIL snippet**: (provide a SAIL code example showing the workaround)
    - **Trade-offs**: [Performance, accessibility, maintainability concerns]
    - **Existing example**: [If found in Atlas — app name + interface name]
    - **Fidelity**: [How close to the original design — 90%? 70%?]

    ---

    ## ❌ Not Possible in SAIL

    ### [Pattern Name]
    - **Design intent**: [What the designer wants]
    - **Why it's not possible**: [Platform limitation]
    - **Closest alternative**: [What SAIL can do instead]
    - **Alternative SAIL snippet**: (provide a SAIL code example of the alternative)
    - **Fidelity**: [How close the alternative gets — 80%? 50%?]
    - **Designer decision needed**: [What to change in the design]

    ---

    ## Recommendations

    ### Design Changes Required
    1. [ ] [Specific change to make the design SAIL-compatible]
    2. [ ] [Another change]

    ### Suggested Approach
    [Overall recommendation for how to approach this design in SAIL —
    which workarounds are worth it, which alternatives to accept]

### Step 7: Save and present

Save the report as `ux-reviews/feasibility-checks/{design-name}-feasibility.md` in the current working directory. Create the folders if they don't exist.

Tell the user:
1. The overall feasibility score
2. Which patterns need design changes (the ❌ items)
3. Which workarounds are worth the complexity vs. accepting the alternative
4. Offer to generate updated SAIL code that implements the feasible version

---

## SAIL Platform Capabilities Reference

Use this as the source of truth when classifying patterns:

### Layout Capabilities
| Capability | Status | Notes |
|---|---|---|
| Multi-column layouts | ✅ | `a!columnsLayout` — up to 6 columns |
| Sidebar + main content | ✅ | `a!sideBarLayout` |
| Header + content | ✅ | `a!headerContentLayout` |
| Tabs | ✅ | `a!tabsField` — horizontal only |
| Vertical tabs | ❌ | Use sidebar navigation instead |
| Sticky headers | ✅ | `isTitleBarFixed: true` on wizards/forms |
| Sticky footer buttons | ✅ | `isButtonFooterFixed: true` |
| Collapsible sections | ✅ | `a!sectionLayout` with `isCollapsible` |
| Accordion (one open at a time) | ⚠️ | Requires local variable to track open section |
| Split pane (resizable) | ❌ | Fixed column widths only |
| Masonry/Pinterest layout | ❌ | Use columns with cards instead |
| Full-bleed/edge-to-edge | ⚠️ | Limited — `contentsWidth: "FULL"` on some layouts |

### Navigation Capabilities
| Capability | Status | Notes |
|---|---|---|
| Breadcrumbs | ✅ | Rich text with links (Aurora pattern) |
| Pagination | ✅ | Built into `a!gridField` |
| Custom pagination | ⚠️ | Rich text links with manual logic |
| Infinite scroll | ❌ | Use pagination instead |
| Anchor links (jump to section) | ❌ | Use tabs or collapsible sections |
| Back button / browser history | ⚠️ | Limited — `a!urlInfoField` for URL params |
| Wizard/stepper | ✅ | `a!wizardLayout` with milestones |
| Deep linking | ⚠️ | URL parameters only, no hash routing |

### Interaction Capabilities
| Capability | Status | Notes |
|---|---|---|
| Click actions | ✅ | Links, buttons, card links |
| Hover effects | ❌ | No hover-only interactions in SAIL |
| Drag and drop | ❌ | Use up/down links for reordering |
| Inline editing (single field) | ✅ | Toggle between read/edit with local variable |
| Inline editing (grid cells) | ⚠️ | Editable grid, but limited styling control |
| Double-click | ❌ | Not supported |
| Right-click context menu | ❌ | Not supported |
| Keyboard shortcuts | ❌ | Not supported (except native browser) |
| Swipe gestures | ❌ | Not supported |
| Long press | ❌ | Not supported |
| Multi-select in grid | ✅ | `selectionStyle: "CHECKBOX"` |
| Bulk actions | ✅ | Buttons enabled by grid selection |
| Expand/collapse rows | ⚠️ | Not native — use nested sections or drill-in |
| Modal dialogs | ✅ | `a!dialogLayout` via button/link |
| Inline dialogs | ✅ | Aurora inline dialog pattern |
| Toast notifications | ❌ | Use `a!messageBanner` instead |
| Tooltips | ✅ | `helpTooltip` parameter on most components |
| Custom tooltips (rich content) | ❌ | Text-only tooltips |

### Data Display Capabilities
| Capability | Status | Notes |
|---|---|---|
| Tables/grids | ✅ | `a!gridField` with full features |
| Editable grids | ✅ | `a!gridLayout` for inline editing |
| Cards | ✅ | `a!cardLayout` with many styles |
| Card groups (equal sizing) | ✅ | `a!cardGroupLayout` for uniform card display |
| Card choices (selection) | ✅ | `a!cardChoiceField` with bar/tile templates |
| KPI/metric cards | ✅ | `a!kpiField` (record-type powered) or `a!stampField` + Aurora pattern |
| Gauge (circular progress) | ✅ | `a!gaugeField` with fraction/percentage/icon |
| Charts (bar, line, pie, area, column, scatter) | ✅ | Dedicated chart components for each type |
| Gantt chart | ❌ | Use milestone or custom grid |
| Timeline/activity feed | ✅ | `a!eventHistoryListField` for record event history |
| Custom timeline | ⚠️ | Custom build with cards + rich text for non-record data |
| Tree view | ⚠️ | `a!hierarchyBrowserFieldTree` for hierarchical data |
| Org chart | ✅ | `a!orgChartField` for user hierarchy |
| Kanban board | ❌ | Use columns with card groups (static only) |
| Calendar view | ⚠️ | Plugin available, limited customization |
| Maps | ⚠️ | Plugin available, limited interactivity |
| Progress bars | ✅ | `a!progressBarField` |
| Badges/tags | ✅ | `a!tagField` with conditional colors |
| Milestones/steppers | ✅ | `a!milestoneField` for process steps |
| Headings (semantic) | ✅ | `a!headingField` with color, size, weight, heading tags |
| Message banners | ✅ | `a!messageBanner` with screen reader announcements |
| Avatars | ⚠️ | `a!imageField` with circular shape or `a!userImage` |
| Rich text formatting | ✅ | `a!richTextDisplayField` with items |
| Document viewer | ✅ | `a!documentViewerField` for inline doc display |
| Video player | ✅ | `a!videoField` for embedded video |
| Web content (iframe) | ✅ | `a!webContentField` for external content |
| Billboard/hero sections | ✅ | `a!billboardLayout` with overlays (bar, column, full) |

### Form Capabilities
| Capability | Status | Notes |
|---|---|---|
| Text input | ✅ | `a!textField` |
| Paragraph/multiline | ✅ | `a!paragraphField` (4000 char limit) |
| Dropdown | ✅ | `a!dropdownField` |
| Multi-select dropdown | ✅ | `a!multipleDropdownField` |
| Picker (search-as-you-type) | ✅ | `a!pickerFieldUsers`, `a!pickerFieldRecords`, `a!pickerFieldCustom` |
| Record picker | ✅ | `a!recordPickerField` — autocomplete filtered by record type |
| Date picker | ✅ | `a!dateField` |
| Date and time picker | ✅ | `a!dateTimeField` |
| Date range picker | ⚠️ | Two separate date fields |
| Time picker | ✅ | `a!timeField` |
| Integer input | ✅ | `a!integerField` |
| Decimal input | ✅ | `a!floatingPointField` |
| Encrypted text | ✅ | `a!encryptedTextField` — encrypted at rest |
| File upload | ✅ | `a!fileUploadField` |
| Signature capture | ✅ | `a!signatureField` |
| Toggle/switch | ✅ | `a!toggleField` |
| Boolean checkbox | ✅ | `a!booleanCheckboxField` — single true/false |
| Radio buttons | ✅ | `a!radioButtonField` |
| Checkboxes | ✅ | `a!checkboxField` |
| Card choices | ✅ | `a!cardChoiceField` — select from styled cards |
| Barcode scanner | ✅ | `a!barcodeField` — scan or manual entry |
| Styled text editor (rich) | ✅ | `a!styledTextEditorField` — HTML formatting |
| Slider/range | ❌ | Use numeric field with validation |
| Color picker | ❌ | Use dropdown with color options |
| Auto-save | ⚠️ | Requires custom timer-based approach |
| Conditional field visibility | ✅ | `showWhen` parameter |
| Field-level validation | ✅ | `validations` parameter |
| Cross-field validation | ✅ | `validations` with references to other fields |

### AI & Chat Capabilities
| Capability | Status | Notes |
|---|---|---|
| Chat interface | ✅ | `a!chatField` — real-time send/receive messages |
| Data fabric chatbot | ✅ | `a!dataFabricChatbotField` — chat with data fabric |
| Documents chatbot | ✅ | `a!documentsChatbotField` — Q&A over documents |
| Records chatbot | ✅ | `a!recordsChatbotField` — chat about a record |

### Dynamic Behavior
| Capability | Status | Notes |
|---|---|---|
| Conditional visibility | ✅ | `showWhen` on any component |
| Conditional styling | ✅ | `a!if()` for style parameters |
| Loading indicators | ⚠️ | No native spinner — use `a!progressBarField` |
| Real-time updates | ❌ | No WebSocket/push — requires page refresh |
| Animations/transitions | ❌ | Not supported |
| Lazy loading | ❌ | All content loads at once |
| Optimistic updates | ❌ | Server round-trip required |
| Undo/redo | ❌ | Must implement manually with local variables |

---

## Rules

1. **Always load SAIL_CODING_GUIDE.md** — it defines what's syntactically possible
2. **Classify every pattern** — nothing should be left as "maybe"
3. **Provide alternatives for every ❌** — never just say "can't do it"
4. **Include SAIL snippets** — show how workarounds actually work in code
5. **Check Atlas for real examples** — if a workaround exists in a real app, reference it
6. **Rate fidelity honestly** — if the alternative is only 50% as good, say so
7. **Separate "hard to do" from "impossible"** — workarounds are fine if the trade-offs are acceptable
8. **Consider accessibility** — a workaround that breaks accessibility is not a valid workaround
9. **Don't invent SAIL capabilities** — only reference documented, real SAIL functions
10. **Prioritize designer decisions** — clearly state what needs to change in the design
11. **Consider the context** — dialog vs. site page vs. record view affects what's possible
12. **Be specific about limitations** — "no hover" is more useful than "limited interactivity"
