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

## 27-05 — App shell & navigation ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `cf8bfb8` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **As built** (behaviour-preserving; first structural UX phase):
  - `shared/layout/nav.ts` — single source of truth for primary nav (`PRIMARY_NAV`+`SETTINGS_NAV`); **Catalog promoted** to top level (revisits ADR-049). Shared by sidebar + palette.
  - `Sidebar.tsx` — rebuilt: **expanded + labelled** by default (collapsible icon-rail), **differentiated** elevated white panel vs the warm canvas, grouped, active = `bg-primary/10` + primary left-marker + `aria-current`, brand tile (`var(--grad-brand)`) + health/env.
  - `TopBar.tsx` — new **glassy** header (`bg-surface-1/70` + backdrop-blur): **breadcrumbs** (ancestors only — current page omitted), **⌘K search trigger**, one-click **theme toggle**, notifications.
  - `breadcrumbs.ts` — route-pattern trail (`matchPath` end:false, depth+specificity ordered, **dedupe by resolved pathname** so static beats param, current dropped); crumb-label zustand store + `useSetCrumb` (generic fallbacks, never raw ids).
  - `CommandPalette.tsx` (+ `command-palette-store.ts`) — global **⌘K/Ctrl-K** palette on the Radix Dialog primitive: fuzzy filter + arrow/enter listbox nav, Navigate + Actions (theme toggle); proper ARIA (`role=listbox>group>option`, `aria-activedescendant`, scroll-into-view, focus-trap + Esc).
  - `AppShell.tsx` — composes Sidebar + (TopBar + UpdateBanner + scrollable main) + right rail; palette mounted once; **expanded by default**.
- **Quality:** tsc/eslint(0 err)/**vitest 200** (+9 `shell.test.tsx`)/build green; token-driven both themes; no hardcoded hex. **Independent sub-agent review = SHIP**; all 3 SHOULD-FIX applied (breadcrumb `/catalog/skills` collision, palette listbox ARIA ownership + `aria-activedescendant`) + covered by new tests. System banners left token-driven (deeper polish → 27-11).

## 27-06 — Applications, Application Detail, Features & Spec Builder ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `a85dd83` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **As built** (behaviour-preserving; the core SDLC authoring surface, rebuilt to `/dev/mockups`):
  - `styles/index.css` — added reusable, **token-derived** `.grad-brand` / `.grad-brand-soft` / `.text-grad`
    (single-source: derive from the two `:root` brand knobs via `--grad-brand*`; no hardcoded hex; reduced-motion
    already neutralizes) + neutralized `animation-delay` under `prefers-reduced-motion` (no stagger flash) + refreshed
    the stale React-Flow override comment (the business-map is token-driven, both-theme parity).
  - **Applications** (`ApplicationsPage`) — grid cards get a **gradient brand tile**, `rounded-2xl`, `hover-lift`,
    staggered `anim-fade-up`. **Application Detail** replaces the generic `Page` header with the mockup **header
    pattern** (gradient app tile + name `h1` + mono uuid + release badge + Refresh/Untrack) and wires
    **`useSetCrumb(app:<uuid>)`** so the breadcrumb shows the real app name; Overview KPIs + cards get motion + `rounded-2xl`.
  - **Features** — feature cards get a soft gradient icon chip + `rounded-2xl` + `hover-lift` + stagger; **FeaturePage**
    wires **`useSetCrumb(feature:<id>)`**; the **artifact pipeline** + **activity feed** adopt `rounded-2xl` + motion;
    the **Spec Builder** toolbar + page header go **glassy** (`backdrop-blur`).
  - **Business map** — canvases + header strip `rounded-2xl`; dead `bg-surface-0` → `bg-surface-1`; React-Flow already
    token-driven (light + dark parity, no retire needed).
- **Quality:** tsc/eslint(0 err)/**web vitest 200** (jest-axe on the redesigned Applications/BusinessMap/Features pages
  passes)/build green; zero hardcoded brand hex; all asserted labels/roles/titles preserved (presentation-only). Shared
  primitives (MetricCard, Tabs) left untouched — deferred to the 27-10/27-11 primitives pass. **Independent review = SHIP
  (clean)**; 2 SHOULD-FIX applied (reduced-motion delay, dead surface class).

## 27-07 — Runs & Run detail ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `1000af0` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **As built** (behaviour-preserving; no change to run execution / node-state semantics / HITL protocol):
  - **Runs list** (`RunsTable`) → `rounded-2xl` card + `shadow-e1`; uppercase, muted header row on `bg-surface-2`;
    fade-in. `StatusPill` labels + all row actions (pause/cancel/review/open) preserved.
  - **Run Detail** (`RunDetailPage`) → glassy header (`bg-surface-1/70` + backdrop-blur) + wired
    **`useSetCrumb(run:<runId>)`** (breadcrumb shows the workflow, matching the page header).
  - **Run graph** (`NodeCard`) → `rounded-xl` + an icon chip; **no transform-hover** (would fight React-Flow node
    transforms); StatusPill + counters + status rings preserved. React-Flow already token-driven (light + dark parity).
  - **HITL** (`HitlBar`) → the gate prompt card gets `rounded-xl` + `shadow-e1` (elevated); controls/aria unchanged.
- **Quality:** tsc/eslint(0 err; 2 pre-existing RunsPage warnings untouched)/**web vitest 200** (jest-axe + the
  run-detail / HITL / documents suites)/build green; zero hardcoded brand hex; all asserted labels/roles preserved.
  **Independent review = SHIP** (no MUST-FIX). Shared primitives (StatusPill, Tabs, MetricCard) untouched → 27-10/27-11.

## 27-08 — Chat & Copilot ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `f541af1` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **As built** (behaviour-preserving; no change to the chat/ACP protocol, session modes, or MCP wiring):
  - **SessionList** → the active session uses the soft-gradient nav treatment (`grad-brand-soft` + `text-primary`),
    rounded-lg items; rename/delete/aria preserved.
  - **Composer** → glassy footer (`bg-surface-1/80` + backdrop-blur); the full ACP parity toolbar (model select,
    context meter, Clear/Compact, slash palette, image attach, export) unchanged.
  - **ChatThread** → mode banner + system nudge `rounded-xl`; **copilot cards** (permission/gate/terminal) + the
    **supervised-runs strip** `rounded-xl`. **ChatPage** empty state gets a gradient brand tile.
- **Note:** the chat session is always the breadcrumb leaf (current page dropped), so no `useSetCrumb` is needed here.
  `ChatThread`/`Composer` are shared with the Spec Builder (`chrome="spec"`) — both call sites verified green.
- **Quality:** tsc/eslint(0)/**web vitest 200** (chat/copilot/skills-chat + jest-axe)/build green; zero hardcoded brand
  hex; all asserted labels/roles preserved. **Independent review = SHIP.** Shared run-detail `Conversation` (used for
  assistant messages) + primitives untouched → 27-11 polish.

## 27-09 — Documents & Memory ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `9b2e733` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **Headline:** the v0.52.1 `/memory` d3-force **constellation** — the **one remaining hardcoded-dark surface**
  (flagged since 27-04) — is now **fully token-driven** and light-first with dark parity. **No hardcoded hex remains
  in `features/memory`.**
- **As built** (behaviour-preserving; no change to document parsing/sync or memory data/API; the d3-force sim is unchanged):
  - `tokens.css` — new **`--mem-*`** token set for BOTH themes (canvas, star/dot texture, label, edge / edge-active /
    edge-invalid, per-kind node hues, selected stroke, glass panel bg/border/fg). Light = a clean dotted surface with
    legible node hues; dark = the original starfield aesthetic, tokenized.
  - `graph.ts` KIND_STYLE colours → `var(--mem-node-*)` (+ `--mem-node-default` fallback); `graph.test` updated.
  - `MemoryGraph.tsx` — every hex/rgba replaced with `--mem-*`; **SVG fills/strokes moved into the `style` prop**
    (CSS `var()` doesn't resolve in SVG presentation attributes — the key trap). Interactions (hover-highlight,
    drag-pin, zoom/pan, search) unchanged.
  - `MemoryWorkspace` header → glassy; `DocumentTable` → rounded-2xl + shadow-e1 + uppercase muted header.
- **Quality:** tsc/eslint(0; 2 pre-existing SpreadsheetView warnings untouched)/**web vitest 200** (memory graph/list/
  inspector/review + jest-axe empty-graph + library suites)/build green; **zero hardcoded hex** in `features/memory` +
  `features/library`. **Independent review = SHIP.** Known pre-existing (out of scope): graph nodes aren't keyboard-
  operable → a11y follow-up for 27-11. Shared primitives untouched.

## 27-10 — Catalog, Settings & Overview ✅ BUILT (unreleased) — 2026-08-24
- **Commit:** genesis `bf41220` (LOCAL on master, unpushed/untagged — ships with the Phase 27 release train).
- **As built** (behaviour-preserving; no change to launch-schema semantics, settings persistence, or metrics/API):
  - **Catalog** — `WorkflowCard` + `SkillCard` get a soft-gradient icon chip + `rounded-2xl` + `hover-lift` + fade-in;
    WorkflowCard keeps its stretched-link whole-card nav + Install/Launch/Remove; SkillCard keeps source badge/actions.
  - **Overview** — KPI `MetricCard`s wrapped in staggered `anim-fade-up`; the Run-trend card `rounded-2xl`.
  - **Settings** — the tab shell + section components already use the token-driven Tabs/section pattern → left as-is.
- **Deliberate scope call:** the shared primitives (`MetricCard`, `Tabs`, `SegmentedControl`) were **NOT** restyled —
  they're used app-wide; any primitive-level polish is deferred to **27-11** (mind the blast radius).
- **Quality:** tsc/eslint(0; 2 pre-existing warnings untouched)/**web vitest 200** (catalog/skills/settings/overview/
  kiro/copilot + jest-axe)/build green; zero hardcoded brand hex. **Independent review = SHIP.** Minor cosmetic note
  (Overview KPI equal-height under the fade-up wrapper) folded into 27-11.

## Next
- **27-11 — Polish, a11y/responsive audit, dark-parity & release** (the FINAL sub-phase): a cross-surface polish pass +
  full jest-axe/responsive/both-theme audit, optional shared-primitive refinements (MetricCard equal-height, Tabs/
  SegmentedControl), memory-graph keyboard-nav (the 27-09 a11y follow-up), system-banner polish — then **cut the Phase 27
  release as genesis v0.53.0** (bump pyproject + FastAPI version, tag, push master + tag, verify CI incl. the frontend
  stale-bundle guard). This is the release gate for the whole 27-04..27-10 train.
