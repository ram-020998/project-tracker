# QE Knowledge Base — GSS (Source Selection)

This steering file provides solution-specific context for the QE Agent when testing the **GSS (Government Source Selection)** solution, also known as **SourceSelection** in the codebase.

---

## 1. Solution Overview

| Field | Value |
|-------|-------|
| Solution Name | Government Source Selection (GSS) |
| Application Prefix | AS_GSS |
| Jira Project | GAMS |
| Jira Component | GSS: Add New Evaluation, GSS: Vendors |
| Team | GAM Source Selection and Vendor Management Team |
| Sites | Source Selection, Source Selection Settings, Source Selection Vendor Data Migration |
| Google Chat Space ID | spaces/AAQAyK426Xg |

### Business Context

GSS enables government contracting officers to manage the source selection (evaluation) process for procurement. Key workflows include creating evaluations, assigning evaluator teams, managing vendors, rating proposals, building consensus reports, and selecting awardees.

### Evaluation Methods

| Method | Description |
|--------|-------------|
| Best Value | Full evaluation with factors, criteria, ratings, and consensus. Settings section visible. |
| LPTA (Lowest Price Technically Acceptable) | Simplified evaluation — pass/fail on technical requirements, award to lowest price. Settings section hidden. |

---

## 2. Test Environment

| Field | Value |
|-------|-------|
| Environment Name | GSS Test2 (MariaDB) |
| Site URL | https://eng-test-fed-aq-gss-test2.appianpreview.com |
| Site Name | Source Selection |
| Database | MariaDB |

### Navigation to GSS

1. Login at the site URL
2. Navigate to the "Source Selection" site from the Appian Tempo page
3. The landing page shows the Evaluations record list

---

## 3. Test Credentials (GSS Test2 MariaDB)

| Role | Username | Password |
|------|----------|----------|
| Contracting Officer | kelly.co | appian24 |
| Contracting Officer 2 | tom.meese | appian24 |
| Contract Specialist | casey.cs | appian23 |
| Contracting Manager | miles.cm | appian23 |
| Evaluator | riley.eval | appian23 |
| Evaluator 2 | melanie.connors | appian24 |
| Evaluation Chair | erin.evalchair | appian2021 |
| Criteria Chair | carla.cc | appian22 |
| Policy | policy1 | appian2021 |
| Legal | legal1 | appian2021 |
| Admin | GSS.admin | appian22 |
| IT | IT1 | appian21 |

### AM Users (on same environment)

| Role | Username | Password |
|------|----------|----------|
| Policy User | Policy1 | appian20 |
| Program Manager | program.manager | appian24 |
| Legal User | Legal1 | appian20 |
| IT | IT1 | appian20 |

### VM Users (on same environment)

| Role | Username | Password |
|------|----------|----------|
| Vendor Admin | vmvendor.user1 | appian22 |
| Vendor POC | vendor.poc1 | appian22 |

### Role Permissions Summary (GSS 2.9)

**Source:** GAM Permissions and Roles spreadsheet — "GSS 2.9" tab

#### Site & Workspace Access

| Role | GSS Site | Add New Evaluation | Active Evaluations | Eval Setup Progress | Overall Tasks Progress | Eval Tasks Progress |
|------|----------|-------------------|-------------------|--------------------|-----------------------|---------------------|
| Contracting Officer (CO) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Contract Specialist (CS) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Contracting Manager | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Evaluator | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Factor Chair | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Factor Advisor | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Evaluation Chief | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| IT/Policy/Legal | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Admin | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### Task Actions

| Role | Edit Due Dates | Mark Complete | Mark Not Needed | Claim Task | Reassign |
|------|---------------|--------------|-----------------|------------|----------|
| Contracting Officer (CO) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Contract Specialist (CS) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Contracting Manager | ✅ | ✅ | ✅ | ✅ | ✅ |
| Evaluator | ❌ | ❌ | ❌ | ❌ | ❌ |
| Factor Chair | ❌ | ❌ | ❌ | ❌ | ❌ |
| Factor Advisor | ❌ | ❌ | ❌ | ❌ | ❌ |
| Evaluation Chief | ✅ | ✅ | ✅ | ✅ | ✅ |
| IT/Policy/Legal | ❌ | ❌ | ❌ | ❌ | ❌ |
| Admin | ❌ | ❌ | ❌ | ❌ | ❌ |

#### Evaluation Record Tabs Visibility

| Role | Summary | Vendor Analysis | Factors | Consensus Tab | Consensus Summary | Consensus Signatures | Vendors | Vendors (Pricing) | Documents | Ratings | Teams | Evaluator Real Names | Tasks | Task History | Eval History |
|------|---------|----------------|---------|---------------|-------------------|---------------------|---------|-------------------|-----------|---------|-------|---------------------|-------|-------------|-------------|
| CO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CM | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Evaluator | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Factor Chair | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Factor Advisor | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Eval Chief | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| IT/Policy/Legal | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Admin | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |

#### Related Actions (Evaluation Record)

| Role | Continue Setup | Create Doc from Template | Add Task | Add Approach | Upload Docs | Delete Docs (ref only) | Submit Doc for Review | Update Vendor Doc Visibility | Update Evaluators | Complete Factor | Complete Evaluation | Duplicate Evaluation | Delete Evaluation | Update Name | Edit Summary Actions | Start Evaluation | Select Awardees | Create/View Award | Create Awards |
|------|---------------|------------------------|----------|-------------|-------------|----------------------|----------------------|-----------------------------|--------------------|----------------|--------------------|--------------------|------------------|-------------|---------------------|-----------------|----------------|-------------------|---------------|
| CO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CM | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Evaluator | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Factor Chair | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Factor Advisor | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Eval Chief | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| IT/Policy/Legal | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Admin | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### Vendor Tab Actions

| Role | Add New Vendor | Vendor List | Vendor Summary | Update Vendor | SAM.gov Sync |
|------|--------------|-------------|----------------|---------------|-------------|
| CO | ✅ | ✅ | ✅ | ✅ | ✅ |
| CS | ✅ | ✅ | ✅ | ✅ | ✅ |
| CM | ✅ | ✅ | ✅ | ✅ | ✅ |
| Evaluator | ❌ | ✅ | ✅ | ❌ | ❌ |
| Factor Chair | ❌ | ✅ | ✅ | ❌ | ❌ |
| Factor Advisor | ❌ | ✅ | ✅ | ❌ | ❌ |
| Eval Chief | ✅ | ✅ | ❌ | ❌ | ❌ |
| IT/Policy/Legal | ❌ | ✅ | ✅ | ❌ | ❌ |
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |

#### Source Selection Settings Site

| Role | Access |
|------|--------|
| Admin | ✅ |
| All other roles | ❌ |

---

## 4. Core Workflow: Evaluation Creation Form

### 4.1 Create Evaluation — Best Value Method

**Trigger:** Contracting Officer clicks "Create Evaluation" button on the Source Selection site.

**Form Sections:**
1. **Details** — Evaluation name, description, award type (Single/Multiple)
2. **Settings** — Visible for Best Value; contains evaluation configuration
3. **Personnel** — Evaluation Chair, Mask Evaluators toggle
4. **Dates** — Start date, Due date, POP dates

**Expected Behavior:**
- Settings section is **visible**
- "Mask Evaluators" field is **visible** in Personnel section
- "Evaluators" picker field is **hidden**

### 4.2 Create Evaluation — LPTA Method

**Trigger:** User selects "LPTA" as the Evaluation Method.

**Form Changes (compared to Best Value):**
- Settings section is **hidden**
- "Mask Evaluators" field is **hidden** from Personnel section
- New "Evaluators" field appears in Personnel section (multiple picker, max 5 users, mandatory)
- Start Date and Due Date fields move to the Details section

**On Save (LPTA):**
- Default Factor created: ID=LPTA-1, Title="Lowest Price Technically Acceptable"
- Rating set to "Acceptable/Unacceptable"
- Default Team created: "LPTA Evaluators" with selected evaluators
- Audit captured for: evaluation creation, default factor addition, default team addition

**Summary Page Differences (LPTA vs Best Value):**
- Ratings tab: **hidden**
- Consensus Reports tab: **hidden**
- Settings section: **hidden**
- Mask Evaluators field: **hidden**

### 4.3 Method Switching Behavior

When switching between LPTA and Best Value on the creation form:
- Previously entered data should be **preserved**
- Section visibility toggles correctly based on selected method
- Mandatory field validations apply per method

---

## 5. Test Plans

### 5.0 GSS 2.7 — Test Plan (GAMS-6127)

**Test Plan Key:** GAMS-6127
**Test Plan Name:** GSS 2.7 - Test plan
**Total Tests:** 9
**Epic:** GSS 2.7
**Status:** Closed

| # | Test Case Key | Summary | Tool Used | Type |
|---|---------------|---------|-----------|------|
| 1 | GAMS-6310 | Verify 'Select Awardees' for Single Award type - Best value evaluation | System Tests (Owl) | Functional |
| 2 | GAMS-3667 | Verify the LPTA evaluation task flow - Single Awardee | System Tests (Owl) | Functional |
| 3 | GAMS-6425 | Verify the LPTA evaluation task flow - Multi Awardee | System Tests (Owl) | Functional |
| 4 | GAMS-6328 | Verify 'Select Awardees' for Multiple Award type - Best value evaluation | System Tests (Owl) | Functional |
| 5 | GAMS-6443 | Verify the Evaluation when in Select Awardees status | Manual | Functional |
| 6 | GAMS-6424 | Verify Evaluations grid | Manual | Functional |
| 7 | GAMS-3347 | Creating/updating an evaluation - add and update Phases in summary page | Manual | Functional |
| 8 | GAMS-3450 | GSS: Duplicate Evaluation | System Tests (Owl) | Regression |
| 9 | GAMS-6493 | Verify the Update due date RA in evaluations with In progress and awardees selected status | Manual | Functional |

---

### 5.0a GSS 2.8 — Test Plan (GAMS-6748)

**Test Plan Key:** GAMS-6748
**Test Plan Name:** GSS 2.8 - Test plan
**Total Tests:** 8
**Epic:** GAMS-6339 (GSS 2.8: CW Integration Part 2)
**Fix Version:** GSS 2.8 (released 2026-01-23)
**Status:** Closed

| # | Test Case Key | Summary | Tool Used | Type |
|---|---------------|---------|-----------|------|
| 1 | GAMS-3450 | GSS: Duplicate Evaluation | System Tests (Owl) | Regression |
| 2 | GAMS-3554 | Verify the Create Evaluation flow from the Solicitation in GCW | Manual | Functional |
| 3 | GAMS-3542 | Verify the evaluation summary page details as GSS user | System Tests (FitNesse) | Functional |
| 4 | GAMS-3438 | As a GSS user on the Create Evaluation Wizard, I can complete the details on the Setup Milestone step | System Tests (FitNesse) | Functional |
| 5 | GAMS-6750 | Verify Create Awards flow from GSS evaluation | System Tests (Owl) | Functional |
| 6 | GAMS-4980 | As a AM user, validate the create evaluation form from AM solicitation | Manual | Functional |
| 7 | GAMS-4706 | As a contracting personnel, should be able to edit the details | System Tests (Owl) | Functional |
| 8 | GAMS-6922 | GSS: Verify the AI document Chat | Manual | Functional |

---

### 5.0b GSS 2.9 — Test Plan (GAMS-7942)

**Test Plan Key:** GAMS-7942
**Test Plan Name:** GSS 2.9 - Test plan
**Total Tests:** 5
**Epic:** GAMS-6339 (GSS 2.8: CW Integration Part 2)
**Fix Version:** GSS 2.8 (released 2026-01-23)
**Status:** Backlog

| # | Test Case Key | Summary | Tool Used | Type |
|---|---------------|---------|-----------|------|
| 1 | GAMS-7904 | Verify Highlights and Documents section in On spot consensus report | Manual | Functional |
| 2 | GAMS-7903 | Verify Highlights and Documents section in Complete LPTA form | Manual | Functional |
| 3 | GAMS-7897 | Verify Highlights and Documents section in Complete Evaluation form | Manual | Functional |
| 4 | GAMS-7766 | Verify 'Start Analysis' in vendor analysis tab | System Tests (Owl) | Functional |
| 5 | GAMS-7741 | Verify Vendor Analysis tab | System Tests (Owl) | Functional |

---

### 5.1 GAMS-3582 — Verify the LPTA Evaluation Creation Flow

**Component:** GSS: Add New Evaluation | **Status:** Backlog

**Steps:**
1. Login as CO → Create evaluation → Select LPTA method → Verify: Settings hidden, Evaluators picker shown (max 5, mandatory), Mask Evaluators hidden, dates moved to Details
2. Switch method to Best Value → Verify: Settings visible, Evaluators removed, Mask Evaluators shown
3. Switch back to LPTA → Verify: fields toggle correctly, previously entered data preserved
4. Fill mandatory fields → Create evaluation → Verify: evaluation created, audit captured for default factor and team
5. Navigate to Summary page → Verify: default factor card (LPTA-1, "Lowest Price Technically Acceptable"), Ratings/Consensus tabs hidden, Settings hidden
6. Navigate to Teams tab → Verify: "LPTA Evaluators" team created with evaluators
7. Navigate to Evaluation History → Verify: audit entries for creation, factor, team
8. Create evaluation from GCW solicitation → Verify: form fields rearranged, method behavior, factor/team auto-creation, fields disabled if evaluation exists
9. Validate LPTA tasks displayed in tasks grid

---

### 5.2 GAMS-3667 — LPTA Evaluation Task Flow (Single Awardee)

**Steps:**
1. CO/CS/CM creates LPTA evaluation (Single Award), adds >1 vendor, starts evaluation → Task assigned to CO (multiple evaluators) or Evaluator (single evaluator)
2. Navigate to summary → Complete Factor RA visible, allowed even if LPTA task not completed
3. Update evaluators → No impact on existing LPTA task, no task regeneration
4. Login as assigned user → Task visible in: evaluation tasks grid, Tasks tab, My Active Tasks
5. LPTA task enabled only for assigned user; Claim Task disabled for all; Reassign enabled for assigned user + CO/CS/EC
6. Non-assigned user sees task in disabled mode, no link available
7. Open LPTA task → Form shows vendor details (read-only): basic info, total price, pricing notes, breakdown, docs
8. Vendor decision section: Decision radio (required), Reason editor (required); Buttons: Cancel (first only), Save and Close, Submit/Next (disabled until decision), Back (after vendor 2)
9. Rejected tag shown for already-evaluated vendors
10. Submit → Task completed, status changes to "Awardees Selected", audit captured, Vendors section replaced with Awardees section
11. Awardees section: grid with Vendors, Decision Details link
12. Complete Evaluation → Full page form with title, description, winning vendors, Completion Date (mandatory, no future dates)
13. Complete → Status changes to "Complete", audit captured

---

### 5.3 GAMS-6425 — LPTA Evaluation Task Flow (Multi Awardee)

**Steps:**
1. CO/CS/CM creates LPTA evaluation (Multi Award), adds >6 vendors, starts evaluation
2. Same task assignment logic as Single Awardee
3. Same evaluator update behavior (no task regeneration)
4. Non-assigned users see task disabled
5. Assigned user sees task in all expected locations
6. Open LPTA task → Same vendor details form
7. First vendor: instruction "Select or Reject this vendor to review the next. This action cannot be undone."
8. Subsequent vendors: instruction shows running count "You have Selected X Vendors and Rejected Y Vendors so far..."
9. Buttons: Cancel (first only), Save and Close (all), Next (enabled after decision), Submit (enabled after ≥1 selected), Back (after vendor 2)
10. Submit → Status "Awardees Selected", Awardees section with search bar, Vendors + Decision Details columns, pagination 5/page
11. Complete Evaluation → Same as Single Awardee flow with Awardees grid (pagination 10/page, sorted by Total Amount ascending)

---

### 5.4 GAMS-6310 — Select Awardees (Single Award, Best Value)

**Steps:**
1. Create Best Value evaluation (Single Award), add vendors with price breakdown, start and complete factor tasks
2. Without completing "Complete Factor" → "Select Awardees" NOT visible
3. Complete Factor → "Select Awardees" becomes visible
4. Without consensus reports → Click Select Awardees → Modal with vendor grid (Vendors, Expiration Date, Business Type, Total Price, Consensus Ratings) + Selected Awardees panel
5. Instruction: "Select one vendor to submit"
6. Select vendor → Added to Selected Awardees, Submit enabled
7. Cancel → Returns to summary, no change
8. Total Price link → Price breakup popup (Item description, Quantity, Unit Price, Amount)
9. Consensus Ratings "View" link → Rating breakdown popup (or "No consensus ratings" message)
10. Submit → Status "Awardees Selected", audit captured, Vendors replaced with Awardees section
11. Complete Evaluation → Full page form, Completion Date mandatory (no future dates)
12. Complete → Status "Complete", audit captured

---

### 5.5 GAMS-6328 — Select Awardees (Multiple Award, Best Value)

**Steps:**
1. Create Best Value evaluation (Multiple Award), add vendors with price breakdown, start and complete factor tasks
2. Same visibility logic for Select Awardees RA
3. Select Awardees modal: multi-select checkboxes, instruction "A minimum of one vendor selection is required"
4. Select vendors → Added to Selected Awardees panel with count
5. Deselect → Removed from panel, count updated
6. Submit without selection → Validation "Select at least one awardee to submit"
7. Submit with selections → Status "Awardees Selected", Awardees section with search bar, pagination 5/page
8. Complete Evaluation → Same flow, Awardees grid with pagination 10/page

---

### 5.6 GAMS-6443 — Evaluation in "Awardees Selected" Status

**Verifications:**
- Summary tab RAs: Add Task, Upload Documents, Submit Document for review, Create Document from template, Complete Factor (LPTA), Complete Evaluation, Duplicate Evaluation, Delete
- Documents tab RAs: Upload, Submit for review, Create from template (Delete NOT available)
- Consensus Reports tab RAs: Open Consensus form, Save Consensus form
- Teams tab: "Update evaluators" is HIDDEN

---

### 5.7 GAMS-6424 — Evaluations Grid

**Verifications:**
- Landing page: My Workspace
- Evaluations page filters: Search bar ("Search Evaluations"), Status filter (Set up, In Progress, Awardees Selected, Complete), Due Date
- Grid columns: Evaluation, Description, Evaluation Method, Start Date, End Date

---

### 5.8 GAMS-6493 — Update Due Date RA

**Verifications:**
- Available ONLY for "In Progress" and "Awardees Selected" statuses
- NOT available for "Complete" or "Setup" statuses
- Modal: instruction text, read-only Start Date, editable Due Date (pre-populated)
- Validations: "Due Date requires a value", "End date should occur after the start date"
- On Update: summary page refreshed, audit history recorded
- On Cancel: no changes

---

---

## 6. Xray Test Repository

**Repository Folder:** `GSS` (Folder ID: `691afe62dedce6322920920c`)
**URL:** https://appian-eng.atlassian.net/projects/GAMS?selectedItem=com.atlassian.plugins.atlassian-connect-plugin:com.xpandit.plugins.xray__testing-board#!page=test-repository&selectedFolder=691afe62dedce6322920920c

All GSS test cases live under this folder in the Xray test repository. When creating new test cases, place them in the appropriate subfolder under GSS.

---

## 7. Open Bugs Query

To find open bugs for GSS, use this JQL:

```
project = GAMS AND type = Bug AND status != Closed AND component in ("GSS: Add New Evaluation", "GSS: Vendors") ORDER BY created DESC
```

### Known Open Bugs (Evaluation-Related)

| Key | Summary | Priority | Component | Status |
|-----|---------|----------|-----------|--------|
| GAMS-6978 | CO and CS pickers do not pull correct groups on Create Evaluation Form | Medium | GSS: Add New Evaluation | Backlog |
| GAMS-3915 | Multiple duplication + method switching creates duplicate factors with same ID | Not Set | GSS: Duplicate Evaluations | Backlog |
| GAMS-625 | Fix Update Evaluators Assignment Selection | Not Set | GSS: Update Evaluators RA | Backlog |
| GAMS-8372 | Inactive sub-factors copied over to duplicated evaluation | Not Set | GSS: Ratings tab | Backlog |
| GAMS-8535 | Incorrect AI Summary on Consensus Form | Not Set | GSS: Consensus Reports | Backlog |
| GAMS-8564 | Link indicated only by color (a11y) | Not Set | GSS: Accessibility | Backlog |
| GAMS-8550 | A11y issues with vendor document cards | Not Set | GSS: Accessibility | Backlog |
| GAMS-7223 | Form controls above grid become enabled behind user's perspective (a11y) | Not Set | GSS: Accessibility | Backlog |
| GAMS-6831 | Keyboard focus set to icon and link text individually (a11y) | Not Set | GSS: Accessibility | Backlog |

**Note:** The agent should check this list before creating new bugs to avoid duplicates. Use the JQL above to get the latest open bugs at test time.

---

## 8. GSS Documentation Reference

**Official Appian Docs:** https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-home-page-overview.html

Key documentation pages:
- [Home Page Overview](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-home-page-overview.html) — My Workspace, active evaluations, tasks
- [Creating a New Evaluation](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-creating-new-evaluation.html) — Full wizard walkthrough
- [Managing Evaluations](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-managing-evaluations.html) — Summary page, related actions, status transitions
- [Evaluating Vendors](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-evaluating-vendors.html) — Evaluator tasks, rating, LPTA vendor selection
- [Creating Consensus](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-creating-new-consensus.html) — Consensus forms, on-the-spot consensus
- [Configuring Phases](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-configuring-phases.html) — Phase setup and management
- [Modifying Dropdowns](https://docs.appian.com/suite/help/26.3/gss-25.4.2.9/gss-modifying-dropdown.html) — Rating methods and reference data

### Create Evaluation Form Fields (from Official Docs)

**Best Value method:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Solicitation PIID | Text | Yes | Procurement Instrument Identifier |
| Title | Text | Yes | Evaluation title |
| Description | Text area | Yes | Description of goods/services |
| Start Date | Date picker | Yes | Evaluation start |
| Due Date | Date picker | Yes | Evaluation end |
| Evaluation Method | Radio (Best Value / LPTA) | Yes | Determines form behavior |
| Reference Documents | File upload | No | PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX; max 15 |
| Multiple or Single Award IDV | Radio | Yes | Single Award or Multiple Award |
| Contracting Officer | Auto-suggest picker | Yes | From CO group |
| Contract Specialist | Auto-suggest picker | Yes | From CS group |
| Evaluation Chief | Auto-suggest picker | Yes | Evaluation chair |
| Mask Evaluators | Radio (Yes/No) | Yes | Substitutes names with aliases |
| Weighted Factors | Radio (Yes/No) | Yes | Enable factor weighting |
| Consensus Report Signatures | Radio (Required/Not Required) | Yes | Signing requirement |
| On the Spot Consensus | Radio (Yes/No) | Yes | Skip individual evaluator tasks |

**LPTA method (simplified — fields hidden):**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Solicitation PIID | Text | Yes | Same as Best Value |
| Title | Text | Yes | Same as Best Value |
| Description | Text area | Yes | Same as Best Value |
| Start Date | Date picker | Yes | Moved to Details section |
| Due Date | Date picker | Yes | Moved to Details section |
| Evaluation Method | Radio | Yes | Set to LPTA |
| Reference Documents | File upload | No | Same as Best Value |
| Multiple or Single Award IDV | Radio | Yes | Single or Multiple |
| Contracting Officer | Auto-suggest picker | Yes | From CO group |
| Contract Specialist | Auto-suggest picker | Yes | From CS group |
| Evaluation Chief | Auto-suggest picker | Yes | Evaluation chair |
| Evaluators | Multi-select picker | Yes | Max 5 users; added to default team |

**Fields HIDDEN for LPTA:** Mask Evaluators, Weighted Factors, Consensus Report Signatures, On the Spot Consensus, Settings section

### Rating Methods (Pre-configured)

| Rating Method | Values |
|---------------|--------|
| Color Rating | Blue, Purple, Green, Yellow, Red |
| Adjective Rating | Outstanding, Good, Acceptable, Marginal, Unacceptable |
| Risk Adjective Rating | Low, Moderate, High |
| Number Rating | 1, 2, 3, 4, 5 |
| Confidence Level Rating | Substantial, Satisfactory, Limited, No, Unknown |
| Acceptable/Unacceptable Rating | Acceptable, Unacceptable |

### Security Groups (Who Can Create Evaluations)

- `AS GSS Create or Update Evaluation PM Access` — Required to create/update evaluations
- Contracting Officer group — Automatically included
- Evaluation Chair group — Automatically included

---

## 9. Cross-Application Dependencies

GSS integrates with these solutions:

| Solution | Integration |
|----------|-------------|
| GCW (Contract Writing) | Create evaluation from solicitation, sync evaluation status, folder security |
| GSM (Vendor Management) | Vendor search, import from SAM.gov, create vendors |
| AM (Award Management) | Solicitation data for evaluation drafting |
| GAM (Shared Framework) | User types, groups, branding, i18n labels |

### Key Integration Points

- **Create Evaluation from GCW:** When creating an evaluation from a solicitation in GCW, the form pre-populates with solicitation data (method, dates, POP). If an evaluation already exists for the solicitation, all fields are disabled.
- **Vendor Sync:** GSS can import vendors from SAM.gov via the GSM integration.
- **Award Creation:** After evaluation completion, GSS triggers award creation in GCW.

---

## 10. GSS Record Types & Actions

### Evaluation Record Actions (Complete List)

| Action | Description |
|--------|-------------|
| Create Evaluation | Create new evaluation (Best Value or LPTA) |
| Start Evaluation | Move evaluation from Setup to In Progress |
| Continue Setup | Resume an incomplete evaluation setup |
| Add Approach | Add evaluation approaches/methodology |
| Add Task | Create ad-hoc tasks for evaluators |
| Add Teams | Assign evaluator teams to evaluation |
| Add Vendors | Add vendors to evaluation |
| Add Phases | Add evaluation phases to summary |
| Update Phases | Modify existing phases |
| Setup Factors | Configure factors and subfactors |
| Setup Criteria | Configure criteria for factors |
| Assign Factors | Assign factors to teams |
| Weighted Factors | Configure factor weights |
| Complete Factor | Mark a factor as complete |
| Select Awardees | Choose winning vendor(s) |
| Complete Evaluation | Finalize evaluation with completion date |
| Update Due Date | Modify evaluation due date |
| Update Evaluators | Add/remove/reassign evaluators |
| Upload Documents | Upload documents to evaluation |
| Submit Document for Review | Submit doc for review workflow |
| Create Document from Template | Generate doc from template |
| Update Vendor Doc Visibility | Control vendor document access |
| Duplicate Evaluation | Clone an existing evaluation |
| Delete Evaluation | Delete an evaluation |
| Start Analysis | AI-powered vendor proposal analysis |
| Save and Close (wizard) | Save milestone progress mid-wizard |
| Review Evaluation Setup | Review all milestones before starting |

### Actions Available by Evaluation Status

#### Setting Up

| Action | Available |
|--------|-----------|
| Continue Setup | ✅ |
| Add Approach | ✅ |
| Add Teams | ✅ |
| Add Vendors | ✅ |
| Add Phases | ✅ |
| Setup Factors | ✅ |
| Setup Criteria | ✅ |
| Assign Factors | ✅ |
| Weighted Factors | ✅ |
| Review Evaluation Setup | ✅ |
| Start Evaluation | ✅ (only when all milestones complete) |
| Upload Documents | ✅ |
| Delete Evaluation | ✅ |
| Duplicate Evaluation | ✅ |
| Update Due Date | ❌ |
| Select Awardees | ❌ |
| Complete Evaluation | ❌ |
| Complete Factor | ❌ |
| Update Evaluators | ❌ |

#### In Progress

| Action | Available |
|--------|-----------|
| Add Task | ✅ |
| Upload Documents | ✅ |
| Submit Document for Review | ✅ |
| Create Document from Template | ✅ |
| Complete Factor | ✅ |
| Update Due Date | ✅ |
| Update Evaluators | ✅ |
| Update Vendor Doc Visibility | ✅ |
| Add Phases | ✅ |
| Update Phases | ✅ |
| Duplicate Evaluation | ✅ |
| Delete Evaluation | ✅ |
| Start Analysis | ✅ |
| Select Awardees | ✅ (only after Complete Factor) |
| Complete Evaluation | ❌ (must select awardees first) |
| Continue Setup | ❌ |
| Start Evaluation | ❌ |

#### Awardees Selected

| Action | Available |
|--------|-----------|
| Complete Evaluation | ✅ |
| Add Task | ✅ |
| Upload Documents | ✅ |
| Submit Document for Review | ✅ |
| Create Document from Template | ✅ |
| Complete Factor (LPTA only) | ✅ |
| Update Due Date | ✅ |
| Duplicate Evaluation | ✅ |
| Delete Evaluation | ✅ |
| Open Consensus Form | ✅ |
| Save Consensus Form | ✅ |
| Update Evaluators | ❌ (hidden) |
| Select Awardees | ❌ (already done) |
| Delete Document | ❌ (not available in this status) |

#### Complete

| Action | Available |
|--------|-----------|
| Duplicate Evaluation | ✅ |
| View (read-only access to all tabs) | ✅ |
| Update Due Date | ❌ |
| Update Evaluators | ❌ |
| Add Task | ❌ |
| Upload Documents | ❌ |
| Delete Evaluation | ❌ |
| Select Awardees | ❌ |
| Complete Evaluation | ❌ (already done) |

### Evaluation Vendor Actions

| Action | Description |
|--------|-------------|
| Add Existing Vendor | Add vendor from registry to evaluation |
| Add New Vendor | Create and add new vendor |
| Edit Vendor | Modify vendor details |
| Remove Vendor | Remove vendor from evaluation |
| View Vendor | View vendor details |
| View Price Breakdown | View vendor price breakup |
| View Decision (LPTA) | View LPTA accept/reject decision |
| Sync from SAM.gov (UEI) | Import vendor by UEI |
| Sync from SAM.gov (CAGE) | Import vendor by CAGE code |
| Sync from SAM.gov (DUNS) | Import vendor by DUNS number |
| SLG Toggle Vendor Details | Vendor details with SLG toggle on |

### Consensus Report Actions

| Action | Description |
|--------|-------------|
| Open Consensus Form | Start a new consensus report |
| Continue Consensus Form | Resume an in-progress consensus |
| Add Version | Create a new version of consensus report |
| Sign | Sign the consensus report |

### Task Actions (Dynamic Record)

| Action | Description |
|--------|-------------|
| Claim Task | Claim an unassigned task |
| Mark Complete | Complete a task |
| Mark Not Needed | Mark task as not needed |
| Reassign | Reassign task to another user |
| Edit Due Dates | Modify task due dates |
| Review (Task) | Review a completed task |
| Add/Edit/Delete Comments | Manage task comments |

### Ref Vendor Actions

| Action | Description |
|--------|-------------|
| Add Vendor | Add to vendor registry |
| Create Vendor Manually | Manual vendor creation |
| Sync with SAM Gov | Import/sync from SAM.gov |
| Update Vendor | Update vendor registry entry |

---

## 11. Evaluation Statuses

| Status | Description |
|--------|-------------|
| Setting Up | Initial state after creation |
| In Progress | Evaluation actively being worked |
| Awardees Selected | Winning vendor(s) chosen |
| Complete | Evaluation finalized |

---

## 12. Known Quirks & Testing Notes

- **Page Load:** Always wait for the Appian progress bar to disappear before interacting with elements.
- **Picker Fields:** Evaluator picker requires typing 2-3 characters before suggestions appear.
- **Method Toggle:** When switching evaluation methods, wait briefly for the form to re-render before validating field visibility.
- **Audit Trail:** Audit entries may take a few seconds to appear in the Evaluation History tab after creation.
- **GCW Integration:** Creating an evaluation from GCW requires the solicitation to exist first. If testing this flow, ensure GCW data is set up.
- **Max Evaluators (LPTA):** The Evaluators picker allows a maximum of 5 selections. Attempting to add more should show a validation error.

---

## 13. Workflow: Add Vendors

### Trigger
Contracting Officer or Contract Specialist clicks "Add Vendors" (or "Add" in the Vendors card) on an evaluation in **Setting Up** or **In Progress** status.

### Process Flow

1. User opens the Add Vendors form
2. Form presents a multi-step wizard:
   - **Step 1 — Select Vendors:** Search and select vendors from:
     - GSS vendor registry (existing vendors)
     - GSM/VM integration (Federal or State & Local Government)
     - SAM.gov sync (by UEI, CAGE, or DUNS)
     - Manual creation
   - **Step 2 — Capture Vendor Information:** Enter/confirm vendor details (legal name, address, business type, expiration date)
   - **Step 3 — Price Breakdown:** Enter pricing (item description, quantity, unit price, amount) and pricing notes
   - **Step 4 — Upload Documents:** Upload vendor proposal documents (PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX)
3. On Submit:
   - Vendor data saved
   - GSM integration updated (if vendor sourced from VM)
   - Documents moved/deleted as needed
   - Audit captured

### Vendor Sources
| Source | Description | Toggle |
|--------|-------------|--------|
| GSS Registry | Existing vendors in the GSS vendor table | Always available |
| GSM Federal | Vendors from Government Supplier Management (Federal) | VM Integration toggle |
| GSM State & Local | Vendors from GSM (SLG variant) | SLG toggle enabled |
| SAM.gov | Import by UEI/CAGE/DUNS from SAM.gov | Always available |
| Manual | Create vendor manually | Always available |

### Vendor Card Actions (on Evaluation Summary)
| Action | Description |
|--------|-------------|
| Update Vendor | Edit vendor details via Update Vendor wizard |
| Delete Vendor | Remove vendor from evaluation (confirmation required) |
| View Price Breakdown | View vendor price breakup popup |
| View Decision (LPTA) | View accept/reject decision details |

### VM Integration Notes
- When GSS is integrated with VM, an "Update Required" tag appears next to a vendor when the vendor resubmits a proposal in VM
- If a vendor withdraws a proposal after being added to the evaluation, the vendor is removed automatically
- Vendor documents can be imported from VM

---

## 14. Workflow: Start Evaluation

### Trigger
Contracting Officer clicks "Start Evaluation" on an evaluation in **Setting Up** status (all setup milestones must be complete).

### Process Flow

1. User opens Start Evaluation form
2. System validates all milestones are complete
3. On Submit:
   - Evaluation status updated to "In Progress"
   - Status synced to GCW (if linked to solicitation)
   - Rating records populated (parent and child ratings)
   - Factors and subfactors updated with ratings
   - **Workflow branching based on method:**
     - **Best Value:** Generate evaluation tasks per assignee → Create consensus reports → Capture audit
     - **LPTA:** Generate LPTA task → Send email to assignee → Capture audit
     - **On The Spot Consensus:** Create consensus reports directly (skip individual evaluator tasks) → Capture audit
   - AI requirement extraction triggered (if toggle enabled)

### Task Generation Logic
- **Best Value:** One task per evaluator per assigned factor. Tasks assigned to evaluator team members.
- **LPTA:** Single LPTA task created. Assigned to evaluator(s) selected during creation. Email sent to assignee.
- **On The Spot Consensus:** No individual evaluator tasks. Consensus reports created directly for each factor.

### Pre-conditions for Start
- At least one factor configured
- At least one vendor added
- At least one team with evaluators assigned
- Factors assigned to teams
- All mandatory milestones in the setup checklist completed

---

## 15. Workflow: Consensus Reports

### Overview
Consensus reports capture the evaluation team's agreed-upon assessment of each vendor for each factor. They are created automatically when an evaluation starts (Best Value method).

### Consensus Report Statuses
| Status | Description |
|--------|-------------|
| Not Started | Report created but not yet opened |
| In Progress | Report opened and being worked on |
| Awaiting Signatures | Report completed, waiting for required signatures |
| Complete | All signatures collected (or signatures not required) |

### Process Flow

1. User clicks "Open Consensus Form" on a consensus report record
2. System opens the consensus form
3. Form sections:
   - **Left Panel:** Factor details, vendor list, evaluation responses from individual evaluators
   - **Right Panel:** Consensus response entry area
   - **Include/Exclude Responses:** Toggle which individual evaluator responses to include
   - **Combined Responses:** AI-combined responses from multiple evaluators
   - **Final Rating & Comments:** Select consensus rating and enter comments
4. On Save:
   - Consensus responses written to data store
   - Status updated (In Progress, Complete, or Awaiting Signatures)
   - If Complete: consensus document generated from template
   - If Awaiting Signatures: signatures built, document generated, email sent to signers

### Consensus Form Milestones
The consensus form uses a milestone-based wizard:
- Select evaluation ratings to include
- Enter standalone responses (strengths, weaknesses, risks)
- Enter combined responses
- Final rating and comments
- Review and submit

### Consensus Document Generation
- Generated as Word document from template
- Includes: factor details, responses by type, ratings, signatures (if required)
- Document stored in evaluation documents with type "Consensus"
- Factor-document mapping maintained for traceability

### Signature Flow
- When "Consensus Report Signatures" is set to "Required" in evaluation settings:
  - After completing the consensus form, status moves to "Awaiting Signatures"
  - Signers determined based on evaluation personnel configuration
  - Email sent to each signer
  - Each signer must sign via the "Sign" action
  - After all signatures collected, status moves to "Complete"

### AI Features in Consensus
- **Combine Responses:** AI combines multiple evaluator responses into a single consensus response
- **Summarize Responses:** AI summarizes individual evaluator responses
- **AI Summary on Consensus Form:** Shows AI-generated summary (known bug: GAMS-8535 — incorrect AI summary)

---

## 16. Workflow: Complete Evaluation

### Trigger
Contracting Officer clicks "Complete Evaluation" on an evaluation in **Awardees Selected** status.

### Process Flow

1. User opens Complete Evaluation form
2. Form displays:
   - Evaluation title (read-only)
   - Description (read-only)
   - Winning vendor(s) / Awardees grid
   - **Completion Date** (mandatory, date picker — no future dates allowed)
3. On Submit:
   - Original evaluation record fetched
   - Evaluation status updated to "Complete"
   - Status synced to GCW
   - Audit captured (field-level audit for status change)
4. On Cancel: returns to summary, no changes

### Post-Completion State
- Evaluation becomes read-only
- Only "Duplicate Evaluation" action remains available
- All tabs viewable but no edit actions
- Tasks cannot be added or modified
- Documents cannot be uploaded or deleted

---

## 17. Workflow: Update Evaluators

### Trigger
Contracting Officer, Contract Specialist, or Evaluation Chair clicks "Update Evaluators" on an evaluation in **In Progress** status.

### Process Flow (from Official Docs)

1. Open Update Evaluators wizard from:
   - Summary tab → More options (…) → "Update Evaluators"
   - Teams tab → "UPDATE EVALUATORS" button
2. **Step 1 — Select Team:** Choose evaluator team to update from Teams panel
3. **Step 2 — Add/Remove Evaluators:**
   - Add: Click "ADD EVALUATORS" → Search via multi-select auto-suggest → Click "ADD"
   - Remove: Select evaluator checkbox(es) → Click "REMOVE EVALUATORS"
4. **Step 3 — Verify Factor Assignments:**
   - Select Evaluation Team (dropdown)
   - Select Evaluators (multi-select dropdown)
   - Select Due Date (date picker — must be future date, before evaluation due date)
5. Click "UPDATE" to save changes
6. Click "CLOSE" to exit wizard

### Constraints
- NOT available when evaluation status is "Awardees Selected" or "Complete"
- NOT available when evaluation status is "Setting Up" (use setup wizard instead)
- Due dates assigned to factors must be in the future and before the evaluation due date
- For LPTA evaluations: updating evaluators does NOT regenerate the LPTA task

---

## 18. Workflow: Select Awardees (Best Value)

### Trigger
Contracting Officer or Evaluation Chair clicks "Select Awardees" on an evaluation in **In Progress** status (only visible after all factors marked complete via "Complete Factor" action).

### Process Flow (from Official Docs + Test Cases)

1. Click "Select Awardees" link in the Vendors section of the Summary tab
2. Modal opens with:
   - Vendor grid: Vendors, Expiration Date, Business Type, Total Price, Consensus Ratings
   - Selected Awardees panel (right side)
3. **Single Award:** Select exactly one vendor → Submit
4. **Multiple Award:** Select one or more vendors (checkboxes) → Submit
5. On Submit:
   - Evaluation status changes to "Awardees Selected"
   - Audit captured
   - Vendors section replaced with Awardees section on Summary
   - If evaluation created from GCW solicitation: vendor-submitted documents automatically attach to the related solicitation record

### Awardees Section (Post-Selection)
- Grid with: Vendor name, Decision Details link
- For Multiple Award: search bar, pagination (5/page)
- "Create Award" button per awardee (if GCW integration active)
- "View Award" link (after award created)

---

## 19. Workflow: Create Awards (GCW Integration)

### Pre-requisite
- Evaluation must be created from a solicitation in GCW
- Awardees must be selected (status = "Awardees Selected")

### Single Award Creation
1. Navigate to evaluation summary → Awardees section
2. Click "Create Award" for the target awardee
3. Solicitation details auto-populate (Instrument Type and Multiple/Single Award IDV are read-only)
4. Update award details as needed
5. Click "CREATE"
6. Award link displayed → clicking navigates to award summary in GCW
7. Award status changes to "Created" in evaluation summary

### Multiple Awards Creation
1. Navigate to evaluation summary → Awardees section
2. Select awardee checkboxes
3. Click "CREATE AWARDS"
4. Solicitation details auto-populate (Instrument Type is read-only)
5. Update award details as needed
6. Click "CREATE AWARD(S)"
7. Multiple awards creation takes a few minutes to complete
8. Award statuses change to "Created" in evaluation summary

---

## 20. Evaluation Summary Tabs — Detailed Workflows

### 20.1 Summary Tab
- Default tab when opening an evaluation record
- Displays: status, important dates, factors card, approach, contracting team, vendors/awardees, solicitation card, opportunity card
- Edit icons for: Details, Description, Personnel, Phases
- "Continue Setup" in Factors card (Setting Up status only)
- "Add" in Vendors card
- Related Actions accessible via "…" more options menu

### 20.2 Vendor Analysis Tab
- Available only for Best Value evaluations after AI analysis is complete
- Displays vendor cards with analysis status
- Click vendor → Detailed analysis view:
  - **Overall Summary:** High-level summary across all factors
  - **Factor Analysis:** Findings organized by factor with:
    - Summary: Detailed factor-wise findings summary
    - What: Brief label identifying the finding category
    - Text: What the vendor stated/demonstrated
    - Source: Document name, section, and page reference
  - Click Source link → Opens referenced document at specific section/page in popup

### 20.3 Factors Tab
- Lists all factors assigned to the evaluation
- Expand each factor to see subfactors
- Shows: Factor ID, Title, Rating Method, Weight (if weighted), Status, Assigned Team

### 20.4 Vendors Tab
- Lists all vendors assigned to the evaluation
- Search and filter capabilities
- Vendor cards with: Legal Name, UEI, CAGE, Business Type, Expiration Date, Total Price
- Actions per vendor: Update Vendor, Delete Vendor, View Price Breakdown

### 20.5 Ratings Tab (Best Value Only — Hidden for LPTA)
- Shows rating results for each vendor
- Columns: Vendor, Factor, Subfactor, Rating, Evaluator
- Filter by: Vendor, Factor, Team
- Download rating summary per vendor
- Rating legend displayed

### 20.6 Consensus Reports Tab (Best Value Only — Hidden for LPTA)
- Lists all vendor consensus reports
- Columns: Vendor, Factor, Status
- Click vendor link → Opens consensus report
- Actions: Open Consensus Form, Continue Consensus Form, Add Version, Sign

### 20.7 Documents Tab
- Lists all documents associated with the evaluation
- Document types: Vendor, Evaluator, Factor, Consensus, Recommendation
- Actions: Upload Documents, Submit Document for Review, Create Document from Template
- Delete Document: NOT available in "Awardees Selected" status

### 20.8 Teams Tab
- Lists evaluator teams with member names and contact info
- "UPDATE EVALUATORS" button (In Progress status only, hidden in Awardees Selected)
- Shows: Team Name, Members, Assigned Factors

### 20.9 Tasks Tab
- Lists all tasks associated with the evaluation
- Sorted by: Outstanding, Completed, Not Needed, Canceled
- Task actions: Claim Task, Mark Complete, Mark Not Needed, Reassign, Edit Due Dates

### 20.10 Task History Tab
- Log of all completed tasks for the evaluation
- Shows: Task Name, Assignee, Completion Date, Status

### 20.11 Evaluation History Tab
- Audit log of all edits, updates, and deletions
- Shows: Action, User, Date/Time, Details
- Entries for: creation, status changes, vendor additions/removals, team changes, factor updates, document actions

---

## 21. AI Features

### 21.1 Start Analysis (Vendor Response Analysis)
- **Trigger:** Contracting Officer clicks "Start Analysis" on an In Progress evaluation
- **Pre-requisite:** Evaluation started, vendors added with proposal documents
- **Process:**
  1. AI extracts requirements from: evaluation title, description, factor descriptions, instructions, solicitation text (from GCW)
  2. CO initiates vendor response analysis (max 10 vendors at a time)
  3. AI analyzes vendor proposals against extracted requirements
  4. Results displayed in Vendor Analysis tab

### 21.2 AI Rating Suggestions
- **Trigger:** Available during evaluator task completion
- **Process:** AI suggests ratings based on vendor analysis findings

### 21.3 AI Factor Summary Generation
- **Trigger:** During consensus form completion
- **Process:** AI generates a summary of all evaluator responses for a factor

### 21.4 AI Consensus Response Combination
- **Trigger:** During consensus form — "Combine Responses" action
- **Process:** AI combines multiple evaluator responses into a unified consensus response

### 21.5 Document Chat
- **Trigger:** Available on evaluation documents
- **Process:** AI-powered chat interface for querying document content

### 21.6 Language Validation
- **Trigger:** During evaluator response entry
- **Process:** AI evaluates language used in evaluator responses for compliance

---

## 22. Test Data Setup Instructions

### 22.1 Creating an Evaluation in "Setting Up" Status
1. Login as `kelly.co` / `appian24`
2. Navigate to Source Selection site
3. Click "CREATE NEW EVALUATION"
4. Fill required fields (Solicitation PIID, Title, Description, Method, Award Type, CO, CS, Evaluation Chief, dates)
5. Save — evaluation is now in "Setting Up" status

### 22.2 Creating an Evaluation in "In Progress" Status
1. Create evaluation (see 23.1)
2. Complete all setup milestones:
   - Add at least one factor (Setup Factors)
   - Add at least one team with evaluators (Add Teams)
   - Add at least one vendor (Add Vendors)
   - Assign factors to teams (Assign Factors)
3. Click "Start Evaluation" → Evaluation moves to "In Progress"

### 22.3 Creating an Evaluation in "Awardees Selected" Status
1. Create and start evaluation (see 23.2)
2. Complete all evaluator tasks (login as evaluator, complete rating tasks)
3. Complete Factor (click "Complete Factor" for each factor)
4. Click "Select Awardees" → Select vendor(s) → Submit
5. Evaluation moves to "Awardees Selected"

### 22.4 Creating an Evaluation in "Complete" Status
1. Get evaluation to "Awardees Selected" (see 23.3)
2. Click "Complete Evaluation"
3. Enter Completion Date (must be today or past)
4. Click "COMPLETE EVALUATION"
5. Evaluation moves to "Complete"

### 22.5 Adding Vendors with Price Breakdown
1. On evaluation summary, click "Add" in Vendors card
2. Search/select vendor from registry or create manually
3. Enter vendor details (legal name, address, business type)
4. Enter price breakdown:
   - Item Description, Quantity, Unit Price → Amount auto-calculated
   - Add multiple line items as needed
   - Enter Pricing Notes (optional)
5. Upload proposal documents (optional)
6. Click Submit

### 22.6 LPTA-Specific Test Data
- When creating LPTA evaluation, select 1-5 evaluators in the Evaluators picker
- After starting: single LPTA task is created and assigned
- Add multiple vendors (>1 for Single Award, >6 for Multi Award testing)
- Each vendor needs: basic info + total price at minimum

---

## 23. Feature Toggles & Admin Settings

### Known Feature Toggles

| Toggle | Description | Impact |
|--------|-------------|--------|
| VM Integration Toggle | Enables/disables VM integration for vendor search | Controls whether "Search from VM" option appears in Add Vendors |
| Evaluation Chief Visibility | Controls Evaluation Chief field visibility | Affects personnel section in create/edit forms |
| Consensus Report Signature | Controls consensus signature requirement toggle | Affects whether signatures section appears in settings |
| Automation Testing Toggle | Enables automation testing mode | May affect timing/behavior for automated tests |
| State & Local Government (SLG) | SLG toggle | Controls SLG-specific vendor flows and UI elements |

### Admin Settings (Source Selection Settings Site)
- Accessible by Admin role (`GSS.admin` / `appian22`)
- Manages: Rating methods, dropdown values, reference data
- Site: "Source Selection Settings"

---

## 24. Duplicate Evaluation Workflow

### Trigger
Available in all statuses except during active setup wizard.

### Process Flow
1. Click "…" more options → "Duplicate Evaluation"
2. System creates a copy of the evaluation with:
   - New evaluation ID
   - Status reset to "Setting Up"
   - Factors, subfactors, and criteria copied
   - Teams and assignments copied
   - Vendors NOT copied (must be re-added)
   - Documents NOT copied
   - Ratings and consensus NOT copied
3. Audit captured for duplication

### Known Bug
- **GAMS-3915:** Multiple duplication + method switching creates duplicate factors with same ID

---

## 25. Delete Evaluation Workflow

### Trigger
Available in Setting Up, In Progress, and Awardees Selected statuses. NOT available in Complete status.

### Process Flow
1. Click "…" more options → "Delete"
2. Delete Evaluation wizard opens
3. Enter "Reason for deletion" (required)
4. Click "DELETE"
5. Evaluation and all associated data (documents, tasks, vendors, ratings, consensus) permanently deleted

### Warning
- Evaluations cannot be recovered once deleted
- All associated data is also deleted
- Audit trail is lost

---

## 26. Task Management Workflows

### Task Types
| Task Type | Generated By | Assigned To |
|-----------|-------------|-------------|
| Evaluation Task (Best Value) | Start Evaluation | Evaluators (per factor assignment) |
| LPTA Task | Start Evaluation (LPTA) | Assigned evaluator(s) |
| Ad-hoc Task | "Add Task" action | Specified user |
| Document Upload Task | System-generated | Specified user |
| Document Template Task | "Create Document from Template" | Specified user |

### Task Actions
| Action | Who Can Perform | Description |
|--------|----------------|-------------|
| Claim Task | Unassigned task — any team member | Claim an unassigned task |
| Mark Complete | Assigned user, CO, CS, EC | Mark task as completed |
| Mark Not Needed | CO, CS, EC | Mark task as not needed (skipped) |
| Reassign | Assigned user, CO, CS, EC | Reassign to another user |
| Edit Due Dates | CO, CS, EC | Modify task due dates |
| Review | CO, CS, EC | Review a completed task |

### Task Statuses
| Status | Description |
|--------|-------------|
| Outstanding | Task is active and pending completion |
| Completed | Task has been marked complete |
| Not Needed | Task was marked as not needed |
| Canceled | Task was canceled (e.g., evaluation deleted) |

### Nightly Process
- System sends email notifications for tasks that are due or overdue

---

## 27. Document Management Workflows

### Document Types
| Type | Description |
|------|-------------|
| Vendor | Vendor proposal documents |
| Evaluator | Evaluator-uploaded documents |
| Factor | Factor-related documents |
| Consensus | Generated consensus report documents |
| Recommendation | Recommendation documents |

### Document Actions
| Action | Description | Availability |
|--------|-------------|--------------|
| Upload Documents | Upload files to evaluation | Setting Up, In Progress, Awardees Selected |
| Submit Document for Review | Submit doc for review workflow | In Progress, Awardees Selected |
| Create Document from Template | Generate doc from Word template | In Progress, Awardees Selected |
| Delete Document | Remove document | In Progress only (NOT in Awardees Selected) |
| Download | Download document | All statuses |

### Supported File Types
PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX

### Document Storage
- Documents stored in Appian document management
- SharePoint integration available for document storage
- Factor-document mapping maintained for traceability

---

## 28. Vendor Data Migration (DRM)

### Site
"Source Selection Vendor Data Migration" — separate site for migrating vendor data

### Capabilities
- Migrate vendor data from legacy systems
- Reconcile vendor records between systems
- Track migration and reconciliation status

---

## 29. GCW Integration Testing Pre-requisites

### To Test "Create Evaluation from Solicitation"
1. Ensure GCW solution is deployed in the environment
2. Create a solicitation in GCW first
3. Navigate to the solicitation in GCW
4. Use the "Create Evaluation" action from the solicitation
5. Form pre-populates with solicitation data (method, dates, POP)
6. If an evaluation already exists for the solicitation, all fields are disabled

### Integration Points to Verify
| Integration | What to Test |
|-------------|-------------|
| Create Eval from Solicitation | Form pre-population, field disabling if eval exists |
| Status Sync | When GSS evaluation status changes, GCW solicitation reflects it |
| Folder Security | Evaluation folder security updated based on solicitation access |
| Award Creation | After awardees selected, "Create Award" triggers GCW award creation |
| Document Sync | Vendor documents attach to solicitation record after awardee selection |


---

## 30. Data Generator — GSS Evaluation Setup Reference

### Record Type UUIDs (GSS)

| Table | Record Type UUID | Key Fields |
|-------|-----------------|------------|
| AS_GSS_EVALUATION | `e6bc8561-d3a6-4679-b7af-6e279910468e` | evaluationId (PK), evaluationStatusId, evaluationMethodId, idvAwardTypeId |
| AS_GSS_CRITERIA (Factors) | `11dcc745-3c81-49f9-9cb2-6427680e4b41` | criteriaId (PK), evaluationId (FK), criteriaStatusId, evaluatorTeamId |
| AS_GSS_EVALUATOR_TEAM | `791d954b-beae-4171-808f-876583d707fa` | teamId (PK), evaluationId (FK) |
| AS_GSS_TEAM_MEMBERSHIP | `7ac70e31-adcc-4145-a566-fcfe1f55146d` | teamMembershipId (PK), teamId (FK), member (username) |
| AS_GSS_EVALUATION_VENDOR | `b6081510-0d11-4d51-8eba-966610b168db` | vendorId (PK), evaluationId (FK), totalPrice |
| AS_GSS_VENDOR_PRICE_BREAKUP | `e29f01c8-20bf-4220-8797-7fe0041be362` | itemId (PK), evalVendorId (FK), unitPrice, quantity, amount |
| AS_GSS_TMG_TASK | `9a04b944-b726-41f5-9b37-8ec71b6cc370` | taskId (PK), evaluationId (FK), criteriaId, vendorId |
| AS_GSS_EVALUATION_PHASE | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` | evaluationPhaseId (PK), evaluationId (FK) |
| AS_GSS_R_DATA (Reference) | `c34b12a0-4ae7-4d21-adb9-09320118b98e` | refDataId (PK), refLabel, refType |
| AS_GSS_RATING | `49daf634-1b3a-4396-99e9-f95bff85ff03` | ratingId (PK), evaluationId, parentRatingId, refRatingId |
| AS_GSS_EVALUATION_PHASE | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` | evaluationPhaseId (PK), evaluationId (FK), taskCategoryId |
| AS_GSS_A_R_EVALUATION (Audit) | `5c676254-a475-43db-8f6f-bac9694e0a05` | Evaluation audit records |
| AS_GSS_A_R_EVALUATION_FIELD (Audit Fields) | `9721dd98-5c92-477b-be08-958113dc28e5` | Field-level audit entries |
| AS_GSS_EVALUATION_STATUS_HISTORY | — | Status transition history |

### Reference Data IDs (AS_GSS_R_DATA)

| refDataId | refLabel | refType |
|-----------|----------|---------|
| 1 | Set up | Evaluation Status |
| 2 | In Progress | Evaluation Status |
| 3 | Complete | Evaluation Status |
| 5 | Best Value | Evaluation Method |
| 34 | Temp | Evaluation Status |
| 61 | Deleted | Evaluation Status |
| 67 | Lowest Price Technically Acceptable | Evaluation Method |
| 77 | Single Award | IDV Award Type |
| 78 | Multiple Award | IDV Award Type |
| 79 | Awardees Selected | Evaluation Status |
| 35 | Not Started | Task Status |
| 36 | In Progress | Task Status |

### Criteria (Factor) Status IDs

| criteriaStatusId | Meaning |
|-----------------|---------|
| 1 | Not Started / Active |
| 2 | Complete |

### Data Generator — Proven Successful Operations

The following records have been CONFIRMED to work via `create_record` / `update_record`:

| Operation | Status | Notes |
|-----------|--------|-------|
| Create evaluation | ✅ Works | All fields including evaluationMethodId, idvAwardTypeId, personnel |
| Create factor (criteria) | ✅ Works | With evaluationId FK, criteriaName, factorNumber |
| Create team | ✅ Works | With evaluationId FK, teamName |
| Create team membership | ✅ Works | With teamId FK, member username (some usernames may 500 — try alternatives) |
| Create vendor | ✅ Works | With evaluationId FK, legalName, totalPrice, uniqueEntityId, cageCode |
| Create price breakup | ✅ Works | With evalVendorId FK, itemDescription, unitPrice, quantity, amount |
| Update evaluation status | ✅ Works | Set evaluationStatusId to any valid value |
| Update factor status | ✅ Works | Set criteriaStatusId=2 for complete |
| Link team to factor | ✅ Works | Update criteria with evaluatorTeamId |

### Data Generator — Full Evaluation Setup Sequence

To create a GSS evaluation in a specific precondition state, follow this EXACT sequence:

```
1. create_record(AS_GSS_EVALUATION) → evaluationId
   Fields: evaluationTitle, evaluationNumber, evaluationDescription, evaluationMethodId,
           idvAwardTypeId, evaluationStatusId=1, evaluationStartDate, evaluationDueDate,
           contractingOfficer, contractingSpecialist, evaluationChief,
           isSignaturesRequired, isWeightedFactorsRequired, isEvaluatorMasked,
           isOnSpotConsensus, isActive=true, createdBy, modifiedBy

2. create_record(AS_GSS_CRITERIA) → criteriaId
   Fields: evaluationId (from step 1), factorNumber, criteriaName, criteriaDescription,
           criteriaChair, isActive=true, isDefaultEntry=false, createdBy, modifiedBy

3. create_record(AS_GSS_EVALUATOR_TEAM) → teamId
   Fields: evaluationId (from step 1), teamName, teamDescription,
           isActive=true, isDefaultEntry=false, createdBy, modifiedBy

4. create_record(AS_GSS_TEAM_MEMBERSHIP) × N evaluators
   Fields: teamId (from step 3), member (username), isActive=true, createdBy, modifiedBy

5. update_record(AS_GSS_CRITERIA) — link team to factor
   Fields: evaluatorTeamId = teamId (from step 3)

6. create_record(AS_GSS_EVALUATION_VENDOR) × N vendors → vendorId[]
   Fields: evaluationId (from step 1), legalName, businessName, uniqueEntityId,
           cageCode, status="Active", totalPrice, isActive=true, createdBy, modifiedBy

7. create_record(AS_GSS_VENDOR_PRICE_BREAKUP) × items per vendor
   Fields: evalVendorId (from step 6), itemDescription, unitPrice, quantity, amount,
           sortOrder, isActive=true, createdBy, modifiedBy

8. create_record(AS_GSS_EVALUATION_PHASE) — at least one phase
   Fields: evaluationId (from step 1), taskCategoryId (query AS_GSS_TMG_R_TASK_CATEGORY),
           duration, startDate, createdBy, modifiedBy, isActive=true

9. create_record(AS_GSS_TMG_TASK) × tasks per vendor per factor
   Fields: evaluationId (from step 1), criteriaId (from step 2), vendorId (from step 6),
           taskCategoryId, taskBehaviorTypeId, assignedGroup, assignee,
           status fields, isActive=true, createdBy, modifiedBy

10. update_record(AS_GSS_EVALUATION) — set status to "In Progress"
    Fields: evaluationStatusId=2

11. update_record(AS_GSS_CRITERIA) — mark factor as complete
    Fields: criteriaStatusId=2, completedBy, completedOn

12. update_record(AS_GSS_TMG_TASK) — mark tasks as complete (if needed)
    Fields: task status fields
```

### Key Principle

**NEVER assume a record "requires process model execution" without attempting `create_record` first.** Process models write to the same database tables. The Data Generator writes to those same tables. If a related action is not visible after setup, query an existing record in the desired state to discover what additional child records are needed, then create those via the Data Generator.
