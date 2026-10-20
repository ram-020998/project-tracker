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
| `reference/decision-log.md` | 210,323 (count corrected 2026-10-20, §5.5: 74 `## ADR-` headings = 72 primary + 2 amendment headings (`ADR-026 amendment`, `ADR-038/040 amendment`); + 2 `###` primary ADRs (028, 029); + 2 bullet-form ADRs (053, 054); + 2 more amendment/addendum headings (`### ADR-027 addendum`, `## Amendment … (amends ADR-061/063/064)`) — 76 distinct ids, ADR-001..076, every one with decision-log text) |
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

### 5.5 Round 4 — anchor rules (2026-10-20, during 47-02/03 build)

Checking the real files' structure (grep/ranged reads of headings, fences and bold leads — no whole-file reads) showed
that the 47-02 §4.1/§4.3 anchor rules did not fit. Found, and decided with the user:

1. **decision-log.md.** ADR-028/029 are `###` headings under `## ADR-027` (with a `### ADR-027 addendum`);
   amendments are their own headings (`## ADR-026 amendment`, `## ADR-038/040 amendment`,
   `## Amendment (…) (amends ADR-061/063/064)`); ADR-053/054 are **column-0 bullets** (`- **ADR-053 (ACCEPTED …`)
   inside the `## ADR-051` section — the only bullet-form entries. **Rule:** anchors are `##`/`###` headings and
   column-0 bullets whose bold lead starts with an ADR id; each runs to the next anchor (so ADR-051 stops before the
   ADR-053 bullet). An anchor names the ids its text starts with (slash continuations included) or, failing that, its
   `amends ADR-…` list. Amendment/addendum anchors load with every ADR they name. No anchor → `bible/04` only, lint
   warns (no current case). Count in §2.1 corrected.
2. **bible/04 bold leads.** Id lists are expanded: `ADR-002/004/020`, `ADR-006–009` ranges, `(+ ADR-029)`,
   `+ ADR-063`.
3. **bible/03.** The first fence holds the base map *and* three `# ──` blocks; Phases 45/46 use a bold line
   (`**Phase 45 — …:**`) + fence instead of `# ──`; `genesis-core/  state.py` appears twice. **Rule:** the base map
   ends at the first `# ──`; bold-only lines start sections keyed by their text; `# ──` / bold sections end at the next
   one or at `---`; duplicate keys get ` #2`.
4. **Gap-fills:** optional `gates = [...]` per area (printed by `check`); a plain `index` only fills empty
   fingerprints, `index --reviewed <ids…>` / `--reviewed-all` refreshes them (so `index` never silences a drift
   finding); the `[[step]]` archive-plan schema lives in 47-03 §3.1 (the tool validates it; the plan itself is 47-04).

Rules recorded in 47-02 §3/§4.1/§4.3 and 47-03 §3/§3.1/§5/§7. D7 holds — neither file is edited.

### 5.6 Round 5 — tag review, closure rule, budgets (2026-10-20, S4 / 47-05)

The review table showed that 14 of 20 area packs were over 40K. The main cause was the amendment closure: it ran the
whole chain in both directions, from every ADR on the always-on areas. For example, ADR-026 → 063 → 065/074 → 047
pulled collaboration and sync ADRs into every pack. Decided with the user:

1. **Closure rule (pack + check).** From the seeds (ADRs selected by areas, path globs or the manifest):
   - follow `amended_by` / `superseded_by` **transitively**, i.e. everything that changes a loaded rule;
   - follow `amends` **one hop, from seeds only**, never from ADRs the chain added.
   
   `genesis-ctx adr <id>` keeps the full chain. Tests: 031 → 033/034/045 still load; 026 no longer pulls 047.
2. **Always-on areas** (`security`, `release-ci`) carry only ADR-011 and ADR-026, plus their lessons.
   ADR-019/029/031/045/046 stay on their real areas.
3. **No blanket trim.** Tags stay recall-first. A tag is removed only when the ADR provably constrains no file in
   that area's globs. ADR-001/010/012/021/068/073 never leave workflows-library / core-engine / runs-worker, and
   ADR-020/029/031/033/034/037 never leave chat.
4. **No area split** for now (features-stages stays one area).
5. **Budgets:** pack warn **60K**, fail **120K** (was 40K / 80K): umbrella §6.1 L2 row and §13 Q2, 47-03 §4,
   `config.py`. The 47-09 §4 pass bar stays "≤ 10 % after the pack".
6. **One-liners:** the critical-ADR rules were approved, with rewrites for ADR-068 (never delete an object; no
   `delete*` tool allowlisted), ADR-021 (references ADR-068) and ADR-017. Low-confidence items were approved as
   proposed.

### 5.7 Round 6 — context bars measure the Genesis share (2026-10-20, before the 47-09 review)

The 47-06 live check measured genesis-dev at 5.51 % at start, against 3.87 % for a plain `kiro-cli --v3` session
with the same prompt. The ≈ 3.9 % baseline is Kiro's own system prompt and built-in tools, which Genesis does not
control. Decided by the user:

1. **Gate on the Genesis share** = session total − a plain `kiro-cli --v3` session with the same prompt.
   Bars: **≤ 5 % at start, ≤ 10 % after the pack**.
2. **Session totals** are recorded for information only, never gated.
3. Applied to 47-06 §9 and 47-09 §4.

### 5.8 Round 7 — the 47-09 review fix round (2026-10-20, after reviews/47-09-review.md: NEEDS_CHANGES)

The independent review (`specs/phase-47-agent-context-system/reviews/47-09-review.md`) passed §2 (golden 97.5 %,
critical 100 %), 47-08 §6 and §4-before-pack, but failed §1 (1 blocker, 1 major on permissions), §3 (recall 91.7 %)
and §4-after-pack (14–20 % vs 10 %). Decided with the user and implemented as one commit per item (local only, no push):

1. **Permissions (B1 + M1).** New `agent-system/hooks/shell-guard.sh`, a `PreToolUse` hook on `shell` for all five
   agents (rendered per agent with its write roots). It exits 2 — even under `--trust-all-tools` — on (a) a `git
   push`/`tag` subcommand in any form (absolute path `/usr/bin/git`, `env`/`command`/`exec`/`VAR=` prefix, `-C`,
   `&&`/`;`/`|` chain, `sh -c "…"`), except for `genesis-release` (`--allow-push-tag`); (b) a shell write (`>`, `>>`,
   `2>`, `&>`, `tee`, `cp`, `mv`, `rm`, `sed -i`, `dd of=`) whose target resolves outside the agent's write roots.
   The broad read-command shell allows (`cat *`, `grep *`, `ls *`, `rg *`, `find *`) are removed from every profile
   (reads go through the `read`/`grep`/`code` tools) and `node *` is `ask`. The installer rejects re-adding a bare
   `<write-cmd> *` shell allow. `OPERATOR_GUIDE.md` golden rule 7 + troubleshooting: never `--trust-all-tools`. Tests
   cover every §1 bypass (`/usr/bin/git … push`, `env git … push`, `cat x > path`); 47-06 §3/§8 record the hook.
2. **Tags (M2).** `ADR-001` += `features-stages`, `ADR-064` += `features-stages`, `ADR-036` += `collaboration-hub`
   (`reviewed_fp` unchanged — the decision-log text did not change). `recall_replay.py` → 84/84 = 100 %. The ADR-019 →
   `release-ci` finding is **rejected** (the standing decision: only ADR-011 and ADR-026 sit on the always-on areas,
   §5.6).
3. **Pack tiers (M3).** The token estimator is calibrated to ≈ chars ÷ 2.5 (was chars ÷ 4, which under-counted packs
   ~1.6× so the verdict lied); L0/state caps rescaled 15K→24K / 4K→6.4K to keep their headroom; pack warn/fail stay
   60K/120K and are now truthful. `pack` renders **full text only for direct hits** — the manifest's `adrs`/`lessons`,
   path-glob hits and their amendment chains; everything an area adds becomes a one-line *Also applies — load with
   `genesis-ctx adr|lesson <id>`* pointer (one-hop disclosure). `check` keeps the full area-wide checklist. The
   `genesis-spec-authoring` skill now requires manifests to list applicable ADR/lesson ids explicitly (from
   `genesis-ctx area <a>`). 47-02 §5/§6, 47-03 §4, 47-09 §3/§4 and the umbrella updated: recall = cited ⊆ full ∪
   listed = 100 %, full-text recall reported separately. The §4 replay packs drop from ~123K/139K/181K to
   ~26K/36K/39K real tokens.
4. **Minors.** A wildcard-free `code`/path entry that is a directory routes as `<dir>/**` (`areas_for_code`,
   `globs_touch`, `check`; lint warns; M4). `check` scans project-tracker too (emits `tracker:` paths) and exits 2 when
   `--since` resolves in no repo (m2/m3). Strict `verify-lossless` is the default — the present side counts only the
   active layer ∪ `archive/`, never specs/progress/fixtures (m1). L-030 gets a `tags/lesson.toml` rule and the
   bold-lead parser ignores `**` inside backticks, so its digest line is no longer truncated (m4). `golden.toml` +
   `golden_grade.py` moved to `context/eval/` (4e).
5. **Golden/docs-dry-run items.** Fixed (prompt issue): the `genesis-doc-writeback` skill now tells the agent to run
   `genesis-ctx` **unpiped** and use the `read`/`grep` tools, not shell pipes (m8). **Listed for the user, no change:**
   golden Q31 (release-ci, not critical) — the answer cites L-056 and is correct in substance; it fails only the
   narrow phrase match, so the expected set is unchanged; m9 (optional eval idea: add golden questions whose key phrase
   is only in the full rule text, not the L0 digest); and the dry run's proposed area additions to ADR-075/076 go
   beyond the 47-08 routing table — confirm them in a real docs run before they land.

### 5.9 Round 8 — the 47-09 round-2 fix round (2026-10-20, after the round-2 re-review: NEEDS_CHANGES, M5)

The re-review (round-2 section of `reviews/47-09-review.md`, fix set `d389aae..1fb3042`) confirmed B1, M1–M4 and Q31
fixed and §2/§3/§4 passing. It raised one new major, **M5**: the B1/M1 shell-guard over-blocked ordinary idioms. m9 (the
batched retrieval was denied), m6 and m7 were still open. Decided with the user; one local commit per item, no push:

1. **M5 — quote-aware shell-guard** (`c8c5d9e`). The guard's Python now lexes the command like a shell (quotes,
   escapes, comments, heredocs, `$(…)`/backtick/`<(…)` bodies, subshells) instead of regexing raw text. A `>` inside
   quotes is not a redirect. `2>&1`, `>&2`, `N>&M` and `N>&-` are fd dups, not writes. `/dev/null`, `/dev/stdout`,
   `/dev/stderr`, `/dev/tty` and `/dev/fd/N` are allowed redirect/`tee`/`cp`/`dd` targets. Variables assigned earlier
   in the line and `for` loop values are resolved, and an unresolvable write target now **fails closed** (round 1
   could treat it as a relative path and allow it). Push/tag detection is hardened too: `$G`, `if`/`while`,
   `timeout`/`sudo -u`/`env -i`, `eval`, a heredoc fed to a shell, `git -c alias.…`.
   - Tests: the 4 review false positives are regression tests, with 55 more cases; all 34 round-1 cases are unchanged
     (94 guard tests in total).
   - The review's probe table is 38/38 (33 original probes plus 5 false-positive probes).
   - A replay of all 196 distinct shell commands Genesis agents ran in recorded sessions: 0 newly blocked, 22 old
     false denials now pass.
2. **m9 — retrieval form** (`a22026b`). The denied batch was genesis-dev's
   `G=…/genesis-ctx; for a in 021 032 035 050; do echo "=== ADR-$a"; $G adr ADR-$a; done` (and the same for 061…076).
   A loop/`;` cannot match the `{{GENESIS_HOME}}/bin/genesis-ctx *` allow rule, so non-interactive mode denied it.
   The allow rules and shell-guard were **not** loosened. Instead, the standard form is now one direct call with many
   ids, `<abs>/genesis-ctx adr ADR-021 ADR-032 …` (`adr`/`lesson` already take `nargs=+`), with no loop, pipe, `;`,
   `&&`, `$(…)`, redirect or `VAR=` prefix. That rule is in L0-core §3 and in all five role prompts (genesis-dev's
   prompt was trimmed by two lines L0 already states, so it stays ≤ 1.2K tokens). A test renders every profile and
   checks that the documented `adr` and `lesson` forms match an allow rule, match no ask/deny rule, and pass the
   profile's shell-guard.
   **Live re-run after `update.sh`:** the review's exact Q41–Q50 batch (one fresh genesis-dev session,
   `--no-interactive`, no trust-all) went from 0/10 to **10/10** (`grade5.py`). The agent's first call was
   `…/genesis-ctx adr ADR-021 ADR-032 ADR-035 ADR-050 ADR-061 ADR-062 ADR-073 ADR-033 ADR-052 ADR-076`, which
   completed. It also attempted a `grep … | grep … | cut` over the saved output, which was denied as expected (a pipe),
   and it recovered with single-id `genesis-ctx adr` calls. Evidence: `/tmp/genesis-dev/batch5-r2.{txt,err}`.
3. **m6** (`8af14c7`). genesis-dev `trustedAgents = ["genesis-review"]` (matches 47-06 §4; pinned by a test).
   genesis-review's `/tmp/**` write is kept as the review left it, and so is genesis-spec's missing explicit
   code-repo push deny (shell-guard refuses it anyway). Both are recorded as deviations in the 47-06 As-built.
4. **m7** (`772405f`). The installed `stop-lint.sh` → full `genesis-ctx lint` on this tracker (≈ 500 `.md`) measured
   0.18 s warm, 0.38 s cold and 0.78 s cold under load, so a 2× margin is ≈ 1.6 s. The CLI default (10 s) already
   covered that, so no raise was needed. It is now set explicitly (`"timeout": 10`) on both Stop hooks, with a test
   keeping it ≥ 10 s. The shared `nosid` fallback counter (the other half of round-1 m7) was not in this round's
   brief and is unchanged.

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
