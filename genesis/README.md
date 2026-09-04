# Genesis — Documentation Index

**Genesis** is an agentic SDLC platform for the Appian **Solutions** department:
a local web application that orchestrates multi-step SDLC **workflows** using
**LangGraph** as the engine and **Kiro** (via `kiro-agent-sdk` over ACP) as the
agent runtime. Workflows are pulled from a shared GitLab library and run on the
user's machine with their own credentials. Genesis **replaces** solutions-copilot
and realizes its deferred (doc-19) orchestration vision.

> All planning/design + as-built documentation lives here in `project-tracker/genesis/`. The code lives in five built +
> shipped repos: `genesis`, `genesis-core`, `genesis-workflows`, `kiro-agent-sdk`, and `genesis-appian-parser`.
> **New here? Read [`AGENT_ONBOARDING.md`](AGENT_ONBOARDING.md) first — the single task-agnostic onboarding doc ("the bible").**

---

## How to navigate

**Start here**
- [`AGENT_ONBOARDING.md`](AGENT_ONBOARDING.md) — **the bible**: the single task-agnostic onboarding doc (architecture, current state + tags, ADRs, hard-won lessons, roadmap). Read this first.
- [`tracker.md`](tracker.md) — master tracker: the **§6 status log** (running history), the Q1–Q14 locked decisions, phase index, reuse map, open items.
- [`specs/00-architecture-overview.md`](specs/00-architecture-overview.md) — the layered architecture, domain model, node taxonomy, state/blackboard rule. **Read before any phase spec.**
- [`progress/`](progress/) — as-built implementation records per phase (evidence, decisions, deviations). Start with [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md).

**Phase specs (the build plans)** — `specs/` · *authoritative status = `AGENT_ONBOARDING.md` §9 + `tracker.md` §6*
| Phase | Spec | Title | Status |
|---|---|---|---|
| 1 | [phase-01](specs/phase-01-core-platform-foundation.md) | Core Platform Foundation | ✅ shipped |
| 2 | [phase-02](specs/phase-02-workflow-contract-and-library.md) | Workflow Contract & Library System | ✅ shipped |
| 3 | [phase-03](specs/phase-03-distribution-install-lockfile.md) | Distribution: GitLab Pull, Selective Install, Lockfile | ✅ shipped |
| 4 | [phase-04](specs/phase-04-configuration-and-secrets.md) | Configuration & Secrets | ✅ shipped |
| 5 | [phase-05](specs/phase-05-run-orchestration-and-hitl.md) | Run Orchestration & HITL | ✅ shipped |
| 6 | [phase-06](specs/phase-06-erd-reference-workflow.md) | ERD Reference Workflow | ✅ shipped |
| 7 | [phase-07](specs/phase-07-01-web-revamp-program-overview.md) | Web Workbench (React+TS revamp) | ✅ shipped |
| 8 | [phase-08](specs/phase-08-settings-revamp.md) | Settings & Integrations Revamp | ✅ shipped |
| 9 | [phase-09](specs/phase-09-agent-artifact-io.md) | Agent Artifact I/O | ✅ shipped |
| 10 | [phase-10](specs/phase-10-chat-assistant.md) | Chat Assistant | ✅ shipped |
| 11 | [phase-11](specs/phase-11-credit-usage-tracking.md) | Credit & Usage Tracking | ✅ shipped |
| 12 | [phase-12](specs/phase-12-code-review-workflow.md) | Appian Code-Review Workflow | ✅ shipped |
| 13 | [phase-13](specs/phase-13-copilot-orchestrator.md) | Chat Copilot & Run Orchestrator | ✅ shipped |
| 14 | [phase-14](specs/phase-14-skills-in-chat.md) | Skills in Chat | ✅ shipped |
| 15 | [phase-15](specs/phase-15-design-doc-workflow.md) | Design-Document Workflow | ✅ shipped |
| 16 | [phase-16](specs/phase-16-appian-knowledge-base.md) | Appian Knowledge Base ("Atlas-into-Genesis") | ▶ in progress — 16-01/02/03/04/08 shipped; 16-05 next |
| 17 | [phase-17](specs/phase-17-business-application-map.md) | Business Application Map (agent-synthesized business flow) | ✅ shipped — 17-01..17-06 (genesis v0.39.0 + genesis-workflows v0.9.1); live-accepted |
| 18 | [phase-18](specs/phase-18-parser-accuracy.md) | Appian parser accuracy overhaul (dependency/orphan/integration-point extraction) | ✅ shipped — 18-01..18-06 (genesis-appian-parser v0.2.0 + genesis v0.40.0 + genesis-workflows v0.9.2); orphans 804→0, edge recall 0.32→0.98; live-validated |
| 19 | [phase-19](specs/phase-19-document-library.md) | Genesis Document Library (attach/parse/sync Drive + uploaded business documents per app; managed-native `gws` connector) | ✅ SHIPPED — genesis-core v0.9.2 + genesis v0.44.0 + genesis-workflows v0.9.3 (19-01..19-08), CI green. ADR-040/041 Accepted. Global dedup'd store + app links, gws read-only OAuth, parsing (pypdf/python-docx/openpyxl), `sync-documents` workflow, `genesis-kb` doc tools + evidence-pack, web Library page + full-screen viewer + Business Artifacts tab + connector card |
| 20 | [phase-20](specs/phase-20-features-and-spec-authoring.md) | Features & Spec Authoring (per-app Features + a conversationally-authored, annotatable HTML Spec) | ✅ SHIPPED — genesis **v0.45.0** (20-01..20-06), CI green. ADR-042/043 Accepted. m0010 `kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions` + `FeatureStore`; Features tab + feature page; spec = a reused Chat (`feature_spec` mode, genesis-kb + `./context/` business-artifact files) authoring **HTML** in the fs sandbox; embedded **vendored Lavish annotation SDK** (MIT, Genesis-themed) → annotation-to-chat bridge; status draft→in-progress→in-review→completed + milestones + MD export. genesis-only release |
| 21 | [phase-21](specs/phase-21-feature-workspace-and-chat-parity.md) | Feature Workspace, Spec-Builder UX & Chat Parity (Phase-20 live-feedback pass) | ✅ SHIPPED — genesis **v0.46.0** + genesis-core **v0.9.3** + kiro-agent-sdk **v0.7.0** (21-01..21-07), CI green. ADR-044/045 Accepted (045 refines ADR-031). Feature page → **artifact pipeline** (Spec card Edit/View + Design/Breakdown placeholders; feature card drops spec status); spec builder → **full-width chat + full-screen annotatable Preview** (our comment-queue + Send-all), `feature_spec` sessions isolated from the main chat; **Kiro CLI/ACP parity** (model @ creation, slash commands + autocomplete, context/compaction meter, clear/compact, image attach) in both places (m0011 `chat_sessions.model`); **Markdown transcript export** |
| 22 | [phase-22](specs/phase-22-distribution-and-shipping.md) | Distribution & Browser-Based Shipping (clone + git-tag self-update) | ✅ SHIPPED — genesis **v0.47.0** (22-01..22-07), CI green. ADR-046. `scripts/install.sh` + `genesis up/down/status/logs/update` + in-app UpdateBanner + Kiro sign-in + preflight |
| 23 | [phase-23](specs/phase-23-scheduled-and-full-package-syncs.md) | Scheduled & Full-Package Syncs | ✅ SHIPPED — genesis **v0.48.0** (23-01..23-03), CI green. ADR-047, m0012. Re-runnable full-package refresh + backend scheduler (application-sync + document-library-sync) |
| 24 | [phase-24](specs/phase-24-ux-revamp-and-environment-credentials.md) | UX revamp + environment-scoped credentials | ✅ SHIPPED — genesis **v0.48.5** (24-01, ADR-048) + **v0.48.6** (24-02, ADR-049). Env-scoped core-MCP creds; Applications-first IA |
| 25 | [phase-25](specs/phase-25-architectural-foundation-hardening.md) | Architectural Foundation Hardening (code-review remediation) | ✅ SHIPPED + COMPLETE — genesis **v0.49.0 + v0.50.0** + genesis-core **v0.9.4 + v0.9.5** (25-01..25-10 + 25-13), CI green. ADR-050/051/052 Accepted + ADR-026 amended. Typed SDLC domain + LifecycleService (m0013) · structured logging · atomic JSON · localhost guardrail · AgentProvider · god-module decomposition · ChatModeProfile · optimistic locking (m0014) · DocumentProvider · reliable_agent_step · observability metrics/activity. **25-11 + 25-12 → backlog** |
| 26 | [phase-26](specs/phase-26-agentic-memory-layer.md) | Agentic Memory Layer | ✅ SHIPPED — genesis **v0.52.0** + genesis-workflows **v0.10.0** (26-01..26-08), CI green. ADR-053/054. Separate `memory.db` (mm0001 — bi-temporal entity/relationship graph + FTS5 + `sqlite-vec`), a read-only **`genesis-memory` MCP** (hybrid retrieval, chat-wired), nightly **`memory-consolidation`** + weekly **`memory-maintenance`** workflows, a browser-only curation API + **/memory** workspace (d3-force constellation, v0.52.1) |
| 27 | [phase-27](specs/phase-27-ui-ux-revamp.md) | UI/UX Revamp | ✅ SHIPPED — genesis **v0.53.0** (27-01..27-11), CI green. ADR-055. Light-first **Indigo·Slate** re-theme + UX overhaul of the whole web app (single-source `tokens.css` brand knobs, Poppins, differentiated shell / glassy TopBar / ⌘K, Home dashboard); frontend-only |
| 28 | [phase-28](specs/phase-28-feature-revamp.md) | Feature Revamp (Feature Workspace framework) | ✅ SHIPPED — genesis **v0.54.0** + genesis-workflows **v0.11.0** (28-01..28-06), CI green. ADR-056 (supersedes ADR-044's sequential unlock). A Feature = **parallel, plug-in stages** (`stages.ts` + `stage-registry.tsx` + command-center Overview + peer stage cards + derived status); a stage plugs in with no shell edits. + 2 library skills |
| 29 | [phase-29](specs/phase-29-ux-design-stage.md) | UX Design Stage (mockup → grounded implementation analysis) | ✅ SHIPPED — genesis **v0.56.2** + genesis-workflows **v0.12.1** + genesis-core **v0.9.6** + kiro-agent-sdk **v0.7.1** (29-01..29-06 + v0.55.1–v0.56.2 follow-ons), CI green. ADR-057. Upload a mockup **PDF** → the **`ux-design-analysis`** workflow (PyMuPDF render → per-screen **multimodal** analysis → grounding [genesis-kb structure + appian-dev code] → synthesize → **grounded verify** critic) → a **StageFinalizer** opens the **`ux_design`** completion chat + sets the stage in-review → annotatable review + Mark complete. Reuses the Spec-page components **generalized** (D0); Spec repointed onto **m0015** `kb_feature_stages`/StageStore (Decision A). `current_version`→15. **Post-ship: `.pdf` upload allowlist + 25 MB cap; StageFinalizer logging + in-flight recovery + bound-run finalize guard; run-detail display fixes (steps-authoritative status, execution counts, "Round k of N" dividers, bordered graph canvas); single-nav feature workspace + mockup-faithful UX empty/running states; UX Re-upload & re-run UI; global ⌘K search (applications/features/documents); and `ux-design-analysis` v0.1.1 reframed to UX/business language (no object-level detail — FB-4).** |
| 30 | [phase-30](specs/phase-30-technical-design-stage.md) | Technical Design Stage (Spec + UX → grounded technical design) | ✅ SHIPPED — genesis **v0.57.0** + genesis-workflows **v0.13.0** (30-01..30-07), CI green (genesis #6725001 / workflows #6725004). ADR-058 (+ an ADR-056 **prerequisite** amendment). Once the **Spec + UX Design** artifacts exist, Start (optional comment, no file) → the **`technical-design-analysis`** workflow (plan by **functional workstream** → per-workstream **existing-state grounding** [genesis-kb structure + appian-dev code, read-only] → per-workstream **design drafting** → **agent assemble** → **grounded verify** critic) → a **`technical_design`** completion chat finalizes it via the same annotatable review. **Object-level + code-grounded** (each change names a real object or is marked NEW; blind spots → Open Questions) — the inverse of ADR-057. Reuses the Phase-29 surface (m0015, the stage components, the StageFinalizer generalized to a workflow→stage binding registry); **no migration; genesis + genesis-workflows only**. Prerequisite gating enforced UI + backend. Also folded in **two UX refinements**: clickable stage cards (no Open button) + openable artifacts (generated → read-only preview; reference → Document Library viewer). **Post-ship (genesis v0.58.0 + genesis-workflows v0.14.0, CI green — genesis #6727262 / workflows #6727270): run-graph revamp (elkjs layered LR + orthogonal routing, executed path green + ×N counts, `/runs/{id}/transitions`), run-detail perf (per-node events + /steps-driven graph), honest partial credit provenance, worker terminal-status fix (approved-escalation finalize), no-cache index.html; TD workflow v0.2.0 = deterministic assemble + synthesize + cleanup.** |
| 31 | [phase-31](specs/phase-31-feature-breakdown-stage.md) | Feature Breakdown Stage (Spec + UX + Technical Design → grounded, Jira-ready backlog) | ✅ SHIPPED — genesis **v0.59.0** + genesis-workflows **v0.15.0** (31-01..31-07), CI green (genesis #6735324 / workflows #6735326). **ADR-059 (Accepted)**. Once **Spec + UX + Technical Design** all exist, Start (optional **notes** + up to **3 uploaded docs**) → the **`feature-breakdown-analysis`** workflow (epics = the TD's **functional workstreams** → per-epic **story/task breakdown** [Appian form-vs-process-model split, entry-point splitting, **Story**=FE-testable / **Task**=not-FE-verifiable, **Gherkin** AC, one-line TD-anchored Dev Notes] → **deterministic assemble** [backlog.json + a Lavish-safe `breakdown.html` — `<details>` cards grouped by epic + CSS-only table toggle + embedded canonical JSON] → **grounded verify** critic) → a **`feature_breakdown`** completion chat refines it via the same annotatable review. **Jira-importable CSV export** (create-new-epics via Issue ID → Parent ID; `openpyxl`/`csv`, no new dep). Methodology from the `spec-to-backlog` Kiro skill (analysis core only). Reuses the Phase-29/30 surface (m0015, stage components, the StageFinalizer binding registry); **no migration; genesis + genesis-workflows only**. |
| 32 | [phase-32](specs/phase-32-finalize-stories.md) | Finalize Stories (Feature Breakdown → first-class, editable Story records) | ✅ SHIPPED — genesis **v0.60.0** (32-01..32-05), CI green (#6737415 master / #6737421 tag). **ADR-060 (Accepted)**. Once the **Feature Breakdown** stage is **completed**, a one-time, **irreversible** **Finalize Stories** action (a header button replacing "Back to application" + a warning dialog) parses the canonical backlog embedded in `breakdown.html` and persists every epic + story/task into new **`kb_epics`/`kb_stories`** (**m0016**; `current_version` 15→16; `kb_features.stories_finalized_at` one-time marker) via `kb/stories.py::StoryStore`. The reserved **Stories tab** becomes a filterable/paginated **grid** (Epic · Type · Title, colored tags, grouped by epic) + a routed **StoryDetailPage** with **story-level CRUD** (add/edit/delete; parent-epic dropdown; **`row_version`** CAS). Epics fixed at finalize (no epic CRUD); story `status` default `design` (forward-compat, not surfaced); **no re-sync**. Also: a themed **`Select`** primitive (Radix DropdownMenu) for the Stories + Runs filters, and **run-detail graph UX fixes** (live executed path + refresh, readable ×N, standard icons, path legend). **Genesis-only + m0016.** |

> The **skill → workflow migration program** (the original "Phase 8") is deferred in [`specs/backlog/`](specs/backlog/).

**Reference docs (the stable, cross-cutting truth)** — `reference/`
| Doc | Purpose |
|---|---|
| [decision-log](reference/decision-log.md) | ADR-style record of Q1–Q14 + alternatives + rationale |
| [roadmap-and-sequencing](reference/roadmap-and-sequencing.md) | Phases, milestones, dependencies, build order |
| [repo-structure](reference/repo-structure.md) | Layout of `genesis` + `genesis-workflows` |
| [node-taxonomy-reference](reference/node-taxonomy-reference.md) | Every node factory + the kiro-agent-sdk integration |
| [state-and-data-model](reference/state-and-data-model.md) | `PlatformState`, blackboard, artifact conventions |
| [mcp-and-cli-registry](reference/mcp-and-cli-registry.md) | Registry schemas + catalog of known servers/CLIs |
| [workflow-authoring-standard](reference/workflow-authoring-standard.md) | The canonical standard authors follow |
| [reliability-standard](reference/reliability-standard.md) | The hard requirement: validator + retry/escalation |
| [hitl-design](reference/hitl-design.md) | The three HITL modes in depth |
| [security-and-secrets](reference/security-and-secrets.md) | Trust model, secret handling, pulled-code stance |
| [testing-strategy](reference/testing-strategy.md) | Platform + workflow testing + CI gates |
| [langgraph-capability-map](reference/langgraph-capability-map.md) | Which LangGraph features are used where |
| [solutions-copilot-relationship](reference/solutions-copilot-relationship.md) | Positioning + reuse map + doc-19 realization |
| [glossary](reference/glossary.md) | Terms |

---

## The idea in five bullets

1. **LangGraph owns control flow** — determinism never depends on a model's discipline (the failure that sank the solutions-copilot agent-orchestrator).
2. **Each former "skill" becomes a workflow** — a LangGraph package; each step is a **program** (if deterministic) or a narrow **agent** node (Kiro via ACP with per-node MCP injection).
3. **Reliability trio is mandatory** — every agent node has a program **validator** + **retry/escalation**, enforced in library CI. This is the differentiator.
4. **Small editable state + a per-run blackboard folder** for bulk data — makes durable checkpointing and human state-editing usable.
5. **Local web app, shared GitLab workflow library, selective install** — internal Solutions use (Dev/Tester/PO/UX), all three HITL modes required.

---

## Related trackers

- [`../kiro-agent-sdk/tracker.md`](../kiro-agent-sdk/tracker.md) — the Kiro/ACP node adapter (built + validated: ERD ran end-to-end, 37 tables / 174 relationships).
- [`../solutions-copilot/`](../solutions-copilot/) — the retired predecessor; its 45 skills are the migration source (Phase 8) and doc-19 is Genesis's de-facto requirements.
