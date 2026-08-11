# 20-03 — Features surface + feature page shell (API + web)

> **Status:** 📋 DRAFT. **Repo:** genesis. **Depends on:** 20-02 (`FeatureStore`). Delivers the navigation + CRUD shell that
> 20-04/20-05 fill in.

## Goal
Add the **Features** tab to an application, a **Create feature** dialog, and the full-page **feature page** with a **Create
spec** empty state — the container the spec workspace lives in.

## Backend — `genesis/api/features.py` (routes under `/api`, ADR-028)
Over `FeatureStore` (+ `KbStore` to validate the app + `ChatManager` to create the spec's chat session in 20-04):
- `GET  /applications/{uuid}/features` — list feature summaries (name, description, spec status, updated_at).
- `POST /applications/{uuid}/features` — `{name, description}` → create → return the feature (id for navigation).
- `GET  /features/{id}` — feature detail (+ its spec summary if any).
- `PATCH /features/{id}` — rename/redescribe (optional in v1).
- `DELETE /features/{id}` — remove a feature (cascades spec + revisions).
- `POST /features/{id}/spec` — create the spec for a feature (title; creates the bound chat session — the create path is
  finalized in 20-04). Returns the spec (+ session id).
- `GET  /features/{id}/spec` — the spec detail (status, html pointer, session id) — 404/empty when none.
Register in `create_app` (mirror `applications`/`documents` registration). Friendly 4xx (unknown app/feature → 404).

## Frontend — `web/src/features/features/` (+ `applications` wiring)
- **Features tab** on `ApplicationDetail` (a 6th tab: Business Map · Overview · Syncs · Releases · Business Artifacts ·
  **Features**): a grid of **feature cards** (name, description, spec-status chip, updated) + a **Create feature** button.
- **`CreateFeatureDialog`** — a small dialog (name + description) using the standardized `ResourceFormDialog` pattern; on
  submit → `POST …/features` → **navigate to the feature page**.
- **Feature page** — a new full-page route **`/applications/:uuid/features/:featureId`** (added to `web/src/app/router.tsx`;
  Sidebar unaffected — reached via the app's Features tab). Shell = a header (feature name/description, back to the app) + the
  **spec area**. When the feature has **no spec**: a single **Create spec** empty-state button (→ `POST /features/:id/spec` →
  render the spec workspace, built out in 20-04/20-05). When a spec exists: render the spec workspace directly.
- **Data hooks** — `web/src/features/features/hooks.ts` (TanStack Query: list/create features, get feature, create/get spec)
  + `web/src/lib/api/features.ts` (typed client, prepends `/api`). Reuse `Chip`/`Card`/`MetricCard`/tokens (ADR-027; no raw
  colors). Status chip tone map (`draft`/`in-progress`/`in-review`/`completed`).

## Tests
- Backend: `tests/test_features_api.py` — feature CRUD, spec create/get, unknown app/feature → 404, list shape includes spec
  status. Frontend: `features/features.test.tsx` — Features tab renders cards, Create-feature dialog creates + navigates,
  feature page shows the Create-spec empty state; **jest-axe** on the new interactive UI.

## Exit criteria
From an application I can open **Features**, create a feature (name + description), land on its **feature page**, and see the
**Create spec** empty state; all backend routes return the documented shapes; tests + `ruff`/`tsc`/`eslint`/`npm run build`
green (commit the rebuilt `web/static/`).
