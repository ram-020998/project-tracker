# Review 54-05 — genesis base 9a365c0 → head 9f5e618, genesis-workflows base d0c0f53 → head e384914 (genesis-review, 2026-11-18)

What this change does: genesis-core's `kiro_node` now takes `mcp`, `skills` and `model` either as static values or as
`(state, ctx)` callables resolved at node start. A new read-only server rule (`genesis_core/mcp/pickable.py`) is used by
a new `CustomAgentStore`, by the `agent-prompt` input builder (wired into the schedule hook and into a new
`POST /api/custom-agents/{id}/run`) and, as a second check, by the new `agent-prompt` workflow's node. The run worker
now loads curated servers plus custom-only server names (`override=False`). `META.schedulable` is read by the loader
and the parity lint, and is set on agent-prompt, sync-documents, generate-business-map and hello-appian.

Both brief shas resolve (`git rev-parse --short HEAD` = 9f5e618 / e384914) and both trees are clean. The user's Q1–Q4
answers are treated as accepted decisions. In particular, Q2 (the node re-checks from the worker's own registry instead
of reading an app-passed flag) replaces the spec's §4 wording and is not a finding.

## Checklist

### ADRs
- [OK] ADR-001 — control flow is LangGraph: `agent-prompt/graph.py:178-201` (attach_reliability + conditional edges); the agent only writes `output.md`.
- [OK] ADR-002/004/020 — servers are injected per node through `ctx.mcp.acp_servers(mcp_names)` (`agent.py`, the diff's `_run`); nothing global is written.
- [N/A] ADR-003, 007, 008, 009 (no HITL mode changed), 015, 016, 017, 022, 023, 024, 025, 026, 027, 028 (one new route under `/api`, `api/custom_agents.py:24`), 030, 031, 033, 034, 036–043, 045–048, 050, 053–065, 070–072, 074–082, 084, 085 — not touched by this diff.
- [OK] ADR-006 — `workflows/agent-prompt/` holds `workflow.yaml` + `graph.py` and has a `registry.json` entry with version 0.1.0 = META; `ci/validate_library.py` PASSED (19 workflows).
- [OK] ADR-010/018 — state holds the inputs (prompt ≤ 20 000 chars and the snapshot); the answer is the `output.md` blackboard doc, and `artifacts` stores its path.
- [OK] ADR-011 — validator + 2 retries + escalation gate: `graph.py:194-195`; `check_reliability` passes in `test_meta_mirrors_the_yaml_and_the_trio_is_present` and in validate_library.
- [OK] ADR-012 — the node imports only `genesis_core` (`graph.py:29-33`); the worker imports `genesis_core.mcp.custom_store`, not app code; the snapshot reaches the worker through inputs (`prompt_inputs.py:36-38`).
- [OK] ADR-014 — the new workflow follows the scaffold shape (trio, `graph:` topology, folder tests).
- [OK] ADR-019 — additive only: new keyword arguments with defaults on `McpRegistry.__init__`/`from_layers`/`kiro_node`, a new module, `CORE_MAJOR` untouched. Release note: agent-prompt imports `genesis_core.mcp.pickable` and passes callables, so it needs a core at least as new as this commit. The library pins (`pyproject.toml:17-25`, `registry.json` `genesis_core_version` 0.82.0) must move at release (L-057), because the major-only gate will not stop a 0.82 app from loading it.
- [OK] ADR-021 — `auto_approve: true`, `hitl_points: [escalate]`, no `pre_mutation`. That is justified because no write-capable server can reach the node: refused servers fail before any turn (`test_a_refused_server_fails_the_node_before_any_turn[appian-dev-write|appian-devops|…]`).
- [OK] ADR-029 — tool trust is unchanged (`_node_mcp_trust(tools, mcp_names, …)`); `test_a_pickable_server_reaches_the_turn_capped_at_its_allowlist` asserts each pickable server's trust equals its real allowlist. Worker tiers: see "Worker registry" below.
- [OK] ADR-032 — the credit path is unchanged (same `turn.usage` code after the per-run resolution).
- [OK] ADR-035 — no `format: file` input (`test_no_file_inputs`).
- [OK] ADR-051 — the node still resolves `get_agent_provider()`; the tests use `set_agent_provider`.
- [OK] ADR-066 — `agent.prompt` / `agent_start` now carry the resolved `mcp_names` and `model_id`, so the capture shows what the run actually used.
- [OK] ADR-067 — N/A for this workflow (no healing declared). It is listed by the area only.
- [OK] ADR-068 — `appian-dev-write` is never pickable (`pickable.py:28`); `delete_file` is not in the node's built-ins (`test_a_pickable_server…` asserts it).
- [OK] ADR-069 — skills are provisioned into the run's `.kiro/skills/` from the managed workspace only (`test_the_agent_and_run_skills_are_provisioned_from_the_managed_workspace`).
- [OK] ADR-073 — `appian-dev-packages` is never pickable (`pickable.py:29`, `test_the_pickable_curated_servers_are_read_only_with_an_allowlist`).
- [OK] ADR-077 — no agent-system change.
- [OK] ADR-080 — the core change is inside `packages/genesis-core`; no new internal dependency entry.
- [OK] ADR-083 — D2 accepted the D9 built-ins (shell, web) for unattended runs; this diff adds no new capability.
- [OK] ADR-086 — the store never touches `~/.kiro/agents`; the node still projects `NODE_AGENT_ID`, and static and callable forms give the same options (`test_static_and_callable_forms_give_the_same_options`).

### Lessons
- [OK] L-001/L-002 — the `KiroAgentOptions` construction is unchanged apart from `model=model_id` and `mcp_names`.
- [OK] L-005 — no new event kinds.
- [OK] L-006 — `graph:` node ids equal the LangGraph nodes (`test_graph_topology_names_every_langgraph_node`).
- [OK] L-009 — async nodes, `ainvoke`, `MemorySaver` in tests.
- [OK] L-013 — parity green; `MIRRORED_BOOL_KEYS` adds the type and both-sides checks (`test_the_parity_lint_knows_schedulable`, 6 cases).
- [OK] L-016 — credits unchanged.
- [OK] L-017 — custom picks without `read_only_mark: true` are refused; curated pickable servers need a non-empty allowlist (`pickable.py:66-67`).
- [OK] L-020 — each escalation resume runs at most about 8 supersteps (retry_agent + 3×2 + escalate), well under 25 per invocation.
- [OK] L-022 — `agent-prompt/graph.py` has no `from __future__ import annotations` (it starts at `from pathlib import Path`).
- [OK] L-026 — the schedule hook calls the builder through `asyncio.to_thread` (`schedule_targets.py:106`); the Run route is a sync `def` (threadpool).
- [OK] L-033 — the Run route returns 409 with an install hint when agent-prompt is missing (`test_run_refusals`).
- [OK] L-042 — the answer is a file in the run folder, not chat content.
- [OK] L-065 — `give_up` sets `status: failed` and `finish` sets `done`; the worker maps both (`worker.py:125`).
- [OK] L-091 — `delete` checks `scheduled_jobs` and deletes under one `BEGIN IMMEDIATE` (`store.py:216-226`). `update` is only partly covered (m1).
- [OK] L-092 — `workflows/agent-prompt/tests/` has no `__init__.py`; no non-test symbol is named `test*`.
- [OK] L-094 — every consumer was listed: the `from_layers` callers (`config/service.py:163`, `worker.py:104`), the `servers()` enumerators (only `pickable.py:74`), the `schedulable` readers (catalog route, `/api/workflows/{id}` meta passthrough asserted in `test_run_starts_agent_prompt_once…`, the schedule handler through `schedulable_of`), and the web types.
- [OK] L-096 — no route shadows `/custom-agents/{id}/run` yet (the CRUD routes come in 54-06).
- [VIOLATION] L-106 — the escalation gate's Feedback answer is silently turned into a reject. See M1.
- [OK] L-109 — the D3 rule has one home (`pickable.py`) and one reader (`check_picks`), used by the store, the builder and the node. The parity test runs against the real `mcp-registry.json` (`test_every_curated_server_is_classified`, both directions).
- [OK, with gaps] L-110 — I verified the node's D3 re-check by mutation in a scratch copy (`/tmp/gw-mut-5405`): dropping `check_picks` from `checked_server_names` fails 8 tests, which matches the author's claim. The retry-counter reset after Approve is not covered by any test (m2), and neither is the app wiring of the schedule hook (m3).
- [OK] L-113 — a changed model is refused when the model list is unavailable (`test_a_model_needs_the_model_list_only_when_it_changes`, Q4).
- [OK] L-115 — invalid front matter fails the node before any turn (`test_a_skill_with_invalid_front_matter_fails_the_node`).
- [OK] L-116 — trust and pickability are tested against the real library registry (`_real_registry()`), not a stub.
- [OK] L-117 — the node tests use the real registry, the real `kiro_node` and the production run-folder layout, plus negative controls (refused servers, unmarked custom server).
- [N/A] L-003, L-004, L-008, L-010, L-018, L-019, L-021, L-023, L-024, L-029, L-031, L-039, L-041, L-044, L-045, L-048–L-053, L-058–L-064, L-066, L-068, L-075, L-076, L-081, L-087–L-089, L-093, L-097–L-101, L-104, L-105, L-107, L-108, L-114, L-118, L-119 — the diff does not touch their area. The release-ci lessons (L-025, L-027, L-030, L-056, L-057, L-111, L-112) apply at release; see Not checked.

### Gates (run by me, 2026-11-18 22:25–22:40 IST, outside the D27 window)
- [OK] `genesis/packages/genesis-core`: pytest **120 passed**; `ruff check genesis_core` clean.
- [OK] `genesis`: `.venv/bin/ruff check genesis` clean; full pytest **2037 passed** in 11:08, no deselect.
- [OK] `genesis-workflows`: `ci/validate_library.py` PASSED (19); `ci/validate_skills.py` PASSED (5); pytest `workflows --ignore=workflows/_fixtures` **461 passed**.
- [OK] web: `tsc --noEmit` clean; eslint on `src/types/catalog.ts` clean; `vite build --outDir /tmp/54-05-static` gives a result identical to `web/static` (`diff -rq`), so the committed bundle is fresh.

### The specific checks asked for
- **Static `kiro_node` callers unchanged:** OK. `_per_run` returns any non-callable unchanged. `mcp_names`/`skill_ids` equal the old `list(mcp)`/`list(skills)`, and static `model` is passed through as given. `Node(name, fn, kind="agent")` carries no argument copy, and no lint inspects `kiro_node` arguments (`grep kiro_node|mcp=` in `genesis/lint`, `ci/` and `runs/`: none). No other workflow's graph changed beyond `version`/`schedulable`.
- **Worker registry cannot switch a node's server:** OK for every name in the curated tier. `from_layers(..., override=False)` keeps the curated entry (`test_the_worker_adds_custom_only_servers_and_keeps_curated_entries` asserts `appian-dev-write` stays curated when the custom store has `/bin/evil`). All 26 static node server names in the library (`jarvis`, `jira`, `appian-atlas`, `appian-dev`, `appian-dev-write`, `genesis-kb`, via `GROUNDING_MCP`/`KB_MCP`/`NODE_MCP`) are curated in `mcp-registry.json`. The only new reach is a name absent from the installed curated file: a static node naming it previously failed to resolve and would now launch a same-named custom server. No current workflow names one. An unreadable custom store falls back to curated only (`test_the_worker_registry_survives_an_unreadable_custom_store`).
- **Delete-409 and snapshot shape:** OK. `delete` raises `CustomAgentConflict(used_by=[{schedule_id, name}])` inside the write lock (`test_delete_refused_while_a_schedule_uses_it_naming_the_schedules`). `agent_id` is stored as an int (`schedule_store.py:147`), so `json_extract(...)=?` matches. The snapshot is `{id, name, instructions, skills, mcp_servers, model}` as spec §1/§4 say (`test_create_get_list_and_snapshot`; through the real RunManager in `test_run_starts_agent_prompt_once…`). I also validated a real snapshot, including `model: null`, against agent-prompt's real `inputs_schema` with `genesis.runs.validation.validate_inputs`: accepted. A 20 001-character prompt is refused.
- **Escalation prompt vs routes:** the Approve and Reject wording matches the routes (`graph.py:161-169`). The third answer the UI always offers (Feedback) is not honoured (M1).

## Findings

### Blockers
None.

### Majors
- M1 **The escalation gate's Feedback answer ends the run as failed and drops the feedback** (`workflows/agent-prompt/graph.py:168-169`, `:124-141`).
  What: `_route_after_escalate` returns `"approve"` only for `escalate.outcome == "approve"`; every other answer goes to `give_up`, which sets `status: failed`. `build_prompt` reads only the validator's message, never `decisions["escalate.feedback"]`.
  Problem: Run Detail's `HitlBar` shows a **Feedback** button on every gate, whatever `options` say (`web/src/features/run-detail/components/hitl/HitlBar.tsx:108-129`, placeholder "Notes for the step — it re-runs with your feedback."). The backend always accepts a feedback dict (`genesis/runs/manager.py:426`), and `hitl_gate` stores it as `outcome="feedback"` (`genesis_core/nodes/gate.py:47-49`). I probed this in a scratch copy: three empty answers, then `Command(resume={"feedback": "write a shorter answer"})`. The result was `status=failed`, still 3 turns, and the feedback in no prompt. The person asked for a re-run with notes and the run failed instead. This is the L-106 case, in a workflow built for unattended schedules where the escalation gate is the main way a person steps in. (memory-consolidation/maintenance use the same pattern; that is pre-existing and out of scope here.)
  Fix: route `"feedback"` like approve (`{"approve": "retry_agent", "feedback": "retry_agent", "reject": "give_up"}`, with `_route_after_escalate` returning the outcome), and in `build_prompt` append `decisions["escalate.feedback"]` when present ("The reviewer asked: …"). Add one test per answer: approve → re-run; feedback → re-run with the text in the next prompt; reject → failed.
  If skipped: a user who types feedback at the gate loses the run and has to start a new one by hand.

### Minors
- m1 **`update` reads the row it merges from outside the write lock** (`genesis/agents/store.py:196-213`; docstring `:24-25`).
  What: `current = self.get(agent_id)` and `_validate(merged)` run before `BEGIN IMMEDIATE`. Inside the lock only existence and the name are re-checked.
  Problem: two saves of the same agent (two tabs, or main and userb on one DB) with A = `{instructions: "X"}` and B = `{skills: ["gam"]}` both merge from the old row. B commits second and writes back the old instructions, so A's edit is lost with no error. The docstring says "Every read-validate-write starts with BEGIN IMMEDIATE (L-091)", which is not true for `update`.
  Fix: read `current` inside the `BEGIN IMMEDIATE` transaction on the same connection, then merge, validate and write there. Or keep the order and make the UPDATE a compare-and-set on `updated_at = current.updated_at`, raising `CustomAgentConflict` on 0 rows. Add a test that interleaves two updates.
- m2 **No test proves the escalation's "3 more attempts" promise** (`graph.py:164-165`, `:189`; test `test_approving_the_escalation_runs_the_agent_again`).
  What: the prompt says "Approve to run the agent again (3 more attempts)", and `retry_agent` resets `retries.run_agent` to 0 to keep that promise.
  Problem: in a scratch copy I replaced `retry_agent`'s update with `{}` (no reset) and all 29 agent-prompt tests still passed. Without the reset, the first refused attempt after Approve goes straight back to the gate (retries 4 > 2), so the gate's promise would be broken with nothing failing. The existing test's 4th answer succeeds, so it never exercises a second failure.
  Fix: in the approve test, feed a second round of 3 bad answers after Approve and assert 6 turns, then the gate again.
- m3 **No test covers the app's wiring of the schedule hook** (`genesis/api/app.py:298-311`).
  What: the scheduler tests pass a fake builder to `register_target_handlers`, and `test_custom_agents` calls `build_agent_prompt_inputs` directly.
  Problem: if `agent_prompt_inputs=agent_prompt_inputs` is dropped from `create_app` (a merge or refactor slip), every agent-prompt schedule is recorded `skipped` ("not available in this build yet") and the whole genesis suite stays green. I checked this: no test builds `create_app` and fires an `agent_prompt` schedule.
  Fix: in `test_custom_agents._client(install=True)`, create an `agent_prompt` schedule for a stored agent and fire it through `app.state.scheduler` (run-now or a `_tick` with an injected clock). Assert one agent-prompt run whose `inputs["agent"]` equals `agents.snapshot(id)` and whose trigger is the schedule's.

### Nits
- n1 **Delete-409 race hand-off to 54-06** (`store.py:216-218`). The docstring says a schedule saved during a delete "cannot be left pointing at nothing". That holds only for a schedule committed before the delete. `ScheduleStore.create_user` does not check that the agent exists (`schedule_store.py:146-148` checks the type only), so a schedule saved after the delete commits points at a gone agent. Today that fails at fire time with "no longer exists", which is honest. 54-06's create and update must check the agent under their own `BEGIN IMMEDIATE`. Record this in As built's "For 54-06".
- n2 **Q3's exclusion reason also fits sync-documents.** memory-consolidation/maintenance are excluded as "already system schedules", but sync-documents is one too (`document-library-sync`, `runtime/sync_jobs.py:207-217`). The real difference is the concurrency guard (consolidation's cursor has none, and library syncs already overlap with the Documents page's Sync button). State that reason in As built so a later reader does not "fix" the inconsistency.
- n3 **Re-validation on update blocks unrelated edits.** `update` re-checks unchanged skills and servers (`store.py:198-199`), so renaming an agent whose skill was uninstalled or whose custom server was removed is refused with 422. This is defensible, but 54-06's UI should say which field blocks the save.

## Not checked
- Live acceptance: no real Kiro turn on v3 with a per-run model, a provisioned skill and a picked custom server, and no live schedule fire on the fleet. All coverage is offline (stub provider). It should be part of the phase's live pass (L-111).
- The release: library pins and `registry.json` `genesis_core_version` must move to the new genesis tag together (L-057), and genesis-workflows CI will fail to import `genesis_core.mcp.pickable` until they do. There has been no CI run in the CI image yet (L-112).
- The sub-spec's **As built** is still the placeholder. The Q1–Q4 decisions and the Q2 mechanism (the node re-checks from the worker registry instead of reading an app-passed flag) are recorded only in the brief.
- Full `npm run lint` and `vitest` were not run; only a type-only line changed in `catalog.ts`, and tsc, eslint on that file and the bundle diff are green.
- `~/.genesis/genesis.db` was not touched.

## Verdict: NEEDS_CHANGES
Fix M1 (honour the Feedback answer and test all three answers). m1–m3 are small and should land in the same fix commit; the nits are hand-off notes. Every gate is green.

---

## Re-run 1 — genesis 9f5e618 → 9f63fc2, genesis-workflows e384914 → 7b35f8a (genesis-review, 2026-11-18)

Both fix shas resolve as each repo's `HEAD`, and both trees are clean. The fix diffs are `genesis/agents/store.py`
and `tests/test_custom_agents.py` in genesis, plus `workflows/agent-prompt/{graph.py, workflow.yaml,
tests/test_workflow.py}` in genesis-workflows. genesis-core is unchanged since 9f5e618. `genesis-ctx check --since` was
run in each repo. genesis's two files map to no area, so only the always-on release-ci and security areas apply.
genesis-workflows maps to workflows-library.

### Round-1 findings

- **M1: fixed.** `_route_after_escalate` (`graph.py:172-176`) returns the outcome when it is `approve` or
  `feedback`, and `reject` for anything else. The edge map (`graph.py:204-205`) sends `feedback` to `retry_agent`.
  `build_prompt` (`graph.py:141-143`) appends "A person reviewed the earlier attempts and asked: …" from
  `decisions["escalate.feedback"]`, which is the key `hitl_gate` writes (`genesis_core/nodes/gate.py:47-49`). The gate
  prompt now names all three routes (`graph.py:167-169`), and `workflow.yaml` has the matching edge and description.
  Tests: `test_feedback_at_the_escalation_reruns_the_agent_with_the_feedback_in_its_prompt` (4 turns, `done`, the text
  in prompt 4 and not in prompt 1); `test_the_gate_prompt_names_every_route` (the route table, including `None` and an
  unknown value → reject). Mutations in a scratch copy (`/tmp/gw-mut-5405r1`):
  - feedback edge → `give_up`: the feedback test fails (`'failed' == 'done'`);
  - drop the reviewer line from `build_prompt`: the feedback test fails.

  The author's route-function mutation also fails the route-table test, which accounts for the "2 tests" claim.
- **m1: fixed.** `update` now runs `BEGIN IMMEDIATE`, then reads the row, merges, validates, checks the name and
  writes, all on one connection (`store.py:196-213`). Validation inside the lock calls only `installed_skills()`
  (a directory listing) and `registry()` (registry files). `models` is a collection the caller passes in, not a call to
  Kiro, so the write lock is not held across a network or CLI call. `test_two_concurrent_updates_keep_both_edits`
  starts B from inside A's validation. I restored 9f5e618's `store.py` in a scratch copy (`/tmp/g-mut-5405r1`,
  `genesis.__file__` confirmed to be the copy): that test fails and the other 30 pass. The test cannot pass by accident:
  if B timed out on the lock, its exception would stay in its thread and the final assert (`skills == ["gam"]`) would
  fail. The module docstring's "Every read-validate-write starts with BEGIN IMMEDIATE" is now true for `update`.
  `create` still validates before its lock, which is correct because no row read is involved.
- **m2: fixed.** `test_approving_the_escalation_gives_three_more_attempts_then_the_gate_again` has 6 empty answers,
  Approve, 6 turns and the gate raised again, then Approve and success on turn 7. Mutation: `retry_agent` returns `{}`
  (no reset), and that test fails.
- **m3: fixed.** `test_the_app_wires_the_builder_into_agent_prompt_schedules` builds the real `create_app`, saves an
  `agent_prompt` schedule, then edits the agent and fires the schedule through `app.state.scheduler.run_now`. It asserts
  `outcome == "fired"`, `workflow_id == "agent-prompt"`, `inputs["agent"] == snapshot` with the edited instructions,
  and the schedule trigger. Mutation: drop `agent_prompt_inputs=` from `create_app` (`app.py:311`), and the test fails
  with `'skipped' == 'fired'`. I restored the file and the copy is green again.
- **n1: done.** `delete`'s docstring (`store.py:218-221`) says what the lock covers and hands the save-time agent check
  to 54-06.
- **n2, n3: not yet recorded.** The author says both go into As built, but the sub-spec's As built
  (`54-05-custom-agents-and-agent-prompt.md:97-100`) is still the placeholder. That is expected before the review
  closes. It must carry n1's 54-06 hand-off, n2's exclusion reason, n3's UI note and the Q1–Q4 decisions.

### Checklist (this fix diff)

ADRs:
- [OK] ADR-001: the new branch is a LangGraph conditional edge; the agent still only writes `output.md`.
- [OK] ADR-006 / ADR-014: still one folder package; `validate_library.py` PASSED (19).
- [OK] ADR-010 / ADR-018: the feedback is a short human string in `decisions` (already the gate's state); no bulk.
- [OK] ADR-011: the trio is unchanged (`attach_reliability`, `graph.py:202-203`); the reliability lint passes.
- [OK] ADR-012: the graph still imports only `genesis_core`.
- [OK] ADR-019: no core change; the release pin note from round 1 stands.
- [OK] ADR-021: `auto_approve: true`, `hitl_points: [escalate]`, and a feedback answer is a human gate response like
  approve. No write path is added.
- [OK] ADR-029 / ADR-068 / ADR-073 / ADR-086: trust and server checks are unchanged. The retry re-enters the same
  `run_agent`, which re-runs `checked_server_names`.
- [OK] ADR-033: the copilot still cannot answer gates; nothing here gives it a route.
- [OK] ADR-080: no dependency entries changed.
- [N/A] ADR-003, 005, 007, 015, 017, 020, 022, 026, 028, 030–032, 034–039, 041, 045, 046, 048, 056–059, 061–063, 065, 067,
  069, 074–078, 081–085: the diff touches neither their area nor their code.

Lessons:
- [OK] L-006: `graph:` nodes are unchanged, and the new edge `escalate → retry_agent (feedback)` uses existing ids.
- [OK] L-009: async, `ainvoke`, `Command(resume=…)` on a checkpointed graph in the tests.
- [OK] L-013: parity is green (`test_meta_mirrors_the_yaml_and_the_trio_is_present`, validate_library).
- [OK] L-020: a feedback resume runs the same ≤ 8 supersteps as an approve.
- [OK] L-022: still no `from __future__ import annotations` in `graph.py`.
- [OK] L-026: no new blocking call on the loop. `update` is called from sync routes and threads.
- [OK] L-091: `update` now reads and validates inside `BEGIN IMMEDIATE`, and the fail-first concurrency test proves it.
- [OK] L-092: no `tests/__init__.py`; the new symbols are tests.
- [OK] L-106: every answer the UI offers (Approve, Feedback, Reject) now takes the route the prompt names.
- [OK] L-110: each fix has a test that fails on its mutation (five mutations above, all run by me).
- [N/A] L-017, L-021, L-023, L-024, L-029, L-033, L-042, L-044, L-045, L-049, L-053, L-064, L-075, L-076, L-087–L-089,
  L-098–L-101, L-104, L-105, L-109, L-113, L-115–L-117, L-119: not touched by this diff. The release lessons (L-025,
  L-027, L-030, L-051, L-056, L-057, L-111, L-112) apply at release, as in round 1.

Gates (run by me, 22:57–23:10 IST, outside the D27 window):
- [OK] genesis: `.venv/bin/ruff check genesis tests/test_custom_agents.py` clean; full
  `pytest -q -p no:warnings` **2039 passed** in 11:04 (round 1's 2037 plus the 2 new tests).
- [OK] genesis-workflows: `ci/validate_library.py` PASSED (19); `ci/validate_skills.py` PASSED (5);
  `ruff check workflows/agent-prompt` clean; `pytest workflows --ignore=workflows/_fixtures` **463 passed**.
- [N/A] genesis-core: unchanged since 9f5e618 (120 passed in round 1). Web: no web file changed.

### New findings

No blocker, major or minor findings.

Nits:
- n4 **Feedback from an earlier round stays in later prompts.** `decisions` uses the merge reducer
  (`genesis_core/state.py:57`), so after feedback, three more failures and an Approve, attempts 7–9 still carry the
  first reviewer note. That is arguably what the person wants, and no promise is broken, because the prompt says
  feedback "goes into its prompt". If 54-06 or a later phase wants Approve to mean "drop my earlier note",
  `retry_agent` can clear `escalate.feedback` on an approve. No change needed now.
- n5 **A non-string feedback would fail the node.** `build_prompt` calls `.strip()` on the value
  (`graph.py:141`). `Respond.decision` is `Any` (`genesis/api/_shared.py:46-47`), so a hand-made
  `{"feedback": 123}` gets past the API and the run errors on the next attempt instead of re-running. The UI always
  sends a string, so this is not reachable from the product. `str(...)` around the value would close it.

### Not checked
- Live acceptance, unchanged from round 1: no v3 turn, no live schedule fire, and no Feedback answer at a real Run
  Detail gate. Add a live check of "Feedback at agent-prompt's escalation re-runs with the note" to the phase's live
  pass (L-111).
- The release pins and CI-image run (L-057, L-112), as in round 1.
- As built is still the placeholder (see n2/n3 above).
- `~/.genesis/genesis.db` was not touched. The scratch copies `/tmp/g-mut-5405r1` and `/tmp/gw-mut-5405r1` were
  restored after each mutation; I could not remove them because `rm -rf` is denied.

### Verdict (Re-run 1): SHIP
M1 and m1–m3 are fixed. Each fix has a test that I watched fail on its mutation, and every gate is green. n4 and n5 are
optional. Before the phase closes, the As built must record the n1 hand-off, the n2 reason, the n3 UI note and the
Q1–Q4 decisions.
