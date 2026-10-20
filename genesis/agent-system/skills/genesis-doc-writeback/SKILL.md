---
name: genesis-doc-writeback
description: Use when writing a finished Genesis phase's knowledge back into its one home — the documentation standard (routing table), genesis-ctx add adr|lesson, the state overwrite, and the L0 budgets. For the genesis-docs agent.
---

# Documentation write-back (the Genesis documentation standard)

One home per fact. Move a finished phase's knowledge into those homes, keep the always-loaded layer small, and leave
`{{GENESIS_HOME}}/bin/genesis-ctx lint` green. Full spec: `{{TRACKER}}/specs/phase-47-agent-context-system/47-08-documentation-standard.md`.

## Routing table — one home per fact
| Fact | Single home | Also | Never |
|---|---|---|---|
| New ADR | `reference/decision-log.md` section (via `{{GENESIS_HOME}}/bin/genesis-ctx add adr`) | a `tags/adr.toml` entry (areas + one-line `rule`) | a new `bible/04` bullet |
| ADR amended | the amending ADR's section says "Amends ADR-0NN: …"; both tag entries get `amends`/`amended_by` | review the amended ADR's `rule` | editing the old ADR's text (except its Status line) |
| New lesson | a marked bullet at the end of `bible/06` §7 (via `{{GENESIS_HOME}}/bin/genesis-ctx add lesson`), bold lead = the rule | `tags/lesson.toml` areas | lessons inside progress docs only |
| New/moved module | a `bible/03` `# ── Phase NN — … ──` block (or edit the base-map entry) | `tags/codemap.toml` | — |
| Current versions / tests / DB version / what works | `context/state/current.md` (**overwrite**) | — | appending history to it |
| What happened in a phase | `progress/phase-NN-<slug>.md` | one `context/changelog.md` line; ≤ 5 lines in `tracker.md` §6 | long tracker entries; banners |
| Phase status | the umbrella Status line | one README phase-table row | the onboarding index |
| Backlog / what's next | `specs/backlog/*.md` | one line in `bible/08` "what's next" | shipped-phase blocks in `bible/08` |
| Process / working-agreement change | `bible/07` | — | — |
| Procedure change (release/review/…) | the matching skill in `agent-system/skills/` + `update.sh` | — | — |
| CI pipeline ids / commit hashes | the release sub-spec's As-run + the progress doc | — | L0, state, digests |

## Write-back, in order (no bulk reading)
1. **Gather:** the umbrella; each sub-spec's **As built**/**As run**; `specs/<phase>/reviews/*`;
   `git log <prev-tag>..<new-tag> --oneline` per changed repo; `{{GENESIS_HOME}}/bin/genesis-ctx status`.
2. **ADRs:** each proposed ADR → **Accepted** (Status line) in the decision-log; new ones via `{{GENESIS_HOME}}/bin/genesis-ctx add adr`;
   amendment links in the tags; review affected one-liners.
3. **Lessons:** each "Lesson candidate" in the As-built → keep (`{{GENESIS_HOME}}/bin/genesis-ctx add lesson`), merge into an existing lesson
   (append a sentence, refresh its fingerprint with `{{GENESIS_HOME}}/bin/genesis-ctx index --reviewed L-0NN`), or drop (say why in `progress/`).
4. **Code map:** "Code-map changes" → a `bible/03` block + a `tags/codemap.toml` entry.
5. **State:** overwrite `context/state/current.md` (versions, DB version, test counts, what works, active phase).
6. **History:** write `progress/phase-NN-<slug>.md` (from the As-builts, cited); one `changelog.md` line
   (`2026-10-25 — Phase 48 <title> — genesis v0.78.0 … — ADR-078`); a ≤ 5-line `tracker.md` §6 entry; the README row.
7. **Skills:** if a procedure changed, edit the skill in `agent-system/skills/` and tell the operator to run `update.sh`.
8. **Verify:** `{{GENESIS_HOME}}/bin/genesis-ctx index && {{GENESIS_HOME}}/bin/genesis-ctx lint` green; print the L0 budget. Commit project-tracker locally; ask before pushing.

## `{{GENESIS_HOME}}/bin/genesis-ctx add` formats
- `{{GENESIS_HOME}}/bin/genesis-ctx add adr --id ADR-0NN --title "…" --areas a,b --rule "…" [--status accepted|proposed] [--amends ADR-0MM] [--body-file F]`
  → appends `## ADR-0NN — <title> (Phase NN) — **Accepted**` with the house bullets (Status, Context, Decision,
  Alternatives rejected, Consequences) + the tag entry; updates the amended ADR's `amended_by`; then `index`.
- `{{GENESIS_HOME}}/bin/genesis-ctx add lesson --areas a,b --rule "<rule sentence>" [--phase NN] [--body-file F]`
  → appends `- <!-- L-0NN --> **<rule> (Phase NN).** <body>` to `bible/06` §7 + the tag entry; then `index`.

## Budgets (enforced by lint)
L0 ≤ 15K tokens · `state/current.md` ≤ 4K · each ADR `rule` and lesson rule ≤ 220 chars · a tracker §6 entry ≤ 5 lines.
When L0 nears its budget, **propose** (never silently apply) a compression: merge a superseded ADR's line into its
successor's, or group lessons by area in the digest.
