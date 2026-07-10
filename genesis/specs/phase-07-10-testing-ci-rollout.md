# Phase 7.10 — Testing, CI & Rollout

> **Goal:** Guarantee the revamped application is correct, accessible, and
> maintainable, and cut over from the interim workbench cleanly. Defines the frontend
> testing strategy (unit/component/E2E), the contract-fixture discipline that keeps
> frontend and backend in lockstep, the CI pipeline, and the removal of the old
> `web/` in a single safe cutover.

Prereq: all prior 07-0N specs. Touches `genesis/web/`, `genesis/.gitlab-ci.yml`, and
the tracker.

---

## 1. Testing strategy (the pyramid)

### 1.1 Unit (Vitest)
- Pure logic: `deriveNodeStates` fold (07-07), conversation coalescing (07-08), zod
  schema generation from `inputs_schema` (07-05), prereq computation (07-05),
  formatters (date/bytes/duration), the SSE→Query reconcile reducer.
- Design-system primitives render + variant tests (07-03) with `jest-axe`.

### 1.2 Component / integration (Vitest + RTL + MSW)
- Every screen against **MSW-mocked** endpoints using shared contract fixtures (§2):
  - Settings: card status, drawer save (write-only), connection test.
  - Catalog: filter, prereq gating, install, launch-form validation.
  - Runs list: filtering, live-status transitions, quick actions.
  - Run Detail: graph renders from topology; node-status fold from a scripted event
    stream; current-node highlight; connection-state indicator.
  - Inspector/Conversation: scripted `agent.*` fixture → transcript (messages,
    thoughts, tool cards update by id, result); program-node empty state.
  - HITL: gate fixture renders per `gate.kind`; approve/reject/feedback submit;
    pause/resume/cancel; edit-state guardrail rejection; fork navigation.
  - Documents: each `preview_kind` renderer; truncation; binary/oversized fallback.
- **SSE simulation**: a test EventSource that emits a scripted, seq-ordered event log
  incl. a mid-stream "restart" (re-hydrate from `/events` then tail) to prove no
  loss/dupes and that gate controls appear from durable state after reload.

### 1.3 End-to-end (Playwright, smoke)
- Against a real `genesis serve` seeded with the run-test library (hello-appian) and
  a stubbed Kiro/MCP layer:
  - Launch hello-appian → watch graph reach done → read result document.
  - A scripted gated workflow → approve from the UI → completes. (Directly guards the
    original approval bug.)
- Kept minimal (happy paths + the gate path); heavy logic covered by component tests.

### 1.4 Accessibility
- `jest-axe` in component tests for shell + each screen; Playwright + `@axe-core`
  smoke on key routes; manual keyboard pass checklist in the PR template.

---

## 2. Contract fixtures (frontend ↔ backend lockstep)

- 07-02 defines golden JSON fixtures for every event `kind`, the `GateDescriptor`,
  topology, steps, artifact listing/content, and config cards.
- These fixtures are **shared**: the backend has a test asserting it emits exactly
  these shapes; the frontend `types/` mirror them and MSW handlers serve them. A
  drift in either side fails a test. Store under `web/src/test/fixtures/` with a note
  pointing at the backend golden source.

---

## 3. CI

- Extend the existing `frontend` job (node:20) in `genesis/.gitlab-ci.yml` to run, on
  `web/**` changes:
  1. `npm ci`
  2. `npm run lint` (ESLint + Prettier check)
  3. `npm run typecheck` (`tsc --noEmit`, strict)
  4. `npm run test` (Vitest, coverage threshold e.g. 80% on logic modules)
  5. `npm run build` (Vite) — and assert `static/` is up to date (fail if the
     committed bundle differs from a fresh build, so the runtime bundle is never
     stale).
  6. (optional/nightly) Playwright E2E job with a headless browser image.
- The Python `genesis` job continues to cover backend (07-02) changes.
- Coverage + a11y results surfaced as CI artifacts.

---

## 4. Rollout / cutover from the interim workbench

Sequenced to avoid a broken `master`:

1. Build the new app **alongside** the old under `web/` (new code in `src/app`,
   `features/`, etc.; old files untouched) until screens reach parity behind the new
   AppShell.
2. Feature-parity gate: Overview, Settings, Catalog, Runs, Run Detail (graph +
   conversation + HITL + docs) all implemented and green.
3. **Cutover commit**: switch the Vite entry to the new `main.tsx`, delete the
   superseded interim files (`App.tsx`, `surfaces.tsx`, `run.tsx`, `components.tsx`,
   `theme.css`, old tests), rebuild + commit `static/`. Verify `genesis serve` serves
   the new SPA and the same-origin routes resolve.
4. Update `docs/debug-in-studio.md` note if paths changed; Studio path unaffected
   (ADR-023).
5. No API breakage: all backend changes were additive (07-02), so a mixed state
   during rollout still works.

---

## 5. Versioning & tracker

- Frontend changes ride `genesis` versions (bundle committed). Each completed 07-0N
  spec → a tracker §6 status-log entry under milestone **M7.1** + a
  `progress/phase-07-<nn>-*.md` note.
- Final program completion → update tracker header/status and the spec index; mark
  M7.1 complete.

---

## 6. Definition of done

1. Unit + component (MSW) suites cover every screen and the core logic; coverage
   threshold met; `jest-axe` clean.
2. Shared contract fixtures in place; a drift between backend emission and frontend
   types fails CI.
3. Playwright smoke (incl. the approve-a-gate happy path) green.
4. `frontend` CI job runs lint+typecheck+test+build (+ stale-bundle guard); green.
5. Interim `web/` removed in a clean cutover; `genesis serve` serves only the new
   app; no route/API breakage.
6. Tracker + progress notes updated; M7.1 marked complete.
