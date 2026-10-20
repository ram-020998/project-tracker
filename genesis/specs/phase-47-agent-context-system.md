# Phase 47 — Agent Context System (tiered context, role agents, cheap migration)

> **Status:** 🟡 **SPEC-DRAFTED 2026-10-20 — awaiting build sign-off.** · **Author:** Genesis assistant with the user.
> Sub-specs: `phase-47-agent-context-system/47-01..47-10`. Findings (research + every decision): `47-01-findings.md`.
> New ADR (**Proposed**): **ADR-077** (§15). Repo: **project-tracker only** — no Genesis code repo changes, no Genesis
> release. Operator guide (how to use the agents): `../agent-system/OPERATOR_GUIDE.md`.

## 1. Why this phase exists

Every Genesis session starts with "read the bible". The mandatory read set is **~1.12 MB ≈ 280–320K tokens**
(`AGENT_ONBOARDING.md` + `bible/00..08` + `tracker.md` + `reference/decision-log.md` + `reference/coding-standards.md`),
before any phase spec, progress doc or code. A fresh 1M-context agent is at **45–50 %** before it does any work, and the
corpus grows **20–40K tokens per phase** because the rules say "read every chunk" and "never summarize". At this rate a
fresh session is full around Phase 55–60.

About **half of the mandatory bytes are history** (the 353 KB `tracker.md` §6 status log, the shipped-phase blocks in
`bible/08`, old release banners, 218 CI pipeline ids). The ADRs are mandatory **twice** (`decision-log.md` and
`bible/04`). A phase's outcome is recorded in up to six places. Measurements: `47-01-findings.md` §2.

A previous attempt to fix this — an agent reading every document and rewriting the corpus from scratch — needed
**120–200 agent sessions** and was abandoned. Its cost grew with the corpus. This phase must not repeat that.

## 2. Goal

1. **A fresh session starts at ≤ 10 % context** (target: ~60–90K tokens: always-loaded core + one role + the task's
   context pack), with **no rule missed**: every ADR and every hard-won lesson stays visible as a one-line rule in every
   session, and the full text of the ones that apply to the task is loaded **deterministically** by a program, not by
   the agent's memory or a fuzzy search.
2. **Five role agents** (Kiro CLI 3, installed globally, sourced from `project-tracker/genesis/agent-system/`):
   `genesis-spec`, `genesis-dev`, `genesis-review`, `genesis-release`, `genesis-docs`, each with its own write
   permissions, on-demand skills and hooks. An **install** script and an **update** script sync the global installation
   from the project-tracker folder.
3. **A cheap, lossless migration**: **≤ 6 agent sessions** in total for the whole phase, including this one. Text is
   **moved, never rewritten**; scripts do the bulk work; agents only make judgment calls on small inputs; a script proves
   that no paragraph was lost.
4. **A documentation standard** with one home per fact, and a documentation agent that writes everything back at the
   end of each phase so the system stays lean as Genesis grows.
5. **An operator guide** — which agent to start, when, with what prompt, in what order.

## 3. Decisions (locked with the user, 2026-10-20 — detail in `47-01-findings.md` §5)

| # | Decision |
|---|---|
| D1 | The **active layer may be curated** (one-line rules, an overwritten current-state snapshot). The **archive stays verbatim**, and a lossless check guarantees no paragraph disappears. This replaces the bible's "never summarize" rule for the active layer only. |
| D2 | Agent configuration, skills, hooks, the `genesis-ctx` tool and the **install / update / uninstall** scripts live in `project-tracker/genesis/agent-system/`. Install copies agents into the **global** `~/.kiro/agents/`; update re-syncs after edits in project-tracker. |
| D3 | Agents are launched from the user's **root workspace** (outside project-tracker, no `README.md`/`AGENTS.md`), so inherited default resources are negligible; the global `chat.disableInheritingDefaultResources` setting is **not** changed (it would affect the user's other agents). All agent paths are **absolute** (rendered at install). |
| D4 | Roles: **spec, dev, review, release, documentation**. API development, web, workflow authoring, DB migrations and live acceptance are **skills**, not agents. |
| D5 | Target **Kiro CLI 3** (Markdown agent profiles, `permissions.rules`, PascalCase hooks, `skill://` on demand). |
| D6 | Specs in the usual **umbrella + sub-spec** format, with this layout (47-01..47-10). API sub-spec: **N/A** (no API in this phase). |
| D7 | **Move, don't rewrite.** Existing files stay where they are and keep their text; we add a **sidecar index** (tags) and change what is *loaded*, not what is *written*. `specs/`, `progress/` and `reference/` (except the decision-log index) are untouched. |
| D8 | **Bootstrap rule:** Phase 47 sessions do **not** read the bible. Their context is this spec set plus the specific files a sub-spec operates on (mostly via scripts). |
| D9 | Rules are selected by **program** (manifest + area tags + amendment closure). Semantic search is allowed for **history only**, never for selecting rules (ADR-001 spirit: determinism never depends on a model). |

## 4. Current state (measured 2026-10-20 — full detail in `47-01-findings.md` §2)

| Source | Size | Nature | After Phase 47 |
|---|---|---|---|
| `tracker.md` (§6 = 353 KB) | 386 KB | history | §6 → `archive/`; not mandatory |
| `reference/decision-log.md` | 210 KB | ADR full text | stays; indexed; loaded **per ADR** |
| `bible/08-roadmap-and-backlog.md` | 134 KB | shipped-phase blocks + backlog | shipped blocks → `archive/`; backlog stays |
| `bible/06-hard-won-lessons.md` | 80 KB | 86 lessons | stays (+ invisible id markers); loaded **per lesson** |
| `bible/03-codebase-map.md` | 79 KB | code map | stays; loaded **per area section** |
| `bible/04-adrs-and-constraints.md` | 74 KB | ADR digest (duplicates decision-log) | stays as source of the one-liners; loaded **per ADR** |
| `bible/01-current-state.md` | 71 KB | state + history | → `archive/`; replaced by `context/state/current.md` (~3K tokens) + live `genesis-ctx status` |
| `AGENT_ONBOARDING.md` | 35 KB | index + old banners | banners → `archive/`; becomes a short pointer |
| `bible/00` / `02` / `05` / `07` | 30 / 4 / 6 / 4 KB | overview / architecture / dev loop / work loop | 00 → `archive/` (its §0 paragraph moves into L0); 02 + 07 always loaded; 05 loaded by skills |

## 5. Operator experience (summary — full detail in `../agent-system/OPERATOR_GUIDE.md`)

```
cd ~/repo-gitlab/ramaswamy.u                       # root workspace (never project-tracker)
kiro-cli chat --agent genesis-spec                 # 1. spec session: Q&A → umbrella + sub-specs (+ context manifests)
kiro-cli chat --agent genesis-dev                  # 2. one session per sub-spec: "Implement 48-03"
                                                   #    → packs its context, builds, tests, sub-agent review, As-built
kiro-cli chat --agent genesis-review               # 3. whole-phase review + live acceptance
kiro-cli chat --agent genesis-release              # 4. version, tag, push, CI (asks before every push/tag)
kiro-cli chat --agent genesis-docs                 # 5. write-back: ADRs, lessons, state, changelog, indexes
```

No more "read the bible". Each agent starts with the always-loaded core (L0) and the live repo status (a `SessionStart`
hook), and pulls the rest through `genesis-ctx`.

## 6. Design overview

### 6.1 Four tiers of context

| Tier | What | How loaded | Budget |
|---|---|---|---|
| **L0** always | `context/L0-core.md` (what Genesis is, retrieval protocol, key implementation contracts) + `bible/02` + `bible/07` + generated **ADR digest**, **lesson digest**, **area catalog** + `context/state/current.md` | `file://` resources in every agent | **≤ 15K tokens** |
| **L1** by role | role prompt (agent body) + `reference/coding-standards.md` (dev/review) + **skills** (bodies on demand) | agent profile; `skill://` | ≤ 10K at start |
| **L2** by task | the **context pack**: full text of the ADRs, lessons and code-map sections for the task's areas (+ amendment closure) + the list of specs/code to read | `genesis-ctx pack` | ≤ 40K (warn above) |
| **L3** on demand | `archive/`, old `specs/` + `progress/`, git history | `genesis-ctx search`, `read` with ranges | — |

One routing level only: a one-line digest entry points straight at the full text. (Controlled evidence that a second
routing level never helps and sometimes hurts — `47-01` §3.)

### 6.2 The context compiler — `genesis-ctx` (stdlib-only Python; 47-03)

`status` · `pack` · `check` · `adr` / `lesson` / `area` · `search` · `index` · `lint` · `add adr|lesson` · one-shot
migration commands `archive` · `mark` · `propose-tags` · `verify-lossless`.

### 6.3 The sidecar index (47-02)

Nothing in `decision-log.md`, `bible/04`, `bible/03` is restructured. `context/tags/*.toml` record per ADR / lesson /
code-map section: **areas**, **path globs**, **amends / amended_by**, **status** and a curated **one-line rule**.
`context/areas.toml` maps ~20 areas to repo path globs and keywords. Lessons gain invisible `<!-- L-NNN -->` markers
(the only in-place edit, scripted).

### 6.4 Sub-specs carry a context manifest (47-02 §5)

Every future sub-spec has a `## Context manifest` (TOML block: areas, extra ADRs/lessons, docs, code paths, upstream
sub-specs). `pack` = manifest ∪ area defaults ∪ path-derived areas ∪ amendment closure — **two independent routes**
must both fail before a rule is missed; the review agent's `check` on the diff is the third.

### 6.5 Role agents (47-06)

| Agent | Writes | Always loads | Skills | Hooks |
|---|---|---|---|---|
| `genesis-spec` | `specs/**` + the `README.md` phase row in project-tracker (local commits) | L0 | spec-authoring | SessionStart status; Stop: bounded spec lint |
| `genesis-dev` | code repos (commit locally; **no push/tag**); the sub-spec's As-built section | L0 + coding-standards | backend-dev, web-dev, workflow-authoring, db-migration, live-acceptance | SessionStart status; PreToolUse bulk-read guard |
| `genesis-review` | review reports only (read-only on code) | L0 + coding-standards | code-review, live-acceptance | SessionStart status |
| `genesis-release` | version files; tag/push **always ask** | L0 | release | SessionStart status |
| `genesis-docs` | `project-tracker/genesis/**` only | L0 | doc-writeback, spec-authoring | SessionStart status; Stop: bounded `lint` |

`genesis-dev` may spawn `genesis-review` as a sub-agent (fresh context) for the per-sub-spec independent review.

### 6.6 Install / update (47-07)

`agent-system/install.sh` / `update.sh` / `uninstall.sh` → a stdlib Python installer that renders `{{TRACKER}}` /
`{{REPOS}}` / `{{MODEL}}` placeholders, validates, writes `~/.kiro/agents/genesis-*.md`, skills under
`~/.kiro/genesis/skills/` (outside the default skill path, so other agents don't inherit them), hook scripts and a
`genesis-ctx` shim; a manifest with hashes; backups; dry-run diff; removes files dropped from the source; never touches
files it does not own.

### 6.7 Documentation standard (47-08)

One home per fact (routing table in 47-08 §2). New ADRs: `decision-log.md` section + a tag entry (no new `bible/04`
bullets). New lessons: a marked bullet in `bible/06` + a tag entry. State: overwrite `context/state/current.md`. History:
`progress/` + one `context/changelog.md` line + a ≤ 5-line `tracker.md` §6 entry. `genesis-docs` does the write-back at
phase end and must leave `genesis-ctx lint` green.

## 7. Session plan (the cheap migration — 6 sessions)

| Session | Sub-specs | Who | Notes |
|---|---|---|---|
| S1 | 47-01 + this set + operator guide | default agent | **done** (this session) |
| S2 | 47-02 skeleton + 47-03 `genesis-ctx` + tests | default agent, bootstrap rule | biggest build session |
| S3 | 47-04 scripted migration + lossless proof; `propose-tags` output | default agent | scripts do the work; agent reads reports only |
| S4 | 47-05 tag review with the user + `L0-core.md` + `state/current.md` | default agent | the one judgment-heavy session; reviews a ~180-row table, not the corpus |
| S5 | 47-06 agents/skills/hooks + 47-07 installer + 47-08 standard | default agent | skills are pointers + procedures, not rewrites |
| S6 | 47-09 eval + pilot + review; 47-10 switchover | **the new agents** (dogfood) | first real use |

## 8. Lifecycle of knowledge (after the switch)

```
spec session ──► umbrella + sub-specs (with context manifests) ──► genesis-ctx lint
dev session  ──► genesis-ctx pack <sub-spec> ──► build/test ──► genesis-review sub-agent (check on diff) ──► As-built
phase review ──► genesis-ctx check --since <tag> ──► review report ──► live acceptance
release      ──► tags + CI ids ──► release notes in the release sub-spec
docs         ──► ADRs/lessons (+ tags) · state overwrite · changelog line · progress doc · README row ──► index + lint
```

## 9. Interfaces (CLI only — no HTTP API)

`genesis-ctx` (47-03 §3) and the three scripts (47-07 §3). No Genesis API, DB or web change.

## 10. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| **47-01** | docs | Findings: measurements, research, options, decisions |
| **47-02** | docs | Layout, sidecar metadata schemas (areas, tags), context-manifest format, L0 composition |
| **47-03** | project-tracker (`agent-system/tools`) | `genesis-ctx` + pytest suite |
| **47-04** | docs | Scripted migration: archive history, lesson markers, `bible/04` contracts → L0, lossless proof |
| **47-05** | docs | Tag review (areas, amendments, one-line rules), `L0-core.md`, `state/current.md`, digests |
| **47-06** | project-tracker (`agent-system`) | Five CLI-3 agents, ten skills, hook scripts, bulk-read guard |
| **47-07** | project-tracker (`agent-system`) | install / update / uninstall + installer tests |
| **47-08** | docs + `agent-system` | Documentation standard; `genesis-docs` write-back procedure; `add adr|lesson` |
| **47-09** | all | Golden-question eval, Phase-46 recall replay, live pilot, independent review |
| **47-10** | all | Switchover: new `AGENT_ONBOARDING.md`, operator guide final, ADR-077 Accepted, docs |

Build order: 47-02 → 47-03 → 47-04 → 47-05 → 47-06 → 47-07 → 47-08 → 47-09 → 47-10.

## 11. Release plan

No Genesis code repo changes → **no Genesis tag**. "Release" = project-tracker commit + push (on the user's go-ahead),
`agent-system/install.sh` run, the switchover in 47-10, ADR-077 → Accepted. Rollback: the old bible files are still in
git; `uninstall.sh` removes the agents; `git revert` restores the mandatory set.

## 12. Scope

**In:** §2 and §10. **Out:** rewriting or summarizing historical documents; changing Genesis product code; changing the
user's global Kiro settings or other agents. **Deferred:** a `knowledgeBase` semantic index over `archive/` (optional,
history only); auto-generating the README phase table; CI for project-tracker (the lint runs from hooks and locally).

## 13. Defaults (chosen by the assistant — confirm at build sign-off)

| # | Default |
|---|---|
| Q1 | Tag files are **TOML** (read with stdlib `tomllib`; tiny emitter for writes) — no third-party dependency. |
| Q2 | Budgets: L0 ≤ 15K tokens, pack warn at 40K / fail at 80K (estimated as chars ÷ 4). |
| Q3 | Archive files are named by source (`archive/tracker-status-log.md`, `archive/bible-08-shipped-phases.md`, …); each moved block leaves a one-line pointer at its old place. |
| Q4 | `genesis-ctx` runs from its project-tracker source via a shim, so tool fixes apply without reinstall; agents/skills/hooks need `update.sh`. |
| Q5 | `genesis-dev` commits locally; only `genesis-release` pushes or tags, and always asks. |
| Q6 | No model is pinned in agent profiles (uses your default); `install.conf` can set `MODEL`. |

## 14. Risks

| Risk | Mitigation |
|---|---|
| A wrong area tag hides a rule | Every rule is always visible as a one-liner (L0 digest); path globs give a second route; the review agent's `check` on the diff is a third; the Phase-46 recall replay (47-09) must hit 100 % |
| Migration loses content | Move-only; `verify-lossless` hashes every paragraph of the baseline mandatory corpus and fails on any missing one |
| Agents read big files whole anyway | L0 retrieval protocol + `PreToolUse` bulk-read guard (blocks whole-file reads of `decision-log.md`, `bible/03/04/06`, `archive/**`; ranged reads and `genesis-ctx` allowed) |
| One-liner digests drift from the full text | One-liners are curated tag fields; `lint` flags ADRs/lessons whose full text changed after the one-liner was reviewed (fingerprint) |
| CLI-3 behaviour differs from the docs (sub-agents, hooks) | 47-06 starts with a 15-minute probe of each feature on the installed CLI; fallbacks documented |
| The system rots after a few phases | `genesis-docs` + `lint` in its Stop hook; budgets enforced by `lint` |
| Stop-hook loops | Hooks continue at most twice per session, then report and stop |

## 15. ADR summaries (full text in `47-01-findings.md` §6; added to `reference/decision-log.md` at 47-10)

**ADR-077 — Tiered, program-compiled agent context and role agents (Proposed).** Agent context is loaded in four tiers
(always-loaded core with one-line rules for every ADR and lesson; role skills; a per-task context pack compiled by
`genesis-ctx` from manifests, area tags and amendment links; on-demand archive). Rules are selected by program, never by
semantic search. History is archived verbatim and leaves the mandatory set. Five role agents with scoped write
permissions replace "read the bible". Amends the bible's "read every chunk" and "never summarize" rules (active layer
only); the archive remains verbatim.
