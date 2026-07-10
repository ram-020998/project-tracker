# Phase 7.3 — Design System & Component Library

> **Goal:** Establish the visual and interaction foundation for the entire
> revamp — design tokens, theming, the Tailwind + shadcn/ui component library, layout
> primitives, and the shared patterns (status, empty/error/loading, toasts,
> drawers) that every screen composes from. Ship it as a self-contained, documented
> layer so all screen specs (04–09) build on identical, accessible building blocks.

Prereq: 07-01. Consumers: all screen specs. Aesthetic target: Overcut-class —
dark-first, calm, dense, high signal-to-noise.

---

## 1. Principles

- **Token-driven.** No hard-coded colors/sizes in components; everything references
  a CSS variable / Tailwind token. Themes are a token swap.
- **Own the components.** shadcn/ui copies component source into the repo
  (`shared/ui/`); we own and theme them. No opaque kit lock-in.
- **Accessible by default.** Radix primitives under shadcn give focus management,
  ARIA, and keyboard behavior; we don't regress them.
- **Composition over configuration.** Small primitives (Button, Card, Badge) →
  patterns (StatusPill, MetricTile) → layouts (Page, SplitPane, Drawer).
- **One way to do a thing.** A single Button, a single Card, one spacing scale.

---

## 2. Design tokens

> **Concrete values updated per the first-hand Overcut study — see
> `phase-07-03a-visual-language-reference.md §3.2`, which is the source of truth for
> palette, radius, and the display-numeral treatment.** The structure below stands;
> the literal hex values come from 03a.

Defined as CSS custom properties in `styles/tokens.css`, surfaced to Tailwind via
`tailwind.config.ts` `theme.extend`. Two themes (`.theme-dark` default,
`.theme-light`) set the same variable names to different values.

### 2.1 Color (semantic, not literal)

```
--bg            app background            --surface-1  card/base panel
--surface-2     raised panel/drawer       --surface-3  popovers/menus
--border        hairline borders          --border-strong
--fg            primary text              --fg-muted    secondary text
--fg-subtle     tertiary/disabled
--primary       brand/action              --primary-fg
--accent        secondary highlight
--success --warning --danger --info       (+ each with -fg and -subtle bg variant)
--focus         focus ring
```

Status color mapping (used by StatusPill + graph nodes):

| Semantic | Runs status | Node status |
|---|---|---|
| info/idle | pending | pending |
| primary (animated) | running | running |
| warning | awaiting_input:gate / :paused | awaiting / retrying |
| success | done | ok |
| danger | failed | failed |
| neutral | cancelled | skipped |

Contrast: all text/status combos meet WCAG AA in both themes (verified in 07-10).

### 2.2 Typography

- Font: system UI stack for prose; **JetBrains Mono / ui-monospace** for
  logs/transcripts/code/JSON.
- Scale (rem): `xs .75 / sm .875 / base 1 / lg 1.125 / xl 1.25 / 2xl 1.5 / 3xl 1.875`.
- Weights: 400 / 500 / 600 / 700. Line-heights tuned for dense tables + readable prose.

### 2.3 Space, radius, elevation, motion

- Spacing scale: 0,1(4px),2,3,4,6,8,12,16 … (Tailwind default).
- Radius: `sm 6 / md 8 / lg 12 / xl 16 / full`. Cards `lg`, controls `md`.
- Elevation: 3 shadow levels (subtle in dark). Borders do most of the separation.
- Motion: durations `fast 120ms / base 200ms / slow 320ms`; easing
  `standard cubic-bezier(.2,0,0,1)`. All motion wrapped so `prefers-reduced-motion`
  disables non-essential transitions.
- Z-index scale: base < sticky < drawer < dropdown < modal < toast.

---

## 3. Theming

- `ThemeProvider` (Zustand `theme` slice) toggles `.theme-dark`/`.theme-light` on
  `<html>`; persisted to `localStorage`; defaults to dark; honors
  `prefers-color-scheme` on first load.
- No component reads a theme flag directly — they read tokens, so theme changes are
  pure CSS.

---

## 4. Component inventory (`shared/ui/`)

shadcn-derived primitives to generate/adapt (each themed to tokens, each with a
Vitest render test + a11y check):

**Primitives:** Button (variants: primary/secondary/ghost/danger/outline; sizes
sm/md/lg; loading state), IconButton, Input, Textarea, Select, Combobox, Checkbox,
Switch, RadioGroup, Slider, Label, Badge, Tag, Avatar, Separator, Kbd, Spinner,
Skeleton, Progress, Tooltip.

**Overlays:** Dialog/Modal, Drawer/Sheet (right + bottom), Popover, DropdownMenu,
ContextMenu, Command palette (⌘K), Toast/Sonner.

**Data:** Table (sortable headers, sticky header, row selection, virtualized
variant), DataList/DescriptionList, Tabs, Accordion, Card (Header/Body/Footer),
Pagination, Breadcrumb.

**Domain patterns (`shared/ui/patterns/`):**
- **StatusPill** — dot + label; maps run/node status → semantic color; animated dot
  when `running`.
- **StatusDot** — bare active/inactive/running dot for list rows (Overcut master-
  detail lists).
- **ActionPill** — Create/Update/Delete-style colored pill for audit/log rows.
- **MetricCard** — icon + label + **oversized display numeral** + sub-stat/trend
  (the signature Overcut dashboard tile). Uses the `.metric-value` type token.
- **SegmentedControl** — date-range / group-by / view toggles.
- **DateRangeControl**, **GroupByControl**, **AutoRefreshChip** — dashboard controls.
- **FilterChip** (removable) + **FilterBar** (search + chips + "Add filter").
- **CategoryChips** — catalog category filtering.
- **ToolChipRow** — capability/tool chips with a "+N" overflow (node/agent tools).
- **NodeCard** — React Flow custom node: title bar (kind icon + label + StatusPill) +
  config-summary lines + counters/colored dots (Overcut node-card aesthetic applied
  to the live run graph).
- **TrendChart** — Recharts line/area with the dark axis + hover-tooltip treatment.
- **MetricTile** — label + big value + delta + optional sparkline.
- **HealthDot** — configured/missing/reachable indicator for integrations.
- **RelativeTime** / **Duration** / **KindBadge** / **CopyButton** / **JsonTree** /
  **CodeBlock** / **MarkdownView** — as before.

---

## 5. Layout primitives (`shared/layout/`)

- **AppShell** — grid: fixed left `Sidebar`, sticky `Topbar`, scrollable
  `<Outlet/>`. Sidebar collapsible; state in `ui` store.
- **Sidebar** — brand, primary nav (Overview/Catalog/Runs/Settings) with active
  state + icons; footer slot (theme toggle, version, future user menu placeholder).
- **Topbar** — breadcrumb (from route handles), contextual actions slot, global
  ⌘K trigger, run-status chip when inside a run.
- **Page** — title + subtitle + actions + content; standard paddings/max-widths.
- **Section** — titled content group with optional collapse.
- **SplitPane** — resizable 2-region (used by Run Detail graph/inspector); persists
  ratio to `run-view` store.
- **Toolbar / FilterBar** — for list screens (search, filters, view toggles).

---

## 6. Feedback patterns (`shared/feedback/`)

- **LoadingState / Skeleton** — layout-matched skeletons per screen (list rows,
  cards, graph placeholder). Never a bare spinner on blank.
- **EmptyState** — icon + headline + description + primary action; one per list/panel.
- **ErrorState** — inline (recoverable, with Retry) and boundary (route-level) forms;
  shows a friendly message + `ApiError` detail behind a "details" disclosure.
- **Toast** — success/info/warning/error; auto-dismiss; action slot (e.g. "Undo",
  "View run"). Used for mutation outcomes.
- **ConfirmDialog** — for destructive actions (cancel run, remove workflow, fork);
  typed intent + explicit confirm.

---

## 7. Iconography & imagery

- `lucide-react` only; a curated `shared/ui/icons.ts` re-export map so icon usage is
  centralized and swappable. Node-kind and status icons are defined once here.
- No raster imagery in-app; illustrations for empty states are inline SVG or simple
  lucide compositions.

---

## 8. Accessibility standards

- Landmarks: `<nav>`, `<main>`, `<header>`; one `<h1>` per page.
- Focus: visible ring (`--focus`); focus trapped in modals/drawers; focus restored
  on close; route change moves focus to page `<h1>`.
- Keyboard: all interactive elements reachable/operable; ⌘K command palette; Esc
  closes overlays; arrow-key nav in menus/tables (Radix).
- ARIA: live region for toasts + run status changes (`aria-live="polite"`); graph
  nodes are buttons with accessible names; status conveyed by text+icon, not color
  alone.
- Motion/contrast: honor `prefers-reduced-motion`; AA contrast enforced.
- Testing: `@axe-core/react` in dev; jest-axe assertions in component tests (07-10).

---

## 9. Tailwind & build setup

- `tailwind.config.ts`: token-mapped `colors`, `borderRadius`, `boxShadow`,
  `fontFamily`, `transitionTimingFunction`; `darkMode: ['class', '.theme-dark']`;
  content globs over `src/**`.
- Plugins: `@tailwindcss/typography` (MarkdownView), `tailwindcss-animate`
  (shadcn), `@tailwindcss/forms` (reset).
- `styles/index.css`: `@tailwind base/components/utilities` + token import +
  base element styles.
- shadcn config (`components.json`) points at `shared/ui`, tokens, and the `cn()`
  class-merge util (`lib/cn.ts` via `clsx` + `tailwind-merge`).

---

## 10. Documentation & governance

- A living **`web/STYLEGUIDE.md`** enumerating components, variants, and usage
  do/don't (source of truth for contributors).
- Optional (recommended) **Storybook** or a `/dev/kitchen-sink` route rendering
  every component/variant for visual QA; gated to dev builds.
- Contribution rule: new UI must reuse a primitive/pattern or add one here — screens
  don't hand-roll one-off styled elements.

---

## 11. Definition of done

1. Tokens + both themes implemented; theme toggle works; no hard-coded colors in
   components.
2. Full component inventory (§4) + layout primitives (§5) + feedback patterns (§6)
   built, themed, and unit-tested with a11y assertions.
3. AppShell renders the new navigation; ⌘K palette scaffolded.
4. STYLEGUIDE.md (and kitchen-sink route) published.
5. `axe` clean on the shell + a representative screen; AA contrast verified in both
   themes.
