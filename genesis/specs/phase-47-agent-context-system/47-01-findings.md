# 47-01 — Findings: why sessions start half full, how others solve it, what we decided

> **Status:** ✅ DONE 2026-10-20. Repo: docs. Parent: `specs/phase-47-agent-context-system.md`.

## 1. The problem (as stated by the user, 2026-10-20)

Each new session is told to follow the bible; the bible lists every document to read; a fresh 1M-context agent is at
45–50 % before any work. The user works in a fixed rhythm: one **spec session** (Q&A → umbrella + mandatory and
feature-specific sub-specs), then **one session per sub-spec**, each re-reading the bible. The user wants each agent to
get the necessary information at the necessary step, with **nothing missed**, in a standard, scalable and above all
reliable way. A previous attempt (one agent reads everything and rewrites the corpus) needed 120–200 sessions and was
abandoned; the migration must be cheap.

## 2. Measurements (2026-10-20, `wc -c` on project-tracker `main`)

### 2.1 The mandatory read set

| File | Bytes |
|---|---|
| `tracker.md` | 386,453 (§6 status log alone: 353,557 — 235 entries) |
| `reference/decision-log.md` | 210,323 (77 `## ADR-` sections) |
| `bible/08-roadmap-and-backlog.md` | 134,108 |
| `bible/06-hard-won-lessons.md` | 80,477 (86 lessons) |
| `bible/03-codebase-map.md` | 79,162 |
| `bible/04-adrs-and-constraints.md` | 74,162 (62 ADR bullets + implementation contracts + amendments) |
| `bible/01-current-state.md` | 71,382 |
| `AGENT_ONBOARDING.md` | 34,874 (~25 KB = historical banners for Phases 26–30) |
| `bible/00-onboarding-and-overview.md` | 29,836 |
| `reference/coding-standards.md` | 9,794 |
| `bible/05` / `bible/02` / `bible/07` | 6,256 / 3,627 / 3,581 |
| **Total** | **1,124,035 ≈ 280–320K tokens** |

Plus, per task, the relevant phase specs + progress docs (Phase 46 alone: 254 KB). The whole tracker folder holds 442
Markdown files, 4.7 MB — which is why "read everything and rewrite" cannot fit in a bounded number of sessions.

### 2.2 Structural causes

1. **History is mandatory.** Roughly half the bytes: tracker §6, the `### ✅ SHIPPED` blocks of `bible/08`, banners,
   218 CI pipeline ids, "SUPERSEDED" build logs.
2. **Duplication.** ADRs exist in full (`decision-log.md`) and as long digests (`bible/04`), both mandatory. ADR-062 is
   mentioned in 9 mandatory files. A shipped phase is described in tracker §6, `bible/08`, `bible/01`, `README.md`, the
   onboarding banner and `progress/`.
3. **Growth is built into the rules:** "read every chunk … not just the one that looks relevant" and "keep it
   verbatim-faithful — never summarize away … when adding an entry".
4. **No separation by kind.** Orientation, constraints, lessons, current state, procedures, area knowledge and history
   all share one loading policy ("all of it, always").

### 2.3 What is good and must be kept

The ADR discipline, the hard-won lessons, the work loop and working agreements, the spec → sub-spec rhythm, the
per-phase `progress/` as-built docs, and the habit of citing evidence. Phase 47 changes **loading and routing**, not the
knowledge.

## 3. Research summary

| Source | Takeaway used |
|---|---|
| Anthropic, *Effective context engineering for AI agents* (2025-09) | Context is a finite "attention budget" with diminishing returns ("context rot"); aim for the smallest high-signal set; **just-in-time retrieval** via lightweight identifiers; **structured notes** across sessions; **sub-agents** explore in fresh contexts and return condensed results. |
| Agent Skills / Kiro `skill://` | **Progressive disclosure**: name + description always loaded, body on demand. Kiro: `file://` resources and steering are in context on **every turn**; `skill://` loads on demand. |
| He et al., *Is Progressive Disclosure All You Need for Long-Context Agents?* (arXiv 2607.17598, 2026-07) | Controlled study: once a corpus is too large to navigate by reading, raw navigation collapses and **one-level** disclosure wins; a **second routing level never helped and sometimes broke accuracy**. → one hop from digest to full text. |
| Kiro CLI 3 docs (custom agents, configuration reference, hooks) | Markdown agent profiles; `resources` = `file://` / `skill://` / `knowledgeBase`; `permissions.rules` (`allow`/`ask`/`deny`, deny wins); `SessionStart` / `UserPromptSubmit` hook **stdout is added to context**; `Stop` hook can make the agent continue; `PreToolUse` can block (exit 2); `toolsSettings.subagent.availableAgents`; custom agents inherit default resources (cwd `README.md`/`AGENTS.md`, global skills/steering) unless disabled. |
| Genesis's own ADR-001 / ADR-011 / ADR-075 | Determinism must not depend on a model's discipline; bounded retry → escalate; **program-owned IDs** inside agent-authored text stay stable. Applied here: rules are selected by program; hook loops are bounded; lessons get program-owned markers. |

## 4. Options considered

| Option | Verdict |
|---|---|
| A. Keep the bible, just trim it | Buys a few phases; growth continues; no "nothing missed" guarantee. Rejected. |
| B. Rewrite the corpus into a new knowledge base from scratch | The prior attempt: cost ∝ corpus (120–200 sessions). Rejected. |
| C. Role agents + skills only, still reading the bible | Moves the problem into five places. Rejected alone. |
| D. Semantic search (RAG / `knowledgeBase`) for everything | Fuzzy recall is the wrong tool for "which non-negotiables apply". Rejected for rules; allowed for history (deferred). |
| **E. Tiered context + sidecar index + program-compiled packs + role agents; move-only migration** | **Chosen.** Cost ∝ index size (~180 items), not corpus size. |

## 5. Decisions (locked with the user, 2026-10-20)

### 5.1 Round 1 — the proposal (tiers, compiler, role agents)
Accepted in principle. Questions asked: verbatim rule, agent location, roles, CLI version, spec format.

### 5.2 Round 2 — answers (verbatim intent)
1. **Verbatim rule:** "it's fine" — the active layer may be curated; the archive stays verbatim (D1).
2. **Location:** agent configuration and an **install script** in the Genesis folder of project-tracker; install puts
   agents in the **global** directory; an **update script** re-syncs the global installation after edits (D2).
3. **Roles:** spec, dev, review, release **and documentation** — a documentation agent that takes the completed work of a
   phase and updates all documentation (D4).
4. **CLI 3** — design everything for CLI 3 (D5).
5. **Umbrella + sub-spec format** (D6).
6. **Migration must be cheap:** no from-scratch rewrite; migrate with very little effort using what exists; focus on
   cleaning up duplicates; not 20–30 sessions (D7).

### 5.3 Round 3 — answers
1. **Inherited resources:** agents are launched from the root workspace (no README there), never from project-tracker;
   no global setting change needed (D3).
2. **Phase layout:** accepted (47-01..47-10).
3. **New request:** a detailed **operator guide** — how to use each agent step by step through a phase, the generic
   prompts, and the sequence → `agent-system/OPERATOR_GUIDE.md` (drafted in S1, finalized in 47-10).

### 5.4 Assistant's refinements (part of the proposal the user accepted)
- The per-ADR/lesson metadata lives in **sidecar TOML** files, not in the documents (D7) — no restructuring of
  `decision-log.md` / `bible/04` / `bible/03`.
- The always-loaded digest uses the **existing** text where possible: `bible/06` lessons already lead with a bold
  one-sentence rule; `bible/04` bullets already lead with a one-sentence ADR rule.
- Duplicates are removed **from the active layer** (archived), not deleted — so the lossless check stays trivially true.
- **Bootstrap rule** (D8): Phase 47 itself is built without reading the bible.
- Skills live in `~/.kiro/genesis/skills/` (not `~/.kiro/skills/`) so the user's other agents do not inherit them.

## 6. ADR-077 (Proposed) — full text

- **Status:** Proposed — 2026-10-20 (Phase 47).
- **Context.** The "read the bible" onboarding loads ~300K tokens of mixed rules, state and history into every session
  (45–50 % of a 1M window) and grows each phase. Rules are only as reliable as the agent's recall of a huge context.
- **Decision.** (1) Agent context is loaded in four tiers: **L0** always (a short core, architecture, work loop, and a
  one-line digest of **every** ADR and lesson, an area catalog, the current-state snapshot); **L1** per role (agent
  prompt, coding standards, `skill://` procedures); **L2** per task (a context pack compiled by `genesis-ctx` from the
  sub-spec's context manifest, area tags, path globs and the amendment closure); **L3** on demand (archive, history).
  (2) Rule selection is **deterministic** (program + tags); semantic search is never used to select rules. (3) History
  is moved verbatim to `archive/` and is not mandatory reading. (4) One home per fact; summary views are generated.
  (5) Five role agents (`genesis-spec/dev/review/release/docs`) with scoped write permissions are installed globally from
  `project-tracker/genesis/agent-system/` by install/update scripts. (6) The migration is move-only and proven lossless.
- **Alternatives rejected.** Trimming the bible; a from-scratch rewrite; role agents that still read the bible;
  semantic search for rules (§4).
- **Consequences.** Amends the bible's "read every chunk" and "never summarize" rules (active layer only). New phases
  carry context manifests in sub-specs. `genesis-docs` owns the write-back; `genesis-ctx lint` guards budgets and
  coverage. No Genesis code or runtime change.

## 7. Key sources

- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://arxiv.org/abs/2607.17598
- https://kiro.dev/docs/custom-agents/configuration-reference/ · https://kiro.dev/docs/cli/v3/agent-config/ ·
  https://kiro.dev/docs/hooks/types/ · https://kiro.dev/docs/cli/2x-reference/
