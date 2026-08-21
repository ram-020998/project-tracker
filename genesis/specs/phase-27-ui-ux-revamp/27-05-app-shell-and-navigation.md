# 27-05 — App shell & navigation

> **Phase 27 (UI/UX Revamp) · sub-phase 05 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04**.
> **Status:** 📋 DRAFT · **Type:** genesis frontend (ships a release).

## Objective
Rebuild the application **frame + navigation** to the approved IA/mockups: `AppShell`, `Sidebar` (and/or top-bar/hybrid per ADR-055), context header + breadcrumbs, optional **command palette / global search**, theme toggle placement, and the system banners (`UpdateBanner`, `PreflightChecklist`) — the consistent chrome every page renders inside.

## Deliverables
- Modernized `shared/layout/{AppShell,Sidebar,Page,SplitPane}` per 27-03; new nav model (regions: brand, primary nav, context header/breadcrumbs, content, right rails).
- Command palette / global search (if adopted in 27-02), quick-actions, keyboard shortcuts.
- Theme toggle surfaced in the shell; `system/{UpdateBanner,PreflightChecklist}` restyled + placed.
- Boot splash / `LoadingScreen` / not-found aligned to the new language.

## Acceptance / gates
- All routes reachable + visually consistent inside the new shell; breadcrumbs correct per route.
- Keyboard-navigable; visible focus; jest-axe green on the shell + a sample page; responsive (nav collapse).
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
Inner page content redesign (subsequent page-group phases) beyond wiring pages into the new shell.
