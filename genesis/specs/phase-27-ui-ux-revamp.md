# Phase 27 — UI/UX Revamp (umbrella)

> **Status:** ⭐ **COMPLETE — SHIPPED as genesis v0.53.0 (2026-08-24)** (all sub-phases 27-01..27-11 + user refinements; release `fba9a94`, tag `v0.53.0`, CI green #6641436/#6641437). · **Author:** Genesis agent · **Date:** 2026-08-21
> **Requested by (user, 2026-08-21):** *"The UI of the application is outdated and I don't want a dark background to be the primary style. I want a proper non-dark theme for the entire application, a very modern and improved user experience. Go through each page, understand its functionality, then think hard on UX and prepare updated wireframes; then create UI mockups for all revamped pages — very modern and future-looking (reference: https://github.com/mui). Once I review the mockups we implement, following all best practices. Treat this as a multi-phase spec: phase 1 research, phase 2 UX revamp, phase 3 UI mockups, the rest for implementation."*
>
> **Goal:** A ground-up **look-and-feel + UX modernization** of the entire Genesis web app — moving from the current **dark-default** aesthetic to a **light-first, modern, "future-looking"** design language (MUI/Material-3 as the visual north star), with **every page audited, re-thought for UX, wireframed, and hi-fi mocked** before a **standards-driven, phased implementation**. **No product/behavioural scope change** — same features, same data, same routes; this is presentation + interaction + information-architecture, not new capability.
> **Repos:** **genesis only** (the SPA lives in `genesis/web`; ships as a committed `web/static` bundle → a genesis release per phase that touches code). genesis-core / genesis-workflows / kiro-agent-sdk / genesis-appian-parser **unchanged**. **No DB / API / schema change** (a pure frontend program; any API need that surfaces is a flag-and-confirm, not assumed).
> **Non-negotiable framing:** preserve every ADR (§5) and the current functional contracts. The web app is **token-driven already** (`web/src/styles/tokens.css` + Tailwind `var(--*)` mapping, with a `.theme-dark` default and an existing `.theme-light`) — the revamp **evolves that system**, it does not fork it lightly. The **MUI reference is an aesthetic/UX north star, not an automatic dependency**: whether to *adopt MUI as a component library* vs *evolve the existing Tailwind/token/shadcn-style primitives to a MUI-inspired language* is the **single biggest open decision**, resolved by the 27-01 research with the user (→ **ADR-055**), NOT pre-decided here. Accessibility (WCAG 2.1 AA, jest-axe green) and the existing gate discipline (tsc/eslint/vitest/build + stale-bundle guard) are hard floors.

---

## 0. TL;DR

Genesis has a solid **token-based theming foundation** but a **dark-default, somewhat dated** visual language and page-by-page UX that grew organically across Phases 7–26. Phase 27 modernizes the **entire** surface in a disciplined pipeline the user explicitly asked for:

1. **Research (27-01)** — walk **every page**, document what it does + how it's built, run a **UX/heuristic + accessibility audit**, inventory the design system (`shared/ui`, tokens, hardcoded-hex offenders), study the **MUI reference**, and **decide the design-language + theming direction** (light-first; MUI-adopt vs MUI-inspired-evolve) → **ADR-055**.
2. **UX revamp + wireframes (27-02)** — a re-thought **information architecture + navigation model**, key **user flows**, a **responsive strategy**, and **lo-fi wireframes for every page-group**.
3. **UI mockups (27-03)** — **hi-fi, light-first, modern/future-looking mockups for all revamped pages**, plus the finalized visual language (color/type/space/elevation/motion) as an implementable design-token spec. **← user review gate before any implementation.**
4. **Implementation (27-04..27-11)** — standards-driven build, foundation-first: **design system + light-first theming + theme toggle (27-04)** → **app shell & navigation (27-05)** → page-groups (**Applications/Features/Spec 27-06**, **Runs/Run-detail 27-07**, **Chat/Copilot 27-08**, **Documents/Memory 27-09**, **Catalog/Settings/Overview 27-10**) → **cross-cutting polish + a11y/responsive audit + dark-mode parity + release (27-11)**.

Each phase has crisp deliverables + acceptance gates; nothing implements until the mockups (27-03) are reviewed and approved.

---

## 1. Motivation & context

- The visual language is **dark-by-default** and, per the user, **"outdated"**. The ask is a **light-first, premium, modern** UI with materially **better UX** — not a re-skin of individual components in isolation.
- The app has accreted **16+ distinct page-surfaces** across Phases 7–26 (see §3) with **inconsistent** layout rhythm, density, empty/loading/error treatments, and navigation depth. A holistic pass (IA + flows + a shared modern component language) is warranted.
- **Good news from the codebase (verified 2026-08-21):** theming is **already a pure token swap** — `web/tailwind.config.ts` maps every color to `var(--*)`, `web/src/styles/tokens.css` defines `:root/.theme-dark` (default) **and a full `.theme-light`**, and only **one** file currently hardcodes dark hex (the Phase-26 `MemoryGraph` "constellation", v0.52.1). So *light-first* is achievable without a rewrite: refine the light palette to a modern spec, flip the default, add a persisted toggle, and reconcile the one hardcoded surface. The heavier lift is the **UX + component-language modernization**, not the theme mechanics.
- Reference: **MUI (github.com/mui)** → Material Design 3 sensibilities (elevation, rounded geometry, purposeful motion, strong type scale, dense-but-airy data surfaces, accessible components). Used as **inspiration**; the adopt-vs-evolve decision is ADR-055 (27-01).

**What already exists (build on, don't rebuild):**
- **Tokens + Tailwind mapping** (`styles/tokens.css`, `tailwind.config.ts`) — light/dark variable sets, radii, shadows (`e1..e3`), motion (`fast/base/slow`, `standard` easing), Inter/JetBrains-Mono fonts, `tailwindcss-animate` + `@tailwindcss/typography` + `@tailwindcss/forms`.
- **A shared primitive library** `web/src/shared/ui/` (button, card, badge, chip, dialog, tabs, tooltip, switch, input, skeleton, segmented, metric-card, health-dot, trend-chart, toast, file-drop, format, logo) + layout (`AppShell`, `Sidebar`, `SplitPane`, `Page`) + `shared/feedback/states`.
- **A `/dev` KitchenSink** design-system gallery (outside the shell) + `design-system.test.ts` — the natural home to build + prove the new component language.
- The **test/gate harness**: `tsc --noEmit`, `eslint .`, `vitest` (incl. **jest-axe** accessibility assertions), `npm run build`, and the **stale-bundle guard** (`web/static` must be rebuilt + committed).

---

## 2. Design principles (the north star for every phase)

1. **Light-first, not light-only.** Light is the **default** theme; a polished dark theme remains a first-class, user-toggleable, persisted option (token parity). No regression to dark-only surfaces.
2. **Modern & future-looking, but calm.** MUI/Material-3-inspired: clear elevation, generous spacing rhythm, a confident type scale, rounded geometry, tasteful motion — never noisy. Content and data legibility win over decoration.
3. **One design language, tokenized.** Every color/space/radius/shadow/motion value comes from a **token** (no hardcoded hex — enforced). Components are composed from a single modernized primitive set.
4. **UX before pixels.** IA, flows, and interaction patterns are decided (27-02) before hi-fi (27-03); pixels before code (27-03 before 27-04+).
5. **Accessibility is a floor, not a feature.** WCAG 2.1 AA contrast in *both* themes, full keyboard paths, visible focus, reduced-motion support, jest-axe green on every page.
6. **Responsive + dense-data-friendly.** Works from a laptop to a wide monitor; graph/table/spec surfaces stay usable at density.
7. **Standards-driven implementation.** Foundation-first, incremental per page-group, each behind green gates; no big-bang rewrite; behaviour-preserving (tests keep passing).

---

## 3. Scope — the page/surface inventory (audited in 27-01)

Grounded in `web/src/app/router.tsx` + `web/src/features/*` (verified 2026-08-21). Every surface below is in scope for audit → wireframe → mockup → implementation.

| # | Surface | Route(s) | Key components | Notes |
|---|---|---|---|---|
| 1 | **App shell / nav** | (all) | `shared/layout/{AppShell,Sidebar,Page,SplitPane}` | SIDEBAR nav; brand logo; the frame for everything. |
| 2 | **Applications (landing)** | `/applications` (`/`→redirect) | `applications/ApplicationsPage`, `AddApplicationDialog` | Primary landing (ADR Phase-24-02 Applications-first IA). |
| 3 | **Application detail** | `/applications/:appUuid` | `ApplicationDetail`, `business-map/*`, `FeaturesTab`, `library/BusinessArtifactsTab` | Tabs: overview + business map (React Flow) + features + artifacts. |
| 4 | **Feature page** | `/applications/:appUuid/features/:featureId` | `features/FeaturePage`, `ArtifactPipeline`, `ActivityFeed` | Artifact pipeline (Spec/Design/Breakdown), activity feed. |
| 5 | **Spec builder** | `.../features/:featureId/spec` | `features/SpecBuilderPage`, `SpecWorkspace` | Full-width chat + full-screen annotatable preview. |
| 6 | **Chat** | `/chat`, `/chat/:sessionId` | `chat/{ChatPage,ChatThread,Composer,SessionList,cards,LaunchDialog,SessionOutputs}` | Kiro/ACP parity toolbar, commands palette, images. |
| 7 | **Runs (list)** | `/runs` | `runs/RunsPage` | Run history/table. |
| 8 | **Run detail** | `/runs/:runId` (+ `/node/:nodeId`, `/docs/:docName`) | `run-detail/{RunDetailPage,graph/*,components/*}`, HITL, conversation, node-states | Graph canvas + node inspector + HITL + documents. |
| 9 | **Catalog** | `/catalog`, `/catalog/skills` | `catalog/{CatalogPage,WorkflowsTab,skills/*}` | Workflows | Skills segmented. |
| 10 | **Workflow detail** | `/catalog/:workflowId` | `catalog/WorkflowDetail` | Workflow metadata + launch entry. |
| 11 | **Launch form** | `/catalog/:workflowId/launch` | `catalog/{LaunchForm,launch-schema}` | Dynamic run-launch form. |
| 12 | **Documents library** | `/documents` | `library/{LibraryPage,DocumentTable,AddDocumentDialog}` | Document list + add. |
| 13 | **Document viewer** | `/documents/:id` | `library/{DocumentDetailPage,SpreadsheetView}`, `documents/renderers/*` | Auto-selected renderer (Rendered/Sheets/Source). |
| 14 | **Memory workspace** | `/memory` | `memory/{MemoryWorkspace,MemoryGraph,MemoryList,MemoryInspector,ReviewQueue}` | Graph (constellation, v0.52.1 — **hardcoded dark**, needs light reconciliation)/list/inspector/review. |
| 15 | **Settings** | `/settings`, `/settings/:tab[/:id]` | `settings/{SettingsPage,components/*}` | Overview, Catalog, Environments, MCP, CLI, Copilot, General/Kiro sign-in. |
| 16 | **Overview / metrics** | (in Settings; `OverviewPage` deep-link) | `overview/OverviewPage`, `metric-card`, `trend-chart` | Metrics/observability surface. |
| 17 | **System banners** | (in shell) | `system/{UpdateBanner,PreflightChecklist}` | Update + preflight UX. |
| 18 | **Design-system gallery** | `/dev` (outside shell) | `dev/KitchenSink`, `shared/ui/*` | Where the new component language is built + proven. |
| — | Not-found / empty / loading / error | (all) | `shared/feedback/states`, `app/error-boundary`, `LoadingScreen`, boot splash | Cross-cutting states to modernize. |

---

## 4. Phase breakdown

> **Pipeline gates:** 27-01 → **27-02 → 27-03 are review-gated with the user** (research decision, then wireframes, then mockups). **No implementation (27-04+) begins until 27-03 mockups are approved.**

### Research & design-decision
- **27-01 — Research & functional audit + design-language decision.** Per-page functional inventory (what each does, data sources, key components), a UX heuristic + a11y audit (Nielsen heuristics + WCAG AA baseline via jest-axe/contrast), a design-system inventory (`shared/ui`, tokens, hardcoded-hex offenders, motion/typography), a MUI reference study, and **the decision: light-first palette direction + MUI-adopt-vs-evolve → ADR-055 (Proposed→Accepted with the user).** *Deliverable: `27-01` doc + an audit appendix; no code.*

### UX revamp
- **27-02 — UX revamp & wireframes.** A revamped **information architecture + navigation model** (sidebar vs top-bar vs hybrid; breadcrumbs; global search / command palette), the **core user flows** (onboard app → author feature/spec → launch run → monitor run → curate memory/docs), a **responsive + density strategy**, interaction patterns (empty/loading/error/skeleton, toasts, dialogs, tables, split-panes), and **lo-fi wireframes for every page-group** in §3. *Deliverable: `27-02` doc + wireframe set. Review gate.*

### UI mockups
- **27-03 — Hi-fi UI mockups.** **Modern, future-looking, light-first mockups for all revamped pages**, the finalized **visual language** (color roles, type scale, spacing/grid, elevation, iconography, motion) expressed as an **implementable token + component spec**, dark-theme parity notes, and a **redlined component map** (which `shared/ui` primitive renders each mockup element). *Deliverable: `27-03` doc + mockups (format decided in 27-01 — see §6). **User review + approval gate → unlocks implementation.***

### Implementation (standards-driven, foundation-first)
- **27-04 — Design-system foundation + light-first theming.** Implement the finalized tokens (light default + dark parity), a **persisted theme toggle** (default flip from dark→light), the modernized `shared/ui` primitive set + layout primitives, type/space/elevation/motion scales, and refresh the `/dev` KitchenSink gallery as the living style guide. *Gate: `/dev` gallery renders all primitives in both themes; `design-system.test` + jest-axe green.*
- **27-05 — App shell & navigation.** Rebuild `AppShell`/`Sidebar` (+ top bar/breadcrumbs/command-palette/global states) to the new IA. *Gate: all routes reachable; a11y green; shell responsive.*
- **27-06 — Applications, Application Detail, Features & Spec Builder.** The core SDLC authoring surface (incl. business-map + artifact pipeline + annotatable spec preview).
- **27-07 — Runs & Run Detail.** Run list + run-detail graph/node-inspector/HITL/conversation/documents.
- **27-08 — Chat & Copilot.** Chat thread, composer/commands, session list, cards, launch dialog.
- **27-09 — Documents Library & viewer + Memory workspace.** Library + auto-renderer viewer + memory graph/list/inspector/review — **incl. reconciling the v0.52.1 constellation to be token-driven / light-theme-aware** (retire the hardcoded dark hex or gate it behind a themed variant).
- **27-10 — Catalog, Settings & Overview/metrics.** Workflows/Skills catalog + workflow detail + launch form + the multi-tab Settings + Overview metrics.
- **27-11 — Cross-cutting polish, responsive + a11y audit, dark-mode parity, docs & release.** Full empty/loading/error pass, responsive sweep, jest-axe on every page, dark-mode parity verification, doc updates, and the **release** (bump + tag + CI, per §5) — likely a minor bump (e.g. **v0.53.0**) given the breadth, decided at release time.

> Implementation page-groups (27-06..27-10) are independently shippable behind gates and may each ship as their own genesis release, or be batched — sequencing decided after 27-03. Each ships with rebuilt+committed `web/static`.

---

## 5. Release & gate strategy

- **Frontend program** → every implementation phase that changes `web/src` rebuilds + commits `web/static` (stale-bundle guard) and ships a **genesis release** (bump `pyproject` + FastAPI version, commit, tag, CI green) per `bible/05`. Research/UX/mockup phases (27-01..27-03) are **docs-only** (project-tracker) — no genesis release.
- **Per-phase gates:** `cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run build`, `git diff --quiet -- web/static` after rebuild, and **jest-axe green** on touched pages. genesis pytest unaffected (no Python change expected) but re-confirmed if any `.py` is touched.
- **No push/tag without the user's explicit go-ahead** (git-safety); commit locally, present the release plan, pause.
- **Behaviour preservation:** existing feature tests must keep passing; where a component is restructured, its tests are updated in the same phase, never deleted to go green.

## 6. Open decisions (resolved in 27-01, with the user)

1. **MUI adopt vs evolve (ADR-055).** Adopt `@mui/material` as the component library (large migration; strong OOTB Material-3 + a11y; heavier bundle; diverges from the current Tailwind/token system) **vs** evolve the existing Tailwind + token + shadcn-style primitives to a MUI-*inspired* language (lower risk; keeps the proven token/gate system; more bespoke work). **Recommendation to validate:** *evolve* unless the user wants literal Material components — but this is the user's call. *This is the pivotal fork; everything downstream depends on it.*
2. **Mockup medium.** Where do hi-fi mockups live so the user can review them: **coded mockups in the `/dev` KitchenSink** (real, themeable, closest to implementation — recommended) vs static images/Figma-style exports vs a standalone static HTML mock set. *Coded-in-`/dev` keeps a single source of truth and doubles as the 27-04 foundation.*
3. **Theme default & toggle mechanics.** Confirm light as the hard default + persistence (localStorage + `color-scheme`) + optional system-preference following.
4. **Navigation model.** Keep SIDEBAR vs move to a top-bar or hybrid; whether to add a global command palette / search (decided in 27-02, framed in 27-01).
5. **Scope guard.** Confirm *no behavioural/feature changes* (presentation + IA only); any functional improvement discovered during the audit is filed to backlog, not folded in silently.

## 7. Non-goals

- No new product features, API endpoints, DB/schema changes, or workflow changes (frontend-only; any need is flagged).
- Not adopting a new framework (stays React + Vite + Tailwind + the token system; MUI is the only library question, per ADR-055).
- Not a rewrite of app logic/hooks/data layer (`features/*/hooks.ts`, `lib/api/*`, query keys) — presentation/IA layer only, minimizing churn to data code.
- No multi-user / auth / theming-per-user-server work (stays local single-user, ADR-026).

## 8. Risks & mitigations

- **Scope explosion (16+ surfaces).** → Foundation-first + strict page-group phasing + review gates; behaviour-preserving; each phase independently shippable.
- **MUI-adoption regret.** → Decide *before* any implementation (ADR-055, 27-01); prototype the pivotal primitives in `/dev` for both options if needed.
- **Dark-theme regressions when flipping default.** → Token parity enforced; jest-axe + a manual both-theme sweep in 27-04 and 27-11; the one hardcoded surface (constellation) explicitly reconciled in 27-09.
- **Test churn.** → Prefer semantic/role queries in tests; update component tests within the same phase; keep `data-testid`s stable.
- **Bundle bloat** (esp. if MUI adopted). → Track bundle size per phase; code-split heavy surfaces (graph/spec/mockups) as today.

## 9. Acceptance (phase-level)

- 27-01: every §3 surface documented + audited; ADR-055 decided with the user; light-palette direction chosen.
- 27-02: revamped IA + flows + responsive strategy + lo-fi wireframes for all page-groups, reviewed.
- 27-03: hi-fi light-first mockups for all pages + finalized token/component spec, **approved by the user**.
- 27-04..27-11: each page-group implemented to the mockups, light default + dark parity, all gates + jest-axe green, `web/static` rebuilt, released per §5; bible/tracker/progress updated.

---

*Sub-specs: `specs/phase-27-ui-ux-revamp/27-01..27-11`. As-built: `progress/phase-27-ui-ux-revamp.md`. ADR: `reference/decision-log.md` ADR-055 (Proposed → Accepted in 27-01).*
