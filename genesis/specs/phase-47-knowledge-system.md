# Phase 47 — Genesis Knowledge System

> **Status:** 🟡 **SPEC-DRAFTED 2026-10-19 — awaiting build sign-off.** Repos: **project-tracker** (the knowledge
> store, the migration workspace, the tools) and the user's Kiro agent folder (`~/.kiro/agents`). **No change to
> genesis, genesis-core, genesis-workflows, kiro-agent-sdk or the parser.** New ADR: **ADR-077** (Proposed).
> Sub-specs: `phase-47-knowledge-system/47-01..47-11`. Progress: `migration/PROGRESS.md`.

## 1. Why
A fresh agent that follows the bible fills 45–50% of a 1M-token context before any work. Measured 2026-10-19:

| Read at onboarding | ~Tokens (chars/4) | What it is |
|---|---|---|
| `tracker.md` | 95K | 233 dated status entries — history |
| `reference/decision-log.md` + `bible/04` | 52K + 18K | the same ADRs twice |
| `bible/08` | 33K | as-builts of every shipped phase (repeats `progress/`) |
| `bible/01` | 18K | "current state"; the genesis tag-table cell alone is 25,521 chars |
| `bible/03`, `bible/06` | 20K each | code map + 86 lessons, appended by phase, not grouped by area |
| the rest of the mandatory list + `reference/` + README | ~45K | |
| + the phase's specs + code | 50K+ | |

The causes are structural: the knowledge is kept as a **chronological journal** and onboarding means **reading the
whole journal**; facts are **copied** into several documents and have **already drifted** (the manifest still said
"ADR-001..074" after a reviewed docs pass); nothing tells an agent **which rules apply to the code it touches**, so
"read everything" is the only safe rule — and long context itself lowers adherence (context rot).

## 2. Goal and success criteria
Rewrite the whole Genesis knowledge **from scratch** into a store organized by **what the agent needs to do**, with
every piece of current knowledge preserved and **proven** preserved; then deliver it through **role agents** that
load only what a task needs. After cutover no agent reads the old documents.

| # | Criterion (measured at 47-10) |
|---|---|
| S1 | A role agent's loaded knowledge at session start (core + role procedure + the sub-spec's areas + the sub-spec) is **≤ 60K tokens** |
| S2 | **100%** of non-blank lines of every extracted source are covered by a unit or a stated skip reason |
| S3 | **100%** of units have a fate (kept in a new document, merged, superseded, or history) |
| S4 | **0** copied paragraphs in the new store (§6.2), every verbatim exemption justified |
| S5 | Examination (§5.4): **100%** of high-stakes questions and **≥ 95%** of the rest answered correctly from the new store alone; every miss fixed or explained |
| S6 | Rule recall: for **every** hard-won lesson replayed as a task, `gk rules` returns the rule/lesson that prevents it |
| S7 | The store validator is green and runs before every project-tracker push; no agent config loads `archive/` |

**Non-goals.** No change to any decision's meaning (a decision changes only through a conflict the user decides,
§3.4, or a new ADR). No product code change. No new Genesis features.

## 3. Definitions
### 3.1 Sources
Every file under `project-tracker/genesis/` at the **migration base** (git tag `knowledge-migration-base`, set in
47-01). 47-01 classifies each file **extract** (read fully, ledgered) or **archive-only** (with a reason, e.g. a
binary image; the list is reviewed). Files changed after the base are handled by a **delta batch** (47-10).

### 3.2 Knowledge unit (KU)
One atomic piece of knowledge, restated by the extractor **in its own words**, with provenance. Schema (47-01 freezes
it): `id` (`KU-<batch>-<nnnn>`), `src` (path), `lines` ([first, last]), `type`, `areas`, `statement`, `exact`
(identifiers, paths, commands, numbers, UI strings kept verbatim), `strength` (MUST / MUST-NOT / SHOULD / INFO),
`scope` (when it applies, exceptions), `refs` (ADR ids, phases, other KUs), `notes`. Later passes add `fate`.

**Types:** RULE · DECISION (an ADR's decision) · RATIONALE (the why) · LESSON · PROCEDURE · CONTRACT (API, schema,
file or wire format) · BEHAVIOUR (what a shipped feature does) · STRUCTURE (where code lives, responsibilities) ·
STATE (versions, counts, ids that change per release) · HISTORY (what happened when) · PLAN (backlog, future) ·
TERM (glossary).

**High-stakes units:** RULE, DECISION, LESSON, CONTRACT, and PROCEDURE steps marked mandatory. These are checked
at 100% by every review (§6.3).

### 3.3 Fate (set in reconcile)
`keep` (goes into a new document) · `merge:<KU>` (duplicate; the target keeps the strongest wording and all
scopes) · `superseded:<KU or ADR>` · `history` (not in the new docs; listed in the history index with its source
path) · `wrong` (**only** through a user-decided conflict).

### 3.4 Conflicts and authority
When sources disagree, or a source disagrees with the code, the conflict is **always recorded**
(`migration/conflicts.md`: both sides, cited). Default authority: **code at HEAD > as-built `progress/` > tracker
§6 > bible > specs (plans)**; for ADRs, `decision-log.md` > `bible/04`. A conflict that changes a RULE, DECISION
or CONTRACT is **decided by the user**; others follow the authority order with the record kept.

### 3.5 Areas
The partition the store is organized by — one per subsystem, each with path globs over the code repos.
**Approved at the 47-01 gate (2026-10-19); `migration/areas.yaml` is authoritative** — 14 areas: `engine` ·
`runs-config` · `data-plane` · `workflow-library` · `agent-sdk` · `chat-copilot` · `appian-parser` · `appian-kb` ·
`feature-sdlc` · `stories-workbench` · `collaboration-hub` · `memory` · `web-ui` · `dev-release-ops`; plus the
pseudo-areas `all` (→ `CORE.md`) and `history` (no pack). (The draft candidate list had 12; the gate split platform
runtime into `engine` + `runs-config` and the parser out of the Appian knowledge base.)

## 4. Target design — the new knowledge store
```
genesis/knowledge/                 authored source of truth (with provenance comments)
  core.md                          → built CORE.md (L0)
  areas/<area>/pack.md             → built area pack (L1)
  areas/<area>/reference/*.md      contracts + feature behaviour, loaded when the pack points to them
  rules/<ID>.md                    one rule per file: ADR-nnn, LSN-nnn (lessons), STD-nnn, WA-nnn (agreements)
  procedures/<name>.md             spec authoring, build loop, review, release, fleet + live acceptance, docs upkeep
  state/current.yaml               versions, DB version, test counts, last CI ids (generated where possible)
  glossary.md
  history/INDEX.md                 one row per phase: what shipped, versions, archive paths
  _build/                          GENERATED, loaded by agents: CORE.md, areas/<area>/SKILL.md (pack + full text
                                   of its rules + its lessons), procedures/<name>/SKILL.md — provenance stripped
genesis/tools/gk/                  the CLI (47-02)
genesis/migration/                 PROGRESS.md, inventory, batches, ledger/, reconciled/, conflicts.md,
                                   handoffs/, reviews/, questions/, exams/, reports/
genesis/agents/                    sources of the Kiro agents + install script (copied to ~/.kiro/agents)
genesis/phases/                    from cutover: new phase specs + handoffs + as-builts
genesis/archive/                   from cutover: everything that was here before (frozen, never loaded)
```
**Loading layers (one level of routing only):**
- **L0 `CORE.md` (≤ 15K tokens), always loaded:** what Genesis is; the architecture; rules that apply everywhere;
  the work loop and working agreements; the **area router** (area → paths → pack); how to load more.
- **L1 area packs (≤ 12K tokens each), loaded per task:** the area's scope and module map, its behaviour and
  contract summaries, the **full text** of every active rule and lesson for the area (built from `rules/`, so each
  rule has one source), pointers to its reference docs.
- **L2 reference docs (≤ 8K each)** inside an area, read when the pack points to them.
- **History** is never loaded; `history/INDEX.md` lets a human (or an agent the user explicitly asks) find it.

**Rule file** (frontmatter frozen in 47-01):
```markdown
---
id: ADR-076
kind: decision                      # decision | lesson | standard | agreement
status: accepted                    # proposed | accepted | superseded
areas: [feature-sdlc, stories-workbench]
applies_to: ["genesis/genesis/services/spec_change.py", "genesis/genesis/kb/cr_*.py"]
amends: [ADR-050]
superseded_by: null
verify: "cd genesis && .venv/bin/python -m pytest -q tests/test_cr_apply.py"
---
MUST: Apply is the only path that changes the stories or backlog of a traceable feature.
MUST: a locked story changes only when the user asked for it and ticked the confirmation.
MUST NOT: the agent writes stories; it only writes ./cr/CR-n/plan.json.
Why: …(rationale rewritten)…
```
**Sub-spec context manifest** (every future sub-spec carries it; the build agent loads exactly this):
```yaml
context:
  areas: [collaboration-hub, web-ui]
  rules: [ADR-063]                  # beyond the areas' own
  read: [genesis/genesis/collab/service.py]
  depends_on: [48-02]
```
**Deterministic selection:** `gk rules --paths <files>` / `gk context <sub-spec>` select by area and path globs —
agents run it as the first step of their loop, so loading never depends on the model choosing to open a skill.

## 5. Method — four passes, separate roles
Every unit of work is one session with one role agent, followed by an **independent review**
(`genesis-migration-reviewer`, §6). No agent reviews its own work.

### 5.1 Pass 1 — Extract (`genesis-migration-extractor`)
Per batch (§7): read each source **fully, in order**; write units to `migration/ledger/<batch>.jsonl` and a
coverage map (`<batch>.coverage.json`: every line range → unit ids or a skip reason: blank, heading-only,
formatting, duplicate-in-batch → unit id). No new documents are written in this pass.

### 5.2 Pass 2 — Reconcile (`genesis-migration-writer`, reconcile mode)
Per area: gather the area's units (`gk ledger --area`), merge duplicates, apply supersessions and amendments,
check every `exact` item that names code against the repos at HEAD, set every unit's fate, record conflicts, and
collect the user's decisions. Output `migration/reconciled/<area>.jsonl`.

### 5.3 Pass 3 — Write (`genesis-migration-writer`, write mode)
Per area: write the rule files, the pack and the reference docs **from the reconciled units and the code** — never
from the old prose (the writer does not open old documents except to resolve a specific unit). Every paragraph
carries `<!-- src: KU-… -->`; `gk build` strips these from `_build/`.

### 5.4 Pass 4 — Examine (`genesis-migration-examiner`)
A question bank is written from the ledger by a session that did **not** write the docs (extractor, question
mode): at least one question per high-stakes unit; every lesson becomes a scenario ("you are changing X — what
must you do and why?"). The examiner answers **from `knowledge/_build/` only**, citing the document for each
answer; the reviewer grades against the units. A miss is a defect in the new docs, fixed by the writer.

## 6. Verification standard (what the reviewer applies to every unit of work)
### 6.1 Mechanical checks (re-run by the reviewer, never taken from the handoff)
Schema validation of everything produced; line coverage = **100%** of non-blank lines; unit usage (after
reconcile) = **100%** with a fate; the copy check (§6.2); `exact` items match their sources and the code; links
resolve; `_build/` is fresh; budgets (§7) met.
### 6.2 Copy check
No paragraph of a new document may share a run of **12 or more consecutive words** with any source, ignoring code
spans, `exact` items and quoted UI strings. An exemption needs an inline `<!-- verbatim: reason -->` and is
reviewed.
### 6.3 Sampling and high-stakes items
Seeded random samples, ≥ 30 per direction: source → ledger; ledger → source; new document → units/sources/code.
**All** high-stakes units in scope are checked for survival at full force — same strength, scope and exceptions.
### 6.4 Verdict
BLOCKER (knowledge lost, distorted or invented; a rule weakened; a check that can pass wrong work; a DoD artifact
missing) · MAJOR · MINOR · PROCESS. **PASS** = no BLOCKER/MAJOR; **PASS WITH FINDINGS** = MINOR/PROCESS only;
**FAIL** otherwise. A FAIL is fixed in a new session and re-reviewed (`-review-2`, …). PROCESS findings update the
method (recorded in `migration/PROGRESS.md` §Method changes) before the next unit starts.

## 7. Budgets
- **Sessions:** a session's mandatory reading is **≤ 300K characters** (~80K tokens); an extraction batch is
  **≤ 200K characters** of source (lowered from 250K at the 47-01 gate, 2026-10-19, so batch + the session's
  spec/schema reading stays under the 300K cap). 47-01's batch plan enforces this; anything larger is split.
- **Store:** `CORE.md` ≤ 15K tokens · area pack ≤ 12K · reference doc ≤ 8K · rule file ≤ 1.5K.
- **Reviews:** the reviewer stays under half its context; it samples (with a seed) rather than skim.

## 8. Agents
| Agent | Created in | Writes only to |
|---|---|---|
| `genesis-migration-reviewer` | ✅ 2026-10-19 (`~/.kiro/agents`) | `migration/reviews/`, `/tmp/genesis-migration-review/` |
| `genesis-migration-extractor` | 47-02 | `migration/ledger/`, `migration/questions/`, `migration/handoffs/` |
| `genesis-migration-writer` | 47-02 | `migration/reconciled/`, `migration/conflicts.md`, `knowledge/`, `migration/handoffs/` |
| `genesis-migration-examiner` | 47-02 | `migration/exams/` |
| `genesis-spec`, `genesis-build`, `genesis-review`, `genesis-release`, `genesis-docs` | 47-09 | per role (47-09) |

**How agents are launched (verified 2026-10-19):** `kiro-cli chat --agent <name> --no-interactive "<task>"` from
`/tmp`, **without `--trust-all-tools`**, with `write` NOT auto-approved. Trust-all, or auto-approving `write`,
bypasses the write-path limits and the denied-command list (both observed). The prompts also forbid out-of-scope
actions (observed to hold).

## 9. Workflow for every unit of work
1. The orchestrating session gives the user the start prompt for the unit.
2. The user runs it with the named role agent; the agent writes its outputs + a handoff note
   (`migration/handoffs/<unit>.md`), updates `migration/PROGRESS.md`, commits and pushes project-tracker.
3. The orchestrating session runs `genesis-migration-reviewer` on the unit and reads the report.
4. PASS → next unit. FAIL → a fix prompt → fix session → re-review. PROCESS findings → method change first.
5. Each sub-spec ends with a **gate** the user approves (47-01 taxonomy, 47-03 pilot GO/NO-GO, 47-05 conflict
   decisions, 47-10 acceptance, 47-11 cutover).

**Freeze:** no new Genesis phase starts until cutover. If any source changes after the base tag, 47-10 runs a delta
batch over the changed ranges.

## 10. Sub-specs
| # | Sub-spec | Sessions (est.) | Gate |
|---|---|---|---|
| 47-01 | Inventory, area taxonomy, schemas, batch plan | 1–2 | user approves areas + batch plan |
| 47-02 | `gk` tooling + the migration agents | 2 | — |
| 47-03 | **Pilot: collaboration & Hub**, all four passes end to end | 6–8 | **GO / NO-GO** |
| 47-04 | Extraction of all remaining batches (B01–B26) | ~26 | — |
| 47-05 | Reconcile, per area | ~12 | user decides conflicts |
| 47-06 | Write, per area | 12–20 | — |
| 47-07 | Core, state, procedures, glossary, history index | 2–3 | — |
| 47-08 | Examination of every area | ~6 | — |
| 47-09 | Role agents + skills + hooks (`genesis-spec/build/review/release/docs`) | 2 | — |
| 47-10 | Whole-program review & acceptance (S1–S7, delta batch, real-task trial) | 2 | user accepts |
| 47-11 | Cutover: archive, onboarding, validator gate, tags | 1 | user approves cutover |

Mandatory sub-spec types: **review** = 47-10 (plus a review after every unit); **release & onboarding** = 47-11;
**API development** = not applicable (no product API; the `gk` CLI interface is specified in 47-02).
Total ≈ 75–85 work sessions plus their reviews.

## 11. Risks
| Risk | Mitigation |
|---|---|
| Rewriting loses or softens knowledge | line coverage + unit fates + 100% high-stakes review + examination |
| Rewriting invents knowledge | provenance on every paragraph; reviewer samples new → source; code checks |
| "Rewritten" is really copied | 12-word copy check; writer works from units, not old prose |
| Old docs are wrong | reconcile checks code; conflicts go to the user |
| Router misses a rule | path globs + areas; `gk rules` deterministic; recall test S6; reviewer computes rules from the diff |
| A session overflows | 300K-char reading cap, batch plan, handoff notes |
| Guardrails bypassed | launch without trust-all (§8); prompts forbid; reviewer is read-only |
| Sources change mid-migration | base tag + freeze + delta batch |

## 12. Decisions so far (user, 2026-10-19)
Restructure the store + role agents (option A) · rewrite every document from scratch, never copy · after cutover
agents use only the new documents; the old ones are archived · a separate Documentation agent maintains the store
after every phase (`genesis-docs`, the only agent that edits it) · an independent reviewer agent verifies every
sub-spec/batch (created first, global) · start with the spec set; a one-area pilot proves the method first.
