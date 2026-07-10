# Genesis — Phase 7.3 (Web Revamp: Design System) Implementation Record

> As-built record of `specs/phase-07-03-design-system.md` (implemented per the
> Overcut-derived visual language in `specs/phase-07-03a-visual-language-reference.md`).
> Part of the web-revamp program (M7.1).

**Date:** 2026-07-10 · **Milestone:** M7.1 · **Status:** ✅ COMPLETE — 14 web tests
(incl. jest-axe a11y) + `tsc` strict clean; **frontend CI green**. Built
**alongside** the interim app (served `static/` bundle untouched — cutover is 07-10).

Commits: `6f63cd5` (design-system foundation), `e976fe3` (new app made the dev root).

---

## 1. Summary

The frontend foundation for the entire revamp is now in place in `genesis/web`, on
the ADR-027 stack (Vite + React 18 + TS strict + Tailwind + Radix/shadcn-style +
Zustand + React Router + Recharts). It implements the tokens, component library,
layout primitives, and feedback patterns that every screen (07-04..09) composes from,
grounded in the first-hand Overcut study (07-03a).

The new app is now the **dev root** (`localhost:5173/`) so screens can be watched as
they land; the design-system gallery lives at `/dev` (and `/dev.html`).

---

## 2. What was built (`genesis/web`)

**Toolchain**
```
tailwind.config.ts   # tokens mapped to Tailwind theme; darkMode class .theme-dark
postcss.config.js    # tailwindcss + autoprefixer (ESM)
tsconfig.json        # + baseUrl/paths "@/*" -> src/*  (strict already on)
vite.config.ts       # + "@" alias; build.outDir=static (unchanged)
package.json         # + Radix, cva, clsx, tailwind-merge, lucide, date-fns, zustand,
                     #   react-router-dom, recharts, sonner; dev: tailwind+plugins, jest-axe
```

**Tokens & theming** — `src/styles/tokens.css` (Overcut-derived dark + light palette:
`--bg #0B0C0E`, `--surface-1 #141619`, brand `--primary #6D8BFF`, semantic status
colors + `-subtle` bg variants), `src/styles/index.css` (Tailwind entry, base styles,
`.metric-value` oversized numeral, reduced-motion). `src/stores/theme.ts` (Zustand,
persisted, system-default, `applyTheme`). `src/lib/cn.ts`.

**Primitives (`src/shared/ui/`)** — Button (cva variants + loading), Card (+Header/
Title/Body/Footer), Input/Textarea/Label/Field, Badge + **StatusPill/StatusDot/
ActionPill/KindBadge** (with the run+node status→tone map), Skeleton/Separator, Switch,
Tooltip, Tabs, Dialog + **Drawer** (side sheet), centralized `icons.ts` (+ node-kind
icon map).

**Patterns** — **MetricCard** (icon + oversized value + sub-stat/trend),
SegmentedControl, FilterChip / **CategoryChips** / **ToolChipRow** / AutoRefreshChip,
HealthDot, RelativeTime / Duration / formatCompact, **TrendChart** (Recharts, dark
axis + tooltip), toasts (sonner Toaster + `toast`).

**Layout (`src/shared/layout/`)** — **AppShell** (collapsible sidebar + topbar +
optional right rail), **Sidebar** (grouped nav MONITOR/LIBRARY/CONFIGURE + brand/health
header — Genesis nouns, not Overcut's), **Topbar** (breadcrumb + theme toggle +
right-rail toggle), **SplitPane** (resizable, for Run Detail), Page/Section.

**Feedback (`src/shared/feedback/`)** — EmptyState, ErrorState (inline + retry),
LoadingState (skeleton rows).

**App wiring** — `src/app/providers.tsx` (theme apply + TooltipProvider + Toaster),
`src/app/RootLayout.tsx` (AppShell + Outlet + derived breadcrumbs), `src/app/router.tsx`
(shell layout with placeholder Overview + ComingSoon routes for runs/catalog/settings;
`/dev` → kitchen sink), `src/app/routes/Overview.tsx` (placeholder dashboard). `main.tsx`
repointed to the new app (interim `App.tsx`/`theme.css` retained, unreferenced).

**Dev/QA** — `src/dev/KitchenSink.tsx` renders every token/primitive/pattern; reachable
at `/dev` (in-app) and `/dev.html` (standalone entry, not in the production build).

---

## 3. Verification

- `npx tsc --noEmit` — strict, **clean**.
- `npx vitest run` — **14 pass** (9 new `design-system.test.tsx` incl. jest-axe
  `toHaveNoViolations`, + the 3 api + 2 interim App tests).
- `npx vite build` (to a temp dir) — succeeds (one chunk-size warning from Recharts;
  route-level code-splitting deferred to 07-10).
- **frontend CI job: success** (`npm ci` from the lockfile → typecheck → test → build).
- Served `static/` bundle **unchanged** (verified via `git status`).

---

## 4. Decisions & notes

- **Build-alongside (07-10 rollout):** the new app is the dev root, but the committed
  `static/` (served by `genesis serve` on :8760) stays the interim app until the final
  cutover. No platform version bump/release (frontend foundation only).
- **shadcn without the CLI:** component source authored directly in `shared/ui` (this
  is what the shadcn CLI produces anyway) — we own and theme it, no kit lock-in.
- **npm registry:** the local `~/.npmrc` Artifactory token is **expired** (E401);
  installed from public npm for local dev. CI's node:20 has no `~/.npmrc` and resolves
  the lockfile's public-npm URLs fine (CI green confirms). Refresh the token when
  convenient.
- **eslint** not yet configured (the `lint` script was removed); it lands in 07-10.

---

## 5. Definition of done (07-03) — status

1. Tokens + both themes; theme toggle works; no hard-coded colors — ✅.
2. Full primitive + pattern + layout + feedback inventory built & unit-tested with
   a11y assertions — ✅.
3. AppShell renders the new grouped navigation — ✅ (⌘K palette deferred).
4. Kitchen-sink route published (`/dev` + `/dev.html`) — ✅ (a standalone STYLEGUIDE.md
   is deferred; the kitchen sink is the living reference for now).
5. `axe` clean on representative components; AA contrast intended in both themes
   (final visual/contrast QA is a manual browser pass) — ✅ (automated) / ⚠️ (manual).

---

## 6. Next

07-04 (Settings/Integrations) — the first real screen — consumes this design system +
the 07-02 data plane (mcp/cli cards, master-detail config, connection status), replacing
the ComingSoon placeholder at `/settings`.
