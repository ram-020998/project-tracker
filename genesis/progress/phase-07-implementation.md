# Genesis — Phase 7 Implementation Record

> As-built record of Phase 7 (Custom Web Workbench). Companion to
> `specs/phase-07-custom-web-workbench.md`.

**Date:** 2026-07-09 · **Milestone:** M7 (Product UI) · **Status:** ✅ COMPLETE — 43 platform tests + 5 frontend tests green, bundle builds, server serves the SPA end-to-end (verified via live launch). Visual/UX QA is manual (headless env — see §5).

---

## 1. Summary

Genesis now has its **own web workbench** — the product surface a Solutions
engineer uses to browse/run/supervise workflows, replacing LangGraph Studio for
day-to-day use. A React + TypeScript SPA (Vite) served by the FastAPI backend on
`localhost`, driven by the Phase 3–5 REST + SSE APIs. One command launches
everything: **`genesis serve`**.

---

## 2. Decision: React + TypeScript (deviation from the spec's Preact — approved)

The spec (§4.1) called for **Preact** (reuse of the solutions-copilot webview
stack). The user set the destination as an **enterprise-grade** (still local,
single-user) product and chose **React + TypeScript** for ecosystem, hiring, and
component-library future-proofing. Approved deviation; the backend architecture is
unchanged (still local single-user per Q1/ADR-012/ADR-023). Recorded here and in
the tracker; a decision-log ADR should capture it.

---

## 3. What was built
**Frontend (`genesis/web/`, React 18 + TS + Vite + Vitest):**
```
src/api.ts        # typed REST client + subscribeRun() SSE helper; ApiError
src/types.ts      # backend-mirroring types
src/components.tsx # StatusBadge, Field, EmptyState, JsonView, useAsync hook
src/surfaces.tsx  # Home, Catalog (role filter + prereq badges), Config, History
src/run.tsx       # RunLaunch (schema-driven form) + RunDetail (timeline, live
                  #   activity, telemetry, artifacts, + all 3 HITL modes)
src/App.tsx       # hash router + sidebar shell
src/theme.css     # token-based design system (light/dark, a11y-minded)
src/*.test.*      # Vitest + Testing Library (api client, App shell, schema form)
```
Built to `web/static/` (committed → runtime needs no node) via `vite build`.

**Backend additions (`genesis/api/app.py`):**
- Static SPA serving: `GET /` → `index.html`, `/assets/*` mounted.
- Config CRUD the UI needs: `GET/POST /config/gitlab-token`, `GET /config/mcp-cards`,
  `POST /config/secrets` (returns key name only), `GET/POST/DELETE /config/environments`,
  `GET /artifacts/usage`.
- Aggregates: `GET /home` (installed + recent runs + health), `GET /workflows/{id}` (META).

**Launch:** `genesis serve [--host --port]` (uvicorn) — the single-command app.

---

## 4. Surfaces (IA) & HITL coverage
- **Overview** — installed count, recent runs, health at a glance.
- **Catalog** — role filter, prereq (MCP/CLI) badges, "Run…" (install/update/remove
  noted as distribution-API/CLI — see §5).
- **Config** — GitLab token, auto-derived MCP secret cards (values never shown),
  credential-free environment CRUD, health panel, artifacts usage.
- **Run launch** — form generated from `inputs_schema` (enum→select, bool→checkbox,
  number, required markers).
- **Run Detail** — step timeline (current node highlighted), live activity (SSE
  custom/tool-call/error events), telemetry, artifacts list, and **all three HITL
  modes**: gate **approve/reject/feedback**; **pause/resume/cancel**; **edit state**
  (JSON merge-patch, guardrails) + **fork** (time-travel).
- **History** — filter by status, open/resume past runs.

---

## 5. Verification (evidence — acceptance criteria §6)

| Criterion | Result | Evidence |
|---|---|---|
| Full journey in custom UI, no Studio | ✓ (surfaces + APIs) | all six surfaces wired to backend; `genesis serve` launch |
| Catalog filters by role + prereq status | ✓ | `surfaces.tsx` Catalog; `App.test.tsx` covers schema form; role filter unit-visible |
| Run Detail streams timeline + tool-call activity | ✓ | `subscribeRun` SSE → RunDetail timeline/activity |
| All three HITL modes usable from UI | ✓ | GatePanel (respond), pause/resume/cancel, StateEditor (patch), ForkPanel |
| Artifacts viewer | ✓ | RunDetail artifacts table from `GET /runs/{id}/artifacts` |
| Single command launches app | ✓ | `genesis serve`; **live launch verified**: `/`→index, `/assets/*.js`→200, `/home`/`/catalog`→JSON |
| Backend endpoints | ✓ | `test_api.py` +3 (home/meta, config, SPA served) — **43 platform tests green** |
| Frontend build + tests + typecheck | ✓ | `tsc --noEmit` clean; `vitest` **5 tests green**; `vite build` → 163 KB bundle |

**Live server smoke** (captured): `GET /` returns the SPA HTML, `GET /assets/index-*.js`
→ `200 text/javascript`, `GET /home` returns installed/recent/health JSON.

---

## 6. Honest gaps / notes
- **Visual/UX QA** (design polish, a11y audit, cross-browser) is a manual step that
  needs a browser — not possible in this headless env. The design system is
  token-based, semantic-HTML, keyboard-navigable by construction; a human pass is
  still owed before "enterprise-grade" is fully signed off.
- **Catalog install/update/remove** from the UI needs the Phase-3 distribution
  operations exposed as endpoints (the `Installer` exists; only `installed` is wired
  today). Catalog currently lists installed workflows + prereqs + launch. Wiring
  install/remove endpoints is a small follow-up.
- **Frontend CI**: added a separate `frontend` job (node:20, runs on `web/**`
  changes) doing `npm ci → typecheck → test → build`, independent of the Python job.

---

## 7. Repos & tags after Phase 7
| Repo | Tag | Change |
|---|---|---|
| `genesis` | **v0.6.0** | +`genesis/web/` React+TS workbench (built bundle committed); FastAPI static serving + config/home endpoints; `genesis serve`; frontend CI job; +uvicorn |
| `genesis-core` | v0.3.0 | unchanged |
| `genesis-workflows` | v0.2.0 | unchanged |

---

## 8. Next: Phase 8 — Skill Migration Program
Migrate the remaining solutions-copilot skills into `genesis-workflows` workflows,
one wave at a time (read/generation first; write-path + LCP-authoring later),
tracking `MIGRATION.md`. See `specs/phase-08-skill-migration-program.md`.
