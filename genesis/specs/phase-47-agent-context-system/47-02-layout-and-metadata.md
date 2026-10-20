# 47-02 — Layout, sidecar metadata, context manifests, L0 composition

> **Status:** 🟢 BUILT 2026-10-20 (skeleton). Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D2, D7, D9. Built in session S2 (skeleton files) together with 47-03.

## 1. Goal

Define where everything lives and the exact data formats that `genesis-ctx` (47-03) reads, so the migration (47-04/05)
only **adds** files and invisible markers — it does not restructure existing documents.

## 2. Directory layout (paths relative to `project-tracker/genesis/`)

```
AGENT_ONBOARDING.md            short pointer to the agent system (rewritten at 47-10)
README.md                      unchanged role (phase table, navigation); one row per phase
tracker.md                     §1–§5 unchanged; §6 restarts short (≤ 5 lines per phase) — old §6 archived
bible/
  02-architecture.md           unchanged — L0
  03-codebase-map.md           unchanged — loaded per section (L2)
  04-adrs-and-constraints.md   unchanged except the "Key implementation contracts" bullets move to L0-core — L2 per ADR
  05-dev-loop-and-release.md   unchanged — read by the dev/release/live-acceptance skills
  06-hard-won-lessons.md       + invisible `<!-- L-NNN -->` markers — L2 per lesson
  07-working-on-tasks-and-agreements.md   §8 step 7 and §10 edited at 47-10 to point at the docs agent — L0
  08-roadmap-and-backlog.md    shipped-phase blocks archived; backlog / what's next stays
  00-*.md, 01-*.md             archived at 47-04/05 (replaced by L0-core + state/current.md)
context/                       NEW — the active context layer
  L0-core.md                   hand-curated core (≤ 4K tokens) — 47-05
  areas.toml                   area registry — 47-05
  tags/adr.toml                per-ADR metadata — 47-05
  tags/lesson.toml             per-lesson metadata — 47-05
  tags/codemap.toml            per code-map section metadata — 47-05
  state/current.md             current-state snapshot (overwritten, never appended) — 47-05
  changelog.md                 one line per phase / release (append) — 47-08
  eval/golden.toml             golden questions — 47-09
  _generated/                  written only by `genesis-ctx index` (never hand-edited)
    adr-digest.md  lesson-digest.md  area-catalog.md
  .packs/                      compiled packs (git-ignored)
archive/                       NEW — verbatim history, never mandatory
  README.md                    what is here, and "search, don't read whole"
  tracker-status-log.md        tracker.md §6 as of the baseline
  bible-08-shipped-phases.md   the `### … SHIPPED …` / `### ✅ CLOSED …` blocks of bible/08
  onboarding-banners.md        the historical banners of AGENT_ONBOARDING.md
  bible-00-onboarding-and-overview.md   bible/01-current-state-2026-10-15.md
  LOSSLESS.json                baseline commit + paragraph hashes + result (47-04)
agent-system/                  NEW — agents, skills, hooks, tool, installer
  OPERATOR_GUIDE.md            how to use the agents (S1 draft; final at 47-10)
  install.sh  update.sh  uninstall.sh  install.conf.example
  agents/genesis-{spec,dev,review,release,docs}.md     CLI-3 Markdown profiles (templated)
  skills/genesis-*/SKILL.md (+ references/)
  hooks/*.sh                   hook scripts (call genesis-ctx)
  tools/genesis_ctx/           the context compiler (stdlib Python ≥ 3.11)
  tools/installer/             the installer (stdlib Python)
  tests/                       pytest for both (run with the genesis venv)
specs/  progress/  reference/  spike/  design/  artifacts/  code-review/   unchanged
```

## 3. Areas — `context/areas.toml`

An **area** is a slice of Genesis that has its own rules. ~20 areas; the list below is the starting proposal, finalized
in 47-05. Paths are globs relative to the repos root (`{{REPOS}}` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`) or,
with the `tracker:` prefix, relative to `project-tracker/genesis/`.

```toml
[area.chat]
title    = "Chat, copilot, chat modes, skills-in-chat"
paths    = ["genesis/genesis/chat/**", "genesis/genesis/skills/**", "genesis/web/src/features/chat/**",
            "kiro-agent-sdk/src/**"]
keywords = ["chat", "copilot", "chat mode", "skill", "steering", "session"]
skills   = ["genesis-backend-dev", "genesis-web-dev"]
docs     = ["tracker:reference/hitl-design.md"]        # optional: docs a pack should list
gates    = []                                          # optional: gate commands `genesis-ctx check` lists for the area
```

Proposed areas: `core-engine` (genesis-core nodes/state/validators/reliability/healing), `sdk-acp` (kiro-agent-sdk),
`workflows-library` (genesis-workflows, registries, CI publish gates), `runs-worker` (run manager, subprocess worker,
HITL gates, events/SSE, checkpoints), `db` (genesis/db, migrations), `api` (FastAPI `/api`), `web-shell` (app shell,
design system, tokens, theming), `web-runs` (runs + run detail graph + inspection), `chat`, `config-secrets` (settings,
secrets, environments, MCP/CLI registries, managed-native), `distribution` (install, lockfile, shipping, launcher,
update), `kb-sync` (Appian KB store, sync, delta sync, business map), `parser` (genesis-appian-parser), `documents`
(document library, gws), `features-stages` (feature workspace, spec, UX, TD, breakdown, stage finalizers, spec change
requests), `stories-workbench` (stories, boards, design/implementation lanes, story workspace, object wiki),
`collaboration-hub` (collab, Hub provider, sync), `memory`, `observability-credits`, `appian-integration` (Dev MCP,
SAIL CLI, DevOps, write tools), and two **cross-cutting** areas that are always included in every pack: `security`
(localhost guardrail, read-only chat, trust, secrets handling) and `release-ci` (versioning, pins, tags, CI).

Rules: an area name is `[a-z0-9-]+`; every area has a `title` and ≥ 1 path glob (except cross-cutting ones,
`always = true`); a file may belong to several areas. Optional keys: `keywords`, `skills`, `docs`, `gates` (string
arrays; `gates` = shell commands that `genesis-ctx check` prints as the area's gates). Any other key is a lint error.
Glob syntax: `**` = any number of path segments (incl. none), `*` / `?` = within one segment.

## 4. Sidecar tags — `context/tags/*.toml`

### 4.1 ADRs — `tags/adr.toml`

```toml
[ADR-031]
title      = "Chat is a read-only assistant"
status     = "accepted"            # proposed | accepted | superseded | amended
areas      = ["chat", "security"]
paths      = []                    # optional extra globs beyond the areas'
amends     = []                    # ADRs this one changes
amended_by = ["ADR-033", "ADR-034", "ADR-045"]
superseded_by = ""
rule       = "Chat never orchestrates or mutates; read-only @server/tool allowlist; file writes only in the per-session sandbox."
reviewed_fp = "3f9a0c1e2b7d4a65"   # fingerprint of the full text when `rule` was last reviewed
b04        = "include"             # optional (default "include"); "skip" omits the bible/04 bullet from packs
```

- **Source anchors are computed, not stored.** No edits to either file. Rules locked 2026-10-20 against the real files
  (47-01 §5.5):
  - **decision-log anchors.** An anchor is (i) any `##` / `###` heading, or (ii) a column-0 bullet whose bold lead
    *starts* with an ADR id (`- **ADR-053 (ACCEPTED …`). Every anchor runs to the next anchor (the next `##`/`###`
    heading or the next such bullet), so a bullet anchor is excluded from the section it sits in (ADR-051's text stops
    before the ADR-053 bullet). `#` and `####`+ headings are content.
  - **Ids an anchor names.** If its text (heading text / bold lead) *starts* with an id group — `ADR-NNN` plus slash
    continuations (`ADR-038/040`, `ADR-061/063/064`) — those ids. Otherwise the ids of an `amends ADR-…` list in the
    heading (same id-list syntax, §4.1 id lists). Ids that appear only as `revises` / `refines` / `amended by` /
    `supersedes` mentions are **relations, not anchors** (they feed `propose-tags` amendment edges). An anchor that
    names no id (`## Technical ADRs (foundational)`) is a boundary only.
  - **Kind.** An anchor is an **amendment** if it is an `amends …` heading or its lead (text before the first ` — `)
    contains the word `amendment` or `addendum`; otherwise **primary**.
  - **An ADR's decision-log text** = every anchor naming it, primary and amendment, in document order. An
    amendment/addendum anchor loads with **every** ADR it names. Each ADR has exactly one primary anchor (lint error on
    a duplicate). An ADR with no decision-log anchor (none today) uses its `bible/04` bullets only; lint warns.
  - **`bible/04` bullets** = the column-0 bullets whose bold lead names the id anywhere, with **id-list expansion**:
    `ADR-NNN`; slash continuations `ADR-002/004/020`; ranges `ADR-006–009` (en dash or `..`); `(+ ADR-029)` and
    `+ ADR-063` are ordinary ids. So the `Amendment (v0.69.0) … (amends ADR-061 + ADR-063)` bullet loads with both.
  - **Fingerprint** (`reviewed_fp`) = `sha256[:16]` of the whitespace-collapsed decision-log text + `bible/04` bullets.
- `amends` / `amended_by` must be **symmetric** (lint). `genesis-ctx adr` loads an ADR's whole amendment chain. `pack` /
  `check` follow `amended_by` / `superseded_by` transitively and `amends` one hop from the seeds only (47-03 §4,
  amended S4 — 47-01 §5.6).
- `rule` ≤ 220 characters, one sentence, imperative.
- **`b04` dedupe (S5, 2026-10-20; step 0, a 47-03 fix).** A `bible/04` bullet that names several ADRs (`ADR-002/004/020`,
  the `ADR-003 + ADR-006–009 + ADR-013–017` range bullet, an `amends ADR-061 + ADR-063` amendment) is printed **once per
  pack**, under the first selected id, with a one-line "shown once under ADR-NNN" pointer under the others — it no longer
  repeats under every id it covers. The optional per-ADR `b04 = "skip"` additionally drops the bullet from `pack` /
  `check` when the decision-log section already carries its distinctive content; a combined bullet is dropped only when
  **every** ADR it covers is `skip`. `genesis-ctx adr <id>` always prints the bullet (it ignores `b04`). `b04` is set by
  `genesis-ctx propose-b04` (47-03 §3): it flags a bullet `include` when it has a distinctive token (backticked
  identifier, version, number, quoted term or a cross-referenced ADR id) absent from that ADR's decision-log text
  (sections + amendments), otherwise `skip`; the default is **`include` when unsure** (no decision-log text, or no
  distinctive token to judge by). `b04` is not part of `reviewed_fp`.

### 4.2 Lessons — `tags/lesson.toml`

```toml
[L-001]
areas = ["sdk-acp", "config-secrets"]
phase = "pre-16"
rule  = ""                         # empty = use the bullet's bold lead sentence verbatim
reviewed_fp = "a1b2c3d4e5f60718"
```

The bullet carries an invisible marker immediately after the list dash: `- <!-- L-001 --> **ACP MCP env MUST be a list
…`. IDs are assigned once, in document order, by `genesis-ctx mark` (47-04); never reused; new lessons get the next id
via `genesis-ctx add lesson` (47-08).

### 4.3 Code-map sections — `tags/codemap.toml`

`bible/03` is not edited. Section rules locked 2026-10-20 against the real file (47-01 §5.5):

- **(a) Base-map entries.** The base map runs from the line after the first fence opener to the first `# ──` line
  (to the fence close if there is none — the real file has three `# ──` blocks inside its first fence). Under a repo
  header line (column 0, ending in `/`, e.g. `genesis/genesis/`), an entry starts only on a line indented exactly
  2 spaces whose **first token is path-like** — it contains `/` or ends in a file extension (`.py .pyi .ts .tsx .js
  .jsx .mjs .cjs .json .md .yaml .yml .toml .sh .ini .cfg .txt .sql .html .css .lock .xml`). Any other line
  (e.g. a wrapped prose line at 2-space indent such as `runner), workflows/…`) continues the previous entry. The
  entry runs to the next entry, repo header or the end of the base map. Key: header + the entry's first token —
  `"genesis/genesis/  db/"`. Text between a repo header and its first entry (if any non-blank) forms a section keyed
  by the header alone — `"genesis-workflows/"`. (Amended S3, 2026-10-20, user-approved: the real `genesis-workflows/`
  block is a wrapped paragraph and the old "every 2-space line" rule produced keys like `runner),`.)
- **(b) `# ── … ──` blocks.** A column-0 line starting `# ──` starts a section. Key: the line without the leading `# `
  and the trailing `─` run — `"── Phase 34 — Design Lane Automation (Workbench Design + Design Review; ADR-062)"`.
- **(c) Bold-line blocks.** A line that is only bold text `**…**` (a trailing `:` inside or outside allowed) starts a
  section (the real Phase 45 / 46 blocks). Key: the text without `**` and the trailing `:`.
- (b) and (c) sections run to the next (b)/(c) start, a `---` line, or EOF — inside or outside a fence.
- **Duplicate keys** get ` #2`, ` #3`, … in document order (`"genesis-core/genesis_core/  state.py #2"`).

```toml
["genesis/genesis/  chat/"]
areas = ["chat"]
```

## 5. Context manifest in sub-specs (all phases ≥ 48)

Every sub-spec carries this section (the `genesis-spec-authoring` skill writes it; `lint` validates it):

````markdown
## Context manifest

```toml
areas    = ["features-stages", "web-shell"]
adrs     = ["ADR-075"]             # MANDATORY: every applicable ADR id (from `genesis-ctx area <a>`) — these get FULL TEXT
lessons  = ["L-083"]               # same: the lessons to load in full
code     = ["genesis/genesis/kb/spec_clauses.py", "genesis/web/src/features/features/**"]
docs     = ["tracker:specs/phase-46-spec-change-requests/46-02-clause-model.md"]
upstream = ["48-02"]               # sub-specs whose As-built this one depends on
```
````

Umbrella specs carry a manifest too (the union the phase is expected to touch). Paths in `code` also contribute areas
through `areas.toml` globs — so a wrong or missing `areas` entry is caught by the paths. The pack renders **full text**
only for the manifest's `adrs`/`lessons`, path-glob hits and their amendment chains; a rule reached only through its
area appears as a one-line *Also applies* pointer (`genesis-ctx adr|lesson <id>`), so list the ids you need in full
explicitly (47-09 §3; genesis-spec-authoring skill).

## 6. L0 composition (every agent, `file://` resources, in this order)

1. `context/L0-core.md` — what Genesis is (the bible §0 paragraph, verbatim), the five repos + root path, the
   **retrieval protocol** (how and when to call `genesis-ctx`; never read the bulk files whole), the **key
   implementation contracts** (moved from `bible/04`), and the definition of "nothing missed" (every rule is in the
   digests below; full text via `genesis-ctx adr|lesson`).
2. `bible/02-architecture.md` (verbatim).
3. `bible/07-working-on-tasks-and-agreements.md` (verbatim, with the 47-10 edit).
4. `context/_generated/adr-digest.md` — one line per ADR: `ADR-031 [chat,security] (amended by 033,034,045) — <rule>`.
5. `context/_generated/lesson-digest.md` — one line per lesson: `L-001 [sdk-acp] — <rule>`.
6. `context/_generated/area-catalog.md` — one line per area.
7. `context/state/current.md`.

Budget ≤ 24K tokens (`lint` fails above; the estimator is ≈ chars ÷ 2.5, calibrated to the real tokenizer — 47-09 fix
M3a, raised from 15K at the old chars ÷ 4). Live repo state is not in L0: the `SessionStart` hook prints
`genesis-ctx status --brief` into the context.

## 7. Acceptance

- Skeleton committed: `context/` (empty tag files with headers), `archive/README.md`, `agent-system/` tree.
- Schemas documented here are what `genesis-ctx` validates (47-03 tests use fixtures of exactly these shapes).

## Context manifest

```toml
areas = []
docs  = ["tracker:specs/phase-47-agent-context-system.md"]
```

## As built

**Session:** S2 (skeleton only; `genesis-ctx` itself is 47-03). **Date:** 2026-10-20. **Bootstrap rule honored**
(no bible / tracker / decision-log reads; context was the Phase 47 spec set plus the real repo layout).

### Files created (20)

Under `project-tracker/genesis/`:

```
context/L0-core.md                 placeholder (commented with the §6 composition it must hold; authored 47-05)
context/areas.toml                 22 areas, paths+keywords filled from the real repo layout (see table below)
context/tags/adr.toml              header-only; §4.1 schema documented; no entries
context/tags/lesson.toml           header-only; §4.2 schema documented; no entries
context/tags/codemap.toml          header-only; §4.3 schema documented; no entries
context/_generated/README.md       "generated — do not edit" + the files `index` will write
context/.gitignore                 ignores .packs/
context/state/.gitkeep             keeps state/ (current.md is 47-05)
context/eval/.gitkeep              keeps eval/ (golden.toml is 47-09)
archive/README.md                  "verbatim history, never mandatory; search, don't read whole"
agent-system/.gitignore            ignores install.conf
agent-system/install.conf.example  TRACKER / REPOS / MODEL template (MODEL empty per Q6)
agent-system/agents/.gitkeep
agent-system/skills/.gitkeep
agent-system/hooks/.gitkeep
agent-system/tools/genesis_ctx/.gitkeep
agent-system/tools/installer/.gitkeep
agent-system/tests/.gitkeep
agent-system/migration/.gitkeep
```

`agent-system/OPERATOR_GUIDE.md` already existed (S1) and was left untouched. No existing document was moved,
edited or archived (that is 47-04/47-05); the only spec edit is this file's Status line and this section.

### Areas — glob-match counts

Globs resolve against `{{REPOS}}` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`. Counts are matching **files**,
excluding `__pycache__`, `*.pyc`, `.DS_Store`, `*.egg-info`. **Every non-cross-cutting glob matches ≥ 1 file
(0 zero-match globs).** Verified with `tomllib` + `pathlib.Path(repos).glob(pattern)`.

| Area | files | Area | files |
|---|---:|---|---:|
| core-engine | 30 | documents | 31 |
| sdk-acp | 4 | features-stages | 75 |
| parser | 58 | stories-workbench | 29 |
| workflows-library | 95 ¹ | collaboration-hub | 23 |
| runs-worker | 15 | memory | 21 |
| db | 28 | config-secrets | 44 |
| api | 28 | distribution | 12 |
| chat | 32 | appian-integration | 14 |
| kb-sync | 4 | observability-credits | 2 |
| web-shell | 48 | web-runs | 35 |
| security | cross-cutting (`always=true`, no paths) | release-ci | cross-cutting (`always=true`, no paths) |

22 areas total: the 20 from §3 + the 2 cross-cutting (`security`, `release-ci`). All four TOML files parse with
`tomllib`.

¹ Corrected in S2 (47-03 build) from 98: pathlib also counted 3 files under
`genesis-workflows/workflows/sync-application/.ruff_cache/`. `genesis-ctx`'s own glob engine (which skips tool
caches) reproduces every other count exactly.

### Deviations from the spec

1. **`.gitkeep` sentinels** in the otherwise-empty directories (`context/state/`, `context/eval/`, and the six
   `agent-system/` subdirs). Git does not track empty directories; the sentinels make the skeleton tree survive a
   clone. Each names what lands there and in which sub-spec. Not mentioned in §2 but required to honor it.
2. **Area path precision beyond the §3 one-liners.** §3 gives each area as a prose phrase ("run manager, subprocess
   worker, HITL gates, …"); §3 says the list is "the starting proposal, finalized in 47-05". I translated each phrase
   into concrete globs against the real tree. Judgment calls worth a second look in 47-05:
   - `chat` keeps `kiro-agent-sdk/src/**` exactly as the §3 example shows, so it overlaps `sdk-acp` (allowed — "a
     file may belong to several areas").
   - `observability-credits` maps only to `api/metrics.py` + `runtime/logging.py` (2 files): there is no dedicated
     credits/observability package in the tree today; run-provenance/credit data lives inside `runs/` and
     `api/metrics.py`. Flagged for 47-05.
   - `runs-worker`, `config-secrets`, `distribution`, `appian-integration` reach into specific `runtime/*.py`,
     `mcp/native/**` and `cli_tools/native/**` files rather than whole packages, to avoid swallowing unrelated code.
3. **`web-runs` uses the real directory name `run-detail`** (`features/run-detail/**`), which is correct for the
   current tree.

No spec item failed against the real repos; nothing required stopping for a decision. `genesis-ctx` validation of
these shapes is exercised by the 47-03 tests.

### Spec amendments during the 47-03 build (S2, 2026-10-20 — user-approved, 47-01 §5.5)

Building `genesis-ctx` against the real files showed that the §4.1 / §4.3 anchor rules did not fit
`decision-log.md` (`###` ADRs, amendment headings, bullet-form ADR-053/054) or `bible/03` (`# ──` blocks inside the
first fence, bold-line Phase 45/46 sections, a duplicate base-map key). The user approved replacement rules, now in
§4.1 and §4.3; §3 gained the optional `gates` field (also documented in the `context/areas.toml` header). The two
`.gitkeep` files in `agent-system/tools/genesis_ctx/` and `agent-system/tests/` were removed when those directories
received their real contents.
