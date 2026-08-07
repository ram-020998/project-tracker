# Phase 17-05 — Web Business Map view

> **Status:** DRAFT · **Repos:** genesis (web) · **Depends on:** 17-04 (API)
> **Goal:** The user-facing payoff: a clean, business-language **Business Map** view on the application detail page — two
> coordinated canvases (**A** value stream + **B** capability constellation) rendered from the `BusinessModel`, with
> generate/regenerate/stale/coverage/credits UX. Reuses the existing React Flow + dagre stack; **no** technical vocabulary.

---

## 1. Current state (grounded)
- `web/src/features/applications/ApplicationDetail.tsx` is a Tabs shell (Overview | Objects | Bundles | Syncs | Releases) with
  `hooks.ts` (`useApplicationDetail`, `useSyncStatus`, …) over the typed client (`lib/api`, prepends `/api`).
- The web already ships **`@xyflow/react` v12 + `@dagrejs/dagre`**, used by `features/run-detail/graph/` (`RunGraph.tsx`,
  `layout.ts` = deterministic left-to-right dagre, `NodeCard.tsx`, MiniMap/Controls/Background). Design tokens + primitives
  per ADR-027; heavy libs lazy; jest-axe on interactive UI; `web/static/` is the committed built bundle (rebuild + commit
  after any `web/src` change; CI stale-bundle guard).

## 2. Design
- **Primary view.** Add a **"Business Map"** entry as the **first/primary** view on the detail page (the existing technical
  tabs remain, grouped under a secondary "Technical" area; relabel/retirement of those is an open decision, not part of 17).
- **States.** *Absent* → an empty state with a "Generate business map" button (→ `POST …/generate` → poll `…/status` like
  `useSyncStatus`, show live progress + a link to the run). *Generating* → progress. *Ready* → the map + a header strip:
  *"based on sync #N · generated {RelativeTime} · {credits} credits · {coverage}% covered"* + **Regenerate**. *Stale* → a
  banner ("A newer sync is available — regenerate") + Regenerate. *Failed* → error + link to the run.
- **Canvas A — Value stream.** A React Flow canvas per `value_stream` (switcher if >1): `stages` → nodes laid out L→R by
  dagre following `next`; `kind` → shape (start ▶ / activity ▭ / decision ◇ / end ⏹); `next.condition` → edge labels; node
  shows business `name`, `actor`, entity chip. New **business node components** (NOT `NodeCard`), design tokens.
- **Canvas B — Capability constellation.** `domain` center; `capabilities` clustered around; `entities` satellites;
  `capability_relations` labeled edges.
- **Coordination (focus+context).** A segmented control toggles A ↔ B (or split view); one shared selection keyed by
  `capability` id — selecting a capability highlights its stages in A and dims the rest; selecting a stage highlights its
  capability in B. Optional per-node "what & why" popover (plain language from evidence); an off-by-default "see underlying
  objects" link to the technical view (traceability only — keeps the map business-clean).
- **Hooks/types.** `useBusinessMap(uuid)` + `useGenerateBusinessMap()` + `useBusinessMapStatus(uuid)` over the 17-04
  contracts; MSW fixtures mirror the API.

## 3. Definition of Done
- Absent→generate→ready→(stale after sync) all render; A + B render from a fixture `BusinessModel`; linking/brushing works;
  labels are business-only (a test asserts no banned technical token appears in rendered labels).
- `npm run lint` + `tsc` + `vitest` green (+ jest-axe on the new interactive canvas); `npm run build` run and **`web/static/`
  committed** (stale-bundle guard). Ships as a genesis release; CI `genesis` + `frontend` jobs green.
