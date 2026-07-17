# Phase 15 — Follow-up Fixes (design-doc live-run issues)

> **Status:** OPEN (documented for a later fix pass) · **Date:** 2026-07-17
> **Found during:** the first live `design-doc` runs against real Jarvis/JIRA/Atlas
> (`r-5c15c313c079` GAMS-9277, `r-d6f144f98f2c` GAMS-9266).
> **Repos affected:** `genesis` (platform + web) and `genesis-workflows` (design-doc).
> Already-shipped related fixes today: v0.27.1 (nested-artifact route + terminal-orphan
> reconcile), v0.27.2 (tool-output toggle moved to Documents), genesis-workflows v0.7.1
> (jarvis preamble coercion + empty-namingConvention). The items below are the **remaining**
> issues. Nothing here is fixed yet.

---

## Issue 1 — Run-view state goes stale for runs orphaned across a server restart

**Severity:** medium (misleading UI; run itself is fine). **Repo:** `genesis`.

**Symptom.** The Run-Detail status badge + graph cursor show an old node while the run has
actually progressed. On `r-d6f144f98f2c` the record showed `status=running, cursor=freshness,
updated_at=10:35`, but the durable eventlog showed the run had completed `v_rjarvis` (node.completed
@10:38) and was actively in `research_atlas` (live tool calls at 16:06, event seq climbing).
Same class of issue seen on `r-5c15c313c079` (record `running@v_plan` while the run had actually
escalated and hit `run.final`).

**Root cause.** The denormalized `RunRecord` (status/cursor/updated_at) is updated by the
manager's `on_event` (`set_status(cursor=node)` on each `node.completed`). When a run **spans a
`genesis serve` restart** (several today for the v0.27.x deploys), the in-flight worker is orphaned
from the record: the durable eventlog keeps advancing (correct) but the record freezes at its
pre-restart cursor. The v0.27.1 `RunManager.reconcile_status` only reconciles the **terminal**
orphan case (no live worker + a terminal `run.final`); it does **not** refresh a **still-running**
orphaned record's cursor.

**Evidence.**
- `GET /api/runs/r-d6f144f98f2c` → `cursor=freshness`, `updated_at=2026-07-17T10:35`.
- Durable events: last `node.completed` = `v_rjarvis` @10:38; `research_atlas` tool calls streaming
  at 16:06 (maxseq 10527→10565 over 18s).
- No `genesis serve`/uvicorn matched by name in `ps` (served on :8760); worker PID 94557 (from
  16:05) is the live one — i.e. a resume the current API process's manager isn't tracking for record
  updates.

**Proposed fix.** Extend `RunManager.reconcile_status` (or add a sibling) so that, at read-time in
`GET /runs/{id}` and `list`, a **non-terminal** record whose worker is not tracked in this process
also adopts the **latest `node.completed` node as its cursor** from the durable eventlog (and, if the
latest `run.final` is non-terminal e.g. `awaiting_input:gate`, set that status). Keep it idempotent
and read-only-derived. Deeper (optional) fix: on server startup, re-attach/reconcile in-flight runs
so restarts don't orphan workers at all (bigger change; the copilot supervisor already does a
level-triggered reconcile for session-linked runs — generalize it).

**Verification.** Unit test: seed a durable log with node.completed past the record cursor + no
tracked worker → `reconcile_status` advances the cursor. Manual: restart `serve` mid-run, confirm the
Run-Detail cursor tracks the durable log.

**Risk.** Low (read-time, idempotent). Avoid regressing the live-worker case (must not override a
record a live in-process worker owns).

---

## Issue 2 — design-doc Jarvis read-only allowlist is INCOMPLETE (agent reaches untrusted tools)

**Severity:** medium (workflow correctness + read-only-cap integrity). **Repo:** `genesis-workflows`.

**Symptom.** In `research_jarvis` the agent called `get_appian_object`, `get_object_dependencies`,
`search_objects_by_name` — real jarvis tools that are **not** in the workflow's `JARVIS_RO` allowlist.

**Root cause (corrected).** NOT wrong tool names — the `jarvis_*`-prefixed KB tools I used **all
exist** on the live server. The allowlist is simply **missing** several real read tools the research
agent naturally uses. Introspected the installed jarvis MCP
(`POST /api/config/mcp-servers/jarvis/tools`) — the full real tool set:

*Read-safe (should be in the research allowlist):*
`get_appian_object, get_package_contents_from_url, get_application_info, get_jarvis_config,
get_object_dependencies, get_object_diff, get_version_context, get_review_checklist, get_stale_objects,
get_kb_folder_id, get_all_type_metadata, get_environment_info, get_deployment_results,
get_inspection_results, analyze_appian_code, explain_appian_code, compare_object,
evaluate_sail_expression, validate_record_relationships, search_objects_by_name, search_objects_semantic,
list_application_objects, list_sites, query_sql, jarvis_get_app_tree, jarvis_get_architecture,
jarvis_get_cluster, jarvis_get_context, jarvis_get_data_model, jarvis_get_dead_code,
jarvis_get_dependency_chain, jarvis_get_dependents_batch, jarvis_get_entry_points_for_object,
jarvis_get_impact_analysis, jarvis_get_object_content, jarvis_get_object_xml, jarvis_get_objects_by_type,
jarvis_get_patterns, jarvis_get_precedents_batch, jarvis_get_shared_objects, jarvis_get_translation`

*Write/deploy/mutating (MUST stay excluded from research; only `create_package_for_ticket` belongs on
the gated package node):*
`create_constant, preview_constant, create_package_for_ticket, deploy_modified_object, deploy_package,
inspect_package, switch_site, generate_uuids`  *(generate_uuids is a benign utility but not needed; keep out.)*

**Proposed fix.** Rebuild `JARVIS_RO` in `workflows/design-doc/graph.py` from the read-safe list above
(at minimum add `get_appian_object, get_object_dependencies, search_objects_by_name, get_version_context,
get_object_diff, get_kb_folder_id, get_all_type_metadata`). Keep `JARVIS_PKG` = `[get_jarvis_config,
create_package_for_ticket]`. Consider deriving/asserting the allowlist against introspection in a test
so drift is caught. Also align the research-prompt tool references to real names.

**Verification.** Re-run against a real ticket; confirm the research node no longer touches untrusted
tools and the research docs are complete.

**Risk.** Low (additive to a read-only set; no write tool added).

---

## Issue 3 — Chat copilot GateCard "feedback box" doesn't dismiss after responding

**Severity:** low/medium (confusing UX). **Repo:** `genesis` (web).

**Symptom.** In copilot Chat, after answering a supervised-run gate (option button or "Send feedback"),
the **gate card / feedback box stays visible** — it looks like the response didn't take.

**Root cause.** `web/src/features/chat/cards.tsx::GateCard` clears its local `feedback` text
(`setFeedback("")`) but the **card itself isn't dismissed**. `ChatThread` renders gate cards from
`useSessionNotifications(...).notifications` filtered to `kind==="gate"`, and `onRespond` only calls
`send(text)` — it never removes the notification. The hook already exposes an **`ack(id)`** that
removes the notification locally + calls `chatApi.ackNotification`, but `ChatThread` doesn't destructure
or call it, so the card persists until a new notification stream state arrives.

**Evidence.** `cards.tsx` GateCard `onRespond` handlers (option buttons + Send feedback) don't dismiss;
`ChatThread` uses `const { notifications } = useSessionNotifications(...)` (no `ack`); the gate card is
`{copilot && gateNotes.map((n) => <GateCard ... onRespond={(text) => send(text)} />)}`.

**Proposed fix.** In `ChatThread`, destructure `ack` from `useSessionNotifications` and dismiss the gate
on respond: wrap `onRespond` so it does `send(text); ack(n.id);` (optimistic removal + server ack). The
GateCard already resets its textarea; dismissing the card is the missing piece. Optionally disable the
buttons while the ack/send is in flight.

**Verification.** Web test: render a GateCard-bearing session, click an option / send feedback, assert
the card disappears and `ackNotification` was called. Manual: answer a real supervised gate in copilot
chat → card dismisses.

**Risk.** Low. Ensure ack doesn't drop a *different* still-pending gate notification (ack by exact id).

---

## Issue 4 — OPEN QUESTION: is the per-node read-only allowlist actually enforced at runtime?

**Severity:** needs investigation (potential security/enforcement gap). **Repo:** `genesis` / `genesis-core`.

**Observation.** In Issue 2, the agent called jarvis tools **not** in the node's `trust_tools` allowlist
(`get_appian_object`, …) and they **executed** — with **no `permission.request` events** recorded and
`tool_update: completed`. Expected: with `trust_all_tools=False` + a `trust_tools` allowlist, an
untrusted MCP tool should trigger `session/request_permission` (which a non-copilot workflow worker has
no handler for → should stall/deny), not silently run.

**Why it matters.** The workflow's "read-only by construction" guarantee (ADR-021/029, and the
code-review workflow's safety story) depends on the per-node allowlist being a **hard runtime cap**. If
workflow agent nodes effectively auto-approve untrusted tools (e.g. `permission_mode=auto_approve`
default in `kiro_node`), the allowlist is advisory, not enforced — meaning a read-only workflow could in
principle call a write/deploy tool if the agent chose to.

**To investigate.** How `kiro_node` sets `permission_mode` for workflow agent turns; what kiro-cli does
with an untrusted MCP tool under that mode; whether `_compute_effective_trust` output actually gates
execution or only shapes the prompt. If it's not enforced, decide the fix: set `permission_mode` to deny
untrusted tools for workflow nodes (fail-closed), or add a worker-side deny handler.

**Verification.** A workflow node with a deliberately restrictive `tools=[…]` that instructs the agent to
call an excluded tool → assert it is refused (not executed).

**Risk of the fix.** Medium — could make currently-"working" runs fail if they secretly relied on
untrusted tools (which is exactly the point). Needs a live check.

---

## Issue 5 — Atlas MCP introspection returns an empty tool list

**Severity:** low (tooling/observability). **Repo:** `genesis` / registry.

**Symptom.** `POST /api/config/mcp-servers/appian-atlas/tools` returned **no tools** (empty), while the
same call for `jarvis` returned 48 tools. The `appian-atlas` allowlist in `mcp-registry.json` is the only
reference for Atlas tool names right now.

**To investigate.** Whether the atlas MCP image starts under introspection (env/secrets — needs
`GITLAB_TOKEN` + `ATLAS_KB_PROJECT_ID` + `ATLAS_DATA_PREFIX`), or whether introspection times out. Confirm
the design-doc `ATLAS_RO` allowlist names match the live atlas server (the `research_atlas` node did run
`get_app_overview`/`search_objects` successfully on `r-d6f144f98f2c`, so those exist).

**Risk.** Low.

---

## Priority & sequencing (suggested)

1. **Issue 3** (chat gate dismiss) — small, isolated, clear UX win (web-only, ships a genesis release).
2. **Issue 2** (jarvis allowlist completeness) — small, evidence-backed (genesis-workflows patch).
3. **Issue 1** (running-orphan reconcile) — small extension of existing `reconcile_status` (genesis).
4. **Issue 4** (allowlist enforcement) — investigate first; the finding may change the security posture.
5. **Issue 5** (atlas introspection) — investigate opportunistically.

All are low-risk except Issue 4 (which is investigation-first). None block current use; the live
`design-doc` runs complete — these are correctness/robustness/UX hardening from the first real runs.
