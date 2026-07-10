# Phase 7.1 — Web Revamp: Program Overview & Frontend Architecture

> **Goal:** Rebuild the Genesis web workbench from the ground up into a modern,
> enterprise-grade, UX-first React application that fully exposes every platform
> capability — configure integrations, browse/install workflows, launch runs, and
> **supervise a live run** (graph visualization, per-node Kiro conversation, HITL
> controls, and document preview). This is the anchor document for the
> **phase-07-0N** sub-series; it defines the vision, the technology stack
> (ADR-027), the application architecture, and the delivery plan. Every other
> `phase-07-0N` doc refines one slice of what is defined here.

Prereq: Phases 1–7 complete (engine, distribution, config, run orchestration + HITL,
ERD reference workflow, and the interim Phase-7 workbench). This program **replaces**
that interim workbench (`genesis/web/`) entirely — see §9 and `phase-07-10`.

Reference product for UX bar: Overcut (https://overcut.ai) — dark-first, data-dense,
calm agentic-SDLC control plane.

---

## 1. Why this program exists

The interim Phase-7 workbench proved the FastAPI + SSE contract but is not a
foundation for an enterprise product:

- **Capability gap.** The platform can do far more than the UI exposes. HITL gate
  approval is unreachable after a reload/restart (gate state is only in an
  in-memory event bus); the live Kiro conversation is discarded; there is no
  workflow graph, no per-node inspection, no document preview.
- **Architecture gap.** The current `web/` is hand-rolled: a hash router, raw
  `fetch`, ad-hoc `useAsync`, a single `theme.css`. There is no design system, no
  server-state cache, no route model, no component library, no test depth. It
  cannot absorb the many features planned on top of it.
- **Data-plane gap.** Some target features are not merely un-rendered — the backend
  does not yet **emit** them (conversation transcript, graph topology, per-node step
  records, artifact content). The revamp is therefore **full-stack** (see
  `phase-07-02`).

This program closes all three gaps with a clean rebuild on a standard, expandable
stack and a persistent, richly-typed data plane.

---

## 2. Product vision & experience principles

**Vision.** Genesis is the local control plane for agentic SDLC workflows. A
Solutions engineer opens Genesis, sees the health of their integrations at a
glance, picks a workflow, launches it, and then **watches the work happen** — the
graph lights up node by node, they can open any node to read exactly what Kiro is
doing (messages, thoughts, tool calls, validation), they approve or redirect at
gates, and they read the documents the workflow produced — all without touching a
terminal or reading raw JSON.

**Experience principles (non-negotiable):**

1. **Show the work, not the plumbing.** No raw JSON blobs as a primary surface.
   Every piece of state has a purpose-built representation. Raw JSON is available
   only behind a "developer / inspect" affordance.
2. **The run is the hero.** Run Detail is the most important screen in the product.
   It must feel live, legible, and trustworthy.
3. **Always actionable.** If the system is waiting on the human, the human always
   has a clear, reachable control — derived from durable state, never from a
   transient event (this is the root cause of the current approval bug).
4. **Calm, dense, fast.** Enterprise operators scan. Dark-first, high
   signal-to-noise, sub-100ms interactions, optimistic UI where safe.
5. **Legible at every state.** Loading, empty, partial, error, and terminal states
   are designed first-class — never an afterthought.
6. **Accessible & keyboard-first.** WCAG 2.1 AA; full keyboard navigation;
   respects reduced-motion and color-contrast.
7. **Expandable by construction.** Feature-sliced structure, typed contracts, and a
   design system so new features compose instead of accreting.

**Non-goals (this program):** multi-user auth, RBAC, hosting/SSO, tenanting. Genesis
remains **local single-user** (ADR-012/023/026). The UI may *reserve space* for a
future user menu but must not implement auth.

---

## 3. Technology stack (ADR-027)

Chosen for standardness, TypeScript-first ergonomics, community depth, and a
bespoke "Overcut-class" look. Full rationale + alternatives in
`reference/decision-log.md` ADR-027.

| Concern | Choice | Why |
|---|---|---|
| Build/dev | **Vite + React 18 + TypeScript (strict)** | Keep (ADR-026); fast HMR, committed static build. |
| Routing | **React Router v6** (data routers) | Real URLs, nested layouts, per-route loaders/error boundaries. |
| Server state | **TanStack Query v5** | Caching, background refetch, polling, invalidation; removes manual effect/poll code. |
| Live updates | **Native `EventSource` + a typed SSE→Query bridge** | Push events reconcile into the Query cache. |
| Client/UI state | **Zustand** | Tiny store for cross-component UI state (selected node, drawers, theme). |
| Styling | **Tailwind CSS v3** | Utility-first tokens; fast; consistent. |
| Components | **shadcn/ui (Radix primitives)** | Owned, themeable, accessible components — not a locked-in kit. |
| Graph/diagram | **React Flow (`@xyflow/react`)** | Standard for interactive node/edge DAGs with live status + click-to-inspect. |
| Forms | **react-hook-form + zod** | Schema-driven forms from `inputs_schema`; typed validation. |
| Markdown/diagrams | **react-markdown + remark-gfm + mermaid** | Document preview rendering. |
| Code/JSON | **shiki** (highlight) + a JSON tree viewer | Transcripts, artifact preview, developer-inspect. |
| Charts | **Recharts** | Telemetry/metrics visualizations. |
| Icons | **lucide-react** | Consistent modern icon set. |
| Dates | **date-fns** | Relative timestamps, durations. |
| Testing | **Vitest + React Testing Library + MSW**; **Playwright** for E2E | Unit/component + mocked network + smoke E2E. |
| Lint/format | **ESLint (typescript-eslint) + Prettier** | Enforced in CI. |

**Constraints preserved:** the production bundle is built with Vite and
**committed** to `genesis/web/static/` so the FastAPI runtime needs no Node
(ADR-026). Same-origin API (no CORS). No telemetry/analytics phone-home.

---

## 4. Application architecture

### 4.1 Layered model

```
┌───────────────────────────────────────────────────────────────┐
│ Presentation      routes/ + features/*/components  (React/JSX)  │
├───────────────────────────────────────────────────────────────┤
│ Feature logic     features/*/hooks  (useX queries/mutations)    │
├───────────────────────────────────────────────────────────────┤
│ Data access       lib/api (typed client) · lib/sse (event bus)  │
│                   lib/query (TanStack config, keys, invalidation)│
├───────────────────────────────────────────────────────────────┤
│ Cross-cutting     shared/ui (design system) · stores/ · types/  │
└───────────────────────────────────────────────────────────────┘
```

Rules: presentation never calls `fetch` directly (only feature hooks); feature
hooks never hard-code URLs (only `lib/api`); all server shapes are typed in
`types/` and generated/mirrored from the backend contract in `phase-07-02`.

### 4.2 Folder structure (`genesis/web/`)

```
web/
  index.html
  vite.config.ts  tailwind.config.ts  postcss.config.js  tsconfig.json
  package.json
  src/
    main.tsx                 # bootstrap: QueryClientProvider, RouterProvider, ThemeProvider
    app/
      router.tsx             # route tree (data router)
      AppShell.tsx           # sidebar + topbar + <Outlet/>
      providers.tsx          # composed providers
      error-boundary.tsx
    features/
      overview/              # dashboard/home
      settings/              # MCP/CLI cards, secrets, environments, health   (phase-07-04)
      catalog/               # browse/install/launch                          (phase-07-05)
      runs/                  # list + history                                 (phase-07-06)
      run-detail/            # the centerpiece                                 (07-07/08/09)
        components/graph/    # React Flow canvas + node renderers
        components/inspector/# node conversation + validator/retry
        components/hitl/     # gate/approval/pause/fork controls
        components/docs/     # documents drawer + preview
        hooks/
      documents/             # shared artifact preview renderers               (phase-07-09)
    shared/
      ui/                    # design-system components (shadcn-derived)        (phase-07-03)
      layout/                # Page, Section, Drawer, SplitPane, Toolbar
      feedback/              # Empty, Error, Loading/Skeleton, Toast
      format/                # date, bytes, duration formatters
    lib/
      api/                   # typed REST client (one module per resource)
      sse/                   # EventSource manager + typed event union + Query bridge
      query/                 # QueryClient, query keys, invalidation helpers
    stores/                  # zustand slices (ui, theme, run-view)
    types/                   # backend contract types (mirror phase-07-02)
    styles/                  # tokens.css, tailwind entry, theme vars
    test/                    # setup, MSW handlers, factories
  static/                    # committed production build (generated)
```

### 4.3 Routing map (URLs are first-class)

> **Shell (per `phase-07-03a`):** a ~280px collapsible **left sidebar** with a Genesis
> brand tile + active-environment/health indicator at top, then nav grouped under
> small-caps section labels — **MONITOR** (Overview, Runs) · **LIBRARY** (Catalog) ·
> **CONFIGURE** (Integrations, Environments) · **SETTINGS** — and a footer (theme
> toggle, version, reserved copilot slot). A **top bar** with a breadcrumb page title
> and a contextual **right-rail toggle** (Run Detail inspector/docs; reserved for a
> future run-aware copilot). No project switcher / billing (local single-user).

| Route | Screen | Spec |
|---|---|---|
| `/` | Overview / dashboard | this doc §7 |
| `/settings` | Integrations & configuration | 07-04 |
| `/settings/:server` | Server config drawer (deep-linkable) | 07-04 |
| `/catalog` | Workflow catalog | 07-05 |
| `/catalog/:workflowId` | Workflow detail | 07-05 |
| `/catalog/:workflowId/launch` | Launch form | 07-05 |
| `/runs` | Runs list & history | 07-06 |
| `/runs/:runId` | Run detail (graph) | 07-07 |
| `/runs/:runId/node/:nodeId` | Run detail + node inspector open | 07-08 |
| `/runs/:runId/docs/:docName` | Run detail + document preview open | 07-09 |

Node/doc selection is a **nested route**, so inspecting a node or previewing a
document is deep-linkable and back-button friendly.

### 4.4 Server-state & live-update architecture

- **Query keys** are centralized (`lib/query/keys.ts`): `['runs']`, `['run', id]`,
  `['run', id, 'events']`, `['run', id, 'state']`, `['run', id, 'topology']`,
  `['catalog']`, `['workflow', id]`, `['config','mcp-cards']`, `['config','health']`.
- **Polling** for lists/records via TanStack Query `refetchInterval` (2–4s) only
  while a run is non-terminal; disabled once terminal.
- **SSE bridge** (`lib/sse`): a single `EventSource` per open run. Incoming typed
  events are **reconciled into the Query cache** (append to the events list, patch
  the run record, flip node statuses) rather than held in ad-hoc component state.
  On terminal `final`/`error`, the source is closed (fixes the reconnect-replay
  loop). On mount of an already-terminal or previously-gated run, the UI **hydrates
  from the persistent event log** (`phase-07-02`) — never depends on a live socket.
- **Optimistic mutations** for safe actions (pause, select) with rollback; gate
  responses and forks are confirmed against server state before UI commit.

### 4.5 State ownership

- **Server state** → TanStack Query (source of truth for anything the backend owns).
- **UI state** → Zustand slices: `theme`, `ui` (open drawers, sidebar collapse),
  `run-view` (selected node, inspector tab, docs-drawer open, graph layout prefs).
- **Form state** → react-hook-form, local to the form.
- No Redux; no global mutable singletons beyond Zustand + Query.

---

## 5. Cross-cutting standards (apply to every screen)

- **Loading:** skeletons that match final layout (never spinners-on-blank). Route
  loaders prefetch primary data.
- **Empty:** every list/panel has a purposeful empty state with a next action.
- **Error:** typed `ApiError`; route-level error boundaries; inline recoverable
  errors with retry; toasts for transient failures. Never a white screen.
- **Optimism & feedback:** every mutation shows pending/success/failure; destructive
  actions (cancel, remove, fork) confirm.
- **Accessibility:** semantic landmarks, focus management on route/drawer change,
  ARIA on custom widgets (Radix gives most), visible focus rings, `prefers-reduced-
  motion`, AA contrast in both themes.
- **Performance budgets:** first meaningful paint < 1.5s local; route chunk < 250KB
  gzip; graph handles ≥ 100 nodes at 60fps; virtualize long lists/transcripts.
- **Security:** secrets are **write-only** in the UI (never rendered back — only
  key names + "set/unset"); same-origin only; no secret in URL/query/localStorage.
- **Observability (client):** a dev-only debug panel (toggle) exposing raw
  events/state/query cache; gated behind a `?debug=1` flag.
- **i18n-ready:** user-facing strings centralized (not hard-coded inline) to allow
  future localization; English only for now.

---

## 6. Visual/design direction (summary; full system in phase-07-03 + phase-07-03a)

Direction is now grounded in a first-hand study of the Overcut app — see
**`phase-07-03a-visual-language-reference.md`** (the visual north star). We adopt
Overcut's *vocabulary*: near-black calm surface, dark hairline-bordered cards,
**metric cards with oversized display numerals** + date-range/group-by segmented
controls + auto-refresh, **master-detail** config, **category-chip + card-grid**
catalogs, **node-card** canvases, **status pills / dots** and **tool chips**, and a
grouped left sidebar. We **innovate on top**: the **live run is the hero** (a live
node-status graph + timeline scrubber), a **per-node Kiro conversation inspector**
(vs. Overcut's single global chat), first-class **HITL controls**, and a **document
preview drawer** — none of which Overcut has. Genesis stays **local single-user**
(no projects/billing/agent-role authoring). The Run Detail uses a **three-region
layout**: graph canvas (center), node inspector (bottom/right, resizable), documents
drawer (right, collapsible). Monospace for logs/transcripts. Purposeful motion
(node-state transitions, drawer slides) that respects reduced-motion.

---

## 7. Overview / dashboard screen (defined here)

The landing screen answers "what's the state of my Genesis?" in one glance, using the
Overcut dashboard pattern (`phase-07-03a §3.4`): a **date-range + group-by**
segmented control row with an **auto-refresh** chip, a grid of **MetricCards** with
oversized display numerals (Total Runs, Success Rate, Avg Duration, Currently
Running, Total Tokens — with sub-stats/trends), and **TrendCharts** (runs over time,
token usage). Genesis-specific additions above the metrics:

- **Active runs strip** — cards for non-terminal runs with live status + jump-in link
  (our hero surfacing; Overcut has no live-run emphasis).
- **Integrations health strip** — compact MCP/CLI/GitLab status (green/amber/red)
  linking into CONFIGURE.
- **Installed workflows** — count + quick launch; getting-started empty state.

Data: `GET /home` (extended in `phase-07-02` to include active-run summaries and
per-integration status).

---

## 8. Delivery plan (the phase-07-0N sub-series)

Each sub-spec is an independently deliverable work-item (fits the multi-agent
session model + `AGENT_ONBOARDING.md`). Recommended sequence:

| # | Spec | Layer | Depends on |
|---|---|---|---|
| 07-01 | Program Overview & Frontend Architecture (this) | — | — |
| 07-02 | Backend & Core Data-Plane Enhancements | genesis / genesis-core / kiro-agent-sdk | — |
| 07-03 | Design System & Component Library | web | 07-01 |
| 07-03a | Visual Language Reference (Overcut-inspired) | web | 07-01 |
| 07-04 | Settings & Configuration Experience | web | 07-02, 07-03 |
| 07-05 | Workflow Catalog & Install Management | web (+ install API) | 07-02, 07-03 |
| 07-06 | Runs List & History | web | 07-02, 07-03 |
| 07-07 | Run Detail — Graph Visualization & Orchestration State | web | 07-02, 07-03 |
| 07-08 | Run Detail — Node Inspection, Kiro Conversation & HITL | web | 07-02, 07-07 |
| 07-09 | Documents & Artifact Preview | web | 07-02, 07-03 |
| 07-10 | Testing, CI & Rollout (cutover from interim web) | web / CI | all |

**Critical path:** 07-02 unblocks everything data-dependent (conversation, graph,
docs, durable gate). 07-03 unblocks all screens. Start 07-02 and 07-03 in parallel,
then the screen specs, then testing/rollout.

**Milestone mapping:** this program is tracked as **M7.1** in the tracker (a
sub-series of M7), with one status-log entry per completed sub-spec.

---

## 9. Relationship to the interim workbench

The existing `genesis/web/` (React+TS, hand-rolled) is **superseded**. It stays on
`master` until 07-03/07-06 reach feature parity behind the new shell, then is
removed in a single cutover commit (`phase-07-10`). No user-facing URL breaks: the
new app serves the same same-origin routes and the FastAPI static-serving contract
is unchanged. Studio (`langgraph dev`) remains the developer debug path (ADR-023).

---

## 10. Decisions applied & opened

- **Applied:** ADR-012 (subprocess workers), ADR-021 (HITL gate classes), ADR-023
  (FastAPI-embedded, not LangGraph Server), ADR-024 (async-first), ADR-025 (fork),
  ADR-026 (React+TS, local single-user).
- **Opened:** **ADR-027 — Frontend stack** (Tailwind + shadcn/ui + React Router +
  TanStack Query + React Flow + Zustand). See decision-log.

---

## 11. Definition of done (program)

1. All `phase-07-0N` specs implemented and their per-spec DoD met.
2. Interim `web/` removed; new app is the only workbench; static bundle committed.
3. Every platform capability reachable from the UI: configure integration → install
   workflow → launch → **supervise live** (graph + conversation + HITL + docs) →
   review artifacts.
4. The HITL approval bug is impossible by construction (controls derive from durable
   state).
5. Vitest/RTL unit+component suites, MSW-backed; Playwright smoke E2E green;
   frontend CI job green; a11y checks pass.
6. Tracker + progress notes updated; ADR-027 recorded.
