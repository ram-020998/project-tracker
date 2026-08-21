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

## Next
- **27-01 — Research & functional audit** (docs-only): per-page functional inventory + UX/a11y audit + design-system/hardcoded-hex inventory + MUI study → **ADR-055 decided with the user**. Then 27-02 wireframes.
