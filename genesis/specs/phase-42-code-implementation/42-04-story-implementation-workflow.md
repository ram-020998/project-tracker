# 42-04 — The `story-implementation` workflow ("Ticket Implementation")

> **Status:** 🟡 DRAFTED. Repo: **genesis-workflows**. Implements **ADR-068**; reuses `attach_healing` (ADR-067), the reliability trio (ADR-011), `appian-dev-write` (42-02), workflow-node skills (42-03). Parent: `specs/phase-42-code-implementation.md`.

## 1. Goal

The unattended, write-capable workflow launched when a card enters the Implementation lane. It reverifies the design against the Technical Design, snapshots a rollback doc, implements every object change in the dev environment, verifies + heals the touched objects, writes the Object Wiki, and (via the finalizer) moves the card to Code Review.

## 2. Graph

```
START → resolve_inputs   (fail-fast: dev env tagged + app synced + design.html present [story stage='design', completed]
                          + feature Technical Design present; else a clear error → the endpoint 409s pre-launch)
  → load_inputs          (read design.html + the feature Technical Design HTML + the story fields → memory)
  → reverify_design      (agent, READ [genesis-kb + appian-dev]; skill: appian; does the design cover EVERY TD
                          "What changes" item? → reverify.json {ok:bool, gaps:[…]})            [v_reverify]
        └─(ok=false) → escalate_reverify  (hitl_gate kind=approval; options PROCEED_ANYWAY | SEND_BACK)
                          ├─(PROCEED_ANYWAY) → prepare_rollback
                          └─(SEND_BACK) → present_sendback → END   (the finalizer moves the lane back to Design Review)
  → prepare_rollback     (agent+program, READ; skill: appian; for each UPDATE object in the design → getX + the
                          current object_version [listObjectVersions]; NEW objects → "delete to roll back"; NO
                          indirect dependents → rollback.md [LOCAL, elaborate — enough for a future rollback agent])
  → implement            (SINGLE agent; skills: appian + appian-object-generation; mcp=[appian-dev-write, genesis-kb];
                          iterate object-by-object over the design's plan; create/update via the write tools;
                          a design that RETIRES an object → updateX setting the description "deprecated by Genesis —
                          <ticket>" (NEVER delete); the skill's validate-then-iterate loop runs internally
                          → implementation.json {objects:[{uuid,name,type,action:created|updated|deprecated,
                          new_version,status}], notes})                                          [v_implement]
  → verify               (agent; skill: appian; validate*/test* on ONLY this run's touched objects → VerificationReport)
        └─ attach_healing(verify → heal [agent, mcp=appian-dev-write: write fixes in place → re-verify | ONE guided
                          restart of `implement` with carry-forward guidance] → escalate)  [bounded {max_heal:1,max_restart:1}]
  → author_wiki          (agent; READ; per touched object write a business_description + a technical_description +
                          change_kind + is_bugfix/change_reason → wiki.json ; then a PROGRAM step upserts
                          wiki_object_pages + appends wiki_object_entries [local] + publishes to the Hub if available)
  → render_report        (DETERMINISTIC program: implementation-report.html from implementation.json + verify.json)
  → present → cleanup → END   (StoryImplementationFinalizer: advance lane implementation → code-review, audited)
```

## 3. Node rules

- **Reliability trio on every agent node** (validator + retry + escalation, ADR-011). `reverify_design` validator = the JSON shape + that every TD item is addressed-or-listed-as-a-gap. `implement` validator = `implementation.json` is well-formed AND every object in the design's plan has a terminal `status` (attempted); a write that returned an error is a validator failure → retry, then escalate. `verify` emits a `VerificationReport` (ADR-067 contract).
- **`attach_healing`** wires verify→heal→{patch|restart→escalate}; the heal agent is the ONLY other write node (mcp=`appian-dev-write`); the restart target is `implement`.
- **Only `implement` + `heal` inject `appian-dev-write`.** Every other node is read-only (`appian-dev`/`genesis-kb`). **No node ever has a `delete*` tool.**
- `recursion_limit` raised for the object iteration (single agent turn may loop many tool calls; validate-iterate). `cleanup` deletes tool scratch, preserves `rollback.md`/`implementation-report.html`/`implementation.json`/`wiki.json`.
- **Deprecate-not-delete** is enforced in the implement prompt/steering AND by the absence of any `delete*` tool (defense in depth).

## 4. Inputs / outputs

Inputs: `story_id, feature_id, app_uuid, story_stage_id, design_path, techdesign_path, story` (the snapshots + fields the endpoint provides, 42-05). Artifacts: `reverify.json`, `rollback.md` (local only — never published), `implementation.json`, `verify.json`, `heal.json`, `wiki.json`, `implementation-report.html`. `workflow.yaml` mirrors `META` (parity lint); `graph:` topology for the run-detail preview.

## 5. Tests

- Offline (stub the agent via `set_collect_impl`): the graph shape; the reverify escalation branch (send-back vs proceed); the implement validator (all objects attempted); `attach_healing` wiring (verify fail → heal → re-verify); the deprecate-path (a retire → an update, never a delete); `author_wiki` produces one entry per touched object. `validate_library` +1 workflow.
- A guard test: no node's effective tool set contains a `delete*` tool.

## 6. Out of scope

Package deploy (DevOps MCP); rollback execution; a Code-Review-lane workflow; writing to non-dev envs.
