# 47-03 — `genesis-ctx`, the context compiler

> **Status:** 🟢 BUILT 2026-10-20. Repo: project-tracker (`genesis/agent-system/tools/genesis_ctx/`).
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
| `check (--since <rev> \| --files f1 f2 … \| --staged) [--repo NAME]` | Map changed files → areas (globs) → a checklist of every applicable ADR rule and lesson rule (with ids) + the area's gate commands (`gates`, 47-02 §3). The review agent must answer each line OK / VIOLATION / N/A. |
| `adr <ID…> [--no-chain]` | Print the decision-log section(s) + every `bible/04` bullet referencing the id + the amendment chain (default on). |
| `lesson <ID…>` | Print the lesson bullet(s) verbatim. |
| `area <name>` | Print the area's catalog line, its ADR/lesson one-liners, its code-map sections, docs, skills. |
| `search <regex> [--archive] [--max N]` | Grep across the active layer (and `archive/`, `specs/`, `progress/` with `--archive`); prints file:line + 1 line of context. History lookups only. |
| `index [--reviewed ID… \| --reviewed-all]` | Regenerate `context/_generated/*` from the tag files + sources. Deterministic (sorted, stable). Fingerprints: a plain `index` only fills **empty** `reviewed_fp` values; `--reviewed ADR-031 L-004 …` (after reviewing those rules) or `--reviewed-all` refreshes them to the current text. A plain `index` never silences a drifted rule. `reviewed_fp` is the only tag field `index` writes, in place, one line per entry (comments and order kept). |
| `lint [--quiet] [--specs-only]` | §5. |
| `add adr --id ADR-NNN --title … --areas … --rule …` / `add lesson --areas … --rule … --body-file F` | Scaffold a new ADR section (end of `decision-log.md`) + tag entry, or a new marked lesson bullet (end of `bible/06` §7) + tag entry; then `index`. Used by `genesis-docs` (47-08). |
| `mark` | One-shot: insert `<!-- L-NNN -->` markers into unmarked `bible/06` lesson bullets (idempotent). |
| `archive --plan FILE [--apply]` | One-shot: move the heading/line ranges named in a plan file into `archive/` files, leaving a one-line pointer; dry-run by default (47-04). |
| `propose-tags` | One-shot: write `context/tags/*.proposed.toml` with candidate areas (keywords + phase→area + path mentions), candidate amendment edges (from "amends / refines / supersedes ADR-NNN" text), candidate one-liners (first sentence of the `bible/04` bullet, or the lesson's bold lead) and a **confidence** per item (47-05). |
| `verify-lossless --baseline <rev> [--write]` | §6. |

### 3.1 Archive plan format (`archive --plan FILE [--step N] [--apply]`)

The plan is TOML (stdlib `tomllib`). The tool validates it; 47-04 writes the actual plan (`agent-system/migration/47-04.plan.toml`).

```toml
date = "2026-10-21"                       # optional; used in pointer lines (default: today)

[[step]]                                  # one entry per move; several entries may share `n` (run together)
n       = 1                               # step number (`--step 1` runs every entry with n = 1)
name    = "Status log"
source  = "tracker.md"                    # relative to project-tracker/genesis/
dest    = "archive/tracker-status-log.md" # created (with a `# <name>` title) if missing, else appended
# selector A — one contiguous range:
start   = '^## 6\. Status log'            # regex; the first matching line
include_start = false                     # false: the range begins on the line after `start` (heading stays)
end     = "EOF"                           # regex of the first line NOT moved, or "EOF"
# selector B — every matching block (instead of start/end):
# heading  = '^### '                      # block-start regex
# contains = ["SHIPPED", "CLOSED"]        # the heading line must contain one of these
# stop     = ['^### ', '^## ', '^Do not start backlog']   # first line matching any ends the block (not moved)
pointer = "each"                          # each (one pointer per moved block) | first | none
note    = "From Phase 47 on: ≤ 5 lines per phase; detail lives in `progress/`."   # optional line after the pointer
```

- Exactly one selector per entry (A: `start` [+ `end`, `include_start`]; B: `heading` + `contains` + `stop`).
  Unknown keys, a missing selector, or a selector that matches nothing is an error (exit 2).
- Pointer line (47-04 §2): `> 📦 Moved verbatim to [<dest>](<relative link>) (Phase 47-04, <date>). Search with
  \`genesis-ctx search <term> --archive\`.`. `verify-lossless` ignores lines starting `> 📦 Moved verbatim to `.
- In `dest`, each moved block is preceded by `<!-- archived from <source> L<a>–L<b>, step <n>, <date> -->`.
- Dry run (default) prints per block: source, line range, bytes, first line, dest. `--apply` writes. Re-running an
  applied entry is a no-op: a selector-A range that already begins with a pointer line is reported "already applied".

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

- an ADR with a **primary anchor** in `decision-log.md` (heading or bullet form, 47-02 §4.1) and no `tags/adr.toml`
  entry, or an entry with no areas or no `rule`; a duplicate primary anchor for one id; a tag entry for an id that has
  neither a decision-log anchor nor a `bible/04` bullet (*warning:* an ADR with `bible/04` bullets but no
  decision-log anchor);
- an unmarked lesson bullet in `bible/06` §7, a marker without a tag entry, a duplicate marker, a tag entry without a
  marker;
- a `bible/03` section (47-02 §4.3 kinds a/b/c) with no `tags/codemap.toml` entry, or an entry whose key matches no
  section;
- an unknown area name anywhere; an area without `title`, with an unknown key, or (not `always`) without `paths`; an
  area whose globs match no file (warning only);
- asymmetric `amends`/`amended_by`; a `superseded` ADR without `superseded_by`;
- a tag whose `reviewed_fp` ≠ the current fingerprint of its full text (**the text changed since the one-liner was
  reviewed** — review the rule, then `index --reviewed <id>` refreshes the fingerprint; an empty `reviewed_fp` is
  filled by a plain `index`, §3);
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
a `bible/03` with a base block and two `# ── Phase` blocks, two sub-specs with manifests). **Real shapes found
2026-10-20 (47-01 §5.5) — each has its own fixture and test:** a `### ADR` under a `##` ADR; an addendum heading; a
slash-combined amendment heading (`ADR-038/040 amendment`); an `amends ADR-061/063/064` list heading; a bullet-form
ADR inside another ADR's section; a `–` range and `(+ ADR-…)` in `bible/04` bold leads; a bold-line code-map section
(`**Phase 45 — …:**` + fence); `# ──` blocks inside the first fence; a duplicate base-map key. Required cases: section
extraction (incl. `(Q1)` headings and the last section), combined-id bullets, amendment closure both directions, path →
area mapping across repos, pack budget warn/fail, every lint rule (one failing fixture each), `mark` idempotence,
`archive` dry-run vs apply + pointer lines, `verify-lossless` detects a deleted paragraph and ignores a moved one,
`status` on a temp git repo with a tag, TOML emitter round-trip, `index` fingerprint fill vs `--reviewed`. Target ≥ 40
tests, all green.

## 8. Acceptance

All tests green; `genesis-ctx --help` lists §3; `status` and `pack --areas chat` run against the real tracker (with the
47-05 tags once they exist; with empty tags they must still run and report "untagged").

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md"]
```

## As built

**Session:** S2, 2026-10-20 (with 47-02). **Bootstrap rule honored:** the only source reads were headings, fences
and bold leads of `decision-log.md` and `bible/03/04/06` (grep / ranged reads, user-permitted) to check the anchor
shapes. No whole-file reads. The anchor rules were then amended with the user's approval (47-01 §5.5; 47-02
§4.1/§4.3; §3, §3.1, §5 and §7 here).

### Files (under `project-tracker/genesis/agent-system/`)

```
tools/genesis-ctx              bash shim: resolves symlinks, picks Python ≥ 3.11 (or $GENESIS_CTX_PYTHON), runs -m genesis_ctx
tools/genesis_ctx/
  cli.py       argparse, exit codes 0/1/2          config.py   paths, budgets, the 13-file corpus, L0 list, CtxError
  md.py        fences, bullets, bold leads, id lists, fingerprint    globs.py   ** / * / ? matcher + prefix-walk expand
  tomlio.py    tomllib + emitter + in-place set_field              sources.py the anchor rules (§4.1/§4.2/§4.3), manifests
  model.py     Corpus (parse once), areas↔paths, chain closure, spec lookup
  query.py     status, adr, lesson, area, search    pack.py   pack, check
  index.py     digests + reviewed_fp fill/refresh   lint.py   every §5 rule
  add.py       add adr | add lesson                 migrate.py  mark, archive (§3.1), propose-tags, verify-lossless
pytest.ini     testpaths = tests
tests/         conftest.py + test_core / test_sources / test_commands / test_lint / test_migrate
tests/fixtures/tracker/        miniature tracker: one fixture per real shape (list in §7)
```

Removed the 47-02 `.gitkeep` sentinels in `tools/genesis_ctx/` and `tests/`. Added `__pycache__/` and `*.pyc` to
`agent-system/.gitignore`.

### Tests

`cd agent-system && /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv/bin/python -m pytest` → **88 passed**
(Python 3.13.3, ~4 s). `ruff check --select E,F,W,B` is clean. Every required case in §7 is covered, plus one
fixture and test per real shape: `###` ADR under `##`, addendum, `ADR-038/040 amendment`, `amends ADR-061/063/064`,
bullet-form ADR-053/054 inside ADR-051, `–` range and `(+ ADR-…)`, bold-line code-map section, `# ──` inside the
first fence, duplicate key ` #2`. Each lint rule has its own failing fixture.

### Acceptance against the real tracker (read-only; packs written to `/tmp`)

- `genesis-ctx --help` lists every §3 command.
- `status --brief`: 7 lines, ~0.5 s, all five repos plus project-tracker.
- `pack --areas chat` and `pack 47-03` run in ~0.1 s. With empty tags they report "Untagged: 76 ADRs, 86 lessons,
  50 code-map sections" (the acceptance requirement).
- **Real corpus parse:**
  - decision-log: 76 primary anchors (72 `##` + 2 `###` + 2 bullets), 4 amendment anchors, 2 boundaries, no duplicate
    primaries. **Every id ADR-001..076 has decision-log text.** ADR-051 stops at L1219.
  - `bible/04`: 64 ADR bullets covering all 76 ids.
  - `bible/06`: 86 lessons, all with bold leads, none marked yet.
  - `bible/03`: 50 sections (33 base, 15 `# ──`, 2 bold) and one ` #2` key.
- `lint` → exit 1 with 215 errors, all expected before 47-04/05: adr-untagged 76, lesson-unmarked 86,
  codemap-untagged 50, generated-stale 3. L0 is currently ~2.1K tokens.
- `verify-lossless --baseline HEAD`: 1,338 baseline units, **0 missing**, 0.65 s; 24 duplicates in the active layer
  (input for 47-04 §5).
- `propose-tags --out-dir /tmp/…` (preview, not committed):
  - ADRs: 76 proposals (22 high / 43 medium / 11 low confidence).
  - Code-map: 50 proposals (15 / 28 / 7), 7 with no area.
  - Lessons are skipped until `mark` runs.
- **Not run on the real tracker** (these writes belong to 47-04/05): `index`, `mark`, `archive`, `propose-tags` into
  `context/tags/`, `add`. So `context/_generated/` is still empty.

### Decisions and deviations

1. **Approved rule changes** (47-01 §5.5): the anchor rules; `index --reviewed` / `--reviewed-all` (a plain `index`
   only fills empty fingerprints); `gates`; the §3.1 plan schema.
2. **`check --since REV`** = `git diff --name-only REV` (committed **and** uncommitted) + untracked files, so a
   review before commit sees everything. Without `--repo`, a repo where `REV` does not resolve is skipped with a
   note; with `--repo` it is an error.
3. **`pack` still writes the file when it exceeds the budget** (exit 1, "narrow areas" hint), so the agent can see
   what is too big.
4. **Generated digests list untagged ADRs/lessons too**, by title / bold lead, so "every rule visible in L0" holds
   before 47-05. They contain no file counts, which would go stale with every code change.
5. **Lint checks beyond the original §5 list:** `tag-invalid` (unknown fields, non-id keys, bad status) and
   `rule-too-long` (the 220-char limit from 47-02 §4.1). `fp-missing` is reported separately from `fp-drift`.
6. **Extra options:**
   - `propose-tags --out-dir` (preview without writing). Proposed entries carry `confidence` and `evidence` fields,
     which are stripped when an entry is accepted (header comment).
   - `add adr --amends --status --body-file`, which updates the amended ADR's `amended_by`; `add lesson --phase`.
   - `search --case`: search is case-insensitive by default and exits 1 on no match, like grep.
   - `mark --dry-run`, `verify-lossless --max-dups`.
7. **Python 3.11 not verified by execution:** no 3.11 interpreter on this machine. The code avoids 3.12+ syntax
   (an AST scan found no backslash or same-quote f-string expressions); it was run on 3.13.
8. **For 47-05:** in `bible/03`'s base map the `genesis-workflows/` block is a wrapped paragraph at 2-space indent.
   Rule (a) therefore yields sections with odd keys: `appian-atlas`, `cli-registry.json,`, `runner),`,
   `skills/{gam/SKILL.md`, `(self-contained`, and `genesis/genesis/  (scripts/`. This is deterministic and lossless,
   only noisier to tag (they can share one area list).
