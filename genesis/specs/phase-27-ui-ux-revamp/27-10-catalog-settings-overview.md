# 27-10 — Catalog, Settings & Overview/metrics

> **Phase 27 (UI/UX Revamp) · sub-phase 10 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04, 27-05**.
> **Status:** ✅ **BUILT (unreleased) — 2026-08-24** (genesis `bf41220`, LOCAL/untagged; independent review = SHIP).

## Objective
Redesign the remaining surfaces to the approved mockups, behaviour-preserving: the **Catalog** (Workflows | Skills), **Workflow Detail**, the **Launch Form**, the multi-tab **Settings** (Overview, Catalog, Environments, MCP, CLI, Copilot, General/Kiro), and the **Overview/metrics** surface.

## Scope (components)
`catalog/{CatalogPage,WorkflowsTab,WorkflowDetail,LaunchForm,launch-schema,skills/*,components/*}`, `settings/{SettingsPage,components/*}`, `overview/OverviewPage`, `metric-card`, `trend-chart`.

## Deliverables
- Catalog: modern Workflows/Skills browse + Workflow Detail + dynamic Launch Form (schema-driven) re-themed; forms use the modernized `@tailwindcss/forms` primitives.
- Settings: consistent tabbed settings layout across all tabs (Environments/MCP/CLI/Copilot/General + Kiro sign-in); dense config forms legible.
- Overview/metrics: modern metric cards + trend charts to the new language (light-first chart palette).

## Acceptance / gates
- Launch a workflow (dynamic form), edit all settings tabs, Kiro sign-in, and view metrics all work; catalog/settings/overview/kiro tests updated + green.
- Light default + dark parity (incl. chart colors); jest-axe green; responsive.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
No change to launch schema semantics, settings persistence, or metrics/API (presentation only).
