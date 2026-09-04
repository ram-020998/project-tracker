# 33-05 — Release

> **Status:** ✅ SHIPPED (genesis v0.61.0). · Part of Phase 33. Repo: **genesis** (single repo + m0017 + `@dnd-kit`). · Gate: CI green.

## Purpose

Ship Phase 33 as a single **genesis** release with the m0017 migration + the `@dnd-kit` dep, verify CI, and
bring the docs current.

## Release (ADR-019)

- **Single repo — genesis only.** No dependent pins move (core / SDK / workflows / parser unchanged). Bump
  `pyproject [project].version` + `web/src/version.ts` + `api/app.py` `create_app(version=…)` to the new
  **genesis vX.Y.0** (suggest **v0.61.0**).
- **`@dnd-kit` pinned** in `web/package.json` (exact versions) + `package-lock.json` committed.
- **Frontend built + committed.** `cd web && npm run build` → commit `web/static` (stale-bundle guard).
- **Commit** with the Genesis identity (`git -c user.name=Genesis -c user.email=genesis@local`), **tag
  `vX.Y.0`**, push master + tag (only on the user's go-ahead).
- **Verify CI** green via `glab ci list -R ramaswamy.u/genesis` — the `genesis` (pytest+ruff), `frontend`
  (tsc/eslint/vitest/build + stale-bundle guard), and **`clean-install`** (fresh non-editable install →
  **`genesis db upgrade` to v17** → serve → `/` + `/api/config/health`) jobs all pass.
- After release, `genesis db upgrade` on the running deployment (or the one-click updater) migrates to v17.

## Docs (Definition of Done)

- **ADR-061 → Accepted** in `reference/decision-log.md` + mirror into `bible/04-adrs-and-constraints.md`;
  note the **ADR-049 amendment** (Workbench nav).
- **bible/01 (§2):** new genesis tag + test counts + a v-note (Workbench / `workbench_boards`+`kb_board_cards` /
  m0017); **`current_version` → 17** everywhere cited; add m0017 to the migrations line + Workbench to
  "what works".
- **bible/03 (§4 codebase map):** `kb/boards.py::BoardStore`, m0017, `api/workbench.py`, the web
  `features/workbench` (nav + landing + board + dnd + import + drawer), the two `LifecycleState` members +
  `STORY_LANES`.
- **bible/08 (§9):** flip the Phase-33 block to SHIPPED (COMPLETE).
- **bible/00 banner + AGENT_ONBOARDING.md** "Last refreshed" + release banner (+ a Phase-33 headline).
- **tracker.md §6** + a new `progress/phase-33-workbench.md` as-built.
- **README.md** phase table += a Phase 33 row.
- Push project-tracker (`git checkout -- .obsidian/{workspace,graph}.json` → `git pull --rebase` → push).

## Gate

CI green on all three jobs; docs pushed; report with cited evidence (commit, tag, pipeline id, test counts).
Live-acceptance (add app → import → drag lanes → persist) is user-driven.
