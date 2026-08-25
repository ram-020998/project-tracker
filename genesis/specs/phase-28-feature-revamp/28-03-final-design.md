# 28-03 — Final Design (LOCKED for build)

> **Status:** ✅ **FINAL — FOR BUILD SIGN-OFF (2026-08-25).** · **Type:** design finalization / docs. · **Phase:** 28 (Feature Revamp). · **Gate:** ⭐ user sign-off on THIS document unlocks 28-04 (build). No build before sign-off.
> **Basis:** 28-01 findings (recommended model) + 28-02 mockups at `/dev/feature-workspace`, **approved by the user** (Overview+cards + full-bleed stage workspace + expand-to-immersive). This is the buildable contract 28-04 implements against.

---

## 1. Resolved decisions (locked)

| # | Decision | Resolution |
|---|---|---|
| D1 | Stage representation | **Command-center Overview + peer stage cards.** Not a stepper/rail, not stages-as-tabs. A **non-gating** progress indicator is context only. |
| D2 | Opening a stage | Routes to a **dedicated full-bleed stage workspace** (its own route/URL), big work area, with an **Expand → immersive** toggle (hides the app shell; "Exit full screen" returns). |
| D3 | Feature status | **Derived (roll-up) from stage states**, with an explicit **Blocked/Cancelled override**. Not hand-maintained. |
| D4 | Parallelism | Feature-level stages are **independent / any-order**; **no stage gates another** (supersedes ADR-044 sequential unlock). |
| D5 | "Not-yet-available" stages | UX Design / Technical Design / Feature Breakdown ship as **first-class stage containers in a `not-available` ("arriving in a later phase") state** — visibly not-gated, startable when their phase lands. |
| D6 | Spec builder surface | **Side-by-side chat + live artifact ("canvas")** in the full-bleed workspace; the annotate-in-popup review (21-03 Lavish) stays available. |
| D7 | Immersive default | **Default = within-shell** (sidebar visible); Expand is opt-in per session. Breadcrumbs/back stay visible in the workspace header even when immersive. |
| D8 | Stories | **Reserved first-class slot** (nav + route) rendered as a "coming in a later phase" empty state; the story workflow is NOT built this phase. |
| D9 | Future write stages | Implementation/Code-Review/Deploy/Verify + git/deploy are **reserved plug-points only** (read-only-now; future program, own ADRs). |
| D10 | Single-user | **No assignment/roles/permissions/lenses/My-Work.** "Needs attention" = system signals only. |
| D11 | Migration | A **small additive migration** is permitted for the generalized per-stage artifact model (ADR-030/019 respected). |

---

## 2. Information architecture & routes

```
/applications/:appUuid/features/:featureId                 → Feature Workspace (command center)
   tabs:  Overview (default) · Artifacts · Activity · Stories(reserved)
   stages surfaced as peer CARDS on Overview (Spec · UX Design · Technical Design · Feature Breakdown)

/applications/:appUuid/features/:featureId/:stage          → full-bleed Stage Workspace
   :stage ∈ { spec (live) | ux | design | breakdown }      (ux/design/breakdown = not-available now)
   (existing …/spec route is absorbed into this pattern; ?expand=1 opens immersive; deep-linkable)
```
- The workspace **header** (back-to-feature · stage name · status · allowed actions · Expand) persists in
  both within-shell and immersive.
- Stage cards are real links → a card can be cmd/ctrl-clicked into a new browser tab (URL-addressable).

---

## 3. Stage-container contract (the plug-in unit)

Every stage renders through **one** contract so a future phase implements only the inner surface.

```ts
type StageStatus = "not-started" | "in-progress" | "in-review" | "completed" | "not-available";

interface StageDescriptor {
  key: string;                 // "spec" | "ux" | "design" | "breakdown" | (future)
  name: string;                // "Spec", "UX Design", …
  icon: LucideIcon;
  artifactKind: ArtifactKind;  // domain/enums.py — SPEC | UX_DESIGN | TECHNICAL_DESIGN | BREAKDOWN | …
  available: boolean;          // false → renders the "arriving in a later phase" body
  summary: StageSummary;       // status + current artifact ref (version/provenance) for the Overview card
  Workspace?: React.ComponentType<StageWorkspaceProps>; // the inner surface (Spec ships one; others later)
}
```
- **Overview card** = compact summary: icon, name, blurb, **status badge**, quick actions (Open · View).
- **Full-bleed workspace** = header (name · `StatusBadge` · **allowed-action buttons from
  `LifecycleService.allowed`** · Expand) + the stage's **inner surface** + an **artifact strip**
  (current artifact · version · provenance · Version history · Preview) + a **completion** action
  (allowed action → completion dialog → `LifecycleService.transition` → m0013 audit).
- A **`not-available`** stage renders the same frame with an "arriving in a later phase — not blocked by any
  other stage" body (no gating language).

**Adding a future stage = inner `Workspace` component + one `LifecycleState`/transition row + one
`ArtifactKind` + one `StageDescriptor` entry. No edits to the shell / Overview / rail.** (28-05 verifies this
with a written UX-Design plug-in walkthrough.)

---

## 4. Stage-agnostic lifecycle & derived feature status

- **Per-stage machine** (reuses the Spec shape; `domain/transitions.py`):
  `not-started —start→ in-progress —submit→ in-review —approve→ completed`
  (+ `in-review —request-changes→ in-progress`, `completed —reopen→ in-progress`).
  A `not-available` stage exposes **no** actions.
- Each stage is its **own `EntityLifecycle`** registered in the `LifecycleService` (ADR-050); every
  transition is audited to **m0013** with the entity addressed per **(feature, stage)** (see §6).
- **Derived feature status** (D3): `Cancelled`/`Blocked` if explicitly set; else `Completed` if all
  *available* stages are `completed`; else `In progress` if any stage is `in-progress`/`in-review`; else
  `Draft`. Pure function over stage states (unit-tested, no DB).

---

## 5. Overview composition, Artifacts, Activity

- **Overview:** feature header (name · app · derived status · non-gating progress meter) → a **Feature
  health** card + a single-user **Needs attention** card (system signals: stages in review, unresolved AI
  findings, blocked/stale artifacts — no assignment) → the **stage cards** grid → **Artifacts** + **Activity**
  glances.
- **Artifacts tab:** feature-wide table — name · type · **version** · **source** (Generated · Uploaded ·
  Google Drive · Appian KB-derived) · updated; row → version history + provenance. Reuses spec revisions +
  document provenance (ADR-041).
- **Activity tab:** feature-wide **audit** timeline over **m0013** (`from→to`, action, actor, at) across all
  the feature's stage entities; each event **links to its object**. "Audit, not a chat transcript."

---

## 6. Backend plan (28-04)

**Reuse-first; the `LifecycleService`/`domain/` layer already supports this (ADR-050).**

1. **Generalized per-stage artifact model (additive migration sketch, `m0015`).** Today: one
   `kb_feature_specs` row per feature (1:1). Add a **`kb_feature_stages`** table (or generalize specs) —
   one row per **(feature_id, stage_key)** with: `status`, `artifact_kind`, `html_path`/`content_hash`,
   `row_version` (CAS, m0014 pattern), timestamps. Spec migrates in as the `spec` stage (back-compat: keep
   the existing spec endpoints working; the spec's chat-session + revisions stay). **Additive only**; bump
   `current_version` + its tests (the §7 lesson). *(If a leaner path is found in 28-04 — e.g. reusing
   `kb_feature_specs` with a `stage` column — that's an allowed refinement; decided at build time.)*
2. **Feature-stage lifecycle machines.** Register an `EntityLifecycle` per stage kind (or a generic
   `STAGE` kind addressed by `(feature_id, stage_key)`) via `read_state`/`write_state` over the new store;
   emit to `LifecycleAuditStore` (m0013). Reuse `build_spec_lifecycle` shape.
3. **API (additive, under `/api`).**
   `GET /features/{id}` → include the **stages[]** (status + artifact summary) + **derived status**;
   `GET /features/{id}/stages/{stage}` · `GET …/stages/{stage}/allowed` ·
   `POST …/stages/{stage}/actions/{action}` (LifecycleService; 409 on illegal/precondition/stale) ·
   `GET /features/{id}/artifacts` (feature-wide) · `GET /features/{id}/activity` (already exists — widen to
   all stages). The existing spec routes remain (spec = the `spec` stage).
4. **No new write-to-Appian capability**; no story tables. Stories/future-write remain reserved.

---

## 7. Web component inventory (28-04)

`FeatureWorkspacePage` (shell + tabs + derived-status header) · `FeatureLifecycleMeter` (non-gating
progress) · `StageCard` · `StageGrid` · `StageWorkspacePage` (full-bleed route + Expand/immersive) ·
`StageWorkspaceHeader` (back · status · allowed actions · Expand) · `StageContainer` (contract wrapper:
inner surface + `ArtifactStrip` + completion) · `SpecStageWorkspace` (wraps the existing `SpecWorkspace`
canvas) · `StageNotAvailable` · `ArtifactsTab` + `ArtifactRow` · `ActivityTab` (reuse/rename `ActivityFeed`,
widened) · `NeedsAttentionCard` · `FeatureHealthCard` · `StoriesReserved` · a stage-agnostic `status.ts`
(labels/tones/actions). Replaces `ArtifactPipeline.tsx` (deleted). Reuses `SpecWorkspace`/`ChatThread`,
`shared/ui`, tokens (ADR-055/027). a11y (jest-axe) on every mountable surface; light + dark parity; no
hardcoded brand hex.

---

## 8. Out of scope / reserved (unchanged from the umbrella)

UX/Tech-Design/Breakdown **authoring** surfaces; Stories entities + story workspace + story execution
(design→…→done); Appian **write/deploy**, git/branch model, environment promotion; multi-user/assignment.
All are **reserved plug-points** the framework leaves clean.

---

## 9. ADR-056

Finalized (Proposed) in `reference/decision-log.md` + `bible/04` — **The Genesis Feature Workspace**
(parallel, plug-in stages; single-user; read-only-now plug-points; Stories reserved; supersedes ADR-044's
sequential unlock clause). **Accept at 28-04** (on build) / re-confirm at 28-06.

---

## 10. Sign-off

**Awaiting the user's explicit sign-off on this document.** On sign-off, 28-04 builds the framework exactly
to §2–§7. Micro-defaults (D7 immersive-opt-in; back/breadcrumbs visible in workspace) are assumed unless the
user says otherwise.
