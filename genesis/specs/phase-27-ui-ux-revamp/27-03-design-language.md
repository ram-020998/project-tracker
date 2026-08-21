# 27-03 — Design language + component redline (finalized spec)

> **Phase 27 (UI/UX Revamp) · sub-phase 03.** Spec: `27-03-ui-mockups.md`. Depends on: 27-02 wireframes.
> **Status:** 📋 **FOR REVIEW (2026-08-21)** — coded mockups live at **`/dev/mockups`** (reload the dev server). **Medium:** coded, themeable mockups in `/dev` (ADR-055). **Gate:** ⭐ **user approval of the mockups unlocks implementation (27-04+).**

## 1. What was built (increment 1)
A **navigable, light-first coded mockup** at `web/src/dev/mockups/Mockups.tsx` (route `/dev/mockups`, outside the app shell), rendered inside a **scoped `.theme-next`** preview palette (`theme-next.css`) so it demonstrates the new language **without changing the live app default** (that flip is 27-04). Gates green: tsc/eslint/vitest **191**/build; `web/static` rebuilt.

**Screens mocked (all page-groups):** the new **shell** (expanded labelled sidebar + slim top app bar with breadcrumbs + ⌘K search + theme toggle) · **Applications** (with the D2 KPI strip) · **Application detail** (tabs + KPIs + distribution) · **Runs** list · **Run detail** (node-graph + HITL inspector split) · **Spec builder** (chat + action bar) · **Chat** · **Memory** (token-driven, **light-aware constellation**) · **Catalog** · **Documents** · **Settings** (with in-page theme toggle) · a **Design-language** panel (color/type/elevation/buttons).

## 1a. Iteration 2 (2026-08-21) — Mira-Pro recreation (supersedes the §2 draft values)
Per user feedback, the mockups were recreated in a **Mira-Pro / modern Material-admin** spirit — more techy-modern, richer elevation + display elements, **glassy semi-transparent top bar/breadcrumbs**, and **motion throughout**. The finalized values below **supersede** the initial §2 draft:
- **Palette (light-first):** canvas `--bg #f4f7fe` (cool blue-gray), `--surface-1 #ffffff`, deep-navy text `--fg #1b2559` (techy), `--fg-muted #4a5578`, `--fg-subtle #64709b` (AA); **brand `--primary #4318ff` (vivid indigo-violet) + `--accent #7551ff`** with a `--grad-brand` gradient; semantic `success #05a878` / `warning #d98a00` / `danger #e0403f` / `info #3965ff`.
- **Elevation:** soft, wide, cool-tinted (`e1` 3px/8px, `e2` 14/28px, `e3` 28/56px) + generous card radii (14–22px).
- **Glass:** `.glass` / `.glass-chip` (translucent + `backdrop-blur` + saturate) on the top bar, breadcrumbs, search, and view-toggles.
- **Motion (reduced-motion-safe):** staggered `fade-up` entrance, sparkline **draw-in**, bar-chart **grow**, hover-**lift** on cards, floating hero orbs, soft **live-pulse** dots, sheen. Keyframes + utilities live in `theme-next.css`.
- **New display widgets** (in `Mockups.tsx`, to become real primitives in 27-04): `StatCard`+`Sparkline`, `MiniBars` chart, `Progress`, `Avatar`, `Delta`, `Chip`, gradient hero, activity feed, pill-tabs.

## 2. Finalized visual language (implementable tokens)
The refined **light-first** token set (in `theme-next.css`; 27-04 promotes it into `styles/tokens.css` as the global default + refreshes the dark parity set):

| Role | Token | Value | Note |
|---|---|---|---|
| Canvas | `--bg` | `#f6f7f9` | soft cool white |
| Surface raised | `--surface-1` | `#ffffff` | cards |
| Surface inset | `--surface-2` | `#f0f2f5` | hover/insets |
| Surface active | `--surface-3` | `#e5e8ee` | tracks/active |
| Border / strong | `--border`/`--border-strong` | `#e6e8ec` / `#d2d7df` | |
| Text | `--fg` | `#14181f` | ~16:1 on bg |
| Text muted | `--fg-muted` | `#4d5763` | ~7:1 |
| Text subtle | `--fg-subtle` | `#667085` | **~4.6:1 — now AA** (was sub-AA) |
| Primary | `--primary`/`--primary-fg` | `#4f46e5` / `#ffffff` | indigo-600 (modern) |
| Accent | `--accent` | `#7c3aed` | violet-600 |
| Semantic | success/warning/danger/info | `#157347`/`#9a6700`/`#d1242f`/`#0b69d4` (+ `-subtle`) | AA on light |
| Focus | `--focus` | `#4f46e5` | |

- **Elevation (light-tuned):** soft, neutral-tinted, layered — `e1` `0 1px 2/3px rgb(16 24 40/.06–.10)`, `e2` medium float, `e3` `0 16px 40px -12px /.20`. (The global `e1..e3` are dark-tuned; `.theme-next` overrides them for light — 27-04 makes this per-theme.)
- **Type scale:** display 30 / title 20 / body 14 / label 12 / mono 12 — Inter + JetBrains Mono, tabular-nums for metrics; tighter tracking on display/title.
- **Radius:** sm 6 / md 8 / lg 12 / xl 16 (cards `lg`–`xl`, pills full).
- **Motion:** `fast 120ms` / `base 200ms` / `slow 320ms`, `standard` easing; hover-lift on cards (`-translate-y-0.5 + shadow-e2`); reduced-motion respected.
- **Iconography:** the existing lucide set (`shared/ui/icons`).

## 3. Component redline (mockup element → primitive)
- **Shell sidebar** → new layout (evolves `Sidebar`): expanded, labelled, `bg-surface-1`, active row = `bg-surface-2` + a **primary left-marker bar**.
- **Top app bar** → new (`AppShell` regains a bar): breadcrumbs (route-derived), a `⌘K` search pill, theme toggle, notifications.
- **KPI tiles** → `MetricCard` (unchanged API).
- **App / workflow cards** → `Card` (radius `xl`, hover-lift), `Badge`, `StatusPill`.
- **Tables (Runs/Documents)** → new lightweight table pattern: `Card` wrapper + `bg-surface-2` sticky header + `divide-border` rows + row hover; numerics right/tabular.
- **Tabs** → `Tabs` (unchanged; add overflow menu when >N in 27-04).
- **Run graph** → nodes = `Card`-like tiles + `NODE_KIND_ICON` + state dot; edges = connectors (real React Flow retained + tokenized).
- **Chat/spec bubbles** → new `Bubble` (user = `bg-primary text-primary-fg`, assistant = bordered `surface-1`); composer = bordered `surface-1` + `Button`.
- **Memory constellation** → token-driven fills (`var(--primary/accent/warning/danger)`) + `--border-strong` edges + `--fg-muted` labels — **light-aware** (retires the hardcoded cosmic hex in 27-09).
- **Segmented / Badge / Button / Input / feedback states** → existing primitives, restyled by tokens only (no API change).

## 4. Dark-parity notes
Every value above has a dark counterpart (27-04 refreshes `.theme-dark` to match the new primary/accent + elevation feel). The mockup is shown in light (the new default); dark parity is verified in 27-04 + audited in 27-11. No surface is light-only.

## 5. Decisions realized / confirmed here
- D1 Catalog **promoted** to primary nav (shown). · D2 **KPI strip** on Applications (shown). · D3 **expanded labelled nav** (shown). — reflecting the user's "yes" (2026-08-21).
- MUI-*inspired*, token-evolved (no `@mui/material`) — the mockups use the existing primitives, restyled by tokens (ADR-055).

## 6. Handoff → 27-04 (implementation, on approval)
On approval: 27-04 promotes `theme-next.css` → `styles/tokens.css` as the **global light default** (+ dark parity + per-theme elevation), flips the `useTheme` default from dark→light, evolves the shared primitives + `AppShell`/`Sidebar` (top bar, expanded nav, breadcrumbs, ⌘K) to match, and refreshes `/dev` KitchenSink. Then the page-group phases (27-05..27-10) rebuild each surface to these mockups; 27-11 audits a11y/responsive/dark-parity + releases.

> **Review:** open **`/dev/mockups`**, click through the sidebar (Applications → a card → Spec/Run, Runs → a row, Memory, Catalog, Documents, Settings, Design language). Feedback on palette, density, type, and per-screen layout folds back here before 27-04.
