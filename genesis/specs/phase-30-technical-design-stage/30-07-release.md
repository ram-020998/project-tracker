# 30-07 — Coordinated release (Technical Design stage)

> **Status:** ✅ SHIPPED (2026-09-03) — genesis v0.57.0 (`0878b13`) + genesis-workflows v0.13.0 (`ae1181c`), CI green (genesis #6725001 / workflows #6725004). Docs updated; project-tracker pushed. PHASE 30 COMPLETE. · Part of Phase 30.

## Purpose

Ship Phase 30 across the two changed repos and update the docs. Only on the user's explicit go-ahead (no
tag/push before 30-07).

## Release chain (ADR-019 order)

Two repos only — genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**; **no migration**
(`current_version` stays 15).

1. **genesis** (backend JSON start + prerequisite gate + StageFinalizer generalization + `technical_design`
   chat mode + web: `design` live + gating + entry state + the 30-05 UX refinements) — bump `pyproject`
   `[project].version` + `api/app.py` version + `web/src/version.ts`; `npm run build` + commit `web/static`;
   tag `vX.Y.0`; push master + tag.
2. **genesis-workflows** (the `technical-design-analysis` workflow + registry) — bump `pyproject` + the
   workflow META version + `registry.json`; **re-pin the genesis dev-pin to the new genesis tag** (keep the
   whole chain consistent — the §7 ResolutionImpossible lesson: genesis-workflows pins genesis *and*
   genesis-core; move both if the middle moves). Tag; push master + tag.

Verify CI green on each via `glab ci list -R ramaswamy.u/<repo>` — wait for the **tag** pipelines (incl.
clean-install / library-validate). `genesis install --from ../genesis-workflows` on the running box so the new
workflow is loadable; a `genesis serve` restart to load the backend changes (check no active run first — the
v0.56.2 orphaned-worker lesson).

## Docs (Definition of Done)

- **bible/01 §2** — new genesis + genesis-workflows tags + test counts + a "what works today" line for the
  Technical Design stage.
- **bible/04 §5** — **ADR-058** + the **ADR-056 amendment** (prerequisites); mirror in
  `reference/decision-log.md`.
- **bible/03 §4** — the `technical-design-analysis` workflow + the StageFinalizer binding registry +
  `technical_design` chat mode + the JSON start endpoint.
- **bible/06 §7** — any new hard-won lesson from the build/dry-run.
- **bible/08 §9** — a Phase 30 as-built block; **AGENT_ONBOARDING.md** banner + Last-refreshed.
- **README.md** — a phase-30 row.
- **tracker.md §6** + **progress/phase-30-technical-design-stage.md** (as-built) — push project-tracker
  (`git checkout -- .obsidian/*`, `git pull --rebase` → push).

## Gate

Both repos tagged + CI green (incl. clean-install + library-validate); pin chain consistent; docs pushed;
report with cited evidence (tags, CI pipeline ids, gate counts). **Live acceptance** (real app + Kiro) is
user-driven — give the manual check. **PHASE 30 COMPLETE — no active phase** (Feature Breakdown is the next
candidate, not started unless asked).
