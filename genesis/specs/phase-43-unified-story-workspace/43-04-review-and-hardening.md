# 43-04 — Review & hardening

> **Phase 43 · sub-phase 04** — independent review + consistency/accessibility hardening + legacy cleanup.
> Depends on 43-01..43-03.

## Goal

An independent review of the unified Story Workspace (SHIP / SHIP-WITH-MUST-FIX), then apply fixes and a
consistency pass, so the page is production-quality and no legacy surface is left dangling.

## Do

1. **Independent review (sub-agent as auditor):** does opening a story from every entry point (Stories tab, each board lane, a legacy-route redirect) land on the same page with the correct default tab and only the relevant documents? Is the design correctly read-only after implementation? Are all documents clearly type-labelled? Is anything from the old surfaces (drawer, `StoryCardPage`, `StoryDetailPage`) still reachable or duplicated?
2. **Consistency pass:** design tokens (no raw palette), reused `shared/ui` primitives, consistent doc chrome + type labels, breadcrumbs, back-navigation; the page matches the app's look-and-feel (ADR-055) and the library document viewer conventions.
3. **Accessibility:** jest-axe green on the Story Workspace + each tab (excluding the sandboxed report iframe body, per the existing impl-review test); keyboard tab navigation; labelled controls.
4. **Legacy cleanup:** `StoryDetailPage` → redirect or removed; `StoryCardPage` → the design-chat target only (or removed with its route redirected); `BoardCardDrawer` deleted; `StoryDesignWorkspace`/`ImplementationReviewWorkspace` either reused by the tabs or the chat target — no dead components, no dead routes. Update any tests that referenced the removed surfaces.
5. **Backend:** confirm the consolidated endpoint + relaxed artifact reads are covered; no lane gate regressions; ruff clean.
6. **Regression tests** for anything the review flags; ensure the board views + the design chat still work end-to-end.

## Done when

Review = SHIP (MUST-FIX applied); genesis pytest + ruff green; web tsc/eslint(0)/vitest(+axe) green + `web/static` rebuilt/committed; no dead routes/components; the enhancement behaves consistently from every entry point.
