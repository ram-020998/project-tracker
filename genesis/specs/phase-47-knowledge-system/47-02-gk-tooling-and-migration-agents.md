# 47-02 — `gk` tooling and the migration agents

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent: `kiro_default`.
> Review: `genesis-migration-reviewer` (adversarial: it tries to make each check pass on wrong input).

## Context manifest — read only this
Umbrella §3–§9 · `migration/schemas/`, `areas.yaml`, `batches.yaml`, `templates/` (47-01) · the reviewer agent
(`~/.kiro/agents/genesis-migration-reviewer.json` + `prompts/genesis-migration-reviewer.md`) as the pattern.

## Goal
Every check the method relies on is a program with tests — including tests proving it **fails** on wrong work —
and each migration role has its own agent with enforced write limits.

## Carried from the 47-01 review (`migration/reviews/47-01-review-1.md`) — fix first, in this unit
- **M1** `check_batches.py` docstring still says 250K (the code enforces 200K) — fix the text.
- **M2** `coverage.schema.json`: when `skip` is `duplicate`, require `duplicate_of` (conditional) — plus a negative test.
- **M3** not a schema change: the only sub-numbered "ADR" in the corpus is `ADR-025-03` in `bible/04` line 73, a
  mis-reference to Phase 25-03's `atomic_json` (no such ADR exists; the reviewer's second example `ADR-25-08` does not
  occur in the corpus). Keep the id pattern; note it in `PROGRESS.md` §Known source issues so the P1 extractor records
  the line faithfully and reconcile logs it as a conflict.
- **M4** `gk inventory`: record archive-only files consistently (one convention for chars/lines, documented).
- **P1** `gk batches check` (new): besides tiling and the cap, verify **mechanically** that every partial-file boundary
  falls on a safe split (not inside a paragraph, list item, table or fenced code block) — with negative tests.
- **P3** `gk inventory` reads file contents **at the base tag** (`git show <tag>:<path>`), never the working tree.

## Work
### A. `gk` — `genesis/tools/gk/gk.py`, Python 3 standard library only, run as `python3 genesis/tools/gk/gk.py`
| Command | Does |
|---|---|
| `inventory` | regenerates `migration/inventory.csv` (replaces the 47-01 script) |
| `ledger validate <batch>` | schema; unique ids; `lines` inside the file at the base tag; **every `exact` item occurs literally in its cited lines** |
| `coverage <batch>` | % of non-blank lines covered; lists gaps; **validates skip reasons** (`blank` is blank, `heading-only` is a heading, `formatting` has no words, `duplicate:` points to a unit in the batch) |
| `ledger query` | filter units by `--area --type --src --fate`, JSONL or a compact table |
| `fates <area>` | every unit has a fate; merge/supersede targets exist; no unit with `wrong` lacks a conflict id |
| `copycheck <paths>` | 12-word shingles of new docs vs all `extract` sources; ignores code spans, `exact` items and `<!-- verbatim: … -->` blocks; reports each hit with both locations |
| `exact <paths>` | paths, modules, symbols, migrations and commands named in new docs exist in the repos at HEAD |
| `validate` | the store: frontmatter schema; unique ids; known areas; no superseded rule in an active pack; links resolve; no link into `archive/` (except `history/INDEX.md`); state facts (version strings, DB version, test counts, CI ids) only in `state/current.yaml`; a provenance comment on every authored paragraph; budgets |
| `build [--check]` | generates `knowledge/_build/` (CORE.md, `areas/<a>/SKILL.md`, `procedures/<p>/SKILL.md` with `name`/`description` frontmatter), strips provenance, deterministic; `--check` fails when stale |
| `budget` | chars/4 per built document against umbrella §7 |
| `rules --paths <files>` · `context <sub-spec>` | the deterministic selection of umbrella §4 |
| `sample --seed --kind source\|ledger\|doc --n` | reproducible samples for reviewers |
| `next-id <LSN\|STD\|WA>` | allocates rule ids |

Tests: `genesis/tools/gk/tests/` with `python3 -m unittest`, fixtures under `tests/fixtures/`. **Each check has
at least one negative test** — e.g. a prose line marked `formatting` fails coverage; an `exact` item absent from
its lines fails validation; a 12-word copy is caught while a code span is ignored; a stale `_build/` fails
`build --check`; a version string outside `state/` fails `validate`.

### B. Agents — sources in `genesis/agents/`, installed by `genesis/agents/install.sh`
| Agent | Writes only to | Notes |
|---|---|---|
| `genesis-migration-extractor` | `migration/ledger/`, `migration/questions/`, `migration/handoffs/`, `migration/PROGRESS.md` | extract mode and question mode; never writes new docs |
| `genesis-migration-writer` | `migration/reconciled/`, `migration/conflicts.md`, `knowledge/`, `migration/handoffs/`, `migration/PROGRESS.md` | reconcile mode and write mode; opens old docs only to resolve a named unit |
| `genesis-migration-examiner` | `migration/exams/` | answers from `knowledge/_build/` only and cites the document for every answer |
| `genesis-migration-reviewer` | (exists) | move its source into `genesis/agents/`; the installed copy stays identical |

Config pattern (verified 2026-10-19): `write` in `tools` but **not** in `allowedTools`, `write.allowedPaths`
set, shell deny list for git writes / `rm` / `mv` / `sed -i` / `gsm` (the extractor and writer may run
`git add <explicit paths>`, `git commit`, `git pull --rebase`, `git push` — allow exactly those), run without
`--trust-all-tools`. Each prompt carries the session discipline (budgets, read only the context manifest, the
search-safety rules, the handoff and the commit procedure).

**Shell is not path-limited (found 2026-10-19).** `write.allowedPaths` limits only the write tool; a script run
through the shell can write anywhere. Every agent prompt therefore forbids running repo-writing scripts in place, and
the **reviewer checks every commit of a unit changes only the paths its agent may write**
(`git show --name-only <commit>`). Deny git writes with the anchored pattern used by the reviewer config
(`\bgit\s+(?:-[Cc]\s+\S+\s+)*(?:add|commit|…)\b`) so words inside paths or messages do not trip it; the extractor's
and writer's lists omit only `add`, `commit`, `pull`, `push`.

## Definition of Done
All 47-01 review findings above closed · all unit tests pass, including every negative test · every agent passes `kiro-cli agent validate` and a guardrail
smoke test (an out-of-scope write fails, `rm` is denied, an allowed write works) recorded in the handoff ·
`install.sh` is idempotent.

## Verification (reviewer — on top of umbrella §6)
Run the tests. Then, on copies under `/tmp/genesis-migration-review/`, try to make `coverage`, `ledger validate`,
`copycheck`, `fates`, `validate` and `build --check` pass on deliberately wrong input; each success is a BLOCKER.
Re-run the guardrail smoke tests.
