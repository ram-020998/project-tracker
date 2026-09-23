# 42-01 — Research, findings & ADR drafts (locks the contracts before the build)

> **Status:** 🟡 DRAFTED (docs only). Gate: ⭐ user sign-off → build. Parent: `specs/phase-42-code-implementation.md`.
> **Deliverable:** the code-grounded findings that back Phase 42 + the frozen contracts (data model, write allowlist, workflow I/O, finalizer/lifecycle, review-surface API) + the drafts of **ADR-068/069/070**. No code.

## 1. Dev MCP 26.6.90 write surface (verified against the installed bundle)

- The bundle (`/Users/ramaswamy.u/Documents/appian-dev-mcp/26.6.90/appian-dev-mcp-server-bundle.tar.gz`) registers **157 tools** via `FastMCP`, each `@mcp.tool(meta={"object_type": …, "action_type": "GET|CREATE|UPDATE|DELETE"})`. Tool modules: `interfaces · record_types · expression_rules · process_models · constants · web_apis · sites · connected_systems · integrations · folders · groups · documents · portals · record_data · ai_agents · ai_skills · applications · robotic_tasks · objects · validation · test_rule · diagnostics · expression_fixups · session`.
- **No server-side readonly gate.** `LCP_TOOL_MODE=readonly` is documented by Appian but **not implemented in 26.6.90** — all tools are always registered. **The only cap is Genesis's `tool_allowlist` × the node's `tools=`** (`node.tools ∩ server.allowlist`, ADR-029). → Write is enabled purely on the Genesis side (42-02).
- **Write tools present (create/update; a `delete*` per type — EXCLUDED by us):** `createInterface`/`updateInterface`; `createRecordType`/`updateRecordType` (+ `updateRecordTypeField`/`updateCustomRecordField`/`updateRecordTypeRelationship`/`updateRecordTypeAction`/`updateRecordTypeView`/`updateRecordTypeUserFilter`); `createExpressionRule`/`updateExpressionRule` (+ test-case create/update); `createConstant`/`updateConstant`; `createProcessModel`/`updateProcessModel`/`createProcessModelNode`/`updateProcessModelNode`; `createWebApi`/`updateWebApi`; `createSite`/`updateSite`; `createConnectedSystem`/`updateConnectedSystem`; `createIntegration`/`updateIntegration`; `createFolder`/`updateFolder`; `createGroup`/`updateGroup`; `createApplication`/`updateApplication`; `updateRecordData`; `updateObjectSecurity`; `publishPortal`/`createPortal`/`updatePortal`. **All `delete*` tools are deliberately excluded (Q3 — no deletes).**
- **Verify tools (already in the read allowlist):** `validateDesignObject`, `validateExpression`, `testInterface`, `testProcessModel`, `testRule`, `runExpressionRuleTestCase`, `runAllExpressionRuleTestCases`, `runInterfaceTestCase`, `runAllInterfaceTestCases`. → step 4 needs no new grant.
- **Rollback-doc tools (already allowlisted):** `listObjectVersions` (Phase-41 addition) + the `get*` definition tools (`getInterface`/`getExpressionRule`/`getProcessModel`/`getRecordType`/…) — fetch current code + version. → step 2 needs no new grant.
- **Object version fields** exist on the SDK models ("...regenerated on every request to prevent stale writes") → the Dev MCP enforces **base-version stale-write protection** on updates (our per-object concurrency safety comes free).

## 2. Skills mechanics (verified)

- `kiro_node` runs with `cwd = ctx.workspace.root` (the run blackboard). kiro-cli auto-discovers skills from `<cwd>/.kiro/skills/` + global `~/.kiro/skills/`.
- The global **`appian`** skill (`~/.kiro/skills/appian/SKILL.md`) = "MANDATORY skill for Appian MCP tool usage" — naming conventions, relationship rules (both sides), data-modeling patterns, dependency order, UUID handling, and a strict **deletion-confirmation** workflow (aligns with our no-delete stance). The library **`appian-object-generation`** skill (`genesis-workflows/skills/appian-object-generation`) = "create/update real Appian design objects … via the lcp-mcp-server MCP tools, with a validate-then-iterate loop" — the implement skill.
- Genesis provisions skills **only into the chat workspace** (`~/.genesis/.kiro/skills/`), not into a workflow run (ADR-034 deferred workflow-node skills). → **42-03 builds the provisioning** (ADR-069).

## 3. Object Wiki pattern research → the model (ADR-070)

- **MediaWiki:** a `page` per subject + an **append-only `revision`** stream + `page.latest`. **Data dictionary vs business glossary:** technical reference (structure) vs plain-language business meaning → the user's **technical vs business** description split. **Append-only audit ledger:** one immutable row per event.
- **Synthesis (locked):** `wiki_object_pages` (one per object, mutable pointer/summary) + `wiki_object_entries` (append-only, one per change; business + technical description; `change_kind` created|updated|deprecated; story ref + bug flag; author; timestamp; object version). No code stored. Append-only entries publish once → conflict-free sync.

## 4. Frozen contracts (locked here for the build)

- **Data model:** m0021 as in the umbrella §5 (`current_version` 20→21).
- **Write allowlist:** `appian-dev-write` = every `create*`/`update*` above (all object types) + `updateObjectSecurity`; **zero `delete*`** (42-02 finalizes the exact list per module).
- **Workflow I/O:** `story-implementation` inputs `{story_id, feature_id, app_uuid, story_stage_id, design_path, techdesign_path, story}`; artifacts `reverify.json`, `rollback.md` (local), `implementation.json`, `verify.json`, `heal.json`, `wiki.json`, and the human-readable `implementation-report.html`.
- **Finalizer/lifecycle:** `StoryImplementationFinalizer` on `run.final{done}` → bind artifacts + set the story-stage `completed` + advance the lane `implementation → code-review` via `LifecycleService.transition(EntityKind.STORY, id, "submit-review", actor=…)` (m0013). No completion chat.
- **Review-surface API:** `GET /api/workbench/boards/{app_uuid}/cards/{story_id}/implementation/report` → `{report_html, rollback_md, run_id, run_status, objects:[…]}`; served for Implementation + Code-Review cards.

## 5. ADR drafts

Draft **ADR-068** (write-capable implementation lane), **ADR-069** (workflow-node skill provisioning), **ADR-070** (the Object Wiki) — text in `reference/decision-log.md` (Proposed). They amend ADR-021/036/037/038 and supersede ADR-062's proposal-only clause for this lane; extend ADR-034; reuse ADR-063/064/065/067/050/061/062.

## 6. Gate

User sign-off on this findings + contract set → proceed to 42-02. No code until then.
