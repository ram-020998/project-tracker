# Phase 12 — Appian Code-Review Workflow (Jarvis → Genesis port)

> **Status:** DRAFT (implementation spec) · **Author:** Genesis agent · **Date:** 2026-07-14
> **Goal:** Port the Jarvis "Code Review Workflow" (an LLM-orchestrated Kiro steering doc) into a
> **deterministic Genesis workflow** where LangGraph owns control flow and Kiro agents are narrow,
> validated steps. **Google Docs export is OUT of scope** (per request).
> **Repos:** primarily **genesis-workflows** (new `code-review` workflow) + a small **genesis**
> engine change (loop recursion limit) + an **mcp-registry** allowlist edit. `genesis-core` needs no
> change. **Secrets** for `jarvis` + `jira` will be configured by the user after the workflow is built.
> **Source:** `…/Jarvis/jarvis-power/steering/code-review-workflow.md` (analyzed in full).

---

## 0. TL;DR

The Jarvis doc is a 6-step Appian code-review process implemented as a **prompt** — with an elaborate
"execution tracker / BLOCKING RULES / 🛑 STOP" apparatus whose only job is to coerce an LLM into
following a deterministic process reliably. That apparatus is a symptom of the exact anti-pattern
Genesis exists to eliminate (ADR-001: agents never orchestrate). Porting it to Genesis **deletes the
entire enforcement layer** and replaces prompt-willpower with runtime guarantees:

| Jarvis (prompt) | Genesis (runtime) |
|---|---|
| Execution tracker re-pasted every turn | LangGraph state + Run-Detail graph/timeline UI |
| "BLOCKING RULES: can't proceed until ✅" | Graph edges (order is structural, not requested) |
| "PRE-WRITE CHECKPOINT: did you run analyze?" | `validator_node` (code-enforced), retry, escalate |
| "process one object at a time, write to file" | LangGraph loop + blackboard (`RunWorkspace`) |
| "a new agent can resume from the file" | Checkpointer (ADR-012): pause=kill, resume=fresh worker |
| "500–3000 line PM overflows context" | Phase 9 artifact I/O (`save_tool_output` by reference) |
| Manual credit awareness | Phase 11 metered credits per node + per run, free |

**Net:** the review logic stays; ~40% of the source doc (enforcement scaffolding) evaporates.

---

## 1. Scope & non-goals

**In scope (the workflow):**
1. Entry via **JIRA ticket** (Path A), **package URL** (Path B), or **object name(s)** (Path C).
2. Reference-date + per-object baseline-version resolution for diff-aware review.
3. Package contents → filter → deterministic sort (light→heavy) → per-object review queue.
4. App/naming validation; review-document scaffold on the blackboard.
5. Optional KB pre-analysis (feature context + blast radius) when a `kbFolderId` exists, gated on KB
   staleness.
6. **Per-object review loop** (sequential): source + version-diff → implementation notes →
   `analyze_appian_code` → naming/folder checks → **dynamic checklist** (`get_review_checklist`) →
   SQL/SMT + i18n verification (`query_sql`, read-only) → findings written to the blackboard.
7. Compile: scorecard, ticket-fix verification, cross-object analysis, verdict.
8. Present the review document (a blackboard artifact, visible in the Run-Detail Documents drawer).

**Out of scope:**
- ❌ Google Docs export (removed per request).
- ❌ Any Appian mutation/deploy (creation/deployment tools are **excluded** by per-node allowlists).
- ❌ Changing the team-managed checklist semantics — the workflow reviews *against* the fetched
  checklist; it never invents or edits checklist items.

---

## 2. MCP tooling inventory (verified against the live Jarvis server)

Both servers are **already registered** in `genesis-workflows/mcp-registry.json`:
- **`jarvis`** — `registry.gitlab.appian-stratus.com/appian/prod/solutions-os/jarvis:latest`,
  env `APPIAN_BASE_URL` (public) + `APPIAN_API_KEY` (secret). Registry `mode: read-write-deploy`,
  **no `tool_allowlist`**.
- **`jira`** — `jira-mcp-proxy:latest`, env `JIRA_URL`+`JIRA_EMAIL` (public) + `JIRA_TOKEN` (secret).

### 2.1 Jarvis tools the workflow uses (confirmed names + schemas)
| Tool | Args | Used for |
|---|---|---|
| `get_jarvis_config` | — | app registry: `appUuid`, `appPrefix`, `kbFolderId`, `jiraProjects`, `reviewDocFolder`, `globalSettings.primaryDb` |
| `get_package_contents_from_url` | `package_url` | object list w/ UUIDs, types |
| `search_objects_by_name` | `searchTerm`, `startIndex?` | Path C UUID resolution |
| `get_application_info` | `appUuid` | `namingConvention`, `ruleFolderDetails[]` |
| `get_appian_object` | `object_uuid`, `object_name?`, `object_type?` | source code/config |
| `get_version_context` | `uuid`, `typeId`, `dateTime` | 3 before/3 after versions (baseline resolution) |
| `get_object_diff` | `uuid`, `typeId`, `dateTime`\|`versionNumber` | old vs latest SAIL (`change_type`) |
| `analyze_appian_code` | `object_uuid`, `analysis_types?` | complexity/best-practice/perf report + RT analyzer |
| `validate_record_relationships` | `object_uuid` | deep Record-Type relationship check (optional) |
| `get_object_dependencies` | `object_uuid`, `dependency_type` (DEPENDENTS/PRECEDENTS) | blast radius |
| `get_review_checklist` | — | **dynamic, team-managed checklist** (severity, `applicableObjectTypes`, examples) |
| `get_stale_objects` | `appUuid` | KB freshness gate |
| `jarvis_get_app_tree` / `jarvis_search_objects` / `jarvis_get_cluster` | `parentFolderId`(+`query`/`clusterName`) | KB feature context |
| `query_sql` | `sql` | **read-only** SQL (SELECT/WITH/EXPLAIN, LIMIT≤500) for SMT/i18n/DB checks |

### 2.2 JIRA tool
`get_jira_issue` (exact tool name to be confirmed from `jira-mcp-proxy` `tools/list` at build time),
returning `summary`, `description`, `customfield_10227` (acceptance criteria), `customfield_10173`
(package URL), `status`, `assignee`, and `changelog` (for reference-date extraction).

### 2.3 Security — read-only enforcement (ADR-021 / ADR-029)
`jarvis` is `read-write-deploy` and has **no registry allowlist**, so per ADR-029 the effective tool
trust = **`node.tools` ∩ server.allowlist** = `node.tools` (server cap absent). **Every agent node
in this workflow MUST declare an explicit read-only `tools=[…]` allowlist** — this is the hard cap
that makes the workflow incapable of creating/deploying objects, and is why **no `pre_mutation` gate
is required** (there is no mutating tool in the allowlist; `query_sql` is server-side read-only).

**The read-only Jarvis allowlist (namespaced `@jarvis/<tool>` per the 10-01 spike finding that
kiro-cli matches MCP tools by `@server/tool`):**
```
@jarvis/get_jarvis_config, @jarvis/get_package_contents_from_url, @jarvis/search_objects_by_name,
@jarvis/get_application_info, @jarvis/get_appian_object, @jarvis/get_version_context,
@jarvis/get_object_diff, @jarvis/analyze_appian_code, @jarvis/validate_record_relationships,
@jarvis/get_object_dependencies, @jarvis/get_review_checklist, @jarvis/get_stale_objects,
@jarvis/jarvis_get_app_tree, @jarvis/jarvis_search_objects, @jarvis/jarvis_get_cluster,
@jarvis/query_sql
```
Explicitly EXCLUDED: `create_constant`, `preview_constant`, and every creation/deployment/refactor
tool. **Recommended registry hardening:** add a `tool_allowlist` (the read set above, un-namespaced)
to the `jarvis` entry in `mcp-registry.json` so the cap is enforced at the registry tier for *all*
read-only workflows — but keep the per-node `tools=` too (defense in depth). *(If other workflows
need Jarvis's write tools, keep the registry allowlist off and rely on per-node `tools=`.)*

### 2.4 Secrets to configure (user, post-build)
`APPIAN_BASE_URL`, `APPIAN_API_KEY` (jarvis); `JIRA_URL`, `JIRA_EMAIL`, `JIRA_TOKEN` (jira). Set via
Settings → MCP (secret fields) or `secrets.json`. The workflow declares `required_mcp: [jarvis, jira]`
so Genesis surfaces missing secrets before a run (config `missing_secrets`).

---

## 3. Inputs & entry paths

`inputs_schema` (at least one of `jira_ticket` / `package_url` / `object_names` required):
```yaml
inputs_schema:
  type: object
  properties:
    jira_ticket:  {type: [string, "null"], default: null}   # Path A, e.g. "GAMS-7081"
    package_url:  {type: [string, "null"], default: null}    # Path B
    object_names: {type: array, items: {type: string}, default: []}  # Path C
    reference_date: {type: [string, "null"], default: null}  # ISO-8601 override for diff baseline
    run_kb_preanalysis: {type: boolean, default: true}       # skip KB context if false
  anyOf:
    - {required: [jira_ticket]}
    - {required: [package_url]}
    - {properties: {object_names: {minItems: 1}}}
```
A program `resolve_inputs` node validates the combination and records the active path (A/B/C) in
`decisions.path`.

---

## 4. State & blackboard model

**State (small, editable — ADR-010):** standard `PlatformState` plus workflow-specific keys carried
in `decisions`/dedicated fields:
- `decisions.path` — "A"|"B"|"C"
- `decisions.reference_date` — ISO-8601 or null
- `decisions.app` — `{appUuid, appPrefix, appName, namingConvention, kbFolderId, ruleFolders:[...]}`
- `review_queue` — `list[ObjectRef]` remaining to review (a queue; reducer = last-writer)
- `current_object` — the `ObjectRef` being reviewed (`{name, uuid, type, typeId, needs_sql}`)
- `reviewed` — `list[str]` of completed object names (append reducer)
- `retries` — per-agent retry counters (the loop RESETS `retries["review_object"]` per object; see §8.2)
- `telemetry` — per-node metrics incl. **Phase 11 credits**

**Blackboard artifacts (`RunWorkspace`, bulk lives here — never in state/chat):**
| Doc | Written by | Content |
|---|---|---|
| `jira.json` | `fetch_ticket` (by reference) | raw JIRA issue + changelog |
| `package.json` | `fetch_package` (by reference) | raw package contents |
| `jarvis_config.json`, `app_info.json` | `fetch_context` | config + app info |
| `checklist.json` | `fetch_context` | the dynamic review checklist (cached once) |
| `queue.json` | `parse_package` | sorted, tagged review queue |
| `obj/{NN}-{name}.md` | `review_object` (per object) | that object's implementation notes + findings |
| `review.md` | `scaffold` + `compile` | **the master deliverable** (incrementally assembled) |
| `report.json` | `compile` | machine-readable scorecard + verdict |

Large tool outputs (a 3000-line process model, a full `analyze_appian_code` report) are saved **by
reference** via the Phase-9 blackboard MCP (`save_tool_output`), so they never re-enter the context
window — this is the deterministic replacement for the doc's "write to file after each object".

---

## 5. Node graph (topology)

```
                         ┌─────────────┐
START ─▶ resolve_inputs ─▶ (path A?) ──▶ fetch_ticket(agent,jira) ─▶ v_ticket ─▶ compute_reference(prog)
                          │  (path B/C: skip to fetch_package)                              │
                          └───────────────────────────────────────────────────────────────┘
   ─▶ fetch_package(agent,jarvis) ─▶ v_package ─▶ parse_package(prog: filter/sort/typeId/sql-tags/queue)
   ─▶ fetch_context(agent,jarvis: get_jarvis_config+get_application_info+get_review_checklist) ─▶ v_context
   ─▶ validate_app(prog: appUuid+namingConvention, scaffold review.md)
   ─▶ [kb_stale?(prog+gate)] ─▶ [kb_preanalysis(agent,jarvis KB)]        (optional branch)
   ─▶ next_object(prog router) ──(queue empty)──▶ compile(prog) ─▶ present(prog) ─▶ END
        │  (queue non-empty: pop → current_object, reset retries)
        ▼
      review_object(agent, jarvis[read-only]) ─▶ v_object(validator)
        ├─ pass     ─▶ advance(prog: append obj section to review.md, mark reviewed) ─▶ next_object
        ├─ retry    ─▶ review_object
        └─ exhaust  ─▶ escalate(gate, escalation)   [approve→advance(skip note) | abort→compile]
```

**Node kinds:** `resolve_inputs, compute_reference, parse_package, validate_app, kb_stale, next_object,
advance, compile, present` = **program**; `fetch_ticket, fetch_package, fetch_context, kb_preanalysis,
review_object` = **agent (kiro_node)**; `v_ticket, v_package, v_context, v_object` = **validator**;
`kb_gate, escalate` = **gate**. The four agent nodes that must be reliable (`review_object` above all)
are wrapped by `attach_reliability` (validator + retry + escalation).

The `graph:` block in `workflow.yaml` mirrors this exactly (node ids == LangGraph node names) so the
Run-Detail graph renders it (a fallback is derived from `/steps` if omitted, but we declare it).

---

## 6. Per-node specification (detailed)

Node factories (from `genesis_core`, signatures confirmed): `program_node(name, fn)`,
`kiro_node(name, prompt_fn, output_doc, mcp=[], tools=None, model=None, turn_timeout, startup_timeout,
blackboard=True)`, `cli_node(name, cmd_fn, parse_fn)`, `validator_node(name, check_fn, target_artifact=None)`,
`hitl_gate(name, kind, prompt_fn, options=None)`, `attach_reliability(g, agent, validator, retry_max,
on_exhaust_gate, nxt)`. `check_fn(data, state, ctx) -> ValidationResult(ok, message, normalized?)`.

### 6.1 `resolve_inputs` (program)
Validate the input combination; set `decisions.path`. For **Path C**, the object-name→UUID resolution
needs an MCP call, so Path C routes to a small `resolve_objects` agent node (jarvis
`search_objects_by_name`) before `parse_package`; Paths A/B skip it. Output: `decisions.path`,
`decisions.reference_date` (from input override if given).

### 6.2 `fetch_ticket` (agent, mcp=[jira], tools=[@jira/get_jira_issue]) — Path A only
Prompt: call the JIRA issue tool for `{jira_ticket}` with the required fields + `expand=[changelog]`,
then `save_tool_output(ref, document="jira.json")`; reply DONE. **`v_ticket`** validates `jira.json`
parses and contains `fields.summary` + a `changelog`.

### 6.3 `compute_reference` (program) — Path A only
Pure logic on `jira.json` (no MCP):
- Scan `changelog.histories` for the FIRST `status` transition to `"Technical Design"`; else FIRST to
  `"In Progress"`; else `null`. Convert to ISO-8601 UTC → `decisions.reference_date`.
- Extract `package_url` from `customfield_10173` (if the input didn't supply one).
- (Baseline *version* is resolved per-object in the loop — §6.9 — because each object has independent
  version history; the ticket assignee `fields.assignee.displayName` is stashed in `decisions.assignee`
  for that.)
This is the intricate deterministic logic the Jarvis doc asks the LLM to do — far more reliable as code.

### 6.4 `fetch_package` (agent, mcp=[jarvis], tools=[@jarvis/get_package_contents_from_url])
Call `get_package_contents_from_url(package_url)`; `save_tool_output(ref, "package.json")`; DONE.
**`v_package`**: `package.json` parses and has ≥1 object.

### 6.5 `parse_package` (program)
Pure logic on `package.json`:
- **Filter**: drop `CollaborationDocument` (i18n bundle files).
- **typeId map** (module constant): Interface=260, ExpressionRule=39, Constant=40, ProcessModel=23,
  Integration=250, DecisionRule=248; RecordType→null (diff skipped).
- **Sort** light→heavy: Constants → Expression Rules → Interfaces → Record Types → Process Models.
- **SQL tags** `needs_sql`: prefix QE_/QR_, Record Types, Process Models, or source hints (resolved
  later); constants referencing `*_ENT_*`.
- Build `review_queue = [ObjectRef,…]`; write `queue.json`. Output `review_queue` + counts.

### 6.6 `fetch_context` (agent, mcp=[jarvis], tools=[get_jarvis_config, get_application_info, get_review_checklist])
Calls `get_jarvis_config` (match `appPrefix` from object-name prefixes → `appUuid`, `kbFolderId`,
`reviewDocFolder`, `globalSettings.primaryDb`), `get_application_info(appUuid)` (namingConvention +
ruleFolders), and `get_review_checklist` (once); saves each by reference to `jarvis_config.json`,
`app_info.json`, `checklist.json`. DONE. **`v_context`**: all three present + `checklist.json` is a
non-empty list with `severity` + `applicableObjectTypes` fields.

### 6.7 `validate_app` (program)
Resolve `appUuid` + `namingConvention` from the fetched config; if the package prefix doesn't match a
known app → set a `decisions.app_warning` (do NOT hard-fail; some reviews are cross-app). Scaffold
`review.md` with the header + Review Summary table + object list (mirrors the doc's Step 3c). Store
`decisions.app`.

### 6.8 KB pre-analysis (optional) — `kb_stale` (program) + `kb_gate` (gate) + `kb_preanalysis` (agent)
Only if `run_kb_preanalysis` and `decisions.app.kbFolderId` exists.
- `kb_stale`: (the staleness number comes from `get_stale_objects`, an MCP call) — so this is actually
  an agent (`kb_check`, tools=[get_stale_objects]) that saves the count; then a program reads it.
  If `staleCount > 0` → route to **`kb_gate`** (kind=`approval`, options `[proceed, refresh_first]`);
  `refresh_first` ends the run with a note (refresh is a separate concern). If 0 → skip the gate.
- `kb_preanalysis` (agent, tools=[jarvis_get_app_tree, jarvis_search_objects, jarvis_get_cluster,
  get_object_dependencies]): identify the feature cluster + blast radius for the 2–3 key objects;
  append a `## KB Context` section to `review.md`. Budget 2–4 calls. Best-effort — failure logs and
  continues (no validator gate; it's enrichment).

### 6.9 `next_object` (program, the loop router)
- If `review_queue` empty → return `{}` and the conditional edge routes to `compile`.
- Else pop the head → `current_object`; **reset `retries["review_object"]=0`** (per-object retry budget,
  see §8.2); return `{current_object, review_queue: rest, retries: {review_object: 0}}`.

### 6.10 `review_object` (agent, mcp=[jarvis], tools=<read-only allowlist §2.3>) — THE core node
For `current_object`, the prompt instructs (with the checklist injected from `checklist.json` and
`reference_date`/`assignee` from state):
1. **Diff/baseline** (skip if RecordType typeId=null or reference_date=null): call
   `get_version_context(uuid, typeId, reference_date)`; apply the deterministic assignee rule — first
   `after` version by `decisions.assignee` → baseline = version immediately before it; else last
   `before`; then `get_object_diff(uuid, typeId, versionNumber=baseline)`. Save the diff by reference.
2. `get_appian_object(uuid, name, type)` → source; save by reference if large.
3. `analyze_appian_code(uuid)` → save by reference. **(v_object asserts this ran.)**
4. **SQL verification** if `needs_sql`: derive table name(s) from source/constants; run `query_sql`
   `DESCRIBE Appian.{TABLE}` / `SHOW INDEX …` / the SMT-pending-migration SELECT / the i18n `BND_Key`
   lookup — dialect per `globalSettings.primaryDb` (MariaDB vs PostgreSQL branch, both documented in
   the tool). Flag Critical (missing column), Medium (unindexed filter col), Info (pending migration).
5. **Review** against (a) the filtered checklist items for this object type, (b) naming/folder rules,
   (c) diff-awareness (New vs Pre-existing), and write the object section to `obj/{NN}-{name}.md`:
   Implementation Notes (if diff) + Findings table (`| # | Severity | Finding | Recommendation |`) +
   `**Checklist:** N items evaluated (…)` + optional Analyzer Observations + Positives.
6. Reply DONE.
Tool budget guidance and the exact section format are embedded in the prompt (ported from the doc).

### 6.11 `v_object` (validator, target_artifact = the per-object doc) — the code-enforced "PRE-WRITE CHECKPOINT"
`check_fn` reads the object doc + the run's tool-output store/events and asserts:
- The doc has a `### Findings` section (or explicit "No issues found.").
- **Every severity** ∈ {Critical, High, Medium, Low}.
- **Only real checklist items**: any `[label]` referenced maps to a `checklist.json` item label.
- The `Checklist: N items evaluated` count **== number of applicable items** for this object type
  (computed from `checklist.json` `applicableObjectTypes`). Mismatch → fail with the delta.
- `analyze_appian_code` was invoked for this object (detect via the Phase-9 tool-output store or the
  `agent.tool_call` events for this node). If not → fail ("run analyze_appian_code").
- If `needs_sql` and no `query_sql` call is recorded → fail.
Returns `ValidationResult(ok, message)`. On fail → `attach_reliability` increments
`retries[review_object]` and re-runs with the message fed back into the prompt.

### 6.12 `advance` (program)
Append `obj/{NN}-{name}.md` content into `review.md`; append name to `reviewed`; update the review
status line (`{done}/{total}`); **reset `retries[review_object]=0`**; route back to `next_object`.

### 6.13 `escalate` (gate, escalation)
Reached when `review_object` exhausts retries on one object. Options `[skip, abort]`: `skip` →
`advance` writes a "⚠️ review incomplete for {object}" stub and continues; `abort` → `compile` with a
partial verdict. (HITL, ADR-021 — a human decides whether one bad object blocks the batch.)

### 6.14 `compile` (program)
Pure aggregation over the per-object docs + findings: Overall Scorecard, Ticket-Fix Verification
(Path A only), Cross-Object Analysis, Positives, Recommendations, and the **Verdict** (Approved /
Approved with Comments / Needs Rework — derived deterministically from the max severity present).
Append all to `review.md`; write `report.json`; set `status=done`.

### 6.15 `present` (program)
Finalize: set the review-doc status to Complete; record `decisions.review_doc` pointer +
`decisions.verdict`. The `review.md` artifact is surfaced in the Run-Detail **Documents drawer**
(rendered markdown) — no chat dump needed.

---

## 7. Determinism strategy (the ADR-001 split)

- **All MCP tool interaction happens inside agent (`kiro_node`) nodes** — program nodes cannot run
  Kiro turns. Agents fetch raw data and `save_tool_output(...)` **by reference** to the blackboard.
- **All deterministic logic runs in program nodes** operating on those blackboard artifacts:
  reference-date extraction, package filter/sort/typeId/SQL-tagging, naming/folder validation,
  scorecard/verdict aggregation, and loop routing. This is where the Jarvis doc's fragile
  "please do these steps in order" becomes structural.
- **Genuinely agentic judgment stays in agents**: implementation-notes prose, checklist evaluation,
  business-logic review of process models, cross-object narrative. These are wrapped by validators
  that check *structure and coverage* (not semantic correctness) — the right boundary.
- The per-object **baseline-version resolution** is a hybrid: the *rule* is deterministic but needs
  `get_version_context` (MCP) mid-review, so it lives in the `review_object` agent with explicit rule
  text + a validator that a diff was obtained or explicitly skipped. *(A future enhancement — a
  "deterministic MCP-call program node" using a direct stdio client like `genesis_core/mcp/introspect.py`
  — could move such calls out of the agent for full determinism; noted as out-of-scope for v1.)*

---

## 8. Loop mechanics (the one genuinely new pattern vs ERD)

ERD is linear; this workflow **loops** over N objects. Two concrete consequences:

### 8.1 Recursion limit (genesis engine dependency)
LangGraph's default `recursion_limit` is **25 supersteps**. The loop spends ~4 supersteps per object
(`review_object`→`v_object`→`advance`→`next_object`), so ~6 objects exhausts it. **`genesis/runs/worker.py`
must set a higher `recursion_limit`** on the astream config — driven by a `META.max_iterations` (or a
generous constant, e.g. 200). This is a **small, additive genesis platform change** (sub-phase 12-01)
and is required before any looping workflow can ship. Proposed: read `META.execution.recursion_limit`
(default 150) in `_config`/astream. Non-looping workflows are unaffected.

### 8.2 Per-object retry budget
`attach_reliability` keys retries by the agent node **name**, and `review_object` is re-entered per
object. Without a reset, retries accumulate across objects and later objects get no retry budget (and
the router's exhaust check trips early). **Fix:** `next_object` and `advance` reset
`retries["review_object"] = 0` (the `_inc_merge` reducer takes the absolute value). Documented here
because it's a non-obvious interaction between looping and the reliability trio.

### 8.3 Context resilience (free)
Because state is checkpointed per superstep (ADR-012) and findings are persisted to the blackboard
after each object, a worker killed mid-batch resumes from the exact object it was on — the doc's
"a new agent can read the review file and resume" is automatic and durable, not a prompt instruction.

---

## 9. Credits (Phase 11 tie-in — free)

Every `review_object` turn now emits metered credits (Phase 11). The Run-Detail view will show
**per-object credit cost** (in the node timeline) and a **run-total** (header + telemetry strip), and
the Overview KPI aggregates it. Reviewers can see "this 3000-line process model cost 6 credits to
review" with zero extra work. Worth calling out as a concrete payoff of shipping Phase 11 first.

---

## 10. Packaging & files (genesis-workflows)

```
workflows/code-review/
  __init__.py
  graph.py            # META + build(ctx) + pure functions + prompt builders + validators
  workflow.yaml       # mirrors META + the graph: topology block (parity lint)
  README.md
  prompts/__init__.py # optional prompt text (or inline in graph.py)
  tests/test_workflow.py
```
- **`registry.json`**: add a `code-review` entry — `path: workflows/code-review`,
  `required_mcp: [jarvis, jira]`, `required_cli: []`, roles `[developer, reviewer]`.
- **`mcp-registry.json`**: (optional) add the read-only `tool_allowlist` to `jarvis` (§2.3).
- **`META`** keys mirror ERD's, plus `hitl_points: [kb-gate, escalate]`, `required_mcp: [jarvis, jira]`,
  `artifacts: [jira.json, package.json, checklist.json, review.md, report.json]`,
  `editable: [inputs, decisions]`, and `execution: {recursion_limit: 150}` (new; consumed by 12-01).
- `workflow.yaml` must mirror `META` (contract parity lint; `graph:` is a `YAML_ONLY_KEYS` exemption).

---

## 11. Testing strategy

Following the ERD test pattern (`set_collect_impl` to stub Kiro; pure functions unit-tested):
- **Pure functions** (no Kiro): `compute_reference` (changelog → reference_date, all 3 fallbacks),
  `parse_package` (filter/sort/typeId/SQL-tags), verdict derivation, scorecard aggregation, the
  per-object-doc parser used by `v_object`.
- **Validators**: `v_object` — feed synthetic object docs (good; wrong severity; invented checklist
  item; wrong count; missing `analyze_appian_code`) and assert ok/fail + message.
- **Graph wiring**: build with a stubbed `collect`/`stream` that writes canned tool outputs + a
  findings doc; run a 2-object queue end-to-end; assert the loop advances, resets retries, compiles a
  verdict, and produces `review.md`. Assert the reliability trio retries on a bad object.
- **Loop bound**: a queue of N objects completes without hitting the recursion limit (validates 12-01).
- **CI**: `genesis-workflows/ci/validate_library.py` 7-gate publish runner + the genesis contract
  parity + reliability lints (every agent node must have a validator + retry + escalation path).
- **Live (manual, post-secrets)**: run against a real GAMS ticket; confirm per-object findings,
  checklist counts, SQL checks, verdict, and metered credits.

---

## 12. Sub-phase plan (recommended sequencing)

- **12-01 — Engine: loop support (genesis).** `worker.py` sets `recursion_limit` from
  `META.execution.recursion_limit` (default 150). Tiny, additive; ship as a genesis patch. **Blocks the
  loop.** *(Only genesis-side change in the whole phase.)*
- **12-02 — MVP workflow (genesis-workflows).** Paths A+B, `fetch_package`→`parse_package`→
  `fetch_context`→`validate_app`→ per-object loop (source+diff+`analyze_appian_code`+dynamic checklist+
  naming/folder) → compile → present. **No KB pre-analysis, no SQL/SMT/i18n.** Reliability trio +
  escalate gate. Ships a runnable, valuable review.
- **12-03 — DB verification.** Add `query_sql` SMT + i18n checks in `review_object` + `v_object` SQL
  assertion. (Needs Appian DB reachable via jarvis creds.)
- **12-04 — KB pre-analysis + staleness gate.** `kb_check`/`kb_gate`/`kb_preanalysis` branch.
- **12-05 — Path C (standalone object review)** + `validate_record_relationships` deep RT check.
- *(Deferred/out: Google Docs export.)*

Rationale: 12-01 unblocks looping; 12-02 delivers the core value against the two most common entry
paths with the fewest credentials; the rest layer on integrations incrementally so we never block the
whole workflow on one credentialed dependency.

---

## 13. Risks & open questions

- **R1 — recursion limit (12-01) is a hard prerequisite.** Without it the loop dies at ~6 objects.
  Mitigation: ship 12-01 first; test with a large queue.
- **R2 — per-object retry accumulation** (§8.2) — mitigated by the reset; covered by a test.
- **R3 — agent adherence to the exact tool sequence.** The review turn asks the agent to call specific
  tools in order. Genesis mitigates via the `v_object` validator (asserts `analyze_appian_code` +
  required SQL ran) + retry, but a stubborn agent could loop-to-exhaust → escalate. Acceptable.
- **R4 — the dynamic checklist is external.** Validators enforce *structure/coverage*, not the
  semantic correctness of each finding (that's the agent's judgment). Align expectations with the user.
- **R5 — JIRA tool exact name/fields.** Confirm from `jira-mcp-proxy` `tools/list` at build; custom
  fields (`customfield_10173/10227`) are Appian-JIRA-specific — verify they exist in this instance.
- **R6 — SQL dialect branching.** `query_sql` supports MariaDB + PostgreSQL with different syntax;
  the prompt must branch on `globalSettings.primaryDb`. Both documented; tested against one dialect.
- **Q1 — registry allowlist vs per-node only?** Recommend per-node `tools=` (always) + optional
  registry `tool_allowlist` on `jarvis`. Confirm no other workflow needs Jarvis write tools before
  adding a registry-tier cap.
- **Q2 — verdict authority.** Derive deterministically from max severity (program), or let the agent
  propose and a program confirm? Recommend deterministic (program) for auditability.

## 14. Acceptance criteria
1. `genesis install` picks up `code-review`; Catalog shows it; launch validates `required_mcp` secrets.
2. A run against a package URL (Path B) reviews every object one-at-a-time, writes `review.md` with
   per-object Implementation Notes + Findings + checklist status, and a final Scorecard + Verdict.
3. Each agent review turn is validator-gated (analyze ran, checklist coverage matches, severities
   valid); a bad object retries then escalates to a HITL gate.
4. The workflow is **incapable of mutating Appian** (read-only tool allowlist; no `pre_mutation` gate
   needed) — verified by the effective-trust computation excluding all write/deploy tools.
5. The loop completes for N>6 objects (recursion limit raised) and resumes correctly after a
   pause/kill (checkpointer).
6. Per-object + per-run **credit usage** is visible (Phase 11).
7. All gates green: genesis-workflows CI 7-gate + contract parity + reliability lint; workflow unit
   tests; a genesis patch for 12-01 with its own test.

## 15. Out of scope / future
- Google Docs export (removed).
- Any Appian object creation/deployment (that's the separate implementation workflow).
- A "deterministic MCP-call program node" (§7) — would tighten determinism; revisit if agent
  tool-sequencing proves unreliable.
- Auto-refreshing a stale KB (the gate defers to the user).
