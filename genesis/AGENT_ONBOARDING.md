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
> §5 (ADRs), §7 (lessons), and §9 (roadmap). **Last refreshed: 2026-08-12 — latest SHIPPED: genesis v0.46.0 +
> genesis-workflows v0.9.3 + genesis-core v0.9.3 + kiro-agent-sdk v0.7.0 + genesis-appian-parser v0.2.0** (Phases 9 Agent-Artifact-I/O,
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

## 2. Current state (as of genesis v0.46.0)

**Five repos** at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, all pushed to
`git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git` (the 5th, `genesis-appian-parser`, is new in Phase 16):

| Repo | Tag | Branch | Role |
|---|---|---|---|
| `kiro-agent-sdk` | **v0.7.0** | main | ACP adapter; `collect`/`collect_streaming`; `permission_mode`(`auto_approve`/`auto_deny`/**`ask`**)+`allow_fs_write`; **per-turn credit metering (11-01)**; **interactive permission bridge `permission_mode="ask"`+`on_permission` callback (13-01)**; **`fs_write_root` sandbox for agent file writes (14-05)**; **ACP extensions (Phase 21-04): `SystemInit` exposes models/modes/commands (from `session/new` + `_kiro.dev/commands/available`); `set_model`/`set_mode`; `execute_command` (via a shared `_turn`); `prompt(images)` gated on `promptCapabilities.image`; `on_commands`/`on_session_status` callbacks** |
| `genesis-core` | **v0.9.3** | master | nodes/state/registries/validators; two-tier MCP/CLI registry + introspection (ADR-029); session tool-output store (Phase 9); telemetry carries **metered credits** (Phase 11); `CORE_MAJOR=1`; **`McpRegistry` managed-native `launch_provider` — a `"managed":"<id>"` entry resolves command/args from a local install; introspect 8 MiB stream limit (16-08)**; **`CliRegistry` managed-native launch resolution — the CLI analog, injected `launch_provider` (Phase 19, ADR-040)**; **pins kiro-agent-sdk v0.7.0 (Phase-21 ACP extensions; pin-only bump, `CORE_MAJOR` unchanged)** |
| `genesis` | **v0.46.0** | master | runtime, dist, config, runs, **db (m0001–m0011)**, api (`/api`+SPA), cli, web SPA; **Chat** (Phase 10); **credit tracking** (Phase 11); worker loop `recursion_limit` (12-01); **Copilot (Phase 13-01..06)**; **Skills (Phase 14-01..05)**; **run-launch file attachments (ADR-035, Phase 15-01)**; **internalized Appian KB: m0007 `kb_*` + `genesis/kb/KbStore` (16-02)**; **read-only `genesis-kb` MCP server (`genesis/mcp/kb_server.py`) + chat cutover off `appian-atlas` (16-05); `KbStore` UUID-dedupe (16-07); native-MCP bundle controls moved into the MCP detail page + Applications UI polish + `scripts/genesisctl.sh` (v0.34.0)**; **Phase-17 Business Map backend: m0008 `kb_business_maps` + `KbStore.build_evidence_pack` (code-free KB→business evidence pack) + Business Map API (v0.35.0) + Business Map web view (React Flow A value-stream + B capability-constellation, first tab, 17-05, v0.36.0) + readability + click-for-detail popups + radial capability constellation + smoothstep edges (v0.37.0/v0.38.0)**; **pins `genesis-appian-parser`; `build_context` injects `ctx.extras['kb_store']`; checkpointer WAL+busy_timeout (16-03)**; **dev-environment `is_dev` toggle + `dev_environment()` (16-08 §2.0)**; **managed-native MCP installer `genesis/mcp/native/` + `api/native_mcp.py` + `genesis mcp` CLI + Settings→MCP panel (16-08 Stage B)**; **Applications surface: `api/applications.py` + `kb/dev_mcp.py` (Dev-MCP `listApplications`) + `web/features/applications` (16-04)**; **Document Library (Phase 19, ADR-040/041, v0.44.0): m0009 (`kb_documents`/`_links`/`_sections`) + `DocumentStore` + `kb/doc_parsing` (pypdf/python-docx/openpyxl, pinned) + `DocumentSyncEngine` + managed-native `gws` connector (`integrations/gws/`, `cli_tools/native/`, `api/native_cli.py`) + `api/documents.py` + `genesis-kb` doc tools + `build_evidence_pack` docs + `web/features/library` (Document Library page + full-screen viewer + per-app Business Artifacts tab + Settings→CLI connector card)**; **Features & Spec authoring (Phase 20, ADR-042/043, v0.45.0): m0010 (`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`) + `FeatureStore` + `api/features.py` (feature CRUD + spec create/context/milestone/status + artifact/sdk.js/export.md) + Chat `feature_spec` mode + vendored MIT Lavish annotation SDK (`api/assets/lavish/`, Genesis-themed) + `markdownify` HTML→MD + `web/features/features` (Features tab + feature page + `SpecWorkspace`)**; **Feature Workspace, Spec-Builder UX & Chat Parity (Phase 21, ADR-044/045, v0.46.0): the feature page is an artifact **pipeline** (`web/features/features/ArtifactPipeline` — Spec Edit/View + Design/Breakdown placeholders; `artifact?annotate=0` read-only preview; builder split to `…/features/:id/spec`); spec builder = full-width `ChatThread` (`chrome="spec"`) + full-screen annotatable Preview (our comment-queue + Send-all); `feature_spec` excluded from the main chat list; **Kiro CLI/ACP parity** (m0011 `chat_sessions.model`; `ChatManager` model-at-creation + `ensure_agent_catalog` + slash-`execute_command` routing + clear/compact + images; `api/chat` `/chat/{models,commands}` + `…/{model,clear,compact}` + `SendMessage.images`; `Composer` parity toolbar + Commands palette + context meter) both places; `chat/export.py` + `…/export.md` Markdown transcript** |
| `genesis-workflows` | **v0.9.3** | master | registries (incl. `jarvis`+`jira`+`appian-atlas` + **`appian-dev`/`appian-devops`** now **managed-native refs** with read/export-only allowlists set from the real installed `tools/list` — 16-08 Stage B; **+ `gws` managed-native read-only CLI entry, Phase 19**), steering, `hello-appian` + `erd-generation` + `code-review` + `design-doc` + **`sync-application` (Appian KB baseline sync via Deployment REST → parser → KbStore, Phase 16-03)** + **`generate-business-map` (Phase-17 agent-synthesized Business Map from the code-free KB, v0.9.0)** + **`sync-documents` (Phase-19 Google-Drive→Document-Library pull/parse/store via the read-only gws connector, program-only)**; `skills/` library + `skills-registry.json` + `ci/validate_skills.py` gate; seed `gam` skill (Phase 14-02) |
| `genesis-appian-parser` | **v0.2.0** | main | **NEW (Phase 16-01).** Genesis-owned, stdlib-only Appian package parser (port of the Atlas front-half). `parse(zip\|bytes) -> KbParseResult` (objects + edges + bundles + **code-free** metadata; no files, no SAIL). Consumed by `genesis/kb` + the sync workflow; pinned into genesis by tag (**v0.2.0**, 16-03/18-06). **Phase 18 (v0.2.0): dependency-extraction accuracy overhaul — universal known-UUID + raw-XML reference scan, `is_orphan`=disconnected (not unbundled), CDT-QName + translation/document/record-action + `rulereferencebyname` by-name edges, APPREF/ENTRYPOINT cross-app integration-point classification. Measured edge recall 0.32→0.98, precision 0.999, orphans 804→0 on a real app; ≥95% CI gate; 25 tests.** |

**Dependency chain** (git-pinned by tag; CI rewrites ssh→https):
`genesis → genesis-core@v0.9.3 → kiro-agent-sdk@v0.7.0`;
`genesis-workflows → genesis-core@v0.9.2 (runtime) + genesis@v0.44.0 (dev pin)`. (`code-review` needs genesis ≥ v0.20.2 at runtime for the loop.) both genesis + genesis-core pin the SDK directly (v0.7.0 — Phase-21 ACP extensions on top of the Phase-14 `fs_write_root` sandbox). **genesis-core `v0.9.3`** = the managed-native `launch_provider` for **both** MCP (16-08) and CLI (Phase 19, ADR-040) + the introspect stream-limit fix + the Phase-21 SDK pin (v0.7.0) — all additive, `CORE_MAJOR` still 1. **`genesis-appian-parser@v0.2.0`** is a stdlib-only leaf (no Genesis deps); **genesis pins it by tag (16-03)**, so it installs transitively wherever genesis does (incl. genesis-workflows CI). **Phase-19 doc-parsing deps (pinned in genesis):** `pypdf==6.15.0`, `python-docx==1.2.0`, `openpyxl==3.1.5`.

**Tests, all green at last release (Phase 21, v0.46.0):** genesis **409** pytest (adds Phase-21 **m0011 `chat_sessions.model`** + **chat parity** [model-at-creation, models/commands catalog, slash→`execute_command` routing, clear/compact] + **chat Markdown export** + the feature-landing `annotate=0` + `feature_spec` session-isolation tests, on top of the Features/KB/Business-Map/Documents suites) · genesis-core **65** (incl. managed-native MCP **and** CLI launch resolution) · kiro-agent-sdk
**93** · genesis-appian-parser **25** (vs a real vendored package + a no-SAIL guard + a raw-XML accuracy oracle with a ≥95% gate) · genesis-workflows **75** (incl. 13 code-review + 16 design-doc + 12 sync-application + 11 generate-business-map + **7 sync-documents**) + `ci/validate_skills.py` + `ci/validate_library.py` (7 workflows) · web **150** Vitest
(incl. contract-fixture drift + jest-axe a11y + the Phase-19 library/connector tests). ruff clean (**`ruff==0.15.20` pinned in genesis AND genesis-core — see §7**); eslint clean (0 errors); `tsc` strict clean. CI green on all code
repos (genesis has a python `genesis` job + a `frontend` job with a stale-bundle guard **that runs only on `web/**` changes**; the SDK repo
has no CI — validated transitively by core+genesis installing its tag).

**Milestones (see `roadmap-and-sequencing.md`):**
- **Phases 1–6 — DONE (M1–M6):** engine + node framework + state/checkpointer/blackboard + MCP
  registry + reliability trio; workflow contract + library + scaffolder + CI enforcement; distribution;
  config + secrets + env registry + health; run orchestration + all 3 HITL modes + streaming; ERD.
- **Phase 7 WEB REVAMP + Code-Review Fix Program (01–06) — DONE + shipped.** React+TS workbench;
  persistence/migrations, Overview, Integrations Studio (ADR-029), retention, SQLite decision (ADR-030),
  conversation rich-chat.
- **Phase 8 — Settings & Integrations Revamp — SHIPPED (v0.16.0).**
- **Phase 9 — Agent Artifact I/O — SHIPPED** (sdk v0.2.0, core v0.6.0, genesis v0.17.0, workflows v0.4.0):
  a per-run tool-output store + agent `save_tool_output`/`list_tool_outputs` (save-by-reference) so large
  MCP results land in the blackboard with zero re-emission into the context window.
- **Phase 10 — Chat Assistant — SHIPPED** (sdk v0.3.0, core v0.7.0, genesis v0.19.0; ADR-031;
  m0002 migration): a read-only conversational Chat page — talk to Kiro (Atlas read MCP) + query all
  Genesis state via a read-only introspection MCP server (`genesis/mcp/introspection_server.py`).
  Follow-ups: Atlas read `tool_allowlist` (workflows v0.4.2), CRLF SSE streaming fix (v0.19.1), a UI
  polish batch (v0.19.2: breadcrumbs, list-view, collapsed nav, clickable catalog cards). **(The top bar + breadcrumbs
  were later removed — v0.42.0/v0.43.0 — and the theme toggle moved to Settings → General.)**
- **Phase 11 — Credit & Usage Tracking — SHIPPED** (sdk v0.4.0, core v0.8.0, genesis v0.20.0; ADR-032;
  m0003 migration): REAL metered per-turn Kiro credits surfaced everywhere — per agent node + run-total
  (Run Detail), Overview KPI (**Credits Used** replaced Tool-Calls), per chat message + session total.
  Then **v0.20.1**: chat shows the credit count in place of the "Turn complete" chip + a secrets
  atomic-write crash fix (see §7).
- **Phase 12 — Appian Code-Review Workflow — SHIPPED** (genesis v0.20.2 for 12-01; genesis-workflows
  v0.5.3 for 12-02..12-05): a deterministic port of the Jarvis code-review process (Google-Docs export
  excluded). Entry via JIRA ticket / package URL / object names; per-object review loop (diff-aware →
  `analyze_appian_code` → dynamic checklist → SQL/i18n `query_sql` → RecordType relationships) with a
  code-enforced PRE-WRITE CHECKPOINT validator; agent-proposed / program-confirmed verdict. Read-only
  by construction (per-node `@jarvis`/`@jira` allowlists; no registry cap on jarvis). 12-01 added the
  worker loop `recursion_limit` (from `META.execution.recursion_limit`, default 150). `jarvis`+`jira`
  MCP registered + connected. Live run against a real ticket still pending.
- **Backlog:** `specs/backlog/skill-migration-program.md` (45-skill migration; deferred). **Do not start
  backlog/Phase-N work unless asked.**

**What works today (verified):**
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`. API under **`/api`**, Swagger at
  `/docs`, SPA history fallback (ADR-028).
- **Screens (all live):** Overview (metrics incl. **Credits Used** KPI + trend + active runs + integration
  health); Runs list; Run Detail (React Flow graph + inspector + turn-grouped Kiro conversation + all-3
  HITL + documents drawer + **per-node & run-total credits**); Catalog (browse/detail/launch, clickable
  cards); **Chat** (read-only assistant, persisted sessions, per-message credit footer); **Settings**
  (MCP · CLI · GitLab · Environments · General — General holds Appearance/**theme toggle**, Storage, Copilot);
  **Applications** (KB apps — detail tabs Business Map · Overview · Syncs · Releases · **Business Artifacts** [linked documents, Phase 19] · **Features** [Phase 20/21]); the **feature page** (`/applications/:uuid/features/:featureId`) — a Phase-21 **artifact pipeline** (Spec card Edit/View + Design/Breakdown placeholders); the **spec builder** (`…/features/:id/spec`) — a full-width chat + an on-demand full-screen annotatable Preview; **Documents** (the global **Document Library** — list/search/filter, add via upload or Google-Drive link, link/sync/remove, full-screen viewer at `/documents/:id` — Phase 19). **Chat** (main + the spec builder) has Phase-21 **ACP parity** (model selector, `/` command palette + autocomplete, context-usage meter, clear/compact, image attach, Markdown export). Settings→CLI has the **Google Workspace (`gws`) connector card**. Left nav collapsed by default;
  **no top bar / no breadcrumbs** (removed v0.42.0/v0.43.0).
- **Data plane:** durable SQLite (`~/.genesis/genesis.db`, WAL) via `genesis/db/` migrations
  (m0001 runs+events, m0002 chat, m0003 chat_usage, m0004 copilot [chat_sessions.mode +
  chat_run_links + chat_permissions], m0005 supervision [chat_notifications], m0006 copilot_actions [audit], **m0007 kb [the code-free temporal `kb_*` Appian KB — Phase 16-02]**, m0008 business_map [`kb_business_maps` — Phase 17-01], **m0009 documents [`kb_documents`/`kb_document_links`/`kb_document_sections` — the global Document Library, Phase 19]**, m0010 features [`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions` — per-app Features & Specs, Phase 20], m0011 chat_model [`chat_sessions.model` — per-session LLM, Phase 21]; `current_version=11`); runs + full conversation +
  checkpoints + chat sessions/messages persist across restart; retention available.
- **Credits (Phase 11):** every agent turn (workflow node OR chat message) reports real credits from
  Kiro's `_kiro.dev/metadata.meteringUsage`; aggregated per-run (`eventlog.aggregate_credits` via
  `json_extract` over `agent.result`) and per-session (`chat_messages.usage`). Provenance
  `metered`/`partial`/`unavailable` — the UI shows honest "n/a", never a fabricated number.
- **Integrations Studio (ADR-029):** curated (MR-governed) + custom (`~/.genesis/mcp-custom.json` /
  `cli-custom.json`) tiers; per-node injection. `jarvis` (read-write-deploy) + `jira` registered.
- `hello-appian` runs GREEN end-to-end; `erd-generation` runs into the live Atlas fetch. All 3 HITL
  modes, streaming, worker isolation, checkpoint resume — implemented + tested.
- **Dev:** `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760).
  Design-system gallery at `/dev`.

---

## 3. Architecture (the mental model)

**Layered, agents never orchestrate.** LangGraph owns all control flow (ADR-001). A workflow's graph
is deterministic; agent nodes are narrow Kiro turns.

- **`kiro-agent-sdk`** — the ACP adapter to Kiro (the only thing that talks to the agent runtime).
- **`genesis-core`** — the shared engine/SDK: node factories (program/agent/cli/validator/gate/
  subgraph/reliability), `PlatformState` + reducers, `RunWorkspace` blackboard, the MCP/CLI registries
  (two-tier), the validator toolkit, and the `PlatformContext` injected into every node. `CORE_MAJOR`
  is the compat-gate key (ADR-019).
- **`genesis`** — the platform: async engine + checkpointer, distribution (GitLab pull/install/
  lockfile/loader), config + secrets + environments + health, the run manager + subprocess supervisor,
  the `db/` persistence/migration layer, the FastAPI app (`/api` + SPA), the CLI, the lint gates
  (contract parity + reliability trio), and the React+TS web app.
- **`genesis-workflows`** — the library: `registry.json` catalog, `mcp-registry.json`/`cli-registry.json`,
  bundles, steering docs, the workflows, and the 7-gate CI publish runner.

**The reliability trio (ADR-011, CI-enforced):** every agent node is wrapped by a program **validator**
+ **retry** + **escalation-to-HITL-gate** on exhaustion. Enforced statically by `genesis/lint/reliability.py`.

**State / blackboard rule (ADR-010/018/022):** LangGraph state is small, serializable, and
human-**editable** (pointers + decisions). Bulk data lives in the per-run `RunWorkspace` blackboard
under `$GENESIS_ARTIFACTS_DIR`. Never inline bulk data in state or chat.

**Subprocess-worker execution (ADR-012):** the graph runs in a disposable subprocess worker, not the
app process. Pause = kill worker; resume = fresh worker from the checkpoint. The app process never
imports workflow Python — only the worker does (standalone `importlib` on `graph.py`).

**Data plane (SQLite):** runs, the full agent conversation, and LangGraph checkpoints live in
`~/.genesis/genesis.db` (WAL). Only bulk artifacts are files. Schema is owned by `genesis/db/` — a
`Database` connection factory + a forward-only migration runner (`schema_migrations` table). The
durable `run_events` log is the source of truth for a run's timeline/conversation; the in-memory
`EventBus` is only live fan-out (SSE). Retention can reclaim terminal runs' events + blackboard.

**HITL (all 3 modes, ADR-021/025):** (1) designed approval/escalation/pre_mutation gates via
`interrupt()`; (2) ad-hoc pause/resume anywhere; (3) mid-run state injection + fork (seed a new thread
from a past checkpoint, original untouched).

**Release/versioning (ADR-019):** git+ssh tag pins along `genesis → genesis-core → kiro-agent-sdk`;
`CORE_MAJOR` (currently 1, distinct from pip version) is the hard compat gate the loader enforces
(refuse-to-load on mismatch; additive-only within a major).

---

## 4. Codebase map (where things live)

```
genesis-core/genesis_core/
  types.py        PlatformContext (run_id, workspace, mcp, clis, settings, emit, secrets,
                  environments, checkpointer, extras); ValidationResult; Node(name,fn,kind);
                  CORE_MAJOR=1; CompatError; check_compat; CTX_KEY="genesis_ctx"; ctx_from_config.
  state.py        PlatformState TypedDict + reducers; new_state, record_artifact, record_decision.
  workspace.py    RunWorkspace (per-run blackboard) + Doc + default_artifacts_root.
  validators.py   toolkit: non_empty, parses_json, json_schema, required_keys, values_in_set,
                  count_between, first_field_is, excludes, referential_integrity, all_items_present,
                  matches_predicate, all_of, any_of (`_dig` dotted paths w/ []).
  mcp/registry.py   McpRegistry.acp_servers(names) -> ACP entries {name,command,args,env:[{name,value}]}
                    (env is a LIST — see §7). from_layers(curated,custom) merges the two tiers (ADR-029);
                    allowlist()/servers(). Resolve: SecretProvider → EnvironmentRegistry → os.environ.
  mcp/custom_store.py  CustomMcpStore: JSON-file CRUD + tool allowlist + validation (custom tier).
  mcp/introspect.py    direct MCP stdio client (JSON-RPC 2.0 initialize + tools/list) — agent-independent.
  clis/registry.py     CliRegistry.ensure/run + from_layers/clis; CliError.
  clis/custom_store.py CustomCliStore: JSON-file CRUD + validation.
  nodes/  program.py; agent.py (kiro_node: prompt_fn(state,ctx,out_path), output_doc, mcp=[],
          tools→trust_tools, _compute_effective_trust = node.tools ∩ server.allowlist, turn_timeout=420,
          startup_timeout=120; emits agent.message|thought|tool_call|tool_update|result; the result
          carries Phase-11 credits/context_pct/provenance from turn.usage); cli.py;
          validator.py; gate.py (hitl_gate via interrupt(); kinds approval|escalation|pre_mutation|review);
          subgraph.py; reliability.py (attach_reliability = the trio); tool_store.py + mcp/blackboard_server.py
          (Phase 9: per-run ToolOutputStore + save_tool_output/list_tool_outputs — save-by-reference).
  state.py `_telemetry_merge` sums `credits` (None never clobbers an accumulated total; Phase 11).

genesis/genesis/
  db/       database.py (Database: connection factory + PRAGMA WAL/busy_timeout/foreign_keys/row_factory
            + tx()); runner.py (Migration + migrate() + current_version/pending + contiguity guard);
            migrations/ (m0001_baseline adopts runs+run_events; m0002_chat adds chat_sessions+chat_messages;
            m0003_chat_usage adds chat_messages.usage; m0004_copilot adds chat_sessions.mode +
            chat_run_links + chat_permissions; m0005_supervision adds chat_notifications; m0006_copilot_actions adds the copilot audit trail; **m0007_kb adds the code-free temporal `kb_*` Appian KB tables (Phase 16-02); m0008_business_map adds `kb_business_maps` (17-01); m0009_documents adds `kb_documents`/`kb_document_links`/`kb_document_sections` (Phase 19)** — current_version=9). Schema is owned HERE (spec 01).
  kb/       (Phase 16-02) store.py (KbStore over `kb_*`: app lifecycle incl. table-scoped untrack; begin/apply
            [baseline+delta SCD-2]/finish syncs; recompute-on-sync bundles [flow_json verbatim]; tag_release/
            list_releases + point-in-time helper; contract-shaped reads; **+ list_syncs/latest_sync (16-04)**). **dev_mcp.py — Dev-MCP `listApplications` via a direct-stdio `tools/call` (16-04).** No source code stored (ADR-037);
            duck-types genesis-appian-parser's KbParseResult (pin lands in 16-03).
            **Phase 19 (Document Library): documents.py (DocumentStore over `kb_documents`/`kb_document_links`/
            `kb_document_sections` — global dedup store; list populates `linked_apps`; untrack unlinks-not-deletes);
            doc_parsing.py (ParsedDocument + parse_document/parse_bytes: PDF/DOCX/XLSX/CSV/MD/TXT → Markdown + per-tab JSON +
            heading sections + content_hash; google_export_target convergence; store_parsed); doc_sync.py (DocumentSyncEngine
            — injected via ctx.extras['document_sync']: resolve/fetch[gws]/parse/write + add_upload/add_gdrive + remove);
            build_evidence_pack extended with a `documents` key (bounded excerpts).**
            **Phase 20 (Features & Specs): features.py (FeatureStore over `kb_features`/`kb_feature_specs`/
            `kb_feature_spec_revisions` — feature CRUD; single spec per feature with a validated status
            draft→in-progress→in-review→completed; milestone revisions; untrack cascades features [ADR-042
            intrinsic-to-app]). `KbStore.untrack_application` also deletes `kb_features` (cascades specs+revisions).**
  integrations/gws/ (Phase 19, ADR-040) client.py (GwsClient — read-only Drive/Docs/Sheets/Slides allowlist, exit-code map,
            reuse vs isolated mode, list/get/export/download_file); login.py (GwsLogin — spawn `gws auth login`, capture the
            sign-in URL from stderr, track idle/pending/connected/failed); factory.py (build_gws_client/build_gws_login,
            isolated mode). Genesis owns an isolated config dir; reads the OAuth client from the dotfiles client_secret.json.
  cli_tools/native/ (Phase 19, ADR-040) installer.py (NativeCliInstaller — drop-in single-binary install/version/rollback/
            active_launch_spec/status) + lockfile.py (NativeCliLockfile — own atomic JSON store). The CLI analog of mcp/native/.
  runtime/  settings.py (Settings: state_dir ~/.genesis, artifacts_dir ~/Genesis/runs, db_path,
            library_dir, lockfile_path, secrets_path, environments_path, custom_mcp_path,
            custom_cli_path, **skills_dir=~/.genesis/.kiro/skills + skill_output_dir=~/.genesis/skill-output [Phase 14]**,
            **mcp_servers_dir=~/.genesis/mcp-servers [16-08]; cli_tools_dir=~/.genesis/cli-tools + isolated gws_config_dir + gws_client_secret_path (dotfiles ~/.config/gws/client_secret.json) + kb_documents_dir=~/.genesis/kb-documents [Phase 19]; feature_specs_dir=~/.genesis/feature-specs [Phase 20 — spec.html + revisions/<n>.html]**,
            retention_keep_last/max_age_days, retention_on_start); checkpoint.py
            (AsyncSqliteSaver); context.py (build_context); engine.py (async run/resume/get_state/stream).
  dist/     gitlab.py, local.py, catalog.py, lockfile.py (**+InstalledSkill / Lockfile.skills — Phase 14, additive/back-compat**),
            install.py, loader.py (check_compat gate, meta_of [yaml, no import], graph_of, installed, load_build);
            **skill_catalog.py (reads skills-registry.json) + skill_install.py (SkillInstaller: pull skills/<id>/** at a
            ref into settings.skills_dir + record Lockfile.skills; update/remove) — Phase 14-02**.
  config/   secrets.py (SecretProvider/PlaintextProvider 0600; **atomic writes: temp+os.replace, and
            set/delete serialize read-modify-write under a per-path lock** — v0.20.1 crash fix), fields.py (mcp_cards/cli_cards/
            secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN}), environments.py, retention.py
            (disk_usage, plan_prune/apply_prune [artifacts], prunable_runs + RetentionService [events +
            blackboard, spec 04]), health.py, service.py (ConfigService facade: merged registries, MCP/CLI
            CRUD, introspect, allowlist, test_server, secrets, environments, health).
  runs/     store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
            awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py (EventLog — durable
            run_events; append/list/last_seq/latest/purge/count/aggregate_tool_calls; **aggregate_credits/
            run_credits/credits_provenance via json_extract over agent.result — Phase 11**), steps.py
            (fold_steps → per-node summary incl. credits/context_pct), events.py (Event +
            single canonical EventBus — legacy dual bus removed in spec 04), validation.py, worker.py
            (SUBPROCESS entry; ops run|resume|get_state|update_state|fork; emits JSONL; sets the
            LangGraph `recursion_limit` from `META.execution.recursion_limit`, default 150 — 12-01), supervisor.py,
            manager.py (RunManager: start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes
            canonical events to EventLog + fans out on cbus; `_CANONICAL_CUSTOM` persists agent.result &c
            with node+full payload; pending_gate [durable + checkpoint cold path]; log_events; steps).
  chat/     (Phase 10) manager.py (ChatManager/ChatSession: persistent read-only ACP client per live
            session, in-process — NOT a subprocess; stream_turn persists per-message usage + emits credits),
            store.py (ChatStore/ChatMessageStore on genesis.db: sessions + messages + usage; session_usage_total),
            events.py (map_message_to_events → canonical agent.* shapes), mcp.py (Atlas + introspection wiring
            + read-tool trust set). Read-only enforcement (ADR-031): trust_tools allowlist + permission_mode
            auto_deny. Phase 14: allow_fs_write=True but **sandboxed** via SDK fs_write_root to the per-session
            skill-output dir only (skill_output_dir/<session_id>); reload_skills/reload_all_skill_clients close
            live clients so a workspace change is picked up next turn.
  mcp/      introspection_server.py (read-only Genesis-introspection MCP server: list_runs/get_run/steps/
            events/list_failures/list_workflows/get_workflow/integration_health/platform_stats over a
            read-only genesis.db connection — Phase 10-02);
            **kb_server.py (Phase 16-05) — read-only genesis-kb MCP: the 17 Tier-1 KB tools over a `mode=ro`
            KbStore with Atlas-mirrored shapes; get_object_code/get_orphan fetch live SAIL via the Dev MCP
            (kb/dev_mcp.object_code), graceful code_status:unavailable. Launched `-m genesis.mcp.kb_server --db <db>`;
            wired into chat (chat/mcp.py) in place of appian-atlas**;
            **native/ (Phase 16-08, ADR-038) — installer.py (NativeMcpInstaller: install(id,bundle_path)→uv sync under
            settings.mcp_servers_dir/<id>/versions/<v>/ → verify entry → sha+lockfile → set current; rollback;
            active_launch_spec [launch from the per-server venv, not uv]; status; NO network update) + lockfile.py
            (NativeMcpLockfile — atomic own JSON store, not genesis.db)**.
  skills/   (Phase 14, ADR-034) model.py (parse_skill_md/validate SKILL.md frontmatter + SkillInfo +
            shadows_personal), store.py (SkillStore: filesystem repo over settings.skills_dir =
            ~/.genesis/.kiro/skills; path-traversal-safe create/list/get/remove + .genesis-source.json marker),
            service.py (facade + reload hook). dist/skill_catalog.py + dist/skill_install.py pull a library
            skill into the workspace + record Lockfile.skills. Chat auto-discovers the workspace (cwd/.kiro/skills)
            + writes documents to the per-session skill-output sandbox (SDK fs_write_root).
  api/      app.py (create_app FastAPI; version 0.32.0; instantiates ChatManager + ChatRunSupervisor + SkillService; registers chat/copilot/skills + **native-mcp** + **applications** routes + per-session skill-output endpoints).
            ALL routes on an APIRouter at prefix="/api" (ADR-028) + a catch-all SPA fallback. Routes:
            catalog(+available), library install|update|DELETE; workflows/{id}(+/graph); config/health,
            gitlab-token, mcp-cards, cli-cards, mcp-cards/{server}/test, secrets, environments;
            config/mcp-servers CRUD(+tools+allowlist+test), config/clis CRUD; **config/environments(+/{label}/dev + /dev/check, 16-08 §2.0); config/native-mcp (GET status) + config/native-mcp/{id}/install|rollback (POST, 16-08 Stage B)**; **applications(+/available) + applications/{uuid}(+/sync +/sync-status +/objects(+/{uuid}) +/bundles(+/{id})) + DELETE (16-04)**; **config/native-cli (GET status) + config/native-cli/{id}/install|rollback + config/gws/auth (GET) + config/gws/auth/login(+/state) + config/gws/auth/logout (Phase 19); documents/upload + documents/gdrive + documents/{id}/link (POST/DELETE) + documents/{id}/sync + documents/sync + applications/{uuid}/documents/sync + GET documents(+?app_uuid) + documents/search + documents/{id} + DELETE documents/{id} (Phase 19)**; **applications/{uuid}/features + features/{id}(+PATCH/DELETE) + features/{id}/spec (POST create-opens-a-feature_spec-chat / GET) + features/{id}/spec/context (GET candidates / POST inject-as-./context/-files) + features/{id}/spec/milestone + features/{id}/spec/status + features/{id}/spec/{artifact,sdk.js,export.md} (Phase 20)**; config/retention/{plan,apply};
            artifacts/usage; home (metrics incl. **total_credits + credits_provenance**); runs (POST/GET),
            runs/{id}(+gate), runs/{id}/state (GET/PATCH), pause|resume|cancel|respond|fork,
            runs/{id}/artifacts(+/{name}(?mode)+/download), runs/{id}/events(?after,kinds,node)+/steps,
            runs/{id}/events/stream (canonical SSE); **chat/sessions CRUD + chat/sessions/{id}/messages
            (SSE turn) + /cancel (Phase 10); chat/sessions/{id}/mode + /notifications + GET/PUT config/copilot
            + chat/actions + resolve-permission (Phase 13 copilot); skills (GET/POST author/DELETE) +
            skills/available + skills/install + skills/update + chat/sessions/{id}/reload +
            chat/sessions/{id}/outputs(+/{name}(?mode)+/download) (Phase 14 skills)**. studio.py.
  cli/      main.py (genesis serve|install|list|create-workflow|test-workflow|db upgrade|db status|**mcp install-native|mcp status|mcp rollback-native** …).
  lint/     contract.py (workflow.yaml↔META parity; YAML_ONLY_KEYS exempts UI-only keys like `graph:`),
            reliability.py (trio enforcement).
  web/      React + TS + Vite (ADR-026/027): Tailwind + Radix/shadcn-style + Zustand + React Router +
            TanStack Query + React Flow + Recharts + react-markdown/remark-gfm + mermaid (lazy) +
            CodeMirror (JSON editor) + lucide + sonner. Structure:
            src/styles/{tokens.css,index.css}; src/lib/{cn.ts, api/** [typed client PREPENDS /api +
            ApiError; resource modules], query/** [keys + client]}; src/stores/**; src/shared/ui/**
            (primitives: Button/Card/Badge/Chip/Dialog+Drawer/Tabs/SegmentedControl/Switch/Input+Field+
            Textarea/HealthDot/MetricCard/TrendChart/format/icons); src/shared/layout/** (AppShell/
            Sidebar/SplitPane/Page — **no top bar (removed v0.43.0); no breadcrumbs (removed v0.42.0); the theme
            toggle lives in Settings → General (`AppearanceSection`)**); src/shared/feedback/** (Empty/Error/Loading); src/app/**
            (providers, router, RootLayout, routes); src/features/{overview,settings,catalog,runs,
            run-detail,documents,chat,applications,library,features}/**; src/test/fixtures (golden contract fixtures); src/dev/KitchenSink.
            **features/features (Phase 20): FeaturesTab + CreateFeatureDialog + FeaturePage + SpecWorkspace (reused ChatThread
            + a sandboxed review `<iframe sandbox="allow-scripts">` served by the API + a postMessage annotation→chat bridge via
            an optional `registerSend` prop on ChatThread + status/milestone/Export-.md/Add-context). api/assets/lavish/ holds
            the vendored MIT Lavish SDK (artifact-sdk.js + mermaid-node.js, Genesis-themed) + the esbuild-built `sdk.js`.**
            **static/ = the COMMITTED, built app** served by `genesis serve`.
            Settings (Phase 8): SettingsPage = Tabs shell (/settings/:tab?/:id?); components/manager/**
            (ResourceManager, ResourceFormDialog, SpecForm, ConfirmDialog — the standardized pattern);
            components/mcp/** + cli/** (tabs+detail on that framework); EnvironmentsSection/GitlabSection/
            StorageSection reused; hooks.useMcpResources/useCliResources merge cards ⋈ custom entries.
            Run-detail conversation (spec 06): conversation.ts buildTranscript + groupTurns; inspector/
            TurnView + ThinkingTimeline + AssistantAnswer + conversationParts.
            Chat (Phase 10): features/chat/** — ChatThread REUSES the run-detail Conversation via a
            `hideResultChip` prop; Composer; SessionList; lib/api/chat.ts `readSse` (CRLF SSE framing).
            Skills (Phase 14): features/catalog/CatalogPage = Tabs shell (Workflows | Skills; static
            `catalog/skills` route ahead of `catalog/:workflowId` to dodge the dynamic-route collision);
            features/catalog/skills/** (SkillsTab + SkillCard + SkillAuthorDialog + hooks); shared/ui/file-drop
            (FileDropList); lib/api/skills.ts (+ client.postForm multipart). Chat `/` palette (Composer) is a
            unified Workflows(copilot-only)+Skills(both modes) menu → skill pick sends `/<name>`; features/chat/
            SessionOutputs renders the per-session skill-output sandbox via the shared DocumentPreview.
            Credits (Phase 11): shared/ui `formatCredits` + `CreditBadge` + `Coins`; Overview "Credits
            Used" KPI (replaced Tool-Calls); run-detail TelemetryStrip Credits stat + per-node + header
            run-total; chat per-message credit footer (in the ResultChip's old position).

genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images:
  appian-atlas [read-only], jarvis [read-write-deploy], appian-data-generator, **appian-dev [read-only] + appian-devops [export-only] — managed-native, ADR-038, resolved the old `lcp` placeholder**, jira),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation, code-review, design-doc, sync-application, _fixtures/noncompliant}, MIGRATION.md.
  skills/{gam/SKILL.md + references/, _fixtures/noncompliant} + skills-registry.json + ci/validate_skills.py
  (self-contained pyyaml validator: registry+manifest+parity+fixture gate; a `skills-validate` CI job) — Phase 14-02.
```

---

## 5. Non-negotiable constraints (ADRs — do not violate; flag + confirm if a task requires it)

- **ADR-001** — LangGraph owns control flow; agents never orchestrate.
- **ADR-002/004/020** — agent steps = narrow Kiro turns over ACP, **per-node MCP injection**; NO global Kiro `mcp.json`.
- **ADR-005 (+ ADR-029)** — the shared MCP/CLI registry lives in the library (curated tier, changed via MR). ADR-029 adds a **user-writable custom tier** on top; the curated tier stays MR-governed. Effective tool trust = `node.tools ∩ server.allowlist` (a hard cap).
- **ADR-010/018/022** — state is small/serializable/**editable** (pointers + decisions); bulk lives in the `RunWorkspace` blackboard under `$GENESIS_ARTIFACTS_DIR`; never inline bulk in state/chat.
- **ADR-011** — reliability trio (validator + retry + escalation) MANDATORY on every agent node; CI-enforced.
- **ADR-012** — graph execution runs in a disposable **subprocess worker**, not the app; pause=kill, resume=fresh worker from checkpoint; the app never imports workflow Python.
- **ADR-019** — genesis-core semver; `CORE_MAJOR` (=1, distinct from pip version) is the compat-gate key; the loader refuses a library whose declared `genesis_core_major != CORE_MAJOR` (additive-only within a major).
- **ADR-021** — `META.auto_approve=true` default; pause only at 3 sanctioned gate classes (approval|escalation|pre_mutation); `pre_mutation` REQUIRED before any write/deploy/data MCP node.
- **ADR-023** — backend is FastAPI **embedding** LangGraph (NOT a LangGraph Server); Studio is interim debug only.
- **ADR-024** — engine is **async-first** (ainvoke/astream + AsyncSqliteSaver + aiosqlite); Python pinned 3.13.
- **ADR-025** — "fork" = seed a NEW thread from a past checkpoint; the original is untouched.
- **ADR-026** — web UI = React+TS (local single-user); multi-user/hosted would re-open ADR-012/023 (separate track).
- **ADR-027** — the web stack (Tailwind + shadcn/Radix + React Router + TanStack Query + React Flow + react-hook-form/zod + react-markdown/mermaid/shiki + Recharts + Vitest/RTL/MSW) and the Overcut visual language (07-03a). **Reuse existing primitives; use design tokens, not raw palette colors.**
- **ADR-028** — ALL backend endpoints under `/api` (APIRouter) + SPA history fallback; the web client prepends `/api` centrally (never hard-code it in components); the Vite dev proxy is a single `/api` → :8760.
- **ADR-029** — two-tier MCP/CLI registry (curated read-only + custom writable) + tool allowlist + direct-stdio introspection.
- **ADR-030** — persistence stays **SQLite**; move to Postgres/pgvector only on an explicit trigger (multi-user, transcript RAG, or heavy analytics). Repositories keep DB-agnostic signatures so the seam stays cheap.
- **ADR-031** — **Chat is a read-only assistant** (never orchestrates): it observes/answers, never drives or mutates. Enforced (defense in depth): `trust_tools` allowlist of read tools only + SDK `permission_mode="auto_deny"` + `allow_fs_write=False` + a read-only `genesis.db` connection in the introspection server. kiro-cli matches MCP tools by the **namespaced** `@server/tool` name — build allowlists as `@server/<tool>`. Chat runs in-process (no subprocess worker; ADR-012 is about workflow Python). **(ADR-034 refines this: since Phase 14 chat runs `allow_fs_write=True` but SANDBOXED via the SDK `fs_write_root` to the per-session skill-output dir only — a skill may write documents there, nothing else on disk.)**
- **ADR-032** — **credit usage is REAL metered data from Kiro ACP** (`_kiro.dev/metadata.meteringUsage`, verified per-turn not cumulative), NOT estimated — there is no pricing engine. SDK captures it → telemetry + `agent.result` + `run_events`/`chat_messages.usage`. Every figure carries `provenance` (`metered`/`partial`/`unavailable`); the UI shows honest "n/a", never a fabricated number.
- **ADR-033 (ACCEPTED — Phase 13, SHIPPED)** — the **Chat copilot may operate runs** (start / read status / answer gates / cancel) at the **run-management layer only**, but (a) LangGraph still owns each workflow's control flow (ADR-001 intact — the copilot calls the same `RunManager` API a human clicks, it is NOT the workflow engine), (b) **every mutation is human-confirmed** (launch dialog for `start_run`; per-call confirm card for `respond_to_gate`/`cancel_run`, via the untrusted-tool → `session/request_permission` → SDK `permission_mode="ask"` bridge), (c) it can NEVER auto-approve/bypass a workflow's own HITL gate — only relay the human's decision, (d) NO config/secret/registry/workflow-definition/deploy tools, (e) read-only default + global kill-switch + per-session concurrency/rate/allow-deny limits (13-06, enforced app-side on `POST /api/runs` gated on the control token) + a `copilot_actions` audit trail. Refines ADR-031; preserves ADR-001. Delivered 13-01..13-06 (genesis v0.25.0 + sdk v0.5.0).
- **ADR-034 (ACCEPTED — Phase 14, SHIPPED)** — **Skills are a first-class "standalone activity" concept beside Workflows, chat-invoked + filesystem-provisioned.** A **Skill** = a single standalone activity (draft a document, build a checklist, apply a body of knowledge like GAM) owned by the **Kiro agent** (its `SKILL.md`), no stages/run; a **Workflow** = a staged/orchestrated activity owned by **LangGraph** (ADR-001 preserved — a skill never starts a run). Skills are **filesystem-discovered** (NOT an ACP wire param like MCP): Genesis provisions them into a managed Kiro workspace **`~/.genesis/.kiro/skills/`** (= the chat `cwd`; **spike-proven** over ACP — auto-activation by `description` + explicit `/skill-name`). Two acquisition paths: install from a new `skills/` library in `genesis-workflows` (mirrors the workflow install/lockfile path) OR author in-flight (SKILL.md + scripts/references/assets). Catalog gains **Workflows | Skills** sub-tabs; Chat's `/` palette becomes a unified workflows+skills menu (skills also work in read-only chat). **Safety:** a skill may write documents **only** into a per-session **skill-output sandbox** `~/.genesis/skill-output/<session_id>/` (via a small additive SDK **`fs_write_root`** option — writes elsewhere rejected); executing bundled `scripts/` stays deferred. Refines ADR-031/033 (chat gains bounded sandboxed document output, no other write authority). Delivered 14-01..14-05 (kiro-agent-sdk v0.6.0 + genesis-workflows v0.6.0 + genesis v0.26.1).
- **ADR-035 (ACCEPTED — Phase 15, SHIPPED)** — **Run input file attachments.** A workflow input may declare `format:"file"`. Such inputs are provisioned at launch, not passed inline: a new **multipart `POST /api/runs/upload`** (browser-only; the JSON `POST /api/runs` is unchanged for tokened/copilot starts) + **`RunManager.start(..., files=)` / `_provision_files`** writes each upload into the run **blackboard** under `uploads/<sanitized>` and rewrites the matching input to that blackboard-relative path **before** schema validation. Guards: 10 MB cap, extension allowlist (`.txt .md .html .htm .csv .png .jpg .jpeg`), filename sanitization (no traversal), target must be a declared `format:"file"` prop (`FileUploadError` → 400). The worker just reads a file already in its own workspace — **ADR-012 isolation intact**; uploads are **read-only inputs, never executed** (mirrors Phase-14 `scripts/` posture). Web: the 07-05 launch form renders a `FileDropList` for file inputs and submits multipart. Preserves ADR-010/018 (bulk → blackboard, never inline). Enables the Phase-15 mockup→i18n branch. Delivered 15-01 (genesis v0.27.0).
- **ADR-036 (ACCEPTED — Phase 16; shipped 16-02/03/04, Atlas cutover in 16-05)** — **Internalized Appian Knowledge Base.** Genesis owns the Appian KB: a Genesis-native parser + a local KB in `genesis.db`, fed by the **single dev-tagged environment** (the Environments registry may hold many; a single-select **`is_dev` toggle** designates the one Phase 16 authenticates against — URL + creds for REST export + Dev/DevOps MCP; Deployment-REST export + Dev MCP). External **Atlas MCP** (GitLab-served) and **Jarvis** are **retired as the KB source** (Atlas = inspiration + interim source until the 16-05 cutover). Sync is a **deterministic LangGraph workflow** (program-node REST export, no agent → ADR-001 preserved). Aligns with local single-user / one-env / own-data-plane (ADR-023/026/030).
- **ADR-037 (ACCEPTED — Phase 16; code-free `kb_*` shipped 16-02/03, live code wires in 16-05, versioning = 16-06 backlog)** — **Code-free temporal KB + live code via the Dev MCP.** The KB stores **only** metadata/structure/dependency-graph/bundles — **never** SAIL source. All code (current + historical) is fetched **live** via the **Dev MCP** (version-parameterized). Object history = a **temporal SCD-2** model keyed to syncs; **user-tagged releases** (`kb_releases`) name points in time; `env_version_ref` bridges a release to the env version. Refines ADR-030 (SQLite `kb_*`; semantic search over parsed content = future pgvector trigger) + ADR-010/018 (export zip + parser output → blackboard; only metadata → `kb_*`). Historical-code slice depends on Dev MCP **AP-62096** (26.8 GA).
- **ADR-038 (ACCEPTED — Phase 16, SHIPPED)** — **Managed native Appian MCP servers (vendored, versioned, replaceable, not forked).** The **Dev MCP** (`lcp-mcp-server`) + **DevOps MCP** (`appian-deployment-mcp`) are installed as managed, versioned local servers (`~/.genesis/mcp-servers/<id>/versions/<v>/` via `uv sync`; launched from the per-server venv; **read-only allowlists**; registered as a **managed reference**, not a static image → resolves the old `lcp` `<lcp-image>` placeholder). **Updatable without forking = MANUAL drop-in (2026-08-05 decision):** a new Appian release is integrated by the operator dropping the new bundle in → Genesis installs it as a new version + swaps `current` (prior kept for **rollback**; sha-verified; bundle never modified). **No auto-fetch update source** — the earlier connected-site bundle-servlet (Dev) and configured-mirror (DevOps) fetch were dropped. New prereq: `uv` at install time; Dev-MCP Basic auth is the headless default (browser/SSO = opt-in). **§2.0 (dev-env `is_dev` toggle) shipped (genesis v0.30.0); Stage B (the managed-native installer + managed-ref resolution + registry entries + API/CLI/web panel) SHIPPED — genesis-core v0.9.1 + genesis v0.31.1 + genesis-workflows v0.8.4; 16-08 COMPLETE.**
- **ADR-040 (ACCEPTED — Phase 19, SHIPPED)** — **Managed-native CLI connector (`gws`).** The Google Workspace CLI is installed as a managed, versioned local **binary** (`~/.genesis/cli-tools/gws/versions/<v>/`; the CLI analog of ADR-038's native MCP — a `genesis-core` `CliRegistry` `"managed":"<id>"` entry resolves via an injected `launch_provider`). Genesis owns an **isolated** config dir (`~/.genesis/cli-tools/gws/config`, file keyring, its own `gws auth login`) and **reads the OAuth client** from the dotfiles-provisioned `~/.config/gws/client_secret.json` — **ships no token**; dotfiles setup is a documented prerequisite. **Read-only** Drive/Docs/Sheets/Slides scopes only (allowlist enforced before spawn). Never point Genesis at the user's real `~/.config/gws` (a forced-keyring probe once invalidated their creds). genesis-core **v0.9.2** + genesis **v0.44.0** + genesis-workflows **v0.9.3**.
- **ADR-041 (ACCEPTED — Phase 19, SHIPPED)** — **Documents are a global first-class store linked into applications.** One row per **unique** document (dedup by `gdrive:<fileId>` / `upload:<sha256>`), stored **once** on disk (**latest version only** — sync overwrites), **linked** into ≥1 app via `kb_document_links`. **Untracking an app removes its links, never the shared document** (FK `ON DELETE CASCADE` covers links). Code-free metadata + pointers + a change-detection fingerprint in `genesis.db` (m0009); bulk parsed Markdown/JSON on disk (ADR-010/018). Refines ADR-030 (semantic/pgvector doc search = a future trigger). genesis **v0.44.0** (+ the `sync-documents` workflow in genesis-workflows **v0.9.3**).
- **ADR-042 (ACCEPTED — Phase 20, SHIPPED)** — **Features & Specs are first-class sub-entities of an application; a spec is authored conversationally (Chat, not a workflow), HTML-authoritative.** m0010 (`kb_features` FK→`kb_applications ON DELETE CASCADE`, so untracking an app cascade-deletes its features → specs → revisions — **intrinsic to the app**, unlike Phase-19 documents). A spec's authoring surface is a **reused Chat session** (ADR-031/034 lineage) — **LangGraph is not involved, ADR-001 intact**; `genesis-kb` (16-05) gives the agent the app's KB. The **HTML artifact is authoritative** (Markdown is a derived export); the agent writes `spec.html` into its per-session `fs_write_root` sandbox (Phase 14, no new write authority). Lifecycle `draft → in-progress → in-review → completed` (user-set; agent may suggest) + milestone snapshots. **One spec per feature** in v1. genesis **v0.45.0**.
- **ADR-043 (ACCEPTED — Phase 20, SHIPPED)** — **Embed the Lavish annotation SDK (vendored, MIT) for in-app HTML review.** Vendor the browser SDK of `kunchenguid/lavish-axi` (`artifact-sdk.js` + `mermaid-node.js` @ `899747a`) into `genesis/api/assets/lavish/`, Genesis-theme it (its `:host` palette → `--lavish-*` overrides fed from design tokens), and host the spec artifact in a **same-origin sandboxed `<iframe>`** whose host is our React chrome listening on `postMessage`. Genesis does **not** run Lavish's server/CLI/poll/export/ht-ml.app sharing. Rationale: the SDK makes **no** server calls (`parent.postMessage` only), fits the single-SPA UX + in-process ChatManager, and avoids a second window / unauthenticated `:4387` server / Node-≥22 runtime. Upstream tracked manually (pinned commit + a documented `:host` theming patch); attribution in `THIRD-PARTY-NOTICES`. Mermaid-whiteboard deferred. genesis **v0.45.0**.
- **ADR-044 (ACCEPTED — Phase 21, SHIPPED)** — **A Feature is a workspace of sequential artifact stages.** The feature page is a **pipeline of artifact cards** (Spec → Design → Breakdown → …), each artifact carrying **its own** status; the **feature has no status derived from any single artifact** (feature-level status is a later, separate concept). Artifacts open in two modes: **Edit** (author — e.g. the spec builder at `…/features/:id/spec`) and **View** (read-only preview — the spec artifact route with `annotate=0`, no Lavish SDK). Landing on a feature shows the pipeline, not the builder; the Features-tab card no longer shows the spec's status. Sequential unlock-on-completion is part of the model but **deferred** until ≥2 artifacts exist (Design/Breakdown ship as disabled placeholders). genesis **v0.46.0**.
- **ADR-045 (ACCEPTED — Phase 21, SHIPPED; refines ADR-031)** — **The reused chat mirrors the Kiro CLI/ACP surface.** Genesis adopts the ACP extensions (`session/set_model` + the models advertised on `session/new`, `_kiro.dev/commands/{available,options,execute}`, `_kiro.dev/{compaction,clear}/status`, image prompts) so the in-app chat offers model selection, slash commands, context/compaction views, clear/compact, and image attachments — in **both** the main chat and the spec builder. This **relaxes ADR-031's "Chat is read-only"**: the surface is **no longer categorically read-only**, but **write-capable actions stay human-confirmed** via the existing `permission_mode="ask"` bridge (ADR-033) — not blanket-denied; safe introspection commands run freely. Model choice is **at creation** (`m0011 chat_sessions.model`); mid-conversation switch deferred. Bounded by local single-user (ADR-026). Needs **kiro-agent-sdk v0.7.0** (additive ACP methods; verified vs kiro-cli 2.16.2 in the 21-01 spike — autocomplete is client-side since the per-command `optionsMethod` isn't wired in 2.16.2; `execute` streams, with the prompt-path as fallback). genesis **v0.46.0** + genesis-core **v0.9.3** (SDK pin).

**Key implementation contracts:**
- Node fns are `async fn(state, config: RunnableConfig)`. LangGraph injects `config` only when the param is annotated `RunnableConfig`; nodes read ctx via `ctx_from_config(config)`.
- `build(ctx) -> CompiledStateGraph` compiled with `ctx.checkpointer`. `META` is a static dict importable with NO side effects. `workflow.yaml` MUST mirror `META` (parity lint; UI-only keys like `graph:` are exempt via `YAML_ONLY_KEYS`).
- Workflow `graph.py` is loaded standalone (importlib on the file) — keep it self-contained (no sibling-package imports); put pure functions in `graph.py`.
- ACP MCP entries: `env` is a **LIST** of `{name,value}` (NOT a dict). See §7.

---

## 6. Environment, dev loop, release, CI

- **OS** macOS; **Python** 3.13; **node** 20 + npm + vite. Use non-interactive shell flags (`rm -f`, etc.).
- **Dev venv (use for all Python):** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv` — editable installs of kiro-agent-sdk, genesis-core, genesis (+ pytest, pytest-asyncio, ruff, pyyaml, requests, jsonschema, aiosqlite, fastapi, sse-starlette, uvicorn, httpx). Python edits are live for the CLI and freshly-spawned workers — **but restart a running `genesis serve`** to pick up server-process changes (it has already imported `api/app.py` + `manager.py`).
- **Run tests:**
  - genesis: `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis`)
  - genesis-core: `cd genesis-core && ../genesis/.venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis_core`)
  - genesis-workflows: `../genesis/.venv/bin/python ci/validate_library.py` and `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures`
  - web: `cd genesis/web && npm run lint && npm run typecheck && npm test`
- **Frontend build (the current, post-cutover rule):** the new app IS the served app; `web/static/` is the **committed** production bundle. `npm run build` (= `tsc --noEmit && vite build`) writes `web/static/`. **After ANY `web/src` change, run `npm run build` and COMMIT the updated `web/static/`.** CI's `frontend` job runs lint → typecheck → test → build → a **stale-bundle guard** (`git diff --quiet -- static`) that fails if the committed bundle differs from a fresh build. (If an older spec's DoD says "web/static/ untouched", treat it as "rebuild + commit" — those specs predate the cutover.)
- **NPM registry:** local `~/.npmrc` points at Appian Artifactory with an EXPIRED token (E401 on new installs). Use `--registry=https://registry.npmjs.org/` for local installs (do NOT edit global `~/.npmrc`). CI's node:20 resolves the lockfile's public-npm URLs fine.
- **Run the app:** `.venv/bin/genesis serve` (→ http://127.0.0.1:8760, `/docs`). Install workflows: `genesis install --from ../genesis-workflows` (or `genesis install` for GitLab pull). `genesis list`. `genesis db status|upgrade`.
- **Distribution/versioning:** pyproject deps are git+ssh. When you change a repo: bump `[project].version`, commit + tag `vX.Y.Z` + push, and bump dependent pins (genesis pins genesis-core; genesis-workflows pins both). Release order core → genesis → genesis-workflows so tags exist. **Frontend-only changes still ship a genesis release** because `static/` is committed. Commits: `git -c user.name=Genesis -c user.email=genesis@local commit -m "..."` (do NOT change git config).
- **CI:** each `.gitlab-ci.yml` rewrites ssh→https via the `GITLAB_PUSH_TOKEN` CI/CD var (set on all 3 code repos — should be rotated; it was shared in chat). `glab` is authed for READS (`glab ci list/trace`) but its token lacks `api` scope → cannot `glab ci run`/`variable set`; **trigger pipelines by pushing.** Verify: `glab ci list -R ramaswamy.u/<repo>`.
- **Gitignore lesson:** build-artifact ignores are anchored (`/dist/`, `/build/`, `web/node_modules/`) so they don't swallow tracked source/served dirs (`genesis/web/static/` IS tracked). After adding a source dir, verify `git check-ignore <path>` says NOT ignored and `git ls-files` lists it.
- **project-tracker repo** (github, branch `main`) is SEPARATE from the code repos; after meaningful work, update `tracker.md` §6 + a `progress/` doc and push it (`git pull --rebase` then push).

---

## 7. Hard-won lessons (do not regress these)

- **ACP MCP env MUST be a list of `{name,value}`** (`McpRegistry.acp_servers`). A dict silently drops env in kiro-cli acp → the MCP container runs without secrets and hangs to timeout. This broke erd-generation. When stubbing an external contract, mirror its REAL schema (a permissive stub hid this).
- **`kiro_node` builds the real `KiroAgentOptions`** (cwd, trust_all_tools, trust_tools, agent, model, agent_engine, kiro_cli_path, extra_args, mcp_servers, startup_timeout, turn_timeout, stream_limit_bytes, debug). There is NO `tools` field (map an allowlist to `trust_tools`). turn_timeout=420, startup_timeout=120 for heavy MCP.
- **SSE streaming:** the per-run bus stays open until the run is TERMINAL (so gate pause/resume keeps streaming); the client dedupes replayed history and CLOSES the EventSource on terminal final/error (else it auto-reconnects and re-replays forever — the "repeated activity" bug). The server sends NAMED SSE events (`event: <kind>`); the client registers a handler per kind.
- **Data plane is SQLite, not JSON** (`~/.genesis/genesis.db`, WAL): runs + full conversation + checkpoints. Only bulk artifacts are files. Schema is owned by `genesis/db/` migrations (spec 01) — never hand-write DDL in the repositories; add a migration. Gate/approval controls MUST derive from durable state (`GET /runs/{id}.gate` via `manager.pending_gate`), NEVER from a transient event.
- **Canonical event kinds:** `run.started` / `node.completed` / `agent.message|thought|tool_call|tool_update|result` / `validator.result` / `retry.scheduled` / `gate.awaiting|resolved` / `run.final` / `error`. There is NO `node.started`/`node.failed` — "running" = `run.cursor`; failure is attributed to the cursor on a failed run. The single live `EventBus` + durable `EventLog` are the whole event model (the legacy dual bus was removed in spec 04).
- **Run Detail resilience:** if a workflow declares no `graph:` topology, the UI derives a fallback from `/steps` (or events) so the graph is never blank. Workflows SHOULD still declare `graph:` (the catalog preview needs it; node ids must match LangGraph node names).
- **Conversation (spec 06):** `buildTranscript` folds `agent.*` events → items; `groupTurns` groups them into turns (validator/retry notes attach to the just-closed turn). The Thinking panel auto-expands while live and collapses on the turn's `result`. Markdown answers reuse the 07-09 renderers (no new deps).
- **Worker error reporting:** a generic `worker_exit` must NOT clobber a specific `error` event; empty-message exceptions report their type + a hint. For MCP-server logs, run the container standalone (Genesis hides them in the ACP subprocess).
- **LangGraph specifics:** sync `invoke` can't run async nodes; sync `SqliteSaver` fails under async (use `AsyncSqliteSaver`). `Command(resume=...)` needs a checkpointer-compiled graph. Fork seeds a NEW thread.
- **API namespacing (ADR-028):** browser routes (`/runs`, `/catalog`, `/settings`) are real client paths; ALL backend endpoints live under `/api`; the client prepends `/api` centrally and REJECTS non-JSON (throws `ApiError` → `ErrorState`). Uniform 500s on `/api/*` in the browser usually means the BACKEND ISN'T RUNNING (the Vite proxy 500s on connection-refused) — `curl http://127.0.0.1:8760/api/config/mcp-cards` first.
- **Frontend contract fixtures:** mirror the 07-02 event/GateDescriptor/topology/steps shapes in `web/src/types` + the golden fixtures in `web/src/test/fixtures`; a drift must fail a test (`contract.test.ts` feeds the golden log through the real folds). The "stub hid the contract" lesson applies.
- **Settings data (Phase 8):** MCP/CLI detail needs BOTH the merged card view (`mcp-cards`/`cli-cards`: status + secret fields) AND the custom entry (`mcp-servers`/`clis`: raw spec + allowlist + source) — joined by name in `useMcpResources`/`useCliResources`. Curated tier is read-only; custom is editable/deletable through the standardized `ResourceFormDialog`/`ConfirmDialog`. Use `HealthDot` + tokens, not raw colors.
- **`workflow.yaml`** may carry UI-only keys (e.g. `graph:` topology) — the parity lint exempts them via `YAML_ONLY_KEYS`.
- **jest-axe (v9)** ships no types: ambient `declare module` + the vitest matcher augmentation live in `web/src/types/jest-axe.d.ts` + `web/src/vitest-axe.d.ts` (keep them pure ambient / module-aug); the matcher is extended globally in `web/src/test-setup.ts`.
- **mermaid + Recharts are heavy;** mermaid is dynamic-imported (lazy chunk). Keep new heavy libs lazy.
- **Credits are REAL, not estimated (Phase 11 / ADR-032).** Kiro reports per-turn credits via the
  `_kiro.dev/metadata` notification: the final one of a turn carries `meteringUsage:[{value,unit:"credit"}]`
  + `contextUsagePercentage` + `turnDurationMs`. Verified **per-turn, not cumulative** (spike: 0.184 then
  0.113 in one session). The SDK captures it into `ResultMessage.usage`/`TurnResult.usage`; agent.py puts
  it on the `agent.result` event; `manager._CANONICAL_CUSTOM` persists that payload verbatim into
  `run_events`, so `aggregate_credits` (json_extract) + `fold_steps` + SSE all get it for free. The
  `_telemetry_merge` reducer must NOT let a None (unavailable) credits value clobber an accumulated sum.
- **Chat read-only (Phase 10 / ADR-031):** trust is fail-CLOSED — never trust-all; build the allowlist
  with the namespaced `@server/tool` form (kiro-cli matches that way). A curated server with NO registry
  `tool_allowlist` (e.g. `jarvis`, which is read-write-deploy) means the ONLY cap is the node's `tools=`
  list — a read-only workflow MUST set an explicit read-only `tools=` allowlist on every agent node
  (effective trust = node.tools ∩ server.allowlist).
- **SSE framing is CRLF:** sse-starlette frames events with `\r\n\r\n`. A client reader that splits on
  `\n\n` never parses a frame (the "stuck on Thinking…" chat bug, fixed v0.19.1). `readSse` splits on
  `/\r?\n\r?\n/`. Don't let a LF-only test fixture hide it.
- **Secret writes must be atomic + serialized (v0.20.1 crash fix).** FastAPI runs sync route handlers in
  a threadpool, so two secret-set requests (e.g. two fields of one MCP server) run concurrently. A plain
  `write_text` isn't atomic → concurrent writers corrupt `secrets.json` (a valid object + leftover tail =
  "Extra data"), which 500s `/api/config/mcp-cards` and crashes the UI. Fix: temp-file + `os.replace`
  (atomic) + a per-path lock around read-modify-write. The other JSON stores (mcp-custom/cli-custom/
  environments) share the old non-atomic pattern — harden them the same way if touched.
- **Looping workflows (Phase 12 note):** LangGraph's default `recursion_limit` is **25 supersteps** and
  the worker doesn't raise it, so a per-item loop dies after ~6 items — a looping workflow needs the
  worker to set a higher limit (from META). Also, `attach_reliability` keys retries by agent NODE NAME, so
  a re-entered loop node must RESET `retries[node]=0` each iteration or later items get no retry budget.
- **Phase 9 save-by-reference:** a huge MCP result (e.g. a 3000-line process model) must not re-enter the
  context window — the agent calls `save_tool_output(ref, document=...)` to persist it to the blackboard
  by reference (the per-run ToolOutputStore records every tool result). Prompts instruct "never paste
  tool output into your reply — save it BY REFERENCE".
- **Workflow graph.py with custom reducer state keys must NOT use `from __future__ import annotations`.**
  The loader imports graph.py standalone (`spec_from_file_location` → not registered in `sys.modules`),
  so LangGraph's `get_type_hints()` can't re-resolve stringized annotations — a `class MyState(PlatformState):
  reviewed: Annotated[list, add]` dies with `NameError: Annotated`. Eager (non-`__future__`) evaluation
  stores real `Annotated` objects and works. (erd-generation's state has no reducer keys, so it never hit
  this; the code-review workflow did.) Also: quote YAML flow-scalars containing `?`/`:` (e.g. `label: "Stale?"`).
- **Parse saved MCP tool outputs DEFENSIVELY — real shapes vary per tool (Phase 12 live-run lesson).**
  `save_tool_output` persists a tool's result verbatim, and jarvis tools are inconsistent: some wrap
  JSON in a human-readable preamble (`get_package_contents_from_url` → `Package Contents from URL:\n\n[…]`;
  `get_application_info` → `Application Info:\n{…}`), others return clean JSON (`get_jira_issue`,
  `get_review_checklist`). Shapes also differ from the obvious guess: object `type` is a QName
  (`{http://…/types/2009}Interface`) with a separate `typeId`; `get_review_checklist` is **3-level
  nested** (`parentCategory→categories→checkListItems`) with `applicableObjectTypes` as display names
  ("Expression Rule", not "ExpressionRule"); `jarvis_config` nests `appUuid`/`kbFolderId` under
  `applications[].appConfig` with `globalSettings` a list. The code-review workflow added `_coerce_json`
  (strip preamble), `flatten_checklist`, and normalized type matching. **Systemic gotcha:** a
  `validator_node`'s `check_fn(data,…)` receives `data` from a plain `json.loads` that falls back to
  raw text on failure — so any JSON-consuming validator must coerce `data` itself (don't assume it's a
  dict). Stubbed tests won't catch these; validate against real captured artifacts under
  `~/Genesis/runs/<wf>/<run>/`.
- **Kiro Skills load over ACP from the filesystem, NOT the wire (Phase 14 spike, 2026-07-16).** kiro-cli
  auto-discovers **skills** from `<cwd>/.kiro/skills/` (workspace) + `~/.kiro/skills/` (global) — there is **no
  `skills` param on `session/new`** the way there is `mcpServers`. A real-ACP spike proved a `SKILL.md` in the chat
  session's `cwd` (`~/.genesis`) both **auto-activates** (by `description` match) and is **explicitly invocable**
  via `/skill-name` in the prompt text. So to give the agent a skill you **write files** into a Kiro workspace, you
  don't inject it over the wire. `--help` doesn't list skills (they're a convention, not a flag) — the binary's
  changelog strings + the spike are the evidence. Do NOT set `KIRO_HOME` to relocate skills (it also relocates the
  user's agents/sessions/settings/auth). See `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` + ADR-034.
- **Pin the linter — unpinned `ruff` drifts and breaks CI on pre-existing code (Phase 16-02).** genesis CI does
  `pip install -e ".[dev]"` then `ruff check genesis`. With `ruff>=0.6` (floating), a newer ruff released a **changed
  default rule set** (added `UP*`) that flagged ~170 pre-existing `Optional[...]` usages repo-wide — a green release
  (v0.27.2) went red 18 days later with **zero code change**. Local `ruff check genesis` (older pinned venv ruff) still
  passed, hiding it. Fix: **`ruff==0.15.20`** in dev deps so CI reproduces local exactly. When adopting a newer ruff,
  do it deliberately with a repo-wide fix (`ruff check --fix` the `Optional`→`X|None` churn) + bump the pin. (Tests
  aren't ruff-gated in CI — only the `genesis` package is — so test-file lint drift won't fail CI.)
- **A blocking DB write inside an async node deadlocks the LangGraph checkpointer — do blocking `genesis.db`
  writes OFF the event loop (Phase 16-03).** `genesis.db` is shared: the async `AsyncSqliteSaver` (aiosqlite) and
  any sync `genesis.db.Database` writer coexist. When a program node does a **synchronous, blocking** KB write
  (`KbStore`) *inside the async worker*, that call holds the single-threaded event loop while it waits on the
  sqlite write lock — but the checkpointer's own `aput`/`aput_writes` do `execute` then `await commit()`, so if a
  checkpoint write is in-flight (lock held, commit pending) the commit can never run to release the lock →
  **deadlock** until busy_timeout expires → flaky `sqlite3.OperationalError: database is locked` (green locally,
  red under CI timing; it can pass on one pipeline and fail on the tag pipeline for the *same commit*). **Root
  cause = sync-blocking-write-in-async-node, NOT a PRAGMA.** **Deterministic fix:** run the blocking write via
  `await asyncio.to_thread(...)` so the loop stays free for the checkpointer to commit/release (the `sync-application`
  `write_kb` is a raw async node for exactly this; `program_node` is sync-only). Reproduced in isolation: a sync
  write on the loop FAILS in ~5s, `to_thread` SUCCEEDS in ~0.25s. **Complementary (necessary, not sufficient):**
  WAL + a `busy_timeout` on *both* the checkpointer connection (`runtime/checkpoint.py`) and every `Database`
  connection so writers serialize with bounded waiting rather than erroring. WAL/busy_timeout alone did NOT fix it
  (only reduced the flake) — the loop-starvation deadlock is the real issue. Reads (WAL) don't take the write lock,
  so validator/read nodes can stay sync.
- **Pin ruff in EVERY repo that runs `ruff check` in CI (16-08 recurrence of the 16-02 lesson).** The pin was applied to
  genesis but NOT genesis-core; the first time genesis-core's CI re-ran (its first release since ruff drifted), the
  unpinned `ruff>=0.6` flagged **44 pre-existing `UP037`** ("remove quotes from type annotation") findings and failed an
  otherwise code-clean release. Local `ruff check genesis_core` (pinned venv ruff) passed, hiding it. Fixed by pinning
  `ruff==0.15.20` in genesis-core too. Rule: any repo with `ruff check` in `.gitlab-ci.yml` pins ruff to the
  locally-verified version.
- **MCP introspection must allow a large `tools/list` line (16-08).** `genesis_core.mcp.introspect` reads
  newline-delimited JSON-RPC via `asyncio` stream readers whose default line limit is **64 KiB**. The Appian **Dev MCP
  returns 145 tools in one `tools/list` line** (well past 64 KiB) → `ValueError: Separator is not found, and chunk exceed
  the limit`. Fixed by spawning with `limit=8 MiB`. Any server with a big tool surface hits this — Settings "Test
  connection" / allowlist introspection would fail on the Dev MCP without the bump.
- **Managed-native launch vs. env-resolution boundary (16-08, ADR-038).** `NativeMcpInstaller.active_launch_spec` returns
  the **binary location only** (command/args from the installed per-server venv); the `${VAR}` env template stays on the
  `mcp-registry.json` entry and is resolved by `McpRegistry` (SecretProvider→Env→os.environ) exactly like every other
  server — so the installer never touches secrets and updating the binary needs no registry edit. The Dev/DevOps **URL**
  vars (`LCP_URL`, `APPIAN_DOMAIN`) resolve from the **dev-tagged** env via `EnvironmentRegistry.resolve_var` (not the
  per-run active env), so Chat and workflows both reach the single Phase-16 target.
- **The genesis `frontend` CI job only runs on `changes: [web/**/*]` (16-08).** A release that lands web changes in one
  tag but ships a follow-up tag touching no web (e.g. a pin/version bump) will NOT re-run the stale-bundle guard. If a
  **transient CI infra failure** (e.g. a Gitaly `HTTP 500` at the git-fetch step, seen on the v0.31.0 pipeline) kills the
  frontend job on the web-changing tag, re-trigger it with a real `web/**` touch (`glab` can't retry — read-only token) —
  don't assume a later green pipeline covered the guard.
- **Match the real Appian Deployment REST contract for the export — read the vendor's own client, don't guess (16-07 live fix).**
  `sync-application`'s export was hand-rolled to a guessed endpoint (`POST …/deployments/export`, JSON body) and **405'd**
  against the live env. The authoritative reference is the **installed DevOps MCP** (`appian-deployment-mcp`): export is a
  **multipart `POST /suite/deployment-management/v2/deployments`** with an **`Action-Type: export`** header + a `json` part
  `{uuids, exportType, name}`; poll `GET /deployments/{uuid}` to `COMPLETED`; download the poll response's **`packageZip`**
  URL; auth header **`appian-api-key`**. Lesson: when hand-rolling a vendor REST call, read the vendor's client rather than
  guessing, and add a request-shape regression test (a permissive stub hides a 405).
- **De-dupe KB objects by UUID — real exports repeat UUIDs (16-07 live fix).** A real Appian export can list the **same
  `object_uuid` more than once**, so a baseline `KbStore.apply` hit `UNIQUE(app_uuid,object_uuid,valid_from_sync)`. Fix:
  `apply` de-dupes objects by UUID (edges by their `(source,target,dep_type)` triple), keeping the first; and the
  workflow's baseline `check_kb` reconciliation is **`0 < written ≤ parsed`** (distinct ≤ raw), not `==`. Synthetic
  fixtures had unique UUIDs and hid this — validate against a real package (verified on a live 2516-object app).
- **A newly-released library workflow must be `genesis install`-ed before it can run — and a missing workflow must not
  500 (Phase 17-05 live).** `run_manager.start(workflow_id, …)` raises if the workflow isn't in the local library
  (`~/.genesis/library`); the `business-map/generate` endpoint surfaced that as a bare **500 "Internal Server Error"**.
  After releasing a workflow in genesis-workflows, run `genesis install --from ../genesis-workflows` (the running
  `genesis serve` picks up the new workflow at run-start — no restart needed; only a *server-code* change needs a
  restart). The endpoint should catch the load failure and return a friendly 409/400 ("install the workflow library")
  — tracked in 17-06.
- **Rendering a real graph needs level-of-detail, not `fitView`-to-fit (Phase 17-05 live).** `fitView` crammed a
  14-node value stream into a short pane → unreadably tiny nodes with most off-screen and no cue to pan ("the data
  looks minimal"). What made it usable: a **readable zoom floor** (`fitViewOptions.minZoom ≈ 0.4–0.55`) + a **MiniMap**
  + pan + wider dagre spacing; **click-for-detail popups** so node cards stay compact instead of truncating text; a
  **manual radial** layout (not dagre) for a domain→capabilities *constellation* to avoid a shared-entity crisscross,
  with entities shown as **chips inside** the capability card rather than separate crisscrossing nodes; and
  **`smoothstep`** edges + arrowheads so branch/loop paths don't overlap. Note: React Flow renders a custom node only
  when `node.type` matches a `nodeTypes` key — a default node renders `data.label` (which business nodes don't set →
  blank), so a `nodeTypes` mismatch looks like "empty nodes".
- **Parser dependency extraction must scan EVERYTHING, and "orphan" ≠ "unbundled" (Phase 18).** `genesis-appian-parser`
  (ported faithfully from Atlas) reported **804 orphans / 30.7%** on a real app, **803 provably false**. Two root causes,
  both inherited: (1) reference extraction was **field-path-scoped** (`SAIL_CODE_FIELDS`/`STRUCTURAL_FIELDS` had **no
  entries** for Constant/AI-Skill/Decision/Translation-String/Document → those types emitted **zero** edges); (2)
  `is_orphan` meant *"not reachable from an entry-point bundle"*, which mislabels used-but-unbundled objects. Fixes that
  took edge recall 0.32→**0.98** / orphans 804→**0**: run dep analysis on **RAW** data (before the resolver rewrites
  `#"_a-uuid"`→`rule!Name`); a **universal known-UUID scan over every string + the raw XML** (transient, still code-free
  per ADR-037) so no reference form/field/type is missed; add record-action + translation-string URNs, CDT **QName**
  (`{urn:…}Type`) refs, and `rulereferencebyname("X")` by-name refs; and **redefine `is_orphan` = disconnected (no
  incoming AND no outgoing edges)**. Keep the scan **known-UUID-gated** for precision (0.999).
- **An Appian prefixed id `_a-<base>_<suffix>` shares its base with folder-siblings — base is a GROUP id, not an object
  id (Phase 18).** Resolving a reference by base UUID alone over-links to an arbitrary sibling (precision cratered
  0.999→0.80 when tried). Match on the **full or canonical (`_a-<base>_<numericSuffix>`)** id; only use base when it is
  **unique** across the package. The accuracy **oracle** has the same trap — and must attribute each file to its object
  by **filename stem** (universal: every object file is `<uuid>.xml`), NOT the in-XML `<uuid>` (a child for content
  objects, a root `uuid="…"` attribute for the rest — 1,386 files were mis-mapped, which falsely showed precision 0.41).
- **APPREF/ENTRYPOINT is a by-name cross-app integration mechanism (Phase 18, user-taught).** Apps soft-integrate across
  environments via `rulereferencebyname(ruleName:"AS_GSS_ENTRYPOINT_…")` — a **name string**, not a UUID, with the peer
  usually in a *different* package (so the object has no in-package incoming edge and looks orphaned). Classify these via
  the ENTRYPOINT/APPREF naming convention (+ the 10-value category taxonomy GETDATA/DISPLAY/STARTPROCESS/RECORDACTION/
  LOGIC/URL/SAVE/APPVERSION/REF/AI, adopted from Jarvis) + behavioral (`rulereferencebyname` caller); **exempt them from
  orphan reporting** and surface them as cross-app integration points (`integration_role`/`integration_peer`/
  `integration_category` in `KbObject.metadata`, + a `stats.cross_app` app-level map ported from Atlas
  `app_cross_app_builder`).
- **When porting a parser front-half, you may silently drop whole layers — diff against the source (Phase 18).** Our port
  dropped Atlas's `output/app_cross_app_builder.py` (cross-app), `output/graph_builder.py` (inbound/outbound + is_hub),
  and the entire `enrichment/` package. A concept-by-concept inventory of BOTH reference implementations (Atlas on disk +
  indexed; the Jarvis plugin decompiled with `javap` — macOS `strings` misreads Java `0xCAFEBABE` as a Mach-O fat
  binary, so use `javap`/a constant-pool reader) is the way to get "best of both". Matrix in `specs/phase-18-*.md` §9.
- **A repository list method must populate the SAME derived fields its single-get promises (Phase 19 live fix).**
  `DocumentStore.get_document` attached `linked_apps`, but `list_documents` returned raw rows without it — the web table read
  `d.linked_apps.length` and crashed (`Cannot read properties of undefined (reading 'length')`) the moment a real (non-mocked)
  list was rendered. The unit test's fixture happened to include `linked_apps`, so it hid the gap ("the stub hid the contract"
  again). Fix: `list_documents` populates `linked_apps` for every row in ONE grouped query; the frontend also reads
  `(d.linked_apps ?? [])` defensively; the API test asserts the field is present. Lesson: derived/joined fields belong in the
  list method, and API tests must assert the shape the UI depends on — don't let the mock be more generous than the backend.
- **Google-native export → converge on the binary parser; auto-sync on add (Phase 19).** A Google Sheet is exported to **.xlsx**
  (not CSV) so `openpyxl` gives per-tab structure, and Docs→`text/markdown`, Slides→`text/plain` — every Google-native doc then
  flows through the *same* `parse_document` used for uploads (no separate Google parser). Uploads parse **synchronously at add**;
  a Drive add only registers the file, so the add endpoint **auto-starts a single-doc `sync-documents` run** (best-effort — the
  content otherwise wouldn't appear until a manual sync). The document viewer must be **full-width with `overflow-x-auto`** (a
  wide spreadsheet's Markdown table overflows a fixed-width card).
- **An agent that must AUTHOR files needs BOTH cwd=sandbox AND the fs tool trusted — and know that fs writes vs tool
  permissions are separate gates (Phase 20, two live fixes).** Reusing the read-only chat setup for the spec-authoring
  `feature_spec` session broke agent file writes twice. (1) **cwd mismatch:** cwd was `state_dir` but `fs_write_root` was the
  per-session sandbox, so the agent's relative `spec.html` resolved outside the sandbox → the SDK's `fs/write_text_file`
  handler refused it. Fix: set **cwd = the sandbox** for `feature_spec` (so a relative write lands in-sandbox, where the
  milestone save also reads it). (2) **permission vs capability:** in the SDK, `fs/write_text_file` is gated ONLY by
  `allow_fs_write`+`fs_write_root` (NOT `permission_mode`), while `session/request_permission` (untrusted **tools**) is what
  `auto_deny` rejects. kiro-cli asks permission for its built-in **`fs_write` tool** before writing, so `auto_deny` denied it
  upstream of the sandbox. Fix: **trust `fs_read`/`fs_write`** for `feature_spec` (the write is still confined by
  `fs_write_root`; every other tool — shell, MCP mutations — stays untrusted → denied). Ground truth came from the SDK's
  `client.py` + `test_permission_policy.py`, not the agent's self-diagnosis (it mislabeled a sandbox refusal as "prompt
  declined"). Lesson: read the SDK's actual permission model; the two gates are independent.
- **Give a CLI agent bulk context as FILES in its workspace, not as chat content (Phase 20).** "Add context" first dumped each
  document's full Markdown into the transcript (as a system message) — token-heavy every turn and it cluttered the chat. Better:
  write the docs as files under the session's `./context/<id>-slug.md` (the agent's cwd/sandbox) and post only a short note
  naming them; the Kiro agent reads them **on demand with its file tools**. There is no ACP "attach documents" wire param for a
  chat session (unlike `mcpServers`), so files-in-cwd is the idiomatic, efficient mechanism — and it composes with the
  cwd=sandbox fix above.
- **Embedding a 3rd-party browser SDK: prefer `postMessage`-host reuse over running its server (Phase 20, ADR-043).** Lavish's
  injected `artifact-sdk.js` talks only via `parent.postMessage` (no server calls), so we vendor two source files, bundle them
  with our own esbuild, serve the artifact + SDK **same-origin** from the API, host it in a **sandboxed iframe** (`allow-scripts`,
  no `allow-same-origin`), and let our React chrome be the host — no second window, no `:4387` server, no Node-≥22. Theme it via
  the vars it already exposes on its shadow `:host` (a one-line patch → `var(--lavish-*, fallback)`), fed from Genesis tokens.
  Keep a golden `postMessage`-schema fixture so an upstream bump can't silently change the contract.
- **The Kiro ACP extension surface is richer than the public docs — spike the *installed* CLI, and prefer typed methods over
  `execute` (Phase 21).** Against **kiro-cli 2.16.2** (the 21-01 spike): the **model list + agents come free on `session/new`**
  (`result.models` = `{currentModelId, availableModels[]}`, `result.modes` = agent personas) — no separate call, no Settings
  fallback; **`session/set_model`/`session/set_mode`** are plain requests. The **slash-command catalog** arrives as the
  `_kiro.dev/commands/available` **notification** (calling it as a request → -32601), carrying `commands` + `prompts` + `tools`.
  The advertised per-command `optionsMethod` (e.g. `_kiro.dev/commands/model/options`) is **NOT wired** in 2.16.2 (-32601) →
  do **autocomplete client-side** off the catalog. **`_kiro.dev/commands/execute` streams** its output and a `panel` command may
  not return a terminal result headlessly (it times out) → treat it as a streaming turn (bound it with a `command_timeout`) and
  keep **sending the slash text through the normal prompt path as the fallback**. `contextUsagePercentage` (already captured for
  metering) + `promptCapabilities.image` are present. Lesson: these `_kiro.dev/*` extensions are experimental — pin the verified
  CLI version in the findings, keep the SDK methods additive/no-op when the peer doesn't advertise, and don't trust the docs'
  version over what the installed binary actually answers.
- **Exposing the CLI surface in a "read-only" chat = refine the ADR, keep the human-confirm backstop (Phase 21, ADR-045).**
  Broadening chat to the full command/model surface makes it no longer categorically read-only (ADR-031). The safe move was
  **not** to trust-all, but to keep the default trust set read-only + `permission_mode="ask"` so any write-capable tool a
  command triggers still raises the Phase-13 confirm card; introspection commands run freely. Consciously recorded as ADR-045
  (refines ADR-031) rather than silently widened.

---

## 8. How to work on ANY task (the loop)

1. **Understand + restate.** State your understanding of the task, which layer(s)/repo(s)/files it touches, and any ADR that applies. Read the relevant spec's "current state" citations and the cited code FIRST — don't guess. For a broad investigation, delegate to a sub-agent to preserve context.
2. **Verify against real code.** For a bug, write a failing test/repro first. For a feature, confirm the backend/API/types already support it (or plan the additions).
3. **Change in the smallest correct scope.** Match existing style/patterns and reuse existing primitives. Don't refactor unrelated code.
4. **Test.** pytest for backend/core; Vitest for web. For bugs, add a regression test that would have caught it — and if a stub hid the bug, fix the stub to mirror reality. Add jest-axe for new interactive UI.
5. **Run all affected gates until green:** backend `pytest` + `ruff`; web `lint` + `tsc` + `vitest`. For web changes, also `npm run build` and **commit the updated `web/static/`** (the stale-bundle guard requires it).
6. **Release (if a code repo changed):** bump version(s) + tag + push + update dependent pins; verify CI green via `glab`. Frontend-only genesis changes still ship a genesis release.
7. **Document:** update `tracker.md` §6 + a `progress/` doc (and the spec/README status tables); push
   project-tracker. **Also refresh THIS doc (`AGENT_ONBOARDING.md`)** when tags/architecture/ADRs/
   hard-won lessons change — §2 (state + tag table + test counts), §4 (map), §5 (ADRs), §7 (lessons),
   §9 (roadmap), and the "Last refreshed" header. Keeping the bible current is part of Definition of Done.
8. **Report with cited evidence** (test output, run ids, CI pipeline ids, file diffs). Be honest about what you verified vs. couldn't — live Kiro/MCP/browser steps can't be driven headlessly; say so and give the manual check.

**When the task is planning/analysis** (not "make this change"): respond with the plan/analysis and, if asked, write it as a spec + update the phase docs — but do NOT start implementing until asked.

---

## 9. Roadmap & backlog (what's next — context, not an assignment)

### ✅ SHIPPED (COMPLETE) — Phase 21: Feature Workspace, Spec-Builder UX & Chat Parity (genesis v0.46.0 + genesis-core v0.9.3 + kiro-agent-sdk v0.7.0)

> **As-built: `progress/phase-21-feature-workspace-and-chat-parity.md`.** A **Phase-20 live-feedback pass** — after the user
> used Features + the Spec builder, three themes: **(A)** the feature page becomes a proper **workspace**, **(B)** the spec
> builder becomes **chat-first**, and **(C)** the reused chat reaches **Kiro CLI/ACP parity**. **ADR-044** (a feature = a
> pipeline of artifact stages, each with its own status) + **ADR-045** (chat mirrors the CLI/ACP surface; **refines ADR-031** —
> introspection free, write-actions human-confirmed via the Phase-13 bridge). Release chain: **kiro-agent-sdk v0.7.0** →
> **genesis-core v0.9.3** (SDK pin) → **genesis v0.46.0**; all CI green.
>
> **Shipped (21-01..21-07):**
> - **21-01 ACP parity spike** — `spike/2026-08-12-acp-parity.md`; verified the surface vs **kiro-cli 2.16.2** (models+agents on
>   `session/new`; commands as a notification; autocomplete client-side; `execute` streams; `contextUsagePercentage` + image cap).
> - **21-02 feature workspace** — `web/features/features/ArtifactPipeline` (Spec **Edit**→builder / **View**→read-only preview
>   via `artifact?annotate=0`; Design/Breakdown disabled placeholders); builder split to `…/features/:id/spec`; feature card
>   drops the spec status. **ADR-044.**
> - **21-03 spec-builder UX** — full-width `ChatThread` (`chrome="spec"` — no copilot banner) + a full-screen annotatable
>   **Preview** popup (the doc + **our own comment-queue rail** + one **Send-all**); **`feature_spec` sessions excluded** from the
>   main Chat list (`ChatStore.list(exclude_modes=…)`).
> - **21-04 SDK ACP extensions** — kiro-agent-sdk **v0.7.0**: `SystemInit` models/modes/commands; `set_model`/`set_mode`;
>   `execute_command`; `prompt(images)`; `on_commands`/`on_session_status`.
> - **21-05 chat parity** — **m0011 `chat_sessions.model`**; `ChatManager` model-at-creation + `ensure_agent_catalog` +
>   slash-`execute_command` routing + clear/compact + images; `api/chat` `/chat/{models,commands}` + `…/{model,clear,compact}` +
>   `SendMessage.images`; `Composer` parity toolbar (model select + context meter + Clear/Compact) + **Commands** palette
>   autocomplete + image attach — **both** the main chat and the spec builder. **ADR-045.**
> - **21-06 chat transcript export** — `chat/export.py` + `GET …/export.md` (Markdown, includes tools + thinking); an Export
>   link in the shared chat toolbar. (PDF deferred → browser print only.)
> - **21-07 release** — the chain above; ADR-044/045 Accepted; docs + this bible refreshed.
>
> **Gate:** genesis **409** pytest + **150** Vitest; genesis-core **65**; kiro-agent-sdk **93**; ruff/eslint/tsc clean; CI green.
> **Live acceptance** is user-driven (restart `genesis serve` to load the new server code + the v0.7.0 SDK). **PHASE 21
> COMPLETE.** (Optional future polish: mid-conversation model switch; slash-command argument entry; the sequential card-unlock
> once Design/Breakdown exist; a spreadsheet-grid preview.)

### ✅ SHIPPED (COMPLETE) — Phase 20: Features & Spec Authoring (genesis v0.45.0)

> **As-built: `progress/phase-20-features-and-spec-authoring.md`.** An Appian application gains first-class **Features** (the
> unit of work an engineer develops), and inside a feature a conversationally-authored, annotatable **Spec** — the first of
> what will grow into design docs / user stories on the **feature page**. **ADR-042** (Features & Specs as first-class app
> sub-entities; Chat-authored — ADR-001 intact; HTML-authoritative; draft→in-progress→in-review→completed) + **ADR-043** (embed
> the vendored MIT **Lavish** annotation SDK). **genesis-only release; genesis-core/genesis-workflows unchanged.**
>
> **Shipped (all CI green; ADR-042/043 Accepted):**
> - **20-01 embed spike** — `spike/2026-08-11-lavish-embed.md`; proved the Lavish SDK embeds (postMessage-only, esbuild-bundled,
>   user-confirmed round-trip) + captured the theming seam.
> - **20-02 data model** — **m0010** (`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`, schema v10) + `FeatureStore`
>   (untrack cascades features — intrinsic-to-app).
> - **20-03 features surface** — `api/features.py` (feature CRUD + spec create) + **Features** tab + **feature page**
>   (`/applications/:uuid/features/:featureId`) + Create-spec empty state.
> - **20-04 spec chat** — a bound **`feature_spec`** Chat session (additive mode; `genesis-kb` auto-wired) seeded with the
>   app/feature identity; **Add context** (the app's linked business artifacts); milestone snapshots + status.
> - **20-05 embedded review** — vendored Lavish SDK (`api/assets/lavish/`, Genesis-themed) served same-origin; `SpecWorkspace` =
>   reused `ChatThread` + sandboxed review iframe + the postMessage **annotation→chat bridge** + Export-`.md` (`markdownify`).
> - **20-06 release** — genesis **v0.45.0**, CI green; ADR-042/043 Accepted.
>
> **Live-accepted** (create feature → the spec chat authors `spec.html` → annotate a passage in the embedded review → the
> comment flows into the chat → the agent revises). **Two live fixes** folded in (see §7): the `feature_spec` **cwd = the fs
> sandbox**, and **trusting `fs_read`/`fs_write`** (kiro-cli's built-in `fs_write` tool was being auto-denied). Context is
> delivered as **`./context/` files** the agent reads on demand (not dumped into the transcript). **PHASE 20 COMPLETE.**
> (Optional future polish: multiple specs per feature + templates; design-docs / user-stories tabs; the Mermaid-as-Excalidraw
> whiteboard; a durable per-session identity preamble so it survives long-conversation cold-starts.)

### ✅ SHIPPED (COMPLETE) — Phase 19: Genesis Document Library (genesis-core v0.9.2 + genesis v0.44.0 + genesis-workflows v0.9.3)

> **Handoff — as-built: `progress/phase-19-document-library.md`.** Attach the business documents that
> describe an application (the PDFs/Word/Excel/Google Docs in Google Drive) to Genesis, parse them to LLM-consumable Markdown
> (+ JSON for tabular), and use them **alongside the Appian KB** for spec generation / design discussion. Documents are a
> **global first-class store** (`kb_documents`, one row per unique doc, dedup by Drive file-id / upload hash) **linked into apps**
> (`kb_document_links`); **untrack unlinks, never deletes** (**ADR-041**). Google Drive is reached via the **Google Workspace CLI
> (`gws`)** integrated as a **managed-native CLI connector** (**ADR-040**, the CLI analog of the native Appian MCP — single
> static binary, no `uv`): Genesis owns an **isolated** config dir (`~/.genesis/cli-tools/gws/config`, file keyring, its own
> `gws auth login`) and **reads the OAuth client** from the dotfiles-provisioned `~/.config/gws/client_secret.json` — **ships no
> token**; the dotfiles setup is a documented prerequisite. Read-only Drive/Docs/Sheets/Slides scopes only.
>
> **Shipped (all CI green; ADR-040/041 Accepted):**
> - **19-01 spike** — `spike/2026-08-11-gws-oauth-and-export.md` (live-verified).
> - **19-02 managed-native `gws` connector** (genesis-core v0.9.2 `CliRegistry` resolution + genesis `NativeCliInstaller`/`gws`
>   seam/login/`api/native_cli.py`/`genesis cli` + genesis-workflows `cli-registry.json`); live isolated-login smoke test passed.
> - **19-03 data model** — m0009 (`kb_documents`/`_links`/`_sections`, schema v9) + `DocumentStore` (untrack unlinks-not-deletes).
> - **19-04 parsing** — `kb/doc_parsing.py` (PDF/DOCX/XLSX/CSV/MD/TXT → Markdown + per-tab JSON + sections); deps pinned
>   `pypdf==6.15.0`/`python-docx==1.2.0`/`openpyxl==3.1.5`; Google-native export→binary/text convergence.
> - **19-05 sync** — `DocumentSyncEngine` (`ctx.extras['document_sync']`) + the deterministic **`sync-documents`** workflow
>   (async `to_thread` write) + `api/documents.py` (upload/gdrive add [auto-syncs Drive docs], link/unlink, sync single|app|
>   library with friendly 409, list/search/get/delete).
> - **19-06 consumption** — `genesis-kb` MCP `list/get/search_documents` (auto-trusted in chat) + `build_evidence_pack` includes
>   linked docs as bounded excerpts (document-aware `design-doc`/`generate-business-map`).
> - **19-07 web** — Document Library page + **full-screen document viewer** (`/documents/:id`, full-width + overflow scroll) +
>   per-app **Business Artifacts** tab (add upload/drive/**multi-pick**, unlink/sync) + Settings→CLI **gws connector card**.
> - **19-08 release** — genesis-core **v0.9.2** → genesis **v0.44.0** → genesis-workflows **v0.9.3**, all CI green; ADR-040/041
>   flipped to **Accepted**. **Tests:** genesis 375 pytest + 138 Vitest · genesis-core 65 · genesis-workflows 75 + validate_library.
>
> **Live-accepted:** a real Google Drive doc (incl. an .xlsx) added → auto-synced via `gws` export → parsed → viewed in the
> full-screen viewer. **PHASE 19 COMPLETE.** (Optional future polish: a spreadsheet-grid view from `tables.json`; a scheduler
> for periodic document sync; semantic/pgvector document search — an ADR-030 trigger.)


### ✅ SHIPPED (COMPLETE) — Phase 18: Appian Parser Accuracy Overhaul (genesis-appian-parser v0.2.0 + genesis v0.40.0 + genesis-workflows v0.9.2)

> **Fixed a catastrophic dependency under-linking bug in `genesis-appian-parser`.** A real 2,620-object app reported
> **804 orphans (30.7%), 803 provably false** — objects genuinely referenced by expression rules / interfaces /
> constants. Root cause (inherited from the Atlas port): field-path-scoped reference extraction (no Constants / AI Skills
> / Decisions / Translation Strings / Documents) + `is_orphan` = "not bundled" rather than "unreferenced". Reverified
> against real XML + the original **Atlas** parser + the **Jarvis** plugin (best-of-both; §9 decision matrix in the spec)
> and drove accuracy **>95%**, verified by a committed **raw-XML reference oracle** + a **≥95% CI gate**: edge recall
> **0.324 → 0.978**, precision **0.999**, referenced-object recall **0.869 → 1.0**, **orphans 804 → 0**, false-orphan
> rate **0.311 → 0.0**, edges 5,084 → 10,617, **12 cross-app integration points**. Also delivered the user's
> **APPREF/ENTRYPOINT** cross-app integration-point model (by-name `rulereferencebyname`, ENTRYPOINT/APPREF naming +
> 10-category taxonomy, orphan-exempt, `integration_*` metadata + `stats.cross_app`). **Live-validated on the user's real
> app** (delete + re-add baseline sync; the venv's editable parser install picks up main without a `genesis serve`
> restart — parsing runs in a fresh subprocess worker). Delivered **18-01..18-05** on `genesis-appian-parser` main
> (afcb66d/31567fa/a357db6/c86b20c/44472c4); suite 13 → **25** green, ruff clean. **18-06 SHIPPED:**
> `genesis-appian-parser` **v0.2.0** (05d0fea) → repin `genesis` **v0.40.0** (8477945) → `genesis-workflows` **v0.9.2**
> (79edb75), all CI green (a fresh `sync-application` baseline/delta recomputes the accurate graph into the KB).
> **Deferred:** a **Tempo Report** parser + **generic-haul fallback** (need a package containing those types), richer
> per-type golden fixtures, Jarvis `orphanCluster` + `TagDetector` behavioral tags (a future Business-Map capability
> signal). Specs: `specs/phase-18-parser-accuracy.md`; as-built: `progress/phase-18-parser-accuracy.md`. **PHASE 18
> COMPLETE.**

### ✅ SHIPPED (COMPLETE) — Phase 17: Business Application Map (17-01..17-06; genesis v0.39.0 + genesis-workflows v0.9.1)

> **Agent-synthesized, business-language map of what an application does end-to-end** — **(A)** value stream(s) + **(B)**
> capability constellation — explicitly **NOT** a technical/object/bundle view (the user's hard steer: no objects, bundles,
> pages, or properties; those terms are **banned** from the output). Business meaning is *derived*, not parsed, so it is
> produced by a new **deterministic `generate-business-map` LangGraph workflow** with narrow **agent** nodes (ADR-001)
> wrapped by the reliability trio (ADR-011); **evidence-grounding + coverage + business-language** validators make it
> un-hallucinated (every business element cites real KB object UUIDs) + a HITL review gate. Reads the **code-free KB only**
> (via `genesis-kb`/`KbStore` — no env round-trip), emits a versioned **`BusinessModel v1`** persisted in **m0008
> `kb_business_maps`** (code-free, point-in-time, stale-on-sync); the web renders A+B on the existing **@xyflow/react +
> dagre** stack with focus+context linking. **Specs:** `specs/phase-17-business-application-map.md` (umbrella) +
> `phase-17-business-application-map/business-model-contract.md` + `17-01..17-06`; **ADR-039** (Proposed). **Release chain
> when built:** genesis (m0008 + KbStore + evidence extractor + API + web) → genesis-workflows (workflow + catalog);
> genesis-core likely unchanged. **Backend (17-01 persistence/m0008 + 17-02 evidence pack + 17-04 API) SHIPPED in
> genesis v0.35.0; the deterministic `generate-business-map` workflow (17-03) SHIPPED in genesis-workflows v0.9.0
> (2 Kiro agent nodes + reliability trio + evidence-grounding/coverage/business-language validators + escalate/review
> gates). The web **Business Map view** (17-05 — React Flow **A** value stream + **B** capability constellation,
> first tab, click-for-detail popups, focus+context linking) SHIPPED and was **exercised live**: the first real
> generation against the 2,763-object "AS GSS Full Application" produced a rich, high-quality model (10 capabilities /
> 10 entities / 14-stage value stream, 2 decision branches) — readability iterations followed in **genesis v0.37.0**
> (readable zoom + MiniMap + radial constellation) and **v0.38.0** (detail popups + smoothstep edge routing). NEXT =
> **17-06** shipped the hardening: (a) a **friendly 409 "workflow not installed"** on generate instead of a 500 (a
> newly-released library workflow must be `genesis install`-ed first — genesis v0.39.0); (b) **recalibrated the coverage
> floor 0.6 → 0.3** — coverage is a lenient "is the map non-trivial" signal (a good map abstracts heavily), the human
> **review gate** is the real backstop (genesis-workflows v0.9.1). **Live-acceptance PASSED** — the first real map read
> as a coherent business story with no technical vocabulary. **PHASE 17 COMPLETE.** (Optional future polish: richer
> golden-fixture harness; per-value-stream layout tuning.)**

### ⭐ ACTIVE (IN PROGRESS — planning complete + pushed; 16-01/16-02/16-03/16-04/16-08 + **16-05 (server + chat)** shipped, **16-05b (workflow cutover) + 16-07 next**) — Phase 16: Appian Knowledge Base ("Atlas-into-Genesis")

> **Handoff for the next session:** planning is complete AND implementation is under way. Read
> `specs/phase-16-appian-knowledge-base.md` (umbrella) + `phase-16-appian-knowledge-base/16-01..16-08` +
> `genesis-kb-tool-contracts.md`, ADR-036/037/038, and `progress/phase-16-04-applications-surface.md` +
> `progress/phase-16-08-native-mcp.md`. **Shipped so far:**
> **16-01** = `genesis-appian-parser` **v0.1.0** (`parse(zip|bytes) -> KbParseResult`, code-free); **16-02** = genesis
> **v0.28.0** (m0007 `kb_*` + `KbStore`); **16-03** = the **`sync-application`** workflow (genesis **v0.29.1** +
> genesis-workflows **v0.8.2**); **16-08** = the dev-env `is_dev` toggle (§2.0, genesis **v0.30.0**) + the
> **managed-native Dev/DevOps MCP installer** (Stage B: genesis-core **v0.9.1** + genesis **v0.31.1** +
> genesis-workflows **v0.8.4**); **16-04** = the **Applications surface** (genesis **v0.32.0**); **16-05** = the
> **`genesis-kb` MCP server + CHAT cutover** (genesis **v0.33.0**); **16-07 Option A** = the **`sync-application` delta
> path** (re-export + SCD-2 delta-merge, genesis-workflows **v0.8.5**) — all CI green.
> **Next: 16-05b** (cut `erd-generation` + `design-doc` off `appian-atlas` → `genesis-kb`; blocked on Section-C schema +
> 16-06 versioning + Jarvis→Dev-MCP — `appian-atlas` RETAINED for them meanwhile) **+ the 16-07 remainder** (true
> incremental delta via a new Appian changed-objects API [the Dev MCP can't back it], scheduler, per-release changelog).
> **📋 See `specs/backlog/phase-16-deferred.md` for the full deferred register.** Keep extending `tracker.md` §6 as you go.

**Goal.** Move the Appian knowledge base *inside* Genesis and make Genesis an agentic Appian-development environment.
Stop calling external **Atlas** (GitLab-served pre-parsed KB) / **Jarvis** (in-Appian KB) as services; reproduce their
*knowledge* surface locally and route every *environment* call through the native **Dev MCP / DevOps MCP**.

**Architecture (decided):**
- **`genesis-appian-parser`** — a NEW pinned repo: port the Atlas parser's front-half (unzip → type-detect → 15 object
  parsers → UUID/URN resolution → dep-graph → entry-point **bundles** → diff-hash) into a Genesis-owned, stdlib-only
  package that emits an **in-memory `KbParseResult`** — **no source code persisted**, no file output. (Atlas parser repo
  `appian/prod/solutions-atlas-parser`; KB repo `appian/prod/solutions-atlas-kb` with `sync_packages.py`; Atlas MCP
  `appian/prod/solutions-atlas-mcp-server` — all read via `glab`.)
- **KB in `genesis.db`** — migration **m0007**, `kb_*` tables, a **temporal SCD-2** model (objects/edges validity-ranged
  by sync) + `kb_bundles`(+`flow_json`) + `kb_releases`; **cross-app queryable**; **NO code**.
- **`sync-application` LangGraph workflow** — deterministic **REST export** (Appian Deployment API in a program node — no
  agent, no credits) → parse → SCD-2 merge → recompute bundles → record sync.
- **Applications page** (`kb_applications`, `/api/applications*`) — tag one env as **dev** (`is_dev` toggle, single-select,
  in the existing Environments registry — supplies URL + creds for all Phase-16 auth; 16-08 §2.0) → list its apps via Dev
  MCP → **Add** an app → baseline sync → status/releases.
- **`genesis-kb` MCP** — Genesis-owned read-only stdio server (like `introspection_server`), serving the KB; **cuts
  chat / erd-generation / design-doc off the external `appian-atlas`** onto it (the "KB swapped, functionality
  preserved" milestone). `get_object_code` fetches SAIL **live via the Dev MCP**.
- **Native MCP integration (16-08)** — the Dev MCP (`lcp-mcp-server`) + DevOps MCP (`appian-deployment-mcp`) installed as
  **managed, versioned, updatable** local servers (bundles the user placed at `artifacts/mcp-servers/`); **updatable
  without forking** (manual drop-in — the operator installs a new bundle; Genesis versions it + keeps the prior for
  rollback; no auto-fetch source — 2026-08-05).
  **Connectivity foundation (16-08 §2.0, build FIRST):** a single-select **`is_dev` toggle** on the Environments
  registry — the registry may hold many envs, exactly one is tagged **dev**, and that env's URL + credentials feed all
  Phase-16 auth (REST export, Dev MCP, DevOps MCP, changed-objects API); no dev env ⇒ fail fast + a "Test connection".

**Scope decisions (2026-08-04, from a full Atlas(34-tool)+Jarvis(50-tool) audit — see `genesis-kb-tool-contracts.md`):**
- **Iteration 1 = 16 read-only KB tools** (Section A / Tier-1): `list_applications`, `get_app_overview`,
  `search_objects`, `get_dependencies`, `get_object_detail`, `get_entry_points_for_object`,
  `get_dependents_batch`/`get_precedents_batch`, `get_shared_objects`, `search_bundles`, `get_bundle`, `list_orphans`,
  `get_orphan`, `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects`, `get_object_code` (live).
  Return shapes **mirror the Atlas MCP** for a lossless cutover.
- **Versioning (6 Version tools + release tagging + point-in-time) = BACKLOG (16-06)** — gated on Dev MCP **AP-62096**
  ("Object version viewing/comparison", Code Review, **26.8 GA / 2026-08-28**; underlying version-UUID plumbing AP-51279
  is Done). Schema kept version-ready (additive) so it lands code-only later.
- **Schema/DDL/data-gen (7+2 tools) = DEFERRED (Section C).** **Write/deploy (Section E) = OUT.** **Documents/git-content/
  pipeline-refresh (Section F) = OUT.** **Live-env reads (Section D) = via Dev/DevOps MCP only.**
- **Governing principle:** *knowledge fetch → internal `genesis-kb`; any environment call → Dev/DevOps MCP.* Read-only
  against Appian throughout (Dev MCP read-only allowlist; DevOps export/status/download only).

**Sub-phases (all in `phase-16-appian-knowledge-base/`; iteration-1 unless noted):** 16-01 parser (new repo) **✅ v0.1.0** ·
16-02 schema+`KbStore` (m0007) **✅ genesis v0.28.0** · 16-03 sync workflow (baseline) **✅ genesis v0.29.1 + genesis-workflows v0.8.2** · 16-08 native MCP integration (§2.0 dev-env toggle **✅ genesis v0.30.0**; **Stage B installer ✅ genesis-core v0.9.1 + genesis v0.31.1 + genesis-workflows v0.8.4** — 16-08 COMPLETE) · 16-04 Applications surface **✅ genesis v0.32.0** · **16-05 `genesis-kb` MCP server + CHAT cutover ✅ genesis v0.33.0**
(workflow cutover split to **16-05b ◀ NEXT** — `appian-atlas` retained for erd/design-doc until Section-C schema + 16-06)
· 16-07 delta refresh **✅ Option A (re-export + delta-merge) genesis-workflows v0.8.5** (true incremental delta via a
new Appian "changed-in-[start,end]" API + scheduler + per-release changelog = deferred, backlog §1.3–§1.5) · **16-06 versioning —
BACKLOG**. Suggested build order: 16-01 → 16-02 → 16-03 → 16-08 → 16-04 → 16-05 → 16-05b/16-07; 16-06 later. **Release chain:**
`genesis-appian-parser` (new) → `genesis` (m0007 + KbStore + kb_server + native-MCP installer + applications api/web) →
`genesis-workflows` (sync-application + managed-native registry entries). genesis-core likely unchanged.

**✅ 16-03 — DONE (`sync-application` workflow).** genesis **v0.29.1** + genesis-workflows **v0.8.2**, CI green. As built
(see `progress/phase-16-03-sync-workflow.md`): a program-only graph `resolve_inputs → export_package → v_export →
parse_package → v_parse → write_kb → v_kb → present`; **export = deterministic Appian Deployment REST** in a program
node, all network/env/secret access isolated in the `_fetch_package_zip` seam (401/403/404 fail-fast; 409/timeout/5xx →
retry); **parse → code-free `result.json`**; **write_kb → `KbStore` baseline**, store injected via
`ctx.extras['kb_store']` (wiring resolved to ctx.extras — `build_context` provides it; `graph.py` never imports the
platform); re-baseline rejected. genesis pins `genesis-appian-parser@v0.1.0`, adds `EnvironmentRegistry.active()`, and
hardened the checkpointer connection (WAL + busy_timeout). **`write_kb` is a raw async node that runs the blocking
`KbStore` write via `asyncio.to_thread`** — the deterministic fix for a flaky CI `database is locked` (a sync write on
the event loop deadlocks the aiosqlite checkpointer; see §7). `appian-dev`/`appian-devops` registered as managed-native
refs (resolved the old `lcp` placeholder).

**✅ 16-08 §2.0 — DONE (dev-environment toggle).** genesis **v0.30.0**, CI green (#6502611). The Environments registry
has an **`is_dev`** flag (single-select — tagging one env clears the others); `EnvironmentRegistry.dev_environment()`/
`dev_environment_label()`/`set_dev_environment()`; `ConfigService.dev_connection_check()` readiness; API `is_dev` on
upsert + `POST /config/environments/{label}/dev` + `GET /config/environments/dev/check`; web dev toggle + **dev** badge +
per-row **Set as dev** + **Test connection**. See `progress/phase-16-08-native-mcp.md`.

**✅ 16-08 Stage B — DONE (managed-native Dev/DevOps MCP installer).** genesis-core **v0.9.1** + genesis **v0.31.1** +
genesis-workflows **v0.8.4**, CI green (see the progress doc for the one `frontend`-guard caveat). As built:
`NativeMcpInstaller` (`genesis/mcp/native/`) installs a drop-in bundle → `uv sync` under
`~/.genesis/mcp-servers/<id>/versions/<v>/` → verify entry → sha256 + lockfile → set `current`; `rollback(id)` to the
prior version; `active_launch_spec(id)` launches from the **per-server venv, NOT `uv`** (Dev `python -m lcp_mcp_server`,
DevOps `.venv/bin/appian-deployment`); **no network `update`** (manual drop-in). `NativeMcpLockfile` = own atomic JSON
store (not `genesis.db`). genesis-core `McpRegistry` resolves a `"managed":"<id>"` entry via an injected `launch_provider`
(env `${VAR}` stays on the entry, resolved as usual; additive, `CORE_MAJOR`=1) + an 8 MiB introspect stream limit.
`mcp-registry.json` `appian-dev`/`appian-devops` are managed refs with read-only allowlists **set from the real installed
`tools/list`** (Dev 67/145, DevOps 13/26). Wiring: `ConfigService` + `worker` inject `native.launch_spec_for`;
`environments.resolve_var` maps `LCP_URL`/`APPIAN_DOMAIN` from the dev env. Surface: `api/native_mcp.py` (GET status +
POST install|rollback), `genesis mcp install-native|status|rollback-native` CLI, Settings→MCP "Appian MCP servers" panel.
See `progress/phase-16-08-native-mcp.md`.

**✅ 16-04 — DONE (Applications surface).** genesis **v0.32.0**, CI green (#6504611: `genesis` + `frontend`). As built
(see `progress/phase-16-04-applications-surface.md`): `api/applications.py` over `KbStore` + `RunManager` (list /
available [Dev-MCP `listApplications` via `kb/dev_mcp.py`, best-effort + manual-UUID fallback] / add→baseline sync /
detail / sync-status / objects / bundles / table-scoped untrack); `KbStore.list_syncs`+`latest_sync`;
`web/features/applications` (page + Add dialog + detail tabs **Business Map | Overview | Syncs | Releases** [Objects + Bundles tabs removed v0.41.0] + live SyncStatus **shown only while a sync is running**)
+ a Sidebar entry. First consumer of the managed-native Dev MCP. (The `frontend` stale-bundle guard ran green here —
also closing the 16-08 Stage-B gap where it hadn't executed.)

**✅ 16-05 — DONE (`genesis-kb` MCP server + CHAT cutover).** genesis **v0.33.0**, CI green (pipeline 6513536; `frontend`
skipped — no web change). As built (see `progress/phase-16-05-kb-mcp-and-cutover.md`): **`genesis/mcp/kb_server.py`** —
a read-only stdio JSON-RPC MCP modeled on `introspection_server.py` (`mode=ro` genesis.db, 32 KB cap, `-m
genesis.mcp.kb_server --db <db>`) exposing the **17 Tier-1 tools** over `KbStore` with **Atlas-mirrored shapes**;
`get_object_code`/`get_orphan` fetch live SAIL via the Dev MCP (`genesis/kb/dev_mcp.py` `object_code`, type→getter map +
defensive parse; graceful `code_status:"unavailable"`, never fabricated). `KbStore` gained the 7 remaining reads
(entry-points, dependents/precedents batch, shared, hub, dependency-path BFS, transitive-deps BFS; current-state only).
**Chat cut over** (`chat/mcp.py`): `genesis-kb` always wired (+ best-effort `@appian-dev` for live code); **`appian-atlas`
dropped from chat**. 288 pytest green, ruff clean.

**⚠️ Phased-cutover decision (2026-08-06) — `appian-atlas` RETAINED for the workflows.** A lossless `erd-generation` +
`design-doc` cutover is **not** possible in iteration 1: `genesis-kb` deliberately omits the **schema/DDL tools
(Section C, deferred)** and the **release/version tools (16-06 backlog, AP-62096)** — exactly what those workflows use
(`get_app_schema`/`get_schema_relationships`; `list_releases`/`get_object_at_release`/`get_changelog`/`compare_releases`/
`get_release_impact`), and `design-doc` also still uses **Jarvis**. **Per the user's decision, both workflows STAY on
`appian-atlas`** (their `required_mcp` unchanged; genesis-workflows not re-released) until parity lands. Only **chat**
cut over (it used Atlas *structural* reads that `genesis-kb` mirrors). Documented in the phase-16 umbrella spec.

**▶ NEXT — 16-05b (workflow cutover) + 16-07 remainder.** **16-05b** = cut `erd-generation` + `design-doc` off
`appian-atlas` → `genesis-kb` (+ Dev MCP for live/schema), unblocked by (a) a Section-C schema decision (build the
schema tools OR repoint their schema/data-model research to live Dev-MCP record-type tools) and (b) **16-06 versioning**
(AP-62096) for `design-doc`'s release-history, plus retiring Jarvis→Dev MCP there. **16-07 remainder** = the true
incremental delta (Appian changed-objects API — the Dev MCP can't back it), the scheduler, and the per-release
changelog. **16-06** (versioning) stays BACKLOG (gated on Dev-MCP AP-62096, 26.8 GA). **📋 The full deferred register
(every postponed Phase-16 item + why + what unblocks it) is `specs/backlog/phase-16-deferred.md` — read it before
picking up any Phase-16 follow-up.**

**✅ 16-07 — Option A DONE (delta refresh via re-export + SCD-2 delta-merge).** genesis-workflows **v0.8.5**, CI green
(pipeline 6513690). `sync-application` v0.2.0 `mode=delta`: full re-export + `KbStore.apply(mode='delta')` (diffs by
`diff_hash`; opens new/modified, closes removed [inferred], recomputes bundles, records the window). `resolve_inputs`
requires an existing baseline for delta; `check_kb` mode-aware. **The true incremental delta (Appian changed-objects
API) is deferred — the Dev MCP cannot fetch objects by modified date/time (confirmed 2026-08-06: no modified-since tool;
objects carry no modified timestamp).** Scheduler + per-release changelog also deferred. See
`progress/phase-16-07-delta-refresh.md` + backlog §1.3–§1.5.

**Key facts for any Phase-16 work:** the sample package the user provided is
`/Users/ramaswamy.u/Documents/test/packages/AiDocumentCenterv4.3.1.zip` (also vendored in the parser repo's
`tests/fixtures/`); the env **accepts Basic auth** (Dev MCP headless, no playwright/SSO); `KbStore` reads/writes are
**current-state only** in iteration 1 (`valid_to_sync IS NULL`); `KbBundle.flow` / `flow_json` is the **structured dict**
(Atlas standard), returned verbatim.

**Open items to confirm with the human:** (1) the Appian **changed-objects** API contract (content vs ids; deletes;
pagination) for 16-07. *(Resolved: env accepts Basic auth; export is deterministic REST not the DevOps MCP; the
KbStore→worker wiring is `ctx.extras['kb_store']` via `build_context`; native-MCP updates = **manual drop-in, no
auto-fetch source** (2026-08-05); commit/push approved — 16-01/16-02/16-03 + 16-08 §2.0 are pushed + CI-green.)*

---

- **Shipped:** Phases 1–6, the web revamp (7.1), the code-review fix program (01–06), Phase 8 (settings
  revamp), **Phase 9 (agent artifact I/O), Phase 10 (chat assistant), Phase 11 (credit tracking),
  Phase 12 (Appian code-review workflow), Phase 13 (Chat Copilot & Run Orchestrator — 13-01..13-06),
  Phase 14 (Skills in Chat — 14-01..14-05), Phase 15 (Design-Document Workflow — 15-01..15-05:
  dual-source Jarvis+Atlas research → Markdown design doc + run-launch file attachments, ADR-035)**.
  See `tracker.md` §3/§6 and `reference/roadmap-and-sequencing.md`.
- **Phase 13: Chat Copilot & Run Orchestrator — COMPLETE (13-01..13-06 shipped; ADR-033 Accepted).**
  Read `specs/phase-13-copilot-orchestrator.md` (umbrella) + `phase-13-copilot-orchestrator/13-01..13-06`
  + **ADR-033** + `progress/phase-13-copilot-orchestrator.md` if you touch the copilot. **Delivered:** type `/`
  in chat → pick a workflow → schema-driven inputs → the Kiro agent **starts the run** and **supervises**
  it (senses HITL gates, presents options, relays the user's decision, reports outcomes) without staying
  alive. **Architecture (decided, code-grounded):**
  - **Genesis Control MCP server** (`genesis/mcp/control_server.py`) — a write-capable sibling of the
    read-only `introspection_server`, but a **thin MCP→HTTP facade over `/api`** (`POST /api/runs`, `GET
    /api/runs/{id}`(+`.gate`), `/respond`, `/cancel`, `/api/catalog`, `GET /api/workflows/{id}`) so
    `RunManager` stays the single source of truth. Tools: `list_launchable_workflows`,
    `get_workflow_inputs_schema`, `check_launch_readiness`, `start_run`, `get_run_status`, `get_run_steps`,
    `get_pending_gate`, `respond_to_gate`, `cancel_run`, `list_session_runs`. NO config/secret/registry/deploy tools.
  - **Human-confirmed mutations via ACP's native permission mechanism** — the SDK permission model is binary
    (`auto_approve`/`auto_deny`) and *trusted tools skip the prompt*. So keep **read tools trusted (silent)**
    and leave **mutating tools UNTRUSTED** → kiro-cli fires `session/request_permission` per call → a new SDK
    **`permission_mode="ask"`** + async `on_permission` callback (13-01) routes it to a **chat confirm card**
    (fail-closed on timeout). **Load-bearing spike (13-01, do FIRST):** prove kiro-cli actually fires
    `request_permission` for untrusted MCP tools; if not, use the ADR-033 fallback (UI-mediated pending-action confirm).
  - **Event-driven supervision** — a `ChatRunSupervisor` (app process) subscribes to `RunManager`'s EventBus
    for **session-linked runs** (`m0004 chat_run_links`); on `gate.awaiting`/`run.final` it emits a notification
    + a proactive **nudge turn** so the copilot surfaces the gate + options; **level-triggered reconcile** from
    durable state (`pending_gate` + `EventLog`) on restart (don't rely on the live subscription). Nudges queue
    behind the session lock + de-dup by `(run_id, gate_node, raised_at)`.
  - **Slash UX** — Composer `/` palette from the catalog; **reuse the 07-05 launch form** for schema inputs;
    on submit the UI hands the agent the `start_run` action (agent is the actor) → confirm card → run linked +
    supervised. In-chat cards: permission-confirm, gate, terminal; a supervised-runs strip.
  - **ADR-033 reconciliation:** ADR-001 preserved (LangGraph still owns each workflow's control flow; copilot
    = operator at the run-management layer = what a human does in the Runs UI); ADR-031 refined (read-write at
    that layer, every mutation human-confirmed, no config/secret/deploy, read-only default + kill-switch).
  - **Sub-phase order + release chain:** **13-01 SDK permission bridge — SHIPPED (kiro-agent-sdk v0.5.0;
    spike confirmed; genesis/core pin bump deferred to 13-03)** → **13-02 control server + ADR-033 —
    BUILT (genesis/mcp/control_server.py on master `b6edf7c`; requests not httpx; token gating deferred to
    13-06)** → **13-03 copilot chat mode + run↔session link (`m0004`) + coordinated sdk-v0.5.0 pin bump —
    SHIPPED (genesis v0.21.0 + genesis-core v0.8.1; the 13-02 control server ships here, now live)** → **13-04
    run-supervision bridge — SHIPPED (genesis v0.22.0: ChatRunSupervisor observes gate/terminal for linked
    runs → durable notifications [m0005] + per-session SSE + deterministic system nudge; level-triggered
    reconcile + SLA)** → **13-05 slash launch + in-chat HITL/confirm UI — SHIPPED (genesis v0.23.0: Composer
    `/` palette → LaunchDialog → start_run intent turn → PermissionCard/GateCard/TerminalCard + SupervisedRunsStrip;
    frontend-only release)** → **13-06 safety/audit/advanced-gate + release — SHIPPED (genesis v0.24.0:
    persisted kill-switch + per-session concurrency/rate/allow-deny enforced app-side on POST /api/runs
    gated on the control token; `copilot_actions` audit trail [m0006]; pre_mutation never auto-approved;
    Settings→Copilot section + activity; ADR-033 → Accepted)**. **PHASE 13 COMPLETE.** `genesis-core`
    unchanged. After any `web/src` change: `npm run build` + commit `web/static`. Remaining: manual
    live-acceptance vs. real kiro-cli (headless-undrivable).
- **Phase 14: Skills in Chat — COMPLETE (14-01..14-05 shipped; ADR-034 Accepted).** Read
  `specs/phase-14-skills-in-chat.md` (umbrella) + `phase-14-skills-in-chat/14-01..14-05` + **ADR-034** + the proving
  spike `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` before touching code. **Goal:** add **Skills** — Kiro's
  portable `SKILL.md` instruction packages — as a **second first-class capability beside Workflows**, usable from
  **Chat** (priority 1). **Concept boundary:** a *Skill* = standalone activity (draft a doc, build a checklist, apply
  a body of knowledge like GAM), no stages/run, owned by the Kiro agent; a *Workflow* = staged/orchestrated, owned by
  LangGraph. **Architecture (spike-proven, code-grounded):** skills are **filesystem-discovered** (`.kiro/skills/`),
  NOT an ACP wire param like MCP — Genesis writes them into a managed workspace **`~/.genesis/.kiro/skills/`** (= the
  chat `cwd`); kiro-cli auto-discovers them (auto-activation by `description` + explicit `/skill-name`, both proven).
  Two acquisition paths: **install from a `genesis-workflows` `skills/` library** (parallel of the workflow install +
  a separate `skills-registry.json`) or **author in-flight** (SKILL.md + scripts/references/assets uploads). **Catalog**
  → Workflows | Skills sub-tabs; **Chat** `/` palette → unified workflows+skills menu (skills also in read-only chat).
  **Safety:** skills may write documents **only** into a per-session **skill-output sandbox**
  `~/.genesis/skill-output/<session_id>/` via a small additive SDK **`fs_write_root`** option (writes elsewhere
  rejected); executing bundled scripts stays deferred. **Sub-phases:** 14-01 foundation + chat discovery → 14-02
  skills library + install-from-repo → 14-03 Catalog Skills tab + in-flight authoring → 14-04 chat skills invocation →
  14-05 safety (skill-output sandbox) / lifecycle / release. **Release chain (shipped):** kiro-agent-sdk **v0.6.0**
  (`fs_write_root`) → genesis-workflows **v0.6.0** (skills library) → genesis **v0.26.1**; genesis-core **v0.8.2** (sdk-pin bump only).
  Remaining: manual live-acceptance vs. real kiro-cli (auto-activation + `/gam`, headless-undrivable).
- **Backlog (`specs/backlog/`):** the **skill → workflow migration program** (the 45 solutions-copilot
  skills, waves A–D) — deferred; the methodology is intact and resumes when scheduled.
- **Open follow-ups (may be assigned):** the Phase-12 **live run** against a real GAMS ticket/package
  (needs a `genesis serve` restart on ≥ v0.20.2 + the connected jarvis/jira secrets) to confirm per-object
  findings, checklist coverage, SQL checks, the diff baseline rule, and metered credits; restart the
  running `genesis serve` to load v0.20.x; harden the other JSON stores' writes to be atomic (like
  secrets); **rotate the shared `GITLAB_PUSH_TOKEN`** + refresh the expired Artifactory npm token; the
  `lcp` MCP image placeholder (`<lcp-image>`) in `mcp-registry.json`.

**Do not start backlog or a *new* phase unless explicitly asked.** (Phase 16 is **actively being implemented** with the
human's go-ahead — specs are pushed and 16-01/16-02 are shipped + CI-green; continue in the build order per §9's Phase-16
block. This does not authorize starting any phase *beyond* 16 or any `specs/backlog/` work.)

---

## 10. Working agreements (how the human wants you to operate)

- **Honest pushback** — correct the human when they're wrong; flag any ADR deviation and confirm before proceeding.
- **Ask before destructive/irreversible actions** (force push, history rewrite, deleting data, anything "prod").
- **Don't push to shared repos beyond the normal Genesis release flow;** never commit secrets; reference secrets by key name only.
- **If stuck twice on the same error,** stop and diagnose the root cause; try a fundamentally different approach.
- **Keep changes scoped** to the task; don't refactor unrelated code.
- **Prefer dedicated tools** (file read/edit/search) over shell equivalents; make independent tool calls in parallel.
- **This document assigns no task** — after restating the architecture + current state + non-negotiables, do the work the human gives you.
