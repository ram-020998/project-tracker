# 47-05 — Tag review, L0 core, current-state snapshot

> **Status:** ✅ BUILT 2026-10-20 (session S4; As built below). Repo: project-tracker. Parent: `specs/phase-47-agent-context-system.md`.
> Decisions D1, D7, D9. Input: `context/tags/*.proposed.toml` from 47-04 step 5. Session S4 (with the user).

## 1. Goal

Turn the script's tag proposals into reviewed tags, write the two small hand-curated files (`L0-core.md`,
`state/current.md`), archive `bible/00` + `bible/01`, and generate the digests — in **one** session, by reviewing a
table instead of reading the corpus.

## 2. Tag review (the only judgment-heavy step)

1. `propose-tags` (47-04) gives, per item: candidate areas + confidence, candidate amendment edges, candidate one-liner.
2. The agent prints **one review table per kind**, sorted with low-confidence items first:

   | id | title / lead (≤ 100 chars) | proposed areas | conf | amends / amended_by | one-liner (≤ 220) |
   |---|---|---|---|---|---|

3. For **low-confidence** items (and all ADRs whose candidate one-liner is > 220 chars or contains "see" / "refines"),
   the agent opens just that item with `genesis-ctx adr|lesson <id>` and fixes the row. High-confidence rows are
   accepted unless the user objects.
4. The user skims the tables (≈ 77 ADRs + 86 lessons + ~60 code-map sections) and answers objections in batches.
5. Accepted rows are written to `context/tags/{adr,lesson,codemap}.toml` (with `reviewed_fp`); `.proposed.toml` files
   deleted. `areas.toml` is finalized from the 47-02 proposal plus anything the review surfaced.

Rules for the one-liners: one imperative sentence; keep the ADR's operative words (e.g. "MANDATORY", "never",
"REQUIRED"); name the mechanism when it is the rule (e.g. "`env` is a LIST of `{name,value}`"); never drop a negation.
Lessons default to their bold lead verbatim (`rule = ""`); write a `rule` only when the lead is > 220 chars.

## 3. `context/L0-core.md` (≤ 4K tokens)

Sections, in order:

1. **What Genesis is** — the `bible/00` §0 paragraphs, verbatim.
2. **Where things are** — the five repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, project-tracker at
   `/Users/ramaswamy.u/repo/project-tracker/genesis/`, the dev venv path; one line each.
3. **Retrieval protocol** —
   - The digests below list **every** ADR and lesson. Before acting on an area, get the full text:
     `genesis-ctx pack <sub-spec>` (or `--areas …`), or `genesis-ctx adr <id>` / `lesson <id>`.
   - Never open `reference/decision-log.md`, `bible/03`, `bible/04`, `bible/06` or `archive/**` whole; use
     `genesis-ctx` or ranged reads.
   - For history ("when/why did we…"), use `genesis-ctx search <term> --archive`, then the `progress/` doc.
   - If a digest line and a full text disagree, the full text wins; report the mismatch to the docs agent.
   - For heavy exploration (many files), use a sub-agent and keep only its summary.
4. **Key implementation contracts** — the bullets moved from `bible/04` (node signature, `build(ctx)`, standalone
   `graph.py`, ACP `env` list), verbatim.
5. **Non-negotiables in one breath** — five lines pointing at the digest classes ("ADRs are non-negotiable; flag and
   confirm any deviation", "lessons are do-not-regress", "ask before destructive actions", etc.), taken from
   `bible/04` §5 heading and `bible/07` §10.

## 4. `context/state/current.md` (≤ 4K tokens, overwritten every phase)

Sections: **Active phase** (one line, e.g. "none — Phase 47 complete" — read by `status --brief`); **Shipped versions**
(the five repos' tags + dependency chain, from `bible/01` §2 table — current values only); **DB version** /
`current_version`; **Test counts** at the last release (one line per repo); **What works today** (the `bible/01` list,
current items only, one line each); **Known open items** (pointers into `specs/backlog/`). No history, no CI ids.

Then archive `bible/00-onboarding-and-overview.md` and `bible/01-current-state.md` verbatim (one commit), re-run
`verify-lossless` (0 missing).

## 5. Generate

`genesis-ctx index` → `_generated/{adr-digest,lesson-digest,area-catalog}.md`; `genesis-ctx lint` green except the
manifest check for future specs (none exist yet).

## 6. Acceptance

- `lint` green; L0 total ≤ 15K tokens (printed by `lint`).
- `genesis-ctx pack --areas chat` produces a pack that contains ADR-031, -033, -034 and -045 (the chat amendment chain)
  and the chat lessons — spot-checked with the user.
- `verify-lossless` 0 missing.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-04-scripted-migration.md"]
```

## As built

**Session:** S4, 2026-10-20. **Bootstrap rule honored.** No bulk file was read whole. I read the proposals, the
`bible/04` bullet leads (≤ 360 chars each, through the Corpus API), and the head of `genesis-ctx adr` / `lesson` for
low-confidence items and label-style lessons. Every other read was a ranged one: `bible/00` §0, `bible/01` (tag
table, dependency chain, test line, "What works today"), the `bible/04` contracts, `bible/07` §10, and the `bible/05`
§6 command lines by grep.

### Commits (local, not pushed)

| Commit | Step |
|---|---|
| `449a2a2` | **Step 0:** `bible/08`, 29 archive pointers → 1 |
| `452da9e` | **Step 1:** reviewed tags + digests; `pack`/`check` closure rule; budgets 60K/120K; spec text (47-01 §5.6, 47-02 §4.1, 47-03 §4, umbrella §6.1/§13) |
| `4109ab7` | **Step 1b:** `areas.toml` finalized with per-area `gates` |
| `1cd0ca2` | **Step 2a:** `context/L0-core.md` + `context/state/current.md`; `bible/04` contracts moved (pointer left); `status` prints the active phase once |
| `366fe5f` | **Step 2b:** `bible/00` + `bible/01` → `archive/` verbatim (pointer stubs kept until 47-10); archive plans gain an optional `phase` |
| (this) | As-built, Status BUILT |

### Tags (decisions: 47-01 §5.6)

- **76 ADRs, 86 lessons and 46 code-map sections** are tagged, all with `reviewed_fp`. The `.proposed.toml` files are
  deleted.
- **Always-on areas** carry only ADR-011 (`release-ci`) and ADR-026 (`security`), plus their lessons: L-017/045 on
  security; L-025/027/030/051/056/057 on release-ci.
- **Removals under round 5 rule 3: none.** The tags stay recall-first.
- **Status / edge corrections, from spot-checking the text:**
  - **ADR-044:** status `amended`, `amended_by = ["ADR-056"]`. ADR-056 supersedes only its *sequential-unlock* clause.
  - **ADR-062:** status `amended`, `amended_by = ["ADR-068"]`. ADR-068 supersedes only its *proposal-only* clause
    for the Implementation lane.
  - The proposals had marked both as `superseded`, without a `superseded_by`.
  - Every proposed `amends` edge was confirmed in the heading or lead text; all edges are symmetric (lint).
- **Areas I corrected from titles** (no full reads):
  - ADR-026/027/049/055 → web-shell (+ the web areas; 027/055 also `paths = ["genesis/web/src/**"]`).
  - ADR-051 lost collaboration-hub; ADR-061/062 lost release-ci; ADR-040 lost appian-integration and security.
  - Lessons: L-017 → chat; L-034 → kb-sync/web (not core-engine); L-068 → web-shell; L-026/044/082 lost release-ci.
  - The proposed security/release-ci tags were all keyword hits. Kept on an always-on area, each would have put its
    rule in every pack.
- **Lesson one-liners:**
  - 16 lessons whose bold lead is only a label, such as "SSE streaming:", got a `rule`: L-003, 005–015, 017, 018,
    020, 021.
  - L-067 got a `rule` because its lead is 250 chars.
  - All the other lessons use their bold lead verbatim.
  - This is the conservative reading of "a one-line rule per lesson". The full text wins on any disagreement.

### Tool changes (94 tests pass)

1. **Closure** (`Corpus.pack_chain`, used by `pack` and `check`):
   - follows `amended_by` / `superseded_by` (and reverse `amends`) transitively;
   - follows `amends` one hop, from seeds only;
   - `adr` keeps the full chain.
   
   A test covers it: transitive changers; 064 added by the chain does not pull 061; a seed's `amends` is one hop;
   `superseded_by` is followed.
2. **Budgets:** `PACK_WARN` 60K, `PACK_FAIL` 120K.
3. **`status`:** the active phase was printed twice ("Active phase: Active phase: …"). The label is now stripped;
   test updated.
4. **Archive plans** accept an optional top-level `phase` (default `47-04`) for the pointer and the archive header.
   Test added.

### L0 and state

- **`context/L0-core.md`** (4.5 KB ≈ 1.1K tokens) has five sections:
  1. the `bible/00` §0 paragraphs, verbatim;
  2. repos and paths;
  3. the retrieval protocol (§3 wording);
  4. the four "Key implementation contracts" bullets, **moved** verbatim from `bible/04` (pointer left there);
  5. five non-negotiables, from the `bible/04` §5 heading and `bible/07` §10.
- **`context/state/current.md`** (3.2 KB ≈ 0.8K tokens) holds current values only:
  - first line `Active phase: Phase 47 — in progress (47-05)`;
  - tags + dependency chain, DB v24 (m0001–m0024) + `memory.db` mm0001;
  - Phase 46 release test counts. The parser has no count recorded at that release, so it says "all pass".
  - 12 "works today" lines;
  - open items pointing to `bible/08` §9.
- **`lint` → 0 errors, 0 warnings; L0 ≈ 12,267 / 15,000 tokens.** The parts:

  | L0 part | ~tokens |
  |---|---:|
  | ADR digest | 4.1K |
  | lesson digest | 3.8K |
  | `bible/02` + `bible/07` | 1.8K |
  | L0-core | 1.1K |
  | state | 0.8K |
  | area catalog | 0.7K |

- `verify-lossless --baseline d89f763` → **0 missing** after every step.
- **Gates** (`areas.toml`): derived from each area's path globs. The genesis / genesis-core / genesis-workflows / web
  commands are the `bible/05` §6 lines. **Assumed, not in bible/05:**
  - kiro-agent-sdk: `cd kiro-agent-sdk && .venv/bin/python -m pytest -q` (the repo's own venv);
  - parser: `pytest -q` + `ruff check .` (from its `.gitlab-ci.yml`), run with the genesis venv.
  
  The always-on areas have no gates.

### Packs with the final tags and closure

`pack --areas chat` → 47,265 tokens. It includes ADR-031, 033, 034, 045 (and 076) and 23 lessons; the 21 directly
tagged chat lessons include L-001, 017, 024, 041, 042, 044–047.

| area | ~tokens (ADRs) | area | ~tokens (ADRs) |
|---|---:|---|---:|
| core-engine | 48,134 (39) | features-stages | 68,796 (34) WARN |
| sdk-acp | 23,926 (17) | stories-workbench | 53,930 (26) |
| parser | 23,390 (13) | collaboration-hub | 25,552 (9) |
| workflows-library | 65,071 (45) WARN | memory | 16,709 (11) |
| runs-worker | 41,781 (33) | config-secrets | 55,594 (33) |
| db | 25,633 (18) | distribution | 21,375 (19) |
| api | 30,744 (18) | appian-integration | 39,059 (20) |
| chat | 47,265 (33) | observability-credits | 13,305 (7) |
| kb-sync | 48,066 (24) | web-shell | 33,677 (20) |
| documents | 28,084 (17) | web-runs | 20,367 (14) |
| always-on only | 8,496 (5: 011, 026 + changers 063, 065, 074) | | |

**Simulated real sub-specs** (manifests built from the text of 46-02 / 46-05 / 46-07: their areas + named code
paths):

| sub-spec | areas | ADRs | lessons | sections | ~tokens |
|---|---|---:|---:|---:|---:|
| 46-02 clause model | features-stages, chat (+ always) | 45 | 35 | 14 | 77,072 WARN |
| 46-05 impact analysis | features-stages, chat, stories-workbench (+ always) | 48 | 36 | 17 | 83,796 WARN |
| 46-07 web experience | features-stages, web-shell (+ always) | 39 | 36 | 12 | 73,793 WARN |

All three are under the 120K fail limit but above 60K. With L0 (~12K) and a role (~10K), a 46-05-sized task
starts at about 106K tokens, which is at or just over the 47-09 §4 bar of "≤ 10 % after the pack" (on a 1M
window). This is flagged for 47-09. Options there: tighter manifests (named `adrs` instead of whole areas), or the
features-stages split that was deferred in round 5.
