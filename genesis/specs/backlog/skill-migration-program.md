# Backlog — Skill → Workflow Migration Program (formerly Phase 8)

> **⏸️ DEFERRED (2026-07-13).** This was Phase 8; it is moved to the backlog and not scheduled for
> now. The Phase 8 slot is reassigned to the **Settings & Integrations Revamp**
> (`specs/phase-08-settings-revamp.md`), with a few more enterprise-polish phases planned before the
> migration program resumes. When it resumes it will be renumbered to the then-current phase.
> The methodology below remains valid; only the sequencing changed.

> **Goal:** Systematically migrate solutions-copilot's 45 skills into Genesis
> workflows, one by one, using a repeatable methodology and the ERD workflow as
> the template. This is an ongoing program (not a single sprint) that grows the
> `genesis-workflows` library to full SDLC coverage.

Prereq: Phases 1–6 (the platform + ERD reference). Source material:
solutions-copilot `.kiro/skills/**` (SKILL.md + references, ~35,900 lines).

---

## 1. Objective & success statement

Every solutions-copilot skill that has ongoing value is reborn as a Genesis
workflow that (a) passes library CI (reliability trio enforced), (b) is
installable and runnable, and (c) preserves the skill's hard-won logic (the
verbatim references are the workflow's design source). Coverage is tracked in a
traceability matrix (skill → workflow → status), mirroring solutions-copilot's
doc 09.

---

## 2. Scope

**In scope:** the migration methodology; per-skill decomposition into program vs
agent nodes; the migration backlog (all 45 skills, prioritized); the traceability
matrix; the LCP-authoring unlock for write-path workflows; the flagship SDLC
pipeline as a composed workflow.
**Out of scope:** platform capabilities (done in Phases 1–7).

---

## 3. Decisions applied

Q9 (trio per agent node — every migrated workflow must comply), Q12 (scaffolder +
steering + open contribution — anyone can migrate a skill), Q13 (migrate one by
one after ERD), plus the LCP-authoring unlock (open item #1 in the tracker).

---

## 4. Migration methodology (per skill)

Repeatable 8-step runbook (successor to solutions-copilot's "build-a-role"):

1. **Read the skill** — SKILL.md + all `references/`. The references ARE the
   authoritative step logic (preserve fidelity, like solutions-copilot §5.8).
2. **Decompose into steps** — list each step; classify **program** (deterministic:
   transform, parse, assemble, call CLI) vs **agent** (judgment or MCP data-access).
   *Default to program; use an agent only where genuinely needed.*
3. **Identify data flow** — what bulk artifacts move between steps → blackboard
   docs; what small decisions → state.
4. **Identify MCP/CLI** — which registry servers/CLIs each agent/cli node needs
   (`atlas`, `jarvis`, `lcp`, `data-gen`, `jira`, `erd-gen`, …).
5. **Scaffold** — `genesis create-workflow`; fill `workflow.yaml` (roles, inputs,
   required_mcp/cli, hitl_points, retry_defaults).
6. **Implement** — program nodes (port logic from references), agent nodes
   (prompts derived from the skill text, verbatim-dump-to-file + decisions-to-file
   patterns), **reliability trio on every agent node**, HITL gates where the skill
   had human checkpoints or where writes/deploys occur.
7. **Test** — unit + stubbed-graph tests; local `test-workflow`; optional live.
8. **Publish** — through library CI (reliability lint must pass); update the
   traceability matrix + `registry.json`.

**Fidelity rule:** large skill references are ported as design source, not
discarded; agent-node prompts reuse the skill's own instructions.

---

## 5. Migration backlog (all 45 skills → workflows)

Prioritized waves. (P = program-heavy/read-path = lower risk; W = write/deploy =
needs LCP/Jarvis + more gates.)

**Wave A — read-path, high value (do first after ERD):**
- documentation: `generate-erd` (✅ Phase 6), `doc-tech-design`, `doc-adr`, `doc-arch-overview`, `doc-fip`, `doc-perf-review`, `doc-security-review`.
- developer: `appian-explore`, `impact-analysis`, `code-review`, `design-document`, `knowledge-query`, `spike-research`.
- product-owner: `explore`, `feature-inventory`, `feature-spec`, `research`, `cross-app-analysis`, `feature-impact-analysis`, `release-review`, `onboarding`, `chat-triage`.
- shared: `sail-reference`, `sail-code-hygiene`, `sail-documentation-standards`, `a11y-audit`, `guide-appian-docs`.

**Wave B — UX + tester (read-path + generation):**
- ux-designer: `aurora-compliance`, `branding-compliance`, `design-consistency-review`, `edge-case-analysis`, `component-decomposition`, `platform-feasibility-check`, `create-html-prototype`, `create-sailwind-prototype`, `generate-sail`, `design-to-dev-handoff`.
- tester: `unit-test`, `test-execution`, `test-data-generation`.

**Wave C — write/deploy (needs LCP-authoring unlock + strict gates):**
- developer: `implementation` (**LCP authoring**), `implementation-summary`, `feature-breakdown`, `refactor-redeploy`, `expression-test-generation`, `i18n`, `a11y-fix`, `technical-debt`, `database-script-management`.
- devops: `pipeline-check`, `package-management`, `deployment`, `promote`.

**Wave D — composition (flagship):**
- `sdlc-pipeline` — compose (via subgraph nodes) the doc-19 flow: Jira ticket →
  gather state → **design-document** → HITL approve → **implementation** → **code-review** →
  fix loop → **deployment** (test env) → **test-execution** → **promote**. Each
  step is an already-migrated workflow embedded as a subgraph; gates at approve,
  pre-deploy, pre-promote.

### 5.1 The LCP-authoring unlock (blocker → enabler)
solutions-copilot deferred orchestration partly because "no reliable agent path
to author Appian objects." Genesis adds an `lcp` MCP server (Appian design-object
API: create record types, interfaces, process models, sites, etc.). **Validate
early** (spike within Wave A/B): can an `lcp` agent node deterministically author
+ verify an object (with a validator confirming creation via the same API)? If
yes, Wave C write-path workflows and the Wave D flagship become real end-to-end —
this is the strategic payoff of the whole program.

### 5.2 Appian-object validators land here (deferred from Phase 1)
The generic validator toolkit (`genesis_core.validators`, Phase 1) covers all
read/generation workflows. **Appian-object validators** — `record_type_exists`,
`fields_match`, `sail_compiles`, etc., which confirm a mutation by re-reading via
LCP/Atlas/Jarvis — are built **in this phase**, together with the LCP-authoring
unlock, since only write-path workflows (Wave C) need them. They extend the
toolkit under `genesis_core.validators.appian`.

---

## 6. Traceability matrix (tracked artifact)

`genesis-workflows/MIGRATION.md` (or a tracker doc): one row per skill —
`skill_id | source_refs | genesis_workflow_id | wave | status | notes`. Status ∈
`{not-started, in-progress, published, dropped(reason)}`. 100% of skills
accounted for (drops require a reason), mirroring solutions-copilot's doc-09 gate.

---

## 7. Task breakdown (program-level)

1. Write the migration runbook into `genesis-workflows/steering/` (successor to build-a-role).
2. Create `MIGRATION.md` traceability matrix seeded with all 45 skills.
3. **Spike the LCP-authoring unlock**; record findings; gate Wave C on it.
4. Execute Wave A (read-path) workflows; publish each through CI.
5. Execute Wave B.
6. Execute Wave C (post-unlock), with strict write/deploy gates.
7. Build the `sdlc-pipeline` composed workflow (Wave D).
8. Keep the matrix current; each published workflow updates `registry.json` + bundles.

---

## 8. Acceptance criteria

- [ ] Migration runbook + `MIGRATION.md` exist; all 45 skills listed with status.
- [ ] Every migrated workflow passes library CI (reliability lint) and is installable/runnable.
- [ ] Wave A complete (read-path coverage for Dev/PO/Docs/shared).
- [ ] LCP-authoring spike concluded (go/no-go recorded) before Wave C.
- [ ] Flagship `sdlc-pipeline` runs the doc-19 flow with gates at approve/pre-deploy/pre-promote, composed from migrated workflows.
- [ ] 100% of skills accounted for (published or explicitly dropped-with-reason).

---

## 9. Risks

- **Volume/effort:** 45 skills is a large body. Mitigation: open contribution
  (Q12), scaffolder + steering + agent-assisted authoring lower per-skill cost;
  prioritize by value (waves).
- **Write-path safety:** LCP/Jarvis writes are mutating. Mitigation: mandatory
  HITL gates before writes/deploys; validators confirm each authored object; never
  touch prod without explicit approval (reuse solutions-copilot safety posture).
- **Fidelity loss:** re-implementing skills risks dropping nuance. Mitigation:
  port references as design source; agent prompts reuse skill text.
- **LCP unlock uncertain:** if authoring proves unreliable, Wave C/D slip;
  read-path value (Waves A/B) still lands independently.

---

## 10. Deliverables

- Migration runbook + traceability matrix.
- Waves A–C workflows in `genesis-workflows` (CI-passing, installable).
- The composed `sdlc-pipeline` flagship workflow.
- A go/no-go record on LCP-driven Appian authoring.
