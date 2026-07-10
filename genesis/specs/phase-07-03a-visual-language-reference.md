# Phase 7.3a — Visual Language Reference (Overcut-inspired, Genesis-innovated)

> **Goal:** Capture the concrete design language derived from a first-hand study of
> the Overcut app (agents/dashboard/executions/mcp/skills/agent-roles/workflows-
> builder/audit screens) and define how Genesis **takes inspiration and innovates on
> top of it** — not replicates it. This is the visual north star that `phase-07-03`
> (design system) implements and every screen spec (04–09) cites. It supersedes the
> generic direction in `phase-07-01 §6` and `phase-07-03` where they differ.

Source: 19 annotated screenshots of the Overcut app (provided 2026-07-10). We
borrow the *vocabulary*; the *experience* is Genesis-specific (our hero is the live
run, which Overcut does not have).

---

## 1. What Overcut does well (adopt the vocabulary)

1. **App shell** — a ~280px **left sidebar**: workspace tile + name + gear at top, a
   **project switcher** dropdown, a small row of utility icons, then nav grouped
   under **small-caps section headers** (Overcut: MONITOR / BUILD / PROJECT), and a
   user avatar + utility icons in the footer. A **top bar** with a breadcrumb-style
   page title, an action pill, and a **persistent agent chat input** with a
   collapsible **right rail** toggle.
2. **Near-black, dark, calm surface** — app background ~#0B0C0E, cards ~#141619 with
   a 1px hairline border (~#232629), ~12px radius, generous padding. Mostly
   monochrome with restrained color; color carries **meaning** (status).
3. **Metric cards** — small icon + label, then an **oversized display numeral**
   (huge, condensed), then a sub-stat with a trend (e.g. "100% · 1/1 successful",
   "↗ 100% vs previous"). Laid out in a responsive 3-up grid.
4. **Dashboard controls** — a **segmented control** for date range (Today / Last 7 /
   30 / 90 / This Month) and **group-by** (Day/Week/Month), plus an **"auto-
   refreshing in Ns"** chip and trend **line charts**.
5. **Master-detail config** — a left **list panel** ("N items", "+ Add", search, rows
   with a **status dot**) beside a right **detail form** with a header showing the
   name + a **status pill** (● Active green / ● Inactive red) and **Delete / Saved**
   controls; sectioned form (General, Configuration, Allowed Tools, Secrets…).
6. **Catalog** — search + **category filter chips** (All / Communication / Data / …)
   + a **card grid** (logo, name, 2-line description, Install link) + "Add Custom".
7. **Node-canvas builder** — a left **palette rail** of node-type icons, a center
   **DAG canvas** of **node cards** (title bar with icon, then config-summary lines,
   colored agent dots), zoom/fit/lock controls, and a right **config panel**;
   Publish / Compare / Discard toolbar. Detail has **sub-tabs** (Dashboard / Builder
   / Memories / History).
8. **Lists** — tables with a removable **filter chip** ("Status Active ✕"), "Add
   filter", a **count + pagination**, auto-refresh, **status pills** (Completed,
   Draft, Create/Update/Soft-Delete color-coded), and **tool chips** with a "+N"
   overflow.
9. **Signature type** — oversized, slightly condensed **display numerals** for
   metrics; clean sans for everything else; mono for config/JSON/logs.

## 2. Where Genesis innovates on top (do NOT replicate)

Overcut is **agent-configuration-centric**; Genesis is **run-supervision-centric**.
Our differentiators:

1. **The live run is the hero.** Overcut's execution view is a table row +
   "View Details". Genesis's Run Detail is a **live graph** with per-node status, a
   current-node pulse, and a **timeline scrubber** — a richer surface than anything
   in Overcut.
2. **Per-node Kiro conversation.** Overcut has a single *global* agent chat docked in
   the top bar. Genesis binds the conversation to the **selected workflow node** — you
   click `fetch_schema` and see exactly what Kiro did *there* (messages, thoughts,
   tool calls, validation). This is our marquee feature and a genuine step beyond.
3. **HITL as a first-class control surface.** Approve / reject / feedback / pause /
   resume / edit-state / fork, surfaced from durable gate state — Overcut has no
   equivalent human-in-the-loop control plane.
4. **Document preview drawer** tied to the run's artifacts.
5. **Genesis nouns, not Overcut's.** We reuse the *grouping idea* but our nav is:
   **MONITOR** (Overview, Runs) · **LIBRARY** (Catalog) · **CONFIGURE** (Integrations,
   Environments) · **SETTINGS**. Genesis is **local single-user** — no workspace/
   project multi-tenancy, no "Upgrade" billing, no agent-roles/skills authoring
   (those are Overcut's model; ours is installed *workflows*).
6. **Optional Genesis Copilot dock (future/innovation).** We may adopt Overcut's
   persistent-assistant idea as a *run-aware* copilot ("explain this failure",
   "summarize this run") — but scoped as a **later** enhancement, reserving the top-
   bar right-rail slot for it now without building it (keeps local single-user posture).

## 3. Concrete design decisions for Genesis (implemented in phase-07-03)

### 3.1 Shell
- Left sidebar (collapsible), grouped nav with small-caps section labels; a Genesis
  brand tile + a compact **environment/health indicator** where Overcut shows the
  project switcher (we have no projects — show active environment + overall health
  dot instead); footer = theme toggle + version + reserved copilot/user slot.
- Top bar: breadcrumb page title (from route handles) + a contextual **right-rail
  toggle** (used by Run Detail's inspector/docs, and reserved for the future copilot).
  No "Upgrade" pill.

### 3.2 Tokens (refine phase-07-03 §2 to these observed values)
- `--bg #0B0C0E`, `--surface-1 #141619`, `--surface-2 #1B1E22`, `--surface-3 #22262B`,
  `--border #232629`, `--border-strong #2E3339`.
- `--fg #F2F4F7`, `--fg-muted #9BA3AE`, `--fg-subtle #6B727C`.
- Accent primary a calm indigo/blue `--primary #6D8BFF` (Genesis identity; Overcut is
  near-monochrome — a restrained brand accent is our differentiator, used sparingly).
- Status: success `#3FB950`, warning `#D29922`, danger `#F85149`, info `#58A6FF`,
  neutral `#6B727C` — each with a `-subtle` translucent background for pills.
- Radius: cards `12px`, controls `8px`, pills `999px`. Hairline borders do the
  separation; shadows are minimal in dark.
- **Display numerals**: a condensed/tabular weight for metric values (e.g. the giant
  "32.4s"/"70.2K" treatment) — define a `.metric-value` type token.

### 3.3 New/confirmed components (add to phase-07-03 §4)
- **MetricCard** (icon + label + oversized value + sub-stat/trend).
- **SegmentedControl** (date-range, group-by, view toggles).
- **DateRangeControl** + **GroupByControl** + **AutoRefreshChip**.
- **MasterDetailLayout** (list panel + detail form + status-pill header + Save/Delete).
- **StatusDot** (active/inactive/running) + **StatusPill** (already planned) +
  **ActionPill** (Create/Update/Delete style for any audit/log surface).
- **FilterChip** (removable) + **FilterBar** (search + chips + "Add filter").
- **ToolChipRow** (tool chips + "+N" overflow) — for node/agent capability display.
- **CategoryChips** (catalog filtering).
- **NodeCard** (React Flow custom node: title bar w/ kind icon + status + config-
  summary lines + counters/dots) — the Overcut node-card aesthetic applied to our
  live run graph.
- **TrendChart** (Recharts line/area with the dark axis + hover tooltip treatment).
- **RightRail / Drawer** with a top-bar toggle.

### 3.4 Patterns per screen (thread into 04–09)
- **Overview (07-01 §7):** MetricCards (Total Runs, Success Rate, Avg Duration,
  Currently Running, Total Tokens) + DateRange/GroupBy + AutoRefreshChip + TrendCharts
  + an integrations-health strip. (Genesis adds an **active-runs** strip up top.)
- **Settings (07-04):** MasterDetailLayout for MCP/CLI — list (status dots) + detail
  form (General / Configuration / Allowed-Tools toggles / Secrets) with a status pill
  + Save state. Overcut's exact MCP-detail structure maps 1:1 to our mcp-cards.
- **Catalog (07-05):** search + CategoryChips + card grid + Install; workflow detail
  with **sub-tabs** (Overview / Graph / Runs).
- **Runs (07-06):** FilterBar (removable chips) + AutoRefreshChip + count/pagination
  + table (Started / Workflow / Trigger / Current node / Duration / Tokens / Status
  pill / Actions) — mirrors Overcut's Executions table, plus our progress bar.
- **Run Detail (07-07/08/09):** Genesis-original — live NodeCard graph + node
  inspector (per-node conversation) + HITL bar + docs drawer + a per-run **dashboard
  sub-tab** using MetricCards (Overcut's per-workflow dashboard aesthetic, applied to
  a single run's telemetry).

## 4. Definition of done (this reference)
1. `phase-07-03` tokens + component inventory updated to §3 (this doc is the source of
   truth for visuals).
2. `phase-07-01 §6` visual direction + §4.3 shell/nav + §7 overview updated to the
   Overcut-derived shell (grouped sidebar, top-bar breadcrumb + right-rail, metric-
   card dashboard) — adapted to Genesis nouns.
3. Screen specs 04–09 reference the patterns in §3.4.
4. The Genesis innovations in §2 remain the explicit differentiators (live graph,
   per-node conversation, HITL, docs preview) — we do not reduce Genesis to an
   Overcut clone.
