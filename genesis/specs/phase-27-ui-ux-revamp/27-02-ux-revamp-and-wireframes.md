# 27-02 — UX revamp & wireframes

> **Phase 27 (UI/UX Revamp) · sub-phase 02 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-01** (ADR-055 decided).
> **Status:** 📋 DRAFT · **Type:** UX/docs-only (no genesis code, no release) · **Gate:** wireframe review with the user before 27-03.

## Objective
Turn the 27-01 findings into a **re-thought user experience**: a modern **information architecture + navigation model**, the **core end-to-end flows**, a **responsive + density strategy**, standardized **interaction patterns**, and **lo-fi wireframes for every page-group** — the structural blueprint the hi-fi mockups (27-03) will paint.

## Inputs
27-01 functional inventory + UX/a11y audit + ADR-055 (design-language + nav intent). MUI/Material-3 layout patterns.

## Deliverables
1. **Information architecture** — the full nav tree + page hierarchy; primary vs secondary surfaces; where Overview/metrics, Settings tabs, and deep surfaces (business-map, run-detail, spec-builder, memory) sit; breadcrumb model.
2. **Navigation model** — sidebar / top-bar / hybrid decision (per ADR-055), global search + command palette (if adopted), quick-actions, and the shell regions (brand, nav, context header, content, right rails).
3. **Core user flows** (wireframed step sequences): (a) add + sync an Application; (b) author a Feature → build its Spec (chat + annotate) → advance the artifact pipeline; (c) launch a workflow/run from Catalog; (d) monitor a Run (graph → node → HITL → docs); (e) curate Memory + Documents; (f) configure Settings/Environments.
4. **Responsive + density strategy** — breakpoints, how dense-data surfaces (tables, graphs, spec/chat split-panes) adapt from laptop → wide monitor; collapse/expand behavior of nav + rails.
5. **Interaction pattern library (lo-fi)** — canonical empty / loading (skeleton) / error / not-found states, toasts, dialogs/sheets, tables (sort/filter/paginate), tabs/segmented, split-panes, forms.
6. **Lo-fi wireframes for every page-group** in umbrella §3 (shell, applications, app-detail, feature/spec, chat, runs, run-detail, catalog, documents, memory, settings, overview).

## Approach
1. Fix IA + nav model first (everything hangs off it); validate against the core flows.
2. Wireframe the shell, then each page-group, reusing the interaction-pattern library for consistency.
3. Annotate each wireframe with intent (what changed vs today + why, tied to a 27-01 audit finding).
4. Keep it **lo-fi** (structure/hierarchy/flow) — no final color/type; those are 27-03.
5. Review the wireframe set with the user; iterate before mockups.

## Acceptance
- IA + nav model + responsive strategy documented and internally consistent with the core flows.
- A lo-fi wireframe exists for **every** page-group, each traceable to an audit finding.
- Reviewed + approved by the user → unblocks 27-03.

## Out of scope
No hi-fi visuals/tokens (27-03), no implementation. Behaviour-preserving: wireframes reflect existing features re-arranged, not new capability.
