# 34-02 — Remove the `design-doc` workflow

> **Status:** 🟡 DRAFTED. · Part of Phase 34. Repos: **genesis-workflows** (delete) + **genesis** (uninstall + scrub). · **Depends on:** 34-01.

## Purpose

Remove the superseded Phase-15 `design-doc` workflow from the library **and** from the running app's local
library (decision Q8). It is replaced by the ticket-level `story-design-analysis` (34-03) and is unused.

## Verified references (2026-09-04)

- **Functional (genesis-workflows):** `workflows/design-doc/` (graph.py, workflow.yaml, README.md, prompts/,
  tests/) + `registry.json` (the `design-doc` catalog entry, lines ~52–60).
- **Non-functional (genesis), doc-only mentions — safe to scrub:** `genesis/mcp/kb_server.py:14` (a comment
  citing "erd-generation / design-doc"), `genesis-core/genesis_core/nodes/reliable.py:4` (a docstring example),
  `web/src/dev/mockups/Mockups.tsx` (a dev-gallery reference).
- **No runtime dependency:** nothing pins/launches `design-doc`; the erd/design-doc Atlas coupling is historical
  (they were the only Atlas consumers). `genesis-workflows` `ci/validate_library.py` counts workflows — it drops
  by one.

## Steps

1. **genesis-workflows:** delete `workflows/design-doc/`; remove its `registry.json` entry; update any
   workflow-count assertions in tests + docs (`validate_library` count −1 — currently 12 → **11**). Run
   `validate_library` + `pytest -q workflows --ignore=workflows/_fixtures` green.
2. **genesis (running app):** uninstall from the local library — `genesis` library-remove for `design-doc`
   (drops it from `~/.genesis/library` + the lockfile) so it disappears from the catalog. Confirm via
   `genesis list` / `GET /api/catalog`.
3. **genesis (scrub, optional-but-tidy):** update the doc-only mentions (kb_server.py comment, reliable.py
   docstring, Mockups.tsx) so no stale "design-doc" references remain; rebuild `web/static` if Mockups changes.
4. **Confirm no orphans:** `grep -r "design-doc"` across both repos returns only historical progress/spec docs
   (which stay as history).

## Gate

`validate_library` + workflows pytest green (genesis-workflows); `design-doc` absent from `genesis list`;
review clean → proceed to 34-03.
