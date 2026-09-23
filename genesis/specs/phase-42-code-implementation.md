# Phase 42 — Code Implementation (the Workbench Implementation lane; Genesis's first write-capable stage)

> **Status:** 🟡 **DRAFTED — specs only; awaiting build go-ahead.** · **Author:** Genesis agent · Created 2026-09-23.
> Umbrella + `phase-42-code-implementation/42-01..42-09`. **New ADRs:** **ADR-068** (write-capable Appian implementation lane) · **ADR-069** (workflow-node skill provisioning) · **ADR-070** (the Object Wiki). These **amend/relax** ADR-021 (pre_mutation), ADR-036/037 (read-only against Appian), ADR-038 (read-only Dev-MCP allowlist), ADR-062 (design proposal-only), and extend ADR-034 (skills beyond chat) + ADR-063/064 (a new Hub-shared entity).
> **Type:** multi-repo — **genesis** (a migration **m0021** + backend + web + the write-registry wiring + the wiki store/API + skill provisioning) + **genesis-workflows** (the `story-implementation` workflow + a new write-scoped MCP registry entry) + the **Appian Genesis Hub** (a new Object-Wiki record type, built by the separate write-capable Dev-MCP agent per ADR-064) + **genesis-core** (only if the workflow-node skill primitive lands in core). · **Depends on:** Phase 34 (the Design/Design-Review lane automation — `story-design-analysis`, m0018 `kb_story_stages`/`StoryStageStore`, `StoryDesignFinalizer`, the drag-confirm board pattern, the audited `LifecycleService` lane transition; ADR-062), Phase 33 (the Workbench board + `STORY_LANES`; ADR-061), Phase 40 (`attach_healing` — the second reliability tier; ADR-067), Phase 41 (Dev MCP **26.6.90** — full CRUD tools + the managed-native install + basic auth + the dev-env credential seam; ADR-038/040 amendment), Phase 35–38 (the collaboration substrate — `SyncProvider`/`CollaborationService`/`_BINDINGS`/publish-pull; ADR-063/064/065), Phase 14 (Skills; ADR-034), Phase 25-01/08 (`LifecycleService` + `STORY_STAGE_TRANSITIONS` + m0013 audit + `row_version` CAS; ADR-050).

---

## 1. Why this phase exists

Everything Genesis has shipped **reads** the Appian environment and **writes documents** — the KB (read-only), the Business Map, the four feature stages (Spec / UX / Technical Design / Feature Breakdown), the finalized stories, the Workbench board, and the story **Design** (proposal-only — "shows the code, never writes it", ADR-062). Genesis is an Appian **SDLC** platform, and the SDLC's centre — **actually implementing the code** — has been deliberately deferred behind a hard read-only posture (ADR-021 `pre_mutation`; ADR-036/037 read-only KB/env; ADR-038 read-only Dev-MCP allowlists; ADR-062 proposal-only) **until a stable Dev MCP made object-level writes safe.** Phase 41 adopted the stable **Dev MCP 26.6.90**, which exposes full object CRUD. **This phase turns the corner: Genesis implements.**

**This is a deliberate, eyes-open contradiction of the read-only areas above.** They were placeholders waiting for exactly this moment; this phase amends them (see §3, §9, and the new ADRs) rather than working around them. It is the **first Genesis capability that mutates a customer's Appian environment.**

**The user-facing flow (mirrors the Phase-34 Design automation, one lane further):** a lead reviews a story's completed **Design** in the **Design Review** lane; when satisfied, they drag the card **Design Review → Implementation**. That drag (with a confirm) is the **single, blanket approval** for all the object changes — from there a backend workflow runs unattended and, on success, moves the card to **Code Review**.

The workflow, in six steps:
1. **Reverify design ↔ Technical Design** — confirm the story's design covers what the feature Technical Design mandates; a mismatch **escalates to the user** (proceed-anyway / send-back).
2. **Prepare a rollback document** (local, temporary) — the current code + object version of every object the design will *update*; new objects noted as "delete to roll back". Elaborate enough for a future agent to execute a rollback (rollback *execution* is a later phase).
3. **Implement** — a **single agent**, armed with the Appian skill(s) + Dev-MCP **write** tools, iterates object-by-object over the whole design and applies the changes to the dev-tagged environment. **No deletes ever** — a design that removes an object instead marks its description "deprecated by Genesis".
4. **Verify** — validate only the objects this run touched (open cleanly, no errors) via the Dev-MCP `validate*`/`test*` tools.
5. **Heal** — on verification failures, a healer writes a healing doc and fixes them, then re-verifies (`attach_healing`, ADR-067).
6. **Update the Object Wiki** — a single wiki-authoring agent writes a **business** description + a **technical** description per affected object; a program persists them locally and publishes to the Genesis Hub. Then the card moves to **Code Review**.

---

## 2. Goal

1. **A write-capable implementation workflow — `story-implementation` ("Ticket Implementation").** Given one story, its **completed design** (Phase-34 `design.html`), and its feature's **Technical Design**, it runs the six steps above against the **dev-tagged environment only**, then moves the card to Code Review. Reliability trio per agent (ADR-011); `attach_healing` for verify→heal (ADR-067); an escalation gate on the reverify mismatch.
2. **Enable Dev-MCP object writes — safely and in isolation.** A **dedicated write-scoped MCP registry entry** (`appian-dev-write`) with a **create/update** allowlist (all object types; **no `delete*`**), injected **only** by the implement node — leaving the shared read-only `appian-dev` untouched for chat / KB grounding / design.
3. **Workflow-node skill provisioning (ADR-069).** A shippable mechanism to inject a Kiro **skill** into a workflow agent session (today skills are chat-only, ADR-034) — the implement/verify/heal agents get the global **`appian`** skill; the implement agent additionally gets **`appian-object-generation`**.
4. **The Object Wiki (ADR-070).** A **local-first, Hub-shared, append-only per-object change ledger**: one page per Appian object + one entry per change (business + technical description, `created`/`updated`/`deprecated`, the originating story + bug flag, author, timestamp, object version) — **no code stored**. Written locally, published to the Hub when available, and kept in sync (pull teammates' entries) — the same publish/pull pattern as features/stories/boards.
5. **Drag-into-Implementation automation + a read-only review surface.** The board drag → a confirm dialog → move + launch; card locked while running, light-red on failure (mirrors Phase 34). A **read-only review surface** (the implementation report + the rollback document + basic info) reachable from the card in **both** Implementation and Code Review.

**Success = a lead drags a design-reviewed ticket into Implementation, confirms, watches the card run (with a run link), and — after Genesis reverifies the design, snapshots a rollback doc, implements every object change in the dev environment, verifies + heals the objects, and writes the Object Wiki — sees the card land in Code Review, where they open a read-only view of exactly what was done and how to undo it.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-23)

Firm inputs, not open questions (from two rounds of Q&A).

1. **No per-object mutation gate.** The **drag into Implementation (confirm dialog) is the single blanket approval**; once it runs, all object changes apply immediately, unattended. (Amends ADR-021.)
2. **Writes target the dev-tagged environment ONLY** (Genesis's single dev env; ADR-048 creds).
3. **No deletes, anywhere.** A design that removes/retires an object is realized by **marking the object's description "deprecated by Genesis" (via update)** — never a delete. The write allowlist **excludes every `delete*` tool**; wiki `change_kind ∈ {created, updated, deprecated}`.
4. **Reverify-design mismatch → escalate to the user** with two options: **proceed anyway** (implement despite gaps) or **send back to Design Review** (abort).
5. **The rollback document is LOCAL + temporary** — never published to the Hub.
6. **No indirect dependents** in the rollback doc — only the objects the design directly updates.
7. **Rollback *execution* is a later phase** — this workflow only *produces* the rollback doc (backlog).
8. **A single implement agent** iterates object-by-object over the whole implementation plan; **healing comes after** verify (not interleaved per object).
9. **Build the workflow-node skill-injection mechanism** (ADR-069) — skills into agent sessions.
10. **A dedicated write registry entry** (`appian-dev-write`), injected only by the implement node.
11. **All object types** in scope for writes (create/update; no delete per #3).
12. **The Object Wiki two-table model** (page + append-only entries; business + technical descriptions) is approved.
13. **A single wiki-authoring agent** reads all the implementations, writes the business + technical descriptions per object, and posts to the Hub.
14. **The wiki is local-first** (same pattern as the other collab entities): write to a **local table**, publish to the **Hub** when available, and **keep it in sync** (pull other users' entries) when the Hub is available. **No hard Hub dependency** — implementation runs whether or not collaboration is enabled.
15. **Agents reading the wiki as grounding/memory → backlog** (a later capability).
16. **A read-only review surface** (implementation report + rollback doc + basic info) reachable from the card in **both Implementation and Code Review**.
17. **Workflow id `story-implementation`**, surfaced as **"Ticket Implementation"**.
18. **This is Phase 42**; new ADRs 068/069/070.

Corrections recorded: **delta sync already exists** (Phase 16-07 / Phase 23 `sync-application mode=delta`, the "Refresh" action) — what's deferred (Q-C) is *auto-triggering* a KB re-sync at the end of an implementation run (backlog).

---

## 4. Current state (what we build on) — code-grounded

- **The Design-lane automation is the exact template (Phase 34, ADR-062).** `genesis/api/workbench.py::start_design` = validate the card is on the board → snapshot the feature's Spec/UX/TD HTML → move the card to the lane → `run_manager.start("story-design-analysis", {...})` bound to a `kb_story_stages` row (m0018) → `story_stages.set_source(run_id)`; fail-fast 409 on no dev env / app not synced / workflow uninstalled. `genesis/chat/story_design_finalizer.py::StoryDesignFinalizer` = a `RunManager` event observer; on `run.final{done}` it opens the completion chat, binds the artifact, sets in-review, and **advances the lane via `LifecycleService.transition(EntityKind.STORY, id, "submit", actor=…)`** (audited m0013) — with a bound-run guard, idempotency, and on-read `reconcile_story_stage` recovery (the §7 orphaned-worker lesson). The board card DTO derives `design_run_status` from the durable `runs` table. **Mirror all of this for `implementation`.**
- **The transition table already declares the edges** (`genesis/domain/transitions.py`): `(DESIGN_REVIEW,"approve")→IMPLEMENTATION`, `(IMPLEMENTATION,"submit-review")→CODE_REVIEW`. So the drag Design-Review→Implementation is the `approve` action; the workflow's terminal lane move Implementation→Code-Review is `submit-review` — both auditable through `LifecycleService`. `STORY_LANES` already includes `implementation` + `code-review`.
- **The per-story artifact store exists (m0018, `StoryStageStore`).** `kb/story_stages.py` (`get_or_create/get/get_for_story/set_html/set_status/set_source/set_chat_session/add_revision/reset_for_rerun`; `VALID_STAGES=('design',)`). **This phase adds `'implementation'` to `VALID_STAGES`** (no schema change — `stage` is TEXT) to store the implementation run + its artifacts (rollback doc, implementation report, verify report); the story's completed **design** lives in the same table at `stage='design'`, and the workflow reads it.
- **Dev MCP 26.6.90 = 157 tools, full CRUD, no server-side readonly gate (Phase 41).** Every tool carries `meta={"action_type":"GET|CREATE|UPDATE|DELETE"}`. `LCP_TOOL_MODE=readonly` is documented by Appian but **not implemented in 26.6.90**, so the ONLY cap on writes is Genesis's per-server `tool_allowlist` × the node's `tools=` (`node.tools ∩ server.allowlist`). The shared `appian-dev` allowlist today lists only `get*`/`list*`/`validate*`/`test*`/`run*TestCase*` (its note literally says *"write is out of scope, Section E"*). **The verify + rollback tools are already allowlisted** — `validateDesignObject`, `validateExpression`, `testInterface`, `testProcessModel`, `testRule`, `runExpressionRuleTestCase`/`runAllExpressionRuleTestCases`/`runInterfaceTestCase`/`runAllInterfaceTestCases`, `listObjectVersions`, and the `get*` definition tools — so steps 1/2/4 need no new grants; only **step 3 (implement)** needs a write entry.
- **`attach_healing` is ready (genesis-core, ADR-067).** `attach_healing(g, *, verify, heal, reassemble, restart_target, nxt, gate, retry_max, max_heal=1, max_restart=1, …)` + `VerificationReport`/`HealDecision` contracts + the per-key-merge `_healing` budget channel. **Reused directly** for verify→heal.
- **The collaboration substrate is ready (Phase 35–38, ADR-063).** `genesis/collab/service.py::CollaborationService` + `_BINDINGS` (feature / stage_artifact / epic / story) + `publish`/`pull`/`pull_all`/`autopull_tick`; `_ParentRef` cross-machine parent resolution; the local-first, publish-when-available, pull-to-sync model; the Genesis Hub frozen contract (`specs/phase-36-genesis-hub-appian-app/contract/`) built by a separate write-capable agent (ADR-064). **The Object Wiki adds two `_BINDINGS` entries + a Hub record type — the same pattern as `story`/`stage_artifact`.**
- **Skills exist but only for chat (Phase 14, ADR-034).** `kiro_node` runs with `cwd = ctx.workspace.root` (the run blackboard), and kiro-cli auto-discovers skills from `<cwd>/.kiro/skills/` + global `~/.kiro/skills/`. The global **`appian`** skill (mandatory Appian-MCP domain knowledge — naming, relationship rules, dependency order, UUID handling, a strict delete-confirmation workflow) and the library **`appian-object-generation`** skill ("create/update real Appian objects via lcp-mcp-server with a validate-then-iterate loop") are exactly what the implement agent needs — but Genesis only *provisions* skills into the **chat** workspace (`~/.genesis/.kiro/skills/`), not into a workflow run. **42-03 builds the workflow-node provisioning** (ADR-069).

**Takeaway:** this phase = one new write-capable workflow + one write-scoped MCP entry + a skill-into-workflow mechanism + the Object Wiki (local table + collab bindings + a Hub record type) + a Workbench implementation-start endpoint + a `StoryImplementationFinalizer` + a read-only review surface + a drag-confirm. The board/lane/finalizer/collab machinery all already exist to mirror.

---

## 5. Data model (m0021) — finalized in 42-01

- **No change to `kb_story_stages`** beyond adding `'implementation'` to `StoryStageStore.VALID_STAGES` (TEXT column). The implementation run/artifacts bind to a `kb_story_stages` row at `stage='implementation'` (`run_id`, `status`, and `html_path`/pointers to the report/rollback docs in the run blackboard).
- **`wiki_object_pages`** — one row per Appian object: `id PK · app_uuid TEXT · object_uuid TEXT · object_type TEXT · object_name TEXT · current_summary TEXT · latest_entry_id INTEGER · created_at · updated_at · sync_uuid TEXT UNIQUE · row_version INTEGER · owner_username · team_uuid · published_by · published_at · published_version · UNIQUE(app_uuid, object_uuid)`.
- **`wiki_object_entries`** — **append-only**, one row per change/iteration: `id PK · page_id FK→wiki_object_pages(id) ON DELETE CASCADE · change_kind TEXT (created|updated|deprecated) · business_description TEXT · technical_description TEXT · story_key TEXT · story_sync_uuid TEXT · is_bugfix INTEGER · change_reason TEXT · object_version TEXT · author_username TEXT · created_at · sync_uuid TEXT UNIQUE · row_version INTEGER · published_by · published_at · published_version`.
- `current_version` **20 → 21**. Every hardcoded `current_version == 20` test bumps with the migration (the §7 lesson); the `clean-install` CI job migrates a fresh DB to **v21**.
- **Design synthesis:** MediaWiki (a page per subject + append-only revisions) × the data-dictionary/business-glossary split (technical reference vs plain-language business meaning) × an append-only audit ledger (one immutable row per change, story-scoped). Append-only entries publish once and never conflict (collab-friendly); the page carries the mutable pointer/summary.

---

## 6. The workflow `story-implementation` — finalized in 42-04

```
START → resolve_inputs (fail-fast: dev env + app synced + design present + TD present)
  → load_inputs (design.html [story stage='design'] + feature Technical Design + the story fields)
  → reverify_design   (agent, READ: does the design cover every TD "What changes" item? → reverify.json {ok, gaps})
        └─(mismatch) → escalate_reverify (hitl_gate: PROCEED_ANYWAY | SEND_BACK) ─(send back)→ END(→ Design Review)
  → prepare_rollback  (agent+program, READ: for each UPDATE object → getX + listObjectVersions → current code + version;
                       NEW objects → "delete to roll back"; NO indirect dependents → rollback.md [LOCAL only])
  → implement         (SINGLE agent; appian + appian-object-generation skills; appian-dev-write CREATE/UPDATE tools;
                       iterate object-by-object over the design; deprecate-in-description instead of delete →
                       implementation.json {per object: uuid, name, type, action, new_version, status})
  → verify            (agent, validate*/test* on ONLY this run's objects → VerificationReport)
        └─ attach_healing: verify → heal (write fixes in place → re-verify | 1 guided restart) → escalate
  → author_wiki       (agent: business + technical description per touched object → wiki.json;
                       program: upsert wiki_object_pages + append wiki_object_entries [local] + publish to Hub if available)
  → present → (StoryImplementationFinalizer: advance lane implementation → code-review, audited m0013)
```

Inputs: `story_id, feature_id, app_uuid, story_stage_id, design_path, techdesign_path, story`. Reliability trio on every agent node; `recursion_limit` raised for the object iteration; a `cleanup` node deletes tool scratch, preserving the report/rollback/wiki artifacts. **The implement + heal agents are the only write-capable nodes** (they inject `appian-dev-write`); every other node stays read-only. **No `delete*` tools are ever available to any node.**

---

## 7. Backend — finalized in 42-05

- **m0021** (wiki tables) + `StoryStageStore.VALID_STAGES += 'implementation'`.
- **`genesis/kb/object_wiki.py::ObjectWikiStore`** — `upsert_page(app_uuid, object_uuid, …)`, `append_entry(page_id, change_kind, business, technical, story_key, …)` (append-only; updates the page's `latest_entry_id`/`current_summary`/`updated_at`), `list_for_app`, `get_page`, `list_entries(page_id)`, `get_object_history(app_uuid, object_uuid)`. `row_version`/`sync_uuid` for collab.
- **`POST /api/workbench/boards/{app_uuid}/cards/{story_id}/implementation/start`** — mirrors `start_design`: validate on-board; **fail-fast 409** on no dev env / app not synced / **no completed design** / **no Technical Design** / workflow not installed; snapshot the design + TD HTML; move the card to `implementation`; `run_manager.start("story-implementation", {...})` bound to a `kb_story_stages(stage='implementation')` row.
- **`StoryImplementationFinalizer`** — a `StoryDesignFinalizer`-style observer bound to `story-implementation`: on `run.final{done}` → bind the artifacts (implementation report + rollback doc paths) to the story-stage row, set it `completed`, and **advance the lane `implementation → code-review`** via `LifecycleService.transition(..., "submit-review", …)` (audited m0013). Bound-run guard + idempotency + on-read recovery. **No completion chat** (unlike design — implementation is unattended). A `failed`/`escalate` run leaves the card in Implementation (light-red + run link).
- **The read-only review surface API** — `GET …/cards/{story_id}/implementation/report` (implementation report + rollback doc + basic run info; served for both Implementation and Code-Review cards). The board card DTO gains `implementation_run_id`/`implementation_run_status`/`implementation_story_stage_id`.
- **Object Wiki collab wiring** + the `author_wiki` program path publish through `CollaborationService` (best-effort when the Hub is available; local write always succeeds).

---

## 8. Web — finalized in 42-07

- **Drag confirm:** `BoardPage.onDragEnd` special-cases a card **entering `implementation`** — a `StartImplementationDialog` ("Start the automated implementation for this ticket? All object changes in the design will be applied to the dev environment."). **Yes** → `POST …/implementation/start`; **No** → the normal lane persist. A card with a running implementation is **locked** (non-draggable).
- **Card states** (reuse the Phase-34 pattern): running → "Implementation running" + a run link; failed → **light-red** + "Workflow failed" + run link.
- **The read-only review surface:** a card in **Implementation** or **Code Review** opens (drawer or a routed page) a read-only view of the **implementation report** (objects created/updated/deprecated + versions + verify results) + the **rollback document** + basic run info. No editing, no chat.
- Types/api/hooks/query-keys + jest-axe on the new surface. `web/static` rebuilt + committed (the stale-bundle guard).

---

## 9. ADRs (drafted in 42-01; Proposed → Accepted at release)

- **ADR-068 — Write-capable Appian implementation lane.** Genesis gains its first environment-mutating capability, scoped to the Workbench Implementation lane + the dev-tagged env. **Amends ADR-021** (the drag-into-Implementation confirm is the single blanket approval; no per-object `pre_mutation` gate — the safety net is the reverify step + the rollback doc + verify/heal + the fact that it's the dev env), **ADR-036/037** (Genesis writes the *environment*; the KB stays read-only and code-free — a re-sync reflects the changes), **ADR-038** (a dedicated `appian-dev-write` managed-native entry with a create/update allowlist, **no delete**), and **supersedes ADR-062's proposal-only clause** for this lane. **No deletes** (deprecate-in-description). Reliability trio + `attach_healing`. Multi-repo.
- **ADR-069 — Workflow-node skill provisioning.** A shippable mechanism to inject a Kiro skill into a workflow agent session (extends ADR-034 beyond chat): provision the named skill(s) into the run's `.kiro/skills/` (the agent's `cwd`) at launch, so a workflow node can be "spun up with a skill" deterministically (not relying on the host's global `~/.kiro/skills`).
- **ADR-070 — The Object Wiki.** A local-first, Hub-shared, append-only per-object change ledger (page per object + entry per change; business + technical descriptions; `created`/`updated`/`deprecated`; story-scoped; no code). Published/pulled via the standard collab pattern; a new Genesis Hub record type additive to the ADR-064 contract (built by the separate Appian agent). Reuses ADR-063/065.

---

## 10. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **42-01** | Research & ADRs | Capture the Dev-MCP write-surface inventory + the skill mechanics + the wiki-pattern research; lock the m0021 data model, the `appian-dev-write` allowlist, the workflow I/O contract, the finalizer/lifecycle model, and the review-surface API; **draft ADR-068/069/070.** Docs only. | ⭐ user sign-off → build |
| **42-02** | Dev-MCP write enablement | The `appian-dev-write` managed-native registry entry (all `create*`/`update*`, **no `delete*`**), the object-type write allowlist, auth via the dev env (ADR-048), and the safety posture (ADR-068). | independent review = SHIP |
| **42-03** | Workflow-node skill provisioning | The mechanism to inject skills into a workflow agent session (ADR-069) — genesis (worker provisions the skill into the run's `.kiro/skills/`) ± a genesis-core primitive; wire `appian` (implement/verify/heal) + `appian-object-generation` (implement). | independent review = SHIP |
| **42-04** | The `story-implementation` workflow | genesis-workflows: `reverify_design → escalate? → prepare_rollback → implement → verify → [attach_healing] → author_wiki → present` + `workflow.yaml` + `registry.json` entry + tests; reliability trio; the escalation gate; the write MCP injected only on implement/heal. | independent review = SHIP |
| **42-05** | Platform backend | m0021 (`current_version`→21) + `ObjectWikiStore`; `StoryStageStore` `'implementation'`; the implementation-start endpoint (move + launch, fail-fast); the `StoryImplementationFinalizer` (done → code-review audited; on-read recovery); the read-only review-surface API; board-card implementation-run DTO fields; tests (+ bump `current_version` tests). | independent review = SHIP |
| **42-06** | Object Wiki store + collab + Hub | `ObjectWikiStore` wiki bindings in `collab/service.py` (`wiki_page` + `wiki_entry`), publish/pull + autopull integration; the **Genesis Hub Object-Wiki record type contract** (+ fixtures) for the separate Appian agent to build (ADR-064 additive); the `author_wiki` publish path (ADR-070). | independent review = SHIP |
| **42-07** | Web | Drag → `StartImplementationDialog`; card running/locked/failed + run link; the read-only Implementation/Code-Review review surface (implementation report + rollback doc); types/api/hooks; jest-axe; `web/static` committed. | independent review = SHIP |
| **42-08** | Code review & hardening | Independent review (write-safety posture; no-delete guarantee; fail-fast prereqs; finalizer bound-run guard + on-read recovery + audited transition; single-agent + healing; wiki append-only + local-first publish/pull; Lavish-free read surface; a11y/dark-parity/no-hardcoded-hex); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **42-09** | Release | genesis vX.Y.0 + genesis-workflows vX.Y.0 (coordinated; ADR-019 order) + the Appian Hub record type (separate agent) [+ genesis-core if 42-03 adds a primitive]; tags; CI green (clean-install DB→**v21** + `validate_library`); docs (bible §2/§3/§4/§8 + tracker + progress + ADR-068/069/070 → Accepted) updated; report. | CI green |

**Suggested order:** 42-01 → 42-02 → 42-03 → 42-04 → 42-05 → 42-06 → 42-07 → 42-08 → 42-09 (linear; 42-06's Appian-side Hub record type can proceed in parallel once 42-01/42-06 freeze the wiki contract, like Phase 36 ran beside 35).

---

## 11. Release plan

**Multi-repo:** genesis (m0021 + backend + web + write-registry wiring + wiki store/API + skill provisioning) + genesis-workflows (the `story-implementation` workflow + the `appian-dev-write` registry entry) + the **Appian Genesis Hub** (a new Object-Wiki record type, Appian-side, built by the separate write-capable agent — additive to the frozen ADR-064 contract; no genesis tag). genesis-core moves **only if** 42-03 lands a workflow-node skill primitive in core (then ADR-019 order core → genesis → genesis-workflows; else genesis → genesis-workflows). Per sub-phase: build → gates (genesis pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`; genesis-workflows `validate_library` + pytest) → local commit → independent review → docs; **no tag/push until 42-09 on the user's go-ahead.** The `clean-install` CI job must migrate a fresh DB to **v21** + serve. **Verify the release commit contains EVERY changed file before tagging (the recurring §7 lesson).**

---

## 12. Scope

**In scope:** the `story-implementation` workflow (reverify → rollback doc → single-agent implement → verify → heal → wiki → move to Code Review); the `appian-dev-write` write-scoped registry entry (create/update all object types, **no delete**); workflow-node skill provisioning (ADR-069); the Object Wiki (m0021 local tables + `ObjectWikiStore` + collab bindings + a Hub record type + the wiki-authoring agent); the implementation-start endpoint + `StoryImplementationFinalizer` (done → code-review, audited); the drag-into-Implementation confirm; the read-only review surface (implementation report + rollback doc) in Implementation + Code Review; the escalation gate on a reverify mismatch.

**Out of scope (future phases / backlog):** **rollback execution** (a separate workflow — `specs/backlog/implementation-rollback-execution.md`); **agents reading the wiki as grounding/memory** (`specs/backlog/wiki-as-agent-memory.md`); **auto KB re-sync after implementation** (`specs/backlog/kb-resync-after-implementation.md`); **object deletion** (never — deprecate-in-description only); leaving Code Review + every later lane's automation (Code Review / Verification / Deployment); writing to any non-dev environment; a Code-Review-lane workflow; multi-user write coordination beyond the Dev MCP's own version stale-write protection.

---

## 13. Open questions

None blocking — all resolved with the user (2026-09-23; §3). Implementation choices deferred to the sub-specs: the exact `story-implementation` node/queue names + the `reverify.json`/`implementation.json`/`wiki.json` schemas (42-01/42-04); whether the workflow-node skill primitive lands in genesis-core or genesis-only (42-03); the precise write allowlist tool list per object type (42-02); the Hub Object-Wiki record-type field tiers + the page/entry normalization (42-06).
