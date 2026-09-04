# 32-05 — Release

> **Status:** 🟡 DRAFTED. · Part of Phase 32. Repo: **genesis** (single repo + m0016). · Gate: CI green.

## Purpose

Ship Phase 32 as a single **genesis** release with the m0016 migration, verify CI, and bring the docs current.

## Release (ADR-019)

- **Single repo — genesis only.** No dependent pins move (genesis-core / kiro-agent-sdk / genesis-workflows /
  genesis-appian-parser unchanged). Bump `pyproject [project].version` + `web/src/version.ts` + `api/app.py`
  `create_app(version=…)` to the new **genesis vX.Y.0**.
- **Frontend built + committed.** `cd web && npm run build` → commit `web/static` (stale-bundle guard).
- **Commit** with the Genesis identity (`git -c user.name=Genesis -c user.email=genesis@local`), **tag
  `vX.Y.0`**, push master + tag (only on the user's go-ahead).
- **Verify CI** green via `glab ci list -R ramaswamy.u/genesis` — the `genesis` (pytest+ruff), `frontend`
  (tsc/eslint/vitest/build + stale-bundle guard), and **`clean-install`** (fresh non-editable install →
  **`genesis db upgrade` to v16** → serve → `/` + `/api/config/health`) jobs all pass.
- After release, `genesis db upgrade` on the running deployment (or the one-click updater) migrates to v16.

## Docs (Definition of Done)

- **ADR-060 → Accepted** in `reference/decision-log.md` + mirror into `bible/04-adrs-and-constraints.md`.
- **bible/01 (§2):** new genesis tag + test counts + a v-note (Finalize Stories / kb_epics+kb_stories / m0016);
  **`current_version` → 16** everywhere it's cited.
- **bible/03 (§4 codebase map):** `kb/stories.py::StoryStore`, m0016, the finalize + stories CRUD routes, the
  web Stories grid + `StoryDetailPage`, the promoted `Story`/`Epic` domain.
- **bible/08 (§9):** flip the Phase-32 block to SHIPPED (COMPLETE).
- **bible/00 banner + AGENT_ONBOARDING.md** "Last refreshed" + the release banner.
- **tracker.md §6** + a new `progress/phase-32-finalize-stories.md` as-built.
- Push project-tracker (`git checkout -- .obsidian/{workspace,graph}.json` → `git pull --rebase` → push).

## Gate

CI green on all three jobs; docs pushed; report with cited evidence (commit, tag, pipeline id, test counts).
Live-acceptance (finalize → grid → edit/add/delete) is user-driven.
