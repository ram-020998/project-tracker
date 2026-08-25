# 28-01 — Findings: Research & UX Analysis

> **Status:** ✅ **DELIVERED — FOR REVIEW (2026-08-25).** · **Type:** research / docs-only (no genesis code). · **Phase:** 28 (Feature Revamp). · **Gate:** ⭐ user review of these findings + the recommended model before 28-02 (mockups).
> **Method:** external product-pattern research (cited below) + a first-hand read of the current feature surfaces (`web/features/features/*`, `api/features.py`, `kb/features.py`, `genesis/domain/*`) + reconciliation against the umbrella §3 constraints and the user's draft design doc.

---

## 1. What we're deciding

How to present an Appian **Feature** as a durable, **parallel** workspace (Spec, UX Design, Technical
Design, Feature Breakdown running in any order) that future capabilities plug into — single-user,
read-only-now, Stories reserved for later. This doc gives the **recommended IA + interaction model** for the
28-02 mockups, an **adopt/adapt/defer/drop** verdict on the draft, a **current-code audit**, and the
**ADR-056** draft.

---

## 2. External product-pattern research (cited)

### 2.1 Parallel status, not a wizard — the "epic/project = container of independently-statused work"
- **Jira** is explicit: *"An epic can have multiple issues with different statuses. However, its own Epic
  Status provides a high-level view of the progress of those issues collectively."*
  (community.atlassian.com/forums/Jira-questions/…/qaq-p/3174091). → A parent shows a **rolled-up** status
  while children each carry their own — precedent for a **derived feature status** over parallel stages.
- **Linear** models a project as a container with **team-specific workflows** (`Backlog > Todo > In Progress
  > Done > Canceled`) and multiple **views/display options** (board vs list, group/order by status/health/
  target) rather than a forced linear path (linear.app/docs/configuring-workflows; linear.app/docs/display-
  options). → Parallel work + switchable views; the container doesn't impose one sequence.
- **Azure Boards** tracks epics/features on a **board** where items "progress left to right" but each item's
  state is its own (learn.microsoft.com/azure/devops/boards/…/kanban-epics-features-stories). → A progress
  *visualization* is fine; it must not gate.

**Takeaway:** mature trackers treat the parent as a **container with a derived progress view**, children
advance **independently/in parallel**. This directly validates the umbrella's core reframe and argues for a
**derived** (roll-up) feature status with parallel per-stage state.

### 2.2 Stepper vs tabs vs cards — what communicates "parallel, any-order, inspectable"
- **NN/g, *Tabs, Used Right*** — tabs "organize and conceal content until requested"; use them for
  **peer sections** (nngroup.com/articles/tabs-used-right).
- **onething.design, *Tabs vs Accordions*** — *"Choose tabs when each section deserves equal attention, and
  users may want to explore or compare them… Use accordions when content is sequential"*
  (onething.design/post/tabs-vs-accordions).
- **PatternFly, *Progress stepper*** — a stepper "encodes workflow rules"; steps are **ordered/bounded**
  units (patternfly.org/components/progress-stepper/design-guidelines). → A stepper/wizard **implies
  sequence** — the exact wrong signal for parallel stages.
- **NN/g, *Progressive Disclosure*** — defer secondary detail to a subsidiary screen; focus attention on the
  primary (nngroup.com/articles/progressive-disclosure).

**Takeaway:** a **stepper/rail is the wrong primary metaphor** for parallel stages (it reads as gated). Use a
**command-center Overview + peer entry-points (cards or tabs)** for the stages, with **progressive
disclosure** into each stage's own workspace. A thin progress *indicator* can remain as read-only context,
but must not look like a gate.

### 2.3 AI authoring — the split-screen "canvas/artifact" pattern
- **ChatGPT Canvas** = a **dual-pane** interface: conversation on one side, a **persistent, directly-editable
  document/code** on the other (chatgptaihub.com/…canvas…; buildfastwithai.com/ai-tools/chatgpt-canvas;
  aiwiki.ai/wiki/chatgpt_canvas).
- **Claude Artifacts** = the artifact is **isolated from the chat and updates in real time as you refine by
  chatting**; the artifact pane is **view-oriented** (the AI makes the edits)
  (medium.com/@yulia.savliuk/…; allthings.how/chatgpt-canvas-vs-claude-artifacts…).

**Takeaway:** the industry norm for "AI + evolving document" is **chat *beside* a live artifact**, not chat
with an on-demand popup. Genesis's Spec builder today is **full-width chat + an on-demand full-screen preview
popup** (21-03). This is a real, if minor, divergence — see §5.4 (recommend making a side-by-side artifact a
first-class option without discarding the annotate-in-popup flow).

### 2.4 Activity = audit chart, not chat transcript
- *"The chat log is the transcript. The audit trail is the chart."* (medium.com/@MindbytesAI/an-audit-trail-
  is-not-a-screenshot). saasui.design and appmaster.io converge: a good activity/audit feed is a
  **time-ordered record of events** (actor · time · resource · what-changed), **each linking to the affected
  object**, chronological + scannable + scales (saasui.design/blog/saas-activity-feed-audit-log-ux-patterns;
  uxpatterns.dev/patterns/data-display/timeline).

**Takeaway:** the draft's "Activity is an audit trail, not a chat transcript" is well-founded and **already
matches** what Genesis has (m0013 `lifecycle_transitions` → the `ActivityFeed`). Extend it feature-wide
(across all stages) with per-event object links.

---

## 3. Current-code audit (what exists, what's reusable, what must generalize)

### 3.1 Frontend (`web/src/features/features/`)
| File | Today | For the reframe |
|---|---|---|
| `FeaturePage.tsx` | Workspace landing = `Page` → `ArtifactPipeline` + `ActivityFeed`. | **Becomes the workspace shell** (command-center Overview + stage entry-points + Artifacts + Activity + reserved Stories). |
| `ArtifactPipeline.tsx` | **Linear** row: Spec card + `Connector` chevrons + `PlaceholderCard` Design/Breakdown ("Coming soon", disabled). Shared `StageFrame`. | **Replaced** — the linear/connector metaphor + disabled-placeholder gating is exactly what goes. `StageFrame` is a good seed for the new **stage-container** card, minus connectors/gating. |
| `SpecWorkspace.tsx` | The rich Spec inner surface: full-width `ChatThread` (`chrome="spec"`) + top action bar (Add context, lifecycle **allowed-action** buttons, Export .md, Save milestone, Preview) + full-screen annotatable Preview (Lavish) + comment-queue rail. | **The reference "stage inner surface."** Its action-bar + allowed-action-button pattern is the template every future stage inherits via the stage-container contract. |
| `ActivityFeed.tsx` | Renders `useFeatureActivity` (spec lifecycle audit; from→to, action, actor, at). | **Generalize** to feature-wide (all stages' transitions) + per-event object links. |
| `FeaturesTab.tsx` | Per-app Features grid (cards) + Create dialog. | Mostly unchanged; maybe surface a lightweight per-feature progress hint. |
| `hooks.ts` / `status.ts` | Query/mutation hooks; **spec** status labels/tones + `SpecAllowed`/`ApplyAction`. | Generalize `status.ts` to a **stage-agnostic** status vocabulary + reuse the allowed-action hook shape per stage. |

### 3.2 Backend (`genesis/`)
- **`api/features.py`** — feature CRUD; **one spec per feature** (`create_spec` → 409 if exists); spec
  create opens a `feature_spec` chat; context injection; milestone snapshots; **lifecycle action endpoints**
  (`/spec/actions/{action}` + `/spec/allowed`) via `LifecycleService`; deprecated `PATCH /spec/status`;
  `/activity` over the audit; artifact/sdk.js/export.md. → **The action-endpoint + allowed pattern
  generalizes cleanly to per-stage**; the **one-spec-per-feature** assumption is the main thing to expand.
- **`kb/features.py` `FeatureStore` (m0010)** — `kb_features` / `kb_feature_specs` (1:1) /
  `kb_feature_spec_revisions`. m0014 `row_version` CAS on set_status. → A **generalized multi-stage artifact
  model** (an artifact per (feature, stage) with status + revisions + provenance) is the key data change —
  likely a **small additive migration** (umbrella §10.3 / 28-04 decision). SCD-2/revisions pattern reused.
- **`genesis/domain/`** (ADR-050) — **this is the big reuse win:**
  - `LifecycleService` is **generic**: a registry `{EntityKind: EntityLifecycle}` where each
    `EntityLifecycle` bundles a transition table + preconditions + `read_state`/`write_state` callables +
    an emit sink (m0013). Adding a **feature-stage** machine = registering more `EntityLifecycle`s over new
    transition tables — **no `if/elif`, no engine change**.
  - `enums.py` **already** defines `ArtifactKind{SPEC, UX_DESIGN, TECHNICAL_DESIGN, BREAKDOWN, STORY_DESIGN,
    IMPLEMENTATION, CODE_REVIEW, DEPLOYMENT, VERIFICATION}`, `EntityKind{FEATURE, SPEC, STORY, STAGE}`, and
    forward-compatible story-stage `LifecycleState`s.
  - `transitions.py` has the live `SPEC_*` tables + a **forward-compatible `STORY_STAGE_*` table**.
  - m0013 `lifecycle_transitions` + `LifecycleAuditStore.list_for(kind, id)` = the Activity substrate.
  - **One generalization to note:** `EntityLifecycle.read_state`/`write_state` are keyed by a single
    `entity_id: int`. Parallel feature-stages need addressing per **(feature, stage)** — either a `STAGE`
    entity row per stage (clean; recommended) or composite keying. A 28-04 detail.

**Audit verdict:** ~70% of the reframe is **composition + UX** over existing, well-factored seams
(`LifecycleService`, m0013 audit, revisions/versioning, the `feature_spec` authoring surface, `StageFrame`).
The genuinely new backend piece is a **generalized per-stage artifact model** (a likely small additive
migration) + registering **feature-stage lifecycle machines**.

---

## 4. Genesis-fit — the draft, classified (adopt / adapt / defer / drop)

| Draft concept | Verdict | Notes |
|---|---|---|
| Feature = workspace (not a wizard) | **ADOPT** | The core idea; realizes ADR-044 as a parallel workspace. |
| Lifecycle **rail** as primary nav | **ADAPT** | Keep a **non-gating progress indicator**, but the primary metaphor is a command-center Overview + peer stage entry-points (§2.2). No sequential unlock. |
| Feature IA: Overview / Stories / Artifacts / Activity | **ADOPT (Stories reserved)** | Adopt Overview / Artifacts / Activity now; **reserve** the Stories slot (built later). |
| Feature-level stages: Spec / UX / Tech Design / Breakdown | **ADOPT (parallel)** | Spec live; the other three are **first-class "not yet available"** containers — *not* sequential-locked. |
| Story-level execution (Design→…→Done), story workspace | **DEFER** | First-class later; framework reserves the slot. |
| Implementation / Deployment / Verify (real Appian writes) | **DEFER (own ADRs)** | Read-only-now; reserved plug-points; future program. |
| Git branch/commit surface (§16) | **DROP** | Not Appian reality (user-confirmed). |
| Roles/personas (PO/UX/Architect/…) | **DROP as access/assignment; keep as labels** | Single-user; may *label* a stage's purpose, never gate/assign. |
| "My Work" personal queue, ownership, reviewers, assignment | **DROP** | Single-user (ADR-026). Return only if Genesis ever goes multi-user. |
| "Needs Attention" panel | **ADAPT** | Keep as **single-user feature health** (unresolved AI findings, blocked/stale artifacts, incomplete stages) — not an assignment inbox. |
| Artifacts tab (type/version/source/provenance) | **ADOPT** | Reuse revisions/versioning + document provenance (ADR-041). |
| Activity tab (audit, not chat) | **ADOPT** | Already have m0013 → `ActivityFeed`; extend feature-wide. |
| Stage-completion dialog (shows unresolved/blocking + approved version) | **ADOPT** | Generalize the existing allowed-action flow + record the approved artifact version. |
| Reproducibility snapshot (KB + doc revisions used) | **ADAPT (later)** | Strong idea; leans on KB SCD-2 + doc revisions + run provenance. Framework leaves room; full build likely with the stages that generate artifacts. |
| Structured AI findings (not buried in chat) | **ADOPT (as a pattern)** | Findings become first-class objects on a stage (like the code-review verdict). Framework defines the slot; per-stage findings arrive with each stage. |
| AI principles §29 (visible versions, sources, no silent gate-complete, resumable) | **ADOPT** | Already aligned with ADR-031/033/045/050. |
| Verify Design AI workflow (§9) | **DEFER** | A UX-Design-phase capability (needs a prototype artifact first). |
| Status model / component inventory / routes / API (Appendices) | **ADAPT** | Good seeds; align to Genesis (`LifecycleService`, `/api`, single-user) in 28-03/28-04. |

---

## 5. Recommended model (for 28-02 to render)

### 5.1 Information architecture
```
/applications/:appUuid/features/:featureId        → Feature Workspace
   ├─ Overview     (command center — default)
   ├─ <stages surfaced here as peer entry-points>  Spec · UX Design · Technical Design · Breakdown
   ├─ Artifacts    (all feature artifacts: type/version/source/provenance)
   ├─ Activity     (audit timeline over m0013, feature-wide, object-linked)
   └─ (reserved)   Stories                          ← first-class slot; built later
   builder routes (unchanged pattern): …/features/:id/spec  (and later …/ux, …/design, …/breakdown)
```

**Recommendation:** **Overview + peer stage cards** (not tabs-per-stage, not a rail-as-nav). Rationale: 4
stages of unequal weight + a reserved Stories area → a **command-center Overview** that shows a compact,
**non-gating** progress indicator + a **grid of stage cards** (each a stage-container) reads as "parallel,
any-order, inspectable" far better than a tab strip that hides peers or a stepper that implies order (§2.2).
Artifacts + Activity are top-level tabs on the workspace. (We'll mock the alternative — stages-as-tabs — in
28-02 so the choice is made on real pixels; this is the recommendation.)

### 5.2 The stage-container contract (the plug-in unit — the heart of the framework)
Every stage (Spec now; UX/Tech/Breakdown later) renders through **one** contract so a future phase implements
only the inner surface:
- **Header:** stage name + a **status badge** (stage-agnostic vocabulary) + the stage's **allowed actions**
  (from `LifecycleService.allowed`, as buttons — reusing the Spec pattern).
- **Body (stage-specific plug-in):** the stage's own surface (Spec = chat + artifact; others slot in later).
- **Artifact strip:** current artifact + **version/provenance** + version history.
- **AI-assist entry:** consistent affordance (the stage's chat/agent action).
- **Completion:** a shared **completion dialog** (unresolved/blocking summary + the exact approved artifact
  version + optional note) that drives a `LifecycleService` transition + m0013 audit.
- **State model (stage-agnostic):** `not-started → in-progress → in-review → completed` (+ `reopen`) —
  the Spec machine's shape, reused per stage. A stage may also be **"not yet available"** (first-class but
  the capability ships in a later phase) — visually distinct from, and **never** implying, sequential gating.

### 5.3 Feature status (answers umbrella §10.2)
**Recommend DERIVED (roll-up) with an optional explicit override**, following Jira's epic-status precedent
(§2.1): overall status computed from stage states (e.g. any in-progress → In Progress; all complete →
Completed; none started → Draft), with an explicit Blocked/Cancelled override. Avoids a hand-maintained
status drifting from reality; matches the parallel model.

### 5.4 Spec builder reconciliation (answers a §5 tension)
Keep the dedicated builder route (`…/spec`) + the annotate-in-popup flow (21-03) — but per §2.3, **offer a
first-class side-by-side "chat + live artifact" layout** as the builder's default on wide screens (canvas
pattern), with the annotatable full-screen preview still one click away. In the *workspace* (Overview), the
Spec stage-container shows a **light summary** (status + artifact version + open-builder), not the full
builder. This is a 28-03 decision; noted here as the recommended direction.

### 5.5 Single-user "Needs Attention" (adapted)
A compact Overview panel driven by **system signals only**: incomplete/in-review stages, unresolved AI
findings, blocked/stale artifacts, failed AI runs. **No** assignment/owner/reviewer.

---

## 6. ADR-056 (draft — Proposed)

**ADR-056 — The Genesis Feature Workspace (parallel, plug-in stages).**
*Context:* ADR-044 modeled a feature as a **sequential** artifact pipeline (unlock-on-completion; Design/
Breakdown as disabled placeholders). Real usage wants **parallel, any-order** work across feature-level
stages, and Genesis needs a durable frame future capabilities plug into.
*Decision:* A Feature is a **workspace** of **parallel, independently-advanceable, plug-in stage containers**
(Spec, UX Design, Technical Design, Feature Breakdown) over a shared **artifact + version/provenance +
activity + lifecycle** substrate. Each stage is governed by its **own `LifecycleService` machine** (ADR-050;
m0013 audit); the primary UX is a **command-center Overview + peer stage entry-points** with a **non-gating**
progress indicator (no stepper/wizard). Overall feature status is **derived** from stage states (Jira-style
roll-up) with an explicit override. **Single-user** — no assignment/roles/permissions/lenses/My-Work
(ADR-026). **Read-only-now** — story execution (implementation/code-review/deploy/verify), the git/branch
model, and environment promotion are **reserved plug-points**, not built (future program, own ADRs, ADR-021/
033). **Stories** are a reserved first-class slot for a later phase. Reuses the Phase-27 design language
(ADR-055) and Phase-20/21 spec authoring + versioning.
*Consequences:* **Supersedes ADR-044's sequential unlock-on-completion clause** (the feature-as-workspace +
per-artifact-status core of ADR-044 stands). A generalized per-stage artifact model may need a small
**additive** migration (ADR-030/019 respected; `CORE_MAJOR` unchanged). Enables each future stage to ship as
"inner surface + one transition table + one `ArtifactKind`" with no shell changes.
*Status:* **Proposed** (finalize at 28-03; Accept at 28-04/28-06).

---

## 7. Open questions for the user (before/at 28-02)

1. **Stage representation** — I recommend **Overview + peer stage cards** (with a non-gating progress
   indicator), and will also mock **stages-as-tabs** for comparison. Any early preference?
2. **Feature status** — OK to go **derived (roll-up) + explicit override** (Jira-style), rather than a purely
   manual status?
3. **Spec builder** — OK to explore a **side-by-side chat + live artifact** as the builder default (canvas
   pattern) while keeping the annotate-in-popup review? Or keep 21-03's full-width chat as-is for now?
4. **"Not yet available" stages** — confirm we show UX/Tech-Design/Breakdown as **first-class containers with
   a clear "arriving in a later phase" treatment** (startable-later), rather than hiding them until built.
5. **Migration appetite** (umbrella §10.3) — comfortable with a **small additive migration** in 28-04 for the
   generalized per-stage artifact model if needed?

*(None block 28-02; they sharpen the mockups. My recommendations above are the default if you're happy with
them.)*
