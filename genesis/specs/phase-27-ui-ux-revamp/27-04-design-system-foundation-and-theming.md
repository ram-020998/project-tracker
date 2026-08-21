# 27-04 — Design-system foundation + light-first theming

> **Phase 27 (UI/UX Revamp) · sub-phase 04 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-03 mockups APPROVED**.
> **Status:** 📋 DRAFT · **Type:** genesis frontend (ships a release) · **First implementation phase — foundation everything else builds on.**

## Objective
Implement the finalized design language as the **platform**: the modernized **light-first token set** (with dark parity), a **persisted theme toggle** (default flipped dark→light), the **modernized `shared/ui` + layout primitives**, the type/space/elevation/motion scales, and a refreshed **`/dev` KitchenSink** as the living style guide — all behaviour-neutral to feature pages.

## Deliverables
- **`web/src/styles/tokens.css`** — refined `.theme-light` (new default) + `.theme-dark` parity, per the 27-03 token spec (color roles, radii, shadows, focus), WCAG AA.
- **Default theme flip + toggle** — light is the hard default; a persisted toggle (localStorage + `color-scheme`, optional system-preference follow); applied at `<html>` (`RootLayout`/boot). No FOUC.
- **Modernized primitives** in `shared/ui/*` (button, card, badge, chip, dialog, tabs, tooltip, switch, input, skeleton, segmented, metric-card, health-dot, trend-chart, toast, file-drop) + layout (`AppShell`/`Sidebar`/`Page`/`SplitPane`) refreshed to the new language — **same prop APIs where possible** to minimize page churn.
- **Type/space/elevation/motion** scales wired via `tailwind.config.ts` + tokens.
- **`/dev` KitchenSink** refreshed to render every primitive + token in both themes (the style guide); `design-system.test` updated.

## Approach
1. Land tokens + toggle first; verify both themes render across existing pages (no visual break beyond intended).
2. Modernize primitives incrementally, keeping prop contracts stable; update snapshots/tests per component.
3. Prove everything in `/dev`; run jest-axe on the gallery for both themes.

## Acceptance / gates
- Light is the default; toggle persists; both themes pass WCAG AA contrast; no FOUC.
- `/dev` renders all primitives in both themes; `design-system.test` + jest-axe green.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5 (bump/tag/CI on the user's go-ahead).

## Out of scope
Per-page layout redesign (that's 27-05..27-10) — this phase changes the *primitives + theme*, not page composition, beyond what's needed to keep pages rendering.
