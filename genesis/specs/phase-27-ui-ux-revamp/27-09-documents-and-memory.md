# 27-09 — Documents Library & viewer + Memory workspace

> **Phase 27 (UI/UX Revamp) · sub-phase 09 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04, 27-05**.
> **Status:** ⭐ **RELEASED — genesis v0.53.0 (2026-08-24)** (genesis `9b2e733`; independent review = SHIP; the `/memory` constellation is now token-driven — the last hardcoded-dark surface is resolved).

## Objective
Redesign the knowledge surfaces to the approved mockups, behaviour-preserving: the **Documents Library** + auto-renderer **viewer**, and the **Memory workspace** (graph/list/inspector/review) — **including reconciling the v0.52.1 memory "constellation" to be token-driven / light-theme-aware** (it currently hardcodes dark cosmic hex — the only hardcoded-hex offender).

## Scope (components)
`library/{LibraryPage,DocumentTable,AddDocumentDialog,DocumentDetailPage,SpreadsheetView,BusinessArtifactsTab}`, `documents/renderers/*`, `memory/{MemoryWorkspace,MemoryGraph,MemoryList,MemoryInspector,ReviewQueue}`.

## Deliverables
- Documents library: modern list/table + add-document flow; the document viewer (Rendered / Sheets / Source auto-select) re-themed; spreadsheet grid restyled.
- Memory workspace: list/inspector/review-queue to the new language.
- **Constellation reconciliation:** replace hardcoded hex in `MemoryGraph.tsx` with **theme tokens** (or a deliberately-themed variant that has a *light* mode) so it fits the light-first app — retaining the d3-force interactions (hover-highlight, drag-pin, zoom/pan). Keep `graph.ts` helpers/tests.

## Acceptance / gates
- Document viewing (all renderer modes), add-doc, and memory graph/list/inspector/review all work; library + memory tests updated + green (incl. the jest-axe empty-graph path).
- **No hardcoded hex remains** in the memory graph (token-driven); light default + dark parity; jest-axe green; responsive.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
No change to document parsing/sync or memory data/API (presentation only). The d3-force *simulation* stays; only its theming/visuals change.
