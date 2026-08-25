# 28-02 — Wireframes (lo-fi)

> **Status:** 📋 structure/hierarchy only (no final color/type — that's the coded hi-fi mockups at `/dev/feature-workspace`). **Date:** 2026-08-25. **Phase:** 28. Renders the 28-01 recommended model. **Gate:** ⭐ user review of the coded mockups before 28-03.

The coded hi-fi version lives at **`/dev/feature-workspace`** (dev-only) with a **Layout** toggle
(Overview+cards = recommended · Stages-as-tabs = alternative) and a **light/dark** toggle.

---

## A. Recommended — Command-center Overview + peer stage cards

```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│ ← Back to application                                                               │
│ Vendor Price Reconciliation                                          ● In Progress  │  ← derived status (roll-up)
│ GSS · Feature GSS-142                                                               │
│ ▓▓▓▓▓░░░░░  Spec in review · 3 stages arriving in later phases   (non-gating meter) │  ← progress INDICATOR, not a rail
├───────────────────────────────────────────────────────────────────────────────────┤
│ [ Overview ]  Artifacts (4)  Activity  · Stories (reserved)                         │  ← workspace tabs
├───────────────────────────────────────────────────────────────────────────────────┤
│ ┌── FEATURE HEALTH ─────────────┐  ┌── NEEDS ATTENTION (system) ─────────────────┐  │
│ │ In Progress                   │  │ ⚠ Spec is awaiting your review              │  │
│ │ 1 stage active · 3 later      │  │ ? 2 open questions in the spec              │  │
│ └───────────────────────────────┘  └─────────────────────────────────────────────┘  │
│                                                                                     │
│ STAGES  (independent — any order; no stage gates another)                           │
│ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐            │
│ │ ① Spec        │ │ ② UX Design   │ │ ③ Tech Design │ │ ④ Breakdown   │            │
│ │ ● In review   │ │ ◷ Later phase │ │ ◷ Later phase │ │ ◷ Later phase │            │
│ │ spec.html v0.8│ │ arriving soon │ │ arriving soon │ │ arriving soon │            │
│ │ [Open] [View] │ │ (first-class, │ │  not gated by │ │  not gated by │            │
│ │               │ │  not locked)  │ │  Spec)        │ │  Spec)        │            │
│ └───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘            │
│                                                                                     │
│ ┌── ARTIFACTS (glance) ─────────┐  ┌── ACTIVITY (glance) ────────────────────────┐  │
│ │ Feature Specification v0.8    │  │ • Spec submitted for review   10m ago       │  │
│ │ Pricing Guidelines.pdf  GDrive│  │ • Milestone saved (rev 3)     25m ago       │  │
│ │ Reconciliation rules  KB      │  │ • Spec created                1h ago        │  │
│ └───────────────────────────────┘  └─────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Stage container (canonical — the plug-in unit; Spec shown; click a stage card → this view)

```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│ ← Overview      SPEC                                   ● In review                  │
│                                        [ Request changes ]   [ Approve ]            │  ← allowed actions (LifecycleService)
├──────────────────────────────────┬──────────────────────────────────────────────────┤
│ AGENT CONVERSATION               │ LIVE ARTIFACT  (canvas)                          │
│                                  │ ┌──────────────────────────────────────────────┐ │
│ PO: support multi-currency…      │ │ 1. Overview   2. Business rules   3. Scope    │ │
│ Agent: based on the KB…          │ │ REQ-001 …                                     │ │
│ [ Ask agent…              ] [→]  │ │ (rendered spec)                               │ │
│                                  │ └──────────────────────────────────────────────┘ │
├──────────────────────────────────┴──────────────────────────────────────────────────┤
│ Artifact: spec.html · v0.8 · Generated · updated 10m ago  [Version history] [Preview]│  ← version + provenance
└───────────────────────────────────────────────────────────────────────────────────┘
```

- **Anatomy every future stage inherits:** header (name · status badge · allowed-action buttons) ·
  body (stage-specific plug-in — Spec = chat + live artifact) · artifact strip (version + provenance +
  history) · completion (an allowed action → completion dialog → `LifecycleService` transition + audit).
- **"Later phase" stages** render this same frame with an "arriving in a later phase" body — first-class,
  **not** a lock-behind-predecessor.

### Artifacts tab
```text
Name                       Type   Version  Source        Updated
Feature Specification      Spec   v0.8     Generated     10m ago
Pricing Guidelines.pdf     Ref    rev 3    Google Drive  yesterday
Reconciliation rules       Ref    —        Appian KB     —
```
Columns: name · type · version · **source (Generated / Uploaded / Google Drive / Appian KB-derived)** ·
updated. Row → version history + provenance.

### Activity tab (audit, not chat)
```text
TODAY
10:22  Spec submitted for review   draft → in-review   · you   → [Spec]
09:57  Milestone saved (rev 3)                          · you   → [Spec]
09:12  Spec created                                     · you   → [Spec]
09:10  Feature created                                  · you   → [Feature]
```
Actor · time · what-changed (from→to) · **link to the object**.

### Stories tab (reserved)
```text
STORIES
Stories arrive after Feature Breakdown — planned for a later phase.
(The slot is reserved so the IA doesn't move when Stories ship.)
```

---

## B. Alternative — Stages as top-level tabs (for contrast)

```text
[ Overview ]  Spec  UX Design  Technical Design  Breakdown  Artifacts  Activity
────────────────────────────────────────────────────────────────────────────────
(selecting a stage tab shows that stage container directly)
```
**Tradeoff (why A wins):** tabs hide the peers and give no at-a-glance parallel view of *all* stage
statuses; with a reserved Stories area + 4 stages + Artifacts + Activity the tab strip gets crowded, and
tabs read as "pick one" rather than "these run in parallel". A's Overview shows every stage's status at
once and drills in on demand (progressive disclosure). Included in the coded mockup so the choice is made
on real pixels.
```
```
