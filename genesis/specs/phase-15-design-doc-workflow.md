# Phase 15 — Appian Design-Document Workflow (Jarvis → Genesis port, dual-source research)

> **Status:** DRAFT (implementation spec) · **Author:** Genesis agent · **Date:** 2026-07-17
> **Goal:** Port the Jarvis **"Design Document Creation Workflow"** (an LLM-orchestrated Kiro steering
> doc) into a **deterministic Genesis workflow** where LangGraph owns control flow and Kiro agents are
> narrow, validated steps. The workflow turns a **JIRA ticket** into an **Appian implementation design
> document** (a **Markdown** deliverable) using **two independent research sources** — the live
> **Jarvis** environment/KB **and** the release-aware **Atlas** knowledge base — reconciled into one
> implementation plan, then (optionally) creates an empty Appian package.
> **Repos:** a small **genesis** platform change (run-launch **file upload** for the mockup — sub-phase
> 15-01) + the new **design-doc** workflow in **genesis-workflows** + a **registry.json** entry.
> `genesis-core` needs no change. **appian-atlas**, **jarvis**, **jira** are already registered in
> `mcp-registry.json`.
> **Source doc analyzed in full:**
> `…/solutions-os/ai-framework/tools/Jarvis/jarvis-power/steering/design-doc-workflow.md`.
> **User decisions (2026-07-17):**
> (1) **No Google Workspace** — the mockup is an **uploaded file** (not a Slides link) and the final
> design document is **Markdown** (not HTML/Google Doc);
> (2) **Two research steps** — a **Jarvis** research node *and* a separate **Atlas** research node;
> both research documents feed the design. Atlas is a superset of Jarvis's object/schema data **plus
> release-wise history**;
> (3) the optional steps (mockup→i18n, KB-freshness, open-questions) become **conditional edges**.

---

## 0. TL;DR

The Jarvis doc is a ~10-step design process implemented as a **prompt**, wrapped in an elaborate
"🛑 STOP / MANDATORY EXECUTION TRACKER / BLOCKING RULES / STEP SKIPPING IS FORBIDDEN" apparatus whose
**only** job is to coerce an LLM into following a deterministic process. That apparatus is the exact
anti-pattern Genesis exists to eliminate (ADR-001: agents never orchestrate). Porting it **deletes the
entire enforcement layer** and replaces prompt-willpower with runtime guarantees:

| Jarvis (prompt) | Genesis (runtime) |
|---|---|
| Execution tracker re-pasted every turn | LangGraph state + Run-Detail graph/timeline UI |
| "BLOCKING RULES: can't proceed until ✅" | Graph edges — order is structural, not requested |
| "VALIDATION CHECKPOINT: confirm you did X" | `validator_node` (code-enforced) + retry + escalate |
| "STOP! ask the user proceed/refresh" | `hitl_gate` (approval) — durable pause/resume |
| "OPTIONAL — skip if no mockup" | **conditional edge** on `mockup_file != null` |
| "build HTML → import to Google Docs" | Markdown artifact on the blackboard, shown in Documents drawer |
| "never paste tool output — write to file" | Phase-9 `save_tool_output` (by reference) |
| Manual credit awareness | Phase 11 metered credits per node + per run, free |

**Net:** the design logic stays; the ~40% of the source doc that is enforcement scaffolding evaporates.
**One genuine addition** vs. the code-review port: this workflow has a **mutation** (`create_package`),
so it carries a **`pre_mutation` HITL gate** (ADR-021); and it needs a **file-upload** capability at
launch (the mockup) — a small, additive genesis platform change (15-01).

---

## 1. Scope & non-goals

**In scope (the workflow):**
1. Entry via a **JIRA ticket** (e.g. `GAMS-7126`); optional **mockup file upload**; optional
   **`create_package`** flag.
2. Deterministic ticket parse (title, description, acceptance criteria, parent epic, project key,
   JIRA URL) + **database/SMT keyword detection**.
3. **Application resolution** from `get_jarvis_config` (match project key / prefix → `appUuid`,
   `kbFolderId`, `staleCount`, `designDocFolderId`, i18n system); HITL gate if no match.
4. **KB-freshness** conditional gate (only if `kbFolderId` exists and `staleCount > 0`).
5. **Dual-source research (the core of Phase 15):**
   - **Jarvis research** — live environment + pre-computed KB (clusters, 35 behavioral tags,
     patterns, data model, architecture, shared objects, recently-created objects, `query_sql`
     verification).
   - **Atlas research** — code intelligence over the Atlas KB **with release-wise history**
     (`list_releases`, `get_object_at_release`, `get_changelog`, `get_release_impact`,
     `compare_releases`) that Jarvis does not surface.
   - **Reconcile** both into one unified, release-aware implementation plan.
6. **Application info + naming/folder validation** (deterministic naming rules; folder assignment).
7. **Best-practices design notes** annotated onto each planned object.
8. **Open-questions** synthesis (conditional — section included only if the agent surfaces any).
9. **Internationalization** from the uploaded mockup (conditional — only if a mockup was provided):
   extract user-facing strings → i18n key/value pairs → **duplicate detection** (reuse-vs-new) →
   delta keys only.
10. **Optional package creation** (`create_package_for_ticket`) behind a **`pre_mutation` gate**.
11. **Build the Markdown design document** (`design-{TICKET}.md`) with the exact section set and
    validate its structure; surface it in the Run-Detail **Documents drawer**.

**Out of scope / non-goals:**
- ❌ Google Workspace of any kind (Slides mockup ingestion via API, Google Docs export). Replaced by
  file upload + Markdown output.
- ❌ Appian object creation/deployment (that is a separate implementation workflow). The **only**
  mutation is the empty-package creation, gated.
- ❌ Executing scripts / running SMT change requests. The workflow *documents* SMT/DDL/DML context in
  the design; it never submits changes.
- ❌ Editing the team-managed i18n bundles or checklist — it proposes keys and references standards.
- ❌ Rendering the mockup if it is a binary Office format (see R3 — v1 supports text-extractable +
  image mockups only).

---

## 2. MCP tooling inventory

Three servers, **all already registered** in `genesis-workflows/mcp-registry.json`:

| Server | Image / mode | Env (public / secret) | Registry allowlist? |
|---|---|---|---|
| `jarvis` | `…/solutions-os/jarvis:latest` · **read-write-deploy** | `APPIAN_BASE_URL` / `APPIAN_API_KEY` | **none** → per-node cap required |
| `appian-atlas` | `…/solutions-atlas-mcp-server:latest` · **read-only** | `ATLAS_KB_PROJECT_ID`, `ATLAS_DATA_PREFIX` / `GITLAB_TOKEN` | **yes** (read-only tools) |
| `jira` | `jira-mcp-proxy:latest` · integration | `JIRA_URL`, `JIRA_EMAIL` / `JIRA_TOKEN` | none (only read tool used) |

### 2.1 Jarvis tools used (names per the source doc — **verify live**, see R2)
| Tool | Used for | Read/Write |
|---|---|---|
| `get_jarvis_config` | app registry: `appUuid`, `appPrefix`, `kbFolderId`, `staleCount`, `jiraProjects`, `designDocFolderId`, `translationSets[]`, `globalSettings` | read |
| `get_application_info` | `namingConvention`, `ruleFolderDetails[]`, `lastUsedFolderFor{Const,Rule,Interface}` | read |
| `jarvis_get_app_tree` / `jarvis_search_objects` / `jarvis_get_cluster` | KB app shape, object discovery, feature clusters | read |
| `jarvis_get_patterns` / `jarvis_get_data_model` / `jarvis_get_architecture` | KB patterns, data model, layers | read |
| `jarvis_get_object_content` / `jarvis_get_shared_objects` | SAIL for modified objects, shared-object risk | read |
| `jarvis_get_impact_analysis` | pre-computed dependency/blast-radius (replaces sequential `get_object_dependencies`) | read |
| `search_objects_semantic` / `list_application_objects` | live: recently-created objects, record types | read |
| `query_sql` | **read-only** `DESCRIBE`/`SHOW INDEX`/SELECT for DB + SMT + i18n verification | read (server-side read-only) |
| `jarvis_get_translation` | i18n duplicate detection (Translation-Set apps) | read |
| `create_package_for_ticket` | **create an empty Appian package** | **WRITE → pre_mutation gate** |

> **Note on `mcp_appian_*` names in the source doc:** the doc references `mcp_appian_get_application_info`
> and `mcp_appian_create_package_for_ticket`. Against the current Genesis registry these are **jarvis**
> tools (there is no separate `appian` server). Exact names are subject to R2 (live verification).

### 2.2 Atlas tools used (from the registered read-only `tool_allowlist`)
Object/schema/dependency (Jarvis-overlapping): `list_applications`, `get_app_overview`,
`get_app_schema`, `get_schema_summary`, `get_schema_relationships`, `get_field_map`,
`get_record_type_map`, `search_objects`, `get_object_code`, `get_object_detail`, `get_dependencies`,
`get_transitive_dependencies`, `get_dependency_path`, `get_hub_objects`, `search_bundles`, `get_bundle`,
`get_reference_data`, `get_insertion_order`.
**Release-wise (the Atlas differentiator):** `get_object_history`, `get_object_at_release`,
`list_releases`, `get_changelog`, `get_release_impact`, `compare_releases`.

### 2.3 JIRA tool
`get_jira_issue(issue_key, fields?, expand?)` — read-only (confirmed live in Phase 12). Called with
`fields=[summary, description, customfield_10227 (AC), parent, project]`. Missing custom fields return
null (harmless).

### 2.4 Security — read-only by construction + one gated write (ADR-021 / ADR-029)
- **Atlas** is registry `read-only` **and** has a `tool_allowlist` → effective trust =
  `node.tools ∩ atlas_allowlist` is doubly read-only. Safe.
- **Jarvis** is `read-write-deploy` with **no** registry allowlist → effective trust = `node.tools`
  (server cap absent). Therefore **every jarvis agent node MUST declare an explicit read-only
  `tools=[@jarvis/…]` allowlist**, EXCEPT the single `create_package` node.
- **The `create_package` node** is the only node that includes a **write** tool
  (`@jarvis/create_package_for_ticket`) and it is **preceded by a `pre_mutation` HITL gate** (ADR-021,
  authoring-standard principle 7). This is the one sanctioned mutation in the workflow.
- kiro-cli matches MCP tools by the **namespaced** `@server/tool` name (10-01 finding) — build every
  allowlist with `@jarvis/<tool>` / `@appian-atlas/<tool>` / `@jira/<tool>`.

**Read-only Jarvis allowlist (research + config + i18n nodes):**
```
@jarvis/get_jarvis_config, @jarvis/get_application_info, @jarvis/jarvis_get_app_tree,
@jarvis/jarvis_search_objects, @jarvis/jarvis_get_cluster, @jarvis/jarvis_get_patterns,
@jarvis/jarvis_get_data_model, @jarvis/jarvis_get_architecture, @jarvis/jarvis_get_object_content,
@jarvis/jarvis_get_shared_objects, @jarvis/jarvis_get_impact_analysis,
@jarvis/search_objects_semantic, @jarvis/list_application_objects, @jarvis/query_sql,
@jarvis/jarvis_get_translation
```
**Write node allowlist (`create_package` only):** `@jarvis/get_jarvis_config,
@jarvis/create_package_for_ticket`.

### 2.5 Secrets to configure (user, post-build)
`jarvis`: `APPIAN_BASE_URL`, `APPIAN_API_KEY`. `jira`: `JIRA_URL`, `JIRA_EMAIL`, `JIRA_TOKEN`.
`appian-atlas`: `GITLAB_TOKEN` (secret) + `ATLAS_KB_PROJECT_ID`, `ATLAS_DATA_PREFIX` (public, already
defaulted in registry). `required_mcp: [jarvis, jira, appian-atlas]` → Genesis surfaces any missing
secret before a run (`missing_secrets`).

---

## 3. Inputs & entry

`inputs_schema` (JSON Schema; the launch form is generated from it — 07-05):
```yaml
inputs_schema:
  type: object
  properties:
    jira_ticket:    {type: string, title: "JIRA ticket", description: "e.g. GAMS-7126"}
    mockup_file:    {type: [string, "null"], default: null,
                     title: "Mockup (optional)", format: "file",
                     description: "Upload a mockup to generate i18n key suggestions"}
    create_package: {type: boolean, default: true,
                     title: "Create empty Appian package"}
  required: [jira_ticket]
```
- `format: "file"` is the new marker (15-01) that tells the launch form to render an **upload control**
  and the backend to accept a multipart attachment; the uploaded file is stored in the run blackboard
  and `mockup_file` is set to its **blackboard-relative path** (`mockup/<filename>`), or `null`.
- A program `resolve_inputs` node validates the ticket key shape and records
  `decisions.has_mockup = mockup_file is not None` and `decisions.create_package`.

---

## 4. State & blackboard model

**State (small, editable — ADR-010/018/022):** standard `PlatformState` plus keys in `decisions`:
- `decisions.ticket` — `{key, title, url, project_key, parent, acceptance_criteria, needs_smt: bool}`
- `decisions.app` — `{appUuid, appName, appPrefix, kbFolderId, staleCount, designDocFolderId,
  i18nSystem: "bnd"|"translationSet", namingConvention, ruleFolders:[{id,uuid,name}],
  lastUsedFolders:{const,rule,interface}}`
- `decisions.has_mockup`, `decisions.has_i18n`, `decisions.has_questions`, `decisions.create_package`
  (bools that drive conditional edges + the final section set)
- `decisions.package_url` — set by `create_package` (or null)
- `decisions.naming_warnings` — list of object names that violate the convention
- `retries`, `telemetry` (Phase-11 credits) — standard

**Blackboard artifacts (`RunWorkspace`; bulk lives here, never in state/chat):**
| Doc | Written by | Content |
|---|---|---|
| `mockup/<filename>` | launch upload (15-01) | the raw mockup the user attached |
| `jira.json` | `fetch_ticket` (by ref) | raw JIRA issue |
| `jarvis_config.json` | `fetch_config` (by ref) | `get_jarvis_config` output |
| `app_info.json` | `fetch_app_info` (by ref) | `get_application_info` output |
| `research_jarvis.md` | `research_jarvis` | live + KB findings (objects, clusters, patterns, data model, SQL) |
| `research_atlas.md` | `research_atlas` | Atlas findings **incl. release history / impact** |
| `plan.md` | `reconcile` | unified, release-aware implementation plan (per-object CREATE/UPDATE) |
| `plan_annotated.md` | `design_notes` | `plan.md` + best-practice design notes + folders |
| `i18n.json` | `extract_i18n` (conditional) | `{system, target, keys:[{key,value,prefix,status:"NEW"\|"REUSE",existing_ref?}]}` |
| `questions.md` | `open_questions` | 0–7 tagged open questions (may be empty) |
| `package.json` | `create_package` (conditional) | package-creation result + URL |
| `design-{TICKET}.md` | `build_design` | **the deliverable** (see §9 template) |

Large tool outputs (a 3000-line SAIL object, a full data-model dump, a changelog) are persisted **by
reference** via the Phase-9 blackboard MCP (`save_tool_output`) so they never re-enter the context
window — the deterministic replacement for the doc's "write to a file, don't paste output".

---

## 5. Node graph (topology)

```
START ─▶ resolve_inputs(prog)
      ─▶ fetch_ticket(agent,jira) ─▶ v_ticket ─▶ parse_ticket(prog: fields, URL, needs_smt)
      ─▶ fetch_config(agent,jarvis) ─▶ v_config ─▶ match_app(prog)
             ├─ (no match) ─▶ app_gate(gate,approval: pick app) ─▶ match_app
             └─ (match) ─▶ freshness(prog: staleCount)
                              ├─ (kbFolderId && stale>0) ─▶ freshness_gate(approval: proceed|refresh)
                              │        ├─ refresh ─▶ present_deferred(prog) ─▶ END
                              │        └─ proceed ─▶ research_jarvis
                              └─ (fresh / no KB)      ─▶ research_jarvis
      ─▶ research_jarvis(agent,jarvis[RO]) ─▶ v_rjarvis
      ─▶ research_atlas(agent,atlas[RO])   ─▶ v_ratlas
      ─▶ reconcile(agent) ─▶ v_plan
      ─▶ fetch_app_info(agent,jarvis[RO]) ─▶ v_appinfo ─▶ validate_naming(prog)
      ─▶ design_notes(agent) ─▶ v_notes
      ─▶ open_questions(agent) ─▶ v_questions              (always runs; may be empty)
      ─▶ i18n_branch?(prog router)
             ├─ (has_mockup) ─▶ extract_i18n(agent,jarvis[RO]+fs read) ─▶ v_i18n ─▶ pkg_branch
             └─ (no mockup)                                                     ─▶ pkg_branch
      ─▶ pkg_branch?(prog router)
             ├─ (create_package) ─▶ pre_mutation_gate(gate,pre_mutation)
             │        └─ approve ─▶ create_package(agent,jarvis[write]) ─▶ v_package ─▶ build_design
             └─ (skip)                                                         ─▶ build_design
      ─▶ build_design(agent) ─▶ v_design ─▶ present(prog) ─▶ END
```

**Node kinds:** program = `resolve_inputs, parse_ticket, match_app, freshness, validate_naming,
i18n_branch, pkg_branch, present, present_deferred`; agent (`kiro_node`) = `fetch_ticket, fetch_config,
research_jarvis, research_atlas, reconcile, fetch_app_info, design_notes, open_questions, extract_i18n,
create_package, build_design`; validator = `v_ticket, v_config, v_rjarvis, v_ratlas, v_plan, v_appinfo,
v_notes, v_questions, v_i18n, v_package, v_design`; gate = `app_gate (approval), freshness_gate
(approval), pre_mutation_gate (pre_mutation)`, plus a shared `escalate (escalation)` reached when any
agent node exhausts retries.

Every agent node is wrapped by `attach_reliability(validator + retry + escalation)` — CI-enforced by
`genesis/lint/reliability.py`. The `graph:` block in `workflow.yaml` mirrors this exactly (node ids ==
LangGraph node names) so the Run-Detail graph renders it.

**Linear, not looping.** Unlike code-review, this workflow does **not** loop over N objects, so the
`recursion_limit` concern (Phase 12-01) does **not** apply — one small platform change (15-01, file
upload) is the only genesis-side dependency.

---

## 6. Per-node specification (detailed)

Node factories (from `genesis_core`, signatures confirmed): `program_node(name, fn)`,
`kiro_node(name, prompt_fn, output_doc, mcp=[], tools=None, model=None, turn_timeout, startup_timeout,
blackboard=True)`, `validator_node(name, check_fn, target_artifact=None)`, `hitl_gate(name, kind,
prompt_fn, options=None)`, `attach_reliability(g, agent, validator, retry_max, on_exhaust_gate, nxt)`.
`check_fn(data, state, ctx) -> ValidationResult(ok, message, normalized?)`. Validators are composed
from `genesis_core.validators` (`non_empty, parses_json, json_schema, required_keys, values_in_set,
count_between, matches_predicate, all_of, any_of, …`).

### 6.1 `resolve_inputs` (program)
Validate `jira_ticket` matches `^[A-Z][A-Z0-9]+-\d+$`. Set `decisions.has_mockup`,
`decisions.create_package`. No I/O. Fails fast on a malformed ticket key.

### 6.2 `fetch_ticket` (agent · mcp=[jira] · tools=[@jira/get_jira_issue])
Prompt: call `get_jira_issue(issue_key={jira_ticket}, fields=[summary, description, customfield_10227,
parent, project])`, `save_tool_output(ref, document="jira.json")`, reply `DONE`.
**`v_ticket`** = `all_of([parses_json("jira.json"), required_keys(["fields"], "jira.json"),
matches_predicate(lambda d: bool(_dig(d,"fields.summary")), "jira.json", "ticket has no summary")])`.

### 6.3 `parse_ticket` (program) — pure logic on `jira.json`
- `title = fields.summary`; `description = fields.description`; `acceptance_criteria =
  fields.customfield_10227`; `parent = fields.parent.fields.summary`; `project_key =
  fields.project.key`.
- `url = https://appian-eng.atlassian.net/browse/{TICKET}`.
- **`needs_smt`** = true if any of `{script, insert, table, database, migration, template data,
  reference data, seed data, SQL, DDL, DML, schema}` (case-insensitive) appears in description or AC
  (drives the SMT research emphasis in §6.7/6.8). Store all under `decisions.ticket`.

### 6.4 `fetch_config` (agent · mcp=[jarvis] · tools=[@jarvis/get_jarvis_config])
Call `get_jarvis_config`, `save_tool_output(ref, "jarvis_config.json")`, `DONE`.
**`v_config`** = `all_of([parses_json, non_empty])` on `jarvis_config.json` (expects an
`applications[]` array).

### 6.5 `match_app` (program) — deterministic app resolution
On `jarvis_config.json`: match `decisions.ticket.project_key` against each application's `jiraProjects`;
tie-break/augment by matching parent-epic text and description against `appPrefix`/`appName`. On match,
populate `decisions.app` (`appUuid, appName, appPrefix, kbFolderId, staleCount, designDocFolderId`,
i18n system inferred: `translationSets[]` populated → `"translationSet"`, else `"bnd"`). **No match →**
route to `app_gate`.

### 6.6 `app_gate` (gate · approval) — only when no app matched
`hitl_gate` presenting the candidate applications from config; the human picks one → its identifiers
are written into `decisions.app` and control returns to the `freshness` check. (One of the 3 sanctioned
pause classes — a genuine human decision, not over-gating.)

### 6.6b `freshness` (program) + `freshness_gate` (gate · approval) — conditional
`freshness` reads `decisions.app.kbFolderId` + `staleCount`:
- `kbFolderId` falsy → no KB → route straight to `research_jarvis` (Atlas + live still run).
- `kbFolderId` set and `staleCount == 0` → route to `research_jarvis`.
- `kbFolderId` set and `staleCount > 0` → route to **`freshness_gate`** (options `[proceed,
  refresh_first]`). `proceed` → `research_jarvis`; `refresh_first` → `present_deferred` (a program node
  that writes a short "run deferred — KB refresh requested for {app}, {staleCount} stale objects" note
  and ends). Mirrors the doc's Step 2.5 exactly, as a durable gate instead of a prompt "STOP".

### 6.7 `research_jarvis` (agent · mcp=[jarvis] · tools=<read-only allowlist §2.4>)
Extract 2–3 keywords from `decisions.ticket`. Then (KB tools only if `kbFolderId` exists):
`jarvis_get_app_tree`, `jarvis_search_objects`, `jarvis_get_cluster` (top cluster), `jarvis_get_patterns`,
`jarvis_get_data_model`, `jarvis_get_architecture`, `jarvis_get_object_content` (top 2–3 modified),
`jarvis_get_shared_objects`, `jarvis_get_impact_analysis`; **live:** `search_objects_semantic`,
`list_application_objects` (recent/undeployed objects the KB snapshot misses); **`query_sql`** for DB
verification when `needs_smt` or the plan touches tables (`DESCRIBE`, `SHOW INDEX`, SMT-app lookup).
Writes a structured `research_jarvis.md`: **Relevant objects** (name/uuid/type/tags/complexity),
**Feature cluster**, **Patterns to follow**, **Data-model position**, **Architecture layer**,
**Shared-object risk flags**, **Recently-created (not in KB)**, **DB/SMT verification**. Save large tool
outputs by reference; put only the distilled findings in the doc. Reply `DONE`.
**`v_rjarvis`** = `matches_predicate` asserting `research_jarvis.md` is non-empty and contains the
`Relevant objects` + `Data-model` headings (structure/coverage check, not semantic correctness).

### 6.8 `research_atlas` (agent · mcp=[appian-atlas] · tools=<atlas read-only allowlist>)
Same keywords, over the **Atlas** KB — and specifically the **release-aware** layer Jarvis lacks:
`list_applications`/`get_app_overview` (locate app), `search_objects`, `get_object_detail`/
`get_object_code` (top objects), `get_dependencies`/`get_transitive_dependencies`/`get_dependency_path`
(blast radius), `get_app_schema`/`get_schema_relationships`/`get_field_map`/`get_record_type_map`
(data model), and the **release tools**: `list_releases`, `get_object_history`, `get_object_at_release`,
`get_changelog`, `get_release_impact`, `compare_releases`. Writes `research_atlas.md` with the same
object/data-model structure **plus** a mandatory **## Release Context** section: for each key object —
when it was introduced/last changed, which release, what `get_release_impact`/`compare_releases`
reveal about recent churn, and any cross-release risk. Save bulk by reference; `DONE`.
**`v_ratlas`** = `matches_predicate` asserting `research_atlas.md` is non-empty and contains a
`## Release Context` section (the Atlas-specific value must be present — this is *why* we run two
sources).

### 6.9 `reconcile` (agent · mcp=[] · no tools) — merge both sources → the plan
Reads `research_jarvis.md` **and** `research_atlas.md` from the blackboard and produces `plan.md`, a
**unified, release-aware implementation plan**. Rules embedded in the prompt:
- **Jarvis is primary for live/KB intelligence** (clusters, tags, patterns, recently-created objects,
  live DB state); **Atlas is authoritative for release history/impact** and fills any object Jarvis
  missed.
- Deduplicate objects appearing in both by name/UUID; prefer Jarvis's live description, annotate with
  Atlas's release context.
- Emit, per object, the **mandatory implementation-plan format** (ported from the doc):
  1. **`CREATE/UPDATE — {Object Name}`**
  2. **Description** — 1–2 sentences, copy-paste-ready for the Appian object description field
     (object's perspective; not "created for GAMS-x").
  3. **What to build** — actionable bullets (behaviour/logic/structure).
  4. **Release context** — one line from Atlas (e.g. "modifies behaviour introduced in R2024.2; last
     changed R2025.1").
- Also carry forward **Test cases** derived from the acceptance criteria and any **DB/SMT** notes.
Reply `DONE`. **`v_plan`** = `matches_predicate` asserting `plan.md` has ≥1 `CREATE/UPDATE —` header
and every such block contains a **Description** + **What to build** (structure/coverage).

### 6.10 `fetch_app_info` (agent · mcp=[jarvis] · tools=[@jarvis/get_application_info])
Call `get_application_info(appUuid)`, `save_tool_output(ref, "app_info.json")`, `DONE`.
**`v_appinfo`** = `all_of([parses_json, required_keys(["namingConvention"], "app_info.json")])`.

### 6.11 `validate_naming` (program) — deterministic naming/folder rules
On `app_info.json` + `plan.md`: for each object name in the plan, assert it starts with
`"{namingConvention} "` **or** `"{namingConvention}_"`; collect violators into
`decisions.naming_warnings` (warn, do not hard-fail — the plan is still useful and the human can fix).
Assign each object a **folder** by type from `lastUsedFolderFor{Const,Rule,Interface}` /
`ruleFolderDetails[]`, and store the folder name/uuid alongside each object for the design doc. (Pure
logic — this is the doc's Step 3.75 validation, far more reliable as code.)

### 6.12 `design_notes` (agent · mcp=[] · no tools) — best-practices annotation
Reads `plan.md` + the ported **best-practices checklist** (a reference file shipped in the workflow's
`prompts/` — see §10) and appends, per object, a **Design Notes** subsection referencing the relevant
standards (e.g. "Use `AS_CO_UT_queryEntity()` per §5.C", "extract validation to a VD rule per §6.C",
naming per §1.F). Writes `plan_annotated.md` (plan + folders from 6.11 + design notes). `DONE`.
**`v_notes`** = `matches_predicate` asserting each `CREATE/UPDATE —` block in `plan_annotated.md` has a
**Design Notes** subsection.

### 6.13 `open_questions` (agent · mcp=[] · no tools) — always runs, may be empty
Pure reasoning over all gathered artifacts (`jira.json`, both research docs, `plan_annotated.md`).
Synthesizes **0–7** open questions that need human judgment, each tagged `[Edge Case]`/`[Assumption]`/
`[Scope]`/`[Security]`/`[Data Model]`/`[Cross-Feature]`. If the ticket is straightforward, it writes an
**empty** `questions.md` (a single line "No open questions."). Sets `decisions.has_questions =
(count>0)`. `DONE`. **`v_questions`** = `matches_predicate` asserting `questions.md` exists and, if
non-empty, every line is tagged and there are ≤7 questions.

> **Conditional-edge note:** the doc frames open-questions as "skip if straightforward". Because
> "straightforward" is a judgment, we **always run the node** and let it emit an empty result; the
> *section* is then included in the deliverable **only if** `decisions.has_questions` (a conditional in
> `build_design` + `v_design`). This keeps the graph deterministic while honouring the optionality.

### 6.14 `i18n_branch` (program router) + `extract_i18n` (agent) — conditional on mockup
`i18n_branch` routes to `extract_i18n` iff `decisions.has_mockup`, else to `pkg_branch`.
**`extract_i18n`** (agent · mcp=[jarvis] · tools=`[@jarvis/query_sql, @jarvis/jarvis_get_translation,
@jarvis/get_jarvis_config]` + fs read of the mockup):
1. Read the mockup from `mockup/<filename>` in the workspace (`cwd`). Extract **all user-facing
   strings** (labels, buttons, validation messages, placeholders, accessibility text, status text,
   tooltips).
2. Generate i18n key/value pairs with prefix conventions (`lbl_`, `vld_`, `plc_`, `acs_`, `txt_`),
   camelCase after the prefix, `=` separator, `[%1]` for dynamic args.
3. **Duplicate detection:** for **BND apps** run one batched `query_sql` (the `BND_Key`/`BND_Bundle`
   join with an `IN (...)` of the labels, `LIMIT 30`); for **Translation-Set apps** call
   `jarvis_get_translation(parentFolderId, query=label)` per unique label. Mark each key `REUSE`
   (with the existing ref) or `NEW`.
4. Write `i18n.json` = `{system, target, keys:[{key,value,prefix,status,existing_ref?}]}`. Set
   `decisions.has_i18n = any(status=="NEW")`. `DONE`.
**`v_i18n`** = `all_of([parses_json, required_keys(["system","keys"], "i18n.json"),
values_in_set("keys[].status", {"NEW","REUSE"}, "i18n.json")])`.

### 6.15 `pkg_branch` (program router) + `pre_mutation_gate` + `create_package` — conditional + gated
`pkg_branch` routes to `pre_mutation_gate` iff `decisions.create_package`, else to `build_design`.
**`pre_mutation_gate`** (gate · **pre_mutation**, ADR-021) presents "Create empty Appian package
'{TICKET} {TITLE}' in {appName}?" → approve/decline. Decline → `build_design` (deployment section notes
"no package created"). Approve → **`create_package`** (agent · mcp=[jarvis] · tools=`[@jarvis/get_jarvis_config,
@jarvis/create_package_for_ticket]`): call `create_package_for_ticket(appUuid, packageName="{TICKET}
{TITLE}")`, `save_tool_output(ref, "package.json")`, set `decisions.package_url`, `DONE`.
**`v_package`** = `matches_predicate` asserting `package.json` yields a non-empty package URL.

### 6.16 `build_design` (agent · mcp=[] · no tools) — author the Markdown deliverable
Reads `plan_annotated.md`, `i18n.json` (if `has_i18n`), `questions.md` (if `has_questions`),
`decisions.package_url`, `decisions.ticket`. Writes `design-{TICKET}.md` following the **exact**
template in §9 — the section set is data-driven:
- Always: **Overview**, **Implementation Plan**, **Test Cases**, **Deployment**.
- **Internationalization** — included **iff** `decisions.has_i18n` (delta/NEW keys only).
- **Open Questions** — included **iff** `decisions.has_questions`.
Reply `DONE`. (The agent authors prose/structure; the program validator enforces the shape.)

### 6.17 `v_design` (validator · target = `design-{TICKET}.md`) — the structure "checkpoint"
Program-enforced (the deterministic replacement for the doc's Step 4.5/5 checklists):
- Title is a level-1 header with a JIRA hyperlink `[{TICKET}: …]({url})`.
- **Exact section set** present and **in order**, matching the flags: `## Overview`,
  `## Implementation Plan`, `## Internationalization` (iff `has_i18n`), `## Open Questions` (iff
  `has_questions`), `## Test Cases`, `## Deployment`. **No forbidden sections** (Executive Summary,
  Requirements, Risk Assessment, Success Criteria, References, Appendix, Configuration Management).
- Implementation Plan has, per object, a **Description** + **What to build** (no "References" line).
- Internationalization (if present) lists **only NEW** keys, grouped by prefix.
- Test Cases is a numbered list; Deployment shows the package URL (or the "no package created" note).
- All object names satisfy the naming convention (reuses the 6.11 rule).
Fail → `attach_reliability` retries `build_design` with the message; exhaust → `escalate`.

### 6.18 `present` (program)
Set `design-{TICKET}.md` status Complete; record `decisions.design_doc` pointer. The Markdown artifact
renders in the Run-Detail **Documents drawer** (existing markdown renderer) — no chat dump.

---

## 7. Determinism strategy (the ADR-001 split)

- **All MCP interaction lives in agent (`kiro_node`) nodes** (program nodes can't run Kiro turns);
  agents fetch raw data and `save_tool_output(...)` **by reference** to the blackboard.
- **All deterministic logic lives in program nodes** over those artifacts: ticket parse + SMT-keyword
  detection, app matching, KB-freshness routing, naming/folder validation, section-set routing, and
  the design-doc structure check. This is exactly where the Jarvis doc's fragile "follow these steps
  in order / show the tracker" becomes **structural**.
- **Genuine judgment stays in agents**: the two research syntheses, the reconciliation into a plan,
  design-note annotation, open-question synthesis, i18n extraction, and the Markdown authoring — each
  wrapped by a validator that checks **structure and coverage**, not semantic correctness (the right
  boundary; validators never rubber-stamp and never over-reach into "is this finding correct").
- **Two research sources, one plan:** running Jarvis and Atlas as **separate, independently-validated**
  agent nodes (rather than one mega-prompt) keeps each node narrow and lets `reconcile` apply an
  explicit merge rule (Jarvis=live/KB primary, Atlas=release-history authority). This is the
  program-bounded-LLM thesis applied to research.

---

## 8. Platform dependency — run-launch file upload (sub-phase 15-01, genesis)

The mockup is the one input that isn't JSON. Minimal, additive design:
- **`inputs_schema`** may mark a string property `format: "file"`. The launch form (07-05) renders an
  **upload control** for such properties (reuse the Phase-14 `FileDropList` + `client.postForm`
  multipart plumbing).
- **`POST /api/runs`** accepts an optional **multipart** body (`inputs` JSON part + file parts keyed by
  the property name). The `RunManager`/worker start path writes each uploaded file into the new run's
  `RunWorkspace` under `mockup/<sanitized-filename>` **before** the graph starts, and rewrites the
  corresponding input to the **blackboard-relative path**. If no file is attached, the input stays
  `null`.
- Size/type guard: cap size (e.g. 10 MB), sanitize the filename (path-traversal-safe), and restrict to
  an allowlist of extensions (v1: `.txt, .md, .html, .csv, .png, .jpg, .jpeg`; see R3). Reject others
  with a clear error at launch.
- **Proposed ADR-035** — "Run input file attachments": runs may accept bounded, sanitized input files
  provisioned into the blackboard at launch; they are read-only inputs, never executed. (Refines the
  blackboard model; does not touch ADR-012 subprocess isolation — the worker just reads a file already
  in its workspace.)

This is the **only** genesis-side change. Everything else is genesis-workflows. If 15-01 slips, the
workflow still ships **without** the mockup branch (i18n simply omitted) — the branch is conditional.

---

## 9. The Markdown deliverable (`design-{TICKET}.md`) — exact template

````markdown
# [{TICKET_KEY}: {TITLE}]({JIRA_URL})

## Overview
{Brief overview of the implementation — 2–4 sentences.}

## Implementation Plan

### CREATE/UPDATE — {Object Name}
_{1–2 sentence description, copy-paste ready for the Appian object description field.}_

**What to build:**
- {actionable detail}
- {actionable detail}

**Design Notes:** {best-practice references, e.g. "Use AS_CO_UT_queryEntity() per §5.C"}
**Folder:** {folder name} · **Release context:** {from Atlas, e.g. "new object; nearest pattern last changed R2025.1"}

---
{repeat per object}

## Internationalization
<!-- included ONLY if a mockup was provided AND there are NEW keys -->
**System:** {BND Bundles | Appian Translation Sets} — **Target:** {bundle/translation-set name}

**Labels (lbl_)**
```
lbl_vendorName=Vendor Name
```
**Validation (vld_)**
```
vld_requiredField=[%1] requires a value
```
{…other prefixes; NEW keys only — REUSE keys are excluded}

## Open Questions
<!-- included ONLY if the agent surfaced questions -->
1. **[Assumption]** {question}
2. **[Data Model]** {question}

## Test Cases
1. Verify that {expected behaviour}.
2. Verify that {expected behaviour}.

## Deployment
Package: [{PACKAGE_URL}]({PACKAGE_URL})
<!-- or: "No package created (create_package = false)." -->
````

**Section-count rule (enforced by `v_design`):** base **4** (Overview, Implementation Plan, Test Cases,
Deployment) **+1** if Internationalization **+1** if Open Questions → **4–6** sections. No others.

---

## 10. Packaging & files (genesis-workflows)

```
workflows/design-doc/
  __init__.py
  graph.py             # META + build(ctx) + pure functions + prompt builders + validators
  workflow.yaml        # mirrors META + the graph: topology block (parity lint)
  README.md
  prompts/
    __init__.py
    best_practices.md  # ported .kiro/steering/appian-best-practices-checklist.md (design_notes ref)
  tests/test_workflow.py
```
- **`registry.json`**: add a `design-doc` entry — `path: workflows/design-doc`,
  `required_mcp: [jarvis, jira, appian-atlas]`, `required_cli: []`, roles `[developer, designer]`.
- **`mcp-registry.json`**: **no change** — all three servers already registered; jarvis stays without a
  registry allowlist (read-only cap is per-node; the one write is gated).
- **`META`** keys: `id: design-doc`, `name: "Appian Design Document"`, `version`, `roles`, `summary`,
  `inputs_schema` (§3), `required_mcp: [jarvis, jira, appian-atlas]`, `required_cli: []`,
  `hitl_points: [app_gate, freshness_gate, pre_mutation_gate, escalate]`, `auto_approve: true`,
  `retry_defaults: {max: 2}`,
  `artifacts: [jira.json, jarvis_config.json, app_info.json, research_jarvis.md, research_atlas.md,
  plan.md, plan_annotated.md, i18n.json, questions.md, package.json, design-{TICKET}.md]`,
  `editable: [inputs, decisions]`. **No `execution.recursion_limit`** (linear workflow).
- `graph.py` must NOT use `from __future__ import annotations` **if** the state adds reducer keys
  (the standalone-loader `Annotated` lesson, §7 of the bible). This workflow's extra state lives under
  `decisions` (no new reducer keys), so it is not affected — but keep the caution if that changes.
- Ship `graph.py` self-contained (loader imports it standalone; no sibling-package imports).

---

## 11. Testing strategy

- **Pure functions (no Kiro):** `parse_ticket` (fields + URL + `needs_smt` keyword detection, all
  branches), `match_app` (project-key + prefix match, no-match → gate), `freshness` routing (no KB / 0
  stale / >0 stale), `validate_naming` (valid / invalid names, folder assignment), the section-count /
  ordering logic used by `v_design`, and the `i18n_branch`/`pkg_branch` routers.
- **Validators:** feed synthetic artifacts to every `v_*` — good and each failure mode (e.g. `v_design`:
  missing section, forbidden section, wrong order, missing Description, non-delta i18n key; `v_i18n`:
  bad status enum; `v_ratlas`: missing `## Release Context`; `v_plan`: block with no Description).
- **Graph wiring (stubbed Kiro via `set_collect_impl`):** inject canned tool outputs + canned agent
  docs; run end-to-end and assert (a) the deliverable has the right sections for each flag combination
  — {no mockup / mockup}, {questions / none}, {create_package on / off}; (b) `app_gate` fires on no
  match; (c) `freshness_gate` fires only when `kbFolderId && stale>0` and `refresh_first` ends the run;
  (d) `pre_mutation_gate` precedes `create_package` and decline skips it; (e) the reliability trio
  retries then escalates on a forced validator failure; (f) **both** research docs are produced and
  `reconcile` consumes both.
- **15-01 platform:** unit-test the multipart run-launch (file stored in blackboard, input rewritten to
  the path, size/type rejection, no-file → null); a web test for the file-input launch control.
- **CI:** `genesis-workflows/ci/validate_library.py` 7-gate publish runner + genesis contract-parity +
  reliability lints (every agent node has a validator + retry + escalation edge).
- **Live (manual, post-secrets):** run against a real GAMS ticket with jarvis + jira + atlas creds;
  confirm the two research docs, the reconciled release-aware plan, naming validation, the gated
  package creation, the conditional i18n/questions sections, and metered credits per node.

---

## 12. Sub-phase plan (recommended sequencing)

- **15-01 — Platform: run-launch file upload (genesis).** `format:"file"` inputs, multipart
  `POST /api/runs`, blackboard provisioning, size/type guard, ADR-035, launch-form upload control.
  Small + additive. **Blocks only the mockup/i18n branch** (rest of the workflow is independent).
- **15-02 — MVP workflow (genesis-workflows):** `resolve_inputs → fetch_ticket → parse_ticket →
  fetch_config → match_app (+app_gate) → freshness (+gate) → research_jarvis → research_atlas →
  reconcile → fetch_app_info → validate_naming → design_notes → build_design (no i18n, no questions,
  no package) → present`. Delivers the **core dual-source, release-aware Markdown design doc**.
- **15-03 — Open-questions branch** (`open_questions` + `v_questions` + conditional section).
- **15-04 — Package creation** (`pkg_branch` + `pre_mutation_gate` + `create_package` + `v_package` +
  Deployment section wiring).
- **15-05 — Mockup i18n branch** (depends on 15-01): `i18n_branch` + `extract_i18n` (+ duplicate
  detection) + `v_i18n` + Internationalization section.
- **15-06 — Safety / lifecycle / release:** registry entry, README, ported best-practices reference,
  CI green, ADR-035 → Accepted, docs (tracker/progress/bible) updated, tag/publish.

Rationale: 15-02 delivers the headline value (two-source research → one design doc) with no platform
dependency; the optional branches and the single mutation layer on incrementally so we never block the
whole workflow on one credentialed dependency or the 15-01 upload work.

---

## 13. Risks & open questions

- **R1 — Two research sources may overlap/conflict.** Jarvis and Atlas cover much of the same object
  data. Mitigation: `reconcile`'s explicit merge rule (Jarvis primary for live/KB, Atlas authoritative
  for release history) + dedup by name/UUID; `v_ratlas` forces the Atlas-unique **Release Context** to
  exist so the second source earns its place. **Confirm** with the user that both sources are wanted
  even where they overlap (the release-history delta is the justification).
- **R2 — Exact Jarvis/Atlas tool names/schemas need live verification.** The source doc mixes
  `mcp_appian_*` / `mcp_jarvis_*` names; some (`get_application_info`, `create_package_for_ticket`) are
  jarvis tools here. Cannot be driven headlessly — build against the doc's names, verify at first live
  run, adjust allowlists. (Same posture as Phase 12 R5, which resolved cleanly.)
- **R3 — Mockup format / multimodal.** kiro-cli reading an **image** mockup depends on ACP multimodal
  support (unverified). v1 supports text-extractable formats (`.md/.txt/.html/.csv`) reliably and
  attempts images if supported; **binary Office formats (.pptx/.pdf) are out of scope for v1** (would
  need a CLI pre-extraction node, e.g. `pdftotext`, added later). Flag to the user.
- **R4 — Validators check structure/coverage, not correctness.** The quality of the design (whether the
  plan is *right*) is the agent's judgment; validators enforce the shape, naming, section set, and
  presence of release context. Align expectations.
- **R5 — `create_package` is a real mutation.** Guarded by the `pre_mutation` gate + a per-node
  allowlist that contains exactly one write tool. Declining the gate still yields a complete design doc.
- **R6 — Custom JIRA field ids** (`customfield_10227` for AC, package-url field) vary per instance;
  requested by name, null if absent (harmless), surfaced as "AC not found" in the doc.
- **Q1 — Sequential vs parallel research.** v1 runs `research_jarvis` then `research_atlas`
  **sequentially** (simplest, matches the single-thread worker). A future optimization could fan them
  out in parallel and join at `reconcile`. Confirm sequential is acceptable for v1 (it is, for
  correctness; only latency differs).
- **Q2 — Keep package creation in-scope?** Included with a gate + skip flag. Confirm it should ship in
  v1 (15-04) or be deferred.

---

## 14. Acceptance criteria
1. `genesis install` picks up `design-doc`; Catalog shows it; launch validates `required_mcp`
   (jarvis, jira, appian-atlas) secrets and renders the mockup **file-upload** control (15-01).
2. A run from a JIRA ticket produces **two** research artifacts (`research_jarvis.md`,
   `research_atlas.md`, the latter with a **Release Context** section) reconciled into a single
   `plan.md`, and a final **`design-{TICKET}.md`** whose section set exactly matches the flags
   (4–6 sections, correct order, no forbidden sections), validated by `v_design`.
3. Naming/folder validation runs as **program** logic; violations are surfaced, not silently accepted.
4. The **mockup branch** is conditional: with a mockup, an Internationalization section with **delta
   (NEW) keys only** appears; without one, it is omitted. The **open-questions** section appears only
   when questions exist.
5. The **only** mutation (`create_package`) is preceded by a **`pre_mutation` gate**; declining yields
   a complete doc with "no package created"; the workflow is otherwise **incapable of mutating Appian**
   (per-node read-only allowlists; Atlas doubly read-only).
6. Every agent node is validator-gated with retry + escalation (reliability lint green); a forced
   validator failure retries then escalates to a HITL gate.
7. Per-node + per-run **credit usage** is visible (Phase 11).
8. All gates green: genesis-workflows CI 7-gate + contract-parity + reliability lints; workflow unit
   tests; the 15-01 genesis platform patch with its own tests; ADR-035 recorded.

---

## 15. Out of scope / future
- Google Workspace (Slides ingestion, Docs export) — permanently replaced by upload + Markdown.
- Binary Office mockup formats (.pptx/.pdf) — needs a CLI pre-extraction node (future).
- Parallel research fan-out (Q1) — latency optimization; revisit after v1.
- Appian object creation/deployment — the separate implementation workflow.
- A "deterministic MCP-call program node" (direct stdio client) to move fetches out of agents — noted
  in Phase 12 §7; revisit if agent tool-sequencing proves unreliable.

---

## 16. Mapping — source doc step → Genesis node(s)

| Jarvis doc step | Genesis node(s) | Kind |
|---|---|---|
| STOP / tracker / blocking rules | *(deleted — LangGraph enforces order)* | — |
| Step 1 Get JIRA ticket | `fetch_ticket` + `parse_ticket` | agent + program |
| Step 1.5 Mockup i18n (optional) | `i18n_branch` → `extract_i18n` (conditional) | program + agent |
| Step 2 Determine application | `fetch_config` + `match_app` (+`app_gate`) | agent + program + gate |
| Step 2.5 KB freshness check | `freshness` (+`freshness_gate`) | program + gate |
| Step 3 Research (KB + live) | `research_jarvis` **+ `research_atlas`** | 2 agents |
| Step 3.25 Consolidate & reconcile | `reconcile` | agent |
| Step 3.75 Application info + naming | `fetch_app_info` + `validate_naming` | agent + program |
| Step 3.8 Best-practices review | `design_notes` | agent |
| Step 3.9 Open questions (optional) | `open_questions` (conditional section) | agent |
| Step 4 Create package | `pkg_branch` → `pre_mutation_gate` → `create_package` | program + gate + agent |
| Step 4.5 Validate HTML structure | `v_design` (structure validator, now Markdown) | validator |
| Step 5 Build document (+ export) | `build_design` (Markdown; no Google export) + `present` | agent + program |
