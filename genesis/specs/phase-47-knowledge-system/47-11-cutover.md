# 47-11 — Cutover

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Mandatory release &
> onboarding sub-spec. **Gate:** the user approves the cutover. Reversible by reverting the cutover commit.

## Work
1. **Archive** — `git mv` everything that existed under `genesis/` at the base (except `knowledge/`, `tools/`,
   `agents/`, `migration/`) into `genesis/archive/`, preserving history. Tag `knowledge-archive-v1`.
2. **New entry points** — a short `genesis/README.md` (what this folder is, the agents, how to start a session)
   and `genesis/AGENT_ONBOARDING.md` reduced to a pointer: use the role agents; a plain session reads
   `knowledge/_build/CORE.md` and follows its router. No agent reads `archive/`.
3. **Phases from now on** live in `genesis/phases/<nn>-<slug>/` (umbrella, sub-specs with manifests, handoffs,
   reviews, as-built); `history/INDEX.md` gets Phase 47's row from `genesis-docs`.
4. **Gate on every push** — `install.sh` installs a project-tracker `pre-push` hook running `gk validate` and
   `gk build --check`; the `docs-upkeep` procedure also runs them.
5. **Agents** — install the final versions; remove nothing else from `~/.kiro/agents`.
6. **Close Phase 47** — `genesis-docs` (its first real run) records Phase 47 in the new store; tag
   `knowledge-system-v1`; push.

## Definition of Done
Archive moved and tagged · the new entry points live · the pre-push gate blocks a deliberately broken store (shown
once, then reverted) · a fresh `genesis-build` session on a trivial manifest starts within S1 · tags pushed.

## Verification (reviewer)
Check no file outside `archive/` links into it (except `history/INDEX.md`), the agents' resources, the gate, the
tags, and that `git log --follow` works for a moved file.
