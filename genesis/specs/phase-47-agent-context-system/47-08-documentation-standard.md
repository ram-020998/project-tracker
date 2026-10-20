# 47-08 — Documentation standard and the documentation agent's write-back

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D4, D7. Session S5. Becomes the body of the `genesis-doc-writeback` skill.

## 1. Goal

Every fact has **one** home. The documentation agent moves a finished phase's knowledge into those homes, keeps the
always-loaded layer small, and leaves `genesis-ctx lint` green — so the context cost of a new session stays flat as
Genesis grows.

## 2. Routing table (one home per fact)

| Fact | Single home | Also | Never |
|---|---|---|---|
| New ADR | `reference/decision-log.md` section (via `genesis-ctx add adr`) | `tags/adr.toml` entry with areas + one-line `rule` | a new `bible/04` bullet |
| ADR amended | the amending ADR's section says "Amends ADR-0NN: …"; both tag entries get `amends` / `amended_by` | review the amended ADR's `rule` | editing the old ADR's text (except its Status line) |
| New lesson | a marked bullet at the end of `bible/06` §7 (via `genesis-ctx add lesson`), bold lead = the rule | `tags/lesson.toml` areas | lessons inside progress docs only |
| New / moved module | `bible/03` — a new `# ── Phase NN — … ──` block (or edit the base-map entry) | `tags/codemap.toml` | — |
| Current versions, tests, DB version, what works | `context/state/current.md` (**overwrite**) | — | appending history to it |
| What happened in a phase (as-built) | `progress/phase-NN-<slug>.md` | one line in `context/changelog.md`; ≤ 5 lines in `tracker.md` §6 | long tracker entries; banners |
| Phase status | the umbrella spec's Status line | one README phase-table row | the onboarding index |
| Backlog / what's next | `specs/backlog/*.md` | one line in `bible/08` "what's next" | shipped-phase blocks in `bible/08` |
| Process / working agreement change | `bible/07` | — | — |
| Procedure change (how to release, review, …) | the matching skill in `agent-system/skills/` + `update.sh` | — | — |
| CI pipeline ids, commit hashes | the release sub-spec's As-run + the progress doc | — | L0, state, digests |

## 3. The phase write-back (what `genesis-docs` does, in order)

1. **Gather** (no bulk reading): the umbrella; each sub-spec's **As-built** / **As-run**; `specs/<phase>/reviews/*`;
   `git log <prev-tag>..<new-tag> --oneline` per changed repo; `genesis-ctx status`.
2. **ADRs:** each ADR the phase proposed → **Accepted** (Status line) in `decision-log.md`; new ones via `add adr`;
   amendment links in tags; review affected one-liners.
3. **Lessons:** each "Lesson candidate" in the As-built sections → keep (add via `add lesson`), merge into an existing
   lesson (append a sentence to it; refresh its fingerprint), or drop (state why in the progress doc).
4. **Code map:** "Code-map changes" → `bible/03` block + tags.
5. **State:** overwrite `context/state/current.md` (versions, DB version, test counts, what works, active phase).
6. **History:** write `progress/phase-NN-<slug>.md` (from the As-built sections, cited); one `changelog.md` line
   (`2026-10-25 — Phase 48 <title> — genesis v0.78.0 … — ADR-078`); ≤ 5-line `tracker.md` §6 entry; README row.
7. **Skills:** if the phase changed a procedure, edit the skill in `agent-system/skills/` and tell the user to run
   `update.sh`.
8. **Verify:** `genesis-ctx index && genesis-ctx lint` green; L0 budget printed; then commit project-tracker
   (`git -c user.name=Genesis -c user.email=genesis@local commit`) and **ask** before pushing.

## 4. Budgets (enforced by `lint`)

L0 ≤ 15K tokens · `state/current.md` ≤ 4K · each ADR `rule` and lesson rule ≤ 220 chars · a tracker §6 entry ≤ 5
lines. When L0 approaches its budget, the docs agent proposes (never silently applies) compressions: merging
superseded ADR lines into their successor's line, or grouping lessons by area in the digest.

## 5. `add` commands (47-03 §3) — formats they write

- **ADR section** appended to `decision-log.md`:
  `## ADR-078 — <title> (Phase 48) — **Accepted**` + bullets **Status**, **Context**, **Decision**, **Alternatives
  rejected**, **Consequences** (the existing house format).
- **Lesson bullet** appended to `bible/06` §7: `- <!-- L-087 --> **<rule sentence> (Phase 48).** <body>`.
- Matching tag entries, then `index`.

## 6. Acceptance

A dry run on Phase 46 (read-only): given only Phase 46's sub-spec As-built sections, the docs agent's planned
write-back (printed, not applied) maps every ADR (075, 076) and every Phase-46 lesson already in `bible/06` to the
right home — checked in 47-09.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-03-genesis-ctx.md"]
```
