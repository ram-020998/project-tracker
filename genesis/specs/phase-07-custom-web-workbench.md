# Phase 7 — Custom Web Workbench UI

> **Goal:** Replace the interim LangGraph Studio surface with Genesis's own
> **web workbench** — the product surface a Solutions engineer logs into to
> discover, install, configure, run, and supervise workflows. Built on the
> backend APIs from Phases 3–5. This is the one explicitly-deferred piece from
> Q13/Q6.

Prereq: Phases 3 (catalog/install APIs), 4 (config APIs), 5 (run/HITL/stream APIs).

---

## 1. Objective & success statement

A single local web app (Q6) presents: a **Catalog** (browse/filter by role,
install/update/remove, bundles), a **Config** area (GitLab token, MCP secrets,
environments, health), a **Run** experience (start with typed inputs, live step
timeline, agent tool-call activity, artifacts viewer), and full **HITL** controls
(approve/reject/feedback at gates, pause/resume anywhere, view+edit state, fork).
No dependency on Studio.

---

## 2. Scope

**In scope:** the web frontend + its integration with the local backend; run
visualization; HITL UI for all three modes; catalog/config UI (restyle the
functional Phase-4 setup UI into the product design system).
**Out of scope:** new backend capabilities (all exist by Phase 5); agent-assisted
authoring UI (later); multi-user/hosted (out of program scope — local only).

---

## 3. Decisions applied

Q6 (single app; custom workbench after Studio), Q5 (role filter + bundles + cross-
role), Q7 (all three HITL modes surfaced), Q8 (state is small + human-editable →
render + edit it directly).

---

## 4. Detailed design

### 4.1 Tech
- Frontend: **Preact + esbuild** reusing the solutions-copilot webview stack
  (token-based design system in `media/style.css`, primitives: Button/Badge/Card/
  Toolbar/StatCard/EmptyState/ProgressBar/Field/TextInput/Segmented) — proven,
  zero-heavy-deps. (React acceptable if preferred.)
- Served by the local backend (FastAPI/LangGraph Server) on `localhost`.
- Live data via SSE/WebSocket (Phase 5 stream) + REST for actions.

### 4.2 Information architecture (surfaces)
1. **Home / Overview** — installed workflows, recent runs, health at a glance.
2. **Catalog** — all library workflows; filter by role; bundles ("install Tester set"); install/update/remove; per-workflow prereq badges (MCP/CLI configured?).
3. **Config / Settings** — GitLab token; MCP secret cards (auto-derived); environment registry CRUD; health panel (incl. MCP literal-env probe).
4. **Run** — pick a workflow → typed input form (from `inputs_schema`) → launch.
5. **Run Detail** — the heart:
   - **Step timeline** (graph nodes; current node highlighted; per-node status).
   - **Live activity** stream (agent messages + ACP tool calls; program/CLI logs).
   - **Artifacts viewer** (browse the run's blackboard files; view JSON/text/diagrams).
   - **State panel** (the small `PlatformState`, pretty-printed; editable at a pause).
   - **HITL controls** (contextual):
     - at a **gate**: approve / reject / feedback textarea → `POST /respond`.
     - **pause/resume/cancel** buttons (mode 2).
     - **edit state** (mode 3): inline JSON editor on whitelisted keys → `PATCH /state`; **fork** button (time-travel from a chosen checkpoint).
6. **Run History** — filter by workflow/status; open past runs; resume paused ones.

### 4.3 HITL UX details
- **Gate prompt** rendered from the `interrupt` payload (`kind`, `prompt`,
  `options`, `context_refs` → links to artifacts). Feedback box wired to the
  `feedback` decision path.
- **Escalation gates** (Q9) visually distinct ("needs your help — the agent
  retried N times").
- **Pause** shows "pausing at next step boundary…" then "paused — resume / edit / fork".
- **State editor** guards non-editable keys (read-only) and validates before resume.

### 4.4 Auth/session
- Local single-user app; no login (the machine's user). Optional lightweight lock
  if secrets are displayed (they are not — only key names).

### 4.5 Backend additions (thin)
- Static file serving for the webview bundle.
- `GET /inputs-form/{workflow_id}` → render hints from `inputs_schema` (or the UI
  builds the form directly from the schema).
- Aggregate `GET /home` (installed + recent runs + health) for the Overview.

---

## 5. Task breakdown

1. Frontend scaffold (Preact + esbuild), design-system port from solutions-copilot webview.
2. Message/data layer over the backend REST + stream (a `useGenesis` model, like solutions-copilot's `useDashboardModel`).
3. Overview surface.
4. Catalog surface (filter, bundles, install/update/remove, prereq badges).
5. Config surface (restyle Phase-4 setup: token, MCP cards, environments, health).
6. Run launch (schema-driven input form).
7. Run Detail: step timeline + live activity stream + artifacts viewer + state panel.
8. HITL controls: gate respond, pause/resume/cancel, state edit, fork.
9. Run history + resume.
10. Packaging: bundle UI into the single local app; one command to launch.
11. UX QA against solutions-copilot's dashboard UX standards (theme-native, token-first, a11y, CSP-safe).

---

## 6. Acceptance criteria

- [ ] User completes the full journey in the custom UI with **no LangGraph Studio**: configure → install → run → supervise.
- [ ] Catalog filters by role, shows bundles, and reflects install/update/remove + prereq status.
- [ ] Run Detail streams the step timeline + agent tool-call activity live.
- [ ] All three HITL modes are usable from the UI: gate approve/reject/feedback; pause/resume anywhere; view + edit state + fork.
- [ ] Artifacts viewer opens the run's blackboard files.
- [ ] Single command launches the whole app (engine + UI) locally.
- [ ] Meets the reused UX standards checklist.

---

## 7. Risks

- **Scope creep** — the workbench can grow unbounded. Anchor v1 to the six
  surfaces above; defer analytics/authoring UI.
- **Stream reliability** — reconnect logic for SSE/WebSocket on long runs.
- **State editor safety** — never allow editing keys that would corrupt a resume;
  validate against the state schema server-side before applying.

---

## 8. Deliverables

- The Genesis web workbench (Preact) integrated with the local backend.
- Studio no longer required for day-to-day use.
- Single-command local launch of the complete app.
