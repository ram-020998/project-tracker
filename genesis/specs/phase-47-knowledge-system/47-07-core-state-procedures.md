# 47-07 — Core, state, procedures, glossary, history index

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent:
> `genesis-migration-writer` (write mode). Review after each session.

## Sessions
1. **Core** — `knowledge/core.md` (→ `_build/CORE.md`, ≤ 15K tokens) from the reconciled units of the pseudo-area
   `all` plus the area summaries: what Genesis is; the architecture (layers, reliability trio, state/blackboard
   rule, subprocess workers, data plane, HITL, release model); every rule that applies everywhere (inlined by the
   build); the work loop; the working agreements; the **area router** (area → code globs → pack, generated from
   `areas.yaml`); how to load more (`gk context`, `gk rules`); what never to read (`archive/`).
2. **State** — `knowledge/state/current.yaml` (repos, tags, pins, DB version, test counts, last CI ids) and
   `gk state refresh` that regenerates what can be derived (git tags, `pyproject` versions and pins, the newest
   migration file); the rest is set by the release procedure. Nothing else in the store repeats these facts.
3. **Procedures** — `knowledge/procedures/`: `spec-authoring` (umbrella + sub-specs, the mandatory sub-specs, the
   context manifest, the Q&A with the user), `build-loop`, `review`, `release` (version surfaces, release order,
   CI checks), `fleet-and-live-acceptance` (backups, provisioning, restarts, Playwright), `docs-upkeep` (for
   `genesis-docs`: integrate into the right documents, never append a journal; refresh state; record the phase
   in `history/INDEX.md`; run every check). Each built as a skill.
4. **Glossary + history index** — `knowledge/glossary.md` (TERM units); `knowledge/history/INDEX.md`: one row per
   phase (what it delivered in one line, its versions, the post-cutover `archive/` paths of its spec and as-built).
   The index is the only document allowed to name `archive/` paths, as plain text.

## Context manifest (per session)
Umbrella §4, §7 · the reconciled units of the session's scope (`gk ledger query`) · the built area packs (for the
core's router and summaries) · `areas.yaml`.

## Definition of Done
All four sessions' checks green · `CORE.md` ≤ 15K tokens · `gk state refresh` matches the repos · every PROCEDURE
unit cited · every phase from 1 to 46 (and 47) has an index row.

## Verification (reviewer — umbrella §6 plus)
Every rule in `CORE.md` checked against its units; the state file compared with the repos; each procedure walked
step by step against its units (no mandatory step lost: release order, gates, pushes, CI checks, backups, "never
restart while a run is active").
