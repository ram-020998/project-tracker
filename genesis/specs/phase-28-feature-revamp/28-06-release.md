# 28-06 — Release

> **Status:** 📋 **PLANNED** (final; after 28-05). · **Type:** release / docs (ships the genesis version) · **Phase:** 28 (Feature Revamp) · **Gate:** CI green + docs current.

---

## Goal

Ship the Feature Workspace framework as a genesis release (on the user's explicit go-ahead), verify CI green,
and bring the bible/tracker/progress/ADR fully current.

## Scope

**In:** version bump + tag + push + CI verification; ADR-056 Accepted; doc refresh; final report.
**Out:** any new code (that's 28-04/05); starting the next phase (UX Design) — that's a separate phase.

## Work (per bible §6 release protocol)

1. **Hold for go-ahead.** Do NOT tag/push until the user says to release (28-01..28-05 land LOCAL on master).
2. **Pre-release gates (all green):** web `tsc` / `eslint` (0 errors) / `vitest` (incl. jest-axe) / `build`
   + committed `web/static` (stale-bundle guard); genesis `pytest` + `ruff`; `web/static` clean vs a fresh
   build; confirm no test pins the old version; if a migration was added, `current_version` tests pass.
3. **Version bump:** `pyproject [project].version` + FastAPI `create_app` version + `web/src/version.ts` to
   the new **genesis vX.Y.0** (frontend-heavy; other repos unchanged; `CORE_MAJOR` unchanged).
4. **Commit / tag / push:** `git -c user.name=Genesis -c user.email=genesis@local` release commit → tag
   `vX.Y.0` → push master + tag.
5. **Verify CI green** via `glab ci list -R ramaswamy.u/genesis` (python `genesis` + `frontend` stale-bundle
   guard + clean-install) for both the master pipeline and the tag pipeline.
6. **Docs (Definition of Done):** flip Phase 28 to SHIPPED across `AGENT_ONBOARDING.md` banner + ACTIVE
   handoff, `bible/00` banner, `bible/01` §2 (genesis row + test counts + a Phase-28 note), `bible/03`
   codebase-map (new/renamed feature-workspace modules), `bible/04` + `reference/decision-log.md`
   (**ADR-056 Accepted**, ADR-044 superseded-clause noted), `bible/08` §9 (SHIPPED block), the spec statuses
   (umbrella + 28-01..28-06 → RELEASED/COMPLETE), `progress/phase-28-feature-revamp.md`, and `tracker.md` §6.
   Push project-tracker (`git pull --rebase` → push).
7. **Report** with cited evidence (release commit, tag, CI pipeline ids, gate counts). Note that the next
   phase (**UX Design**) plugs into the framework; do NOT start it unless asked.

## Acceptance / DoD

- genesis **vX.Y.0** tagged + pushed; **CI green** (master + tag pipelines) — pipeline ids recorded.
- ADR-056 Accepted; ADR-044's sequential clause marked superseded.
- All Phase-28 docs updated to SHIPPED; project-tracker pushed.
- Report delivered with cited evidence.

## Gate

CI green + docs current → **PHASE 28 COMPLETE.**
