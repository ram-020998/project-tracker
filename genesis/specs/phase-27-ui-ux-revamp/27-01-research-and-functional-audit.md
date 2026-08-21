# 27-01 — Research & functional audit + design-language decision

> **Phase 27 (UI/UX Revamp) · sub-phase 01 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`.
> **Status:** ✅ **COMPLETE (2026-08-21)** — findings: `27-01-findings.md`; **ADR-055 Accepted**. · **Type:** research/docs-only (no genesis code, no release) · **Gate:** ✅ reviewed with the user → 27-02 unblocked.

## Objective
Build the factual + decision foundation for the revamp: **understand every page** (function + implementation), **audit UX + accessibility**, **inventory the design system**, **study the MUI reference**, and **decide the design-language + theming direction** (light-first; MUI adopt-vs-evolve) as **ADR-055**.

## Inputs (verified 2026-08-21)
- `web/src/app/router.tsx` (routes) + `web/src/features/*` (feature code) + `web/src/shared/{ui,layout,feedback}` (primitives).
- `web/tailwind.config.ts` + `web/src/styles/{tokens.css,index.css}` (the token system — light/dark sets already exist).
- `web/src/dev/KitchenSink.tsx` + `shared/ui/design-system.test.tsx` (the design-system gallery).
- Reference: **https://github.com/mui** (Material UI / Material Design 3).

## Deliverables
1. **Per-page functional inventory** (one entry per §3 surface): purpose, primary user + job-to-be-done, data sources (hooks/API/query-keys), key components, current layout, notable interactions, and known pain points. → appendix `27-01-audit.md` (or inline table).
2. **UX heuristic audit** — Nielsen's 10 heuristics per page-group; consistency issues (density, spacing rhythm, navigation depth, empty/loading/error treatments); top prioritized problems.
3. **Accessibility baseline** — current jest-axe coverage, contrast check of the existing light + dark token sets (WCAG AA), keyboard/focus gaps.
4. **Design-system inventory** — catalog `shared/ui` primitives (props/variants), token coverage, **hardcoded-hex offenders** (grep; known: `memory/MemoryGraph.tsx` v0.52.1), motion/typography usage, and gaps vs a modern language.
5. **MUI reference study** — what to borrow (elevation, type scale, motion, data-density patterns, component set) and the concrete **adopt-vs-evolve tradeoff** (bundle, a11y, migration cost, token-system fit).
6. **ADR-055 (Proposed → Accepted with the user)** — the design-language + theming direction: light-first default; MUI adopt vs evolve; navigation-model intent; mockup medium (§6 umbrella).

## Approach
1. Read each feature's page + primary components + `hooks.ts`; record function + data flow (do **not** edit code).
2. Run the existing web test suite + note jest-axe coverage; compute token contrast ratios for light + dark.
3. `grep` for hardcoded colors / non-token styles; list offenders for later reconciliation.
4. Summarize MUI/Material-3 patterns relevant to Genesis' dense, data-heavy surfaces (graphs, tables, spec/chat).
5. Draft ADR-055 with a clear recommendation (**evolve the token/Tailwind system to a MUI-inspired light-first language**, unless the user wants literal Material components) + the open-decision answers from §6; review with the user.

## Acceptance
- Every §3 surface has a functional-inventory entry + at least the top UX/a11y issues noted.
- Design-system + hardcoded-hex inventory complete.
- ADR-055 decided **with the user** (light-first confirmed; adopt-vs-evolve chosen; mockup medium + nav intent set) — this unblocks 27-02.

## Out of scope
No code changes, no mockups (that's 27-03), no final wireframes (that's 27-02). Any functional bug/improvement found is filed to `specs/backlog/` or `specs/bugs/`, not fixed here.
