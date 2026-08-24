# 27-06 — Applications, Application Detail, Features & Spec Builder

> **Phase 27 (UI/UX Revamp) · sub-phase 06 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04, 27-05**.
> **Status:** ⭐ **RELEASED — genesis v0.53.0 (2026-08-24)** (genesis `a85dd83`; independent review = SHIP clean, 2 SHOULD-FIX applied). *The core SDLC authoring surface.*

## Objective
Redesign the primary product surface to the approved mockups, behaviour-preserving: the **Applications** landing, **Application Detail** (overview + business-map + features + business-artifacts tabs), the **Feature page** (artifact pipeline + activity feed), and the **Spec Builder** (full-width chat + full-screen annotatable preview).

## Scope (components)
`applications/{ApplicationsPage,ApplicationDetail,AddApplicationDialog,business-map/*}`, `features/{FeaturePage,FeaturesTab,ArtifactPipeline,ActivityFeed,SpecBuilderPage,SpecWorkspace,CreateFeatureDialog,status}`, `library/BusinessArtifactsTab`.

## Deliverables
- Modernized Applications grid/list + add-application flow.
- Application Detail with the new tab/header pattern; **business-map (React Flow)** restyled to tokens (retire `index.css` React-Flow dark overrides in favor of themed tokens; light + dark parity).
- Feature page artifact pipeline + activity feed to the new language.
- Spec Builder: the chat + annotatable preview split re-themed; annotation SDK surfaces (Lavish) restyled to the light-first palette.

## Acceptance / gates
- All existing flows work (create/sync app, create feature, build/annotate spec, advance pipeline); feature tests updated + green.
- Light default + dark parity; jest-axe green on each page; responsive.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
No API/behavioural change; annotation/business-map *logic* unchanged (presentation only).
