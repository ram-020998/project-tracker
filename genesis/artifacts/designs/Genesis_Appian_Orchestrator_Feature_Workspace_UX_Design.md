# Genesis Appian Orchestrator — Feature Workspace UX & Implementation Specification

**Version:** 1.0  
**Purpose:** Define the information architecture, wireframes, states, interactions, and implementation requirements for managing an Appian feature from specification through story verification.

---

## 1. Executive Summary

Genesis should treat a **Feature as a workspace**, rather than a sequence of stage cards.

The feature lifecycle has two fundamentally different parts:

1. **Feature-level discovery/design lifecycle**
   - Spec
   - UX Design
   - Feature Technical Design
   - Feature Breakdown

2. **Story-level execution lifecycle**
   - Design
   - Implementation
   - Code Review
   - Deploy
   - Verify
   - Done

The primary UX principle is:

> Keep the feature lifecycle visible as a simple progress rail, but move parallel work into a Story Execution Workspace.

This avoids a single linear page becoming unmanageable as the number of stories increases.

---

## 2. UX Goals

- A user should understand the current feature state within seconds.
- Users should always know what requires their attention.
- Previous completed stages remain inspectable; future stages are gated rather than hidden.
- The UI should work equally well for 5 or 50 stories.
- POs should focus on business artifacts and AI collaboration, not technical workflow mechanics.
- UX users should focus on prototypes and design verification.
- Architects/developers should focus on technical design and story execution.
- Reviewers/testers should see only the work relevant to their current action.
- Every important decision, artifact, status change, and review should be traceable through Activity.
- Artifacts must have visible versions and provenance.
- The UI should support AI assistance without making the AI conversation the only way to operate the system.

---

## 3. Core Information Architecture

```text
APPLICATION
│
├── Overview
├── Business Map
├── Business Artifacts
└── Features
      │
      └── FEATURE
            │
            ├── Overview       ← Feature command center
            ├── Stories        ← Parallel story execution
            ├── Artifacts      ← All feature artifacts
            └── Activity       ← Audit/history
                  │
                  └── STORY
                        ├── Overview
                        ├── Design
                        ├── Implementation
                        ├── Code Review
                        ├── Deployment
                        ├── Verification
                        └── Activity
```

---

## 4. Feature Lifecycle Model

The top lifecycle rail is the persistent visual representation of feature progress.

```text
SPEC ✓ ── UX DESIGN ✓ ── TECHNICAL DESIGN ● ── BREAKDOWN ○ ── STORY EXECUTION ○
```

| Stage | Type | Primary User | Output | Completion Condition |
|---|---|---|---|---|
| Spec | Feature-level | PO / BA | Approved specification | Spec reviewed and marked complete |
| UX Design | Feature-level | UX designer | Prototype(s) + design verification | Prototype verified and UX stage completed |
| Technical Design | Feature-level | Architect / senior developer | Technical design document + decisions | Technical design approved |
| Feature Breakdown | Feature-level | Lead / team | Stories + tasks + acceptance criteria | Breakdown validated |
| Story Execution | Parallel | Developers / reviewers / testers | Completed stories | All stories verified or explicitly closed |

---

## 5. Navigation Principles

- Feature navigation should use:
  - **Overview**
  - **Stories**
  - **Artifacts**
  - **Activity**
- The lifecycle rail communicates where the feature is in its lifecycle; it should not become the primary tab navigation.
- Completed lifecycle stages are clickable for inspection.
- The current lifecycle stage is actionable.
- Future stages are visible but disabled with a reason.
- Stories are always accessible after Feature Breakdown is available.
- A global **My Work** view should allow users to jump directly to work assigned to them.
- Back navigation should preserve the user's previous filter, tab, and scroll context where practical.

---

# 6. Screen 1 — Feature Overview / Command Center

This is the default screen when a user enters an existing feature.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ← Features                                                                 │
│                                                                            │
│ Vendor Price Reconciliation                                  ● In Progress │
│ GSS • Feature GSS-142                                                      │
│                                                                            │
│ SPEC ✓ ─ UX ✓ ─ TECH DESIGN ● ─ BREAKDOWN ○ ─ STORY EXECUTION ○            │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│ OVERVIEW        STORIES (12)        ARTIFACTS (18)        ACTIVITY         │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────────────┐  ┌────────────────────────────────────────┐  │
│  │ FEATURE HEALTH           │  │ NEEDS ATTENTION                        │  │
│  │                          │  │                                        │  │
│  │ 42% Complete             │  │ ⚠ Technical Design needs review        │  │
│  │                          │  │ ⚠ Story GSS-142-03 blocked             │  │
│  │ 5  Done                  │  │ ⚠ 2 stories awaiting code review       │  │
│  │ 3  In Progress           │  │                                        │  │
│  │ 2  Blocked               │  │ [View all]                             │  │
│  └──────────────────────────┘  └────────────────────────────────────────┘  │
│                                                                            │
│  ┌──────────────────────────┐  ┌────────────────────────────────────────┐  │
│  │ TEAM                     │  │ FEATURE DETAILS                        │  │
│  │                          │  │                                        │  │
│  │ 4 Developers             │  │ Owner: ...                             │  │
│  │ 1 UX                     │  │ Started: ...                           │  │
│  │ 1 Reviewer               │  │ Target: ...                            │  │
│  └──────────────────────────┘  └────────────────────────────────────────┘  │
│                                                                            │
│  STORIES                                                                   │
│  ┌────────┬──────────────────────┬─────────┬────────────────────────────┐  │
│  │ ID     │ Story                │ Owner   │ Progress                   │  │
│  ├────────┼──────────────────────┼─────────┼────────────────────────────┤  │
│  │ 142-01 │ Vendor card          │ Ram     │ ✓ Done                     │  │
│  │ 142-02 │ Reconciliation       │ Arun    │ ● Code Review              │  │
│  │ 142-03 │ Validation           │ Priya   │ ● Implementation           │  │
│  │ 142-04 │ Error handling       │ Dheeraj │ ⚠ Blocked                  │  │
│  └────────┴──────────────────────┴─────────┴────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

### 6.1 Feature Overview Components

| Component | Behavior |
|---|---|
| Feature header | Feature name, application, feature identifier, overall status |
| Lifecycle rail | Shows all feature-level stages and current stage |
| Feature Health | Aggregates story counts and overall completion |
| Needs Attention | Shows actionable items for current user first, then feature-wide issues |
| Team | Shows contributors by role; clicking a person filters relevant work |
| Story preview | Shows highest-priority stories; "View all" opens Stories tab |
| Feature Details | Owner, dates, target date, status, description and other metadata |

---

# 7. Lifecycle Rail States

| State | Visual Treatment | Interaction |
|---|---|---|
| Completed | Check mark + completed styling | Clickable; opens stage in read-only/review mode |
| Current | Strong emphasis + active indicator | Clickable; opens active stage workspace |
| Available | Neutral enabled styling | Only available if prerequisites are satisfied |
| Locked | Muted + lock icon | Disabled; tooltip explains prerequisite |
| Blocked | Warning indicator | Clickable; opens blocking issue details |
| Failed | Error indicator | Clickable; opens failure and retry information |

---

# 8. Screen 2 — Spec Workspace

The Spec workspace is an AI-assisted document creation environment.

The PO should be able to converse with the agent while continuously seeing the evolving specification.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ← Feature / Vendor Price Reconciliation                                    │
│ SPECIFICATION                                                   Draft v0.8 │
├───────────────────────────────┬────────────────────────────────────────────┤
│ AGENT CONVERSATION            │ SPECIFICATION                              │
│                               │                                            │
│ PO: We need to support...     │ 1. Overview                                │
│ Agent: Based on the KB and... │ 2. Business Context                        │
│ PO: Add support for...        │ 3. Scope                                   │
│                               │ 4. Business Rules                          │
│ [ Ask agent... ]              │ 5. Functional Requirements                 │
│                               │ 6. Acceptance Criteria                     │
│                               │                                            │
│                               │ Requirement REQ-001                        │
│                               │ ...                                        │
│                               │                                            │
│                               │ [Open artifact] [Version history]          │
├───────────────────────────────┴────────────────────────────────────────────┤
│ Sources: Appian KB • 12 reference documents       [Complete Spec]          │
└────────────────────────────────────────────────────────────────────────────┘
```

### 8.1 Spec Requirements

- Chat panel and specification artifact remain visible together on desktop.
- The agent can cite Appian KB objects and reference documents.
- Specification has explicit versioning.
- User can inspect sources supporting a requirement.
- **Complete Spec** requires confirmation.
- Outstanding unresolved questions are displayed separately from normal chat.
- The generated artifact is stored as a feature artifact.
- The approved specification becomes an input to later stages.

---

# 9. Screen 3 — UX Design Workspace

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ UX DESIGN                                                                  │
│ Spec ✓                                                      Prototype: v0.4│
├───────────────────────────────┬────────────────────────────────────────────┤
│ SPEC / REQUIREMENTS           │ PROTOTYPE / DESIGN                         │
│                               │                                            │
│ ✓ REQ-001                     │  ┌──────────────────────────────────────┐  │
│ ✓ REQ-002                     │  │                                      │  │
│ ⚠ REQ-003                     │  │          Prototype / Mockup          │  │
│ ? REQ-004                     │  │                                      │  │
│                               │  │                                      │  │
│ [Filter] [View requirement]   │  └──────────────────────────────────────┘  │
├───────────────────────────────┴────────────────────────────────────────────┤
│ AI DESIGN VERIFICATION                                                     │
│                                                                            │
│ ✓ REQ-001 represented                                                      │
│ ⚠ REQ-002 missing empty/error state                                        │
│ ⚠ REQ-005 not represented                                                  │
│ ? REQ-007 requires clarification                                           │
│                                                                            │
│ [Verify Design]                                              [Complete UX] │
└────────────────────────────────────────────────────────────────────────────┘
```

## 9.1 Verify Design Behavior

Verify Design should run an agent workflow comparing the current prototype/design artifacts against:

- Approved specification
- Relevant Appian knowledge
- Feature context

| Finding | Meaning | Required Action |
|---|---|---|
| Missing | Requirement is not represented | Resolve or explicitly justify |
| Incomplete | Requirement lacks a required state/interaction | Update prototype |
| Question | Agent cannot determine compliance | Clarify or resolve |
| Conflict | Prototype contradicts specification | Resolve design/spec conflict |
| Verified | Requirement appears adequately represented | No action |

The UX stage should not be completed while unresolved **critical** findings remain unless the user explicitly overrides them with a recorded rationale.

---

# 10. Screen 4 — Feature Technical Design Workspace

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ FEATURE TECHNICAL DESIGN                                  Draft v0.6       │
├────────────────────────────────────────────────────────────────────────────┤
│ CONTEXT                                                                    │
│ Spec ✓       UX ✓       Appian KB ✓                                        │
│                                                                            │
│ ┌────────────────────────────────────────────────────────────────────────┐ │
│ │ TECHNICAL DESIGN                                                       │ │
│ │                                                                        │ │
│ │ 1. Architecture                                                        │ │
│ │ 2. Data Model                                                          │ │
│ │ 3. Records                                                             │ │
│ │ 4. Interfaces                                                          │ │
│ │ 5. Process Models                                                      │ │
│ │ 6. Expression Rules                                                    │ │
│ │ 7. Security                                                            │ │
│ │ 8. Performance                                                         │ │
│ │ 9. Open Questions                                                      │ │
│ └────────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│ AI ANALYSIS                                                                │
│ 3 decisions • 2 open questions • 1 risk                                    │
│                                                                            │
│ [Ask Agent] [Generate Draft] [Upload] [Version History] [Complete Design]  │
└────────────────────────────────────────────────────────────────────────────┘
```

### 10.1 Technical Design Features

- Upload supporting technical documents.
- Generate draft technical design documents with AI.
- Revise/refine generated drafts.
- Show Appian KB objects referenced by the design.
- Track architectural decisions separately from prose.
- Track open questions and risks.
- Attach spikes/investigations to the feature.
- Record the final approved version when the stage completes.

---

# 11. Screen 5 — Feature Breakdown Workspace

This stage converts feature-level artifacts into independently executable stories.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ FEATURE BREAKDOWN                                                          │
│ Source: Spec ✓  UX ✓  Technical Design ✓                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ AI BREAKDOWN                                                               │
│ [Generate Story Breakdown]                                                 │
│                                                                            │
│ Stories: 12       Tasks: 47       Dependencies: 3                          │
│                                                                            │
│ ┌────────┬──────────────────────────────┬────────────┬──────────────┐      │
│ │ ID     │ Story                        │ Owner      │ Status       │      │
│ ├────────┼──────────────────────────────┼────────────┼──────────────┤      │
│ │ 142-01 │ Vendor card changes          │ Ram        │ Ready        │      │
│ │ 142-02 │ Reconciliation form          │ Dheeraj    │ Ready        │      │
│ │ 142-03 │ Price validation             │ Unassigned │ Draft        │      │
│ └────────┴──────────────────────────────┴────────────┴──────────────┘      │
│                                                                            │
│ [Validate Breakdown]                                   [Complete Breakdown]│
└────────────────────────────────────────────────────────────────────────────┘
```

## 11.1 Breakdown Validation

- Every story must map to one or more requirements.
- Acceptance criteria must exist for every story.
- Technical design references should be linked where applicable.
- Dependencies must be explicit.
- Stories should be independently executable where possible.
- Duplicate or overlapping stories should be flagged.
- Uncovered requirements should be flagged.
- Validation should produce actionable findings rather than a single pass/fail.

---

# 12. Story Execution Workspace

Once Feature Breakdown is completed, Story Execution becomes the main feature activity.

Multiple stories may be in different lifecycle stages simultaneously.

```text
STORY
GSS-142-03 • Price Validation

Owner: Arun                         Reviewer: Dheeraj
Status: ● In Progress

DESIGN ✓ → IMPLEMENTATION ● → CODE REVIEW ○ → DEPLOY ○ → VERIFY ○ → DONE ○

────────────────────────────────────────────────────────────────────────────
OVERVIEW | DESIGN | IMPLEMENTATION | REVIEW | DEPLOYMENT | VERIFICATION | ACTIVITY
```

---

# 13. Screen 6 — Stories List

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ STORIES                                               12 stories           │
├────────────────────────────────────────────────────────────────────────────┤
│ [All] [My Stories] [Blocked] [In Progress] [Review] [Done]                 │
│ Search stories...     Owner ▼     Status ▼     Priority ▼                  │
│                                                                            │
│ ┌────────┬────────────────────────┬──────────┬───────────────────────────┐ │
│ │ ID     │ Story                  │ Owner    │ Lifecycle                 │ │
│ ├────────┼────────────────────────┼──────────┼───────────────────────────┤ │
│ │ 142-01 │ Vendor card            │ Ram      │ ✓ Done                    │ │
│ │ 142-02 │ Reconciliation form    │ Dheeraj  │ ● Code Review             │ │
│ │ 142-03 │ Price validation       │ Arun     │ ● Implementation          │ │
│ │ 142-04 │ Error handling         │ Priya    │ ⚠ Blocked                 │ │
│ │ 142-05 │ Audit history          │ Ram      │ ● Deployment              │ │
│ └────────┴────────────────────────┴──────────┴───────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘
```

## 13.1 Story List Requirements

- Default sort prioritizes items requiring the current user's action.
- Support filtering by:
  - Owner
  - Status
  - Lifecycle stage
  - Priority
  - Blocked state
  - Due date
- Search supports story ID, title, and relevant metadata.
- Lifecycle column communicates exact current stage.
- Blocked stories expose a concise blocking reason.
- Selecting a story opens the Story Workspace.

---

# 14. Screen 7 — Story Overview

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ← Feature / Vendor Price Reconciliation                                    │
│                                                                            │
│ GSS-142-03                                                                 │
│ Price validation                                                           │
│ Owner: Arun          Reviewer: Dheeraj             ● In Progress           │
├────────────────────────────────────────────────────────────────────────────┤
│ DESIGN ✓ → IMPLEMENT ● → REVIEW ○ → DEPLOY ○ → VERIFY ○ → DONE ○           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ OVERVIEW                                                                   │
│                                                                            │
│ Requirements                                                               │
│ ✓ REQ-023   ✓ REQ-024   ✓ REQ-025                                          │
│                                                                            │
│ Acceptance Criteria                                                        │
│ 3 / 5 completed                                                            │
│                                                                            │
│ Dependencies                                                               │
│ ✓ Pricing record design                                                    │
│ ⚠ Price extraction integration                                             │
│                                                                            │
│ Recent Activity                                                            │
│ • Arun updated implementation 5m ago                                       │
│ • Design approved 2h ago                                                   │
└────────────────────────────────────────────────────────────────────────────┘
```

---

# 15. Screen 8 — Story Design

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ STORY DESIGN                                                               │
│ GSS-142-03 • Price validation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│ REQUIREMENTS                                                               │
│ REQ-023  REQ-024  REQ-025                                                  │
│                                                                            │
│ TECHNICAL DESIGN                                                           │
│ ✓ Record design                                                            │
│ ✓ Expression rules                                                         │
│ ✓ Interface design                                                         │
│ ⚠ Integration approach                                                     │
│                                                                            │
│ APPIAN OBJECTS                                                             │
│ AS_GSS_R_Pricing                                                           │
│ AS_GSS_UI_Reconciliation                                                   │
│ AS_GSS_INT_PriceExtraction                                                 │
│                                                                            │
│ OPEN QUESTIONS                                                             │
│ 1. Should validation run synchronously?                                    │
│                                                                            │
│ [Ask Agent] [Generate Design Draft] [Upload] [Finalize Design]             │
└────────────────────────────────────────────────────────────────────────────┘
```

Finalizing design should create an immutable approved design version and transition the story to Implementation.

---

# 16. Screen 9 — Story Implementation

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ IMPLEMENTATION                                                             │
│ GSS-142-03 • Price validation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│ Design: ✓ Approved                                                         │
│                                                                            │
│ IMPLEMENTATION PROGRESS                                                    │
│ ✓ Record Type                                                              │
│ ✓ Expression Rules                                                         │
│ ● Interface                                                                │
│ ○ Integration                                                              │
│ ○ Tests                                                                    │
│                                                                            │
│ APPIAN OBJECTS CHANGED                                                     │
│ AS_GSS_R_Pricing                                                           │
│ AS_GSS_UI_Reconciliation                                                   │
│                                                                            │
│ DEVELOPMENT                                                                │
│ Branch: feature/GSS-142-03                                                 │
│ Last change: 8f72a1 — Implement reconciliation validation                  │
│                                                                            │
│ [Run Tests] [View Changes] [Ask Agent] [Mark Implementation Complete]      │
└────────────────────────────────────────────────────────────────────────────┘
```

---

# 17. Screen 10 — Code Review

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ CODE REVIEW                                                                │
│ GSS-142-03 • Price validation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│ IMPLEMENTATION                                                             │
│ Completed by Arun                                                          │
│                                                                            │
│ AI REVIEW                                                                  │
│ ✓ Accessibility                                                            │
│ ✓ Naming conventions                                                       │
│ ⚠ Expression complexity                                                    │
│ ⚠ Missing error handling                                                   │
│                                                                            │
│ 2 findings require attention                                               │
│                                                                            │
│ HUMAN REVIEW                                                               │
│ Reviewer: Dheeraj                                                          │
│                                                                            │
│ [Approve]                         [Request Changes]                        │
└────────────────────────────────────────────────────────────────────────────┘
```

Request Changes should transition the story back to the appropriate implementation/design state and record the reason.

Approval moves the story to Deployment.

---

# 18. Screen 11 — Deployment

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ DEPLOYMENT                                                                 │
│ GSS-142-03 • Price validation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│ ENVIRONMENT                                                                │
│ DEV ✓       TEST ●       PROD ○                                            │
│                                                                            │
│ DEPLOYMENT #128                                                          │
│ ✓ Package generated                                                        │
│ ✓ Validation passed                                                        │
│ ● Deployment in progress                                                   │
│                                                                            │
│ [View Deployment] [Refresh]                                                │
└────────────────────────────────────────────────────────────────────────────┘
```

Deployment status should be system-driven wherever possible. Manual completion should not be the primary mechanism if deployment tooling can provide authoritative status.

---

# 19. Screen 12 — Verification

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ VERIFICATION                                                               │
│ GSS-142-03 • Price validation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│ ACCEPTANCE CRITERIA                                                        │
│ ✓ Valid price accepted                                                     │
│ ✓ Invalid price rejected                                                   │
│ ⚠ Boundary value scenario                                                  │
│ ○ Audit event generated                                                    │
│                                                                            │
│ TEST RESULTS                                                               │
│ 8 / 10 passed                                                              │
│                                                                            │
│ ISSUES                                                                     │
│ 1 open clarification                                                       │
│                                                                            │
│ [View Test Results]                                                        │
│                                                                            │
│ [Pass Verification]                                [Report Issue]          │
└────────────────────────────────────────────────────────────────────────────┘
```

Report Issue should:

1. Create a linked issue/defect.
2. Return the story to the required implementation/review stage.
3. Preserve the verification attempt and result.

---

# 20. Story Completion

A story is complete only when verification passes or an authorized user explicitly closes it with a recorded reason.

```text
VERIFY
   │
   ├── Pass ───────────────→ DONE
   │
   └── Issue
         ↓
    IMPLEMENTATION
         ↓
      REVIEW
         ↓
      DEPLOY
         ↓
      VERIFY
```

---

# 21. Screen 13 — Artifacts

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ARTIFACTS                                             18 artifacts         │
├────────────────────────────────────────────────────────────────────────────┤
│ [All] [Spec] [UX] [Technical] [Stories] [Other]                            │
│ Search artifacts...                                                        │
│                                                                            │
│ Name                         Type       Version      Updated               │
│ ───────────────────────────────────────────────────────────────────────────│
│ Feature Specification       DOCX       v0.8         10m ago                │
│ UX Prototype                PDF        v0.4         2h ago                 │
│ Technical Design            DOCX       v0.6         1h ago                 │
│ Story Breakdown             XLSX       v1.0         3h ago                 │
│ Pricing Guidelines          PDF        v3           Yesterday              │
└────────────────────────────────────────────────────────────────────────────┘
```

### Artifact Requirements

- Show type, version, source, stage, owner, last modified time, and status.
- External reference documents should show their source, e.g. Google Drive.
- Genesis-generated artifacts should be clearly identified.
- Artifact detail should expose version history and provenance.
- A feature artifact must never silently change the version used by a completed stage.

---

# 22. Screen 14 — Activity

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ACTIVITY                                                                   │
├────────────────────────────────────────────────────────────────────────────┤
│ Filter: [All] [Stages] [Artifacts] [Comments] [AI] [Status]                │
│                                                                            │
│ TODAY                                                                      │
│ 18:22  Arun completed implementation of GSS-142-03                         │
│ 17:51  AI review identified 2 findings                                     │
│ 16:43  Dheeraj approved story design                                       │
│ 15:12  Technical Design v0.6 uploaded                                      │
│                                                                            │
│ YESTERDAY                                                                  │
│ 14:33  UX verification completed                                           │
│ 11:20  Spec v0.8 approved                                                  │
└────────────────────────────────────────────────────────────────────────────┘
```

Activity is an audit trail, not a chat transcript.

Each event should link to the affected object, stage, or artifact.

---

# 23. Screen 15 — My Work

This should be available globally and solve the multi-user navigation problem.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ MY WORK                                                                    │
│                                                                            │
│ 3 items need your attention                                                │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ GSS • Vendor Price Reconciliation                                          │
│ Story GSS-142-03                                                           │
│ Implementation                                      Due today              │
│ [Continue]                                                                 │
│                                                                            │
│ RM • Vendor Onboarding                                                     │
│ Story RM-221-04                                                            │
│ Code Review                                         2 findings             │
│ [Review]                                                                   │
│                                                                            │
│ GSS • Evaluation Revamp                                                    │
│ Story GSS-144-02                                                           │
│ Verification pending                                                       │
│ [Verify]                                                                   │
└────────────────────────────────────────────────────────────────────────────┘
```

### My Work Requirements

- Prioritize items requiring the current user's action.
- Show due dates and overdue state.
- Show blocked items separately.
- Open the exact actionable screen, not just the feature overview.
- Do not overwhelm users with every feature they have access to.

---

# 24. Needs Attention Model

Needs Attention is a cross-cutting UX pattern appearing on Feature Overview and My Work.

| Priority | Examples | UI |
|---|---|---|
| Critical | Failed deployment, blocking defect | Strong error indicator |
| High | Review requested, verification required | Prominent attention indicator |
| Medium | Open question, non-blocking finding | Warning indicator |
| Low | Informational update | Muted indicator |

Each item should contain:

- Title
- Object
- Reason
- Timestamp
- Owner/actor where useful
- Primary action

---

# 25. Status Model

| Object | Recommended Statuses |
|---|---|
| Feature | Draft, In Progress, Blocked, Completed, Cancelled |
| Feature Stage | Locked, Available, In Progress, Review, Completed, Blocked, Failed |
| Story | Draft, Ready, In Progress, Blocked, In Review, Verification, Completed, Cancelled |
| Artifact | Draft, In Review, Approved, Superseded, Archived |
| Verification | Pending, In Progress, Passed, Failed, Blocked |

---

# 26. Ownership Model

Ownership should be explicit but lightweight.

| Role | Typical Responsibilities |
|---|---|
| PO / BA | Spec creation, business validation, acceptance criteria, feature completion decisions |
| UX | Prototype creation, design verification, UX completion |
| Architect / Technical Lead | Feature technical design, architecture decisions, technical risks |
| Developer | Story design, implementation, unit tests, implementation completion |
| Reviewer | Code review and approval |
| Tester / Business Verifier | Verification and acceptance |
| Feature Lead | Breakdown validation, assignment, dependency management, overall progress |

---

# 27. Artifact and Versioning Rules

- Every generated or uploaded artifact receives a version.
- Stage completion records the exact artifact version used for the completion decision.
- Later artifact updates create a new version; they must not mutate the historical version.
- A completed stage displays a link to the exact approved version.
- Artifacts should expose source:
  - Generated
  - Uploaded
  - External / Google Drive
  - Appian KB-derived
- Reference documents from Google Drive should retain:
  - External file ID
  - Revision/version information
  - Modified time
  - Sync status
- A feature run should be reproducible from its Appian KB snapshot and reference-document versions.

---

# 28. Feature Snapshot / Reproducibility

Every major AI-generated stage should record the knowledge used to produce it.

```text
FEATURE / SPEC RUN #123

Appian KB
  Snapshot: 2026-08-12 10:30
  Release: DEV-26.8

Reference Documents
  Requirements.docx       Revision 14
  Guidelines.pdf          Revision 3
  Pricing.xlsx            Revision 8

Output
  Specification v0.8
```

This prevents a later Google Drive update or KB refresh from silently changing the context of an existing specification.

---

# 29. AI Interaction Principles

- AI actions should be explicit and explainable.
- AI findings should become structured objects where possible, not remain buried in chat.
- Generated documents should always have a visible draft/version state.
- AI should show sources when making factual claims about the feature.
- The user should be able to accept, reject, edit, or ask for clarification on findings.
- AI should not silently mark a human approval gate complete.
- Long-running AI operations should show progress and allow users to leave the page without losing state.
- AI-generated recommendations should be visually distinct from authoritative system state.

---

# 30. Stage Completion Pattern

Use a consistent completion pattern across all feature-level stages.

```text
┌────────────────────────────────────────────────────────────┐
│ Complete Technical Design?                                 │
│                                                            │
│ Final artifact: Technical Design v0.6                      │
│                                                            │
│ ✓ 3 decisions recorded                                     │
│ ✓ 0 critical findings                                      │
│ ⚠ 2 informational questions remain                         │
│                                                            │
│ Completion note (optional):                                │
│ [........................................................] │
│                                                            │
│                         [Cancel] [Complete Stage]          │
└────────────────────────────────────────────────────────────┘
```

The completion dialog should show:

- Whether unresolved items exist.
- Whether they are blocking.
- The artifact version being approved.
- Optional completion notes.
- The resulting lifecycle transition.

Blocking items should require resolution or an authorized override.

---

# 31. Responsive / Layout Guidance

- Desktop is the primary target because the workflow contains dense engineering information.
- Use a maximum content width that keeps tables readable while allowing artifact panels to expand.
- On smaller screens, stack split panes rather than shrinking text below readable size.
- Persistent lifecycle navigation should collapse to a compact progress component on narrow screens.
- Story tables should support horizontal scrolling rather than truncating important fields.
- Chat and artifact panels may become tabs on smaller screens.

---

# 32. Component Inventory

| Component | Purpose |
|---|---|
| `FeatureLifecycleRail` | Feature-level stage progress and navigation |
| `StageStatusBadge` | Consistent stage/status display |
| `NeedsAttentionPanel` | Actionable items requiring attention |
| `FeatureHealthCard` | Feature progress and story counts |
| `StoryTable` | Scalable story listing and filtering |
| `StoryLifecycle` | Story-level progress rail |
| `ArtifactList` | Feature/story artifact management |
| `ArtifactViewer` | Preview/version/provenance |
| `AIConversation` | Agent interaction |
| `AIFindingList` | Structured AI findings |
| `ApprovalGate` | Human approval/completion action |
| `ActivityTimeline` | Audit/history |
| `MyWorkList` | Personal actionable work |
| `DependencyList` | Story/feature dependencies |
| `VerificationChecklist` | Acceptance/test verification |

---

# 33. Interaction Rules

| Interaction | Expected Behavior |
|---|---|
| Click completed stage | Open stage in inspection/review mode |
| Click current stage | Open active workspace |
| Click locked stage | Explain prerequisite |
| Click story | Open Story Workspace |
| Click Needs Attention item | Open exact actionable context |
| Complete stage | Validate prerequisites, confirm, persist event, advance lifecycle |
| Request changes | Move object back to required stage and record reason |
| Report issue during verification | Create linked issue and transition story to required remediation stage |
| Update artifact | Create new version; preserve historical version |
| AI verification | Create structured findings with status and source references |

---

# 34. Empty States

### Stories — Before Breakdown

```text
STORIES — BEFORE BREAKDOWN

No stories have been created yet.

Complete Feature Breakdown to generate and validate
the story set.

[Go to Feature Breakdown]
```

### My Work

```text
MY WORK

You're all caught up.

No assigned items currently require your action.
```

### Artifacts

```text
ARTIFACTS

No artifacts yet.

Artifacts created during Spec, UX Design, Technical Design,
and Breakdown will appear here.
```

---

# 35. Error / Failure States

- **AI workflow failure**
  - Show what failed.
  - Preserve existing artifact/version.
  - Offer retry.

- **Document upload failure**
  - Show filename.
  - Show failure reason.
  - Provide retry.
  - Do not partially mark stage complete.

- **Deployment failure**
  - Show environment.
  - Show deployment identifier.
  - Show failure summary.
  - Provide remediation/retry action.

- **Verification failure**
  - Retain test results.
  - Allow issue creation.

- **External document synchronization failure**
  - Show stale status.
  - Show last successful sync time.
  - Allow retry.

---

# 36. Accessibility and Usability

- Every status indicator must have text in addition to color.
- Keyboard navigation must work across lifecycle, tables, dialogs, and action controls.
- Focus should move predictably after dialogs and stage transitions.
- Tables need accessible column headers and row actions.
- Do not use color alone to communicate Done, Blocked, Review, or Failed.
- Long AI output should be collapsible.
- Loading and AI-running states need textual status and not only a spinner.

---

# 37. Suggested Data Model

```text
Application
  └── Feature
        ├── lifecycle_stage
        ├── status
        ├── owner
        ├── dates
        ├── artifacts[]
        ├── decisions[]
        ├── findings[]
        ├── dependencies[]
        ├── stories[]
        └── activity[]

Story
  ├── status
  ├── lifecycle_stage
  ├── owner
  ├── reviewer
  ├── requirements[]
  ├── acceptance_criteria[]
  ├── appian_objects[]
  ├── artifacts[]
  ├── dependencies[]
  ├── defects[]
  └── activity[]
```

---

# 38. Recommended Feature Page Flow

```text
CREATE FEATURE
      │
      ▼
FEATURE OVERVIEW
      │
      ▼
SPEC WORKSPACE
  Chat + KB + Documents
      │
      ▼
SPEC COMPLETE
      │
      ▼
UX DESIGN WORKSPACE
  Prototype + AI Verification
      │
      ▼
UX COMPLETE
      │
      ▼
TECHNICAL DESIGN WORKSPACE
  Architecture + Spikes + Documents
      │
      ▼
TECHNICAL DESIGN COMPLETE
      │
      ▼
FEATURE BREAKDOWN
  Stories + Tasks + Dependencies
      │
      ▼
BREAKDOWN VALIDATED
      │
      ├───────────────┬────────────────┬─────────────────┐
      ▼               ▼                ▼                 ▼
   STORY 01         STORY 02        STORY 03          STORY N
      │               │                │
      ▼               ▼                ▼
   DESIGN          DESIGN          IMPLEMENTATION
      │               │                │
   IMPLEMENT       IMPLEMENT        REVIEW
      │               │                │
    REVIEW         DEPLOY           DEPLOY
      │               │                │
   DEPLOY          VERIFY           VERIFY
      │               │
   VERIFY           DONE
      │
     DONE
```

---

# 39. Implementation Priorities

| Priority | Scope |
|---|---|
| P0 | Feature Overview, lifecycle rail, Stories list, Story Workspace, status model, stage transitions |
| P0 | Spec workspace with artifact + agent conversation |
| P0 | Feature Breakdown and story creation/validation |
| P1 | UX Design workspace + Verify Design findings |
| P1 | Technical Design workspace + artifact/version management |
| P1 | My Work + Needs Attention |
| P1 | Activity timeline |
| P2 | Advanced artifact provenance/version snapshots |
| P2 | Rich annotation / artifact feedback |
| P2 | Advanced AI recommendations and automated validation |

---

# 40. MVP Acceptance Criteria

- A user can create a feature under an Application.
- The feature shows a clear lifecycle rail.
- The user can enter Spec, UX, Technical Design, and Breakdown workspaces.
- Completed stages remain inspectable.
- Future stages are visibly locked with prerequisite information.
- Feature Breakdown produces a story list.
- Multiple stories can be in different lifecycle stages simultaneously.
- Each story has its own lifecycle and workspace.
- Users can filter Stories and My Work.
- The system shows items requiring user attention.
- Every stage transition is recorded in Activity.
- Every stage completion records the relevant artifact version.
- A verification failure can return a story to remediation without losing history.
- The Feature Overview accurately aggregates story progress.

---

# 41. Design Principles for the Implementing Agent

1. **Do not implement the feature as a long sequence of stage cards.**
2. Treat feature-level and story-level workflows as separate state machines connected by the Feature Breakdown transition.
3. Prefer progressive disclosure over showing every technical detail at once.
4. Keep lifecycle state persistent and visible.
5. Make the current user's next action obvious.
6. Never hide completed work merely because the lifecycle has advanced.
7. Do not allow future work to appear actionable before prerequisites are met.
8. Preserve version history for artifacts and stage approvals.
9. Make parallel story execution the primary model after breakdown.
10. Avoid creating a separate dashboard for every role; reuse the same objects and filter information to the user's context.
11. Keep AI outputs structured where they affect workflow state.
12. Do not use AI output as authoritative system state without human/system validation.
13. Design all long-running operations for resumability and failure recovery.

---

# 42. Final UX Concept

Genesis Feature should feel like a **project workspace with an AI-native development assistant**, not like a wizard.

```text
APPLICATION
    ↓
FEATURE COMMAND CENTER
    │
    ├── Lifecycle Rail
    │      Spec → UX → Tech → Breakdown → Execution
    │
    ├── Feature Artifacts
    │
    ├── Needs Attention
    │
    └── Stories
           │
           ├── Story A
           │      Design → Implement → Review → Deploy → Verify → Done
           │
           ├── Story B
           │      Design → Implement → Review → Deploy → Verify → Done
           │
           └── Story C
                  Design → Implement → Review → Deploy → Verify → Done

GLOBAL
    │
    └── My Work
          └── "What do I need to do now?"
```

The central UX idea is:

> **The Feature page answers “Where is the feature?” while the Story workspace answers “What am I doing right now?”**

This keeps the experience simple for individual users while preserving complete traceability for leads and the team.

---

# Appendix A — Suggested Route Structure

```text
/applications
/applications/:applicationId
/applications/:applicationId/features
/applications/:applicationId/features/:featureId
/applications/:applicationId/features/:featureId/stories
/applications/:applicationId/features/:featureId/stories/:storyId
/my-work
```

---

# Appendix B — Suggested Feature API Concepts

```text
GET    /features/:id
POST   /features
PATCH  /features/:id

GET    /features/:id/stages
POST   /features/:id/stages/:stage/complete

GET    /features/:id/stories
POST   /features/:id/stories
PATCH  /stories/:id

GET    /stories/:id
POST   /stories/:id/stages/:stage/complete
POST   /stories/:id/request-changes
POST   /stories/:id/report-issue

GET    /features/:id/artifacts
POST   /features/:id/artifacts
GET    /artifacts/:id/versions

GET    /features/:id/activity
GET    /my-work
GET    /needs-attention
```

---

# Appendix C — Terminology

| Term | Definition |
|---|---|
| Feature | A business/functional capability being developed within an Appian application |
| Feature Stage | A gated feature-level phase before parallel story execution |
| Story | An independently executable unit created during Feature Breakdown |
| Story Stage | The current execution phase of an individual story |
| Artifact | A document, prototype, design, specification, or other persistent output |
| Finding | A structured issue/question/recommendation produced by AI or validation |
| Approval Gate | A human/system-controlled transition that marks a stage as complete |
| Snapshot | The exact KB/document versions used for a generation or approval event |
