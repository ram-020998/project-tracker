# Phase 7.5 — Workflow Catalog & Install Management

> **Goal:** A modern catalog where users discover available workflows, understand
> their prerequisites at a glance, install/update/remove them from the shared
> library, and launch a run via a schema-driven form. Turns the current read-only
> catalog into a full lifecycle-managed library surface.

> **API paths (ADR-028):** endpoints referenced here are served under **`/api`** (the
> `lib/api` client prepends it centrally); non-`/api` paths hit the SPA history fallback.

Prereq: 07-02 (catalog + graph + install endpoints), 07-03 (design system) + 07-03a
(visual language). Feature dir: `features/catalog/`. Routes: `/catalog`,
`/catalog/:workflowId`, `/catalog/:workflowId/launch`.

> **Visual (per `phase-07-03a`):** the catalog uses Overcut's **search + CategoryChips
> + card grid** pattern; workflow detail uses **sub-tabs** (Overview / Graph / Runs)
> like Overcut's per-workflow Dashboard/Builder/History tabs.

---

## 1. Objective & user story

"As a user, I browse the workflow library, filter to my role, see which workflows I
can run right now (prereqs met) vs which need setup, install the one I want, and
launch it with a guided form."

---

## 2. Backend dependency: install lifecycle API

The `Installer`/`Loader` exist and are exercised by the `genesis install`/`list`
CLI. Expose them as endpoints (small addition, tracked with this spec):

| Method | Path | Purpose |
|---|---|---|
| GET | `/catalog` | installed workflows (existing) |
| GET | `/catalog/available` | available-but-not-installed from the GitLab library registry (via stored token) |
| GET | `/workflows/{id}` | META (existing) |
| GET | `/workflows/{id}/graph` | topology (07-02) |
| POST | `/library/install` | `{id, version?}` → install/pull from library |
| POST | `/library/update` | `{id}` → update to latest compatible |
| DELETE | `/library/{id}` | remove installed workflow |

Install/update/remove run through the existing `Installer` (compat gate enforced,
lockfile updated). Long installs return a job/status or block with a bounded
timeout; the UI shows progress + result.

---

## 3. Catalog browse (`/catalog`)

### 3.1 Layout

- **FilterBar**: search; role filter (from workflow `roles`); status filter
  (Installed / Available / Needs prereqs); sort (name/role/recently updated).
- **Workflow cards** (grid):

```
┌────────────────────────────────────────────┐
│ [icon] ERD Generation             v0.3.0     │
│ Generate an ERD from an Appian app schema.    │
│ Roles: architect, developer                   │
│ Needs: atlas ✓   erd-gen ✗        ● Installed │
│              [ Launch ]   [ Details ]  [ ⋯ ]  │
└────────────────────────────────────────────┘
```

- **Prereq badges**: each required MCP/CLI shows met (✓ configured) / unmet (✗) by
  cross-referencing `mcp-cards`/`cli-cards` status. Unmet prereqs → `Launch` is
  disabled with a tooltip linking to Settings.
- **Install state**: Installed (green) / Available (outline `Install` button) /
  Update available (amber `Update`).
- `⋯` menu: Update, Remove (ConfirmDialog), View on GitLab (if available).

### 3.2 Empty/loading/error

- Empty (nothing installed, none available): getting-started state — "Set your
  GitLab token in Settings to browse the library," deep link.
- Loading: skeleton cards. Error: inline retry.

---

## 4. Workflow detail (`/catalog/:workflowId`)

- Header: name, version, roles, summary, install state + actions.
- **Overview**: full description (markdown from META if present), inputs summary,
  HITL points (`hitl_points`), required MCP/CLI with live prereq status.
- **Graph preview**: render `GET /workflows/{id}/graph` with React Flow (read-only,
  non-interactive layout) so users see the shape before running — reuses the
  Run-Detail graph renderer (07-07) in a "static" mode.
- **Recent runs of this workflow**: quick list linking to Run Detail.
- Primary action: **Launch** (prereqs met) → `/catalog/:workflowId/launch`.

---

## 5. Launch form (`/catalog/:workflowId/launch`)

- Schema-driven from `META.inputs_schema` using **react-hook-form + zod**:
  - Generate a zod schema from the JSON Schema (types, required, enum, defaults,
    min/max, pattern) → typed, validated form.
  - Field widgets by type: text/number/textarea/select(enum)/switch(boolean)/
    date; descriptions as helper text; required markers; sensible defaults.
  - Unknown/complex properties → JSON editor fallback with validation.
- **Environment selector** (optional) from environments registry.
- **Prereq guard**: if any required integration is unmet, block submit with a clear
  message + link to Settings.
- Submit → `POST /runs` → on success navigate to `/runs/:runId` (straight into the
  live Run Detail). Surface `InputValidationError` (400) field-mapped where possible.
- Confirmation for workflows whose META marks a write/deploy posture (informational:
  "this workflow can modify external systems" — actual mutation still gated by
  pre_mutation HITL at runtime).

---

## 6. Data & hooks

- `useCatalog()`, `useAvailableWorkflows()`, `useWorkflowMeta(id)`,
  `useWorkflowGraph(id)`, `useWorkflowRuns(id)`.
- Mutations: `useInstall()`, `useUpdate()`, `useRemove()`, `useStartRun()` — invalidate
  `['catalog']`, `['catalog','available']`, and toast; install/remove reflect
  optimistically then reconcile.
- Prereq computation: a selector joining workflow `required_mcp/cli` with
  `mcp-cards`/`cli-cards` status.

---

## 7. Definition of done

1. Catalog lists installed + available workflows with role/status filters and
   accurate prereq badges.
2. Install / Update / Remove work end-to-end via the new library endpoints (compat
   gate + lockfile respected), with progress + confirmation.
3. Workflow detail shows overview, HITL points, prereqs, and a static graph preview.
4. Schema-driven Launch form validates via zod, guards prereqs, starts a run, and
   routes into Run Detail.
5. States (loading/empty/error/success) designed; component + MSW tests for filter,
   prereq gating, install, and launch-validation.
