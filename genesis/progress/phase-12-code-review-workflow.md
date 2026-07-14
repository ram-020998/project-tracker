# Phase 12 — Appian Code-Review Workflow (as-built)

**Status:** ✅ Shipped (code + tests + CI). Live run against a real ticket/package pending (needs a
`genesis serve` restart on ≥ v0.20.2 + jarvis/jira secrets, which are connected).
**Releases:** genesis **v0.20.2** (12-01 engine loop support) + genesis-workflows **v0.5.0**
(`code-review` workflow, 12-02..12-05), then **v0.5.1 → v0.5.3** (live-data robustness fixes — see
"Live-run hardening" below). **Spec:** `specs/phase-12-code-review-workflow.md`.

## What shipped

### Open questions resolved with the user (before building)
- **R5 — JIRA tool:** confirmed live via Genesis MCP introspection (`POST /api/config/mcp-servers/jira/tools`):
  `get_jira_issue(issue_key, fields?, expand?)`, explicitly read-only, `expand=["changelog"]` supported.
  Custom fields `customfield_10173` (package URL) / `customfield_10227` (acceptance criteria) requested
  by name; existence verified at first live run (absent → null, harmless).
- **Q1 — jarvis allowlist:** **no** registry `tool_allowlist` on `jarvis` (other/future workflows need
  its write/deploy tools). Read-only cap is enforced **per-node** via `tools=[@jarvis/…]`.
- **R4 — checklist scope:** validators enforce *structure + coverage*; the agent owns each finding's
  semantic correctness.
- **Q2 — verdict authority:** **option (b)** — agent-proposed + program-confirmed against a severity floor.

### 12-01 — genesis engine loop support (genesis v0.20.2)
`genesis/runs/worker.py`: added `DEFAULT_RECURSION_LIMIT=150` + `_recursion_limit_of(meta)` (reads
`META.execution.recursion_limit`, falls back on unset/malformed/≤0) + `_config(run_id, ctx, recursion_limit=None)`
which places `recursion_limit` at the top level of the LangGraph config; applied in run/resume and fork.
Additive — non-looping workflows are unaffected. Tests (`tests/test_runs.py`): a 40-iteration `LOOP`
(META limit 200) completes past the built-in 25; a `LOWLOOP` (limit 5) fails, proving META is honored;
`_recursion_limit_of`/`_config` unit tests. **122 genesis pytest, ruff clean, CI #6344231 ✅.**

### 12-02..12-05 — the workflow (genesis-workflows v0.5.0)
`workflows/code-review/{graph.py, workflow.yaml, __init__.py, README.md, tests/test_workflow.py}` +
`registry.json` entry (`required_mcp: [jarvis, jira]`, roles `[developer, reviewer]`). One graph
implements every sub-phase:

- **Entry (Paths A/B/C)** via `_route_entry`: A = `fetch_ticket` → `compute_reference` (pure changelog
  scan: first transition to *Technical Design*, else *In Progress*; + package URL from `customfield_10173`
  + assignee); B = `fetch_package`; C = `resolve_objects` (names → UUIDs). All converge on `parse_package`
  (filter `CollaborationDocument`, typeId map, light→heavy sort, `needs_sql` tagging) → `fetch_context`
  (`get_jarvis_config` + `get_application_info` + dynamic `get_review_checklist`) → `validate_app`
  (resolve appUuid/naming, scaffold `review.md`).
- **KB branch (optional)** gated on `run_kb_preanalysis` + `kbFolderId`: `kb_check` (`get_stale_objects`)
  → `kb_stale` (program) → `kb_gate` (approval: proceed / refresh_first → `present_kb_deferred`) →
  `kb_preanalysis` (feature cluster + blast radius, best-effort).
- **Per-object loop:** `next_object` (pop head → `current_object`, reset `retries[review_object]=0`,
  snapshot the tool-store index length as `_store_cursor`) → `review_object` (agent, read-only
  `@jarvis/*` allowlist: diff/baseline via `get_version_context`+`get_object_diff` → `get_appian_object`
  → **required** `analyze_appian_code` → `query_sql` DB/i18n when `needs_sql` → `validate_record_relationships`
  for RecordTypes → evaluate the applicable checklist) → **`v_object`** → `advance` (persist
  `obj/NN-name.md`, append to `review.md`, accumulate `all_findings`, reset retries) → loop. On retry
  exhaustion → `review_escalate` gate (skip → `advance_skip` stub / abort → `compile`).
- **`v_object` = the code-enforced PRE-WRITE CHECKPOINT:** asserts a Findings section with valid
  severities (or "No issues found."), checklist coverage == the number of applicable items for the
  object type, and — via a **per-object tool-store window** (`_toolcalls/index.json[cursor:]`) — that
  `analyze_appian_code` ran for *this* object's uuid (and `query_sql` + a SQL section when `needs_sql`).
- **Verdict (Q2=b):** `compile` aggregates findings → scorecard + deterministic **severity floor** →
  `report.json`; `propose_verdict` (agent, no MCP) proposes verdict + rationale; **`v_verdict`** confirms
  a valid enum, non-empty rationale, and **not more lenient than the floor** (stricter is allowed);
  exhaust → `verdict_gate` (human sets the verdict) → `present`.

### Security — read-only by construction
Every agent node declares an explicit per-node `tools=` allowlist of read tools only (`JARVIS_READONLY`
= the 16 namespaced `@jarvis/*` read tools; `fetch_ticket` = `[@jira/get_jira_issue]`). `jarvis` carries
no registry allowlist, so effective trust = node.tools (ADR-029) — the workflow cannot create/deploy, so
**no `pre_mutation` gate** is needed. Verified structurally by the reliability lint + the effective-trust
computation.

## Decisions & deviations
- **ADR-029 per-node cap chosen over a registry cap (Q1)** so future write/deploy workflows keep Jarvis's
  mutating tools.
- **Reliability-lint deviation from the spec:** ADR-011's trio is CI-enforced on *every* agent node, so
  `kb_check` and `kb_preanalysis` were given **lenient validators** (the spec's §6.8 "no validator" note
  would have failed the lint). KB pre-analysis stays effectively best-effort (its validator only checks
  `review.md` survived).

## Two build fixes worth remembering
1. **Removed `from __future__ import annotations` from graph.py.** The loader imports graph.py standalone
   (`spec_from_file_location`, **not** registered in `sys.modules`), so LangGraph's `get_type_hints()`
   could not resolve the stringized `Annotated[list, add]` reducer keys on `CodeReviewState`
   (`NameError: Annotated`). Eager (non-`__future__`) evaluation stores real `Annotated` objects and
   fixes it — this would have failed at real runtime too, not just in tests.
2. **Quoted `"Stale?"`** in `workflow.yaml` — a `?` in a YAML flow-scalar (`{label: Stale?, ...}`) breaks
   the parser.

## Live-run hardening (v0.5.1 → v0.5.3)

The first live runs against a real JIRA ticket (**GAMS-9256**) surfaced real tool-output shapes the
stubbed tests couldn't. Each fix was verified against the actual run artifacts under
`~/Genesis/runs/code-review/<run>/` and synced into the installed `~/.genesis/library` for immediate
effect (no server restart needed — the worker re-imports graph.py per run).

- **v0.5.1** — run `r-69a92cf7edf4` escalated at `fetch_package` (`v_package`: "parsed to zero
  objects"). `get_package_contents_from_url` returns JSON **wrapped in a text preamble**
  (`Package Contents from URL: …\n\n[…]`) and each object's `type` is an Appian **QName**
  (`{http://www.appian.com/ae/types/2009}Interface`) with a separate `typeId`. Added `_coerce_json`
  (strip preamble + extract outer JSON) and `_local_type` (QName→local name, typeId fallback); made
  the JSON doc-readers tolerant. Verified on the real `package.json`.
- **v0.5.2** — run `r-2382da6e4169` escalated at `fetch_context` (`v_context`: "checklist items must
  carry a 'severity'"). Live `get_review_checklist` is **3-level nested**
  (`parentCategory → categories → checkListItems`, **112 items**) and `applicableObjectTypes` uses
  **display names** ("Expression Rule" vs my "ExpressionRule"); `jarvis_config` nests
  `appUuid`/`kbFolderId`/`reviewDocFolderId` under `applications[].appConfig`, with `globalSettings`
  a **list**. Added `flatten_checklist`, `_type_key`/`item_applies` (normalized matching, incl.
  Decision↔DecisionRule alias), `_pick_appconfig` (match by app_info uuid, else object-name prefix)
  and `_primary_db`. Wired into `check_context`, `count_applicable`, the review prompt, `check_object`,
  and `_validate_app`. Verified live: 112 items flatten, applicable-to-Interface=75, `check_context`
  passes, `_pick_appconfig` finds AS_GSS (uuid + kbFolderId 1619984).
- **v0.5.3** — proactive audit ("check the other validators too"). Found the **systemic** gap:
  validators consuming `validator_node`'s `data` (a plain `json.loads` that falls back to raw text)
  weren't preamble-robust. `check_ticket`/`check_kb_stale`/`check_verdict` now coerce. Also made
  `v_object`'s `analyze_appian_code` detection tolerant of the uuid arg name
  (`object_uuid`/`uuid`/`object_id`, or the uuid anywhere in the recorded input), since the tool-store
  `raw_input` shape can't be confirmed until the loop runs. Verified the full Path-A pre-loop chain
  against live artifacts (reference_date from a real status transition, package URL, assignee, app
  record). 18 code-review tests, 7-gate CI, ruff clean.

**Lesson:** jarvis MCP tools are inconsistent — some wrap JSON in a human-readable preamble
(`get_package_contents_from_url`, `get_application_info`), others return clean JSON
(`get_jira_issue`, `get_review_checklist`); nested/QName/display-name shapes differ from the obvious
assumptions. Every consumer of a saved tool output must parse defensively (coerce + normalize).

**Still un-exercised against live data** (no run has reached the per-object loop yet): `v_object`'s
parse of the agent's `object_review.md` structure and the real `analyze_appian_code` `raw_input`
shape; `v_verdict` against a real agent `verdict.json`. Hardened defensively; confirm on a live loop run.

## Verification
- **13 code-review tests** (`tests/test_workflow.py`): pure functions (typeId/needs_sql, parse+queue
  sort/filter, reference-date 3 fallbacks, package-url extract, severity floor + verdict-meets-floor,
  count_applicable + parse_object_doc); `v_object` (pass / analyze-missing / wrong-coverage) and
  `v_verdict` (valid / lenient-below-floor / bad-enum / empty-rationale); a **full stubbed 2-object
  Path-B run** → verdict Approved + `review.md` with both object sections + Scorecard + Verdict; a
  **forced-failure** object → retry to exhaustion → `review_escalate` interrupt → resume "skip" →
  finish + verdict; per-object retry reset.
- **All 22 genesis-workflows tests pass**; `ci/validate_library.py` 7-gate **PASSED (3 workflows)**
  (contract parity + reliability lint + the non-compliant fixture still correctly fails); ruff clean.
- genesis **CI #6344231 ✅** (v0.20.2). genesis-workflows **v0.5.0 CI #6344394 ✅**.

## Not done / follow-ups
- **Live run** against a real GAMS ticket + package (needs `genesis serve` restart on ≥ v0.20.2 and the
  jarvis/jira secrets, which the user has connected). Confirm per-object findings, checklist counts, SQL
  checks, the diff baseline rule, and metered credits per object.
- SQL dialect is exercised against one dialect only (MariaDB/PostgreSQL branch documented, R6).
- Google Docs export remains intentionally out of scope.
