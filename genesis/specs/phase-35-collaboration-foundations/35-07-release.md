# 35-07 — Release

> **Status:** 🟡 DRAFTED. · Part of Phase 35. Repo: **genesis**. · **Depends on:** 35-06 (review clean). ADR-019 (release protocol).

## Purpose

Ship Phase 35 as a single-repo **genesis** release and update all documentation. The collaboration layer is
opt-in/off-by-default, so this release is safe for existing solo users.

## Release steps (ADR-019)

1. **Version bump** genesis → suggest **v0.63.0** (the three anchors: `pyproject.toml`, `web/src/version.ts`,
   `api/app.py` `create_app` version). No core/SDK/workflows change (no pins move).
2. **Gates:** genesis `pytest` + `ruff`; web `tsc`/`eslint`/`vitest` + `npm run build` + commit `web/static`.
3. **Commit + tag** `v0.63.0` (git identity `git -c user.name=Genesis -c user.email=genesis@local`) + push
   master + tag.
4. **CI green** (via `glab`): the `genesis` job + `frontend` job + the **`clean-install`** job must migrate a
   fresh DB to **v19** and serve.
5. **Docs:** flip **ADR-063 → Accepted** (decision-log + mirror to `bible/04`); update `bible/01` §2 (tag table
   → v0.63.0, test counts, `current_version=19`, m0019 in the migrations line, add a "what works" note that
   collaboration foundations exist behind the opt-in flag against a local provider); `bible/03` codebase-map
   (the `genesis/collab/` package); `bible/08` §9 (flip the Phase-35 block to SHIPPED); banners
   (`AGENT_ONBOARDING.md` + `bible/00`); `tracker.md` §6 entry; `progress/phase-35-collaboration-foundations.md`
   (as-built); README phase row; flip the Phase-35 spec statuses to SHIPPED. Push project-tracker.

## Verification

Fresh clean-install → v19 + serve; solo behavior unchanged (no Hub configured); the local-provider
publish→pull round-trip works (the 35-06 script). Real Appian Hub sync is **Phase 37** — note that live
acceptance is deferred there.

## Gate

CI green + docs updated → Phase 35 COMPLETE.
