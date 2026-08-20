# Genesis — UI Screen Catalog & UX Brief (for LLM-assisted redesign)

> **Purpose.** A complete, per-screen description of the Genesis web application — every page, what it's for, who uses it,
> its layout/regions, the data it shows, its interactions, its states, and the UX intent — written so you can hand any one
> section to a design LLM and get a faithful, well-grounded redesign. Grounded against the live app (routes in
> `web/src/app/router.tsx`, features in `web/src/features/**`, chrome in `web/src/shared/layout/**`) as of genesis v0.51.4.
> **Read Part A first** (it applies to every screen), then the screen you're designing in Part B.

---

# PART A — Foundations (apply to every screen)

## A1. What Genesis is (context for tone + density)
Genesis is a **local, single-user desktop-class web app** (runs at `127.0.0.1:8760` in the browser) that lets an Appian
**Solutions engineer** discover, run, and supervise **agentic SDLC workflows**, chat with an AI agent, manage an internal
**Appian knowledge base** (Applications), author **feature specs**, and curate **business documents**. It is a **professional
power-tool**, not a consumer app: information-dense, keyboard-friendly, fast, calm. Think "enterprise developer console"
(GitHub/Linear/Vercel-dashboard energy), not marketing site.

## A2. Personas (who is on each screen)
- **Developer** — runs workflows (code review, ERD, sync), inspects runs, chats with the agent for build help.
- **PO / Business analyst** — authors feature specs in chat, reads the Business Map, curates documents.
- **UX designer** — discusses/creates mockups via chat, reads specs.
- **Tester** — inspects runs, shares knowledge via chat.
All are the **same single local user** today (no login, no multi-tenant) — so **no account/permission UI**; optimize for one
expert user doing deep work, not onboarding a crowd.

## A3. Visual language & design system (the house style)
- **Overcut-inspired, dark-first.** Default theme is **dark** (`theme-dark`); a **light** theme exists (toggle in Settings →
  General). Calm, low-chrome, high-contrast-where-it-matters, generous whitespace, subtle borders over heavy shadows.
- **Design tokens (never raw hex).** Surfaces layer as `surface-1` (sidebar/base) → `surface-2` (cards/hover) → `surface-3`
  (active/raised); text as `fg` / `fg-muted` / `fg-subtle`; hairline `border` / `border-strong`; brand **`primary`** is a
  **blue→purple gradient** (`#6d8bff → #b892ff`). Rounded radii (cards ~`rounded-lg`, controls ~`rounded-md`), fast motion
  (`duration-fast`/`duration-base`), reduced-motion-safe.
- **Brand mark.** `GenesisLogo` = a rounded blue→purple gradient tile with a geometric white **"G" monogram**. The app-wide
  loader is a **standard spinner ring** around the static mark.
- **Component library** (shadcn/Radix-style primitives in `shared/ui/**` — compose these, don't reinvent): Button, Card, Badge,
  Chip, Dialog, Drawer, Tabs, SegmentedControl, Switch, Input/Field/Textarea, **HealthDot** (status dot), **MetricCard**,
  **TrendChart**, **CreditBadge/Coins**, icons via a curated **lucide** re-export. Graphs use **React Flow (@xyflow/react) +
  dagre**; charts use **Recharts**; markdown via **react-markdown + remark-gfm**; diagrams via **mermaid** (lazy); JSON via
  **CodeMirror**; toasts via **sonner**.
- **Accessibility is a requirement** (WCAG-minded): labelled controls, `aria-*`, keyboard operability, visible focus, and
  automated **jest-axe** checks. Any redesign must keep this.

## A4. App chrome & layout (the frame around every screen)
- **AppShell = a collapsible left Sidebar + a content area. There is NO top bar and NO breadcrumbs** (both were deliberately
  removed). The screen owns its own header.
- **Sidebar** (`264px` expanded / `64px` collapsed, collapse toggle at the bottom, persists collapsed by default):
  - **Brand block** (top): the G logo + "Genesis" + a **HealthDot + the active environment name** (e.g. "Production" / "None").
  - **Workspace nav group** (the only primary group): **Applications · Chat · Runs · Documents** (icons: app-window, messages,
    rocket, file). Active item = `surface-3` fill.
  - **Bottom**: **Settings** (gear) + the collapse chevron.
- **Landing:** `/` redirects to **`/applications`**.
- **Content area** patterns: a **Page** header (title + optional actions), and where master-detail is needed a **SplitPane**
  (list/nav on the left, detail on the right). Full-screen viewers (document/spec) break out of the split.

## A5. Universal states (design all three for every screen)
- **Loading** — a branded spinner (`LoadingScreen` for full-page; inline skeletons/spinners for regions). Never a blank flash.
- **Empty** — an `EmptyState` with an icon, a one-line explanation, and the **primary next action** (e.g. "No applications
  yet — Add your first application").
- **Error** — an `ErrorState` (icon + human message + retry); API failures surface as toasts for transient actions.
- **Live/streaming** — runs + chat stream via SSE; show "thinking"/progress and settle on a terminal state (don't spin forever).

## A6. Cross-cutting UX principles (the bar for the redesign)
Density with hierarchy · fast perceived performance (optimistic where safe, skeletons otherwise) · everything important is
**deep-linkable** (URLs carry state: tab, selected node, doc) · destructive actions are confirmed · real data only (credits,
counts are metered/real — show honest "n/a", never fake) · consistency over novelty (reuse the primitives + tokens).

---

# PART B — The screens

> Each screen below is self-contained: **Route · Purpose · Persona · Layout & regions · Key components · Data shown ·
> Interactions · States · UX notes.** Hand any one block to your design agent.

## B1. Applications (list) — the landing page
- **Route:** `/applications` (also `/`). **Persona:** all. **Source:** `features/applications/ApplicationsPage.tsx`.
- **Purpose:** the home base — the list of Appian applications whose knowledge base Genesis tracks; entry point to add/track a
  new app and to open an app's workspace.
- **Layout & regions:** a Page header ("Applications") with a primary **"Add application"** button; a **grid/list of
  application cards**. Each card: app name, a few KB stats (object count, last sync, current release), a health/sync indicator,
  and a click target → the app detail.
- **Key components:** application cards (MetricCard-like), Add button → **AddApplicationDialog** (pick an untracked app from the
  dev environment via the Dev MCP, or enter a UUID; kicks a baseline sync), HealthDot for sync state.
- **Data shown:** tracked applications + summary counts; the list of *available* (untracked) apps for the add dialog.
- **Interactions:** add/track an app → baseline sync starts; click a card → app detail; (a sync may be in progress → show status).
- **States:** empty ("No applications yet" + Add CTA); loading (skeleton cards); error; a per-card "syncing…" state.
- **UX notes:** this is the **first thing every user sees** — make the "add your first application" path obvious, and make an
  app card scannable (name + freshness at a glance). Syncing apps should feel alive but not noisy.

## B2. Application Detail — the app workspace (tabbed)
- **Route:** `/applications/:appUuid`. **Persona:** all. **Source:** `features/applications/ApplicationDetail.tsx`.
- **Purpose:** everything about one application, organized as tabs.
- **Layout & regions:** a Page header (app name + a **Refresh** action [re-sync] + an untrack/remove action); a **tab strip**:
  **Business Map · Overview · Syncs · Releases · Business Artifacts · Features**. (Objects/Bundles tabs were removed — keep the
  set lean.) A live **SyncStatus** strip appears only while a sync is running.
- **Tabs:**
  - **Business Map** (the hero) — see B2a.
  - **Overview** — KB summary: object counts by type, dependency/coverage summary, bundle index, last sync + current release.
  - **Syncs** — history of sync runs (baseline/refresh), each linking to its run.
  - **Releases** — user-tagged KB releases (point-in-time snapshots).
  - **Business Artifacts** — the documents linked to this app — see B2b.
  - **Features** — the app's features — see B2c.
- **States:** a not-yet-synced app (Business Map/Overview empty → "run a sync"); syncing; error.
- **UX notes:** tabs must be deep-linkable; the header's Refresh should show progress and disable while running. Business Map is
  the tab users will live in — default to it when data exists.

### B2a. Business Map view (inside Application Detail)
- **Source:** `features/applications/business-map/**` (React Flow + dagre). **Purpose:** an **agent-synthesized, business-language
  map** of what the app does — explicitly **not** a technical/object view (no objects/bundles/pages vocabulary).
- **Two lenses:** **(A) Value Stream** (a left→right staged flow with decision branches) and **(B) Capability Constellation** (a
  radial domain→capabilities view with entities as chips inside capability cards).
- **Layout:** a full-canvas React Flow graph with a **MiniMap**, pan/zoom (a readable zoom floor so nodes aren't microscopic),
  `smoothstep` edges + arrowheads, and a lens switch (A/B). **Click a node → a detail popup** (compact cards; full text in the
  popup, not truncated on the node).
- **Interactions:** switch lens, pan/zoom, click-for-detail, focus+context linking; a **Generate/Regenerate** action (runs the
  `generate-business-map` workflow; friendly "install/again" states, not a 500).
- **States:** not generated ("Generate the business map"); generating (progress); generated; stale (after a sync).
- **UX notes:** readability is everything here (a real app has ~10–15 stages / ~10 capabilities) — level-of-detail over
  fit-to-screen; keep business language, ban technical terms.

### B2b. Business Artifacts tab
- **Source:** `features/library/BusinessArtifactsTab.tsx`. **Purpose:** the documents (PDF/Docx/Sheets/Drive) linked to this app,
  used as business context for specs/design.
- **Layout:** a table/list of linked documents (name, type, source [upload/Drive], last synced) + actions: **Add** (upload or a
  Google-Drive link, multi-pick), **unlink**, **sync**. Rows link to the full-screen document viewer (B9).
- **UX notes:** "add via Drive link" auto-syncs; show sync freshness; unlink ≠ delete (it just unlinks from this app).

### B2c. Features tab
- **Source:** `features/features/FeaturesTab.tsx` + `CreateFeatureDialog.tsx`. **Purpose:** the app's **features** (the unit of
  work an engineer develops).
- **Layout:** a list of feature cards (name, description, created) + a **Create feature** button (dialog). A card → the Feature
  page (B3).
- **UX notes:** the card is a launchpad into the artifact pipeline; keep it simple (no status noise on the card).

## B3. Feature Page — the artifact pipeline
- **Route:** `/applications/:appUuid/features/:featureId`. **Persona:** PO, UX, Dev. **Source:** `features/features/FeaturePage.tsx`
  + `ArtifactPipeline.tsx` + `ActivityFeed.tsx`.
- **Purpose:** a feature as a **pipeline of sequential artifact stages** — **Spec → Design → Breakdown → …** — each artifact card
  carrying its own status. Landing here shows the pipeline, not the editor.
- **Layout & regions:** a Page header (feature name); the **artifact pipeline** = a row/column of **artifact cards**: **Spec**
  (functional: **Edit** → the Spec Builder B4, **View** → read-only preview), **Design** + **Breakdown** as **disabled
  placeholders** (future); an **Activity feed** (lifecycle events — created/started/submitted/approved) alongside.
- **Interactions:** open the Spec in Edit (builder) or View (read-only annotated preview); allowed **lifecycle actions** render
  as the only enabled buttons (state-machine driven; illegal actions simply aren't offered).
- **States:** no spec yet (empty → "Create spec"); spec in draft/in-progress/in-review/completed; design/breakdown disabled.
- **UX notes:** the pipeline metaphor should read as a **progression**; disabled future stages should look intentional
  ("coming next"), not broken.

## B4. Spec Builder — chat-authored, annotatable spec
- **Route:** `/applications/:appUuid/features/:featureId/spec`. **Persona:** PO (primary), UX. **Source:**
  `features/features/SpecBuilderPage.tsx` + `SpecWorkspace.tsx`.
- **Purpose:** author a feature **spec** conversationally with the agent, then review it in an **embedded, annotatable** preview.
- **Layout & regions:** a **full-width chat** (`ChatThread` with `chrome="spec"` — no copilot banner) on one side; an on-demand
  **full-screen annotatable Preview** popup showing the rendered spec (HTML-authoritative) with a **comment/annotation rail** +
  a single **"Send all"** to push comments back into the chat. An **"Add context"** action injects the app's linked business
  artifacts as files the agent can read; **status** control (draft→in-progress→in-review→completed) + **milestone** snapshots +
  **Export .md**.
- **Interactions:** chat to author/revise; open Preview; **highlight a passage → comment → it flows into the chat** as a
  revision request; save milestones; export markdown.
- **States:** empty (new spec); authoring (agent writing); review (annotating); exporting.
- **UX notes:** this is a **two-mode workspace** (converse ⇄ review) — the transition to the full-screen annotate view must be
  smooth; the annotation→chat bridge is the signature interaction (make it feel connected, not like two apps).

## B5. Chat — the agent workspace (assistant + copilot + skills)
- **Route:** `/chat` and `/chat/:sessionId`. **Persona:** all. **Source:** `features/chat/ChatPage.tsx` + `ChatThread.tsx` +
  `Composer.tsx` + `SessionList.tsx` + `cards.tsx` + `LaunchDialog.tsx`.
- **Purpose:** the conversational surface — ask the agent (read-only assistant), **launch + supervise workflow runs** (copilot),
  and invoke **skills**. Persisted, resumable sessions.
- **Layout & regions:** **SplitPane** — left: **SessionList** (past sessions, new-session button, per-session mode); right: the
  **ChatThread** (turn-grouped conversation: user/agent messages, a collapsible **Thinking** timeline, tool calls, markdown
  answers, a per-message **credit** footer) + the **Composer** at the bottom.
- **Composer (rich):** multi-line input; a **model selector** (chosen at session creation); a **`/` command palette** (slash
  commands + a unified **Workflows + Skills** menu with client-side autocomplete); **image attach**; a **context-usage +
  compaction meter**; **Clear/Compact** actions; **Export transcript (.md)**.
- **In-chat cards (copilot):** a **LaunchDialog** (schema-driven inputs to start a workflow), a **permission-confirm card** (every
  mutating action is human-confirmed), a **gate card** (respond to a workflow HITL gate), a **terminal card** (run finished), and
  a **supervised-runs strip** (live status of runs this session launched). **SessionOutputs** renders any files a skill wrote.
- **Interactions:** send/stream a turn; run a slash command; pick a workflow → fill inputs → confirm → launch → the agent
  **supervises** it and surfaces gates/results proactively; confirm/deny permission prompts; attach images; clear/compact/export.
- **States:** no sessions (empty + "New chat"); streaming ("thinking"); awaiting a permission/gate confirm; run terminal;
  error/stale-auth (a "sign in to Kiro" hint if the agent isn't authed).
- **UX notes:** this is the most interaction-dense screen — the **turn grouping** + **collapsible thinking** keep it readable;
  confirm cards must be unmistakable (nothing mutates without a click); the composer should feel like a modern CLI/agent chat
  (Kiro/Claude-Code parity). Spec-builder chat reuses this thread with a slimmer chrome.

## B6. Runs — the run list & history
- **Route:** `/runs`. **Persona:** Dev, Tester. **Source:** `features/runs/RunsPage.tsx` + `components/RunsTable.tsx`.
- **Purpose:** all workflow runs (active + historical) with status and quick actions.
- **Layout & regions:** a Page header ("Runs") + filters (status, workflow); a **table** of runs — workflow name, status badge,
  started/duration, credits, and quick actions (open, cancel). Live status updates.
- **Data shown:** run id, workflow, status (pending/running/awaiting_input/done/failed/cancelled), timing, credits.
- **Interactions:** filter; click a row → Run Detail (B7); cancel a running run; (launches happen from Catalog/Chat, not here).
- **States:** empty ("No runs yet"); loading; live-updating rows; terminal rows.
- **UX notes:** status must be instantly legible (color + label + HealthDot); "awaiting input" should stand out (it needs the
  user). Keep it a fast scan-and-drill table.

## B7. Run Detail — graph, conversation, HITL, documents, telemetry
- **Route:** `/runs/:runId` (+ `/node/:nodeId`, `/docs/:docName`). **Persona:** Dev, Tester. **Source:**
  `features/run-detail/RunDetailPage.tsx` + `graph/**` + `components/**` (Inspector, Timeline, HITL, docs).
- **Purpose:** observe and steer a single workflow run end-to-end.
- **Layout & regions:** a Page header (workflow + run status + **run-total credits** + pause/resume/cancel); a **SplitPane**:
  - **Left/center — the graph** (`RunGraph`, React Flow): nodes = workflow steps colored by state (done/running/failed/awaiting);
    a fallback layout from `/steps` if no topology is declared; a **NodeListView** alternative.
  - **Right — the Inspector** (tabbed): the selected node's **Kiro conversation** (turn-grouped: messages, **Thinking** timeline,
    tool calls, validator/retry notes, the node **result** + per-node **credits/context%**), plus a **Documents** drawer
    (artifacts the run produced, with rendered previews — B9 renderers), and a **Timeline** of events.
  - **HITL** — when the run is at a gate: an approval/escalation/pre_mutation panel (approve/reject/edit-state/fork), driven from
    **durable state** (not transient events).
- **Interactions:** click a node → inspector; scrub the timeline; expand thinking; open a document; **respond to a gate**;
  **pause/resume/cancel**; **fork** from a checkpoint; live SSE streaming that stops cleanly on terminal.
- **States:** running (live, thinking, streaming); awaiting input (gate panel prominent); done/failed (final); the "no topology →
  derived graph" fallback (never a blank graph).
- **UX notes:** the graph is the map, the inspector is the story — keep them **linked** (selecting a node drives the inspector,
  and the URL). The gate experience must be obvious and safe. Credits are real — show per-node and run-total honestly.

## B8. Documents (Library) — the global document store
- **Route:** `/documents`. **Persona:** PO, UX, Dev. **Source:** `features/library/LibraryPage.tsx` + `DocumentTable.tsx` +
  `AddDocumentDialog.tsx`.
- **Purpose:** the global library of business documents (PDF/Word/Excel/CSV/Markdown/Google-Drive), dedup'd and linked into apps.
- **Layout & regions:** a Page header ("Documents") + **search + filters** + an **Add** button; a **table** of documents (name,
  type, source [upload/Drive], **linked apps**, last synced, size). Rows → the full-screen viewer (B9).
- **Interactions:** search/filter; **Add** (upload a file, or paste a Google-Drive link — Drive docs auto-sync); **link** to an
  app; **sync** (single / per-app / whole library); **remove**. 
- **States:** empty ("Add your first document"); loading; syncing; error.
- **UX notes:** the "linked apps" column is the connective tissue — make it scannable; adding via Drive should feel one-step.

## B9. Document Detail — the full-screen viewer
- **Route:** `/documents/:id`. **Persona:** all. **Source:** `features/library/DocumentDetailPage.tsx` + `SpreadsheetView.tsx` +
  `documents/renderers/**` (Markdown, Mermaid, CSV, JSON, CodeBlock).
- **Purpose:** read a parsed document, full-width.
- **Layout & regions:** a full-width viewer (breaks out of the split) with a header (doc name, source, back). The **renderer is
  auto-selected by type**: **Sheets** (an Excel-like sheet-tab strip + paged grid, for tabular docs with a `tables_path`),
  **Rendered** Markdown (default for prose), or raw **Source** (`<pre>`) as a safety net for very large non-tabular docs (so it
  never freezes the tab).
- **Interactions:** for spreadsheets, switch sheet tabs + page through rows (100/page) + horizontal scroll; scroll long docs.
- **States:** loading; large-doc guarded rendering; error.
- **UX notes:** performance is a first-class UX concern here (big spreadsheets/markdown must open instantly) — the auto-selection
  exists to avoid main-thread hangs; keep wide tables horizontally scrollable, not clipped.

## B10. Settings — the configuration & workspace hub
- **Route:** `/settings/:tab/:id?`. **Persona:** Dev/admin-of-self. **Source:** `features/settings/SettingsPage.tsx` +
  `components/**`. **Structure:** a Tabs shell with two zones —
  - **Workspace zone:** **Overview** (default tab, B10a) · **Catalog** (B10b).
  - **Configuration zone:** **MCP** · **CLI** · **GitLab** · **Environments** · **General**.
- **Layout & regions:** a left tab rail (or top tabs) + a detail pane; most config tabs use the standardized **master-detail +
  add/edit** pattern (`ResourceManager` list ⋈ detail, `ResourceFormDialog`, `ConfirmDialog`).
- **Configuration tabs:**
  - **MCP** — curated (read-only) + custom (editable) MCP servers; per-server status (HealthDot), secret fields, tool
    allowlist, **Test connection**; a managed-native **Appian MCP servers** install/rollback panel.
  - **CLI** — CLI connectors incl. the **Google Workspace (`gws`)** connector card (connect/auth).
  - **GitLab** — the GitLab token for pulling the workflow library.
  - **Environments** — the Appian environment registry: add/edit environments, per-env **credentials** (username/password/API
    key), a single-select **"dev" toggle** + a **dev** badge + **Test connection**.
  - **General** — **Appearance** (theme toggle), **Storage/Retention**, **Copilot** settings (kill-switch, limits, audit),
    **Kiro sign-in** (device-flow login/logout + status), and a **Metrics** section (system metrics).
- **Interactions:** CRUD config resources through dialogs; test connections; toggle theme; sign in to Kiro; set the dev env.
- **States:** each resource list has empty/loading/error; connection tests show pass/fail; secrets show `is set` (never values).
- **UX notes:** this is a **power-user config surface** — the master-detail consistency is the point; secrets must never be
  echoed; connection tests + health dots give confidence. Keep the two zones (Workspace vs Configuration) visually distinct.

### B10a. Overview (Settings tab) — the metrics dashboard
- **Source:** `features/overview/OverviewPage.tsx`. **Purpose:** at-a-glance system health + activity.
- **Layout:** a grid of **MetricCards** (e.g. **Credits Used** KPI, run counts) + a **TrendChart** + integration health. (Active-
  runs + Installed-workflows sections were trimmed.)
- **UX notes:** dashboard-style; real metered numbers with honest "n/a"; make the KPI row skimmable.

### B10b. Catalog (Settings tab) — workflows & skills
- **Route:** `/catalog`, `/catalog/skills`, `/catalog/:workflowId`, `/catalog/:workflowId/launch`. **Source:**
  `features/catalog/**`. **Purpose:** browse/install/launch **Workflows** and **Skills**.
- **Layout:** a **Workflows | Skills** sub-tab shell; a grid of **WorkflowCard**/**SkillCard** with **prereq badges**; a
  **WorkflowDetail** page (description, inputs schema, prereqs, graph preview) with **Launch**; a schema-driven **LaunchForm**
  (renders typed inputs incl. **file drop** inputs); **SkillsTab** with a **Skill author** dialog (author a SKILL.md +
  scripts/references).
- **Interactions:** browse/filter; install/update/remove; open detail; **launch** (fill inputs → start a run → jump to Run
  Detail); author/install a skill.
- **States:** empty catalog; not-installed vs installed; launching.
- **UX notes:** cards must show **prerequisites + install state** clearly; the launch form is schema-driven so it must handle
  varied input types gracefully (text, enum, boolean, file).

## B11. System overlays (global, not routes)
- **Update banner** (`features/system/UpdateBanner.tsx`) — appears in the shell when a new release tag is available;
  one-click **Update** (checkout → install → migrate → restart). Only on managed installs.
- **Preflight checklist** (`features/system/PreflightChecklist.tsx`) — a first-run/dismissible modal listing readiness items
  (Kiro signed in, DB migrated, health OK; optional: dev env, uv, gws) with **Fix →** links.
- **Toasts** (sonner) — transient success/error feedback for actions across the app.
- **UX notes:** these are **ambient/att-attention** surfaces — informative, dismissible, never blocking the daily work.

## B12. Upcoming (design-ahead) — Memory (Phase 26, spec'd, not built)
Two new surfaces are specified (see `specs/phase-26-agentic-memory-layer/26-08-…`): a **Memory workspace** — a rich, accessible
browser to see + edit the agent's memory, centered on an **Obsidian-style force-directed memory graph** (entities +
relationships; hover-highlight, local-graph focus, search/filters, a bi-temporal time-scrubber, community coloring) alongside a
**list/table workbench**, an **inspector editor**, and a **review queue** — plus a per-application **"Memory" tab** and a
**Settings → "Your Memory"** panel. Worth designing in the same language now so it lands cohesively.

---

## Appendix — how to drive a design LLM with this
For each screen, give the agent: **Part A** (foundations — once), then the screen's block, plus this instruction: *"Design this
screen for a local single-user, dark-first, information-dense professional tool. Use the token system + primitives in A3, the
shell in A4, and design the loading/empty/error states in A5. Prioritize the persona and the primary action named in the block.
Keep it consistent with the other screens — reuse patterns, don't invent."* Then iterate per region.
