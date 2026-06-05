# QE Knowledge Base — RM (Requirements Management)

This steering file provides solution-specific context for the QE Agent when testing the **RM (Requirements Management)** solution, also known as **RequirementsManagement** in the codebase.

---

## 1. Solution Overview

| Field | Value |
|-------|-------|
| Solution Name | Appian Requirements Management (RM) |
| Application Prefix | AS_RM |
| Jira Project | GAMS |
| Jira Components | See Section 21 for full component list |
| Team | Requirements and Award Management |
| Sites | Requirements Management, Requirements Management Settings |
| UAM Site Path | `/suite/sites/user-access` (NOT `user-access-management`) |
| Google Chat Space ID | spaces/AAAAuo-nqqs |

### Business Context

RM streamlines acquisition requirement processes for government organizations. It enables requestors to create, manage, and track procurement requirements through their lifecycle — from initial need identification through market research, document creation, review/approval, and handoff to contracting (via CW or AM integration). Key capabilities include AI-assisted requirement creation, intelligent PSC/NAICS code classification, ProcureSight market research integration, AI Document Builder, configurable checklists, and SharePoint document collaboration.

### Requirement Statuses

| Status | Description |
|--------|-------------|
| Draft | Initial state after creation |
| Review | Requirement submitted for review |
| Submitted | Requirement submitted to contracting |
| Assigned | Requirement assigned to contracting personnel |
| Accepted | Requirement accepted and ready for procurement |
| Inactive | Requirement marked as inactive |

---

## 2. Test Environment

| Field | Value |
|-------|-------|
| Environment Name | RM Standalone Test (MariaDB) |
| Site URL (RM Standalone) | https://eng-test-fed-aq-rm-test2.appianpreview.com |
| Site URL (Shared/All Apps) | https://eng-test-fed-aq-test2.appianpreview.com |
| Site Name | Requirements Management |
| Database | MariaDB |

### Environment Selection Rules

There are two test environments available for RM testing. **Randomly alternate** between them for each test execution, with the following constraints:

| Environment | URL | When to Use |
|-------------|-----|-------------|
| RM Standalone (rm-test2) | `eng-test-fed-aq-rm-test2.appianpreview.com` | RM-only testing, ProcureSight, AIDB. **Atlas Data Generator MCP is configured for this environment only** — always use rm-test2 when generating test data via the Data Generator. |
| Shared/All Apps (aq-test2) | `eng-test-fed-aq-test2.appianpreview.com` | Cross-solution testing (RM + UAM, RM + CW, RM + AM, RM + GSS). Use this whenever the test involves multiple solutions. |

**Key rules:**
- **Cross-solution tests → always use aq-test2.** If the ticket involves RM and another solution (UAM, CW, AM, GSS), use the shared environment.
- **Data Generator → always use rm-test2.** The Atlas Data Generator MCP is only configured for rm-test2. When test data needs to be created via `create_record`, it will be on rm-test2, so test on rm-test2 in that case.
- **RM-only tests → pick randomly** between the two environments.
- **Credentials are the same** for both environments.

### Navigation to RM

1. Login at the chosen site URL
2. Navigate to the "Requirements Management" site
3. The landing page shows the Home page with My Requirements and My Tasks tabs

---

## 3. Test Credentials (Combined Test)

**⚠️ MANDATORY RULE: For RM testing, ALWAYS use the credentials listed in this table below. Do NOT look up credentials from the Google Sheets credentials spreadsheet. Do NOT call `read_sheet_values` for RM credentials. The credentials in this section are the single source of truth for all RM test execution.**

| Role | Username | Password |
|------|----------|----------|
| Requestor | RMRequestor | appian23 |
| Requestor Manager | RMRequestorManager | appian23 |
| Contracting Manager | RMContractingManager | appian23 |
| Contracting Officer | RMContractingOfficer | appian23 |
| Contract Specialist | RMContractSpecialist | appian23 |
| Admin | RMAdmin | appian23 |
| IT | IT1 | appian20 |
| Policy | Policy1 | appian20 |
| Legal | Legal1 | appian20 |

---

## 4. Role Permissions Summary (RM 2.6)

**Source:** RM Security Matrix spreadsheet — https://docs.google.com/spreadsheets/d/1T2haLM2PHYrzyJuh2BBYfhCtH3wBauPM8cBkz6axBDI/edit

**Roles:** Requestor, Requestor Manager, Contracting Manager, Contracting Officer, Contract Specialist, IT/Policy/Legal Group User, Requirement Settings Site Access Users, Admin

**Access Level Legend:**

| Code | Meaning |
|------|---------|
| a | Requirements and tasks assigned to the user |
| b | Requirements assigned to the department |
| c | All requirements |
| e | Documents uploaded by the requestor or the requestor manager |
| f | All documents/templates |
| g | Collections/Documents created by the user |
| h | Messages created by the user |
| i | View only |
| j | View all (only released awards' links are functional) |
| (blank) | No Access |

### 4.1 Home Page — My Requirements & My Tasks

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Requirements List | a | b | c | a | a | ❌ | ❌ | ❌ |
| Create Requirement | c | c | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Update Requirement | a | b | c | a | a | ❌ | ❌ | ❌ |
| Add Checklist | a | b | c | a | a | ❌ | ❌ | ❌ |
| Mark Inactive | a | b | c | a | a | ❌ | ❌ | ❌ |
| Reassign | ❌ | b | c | ❌ | ❌ | ❌ | ❌ | ❌ |
| Requirement Summary | a | b | c | a | a | ❌ | ❌ | ❌ |
| Tasks | a | o | o | a | a | a | o | a |
| Mark Not Needed | a | o | o | a | a | a | o | a |
| Claim Item | a | o | o | a | a | a | o | a |
| Reassign Task | a | o | o | a | a | a | ❌ | a |

### 4.2 Forecasts (NEW in RM 2.6)

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Forecasts List | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Create Forecast | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Forecast Summary | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Update Forecast | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Cancel Forecast | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Initiate Requirement | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |

### 4.3 Requirements Tab — Site & Feature Access

### Requirement Record Tabs

| Tab | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|-----|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Summary | c | c | c | c | c | c | o | c |
| Related Awards (AM) | ❌ | j | c | c | c | ❌ | ❌ | ❌ |
| Related Procurements (GCW) | i | i | c | c | c | i | ❌ | ❌ |
| Edit from Summary | a | b | c | a | a | ❌ | ❌ | ❌ |
| Addresses | c | c | c | c | c | c | o | c |
| Additional Information | c | c | c | c | c | c | o | c |
| Line Items Grid | c | c | c | c | c | c | ❌ | c |
| Edit Line Items | c | c | c | c | c | c | ❌ | c |
| Research — AI Collection | c | c | c | c | c | c | o | c |
| Research — Saved User | c | c | c | c | c | c | o | c |
| Research — Best In Class | c | c | c | c | c | c | o | c |
| Research — Search | c | c | c | c | c | c | o | c |
| Documents — Grid | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | c |
| Documents — Upload | a | a | ❌ | ❌ | ❌ | ❌ | ❌ | c |
| Documents — AI (Summarize/Chat) | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | c |
| Documents — Download | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | c |
| Documents — Add Reviews | a | a | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Documents — View Review Process | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Documents — Update in SharePoint | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Documents — Finalize from SharePoint | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Documents — Upload to SharePoint | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Documents — Delete | e | e | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Contract File — Grid | ❌ | ❌ | f | f | f | ❌ | ❌ | c |
| Contract File — Upload | ❌ | ❌ | c | a | a | ❌ | ❌ | c |
| Contract File — AI (Summarize/Chat) | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — Download | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — Move | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — Add Reviews | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — View Review Process | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — Update in SharePoint | ❌ | ❌ | a | a | a | ❌ | ❌ | c |
| Contract File — Finalize from SharePoint | ❌ | ❌ | a | a | a | ❌ | ❌ | c |
| Contract File — Upload to SharePoint | ❌ | ❌ | c | c | c | ❌ | ❌ | c |
| Contract File — Delete | ❌ | ❌ | c | a | a | ❌ | ❌ | c |
| Contract File — Edit Document | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Contract File — Send to Documents | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| AI Document Builder — Drafts Subtab | g | g | g | g | g | g | ❌ | ❌ |
| Tasks History | g | g | g | g | g | g | o | c |
| Requirement History | c | c | c | c | c | c | o | c |
| Messages — Send Message | c | c | c | c | c | c | o | c |
| Messages — Draft (Create/Edit/Delete) | h | h | h | h | h | h | o | h |

### Related Actions (Requirement Record)

| Action | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|--------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Update Requirement | a | b | c | a | a | ❌ | o | ❌ |
| Upload Documents | a | b | c | a | a | ❌ | o | ❌ |
| Submit Document For Review | c | c | c | c | c | c | o | c |
| Add Item (Line Item) | b | b | c | c | c | ❌ | o | ❌ |
| Add Checklist | b | b | c | c | c | ❌ | o | ❌ |
| Submit for Review | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Submit to Contracting | c | c | c | c | c | ❌ | ❌ | ❌ |
| Edit Line Items | c | c | c | a | a | ❌ | ❌ | ❌ |
| Mark Inactive | c | c | c | c | c | c | o | ❌ |
| Reassign Requirement | a | b | a | ❌ | ❌ | ❌ | ❌ | ❌ |
| Review Requirement | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Assign Requirement | ❌ | a | c | ❌ | ❌ | ❌ | ❌ | ❌ |
| Copy Requirement | c | c | c | c | c | c | ❌ | ❌ |
| Create Document | a | b | c | a | a | ❌ | ❌ | ❌ |

### 4.4 Directory (People & Locations)

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Contact List | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Add Contact | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Update Contact | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Users List | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Update My Information | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Locations List | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Add/Update Location | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 4.5 Messages Tab

All roles have access to the Messages Tab (✅ for all).

### 4.6 Reports Tab

All roles have access to the Reports Tab (✅ for all).

### 4.7 ProcureSight Tab

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Search | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Save to/Remove from Requirement | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Add to/Remove from Collection | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create Collection | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit Collection | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delete Collection | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Procurement Summary | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Procurement Documents | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 4.8 Procurement AI Copilot

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Procurement AI Copilot | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Analytics Dashboard | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| AI Copilot — Analytics Dashboard | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| AI Copilot — Document Database | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| AI Copilot — Settings | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |

### 4.9 AI Document Builder Tab

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Create New Document | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create New Template | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 4.10 RM Settings Site

| Feature | Requestor | Req Manager | Contracting Mgr | CO | CS | IT/Policy/Legal | Settings Users | Admin |
|---------|-----------|-------------|-----------------|----|----|-----------------|----------------|-------|
| Settings Site Access | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 5. Core Workflow: Create Requirement

### 5.1 Create Requirement — AI-Assisted

**Trigger:** Requestor or Requestor Manager clicks "CREATE REQUIREMENT" on the Home page.

**Prerequisites:**
- User must be in `Requestor` or `Requestor Manager` group
- AI-Assisted Requirement Creation toggle must be enabled by admin

**Steps:**
1. Enter natural language description in the Description field
2. (Optional) Expand "Key Information to Include" for guidance
3. Click NEXT
4. Review AI-populated fields across subtabs:
   - **Requirement Setup** — Title, Description, Type (New/Modification), Category, Priority, Dates
   - **DoDAAC & POC** — Department of Defense Activity Address Code, Point of Contact
   - **Codes** — PSC and NAICS codes (semantic search)
   - **Funding** — Estimated Total Contract Value, Base Period Value, Committed Award Amount, Fiscal Year Amount
   - **Addresses** — Location Type, DoDAAC, Address Type, POC
   - **Additional Information** — Organization-specific questionnaire responses
5. Click CREATE
6. Confirmation screen shows AI Market Deep Dive progress (Conducting Research → Creating Collection → Drafting Report)
7. Options: GO TO RESEARCH, GO TO SUMMARY, or CLOSE

### 5.2 Create Requirement — Manual

**Trigger:** User clicks "CREATE REQUIREMENT" then selects "use the standard form"

**Form Tabs:**
1. **Requirement Setup** — Title (required), Description (required), Type, Category, Priority, Dates
2. **DoDAAC & POC** — DoDAAC search/select, Point of Contact search/select
3. **Codes** — PSC codes (semantic search), NAICS codes (semantic search)
4. **Funding** — Estimated Total Contract Value, Base Period Value, Committed Award Amount, Fiscal Year Amount, Fiscal Year
5. **Addresses** — Location Type, DoDAAC, Address Type, POC Name, POC Type
6. **Additional Information** — Configurable questionnaire

### 5.3 Create Requirement Form Fields

| Field | Type | Required | Section | Notes |
|-------|------|----------|---------|-------|
| Title | Text | Yes | Requirement Setup | Requirement title |
| Description | Text area | Yes | Requirement Setup | Description of goods/services |
| Type | Dropdown | Yes | Requirement Setup | New or Modification |
| Category | Dropdown | Yes | Requirement Setup | Facilities, IT Hardware, IT Services, IT Software, Telecom, Other |
| Priority | Dropdown | Yes | Requirement Setup | Configurable priority values |
| Requested Award Date | Date picker | No | Requirement Setup | Expected award date |
| Delivery Type | Dropdown | Conditional | Requirement Setup | "Date or Dates" or "Lead Time" (for goods categories) |
| POP Begin | Date picker | Conditional | Requirement Setup | For service categories |
| POP End | Date picker | Conditional | Requirement Setup | For service categories |
| DoDAAC | Auto-suggest | No | DoDAAC & POC | Department of Defense Activity Address Code |
| Point of Contact | Auto-suggest | No | DoDAAC & POC | POC for the requirement |
| PSC Code | Semantic search + radio | No | Codes | Product Service Code |
| NAICS Code | Semantic search + radio | No | Codes | North American Industry Classification System |
| NIGP Codes | Manual entry | No | Codes | Visible only if PSC codes disabled; max 10 |
| Estimated Total Contract Value | Currency | No | Funding | Overall contract value |
| Estimated Base Period Value | Currency | No | Funding | Base period value |
| Committed Award Amount | Currency | No | Funding | Total committed funds |
| Estimated Fiscal Year Amount | Currency | No | Funding | First fiscal year amount |
| Fiscal Year | Dropdown | No | Funding | Fiscal year selection |

### 5.4 Category-Based Date Behavior

| Category Type | Date Fields Shown |
|---------------|-------------------|
| Goods (Facilities, IT Hardware) | Requested Award Date, Delivery Type (Date or Dates / Lead Time) |
| Services (IT Services, IT Software, Telecom) | Requested Award Date, POP Begin, POP End |
| Other | Requested Award Date, Delivery Type |

---

## 6. Core Workflow: Manage Requirements

### 6.1 Requirement Record Tabs

| Tab | Description |
|-----|-------------|
| Summary | Key details, related procurements, timeline, tasks, funding, contacts |
| Addresses | Physical address and contact details for delivery |
| Additional Information | Organization-specific questionnaire responses |
| Line Items | View, add, update, duplicate, or delete line items |
| Research | AI Research Collection, Saved User Research, Best in Class, ProcureSight Search |
| Documents | Requestor-visible document management (upload, preview, edit, AI summary) |
| Contract File | Contracting personnel document management |
| Messages | Internal messaging and communication |
| Checklist | Task progress and status overview |
| Task History | Audit log of all task actions |
| Requirement History | Audit log of all requirement actions |

### 6.2 Related Actions

| Action | Description |
|--------|-------------|
| Update Requirement | Edit requirement details via wizard |
| Submit to Contracting | Submit requirement to contracting team |
| Create Document | Create document using AI or from pre-approved template |
| Upload Documents | Upload files to requirement |
| Submit for Review | Submit requirement for group review |
| Review Requirement | Approve, Request Changes, or Reject |
| Mark Inactive | Deactivate the requirement |
| Reassign Requirement | Reassign to another requestor |
| Copy Requirement | Duplicate requirement details |
| Add Checklist | Set up task checklist |
| Add Item | Add line items |
| Edit Line Items | Modify existing line items |

### 6.3 Line Items

**Create Line Item Tabs:**
1. **Details** — Item Number, Title, Description, Option, Type, Delivery Date
2. **PSC Codes** — Semantic search for PSC codes
3. **Pricing** — Pricing Arrangement, Unit of Measure, Quantity, Unit Price

**Line Item Actions:** Add, Update, Delete, Duplicate

### 6.4 Document Management

**Supported File Types:** PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX
**Upload Limit:** Up to 15 documents at a time, max 4 MB each

**Document Actions:**
- Upload Documents
- Preview (PDF viewer for PDFs, download for other types)
- Edit in SharePoint
- Finalize from SharePoint
- Ask AI (document summary and chat)
- Move (change folder location)
- Download
- Delete
- Create Review Process

### 6.5 AI Document Builder

**Two paths for document creation:**

1. **Create Document using AI:**
   - Select template → Provide context documents (Select from requirements or Upload) → Enter Document Name → GENERATE DRAFT
   - Draft statuses: Drafting → Draft Generated → In Progress → Published
   - Edit with AI Drafting Mode (Template Assistant or Editing Assistant)
   - Finalize and Export → Send to Documents

2. **Create Document from Pre-Approved Template:**
   - Select template (Capabilities Templates, Statement of Work, Performance Work Statement)
   - Auto-populate with requirement data
   - Open in SharePoint → Edit → Finalize

### 6.6 Research Tab

| Section | Description |
|---------|-------------|
| AI Research Collection | PSE AI Research Agent results — Summary, Bookmarks, Attachments |
| Saved User Research | User-saved procurements, attachments, vendors from ProcureSight search |
| Best in Class | BIC contract recommendations based on PSC code |
| Search | ProcureSight-powered search for procurements, vendors, protests, codes |

### 6.7 Messages

- Compose, view, and respond to internal messages
- Attach documents to messages
- Thread-based communication

### 6.8 Checklist & Tasks

- Configurable checklists with automated task assignment
- Task types: Attach, Document, Review, and custom types
- Task actions: Claim Task, Mark Not Needed, Reassign, Edit Dates
- Bulk task actions supported

---

## 7. Test Plans

### 7.1 RM 2.6 Release Test Plan (GAMS-8042)

**Test Plan Key:** GAMS-8042
**Test Plan Name:** RM 2.6 Release Test Plan
**Status:** Closed

### 7.2 RM 2.5 Release Test Plan (GAMS-7764)

**Test Plan Key:** GAMS-7764
**Test Plan Name:** RM 2.5 Release Test Plan
**Status:** Backlog

### 7.3 RM 2.4 Release Test Plan (GAMS-6962)

**Test Plan Key:** GAMS-6962
**Test Plan Name:** RM 2.4 Release Test Plan
**Fix Version:** RM 2.4 (released 2026-03-02)
**Status:** Ready

### 7.4 RM 2.2 Test Plan (GAMS-6961)

**Test Plan Key:** GAMS-6961
**Test Plan Name:** RM 2.2 Test Plan
**Fix Version:** RM 2.2 (released 2025-03-07)
**Status:** Closed

### 7.5 RM 2.1 Test Strategy (GAM-16916)

**Test Plan Key:** GAM-16916
**Test Plan Name:** RM 2.1 Test strategy
**Status:** Submitted

### 7.6 RM 2.0 Feature Test Strategy (GAM-15411)

**Test Plan Key:** GAM-15411
**Test Plan Name:** RM 2.0: Feature Test Strategy
**Status:** In Progress

### 7.7 RM SafetyNet Test Plan — OWL (GAM-12998)

**Test Plan Key:** GAM-12998
**Test Plan Name:** RM SafetyNet test plan - OWL
**Status:** Submitted

---

## 8. Key Test Cases

| # | Key | Summary | Component | Status |
|---|-----|---------|-----------|--------|
| 1 | GAMS-8048 | RM: AI Market Research from Requirement - End to End | RM: AI Market Research | Ready |
| 2 | GAMS-7968 | Test RM: AI Requirement Creation | RM: Create Requirement using AI | Ready |
| 3 | GAMS-7801 | RM: Create document from predefined templates | RM: Create document | Closed |
| 4 | GAMS-7767 | RM: Verify the new Create document from template task | RM: Create document | Backlog |
| 5 | GAMS-7542 | RM: Create document using AI/from templates | RM: Create document | Backlog |
| 6 | GAMS-7105 | RM: Search for protest, Vendors, Codes in ProcureSight | RM: Procuresight | Closed |
| 7 | GAMS-7009 | RM: Natural language input for PSC and NAICS codes | RM: Add New Requirement | Ready |
| 8 | GAMS-7006 | RM: ProcureSight Search and Add/Remove procurements/vendors | RM: Procuresight | Ready |
| 9 | GAMS-6685 | RM: AI document summary and chat about document | RM: Document Summary | Ready |
| 10 | GAMS-5775 | RM: Access document builder | RM: Document Summary | Ready |
| 11 | GAMS-5463 | Admin: Switch AI options using solutions hub toggle for RM | RM: Requirements Management Site | Ready |
| 12 | GAMS-2685 | RM CO/CS: Verify Solicitation Creation from a Requirement | RM: Requirements Management Site | Ready |
| 13 | GAMS-2686 | RM CO/CS: Verify the RM/AM integration | RM: Requirements Management Site | Ready |
| 14 | GAMS-3093 | AM: RM Integration End to End Test for Solicitation | — | Ready |
| 15 | GAMS-3038 | AM: RM Integration End to End Test for Award | — | Ready |
| 16 | GAMS-2394 | RM: Verify Edit Related action and edit documents in SharePoint | Document Tab, Contract File | Backlog |
| 17 | GAMS-2637 | RM: Verify document folders in SharePoint | Document Tab | Ready |
| 18 | GAMS-2402 | RM: Verify document upload and edit in SharePoint | Document Tab, Contract File | Ready |
| 19 | GAMS-2408 | RM Admin: Delete checklist | Checklists, Settings site | Ready |
| 20 | GAMS-2430 | RM SafetyNet: Verify line Items and delivery | RM Line Item | Ready |
| 21 | GAMS-2523 | RM: Verify Line Item Metrics | RM Line Item | Ready |
| 22 | GAMS-2562 | RM: Verify AI Copilot application security & RM Copilot | RM AI Copilot | Ready |
| 23 | GAMS-2605 | RM Admin: Verify Creation/deletion of Questions & Questionnaire | Additional Questions | Ready |
| 24 | GAMS-2489 | RM: Verify questionnaire responses copied for copy requirement | RM: Requirements Management Site | Ready |
| 25 | GAMS-2373 | RM: Verify Procurement summary for ProcureSight search results | RM Procuresight | Ready |

---

## 9. Xray Test Repository

**Repository Folder:** `RM` (Folder ID: `695f88f82c8251118677187b`)
**URL:** https://appian-eng.atlassian.net/projects/GAMS?selectedItem=com.atlassian.plugins.atlassian-connect-plugin:com.xpandit.plugins.xray__testing-board#!page=test-repository&selectedFolder=695f88f82c8251118677187b

All RM test cases live under this folder in the Xray test repository. When creating new test cases, place them in the appropriate subfolder under RM.

---

## 10. Open Bugs Query

To find open bugs for RM, use this JQL:

```
type = Bug AND "Team[Team]" = db58b686-81d7-461f-8d25-68cc808df6d4 and summary !~ "AM" and status!=Closed and component NOT IN ("3.8 AM: Accessibility") ORDER BY created DESC
```

### Known Open Bugs

| Key | Summary | Priority | Component | Status |
|-----|---------|----------|-----------|--------|
| GAMS-8586 | Requirement Smart Search Not Working | Not Set | RM: Requirements Management Site | Backlog |
| GAMS-8454 | Create document from template task assigned to IT/Policy/Legal not completing | Not Set | RM: Create document | Backlog |
| GAMS-8196 | Validation banner in requirement creation missing section name | Not Set | RM: Create Requirement using AI | Backlog |
| GAMS-8195 | Field validation for optional Requested Award Date allows invalid data | Not Set | RM: Create Requirement using AI | Backlog |
| GAMS-7896 | Send to documents from drafts tab fails with 1000 char description | Not Set | RM: AI Document Builder | Backlog |
| GAMS-7753 | Edit option not available until full page refresh; grid refresh not working | Not Set | RM: AI Document Builder | Backlog |
| GAMS-7380 | Content added to interface behind user's perspective (a11y) | Not Set | RM: Accessibility | Backlog |
| GAMS-7018 | Requirement Review Task Not Recreating After Rejection and Reassignment | Medium | RM: Requirements Management Site | Backlog |
| GAMS-6971 | Finalize action not displayed if document updated more than once | Not Set | RM: Document Summary | Backlog |
| GAMS-5103 | Slowness in SharePoint Update action | Not Set | Document Tab | Backlog |
| GAMS-5102 | Cannot regenerate completed tasks with existing due dates | Not Set | Checklist Grid | Backlog |
| GAMS-5094 | User able to add custom task with duplicate name | Not Set | Checklist Setup interface | Backlog |
| GAMS-5077 | Checklist tasks order not retained after 'Update' action | Not Set | Checklists (Settings) | Backlog |
| GAMS-5118 | Removal of selected task in different pages redirects to first page | Not Set | Checklists (Settings) | Backlog |
| GAMS-5065 | NAICS record syncs null data from 3rd party app | Not Set | Create New Requirement Interface | Backlog |
| GAMS-5136 | AI Doc Chat - Button focus indicator inadequate color contrast (a11y) | Not Set | RM: Accessibility | Backlog |
| GAMS-5135 | RM Copilot - Decorative document icon has text alternative (a11y) | Not Set | RM: Accessibility | Backlog |
| GAMS-5150 | RM Copilot - Icon has incorrect text alternative (a11y) | Not Set | RM: Accessibility | Backlog |
| GAMS-5146 | AI Doc Chat - Large text insufficient color contrast (a11y) | Not Set | RM: Accessibility | Backlog |

**Note:** Check this list before creating new bugs to avoid duplicates. Use the JQL above to get the latest open bugs at test time.

---

## 11. Cross-Application Dependencies

RM integrates with these solutions:

| Solution | Integration |
|----------|-------------|
| GCW (Contract Writing) | Create solicitations from accepted requirements; requirement data auto-populates solicitation fields; bidirectional linking |
| AM (Award Management) | Create awards directly from accepted requirements; line items and documents copied; bidirectional linking |
| GSS (Source Selection) | Evaluation creation from requirements via solicitation flow |
| AIDB (AI Document Builder) | AI-powered document generation from requirement context |
| ProcureSight (Plus/Enterprise) | Market research, procurement search, vendor search, AI Copilot, AI Market Deep Dive Agent |

### Key Integration Points

- **RM → CW:** When a requirement reaches "Accepted" status, users can create solicitations in CW. Requirement data (line items, documents, codes) transfers automatically.
- **RM → AM:** Users can create awards directly from accepted requirements. All relevant data including line items and documents are copied.
- **ProcureSight:** Embedded search within RM for procurements, vendors, protests, and codes. AI Research Agent conducts automated market research on requirement creation.
- **SharePoint:** Document collaboration via SharePoint integration for editing and finalizing documents.

---

## 12. RM Documentation Reference

**Official Appian Docs:** https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/appian-requirement-management-home.html

Key documentation pages:
- [Home Page Overview](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-home-page.html) — My Requirements, My Tasks, navigation
- [Create a New Requirement](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-create-a-new-requirement.html) — AI-assisted and manual creation
- [Manage Requirements](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-manage-requirements.html) — Record tabs, related actions, documents, research
- [Manage Checklists](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-manage-checklists.html) — Task setup and management
- [Configure RM Settings](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-access-rm-settings.html) — Admin configuration
- [Modifying Dropdowns](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-modify-dropdown-lists.html) — Reference data configuration
- [Configure Codes](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-configure-codes.html) — PSC/NAICS code configuration
- [Configure Questionnaires](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-configure-questionnaires.html) — Additional Information setup
- [Groups Reference](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-groups-reference.html) — Security groups
- [ProcureSight Module](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-ps-module.html) — ProcureSight search and collections
- [AI Copilot](https://docs.appian.com/suite/help/26.4/rm-26.3.2.6/rm-ai-copilot-overview.html) — Procurement AI Copilot

---

## 13. Database Schema & Record Type UUIDs (Atlas KB)

**Application:** RequirementsManagement
**Total Tables:** 178
**Total Columns:** 1,365
**Total Foreign Keys:** 235

### Table Categories

| Category | Count |
|----------|-------|
| Business | 89 |
| Reference | 38 |
| Audit | 36 |
| Task Management | 13 |
| Framework | 2 |

### Record Type UUIDs (Key Tables)

| Table | Record Type UUID | Record Type Name |
|-------|-----------------|------------------|
| AS_RM_REQUIREMENT | `721b8bd2-178b-445f-a90e-61dfcee46f2a` | AS_RM_Requirement_SYNCEDRECORD |
| AS_RM_REQUIREMENT_DOCUMENT | `061ffdc7-0fe3-4963-b3f1-a9d29ff751ff` | AS_RM_RequirementDocument_SYNCEDRECORD |
| AS_RM_REQUIREMENT_LINE_ITEM | `01fc18a5-6c4f-4164-a1ba-b8da087730fa` | AS_RM_InActiveLineItem_SYNCEDRECORD |
| AS_RM_REQUIREMENT_KEYDATES | `5854f387-e388-486b-b6b5-bcb7eb45bec7` | AS_RM_RequirementKeyDates_SYNCEDRECORD |
| AS_RM_REQUIREMENT_CODES | `011ec88d-48a5-484b-897a-b857d76b14ef` | AS_RM_RequirementCode_SYNCEDRECORD |
| AS_RM_RQIREMENT_AAC_ADDRESS | `35617de7-3567-4b08-ae08-0c0ab3596e7f` | AS_RM_RequirementAddress_SYNCEDRECORD |
| AS_RM_RQRMNT_FNDNG_INFRMTON | `4ce1a201-205f-4cb8-8289-046c5ec02b6c` | AS_RM_RequirementFundingInformation_SYNCEDRECORD |
| AS_RM_POINT_OF_CONTACT | `20665775-2fc8-4ea0-a9d0-2d5024986707` | AS_RM_PointOfContact_SYNCEDRECORD |
| AS_RM_CONTACT_ADDRESS | `7930e5ea-4ff8-4727-9e14-50e3757b1b5e` | AS_RM_ContactAddress_SYNCEDRECORD |
| AS_RM_ACTIVITY_ADDRESS_CODE | `596ccde1-1ddb-4063-a2a5-c3f0a01ff01f` | AS_RM_ActivityAddressCode_SYNCEDRECORD |
| AS_RM_EXTERNAL_USER | `a9326efd-e1c3-44d3-a8a6-8c3bca70d04f` | AS_RM_ExternalUser_SYNCEDRECORD |
| AS_RM_R_DATA | `07ce4663-d419-40ab-b4ed-961165e907c2` | AS_RM_R_Data_SYNCEDRECORD |
| AS_RM_R_DOCUMENT_TEMPLATE | `790e846b-23e0-4e3d-a5d9-d686e6b2aaac` | AS_RM_R_DocumentTemplate_SYNCEDRECORD |
| AS_RM_R_DOCUMENT_TYPE | `d92230ca-5012-4d53-8e2e-93b2d82cac50` | AS_RM_R_DocumentType_SYNCEDRECORD |
| AS_RM_R_CONTRACT_FILE_FLDR | `d104cab3-0094-4c04-9620-13f8d3356773` | AS_RM_R_ContractFileFolder_SYNCEDRECORD |
| AS_RM_LINE_ITEM_PRICING | `68aa4d49-beb7-4015-9f49-33dd88917bdb` | AS_RM_LineItemPricing_SYNCEDRECORD |
| AS_RM_TMG_TASK | `2a66b4a9-ac54-40e3-97b5-c56189ed6840` | AS_RM_TMG_Task_DocumentReview_SYNCEDRECORD |
| AS_RM_TMG_TASK_REVIEW | `ec530167-51e1-4ce7-bd07-9490d4574dd5` | AS_RM_TMG_Task_Review_SYNCEDRECORD |
| AS_RM_TMG_TASK_PRECEDENT | `9a1212fc-296a-46c5-8c54-fbca1dd10e25` | AS_RM_TMG_Task_Precedent_SYNCEDRECORD |
| AS_RM_TMG_TASK_DOC_UPLOAD | `d8cd6af7-ac42-497b-bf67-3ee903cea5ac` | AS_RM_TMG_TaskDocUploadContext_SYNCEDRECORD |
| AS_RM_TMG_R_TEMPLATE (Checklist) | `350072ce-87d5-49a5-8a8b-46e2f2b56802` | AS_RM_TMG_Checklist_SYNCEDRECORD |
| AS_RM_TMG_R_TEMPLATE_TASK | `66da8caa-53e5-4857-95a3-a9d597afca81` | AS_RM_TMG_ChecklistTask_SYNCEDRECORD |
| AS_RM_TMG_R_TASK_REF | `5cb1dd26-7c60-4346-b399-b77d1b30b060` | AS_RM_TMG_R_ActiveTask_SYNCEDRECORD |
| AS_RM_TMG_R_TASK_CATEGORY | `6bce0f16-c4ae-4989-8468-410192dafe1f` | AS_RM_TMG_R_TaskCategory_SYNCEDRECORD |
| AS_RM_TMG_RECOMMENDATION | `eecefb0c-3e8c-46c9-8b70-b531addfe826` | AS_RM_TMG_Recommendation_SYNCEDRECORD |
| AS_RM_ITEM_DELIVERY | `c86e7954-48d7-4a40-a407-840c995be01d` | AS_RM_LineItemDelivery_SYNCEDRECORD |
| AS_RM_ADDRESS | `13e5cb09-cb3b-40de-ac39-ac786f0018b3` | AS_RM_Address_SYNCEDRECORD |
| AS_RM_R_ADDRESS | `70cd37f3-93b8-44f5-bed8-9b925282f8fa` | AS_RM_R_Address_SYNCEDRECORD |
| AS_RM_SHAREPOINT_DRIVE | `a2cf8955-75dd-4eae-a16f-86213bcb73ea` | AS_RM_SharepointDrive_SYNCEDRECORD |
| AS_RM_MSG_THREAD | `53d3f93d-ccb6-423d-9238-2edf8811d08f-as_vm_msg-as_rm_msg` | AS_RM_MSG_Thread_SYNCEDRECORD |
| AS_RM_MSG_MESSAGE | `dcbd4c04-5f06-4dbc-b334-0a0a84742788-as_vm_msg-as_rm_msg` | AS_RM_MSG_NonLoggedInUser_Message_SYNCEDRECORD |
| AS_RM_AIDB_REQ_DOCUMENT_MAP | `67eec3a8-6490-4228-bef9-b8a5d946a63a` | AS_RM_AIDB_ReqDocumentMap_SYNCEDRECORD |
| AS_RM_PRO_COLLECTION | `501f7ba6-1bcf-43b9-9a77-4d7ab4ecb43b-as_rm_pro` | AS_RM_PRO_Collection_SYNCEDRECORD |
| AS_RM_PRO_OPPORTUNITY | `06968642-c224-47fe-b792-c97f6d25a299-as_rm_pro` | AS_RM_PRO_Opportunity_SYNCEDRECORD |
| AS_RM_PRO_VENDOR | `e00dede2-869a-457a-a75f-e197d5dcd267` | AS_RM_PRO_Vendor_SYNCEDRECORD |
| AS_RM_PRO_REQ_OPP_MAP | `8e8b8a08-6c28-4faa-9c50-15aa52be00c9` | AS_RM_PRO_RequirementOpportunityMap_SYNCEDRECORD |
| AS_RM_PRO_REQ_VENDOR_MAP | `37609cfe-1878-4a26-90c4-3a2a10a64c91` | AS_RM_PRO_RequirementVendorMap_SYNCEDRECORD |
| AS_RM_PRO_MAKT_RES_MAP | `dad67d34-c15d-4500-b3d7-e58fc01eb1a2` | AS_RM_PRO_MarketResearchMap_SYNCEDRECORD |
| AS_RM_BIC_CONTRACT | `cf3b6670-c587-49e0-ae71-e76bf7cd6466` | AS_RM_BIC_Contract_SYNCEDRECORD |
| AS_RM_QNM_T_QUESTIONNAIRE | `d05951e8-55fb-46c5-866d-c1bdf2ce9090` | AS_RM_QNM_T_Questionnaire_SYNCEDRECORD |
| AS_RM_QNM_T_QUESTION | `20d489dd-28eb-406a-8c3e-dd1983232c41` | AS_RM_QNM_T_Question_SYNCEDRECORD |
| AS_RM_QNM_R_QUESTION | `54068d5b-e23b-4959-a28b-67d66c1ec794` | AS_RM_QNM_R_Question_SYNCEDRECORD |
| AS_GAM_R_STATE | `1e089b45-513f-414c-bdde-990ede494d02` | AS_RM_R_State_SYNCEDRECORD |
| AS_GAM_R_COUNTRY | `97d2d412-e45e-4ff4-9c79-0e1655deee27` | AS_RM_R_Country_SYNCEDRECORD |

### Key Relationships (AS_RM_REQUIREMENT)

| Relationship Name | Target Record Type |
|-------------------|-------------------|
| category | AS_RM_R_Data_SYNCEDRECORD |
| status | AS_RM_R_Data_SYNCEDRECORD |
| priority | AS_RM_R_Data_SYNCEDRECORD |
| requirementType | AS_RM_R_Data_SYNCEDRECORD |
| addresses | AS_RM_RequirementAddress_SYNCEDRECORD |
| fundingInfo | AS_RM_RequirementFundingInformation_SYNCEDRECORD |
| keyDate | AS_RM_RequirementKeyDates_SYNCEDRECORD |
| codes | AS_RM_RequirementCode_SYNCEDRECORD |
| poc | AS_RM_PointOfContact_SYNCEDRECORD |
| aac | AS_RM_ActivityAddressCode_SYNCEDRECORD |
| lineItems | AS_RM_RequirementLineItem_SYNCEDRECORD |
| documents | AS_RM_RequirementDocument_SYNCEDRECORD |
| messageThreads | AS_RM_MSG_Thread_SYNCEDRECORD |
| nigpCodes | AS_RM_Requirement_NIGPCodes_SYNCEDRECORD |
| sharepointFolder | AS_RM_RequirementSharepointDrive_SYNCEDRECORD |
| summaryToggle | AS_RM_RequirementBannerToggle_SYNCEDRECORD |
| requirementOpportunityMap | AS_RM_PRO_RequirementOpportunityMap_SYNCEDRECORD |

### Audit Tables

| Table | Record Type UUID |
|-------|-----------------|
| TEMP_RM_A_R_REQUIREMENT | `6569bb04-322e-4d5a-898c-589699b491ac` |
| AS_RM_A_R_REQUIREMENT_FIELD | `740cc38a-57be-4ca3-962b-9220a4608f99` |
| AS_RM_A_R_RQRMNT_LN_ITM_FLD | `5179f4f2-cb5f-4d29-a094-3664bafe5130` |
| AS_RM_A_R_RQRMNT_DCMNT_FELD | `c205ecd5-2a3c-489b-8ad0-1d3a57d01eaa` |
| AS_RM_A_R_ITEM_DEL_FLD | `effb6bb3-be68-4e57-b071-5597330bbec5` |
| AS_RM_A_R_REQ_AC_ADDRSS_FLD | `f47f15db-9fcb-49d2-922e-42b335dd077c` |
| AS_RM_TMG_TASK_ACTION_AUDIT | `b67c6f59-7955-4273-853e-2be8d011423f` |

---

## 14. Known Quirks & Testing Notes

- **AI-Assisted Creation:** Requires the AI toggle to be enabled in Settings. If disabled, the AI path is not visible.
- **PSC/NAICS Codes:** Uses semantic search — pre-fills with requirement title. Modify search text for better results.
- **Category-Based Dates:** Date fields change based on selected category (goods vs. services). Test both paths.
- **SharePoint Integration:** Document editing requires SharePoint connection. Finalization auto-saves if link expires.
- **ProcureSight:** Requires ProcureSight Plus or Enterprise subscription. AI Market Deep Dive runs in background after creation.
- **Document Upload Limits:** Max 15 documents at a time, max 4 MB each. Supported types: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX.
- **Checklist Recommendations:** System automatically recommends checklists based on requirement inputs (PSC/NAICS codes).
- **Review Process:** Supports precedent-based sequential reviews with configurable groups and due dates.
- **Copy Requirement:** Copies requirement details including questionnaire responses (if no changes to default questionnaire).
- **Smart Search:** Home page search uses AI semantic search with Search Relevance column (known bug: GAMS-8586).

---

## 15. AI Features

### 15.1 AI-Assisted Requirement Creation
- **Trigger:** User enters natural language description on Create Requirement form
- **Process:** AI parses description and auto-populates form fields (title, category, priority, codes, etc.)
- **Toggle:** Must be enabled by admin in Settings

### 15.2 Intelligent PSC/NAICS Code Classification
- **Trigger:** During requirement creation or line item creation
- **Process:** Semantic search pre-fills with requirement/line item title; returns ranked code suggestions

### 15.3 AI Market Deep Dive (ProcureSight Enterprise)
- **Trigger:** Automatically after requirement creation
- **Process:** AI agent searches procurement data, creates collection, drafts market research report
- **Results:** Displayed in Research tab > AI Research Collection

### 15.4 AI Document Builder
- **Trigger:** User clicks CREATE DOCUMENT > Create Document using AI
- **Process:** Selects template, provides context documents, generates draft with AI
- **Editing:** AI Drafting Mode with Template Assistant and Editing Assistant

### 15.5 Document AI (Summarize & Chat)
- **Trigger:** User clicks document > Details (for summary) or Ask AI (for chat)
- **Process:** AI generates document summary; chat interface for querying document content

### 15.6 Procurement AI Copilot
- **Trigger:** Available in Copilot tab
- **Process:** AI chatbot answers procurement-related questions using search results and requirement context

### 15.7 AI Semantic Search
- **Trigger:** Home page search bar
- **Process:** Natural language search across requirements with relevance scoring

---

## 16. Settings Site (Admin)

**Access:** Admin and Contracting Manager roles only

### Configurable Settings

| Setting | Description |
|---------|-------------|
| Dropdowns | Category, Priority, Delivery Type, Lead Time Event, Duration Unit, Location Type, POC Type |
| Checklists | Create, update, delete checklist templates with task assignments |
| Questionnaires | Configure Additional Information questions and categories |
| Document Templates | Manage pre-approved document templates |
| AI Toggles | Enable/disable AI-Assisted Requirement Creation, AI Document Builder |
| SharePoint | Configure SharePoint drives and folder structure |
| ProcureSight | Configure ProcureSight integration settings |

---

## 17. Test Data Setup Instructions

### 17.1 Creating a Requirement in "Draft" Status
1. Login as `RMRequestor` / `appian23`
2. Navigate to Requirements Management site
3. Click "CREATE REQUIREMENT"
4. Fill required fields (Title, Description, Type, Category, Priority)
5. Click CREATE — requirement is now in "Draft" status

### 17.2 Submitting a Requirement for Review
1. Create a requirement (see 17.1)
2. On the Summary tab, click "Submit for Review"
3. Add Review Group with Assigned Group and Individual Assignee
4. Set Due Date
5. Click SUBMIT FOR REVIEW — requirement moves to "Review" status

### 17.3 Submitting to Contracting
1. Create a requirement in Draft status
2. On the Summary tab, click "SUBMIT TO CONTRACTING"
3. Select Individual Assignee
4. Click SUBMIT TO CONTRACTING — requirement moves to "Submitted" status

### 17.4 Getting a Requirement to "Accepted" Status
1. Submit requirement to contracting (see 17.3)
2. Login as contracting personnel (RMContractingManager)
3. Assign the requirement
4. Complete review process
5. Accept the requirement — moves to "Accepted" status

### 17.5 Adding Line Items
1. Navigate to requirement > Line Items tab
2. Click ADD
3. Fill Details (Item Number, Title, Description, Option, Type, Delivery Date)
4. Select PSC Code
5. Fill Pricing (Pricing Arrangement, Unit of Measure, Quantity, Unit Price)
6. Click CREATE

### 17.6 Setting Up a Checklist
1. Navigate to requirement summary
2. Click ADD CHECKLIST
3. Select or create checklist template
4. Tasks are auto-assigned based on template configuration

---

## 18. Workflow: Review Process

### Trigger
Requestor or Requestor Manager clicks "Submit for Review" on a requirement.

### Process Flow
1. User configures review groups:
   - Assigned Group (security group)
   - Individual Assignee (specific user)
   - Due Date
   - Precedents (sequential review ordering)
2. On Submit:
   - Review tasks created for each group/assignee
   - Precedent-based ordering enforced
   - Email notifications sent
3. Reviewer actions:
   - **Approve** — Moves to next reviewer or completes review
   - **Request Changes** — Returns to requestor with comments
   - **Reject** — Rejects the requirement with reason

### Known Bug
- **GAMS-7018:** Review task not recreating after rejection and reassignment

---

## 19. Workflow: Copy Requirement

### Trigger
User clicks "Copy Requirement" from the Summary tab ellipsis menu.

### Process Flow
1. System duplicates requirement details into Create Requirement wizard
2. User can edit any fields before creating
3. Click CREATE — new requirement created with copied data
4. Questionnaire responses are copied if no changes to default questionnaire (GAMS-2489)

---

## 20. Workflow: Mark Inactive

### Trigger
User clicks "Mark Inactive" from the Summary tab or Home page.

### Process Flow
1. User enters reason in Comment field
2. Click MARK INACTIVE
3. Requirement status changes to "Inactive"
4. Bulk mark inactive supported from Home page

---

## 21. Jira Components (RM)

| ID | Component Name | Description |
|----|----------------|-------------|
| 28759 | 1. RM: Requirements Management Site | Requirement Management Site |
| 28760 | 1.1 Home Page | Requirement Management Site → Home Page |
| 28761 | 1.1.1 RM: Add New Requirement | Requirement Management Site → Home Page → Add New Requirement |
| 28762 | 1.1.1.1 Checklist Setup interface | Requirement Management Site → Home Page → Add New Requirement → Checklist setup interface |
| 28765 | 1.1.2.2 RM: Update Requirement | Update Requirement |
| 28771 | 1.1.3.1.1.1 Checklist Grid | Requirement Management Site → Home Page → Checklist Grid |
| 28774 | 1.1.3.1.10 RM: GCW Integration | GCW Integration |
| 28775 | 1.1.3.1.2 Document Tab | Requirement Management Site → Requirement Summary → Document |
| 28776 | 1.1.3.1.2.1 RM: Document Summary | Requirement Summary → Document Tab → Document Summary |
| 28777 | 1.1.3.1.3 Checklist Tab | Requirement Summary → Checklist tab |
| 28778 | 1.1.3.1.4 Contract File tab | Requirement Summary → Contracting |
| 28782 | 1.1.3.1.7 Collaboration | Requirement Summary → Collaboration tab |
| 28783 | 1.1.3.1.8 Related Actions | Requirement Summary → Related Actions |
| 28785 | 1.1.3.1.8.10 Copy Requirement | Copy Requirement |
| 28788 | 1.1.3.1.8.3 Submit For Review | Submit Review Interface |
| 28794 | 1.1.3.1.8.9 Reassign Requirement | Reassign Requirement |
| 28800 | 1.10 RM: Messaging | RM Messaging |
| 28801 | 1.2 Requirements page | Requirements Page |
| 28803 | 1.2.2 Create New Requirement Interface | Create New Requirement |
| 28805 | 1.2.4 Requirement Summary | Requirement Summary |
| 28809 | 1.2.4.4 Review Requirement | Approve Requirement |
| 28810 | 1.2.4.5 Submit Requirement to Contracting | Submit Requirement to Contracting |
| 28812 | 1.2.4.7 Add Item | Add Item |
| 28813 | 1.2.5 Checklist Items | Checklist grid |
| 28814 | 1.2.5.1 Attach Document | Attach Document |
| 28822 | 1.2.5.8 Set Up Checklist Item | Set Up Checklist Item |
| 28824 | 1.3 People Tab | Contacts page |
| 28844 | 1.9 RM: Accessibility | RM Accessibility |
| 28845 | 2. Requirement Management Setting site | Settings site |
| 28849 | 2.1.4 Checklists | Settings → Checklists |
| 28863 | 2.4 Additional Questions | Additional Questions |
| 29403 | RM AI Copilot | RM AI Copilot |
| 29404 | RM Line Item | RM Line Item |
| 29405 | RM Procuresight | RM Procuresight Component |
| 31297 | RM: Procuresight | RM: Procuresight |
| 31963 | RM: Create document | RM: Create document |
| 32134 | RM: AI Document Builder | RM: AI Document Builder |
| 32196 | RM: Create Requirement using AI | RM: Create Requirement using AI |
| 32197 | RM: AI Market Research | RM: AI Market Research |

---

## 22. Reference Data IDs (AS_RM_R_DATA)

The `AS_RM_R_DATA` table contains 256 rows across 25 reference types. Below are the confirmed refDataId values extracted from application constants:

### Requirement Status IDs

| refDataId | refLabel | Constant Name |
|-----------|----------|---------------|
| 12 | Draft | AS_RM_REF_ID_REQUIREMENT_STATUS_DRAFT |
| 13 | Submitted | AS_RM_REF_ID_REQUIREMENT_STATUS_SUBMITTED |
| 14 | Accepted | AS_RM_REF_ID_REQUIREMENT_STATUS_ACCEPTED |
| 49 | Review (Submitted for Review) | AS_RM_REF_ID_REQUIREMENT_STATUS_SUBMITTED_REVIEW |
| 52 | Assigned | AS_RM_REF_ID_REQUIREMENT_STATUS_ASSIGNED |
| 135 | Procurement Created | AS_RM_REF_ID_REQUIREMENT_STATUS_PROCUREMENT_CREATED |

### Task Status IDs (AS_RM_TMG_R_TASK_STATUS)

| statusId | Status Label | Constant Name |
|----------|-------------|---------------|
| 1 | Queued | AS_RM_TMG_REF_ID_TASK_STATUS_QUEUED |
| 2 | Assigned | AS_RM_TMG_REF_ID_TASK_STATUS_ASSIGNED |
| 3 | In Progress | AS_RM_TMG_REF_ID_TASK_STATUS_INPROGRESS |
| 4 | Complete | AS_RM_TMG_REF_ID_TASK_STATUS_COMPLETE |
| 5 | Not Needed | AS_RM_TMG_REF_ID_TASK_STATUS_NOT_NEEDED |
| 6 | Cancelled | AS_RM_TMG_REF_ID_TASK_STATUS_CANCELLED |
| 7 | All (filter) | AS_RM_TMG_REF_ID_TASK_STATUS_ALL |

### Document Review Status IDs

| refDataId | Status Label | Constant Name |
|-----------|-------------|---------------|
| 136 | Not Started | AS_RM_REF_ID_DOCUMENT_REVIEW_STATUS_NOT_STARTED |
| 137 | In Progress | AS_RM_REF_ID_DOCUMENT_REVIEW_STATUS_INPROGRESS |
| 138 | Completed | AS_RM_REF_ID_DOCUMENT_REVIEW_STATUS_COMPLETED |

### Document Finalization Status IDs

| refDataId | Status Label | Constant Name |
|-----------|-------------|---------------|
| 275 | Failed | AS_RM_REF_DATA_ID_DOCUMENT_FINALIZE_STATUS_FAILED |
| 276 | Completed | AS_RM_REF_DATA_ID_DOCUMENT_FINALIZE_STATUS_COMPLETED |

### Checklist Status IDs

| refDataId | Status Label | Constant Name |
|-----------|-------------|---------------|
| 114 | Outstanding | AS_RM_REF_ID_CHECKLIST_STATUS_OUTSTANDING |
| 115 | Completed | AS_RM_REF_ID_CHECKLIST_STATUS_COMPLETED |

### All Reference Types in AS_RM_R_DATA

| Ref Type | Description |
|----------|-------------|
| Requirement Status | Draft, Review, Submitted, Assigned, Accepted, Procurement Created |
| Requirement Type | New, Modification |
| Address Type | Address type classifications |
| Amount Type | Amount type classifications |
| Best In Class Category | BIC contract categories |
| Best In Class Contract Type | BIC contract types |
| Best In Class Subcategory | BIC subcategories |
| Conditional Operator | Operators for questionnaire conditional logic |
| Delivery Address Type | Delivery address classifications |
| Document Finalization Status | Not Started, In Progress, Failed, Completed |
| Document Review Status | Not Started, In Progress, Completed |
| Document Review Type | Types of document reviews |
| Due Date Change Reason | Reasons for task due date changes |
| Line Item Option | Line item option types (Base, Option) |
| Line Item Type | Line item type classifications |
| Operation | Operation types |
| Pricing Arrangement | Pricing arrangement types for line items |
| Procurement Type | Procurement type classifications |
| Reference Document Type | Reference document type classifications |
| Requirement Review Type | Review type classifications |
| Sharepoint Drive Category | SharePoint drive categories |
| Sharepoint Drive Type | SharePoint drive types |
| Template Question Visibility | Questionnaire question visibility rules |
| TemplateId | Template identifiers |
| Vendor Address Type | Vendor address type classifications |

### Other Reference Tables

| Table | Row Count | Key Info |
|-------|-----------|----------|
| AS_RM_TMG_R_TASK_CATEGORY | 4 | Task categories |
| AS_RM_TMG_R_TASK_REF | 7 | Reference tasks (TASK_NAME, TASK_BEHAVIOR_TYPE_ID, DEFAULT_GROUP_ASSIGNEE) |
| AS_RM_R_DOCUMENT_TYPE | 29 | Document types (LABEL, DEFAULT_CONTRACT_FILE_FOLDER) |
| AS_RM_R_CONTRACT_FILE_FLDR | 118 | Hierarchical folder structure (FOLDER_NAME, PARENT_FOLDER_ID) |
| AS_RM_R_DOCUMENT_TEMPLATE | 2 | Document templates (DOCUMENT_NAME, FILE_TYPE) |
| AS_RM_PRO_R_AGENCY | 207 | ProcureSight agency reference (NAME, LEVEL) |
| AS_RM_BIC_CONTRACT | 172 | Best in Class contracts (TITLE, MANAGING_AGENCY) |
| AS_GAM_R_COUNTRY | 14 | Country reference (COUNTRY_NAME, COUNTRY_CODE) |
| AS_GAM_R_BUSINESS_TYPE | 93 | Business type codes (CODE, DESCRIPTION) |

---

## 23. Key Test Case Steps

### 23.1 GAMS-7968 — AI Requirement Creation (End to End)

**Component:** RM: Create Requirement using AI | **Status:** Ready

**Steps:**
1. Navigate to RM Home Page → Verify "Create Requirement" button label (NOT "Add Requirement")
2. Click "Create Requirement" → Form opens in modal dialog (not full-page navigation)
3. Login as Requestor → Enable AI toggle → Click Create Requirement → Verify Step 1 wizard: left pane (pencil icon, "Tell us about your requirement", "Fill out the form instead" link, "Key Info to Include" accordion collapsed), right pane (Description textarea, Supplementary Documents upload), footer (CANCEL link, NEXT button disabled)
4. Enter text in Description → NEXT button enables on keypress; expand "Key Info to Include" accordion
5. NEGATIVE: Enter >4000 chars → System restricts or shows validation
6. NEGATIVE: Upload non-PDF → Validation "only PDF format accepted"
7. NEGATIVE: Upload 6 PDFs → 5 accepted, 6th rejected with validation
8. Enter valid description + upload valid PDF → NEXT enabled
9. Click NEXT → Loading indicator → Step 2 (Review AI Results) within 15s
10. Verify KPI pane: "AI Auto-Populated" count, Missing Fields count (required + optional)
11. Verify navigation cards: Requirement Setup, DoDAAC & POC, Codes, Funding, Addresses, Additional Information
12. Click "Requirement Setup" → Verify AI-populated Title, Description, Type ("Modification"), Category ("Facilities")
13. Edit Title, set Priority → Values accepted
14. Click "DoDAAC & POC" → Verify AI-populated DoDAAC, POC, Organization, Email, Phone
15. NEGATIVE: Invalid phone → validation; correct → card counts update dynamically
16. Click "Codes" → Verify AI pre-selected PSC and NAICS codes
17. Remove PSC code, search new one → Selection updates
18. Click "Funding" → Verify AI-populated values; edit Estimated Total Contract Value
19. Click "Addresses" → Click "+ ADD NEW ADDRESS" → New blank form added
20. Click "Refine Inputs" → Returns to Step 1 with data preserved
21. Modify description, click NEXT → AI re-processes with updated results
22. Fill all required fields → Click CREATE → Step 3 confirmation with "Go to Research Tab", "Go to Requirement Summary Tab", "CLOSE"
23. Verify AI Market Deep Dive section (3 steps, Research Areas with 8 cards in 4x2 grid)
24. Click "Go to Requirement Summary Tab" → Summary page with "Market Research In Progress" banner
25. As Admin disable AI toggle → Click Create Requirement → Manual form shown directly
26. Re-enable toggle → "Fill out the form instead" → Manual form without AI processing
27. NEGATIVE: Prompt injection in Description → AI treats as plain text, no system prompt leaked
28. NEGATIVE: Contradictory inputs → AI picks one value per field, no garbled values
29. NEGATIVE: Vague description → Defaults applied (Type: "New", Category: "Other"), no hallucinated values
30. PERFORMANCE: Locust load test — 0 failures, 5 cycles in 120s, ~24s per cycle
31. PERFORMANCE: AI processing (NEXT) averages ~5.7s (p95: 6.1s), within 15s threshold
32. PERFORMANCE: CREATE averages ~4.6s; form fills ~393ms; navigation ~628ms

---

### 23.2 GAMS-8048 — AI Market Research from Requirement (End to End)

**Component:** RM: AI Market Research | **Status:** Ready

**Steps:**
1. Login as Requestor → Verify AI Deep Dive Agent toggle NOT visible to non-admin
2. Create requirement with AI Market Research toggle ON → Agent triggered
3. Navigate to Summary → "AI Agent conducting market research" banner displayed
4. Wait ~30s → Banner refreshes (status re-polled)
5. Navigate away (Tasks tab) → Return → Banner still visible
6. Wait for agent completion → Banner disappears, no error
7. Navigate to Research tab → "AI Research Collection" sub-tab visible
8. Click "AI Research Collection" → PSE Collection view with Summary tab default
9. Verify left nav: AI Research Collection, Saved Procurement Data, Best in Class, Search
10. Summary tab → AI-generated research summary (Taxonomy, Spend, Vendor Landscape, Standardized Requirements) with generation date and Re-generate link
11. Click Re-generate → Summary refreshes with new date
12. Bookmarks section → Table (Title, Type, Source, Date Added) with filters and REMOVE BOOKMARKS button
13. Filter by type (e.g., Award) → Table filters correctly
14. Filter by "Added by: Agent" → Shows agent-added bookmarks only
15. Select bookmarks → Click REMOVE BOOKMARKS → Removed, count updates
16. Verify Document Builder card with GENERATE button in right sidebar
17. Click GENERATE → AI document generation triggered
18. Click "Saved Procurement Data" → Searchable table (Name, Related Record, Agency) with Ask AI and download buttons
19. Download a document → Downloads successfully
20. Search → Table filters to matching documents
21. ERROR SCENARIO: Create requirement where agent fails → In-progress banner shown initially
22. Wait for failure → Error banner replaces in-progress banner with user-friendly message
23. Navigate to Research tab → Error message instead of collection
24. Verify other tabs (Summary, Tasks, Line Items) still functional
25. Verify backend: AS_RM_PSE_Collection_Mapping → agentStatus = ERROR, researchEndDate populated
26. Disable AI Deep Dive Agent toggle → Create requirement → Agent runs but no Market Research Report auto-generated
27. Create requirement with AI Market Research toggle OFF → No banner, no AI Research Collection sub-tab

---

### 23.3 GAMS-2685 — Verify Solicitation Creation from a Requirement (RM/AM Integration)

**Component:** RM: Requirements Management Site | **Status:** Ready

**Prerequisites:**
- Create requirement as Requestor → Submit to Contracting/Submit for Review
- Login as Contracting Manager → Approve → Assign to CO
- Login as CO → Approve → Requirement reaches "Accepted" status

**Steps:**
1. Login to AM as CO → Search for created requirement → Requirement displayed in AM (Accepted/Procurement Created status, Active)
2. Click "Create Solicitation" related action → Wizard opens with pre-populated data from requirement:
   - Key Details: Title, Description, Requirement Number, Fiscal Year, Category
   - Codes: PSC Code/Description, NAICS Code/Description
   - Team Members: Contracting Officer, Contract Specialist
   - Additional Info: POP Start/End dates mapped from delivery dates
3. Navigate to Solicitation summary → Verify:
   - Related Requirements section shows requirement card (ID, date, agency, Accepted Date)
   - Requirement status updated from "Accepted" to "Procurement Created"
   - Contract File: Reference to all documents from requirement added (not copied)
   - Delete doc in AM → NOT deleted in RM; Delete doc in RM → NOT deleted in AM
4. Navigate to Line Items → Verify all line items cloned from requirement
5. Verify Related Actions available: Add Item, Add Line Item, Update Line Item, Import Line Item, Add Checklist, Upload Document, Create Award
6. Login to RM as CO/CS/CM → Requirement Summary shows "Procurement Created" status; Related Procurements card shows Solicitation link → Click navigates to AM
7. Login to AM → Select solicitation → Related Requirements section shows requirement link → Click navigates to RM

---

### 23.4 GAMS-2430 — SafetyNet: Verify Line Items and Delivery

**Component:** RM Line Item | **Status:** Ready

**Steps:**
1. Login as Requestor → Navigate to Requirement record → Line Items tab → Grid displayed with line items and related actions
2. Click Add RA → Fill all fields (Item Number, Title, Description, Option, Type, Delivery Date, PSC Code, Pricing) → Line item added, returns to grid
3. Click line item → View summary with related actions to add deliveries
4. Click Add delivery → Fill fields → Delivery added successfully

---

### 23.5 GAMS-2452 — Requirement Status Flow (Draft → Submitted Review → Submitted → Assigned → Accepted)

**Component:** Submit For Review, Review Requirement, Submit to Contracting | **Status:** Ready

**Steps:**
1. Login as Requestor → Create requirement with all details → Status = **Draft**
2. Submit to Review → Assign to contracting user → Task assigned, status = **Submitted Review**
3. Submit to Contracting → Assign to Contracting Manager → Task assigned, status = **Submitted**
4. Login as Contracting Manager → Complete assigned task → Assign to CO and CS for review → Status = **Assigned**
5. Login as CO or CS → Complete assigned task → Status = **Accepted**

---

### 23.6 GAMS-2607 — Manual Requirement Creation (Requirement ID and Name Verification)

**Component:** RM: Add New Requirement, Update Requirement, Copy Requirement | **Status:** Ready

**Steps:**
1. Login as Requestor → Navigate to RM Home page
2. Click Add RA → Fill mandatory fields → Click Create
3. Verify: Confirmation popup shows Requirement ID link; format = `<DoDAAC>+<0000000001>` (first serial for that AAC)
4. Create another requirement with same DoDAAC → ID = `<DoDAAC>+<0000000002>` (incremented serial)
5. Verify: Requirement grid shows `<ReqID>|<Req Title>` as link
6. Verify: Requirement History captures Requirement ID
7. Select requirement → Click Update RA → Modify fields EXCEPT DoDAAC → Update → Requirement ID unchanged
8. Repeat Update → Modify DoDAAC → Update → Requirement ID changes to `<NewDoDAAC>+<next serial for new AAC>`
9. Verify: Requirement History captures ID change
10. Open requirement → Click Copy Requirement RA (no DoDAAC change) → New requirement ID = `<DoDAAC>+<previous serial+1>`
11. Copy Requirement with DoDAAC change → ID = `<NewDoDAAC>+<next serial for new AAC>`
12. Verify: Requirement History for copied requirement

---

### 23.7 GAMS-2402 — SharePoint Document Upload and Edit Integration

**Component:** Document Tab, Contract File tab | **Status:** Ready

**Prerequisites:** AS_GAM_BOL_OFFICE_365 toggle (True/False controls SharePoint integration)

**Steps:**
1. Login as Requestor/Requestor Manager → Create requirement → Empty folder created in SharePoint (Requirement ID as folder name) under Documents tab
2. Login as CO/CS/CM → Same but folder under Contract Files tab in SharePoint
3. Open requirement → Document Tab → Verify "Upload Documents" RA and grid columns (Document Name, Review Status, Description, Uploaded On, Download, Menu icon)
4. Verify Review Status colors: Not Started (#E8F2FA), In Progress (#F0E0FF), Completed (#DCF5D6)
5. Verify Search and filters (partial text search, Review Status multi-select, Manage Filters with Clear/Save)
6. Click Upload Documents → Window shows: Title, Document(s) with Upload button, supported types (pdf, doc, docx, xls, xlsx, ppt, pptx), max 15 docs, + symbol to add more
7. Upload documents → Available in Document tab, SharePoint, and AS_RM_REQUIREMENT_DOCUMENT table; Requirement History captured
8. With AS_GAM_BOL_OFFICE_365 = False → Documents uploaded to tab and table but NOT to SharePoint
9. Click Document Name → Opens interface with: Document Preview (left), Document Details (right: Title, Description, Uploaded On, Last Updated, Review Status), Edit button (if SharePoint ON), Upload to SharePoint button (if doc uploaded with toggle OFF)
10. PDF files → Preview rendered; Other types → "Preview Unavailable" message with download option
11. Click Edit → Edit Document window: "Open and Edit Document" link (opens in O365), "Finalize" button (brings back to RM), "Exit" button
12. Edit document in SharePoint → Finalize → Document holds latest edits; Requirement History captured; Link expiry = 2 days from click (extended on each click)
13. Click Upload to SharePoint (for docs uploaded with toggle OFF) → Document uploaded, office365DocumentId saved
14. Delete RA: Disabled by default, enabled on selection (single/multi-select); Not available for Inactive requirements
15. Delete → Popup with document count, warning banner "Any review processes will also be deleted", optional Reason (500 chars), Delete/Cancel
16. On Delete → Removed from grid, AS_RM_REQUIREMENT_DOCUMENT table, and SharePoint; Review tasks deleted; Audit captured
17. Max 200 documents for bulk delete; error shown if exceeded
18. Download link behavior: Enabled normally; Disabled when document is open in SharePoint; Re-enabled after Finalize

---

### 23.8 GAMS-7801 — Create Document from Pre-Approved Template

**Component:** RM: Create document | **Status:** Closed

**Steps (AI Doc Builder ON):**
1. Open "Create Document" action → "Choose Starting Point" section with two cards displayed
2. "Create using AI" selected by default; "Create using Template" card available
3. Select "Create using Template" → Card highlighted; click Next

**Steps (AI Doc Builder OFF):**
1. Open "Create Document" → Skips starting point, lands directly on "Create Document from Template"

**Step 1 — Choose a Template:**
1. "Choose a Template" section with "All Templates (N)" count
2. Selected Template placeholder: "A template must be selected"
3. Template cards in groups of 4 with pagination; Search bar available
4. Next button disabled until template selected
5. Select template → Card shows selected indicator; Preview Pane shows template content; Next enabled
6. Remove via X icon → Reverts to placeholder; Next disabled

**Step 2 — Attach Supporting Sources:**
1. "Upload Relevant Files" section with suggested documents grid (checkboxes)
2. Search requirements → Drill into requirement → Select documents (max 10 total)
3. File Upload field for additional uploads (supported types only)
4. "Supporting Notes" text area (optional, multi-line)
5. Data persists across step navigation (cached)

**Step 3 — Provide Document Details:**
1. Document Name (mandatory, restricted chars: `/;:`)
2. Description (visible only when AI skill OFF)
3. Click "Generate Draft" → Redirected to Drafts grid with new draft record

**SharePoint ON flow:**
- Step 3 shows "Generate Document" → "GENERATE AND AUTO-POPULATE DOCUMENT" button
- After generation → Button changes to "OPEN IN SHAREPOINT"
- "Finalize" button enabled after generation
- CO users see mandatory Folder picker; non-CO users don't see folder field

**SharePoint OFF flow:**
- Step 3 shows "Download Document" with "AUTO-POPULATED DOCUMENT" and "UNPOPULATED DOCUMENT" cards
- Step 4: "Review and Upload Document" with mandatory file upload
- Click Create → Document saved to requirement record

---

### 23.9 GAMS-7767 — Create Document from Template Task

**Component:** RM: Create document | **Status:** Backlog

**Steps:**
1. Navigate to Create Document from Template task as assigned user → Title shown, selected template read-only, three-step process displayed
2. Task Details section (right side, read-only)
3. **Step 1 — Describe Document:** Description text area (optional)
4. **Step 2 (SharePoint OFF):** "Download Document" heading; buttons: "AUTO-POPULATED DOCUMENT" and "UNPOPULATED DOCUMENT"
5. **Step 2 (SharePoint ON):** "Generate Document" heading; button: "GENERATE AND AUTO-POPULATE DOCUMENT" → Changes to "OPEN IN SHAREPOINT" after click
6. **Step 3 (SharePoint OFF):** "Review and Upload Document" with mandatory "Document *" field; supports button upload, drag & drop, paste
7. **Step 3 (SharePoint ON):** "Review and Save Document" heading; upload section NOT displayed
8. CO users see mandatory "Folder *" field (pre-populated with template default); non-CO users don't see folder
9. Click SUBMIT → Document available in requirement record's document grid with correct metadata
10. CANCEL → Exit without saving

---

### 23.10 GAMS-6685 — AI Document Summary and Chat

**Component:** RM: Document Summary | **Status:** Ready

**Prerequisites:** AI Features toggle ON in RM Settings; AI Provider configured (Appian Native or Azure AI)

**Steps:**
1. Login as Contracting Professional → Open requirement → "AI Summary" section and "Ask AI" tab visible (standard Description field hidden when AI ON)
2. Upload PDF document → Document uploads successfully
3. Navigate to "Ask AI" tab immediately → "Indexing in progress" state; chat disabled
4. Wait for indexing → "AI Summary" auto-populates; "Ask AI" shows suggested prompts
5. Select prompt or type question → AI responds based on PDF content with citations/source links
6. Change AI Provider (Admin: Settings → Azure AI) → UI remains consistent
7. Upload DOCX → "Ask AI" not supported for DOCX
8. Ask unrelated question → AI refuses, states it can only answer about the document
9. Upload corrupted/empty PDF → Indexing/Chat fails gracefully with user-friendly error
10. Upload large document (>2MB) → Message "AI Features only available for PDFs smaller than 2 MB"
11. Upload PDF >100 pages → Message "AI Summarization only available for PDFs with 100 pages or fewer"
12. Disable AI Features toggle (Admin) → "AI Summary" and "Ask AI" disappear; original Description field returns
13. Verify no data loss in Description field after toggling
14. Click Reviews tab → List of reviews displayed (or "No Items available"); "Add Reviews" button available
15. Click Add Reviews → Submit Document for Review form displayed

---

### 23.11 GAMS-2408 — Admin: Delete Checklist

**Component:** Checklists, Requirement Management Settings site | **Status:** Ready

**Steps:**
1. Login as Admin → Navigate to RM Settings → Task Management → Checklists → Grid with checklists and actions displayed
2. Select checklist → Click Delete menu action → Confirmation: "Deleting the checklist '<name>' will not delete its tasks. This action cannot be undone." with Cancel & Delete buttons
3. Click Cancel → Checklist NOT deleted; still in grid and backend (AS_RM_TMG_R_TEMPLATE, AS_RM_TMG_R_TEMPLATE_TASK)
4. Repeat → Click Delete → Checklist deleted from grid; Audit in AS_RM_TMG_A_R_TEMPLATE
5. Verify metrics: Admin console → Rule performance → AS_RM_MTR_SAVE_deleteChecklist

---

### 23.12 GAMS-2494 — Add Checklist to a Requirement

**Component:** Checklist Setup interface, Checklists | **Status:** Ready

**Steps:**
1. Login as RM user → Verify "ADD CHECKLIST" RA visible next to Update RA above Requirements grid
2. Select single requirement (status ≠ Procurement Created) → "Add Checklist" enabled
3. Click Add Checklist → "Set up Checklist" window opens with:
   - Checklist selection box (auto-populated if recommended checklist configured in Settings; otherwise instruction "No recommended checklist was found")
   - Description of the Checklist
   - Add task button for each category
   - **Note:** Duplicate checklist selection shows error "The selected checklist is already added and is still active"
4. Verify task grid columns (editable): Task Name (read-only), Type (read-only), Dependents (multi-select dropdown), Assigned Group (required, picker), Individual Assignee (optional, picker based on group), Days to Complete (required, integer), Due Date (required)
5. Dependents: Multi-select dropdown, read-only when single row; tooltip "Dependent tasks are assigned after the current task completes"
6. Days from Start: Enabled only when precedents dropdown is not empty; disabled when Due Date is set
7. Due Date: Required; past date → validation "Enter a future date"
8. Remove icon → Removes row from grid
9. Click "Add Item" under any category → Shows existing items from Settings + "Add Custom Item" RA
10. Submit without items → Validation "You cannot submit without a checklist selected. You cannot submit without any items"
11. Fill all mandatory values → Click "Set up checklist" → Checklist added to Checklist Items grid
12. Verify Checklist tab: Tasks with Due Date, Type, Assigned Group & Assignee
13. Verify Checklist Item History: "<User name> created <Task name> <date/time>"
14. Verify: Add Checklist RA on Summary page enabled only when Select Checklist task is completed
15. Inactive requirement → Add Checklist RA NOT enabled

---

### 23.13 GAMS-2508 — Document Review Process

**Component:** Document Tab, Contract File tab | **Status:** Ready

**Steps:**
1. Login as Requestor → Navigate to active requirement → Document dashboard
2. Click "Create Review Process" from menu icon in document grid → Form: "Submit document for review|<Req name>"
3. Verify form sections:
   - **Document:** Document name (read-only)
   - **Existing Review Process:** Grid (Precedents, Assigned Group, Individual Assignee, Due Date, Review Date, Decision, Comments); pagination at 5; sorting on Review Date
   - **Decision colors:** Approved (#DCF5D6/#04531D), Rejected (#EDEEF2/#2E2E35), Changes Requested (#FFF6C9/#816C03)
4. **New Review Process Configuration:**
   - If matching template exists in Settings: Pre-populated grid with Precedents, Assigned Group, Individual Assignee, Days to Complete, Due Date; plus Review Name, Document Template, Threshold Amount, Document Type
   - If multiple templates match: Shows template where threshold = Estimated Total Contract Value
   - If no template matches: Empty grid with manual add capability
5. Leave required fields blank → Submit → Validation "You must add at least one review task"
6. Enter duplicate Assigned Groups → Validation "Group exists already"
7. Fill all details → Cancel → No review tasks created
8. Fill all details → Submit → Review tasks created (tasks with precedents created only after precedent completion)
9. Navigate to Checklist History → Task creation audits captured
10. Repeat for Contracting user on Contract File tab → Same behavior

---

### 23.14 GAMS-7542 — Create Document using AI (Full Flow)

**Component:** RM: Create document | **Status:** Backlog

**Step 1 — Choose a Template:**
1. Navigate to Documents tab (AI enabled) → "Create Document" action visible (NOT "Create Document from Template")
2. Click Create Document → Two options: "Create Document using AI" (default) and "Create Document from Template"
3. Select "Create Document using AI" → Click NEXT → Step 1 loads
4. "Choose a Template" section: Selected Template placeholder, All Templates (N) count, search bar, template cards (4 per page with pagination)
5. Next button disabled until template selected
6. Select template → Card highlighted, Preview Pane shows template content, Next enabled
7. Remove via X → Reverts to placeholder, Next disabled

**Step 2 — Attach Supporting Sources:**
1. "Upload Relevant Files" section with suggested documents grid (checkboxes)
2. Search requirements → Click requirement → Shows associated documents
3. Select documents (max 10 total including uploads)
4. File Upload field for additional files (supported types only; unsupported shows validation)
5. "Supporting Notes" text area (optional, multi-line, persists across navigation)
6. Next enabled regardless of document selection (0 docs allowed)

**Step 3 — Provide Document Details:**
1. Document Name (mandatory; restricted chars `/;:` → validation message)
2. Description (visible only when AI skill OFF; hidden when ON)
3. Info message and image on right pane
4. Click "Generate Draft" → Redirected to Drafts grid with new draft record
5. Empty Document Name → Blocked with validation

---
