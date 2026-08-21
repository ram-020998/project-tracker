# 27-02 — UX revamp & wireframes — DELIVERABLE

> **Phase 27 (UI/UX Revamp) · sub-phase 02.** Spec: `27-02-ux-revamp-and-wireframes.md`. Depends on: 27-01 (`27-01-findings.md`, ADR-055 Accepted).
> **Status:** 📋 **FOR REVIEW** (docs-only; no genesis code). **Date:** 2026-08-21. **Medium:** lo-fi ASCII wireframes (structure/hierarchy/flow only — no final color/type; those are the 27-03 hi-fi coded mockups). **Gate:** ⭐ **user review of this document before 27-03.**

## 1. Information architecture (revamped)

**Principle:** stay **Applications-first** (ADR-049) but fix wayfinding — expose the daily-work surfaces in a **persistent, labelled left nav**, add a **top app bar** (breadcrumbs + global search/command palette + theme + environment), and stop burying **Catalog** inside Settings.

```
Genesis
├─ Applications            (landing)      →  App detail → Feature → Spec builder
├─ Chat
├─ Runs                                    →  Run detail (Flow / Documents)
├─ Catalog   ⟵ promoted from Settings      →  Workflow detail → Launch
│   ├─ Workflows
│   └─ Skills
├─ Documents                               →  Document viewer
├─ Memory                                  (Graph / List / Review)
└─ Settings   (bottom)
    ├─ Overview (metrics)   ⟵ stays here (or a compact home summary — see Decision D2)
    ├─ MCP · CLI · GitLab · Environments · General (theme, Kiro, storage, copilot)
```

> **Open IA decisions for your review (the wireframe gate):**
> - **D1 — Promote Catalog to primary nav?** It's a daily launch surface; 27-01 flagged its dual home (standalone + Settings tab) as confusing. *Recommend: yes, promote to primary nav; remove the duplicate Settings→Catalog tab.* (Revisits ADR-049's "Catalog in Settings" — confirm.)
> - **D2 — Overview/metrics home?** Keep metrics only in Settings→Overview, **or** add a compact metrics strip to the Applications landing (a light "home" feel) without a separate Home route. *Recommend: keep Settings→Overview + add a small KPI strip atop Applications.*
> - **D3 — Nav default state:** expanded-with-labels by default (collapsible), replacing today's collapsed-by-default icon rail. *Recommend: expanded by default on ≥1280px, collapsible; icon-rail on smaller.*

## 2. Navigation model & shell regions

A **persistent left sidebar** + a **slim top app bar** (reintroduced — it was removed in Phase 24; it returns to carry breadcrumbs + search + global controls).

```
┌───────────┬───────────────────────────────────────────────────────────────┐
│  SIDEBAR  │  TOP APP BAR                                                     │
│ (240px,   │  ‹ Breadcrumbs: Applications › Orders › Checkout ›  [⌘K Search] │
│  collaps- │                                        [◑ theme] [env ▾] [⇪ upd] │
│  ible)    ├───────────────────────────────────────────────────────────────┤
│           │                                                                 │
│ ▣ Genesis │   PAGE CONTENT (Page: title + subtitle + actions, then body)    │
│  ● env    │                                                                 │
│           │                                                                 │
│ WORKSPACE │                                                                 │
│ ▸ Apps    │                                                                 │
│ ▸ Chat    │                                                                 │
│ ▸ Runs    │                                                                 │
│ ▸ Catalog │                                          [optional RIGHT RAIL]  │
│ ▸ Docs    │                                                                 │
│ ▸ Memory  │                                                                 │
│           │                                                                 │
│ ─────     │                                                                 │
│ ⚙ Settings│                                                                 │
│ ‹ Collapse│                                                                 │
└───────────┴───────────────────────────────────────────────────────────────┘
```

- **Sidebar:** brand + environment/health; grouped nav (labels visible by default); active state = tonal surface + accent left-marker; Settings + collapse pinned bottom.
- **Top app bar:** **breadcrumbs** (route-derived, deep-link aware); **global search / command palette (⌘K)** (jump to app/feature/run/doc + run actions); **theme toggle** (moved from Settings for one-click access; Settings keeps it too); **environment switcher** + **update indicator** (the `UpdateBanner`/preflight fold into an app-bar affordance instead of a stacked banner).
- **Content:** the existing `Page` (title/subtitle/actions + body) is retained + restyled; **right rail** standardized (used by Spec/Run inspectors/Memory).

## 3. Core user flows (unchanged behaviour, clearer path)

```
A. Onboard an application
   Applications ─[Add application]→ dialog(pick env app) ─→ card appears ─→ auto/again [Refresh]
   → App detail (Business Map default) ; live sync status chip → [view run]

B. Author a feature → spec  (the flagship flow)
   App detail › Features ─[New feature]→ Feature page (artifact pipeline)
   → [Build spec] → Spec builder:  full-width chat  ⇄  [Preview] full-screen annotate
        highlight → comment → queue (right rail) → [Send all to agent] → new revision reloads
   → spec actions (allowed-only) advance status ; [Export .md] / [Save milestone]

C. Launch & monitor a run
   Catalog › Workflows → Workflow detail ─[Launch]→ Launch form(schema) ─submit→ Run detail
   → Flow (Graph⇄List) + Inspector ; live/replay ; HITL prompt → respond ; Documents tab

D. Curate memory / documents
   Memory: Graph(explore) → click entity → List(scoped) → row → Inspector(edit) ; Review queue
   Documents: list → viewer (auto renderer: Rendered / Sheets / Source)

E. Configure
   Settings: Overview(metrics) · MCP · CLI · GitLab · Environments · General(theme/Kiro/storage/copilot)
```

## 4. Responsive & density strategy

| Breakpoint | Sidebar | Dense surfaces |
|---|---|---|
| **≥1280 (desktop, primary)** | expanded (labels) | split-panes side-by-side; graph + inspector both visible; multi-col card grids (3-up) |
| **1024–1279** | collapsible (default icon-rail) | 2-up grids; split-panes keep side-by-side at reduced ratio |
| **<1024 (narrow/tablet)** | overlay drawer (hamburger in app bar) | **split-panes → tabs** (e.g. Run-detail Graph *or* Inspector; Spec chat *or* Preview); 1-up cards; tab strips scroll horizontally |

- **Dense-data rules:** tables get sticky headers + horizontal scroll (never squish); graphs keep min-canvas + fit-to-view; tab strips overflow to a "More ▾" menu beyond N tabs (App-detail's 6, Settings' 7).
- **Content max-width** for reading surfaces (spec/doc/settings forms) to avoid over-wide line lengths; full-bleed for canvases (graphs, business map).

## 5. Interaction pattern library (lo-fi, reuse `feedback/states`)

- **Empty / Loading / Error / Not-found** — keep the `EmptyState`/`LoadingState`(skeleton)/`ErrorState`/`LoadingScreen` API; restyle in 27-03. Every list/detail wires all three.
- **Tables** — header (sort ▲▼), optional filter row, row hover, right-aligned numerics (tabular-nums), pagination or virtualized scroll; empty/loading variants.
- **Toolbars / action bars** — primary action right-aligned (filled), secondary as outline/ghost, overflow to a "⋯" menu (fixes Spec's 7-inline-control bar).
- **Dialogs vs sheets** — dialogs for confirm/short forms (destructive = danger + explicit confirm, per current Untrack pattern); right **sheet/rail** for inspectors + long context.
- **Tabs / segmented** — tabs for page sections; segmented for view-mode toggles (Graph/List, Memory views).
- **Feedback** — toasts for async results; inline `aria-busy` skeletons; optimistic where safe.
- **Command palette (⌘K)** — fuzzy jump (apps/features/runs/docs) + quick actions (new feature, launch, toggle theme).

## 6. Lo-fi wireframes (per surface)

### 6.1 Applications (landing)
```
Page: Applications        subtitle: Appian apps tracked locally         [+ Add application]
[optional KPI strip: Apps 12 · Objects 3.4k · Open features 7 · Runs today 4]   (Decision D2)
┌───── card ─────┐ ┌───── card ─────┐ ┌───── card ─────┐
│ ▣ Orders   v2.1│ │ ▣ Billing  v1.3│ │ ▣ CRM       —  │   (3-up ≥1280, 2-up md, 1-up sm)
│ uuid…          │ │ uuid…          │ │ uuid…          │
│ [obj][bnd][orf]│ │ [obj][bnd][orf]│ │ [obj][bnd][orf]│
│ Last sync ✓ 2h │ │ Last sync ✗    │ │ never synced   │
└────────────────┘ └────────────────┘ └────────────────┘
```

### 6.2 Application detail
```
‹ Applications › Orders                        [↻ Refresh]  [🗑]
Title: Orders    subtitle: uuid…    [sync-in-progress chip → view run]
[ Business Map | Overview | Syncs | Releases | Business Artifacts | Features ]  (overflow ▾ on narrow)
┌───────────────────────────── active tab body ─────────────────────────────┐
│  Business Map (React Flow, tokenized) / Overview KPIs + distribution+bundles│
└────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Feature page (artifact pipeline)
```
‹ … › Orders › Checkout                                   [status badge]
┌ Pipeline ───────────────────────────────────────────────┐  ┌ Activity ─────┐
│  ● Spec ──▶ ○ Design ──▶ ○ Breakdown                     │  │ • event  2h   │
│  [Open spec builder]     (stage cards w/ state + action) │  │ • event  3h   │
└──────────────────────────────────────────────────────────┘  └───────────────┘
```

### 6.4 Spec builder  (chat ⇄ full-screen annotate)
```
‹ … › Checkout › Spec        [+ Context] ······· [status] [actions▾] [Export][Milestone][👁 Preview]
┌──────────────────────── full-width chat (ChatThread, chrome=spec) ─────────────────────────┐
│  … streaming conversation …                                                                 │
│  [ composer ▸ ]                                                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
  Preview (dialog, 94vw): [ document iframe ................ ] │ Comments (queue) [Send all ▸] │
```

### 6.5 Chat
```
┌ Sessions ─────┐ ┌───────────────── thread ──────────────────┐
│ ▸ Session A   │ │  user … / assistant … (cards inline)       │
│   Session B   │ │                                            │
│ [+ New]       │ │  ────────────────────────────────────────  │
│               │ │  [ composer  | model▾ /cmds 📎 images  ▸ ] │
└───────────────┘ └────────────────────────────────────────────┘
```

### 6.6 Runs (list)
```
Page: Runs
┌ table ───────────────────────────────────────────────────────────────────┐
│ Status  Workflow        Run id     Started ▼   Duration   Credits   ▸      │
│ ✓ live  application-sync 3f9c…      2h          00:42      12        →      │
│ ⏳ run   generate-map     a12b…      just now    …          —         →      │
└────────────────────────────────────────────────────────────────────────────┘
```

### 6.7 Run detail
```
‹ Runs › application-sync  3f9c…  [copy]      [● Live]   [Graph|List]
[ Flow | Documents (n) ]
┌───────────── Graph (React Flow, tokenized) ─────────────┐
│                                                          │
├──────────────────────── split ──────────────────────────┤
│  Inspector: node io / conversation / HITL prompt→respond │
└──────────────────────────────────────────────────────────┘
  (narrow: Graph OR Inspector as tabs)
```

### 6.8 Catalog / Workflow detail / Launch
```
Page: Catalog   [ Workflows | Skills ]
┌ wf card ┐ ┌ wf card ┐ ┌ wf card ┐        → Workflow detail: meta + [Launch]
└─────────┘ └─────────┘ └─────────┘        → Launch form: schema fields + [Run ▸]
```

### 6.9 Documents library + viewer
```
Page: Documents      [+ Add]                    ‹ Documents › Q3 Plan.xlsx
┌ table: Title  Type  Source  Updated  ▸ ┐      ┌ viewer (auto: Rendered/Sheets/Source) ┐
└────────────────────────────────────────┘      │ [Sheet1|Sheet2]  grid …                │
                                                 └────────────────────────────────────────┘
```

### 6.10 Memory
```
Memory   [ Graph | List | Review ]   [🔎 find] [as-of ▤] [◻ show invalidated]     (right rail: Inspector)
┌──────────────── Graph (constellation → tokenized, light-aware) ─────────────┐ │ Inspector      │
│   ✦ entities/relationships ; hover-highlight ; drag-pin ; zoom               │ │ edit / actions │
└──────────────────────────────────────────────────────────────────────────────┘ │                │
  List: scoped table of memories · Review: curation queue                         └────────────────┘
```

### 6.11 Settings
```
Page: Settings
[ Overview | Catalog* | MCP | CLI | GitLab | Environments | General ]   (*removed if D1=promote)
┌ active section (cards/forms; General: Appearance[theme] · Kiro · Storage · Copilot) ┐
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## 7. Carry-forward fixes (from 27-01, realized here)
- Tokenize React-Flow theming (business-map, run-graph) — retire the `index.css` global overrides.
- Reconcile the memory constellation to be token-driven / light-aware.
- Group dense action bars (Spec, Run-detail header) with overflow menus.
- Add breadcrumbs + command palette + expanded nav (wayfinding).
- Close a11y gaps + refine `fg-subtle` contrast (carried to 27-03 palette + 27-11 audit).

## 8. Handoff → 27-03 (hi-fi mockups)
On approval of this IA/nav/flows/wireframe set (and D1–D3), 27-03 produces the **coded, light-first hi-fi mockups in `/dev`** for every surface above + the finalized token/type/elevation/motion spec + the component redline map.
