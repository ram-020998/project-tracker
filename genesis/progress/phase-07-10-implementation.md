# Genesis — Phase 7.10 (Web Revamp: Testing, CI & Rollout) Implementation Record

> As-built record of `specs/phase-07-10-testing-ci-rollout.md` — the final web-revamp phase:
> lint gate, contract-fixture discipline, CI hardening, and the **cutover** from the interim
> workbench. Completes milestone **M7.1**.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — released **genesis v0.11.0** (`f32f912`,
tagged). CI pipeline **#6328080 SUCCESS** (frontend + genesis), including the new stale-bundle
guard. This is the one web-revamp phase that intentionally **rebuilds + commits `web/static/`**.

---

## 1. Summary

Guaranteed the revamped app is lint-clean, contract-locked to the backend, and CI-guarded, then
**cut over** from the interim workbench: deleted the superseded interim files and rebuilt the new
app into `web/static/`. The FastAPI backend now serves **only the new SPA**. Verified end-to-end
in a real browser (Playwright MCP) against a live `genesis serve`.

---

## 2. Lint gate (ESLint)

- Added `eslint.config.js` (flat config): `@eslint/js` + `typescript-eslint` recommended +
  `eslint-plugin-react-hooks` + `react-refresh`, with `no-unused-vars` as an error (the CI
  typecheck already enforces the same, so lint + tsc are belt-and-suspenders), `no-explicit-any`
  as a warning, and a config-file override allowing `require()` in `tailwind.config.ts`.
- `npm run lint` → **0 errors** (9 benign warnings: react-refresh on design-system files that
  export helpers alongside components, 2 exhaustive-deps in RunsPage). CI does not fail on warnings.

## 3. Contract fixtures (frontend ↔ backend lockstep)

- `src/test/fixtures/` — golden, **typed** fixtures for every canonical event kind, the
  `GateDescriptor` per sanctioned kind, topology, steps, the artifact manifest + content, and the
  MCP/CLI config cards. Because they are typed against the FE `types/`, a type drift breaks `tsc`.
- `contract.test.ts` — runtime drift guard that feeds the golden event log through the **real**
  `buildTranscript` (07-08) and `deriveNodeStates` (07-07) folds and asserts the canonical kinds +
  payload keys, so a change on either side of the contract fails a test. Each fixture file cites its
  backend golden source (manager.py / kiro_node / reliability.py / gate.py / loader / app.py).

## 4. CI

- Extended the `frontend` job (node:20, on `web/**` changes): `npm ci` → `npm run lint` →
  `npm run typecheck` → `npm test` → `npm run build` → **stale-bundle guard**
  (`git diff --quiet -- static`, fails if the committed bundle differs from a fresh build).
- The guard passed on the cutover commit — proving the committed `static/` equals a CI fresh build
  (Vite/rollup/esbuild output is deterministic across the local + CI environments given the locked
  deps). The Python `genesis` job continues to cover the backend.

## 5. Cutover (rollout)

- `main.tsx` / `index.html` already pointed at the new app (since 07-03), so a plain `vite build`
  **is** the cutover bundle. Deleted the interim files — `App.tsx`, `surfaces.tsx`, `run.tsx`,
  `components.tsx`, `api.ts`, `types.ts`, `theme.css`, and their tests (`App.test.tsx`,
  `api.test.ts`) — after confirming (grep) that only interim files referenced each other.
- Rebuilt + committed `web/static/` (new app; mermaid + diagram engines are lazy chunks). The old
  interim bundle assets were removed. `genesis serve` now serves only the new SPA with the SPA
  history fallback (ADR-028).
- No API breakage: all backend changes across the program were additive (data plane in 07-02);
  backend here changed only its version string (0.10.0 → 0.11.0).

## 6. Manual verification (Playwright MCP)

Per direction, the automated Playwright E2E suite (spec §1.3) was **replaced by manual
MCP-driven browser verification** against a live `genesis serve` on :8760 serving the freshly-built
`static/`. All passed:

- Overview dashboard; grouped sidebar (Monitor/Library/Configure); theme.
- **Runs** — Active/History tables, filters, live status, quick actions.
- **Run Detail** — React Flow graph with per-node statuses folded from the durable log
  (`Fetch schema OK ×2 🔧7 💬49`, `Escalate — Needs you`), Graph/List toggle.
- **HITL from durable state** — opened the pre-existing gated run `r-0b79c1573923` (escalation gate
  raised in a prior session, server since restarted): the HITL bar renders the gate, prompt,
  `raw_schema.json` context ref, and **approve/reject/feedback** controls. This is the ADR-028/07-02
  "approval reachable after reload/restart" guarantee, verified live.
- **Node inspector** — the Kiro conversation transcript rebuilt from the durable log: assistant
  messages (coalesced), `@appian-atlas/*` tool-call cards, collapsible thoughts, "Turn failed"
  chips, and `Validator v_fetch failed` + `Retry 1/2`, `Retry 2/2` notes across the 3 attempts.
- **Documents** — opened `raw_schema.json` (78 KB), deep-linked at `/runs/:id/docs/:name`, with
  Download/Copy/Raw and correct graceful **fallback to raw** (the file is not valid JSON — which is
  exactly why the run's validator failed and escalated).
- **Deep-link / SPA fallback** — hard-loaded `/settings` directly → resolves via the history
  fallback with full live data; `/catalog` likewise (installed workflows, prereq badges, launch/remove).

## 7. Verification (gates)

- `npm run lint` — 0 errors. `npx tsc --noEmit` strict — clean.
- `npx vitest run` — **59 passed** (53 screen/logic + 6 contract; interim App/api tests removed at
  cutover).
- `npm run build` — OK; `git diff web/static` empty against the committed bundle (stale-bundle guard).
- Backend: `ruff check genesis` clean; `pytest -q` **54 passed**.
- CI pipeline **#6328080**: `frontend: success`, `genesis: success`.

## 8. Definition of done (07-10) — status

1. Unit + component (MSW) suites cover every screen + core logic; `jest-axe` in the design-system
   suite — ✅ (coverage-threshold gate deferred — see §9).
2. Shared contract fixtures; drift fails CI (tsc + contract.test.ts) — ✅.
3. Playwright smoke incl. approve-a-gate — ⚠️ **replaced by manual MCP verification** (§6), per
   user direction not to author Playwright scripts. The gate render + approve/reject/feedback
   submission is covered by the 07-08 component tests; live approve→resume needs Kiro (can't run headless).
4. `frontend` CI runs lint + typecheck + test + build + stale-bundle guard; green — ✅.
5. Interim `web/` removed; `genesis serve` serves only the new app; no route/API breakage — ✅.
6. Tracker + progress updated; **M7.1 marked complete** — ✅ (this doc + tracker §6 + header).

## 9. Decisions & honest deviations

- **Automated Playwright E2E → manual MCP verification** (user-directed). No `*.spec.ts` E2E
  scripts and no nightly Playwright CI job were added; verification is the documented §6 browser pass.
- **Coverage-threshold gate deferred.** `npm test` runs the full Vitest suite but CI does not yet
  enforce a coverage %; adding `@vitest/coverage-v8` + a tuned threshold is a low-risk follow-up
  (avoided gating CI on a number this pass).
- **shiki syntax highlighting + CSV/text virtualization** remain deferred from 07-09 (CodeBlock is
  plain monospace). mermaid is already code-split via dynamic import; a Recharts manualChunks split
  is the remaining bundle-size follow-up (the 500KB chunk warning persists, non-failing).
- **Stale-bundle guard is a strict byte-diff.** It held here; if a future node/toolchain bump makes
  the build non-reproducible, the guard would need a rebuild-and-commit (that's the intended signal).

---

## 10. Outcome — M7.1 Web Revamp COMPLETE

All ten web-revamp specs (07-01 … 07-10) are delivered, released, and CI-green. The enterprise-grade,
Overcut-inspired workbench is the shipped app: durable data plane (07-02), design system (07-03),
Settings (07-04), Catalog (07-05), Runs (07-06), Run Detail graph (07-07), node inspection + Kiro
conversation + full HITL from durable state (07-08), documents & preview (07-09), and this
testing/CI/cutover phase (07-10). Next program: **Phase 8 — skill migration**.
