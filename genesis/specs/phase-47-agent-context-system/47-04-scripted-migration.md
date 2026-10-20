# 47-04 — Scripted migration and lossless proof

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D7, D8. Tools: `47-03` (`archive`, `mark`, `verify-lossless`, `propose-tags`). Session S3.

## 1. Goal

Take history out of the mandatory set and give lessons stable ids, **by script**, with the agent reading only the
scripts' reports — never the corpus. Prove that no paragraph was lost.

## 2. Principles

1. **Move, never rewrite.** Text is cut from one file and pasted verbatim into an `archive/` file (or into
   `context/L0-core.md` for the implementation contracts). Nothing is summarized in this step.
2. **Pointer at the old place.** Each moved block leaves one line, e.g.
   `> 📦 Moved verbatim to [archive/tracker-status-log.md](archive/tracker-status-log.md) (Phase 47-04, 2026-10-2x). Search with \`genesis-ctx search <term> --archive\`.`
3. **Duplicates are removed from the active layer only.** The other copy stays (in the archive or in its home file),
   so `verify-lossless` stays green by construction.
4. **One commit per step**, so any step can be reverted on its own.

## 3. Baseline

Before any change: commit or stash pending project-tracker edits, record `BASELINE=$(git rev-parse HEAD)` in
`archive/LOSSLESS.json` (via `verify-lossless --baseline $BASELINE --write` at the end).

## 4. Steps (the plan file `agent-system/migration/47-04.plan.toml`)

| # | Move | From → To | Selector |
|---|---|---|---|
| 1 | Status log | `tracker.md` §6 body → `archive/tracker-status-log.md` | from the line after `## 6. Status log` to EOF. §6 keeps its heading, the pointer, and a note: "From Phase 47 on: ≤ 5 lines per phase; detail lives in `progress/`." |
| 2 | Shipped phases | `bible/08` → `archive/bible-08-shipped-phases.md` | every `### ` block whose heading contains `SHIPPED` or `CLOSED`, up to the next `### ` / `## ` / the closing "Do not start backlog…" paragraph. Keeps the `## 9` heading, non-shipped blocks and the closing paragraph. |
| 3 | Onboarding banners | `AGENT_ONBOARDING.md` → `archive/onboarding-banners.md` | the `## ⭐ SHIPPED — Phase 26..30 …` sections and the historical note above them. (The file itself is rewritten at 47-10; the full pre-switch version is also archived then.) |
| 4 | Lesson ids | `bible/06` in place | `genesis-ctx mark` inserts `<!-- L-NNN -->` after the dash of each top-level lesson bullet in §7, document order, L-001.. |
| 5 | Tag proposals | — → `context/tags/*.proposed.toml` | `genesis-ctx propose-tags` (input to 47-05) |

`bible/00` and `bible/01` are archived in 47-05, at the moment their replacements (`L0-core.md`, `state/current.md`)
exist. The `bible/04` "Key implementation contracts" bullets move into `L0-core.md` in 47-05 as well.

Each step: `genesis-ctx archive --plan … --step N` (dry run → shows line ranges and byte counts) → `--apply` →
`verify-lossless --baseline $BASELINE` (must be 0 missing) → commit.

## 5. Duplicate report

`verify-lossless` also prints units that appear **more than once in the active layer** (everything outside `archive/`,
`specs/`, `progress/`). For each, the agent decides keep/remove using only the unit text and its locations (a short
table). Expected to be small after steps 1–3 (most duplication was between history files).

## 6. Expected result

| | Before | After 47-04 |
|---|---|---|
| `tracker.md` | 386 KB | ~33 KB (and no longer mandatory) |
| `bible/08` | 134 KB | ≲ 15 KB backlog / what's next |
| `AGENT_ONBOARDING.md` | 35 KB | ~10 KB until the 47-10 rewrite |
| Archive | — | ~500 KB verbatim, never mandatory |

## 7. Acceptance

- `verify-lossless --baseline $BASELINE` → **0 missing units**; result written to `archive/LOSSLESS.json`.
- Every lesson in `bible/06` §7 has exactly one marker (`lint` lesson check passes; tags may still be missing — 47-05).
- `git log` shows one commit per step; each commit message names the step.
- The agent's context in S3 stays under 25 % (it reads plan output, diffs of pointer lines and reports — not the files).

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-03-genesis-ctx.md"]
```
