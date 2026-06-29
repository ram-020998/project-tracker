# 20 — Dashboard UX Standards & Contribution Guide

**Status:** Implemented · **Applies to:** `solutions-copilot/installer/` (the Kiro IDE extension webview)
**Builds on:** doc 13 (config-app design), doc 16 (dashboard), doc 17 (installer architecture & review)
**Last updated:** 2026-06-29

> The dashboard webview was modernized into a **token-based design system** with a **decomposed,
> OOP-influenced component architecture**. This document is the **authoritative UX standard** for the
> extension UI and the **step-by-step contract** for adding new screens, components, or actions so
> everything stays visually and structurally consistent.
>
> **Golden rule:** never hand-build markup with ad-hoc styles. Reuse the design tokens and the
> component library. If something you need doesn't exist, add it to the component library first
> (§4), then use it.

---

## 0. Where things live (file map)

All UI lives under `installer/` and is bundled by esbuild from `webview/main.tsx` → `media/dist/main.js`.

```
installer/
├── media/
│   └── style.css                 # THE design system (tokens + component styles). Single stylesheet.
├── src/
│   └── messages.ts               # Host⇄webview message protocol (pure types). The contract.
└── webview/
    ├── main.tsx                  # entry — renders <App/> into #root
    ├── vscode.ts                 # acquireVsCodeApi() wrapper + post()
    ├── app.tsx                   # thin composition root (gateway + model + layout + sections)
    ├── state/
    │   ├── gateway.ts            # MessageGateway class — typed webview→host protocol methods
    │   └── model.ts              # useDashboardModel — the view-model (all state + actions)
    ├── components/
    │   ├── icons.tsx             # Icon component + inline SVG set (currentColor)
    │   ├── primitives.tsx        # Button, Badge, Card, StatCard, Toolbar, EmptyState, ProgressBar, Field, TextInput, Segmented
    │   ├── layout.tsx            # Shell, TopBar, Sidebar (+ NAV_ITEMS)
    │   └── shared.tsx            # cross-section bits: AgentStatusBadge, ConnectPanel
    └── sections/
        ├── Overview.tsx          # one file per nav section — single-responsibility containers
        ├── Agents.tsx            # list + detail (+ custom-authoring forms)
        ├── Catalog.tsx
        ├── Connections.tsx
        ├── Environments.tsx
        └── Status.tsx
```

The host side (`src/app/panel.ts` + `src/services/*` + `src/core/*`) is unchanged by the UI work and
is documented in doc 17. **The webview only talks to the host through `src/messages.ts`.**

---

## 1. Design principles (the "why")

| # | Principle | What it means in practice |
|---|---|---|
| P1 | **Theme-native** | Every color derives from `var(--vscode-*)` theme variables. The UI must look correct in light, dark, and high-contrast themes without per-theme code. Never hard-code hex colors except as a fallback inside `color-mix()` accents. |
| P2 | **Token-first** | Spacing, radius, elevation, and motion come from the `:root` token scale. No magic pixel values in component CSS. |
| P3 | **Component reuse** | Markup is composed from the primitive library (§4). Sections contain *layout + data wiring*, not bespoke styled elements. |
| P4 | **Separation of concerns** | Presentation (components) ⟂ state/behavior (the view-model) ⟂ protocol (the gateway). A component never calls the host directly; it calls a model action. |
| P5 | **Progressive enhancement** | `color-mix()` tints have a solid fallback declared first, so older Kiro/Electron engines (engine floor `^1.74`) degrade gracefully instead of rendering blank surfaces. |
| P6 | **CSP-safe** | No external fonts/images/scripts. Icons are inline SVG. The only script is the nonce-tagged bundle; the only stylesheet is `media/style.css`. |
| P7 | **Accessible by default** | Keyboard operable, visible focus, ARIA roles on nav/tabs/progress, labels on icon-only buttons (doc 13 §13). |

---

## 2. Design tokens (the single source of visual truth)

Defined once in `media/style.css` `:root`. **Use these — do not invent new spacing/radius values.**

```css
/* spacing */   --sp-1:4px  --sp-2:8px  --sp-3:12px  --sp-4:16px  --sp-5:22px  --sp-6:30px
/* radius */    --r-sm:6px  --r-md:10px  --r-lg:14px  --r-pill:999px
/* elevation */ --shadow-sm  --shadow-md  --shadow-lg
/* motion */    --ease (cubic-bezier)  --t-fast:120ms  --t-med:200ms
/* surfaces */  --surface  --surface-2  --border  --border-strong
/* accent */    --accent  --accent-fg  --focus  --hover
/* status */    --ok  --warn  --danger  --info  --purple
```

Rules:
- **Surfaces:** cards/topbar/sidebar use `--surface`; the page背景 is `--surface-2`. Borders use
  `--border` (subtle) or `--border-strong` (controls).
- **Accent:** primary actions and active states use `--accent` / `--accent-fg`. Focus rings use
  `--focus`.
- **Status colors:** map state → token — success `--ok`, warning `--warn`, error/destructive
  `--danger`, informational `--info`, custom/user-owned `--purple`. Never use a raw green/red.
- **Motion:** transitions use `--t-fast` (hover/press) or `--t-med` (layout/elevation), always with
  `--ease`. Keep animations subtle (≤240ms); respect that some users disable motion.

### 2.1 The `color-mix` fallback pattern (mandatory for tints)
Any tinted background built with `color-mix()` MUST declare a solid fallback on the line above:

```css
.thing {
  background: var(--hover);                                  /* fallback for old engines */
  background: color-mix(in srgb, var(--accent) 16%, transparent);  /* modern engines override */
}
```
Modern engines use the second declaration; engines without `color-mix` ignore it and keep the
fallback. This is why the brand mark, avatars, stat icons, nav-active, and badges all have a
preceding solid `background`.

---

## 3. Layout & navigation standards

- **Shell:** `<Shell topbar sidebar>{section}</Shell>` — a sticky `TopBar`, a fixed-width icon
  `Sidebar`, and a scrolling content column capped at `max-width: 1040px` and centered.
- **TopBar:** brand mark + name on the left; on the right a `Segmented` **scope** control
  (Workspace/Global), an **Updates** ghost button, and a **connection pill** (green dot when
  connected). Global affordances only — never put section-specific actions here.
- **Sidebar:** one `nav__item` per section, each with an icon + label and an active accent bar.
  Section list is `NAV_ITEMS` in `components/layout.tsx`.
- **Section header:** every section starts with `<Toolbar title subtitle>` and right-aligned
  section actions in the toolbar's `children`. The `subtitle` carries context (e.g. the scope path,
  "adding to workspace").
- **Content rhythm:** stack cards with the default `--sp-4` bottom margin; group multi-field forms
  in `.grid--2`; lay out card collections in `.grid--cards` (auto-fill, 230px min) and stats in
  `.grid--stats`.
- **Back navigation:** drill-in views (agent detail, secret editor) start with a `.backlink`
  (chevron + label) that returns to the list.

---

## 4. Component library (use these; extend, don't fork)

### 4.1 Primitives — `components/primitives.tsx`
| Component | Use for | Key props |
|---|---|---|
| `Button` | all clickable actions | `variant` = `primary`\|`ghost`\|`danger`\|`link`; `size` = `sm`\|`md`; `icon` |
| `Badge` | status / labels | `tone` = `ok`\|`warn`\|`danger`\|`info`\|`custom`\|`muted`; `dot` |
| `Card` | any surface/panel | `pad`, `interactive`, `selected` |
| `Toolbar` | section header | `title`, `subtitle`, `children` (actions) |
| `StatCard` | KPI tiles | `icon`, `value`, `label` |
| `EmptyState` | empty/zero/disconnected | `icon`, `title`, `hint`, `children` (CTA) |
| `ProgressBar` | completion ratios | `value`, `total` |
| `Field` + `TextInput` | labeled inputs | `TextInput` uses `value` + `onValue(v)` (not raw `onInput`) |
| `Segmented` | 2–3 exclusive options | `value`, `options[]`, `onChange` |

Conventions:
- **Buttons:** primary = the one main action per view; everything else is `ghost`. Destructive =
  `danger`. Inline text actions = `link`. Toolbar/secondary actions use `size="sm"`.
- **Icon-only buttons** use the `.icon-btn` class and **must** have `aria-label`.
- **Inputs** always go through `TextInput`/`Field` (consistent focus ring + sizing). For native
  `<select>`, use the `.select` class.

### 4.2 Icons — `components/icons.tsx`
`<Icon name size strokeWidth />`. Stroke-based, inherits `currentColor`. To add an icon, add a new
entry to the `IconName` union and the `PATHS` map (a 24×24 stroke path). **Do not** import an icon
font or external SVG (CSP + offline).

### 4.3 Status semantics (reuse, don't reinvent)
- Agent state → `AgentStatusBadge` (`components/shared.tsx`): custom → purple; not installed →
  muted "available"; update-available → warn "update"; installed → ok "installed".
- MCP completeness, check results, etc. reuse `Badge` tones and the `.check--{pass,warn,fail}`
  pattern. Keep the mapping identical everywhere.

---

## 5. Architecture & state standards (OOP / SoC)

Three layers, strictly separated:

```
sections/*  (presentation)  ──uses──▶  useDashboardModel (state+actions)  ──uses──▶  MessageGateway (protocol)  ──▶ host
components/* (presentation, dumb)                                                     src/messages.ts (types)
```

- **`MessageGateway` (`state/gateway.ts`)** — a class with exactly one typed method per outbound
  message. Components/sections never call `post()` directly; the model calls the gateway.
- **`useDashboardModel` (`state/model.ts`)** — the **single** view-model. Owns all `useState`,
  registers the **single** `window` message listener, and exposes a typed `DashboardModel` object
  (state fields + action methods + derived `detail`/`previewRoles`). Preserves the `scopeRef` mirror
  that keeps the once-registered handler reading the latest scope (fixes the init/auto-connect race).
- **Sections** receive `model: DashboardModel` and render; they hold **no** business logic and never
  touch the host.
- **Primitives** are pure/"dumb": props in, markup out. No app state, no protocol.

This mirrors the host-side service decomposition in doc 17 (thin controller → services → pure core).

---

## 6. The protocol contract — `src/messages.ts`

The webview and host communicate **only** through the discriminated unions `InboundMessage`
(webview→host) and `OutboundMessage` (host→webview), plus shared data types.

Rules:
- **Additive, typed changes only.** Add a new message as a new union member; never repurpose an
  existing one.
- Webview→host goes through a **new `MessageGateway` method** (never inline `post`).
- Host→webview is handled by a **new `case` in the model's message switch**.
- Keep both sides in sync; the strict webview typecheck (`tsconfig.webview.json`) will catch drift.

---

## 7. HOW-TO: add a new feature consistently (the checklist)

### 7.1 Add a new **section** (nav tab)
1. Add the id to the `Section` union in `state/model.ts` and to `NAV_ITEMS` in `components/layout.tsx`
   (pick an `IconName`, adding one to `icons.tsx` if needed).
2. Create `sections/<Name>.tsx` exporting `function <Name>Section({ model }: { model: DashboardModel })`.
   Start with `<Toolbar title subtitle>`; compose from primitives; use `EmptyState` for the
   empty/disconnected case.
3. Render it in `app.tsx`: `{model.section === "<id>" && <NameSection model={model} />}`.
4. If it needs host data/actions, follow §7.3.

### 7.2 Add a new **reusable component**
1. If presentational and generic → add to `components/primitives.tsx` (typed props, no state).
2. If cross-section but app-aware (needs the model) → add to `components/shared.tsx`.
3. Add its styles to `media/style.css` using **tokens only** and the `color-mix` fallback pattern.
4. Prefer extending an existing primitive (new `variant`/`tone`) over creating a near-duplicate.

### 7.3 Add a new **host action / data flow**
1. Add the message type(s) to `InboundMessage`/`OutboundMessage` in `src/messages.ts`.
2. Add a typed method to `MessageGateway` (`state/gateway.ts`) for the outbound message.
3. In `useDashboardModel`: add any state, an action method that calls the gateway, and (for the
   response) a new `case` in the message switch that updates state.
4. Add the host handler in `src/app/panel.ts` routing to the appropriate service (see doc 17).
5. Expose the new state/action on the `DashboardModel` interface and the returned object.
6. Wire it into the section UI via the model.

### 7.4 Styling rules when adding CSS
- Tokens only (§2). New spacing/radius/color **must** map to an existing token; if a genuinely new
  token is needed, add it to `:root` with a sensible name and reuse it.
- Use BEM-ish class names scoped to the component (`.thing`, `.thing__part`, `.thing--modifier`).
- Tinted backgrounds → solid fallback then `color-mix` (§2.1).
- Add hover/active transitions with `--t-fast`; respect the existing elevation/hover conventions
  (`.card--interactive` lifts on hover).

### 7.5 Accessibility checklist (every addition)
- Reachable and operable by keyboard; `:focus-visible` ring shows (it's global — don't remove it).
- Icon-only controls have `aria-label`.
- Tabs/exclusive toggles use `role="tablist"`/`tab` + `aria-selected` (see `Segmented`).
- Don't convey state by color alone — pair with text/icon (badges already do: dot + label).

---

## 8. Build, run & verification

```bash
cd installer
npm install
npm run build              # tsc host + esbuild webview bundle
npm run typecheck:webview  # strict webview typecheck (catches protocol/prop drift)
npm test                   # headless core tests (must stay green)
npm run package            # -> solutions-copilot.vsix
kiro --install-extension solutions-copilot.vsix --force   # then reload Kiro
```

**Definition of done for any UI change:**
1. `npm run build`, `npm run typecheck:webview`, and `npm test` all pass.
2. The change uses tokens + the component library (no ad-hoc styles/markup).
3. Any host interaction goes types → gateway → model → section (no inline `post`).
4. Verified rendering (light + dark) with no console errors.

### 8.1 Offline visual verification (optional but recommended)
Because the webview is a plain Preact bundle, you can render it outside Kiro to eyeball changes:
mount `media/dist/main.js` in a static HTML page that (a) defines the common `--vscode-*` variables
for a theme, (b) stubs `window.acquireVsCodeApi`, and (c) `postMessage`s canned `init`/`catalog`/
`dashboard` payloads. Serve over `http://` (not `file://`) and screenshot. This catches runtime
errors and layout regressions without a full extension reload. (Used during the 2026-06-29
modernization to validate Overview, Agents, Agent detail, Catalog, and Status.)

---

## 9. Anti-patterns (do NOT do these)
- ❌ Hard-coded colors/pixels instead of tokens/theme vars.
- ❌ Bespoke styled markup in a section instead of a reused primitive.
- ❌ Calling `post()` / assembling protocol envelopes from a component (use the gateway via the model).
- ❌ A second `window` "message" listener (there is exactly one, in the model).
- ❌ `color-mix()` without a solid fallback.
- ❌ External fonts/images/icon-fonts (breaks CSP + offline).
- ❌ Icon-only buttons without `aria-label`; removing the global focus ring.
- ❌ Repurposing an existing message type instead of adding a new one.

---

## 10. Relationship to other docs
Implements the UX/accessibility intent of doc 13 (§5, §13) and the dashboard surfaces of doc 16 on a
standard, modular footing consistent with doc 17's architecture review. The host services/contract it
depends on are unchanged; this doc governs the **presentation layer** only.
