# Genesis — Master Tracker

> **Genesis** is an agentic SDLC platform for the Appian **Solutions** department.
> It is a local web application that orchestrates multi-step SDLC **workflows**
> using **LangGraph** as the engine and **Kiro** (via `kiro-agent-sdk` over ACP)
> as the agent runtime. Workflows are pulled from a shared GitLab library and run
> on the user's machine with their own credentials.

| | |
|---|---|
| **Program** | Genesis |
| **Platform repo** | `genesis` (local web app + LangGraph engine + config UI) |
| **Workflow library repo** | `genesis-workflows` (workflow packages + authoring steering) |
| **Agent adapter** | `kiro-agent-sdk` (Kiro ACP node adapter — already built) |
| **Engine** | LangGraph (v1) |
| **Users** | Internal Solutions dept — Dev, Tester, PO, UX |
| **Status** | 🟢 **Phases 1–48 COMPLETE — no active build** (as of 2026-10-21). Latest release: **Phase 48 Object Wiki UI** — genesis **v0.78.0** (other repos unchanged). Current tags, DB version, test counts and what works: [`context/state/current.md`](context/state/current.md) (the one home for those facts). Follow-ups: `specs/backlog/phase-48-follow-ups.md`. Running history: §6 below + [`context/changelog.md`](context/changelog.md). (Phase 1–7 era detail is in `archive/` + `progress/`.) |
| **Agent onboarding** | [`AGENT_ONBOARDING.md`](AGENT_ONBOARDING.md) — paste into any new agent session working on fixes/enhancements |
| **Supersedes** | solutions-copilot (retired) — Genesis realizes its deferred doc-19 orchestrator |
| **Created** | 2026-07-07 |

---

## 1. What Genesis is (and why it exists)

solutions-copilot tried to use an **LLM agent as the orchestrator** of multi-step
SDLC skills. It failed the way agent-orchestrators fail: agents skipped steps and
didn't follow the skill's workflow. solutions-copilot's own `19-workflows-orchestration-deferred.md`
concluded durable external orchestration was needed and explicitly named LangGraph.

**Genesis is that orchestrator.** The control flow moves out of the model and into
LangGraph. Each former "skill" becomes a **workflow** — a Python LangGraph package
whose steps are either deterministic **program nodes** or narrow **agent nodes**
(Kiro via ACP). Determinism of sequencing never depends on a model's discipline.

Positioning: **Genesis replaces solutions-copilot.** The agents/skills/powers/
IDE-installer model is retired. We keep the *content* (the 45 skills become the
specs for workflows) and proven *patterns* (manifest→catalog, lockfile, MCP
wiring, analysis-doc handoff), reimplemented natively in Genesis.

---

## 2. Locked design decisions (Q1–Q14)

| # | Decision | Detail |
|---|---|---|
| **Q1** | **Local web app; shared GitLab library; internal Solutions users** | Engine + Kiro/MCP run locally with the user's creds; workflows pulled from GitLab; users = Dev/Tester/PO/UX. |
| **Q2** | **Per-node MCP injection** (not global-installed agents) | Each agent node opens an ACP session with only the MCP server(s) it needs; session closes after the step. Proven in the ERD workflow. |
| **Q3** | **No "profiles"** — shared **MCP registry** only | One registry defines how each MCP server launches + its secrets. Nodes reference servers by name + carry their own prompt/tools. |
| **Q4** | **Workflow = self-contained package**; catalog via `registry.json` | Folder per workflow: `workflow.yaml` (META) + `graph.py` (`build()`), `common/` shared lib, root `registry.json` + `mcp-registry.json`. |
| **Q4** | **Selective install + lockfile** | Persona-driven; users install the workflows they need; pinned by ref; update detection. |
| **Q5** | **Role = filter tag + curated bundles**; cross-role picking allowed | No hard gating; multi-hat users; "install the Tester set" bundles for onboarding. |
| **Q6** | **Single app** (engine + UI bundled); **Studio first, custom workbench later** | Validate on LangGraph Studio, then build the bespoke web workbench. |
| **Q7** | **All three HITL modes required** | (1) designed approval gates, (2) ad-hoc pause/resume anywhere, (3) mid-run state injection. All important, v1. |
| **Q8** | **Small editable state + pointers; bulk in per-run artifacts folder; local SQLite checkpointer** | State is human-editable; blackboard holds bulk data + cross-agent handoff docs. |
| **Q9** | **Reliability standard = HARD REQUIREMENT** | Every agent node must have a program **validator** + **retry/escalation**; enforced in library CI at publish time. Retry count configurable per workflow; escalates to HITL on exhaustion. |
| **Q10** | **`build()` + `META` contract; validated in CI; run in a subprocess worker** | Trust internal GitLab + CI + pinned refs; graph execution runs in a disposable subprocess worker (ADR-012), not in-process — crash/hang/leak isolation + kill switch. genesis-core semver + hard major-compat gate (ADR-019). |
| **Q11** | **solutions-copilot retired; Genesis has its own config UI** | Reuse concepts (SecretProvider, env registry, GitLab client) as fresh implementations. |
| **Q12** | **Authoring: scaffolder + templates + test harness AND agent-assisted authoring**; **authoring steering in the library**; open contribution | Any Solutions engineer can build a workflow, guided. |
| **Q13** | **Build the complete application + ERD workflow first; then migrate skills one by one** | Custom workbench UI is the one explicitly-deferred piece (Studio interim). |
| **Q14** | **Name = Genesis** | Platform `genesis`, library `genesis-workflows`, SDK `kiro-agent-sdk`. |

---

## 3. Phase index (see `specs/` for the detailed spec of each)

| Phase | Spec file | Title | Outcome |
|---|---|---|---|
| — | `specs/00-architecture-overview.md` | Architecture Overview | Shared reference for all phases |
| 1 | `specs/phase-01-core-platform-foundation.md` | Core Platform Foundation | Engine, node framework, state, checkpointer, blackboard, MCP registry, validator/retry |
| 2 | `specs/phase-02-workflow-contract-and-library.md` | Workflow Contract & Library System | `build()`/`META` contract, common lib, authoring scaffolder + steering, CI enforcement |
| 3 | `specs/phase-03-distribution-install-lockfile.md` | Distribution: GitLab Pull, Selective Install, Lockfile | Catalog browse, install/update/remove, lockfile |
| 4 | `specs/phase-04-configuration-and-secrets.md` | Configuration & Secrets | Config UI, SecretProvider, env registry, GitLab token |
| 5 | `specs/phase-05-run-orchestration-and-hitl.md` | Run Orchestration & HITL | Run lifecycle, all 3 interrupt modes, streaming, Studio integration |
| 6 | `specs/phase-06-erd-reference-workflow.md` | ERD Reference Workflow | ERD ported to Genesis as the canonical template |
| 7 | `specs/phase-07-custom-web-workbench.md` | Custom Web Workbench UI | Bespoke run/observe/interrupt UI (deferred item) |
| 7.1 | `specs/phase-07-01-web-revamp-program-overview.md` | **Web Revamp** — Program Overview & Frontend Architecture | ADR-027 stack, folder/routing/state architecture, delivery plan (anchor) |
| 7.1 | `specs/phase-07-02-backend-data-plane.md` | Web Revamp — Backend & Core Data-Plane | Persistent event log, gate-from-checkpoint, ACP conversation streaming, topology/steps/artifact-content/status APIs |
| 7.1 | `specs/phase-07-03-design-system.md` | Web Revamp — Design System & Component Library | Tokens/themes, shadcn/ui inventory, layout primitives, a11y |
| 7.1 | `specs/phase-07-03a-visual-language-reference.md` | Web Revamp — Visual Language Reference (Overcut-inspired) | First-hand Overcut study; tokens/patterns Genesis adopts + how it innovates on top |
| 7.1 | `specs/phase-07-04-settings-configuration.md` | Web Revamp — Settings & Configuration | MCP/CLI cards + live status, config drawer, connection test, environments |
| 7.1 | `specs/phase-07-05-catalog-and-install.md` | Web Revamp — Catalog & Install Management | Browse/filter/prereqs, install/update/remove, schema-driven launch |
| 7.1 | `specs/phase-07-06-runs-list-and-history.md` | Web Revamp — Runs List & History | Active vs history, filters, live status, quick actions |
| 7.1 | `specs/phase-07-07-run-detail-graph.md` | Web Revamp — Run Detail: Graph & Orchestration | React Flow graph, node-status fold, timeline, telemetry |
| 7.1 | `specs/phase-07-08-node-inspection-conversation-hitl.md` | Web Revamp — Node Inspection, Kiro Conversation & HITL | Per-node transcript, all 3 HITL modes from durable state |
| 7.1 | `specs/phase-07-09-documents-and-preview.md` | Web Revamp — Documents & Artifact Preview | Documents drawer + rendered preview (md/json/mermaid/csv/text) |
| 7.1 | `specs/phase-07-10-testing-ci-rollout.md` | Web Revamp — Testing, CI & Rollout | Test pyramid, contract fixtures, CI, cutover from interim web |
| 8 | `specs/phase-08-settings-revamp.md` | Settings & Integrations Revamp ✅ | Tabbed Settings workspace (MCP/CLI/GitLab/Environments/General) + one standardized master-detail + add/edit pattern — shipped genesis v0.16.0 |
| 9 | `specs/phase-09-agent-artifact-io.md` | Agent Artifact I/O ✅ | Session tool-output store + agent-driven save-by-reference (`list_tool_outputs`/`save_tool_output`): large MCP results land in the blackboard with zero re-emission. **Shipped** — sdk v0.2.0, genesis-core v0.6.0, genesis v0.17.0, genesis-workflows v0.4.0 |
| 10 | `specs/phase-10-chat-assistant.md` (+ `phase-10-chat-assistant/10-01..10-07`) | Chat assistant ✅ | Read-only conversational Chat page: talk to Kiro (Atlas read MCP) + query all Genesis data via a read-only introspection MCP server (runs/failures/progress/health). Persisted, deletable sessions; single-user. **Shipped — sdk v0.3.0, genesis-core v0.7.0, genesis v0.19.0; ADR-031; spike + live-verified.** |
| 11 | `specs/phase-11-credit-usage-tracking.md` | Credit & Usage Tracking ✅ | Real, metered per-turn Kiro credits (ACP `_kiro.dev/metadata.meteringUsage`, spike-verified per-turn) surfaced everywhere: per agent node + run-total (run detail), Overview KPI (replaces Tool-Calls), per chat message + session total. SDK captures usage → telemetry/`agent.result` → `run_events`/`fold_steps`/`aggregate_credits` → UI (`formatCredits`/`CreditBadge`). **Shipped — sdk v0.4.0, genesis-core v0.8.0, genesis v0.20.0; m0003; ADR-032.** |
| 12 | `specs/phase-12-code-review-workflow.md` | Appian Code-Review Workflow ✅ | Deterministic port of the Jarvis code-review process (Google-Docs export excluded): entry via JIRA ticket / package URL / object names; per-object review loop (diff-aware → `analyze_appian_code` → dynamic checklist → SQL/i18n) → agent-proposed / program-confirmed verdict. Read-only by construction (per-node `@jarvis`/`@jira` allowlists). **Shipped — genesis v0.20.2 (worker loop `recursion_limit`, 12-01) + genesis-workflows v0.5.3 (`code-review` workflow, 12-02..12-05; v0.5.1–v0.5.3 = live-data robustness fixes).** |
| 13 | `specs/phase-13-copilot-orchestrator.md` (+ `phase-13-copilot-orchestrator/13-01..13-06`) | Chat Copilot & Run Orchestrator 🚧 | Evolve read-only Chat into a **copilot**: slash-command to launch any workflow (schema-driven inputs), the Kiro agent **starts the run** and **supervises** it (senses HITL gates, relays the user's decision, reports outcomes) without staying alive. A write-capable **Genesis Control MCP server** (proxies `RunManager` API), human-confirmed mutations via a new SDK `permission_mode="ask"` bridge, and an event-driven supervision bridge (gate/terminal → proactive chat nudges). **ADR-033** (copilot = run-operator, human-gated, LangGraph still owns control flow). **COMPLETE: Phase 13 shipped in full (13-01..13-06) — the Chat copilot launches, confirms every mutation, supervises gates/terminals in-chat, and is safety-hardened (kill-switch + concurrency/rate/allow-deny + audit trail); genesis v0.24.0 + kiro-agent-sdk v0.5.0 + genesis-core v0.8.1; ADR-033 Accepted. Only manual live-acceptance vs. real kiro-cli remains.** |
| 14 | `specs/phase-14-skills-in-chat.md` (+ `phase-14-skills-in-chat/14-01..14-05`) | Skills in Chat ✅ | Add **Skills** (Kiro's portable `SKILL.md` instruction packages) as a **second first-class capability** beside Workflows: a **standalone activity** (draft a document, build a checklist, apply a body of knowledge like GAM) with no stages/orchestration, owned by the Kiro agent — vs a Workflow (staged/orchestrated, owned by LangGraph). Filesystem-provisioned into a managed Kiro workspace (`~/.genesis/.kiro/skills/` = the chat cwd; **spike-proven** over ACP). **Install from a `genesis-workflows` skills library** OR **author in-flight** (SKILL.md + scripts/references/assets). Catalog gets **Workflows \| Skills** sub-tabs; Chat's `/` palette lists skills + auto-activation. **ADR-034.** Chat is priority 1; workflow-node skills later. **SHIPPED 14-01..14-05: kiro-agent-sdk v0.6.0 + genesis-workflows v0.6.0 + genesis v0.26.1; ADR-034 Accepted. Per-session skill-output sandbox (SDK `fs_write_root`).** |
| 15 | `specs/phase-15-design-doc-workflow.md` | Design-Document Workflow ✅ | Port the Jarvis "Design Document Creation Workflow" into a **deterministic Genesis workflow**: a JIRA ticket → an Appian implementation **design document (Markdown)** via **dual-source research** — the live **Jarvis** environment/KB **and** the release-aware **Atlas** KB — reconciled into one release-aware plan. Conditional branches (KB-freshness gate, mockup→i18n, open-questions); one gated mutation (empty-package creation, `pre_mutation`). Adds a genesis platform capability: **run-launch file attachments** (`format:"file"` inputs → `POST /api/runs/upload` → blackboard provisioning), **ADR-035**. **SHIPPED 15-01..15-05: genesis-workflows v0.7.0 + genesis v0.27.0; genesis-core + kiro-agent-sdk unchanged.** |
| 16 | `specs/phase-16-appian-knowledge-base.md` (+ `phase-16-appian-knowledge-base/16-01..16-08` + `genesis-kb-tool-contracts.md`) | Appian Knowledge Base (Atlas-into-Genesis) 📋 | Bring the Appian **knowledge base** *inside* Genesis: a **Genesis-native parser** (`genesis-appian-parser`, ported from the Atlas parser front-half), a **code-free temporal KB** in `genesis.db` (m0007 `kb_*` SCD-2 tables — metadata/structure/deps/bundles only, **no source code**), an **Applications** page (add apps from the **dev-tagged** env → baseline sync), a deterministic **`sync-application` LangGraph workflow** (Deployment-REST export → parse → SCD-2 merge → bundles), a read-only **`genesis-kb` MCP** (16 iteration-1 tools) that serves the KB + fetches **live code via the Dev MCP**, and **managed, updatable native Dev/DevOps MCP** servers (16-08) resolved against a single-select **`is_dev`** environment. Cuts chat/erd/design-doc off the external `appian-atlas`. User-tagged **releases** + point-in-time = **backlog** (16-06, gated on Dev MCP **AP-62096**, 26.8 GA); **delta refresh** (16-07) via a new Appian "changed-in-window" API. Read-only against Appian. **ADR-036** (internalized KB) + **ADR-037** (code-free temporal KB) + **ADR-038** (managed native MCP servers). **DRAFT — spec only (umbrella + 8 sub-phases + tool-contracts doc); awaiting approval to implement.** |
| — | `specs/backlog/skill-migration-program.md` | ⏸️ Backlog — Skill → Workflow Migration (was Phase 8) | Deferred; methodology + backlog to migrate 45 skills — resumes after the upcoming polish phases |

> **Note:** Phases 17 (Business Map), 18 (Parser accuracy), 19 (Document Library), 20 (Features & Spec authoring), and
> 21–29 (Feature Workspace/Chat parity · Distribution · Scheduled syncs · UX+env-creds · Foundation hardening · Agentic
> Memory · UI/UX Revamp · Feature Revamp · **UX Design Stage**) are tracked
> authoritatively in **§6 (status log)** + **`AGENT_ONBOARDING.md` §9** + **`README.md`** — this index table was not back-filled
> for them.

- **Phase 20** — `specs/phase-20-features-and-spec-authoring.md` (+ `phase-20-features-and-spec-authoring/20-01..20-06`) —
  **Features & Spec Authoring** 📋 SPEC DRAFT. Per-app **Features** (m0010 `kb_features`) + a conversationally-authored
  **Spec**: a reused Chat (genesis-kb + injected business-artifact context) authors an **HTML-authoritative** spec in the
  fs-write sandbox, reviewed in an **embedded, annotatable** surface (the **vendored Lavish annotation SDK**, MIT → an
  annotation-to-chat bridge), with status draft→in-progress→in-review→completed + milestone revisions + Markdown export.
  Mostly **genesis**. **ADR-042** (Features & Specs model) + **ADR-043** (embed Lavish SDK) — Proposed.
- **Phase 21** — `specs/phase-21-feature-workspace-and-chat-parity.md` (+ `phase-21-feature-workspace-and-chat-parity/21-01..21-07`) —
  **Feature Workspace, Spec-Builder UX & Chat Parity** ✅ SHIPPED (v0.46.0; 21-01..21-07; Phase-20 live-feedback pass). **(A)** the feature page
  becomes an **artifact-pipeline** landing (Spec card functional + Design/Breakdown disabled placeholders; feature card drops
  spec status); **(B)** the spec builder becomes a **full-width chat** with an on-demand **full-screen annotatable Preview**
  (our own comment-queue + Send-all), `feature_spec` sessions **isolated** from the main chat, copilot banner removed there;
  **(C)** the reused chat reaches **Kiro CLI/ACP parity** (model @ creation, slash commands + autocomplete, context/compaction
  meter, clear/compact, image attach) + **Markdown transcript export** — both places. Requires **kiro-agent-sdk** ACP
  extensions (`session/set_model`, `_kiro.dev/commands/*`, compaction/clear status, image prompts). **ADR-044** (feature =
  artifact-stage workspace) + **ADR-045** (chat mirrors the CLI/ACP surface; revises ADR-031 — introspection free,
  write-actions human-confirmed) — **Accepted**. Released **genesis v0.46.0 + genesis-core v0.9.3 + kiro-agent-sdk v0.7.0**, CI green.
  Follow-up patch **v0.46.1** (chat parity hotfixes: slash commands via the prompt path, export float-total + thought coalescing).

- **Phase 22** — `specs/phase-22-distribution-and-shipping.md` (+ `phase-22-distribution-and-shipping/22-01..22-07`) —
  **Distribution & Browser-Based Shipping (clone + git-tag)** ✅ SHIPPED (genesis **v0.47.0**, CI green [genesis + frontend +
  the new clean-install]; genesis-only, no schema). A **standard, working way to ship Genesis to internal users** as a **local, browser-based** app — modeled on
  `appian/prod/friday`'s clone + venv + git-tag self-update installer, but **browser-based** (no Mac `.app`), leveraging
  Genesis's single-port `genesis serve`. **Install** (`scripts/install.sh`: prereq + SSH-access preflight → clone `genesis`
  [one clone; the 3 internal deps resolve via their `git+ssh` tag pins] → venv → `pip install .` → `genesis db upgrade`) →
  **launch** (`genesis up` backgrounds serve + opens the default browser at `127.0.0.1:8760`) → **update in place** from release
  tags (one-click banner + `genesis update`: checkout tag → `pip install .` → `db upgrade` → detached restart) → **in-app Kiro
  login** + a **first-run preflight** + a **CI clean-install verify**. New runtime code is a tiny read-only `api/system` surface
  + a web update banner/panels + installer/updater shell scripts + `genesis up/down/status/update` CLI. **ADR-046** (clone+tag
- **Phase 23** — `specs/phase-23-scheduled-and-full-package-syncs.md` (+ `phase-23-scheduled-and-full-package-syncs/23-01..23-03`)
  — **Scheduled & Full-Package Syncs** ✅ SHIPPED (genesis **v0.48.0**, CI green #6588951 [genesis + frontend + clean-install];
  genesis-only + **m0012**). Keep the local
  Appian KB + Document Library fresh **automatically**. **(1)** Make the application sync **re-runnable as a full-package
  refresh** — exposing the already-built `sync-application` **`mode=delta`** (full re-export → parse → diff the DB by
  `diff_hash` → write only the changes) that today is **blocked at the API** (`_start_sync` rejects non-baseline). It is a full
  re-export + **local** diff, **not** an environment delta-patch (which stays deferred — needs the Appian changed-objects API).
  **(2)** A **backend scheduler** (`runtime/scheduler.py`, an asyncio minute-tick, TZ-aware IST, weekdays only) running
  **`application-sync`** (all tracked apps, **07:00 IST**, **serialized** — the Appian export is one-at-a-time / HTTP 409) and
  **`document-library-sync`** (`scope=library`, **08/12/16/20 IST**), with preflight skips (no dev env / no `gws`). Schedule +
  last-run held in **m0012 `scheduled_jobs`** (backend-fixed now; the seam for later user config). **ADR-047** (Accepted).
  genesis-only release → **v0.48.0** (+ m0012). **(Superseded by Phase 45 / ADR-074, genesis v0.76.0: `application-sync` is now enabled by default every 4 h 08:00–20:00 IST weekdays, user-configurable in Settings → General, incremental with full fallbacks.)**
- **Phase 24** — `specs/phase-24-ux-revamp-and-environment-credentials.md` (+ `phase-24-ux-revamp-and-environment-credentials/24-01..24-02`)
  — **UX revamp + environment-scoped credentials** ✅ SHIPPED + COMPLETE (24-01 genesis v0.48.5 + genesis-workflows v0.9.5; 24-02 genesis v0.48.6). **(1, 24-01)** the two core
  Appian MCPs (`appian-dev`/`appian-devops`) take their creds from the **environment** (entered on the env form, stored per-env
  in the SecretProvider `env:<label>` scope, resolved ONLY from the dev env; `LCP_API_PATH` → public env field; `LCP_URL`/
  `APPIAN_DOMAIN` auto-derived + hidden; non-destructive migration of legacy server-scoped creds). **(2, 24-02)**
  **Applications-first IA** — primary nav = Applications · Chat · Runs · Documents; Overview + Catalog move to Settings tabs
  (default Overview). **ADR-048/049** (PROPOSED). Release: genesis-workflows (`mcp-registry.json`) + genesis (+ frontend).
- **Phase 25** — `specs/phase-25-architectural-foundation-hardening.md` (+ `phase-25-architectural-foundation-hardening/25-01..25-10,25-13,25-14`) — **✅ SHIPPED + COMPLETE** (genesis v0.49.0 + v0.50.0, core v0.9.4 + v0.9.5; 25-11 + 25-12 → `specs/backlog/`)
  — **Architectural Foundation Hardening (code-review remediation)** 📝 SPECS DRAFTED; awaiting approval to build. Umbrella +
  **13 active** sub-phase specs covering every action item from `code-review/genesis-production-readiness-review-2026-08-18.md`:
  **25-01** typed SDLC domain + single-authority `LifecycleService` (keystone; C-1/C-2), **25-02** structured logging +
  correlation ids (E-2), **25-03** atomic JSON-store hardening (E-5), **25-04** network-exposure guardrail (D-2), **25-05**
  `AgentProvider` interface (E-3), **25-06** god-module decomposition + service layer (C-3/C-5), **25-07** `ChatModeProfile`
  (C-4), **25-08** concurrency + optimistic locking (D-1), **25-09** `DocumentProvider` interface, **25-10**
  `reliable_agent_step()` helper, **25-12** AI cost & performance pass, **25-13** observability II (metrics + lifecycle audit),
  **25-14** phase release & closeout (tag/ship/document — ADRs→Accepted, pin alignment, bible refresh, review-delta). **Proposed
  ADR-050/051/052.** Sequencing: Phase-0 guardrails (02/03/04) ∥ keystone 25-01 → seams (05/06/07/09/10) → concurrency 08 →
  observability 13 / cost 12 → **capstone 25-14**. **Completability (2026-08-18): all 13 completable with today's app state.**
  **▸ 25-01 ✅ BUILT (2026-08-18, unreleased):** typed `genesis/domain/` + single-authority `LifecycleService` + m0013 audit + spec
  action endpoints (409 on illegal/precondition) + web allowed-action buttons; backend 509 pytest, web 163 vitest, all green;
  committed locally (`d70bd20`+`0b90392`), version held at 0.48.7 (ships via 25-14).
  **▸ 25-02 ✅ BUILT (2026-08-18, unreleased):** structured logging + correlation IDs (`genesis/runtime/logging.py`; zero-dep stdlib configure + contextvars run_id/request_id + JSON/console + redaction), wired into create_app/worker/CLI; commit `c8ec7d6`; backend 521 pytest green.
  **▸ 25-03 ✅ BUILT (2026-08-18, unreleased):** atomic+serialized JSON writes (`genesis_core/util/atomic_json.py`) across custom MCP/CLI stores + environments/secrets/dist; core `bc06930` + genesis `105c538`; core 71 / genesis 522 pytest green.
  **▸ 25-04 ✅ BUILT (2026-08-18, unreleased):** network-exposure guardrail — `genesis serve/up` refuse a non-loopback bind without `--i-understand-no-auth`/env override (logs a warning); commit `0a8f13f`; backend 535 pytest green.
  **▸ 25-05 ✅ BUILT (2026-08-18, unreleased):** `AgentProvider` interface + `KiroAcpProvider` over the workflow-agent turn path (`genesis_core/agents/`); `set_collect_impl` preserved; commit `a2a0ee1`; core 76 pytest green. Chat session-provider deferred.
  **▸ 25-08 ✅ SHIPPED:** optimistic locking (m0014 row_version CAS + StaleWriteError→409 + LifecycleService state-CAS + run-start idempotency; D-1/§17). **▸ RELEASED:** 25-01..25-08 shipped as **genesis v0.49.0 + genesis-core v0.9.4** (2026-08-18, CI green); ADR-050/051 Accepted; 25-09..25-14 remain.
  **▸ 25-09 ✅ BUILT (unreleased):** DocumentProvider interface + GoogleDriveProvider (`cd9abc8`); DocumentSyncEngine depends on the interface; ADR-052 Proposed until its release. **▸ 25-10 ⏳ IN PROGRESS:**   **▸ 25-10 ◑ CORE BUILT (unreleased):** reliable_agent_step() in genesis-core (`679ee73`, +4 tests); workflow adoption deferred (user) + release-gated. **▸ NEXT = 25-13** (observability; 25-12 cost pass depends on it + needs live telemetry).
  **▸ 25-13 ✅ BUILT (unreleased):** observability — `/system/metrics` + `/runs/{id}/provenance` + feature lifecycle Activity feed + web Activity/Metrics (`cba724e`+`3504c28`). **▸ Remaining: 25-12** (cost pass, data-driven/live-gated) + **25-14** closeout.
  **▸ PHASE 25 COMPLETE (2026-08-19):** 25-09/25-10-core/25-13 shipped in **genesis v0.50.0 + genesis-core v0.9.5** (CI green); ADR-050/051/052 Accepted + ADR-026 amended; 25-11 + 25-12 in backlog.
  🅱️ **Backlog:** former **25-11** per-story execution + WorkflowRun linkage → `specs/backlog/phase-25-11-per-story-execution.md`
  (new product capability; gated on Breakdown→Stories + per-stage workflows). Do NOT start until explicitly approved.
- **Phase 26** — `specs/phase-26-agentic-memory-layer.md` (+ `phase-26-agentic-memory-layer/26-01..26-08`) —
  **Agentic Memory Layer** 📋 SPEC DRAFT; awaiting approval to implement. Distil the conversations already in `genesis.db` into a
  persistent, self-maintaining **agentic memory** — **personal** (a named user's preferences/rules/habits, never shared) vs
  **shared** (application knowledge/architecture/decisions/patterns, **entity-anchored** with **traversable relationships**), ×
  three types (semantic/episodic/procedural), **bi-temporal**. Formed in the background by a **nightly `memory-consolidation`
  workflow** (extract → classify → entities/relationships → reconcile ADD/UPDATE/INVALIDATE/NOOP → embed → write) and refined by
  a periodic **`memory-maintenance` "dreaming" workflow** (reflect / dedup-evolve / invalidate / decay / communities); all
  reasoning is **Kiro-over-ACP inside deterministic workflows** (ADR-001 + reliability trio), embeddings by a **small local
  model** in the worker/MCP subprocess (no outbound data). Stored in a **separate `~/.genesis/memory.db` on SQLite + sqlite-vec +
  FTS5** behind **DB-agnostic seams** (`MemoryStore`/`GraphStore`/`VectorIndex`/`Embedder`) — the ADR-030 "transcript RAG"
  trigger, with an easy **Postgres + pgvector** swap later. Read via a **separate read-only `genesis-memory` MCP** (hybrid
  semantic+keyword+entity × recency × importance; **MCP-only** injection). Plus a **Memory Management UI (26-08)** — a rich,
  accessible browser to **see + edit** memory centered on an **Obsidian-style force-directed memory graph** (hover-highlight,
  local-graph focus, search/filters, bi-temporal time-scrub, community coloring) + list/inspector/review-queue + a browser-only
  curation API; human edits are **authoritative** and **protected from the nightly maintenance**, while the agent MCP stays
  read-only. Fires on the **Phase-23 scheduler**; personal memory keyed to a **named user**. **Proposed ADR-053** (Memory Layer) +
  **ADR-054** (store/infra + local embedder). Grounded in a survey of mem0/Zep-Graphiti/Letta/LangMem/cognee/A-MEM/generative-agents;
  integrates **no** external memory service. Repos: **genesis** + **genesis-workflows** (genesis-core likely unchanged).
  distribution; wheel+index deferred as a phase-2 transport; Docker/native-app out). genesis-only release → **v0.47.0**.

- **Phases 27–48** — see the full phase table in [`README.md`](README.md) (each row links its `specs/phase-NN-*.md`; as-built in `progress/`). Latest: **Phase 48 The Object Wiki in the application page** ✅ SHIPPED 2026-10-21 (genesis v0.78.0).

**Build order per Q13:** Phases 1–6 constitute the "complete application + ERD workflow" milestone (Studio as interim UI). Phase 7 (custom workbench) + the 07-code-review-fixes program follow. **Phase 8 is the Settings & Integrations Revamp** (enterprise-polish track); a few more polish phases are planned before the **skill-migration program** (backlog) resumes.

---

## 3a. Progress logs (implementation detail per phase)

Detailed, evidence-backed records of what was actually built each phase live in
`progress/`. The specs in `specs/` are the plan; these are the as-built record.

| Phase | Progress log | Status |
|---|---|---|
| 1 | [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md) | ✅ Complete (M1) — repos/tags, modules, evidence, decisions |
| 2 | [`progress/phase-02-implementation.md`](progress/phase-02-implementation.md) | ✅ Complete (M2) — contract, library, scaffolder, reliability lint (CI-proven) |
| 3 | [`progress/phase-03-implementation.md`](progress/phase-03-implementation.md) | ✅ Complete (M3) — GitLab pull, install, lockfile, loader + compat gate |
| 4 | [`progress/phase-04-implementation.md`](progress/phase-04-implementation.md) | ✅ Complete (M4) — SecretProvider, MCP cards, env registry, health, retention, ConfigService |
| 5 | [`progress/phase-05-implementation.md`](progress/phase-05-implementation.md) | ✅ Complete (M5) — subprocess worker, run store, RunManager (3 HITL modes), FastAPI + SSE, Studio doc |
| 6 | [`progress/phase-06-implementation.md`](progress/phase-06-implementation.md) | ✅ Complete (M6) — erd-generation reference workflow (2 trios, approval gate, cli node) |
| 7 | [`progress/phase-07-implementation.md`](progress/phase-07-implementation.md) | ✅ Complete (M7) — React+TS web workbench (6 surfaces, 3 HITL modes, SSE); `genesis serve` |
| 8–46 | `progress/phase-NN-*.md` (one per phase, e.g. [`progress/phase-46-spec-change-requests.md`](progress/phase-46-spec-change-requests.md)) — indexed from the phase table in [`README.md`](README.md) | ✅ Complete through Phase 45 (2026-10-13) |

---

## 4. Component reuse from solutions-copilot

| Genesis needs | Reuse (reimplemented in Genesis) | Source doc/module |
|---|---|---|
| Catalog/registry | Manifest → Catalog projection + lockfile | manifest.ts, registry.ts, lockfile.ts |
| MCP wiring | Template → generated config, `${VAR}` substitution, owner/env-key classification | mcpConfig.ts, secretFields.ts |
| Secrets | SecretProvider (plaintext→keychain), `scope/VAR` vault keys | secretProvider.ts |
| Env registry | Credential-free `environments.json`, label resolution | registry.ts, steering.ts |
| GitLab pull | REST v4 client, tag-based update detection | gitlab.ts, planner.ts |
| Handoff | `.kiro/analysis/*.md` loss-free docs → Genesis blackboard | doc 11 §7 |
| Workflow specs | The 45 skills (SKILL.md + references, ~35,900 lines) | solutions-copilot `.kiro/skills/**` |

---

## 5. Open items to validate early

1. **LCP MCP as the "Appian authoring" unlock** — solutions-copilot's stated blocker was "no reliable agent path to author Appian objects." Validate that the `lcp-mcp-server` can create record types/interfaces/process models/sites within a workflow (Phase 6/8 dependency for write-path workflows).
2. **ACP + `KIRO_API_KEY`** — confirm whether ACP honors API-key auth for headless/CI contexts (default is local interactive login).
3. **Cost/latency of many one-shot ACP sessions** — measure; add a session-pool later if needed.
4. **HITL when actor is a sub-agent** — LangGraph `interrupt()` gates at the graph level, sidestepping solutions-copilot's open question.

---

## 6. Status log

From Phase 47 on: ≤ 5 lines per phase; detail lives in `progress/`.

- **2026-10-21 — Phase 48 (Object Wiki UI): ✅ SHIPPED genesis v0.78.0 (no migration, DB v24; pins unchanged).** Object
  Wiki tab + per-object history page, URL-addressable app tabs, two read-only wiki endpoints; pytest 1187, vitest 380.
  First phase run end to end by the five agents (pilot); 48-04 took 6 review rounds (narrow-width table, stale bundle B1).
  Lessons L-089/L-090. Details: `progress/phase-48-object-wiki-ui.md`.
- **2026-10-20 — Phase 47 (Agent Context System): ✅ SHIPPED (project-tracker only; ADR-077 Accepted).** Tiered context
  (always-loaded core ≈1.5 % of a 1M window; per-task packs via `genesis-ctx`) + five CLI-3 role agents installed from
  `agent-system/`; move-only migration proven lossless (0 of 1,338 baseline units missing); 47-09 review SHIP after 3 rounds.
  Details: `progress/phase-47-agent-context-system.md`. Pilot carried into Phase 48.

> 📦 Moved verbatim to [archive/tracker-status-log.md](archive/tracker-status-log.md) (Phase 47-04, 2026-10-20). Search with `genesis-ctx search <term> --archive`.
