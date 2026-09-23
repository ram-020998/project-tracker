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

## Next

42-04 — the `story-implementation` workflow (genesis-workflows): `resolve_inputs → load_inputs → reverify_design →
escalate? → prepare_rollback → implement → verify → [attach_healing] → author_wiki → render_report → present → cleanup`;
reliability trio per agent; the escalation gate; `appian-dev-write` (42-02) + skills (42-03) injected only on implement/heal;
the no-`delete*` guard extended to the workflow's effective node tool sets. Then 42-05 backend (incl. the send-back
`(IMPLEMENTATION,"send-back")→DESIGN_REVIEW` transition edge — pending the user's action-name nod).
