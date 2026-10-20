# 47-03 — `genesis-ctx`, the context compiler

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker (`genesis/agent-system/tools/genesis_ctx/`).
> Parent: `specs/phase-47-agent-context-system.md`. Formats: `47-02`. Built in session S2.

## 1. Goal

One small, deterministic, offline CLI that every agent and hook calls to get exactly the context a task needs, to check
a diff against the rules, and to keep the context layer healthy. It is also the migration tool (47-04).

## 2. Constraints

- **Python ≥ 3.11, standard library only** (`tomllib`, `argparse`, `pathlib`, `re`, `hashlib`, `subprocess`, `json`).
  A tiny TOML emitter for the files it writes (flat tables of strings / string arrays only).
- **Offline and fast:** no network; `status` < 2 s (no `git fetch`); `pack` < 3 s.
- **Read-only by default.** Only `index`, `mark`, `archive`, `propose-tags`, `add`, `verify-lossless --write` write, and
  only inside `project-tracker/genesis/`.
- Paths: `--tracker` (default: derived from the tool's own location) and `--repos` (default from
  `~/.kiro/genesis/install.json`, else `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`).
- Exit codes: `0` ok, `1` findings (lint/check problems), `2` usage/config error.
- Output is Markdown on stdout (agents read it); `--json` on `status`, `check`, `lint` for scripts.

## 3. Commands

| Command | Does |
|---|---|
| `status [--brief]` | For each of the five repos: branch, latest tag (`git describe --tags --abbrev=0`), dirty file count, commits ahead of upstream (from the local ref, no fetch); project-tracker dirty count; the "Active phase" line of `context/state/current.md`. `--brief` ≤ 25 lines (used by the `SessionStart` hook). |
| `pack <sub-spec-id or path> [--areas a,b] [--out FILE]` | Compile the task's context pack (§4). With only `--areas` (no sub-spec) for bug fixes and small tasks. Writes `context/.packs/<id>.md` and prints its path + a summary table. |
| `check (--since <rev> \| --files f1 f2 … \| --staged) [--repo NAME]` | Map changed files → areas (globs) → a checklist of every applicable ADR rule and lesson rule (with ids) + the area's gate commands. The review agent must answer each line OK / VIOLATION / N/A. |
| `adr <ID…> [--no-chain]` | Print the decision-log section(s) + every `bible/04` bullet referencing the id + the amendment chain (default on). |
| `lesson <ID…>` | Print the lesson bullet(s) verbatim. |
| `area <name>` | Print the area's catalog line, its ADR/lesson one-liners, its code-map sections, docs, skills. |
| `search <regex> [--archive] [--max N]` | Grep across the active layer (and `archive/`, `specs/`, `progress/` with `--archive`); prints file:line + 1 line of context. History lookups only. |
| `index` | Regenerate `context/_generated/*` from the tag files + sources. Deterministic (sorted, stable). |
| `lint [--quiet] [--specs-only]` | §5. |
| `add adr --id ADR-NNN --title … --areas … --rule …` / `add lesson --areas … --rule … --body-file F` | Scaffold a new ADR section (end of `decision-log.md`) + tag entry, or a new marked lesson bullet (end of `bible/06` §7) + tag entry; then `index`. Used by `genesis-docs` (47-08). |
| `mark` | One-shot: insert `<!-- L-NNN -->` markers into unmarked `bible/06` lesson bullets (idempotent). |
| `archive --plan FILE [--apply]` | One-shot: move the heading/line ranges named in a plan file into `archive/` files, leaving a one-line pointer; dry-run by default (47-04). |
| `propose-tags` | One-shot: write `context/tags/*.proposed.toml` with candidate areas (keywords + phase→area + path mentions), candidate amendment edges (from "amends / refines / supersedes ADR-NNN" text), candidate one-liners (first sentence of the `bible/04` bullet, or the lesson's bold lead) and a **confidence** per item (47-05). |
| `verify-lossless --baseline <rev> [--write]` | §6. |

## 4. The pack algorithm

```
inputs : manifest M (from the sub-spec's "## Context manifest" TOML block; empty if --areas only)
areas  = M.areas ∪ --areas ∪ areas_matching(M.code paths) ∪ {always-on areas: security, release-ci}
adrs   = M.adrs ∪ {a | a.areas ∩ areas ≠ ∅} ∪ {a | a.paths match M.code}
adrs   = closure(adrs, amends ∪ amended_by ∪ superseded_by)        # whole chain, both directions
lessons= M.lessons ∪ {l | l.areas ∩ areas ≠ ∅}
codemap= {s | s.areas ∩ areas ≠ ∅}
docs   = M.docs ∪ area.docs ∪ M.upstream sub-specs (their files) ∪ the umbrella spec
```

Pack layout (Markdown):

1. **Header** — task id, areas (and *why* each: manifest / path `X` / always-on), token estimate, budget verdict.
2. **Inclusion table** — every ADR / lesson / section with the reason it is included (area, path, manifest, chain).
3. **ADRs — full text** (decision-log section + `bible/04` bullet(s)), sorted by id.
4. **Lessons — full text**, sorted by id.
5. **Code map — the matching sections** verbatim.
6. **Read next** — the docs and code paths (paths only, with reasons): the agent opens them itself, in ranges.

Budget: warn at 40K tokens (chars ÷ 4), fail at 80K with a hint to narrow `areas`. Excluded items remain visible in L0
as one-liners, so narrowing never hides a rule.

## 5. Lint

Fails (exit 1) on any of:

- an `## ADR-NNN` section in `decision-log.md` with no `tags/adr.toml` entry, or an entry with no areas or no `rule`;
- an unmarked lesson bullet in `bible/06` §7, a marker without a tag entry, a duplicate marker;
- a `bible/03` section with no `tags/codemap.toml` entry;
- an unknown area name anywhere; an area whose globs match no file (warning only);
- asymmetric `amends`/`amended_by`; a `superseded` ADR without `superseded_by`;
- a tag whose `reviewed_fp` ≠ the current fingerprint of its full text (**the text changed since the one-liner was
  reviewed** — review the rule, then `index` refreshes the fingerprint);
- `_generated/*` out of date (regenerate and diff);
- L0 over 15K tokens; `state/current.md` over 4K tokens;
- broken relative links in `context/`, `agent-system/`, `AGENT_ONBOARDING.md`;
- a sub-spec of phase ≥ 48 without a valid `## Context manifest`, or referencing unknown ids/areas.

`--specs-only` runs the last check only (used by the spec agent's Stop hook).

## 6. verify-lossless

1. Read the **baseline mandatory corpus** at `<rev>` via `git show <rev>:<path>` (the 13 files of 47-01 §2.1).
2. Split each file into **units**: blank-line-separated blocks; a block that is a list is further split into its
   top-level bullets; table rows are units; fenced blocks are one unit each.
3. Normalize: strip `<!-- L-NNN -->` markers, collapse whitespace, strip trailing spaces; hash (`sha256[:16]`).
4. Build the same unit hash set over **every `.md` file under `project-tracker/genesis/`** in the working tree.
5. Report every baseline unit whose hash is absent → must be **zero**. Units ≤ 3 characters and the archive pointer lines
   are ignored.
6. `--write` stores `archive/LOSSLESS.json` (baseline rev, counts, result, timestamp).

## 7. Tests (`agent-system/tests/`, run with `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv/bin/python -m pytest`)

Fixtures are miniature copies of the real shapes (a 4-ADR decision-log with a `(Q1)` heading and an amendment, a
`bible/04` with a combined `ADR-002/004/020` bullet and an `Amendment (v0.69.0)` bullet, a `bible/06` with 5 lessons,
a `bible/03` with a base block and two `# ── Phase` blocks, two sub-specs with manifests). Required cases: section
extraction (incl. `(Q1)` headings and the last section), combined-id bullets, amendment closure both directions, path →
area mapping across repos, pack budget warn/fail, every lint rule (one failing fixture each), `mark` idempotence,
`archive` dry-run vs apply + pointer lines, `verify-lossless` detects a deleted paragraph and ignores a moved one,
`status` on a temp git repo with a tag, TOML emitter round-trip. Target ≥ 40 tests, all green.

## 8. Acceptance

All tests green; `genesis-ctx --help` lists §3; `status` and `pack --areas chat` run against the real tracker (with the
47-05 tags once they exist; with empty tags they must still run and report "untagged").

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md"]
```
