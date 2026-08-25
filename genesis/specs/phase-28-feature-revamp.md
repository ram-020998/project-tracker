# Phase 28 — Feature Revamp (the Feature Workspace framework)

> **Status:** ⭐ **COMPLETE — SHIPPED as genesis v0.54.0 + genesis-workflows v0.11.0 (2026-08-25, CI green).** · **Author:** Genesis agent · **Date:** 2026-08-25
> **Type:** genesis frontend + a thin backend lifecycle/model layer (ships a release) · **Depends on:** Phase 20/21 (Features & Specs; ADR-042/044), Phase 25-01 (`LifecycleService`/`domain/`; ADR-050), Phase 27 (the light-first design language; ADR-055).

---

## 1. Why this phase exists

Today a Feature is presented as a **linear artifact pipeline**: the Spec card is functional and the
**Design / Breakdown** cards are **disabled placeholders** wired for **sequential unlock-on-completion**
(`web/features/features/ArtifactPipeline.tsx`, ADR-044). That model does not match how the work actually
happens — a user wants to **start a Spec and, in parallel, start a Design, a Technical Design, or a
Breakdown**, in any order, without one gating another.

This phase **re-conceives the Feature as a durable, UX-centric *workspace*** — a framework into which every
future capability (UX Design, Technical Design, Feature Breakdown, and later Stories + story execution)
**plugs in directly**, rather than each future phase re-litigating the feature-page UX when it is built.

**This phase builds the framework, not the stage features.** We finalize the **feature-level** IA, the
landing/command-center, the Spec tab as it exists, the parallel lifecycle model, the artifact/activity model,
and the plug-in "stage container" pattern — then future phases (starting with **UX Design**) drop their
capability into a known slot.

The trigger is the review of the user's draft
`artifacts/designs/Genesis_Appian_Orchestrator_Feature_Workspace_UX_Design.md` (2026-08-25). That draft is a
rich, multi-user, end-to-end (spec→deploy→verify) vision; **this phase adopts its feature-level mental model
and adapts it to Genesis's actual constraints** (see §3).

---

## 2. Goal

A **durable, extensible Feature Workspace** whose information architecture, navigation, states, and
interaction patterns are finalized and built as a **framework** — so that:

- A user understands a feature's state within seconds (a persistent, **parallel-capable** lifecycle view).
- **Feature-level stages run in parallel** — Spec, UX Design, Technical Design, Feature Breakdown are each
  independently startable/advanceable; none is gated behind another (the sequential rail is gone).
- Each stage is a **plug-in "stage container"** with a consistent shell (status, artifacts, versions,
  activity, AI-assist, completion) so a future phase implements only that stage's *inner* surface.
- **Artifacts + Activity are first-class** and cross-cutting (version/provenance visible; every state change
  audited) — reusing the existing lifecycle-audit + versioning machinery.
- The shell is **forward-compatible** with **Stories** (first-class later) and, further out, story execution
  (implementation/deploy/verify) — clean plug-points, no scaffolding for them built now.

---

## 3. Constraints that shape this phase (decided with the user, 2026-08-25)

These adapt the user's draft design to Genesis reality. **They are firm inputs, not open questions.**

1. **Single-user — no assignment/roles/permissions/lenses (ADR-026).** The draft's ownership model,
   role dashboards, reviewer/owner assignment, and personal "My Work" queue are **OUT**. Anyone can act on
   any stage. "Roles" (PO/UX/Architect/Dev/…) are, at most, *descriptive labels* on a stage's purpose —
   never access control, assignment, or a user-identity concept. No multi-user configuration anywhere.
   *(If Genesis ever goes multi-user, assignment/My-Work return then — not now.)*
2. **Read-only against Appian stays (ADR-036/037).** Genesis does not create or deploy Appian objects yet.
   The draft's **story-execution write stages (Implementation, Code Review of real changes, Deployment,
   Verification), the git branch/commit model, and environment promotion are OUT of this phase** — real
   build/deploy is a future program (≈ months out) with its own ADRs (ADR-021 `pre_mutation`/ADR-033
   human-confirmed mutations). The framework only leaves **clean plug-points** for them.
3. **Stories are first-class *later*.** The framework must **accommodate** a Stories tab + story workspace
   (route/IA/nav reserve the slot), but the **story workflow is not finalized or built in this phase** — we
   finalize the **feature** workflow now. `domain/` already defines a forward-compatible `STORY` entity +
   story-stage machine; we do not wire it here.
4. **Parallel, not sequential (amends ADR-044).** The "sequential unlock-on-completion" clause of ADR-044 is
   replaced by **parallel, independently-advanceable stages**. This is the core behavioral change and needs a
   new/amended ADR (see §7).
5. **Framework/architecture only.** No stage-specific capability (UX mockup upload/AI mockup authoring,
   tech-design generation, breakdown generation) is built here. Spec already exists and is wired in as the
   reference stage.
6. **Reuse the shipped foundations.** Light-first Indigo·Slate design language + primitives (Phase 27,
   ADR-055); `LifecycleService`/`domain/` typed transitions + m0013 audit + allowed-actions (ADR-050);
   feature spec revisions/versioning + document provenance (Phase 20/ADR-041); the `feature_spec` chat
   authoring surface (Phase 20/21).

---

## 4. Current state (what we're replacing / extending) — code-grounded

- **Web** (`web/src/features/features/`): `FeaturePage.tsx` (workspace landing) renders
  `ArtifactPipeline.tsx` (the **linear** Spec + Design/Breakdown-placeholder pipeline with connectors) +
  `ActivityFeed.tsx`. `SpecWorkspace.tsx` + `SpecBuilderPage.tsx` = the full-width `feature_spec` chat + the
  annotatable Lavish preview (route `…/features/:featureId/spec`). `FeaturesTab.tsx` = the per-app Features
  list; `CreateFeatureDialog.tsx`; `hooks.ts`; `status.ts`.
- **Backend** (`genesis/`): `api/features.py` (feature CRUD + spec create/context/milestone + spec **action**
  endpoints `POST /features/{id}/spec/actions/{action}` + `/activity`); `kb/features.py` `FeatureStore` over
  **m0010** (`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`); **m0014** `row_version` CAS.
- **Domain** (`genesis/domain/`, ADR-050): `LifecycleService` (single transition authority), `enums.py`
  already defines `EntityKind{FEATURE,SPEC,STORY,STAGE}`, a rich `ArtifactKind{SPEC,UX_DESIGN,
  TECHNICAL_DESIGN,BREAKDOWN,STORY_DESIGN,IMPLEMENTATION,CODE_REVIEW,DEPLOYMENT,VERIFICATION}`, and
  `LifecycleState` (spec states live; story-stage states forward-compatible); `transitions.py` has the live
  `SPEC_*` tables + a forward-compatible `STORY_STAGE_*` table; **m0013 `lifecycle_transitions`** is the audit.
  → **The bones for a multi-stage, parallel feature model already exist**; this phase mostly *composes* them
  into a feature-stage machine + the workspace UI.

**Takeaway:** the reframe is more *composition + UX* than net-new backend. The main additions are a
**feature-stage** lifecycle (one independent state machine per feature-level stage) + a generalized
**feature artifact** model (beyond the single spec) + the workspace UI shell.

---

## 5. The reframed Feature model (to be finalized in 28-01..28-03)

*A working hypothesis for research/mockups to refine — NOT yet locked.*

- **Feature = a workspace** with a persistent header (name, app, identifier, overall status) + a
  **parallel stage overview** (not a gated rail) + cross-cutting **Artifacts** and **Activity**.
- **Feature-level stages** (each an independent, parallel state machine, each a plug-in container):
  **Spec** (built), **UX Design**, **Technical Design**, **Feature Breakdown**. Each stage has: a status,
  its artifact(s) with versions/provenance, an AI-assist surface, a completion action (records the approved
  artifact version), and its own activity.
- **Stories** (reserved slot; built later): after Breakdown, a Stories tab + per-story workspace.
- **Feature IA (candidate):** `Overview` · `Stages`(or the stages surfaced on Overview) · `Artifacts` ·
  `Activity` · *(reserved)* `Stories`. The exact tab set + whether stages are tabs vs cards-on-overview is a
  **28-03 decision**.

**Open design tensions for research/mockups (not scope questions — design questions):**
- Stages as **tabs** vs **cards on the Overview** vs a **non-gated rail of entry-points** — which best
  communicates "parallel, any-order, inspectable" for 4 stages (and stays sane when Stories arrive)?
- Where the **command-center** lives (a dedicated Overview vs the landing itself).
- How a **completed** stage reads vs an **in-progress** vs **not-started** one, without implying gating.
- How the **Spec builder** (full-width chat + preview, per 21-03) reconciles with a stage that also needs an
  at-a-glance status/artifact view — do we keep the builder as a dedicated route and a lighter stage summary
  on the workspace? (Candidate: yes.)
- The at-a-glance **"needs attention"** concept from the draft — valuable, but must be single-user (feature
  health / unresolved AI findings / blocked artifacts), not an assignment inbox.

---

## 6. Scope

**In scope (this phase):**
- Finalized feature-workspace IA, navigation, states, and interaction patterns (research + mockups +
  brainstorm).
- The built **framework**: the workspace shell, the **parallel** stage-overview, the **stage-container**
  plug-in pattern, a generalized **feature artifact + version/provenance** surface, the **Activity** surface,
  and the **feature-stage lifecycle** (parallel machines) via `LifecycleService`/`domain/`.
- **Spec** wired into the new framework as the one live stage (behavior preserved: create → build → review →
  complete; annotatable preview).
- UX Design / Technical Design / Breakdown present as **first-class stage containers in a "not yet available"
  state** — *not* sequential-locked, but "startable in a future release" plug-points (empty inner surface).
- ADR (new/amended) for the parallel workspace model.

**Out of scope (future phases):**
- Building UX Design authoring (mockup upload / AI mockup creation), Technical Design generation, or
  Breakdown generation — each is its own later phase that plugs into a slot this phase defines.
- Stories as first-class entities + the story workspace + story execution (design/impl/review/deploy/verify).
- Any Appian **write/deploy** capability; git/branch model; environment promotion.
- Multi-user, assignment, roles/permissions, personal "My Work".

---

## 7. ADR

- **ADR-056 (PROPOSED — this phase): The Genesis Feature Workspace.** A feature is a workspace of
  **parallel, independently-advanceable, plug-in stage containers** over a shared artifact/activity/lifecycle
  substrate — **superseding ADR-044's sequential unlock-on-completion**. Single-user (no assignment/roles);
  read-only-now (story-execution/deploy are reserved plug-points); Stories reserved as a first-class slot for
  a later phase. Reuses `LifecycleService`/`domain/` (ADR-050), the Phase-27 design language (ADR-055), and
  the Phase-20/21 spec authoring + versioning. **Drafted in 28-01/28-03, Accepted at 28-04/28-06.**
  Mirror in `reference/decision-log.md` + `bible/04`.

---

## 8. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **28-01** | Research & UX analysis | External product-pattern research (issue/feature trackers, AI-native dev tools, workspace UIs) + a Genesis-fit analysis + a recommended IA/model + the ADR-056 draft. **Docs only.** | ⭐ user review before mockups |
| **28-02** | Wireframes & hi-fi mockups | Lo-fi wireframes → coded hi-fi mockups at **`/dev/mockups`** (light-first, Phase-27 language) of the feature landing/command-center, the stage-overview (parallel), a stage container (Spec live; others "not yet available"), Artifacts, Activity. **Dev-only; no production wiring.** | ⭐ user review of the mockups |
| **28-03** | Brainstorm & finalize | Iterate the mockups with the user; resolve the §5 design tensions; **lock** the IA + model + ADR-056. | ⭐ user sign-off → build unlocked |
| **28-04** | Feature-workspace architecture build | Build the finalized framework in production (web shell + stage-container pattern + parallel feature-stage lifecycle + artifact/activity model + Spec wired in; other stages as "not yet available" plug-points). Gates green; **ADR-056 Accepted**; committed `web/static`. | independent review = SHIP |
| **28-05** | Code review & hardening | Independent architecture/code review of the built framework; a11y (jest-axe) + dark parity + no-hardcoded-hex + contract-fixture pass; apply SHOULD-FIX. | review clean |
| **28-06** | Release | Version bump + tag + push + CI green; docs (bible/tracker/progress/ADR) updated; report. | CI green |

**Suggested order:** 28-01 → 28-02 → 28-03 → 28-04 → 28-05 → 28-06 (linear; each gated on the prior).

---

## 9. Release plan

Frontend-heavy genesis release (+ a thin backend lifecycle/model layer; possibly a small additive migration
**only if** a generalized feature-artifact model needs one — to be determined in 28-04, kept additive per
ADR-030/019). Other repos (genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser) expected
**unchanged**. `CORE_MAJOR` unchanged. One coordinated **genesis vX.Y.0** at 28-06. Per-sub-phase: build →
gates → local commit → independent review → docs → present; **no tag/push until 28-06 on the user's
go-ahead**.

---

## 10. Open questions for the user (non-blocking; can resolve during 28-01/28-03)

1. **Tab set naming/shape** — is `Overview · Artifacts · Activity` + stages-on-overview the right frame, or do
   you want explicit per-stage tabs? (A 28-03 decision, but early steer welcome.)
2. **"Feature status" semantics** in a parallel world — is overall status derived (e.g. from stage
   completion) or set explicitly? (ADR-044 said feature has no single-artifact-derived status.)
3. **Migration appetite** — are you comfortable with a small additive migration in 28-04 if the generalized
   feature-artifact model needs one, or should we constrain 28-04 to the existing m0010 shapes?

*(These are refinements; the phase can start 28-01 without them.)*
