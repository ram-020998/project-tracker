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

## 27-03 — Hi-fi UI mockups 📋 DELIVERED — FOR REVIEW (2026-08-21)
- **Deliverable:** coded, light-first mockups at **`/dev/mockups`** (`web/src/dev/mockups/{Mockups.tsx,theme-next.css}`) + the finalized `specs/phase-27-ui-ux-revamp/27-03-design-language.md` (token/type/elevation/motion spec + component redline). Rendered in a **scoped `.theme-next`** preview palette so the new language shows **without** changing the live default (that flip is 27-04).
- **Screens:** new shell (expanded labelled sidebar + slim top app bar: breadcrumbs + ⌘K + theme toggle) + all page-groups — Applications (KPI strip), App detail, Runs, Run detail (HITL), Spec, Chat, Memory (token-driven light-aware constellation), Catalog, Documents, Settings + a Design-language panel.
- **Palette:** light-first; indigo primary `#4f46e5` + violet accent; `fg-subtle` fixed to AA; light-tuned soft elevation. Reflects ADR-055 (evolve, no `@mui/material`) + D1/D2/D3.
- **Gates:** tsc/eslint/vitest **191**/build green; `web/static` rebuilt. genesis commit **`7c7ffe0` LOCAL (unpushed, not tagged)** — release deferred to 27-04.

## 27-03 — Hi-fi UI mockups ✅ APPROVED (2026-08-21)
- **Outcome:** the user approved the `/dev/mockups` look after the orange/stone + Poppins iteration. Genesis mockup commits **pushed to master** (`7c7ffe0`→`4a979da`→`16c2b8a`); **no tag/release** (the /dev preview ships with the 27-04 foundation).
- **Final language:** primary **`#C2410C`** (burnt orange) + secondary **`#57534E`** (stone), warm-gray canvas, **Poppins**, differentiated elevated white side-nav, glassy top bar, Home-rooted breadcrumb (drops current page), soft warm elevation, generous radii, and motion (screen fade-up, nav-icon hover, sparkline draw-in, bar-grow, animated brand gradient, live-pulse). Spec: `27-03-design-language.md` (§1a = final).

## 27-04 — Design-system foundation + light-first theming ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `286528c` (LOCAL on master, unpushed/untagged — awaiting release go-ahead).
- **As built:** promoted the approved Indigo·Slate language into the **global** token system as the **default**:
  - `styles/tokens.css` — light-first (`:root == .theme-light`) + refreshed dark parity; **two brand knobs at `:root`** (`--brand #4f46e5`, `--brand-secondary #475569`) are the single source of truth — both themes + all gradients/glows/focus derive from them via `color-mix()`; per-theme `--shadow-e1..e3`; `fg-subtle` meets WCAG AA in both.
  - `tailwind.config.ts` — `boxShadow e1..e3 → var(--shadow-*)`; `sans` adds **Poppins**; new `secondary` token; radii lg14/xl18/2xl22.
  - **Poppins self-hosted** via `@fontsource/poppins@5.3.0` (latin subset, weights 400/500/600/700) — offline-safe (ADR-026), no CDN.
  - **Default flipped dark→light**: `stores/theme.ts` default light; `index.html` `html.theme-light` + **no-FOUC inline theme-init script** (also sets `theme-color`) + light boot splash with `.theme-dark` override; brand gradient (favicon/splash/`logo.tsx`) → indigo.
  - `styles/index.css` — reusable reduced-motion-safe `.anim-fade-up` + `.hover-lift`; KitchenSink "How to re-theme" note.
  - Primitives **not** restructured — token/config changes refresh them (same prop APIs, minimal churn).
- **Quality:** tsc/eslint(0 err)/**vitest 191**/build green; **zero hardcoded brand hex** in components; **independent sub-agent review = SHIP** (no blockers; AA verified numerically both themes); its polish items applied (latin-only fonts, dynamic theme-color, comments).
- **Known temporary:** the `/memory` d3 **constellation is still hardcoded dark** (a dark panel in the now-light app) → reconciled in **27-09**.

## Next
- **Release 27-04 as genesis v0.53.0** (on the user's go-ahead): bump `pyproject` + FastAPI app version, commit, tag, push master + tag, verify CI green (incl. the frontend stale-bundle guard). Then **27-05 — App shell & navigation** (the first structural UX phase: differentiated sidebar, top app bar, breadcrumbs, ⌘K, states).
