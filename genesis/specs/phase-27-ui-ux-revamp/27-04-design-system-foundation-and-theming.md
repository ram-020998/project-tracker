# 27-04 — Design-system foundation + light-first theming

> **Phase 27 (UI/UX Revamp) · sub-phase 04 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-03 mockups APPROVED**.
> **Status:** 📋 DRAFT · **Type:** genesis frontend (ships a release) · **First implementation phase — foundation everything else builds on.**

## Objective
Implement the finalized design language as the **platform**: the modernized **light-first token set** (with dark parity), a **persisted theme toggle** (default flipped dark→light), the **modernized `shared/ui` + layout primitives**, the type/space/elevation/motion scales, and a refreshed **`/dev` KitchenSink** as the living style guide — all behaviour-neutral to feature pages.

## Deliverables
- **`web/src/styles/tokens.css`** — promote the approved **Indigo · Slate** language: refined `.theme-light` (new default) + `.theme-dark` parity, per the 27-03 token spec (color roles, radii, shadows, focus), WCAG AA.
- **⭐ Single-source, easily-configurable theming (user requirement, 2026-08-21).** A **brand token block** is the *one place* to change the theme — set `--primary` / `--primary-fg` / `--secondary` and everything follows:
  - Every color flows through CSS variables → Tailwind `var(--*)` → components; **no hardcoded hex anywhere** (the 27-01 audit's 4 offenders are reconciled; a lint/grep guard keeps it that way).
  - **Derived values** (brand gradient `--grad-brand`, soft/glow variants, hover tints) are computed from `--primary` via `color-mix()` — so changing the single `--primary` re-themes gradients + accents too (proven in the mockup).
  - Semantic tokens (success/warning/danger) remain separate from brand.
  - Documented: a short "How to re-theme Genesis" note (edit these N variables in `tokens.css`) in the design-system docs / `/dev` KitchenSink.
- **Default theme flip + toggle** — light is the hard default; a persisted toggle (localStorage + `color-scheme`, optional system-preference follow); applied at `<html>` (`RootLayout`/boot). No FOUC.
- **Modernized primitives** in `shared/ui/*` (button, card, badge, chip, dialog, tabs, tooltip, switch, input, skeleton, segmented, metric-card, health-dot, trend-chart, toast, file-drop) + layout (`AppShell`/`Sidebar`/`Page`/`SplitPane`) refreshed to the new language — **same prop APIs where possible** to minimize page churn.
- **Type/space/elevation/motion** scales wired via `tailwind.config.ts` + tokens; add **Poppins** to the font stack; port the motion utilities (fade-up, hover-lift, draw-in, live-pulse) reduced-motion-safe.
- **`/dev` KitchenSink** refreshed to render every primitive + token in both themes (the style guide); `design-system.test` updated.

## Approach
1. Land tokens + toggle first; verify both themes render across existing pages (no visual break beyond intended).
2. Modernize primitives incrementally, keeping prop contracts stable; update snapshots/tests per component.
3. Prove everything in `/dev`; run jest-axe on the gallery for both themes.

## Acceptance / gates
- Light is the default; toggle persists; both themes pass WCAG AA contrast; no FOUC.
- **Configurability proof:** changing `--primary` (and/or `--secondary`) in `tokens.css` re-themes the whole app — buttons, links, active nav, gradients, glows, focus rings — with **no other edits**; a grep confirms zero hardcoded brand hex in `web/src`.
- `/dev` renders all primitives in both themes; `design-system.test` + jest-axe green.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5 (bump/tag/CI on the user's go-ahead).

## Out of scope
Per-page layout redesign (that's 27-05..27-10) — this phase changes the *primitives + theme*, not page composition, beyond what's needed to keep pages rendering.
