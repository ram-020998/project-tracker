# 38-07 — Release

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis**. · **Depends on:** 38-06. ADR-019.

## Release steps (ADR-019)

1. Version bump genesis → suggest **v0.65.0** (the three anchors). **No migration** (m0019 stands); no core/SDK/
   workflows pin moves.
2. Gates: genesis pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`.
3. Commit + tag `v0.65.0` + push master + tag; **CI green** (genesis + frontend + clean-install still v19).
4. **Docs:** `bible/01` §2 (tag → v0.65.0; "what works" gains the **full collaborative SDLC** — shared features/
   artifacts/stories/boards + the collaboration UX + adoption); `bible/03` (the per-entity sync mappings + the
   collaboration UX components); `bible/04` (any ADR-063 addendum); `bible/08` §9 (flip the Phase-38 block →
   the collaboration program COMPLETE for KB+features+stories+boards; shared-memory noted as the remaining
   deferred phase); banners (`AGENT_ONBOARDING.md` + `bible/00`); `tracker.md` §6; `progress/phase-38-
   collaborative-sdlc.md` (as-built); README row; flip the Phase-38 spec statuses to SHIPPED. Push
   project-tracker.
5. **Full-SDLC live-acceptance script** (user-driven / headless-undrivable): with the Hub deployed + ≥2
   instances onboarded to one team → instance A (PO) authors + publishes a Spec → instance B (UX) auto-sees the
   feature + spec, does + publishes UX Design → a Dev instance picks up Technical Design then Breakdown →
   Finalize publishes stories → board lanes sync across instances → verify staleness badge (edit the spec →
   downstream shows "changed"), advisory markers, attribution, and the one-time adoption bulk-publish.

## Gate

CI green + docs updated → Phase 38 COMPLETE — the local-first + shared-Hub collaboration program is delivered
for the KB, features/artifacts, stories, and boards (shared-memory sync remains the one deferred future phase).
