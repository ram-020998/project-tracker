# Branding: logo, favicon & app-wide loading animations (2026-08-19) — genesis v0.51.3

Gave Genesis a real brand mark + a branded loading experience. Frontend-only.

## The mark
`GenesisLogo` (`web/src/shared/ui/logo.tsx`) — an inline SVG: a rounded **blue→purple gradient tile**
(`#6d8bff`→`#b892ff`, the brand identity — fixed, not theme tokens) containing a white **orbit ring +
core dot + a "genesis" node** on the orbit. Inline SVG (not an asset file) so it's crisp at any size,
needs no network request (works with the SPA's index.html-fallback backend), and animates. Props:
`size`, `animated`, `title`, `className`; unique gradient id via `useId`.

## Where it's configured
- **Sidebar** brand block now renders `<GenesisLogo size={36} />` (replaced the generic `Zap` tile).
- **Favicon**: inline **SVG data-URI** `<link rel="icon">` in `web/index.html` (+ `apple-touch-icon` +
  `<meta theme-color="#0b0c0e">`). Inlined on purpose — the FastAPI backend serves `index.html` for any
  non-`/api`/`/assets` path (SPA catch-all), so a `public/favicon.svg` would return HTML. Title → "Genesis".
- **App-wide loading animation**:
  1. A **pre-JS boot splash** inside `#root` in `index.html` — the animated mark on a dark background,
     shown instantly on every load/refresh (before the JS bundle) and replaced when React mounts into
     `#root`. Dark body bg avoids a white flash.
  2. A branded **`LoadingScreen`** (`shared/feedback/states.tsx`: animated logo + label, `role="status"`)
     wired as the `RouterProvider` **Suspense fallback** in `main.tsx` for in-app full-page loads.
- **Animation**: `genesis-spin` (orbit) + `genesis-core-pulse` (core) keyframes in `styles/index.css`
  (`transform-box: view-box; transform-origin: 16px 16px` so rotation is centered). The pre-existing
  global `prefers-reduced-motion` rule disables them; the splash has its own reduced-motion guard.

## Gates
web **178 → 182** vitest (+4 `logo.test.tsx`: accessible mark, static-vs-animated classes, size/title,
LoadingScreen), lint 0 errors, tsc clean, build green. Built `static/index.html` verified to retain the
favicon data-URI + boot splash + title. **genesis v0.51.3** (frontend-only; core/workflows unchanged).
Commit `052ce36`, tag **v0.51.3**, CI green (#6609135: genesis + frontend + clean-install).

## Notes / future
- SVG favicons cover all modern browsers; a legacy `.ico` fallback wasn't added (local single-user, modern browser).
- A wordmark/full-lockup component + a light-theme-tuned mark are easy follow-ons if wanted.

## Update — v0.51.4 (logo redesign per feedback)
The first mark (an abstract orbit ring + node) was replaced with a **more modern, standard "G" monogram**:
the blue→purple gradient tile + a clean geometric white **G** (an open ring + an inward crossbar). The
`animated` prop on `GenesisLogo` was dropped — the mark is now always static, and the **loading animation is
a standard spinner ring** (`.genesis-spinner` in `index.css`) rotating around the static mark, used by both
`LoadingScreen` and the `index.html` boot splash (replacing the spinning-orbit/pulsing-core animation). Favicon
+ apple-touch-icon + boot splash SVGs updated to the G. web 182→181 vitest (dropped the animated-classes test),
gates green; genesis **v0.51.4** (`5a7a532`), CI green (#6609256).

