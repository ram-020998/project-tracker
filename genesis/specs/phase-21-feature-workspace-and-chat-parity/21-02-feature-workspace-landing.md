# 21-02 — Feature workspace landing + artifact cards

> **Status:** 📝 DRAFT · **Phase:** 21 · **Repo:** genesis (web + minor api) · **ADR:** ADR-044
> **Depends on:** Phase 20 (features) · **Blocks:** 21-03 (builder route split)

## Goal

Make the feature page a **workspace landing** — a polished **artifact pipeline** of cards — instead of dropping the user
straight into the spec builder. Ship the **Spec** card (functional) plus **Design** and **Breakdown** as **disabled
placeholders**. Remove the spec's status from the **feature card**.

## Current state (verified)

- `web/features/features/FeaturePage.tsx` — binary: `spec === null` → a `Create spec` `EmptyState`; else renders
  `<SpecWorkspace>` directly. Route `/applications/:appUuid/features/:featureId`.
- `FeaturesTab.tsx › FeatureCard` — renders `feature.spec_status` as the card `Badge` (or "No spec"). `FeatureSummary` carries
  `spec_status`.
- `useFeature` returns `{ feature, spec }`; `featuresApi.artifactUrl(featureId, theme, bust)` serves `spec.html` **with** the
  Lavish SDK injected.

## Changes

### Routing (split landing vs builder)
- `/applications/:appUuid/features/:featureId` → the **workspace landing** (new).
- `/applications/:appUuid/features/:featureId/spec` → the **spec builder** (the current `SpecWorkspace`, re-laid-out in 21-03).
- `router.tsx` gains the nested `spec` route; the landing links **Edit** → `…/spec`.

### Feature card (item 1/3)
- **Remove** the `spec_status` badge (and the "No spec" badge) from `FeatureCard`. Show **no status** for now (feature-level
  status is a later phase). Keep name, description, updated-time. (Backend `spec_status` may remain on the payload, unused by UI.)

### The artifact pipeline (new components)
- `ArtifactPipeline` — a responsive row (stacks on small screens) of `ArtifactCard`s with subtle `border`-toned connectors,
  read left→right as ordered stages (① Spec, ② Design, ③ Breakdown).
- `ArtifactCard` variants (all from existing primitives — `Card`/`CardBody`/`Badge`/`Button` + tokens):
  - **active + present (Spec with a spec):** step index + icon, **status pill** (`specStatusTone`), one-line description, footer
    actions **Edit** (pencil → `…/spec`) and **View** (eye → read-only preview overlay).
  - **active + empty (Spec, no spec):** same frame, actions collapse to a single **Create spec** (primary) that calls
    `useCreateSpec` then routes to `…/spec` (so a fresh spec opens in the builder). No layout shift.
  - **placeholder (Design/Breakdown):** muted `surface`/`text-fg-subtle`, **dashed** border, **lock** glyph + neutral
    **"Coming soon"** chip, `aria-disabled`, non-interactive. Purpose-built, not a greyed active card.
- Sequential unlock-on-completion is **not** implemented here (ADR-044 defers it) — placeholders are simply disabled.

### Read-only preview (the eye)
- **View** opens a **full-screen read-only overlay** (`Dialog`, ~`inset-4`) rendering `spec.html` **without** annotation tools.
- Backend: the spec artifact route gains a **read-only mode** — e.g. `GET …/spec/artifact?annotate=0` serves the HTML **without
  injecting the Lavish `sdk.js`** (plain document). Default (annotate=1) is unchanged for the builder. `featuresApi` gets a
  `previewUrl(featureId, theme)` helper.

## Testing (Vitest)

- Landing renders the pipeline: Spec card active; Design/Breakdown disabled (`aria-disabled`, not clickable).
- No-spec Spec card shows **Create spec**; with a spec shows **Edit** + **View** + the status pill.
- **Edit** routes to `…/spec`; **View** opens the read-only overlay (iframe `src` has `annotate=0`, no SDK).
- `FeatureCard` no longer renders a status badge.
- Update the existing `features.test.tsx` navigation expectations (create-feature now lands on the workspace, not the builder).

## Definition of done

- The pipeline UX matches §9.1 of the umbrella; disabled cards look intentional (no stale styling).
- Preview is read-only (no annotation affordances); builder reachable only via **Edit**.
- Web gate green (lint/tsc/vitest) + `npm run build` + committed `web/static/`; backend `annotate=0` path tested.
