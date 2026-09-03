# 30-05 — UX refinements (clickable stage cards + openable artifacts)

> **Status:** 📋 DRAFT. Gate: independent review = SHIP. · Part of Phase 30. Repo: **genesis** (web-only). Two small, user-requested fixes folded into this phase.

## Change A — the stage card itself is clickable (drop the "Open" button)

**Today** (`FeaturePage.tsx::StageCard`): the card shows a status badge + name + blurb, and a footer with
either the stage's `CardActions` or a generic **Open**/**Details** button. Opening a stage requires clicking
that button.

**Change:** the **card body becomes the primary click target** that navigates to the stage workspace
(`/applications/:appUuid/features/:id/:stageKey`); remove the standalone **Open**/**Details** button for **all**
stages. Genuinely-distinct secondary actions stay (Spec **Create spec** when none / **View**; UX & TD
**Re-run** / **View**), rendered above the card surface.

**Accessibility (the load-bearing detail):** a real `<button>` nested inside a click-target link/button is
invalid and fails a11y. Use the **card-as-link + overlay** pattern: the card's primary navigation is a single
accessible control (a `<button>`/`<Link>` spanning the card via an absolutely-positioned `::after` overlay or
an `onClick` on a `role`-correct element with a keyboard handler), and the secondary action buttons sit at a
higher `z-index` with `e.stopPropagation()` so they don't trigger navigation. Keep **jest-axe green** and
keyboard focus order sensible (card focusable; actions focusable after). A locked (prerequisite-unmet) card is
**not** navigable — it shows the "Complete Spec & UX Design first" hint and is `aria-disabled`.

**Files:** `FeaturePage.tsx` (`StageCard`), the stage `CardActions` components (ensure `stopPropagation`),
`features.test.tsx` (assert clicking the card navigates; the Open button is gone; jest-axe clean).

## Change B — artifacts are openable/viewable (like the Document Library)

**Today** (`FeaturePage.tsx::ArtifactsTab`): a static table (Spec [Generated] + linked Reference docs) with
**no way to open** a row.

**Change:** rows become clickable, and the tab lists **all generated stage artifacts** (Spec, UX Design,
Technical Design) + linked reference docs. On click:
- **Generated** artifacts (`Generated` source) → open a **read-only rendered HTML preview** in a full-screen
  overlay — reuse the `SpecPreviewOverlay`/`AnnotatablePreviewDialog` read-only path over the generalized
  stage artifact endpoint (`/features/{id}/stages/{stage}/artifact`, `annotate=0`). No annotation tools.
- **Reference** business docs → open the **Document Library viewer** (`navigate("/documents/:id")`), the same
  full-screen viewer the library uses.

**Sourcing the generated list:** derive from the feature detail's `stages` (each stage with an artifact at
`draft`+ contributes a row: name = stage title, type = stage name, source = "Generated", status). Reference
docs from the existing `useSpecContextCandidates`. A row carries enough to route/open (stage key or document
id).

**Files:** `FeaturePage.tsx` (`ArtifactsTab` → clickable rows + the generated-artifact overlay + the doc-viewer
navigation), a small shared read-only artifact preview (extract from `SpecPreviewOverlay` if convenient),
`features.test.tsx` (assert a generated row opens the preview; a reference row navigates to the viewer;
jest-axe clean).

## Why fold these into Phase 30

Technical Design adds a **third** generated artifact, which makes "open the artifact" materially more useful,
and the **clickable-card** affordance is the same entry pattern the TD stage uses — so both land naturally with
this phase rather than as a separate release.

## Gate

web tsc/eslint/vitest/build green; `web/static` committed; jest-axe clean on the Feature page (both tabs);
independent review = SHIP. Frontend-only.
