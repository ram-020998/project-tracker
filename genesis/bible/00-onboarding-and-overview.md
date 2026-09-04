<!-- GENESIS BIBLE — CHUNK 00. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **Purpose, keep-current rules, the phase/release banner, §0 What Genesis is, §1 How to onboard (read order).**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

# Genesis — Agent Onboarding & Reference ("the bible")

> **Purpose.** This is the single, task-agnostic document that brings any new agent session fully up
> to speed on Genesis: what it is, how it's built, the decisions behind it, what has shipped, the
> operating rules, and how to do work of any kind. Read this end-to-end (and the linked docs/code it
> points to) and you should be able to take on *any* task in the program — a bug fix, a new feature,
> a new phase, a refactor, a release, or a question — without further ramp-up.
>
> **This document does not assign a task.** The task comes from the human in the session. Your job
> after reading is to (1) briefly restate the architecture + current state + the non-negotiables, and
> (2) do whatever work is asked, following §8's loop.
>
> **Keep this current.** When tags, architecture, ADRs, or hard-won lessons change, update §2 (state),
> §5 (ADRs), §7 (lessons), and §9 (roadmap). **Last refreshed: 2026-09-04 — Latest SHIPPED: **genesis v0.60.0 + genesis-workflows v0.15.0 + genesis-core v0.9.6 + kiro-agent-sdk v0.7.1** — **Phase 31 Feature Breakdown stage COMPLETE** — the FOURTH feature stage: once Spec + UX + Technical Design exist, Start (optional notes + up to 3 supporting docs, ADR-035) → the **`feature-breakdown-analysis`** workflow (epics = the Technical Design's functional workstreams → per-epic story/task breakdown [Appian form-vs-process-model split, entry-point splitting, Story=front-end-testable / Task=not-FE-verifiable, **Gherkin** AC, one-line TD-anchored dev notes] → **deterministic assemble** [a Lavish-safe `breakdown.html` — `<details>` cards + a CSS-only table toggle + an embedded canonical `backlog.json`] → **grounded coverage** critic → cleanup) → a **`feature_breakdown`** completion chat + a **Jira-importable CSV export** (create-new-epics via Issue ID → Parent ID); ADR-059; no migration (m0015 reused); genesis + genesis-workflows only; CI green — genesis #6735324 / workflows #6735326. Prior: run-detail workflow-graph revamp (elkjs layered LR + orthogonal routing, executed path GREEN + ×N counts, `/runs/{id}/transitions`) + run-detail perf + honest partial credit provenance + worker terminal-status fix + no-cache index.html; technical-design-analysis v0.2.0 (genesis v0.58.0 / genesis-workflows v0.14.0; CI green — genesis #6727262 / workflows #6727270). Prior: **Phase 30 Technical Design stage COMPLETE** (grounded Spec+UX→Technical Design; ADR-058 + the ADR-056 prerequisite amendment; CI green — genesis #6725001 / workflows #6725004) + clickable stage cards + openable artifacts. Prior: global ⌘K search + run-detail display fixes + single-nav feature workspace + UX **Re-upload & re-run** + StageFinalizer correctness (v0.56.0→v0.56.2) and the UX-level `ux-design-analysis` v0.1.1 (FB-4, workflows v0.12.1), all on top of Phase 29 UX Design stage COMPLETE (grounded mockup→UX Implementation Analysis, ADR-057; CI green — core #6680648 / genesis #6680663 / workflows #6680673). Prior: Phase 28 Feature Workspace framework (v0.54.0, ADR-056). Prior: genesis v0.53.0 (Phase 27) +
> genesis-workflows v0.10.0 +
> genesis-core v0.9.5 + kiro-agent-sdk v0.7.0 + genesis-appian-parser v0.2.0** (genesis v0.50.0 + core v0.9.5 =
> the Phase-25 Architectural Foundation Hardening release (v0.49.0 + v0.50.0) — Phase 25 COMPLETE; 25-11 + 25-12 backlog — see §9) (Phases 9 Agent-Artifact-I/O,
> 10 Chat-assistant, 11 Credit-tracking, 12 Appian Code-Review Workflow, 13 Chat Copilot & Run Orchestrator,
> 14 Skills in Chat all shipped). **Phase 15 — Design-Document Workflow — COMPLETE (15-01..15-05 shipped):**
> a new **`design-doc`** workflow ports the Jarvis design-doc process into a deterministic Genesis graph —
> a JIRA ticket → an Appian **design document (Markdown)** via **dual-source research** (live **Jarvis** +
> release-aware **Atlas**), reconciled into one release-aware plan; conditional branches (KB-freshness gate,
> mockup→i18n, open-questions) and one gated mutation (empty-package creation, `pre_mutation`). Plus a genesis
> platform capability: **run-launch file attachments** (`format:"file"` inputs → `POST /api/runs/upload` →
> blackboard provisioning; **ADR-035**). genesis-workflows **v0.7.0** + genesis **v0.27.0** (core + sdk
> unchanged). Only remaining item is manual live-acceptance vs. real kiro-cli (can't be driven headlessly).
> **ACTIVE EFFORT — Phase 16 (Appian Knowledge Base / "Atlas-into-Genesis") is IN PROGRESS (planning complete + pushed;
> implementation under way).** Bring the Appian KB *inside* Genesis: a Genesis-native parser + a code-free temporal
> KB in `genesis.db` + an Applications page + a sync workflow + a read-only `genesis-kb` MCP, with all *environment*
> calls routed through the managed native **Dev MCP / DevOps MCP** (Atlas & Jarvis retired as services). Full spec set
> in `specs/phase-16-appian-knowledge-base.md` (+ `phase-16-appian-knowledge-base/16-01..16-08` +
> `genesis-kb-tool-contracts.md`); **ADR-036/037/038** (Accepted — implemented across 16-02/03/04/08). **Shipped so far: 16-01** = `genesis-appian-parser`
> **v0.1.0** (new repo, CI green); **16-02** = genesis **v0.28.0** (m0007 `kb_*` + `KbStore`); **16-03** = the
> **`sync-application`** workflow (genesis **v0.29.1** + genesis-workflows **v0.8.2**); **16-08 COMPLETE** — the
> dev-environment `is_dev` toggle (§2.0, genesis **v0.30.0**) + the **managed-native Dev/DevOps MCP installer** (Stage B:
> genesis-core **v0.9.1** + genesis **v0.31.1** + genesis-workflows **v0.8.4**); **16-04 Applications surface** shipped
> (genesis **v0.32.0**); **16-05** = the **`genesis-kb` MCP server + CHAT cutover** (genesis **v0.33.0**; chat now runs on
> the internal KB, `appian-atlas` dropped from chat). **Next = 16-05b** (cut `erd-generation`/`design-doc` off
> `appian-atlas` — deferred until Section-C schema + 16-06 versioning; `appian-atlas` retained meanwhile) **+ 16-07**.
> A new session should **read §9's Phase-16 block first**, then implement in the build order. **Newest work: Phase 18 —
> Appian Parser Accuracy Overhaul — ✅ SHIPPED + live-validated (18-01..18-06): `genesis-appian-parser` v0.2.0 → genesis
> v0.40.0 → genesis-workflows v0.9.2, all CI green. Orphans 804 → 0, edge recall 0.32 → 0.98, precision 0.999, + APPREF/
> ENTRYPOINT cross-app integration points. See §9's Phase-18 block.**
> **⭐ SHIPPED — Phase 19 — Genesis Document Library — COMPLETE (19-01..19-08): genesis-core v0.9.2 + genesis v0.44.0 +
> genesis-workflows v0.9.3, all CI green.** Attach/parse/sync business documents (Google Drive + uploads) as a GLOBAL dedup'd
> store linked into apps (ADR-041), reached via a managed-native `gws` CLI connector (ADR-040, isolated config + read-only
> OAuth, client read from the dotfiles `~/.config/gws/client_secret.json`, no shipped token). Parsing = pypdf/python-docx/
> openpyxl (pinned) → canonical Markdown + per-tab JSON; `sync-documents` workflow; `genesis-kb` doc tools + evidence-pack
> integration; web Document Library page + full-screen viewer + per-app Business Artifacts tab + Settings→CLI connector card.
> ADR-040/041 Accepted. See §9's Phase-19 block + `progress/phase-19-document-library.md`.**
> **⭐ SHIPPED — Phase 20 — Features & Spec Authoring — COMPLETE (20-01..20-06): genesis v0.45.0, CI green; ADR-042/043
> Accepted.** An Appian application gains first-class **Features** (m0010 `kb_features`/`kb_feature_specs`/
> `kb_feature_spec_revisions`) and, inside a feature, a conversationally-authored, annotatable **Spec**. Spec authoring is a
> reused **Chat** in a new additive **`feature_spec`** mode (no LangGraph — ADR-001 intact): `genesis-kb` auto-wired, the agent
> authors **HTML** (`spec.html`) into its per-session fs sandbox (cwd=sandbox + trusted `fs_read`/`fs_write`), **Add context**
> drops the app's linked business artifacts as `./context/` files the agent reads on demand, and the HTML is reviewed in an
> **embedded, annotatable iframe** (the **vendored MIT Lavish SDK**, Genesis-themed) whose highlight-and-comment flows back into
> the chat (postMessage bridge). Status draft→in-progress→in-review→completed + milestone snapshots + Markdown export
> (`markdownify`). genesis-core/genesis-workflows unchanged. See §9's Phase-20 block + `progress/phase-20-features-and-spec-authoring.md`.**
> **⭐ SHIPPED — Phase 21 — Feature Workspace, Spec-Builder UX & Chat Parity — COMPLETE (21-01..21-07): genesis v0.46.0 +
> genesis-core v0.9.3 + kiro-agent-sdk v0.7.0, CI green; ADR-044/045 Accepted (045 refines ADR-031).** A Phase-20
> live-feedback pass. **(A)** the feature page is now an **artifact pipeline** (Spec card **Edit**→builder / **View**→read-only
> preview; Design/Breakdown disabled placeholders; the feature card drops the spec's status). **(B)** the spec builder is a
> **full-width chat** (`ChatThread chrome="spec"`, no copilot banner) + an on-demand **full-screen annotatable Preview** popup
> (our own comment-queue rail + one Send-all); **`feature_spec` sessions are hidden from the main Chat list**. **(C)** the reused
> chat reaches **Kiro CLI/ACP parity** in BOTH places (shared `Composer`): **model @ creation** (m0011 `chat_sessions.model`),
> **slash commands + client-side autocomplete**, a **context-usage + compaction meter**, **clear/compact**, **image attach**,
> plus **Markdown transcript export**. Needs **kiro-agent-sdk v0.7.0** ACP extensions (`session/set_model`,
> `_kiro.dev/commands/*`, compaction/clear status, images — additive; verified vs kiro-cli 2.16.2). ADR-045 keeps write-capable
> actions **human-confirmed** (Phase-13 bridge). See §9's Phase-21 block + `progress/phase-21-feature-workspace-and-chat-parity.md`.**
> **⭐ SHIPPED — Phase 22 — Distribution & Browser-Based Shipping (clone + git-tag) — COMPLETE (22-01..22-07): genesis
> v0.47.0, CI green (genesis + frontend + the new clean-install); ADR-046.** A **standard, working way to ship Genesis to
> internal users** as a **local, browser-based** app (no Mac `.app`, no Docker, no hosting), modeled on `appian/prod/friday`'s
> clone + git-tag self-update. Clone `genesis` (one clone — deps resolve via their `git+ssh` tag pins) → `scripts/install.sh`
> (prereq + **SSH-access preflight** → venv → `pip install .` → `db upgrade`) → **`genesis up`** (backgrounds serve + opens the
> browser). In-app **one-click updates** from release tags (UpdateBanner + `runtime/updater.py` + `genesis update`), **in-app
> Kiro sign-in** (`runtime/kiro_auth.py` + Settings), a **first-run preflight** checklist, and a **`clean-install` CI job**.
> New surface: `scripts/install.sh`, `runtime/{launcher,updater,kiro_auth,preflight}.py`, `api/system.py`,
> `web/features/system` + `genesis up/down/status/logs/update`. genesis-only, no schema. See §9's Phase-22 block +
> `progress/phase-22-distribution-and-shipping.md`.**
> **⭐ SHIPPED — Phase 23 — Scheduled & Full-Package Syncs — COMPLETE (23-01..23-03): genesis v0.48.0, CI green (#6588951:
> genesis + frontend + clean-install); ADR-047; adds m0012.** Keep the local Appian KB + Document Library fresh
> **automatically**. **(1)** the app sync is **re-runnable as a full-package refresh** — `api/applications.py` unblocks
> `sync-application` **`mode=delta`** (a full re-export → parse → diff the DB → write only the changes; **not** an env
> delta-patch) with auto-pick baseline↔delta + a per-app already-running **409** guard + a web **Refresh** action. **(2)** a
> backend **scheduler** (`runtime/scheduler.py` 60s tick + pure `due_slot`; `runtime/schedule_store.py` over **m0012
> `scheduled_jobs`**; `runtime/sync_jobs.py`) runs **`application-sync`** (all tracked apps, 07:00 IST weekdays, **serialized**
> — Appian export is one-at-a-time/409) + **`document-library-sync`** (`scope=library`, 08/12/16/20 IST weekdays), TZ/weekday/
> daytime-aware + restart-safe, preflight-skips (no dev env / no gws); read-only `GET /api/system/schedules`. Backend-fixed now,
> user-configurable later. See §9's Phase-23 block + `progress/phase-23-scheduled-and-full-package-syncs.md`.**

---

## 0. What Genesis is (one paragraph)

Genesis is a **local, single-user web application** that lets a Solutions engineer discover, install,
run, and supervise **workflows**. A workflow is a **LangGraph** graph whose nodes are deterministic
**program** steps or narrow **agent** steps that drive **Kiro** via `kiro-agent-sdk` over ACP,
injecting only the MCP server(s) that step needs. LangGraph owns control flow + durable state; a
per-run artifacts folder (the **blackboard**) holds bulk data; workflows are pulled from the shared
`genesis-workflows` GitLab repo via selective install + a lockfile. Every agent step is wrapped by a
program **validator + retry/escalation** (hard requirement). Genesis replaces the retired
solutions-copilot, which failed by using an LLM as the orchestrator. Backend = **FastAPI embedding
LangGraph as a library** + disposable **subprocess workers**; frontend = **React + TypeScript SPA**
served by the same backend. It runs on localhost with the user's own credentials. The destination is
"enterprise-grade polish" but **still local single-user** — multi-user/hosted is an explicitly separate
future track (ADR-026); **do not build auth/multi-tenancy unless asked.**

Since Phase 14 there is a **second first-class capability beside workflows: Skills** (ADR-034) — Kiro's
portable `SKILL.md` instruction packages for **standalone activities** (draft a document, apply a body of
knowledge like GAM) that the Kiro agent performs in **Chat**, with **no stages/orchestration**. A *Workflow*
= staged/orchestrated, owned by LangGraph; a *Skill* = a single standalone activity, owned by the Kiro agent.
Skills are filesystem-provisioned into a managed Kiro workspace (`~/.genesis/.kiro/skills/`) and invoked from
the Chat `/` palette (or auto-activated by description).

---

## 1. How to onboard (read order — don't skip)

**A) Design + as-built docs — `/Users/ramaswamy.u/repo/project-tracker/genesis/`**
1. `README.md` — one-screen orientation.
2. `tracker.md` — the master record. **Read §6 STATUS LOG top-down** (it is the running history and
   the source of truth for "what is done"); §2 has the locked decisions Q1–Q14; §3 is the phase index.
3. `specs/00-architecture-overview.md` — layers, domain model, node taxonomy, state/blackboard rule.
4. `reference/decision-log.md` — **ADR-001…034** (the "why"). Every non-negotiable lives here.
   (Recent: ADR-031 Chat is read-only; ADR-032 credits are REAL metered data; ADR-033 **Accepted** —
   the Chat copilot may operate runs at the run-management layer, human-confirmed (Phase 13, shipped);
   ADR-034 **Accepted** — Skills as first-class standalone activities, chat-invoked + filesystem-provisioned
   (Phase 14, shipped).)
5. `reference/coding-standards.md` — enforcement-anchored standards. §1 is the hard floor (lints/
   typecheck/CI gates that fail the build); §2–§6 are Python/frontend/testing conventions + the
   Definition of Done. When it conflicts with an ADR, the ADR wins; if a task needs a deviation, flag it.
6. `reference/` (the rest): repo-structure, node-taxonomy-reference, state-and-data-model,
   mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
   security-and-secrets, testing-strategy, langgraph-capability-map, solutions-copilot-relationship,
   glossary, roadmap-and-sequencing, spike-findings.
7. `specs/` — the plan for each phase. Phases 1–6, the web-revamp (`phase-07-0N-*`), the
   `phase-07-code-review-fixes/` program (01–06), `phase-08-settings-revamp.md`, **`phase-09-agent-artifact-io.md`,
   `phase-10-chat-assistant.md` (+ `phase-10-.../10-01..07`), `phase-11-credit-usage-tracking.md`,
   `phase-12-code-review-workflow.md`, `phase-13-copilot-orchestrator.md` (+ `phase-13-.../13-01..06`),
   `phase-14-skills-in-chat.md` (+ `phase-14-skills-in-chat/14-01..14-05`)**, and **`phase-15-design-doc-workflow.md`
   (15-01..15-05)** are all **shipped**. **`phase-16-appian-knowledge-base.md` (+ `phase-16-appian-knowledge-base/
   16-01..16-08` + `genesis-kb-tool-contracts.md`) is the ACTIVE effort — specs pushed; **16-01/16-02/16-03/16-04/16-08
   shipped, 16-05 next** — read it (and §9's Phase-16 block) before touching this area.** `specs/backlog/` holds
   deferred work (the skill-migration program + `phase-15-followup-fixes.md`).
8. `progress/` — the as-built record, one file per phase/item (`phase-01..16-*`; newest:
   `phase-16-04-applications-surface.md`, `phase-16-08-native-mcp.md`). Read the one(s)
   relevant to the area you're touching; they cite commits, tags, CI pipelines, and decisions.
9. `spike/` — time-boxed feasibility probes (throwaway code, durable findings). Read the relevant one before
   building on its area (e.g. `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` proves Kiro Skills over ACP for
   Phase 14).

**B) The code — `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`** (read before editing; §4 is the map)
- `genesis-core/genesis_core/**` — shared engine/SDK (nodes, state, registries, validators).
- `genesis/genesis/**` — the platform (runtime, dist, config, runs, api, cli, lint, db).
- `genesis/web/**` — the React+TS workbench (the shipped app; `web/static/` is the served bundle).
- `genesis-workflows/**` — the library (registries, steering, workflows, CI publish gate).
- `kiro-agent-sdk/src/kiro_agent_sdk/**` — the ACP adapter (read `client.py` + `__init__.py`).
- `genesis-appian-parser/genesis_appian_parser/**` — the NEW (Phase 16) Appian package parser: `api.parse()` +
  `result.py` (`KbParseResult`); the ported front-half in `parsers/`, `resolution/`, `dependencies/`, `domain/`,
  `output/` (bundle builders). Consumed by `genesis/kb`.
- tests: `genesis/tests/**`, `genesis-core/tests/**`, `genesis-workflows/workflows/*/tests/**`.

**After reading, be able to restate:** the layered architecture, the reliability trio, the
state/blackboard rule, the subprocess-worker execution model, the data plane (SQLite + migrations),
and the release/versioning protocol.

---

