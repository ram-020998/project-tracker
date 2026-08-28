# 29-04 — Build (multi-repo)

> **Status:** 📋 **PLANNED** (after 29-03 sign-off). · **Type:** genesis-core + genesis + genesis-workflows (built LOCAL; no tag/push until 29-06) · **Phase:** 29 (UX Design Stage) · **Gate:** independent review = SHIP.

---

## Goal

Build the locked 29-03 design in production across the three repos. **ADR-057 → Accepted.** Each build step
passes gates + gets an independent review; committed LOCAL on each repo's master (no tag/push until 29-06).

## Work — build order (respects the dependency chain)

**A. genesis-core (additive) — agent-node images.**
- Extend `kiro_node` / `nodes/agent.py` to accept image inputs (blackboard image files) and thread them into
  the agent turn as `client.prompt(images=…)` parts, **gated on `promptCapabilities.image`** (graceful no-op
  when absent — mirrors the SDK). Additive; `CORE_MAJOR` unchanged. Unit tests (images passed when capable;
  dropped when not). ruff/pytest green.

**B. genesis — backend + web.**
- **Render:** a PyMuPDF PDF→PNG utility (pinned `PyMuPDF` in `pyproject.toml`); runs off the event loop
  (`asyncio.to_thread`, §7 lesson) inside the workflow's program node. Rejects non-PDF.
- **`m0015`** migration (the locked generalized per-`(feature, stage)` artifact/lifecycle model;
  `current_version` → 15) + the store (a `FeatureStore` extension or a sibling store) + on-disk artifact dir;
  a `ux_design` `LifecycleService` machine (ADR-050) with m0013 audit. Bump the `current_version==N` tests.
- **`ux_design` chat mode:** a `ChatModeProfile` (`chat/mode_profile.py`) — seed + tools (genesis-kb +
  appian-dev **read** + `fs_read`/`fs_write` sandbox) + walk-open-questions/edit-HTML-live + completion.
- **API:** upload the mockup PDF (ADR-035 multipart) + launch the supervised `ux-design-analysis` run;
  read the artifact; **re-upload = delete prior page images + supersede artifact + re-run**; completion
  actions (→ `completed`). Read-only against Appian.
- **Web — make the UX stage live (no shell edits):** flip `STAGE_DEFS.ux` to `available:true` + a real
  `deriveStatus`; add a `ux` entry to `stage-registry.tsx` (`{Workspace, CardActions}`); build the inner UX
  **Workspace** (upload → running/supervised run → draft analysis in the annotatable Lavish review + the
  bound completion chat → Mark complete), reusing `StageWorkspaceHeader` + the Phase-20/21 review/chat
  components. jest-axe + dark parity + no hardcoded hex.

**C. genesis-workflows — the workflow.**
- `workflows/ux-design-analysis/` (graph.py + workflow.yaml + tests) per the locked node graph: program
  render/route/persist + narrow multimodal Kiro agent nodes (reliability trio each) + validators +
  open-questions + the grounded `verify` critic + escalation gate. Registry entries with **read-only**
  `appian-dev` + `genesis-kb` allowlists per node. `ci/validate_library.py` (reliability trio) green.

## Acceptance / DoD

- genesis-core: pytest + ruff green; image path unit-tested.
- genesis: pytest + ruff green (incl. the `m0015` `current_version==15` bump); web tsc/eslint/vitest/build
  green + **`web/static` committed** (stale-bundle guard); jest-axe clean; no hardcoded brand hex.
- genesis-workflows: `pytest` + `validate_library` + `validate_skills` green; the workflow declares the
  reliability trio on every agent node; read-only Appian allowlists.
- **ADR-057 → Accepted** in `reference/decision-log.md` + `bible/04`; bible/03 codebase-map updated with the
  new modules. Built LOCAL on each repo's master (no tag/push). Progress + tracker updated.

## Gate

Independent architecture/code review (29-05) returns **SHIP** (all MUST-FIX resolved).

## Notes

- **No tag/push here** — 29-06 does the coordinated release on the user's go-ahead.
- Live-acceptance (a real multimodal run against a real deck + the completion chat) is **headless-undrivable**
  — verified by the user; the build proves structure + gates + validators offline (stub the SDK / KB / MCP as
  the existing suites do).
