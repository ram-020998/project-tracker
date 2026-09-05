# 37-06 — Release

> **Status:** 🟡 DRAFTED. · Part of Phase 37. Repo: **genesis**. · **Depends on:** 37-05. ADR-019.

## Release steps (ADR-019)

1. Version bump genesis → suggest **v0.64.0** (the three anchors: `pyproject.toml`, `web/src/version.ts`,
   `api/app.py`). **No migration** (m0019 stands); no core/SDK/workflows pin moves.
2. Gates: genesis pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`.
3. Commit + tag `v0.64.0` + push master + tag; **CI green** (genesis + frontend + clean-install still migrates to
   v19 + serves).
4. **Docs:** `bible/01` §2 (tag → v0.64.0, "what works" gains **live Hub sync for the KB + identity/teams**,
   external dependency note = the Phase-36 Hub app + `contract_version`); `bible/03` (`AppianHubProvider` +
   `hydrate_from_blob` + the sync-UX foundation); `bible/08` §9 (flip the Phase-37 block); banners
   (`AGENT_ONBOARDING.md` + `bible/00`); `tracker.md` §6; `progress/phase-37-hub-wireup.md` (as-built); README
   row; flip the Phase-37 spec statuses to SHIPPED. Push project-tracker.
5. **Live-acceptance script** (user-driven / headless-undrivable): deploy the Phase-36 Hub → configure Settings →
   Collaboration on two instances → onboard both → refresh-from-Appian on instance A (parse + publish blob) →
   sync on instance B (pull + hydrate, no parse) → team + attribution visible on both.

## Gate

CI green + docs updated → Phase 37 COMPLETE (the KB + identity/teams are live on the real Hub).
