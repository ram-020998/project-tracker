---
name: genesis-ctx
description: Use whenever you need Genesis context or touch the context layer — every genesis-ctx command, its flags, outputs and exit codes; the context-manifest format; how packs are built (full text vs "Also applies"); budgets; the safe one-call form. For all five Genesis agents.
---

# genesis-ctx — the context compiler

Binary (always call it by this absolute path, as ONE direct command — no pipes, loops, `;`/`&&`, `$(…)`, redirects or
`VAR=` prefixes; those fall outside the allow rules and are denied non-interactively):
`{{GENESIS_HOME}}/bin/genesis-ctx`. Offline, deterministic, stdlib-only. Exit codes: `0` ok · `1` findings (lint/check
problems, missing ids) · `2` usage/config error (bad flag, unknown id, a `--since` rev that resolves in no repo).
Long output: write it with `--out <file>` (pack) and read the file in ranges.

## Reading (every agent)

| Command | Use it for |
|---|---|
| `status [--brief] [--json]` | Branch, latest tag, dirty count, ahead count for the five repos + project-tracker; the active phase. Sub-agents (no SessionStart hook) run `status --brief` first. |
| `pack <id\|path> [--areas a,b] [--out F]` | The task's context. `<id>` = sub-spec (`48-03`), umbrella (`48`) or a path. `--areas` alone (no id) for bugs / small tasks. Default output `context/.packs/<id>.md`. |
| `adr <ID> <ID> … [--no-chain]` | Full text: decision-log section(s) + amendment sections + the `bible/04` bullet + the amendment chain. Many ids in ONE call. |
| `lesson <L-NNN> …` | Lesson bullets verbatim. |
| `area <name>` | An area's catalog line, its ADR/lesson one-liners, code-map sections, docs, skills, gates. Use it to write a manifest. |
| `search <regex> [--archive] [--max N] [--case]` | Grep the active layer; `--archive` also searches `archive/`, `specs/`, `progress/`. History only — never to decide which rules apply. |
| `check (--since REV \| --files F… \| --staged) [--repo R] [--json]` | Changed files → areas → the full checklist of applicable ADR + lesson rules + the areas' gate commands. Covers project-tracker (`tracker:` paths) and includes uncommitted/untracked files with `--since`. The reviewer answers each line OK / VIOLATION / N/A. |

## How a pack is built

`seeds` = manifest `adrs`/`lessons` ∪ ADRs whose `paths` match manifest `code` ∪ the areas (manifest `areas` ∪ areas
whose globs match `code` ∪ always-on `security`, `release-ci`). Chain closure: everything that **amends or supersedes**
a loaded ADR, transitively; what a seed amends, one hop. Output sections: header + inclusion table (why each item is
in) → **full text** for direct hits (manifest ids, path hits) and their chains → **Also applies** — one line per ADR /
lesson reached only through an area: *load it with `adr <id>` before changing code it governs* → code-map sections →
"Read next" (docs + code paths). Budgets (≈ chars ÷ 2.5): warn 60K, fail 120K — narrow the manifest, never drop a
rule. Every rule is also in the L0 digests.

## Context manifest (every sub-spec from Phase 48; validated by `lint`)

````markdown
## Context manifest

```toml
areas    = ["features-stages", "web-shell"]
adrs     = ["ADR-075", "ADR-042"]       # REQUIRED: every ADR the sub-spec relies on (from `area <a>`)
lessons  = ["L-083"]
code     = ["genesis/genesis/kb/spec_clauses.py", "genesis/web/src/features/features/**"]   # a bare dir = dir/**
docs     = ["tracker:specs/phase-46-spec-change-requests/46-02-clause-model.md"]
upstream = ["48-02"]
```
````

Paths are relative to the repos root, or to `project-tracker/genesis/` with the `tracker:` prefix.

## Writing (genesis-docs / genesis-spec only)

| Command | Does |
|---|---|
| `lint [--specs-only] [--quiet] [--json]` | Validates tags, markers, digests, budgets, links, manifests. Must be green before you finish (Stop hook enforces, max 2 retries). `--specs-only` = manifests only. |
| `index [--reviewed ID… \| --reviewed-all]` | Regenerates `context/_generated/*`; fills empty fingerprints. After you review an ADR/lesson one-liner whose full text changed, `--reviewed <id>` refreshes its fingerprint. |
| `add adr --id ADR-NNN --title T --areas a,b --rule R [--body-file F] [--amends ADR…] [--status accepted\|proposed] [--phase NN]` | Appends the decision-log section (house format) + tag entry (+ `amended_by` on the amended ADR), then indexes. |
| `add lesson --areas a,b --rule R [--body-file F] [--phase NN]` | Appends a marked bullet `- <!-- L-NNN --> **R (Phase NN).** body` to `bible/06` §7 + tag entry, then indexes. |

One-liners: ≤ 220 chars, one imperative sentence, keep MUST/never/REQUIRED and negations.

## Maintenance only (don't use in normal work)

`mark` (lesson markers) · `archive --plan F [--step N] [--apply]` (move text into `archive/`, dry run by default) ·
`propose-tags [--out-dir D]` · `propose-b04 [--apply]` · `verify-lossless --baseline REV [--write]` (prove no baseline
paragraph is missing — run after any archive move; the Phase-47 baseline is `d89f763`).
