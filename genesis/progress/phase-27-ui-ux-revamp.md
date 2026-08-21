# Phase 27 — UI/UX Revamp — progress (as-built)

> Running as-built record for Phase 27 (spec: `specs/phase-27-ui-ux-revamp.md` + `27-01..27-11`).
> **Status:** 📋 **PLANNING — specs authored; no code yet.** Repo when implementing: **genesis** only (frontend; ships `web/static` per phase). A pure UI/UX modernization (light-first, modern, MUI-inspired) — **no API/DB/behavioural change**.
> **Pipeline:** 27-01 research → 27-02 wireframes → 27-03 mockups (**user-review gates**) → 27-04 design-system/theming → 27-05 shell → 27-06..27-10 page-groups → 27-11 polish/a11y/release. **No implementation until the 27-03 mockups are approved.**

## Planning — 2026-08-21 (specs authored)
- **Requested by the user (2026-08-21):** revamp the app's look-and-feel + UX; **drop dark as the primary theme** → a proper **light/non-dark default**; **very modern, future-looking** UI + improved UX; reference **https://github.com/mui**; process = research → UX/wireframes → UI mockups → implementation; "very very standard and efficient."
- **Authored:** umbrella `specs/phase-27-ui-ux-revamp.md` + 11 sub-specs (`27-01..27-11`) + this progress doc. Roadmap `bible/08` §9 NEXT block + `tracker.md` §6 + AGENT_ONBOARDING ACTIVE handoff + **ADR-055 (Proposed)** in `reference/decision-log.md`.
- **Grounding (verified against real code, 2026-08-21):**
  - **16+ page-surfaces** enumerated from `web/src/app/router.tsx` + `web/src/features/*` (see umbrella §3).
  - **Theming is already token-driven** — `web/tailwind.config.ts` maps colors → `var(--*)`; `web/src/styles/tokens.css` has `:root/.theme-dark` (default) **and a full `.theme-light`**. So light-first ≈ refine the light palette + flip the default + add a persisted toggle + reconcile the **one** hardcoded-hex surface (`memory/MemoryGraph.tsx`, the v0.52.1 constellation).
  - Shared primitives live in `web/src/shared/{ui,layout,feedback}`; a `/dev` KitchenSink gallery already exists (the natural home for the new component language / coded mockups).
- **Pivotal open decision (→ ADR-055, decided in 27-01 with the user):** **adopt `@mui/material`** as the component library **vs evolve** the existing Tailwind/token/shadcn-style primitives to a **MUI-inspired** language. Recommendation to validate: *evolve* (keeps the proven token/gate system, lower risk) unless the user wants literal Material components.

## 27-01 — Research & functional audit ✅ COMPLETE (2026-08-21)
- **Deliverable:** `specs/phase-27-ui-ux-revamp/27-01-findings.md` — per-page functional inventory (16 surfaces), UX heuristic audit (prioritized), a11y baseline (15 jest-axe suites + gaps + a `fg-subtle` sub-AA contrast finding), design-system inventory (20+ primitives; **only 4 hardcoded-hex files**, all memory/logo), and the MUI adopt-vs-evolve study. Docs-only; no genesis code.
- **Key finding:** the "outdated" feel is **aesthetic + IA, not structural** — theming is already a pure token swap (`tokens.css` has a full `.theme-light`; the theme toggle already exists in Settings→General), so light-first is a palette-refine + default-flip + reconcile the one hardcoded surface (`MemoryGraph.tsx`), not a rewrite.
- **Decisions (ADR-055 Accepted with the user):** light-first (dark retained/toggleable) · **evolve** the Tailwind/token primitives to a MUI-inspired language (no `@mui/material`) · coded mockups in `/dev` · nav to gain expanded/hybrid + breadcrumbs + command palette (designed in 27-02) · presentation/IA only (no behavioural/API/DB change).

## 27-02 — UX revamp & wireframes 📋 DELIVERED — FOR REVIEW (2026-08-21)
- **Deliverable:** `specs/phase-27-ui-ux-revamp/27-02-wireframes.md` — revamped **IA** (Applications-first, Catalog promoted out of Settings), **navigation model + shell regions** (persistent labelled left sidebar + a re-introduced slim top app bar carrying breadcrumbs + ⌘K command palette/search + theme toggle + environment/update), **core flows** (A onboard app · B feature→spec→annotate · C launch→monitor run · D curate memory/docs · E settings), a **responsive + density strategy** (split-panes→tabs <1024; tab overflow menus; sticky-header tables), an **interaction-pattern library** (reusing `feedback/states`), and **lo-fi ASCII wireframes for all 16 surfaces** + the shell.
- **Open decisions for the user (wireframe gate):** **D1** promote Catalog to primary nav (revisits ADR-049) · **D2** add a compact KPI strip to Applications vs metrics-only-in-Settings · **D3** expanded-by-default nav. Recommendations given for each.
- Docs-only; no genesis code/release. **Behaviour-preserving** (existing features re-arranged, not changed).

## Next
- ⭐ **User review of 27-02** (wireframes + D1–D3). On approval → **27-03 — hi-fi coded mockups in `/dev`** (light-first) for every surface + the finalized token/type/elevation/motion spec + component redline. **No implementation until 27-03 is approved.**
