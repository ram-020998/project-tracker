# 54-05 — Custom agents, per-run skills and servers in `kiro_node`, and the `agent-prompt` workflow

> **Status:** BUILT 2026-11-18 (genesis `9a365c0..9f63fc2`, genesis-workflows `d0c0f53..7b35f8a`, local; review SHIP,
> `reviews/54-05-review.md`). SPEC-DRAFTED 2026-11-19. Repos: genesis (`packages/genesis-core`, `genesis/runs/`, a new
> `genesis/agents/` package, `genesis/runtime/context.py`), genesis-workflows. Parent:
> `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev**. Decisions: D2–D5, D7, F3–F5
> (`54-01-findings.md` §8–§9). ADR draft: `adr-drafts.md`.

## 0. From 54-04's As built (read it: "For 54-05 / 54-06")

- **Hook:** `register_target_handlers(scheduler, run_manager=, executions=, kb_store=, agent_prompt_inputs=None,
  kiro_ready=None)` in `api/app.py`. 54-05 passes `agent_prompt_inputs=fn(target: dict) -> dict` returning the
  `agent-prompt` inputs (§4) with the custom-agent snapshot taken at call time. Raise `LookupError` or `ValueError`
  (agent gone, a server no longer pickable under D3) and the row is recorded `failed` with that message. The handler
  already checks that `agent-prompt` is installed and Kiro is signed in, and starts the run with its trigger; today it
  records `skipped` ("nothing to run in this build") until the hook is passed.
- **`schedulable`:** the workflow handler reads `meta.get("schedulable") is True`; §5 adds the key to the loader, the
  parity lint and the library.
- **`custom_agents`** exists (m0030) with the F3 columns: `name` UNIQUE, `skills_json` and `mcp_servers_json`
  default `'[]'`, `model` nullable. §1 builds the store over it; no migration change.
- A one-off Run (§6) leaves `trigger` None.

## 1. Custom agents store (`genesis/agents/`)

Over m0030's `custom_agents` (54-04 §1): `list`, `get`, `create`, `update`, `delete` (409 with the schedule names when
any `agent_prompt` schedule references it, F3), `snapshot(id)` → `{id, name, instructions, skills, mcp_servers, model}`.
Validation on write:
- `name` unique, 1–60 chars; `instructions` ≤ 20 000 chars;
- `skills`: ids of installed managed skills (`~/.genesis/.kiro/skills/`, Phase 53 D7/D8); unknown ids refused;
- `mcp_servers`: names that pass the **read-only server rule** (§2); a custom server needs `read_only_mark: true`;
- `model`: a model id the model list knows, or null.
Genesis never reads or writes `~/.kiro/agents` (ADR-086).

## 2. The read-only server rule (D3) — one function, one home

`pickable_servers(registry)` in one module, used by the custom-agent store, the schedule API (54-06), the schedule
handler at fire time (54-04 §4) and the `agent-prompt` node (defence in depth; L-109). A server is pickable when:
- it is curated, has a non-empty `tool_allowlist`, and is one of the read-only set: `appian-dev`, `genesis-kb`,
  `appian-atlas` (a named list in code, with a test that fails if a curated server is added to the registry without
  a decision: every curated name must be classified pickable or not);
- or it is a custom server and the pick carries `read_only_mark: true` (the user's claim, stored with the pick).
Never pickable: `appian-dev-write` (ADR-068), `appian-dev-packages` (ADR-073), `appian-devops`, `jira`, `jarvis`,
`appian-data-generator` (no allowlist = every tool, ADR-029/086).

## 3. genesis-core: `kiro_node` takes per-run `skills`, `mcp`, `model` (F4)

`kiro_node(..., mcp=…, skills=…, model=…)` (`packages/genesis-core/genesis_core/nodes/agent.py:273-312`) accepts either
today's static value or a callable `(state, ctx) -> value`, resolved when the node runs, before the session starts.
Everything downstream is unchanged: skills through `ctx.extras['skill_source']` with the front-matter check (L-115),
provisioning into the run's `.kiro/skills/` (ADR-069), MCP trust `node.tools ∩ allowlist` in the projected agent
(ADR-029/086, L-116), D9's built-ins, credits from `turn_completion` (ADR-032). Static callers are untouched; the change
is additive, `CORE_MAJOR` stays 1 (ADR-019). Unit tests: static and callable forms give the same `KiroAgentOptions`;
a callable naming a missing skill fails the node with the existing message.

## 4. The `agent-prompt` workflow (genesis-workflows, new)

- Folder `workflows/agent-prompt/` (`workflow.yaml` + `graph.py`, self-contained, no sibling imports; the L0-core §4
  contracts), version 0.1.0, `schedulable: true`, `auto_approve: true`, no `pre_mutation` gate (no write-capable server is
  possible, D3).
- `inputs_schema`: `prompt` (string, textarea, required, ≤ 20 000 chars), `agent` (object, optional: the snapshot
  `{id, name, instructions, skills[], mcp_servers[], model}`), `skills` (array of strings), `mcp_servers` (array of
  `{name, read_only_mark}`), `model` (string, optional), `title` (string, optional, used in the output's heading).
  Effective skills/servers = agent's ∪ the run's own; effective model = run's, else agent's, else Kiro's default (F5).
- Graph: `run_agent` (`kiro_node`, callables from §3, prompt = agent instructions + the user prompt + a fixed output
  instruction: write the answer as Markdown to `output.md` in the run folder) → `validate_output` (program: `output.md`
  exists, non-empty after strip, decodes as UTF-8) → retry `run_agent` up to 2 times → escalation gate (ADR-011,
  `attach_reliability`). The node re-checks D3 with the core's copy of the rule data passed in by the app (the worker
  never imports app code, ADR-012): the app passes the pickable decision in inputs and the node refuses any server not
  marked pickable; record the exact mechanism in As built.
- `graph:` topology in `workflow.yaml` (L-006); parity lint green (L-013).
- Output viewed in Run Detail's documents (`/runs/:runId/docs/output.md`); declare `output.md` as the node's
  `output_doc` so the existing document list shows it.
- Tests in the workflow folder (no `tests/__init__.py`, L-092): graph builds; validator passes and fails on the right
  files; the effective-set merge.

## 5. `schedulable` META key

- genesis: `META.schedulable` (bool, default false) read from `workflow.yaml` by the loader (`dist/loader.py`), exposed
  in `GET /api/catalog` items and `GET /api/workflows/{id}` (54-06), parity lint knows the key.
- genesis-workflows: `schedulable: true` on `agent-prompt` and on standalone workflows that are safe unattended. Check
  each candidate before flagging (no stage/story binding in the finalizer registry, no `pre_mutation` gate, no write
  server, inputs that can be stored): `sync-documents`, `generate-business-map`, `hello-appian`,
  `memory-consolidation`, `memory-maintenance`. Record the final list and the reason for each exclusion in As built.
- A schedule's stored inputs may not contain `format:"file"` fields this phase (files are uploaded per launch,
  ADR-035); a workflow whose required inputs include a file is not offered (a default set in this sub-spec; the user
  may object at review).

## 6. One-off Run of a custom agent (D5)

`POST /api/custom-agents/{id}/run {prompt}` → `RunManager.start("agent-prompt", inputs with the snapshot)`;
`trigger_json` stays NULL (not a schedule). Refused with a clear message if `agent-prompt` is not installed (L-033).

## 7. Gates

genesis-core pytest + ruff; genesis pytest + ruff; genesis-workflows `ci/validate_library.py`, `ci/validate_skills.py`
if present, pytest (`workflows --ignore=workflows/_fixtures`).

## As built

**Status:** BUILT 2026-11-18, review **SHIP** (re-run 1). Local commits only (not pushed, not tagged). No migration
change (DB stays v30). No web behaviour change (one optional type field; `npm run build` left `web/static` identical).

### Commits

| repo | base → head | sha | what |
|---|---|---|---|
| genesis | `9a365c0` → `9f63fc2` | `9f5e618` | genesis-core per-run `kiro_node` args, `McpRegistry` tiers, `mcp/pickable.py`; `genesis/agents/` (store + inputs builder); worker registry; `schedulable` (loader, lint, catalog); hook wired; the Run route; tests |
| | | `9f63fc2` | review round 1: m1 (`update` under the write lock), m3 (app-wiring test), n1 |
| genesis-workflows | `d0c0f53` → `7b35f8a` | `e384914` | `workflows/agent-prompt/` 0.1.0; `schedulable: true` + patch bumps on sync-documents, generate-business-map, hello-appian (0.1.1); `registry.json` |
| | | `7b35f8a` | review round 1: M1 (the gate's Feedback answer re-runs with the note), m2 (test) |

genesis: 17 files, +1248/−26. genesis-workflows: 10 files, +674/−9.

### Changed

- **genesis-core** (additive, `CORE_MAJOR` stays 1, ADR-019):
  - `nodes/agent.py`: `kiro_node(mcp=, skills=, model=)` each take today's static value or a callable
    `(state, ctx) -> value` (`PerRun`), resolved first thing in the node by `_per_run` (type-checked: a list of str for
    `mcp`/`skills`, a str or None for `model`; `""` → None). The resolved values feed everything that read the static
    ones before: skill provisioning (the `skill_source` resolver with its front-matter check, L-115), `acp_servers`,
    `_node_mcp_trust` (`node.tools ∩ allowlist`), the options' `model`, and the `agent_start` / `agent.prompt` events
    (so ADR-066's capture shows what the run really used). A non-callable is returned untouched, so static callers are
    byte-identical.
  - `mcp/registry.py`: `McpRegistry(custom_names=, overridden_names=)`, `tier(name)` (`curated` | `custom` | None),
    `overrides_curated(name)`; `from_layers(..., override=True)` records both; `override=False` keeps the curated entry
    for a name in both tiers and adds only custom-only names. `load`/`from_dict` registries read as curated.
  - `mcp/pickable.py` (new) — **the one home of D3** (Q2): `PICKABLE_CURATED` (`appian-dev`, `genesis-kb`,
    `appian-atlas`), `NOT_PICKABLE_CURATED` (name → reason: `appian-dev-write`, `appian-dev-packages`, `appian-devops`,
    `jira`, `jarvis`, `appian-data-generator`), `classify`, `pickable_servers`, `check_picks`, `NotPickableError`
    (a `ValueError` with `.refused`). A curated server is pickable only when listed, not overridden and with a
    non-empty allowlist; an unclassified curated server is refused ("is not classified for agent prompts"); a custom
    server is pickable only with `read_only_mark: true` and never when it replaces a curated name.
- **genesis**:
  - `genesis/agents/` (new): `store.py` `CustomAgentStore` over m0030's `custom_agents` (§1 validation; delete 409 with
    `used_by`; `snapshot`), `prompt_inputs.py` `build_agent_prompt_inputs` (one builder for the schedule hook and the
    Run, L-109), `__init__.py` re-exports the core rule for app callers.
  - `runs/worker.py` `_load_registries` (Q1 = A): curated + custom-only names via `from_layers(override=False)`; an
    unreadable custom store falls back to curated only. Before this, a workflow run never saw the custom tier.
  - `dist/loader.py`: `schedulable_of(meta)` (only a literal `true`) and `InstalledWorkflowInfo.schedulable`;
    `runtime/schedule_targets.py` uses it.
  - `lint/contract.py`: `MIRRORED_BOOL_KEYS = {"schedulable"}` — must be a bool on each side, and a META value must be
    in `workflow.yaml` too (the app reads the yaml).
  - `api/catalog_routes.py`: `GET /api/catalog` items carry `schedulable`; `GET /api/workflows/{id}` already passes the
    yaml through. `web/src/types/catalog.ts`: optional `schedulable` on `CatalogEntry` and `WorkflowMeta`.
  - `api/app.py`: builds `CustomAgentStore(registry=config.merged_mcp_registry, installed_skills=<managed skill ids>)`
    (`app.state.custom_agents`), passes `agent_prompt_inputs` to `register_target_handlers`, registers the Run route.
  - `api/custom_agents.py` (new): `POST /api/custom-agents/{id}/run {prompt}` → `{run_id}`; `trigger` None.
- **genesis-workflows**:
  - `workflows/agent-prompt/` 0.1.0 (`graph.py`, `workflow.yaml`, `tests/test_workflow.py`; no `tests/__init__.py`,
    L-092; no `from __future__`, L-022): `run_agent` (`make_run_agent()`, the per-run callables) → `validate_output`
    (bytes → UTF-8, non-empty after strip) → 2 retries → `escalate` (approve or feedback → `retry_agent`, which resets
    the attempt count and puts the feedback into the next prompt; reject → `give_up`, status failed); pass → `finish`.
    `auto_approve: true`, `hitl_points: [escalate]`, `schedulable: true`, `artifacts: [output.md]`, no file input,
    `graph:` topology. The prompt = the agent's instructions, the task, the fixed instruction to write Markdown to
    `output.md` (with `# <title>` first when a title is given) and reply DONE, then any validator / reviewer feedback.
  - `schedulable: true` and a patch bump on `sync-documents`, `generate-business-map`, `hello-appian` (0.1.1);
    `registry.json` updated (text edit, existing `\u` escapes kept).

**The D3 re-check at node start (record of the mechanism, §4):** `run_agent`'s `mcp` callable is
`checked_server_names(state, ctx)`: it merges the agent's and the run's servers (`effective_servers`) and passes them to
`genesis_core.mcp.pickable.check_picks(ctx.mcp, …)` — the same function the store and the builder call — on the
**worker's own registry** (curated + custom-only, with tiers). A refused server raises `NotPickableError` before any
skill is provisioned or any turn starts, so the run fails with the reason. It does not trust any flag in the inputs,
because `POST /api/runs` can start `agent-prompt` with hand-written inputs; the worker imports only genesis-core
(ADR-012). This replaces the spec's "the app passes the pickable decision in inputs" wording (Q2, the user's choice).

**Final `schedulable` list (§5):** `agent-prompt`, `sync-documents`, `generate-business-map`, `hello-appian`. Checked
for each: no binding in the finalizer registry, no `pre_mutation` gate, no write server (`required_mcp: []` for all
four), inputs a schedule can store (no `format: file`).
- `sync-documents`: no agent, no MCP, string/int inputs. It is also a system job (`document-library-sync`), but
  manual syncs already overlap it today with no harm, so a user schedule adds no new kind of concurrency.
- `generate-business-map`: KB-only, `app_uuid` string; its optional `review` gate is handled by D8.
- `hello-appian`: no inputs, no MCP.
- **Excluded `memory-consolidation` and `memory-maintenance`.** The deciding reason (review n2): consolidation advances
  a cursor with no guard against a concurrent run (`runtime/memory_jobs.py`), and the overlap rule is per schedule, so
  a user copy beside the system row could distil the same sessions twice; maintenance shares the memory store and is
  kept with it. Both stay system schedules, with their options on the system row (D1/D15).
- Every other workflow stays off (stage-, story- or test-bound, or mutating; D7).

### Tests

- genesis-core `tests/test_agent_per_run.py` (11): static vs callable give equal options (trust, model, servers,
  events) and the callable is resolved once with the node's ctx; a callable naming a missing skill fails with the
  existing message and no turn; empty callables; wrong types fail before the turn; `from_layers` tiers and
  `override=False`; the rule lists are disjoint; `classify`/`check_picks` cases; a pickable curated server without an
  allowlist is refused.
- genesis `tests/test_custom_agents.py` (31): store create/get/list/snapshot, 11 validation cases, the model-list rule
  (Q4), unique names and partial update, two concurrent updates keep both edits (m1, fail-first on `9f5e618`), delete
  409 naming the schedules; the builder (snapshot, run picks, effective model; gone agent → `LookupError`; a server no
  longer pickable → `ValueError`); `schedulable_of`; the parity lint (6 cases); the worker registry (custom-only added,
  curated kept, unreadable store); the Run route through `create_app` + a real `RunManager` worker (snapshot in the
  inputs, trigger None, catalog/meta `schedulable`), its refusals (409 not installed, 404, 400 ×2, 422); the app wires
  the builder into agent-prompt schedules (m3: a fired schedule's run carries the snapshot taken at fire time and the
  trigger; fails when the wiring is removed).
- genesis `tests/test_scheduler.py` (+3): a wired builder starts `agent-prompt` with its inputs and trigger; a builder
  raising `LookupError` / `ValueError` records `failed` and counts. The 54-04 "skipped until wired" test still holds
  for a handler registered without a builder.
- genesis-workflows `workflows/agent-prompt/tests/test_workflow.py` (31): parity + trio; `graph:` ids = LangGraph
  nodes; no file inputs; the validator (5 bodies + missing file); the effective-set merge; the prompt; **every curated
  server in the real `mcp-registry.json` is classified, and nothing classified is missing from it** (the §2 test);
  pickable servers are `read-only` with an allowlist; each pickable server reaches the turn capped at its real
  allowlist and without `delete_file` (L-116); each refused server (and an unknown name) fails the node before any turn,
  from the run's picks and from an agent snapshot; a custom server needs the mark; skills from the managed workspace
  (the real `appian` installed through `SkillInstaller`), a missing skill and invalid front matter fail the node; the
  whole graph: done, retry then success, exhaustion → gate → reject = failed, approve = three more attempts then the
  gate again, feedback re-runs with the note, the gate prompt names every route.
- Mutation evidence: dropping `check_picks` from the node fails 8 tests; no retry reset fails the m2 test; feedback →
  reject fails 2; removing the app wiring fails the m3 test; the pre-fix `update` fails the m1 test. The reviewer
  repeated each.
- **Gates (final heads):**
  - genesis-core: pytest **120 passed**; `ruff check genesis_core` clean (5 pre-existing findings in `tests/`, outside
    CI's `genesis_core` scope).
  - genesis: `ruff check genesis` clean; full pytest **2039 passed** (22:45–22:56 IST, **outside** the 00:00–02:00
    D27 window, no deselect).
  - genesis-workflows: `ci/validate_library.py` PASSED (19 workflows); `ci/validate_skills.py` PASSED (5);
    `pytest workflows --ignore=workflows/_fixtures` **463 passed** (432 + 31).
  - web: `tsc --noEmit` clean; `npm run lint` 0 errors (20 pre-existing warnings); `npm run build` left `web/static`
    unchanged.
- `~/.genesis/genesis.db` was not read or written; every test uses a temp DB. No DB copy was made.

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-05-review.md`.
- **Round 1, NEEDS_CHANGES:** M1 (L-106: the gate's Feedback answer, offered on every gate by Run Detail, ended the run
  failed and dropped the note); m1 (`update` merged from a row read outside the write lock, L-091); m2 (the "3 more
  attempts" promise untested); m3 (no test of the app's hook wiring); nits n1–n3.
- **Re-run 1, SHIP.** Optional nits not taken: n4 (feedback from an earlier gate round stays in later prompts:
  `decisions` merges, and the prompt promises the feedback goes in); n5 (a hand-sent non-string feedback would make
  `build_prompt`'s `.strip()` raise; the UI always sends a string). Both are listed under follow-ups.

### Decisions / deviations

No ADR deviation. Decided by the user in this session (genesis-dev's questions):
- **Q1 = A.** The worker gains custom-only servers; a custom entry with a curated name is never applied in a run and is
  never pickable ("replaces a curated server of the same name").
- **Q2 = core.** The D3 rule lives in `genesis_core/mcp/pickable.py`; the node re-checks from the worker's registry
  (mechanism above). This replaces §4's literal "the app passes the pickable decision in inputs".
- **Q3 = ok.** The `schedulable` list and exclusions above, with patch bumps.
- **Q4 = ok.** A changed model is refused while the model list is unavailable; an unchanged model needs no list.

Mine:
- The escalation gate's routes (not in the spec): approve / feedback → `retry_agent` (attempt count reset, feedback in
  the prompt), reject → `give_up` (status failed, L-065); the prompt names all three (L-106, review M1).
- `description` capped at 1 000 characters (the spec gives no limit); `instructions` may be empty.
- `update` changes only the fields it is given (PUT-with-partial semantics for 54-06) and re-validates the merged row,
  so an agent whose skill was uninstalled cannot be saved until that skill is removed or reinstalled (review n3).
- The model list is passed in per call (`models=`), not fetched by the store, so no Kiro probe runs under the write
  lock.
- The Run route checks the prompt length (1–20 000, the schedule store's `MAX_PROMPT_CHARS`) and does not check Kiro
  sign-in (as `POST /api/runs`); the schedule handler does.
- `title` (§4) is honoured through the prompt (the agent writes `# <title>` first); the validator does not check it.

### Found, not fixed (follow-ups)

- n4 / n5 above (agent-prompt feedback carry-over; non-string feedback).
- The release (54-11): genesis-workflows' pins and `registry.json` `genesis_core_version` must move to the new genesis
  tag together (L-057). Until then the library's CI cannot import `genesis_core.mcp.pickable`, and the major-only gate
  will not stop a 0.82 app from loading `agent-prompt` (ADR-019 note in the review). Give it a CI-image run (L-112).
- Live acceptance (54-10): a real v3 turn with a per-run model, a provisioned skill and a picked server; a fired prompt
  schedule writing `output.md`; a custom server marked read-only; **Feedback at agent-prompt's escalation re-runs with
  the note**. All coverage here is offline (stub provider).
- Pre-existing, same L-106 pattern: `memory-consolidation` / `memory-maintenance` route every non-approve answer
  (including Feedback) to their reject path.

### For 54-06 / 54-07 / 54-08

- **Store** (`app.state.custom_agents`, a `genesis.agents.CustomAgentStore`; all blocking — call via
  `asyncio.to_thread` from async routes):
  - `list() -> [CustomAgent]` (by name), `get(id) -> CustomAgent | None`, `used_by(id) -> [{schedule_id, name}]`.
  - `create(data, *, models=None)`, `update(id, data, *, models=None)` (only the given fields; unknown fields 400),
    `delete(id)`.
  - `CustomAgent.to_dict()` = `{id, name, description, instructions, skills, mcp_servers, model, created_at,
    updated_at}`; `mcp_servers` items are `{name, read_only_mark}`.
  - Errors → HTTP: `CustomAgentError` 400; its subclass `CustomAgentRefused` 422 (server not pickable, skill not
    installed, unknown model, model list unavailable) — map the subclass first; `CustomAgentNotFound` 404;
    `CustomAgentConflict` 409 (name taken, or in use with `.used_by`).
  - `models=`: pass the ids from `ChatManager.available_models()["models"]` (fetch it before calling; None when the
    probe fails). Needed only when the model changes.
  - **n1 hand-off:** schedule create/update with an `agent_id` must check the agent exists under its own
    `BEGIN IMMEDIATE` (`ScheduleStore.create_user` checks only the type); otherwise a schedule saved after a delete
    fails at fire time with "custom agent N no longer exists".
  - **n3 for the UI:** a 422 on save can come from an unchanged field (a skill since uninstalled, a server since
    removed); show which field blocks it.
- **Snapshot** (`store.snapshot(id)`, what a run's `inputs.agent` holds): `{id, name, instructions, skills,
  mcp_servers, model}`. `CustomAgentNotFound` is a `LookupError`.
- **Inputs builder:** `genesis.agents.build_agent_prompt_inputs(target, *, agents, registry)` with `target` an
  `agent_prompt` schedule target or `{prompt, agent_id}` → `{prompt, agent?, skills, mcp_servers, model?, title?}`;
  raises `LookupError` (agent gone) or `NotPickableError` (`ValueError`). `registry` = `config.merged_mcp_registry`.
- **`pickable_servers(registry)` output** (for `GET /schedules/pickable`'s `servers`): a list sorted by name of
  `{name, tier: "curated" | "custom" | None, pickable: bool, needs_read_only_mark: bool, reason: str | None}`. A custom
  server shows `pickable: true, needs_read_only_mark: true` (D24's "This server only reads" tick); `reason` is the text
  for "Can't be picked". Validate a pick list with `check_picks(registry, picks)` → normalized
  `[{name, read_only_mark}]` or `NotPickableError(.refused = [{name, reason}])`. Import from `genesis.agents` (re-export)
  or `genesis_core.mcp.pickable`.
- **`schedulable`:** `genesis.dist.loader.schedulable_of(meta)` / `InstalledWorkflowInfo.schedulable`; `/api/catalog`
  items have `schedulable`; the file-input rule is `runtime.schedule_targets.file_inputs(meta, stored)`.
- **The Run route:** `POST /api/custom-agents/{id}/run {prompt}` → `200 {run_id}`; 400 (prompt empty or > 20 000), 404
  (no agent), 409 (`agent-prompt` not installed, L-033), 422 (a server no longer pickable). 54-06 adds the CRUD routes
  in `api/custom_agents.py` (`register_custom_agent_routes(api, *, agents, run_manager, registry)`); register static
  paths before `/custom-agents/{agent_id}` routes (L-096).
- **For 54-08 (chat):** the agent's servers through `check_picks` against `config.merged_mcp_registry()`; the
  snapshot's `instructions`/`skills`/`mcp_servers` are what the chat session adds (D6).

### Lesson candidates

1. **When a value moves from "a flag the caller sets" to "a rule the executor checks", recompute it at the executor
   from its own data.** The spec had the app pass a pickable decision in the inputs; `POST /api/runs` accepts any
   inputs, so the node re-checks with the shared rule on the worker's registry (L-109 one home, L-116 real registry).
2. **A worker that builds its own copy of a two-tier registry silently drops the second tier.** ADR-029 said custom
   servers reach "per-node injection automatically", but `runs/worker.py` loaded the curated file only; the gap was
   invisible until a feature needed a custom server in a run. When a layered config is re-read in another process,
   test that process's view of each tier.
3. **A gate's options are not the only answers it gets** (extends L-106): Run Detail offers Feedback on every gate, so
   a route function must handle approve, feedback and reject, and a test must send each.

### Code-map changes (for genesis-docs, bible/03)

- `packages/genesis-core/genesis_core/nodes/agent.py`: `kiro_node(mcp=, skills=, model=)` accept `PerRun` callables;
  `_per_run`.
- `packages/genesis-core/genesis_core/mcp/registry.py`: `tier`, `overrides_curated`, `from_layers(override=)`.
- `packages/genesis-core/genesis_core/mcp/pickable.py` (new): `PICKABLE_CURATED`, `NOT_PICKABLE_CURATED`, `classify`,
  `pickable_servers`, `check_picks`, `NotPickableError` — the read-only server rule (D3).
- `genesis/agents/` (new): `store.py` (`CustomAgentStore`, `CustomAgent`, the four errors), `prompt_inputs.py`
  (`build_agent_prompt_inputs`).
- `genesis/api/custom_agents.py` (new): `register_custom_agent_routes` (the Run route).
- `genesis/runs/worker.py` `_load_registries`: curated + custom-only.
- `genesis/dist/loader.py`: `schedulable_of`, `InstalledWorkflowInfo.schedulable`.
- `genesis/lint/contract.py`: `MIRRORED_BOOL_KEYS`.
- `genesis/api/app.py`: `app.state.custom_agents`; `agent_prompt_inputs` wired.
- genesis-workflows `workflows/agent-prompt/` (new, 0.1.0); `schedulable: true` on sync-documents, generate-business-map,
  hello-appian (0.1.1).

## Context manifest

```toml
areas    = ["core-engine", "workflows-library"]
adrs     = ["ADR-006", "ADR-010", "ADR-011", "ADR-012", "ADR-019", "ADR-021", "ADR-029", "ADR-032", "ADR-035", "ADR-068", "ADR-069", "ADR-073", "ADR-083", "ADR-086"]
lessons  = ["L-002", "L-006", "L-013", "L-016", "L-033", "L-042", "L-092", "L-109", "L-113", "L-115", "L-116"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/runtime/context.py", "genesis/genesis/dist/loader.py", "genesis/genesis/lint/**", "genesis/genesis/agents/**", "genesis-workflows/workflows/agent-prompt/**", "genesis-workflows/registry.json", "genesis-workflows/mcp-registry.json"]
upstream = ["54-04"]
```
