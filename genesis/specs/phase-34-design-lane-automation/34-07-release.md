# 34-07 — Release (coordinated genesis + genesis-workflows)

> **Status:** 🟡 DRAFTED. · Part of Phase 34. Repos: genesis + genesis-workflows. · **Depends on:** 34-06 clean. **GATED on the user's go-ahead.**

## Purpose

Ship Phase 34 as a coordinated multi-repo release; verify CI; flip ADR-062 → Accepted; update all docs.

## Release order (ADR-019)

genesis-core / kiro-agent-sdk unchanged (no pin moves). Two repos change:

1. **genesis-workflows** — the new `story-design-analysis` workflow + `design-doc` removed. Bump `vX.Y.0`
   (suggested **v0.16.0**), tag, push; CI green (`validate_library` = current−1+1, workflows pytest).
2. **genesis** — m0018 + backend + web. Bump `[project].version` + `web/src/version.ts` + `create_app` version
   (suggested **v0.62.0**), rebuild + commit `web/static`, tag, push; CI green (`genesis` pytest + ruff, the
   `frontend` stale-bundle guard, and **`clean-install` migrating a fresh DB to v18** + `genesis install`
   picking up the new workflow).

Both tags are new (safe). Re-pin nothing (neither core nor SDK moved). Commit via
`git -c user.name=Genesis -c user.email=genesis@local`.

## Verify

`glab ci list` green on both repos (master + tag pipelines); clean-install boots + migrates to **v18** + serves;
`design-doc` absent from a fresh catalog; `story-design-analysis` present.

## Docs (Definition of Done)

- **ADR-062 → Accepted** in `reference/decision-log.md` + mirror in `bible/04`; note the ADR-061 amendment.
- **bible/01 §2** — tag table (genesis vX.Y.0, genesis-workflows vX.Y.0), test counts, `current_version` → 18,
  m0018 in the migrations line, the Workbench "what works" gains the Design/Design-Review automation.
- **bible/03** — the Phase-34 codebase-map block (m0018 `kb_story_stages`, `StoryStageStore`,
  `story_design_finalizer.py`, the design-start endpoint, `story-design-analysis`, the web additions).
- **bible/08 §9** — flip the Phase-34 block to SHIPPED.
- **bible/00 + AGENT_ONBOARDING** — banners to the new versions + "Phase 34 COMPLETE".
- **tracker.md §6** — the release entry; **`progress/phase-34-design-lane-automation.md`** as-built; **README**
  phase row; spec statuses → SHIPPED.
- Push project-tracker (`git checkout -- genesis/.obsidian/{workspace,graph}.json` → `git pull --rebase` →
  push).

## Gate

CI green on both repos; docs updated + pushed; report with cited pipeline ids. **PHASE 34 COMPLETE.**
