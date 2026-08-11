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
| **Status** | 🟢 Phases 1–7 COMPLETE (M1–M7) + **M7.1 WEB REVAMP COMPLETE** (all 07-01…07-10 shipped). Workbench runs real workflows: **hello-appian green end-to-end**; **erd-generation** past MCP init into the live Atlas fetch. Latest tags: kiro-agent-sdk **v0.1.0**, genesis-core **v0.4.0**, genesis **v0.11.0**, genesis-workflows **v0.3.1**. The enterprise-grade, Overcut-inspired app is the shipped bundle (interim workbench retired at the 07-10 cutover; `genesis serve` serves only the new SPA). 54 platform + 59 frontend + 16 core + 9 workflow tests green; lint + tsc strict clean; CI green (incl. the stale-bundle guard). Next: **Phase 8 (skill migration)**. |
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

> **Note:** Phases 17 (Business Map), 18 (Parser accuracy), 19 (Document Library), 20 (Features & Spec authoring) are tracked
> authoritatively in **§6 (status log)** + **`AGENT_ONBOARDING.md` §9** + **`README.md`** — this index table was not back-filled
> for them.

- **Phase 20** — `specs/phase-20-features-and-spec-authoring.md` (+ `phase-20-features-and-spec-authoring/20-01..20-06`) —
  **Features & Spec Authoring** 📋 SPEC DRAFT. Per-app **Features** (m0010 `kb_features`) + a conversationally-authored
  **Spec**: a reused Chat (genesis-kb + injected business-artifact context) authors an **HTML-authoritative** spec in the
  fs-write sandbox, reviewed in an **embedded, annotatable** surface (the **vendored Lavish annotation SDK**, MIT → an
  annotation-to-chat bridge), with status draft→in-progress→in-review→completed + milestone revisions + Markdown export.
  Mostly **genesis**. **ADR-042** (Features & Specs model) + **ADR-043** (embed Lavish SDK) — Proposed.

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

- **2026-08-11 (Phase 20 — Features & Spec Authoring — 📋 SPEC DRAFTED; awaiting approval to implement):** New feature spec set
  written after a code-grounded evaluation of the **Lavish** annotation tool (`kunchenguid/lavish-axi`, MIT). Decided **Path B
  (embed)**: the injected browser SDK makes **no server calls** and talks only via `parent.postMessage` (`lavish:queuePrompt`
  / `sendQueuedPrompts`, durable text-range anchors), so we **vendor** `artifact-sdk.js`(+`mermaid-node.js`), host the spec in
  a **same-origin sandboxed iframe** inside the feature page, and bridge annotations into a **reused Chat** — no Lavish server/
  CLI/poll/export/ht-ml.app, no Node ≥22 runtime, no second window. **Feature** = first-class app sub-entity (**m0010**
  `kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`, cascade-with-app); **Spec** = a Chat-authored (**ADR-001
  preserved** — no workflow) **HTML-authoritative** artifact written to the Phase-14 fs sandbox, KB-aware via `genesis-kb`, with
  **"Add context"** injecting the app's Phase-19 business artifacts (reuse `build_evidence_pack` docs); status
  **draft→in-progress→in-review→completed** + milestone revisions + **Markdown export**. Scope v1 = features + the spec only
  (design docs / user stories later). Mostly a **genesis**-only release. Specs: `specs/phase-20-features-and-spec-authoring.md`
  (+ `phase-20-features-and-spec-authoring/20-01..20-06`); **ADR-042** (Features & Specs model) + **ADR-043** (embed the Lavish
  SDK) — both **Proposed**. Suggested build order 20-01 (embed spike) → 20-02 (m0010 + `FeatureStore`) → 20-03 (Features tab +
  feature page) → 20-04 (spec chat backend) → 20-05 (embedded review + annotation bridge) → 20-06 (release). **DRAFT — no code
  yet.**

- **2026-08-11 (Phase 19 — Genesis Document Library — ✅ SHIPPED + COMPLETE; 19-01..19-08, all CI green):** Built the
  feature. **19-01 spike ✅** (live-verified gws OAuth + export; `spike/2026-08-11-gws-oauth-and-export.md`). **19-02 managed-native
  `gws` connector ✅ code-complete + `genesis cli` subcommands + a LIVE isolated-mode smoke test PASSED** (installed the real gws
  into `~/.genesis/cli-tools/gws/`, drove Genesis's own read-only `gws auth login`, verified `connected` + a Drive `list_files`
  read; the user's `~/.config/gws` untouched). **19-03 data model ✅** — migration **m0009** (`kb_documents`/`kb_document_links`/
  `kb_document_sections`, schema v9) + `DocumentStore` (global dedup store + app links; **untrack unlinks, never deletes** —
  ADR-041). **19-04 parsing pipeline ✅** — `kb/doc_parsing.py` (per-type PDF/DOCX/XLSX/CSV/MD/TXT → canonical Markdown + per-tab
  JSON tables + heading sections + `content_hash`; **deps pinned à-la-carte `pypdf`/`python-docx`/`openpyxl`**) + gws
  `export_file`/`download_file` + Google-native→binary/text convergence + `store_parsed` to `~/.genesis/kb-documents/<id>/`.
  **19-05 sync-documents ✅** — `DocumentSyncEngine` (`kb/doc_sync.py`, injected via `ctx.extras['document_sync']`) + the
  deterministic **`sync-documents`** workflow (genesis-workflows; program-only, async `to_thread` write, fingerprint
  change-detection) + `api/documents.py` (upload/gdrive add, link/unlink, sync single|app|library with friendly 409, list/
  search/get/delete). **19-06 consumption ✅** — `genesis-kb` MCP `list/get/search_documents` (auto-trusted in chat) +
  `KbStore.build_evidence_pack` now includes an app's linked docs as bounded code-free excerpts (`documents` key) →
  `design-doc`/`generate-business-map` document-aware. **19-07 web ✅** — global **Document Library** page + per-app **Business
  Artifacts** tab (5th app-detail tab; add via upload/Drive/pick-from-library + unlink/sync) + a **Settings→CLI Google Workspace
  connector card** (Connect/Reconnect/Disconnect); Sidebar entry + `/documents` routes; reuses the 07-09 DocumentPreview.
  **Decisions locked:** global first-class document store + app-link table (ADR-041); `gws` as a managed-native CLI (ADR-040)
  with an **isolated** config dir reading the OAuth client from the dotfiles `~/.config/gws/client_secret.json` (**no shipped
  token**, dotfiles = prerequisite), read-only scopes. **Tests green (working tree):** genesis **375**, genesis-core **65**,
  genesis-workflows **75** + `validate_library` (7), **web 138 Vitest (tsc clean, eslint 0 errors, `npm run build` OK)** — ruff
  clean. **19-08 release ✅** — **genesis-core v0.9.2 → genesis v0.44.0 → genesis-workflows v0.9.3**, committed + tagged + pushed,
  **all CI green**; ADR-040/041 flipped to **Accepted**. **Live-accepted:** a real Google Drive doc (incl. an .xlsx) added →
  auto-synced via the `gws` export → parsed → viewed full-screen. **PHASE 19 COMPLETE.**
  **Full as-built: `progress/phase-19-document-library.md`.** Specs: `specs/phase-19-document-library.md`
  (+ `19-01..19-08`); ADR-040/041 (Accepted).

- **2026-08-11 (Phase 19-01 — `gws` OAuth spike — ✅ DONE, PASS):** Ran the load-bearing feasibility spike against the real
  Google Workspace CLI (`gws 0.22.5`, `brew install googleworkspace-cli`, macOS arm64). **All locally-verifiable questions
  passed:** (Q1) `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` + `KEYRING_BACKEND=file` fully isolate creds under our dir (no `~/.config/gws`
  created); (Q2/Q3) under a **non-interactive subprocess** (stdin closed, no TTY) `gws auth login` prints a **parseable OAuth
  URL to stderr** and blocks on a `localhost:<ephemeral>` callback listener — so Genesis can spawn it, scrape the URL, and the
  browser callback hits gws's own listener (no proxy); (Q5) a no-auth API call returns `{code:401,reason:authError}` + **exit
  2** (reconnect signal); (Q6) `--readonly -s drive,docs,sheets,slides` yields exactly the read-only scope set; export + the
  Drive sync fingerprint fields (`id,name,mimeType,modifiedTime,version,md5Checksum`) both confirmed via `gws schema` /
  `gws drive files export`. **Primary browser-OAuth-under-subprocess design is viable — `auth export` fallback documented but
  not needed as primary; no spec change.** Full login completion + real Drive/Docs/Sheets calls remain a **manual acceptance**
  step (needs the shared org OAuth client id/secret + a human browser approval — the one dependency to obtain). Findings:
  `spike/2026-08-11-gws-oauth-and-export.md`; 19-01 marked DONE. **Ready to start 19-02** once the shared OAuth client is
  provisioned.

- **2026-08-11 (Phase 19 — Genesis Document Library — 📋 SPEC DRAFTED; awaiting approval to implement):** New feature spec set
  written after a design discussion with the user. **Goal:** attach the business documents that describe an application (the
  PDFs/Word/Excel/Google Docs in Google Drive) to Genesis, parse them into LLM-consumable Markdown (+ JSON for tabular), and
  use them **alongside the Appian KB** for spec generation / design discussion. **Decided design:** documents are a **global,
  first-class store** (`kb_documents`, one copy per unique doc, dedup by Drive file-id / content-hash) **linked into apps**
  (`kb_document_links`) — the same doc is stored/synced once, never per-app; **untrack unlinks, never deletes** (a deliberate
  break from the per-app table-scoped untrack — **ADR-041**). **Latest-version-only** on disk (sync overwrites). Google Drive
  is reached via the **Google Workspace CLI (`gws`)** integrated as a **managed-native CLI connector** (a lighter cousin of the
  ADR-038 native-MCP installer — `gws` is a single static binary), configured in Settings→CLI, authenticated with `gws`'s
  **standard OAuth** browser login using the shared org OAuth client (the dotfiles approach), **read-only** Drive/Docs/Sheets/
  Slides scopes only — **ADR-040**. Sync is a deterministic program-only **`sync-documents`** workflow (mirrors
  `sync-application`; blocking writes via `asyncio.to_thread`); **manual "Sync now" first, scheduler deferred**. Consumed via
  `genesis-kb` document tools + `KbStore.build_evidence_pack`. Surfaces: a global **Document Library** page + a per-app
  **Business Artifacts** tab. **Sub-phases:** 19-01 gws-OAuth spike (load-bearing, first) · 19-02 managed-native gws connector +
  standard OAuth · 19-03 m0009 data model + DocumentStore · 19-04 parsing pipeline (gws export + binary→MD/JSON; dep pinned) ·
  19-05 sync-documents workflow · 19-06 genesis-kb consumption + evidence pack · 19-07 web · 19-08 release + acceptance.
  **Release chain:** genesis-core (CliRegistry managed resolution, additive) → genesis (m0009 + store + installer + connector +
  parsing + api + web) → genesis-workflows (`sync-documents` + `gws` cli-registry entry). Specs:
  `specs/phase-19-document-library.md` (+ `phase-19-document-library/19-01..19-08`); **ADR-040/041** (Proposed). **DRAFT — no
  code yet; awaiting the user's go-ahead to implement.**

- **2026-08-10 (Remove the top bar + relocate theme toggle — genesis v0.43.0):** The `Topbar` (which held only the theme toggle after breadcrumbs were removed) is gone entirely; `AppShell` = Sidebar + content (+ optional right rail). The dark/light **theme toggle** moved to **Settings → General** as a new `AppearanceSection` (Switch). `ChatPage` now fills full height (no topbar to subtract); deleted the unused `Topbar.tsx`. Frontend-only release; web suite 132 green, typecheck clean, 0 eslint errors, CI green (genesis + frontend).

- **2026-08-10 (Remove top breadcrumb navigation — genesis v0.42.0):** Per user request, dropped the `Topbar`
  breadcrumb `<nav>` from all pages (kept the theme + right-panel toggles, header now right-aligns them) and cleaned up
  the `crumbs`/`Crumb` plumbing through `AppShell` + `RootLayout` (removed `crumbsFor`/`LABELS`/`useLocation`).
  Frontend-only release; web suite 132 green, typecheck+eslint clean, CI green (genesis + frontend).

- **2026-08-10 (Applications detail UI polish — genesis v0.41.0):** Per user feedback on the Application page: the
  live **sync status bar** (below the app name/uuid) now shows **only while a sync is in progress** (running/pending) —
  older syncs remain in the **Syncs** tab; and the **Objects** and **Bundles** tabs are **removed** (detail tabs =
  Business Map | Overview | Syncs | Releases). Removed the unused ObjectsTab/BundlesTab/SearchBox + imports. Frontend-only
  release (web/static rebuilt + committed); web suite 132 green, typecheck+eslint clean, CI green (genesis + frontend).

- **2026-08-07 (Phase 18 — Parser Accuracy Overhaul — ✅ SHIPPED + LIVE-VALIDATED; PHASE 18 COMPLETE):** Fixed a
  catastrophic dependency under-linking bug in `genesis-appian-parser` — a real 2,620-object app reported **804 orphans
  (30.7%), 803 provably false**. Root cause: field-path-scoped reference extraction (no Constants/AI-Skills/Decisions/
  Translation-Strings/Documents) + "orphan" defined as "not bundled" rather than "unreferenced". Reverified against real
  XML + the original **Atlas** parser + the **Jarvis** plugin (best-of-both) and drove accuracy **>95%**, verified by a
  committed raw-XML reference oracle: **edge recall 0.324 → 0.978, precision → 0.999, referenced-object recall 0.869 →
  1.0, orphans 804 → 0, false-orphan rate 0.311 → 0.0, edges 5,084 → 10,617, 12 cross-app integration points**. Also
  added the user's **APPREF/ENTRYPOINT** cross-app integration-point classification (by-name `rulereferencebyname`,
  ENTRYPOINT/APPREF naming + 10-category taxonomy, orphan-exempt). Delivered 18-01..18-05 on `genesis-appian-parser` main
  (afcb66d/31567fa/a357db6/c86b20c/44472c4), parser suite 13 → 25 green, ruff clean, ≥95% CI gate. **Live-validated on
  the user's real app** (delete + re-add baseline sync via the editable install). Spec
  `specs/phase-18-parser-accuracy.md`, progress `progress/phase-18-parser-accuracy.md`. **18-06 released:
  `genesis-appian-parser` v0.2.0 (05d0fea) → genesis v0.40.0 (8477945) → genesis-workflows v0.9.2 (79edb75), all CI
  green** (+ deferred Tempo Report / generic-haul parsers).

- **2026-08-07 (Phase 17-06 SHIPPED ✅ — PHASE 17 COMPLETE):** Hardening from the live run. **genesis v0.39.0** —
  `business-map/generate` now returns a friendly **409** ("install the workflow library") when `generate-business-map`
  isn't installed, instead of a raw 500 (pre-checks `run_manager.loader.installed()`; +1 API test → 14). **genesis-
  workflows v0.9.1** — **recalibrated the coverage floor 0.6 → 0.3**: coverage is a *lenient "is the map non-trivial"*
  signal (a good business map consolidates heavily → references only a fraction of significant objects), with the human
  **review** gate as the real backstop (the first live map scored 0.355 and was correctly review-gated + approved).
  Live-acceptance **PASSED** (coherent business story, no technical vocabulary). 302 pytest + 11 workflow tests +
  validate_library + CI green (genesis 27f1e73, workflows 1bb26b8). Library reinstalled locally so the fix is live.
  **Phase 17 — Business Application Map — is COMPLETE (17-01..17-06 shipped, live-accepted).**

- **2026-08-07 (Phase 17 — first live map generated + readability/detail iterations, genesis v0.37.0 → v0.38.0):**
  The **first real business-map generation** ran against the 2,763-object **"AS GSS Full Application"** and produced a
  genuinely rich, high-quality model — domain *"Procurement source selection and proposal evaluation"*, **10
  capabilities, 10 entities, 5 actors, a 14-stage value stream** with two real decision branches (review→accepted/
  returned; signatures?) — 6.07 credits, coverage **0.355** (< the 0.6 gate → correctly routed to the **review** gate,
  approved). The model was excellent; the **rendering** wasn't, so two follow-ups shipped: **genesis v0.37.0** — readable
  zoom floor + MiniMap + taller canvas + richer stage cards; the capability view redesigned as a clean **radial
  constellation** (entities as chips, no crisscross). **genesis v0.38.0** — **click any node → full detail popup**
  (untruncated stage/capability info + "leads to" branches + connections + "highlight its stages"); value-stream edges →
  orthogonal **smoothstep** routing + arrowheads + wider spacing so paths stop overlapping. Live findings for **17-06**:
  (a) a newly-released library workflow must be `genesis install`-ed before it runs — an uninstalled workflow currently
  **500s** on generate (add a friendly error); (b) **recalibrate coverage** (0.355 for a good map suggests the
  denominator over-counts). 131 web vitest + 301 pytest + CI (frontend+genesis) green across both releases. See
  `progress/phase-17-business-application-map.md`.

- **2026-08-07 (Phase 17-05 — Business Map web view SHIPPED ✅ genesis v0.36.0):** The user-facing payoff — a
  **business-language** view as the **primary/first tab** on the Applications detail page. States
  (absent → *Generate* / generating → live / ready / **stale** banner / failed); a header strip (domain · summary ·
  coverage % · credits · "based on sync #N" · **Regenerate**); a segmented **A | B** toggle; and two coordinated
  **React Flow** canvases — **(A)** the end-to-end **value stream** (left→right dagre; start/activity/decision/end
  stages + branch labels + actor/entity chips) and **(B)** the **capability constellation** (domain → capabilities →
  entities + hand-offs) — linked by a shared capability **focus + context**. Business-styled node components (reuse
  `@xyflow/react` + `@dagrejs/dagre`; **not** the technical `NodeCard`). Types + api client + hooks
  (`useBusinessMap`/`useBusinessMapStatus`[poll]/`useGenerateBusinessMap`). genesis **v0.36.0** (commit f330875, CI
  green pipeline 6523164 — **frontend + genesis** both green); **131 web vitest** + tsc + eslint green; web/static
  rebuilt. **Next:** 17-06 (validation/quality + manual live-acceptance against the real synced app) — the last
  Phase-17 sub-phase.

- **2026-08-07 (Phase 17-03 — `generate-business-map` workflow SHIPPED ✅ genesis-workflows v0.9.0):** The core of
  the Business Application Map — a **deterministic LangGraph workflow** that synthesizes the business model from the
  code-free KB. Topology: `resolve_inputs → extract_evidence → v_evidence → [synthesize_capabilities → v_capabilities]
  → [synthesize_value_streams → v_value_streams] → compose_model → v_model → (persist | review | escalate)`. **Two
  narrow Kiro agent nodes** (B capabilities, then A value streams) each wrapped by the **reliability trio** (ADR-011);
  the **evidence pack** (`KbStore.build_evidence_pack`) is the complete, self-contained agent input (**no MCP** — a
  scoped 17-03 decision: stronger anti-hallucination + no genesis-kb-in-workflow-registry wiring needed). Grounding
  guards: **evidence integrity** (every cited uuid ⊆ the pack), **business-language guard** (banned technical words +
  SAIL markers like `rule!`/`SYNCEDRECORD`), **value-stream DAG** well-formedness, and a **coverage gate**
  (`COVERAGE_MIN=0.6`) that routes a thin model to the **review** gate; validator exhaustion → the **escalate** gate.
  `persist_map` writes via `asyncio.to_thread(upsert_business_map)` (16-03 loop-deadlock lesson). genesis-workflows
  **v0.9.0** (commit 4caf9a9, pins genesis v0.35.0; CI green pipeline 6523136 — workflow-tests + library-validate +
  skills-validate); **11 workflow tests + full suite 68 + validate_library(6) + ruff** green. **Next:** 17-05 (web
  Business Map view — React Flow A+B) → 17-06 (validation/quality/acceptance against the real app).

- **2026-08-07 (Phase 17 backend — SHIPPED ✅ genesis v0.35.0):** The Business Application Map backend
  foundation (no UI yet). **17-01** migration **m0008 `kb_business_maps`** (code-free `BusinessModel`
  store; one current map per app; stale-on-sync) + `KbStore` upsert/get/status; **17-02**
  `KbStore.build_evidence_pack` — deterministic, capped, code-free KB→business evidence pack
  (entities/activities/surfaces/capability-signals/actors/structure), verified against the real
  2,763-object app (significant_total=198); **17-04** Business Map API (`GET business-map`, `POST
  business-map/generate` [KB-only, 409 until a completed baseline], `GET business-map/status`). genesis
  **v0.35.0** (commit f59aea6, CI green pipeline 6523081; frontend job skipped — no web change); **301
  pytest** + ruff green. **Next:** 17-03 (the `generate-business-map` workflow in genesis-workflows,
  pins genesis v0.35.0) → 17-05 web view → 17-06 quality/acceptance.

- **2026-08-07 (Phase 17 — Business Application Map — SPEC DRAFTED 📋; docs only, awaiting approval to implement):** New
  phase specced end-to-end. Goal: an **agent-synthesized, business-language** map of what an application does for the
  business, end to end — **(A)** value stream(s) + **(B)** capability constellation — deliberately **NOT** a technical
  view (no objects/bundles/pages/properties; those terms are banned from the output). Business meaning is *derived*, so it
  is produced by a new **deterministic `generate-business-map` LangGraph workflow** (narrow agent nodes wrapped by the
  reliability trio; **evidence-grounding + coverage + business-language** validators make it un-hallucinated — every
  business element cites real KB object UUIDs; HITL review gate; async `to_thread` persist) reading the **code-free KB
  only** via `genesis-kb`/`KbStore`. Persists a versioned **`BusinessModel v1`** in **migration m0008 `kb_business_maps`**
  (code-free, point-in-time, stale-on-sync); web renders A+B on the existing **@xyflow/react + dagre** stack with
  focus+context linking. Deliverables (all in project-tracker): `specs/phase-17-business-application-map.md` (umbrella) +
  `phase-17-business-application-map/business-model-contract.md` + `17-01..17-06` + **ADR-039**. Release chain when built:
  genesis (m0008 + KbStore + evidence extractor + API + web) → genesis-workflows (workflow + catalog); genesis-core likely
  unchanged. **No code written — awaiting the go-ahead.**

- **2026-08-06 (Live-run fixes + UI polish SHIPPED ✅; genesis v0.34.0 + genesis-workflows v0.8.6→v0.8.7):** First
  live sync of a real app surfaced two bugs, both fixed + regression-tested (verified against a live **2516-object**
  app): **(1) export 405** — `sync-application`'s Deployment REST export was hand-rolled wrong; corrected to the real
  contract from the installed DevOps MCP (**multipart `POST /deployments`** + `Action-Type: export` + `{uuids,
  exportType, name}`; poll; download the `packageZip` URL; `appian-api-key` auth) — **genesis-workflows v0.8.6**.
  **(2) UNIQUE-constraint crash** — real exports repeat object UUIDs; `KbStore.apply` now de-dupes by UUID (edges by
  triple) and baseline `check_kb` reconciliation is `distinct ≤ parsed` — **genesis v0.34.0** + **genesis-workflows
  v0.8.7** (workflow v0.2.2, pin → genesis v0.34.0). **UI/UX:** managed-native (Dev/DevOps) bundle install/rollback
  moved out of the top Settings→MCP box **into each server's detail page** (new `NativeMcpSection`; removed
  `NativeMcpPanel`) + fixed right-pane horizontal overflow; **Applications** cards + detail Overview redesigned
  (icon/mono-uuid/stat-tiles/sync-footer; MetricCard KPIs + object-type bars + top bundles; row hover). Added
  **`scripts/genesisctl.sh`** (start/stop/status/logs/open). CI green (genesis #6514160 genesis+frontend; workflows
  #6514162). 288 pytest · 57 workflow · 126 web · ruff/eslint/tsc clean.

- **2026-08-06 (Phase 16-07 — delta refresh, Option A SHIPPED ✅; genesis-workflows v0.8.5):** `sync-application` v0.2.0
  gains a **delta** mode without the (not-yet-built) Appian changed-objects API: a **full re-export + SCD-2
  delta-merge** (`KbStore.apply(mode='delta')` diffs the re-parse by `diff_hash` — opens new/modified, **closes removed
  [inferred]**, recomputes bundles, records the `[last-sync,now]` window). `resolve_inputs` requires an existing
  baseline for delta; `check_kb` is mode-aware; the report carries `mode`+`window`. **Confirmed the Dev MCP cannot back
  a changed-in-window query** (no modified-since tool; objects carry no modified timestamp) → the true incremental
  delta needs a new Appian API and stays deferred (backlog §1.3), along with the scheduler (§1.4) + per-release
  changelog (§1.5). 55 workflow tests + `validate_library` green; CI green (pipeline 6513690). genesis dev pin →
  v0.33.0. See `progress/phase-16-07-delta-refresh.md`.

- **2026-08-06 (Phase 16-05 — `genesis-kb` MCP server + CHAT cutover SHIPPED ✅; genesis v0.33.0):** The internal,
  read-only Appian knowledge-base MCP. **`genesis/mcp/kb_server.py`** (NEW) — a stdio JSON-RPC 2.0 server modeled on
  `introspection_server.py` (read-only `mode=ro` genesis.db, 32 KB cap, `-m genesis.mcp.kb_server --db <db>`), exposing
  the **17 Tier-1 tools** over `KbStore` with **Atlas-mirrored shapes**. **`KbStore`** gained the 7 remaining reads
  (entry-points, dependents/precedents batch, shared, hub, dependency-path BFS, transitive-deps BFS; current-state only).
  **Live code** via `genesis/kb/dev_mcp.py` `object_code` (type→Dev-MCP getter map + defensive parse; graceful
  `code_status:"unavailable"`, never fabricated — ADR-037/032). **Chat cut over** (`chat/mcp.py`): wires `genesis-kb`
  (always) + best-effort `@appian-dev` for live code; **`appian-atlas` dropped from chat**. **288 pytest green**
  (+14), ruff clean; CI green (pipeline 6513536, `frontend` correctly skipped — no web change).
  **⚠️ Phased-cutover decision (2026-08-06):** `erd-generation` + `design-doc` **STAY on `appian-atlas`** (and Jarvis)
  until the KB reaches parity — they depend on the **Section-C schema tools (deferred)** + the **16-06 versioning tools
  (backlog, AP-62096)**, which `genesis-kb` iteration-1 omits. `appian-atlas` remains registered; both workflows'
  `required_mcp` unchanged; genesis-workflows not re-released. Full workflow cutover tracked as **16-05b**. Documented
  in the phase-16 umbrella spec. See `progress/phase-16-05-kb-mcp-and-cutover.md`.

- **2026-08-05 (Phase 16-04 — Applications surface SHIPPED ✅; genesis v0.32.0):** The user-facing surface over the
  internal Appian KB — the first consumer of the managed-native Dev MCP (16-08). **Backend** `genesis/api/applications.py`
  (`register_applications_routes` over `KbStore` + `RunManager`): `GET /applications` (tracked, from `list_applications`),
  `GET /applications/available` (apps in the **dev-tagged** env not yet tracked, enumerated via the Dev MCP), `POST
  /applications` (resolve `dev_environment()` [400 if none] → `register_application` → start a **baseline
  `sync-application` run**), `GET /applications/{uuid}` (overview+releases+syncs), `POST /{uuid}/sync` (baseline; delta→400,
  16-07), `GET /{uuid}/sync-status` (latest sync run status + kb_syncs counts), `GET /{uuid}/objects|objects/{uuid}|
  bundles|bundles/{id}`, `DELETE /{uuid}` (table-scoped untrack). New `genesis/kb/dev_mcp.py` (direct-stdio
  `tools/call listApplications`, reusing the merged-registry managed launch+secret resolution; best-effort + defensive
  parse; manual-UUID fallback). `KbStore` + `list_syncs`/`latest_sync`. `create_app` wires the router + `KbStore` on
  `app.state`; FastAPI `0.32.0`. **Web** `features/applications/` — Applications page (tracked-app cards + Add), the Add
  dialog (Dev-MCP available list + manual UUID), the detail (Tabs Overview|Objects|Bundles|Syncs|Releases + live
  SyncStatus + Sync-now + untrack), `lib/api/applications.ts`, `types/applications.ts`, hooks (poll while syncing),
  Sidebar **Applications** under Library (`AppWindow`), router entries. **Verified:** `tests/test_applications_api.py`
  (8) + `applications.test.tsx` (4); genesis **274** pytest + web **125** vitest; ruff/eslint/tsc clean; `web/static`
  rebuilt. **CI green #6504611** (`genesis` + `frontend`). Because this release changed `web/**`, the `frontend`
  **stale-bundle guard ran green — this also CLOSES the 16-08 Stage-B gap** (that guard hadn't run: v0.31.0's frontend
  job died on a transient Gitaly 500 and v0.31.1 touched no web). Progress: `progress/phase-16-04-applications-surface.md`.
  **Next: 16-05** (`genesis-kb` MCP + cutover — the headline).

- **2026-08-05 (Phase 16-08 Stage B — managed-native Dev/DevOps MCP installer SHIPPED ✅; genesis-core v0.9.1 + genesis
  v0.31.1 + genesis-workflows v0.8.4):** The second half of 16-08 — **Phase 16-08 is now COMPLETE**. Built to the
  no-auto-update-source decision: **install-from-local-bundle + versioning + rollback only**.
  - **genesis-core v0.9.1** — `McpRegistry` gains a `launch_provider` kwarg: an entry marked `"managed": "<id>"` resolves
    its **command/args** from `launch_provider(id)` at launch (env `${VAR}` list stays on the entry, resolved as usual);
    `is_managed()` accessor; fail-fast when a managed server isn't installed. Additive — **`CORE_MAJOR` unchanged (=1)**.
    Also raised `introspect.list_tools` StreamReader limit to 8 MiB (the Dev MCP returns a single 145-tool `tools/list`
    line that blew past asyncio's 64 KiB default). Pinned `ruff==0.15.20` (unpinned `ruff>=0.6` had drifted → 44
    pre-existing UP037 findings; the Phase-16-02 lesson, never applied to genesis-core).
  - **genesis v0.31.1** — `Settings.mcp_servers_dir`; `genesis/mcp/native/{lockfile,installer}.py`: `NativeMcpInstaller`
    (`install(id,bundle_path)` → sha/idempotent → safe extract → find project root → `uv sync` [guarded] → verify entry
    → lockfile row → set `current`; `rollback`; `active_launch_spec` launches from the per-server venv, NOT `uv`;
    `status`; **no network `update`**) + `NativeMcpLockfile` (own atomic JSON store at `mcp-servers/lockfile.json`).
    Wired `native.launch_spec_for` into `ConfigService.merged_mcp_registry` + `worker._load_registries` + introspect;
    `environments.resolve_var` maps `LCP_URL`/`APPIAN_DOMAIN` from the dev env (§2.5); `dev_connection_check` reports
    native install status. `api/native_mcp.py` (GET status + POST install|rollback); `genesis mcp
    install-native|status|rollback-native` CLI; Settings→MCP **"Appian MCP servers"** web panel.
  - **genesis-workflows v0.8.4** — `appian-dev`/`appian-devops` are **managed refs** (`"managed": "<id>"`, docker
    placeholder dropped) with correct per-bundle env (Dev: `LCP_URL`/`LCP_AUTH_METHOD=basic`/`LCP_API_PATH`/`LCP_USERNAME`/
    `LCP_PASSWORD`; DevOps: `APPIAN_DOMAIN`/`APPIAN_API_KEY`) and **read-only allowlists set from the REAL installed
    `tools/list`** (both bundles installed + introspected): Dev **67**/145 (get*/list*/test/validate; all write excluded),
    DevOps **13**/26 (export/inspect/status/download; deploy/pipeline-mutation excluded).
  - **Design decision:** `active_launch_spec` returns the binary location only; the `${VAR}` env template stays on the
    registry entry and is resolved by `McpRegistry` — the installer never touches secrets (DRY + defense in depth).
  - **Verified:** genesis **266** pytest (+24 native; 3 uv-guarded integration tests run a real `uv sync` install of both
    ids locally, skip where uv absent), genesis-core **61** (+4), web **121** (+1 panel); ruff/eslint/tsc clean.
    **Live acceptance (manual):** installed both real bundles + introspected (Dev 145 tools, DevOps 26) — `uv sync` +
    venv launch + `active_launch_spec` + `tools/list` all work end-to-end. **CI:** genesis-core v0.9.1 ✅, genesis
    v0.31.1 (`genesis` job) ✅, genesis-workflows v0.8.4 (all 3 jobs) ✅. **Caveat:** the genesis **`frontend`** job
    (stale-bundle guard) did **not** run in CI this release — it's gated on `changes: [web/**/*]`; the web changes were in
    v0.31.0 whose frontend job died on a **transient Gitaly HTTP-500** at git-fetch, and v0.31.1 touched no web →
    skipped; `glab` can't retry (read-only token). `web/static` was rebuilt + committed + locally verified; a v0.31.2
    web-touch push is the way to re-trigger the guard. Progress: `progress/phase-16-08-native-mcp.md`.

- **2026-08-05 (Phase 16-08 §2.0 — dev-environment toggle SHIPPED ✅; genesis v0.30.0):** The **connectivity
  foundation** (the "build FIRST" half of 16-08). The Environments registry gains an **`is_dev` flag** — exactly one env
  is the dev-tagged Appian target that ALL Phase-16 auth resolves against (REST export, Dev/DevOps MCP, changed-objects).
  Backend: `Environment.is_dev` + single-select invariant in `EnvironmentRegistry.upsert` (tagging one clears the others
  in one write) + `set_dev_environment()`/`dev_environment()`/`dev_environment_label()`; `ConfigService` passthroughs +
  `dev_connection_check()` readiness (dev env tagged + native-MCP secret keys present, by key name); API `is_dev` on
  upsert + `POST /config/environments/{label}/dev` + `GET /config/environments/dev/check`. Web: Environments section dev
  toggle (single-select `Switch`) + **dev** badge + per-row **Set as dev** + **Test connection**. Tests:
  `test_config.py::test_dev_environment_single_select`, `test_api.py::test_api_dev_environment_toggle`, a settings
  vitest; **242 python + 120 web passed; CI green #6502611** (genesis + frontend jobs; stale-bundle guard passed).
  Progress: `progress/phase-16-08-native-mcp.md`.
  - **SCOPE DECISION (2026-08-05, from the user) — no auto-update source for the native MCPs.** Stage B drops the
    connected-site bundle-servlet fetch (Dev) and the configured-mirror fetch (DevOps). New Appian releases are
    integrated **manually**: the user drops the new bundle in and Genesis **installs it as a new version** (prior kept
    for **rollback**; `current` pointer swap). The installer is thus **install-from-local-bundle + version/rollback
    only** (no network fetch). "Updatable without forking" still holds via the manual drop-in; the bundle is never modified.
  - **Stage B remaining (tasks 5–9, next session):** `Settings.mcp_servers_dir` + `genesis/mcp/native/{installer,lockfile}.py`
    (`uv sync` install under `~/.genesis/mcp-servers/<id>/versions/<v>/`, launch from the per-server venv, version/current/
    rollback, `active_launch_spec`); genesis-core `McpRegistry.acp_servers` **managed-reference** resolution
    (`"managed": id → active_launch_spec`) resolving the `<managed-native:appian-dev|appian-devops>` placeholders with
    read/export-only allowlists; `api/native_mcp.py` (status/install/rollback — no `update`) + a Settings→Integrations
    panel + a `genesis mcp install-native` CLI; release chain genesis-core → genesis → genesis-workflows. See
    AGENT_ONBOARDING.md §9 "▶ NEXT — 16-08 Stage B" for the step-by-step start.

- **2026-08-04 (Phase 16-03 — `sync-application` workflow SHIPPED ✅; genesis v0.29.1 + genesis-workflows v0.8.2):**
  A deterministic, **program-only** LangGraph workflow that populates the KB from a live app:
  `resolve_inputs → export_package → v_export → parse_package → v_parse → write_kb → v_kb → present`. **export_package**
  = Appian **Deployment REST** (export/poll/download) in a program node (ADR-001; no agent/credits; no pre_mutation —
  read-only Appian), all network/env/secret access isolated in the `_fetch_package_zip` seam (401/403/404 fail-fast;
  409/timeout/5xx → retry). **parse_package** → code-free `result.json` (ADR-037). **write_kb** → `KbStore` baseline
  (register/begin_sync/apply/finish_sync), store provided via `ctx.extras['kb_store']` so `graph.py` never imports the
  platform; **re-baseline is rejected** (delta = 16-07). genesis (v0.29.1): pin `genesis-appian-parser@v0.1.0`;
  `build_context` injects the KbStore; `EnvironmentRegistry.active()`; checkpointer connection WAL + busy_timeout.
  genesis-workflows (v0.8.2): the workflow + `registry.json` entry + `mcp-registry.json` **appian-dev (read-only) +
  appian-devops (export-only)** managed-native refs (ADR-038, resolves the old `lcp` `<lcp-image>` placeholder); dev-pin
  genesis v0.17.0→v0.29.1 + genesis-core v0.6.0→v0.8.2. **Concurrency fix (v0.8.2):** `write_kb` runs the blocking
  `KbStore` write via **`asyncio.to_thread`** — a sync write on the async event loop deadlocked the aiosqlite
  checkpointer (flaky 'database is locked': green on master, red on the tag pipeline for the same commit #6496968);
  offloading keeps the loop free so the checkpointer commits/releases (repro: blocking FAILS ~5s, to_thread SUCCEEDS
  ~0.25s). **Verified:** validate_library PASSED (5 workflows); workflow suite 54 passed; genesis suite 240 passed; ruff
  clean; **CI green** (genesis #6496959; genesis-workflows master #6497156 + tag #6497157 — two independent runs of the
  previously-flaky path). Progress: `progress/phase-16-03-sync-workflow.md`. **Next: 16-08** (managed-native MCP install
  + `is_dev` toggle).

- **2026-08-04 (Phase 16-02 — internalized KB schema + store SHIPPED ✅; genesis v0.28.0):** Added the code-free
  temporal Appian KB to `genesis.db`. **Migration m0007** creates the `kb_*` tables (applications/syncs/objects/
  dependencies/bundles[+flow_json,key_objects_json,entry_point_json,release_label]/bundle_members/releases + indexes;
  SCD-2, additive; `current_version`→7, auto-applies at boot). **`KbStore`** (`genesis/kb/store.py`): app lifecycle
  (register/archive/**untrack table-scoped**), sync (`begin`/`apply` baseline+delta SCD-2/`finish`), recompute-on-sync
  bundles (**`flow_json` verbatim** = Atlas standard), `tag_release`/`list_releases` + point-in-time helper, and
  contract-shaped reads (list_applications/get_app_overview[at_release]/search_objects[cross-app]/get_dependencies/
  get_object/get_bundle/search_bundles/list_orphans). **No code stored** (ADR-037); duck-types `KbParseResult` (parser
  pin lands in 16-03). **Verified vs the real package** (KbStore reads reconcile to 2620 objects / 5084 edges /
  174 bundles / 804 orphans). **10 new tests** (incl. SCD-2 delta history, cross-app, table-scoped untrack,
  point-in-time, no-SAIL guard, real end-to-end); updated migration-count assertions to 7; **fixed a pre-existing
  time-bomb** in the retention test (inject `now`); **pinned `ruff==0.15.20`** (unpinned ruff drifted to a UP-enabled
  default that failed CI on ~170 pre-existing `Optional[...]` usages — none in the new code). **Full suite 239 passed;
  genesis package ruff-clean; CI green** (pipeline #6496454). Progress: `progress/phase-16-02-kb-schema-and-store.md`.
  **Next:** 16-03 (`sync-application` workflow).

- **2026-08-04 (Phase 16-01 — native parser IMPLEMENTED ✅ · local only):** Built
  **`genesis-appian-parser` v0.1.0** (new repo at `repo-gitlab/ramaswamy.u/genesis-appian-parser`,
  commit `822b683`, tagged `v0.1.0` — **local, not pushed**; remote creation likely needs the user per
  the `glab` api-scope limit). A faithful **port of the Atlas parser front-half** into a Genesis-owned,
  **stdlib-only** py3.13 package emitting an **in-memory `KbParseResult`** (objects + edges + bundles +
  **code-free** metadata) — **no file output, no SAIL retained** (ADR-037). Public API
  `parse(zip|bytes) -> KbParseResult`. Kept package_reader/type_detector/parser_registry + 20+ parsers +
  resolution + dependencies + domain + diff_hash + the 4 in-memory bundle builders; dropped the Atlas
  file-writers, versioning, schema, enrichment, CLI (versioning → KbStore SCD-2 in 16-02). **Verified vs the
  user's real package** (`AiDocumentCenterv4.3.1.zip`): **2620 objects / 5084 edges / 174 bundles / 804
  orphans / 0 errors**, ~1.9 s; the newer `aiAgent` type is skipped gracefully. **13 pytest tests green**
  (structure/resolution/bundles/entry-points/orphans/determinism/`bytes==path` + two **no-SAIL** guards
  incl. a proof that real source SAIL is absent from the result); **ruff clean**; CI = ruff+pytest on py3.13.
  Progress: `progress/phase-16-01-native-parser.md`. **`KbBundle.flow` resolved** ("follow the standard solution"): it
  is the **Atlas-standard structured dict** `{process_model,subprocesses}` (verified against the Atlas MCP + parser MCP,
  which return it verbatim) — KB stores it verbatim as `flow_json`, `get_bundle` returns it verbatim; the tool-contracts
  §2.10 + umbrella DDL + 16-01 field type were corrected (the earlier "textual list" assumption was wrong). **Next:**
  16-02 (m0007 `kb_*` + `KbStore`).

- **2026-08-04 (Phase 16 spec — refinements after tool audit + review 📋):** Extended the initial Phase-16 draft
  (below) into the final planning set — still **spec-only, awaiting approval to implement**. Changes:
  - **Full Atlas (34-tool) + Jarvis (50-tool) capability audit** → a new authoritative
    **`phase-16-appian-knowledge-base/genesis-kb-tool-contracts.md`** (per-tool params · exact return JSON · backing
    `kb_*` query · parser fields) and locked **scope decisions:** iteration-1 = **16 read-only KB tools** (Section A/
    Tier-1); **versioning = BACKLOG (16-06)** gated on Dev MCP **AP-62096** (Object version viewing/comparison — in Code
    Review, **26.8 GA / 2026-08-28**; plumbing AP-51279 Done); schema/DDL/data-gen (Section C) **deferred**; live-env
    reads via Dev/DevOps MCP only (Section D); write/deploy (E) + documents/git/pipeline (F) **out**.
  - **New sub-phase 16-08 "Native MCP integration & updatability"** + **ADR-038**: the two Appian MCP bundles the user
    placed at `artifacts/mcp-servers/` (**Dev MCP** `lcp-mcp-server`, **DevOps MCP** `appian-deployment-mcp`) are
    integrated as **managed, versioned, opaque, replaceable** local servers (installed under `~/.genesis/mcp-servers/` via
    `uv sync`, launched from the per-server venv, registered as a **managed reference** with read-only allowlists).
    **Updatable without forking (manual drop-in):** new Appian releases are integrated by the user dropping the new
    bundle in → Genesis installs it as a new version + swaps `current`; prior kept for rollback; sha-verified; bundle
    never modified. *(2026-08-05: the earlier auto-fetch sources — Dev site bundle-servlet, DevOps configured mirror —
    were dropped by the user; updates are manual.)* New prereq `uv`; Dev-MCP **Basic auth** is the headless default
    (browser/SSO opt-in). Resolves the old `lcp` `<lcp-image>` placeholder.
  - **Connectivity model decided (supersedes "one connected environment"):** the Environments registry may hold **many**
    envs; a single-select **`is_dev` toggle** designates the one Phase-16 authenticates against — its URL + credentials
    feed **all** Phase-16 auth (REST export, Dev MCP, DevOps MCP, changed-objects API); no dev env ⇒ fail fast + a
    Settings "test connection". Specified as **16-08 §2.0 (build first)**; ADR-036 + umbrella §12/§3/§4 updated.
  - **Export mechanism confirmed with the user:** the sync pipeline exports via a **deterministic Deployment REST call
    in a program node** (no agent, no credits — ADR-001), NOT via the DevOps MCP tool (the DevOps MCP stays registered
    for agent use).
  - **Updated build order:** 16-01 parser → 16-02 store → 16-03 sync → **16-08 native MCP + dev-env toggle** → 16-04
    apps → 16-05 KB MCP + cutover → 16-07 delta; **16-06 versioning later** (post-AP-62096). Umbrella §13 table + the
    `AGENT_ONBOARDING.md` §9 Phase-16 block + §5 ADR list refreshed to match. Final set = umbrella + **8 sub-phases** +
    the tool-contracts doc + **ADR-036/037/038**.

- **2026-08-04 (Phase 16 spec — Appian Knowledge Base / Atlas-into-Genesis 📋):** After a code-grounded
  exploration of the Atlas MCP server, the Atlas parser, the Atlas KB + its `sync_packages.py` pipeline
  (all read from GitLab via `glab`), Jarvis, and the native Appian **Dev MCP** + **DevOps/Deployment MCP**
  docs — plus a read-only recon of the Genesis internals (Environments registry, internal MCP-server +
  injection pattern, `db/` migrations, workflow authoring/run wiring, web app-shell) — drafted a full,
  standard, multi-sub-phase plan to **bring the Appian knowledge base inside Genesis**. Umbrella
  `specs/phase-16-appian-knowledge-base.md` + **7 sub-phase docs** (`16-01..16-07`) + **ADR-036**
  (Internalized Appian KB) & **ADR-037** (Code-free temporal KB + live code via Dev MCP). **Design
  (decided with the user):** a **Genesis-native parser** (`genesis-appian-parser`, a new pinned repo —
  port the Atlas parser's front-half: unzip→type-detect→15 parsers→UUID/URN resolution→dep-graph→
  entry-point bundles→diff-hash; emit an **in-memory** structured result; **no code persistence**, no file
  output); a **code-free temporal KB** in `genesis.db` (m0007 `kb_*` **SCD-2** tables + user-tagged
  `kb_releases`; metadata/structure/deps/bundles only; **cross-app**; point-in-time via validity ranges);
  an **Applications** page + `/api/applications*` (add apps from the **one** connected env via the Dev MCP
  → baseline sync); a **`sync-application` LangGraph workflow** with **deterministic REST export** (Appian
  Deployment API in a program node — no agent, no credits; ADR-001) → parse → SCD-2 merge → recompute
  bundles → record sync; a read-only **`genesis-kb` MCP server** (internal, like introspection_server) that
  serves the KB + fetches **current & historical code LIVE via the Dev MCP** (version-parameterized) — with
  **chat / erd-generation / design-doc cut over from the external `appian-atlas`** (the "KB swapped,
  functionality preserved" milestone, 16-05); **release tagging + point-in-time** (16-06); and **delta
  refresh** (16-07) via a new Appian "changed-in-[start,end]" API (user-owned) + manual/scheduled syncs.
  **Key decisions locked:** KB in `genesis.db` (not a separate file); **no source code** in the KB (Dev MCP
  does all code + version fetch — historical gated on AP-62096, 26.8 GA); the **dev-tagged** environment (existing
  registry; see the refinement entry above); app identity = **application UUID**; native Dev MCP (read-only here) + DevOps MCP (export) become
  curated connectors (resolves the `lcp` placeholder); read-only against Appian (write/deploy out of scope).
  Scale checked: ~5–8 MB/app, ~50–150 MB for ~10 apps × ~10 releases — comfortably SQLite. **Release chain:**
  `genesis-appian-parser` (new) → `genesis` (m0007 + KbStore + kb_server + applications api/web) →
  `genesis-workflows` (sync-application + Dev/DevOps registry entries); genesis-core likely untouched.
  **Spec-only; not pushed; awaiting approval to implement (order: 16-01 parser → 16-02 store → 16-03 sync →
  16-04 apps → 16-05 KB MCP + cutover → 16-06 versions → 16-07 delta).**

- **2026-07-17 (Phase 15 follow-up issues documented — not yet fixed):** the first real `design-doc`
  runs surfaced 5 issues, captured in `specs/phase-15-followup-fixes.md` for a later pass: **(1)** run-view
  cursor/status goes stale for runs orphaned across a `serve` restart (v0.27.1 reconcile covers only the
  terminal case, not still-running); **(2)** the design-doc jarvis read-only allowlist is *incomplete* —
  the `jarvis_*` tools all exist, but `get_appian_object`/`get_object_dependencies`/`search_objects_by_name`
  (and a few more) were omitted (full introspected tool list in the doc); **(3)** the chat copilot GateCard
  feedback box doesn't dismiss after responding (needs `ack(n.id)` in ChatThread); **(4)** OPEN: verify the
  per-node read-only allowlist is actually enforced at runtime (untrusted jarvis tools executed with no
  permission event); **(5)** atlas MCP introspection returns empty. None block current use.

- **2026-07-17 (More live-run fixes — genesis v0.27.2 + genesis-workflows v0.7.1):** **(a)** the
  show/hide **tool-outputs toggle** had been mis-placed in Chat + the run-detail conversation node view
  (as a "tool activity" transcript filter). Moved it to the **Documents tab** where it belongs: a
  "Show tool outputs" switch (default OFF) that hides the raw tool-output-store files (`_toolcalls/*`,
  `.DS_Store`) from the document list; removed `ToolActivityToggle` from chat/inspector (conversation
  now simply doesn't show raw tool chips). `showToolActivity` pref → `showToolOutputs`. genesis v0.27.2
  (frontend; bundle rebuilt + committed). **(b)** the R2 finding is now fixed (genesis-workflows v0.7.1):
  `get_application_info` wraps JSON in a prose preamble (`Application Info:\n{...}`) AND some apps have an
  **empty** `namingConvention` — added `_coerce_json` (strip preamble) across the design-doc JSON
  readers/validators and relaxed `check_app_info` to require the `namingConvention` KEY (may be empty),
  not a truthy value. **Verify:** design-doc **18** tests (+2 coercion) + ruff + `validate_library` green;
  web **119** Vitest + `tsc` + bundle; both CIs green. Restart `genesis serve` to pick up v0.27.2.

- **2026-07-17 (Bugfixes on the first design-doc live run — genesis v0.27.1):** two UI issues found on a
  real `design-doc` run (r-5c15c313c079, GAMS-9277). **(1) Documents wouldn't open:** the tool-output
  store writes files under a subdir (`_toolcalls/call_N.out`), but the artifact routes used `{name}`
  which won't match a slash → 404. Fixed to `{name:path}` (content + download; download registered first
  so the greedy converter doesn't swallow `/download`); traversal guard unchanged. **(2) UI showed a
  stale state:** the run actually escalated and hit `run.final`, but after a server restart the
  denormalized `RunRecord` stayed `running@v_plan` while the durable eventlog was correct. Added
  `RunManager.reconcile_status` — a read-time, idempotent reconcile (only when no worker for the run is
  tracked in this process): adopt the latest durable `run.final` status + last completed node as cursor;
  wired into `GET /runs/{id}` and the runs list. **Bonus finding (workflow robustness, not fixed here):**
  the run escalated because live jarvis `get_application_info` returned no top-level `namingConvention`
  (R2 real-shape drift) → `fetch_app_info` retried to exhaustion; `check_app_info` should parse defensively
  (Phase-12 lesson) — follow-up. **Verify:** genesis **230** pytest (+3: nested-artifact + 2 reconcile) +
  ruff clean; backend-only (bundle untouched). Restart a running `genesis serve` to pick up the fix.

- **2026-07-17 (Phase 15 — Design-Document Workflow ✅ SHIPPED, 15-01..15-05):** a new **`design-doc`**
  workflow ports the Jarvis design-doc process into a deterministic Genesis graph — JIRA ticket → Appian
  **design document (Markdown)** via **dual-source research** (live **Jarvis** + release-aware **Atlas**),
  reconciled into one release-aware plan. **15-02** MVP chain (ticket→config→app-match(+gate)→freshness(+gate)
  →research_jarvis→research_atlas→reconcile→app-info→naming→design-notes→build→present); `v_ratlas` **requires**
  a `## Release Context` section so Atlas earns its place. **15-03** open-questions (conditional section via the
  deterministic `plan_sections` node). **15-04** empty-package creation behind a **`pre_mutation`** gate (the one
  mutation; jarvis `create_package_for_ticket`). **15-05** mockup→i18n branch (extract keys, dedup NEW vs REUSE,
  Internationalization section shows NEW only). Read-only by construction (per-node `@jarvis/…` allowlists; Atlas
  registry read-only). **15-01 platform:** run-launch **file attachments** — `format:"file"` inputs, multipart
  `POST /api/runs/upload`, `RunManager._provision_files` writes to the run blackboard `uploads/` + rewrites the
  input to a relative path before validation, size/type/traversal guards (`FileUploadError`); web launch form gets
  a `FileDropList`. **ADR-035 Accepted.** **Verify:** design-doc **16** tests + ruff + `validate_library` (4 wf);
  genesis full **227** pytest (+5 upload) + ruff clean; web `tsc` clean + **119** Vitest + bundle rebuilt.
  **Release:** genesis-workflows **v0.7.0** + genesis **v0.27.0** (genesis-core + kiro-agent-sdk unchanged).
- **2026-07-16 (Phase 14 — Skills in Chat ✅ SHIPPED, 14-01..14-05):** Skills (Kiro's portable `SKILL.md` packages)
  are now a **second first-class capability** beside Workflows — a *standalone activity* (draft a doc, apply the GAM
  body of knowledge) owned by the Kiro agent, no stages/run (ADR-034 **Accepted**). **14-01** managed workspace
  `~/.genesis/.kiro/skills/` + `genesis/skills/` model/store/service + `/api/skills` CRUD + chat discovery/reload.
  **14-02** `genesis-workflows` `skills/` library + `skills-registry.json` + `ci/validate_skills.py` gate + seed
  **`gam`** skill; genesis `SkillInstaller` + `Lockfile.skills` + `/api/skills/available|install|update`. **14-03**
  Catalog **Workflows \| Skills** sub-tabs + `SkillCard` + in-flight **authoring** dialog (SKILL.md body +
  scripts/references/assets uploads) + `FileDropList`. **14-04** unified Chat `/` palette (Workflows copilot-only +
  Skills both modes) → skill pick sends `/<name>`; per-session **skill-output** surfacing (reuses Documents renderer)
  + reload affordance. **14-05** SDK **`fs_write_root`** sandbox (writes confined to `~/.genesis/skill-output/<session_id>/`,
  traversal/symlink-safe) wired into both chat modes; dedup/shadow surfacing; script execution stays deferred.
  **Release:** kiro-agent-sdk **v0.6.0** → genesis-workflows **v0.6.0** → genesis-core **v0.8.2** → genesis **v0.26.1**.
  Gates green: genesis 222 pytest + ruff, kiro-agent-sdk 82, genesis-workflows validate_skills + validate_library,
  web 119 Vitest + lint/tsc + `web/static` rebuilt. Remaining: manual live-acceptance vs. real kiro-cli (auto-activation
  + `/gam`, headless-undrivable).
- **2026-07-16 (Phase 14 spec — Skills in Chat 📋 + skills-over-ACP spike ✅):** Explored the chat/catalog/dist/
  genesis-workflows architecture and wrote a full, standard, multi-sub-phase plan to add **Skills** (Kiro's portable
  `SKILL.md` packages) as a **second first-class capability** beside Workflows, invocable from **Chat** (priority 1).
  **Concept boundary (ADR-034):** a **Skill** = a *standalone activity* (draft a doc, build a checklist, apply a body
  of knowledge like GAM) owned by the Kiro agent — no stages, no run; a **Workflow** = a *staged/orchestrated* activity
  owned by LangGraph (ADR-001 preserved). **Spike first (`spike/2026-07-16-kiro-skills-in-acp-and-chat.md`):** proved
  real kiro-cli 2.12.2 **discovers + activates skills over ACP** (the chat channel) via both **auto-activation**
  (description match) and **explicit `/skill-name`** — skills are a **filesystem convention** (`.kiro/skills/`), NOT an
  ACP wire param like MCP, so Genesis provisions them by writing into a **managed workspace at `~/.genesis/.kiro/skills/`**
  (= the chat `cwd`); no SDK/protocol/core change. **Two acquisition paths:** install from a new `skills/` library in
  `genesis-workflows` (mirrors the workflow install/lockfile path), or **author in-flight** (SKILL.md body + scripts/
  references/assets uploads). **Catalog** gains **Workflows \| Skills** sub-tabs; **Chat** `/` palette becomes a unified
  command menu (workflows + skills), skills available in read-only chat too. **v1 safety (user-approved):** skills may
  write documents **only** into a per-session **skill-output sandbox** (`~/.genesis/skill-output/<session_id>/`, via a
  small additive SDK `fs_write_root` option — writes elsewhere rejected); executing bundled scripts stays deferred.
  Seed library skill: **GAM** only.
  Umbrella `specs/phase-14-skills-in-chat.md` + **5 sub-phase docs** (14-01 foundation+chat-discovery → 14-02 library+
  install → 14-03 catalog Skills tab + authoring → 14-04 chat invocation → 14-05 safety/lifecycle+release) + **ADR-034
  (proposed)**. Release chain: `kiro-agent-sdk` (small additive `fs_write_root` for the skill-output sandbox) →
  `genesis-workflows` (skills library) → `genesis`; genesis-core unchanged.
  **Spec-only; spike-first done; awaiting approval to implement.**
- **2026-07-15 (Run Detail UX — tabbed page + Documents master-detail + hide tool outputs — SHIPPED,
  genesis v0.25.0, frontend):** Documents are a primary run output, so Run Detail is now **tabbed
  (Flow | Documents)**. **Flow** = the existing graph/list + inspector (Graph/List moved into it).
  **Documents** = a master-detail view — a left rail of document **cards** (icon · name · kind · size ·
  a pinned + auto-selected **Result**) → a **wide** `DocumentViewer` (sticky header + download/copy/raw/
  load-full, reusing the shared renderers), resizable `SplitPane`. Default tab: **Graph while running,
  Documents when completed** (seeded once; a `/docs/:name` deep-link also lands on Documents). The two
  right **Drawers** (`DocumentsList` + `DocumentPreviewSheet`) are **retired/deleted**. Also a shared
  **"Show tool activity" toggle** (`useUiPrefs`, OFF by default) hides the agent's tool calls/updates from
  the conversation — applied to **both Run Detail and Chat** (`Conversation` gained a `showTools` filter).
  Tests: `documents.test` rewritten (DocumentsTab + DocumentViewer + jest-axe); `run-detail.test` +
  tool-activity hide/show + toggle-store. **web 101** (was 89); lint 0 errors, tsc clean; `web/static`
  rebuilt. Released genesis **v0.25.0** (`d14dfe7`); frontend-only, no SDK/core/backend change.
- **2026-07-15 (genesis v0.24.1 — bugfix):** the Chat copilot mode toggle could get stranded as
  "Copilot disabled". `useCopilotEnabled` treated ANY non-success from `GET /api/config/copilot`
  (loading, network error, or a **404 from a stale `genesis serve` that predates the 13-06 endpoint**)
  as "kill-switch off", greying out "Enable copilot" with no way back. Fixed to mirror the backend
  default — ENABLED unless the server explicitly returns `enabled:false` (retry off). Root trigger was an
  old running server; **restarting `genesis serve` onto ≥ v0.24.0 also resolves it** (the endpoint then
  exists). Regression tests added (404→enabled, explicit-false→disabled); web 95. Reinforces the standing
  lesson: restart `genesis serve` after a server-side change.
- **2026-07-15 (Phase 13-06 — Copilot safety, audit & advanced-gate hardening — SHIPPED, genesis v0.24.0;
  PHASE 13 COMPLETE):** Global **kill-switch** + per-session **concurrency cap** + **rate limit** +
  **workflow allow/deny** (persisted `CopilotConfig` at `~/.genesis/copilot.json`, runtime-toggleable),
  enforced **app-side on `POST /api/runs` gated on the control token** (browser Runs-UI untouched — a
  flagged, stronger deviation from the spec's "enforce in the control server"). Kill-switch off ⇒ the
  copilot surface is demoted to read-only (control tools gone) at 3 layers. **Audit trail** (`m0006
  copilot_actions`, schema v6): every agent-initiated mutation logged proposal → human confirmation →
  outcome; `GET /api/chat/actions`. **Advanced-gate:** `pre_mutation`/any gate can never be auto-approved
  (relayed only via the always-confirmed, never-trusted `respond_to_gate`); SLA re-nudge reads the
  persisted `gate_sla_minutes` and only escalates. `GET/PUT /api/config/copilot`. **Web:** Settings →
  General **Copilot** section (kill-switch + limits + allow/deny + activity table); the Chat mode toggle
  is gated on the kill-switch. Tests: `test_copilot_safety.py` (13) + `test_copilot_e2e.py` (1) →
  **genesis 180 pytest** (was 166), ruff clean; `copilot-settings.test.tsx` (4) → **web 93** (was 89),
  lint 0 errors, tsc clean, jest-axe green; `web/static` rebuilt. **ADR-033 flipped Proposed → Accepted.**
  Live acceptance vs. real kiro-cli remains a manual step (can't be driven headlessly). Released genesis
  **v0.24.0** (`237d411`; no SDK/core change). Progress: `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13-05 — Slash-command launch + in-chat HITL/confirm UI — SHIPPED, genesis v0.23.0,
  frontend):** The copilot UX. Composer **`/` palette** (fuzzy installed-workflow list from `/catalog`,
  readiness-annotated) → schema-driven **LaunchDialog** (reuses the 07-05 `buildLaunchForm`/`toRunInputs`)
  → emits a **`start_run` intent chat turn** so the agent starts the run (ADR-033) → untrusted `start_run`
  raises a **PermissionCard** (Allow/Deny → `POST …/permissions/{tcid}`). **GateCard** (from
  `run.notification` gate: option buttons + feedback → composed decision turn the agent relays),
  **TerminalCard** (Run-Detail link), **SupervisedRunsStrip** (`/chat/runs` + live status dots,
  "awaiting you" highlighted), a per-session **mode toggle**, and `SystemNudge` for the 13-04 nudges.
  `readSse` made generic to serve both the turn stream (permission.request/resolved) and the
  `run.notification` stream (`useSessionNotifications`). Read-only chat unchanged. 11 web tests (**89
  total**); lint 0 errors, tsc clean, jest-axe green; `web/static` rebuilt + committed. Released genesis
  **v0.23.0** (`e74e896`; frontend-only, no SDK/core change). Progress:
  `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13-04 — Run-supervision bridge — SHIPPED, genesis v0.22.0):** The copilot now
  **senses** gates/terminals on runs it started, without staying alive. `RunManager.add_event_observer`
  hook (invoked in `_log`); `ChatRunSupervisor` observes `gate.awaiting`/`run.final` for **session-linked**
  runs (`chat_run_links`) → writes a durable `chat_notification` (**m0005**, UNIQUE dedup_key
  `run_id:kind:seq`) → pushes a `run.notification` on a per-session SSE → injects a **deterministic system
  nudge** into the transcript (no LLM/credit spend) surfacing the gate + options; the user replies → agent
  `respond_to_gate` → run resumes. Observer runs on the worker **reader thread** → schedules SSE/nudge on
  the app loop via `call_soon_threadsafe`. **Level-triggered reconcile** (startup + each notification-stream
  connect) recovers pending gates/missed terminals from `pending_gate`+`RunStore` (idempotent via the event
  seq → survives restart). **SLA re-nudge** (`copilot_gate_sla_minutes`, default off) escalates attention,
  never auto-answers. API: notifications list/ack + `notifications/stream` SSE. 8 supervisor tests; **full
  genesis suite 166 passed**; genesis ruff-clean. Released genesis **v0.22.0** (`a51c79b`; no SDK/core
  change). Progress: `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13-03 — Copilot chat mode + run↔session link — SHIPPED, genesis v0.21.0 +
  genesis-core v0.8.1):** Chat can now act as a supervised run **operator** (ADR-033). A per-session
  **mode** (`read_only` default | `copilot`; `m0004`). Copilot wires the 13-02 **control MCP server** with
  read tools trusted and mutating tools (`start_run`/`respond_to_gate`/`cancel_run`) **untrusted**, so each
  fires `session/request_permission` → the SDK `permission_mode="ask"` bridge (13-01) → a **confirm card**:
  `_on_permission` persists a `chat_permissions` row, emits a `permission.request` on the turn SSE (via an
  out-of-band queue merged into a refactored `stream_turn` — read-only output unchanged), and awaits a
  Future resolved by `POST /api/chat/sessions/{id}/permissions/{tcid}` (allow optionId → tool runs;
  null/timeout → deny, fail-closed). A per-session **control token** maps token→session so `POST /api/runs`
  **links** the run (`chat_run_links`); `GET /api/chat/runs` returns a session's runs + live status;
  `POST …/mode` toggles mode. `Settings.api_base` (set by `serve` from `--host/--port`) lets the in-process
  chat tell the control subprocess where to call back. Copilot steering preamble (relay — never invent —
  gate decisions; every mutation confirmed; no config/secret/deploy). `app.state.chat`/`run_manager` exposed
  for the 13-04 supervisor. 13 new tests; **full genesis suite 158 passed**; genesis package ruff-clean.
  **Coordinated release (resolves the 13-01 deferral):** both genesis + genesis-core pin the SDK directly,
  so bumped together — genesis-core **v0.8.1** (SDK pin→v0.5.0, dependency-only) → genesis **v0.21.0** (SDK
  pin→v0.5.0, core pin→v0.8.1, copilot mode; also ships the 13-02 control server, previously inert). CI
  green on both. Progress: `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13-02 — Genesis Control MCP server — code committed, no release yet):** Built
  `genesis/mcp/control_server.py`, the write-capable sibling of the read-only introspection server, as a
  **thin MCP→HTTP facade over `/api`** (Codex-as-MCP pattern) so `RunManager` stays the single source of
  truth. 10 run-management tools (`list_launchable_workflows`, `get_workflow_inputs_schema`,
  `check_launch_readiness`, `start_run`, `get_run_status`, `get_run_steps`, `get_pending_gate`,
  `respond_to_gate`, `cancel_run`, `list_session_runs`); `MUTATING_TOOLS={start_run,respond_to_gate,cancel_run}`
  exported for the 13-03 untrusted-wiring. Run-management ONLY — **no** config/secret/registry/deploy tools
  (ADR-033/ADR-029). `respond_to_gate` validates the decision against the gate options. Added a
  `GET /api/chat/runs` placeholder (filled by 13-03). 23 tests; full genesis suite **145 passed**; ruff
  clean; stdio-smoke-tested. **Two intentional deviations (flagged):** (a) used `requests` not `httpx`
  (httpx is dev-only; requests is a runtime dep and the subprocess needs it); (b) token gating deferred —
  the shared mutation endpoints are the SAME ones the browser Runs UI calls tokenless, so a hard token
  gate would break the UI and is incoherent on an unauthenticated-localhost app (ADR-026); the server
  *sends* `X-Genesis-Control-Token` for future audit/identification, but the security model is finalized
  in 13-06. Committed to genesis master (`b6edf7c`), **not tagged** — genesis releases once at 13-03 (with
  the coordinated sdk v0.5.0 pin bump), since the control server is inert until wired. Progress:
  `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13-01 — SDK interactive permission bridge — SHIPPED, kiro-agent-sdk v0.5.0):**
  The load-bearing enabler for the copilot's human-confirmed actions. **Spike CONFIRMED** first (against
  real kiro-cli 2.12.2): an **untrusted** MCP tool call fires `session/request_permission` (options
  `allow_once`/`allow_always`/`reject_once`); a **trusted** tool fires it 0×. Captured the real param
  shape — `{sessionId, toolCall:{toolCallId,title:"Running: @server/tool"}, options:[…], id:<string uuid>}`
  — note the request carries **no rawInput** (the confirm card must correlate args by `toolCallId` from the
  preceding `tool_call` event, a 13-03 note). Then implemented `permission_mode="ask"` +
  `on_permission(PermissionRequest)->optionId|None` + `permission_timeout` in the SDK: the ask round-trip
  is scheduled as a task so the read loop never blocks; **fail-closed** on timeout/exception/unknown-option
  (and, beyond spec, ask-without-callback denies rather than auto-approving). `auto_approve`/`auto_deny`
  unchanged. 16 new tests; full SDK suite **75 passed**, ruff clean on touched files. Tagged **v0.5.0**
  (`b07e9fd`). **Pin bump deferred to 13-03** (both genesis + genesis-core pin the SDK directly; bumping
  one alone would give pip conflicting refs; nothing consumes the feature until the copilot mode wires it).
  Progress: `progress/phase-13-copilot-orchestrator.md`.
- **2026-07-15 (Phase 13 spec — Chat Copilot & Run Orchestrator 📋):** Researched + wrote a full, standard, multi-sub-phase plan to evolve read-only Chat (Phase 10) into a **copilot** that launches + supervises runs. Umbrella `specs/phase-13-copilot-orchestrator.md` + **6 sub-phase docs** (`13-01..13-06`) + **ADR-033** (proposed). **User ask:** type `/` in chat → pick a workflow → schema-driven inputs → the Kiro agent starts the run and supervises it (senses a manual approval gate, presents options, relays the user's decision), without staying alive; expose run actions as MCP tools. **Research (web):** the industry-standard "agents orchestrate; a durable engine executes" pattern (MS Durable Task, Airflow-MCP, OpenAI Codex-as-MCP-server) + LangGraph Agent Inbox (surface interrupts) + MCP elicitation. **Architecture decided (code-grounded):** (1) a write-capable **Genesis Control MCP server** — the sibling of the read-only introspection server — that **proxies the existing `/api` `RunManager` surface** (start/status/gate/respond/cancel/catalog/schema), so `RunManager` stays the single source of truth (no forked run logic). (2) **Human-confirmed mutations via ACP's native permission mechanism**: read tools trusted (silent), **mutating tools left UNTRUSTED** so kiro-cli fires `session/request_permission` per call → a new SDK **`permission_mode="ask"`** bridge routes it to a chat **confirm card** (fail-closed timeout; no dependence on unavailable MCP elicitation). (3) An event-driven **`ChatRunSupervisor`** that watches `RunManager` events for **session-linked runs** (`m0004 chat_run_links`) and, on `gate.awaiting`/`run.final`, emits a notification + a proactive **nudge turn** so the copilot surfaces the gate + options; level-triggered reconcile from durable state on restart (no reliance on a live subscription). (4) **Slash-command launch UX** — `/` palette from the catalog + the reused 07-05 schema launch form; on submit the UI hands the agent the `start_run` action (agent is the actor) → confirm card → run linked + supervised. **ADR reconciliation (ADR-033, proposed):** ADR-001 preserved (LangGraph still owns each workflow's control flow; the copilot operates only at the run-management layer = what a human operator does in the UI); ADR-031 refined (chat is read-write at that layer, but every mutation is human-confirmed, run-management only, no config/secret/registry/deploy, auditable, read-only default + kill-switch). **Sub-phases:** 13-01 SDK permission bridge (+spike: untrusted MCP tool → request_permission) → 13-02 Control MCP server + ADR-033 → 13-03 copilot chat mode + run↔session link → 13-04 supervision bridge → 13-05 slash launch + in-chat HITL/confirm UI → 13-06 safety/audit/advanced-gate + release. Release chain: kiro-agent-sdk (permission bridge) → genesis (control server + copilot mode + supervisor + api + web); genesis-core unchanged. **Spec-only; spike-first; awaiting approval to implement.**
- **2026-07-14 (Phase 12 live-run hardening ✅; genesis-workflows v0.5.1 → v0.5.3):** First live runs of `code-review` against a real JIRA ticket (GAMS-9256) surfaced **real tool-output shapes the stubbed tests couldn't** — three fix releases, each verified against the actual run artifacts under `~/Genesis/runs/code-review/`. **v0.5.1 (run r-69a92cf7edf4 → escalated at `fetch_package`):** `get_package_contents_from_url` returns JSON **wrapped in a text preamble** (`Package Contents from URL: …\n\n[…]`) and each object's `type` is a **QName** (`{http://…/types/2009}Interface`) with a separate `typeId` — my parser saw zero objects. Added `_coerce_json` (strips preamble, extracts the outer JSON) + `_local_type` (QName→local, typeId fallback); made the JSON doc-readers tolerant. **v0.5.2 (run r-2382da6e4169 → escalated at `fetch_context`):** the live `get_review_checklist` is **3-level nested** (`parentCategory→categories→checkListItems`, 112 items) with `applicableObjectTypes` as **display names** ("Expression Rule" vs my "ExpressionRule"); `jarvis_config` nests `appUuid`/`kbFolderId` under `applications[].appConfig` with `globalSettings` a **list**. Added `flatten_checklist` + normalized type matching (`_type_key`/`item_applies`) + `_pick_appconfig`/`_primary_db`; wired into `check_context`, `count_applicable`, the review prompt, `check_object`, `_validate_app`. **v0.5.3 (proactive audit — "check the other validators too"):** found the **systemic** gap — validators consuming `validator_node`'s `data` (plain `json.loads` → raw text on failure) weren't preamble-robust; `check_ticket`/`check_kb_stale`/`check_verdict` now coerce. Also made `v_object`'s `analyze_appian_code` detection tolerant of the uuid arg name (`object_uuid`/`uuid`/`object_id` or anywhere in the recorded input), since the tool-store `raw_input` shape couldn't be confirmed yet. **Verified against the live artifacts:** the full Path-A pre-loop chain (`fetch_ticket→compute_reference→fetch_package→parse_package→fetch_context→validate_app`) now produces correct results (reference_date from a real status transition, package URL, assignee, app AS_GSS + kbFolderId + MariaDB; checklist flattens to 112 items, applicable-to-Interface=75; `check_context` passes). Each fix synced into the installed `~/.genesis/library` for immediate effect (no server restart). 18 code-review tests, 7-gate CI, ruff clean. **Honest residual:** `v_object`/`v_verdict` still un-exercised against live data (no run has reached the per-object loop yet) — hardened defensively; the agent's `object_review.md` structure + real `analyze_appian_code` `raw_input` are the next things to confirm on a live loop run.
- **2026-07-14 (Phase 12 — Appian Code-Review Workflow ✅; genesis v0.20.2 + genesis-workflows v0.5.0):** Ported the Jarvis "Code Review Workflow" (an LLM-orchestrated steering doc) into a **deterministic Genesis workflow** — the ADR-001 win: the doc's "BLOCKING RULES / execution tracker / 🛑 STOP" apparatus is deleted and replaced by graph edges + validators + retry/escalation + checkpointer + Phase-9 save-by-reference + Phase-11 metering. **Open questions resolved with the user first:** R5 jira tool confirmed live via Genesis introspection (`get_jira_issue(issue_key, fields?, expand?)`, read-only); Q1 **no** registry `tool_allowlist` on `jarvis` (future write/deploy workflows need those tools) → read-only cap is **per-node**; R4 validators enforce structure/coverage only (agent owns each finding's correctness); Q2 **option b** — verdict is agent-proposed + program-confirmed against a severity floor. **12-01 (genesis v0.20.2):** `worker.py` now sets the LangGraph `recursion_limit` from `META.execution.recursion_limit` (default 150) so looping workflows survive past the built-in 25 supersteps; additive, non-looping workflows unaffected; loop + low-limit integration tests + helper units (122 genesis pytest, CI #6344231 ✅). **12-02..12-05 (genesis-workflows v0.5.0):** new `workflows/code-review/` (graph.py + workflow.yaml + README + 13 tests). One graph covers all sub-phases: Paths **A** (JIRA→`compute_reference` from changelog: Technical-Design→In-Progress fallback + `customfield_10173` package URL), **B** (package URL), **C** (`resolve_objects` names→UUIDs); **per-object loop** `next_object`(pop + reset `retries[review_object]`=0 + snapshot tool-store cursor) → `review_object`(agent, read-only `@jarvis/*` allowlist; diff/baseline → `get_appian_object` → `analyze_appian_code` → SQL/i18n `query_sql` when `needs_sql` → RecordType `validate_record_relationships` → dynamic checklist) → **`v_object`** (the code-enforced PRE-WRITE CHECKPOINT: analyze ran for *this* object via a per-object tool-store window, checklist coverage == applicable-item count, valid severities, SQL section+call when needed) → `advance`(persist `obj/NN.md`, append `review.md`, accumulate findings) → loop; exhaust → `review_escalate` gate (skip/abort). Optional **KB branch** (`kb_check` `get_stale_objects` → `kb_stale` → `kb_gate` approval → `kb_preanalysis`). **Verdict (Q2=b):** `compile`(scorecard + deterministic severity floor → `report.json`) → `propose_verdict`(agent) → **`v_verdict`** (valid enum + rationale + **not more lenient than the floor**; agent may be stricter) → `present`; exhaust → `verdict_gate` (human sets verdict). **Read-only by construction:** every agent node carries an explicit `tools=[@jarvis/…|@jira/…]` allowlist; since `jarvis` has no registry allowlist, effective trust = node.tools (ADR-029) — structurally incapable of mutation, so **no `pre_mutation` gate**. **2 build fixes:** (1) removed `from __future__ import annotations` from graph.py — the loader imports graph.py standalone (not in `sys.modules`) so LangGraph `get_type_hints()` couldn't resolve stringized `Annotated` reducer keys; eager eval fixes it (would have failed at runtime too). (2) quoted `"Stale?"` in workflow.yaml (YAML flow-scalar). **Deviation from spec flagged:** the reliability lint requires the trio on EVERY agent node, so `kb_check`/`kb_preanalysis` got lenient validators (spec had said "no validator"). Gates: 13 code-review tests + all 22 workflow tests + `validate_library.py` 7-gate (3 workflows) + contract parity + reliability lint, ruff clean; genesis CI #6344231 ✅, genesis-workflows v0.5.0 CI #6344394 ✅. Runtime dep: needs genesis ≥ v0.20.2 for the loop. **Live run pending** (needs `genesis serve` restart + a real GAMS ticket/package + jarvis/jira secrets — already connected). 📄 `progress/phase-12-code-review-workflow.md`.
- **2026-07-14 (genesis v0.20.1 — chat credit footer + secrets crash fix ✅):** Two fixes. (1) **Chat:** removed the per-response 'Turn complete' chip and show the metered **credit count** in that footer position instead (new `hideResultChip` prop on Conversation/TurnView; run-detail unaffected). (2) **Secrets page-crash fix:** setting two Jarvis MCP secret fields at once corrupted `~/.genesis/secrets.json` into invalid JSON ('Extra data') → `/api/config/mcp-cards` 500 → UI crash. Root cause: `PlaintextProvider._save` used non-atomic `write_text` and FastAPI runs sync handlers in a threadpool, so concurrent writes raced (209 valid bytes + 82 leftover tail). Fixed: atomic temp-file + `os.replace`, and set/delete serialize read-modify-write under a per-path lock; regression test with 40 parallel writers. Repaired the live file (backed up to .corrupt-bak; APPIAN_API_KEY re-entered by user). Gates: 118 genesis pytest, 78 web vitest, ruff/eslint/tsc clean, web/static committed. CI #6343891 ✅. NOTE: jarvis + jira MCP servers now connected + running in the app (unblocks Phase 12).
- **2026-07-14 (Phase 11 — Credit & Usage Tracking ✅; sdk v0.4.0, genesis-core v0.8.0, genesis v0.20.0):** Real, metered per-turn Kiro credits surfaced across the app. **Spike-driven pivot:** a live ACP spike (kiro-cli 2.12.1) found Kiro DOES report per-turn credits via `_kiro.dev/metadata.meteringUsage` ({value,unit:'credit'}) — verified per-turn not cumulative (0.184 then 0.113 in one session) — so this is *plumb real data*, not estimation (dropped the draft's pricing engine; ADR-032). SDK captures usage→ResultMessage/TurnResult; core writes per-node telemetry + `_run` aggregate + `agent.result` event (reducer hardened: None never clobbers a credit sum); genesis aggregates from `run_events` (`aggregate_credits` via json_extract) + folds per-node (`fold_steps`); chat persists per-message usage (m0003 `chat_messages.usage`) + session total. Web: Overview KPI **Credits Used** replaces Tool-Calls; run-detail telemetry strip + per-node + header run-total; chat per-message credit footer; `formatCredits`/`CreditBadge`/Coins. Every figure carries provenance (metered|partial|unavailable) → honest 'n/a', never fabricated. Gates: sdk 62 · core 57 · genesis 116 pytest, web 78 vitest, ruff/eslint/tsc clean, web/static committed. CI: core #6340868 ✅, genesis #6340870 ✅ (sdk repo has no CI; validated via the dependent pipelines installing @v0.4.0).
- **2026-07-14 (Phase 11 spec + credit-metering spike 📝):** Drafted `specs/phase-11-credit-usage-tracking.md` (credit usage everywhere: per agent node, per run, Overview KPI replacing Tool-Calls, per chat message). **Key: ran a live ACP spike against kiro-cli 2.12.1** driving raw JSON-RPC — Kiro DOES report real per-turn credits via the custom `_kiro.dev/metadata` notification (`meteringUsage:[{value,unit:'credit'}]` + `contextUsagePercentage` + `turnDurationMs`). Verified **per-turn, not cumulative** (two turns in one session: 0.1844 then 0.1115 credits). So Phase 11 is *plumb real metered data through*, NOT estimation — dropped the earlier draft's pricing-engine/`CreditModel`. Re-verified the plan against the repo: the linchpin holds — `manager._CANONICAL_CUSTOM` already persists `agent.result` events into `run_events` with `node` + full payload, so adding `credits` to the emit flows automatically to `aggregate_credits` (json_extract) + `fold_steps` + SSE; `state._telemetry_merge` already sums `credits`; run-total is a client-side sum of `/steps` (no new endpoint). Planned: sdk v0.4.0 → core v0.8.0 → genesis v0.20.0; m0003 adds `chat_messages.usage`; proposed ADR-032. Not started (implementation next).
- **2026-07-13 (Phase 10 UI polish batch ✅; genesis v0.19.2):** Five web fixes, browser-verified with Playwright. (1) **Breadcrumbs** now navigate — Topbar rendered every crumb as an inert `<span>`; intermediate crumbs with a target are now `<Link>`s (Runs/Catalog clickable). (2) **Run-detail list view**: narrowed the master pane (SplitPane `initial` 34→26%) + replaced the 4-across metric strip with a **compact stacked stat list**, giving the conversation pane far more width. Root bug found+fixed: the graph and list SplitPanes shared a React instance (same tree position), so the list pane inherited the graph pane's 48% split — added distinct `key`s so each mounts with its own `initial`. (3) **Left nav collapsed by default** (AppShell `useState(true)`). (4) **Catalog cards fully clickable** via the accessible **stretched-link** pattern (title link's ::after overlay covers the card; action buttons layered `z-10` above) — no nested-interactive a11y violation. (5) **Overview installed-workflow cards** polished: centered icon, distinct version/role chips, balanced two-button footer (outline Details + primary Launch). Web-only; 74 vitest, tsc + eslint (0 errors) clean; web/static rebuilt+committed; genesis **v0.19.2** (CI #6336083 green).
- **2026-07-13 (Phase 10 fix — live chat streaming ✅; genesis v0.19.1):** User saw only "Thinking…" during a turn with the answer popping in at the end. Root cause: sse-starlette frames SSE with **CRLF** (`\r\n\r\n`) but the web `readSse` reader split on `\n\n`, so no frame ever parsed → `liveEvents` stayed empty (stuck on "Thinking…") and the answer only appeared when the turn ended and the transcript re-fetched. (The `readSse` test used LF framing, hiding it — "stub hid the contract".) Fixed `readSse` to split on `/\r?\n\r?\n/` (CRLF+LF); test now uses the real CRLF framing. Live thoughts/tool-calls/token-by-token answer now stream. Web-only; 74 vitest; genesis **v0.19.1** (CI #6335667 green); web/static rebuilt+committed. 📄 progress/phase-10-chat-assistant.md.
- **2026-07-13 (Phase 10 follow-up — Atlas read `tool_allowlist` ✅; genesis-workflows v0.4.2):** Live-checking the first real chat found the Genesis-introspection half worked but **Atlas doc Q&A was blocked** — `appian-atlas` had no `tool_allowlist`, so chat's fail-closed trust (never trust-all) denied all Atlas tools while still injecting the server (agent tried `list_applications` → auto-denied). Enumerated Atlas's tools from the live MCP (33 READ + 1 WRITE `refresh_knowledge_base`) and added a read-only `tool_allowlist` (33 read tools) to `appian-atlas` in `mcp-registry.json`; shipped **genesis-workflows v0.4.2** (CI #6335515 green) + patched the installed library for immediate effect. **Verified live**: a new chat asked to list Appian apps → `list_applications` completed, returned 15 real apps (incl. SourceSelection). Read-only holds (write tool untrusted); the allowlist also caps Atlas to read-only for workflow nodes (erd unaffected, 9 tests pass). 📄 progress/phase-10-chat-assistant.md.
- **2026-07-13 (Phase 10 SHIPPED — Chat: read-only conversational assistant ✅):** Implemented the full 7-sub-phase plan across three repos (order sdk → core → genesis). **Release chain: kiro-agent-sdk v0.3.0 → genesis-core v0.7.0 → genesis v0.19.0**; CI green (genesis-core #6335360, genesis #6335364; sdk no CI). New **Chat** page: a persistent, **read-only** multi-turn Kiro conversation that (1) answers with the `appian-atlas` read MCP and (2) queries all Genesis state via a new read-only **introspection MCP server** (runs/failures/progress/workflows/health). Persisted + deletable sessions; single-user (ADR-026). **ADR-031** records the boundary (Chat observes/answers, never orchestrates — ADR-001 preserved). **Read-only enforcement (spike-first, load-bearing gate):** SDK gained `permission_mode="auto_deny"` + `allow_fs_write=False` (10-01); chat trusts only read tools via the **`@server/tool`** namespaced form (the spike's key finding vs kiro-cli 2.12.1); introspection server opens `genesis.db` `mode=ro` + redacts secrets. Runs **in-process** (not a subprocess worker) since it executes no workflow Python and the agent is already isolated as the kiro-cli subprocess. Backend: `genesis/mcp/introspection_server.py`, extracted `runs/steps.py fold_steps`, db `m0002` (chat_sessions+chat_messages FK-cascade), `chat/{store,events,mcp,manager}` (persistent `KiroACPClient`, streaming, persistence, steering, cold-start replay), `api/chat.py` (/api/chat/* + SSE turn stream), `create_app` wiring + FastAPI 0.19.0; genesis now takes a **direct** kiro-agent-sdk@v0.3.0 dep (ChatManager uses `KiroACPClient` directly). Web: Chat page (session list + reused run-detail conversation renderer + composer + `readSse` SSE-over-fetch reader), `/chat` route + Sidebar nav; `web/static` rebuilt+committed. **Spike PASSED** (trusted read ran; untrusted mutate + fs write auto-denied; multi-turn context persisted) and **live end-to-end verified** with real kiro-cli: a "which runs failed and why?" question was answered from the introspection tools, and a "cancel the run" request was refused as read-only. Tests: sdk **55** (+7), genesis **110** (+21), genesis-core **54**, web **73** (+5); ruff/tsc/eslint clean; web stale-bundle guard passes. 📄 [`progress/phase-10-chat-assistant.md`](progress/phase-10-chat-assistant.md). Honest caveats: Kiro context is per-live-subprocess (bounded transcript-preamble replay on cold client); a cosmetic asyncio-teardown traceback in the standalone smoke; `ChatThread` uses an interim feature→feature import of the conversation renderer; deferred: LLM titles, long-session summarization, MCP set beyond Atlas. **User: restart `genesis serve` (applies m0002 + new bundle); configure `appian-atlas` (token + read allowlist) for doc Q&A — introspection chat works without it.**
- **2026-07-13 (Phase 10 spec — Chat: read-only conversational assistant 📋):** Rewrote the basic draft into a full, standard, multi-sub-phase implementation plan after code-verified research across all four repos + the `appian/prod/ai-sre` reference (read via `glab`). Umbrella `specs/phase-10-chat-assistant.md` + **7 sub-phase docs** `phase-10-chat-assistant/10-01..10-07`. **Feature:** a Chat page — a persistent multi-turn Kiro conversation that (1) answers with the **`appian-atlas`** read MCP and (2) answers about Genesis's own state via a new **read-only introspection MCP server**; single blended chat, persisted+deletable sessions, single-user. **ADR-031 (drafted):** Chat is a **read-only assistant, never orchestrates** (preserves ADR-001) — enforced by capability restriction (`trust_tools`=read-only) + a new SDK **`permission_mode="auto_deny"`** + **`allow_fs_write=False`** + an ro-SQLite introspection server + steering; runs **in-process** (ADR-012's subprocess isolation is about workflow Python, which chat never executes; the agent is already isolated as the kiro-cli subprocess). **Key code-verified findings that shaped it:** persistent chat = `KiroACPClient` directly (`start` once, `prompt` per turn) — `collect*`/`query` are single-shot; the SDK today **auto-approves** permissions + fs-writes (hence 10-01 must add the deny policy — this is the load-bearing, spike-first risk); `kiro_node._emit_message` canonical `agent.*` shapes + the web `buildTranscript`/`groupTurns` renderer are **directly reusable**; the blackboard MCP server is the template for the introspection server; m0002 is the next migration (FK cascade works). **Sub-phases:** 10-01 SDK read-only permission policy (+ enforcement spike) → **sdk v0.3.0**; 10-02 Genesis-introspection MCP server (runs/failures/progress/health, ro conn, secret-redacted); 10-03 chat persistence (m0002 `chat_sessions`+`chat_messages`, stores); 10-04 `ChatManager`/`ChatSession` (persistent client, Atlas+introspection wiring, per-turn streaming, safety caps, cold-client transcript replay); 10-05 `/api/chat/*` + SSE turn stream; 10-06 web Chat page (session list + reused transcript + composer, SSE-over-fetch); 10-07 ADR-031 + steering + live acceptance + release. **Release chain:** kiro-agent-sdk **v0.3.0** → genesis-core **v0.7.0** (sdk pin) → genesis **v0.19.0** (direct sdk dep + server + migration + chat manager + api + web). **Spec-only; spike-first; awaiting approval to implement.**
- **2026-07-13 (Phase 9 SHIPPED — Agent Artifact I/O ✅):** Implemented + released the session tool-output store + agent-driven save-by-reference across all four repos (order sdk → core → genesis → workflows). **kiro-agent-sdk v0.2.0:** `ToolCall`/`ToolCallUpdate` gain `name` (`_meta.kiro.toolName`), `raw_input` (`rawInput`), `output` (extracted from `rawOutput` — the spike's correction; MCP results are NOT in `content`), + `extract_tool_output` helper (48 tests). **genesis-core v0.6.0** (CORE_MAJOR still 1, additive): `nodes/tool_store.py` (records every session tool result to `<run>/_toolcalls/` atomically) + `mcp/blackboard_server.py` (stdlib stdio MCP: `list_tool_outputs`/`save_tool_output`/`read_tool_output`, path-escape guard, retry) + `kiro_node(blackboard=True)` **default-on** (injects the server, records, services save-by-reference, emits `tool_output.recorded`/`artifact.saved`, telemetry counters, auto-trusts blackboard tools) (54 tests). **genesis v0.17.0:** eager `_toolcalls/` purge at `_finalize` (`purge_tool_store_on_final`, default on) + core pin v0.6.0 (89 tests). **genesis-workflows v0.4.0:** erd `fetch_schema` prompt rewritten to navigate + `list_tool_outputs`/`save_tool_output` (no verbatim dump; validator unchanged); documented the store as a **standard always-on authoring convention** (steering 01–04, README, new `erd-generation/README.md`, MIGRATION); core pin v0.6.0 + genesis dev pin v0.17.0 (9 tests + validate_library). All suites green + ruff clean; CI green on core/genesis/workflows (sdk has no CI). **Grounded in two spikes** (real kiro-cli 2.12.1): ACP payload shape (`rawInput`/`rawOutput`/`_meta.kiro.toolName`) and the full loop (107,839-byte gamma saved by reference with the marker absent from the model's messages — zero re-emission). Honest caveat: fixes the **output** re-emission (the `turn_timeout` bug), not the model's **input** context (kiro-cli owns the loop; a gateway would be needed — deferred). **Pending manual acceptance:** a live `genesis serve` erd run against Atlas (Docker up) to confirm `fetch_schema` completes in one short turn with no `turn_timeout` and confirm the real Atlas `rawOutput` wrapping matches the extractor. Deferred: auto-capture, `write_document` authoring, MCP gateway (§5/§9 of the spec).
- **2026-07-13 (Phase 9 spec rewritten — spike-validated design 📋):** After iterating on the design with the domain owner, replaced the whole Phase 9 spec (`specs/phase-09-agent-artifact-io.md`) with a **spike-validated** approach: a **session tool-output store + agent-driven save-by-reference**. Ran two spikes against real kiro-cli 2.12.1: (1) confirmed the ACP `tool_call` payload carries `rawInput` (args) + `_meta.kiro.toolName`, and — key correction — the tool **result arrives in `rawOutput`, not `content`** (the SDK's `content` is `None` for MCP tools, so the earlier "capture from content" plan would have written empty files); (2) end-to-end loop with two MCP servers in one Kiro session (a tool server + a Genesis blackboard server exposing `list_tool_outputs`/`save_tool_output`) — the agent fetched three ~107 KB app schemas (alpha/beta/gamma), then saved the **full 107,839-byte gamma** output to `raw_schema.json` **by reference**, and `MARKER-gamma` **never appeared in the model's messages** (its whole reply was "I'll execute these steps in order.DONE"). 107 KB persisted, zero re-emission — ALL assertions PASS. Design: `kiro_node` records every session tool result to `<run>/_toolcalls/` (index + per-call files) from the ACP stream; a Genesis-owned blackboard MCP server (shipped in genesis-core, launched via `sys.executable`, coordinating through the shared run dir) lets the **agent** decide which captured output → which doc — so Genesis needs **no** domain identifier (works as a common module). Matches the industry-standard "offload large tool outputs to the filesystem" pattern (LangChain Deep Agents, TrueFoundry, Anthropic code-execution-with-MCP; MCP `ResourceLink` is the deferred server-side variant). Honest caveat documented: fixes the **output** re-emission (the actual `turn_timeout` bug) but not the model's **input** context (kiro-cli owns the loop; a gateway would be needed, deferred). Spec covers the exact SDK changes (`name`/`raw_input`/`output`), genesis-core store + server + `kiro_node(blackboard=True)`, the **exact erd `fetch_schema` node + prompt rewrite** (validator unchanged), and the **genesis-workflows README/steering doc updates**. Ruled out: program-node fetch, capture-from-`content`, Genesis argument-matching, last-wins, server-reads-Genesis-memory. Deferred: auto-capture, `write_document` authoring, MCP gateway. **Spec-only; awaiting approval to implement (order: sdk → core → workflows).**
- **2026-07-13 (Fix — terminal `run.final` on all exit paths ✅; genesis v0.16.1):** Fixed the "run stuck showing running after cancel/crash" bug. **Root cause (event-model gap):** `run.final` was emitted only on clean completion — cancel emitted no event, a crash emitted only `error` — so the durable log didn't record termination for 2 of 3 exit paths and live clients (which key off `run.final`) never refetched. **Standard fix (state-machine terminal-event pattern, à la Temporal/Step Functions + Kubernetes-watch reconcile):** a single **idempotent `RunManager._finalize(status)` chokepoint** that records an optional `error` diagnostic, emits **exactly one** canonical `run.final{status}`, sets the store status, and closes the live bus. Routed done/failed/cancelled through it (worker `final`-terminal, `error`, `worker_exit`, worker-died-while-running, and `cancel()`); non-terminal stops (awaiting gate/paused) are unchanged and keep the bus open for resume. **Frontend backstop:** `useRunStream` now reconciles run detail+steps against the durable store on stream close (`onerror`) instead of inferring lifecycle from the transport. Tests: cancel + crash each produce a terminal `run.final` and leave no run non-terminal; `_finalize` idempotency (**86 pytest**, +3). ruff/tsc/eslint clean; 67 vitest; `web/static` rebuilt+committed; CI green. (Also diagnosed a separate live issue: erd run `r-0d97a6bdd9f9` failed because **Docker wasn't running** so no MCP server could start — environment, not a code bug; the readiness probe now reports it, and a follow-up idea is a MCP-readiness preflight that fails fast instead of letting the agent freelance.)
- **2026-07-13 (Phase 8 — Settings & Integrations Revamp ✅ SHIPPED):** Implemented `specs/phase-08-settings-revamp.md` (web-only). Released **genesis v0.16.0** (`d054491`, tagged; CI #6332251 master + #6332254 tag SUCCESS). Replaced the one-long-scroll settings page + 3 inconsistent add/edit dialogs with a **tabbed Settings workspace** (MCP · CLI · GitLab · Environments · General) at `/settings/:tab?/:id?`; removed the "Configure" sidebar group (single bottom Settings entry). Built ONE standardized, reusable pattern: **`ResourceManager`** (searchable master-detail), **`ResourceFormDialog` + `SpecForm`** (Guided ⇄ Advanced-JSON, per-field validation, name-collision guard, security callout), **`ConfirmDialog`** (retires browser `confirm()`). **MCP** tab (`useMcpResources` joins `mcp-cards` ⋈ `mcp-servers`) now shows the **real** spec, seeds the allowlist from `spec.tool_allowlist`, detects `source` correctly, and wires `updateMcpServer` — **fixing the review bugs where custom MCP servers couldn't be edited/deleted, the config JSON was fabricated, and the allowlist reset to []**. **CLI** tab wires the previously-dead edit/delete. Raw palette → semantic tokens throughout. Removed dead `McpSection`/`McpServerDetail`/`CliSection`. **67 vitest** (settings suite rewritten for tabs + regressions for the fixed bugs + jest-axe); tsc + eslint clean (0 errors); backend unchanged (83 pytest green); `web/static/` rebuilt + committed (stale-bundle guard passed). 📄 [`progress/phase-08-settings-revamp-implementation.md`](progress/phase-08-settings-revamp-implementation.md). **Next: upcoming polish phases (TBD); skill-migration stays in `specs/backlog/`.**
- **2026-07-13 (Phase reshuffle + Phase 8 planned — Settings & Integrations Revamp 📋):** The Code-Review Fix Program is complete (01–06). Reprioritized the roadmap toward **enterprise-polish** before coverage: the old Phase 8 (**Skill → Workflow Migration**) is **moved to the backlog** (`specs/backlog/skill-migration-program.md`, deferred — methodology intact, resumes after the upcoming polish phases). **Phase 8 is reassigned to the Settings & Integrations Revamp** — drafted `specs/phase-08-settings-revamp.md`. Scope (frontend-only; the spec-03/04 API already suffices): replace the one-long-scroll settings page + 3 inconsistent add/edit dialogs with a single **tabbed Settings workspace** (MCP · CLI · GitLab · Environments · General) and ONE standardized, reusable **master-detail + `ResourceFormDialog`** pattern for every integration type; remove the "Configure" sidebar items (single bottom Settings entry); `/settings/:tab?/:id?` routing. The spec also fixes real bugs found in review: `McpServerDetail` fabricates its config JSON + never seeds the allowlist from `spec.tool_allowlist` + mis-detects `source` (so custom MCP servers can't be edited/deleted today, and `updateMcpServer` is unwired), CLI edit/delete is dead, and raw palette colors violate the token system. Updated §3 phase index + `reference/roadmap-and-sequencing.md` (M8 = settings polish; skill migration → M9+ backlog). **Awaiting approval to implement (5-step delivery plan in the spec §7).** No code changed yet.
- **2026-07-13 (Code-Review Fix Program · P1 06 — Conversation Rich-Chat ✅):** Implemented spec `06-conversation-rich-chat.md` (web-only). Released **genesis v0.15.0** (`61418bb`, tagged; CI #6331854 master + #6331855 tag SUCCESS). A pure **rendering upgrade** over the existing durable event-fold engine — no transport/persistence/event-model change (kept SSE + durable log; no WebSocket/localStorage). Added a pure **`groupTurns(items, live)`** fold in `run-detail/conversation.ts` (leaves `buildTranscript` untouched): iterates items by seq, `thought`/`tool`→`thinking`, `message`→`answer`, `note`→`notes`; an `agent.result` closes the turn; **validator/retry notes that follow a result stay attached to that just-closed turn** (so a retry attempt's fail-notes belong to the attempt), a new turn opens on the next thought/tool/message; the trailing open turn is marked `live`. New components: **`TurnView`** (Thinking → markdown answer → footer), **`ThinkingTimeline`** (one collapsible left-rail panel replacing scattered ThoughtBlocks; **auto-expands while live, auto-collapses on result**, pulsing dot; manual toggle overrides), **`AssistantAnswer`** (markdown via the reused 07-09 `MarkdownView` — no new dep; **typing cursor** while live + **loading dots** pre-first-token); extracted **`conversationParts.tsx`** so `ToolCard`/`ResultChip`/`NoteRow`/`CopyButton` are reused (no circular import). `Conversation.tsx` now `useMemo(groupTurns)` + `turns.map(TurnView)`, keeping the auto-scroll/jump-to-latest + empty/non-agent states verbatim. "Regenerate" maps to the existing fork/retry HITL (not reinvented). **Tests:** `groupTurns` unit tests (single-attempt grouping + two-turn split with note-attachment + live flag) + turn-structure render tests (finished-turn thinking collapsed → expand reveals thought+tool; live-turn thinking auto-expanded w/ `aria-expanded=true`); existing `buildTranscript` + HITL tests stay green. **64 vitest** (+4), tsc + eslint clean (0 errors); backend **83 pytest** + ruff green (unchanged); `web/static/` rebuilt + committed (stale-bundle guard passed). 📄 [`progress/phase-07-cr-06-conversation-implementation.md`](progress/phase-07-cr-06-conversation-implementation.md). **Code-Review Fix Program COMPLETE: 01 ✅ 02 ✅ 03 ✅ 04 ✅ 05 ✅(decision) 06 ✅.**
- **2026-07-13 (Code-Review Fix Program · P2 05 — Persistence Scale Decision ✅ DECIDED):** Ratified spec `05-p2-persistence-scale-decision.md`. This is a **decision item, not code** — no repo changes, no release. **Standing decision: remain on SQLite** (`~/.genesis/genesis.db`, WAL) for the local single-user posture; it is the correct zero-ops choice for the single-writer / append-only-`run_events` / read-by-`run_id` access pattern. Formalized as **ADR-030** (reference/decision-log.md) with explicit re-open **triggers** — (1) multi-user/hosted/concurrent writers [a whole track re-opening ADR-012/023/026], (2) semantic search/RAG over transcripts [pgvector; the most probable trigger], (3) heavy cross-run analytics — plus the **migration path** (SQLAlchemy Core + Alembic re-home; `AsyncSqliteSaver`→`langgraph-checkpoint-postgres` behind the one checkpoint factory; a `genesis db migrate-to-postgres` one-shot export/import; pgvector `embeddings` table keyed `(run_id,node,seq)`). Guardrail recorded: **do not adopt Postgres "to be safe"** — only a real trigger warrants it. Spec 01's DB-agnostic repository signatures keep this seam cheap to cross. No test/CI impact (documentation only). **Program remaining: P1 06 (Conversation rich-chat) is the only open implementation item; P2 04 ✅ + P2 05 ✅ done.**
- **2026-07-13 (Code-Review Fix Program · P2 04 — Event-log Retention & Bus Consolidation ✅):** Implemented spec `04-p2-eventlog-retention-and-bus-consolidation.md` end-to-end. Released **genesis v0.14.0** (`44af9aa`, tagged; CI pipelines #6331764 master + #6331766 tag SUCCESS). **Part A (retention):** pure `prunable_runs()` planner in `config/retention.py` (TERMINAL-only; `keep_last ∪ max_age_days`; a `running`/`awaiting_input:*` run is NEVER returned — the hard ADR-022/§4.1 safety rule) + `RetentionService.plan()/apply()` (purges `run_events` via `EventLog.purge` + the run's blackboard dir, keeps the `runs` row as a tombstone, and **re-checks each run's status immediately before delete** to skip any run that flipped non-terminal since planning); `Settings.retention_on_start` (`GENESIS_RETENTION_ON_START=1`) drives an opt-in one-shot purge at `RunManager` init; `EventLog.count()` added for plan estimates; API `GET /api/config/retention/plan` + `POST /api/config/retention/apply` (re-plans server-side); web **Settings → Storage** "Reclaim space" flow (on-demand plan preview + confirm dialog + danger Purge; on-demand mutations so nothing fires on mount). **Part B (bus consolidation, now that the 07-10 cutover retired the interim UI):** removed the legacy `_buses` dict + `RunManager.bus()`/`events()` + every `bus.publish(...)` in `_spawn` (only the canonical `self._log()` writes + `cbus` fan-out remain; `on_exit` closes only `cbus`); pruned the unused legacy `Event` kinds (`NODE/CUSTOM/AWAITING/FINAL/ERROR/LOG`) + `last_final()` from `events.py` (kept `Event` + `EventBus`); removed the legacy `GET /runs/{id}/stream` route (verified the new web client uses only the canonical `/events` + `/events/stream`). **Tests:** new `tests/test_retention.py` (8 — planner keep_last/age/union + **two mandatory safety tests**: non-terminal never prunable even when oldest, and apply skips a run that flipped non-terminal between plan and apply); `test_runs.py` updated to assert the canonical durable log (`node.completed`/`run.final`) + `pending_gate` instead of the legacy bus. **83 pytest + 60 vitest pass** (2 new safety tests + 1 new web retention-flow test); ruff + tsc + eslint clean; `web/static/` rebuilt + committed (stale-bundle guard passed). Single event path now: canonical `EventBus` (live) + durable `EventLog`. 📄 [`progress/phase-07-cr-04-retention-bus-implementation.md`](progress/phase-07-cr-04-retention-bus-implementation.md). **Next: P1 06 (Conversation rich-chat); P2 05 (Postgres scale decision — revisit on trigger).**
- **2026-07-11 (Code-Review Fix Program · P1 03 — Integrations Studio ✅):** Implemented spec `03-p1-integrations-studio.md` end-to-end. Released **genesis-core v0.5.0** + **genesis v0.13.1** (CI green). **ADR-029** written (two-tier registry). genesis-core: `CustomMcpStore` + `CustomCliStore` (JSON file CRUD + allowlist + validation), `McpRegistry.from_layers` + `.allowlist()` + `.servers()`, `CliRegistry.from_layers` + `.clis()`, `mcp/introspect.py` (direct MCP stdio: JSON-RPC 2.0 initialize + tools/list), `_compute_effective_trust` in `agent.py` (node.tools ∩ server.allowlist). genesis: Settings paths, ConfigService extended (merged registries, CRUD, introspect, allowlist, upgraded test_server with real handshake), full API routes (`GET/POST/PUT/DELETE /config/mcp-servers` + `/tools` + `/allowlist` + `/test`; CLI parity). Frontend: types + API resource + query keys + hooks, **JsonEditor** (CodeMirror 6, dark theme, live validation, format), **McpSection** extended (Add MCP Server dialog with JSON editor + security callout), **McpServerDetail** redesigned to match Overcut reference (General/Configuration/Allowed Tools/Secrets vertical sections, Discover tools introspect, Active/Inactive status), **CliSection** extended (Add CLI dialog). **45 genesis-core + 75 genesis pytest + 59 vitest pass**; all CI green. 📄 [`progress/phase-07-cr-03-integrations-implementation.md`](progress/phase-07-cr-03-integrations-implementation.md). **Next: P1 06 (Conversation rich-chat).**
- **2026-07-11 (Code-Review Fix Program · P0 02 — Overview Dashboard ✅):** Implemented spec `02-p0-overview-dashboard.md`. Released **genesis v0.12.1** (`fdeb8dc`, tagged; CI pipelines #6328357/#6328356 SUCCESS). Delivered: (1) new **`genesis/api/home.py`** — pure `build_home()` aggregator computing metrics (total/active/succeeded/failed/success_rate/avg_duration_ms/tokens/tool_calls), 14-day trend buckets, active-run summaries (cap 20), per-integration health (MCP/CLI/GitLab), installed workflows (id/version/name/roles); (2) **`EventLog.aggregate_tool_calls(run_ids)`** — batched `GROUP BY` query (O(1) not O(runs)); (3) **frontend `features/overview/`** — `OverviewPage.tsx` (MetricCards grid, TrendChart, active-runs strip with jump-in links, integrations health chips linking to settings, installed workflows with quick-launch), `hooks.ts` (`useHome` TanStack Query, 15s refetch), `types/home.ts`, `lib/api/home.ts`, `lib/query/keys.ts` updated; router wired to `OverviewPage`; static placeholder removed (only `ComingSoon` retained); (4) **6 new vitest tests** (metrics rendering + null-handling, active-run links, integration chips, installed workflows, auto-refresh chip); (5) `web/static/` rebuilt + committed (stale-bundle guard). **75 pytest + 59 vitest pass**; ruff + tsc + eslint clean. The Overview is **no longer a static placeholder** — it calls `GET /api/home` and renders live data. 📄 [`progress/phase-07-cr-02-overview-implementation.md`](progress/phase-07-cr-02-overview-implementation.md). **Next: P1 03 (Integrations Studio) or P1 06 (Conversation rich-chat).**
- **2026-07-11 (Code-Review Fix Program · P0 01 — Persistence & Migrations ✅):** Implemented spec `01-p0-persistence-and-migrations.md`. Released **genesis v0.12.0** (`a9aac7f`, tagged; CI pipelines #6328341/#6328342 SUCCESS). Delivered: (1) new **`genesis/db/`** package — `Database` (connection factory centralizing PRAGMA WAL/busy_timeout/foreign_keys/row_factory), `runner.py` (forward-only migration runner + `schema_migrations` bookkeeping, contiguous-version validation, `current_version`/`pending` helpers), `migrations/m0001_baseline.py` (adopts existing `runs` + `run_events` tables idempotently); (2) **refactored `EventLog` + `RunStore`** onto `Database` — removed all `_conn()`/`_init()` DDL; no `import sqlite3` remains outside `genesis/db/`; (3) **`RunManager.__init__`** builds `Database` + calls `migrate()` once (guarantees schema before any read/write); (4) **CLI** `genesis db upgrade|status`. **21 new tests** in `test_db.py` (fresh migration, adoption/data-safety, idempotency, contiguity guard, sequential m0002, tx commit/rollback, helpers, refactored store CRUD + event log ops). **75 total pytest pass** (54 existing unbroken + 21 new); ruff clean. **Data-safety verified on real `~/.genesis/genesis.db`**: 13 runs, 224 events preserved after adoption; `schema_migrations = [(1, 'baseline')]`. No behavioral change to any public API. 📄 [`progress/phase-07-cr-01-persistence-implementation.md`](progress/phase-07-cr-01-persistence-implementation.md). **Next: P0 02 (Overview dashboard).**
- **2026-07-11 (Post-revamp · Code Review + Fix Program):** Ran a full, **code-grounded** review at the phase-7 checkpoint (read `kiro-agent-sdk`, `genesis-core`, `genesis` v0.11.0, `web`, all decision-log ADRs) and authored the **[`specs/phase-07-code-review-fixes/`](specs/phase-07-code-review-fixes/README.md)** package. Headline findings: the data plane is **already SQLite** (`genesis.db`, WAL) — runs, the full agent conversation (durable via `EventLog`), and checkpoints; only bulk artifacts are files (ADR-010/018), so "everything is JSON files" was a misread. Real gaps: **no DB migration framework** (raw sqlite3 + hand-written DDL ×3), **no frontend MCP/CLI extensibility** (read-only manifest registries), and the **Overview screen is unwired** (`GET /home` exists; `Overview.tsx` is a static placeholder). The package = a formal review (`00`) + implementation-ready specs: **P0** `01` persistence/migrations + `02` Overview dashboard; **P1** `03` Integrations Studio (two-tier registry + CRUD + JSON editor + tool introspection/allowlist, **ADR-029**) + `06` Conversation rich-chat (ai-sre-inspired unified Thinking timeline + markdown, keeping our durable event-fold engine); **P2** `04` event-log retention + bus consolidation + `05` a SQLite→Postgres/pgvector decision framework (verdict: stay on SQLite until a multi-user or transcript-search trigger). **Next: implement P0 (`01` + `02`), then P1.**
- **2026-07-11 (M7.1 · 07-10 Testing/CI/Rollout — WEB REVAMP COMPLETE 🎉):** The final web-revamp phase — released **genesis v0.11.0** (`f32f912`, tagged; CI pipeline #6328080 SUCCESS). Delivered: (1) an **ESLint** flat config (typescript-eslint + react-hooks) + `npm run lint` (0 errors); (2) **shared contract fixtures** in `web/src/test/fixtures` (golden event kinds / GateDescriptor / topology / steps / artifacts / config cards, typed so drift breaks tsc) + a `contract.test.ts` drift guard that feeds the golden log through the real `buildTranscript`/`deriveNodeStates` folds; (3) CI `frontend` job extended with **lint + a stale-bundle guard** (`git diff --quiet static` after build — passed, proving the committed bundle == a fresh CI build); (4) the **CUTOVER** — deleted the interim workbench (`App/surfaces/run/components/api/types/theme` + their tests, all confirmed self-referential) and rebuilt + committed the new app into `web/static/` (mermaid lazy-chunked); `genesis serve` now serves only the new SPA. Backend unchanged except the version bump. **Manual browser verification via the Playwright MCP** (per user direction, replacing authored E2E scripts) on the live `:8760` bundle passed for every screen incl. the durable **escalation-gate HITL** and per-node **Kiro conversation transcript** on the pre-existing gated run `r-0b79c1573923` (approval reachable after restart — the ADR-028 guarantee, verified live), the **documents preview** (graceful raw fallback for non-JSON), and **deep-link SPA fallback** (`/settings`, `/catalog` hard loads). 59 web tests (53 + 6 contract; interim tests removed) + 54 pytest; lint + tsc strict clean. Deviations (recorded): automated Playwright E2E → manual MCP verification; coverage-threshold gate deferred; shiki + virtualization deferred. 📄 [`progress/phase-07-10-implementation.md`](progress/phase-07-10-implementation.md). **M7.1 Web Revamp COMPLETE — all 07-01…07-10 shipped. Next program: Phase 8 (skill migration).**
- **2026-07-11 (M7.1 · 07-09 Documents & Artifact Preview):** Surfaced a run's produced documents as first-class output. **Frontend-only** — consumes the existing 07-02 artifact APIs (`/artifacts`, `/artifacts/{name}?mode=`, `/download`), so **no backend/core change and no release** (genesis stays v0.10.0). Built **pure, reusable renderers** in `features/documents/` — `MarkdownView` (react-markdown + remark-gfm; mermaid fences), `MermaidView` (**dynamic-imported** mermaid → lazy chunk, source-toggle, error→source fallback), `JsonTree` (collapsible + raw), `CsvTable` (RFC-4180 `parseCsv` + column sort + raw), `CodeBlock` (wrap+copy) — behind a `DocumentPreview` dispatcher by `preview_kind`. Wired the Run Detail **documents drawer** (`DocumentsList`: kind icon/name/size/download + Result badge on terminal) and a **deep-linkable preview sheet** (`/runs/:runId/docs/:docName`) with Download/Copy/Raw/Load-full, truncation banner, and graceful 415-binary/404-pruned degradation. Gate `context_refs` + node Inputs/Outputs docs now **cross-link** into the preview. New deps (public npm): react-markdown@9, remark-gfm@4, mermaid@11 — mermaid is lazy-loaded so the main bundle grew only ~170KB. Deviations (all recorded): live list is **polled** while active (no `artifact.written` event yet — 07-02 deferred); shiki highlighting + CSV/text virtualization deferred to 07-10. **52 web tests** (added 10: parseCsv, per-kind dispatch, drawer list, preview truncation/binary/404), tsc strict clean, temp vite build OK, `static/` untouched. Committed `4dc31a0`; frontend + genesis CI green. 📄 [`progress/phase-07-09-implementation.md`](progress/phase-07-09-implementation.md). **Next: 07-10 Testing/CI/rollout + cutover.**
- **2026-07-11 (M7.1 · 07-08 Node Inspection + Kiro Conversation + HITL):** Filled the Run Detail inspector and shipped the platform's full HITL power to the UI. **Frontend-only** — the 07-02 data plane already exposed everything (`GET /runs/{id}.gate`, `/events?node=`, `/state`, `respond`/`pause`/`resume`/`cancel`/`PATCH state`/`fork`), so **no backend/core change and no release** (genesis stays v0.10.0). Built: a **pure `buildTranscript`** fold of a node's `agent.*` + `validator.result`/`retry.scheduled` events (coalesces message/thought chunks; tool cards updated in place by `tool_call_id`); a **tabbed Node Inspector** (Conversation / Inputs-Outputs / Validation / Raw) with header (KindBadge/StatusPill/prev-next) + counters; and the **HITL bar** — a *pure function of `run.status` + `run.gate`* — covering all three modes: designed gates (approve/reject-with-confirm/feedback from `gate.options`, `pre_mutation` warned, `aria-live` announced), pause/resume/cancel, and edit-state (JSON patch; server `check_editable` 400 surfaced **inline**) + fork (ADR-025, navigates to the new run). This structurally delivers the ADR-028 "approval-from-durable-state" guarantee to the UI (reachable after reload/restart). No new deps; MarkdownView + transcript virtualization intentionally deferred to 07-09/07-10. **42 web tests** (added 8: transcript coalescing/tool-update/notes, Conversation render, gate approve/reject/feedback bodies via MSW, edit-state 400 inline), tsc strict clean, temp vite build OK, `static/` untouched. Committed `b23c5b1`; frontend + genesis CI green. 📄 [`progress/phase-07-08-implementation.md`](progress/phase-07-08-implementation.md). **Next: 07-09 Documents & preview.**
- **2026-07-11 (M7.1 · 07-07 fix — blank graph):** Run Detail rendered blank because the installed workflow.yaml files carried no `graph:` topology (hello-appian had none; erd was stale) and graph_of's steps fallback found nothing. Fixed three ways: (1) frontend now derives a fallback topology from `/steps`/events so Run Detail is never blank (committed, CI green); (2) authored a `graph:` section for **hello-appian** and released **genesis-workflows v0.3.1** (erd already had one); (3) re-installed the library + restarted the backend to v0.10.0. Verified graph endpoints return 4/11 nodes and /api/catalog/available is 200.
- **2026-07-11 (M7.1 · 07-07 Run Detail — Graph Visualization):** Built the centerpiece `/runs/:runId` screen (frontend-only; genesis stays v0.10.0). An interactive **React Flow** workflow graph (@xyflow/react + dagre auto-layout, custom NodeCards) lights up node-by-node from a pure **node-status fold** (`deriveNodeStates`) over the durable event log; hydrates via `GET /events` then tails the **named** SSE stream (dedupe by seq, closes on run.final, no-op under jsdom). Plus an accessible **list** mirror, a **timeline + telemetry** strip from `/steps`, a resizable **SplitPane** (graph / inspector), a live/replaying/closed indicator, and node selection deep-linked at `/runs/:runId/node/:nodeId`. Correct after reload/restart (durable log). Retrofit: the Catalog workflow-detail Graph tab now reuses the same renderer in **static mode** (deleted the interim GraphPreview). 32 web tests (added 5). static/ untouched. Key model note: no node.started/failed events — running = run.cursor, failure attributed to the cursor. Deviations: the inspector body + HITL bar are placeholders (07-08) and the documents drawer is a placeholder (07-09). 📄 [`progress/phase-07-07-implementation.md`](progress/phase-07-07-implementation.md). **Next: 07-08 Node Inspection + Conversation + HITL.**
- **2026-07-11 (M7.1 · 07-06 Runs List & History):** Frontend-only (the `/runs` list + pause/cancel already existed; genesis stays v0.10.0). Built `features/runs/` — the `/runs` mission-control list with **Active** and **History** sections, live StatusPills, current-node + live Duration, filters (search/status/workflow/sort), copyable run ids, and quick actions (Open / Pause / Cancel-with-confirm / Review-a-gate). `useRuns` polls every 3s **only while an active run exists**, then stops. 27 web tests (added 4, MSW). static/ untouched. Deviations: filters are client-side over a full fetch (fine at local scale); the progress column shows the current node + running pill rather than a precise step-count bar (avoids an N+1 /steps fan-out — deferred). 📄 [`progress/phase-07-06-implementation.md`](progress/phase-07-06-implementation.md). **Next: 07-07 Run Detail (graph).**
- **2026-07-11 (M7.1 · 07-05 Catalog & Install Management):** Backend (**genesis v0.10.0**, released, CI green): exposed the install lifecycle as `/catalog/available`, `POST /library/install`, `POST /library/update`, `DELETE /library/{id}` via the existing `Installer` (create_app gains an injectable `source_factory`; default builds a GitLabClient from the stored token, 400 if unset; tests use a `LocalSource` fixture → 54 pytest, ruff clean). Frontend (committed, frontend+genesis CI green): `features/catalog/` — browse (search + status + role filters, merged installed+available grid, live prereq badges cross-referencing mcp/cli status), install/remove (confirm) + update, workflow **detail** with Overview/Graph/Runs sub-tabs, and a **schema-driven Launch form** (JSON-Schema→zod widgets, env selector, prereq guard) that starts a run and routes into Run Detail. 23 web tests (MSW). static/ untouched. Deviations: the Graph tab is a lightweight static topology preview (the React Flow renderer lands in 07-07 and replaces it); no auto 'update available' detection (Update is an explicit action). 📄 [`progress/phase-07-05-implementation.md`](progress/phase-07-05-implementation.md). **Next: 07-06 Runs List.**
- **2026-07-11 (M7.1 · ADR-028 — API namespaced under `/api` + SPA history fallback):** During 07-04 live bring-up the browser-router app collided with the root-path API (a relative fetch on :5173 hit the SPA fallback and returned HTML, crashing the MCP sorter; and root prefixes /runs,/catalog can't be proxied without shadowing client routes). Fixed by moving ALL backend endpoints onto an APIRouter at `prefix="/api"` and adding a catch-all that serves index.html for non-`/api`/`/assets` paths (SPA history fallback). Frontend client + Vite proxy repointed to a single `/api`; client now rejects non-JSON (→ ErrorState) with a route error boundary. Released **genesis v0.9.0** (52 pytest incl. `test_spa_history_fallback`, ruff clean; frontend+genesis CI green). Consequence: the interim served bundle is API-broken until the 07-10 cutover; the new app runs via `npm run dev` + `genesis serve`. Docs: ADR-028 + specs 07-01/02/05..10 + 07-04 progress + AGENT_ONBOARDING updated. **Next: 07-05 Catalog.**
- **2026-07-11 (M7.1 · 07-04 Settings & Configuration):** Shipped the first real revamp screen. Backend (**genesis v0.8.0**, released, CI green): added `GET /config/cli-cards` and `POST /config/mcp-cards/{server}/test` (a lightweight *readiness* probe — secrets set + docker on PATH — NOT a live container handshake, which stays deferred), closing the contract gap 07-02 had left; `ConfigService.cli_cards/test_server` + `fields.CliCard`; +3 tests (51 pass), ruff clean. Frontend (committed, frontend+genesis CI green): stood up the data-access layer (`lib/api` typed client + `ApiError`, `lib/query` keys + shared QueryClient, TanStack Query, react-hook-form + zod) that all later screens reuse, then the `features/settings/` screen — MCP **master-detail** (searchable list + write-only secret form, per-field save, inline readiness test), CLI availability cards, global GitLab token, credential-free **Environments** CRUD (400 surfaced inline), and Storage usage. Routes `/settings`, `/settings/:server`, `/settings/environments`. 18 web tests (MSW-backed) pass; `static/` untouched (build-alongside). Deviations: secret Clear/unset omitted (no delete-secret endpoint), Allowed-Tools toggles omitted (trust_tools are per-agent-node, not server-level). 📄 [`progress/phase-07-04-implementation.md`](progress/phase-07-04-implementation.md). **Next: 07-05 Catalog.**

- **2026-07-07** — Design locked through Q1–Q14; name = Genesis; specs authored. Implementation pending.
- Prior art: `kiro-agent-sdk` built + validated (ERD workflow ran end-to-end: 37 tables, 174 relationships). See `project-tracker/kiro-agent-sdk/tracker.md`.
- **2026-07-08** — Review feedback applied: in-process → **subprocess-worker execution** (ADR-012 revised) + **genesis-core semver major-compat gate** (ADR-019 revised).
- **2026-07-08** — **Phase 1 de-risking spike PASSED** (25/25 assertions). Validated on **langgraph 1.2.8 / Python 3.13.3**: per-superstep SQLite checkpoints; `interrupt()`+resume; `update_state` edit; fork; async node; subprocess worker kill→resume (no re-exec) + `sys.exit`/hang isolation; compat-gate. Two findings recorded → **ADR-024** (async-first engine: `AsyncSqliteSaver`+`aiosqlite`; Python 3.13 pin) and **ADR-025** (fork = seed a new thread). See `reference/spike-findings.md`.
- **2026-07-08** — **Phase 1 core BUILT + tests green** (M1). Scaffolded `genesis-core` and `genesis` repos at `repo-gitlab/ramaswamy.u/` (git-initialized, committed locally). Implemented: `genesis_core` (state+reducers, RunWorkspace/Doc, PlatformContext, compat gate, node factories `program/kiro/cli/validator/gate/subgraph`, `attach_reliability` trio, batteries-included `validators` toolkit, MCP+CLI registries) and `genesis` platform (settings with state+artifacts roots, async `AsyncSqliteSaver` checkpointer, engine compile/run/resume, context builder, testing harness). **20 tests pass** (15 core units + 5 platform smoke), **ruff clean**. Acceptance verified: smoke workflow completes; reliability trio retries `retry_max` then escalates; per-node + `_run` telemetry captured; MCP fail-fast on unresolved `${VAR}`; per-node MCP injection; no bulk in state; durable resume from checkpoint (true kill/resume proven in the spike).
- **2026-07-08** — **Repos pushed to GitLab + distribution wired.** `kiro-agent-sdk` tagged **v0.0.1**, `genesis-core` **v0.1.0**, `genesis` **v0.1.0**. Git-pinned dependencies (option A): `genesis → genesis-core → kiro-agent-sdk`, all `git+ssh` by tag with `allow-direct-references`. Verified in clean venvs that `pip install genesis@v0.1.0` resolves the entire tree — **the SDK is pulled transitively; no separate download**. `genesis-workflows` remote exists but is empty (Phase 2).
- 📄 **Full detail:** [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md) — repos/tags, module inventory, evidence table, implementation decisions, deviations, deferred items, dev run instructions.
- **2026-07-09** — CI fixed: `git+ssh` deps couldn't clone in runners; each `.gitlab-ci.yml` now rewrites to HTTPS via `GITLAB_PUSH_TOKEN` (matches solutions-atlas-kb). All three pipelines green (genesis-workflows `library-validate` runs the reliability-lint gate + fixture proof in real CI).
- **2026-07-09** — **Phase 3 COMPLETE + pushed** (M3 — Distribution works). Added `genesis/dist/`: GitLab REST client, catalog (filter + bundle expand + cross-role selection + prereqs), lockfile (+ update detection), installer (resolve/install/update/remove), and the loader with the **genesis-core major-compat gate** (ADR-019 — refuses load on major skew). Proven end-to-end: install `hello` from a fake GitLab → load → run to completion. **24 platform tests green**, ruff clean. Tags: genesis **v0.3.0**, genesis-workflows **v0.1.1**. 📄 Detail: [`progress/phase-03-implementation.md`](progress/phase-03-implementation.md). **Next: Phase 4** (configuration & secrets).
- **2026-07-09** — **Phase 4 COMPLETE + pushed** (M4 — Config & secrets). Added `genesis/config/`: `SecretProvider`/`PlaintextProvider` (0600, `scope/VAR`, server→global resolve, collisions), MCP-registry-derived config cards + `missing_secrets`, credential-free `EnvironmentRegistry` (rejects credential-looking fields; requires url+api_endpoint), artifacts **retention** (keep-last-N / max-age over terminal runs) + Settings, **health checks** incl. the stubbable **MCP literal-env probe**, and the `ConfigService` facade. genesis-core `McpRegistry` `${VAR}` resolution is now **server-scoped** (additive, backward-compatible — MAJOR stays 1) with **fail-fast before Kiro spawns**; `build_context` default-wires the providers. **26 platform + 15 core + 2 workflow tests green**, ruff clean, library validation passing. Tags: genesis-core **v0.3.0**, genesis **v0.4.0**, genesis-workflows **v0.1.2**. 📄 Detail: [`progress/phase-04-implementation.md`](progress/phase-04-implementation.md). **Next: Phase 5** (run orchestration & HITL).
- **2026-07-09** — **Phase 5 COMPLETE + pushed** (M5 — Supervised runs). Added `genesis/runs/` (RunStore + lifecycle, EventBus, input/edit validation, **subprocess worker** per ADR-012, supervisor spawn/kill/death-detection, **RunManager** facade) and `genesis/api/` (FastAPI backend embedding LangGraph + SSE stream + Studio debug graph). **All three HITL modes** implemented and tested: designed gates (approve/reject/feedback), pause/resume (durable across a fresh manager = app restart), and state injection (edit + fork on a new thread, ADR-025). **Worker isolation** proven (a crashing workflow fails only its run; app survives; resumable). **40 platform tests green** (10 run + 4 API via real subprocess workers on program-only workflows), ruff clean. Tag: genesis **v0.5.0** (core/workflows unchanged). ⚠️ The "demonstrable in Studio" criterion is a GUI step — wiring + runbook delivered (`langgraph.json`, `studio.py`, `docs/debug-in-studio.md`); not runnable in this headless env. In-flight ACP `session/cancel` deferred to the SDK. 📄 Detail: [`progress/phase-05-implementation.md`](progress/phase-05-implementation.md). **Next: Phase 6** (ERD reference workflow).
- **2026-07-09** — **Phase 6 COMPLETE + pushed** (M6 — Reference workflow). Built **`erd-generation`** in genesis-workflows: the canonical reference workflow porting the validated ERD pipeline onto Genesis primitives — `preflight`→`fetch_schema`(agent, appian-atlas, verbatim-dump)→`normalize`(program)→`assign_domains`(agent, decisions-to-file)→**approve-domains** gate (feedback re-runs assign)→`assemble`→`run_erdgen`(cli, dry-run branch)→`report`, with **two reliability trios** (custom cross-artifact validators: table coverage, domain-in-set, PK-first, audit exclusion) sharing an `escalate` gate. Ported pure fns are unit-tested; stubbed-graph tests prove gate-resume + forced-failure escalation. **9 workflow tests green**, library validation passing (2 workflows), steering points to it as the template. Tag: genesis-workflows **v0.2.0**. ⚠️ Live dry-run parity (~37 tables/174 rels) needs real Atlas+Kiro+Lucid creds (opt-in; stubbed pipeline proven). 📄 Detail: [`progress/phase-06-implementation.md`](progress/phase-06-implementation.md). **Next: Phase 7** (custom web workbench).
- **2026-07-09** — **Phase 7 COMPLETE + pushed** (M7 — Product UI). Built the **Genesis web workbench**: a **React + TypeScript** SPA (Vite) served by the FastAPI backend, replacing Studio for day-to-day use. Six surfaces (Overview, Catalog w/ role filter + prereq badges, Config, Run launch w/ schema-driven form, Run Detail, History) with **all three HITL modes** in the UI (gate approve/reject/feedback, pause/resume/cancel, edit-state + fork), live **SSE** step timeline + activity + telemetry + artifacts. Backend gained static SPA serving + config CRUD + `/home`/`/workflows/{id}` aggregates; one-command launch via **`genesis serve`** (uvicorn). **Live launch verified** (index + JS bundle + /home/ /catalog served). **43 platform + 5 frontend tests green**; both CI jobs green (added a node:20 `frontend` job: typecheck+vitest+build). Tag: genesis **v0.6.0**. ⚠️ Deviation (approved): spec said Preact; user chose **React+TS** for enterprise-grade future-proofing (backend unchanged — still local single-user). ⚠️ Visual/UX QA is a manual browser step; Catalog install/remove endpoints are a small follow-up. 📄 Detail: [`progress/phase-07-implementation.md`](progress/phase-07-implementation.md). **Next: Phase 8** (skill migration program).
- **2026-07-10** — **M7.1 · phase-07-03 (Design System) implemented + CI green.** Stood up the frontend foundation in `genesis/web` on the ADR-027 stack: **Tailwind v3 + design tokens** (the Overcut-derived dark/light palette from 07-03a, incl. the `.metric-value` oversized numeral), a **Zustand theme store**, and a shadcn-style, Radix-backed **component library** — primitives (Button/Card/Input/Badge+**StatusPill/StatusDot/ActionPill/KindBadge**/Switch/Tooltip/Tabs/Dialog+**Drawer**/Skeleton), **patterns** (**MetricCard**, SegmentedControl, FilterChip/**CategoryChips**/**ToolChipRow**/AutoRefreshChip, HealthDot, RelativeTime/Duration, **TrendChart**, toasts), **layout** (AppShell, grouped **Sidebar** [MONITOR/LIBRARY/CONFIGURE], Topbar w/ breadcrumb + theme + right-rail toggle, resizable SplitPane, Page/Section), and feedback states (Empty/Error/Loading). A **kitchen-sink** dev route renders everything for visual QA via a **separate `dev.html` entry** — so the production build output (served `static/`) is untouched (**build-alongside**, per 07-10). **14 web tests pass** (incl. jest-axe a11y), `tsc` strict clean; **frontend CI job green**. Note: installed from public npm (the local Artifactory token is expired). Not released (no version bump — foundation not yet cut over). Also flipped the **new app to the dev root** (router + AppShell + placeholder Overview; kitchen sink at `/dev`) so screens can be watched as they land — the interim app is retained and the served `static/` bundle is unchanged until cutover. 📄 [`progress/phase-07-03-implementation.md`](progress/phase-07-03-implementation.md). Screens (07-04..09) consume this + the 07-02 data plane. **Next: 07-04 Settings.**
- **2026-07-10** — **Web-revamp designs updated from a first-hand Overcut study.** Analyzed 19 screenshots of the Overcut app and authored **`specs/phase-07-03a-visual-language-reference.md`** (the visual north star): Genesis adopts Overcut’s vocabulary (near-black surface, **metric cards** w/ oversized numerals + date-range/group-by/auto-refresh, **master-detail** config, **category-chip card** catalogs, **node-card** canvases, status pills/dots, tool chips, grouped sidebar) and **innovates on top** (live run graph as hero, **per-node Kiro conversation** inspector, first-class HITL, doc preview drawer). Revised **07-01** (shell/nav grouping + Genesis nouns, metric-card Overview), **07-03** (tokens → observed palette + new components: MetricCard/SegmentedControl/DateRange/FilterChip/CategoryChips/ToolChipRow/NodeCard/TrendChart), **07-04** (master-detail config), **07-05** (category chips + workflow sub-tabs), **07-06** (Executions-table parity), **07-07** (NodeCard aesthetic + per-run dashboard tab). ADR-027 addendum recorded. Genesis stays local single-user.
- **2026-07-10** — **M7.1 · phase-07-02 (Backend Data Plane) COMPLETE + released.** Implemented the critical-path data plane for the web revamp — durable-first and fully additive. **Persistent event log** (`run_events` table + `EventLog`): every event is durably logged + fanned out, so a run’s timeline/conversation survives a reload/restart. **Gate-from-checkpoint** fixes the approval bug at the root: `hitl_gate` emits a full GateDescriptor, `RunManager.pending_gate()` derives it from the durable log (fast) or the checkpoint’s pending interrupt (cold), and `GET /runs/{id}` now returns `gate` — controls no longer depend on a transient event (regression test: gate reachable from a fresh RunManager = simulated server restart). **Live Kiro conversation**: SDK `collect_streaming`, `kiro_node` forwards ACP messages as canonical `agent.*` events (graceful fallback), trio emits `validator.result`/`retry.scheduled`. New APIs: `/workflows/{id}/graph` (topology), `/runs/{id}/events` + `/events/stream` (durable replay+live, dedupe by seq), `/runs/{id}/steps`, artifact `content`/`download` + media/preview kinds, `respond` gate-option validation. ERD `workflow.yaml` gained a `graph:` section (parity lint exempts yaml-only keys). Tests: sdk 41 · core 17 · genesis 48 (incl. 5 data-plane) · workflows validation green; ruff clean. Released in order: kiro-agent-sdk **v0.1.0** → genesis-core **v0.4.0** → genesis **v0.7.0** → genesis-workflows **v0.3.0** (pins bumped, stale workflow pins cleared); all CI green. 📄 [`progress/phase-07-02-implementation.md`](progress/phase-07-02-implementation.md). **Next: 07-03 design system + screen specs.**
- **2026-07-10** — **Web Revamp program specced (M7.1 — sub-series of Phase 7).** After live use surfaced that the interim workbench under-exposes the platform (HITL gate approval unreachable after reload/restart; Kiro conversation discarded; no workflow graph, node inspection, or document preview), scoped a full **enterprise-grade web-app revamp** as a spec-first program. Authored **10 detailed implementation specs** in `specs/phase-07-0N-*`: (01) program overview & frontend architecture, (02) backend/core data-plane — persistent event log, gate-from-checkpoint (root-cause fix for the approval bug), ACP **conversation streaming** across kiro-agent-sdk/genesis-core/worker, topology/steps/artifact-content/status APIs, (03) design system (Tailwind + shadcn/ui), (04) settings, (05) catalog & install, (06) runs list, (07) run-detail **graph visualization** (React Flow), (08) node inspection + **Kiro conversation** + **all 3 HITL modes** from durable state, (09) documents & preview, (10) testing/CI/rollout. Stack recorded as **ADR-027** (Vite/React/TS + React Router + TanStack Query + Zustand + Tailwind/shadcn + React Flow + rhf/zod + Vitest/RTL/MSW/Playwright). Full rebuild of `genesis/web/`; backend changes additive (data plane spans genesis v0.7.0 / genesis-core v0.4.0 / kiro-agent-sdk v0.1.0 / genesis-workflows v0.3.0). ⚠️ Deviation approved: expanded frontend dep surface + cross-repo data-plane work (user authorized touching any repo). **Next: implement 07-02 + 07-03 (critical path), then screen specs.**
- **2026-07-09** — **Post-M7 live bring-up + hardening** (first real end-to-end runs via the workbench). Added the missing distribution loop: **`genesis install` / `genesis list`** CLI (GitLab pull via the stored token, or `--from <local checkout>`) + a `LocalSource` — populates `~/.genesis/library` so the Catalog is non-empty. Ran **hello-appian green end-to-end** (real Kiro: 1 turn, validator passed, `result.json` written). Then drove **erd-generation** to first success, fixing a chain of real bugs found only by running live:
    1. **`kiro_node` passed an unsupported `tools=` kwarg** to `KiroAgentOptions` → mapped to the SDK's `trust_tools`/`trust_all_tools`; added a regression test using the **real** options dataclass (core **v0.3.1**).
    2. **SSE reconnect-replay loop** (the "13× repeated activity"): terminal runs closed the bus → `EventSource` auto-reconnected and re-replayed history forever. Fixed server-side (keep the bus open until terminal; don't mislabel a paused worker as failed) + client-side (dedupe replays; close `EventSource` on terminal) (**v0.6.2**).
    3. **Error diagnostics clobbering** — a generic `worker_exit` overwrote the real error; now the specific error (with exception type + timeout hint) surfaces in the UI (**v0.6.3**).
    4. **Placeholder MCP images** in the library registry (`<atlas-image>` …) → replaced with the real internal images (atlas/jarvis/datagen/jira); configurable `startup_timeout` (default 120s) for heavy MCP servers (genesis-workflows **v0.2.1**, core **v0.3.2**).
    5. **THE root cause — ACP MCP `env` shape:** `McpRegistry.acp_servers()` emitted `env` as a **dict**, but ACP/kiro-cli expects a **list of `{name,value}`** (per the SDK's `load_mcp_servers`). So kiro-cli silently dropped the env → the Atlas container ran **without `GITLAB_TOKEN`** and hung to the session timeout. Fixed to the list shape; corrected the smoke/config/core tests that had asserted the wrong dict shape (the stub that hid the bug). Verified live: ERD now gets past MCP init into the real (slow) Atlas schema fetch instead of failing at ~120s (core **v0.3.3**, genesis **v0.6.4**). Latest tags: genesis-core **v0.3.3**, genesis **v0.6.4**, genesis-workflows **v0.2.1**. Remaining follow-ups: Catalog install/remove buttons in the UI; a browser UX pass; full ERD dry-run parity (~37 tables/174 rels) once the two agent turns complete.
