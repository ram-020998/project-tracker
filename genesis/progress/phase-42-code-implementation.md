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

## 42-06 — Object Wiki: collaboration bindings + the Genesis Hub record type · ✅ BUILT (local; independent review = SHIP)

**Repos:** genesis (local `1b6e8f0`; **unpushed**, no tag) + the Genesis Hub contract addition (docs, pushed —
for the separate write-capable Appian agent). Implements ADR-070; reuses the ADR-063 collab substrate.

- **Collab bindings (`collab/service.py`):** added `wiki_page` + `wiki_entry` to `_BINDINGS`. `wiki_page` →
  `wiki_object_pages`, **no parent** (round-trips on the global `app_uuid`, like `feature`). `wiki_entry` →
  `wiki_object_entries`, **append-only**, parented on its page via a single `_ParentRef(page_id →
  page_sync_uuid, parent_kind="wiki_page")` — the exact cross-machine resolution `stage_artifact`/`story` use
  (publish page first; a pull skips an entry until its page is present, then retries). The optional
  `story_sync_uuid` rides as a plain shared column. **No-leak:** the machine-local `latest_entry_id` page
  pointer was added to `_LOCAL_ONLY`, so it is excluded from both publish and pull (a pulled mirror's pointer
  stays NULL — never a dangling id); `id`/`row_version`/`published_*` were already excluded. New helpers
  `publish_object_wiki_page(page_id)` (page then its entries) + `publish_object_wiki(app_uuid)`. Both providers
  are already generic over `kind`, so **no provider change** was needed.
- **`build_context` wiring (`runtime/context.py`):** `ctx.extras['object_wiki'] = ObjectWikiStore(db_path)`
  (signatures match the 42-04 `persist_wiki` calls exactly) + `ctx.extras['object_wiki_publish']` — a
  best-effort, **offline-tolerant** callable that lazily builds a `CollaborationService` (via
  `build_sync_provider`) and **no-ops unless enabled + available + onboarded**, and **never raises**. This
  **activates** the 42-04 workflow's `persist_wiki` node (which degraded gracefully until now). **Local-first,
  no hard Hub dependency (Q14):** the local wiki write always succeeds; publishing is opt-in.
- **Genesis Hub contract addition** (`specs/phase-36-genesis-hub-appian-app/contract/object-wiki-contract-addition.md`
  + fixtures `object_wiki_page.json` / `object_wiki_entry.json`): **additive to the frozen v1.0.0 contract**
  (ADR-064 amendment, like the v0.69.0 `on_board` field). Two new record kinds `wiki_page` + `wiki_entry`
  served by the **existing generic** `/records/{kind}` + `/changes` endpoints — **no new Web API**. Field
  tables = the m0021 columns minus `latest_entry_id`; `business_description`/`technical_description` are
  Extra-Long Text (2 of the ≤3 budget); **no blobs** (descriptions are inline). Built Appian-side by the
  separate agent; a live round-trip is appended to the 36-06 harness.
- **Independent review = SHIP** (sub-agent auditor): all 8 dimensions verified (bindings reuse the proven
  mechanism, no-leak incl. no other leaking int columns, exact persist_wiki contract match, best-effort +
  onboarded-guarded + worker-safe lazy import, additive contract + self-consistent fixtures, the extended
  binding guard, gates). No MUST-FIX. SHOULD-FIX (pre-existing in the 42-04 workflow, deferred to 42-08): the
  `persist_wiki` node passes `author_username=None`/`story_sync_uuid=None` + an unused `envs` local — populate
  attribution/story-linkage from the run inputs later.
- **Tests:** `tests/test_object_wiki_collab.py` (LocalHubProvider two-instance round-trip incl. unicode; the
  append-only entry skips until its page is present; the no-leak of `latest_entry_id`/`id`/`row_version`; the
  publish helpers) + extended `test_binding_kinds_match_the_hub_contract` to the two additive kinds (the §7
  "stub hid the contract" guard). **genesis pytest 836** + ruff clean.

## 42-07 — Web: drag confirm + card run-states + the read-only review surface · ✅ BUILT (local; independent review = SHIP)

**Repo:** genesis (local `4010000`; **unpushed**, no tag). Frontend-only; mirrors the Phase-34 design-lane web.

- **Drag-into-Implementation confirm** (`BoardPage.tsx`): dragging a card into `implementation` from another
  lane opens a `StartImplementationDialog` (the **single blanket approval**, Q1) whose copy makes explicit it
  **writes every object change to the live dev environment**. Yes → `useStartImplementation` (POST
  `…/implementation/start`); No/dismiss → just move (revert the optimistic mirror). An intra-lane reorder
  never triggers it.
- **Card run-states** (`StoryCard.tsx` + `types/workbench.ts`): a running implementation **locks** the card
  (non-draggable) + shows "Implementation running" + a run link; a failed run paints it light-red + shows the
  run link (reuses the Phase-34 states; `isImplementationRunning` covers pending/running/awaiting_input:*,
  `isImplementationFailed` covers failed/cancelled).
- **Read-only review surface** (`ImplementationReviewWorkspace.tsx`, on the existing
  `/workbench/:app/cards/:id` route via `StoryCardPage`): reachable from a card in **Implementation OR Code
  Review** (Q16). Shows the per-object result table (name/type/action/version/status), the deterministic
  implementation report in a **sandboxed (`sandbox=""`, no-script, XSS-safe) iframe**, and the rollback
  document via `MarkdownView` — **no chat, no Lavish, no editing**. Running → running panel; failed-without-
  report → failed panel + run link. `useImplementationReport` is disabled while the run is active.
- **Plumbing:** `types/workbench.ts` (implementation fields + helpers + `ImplementationReport`/`ImplObject`);
  `lib/api/workbench.ts` (`startImplementation` + `implementationReport`); `lib/query/keys.ts` (the report
  key); `hooks.ts` (`useStartImplementation` mirroring `useStartDesign` + `useImplementationReport`).
- **Independent review = SHIP** (sub-agent auditor): all 6 dimensions verified — drag-confirm parity + informed
  approval, card lock, read-only + sandboxed-iframe (no XSS), api/hooks/keys correct, jest-axe, gates, and the
  **stale-bundle guard clean** (`git status -- web/static` empty after a fresh build). No MUST-FIX / SHOULD-FIX.
- **Gates:** eslint **0 errors** (20 pre-existing warnings), `tsc` clean, **vitest 276 passed** (37 files;
  +13 workbench incl. the review-surface render/running/axe + the impl run-state helpers), `npm run build` OK;
  `web/static` rebuilt + committed.

## 42-08 — Code review & hardening · ✅ DONE (local; whole-phase review = SHIP-WITH-MUST-FIX, MUST-FIX applied)

**Repos:** genesis-workflows (local `d5b4c19`) + genesis (local `ecb8e0c`); **unpushed**, no tag.

- **Independent whole-phase write-safety review** (sub-agent auditor) across all three repos against the 42-08
  §1 checklist. Verdict **SHIP-WITH-MUST-FIX**; every gate green at review time (genesis pytest 836, genesis-core
  96, genesis-workflows validate_library 13 + pytest 212, web tsc + vitest 276, fresh DB → v21). All checklist
  items PASS: no-delete triple-guard, write isolation, single-blanket-approval, fail-fast prereqs, finalizer
  correctness (bound-run + lane-guard + audited transitions; result.json contract matches), reliability trio +
  attach_healing {1,1}, migration, wiki append-only + no-leak + no-code-stored, skills fail-fast, KB honesty,
  web read-only + sandboxed iframe.
- **MUST-FIX applied — least-privilege write surface (60 → 55):** the review found the allowlist granted 5
  writes that are **not design-object authoring** and exceed the Q11 "object types (create/update; no delete)"
  scope — **removed** `completeTask` (runtime task instance), `insertRecordData`/`updateRecordData` (business
  row data), `addGroupMembers`/`removeGroupMember` (security principals). Updated `mcp-registry.json` (+ note),
  the graph `WRITE_TOOLS`, the pinned guard test (**55**) + a new `test_write_allowlist_excludes_non_authoring…`
  guard, and the workflow `WRITE_TOOLS` count. The retained 55 only author/configure/deploy design objects
  (incl. `updateObjectSecurity`, portal publish, document content — all object-lifecycle, not runtime/data).
- **SHOULD-FIX applied:** (a) **report-endpoint lane gate** — `GET …/implementation/report` is now scoped to
  the **Implementation + Code Review** lanes (Q16); any other lane 404s (the rollback doc stays local/temporary).
  (b) **persist_wiki attribution** — `build_context` exposes `ctx.extras['actor']` (canonical username,
  offline-safe) and `start_implementation` carries the story's `sync_uuid`; the workflow's `_persist_wiki_sync`
  now stamps each Object-Wiki entry's `author_username` + `story_sync_uuid` (were NULL) and drops an unused
  local. (c) refreshed the stale `workbench.py` module docstring (it now hosts the write-capable lane).
  NICE-TO-HAVE (keyless-story dedupe) is a non-issue — design stories always carry a key.
- **Gates (post-hardening):** genesis-workflows `validate_library` **13** + pytest **213** (+1 guard); genesis
  pytest **837** (+1 lane-gate test) + ruff clean; genesis-core ruff clean (untouched in 42-08); web unchanged.

### Live-acceptance procedure (headless-undrivable — user-driven, the 42-09 pre-release gate)

Because this is Genesis's first capability that **writes to a customer Appian env**, the first live run MUST be
on a **throwaway/sandbox app + story**, reviewed object-by-object:

1. **Deploy prerequisites:** install the workflows library into the target instance (`genesis install --from
   ../genesis-workflows`); ensure the **`appian-object-generation`** skill is installed into the managed skills
   workspace (or present in `~/.kiro/skills`) — otherwise the implement node fails fast at launch (42-03 S2);
   a **dev-tagged environment** with basic-auth creds (ADR-048); the target app **synced** into the KB; the
   story has a **completed Design** + its feature a **Technical Design**.
2. **Run:** drag a design-reviewed ticket **Design Review → Implementation** → confirm the dialog (it states it
   writes to the dev env). Watch the card lock + "Implementation running".
3. **Verify in Appian:** the objects named in `implementation.json` exist + open cleanly; **no deletes** (a
   retired object shows "deprecated by Genesis — <ticket>" in its description). Confirm the reverify escalation
   behaves (a design/TD mismatch → proceed/send-back).
4. **Rollback doc:** open the read-only review surface; **validate the rollback document by hand** (current code
   + object version per UPDATE'd object; NEW → "delete to roll back") before trusting it at scale.
5. **Object Wiki:** confirm the local entries (business + technical descriptions, author, story link) and — if
   collaboration is enabled — that they published to the Hub.
6. **Lane:** the card lands in **Code Review** (or returns to **Design Review** on a send-back). A failed run
   leaves it in Implementation (light-red + run link).

## Next

42-09 — coordinated release (**awaiting the user's explicit go-ahead to push/tag**): tag + push in ADR-019 order
genesis-core → genesis → genesis-workflows (genesis-core moves because 42-03 added the `kiro_node(skills=)`
primitive); the **Appian Genesis Hub** `GH Object Wiki Page`/`Entry` record types built + live-validated by the
separate write-capable agent (additive to the ADR-064 contract; no genesis tag); flip **ADR-068/069/070 →
Accepted** (decision-log + bible §5); update bible §2/§3/§4/§8 + tracker + this progress doc + the stamps; CI
green (clean-install DB → **v21** + `validate_library`); **verify the release commit contains EVERY changed
file before tagging** (the recurring §7 lesson).
