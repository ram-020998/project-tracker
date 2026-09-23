# Phase 42 — Code Implementation (as-built / progress)

> Running as-built record for Phase 42 (the Workbench Implementation lane — Genesis's first
> write-capable stage). Specs: `specs/phase-42-code-implementation.md` (+ `42-01..42-09`).
> ADRs 068/069/070 (Proposed → Accepted at 42-09). **Build in progress — no code repo pushed/tagged
> until 42-09 on the user's go-ahead.** Newest entries at the top.

## 42-01 — Research & ADRs · ✅ LOCKED (docs only)

The findings + frozen contracts + ADR-068/069/070 drafts were authored and pushed to project-tracker
(the spec set). Before starting the build, the load-bearing contract claims were **code-grounded** against
the real repos:

- `genesis/domain/transitions.py` — `STORY_STAGE_TRANSITIONS` declares `(DESIGN_REVIEW,"approve")→IMPLEMENTATION`
  and `(IMPLEMENTATION,"submit-review")→CODE_REVIEW`; `STORY_LANES` includes both lanes. ✓
- `genesis/kb/story_stages.py` — `StoryStageStore.VALID_STAGES == ("design",)` (42-05 adds `'implementation'`;
  TEXT column, no schema change). ✓
- `genesis-workflows/mcp-registry.json` — `appian-dev` is `mode:"read-only"`; its allowlist already contains the
  verify tools (`validateDesignObject`/`validateExpression`/`testInterface`/`testProcessModel`/`testRule`/
  `runExpressionRuleTestCase`/`runAllExpressionRuleTestCases`/`runInterfaceTestCase`/`runAllInterfaceTestCases`)
  and the rollback tools (`listObjectVersions` + all `get*`). So workflow steps 2 (rollback) & 4 (verify) need
  NO new grant — only step 3 (implement) needs a write entry. No `appian-dev-write` existed yet. ✓
- `genesis-core/genesis_core/mcp/registry.py` — `is_managed`/`_managed_launch` resolve `"managed":"<id>"` to the
  installed per-server venv launch spec; `allowlist()` reads `tool_allowlist`; effective trust = `node.tools ∩
  server.allowlist`. So a write entry with `"managed":"appian-dev"` reuses the SAME binary (no second install). ✓

**One contract gap surfaced by the verification (to resolve in 42-05):** the reverify **SEND_BACK** path needs to
move the card `implementation → design-review`, but `STORY_STAGE_TRANSITIONS` has no such edge (only
`implementation→submit-review→code-review`). Recommendation: add `(IMPLEMENTATION,"send-back"):DESIGN_REVIEW`
so the finalizer's send-back move stays audited via `LifecycleService` (no raw status writes). Pending the
user's action-name confirmation; folded into 42-05's domain work.

## 42-02 — Dev-MCP write enablement (`appian-dev-write`) · ✅ BUILT (local; independent review = SHIP)

**Repo:** genesis-workflows (local commits `e5e1260` + `bc92a09`; **unpushed**, no tag). Implements ADR-068;
relaxes ADR-038's read-only allowlist for this one write-scoped entry.

- **New registry entry `appian-dev-write`** (`mcp-registry.json`): reuses the SAME managed-native binary as
  `appian-dev` (`"managed":"appian-dev"` → resolved to the installed per-server venv; **no second install**,
  same process contract), `mode:"read-write"`, dev-env creds via ADR-048 (`${LCP_URL}` + basic
  `${LCP_USERNAME}`/`${LCP_PASSWORD}`; `secretKeys`/`publicKeys` empty). It is **injected only by the
  `story-implementation` implement/heal nodes** (42-04) — never chat / KB grounding / the design workflow;
  `appian-dev` stays literally read-only (defense in depth; `node.tools ∩ server.allowlist`).
- **Allowlist = the exact 60 write tools** — all **20 CREATE + 40 UPDATE** tools of Dev MCP 26.6.90
  (enumerated from the installed source `/tmp/devmcp2669/src/lcp_mcp_server/tools`, `action_type ∈ {CREATE,UPDATE}`),
  incl. `updateObjectSecurity`. **NO DELETES EVER (Q3):** zero `delete*`-named tools — the 23 object `delete*`
  tools are excluded, **and the UPDATE-tagged but delete-named `deleteProcessModelNode` is excluded too** (the
  `delete*` guard). Session `logout` (DELETE bucket) also excluded. A design that retires an object → `updateX`
  setting the description "deprecated by Genesis — <ticket>", never a delete.
- **Judgment call flagged:** `completeTask` (a runtime task action, `action_type=UPDATE`) is **included** to honor
  the locked "all create/update except delete" decision (Q11); flagged in the entry `note` + here for 42-08 to
  tighten if design-object scope is preferred (review SHOULD-FIX b).
- **Guard test** `workflows/story-implementation/tests/test_write_registry.py` (+4 tests): the entry exists /
  managed-reuse / `read-write`; the allowlist is **exactly** the pinned 60-tool set (drift fails consciously —
  review SHOULD-FIX a applied); **zero `delete*` tools** (mutation-tested — injecting `deleteInterface` fires the
  assertion); `deleteProcessModelNode`/`logout` excluded; `appian-dev` stays read-only (get/list/run/test/validate
  only). (The `story-implementation/` package is otherwise created in 42-04; `validate_library`'s `_iter_workflows`
  skips a dir without `graph.py`, so the catalog is unaffected.)
- **Independent review = SHIP** (sub-agent auditor): exact 60-tool match verified against the installed bundle
  (MISSING=∅, EXTRA=∅, delete-leak=∅), write isolation confirmed, gates re-run green. No MUST-FIX. SHOULD-FIX (a)
  applied; (b) deferred to 42-08.
- **Gates:** `validate_library` = 12 workflows; `pytest -q workflows` = **188 passed** (184 + 4). ruff n/a (JSON + test).

## 42-03 — Workflow-node skill provisioning (ADR-069, option B) · ✅ BUILT (local; independent review = SHIP)

**Repos:** genesis-core (local `4d7b3d3`) + genesis (local `1148545` + `4efbeb3`); **unpushed**, no tag. Option **B**
(the genesis-core primitive) chosen by the user. Implements ADR-069 (extends ADR-034 skills beyond chat).

- **genesis-core** `kiro_node(skills=[...])` (additive; `CORE_MAJOR` unchanged = 1): before the turn, `_provision_skills`
  copies each declared skill's directory into the run's **`<cwd>/.kiro/skills/<id>/`** (kiro-cli auto-discovers it), so a
  workflow node runs WITH the skill deterministically — not relying on the host's global `~/.kiro/skills`. Source resolved
  via **`ctx.extras['skill_source'](id) -> path|None`**. **Fail-fast** if the provisioner is unwired or a declared skill is
  unresolvable (never silently run without the domain rules — the "workflow not installed" 409 lesson). **Never sets
  `KIRO_HOME`** (§7); **path-traversal-safe** (`_SKILL_ID_RE`); writes only into the disposable run workspace; idempotent
  (`copytree(dirs_exist_ok=True)`) across reliability retries. `skills=None` (the common case) is a byte-identical no-op.
- **genesis** `build_context` wires **`ctx.extras['skill_source']`** — searches the managed `settings.skills_dir` first, then
  the global `~/.kiro/skills` (where the global `appian` skill lives); returns None if absent (core fails fast). Defensive
  unsafe-id guard (review S1). Genesis owns the source policy; core does the copy.
- **Skill sources (verified):** `appian` → global `~/.kiro/skills/appian` (present); `appian-object-generation` → a
  genesis-workflows **library** skill, installed into the managed `~/.genesis/.kiro/skills` via `SkillInstaller`. The per-node
  declaration (`appian` on implement/verify/heal; `appian-object-generation` on implement) lands in **42-04** (the workflow).
- **Independent review = SHIP** (sub-agent auditor): additive/behavior-preserving, both fail-fast paths, no `KIRO_HOME`,
  traversal-safe, idempotent, resolver correct, all gates green. Applied SHOULD-FIX S1 (defensive resolver id validation).
- **⚠️ Deploy prerequisite (review S2):** for a live `story-implementation` run, `appian-object-generation` must be installed
  into the managed skills workspace (or present in `~/.kiro/skills`); otherwise the implement node fails fast at launch (correct,
  but a setup step — like `genesis install` for the workflow library). Fold into the 42-09 deploy/live-acceptance notes.
- **Gates:** genesis-core pytest **96** (+5) + ruff clean; genesis pytest **806** (+3) + ruff clean; `validate_library` 12.

## 42-04 — The `story-implementation` workflow ("Ticket Implementation") · ✅ BUILT (local; independent review = SHIP)

**Repo:** genesis-workflows (local `7d152fd`; **unpushed**, no tag). Genesis's FIRST write-capable workflow (ADR-068);
reuses `attach_healing` (ADR-067), the reliability trio (ADR-011), `appian-dev-write` (42-02), workflow-node skills (42-03).

- **Graph:** `resolve_inputs → load_inputs → reverify_design →(gap) escalate_reverify(PROCEED_ANYWAY|SEND_BACK) →
  prepare_rollback → implement → verify → [attach_healing: verify→heal→{patch→reassemble→re-verify | 1 guided restart of
  implement | escalate}] → author_wiki → persist_wiki (off-loop) → render_report → present → cleanup`. Reliability trio on
  every agent; `attach_healing` bounded `{max_heal:1, max_restart:1}` (`META.healing`); `recursion_limit` 250.
- **Write-safety (the headline):** `appian-dev-write` (+ the `appian`/`appian-object-generation` skills) injected **only** on
  `implement` + `heal` (`NODE_MCP`/`NODE_TOOLS`); every other node read-only; `author_wiki` has `mcp=[]`. **No node has any
  `delete*` tool**; the graph `WRITE_TOOLS` **equals** the appian-dev-write registry allowlist (60, zero delete — a guard test);
  the implement/heal prompts carry the deprecate-in-description rule; `check_implementation` **rejects `action=="deleted"`** and
  requires a terminal status per object (triple defense).
- **Fail-safe reverify gate:** only `PROCEED_ANYWAY` proceeds to writes; ambiguous / missing / reject / `SEND_BACK` → send back
  to Design Review (`present_sendback` writes a `send_back` marker the finalizer reads). Never auto-writes on an unclear decision.
- **Off-loop DB write:** `persist_wiki` is a **raw async node** using `asyncio.to_thread` (the §7 deadlock lesson — like
  sync-application's `write_kb`), and **degrades gracefully** until `ctx.extras['object_wiki']` is wired (42-06): `wiki.json`
  always remains in the blackboard. The `StoryImplementationFinalizer` does **not** persist the wiki → no double-persist.
- **Deterministic:** `render_report` builds `implementation-report.html` from `implementation.json` + `verify.json`; `cleanup`
  preserves every declared artifact (rollback / report / implementation / wiki / result).
- **Independent review = SHIP** (sub-agent auditor): all 10 dimensions verified (no-delete triple-guard, write isolation,
  attach_healing wiring, fail-safe gate, off-loop persist, parity/catalog, tests, gates). No MUST-FIX.
- **Carry-forward SHOULD-FIX:** (a) `completeTask` / data / security writes in the allowlist are broader than pure
  design-object create/update — 42-08 to reconsider `completeTask` (Q11-locked, all non-delete). (b) **Wiki entry idempotency on
  a full workflow re-launch** — `ObjectWikiStore.append_entry` should dedupe by (story, object) in 42-06 (within a single run
  persist_wiki runs exactly once, so no in-run double-append).
- **Gates:** `validate_library` **13** (reliability trio + META↔yaml parity + catalog all green for the new workflow);
  `pytest -q workflows` **212** (+28: 24 workflow + the 4 registry guards from 42-02).

## 42-05 — Platform backend (genesis) · ✅ BUILT (local; independent review = SHIP)

**Repo:** genesis (local `92ea722`; **unpushed**, no tag). Mirrors the Phase-34 design-lane backend
(`start_design` + `StoryDesignFinalizer` + the audited STORY `LifecycleService`).

- **m0021** (`current_version` 20→21; additive/idempotent): `wiki_object_pages` (one per object: summary +
  `latest_entry_id` pointer + m0019 collab cols `sync_uuid` UNIQUE/`row_version`/provenance; `UNIQUE(app_uuid,
  object_uuid)`) + `wiki_object_entries` (**append-only**; FK→pages `ON DELETE CASCADE`; `change_kind`
  created|updated|deprecated; business + technical descriptions; story ref + bug flag; object version; **no
  source code — ADR-037 holds**). Registered in `migrations/__init__`; a fresh DB migrates to **v21** with both
  tables (verified). Bumped every `current_version==20` head assertion (test_db/chat/collab_migration/board/
  document/feature/kb/stage stores) + the migration-count + synthetic-next (→v22) tests.
- **`StoryStageStore.VALID_STAGES += 'implementation'`** (TEXT column, no schema change).
- **`ObjectWikiStore`** (`kb/object_wiki.py`, exported): `upsert_page` (idempotent, `sync_uuid` preserved on
  rename), `append_entry` (**append-only**, advances the page pointer/summary in one tx, **deduped by (page,
  story_key)** so a full workflow re-launch never double-appends — the 42-04 review carry-forward), `list_for_app`
  / `get_page` / `list_entries` / `get_object_history`.
- **Audited send-back edge:** `domain/transitions.py` gains **`(IMPLEMENTATION,"send-back")→DESIGN_REVIEW`** (the
  edge surfaced in 42-01) so the finalizer's send-back is a `LifecycleService.transition` (m0013 audit), not a raw
  status write. `(IMPLEMENTATION,"submit-review")→CODE_REVIEW` was already present.
- **`StoryImplementationFinalizer`** (`chat/story_implementation_finalizer.py`) — a RunManager observer bound to
  `story-implementation`, no completion chat (unattended). On `run.final{done}` it reads `result.json.decision`:
  **implemented** → copies the durable artifacts (`implementation-report.html` + `rollback.md` +
  `implementation.json`) out of the disposable blackboard into the story-stage dir, binds + completes the stage,
  and advances `implementation→code-review` (audited `submit-review`); **send_back** → `implementation→design-review`
  (audited `send-back`). Bound-run guard + **lane-guarded idempotency** (the lane move is the sentinel — no chat
  marker) + on-read `reconcile_story_stage` (returns True only when it moved the lane). A done run with neither a
  report nor a send-back leaves the card in Implementation (light-red + run link); a broad guard keeps
  finalization from ever crashing the reader thread.
- **Endpoints (`api/workbench.py`):** `POST …/implementation/start` mirrors `start_design` — fail-fast **409** on
  no dev env / app not synced / no completed design (`in-review`|`completed`) / no feature Technical Design /
  workflow-not-installed (`FileNotFoundError`→409, not 500); snapshots design.html + the TD; moves the card to
  `implementation`; launches bound to a `stage='implementation'` row; `reset_for_rerun` on a re-drag. `GET
  …/implementation/report` = the read-only review surface (report + rollback + per-object result + run info; no
  chat, no Lavish). Board card DTO gains `implementation_run_id`/`_status`/`_story_stage_id` (LEFT JOIN the
  implementation stage + `runs`); `_maybe_recover` extended to implementation cards. Finalizer wired in `app.py`.
- **Independent review = SHIP** (sub-agent auditor): all 9 dimensions verified (migration additive + every test
  bump, append-only + dedupe, audited transitions + bound-run guard + sound lane-guard idempotency + on-read
  recovery, fail-fast start matrix, read-only review surface, no code stored, gates). No MUST-FIX. SHOULD-FIX:
  (a) the report endpoint isn't lane-gated (read-only + harmless — returns empty for a sent-back stage; the DTO
  drives the UI link visibility) → fold into 42-07/42-08; (b) confirmed the `result.json.decision` contract
  matches the 42-04 `present`/`present_sendback` outputs.
- **Gates:** genesis **pytest 829** (+ the m0021 bumps + `test_object_wiki.py` + `test_story_implementation.py`)
  + ruff clean; fresh-DB migrate → v21 with the wiki tables verified.

## Next

42-06 — Object Wiki collaboration bindings + the Genesis Hub record type: add `wiki_page` + `wiki_entry` to
`CollaborationService._BINDINGS` (`wiki_page` parented on the global `app_uuid`; `wiki_entry` parented on
`wiki_page` via `_ParentRef`, append-only) with publish/pull + autopull integration; **wire
`ctx.extras['object_wiki']` (+ an `object_wiki_publish` callable) in `build_context`** so the workflow's
`persist_wiki` node activates (it degrades gracefully today); freeze the **Genesis Hub `GH Object Wiki
Page`/`GH Object Wiki Entry` record-type contract addition** (+ fixtures) in
`specs/phase-36-genesis-hub-appian-app/contract/` for the separate write-capable Appian agent (ADR-064
additive); the binding guard test (every `_BINDINGS` kind is a real contract kind) + a LocalHubProvider
round-trip.
