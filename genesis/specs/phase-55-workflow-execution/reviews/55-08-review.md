# Review 55-08 — base 0a4acd0c, head be3097b3 (genesis-review, 2026-11-23)

What this change does: it adds the Phase 55 run-action routes (`fix-and-accept`, `relaunch`, `restart-from`, and
`respond` with action dicts) behind one error mapper. It adds the D23 relaunch policy (one reader shared by
`RunManager` and the parity lint, plus the ADR-068 `appian-dev-write` guard) and the D22 audit fields on action
events. It also lands the D20 System-path refusal on the file routes, the `/documents` `writing`/`legacy` fixes, the
scheduler following a replaced run, the D25 consolidation filter, and the web types and client functions checked
against recorded fixtures. No migration (DB v30).

Commits checked: `bd9873c6` (source, tests, fixtures) and `be3097b3` (web/static); both exist and the tree is clean.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `pytest -q -p no:warnings` (genesis, `GENESIS_STATE_DIR=/tmp/gr-55-08-review/state`) | **2376 passed, 4 skipped** in 14:16 (`/tmp/gr-55-08-review/pytest-full.txt`). This matches the author. `git status` stayed empty, so the fixture recorder compares and does not rewrite. |
| `ruff check genesis` (ruff 0.15.20) | All checks passed |
| `packages/kiro-agent-sdk` pytest | 302 passed |
| web `npm run typecheck` | clean |
| web `npm run lint` | 0 errors, 20 warnings (the baseline) |
| web `npx vitest run` | 84 files, 971 passed |
| Stale bundle: `npx vite build --outDir /tmp/gr-55-08-review/static` then `diff -rq … web/static` | IDENTICAL |
| genesis-workflows `ci/validate_library.py` | exit 1 with the 56 F8 violations expected until 55-10, none about `relaunch` (`/tmp/gr-55-08-review/vl.txt`) |

## Checklist

ADRs
- [N/A] ADR-001 — no control flow moved to an agent. Relaunch, restart and fix are program methods on `RunManager`.
- [N/A] ADR-002 / ADR-004 / ADR-020 — no ACP or MCP injection change.
- [N/A] ADR-005 / ADR-029 — no registry or trust change. The guard only reads `required_mcp` and the graph `mcp` names.
- [N/A] ADR-008 — no change to how the app bundles engine and UI.
- [OK] ADR-009 — all three HITL modes are kept. `fork` is unchanged (`run_routes.py` fork route untouched). `respond` still resumes a gate. The new 409 applies only to a run that is not at a gate (`manager.py` respond; `test_respond_refuses_a_run_that_does_not_wait_at_a_gate`).
- [OK] ADR-010 / ADR-018 / ADR-022 — the audit `params` hold small values (path, instructions ≤ 4000, step, values). No bulk data goes into state or events.
- [N/A] ADR-011 — no agent node added. `validate_library` shows only the expected F8 set.
- [OK] ADR-012 — the policy reads the installed `workflow.yaml` through `loader.meta_of` (`manager._meta`), never `graph.py`.
- [N/A] ADR-019 / ADR-046 / ADR-080 — no version or packaging change. `check_compat` still runs inside `_meta`, and a failure there is refused fail-closed (`test_an_unreadable_workflow_is_never_relaunched`).
- [OK] ADR-021 / ADR-068 — whatever the flag says, a workflow that uses `appian-dev-write` is never relaunched or restarted (`relaunch_policy.write_refusal`, checked first in `_new_run_refusal`). `story-implementation`'s yaml declares it in `required_mcp` and on its nodes. The lint flags `relaunchable: true` together with dev-write. See m1 and m2 for the edges this misses.
- [N/A] ADR-023 / ADR-024 — no engine change.
- [OK] ADR-025 — restart still forks a new thread. `fork` is untouched, and the original's checkpoints stay as they were (55-06/07 code, only wrapped in `_replacing`).
- [OK] ADR-026 — no new network surface or bind change.
- [N/A] ADR-027 / ADR-055 — no UI components. The mockup now only imports the real types.
- [OK] ADR-028 / L-010 — the new client functions use `api.post/get` with paths without `/api` (`lib/api/runs.ts`, `lib/api/resolve.ts`). The only literal `/api` is the existing download href in the api layer.
- [N/A] ADR-030 / ADR-041 — no store or table added (no migration).
- [OK] ADR-031 / ADR-033 / ADR-034 — copilot `respond_to_gate` is still confirmed by a person in chat. It is now only labelled `source: "copilot"` (`run_routes.py` respond; test in `test_respond_takes_action_dicts_and_maps_the_errors`). The copilot gets no new tool, and the Resolve agent still cannot call `/respond`.
- [N/A] ADR-032 — no credits touched.
- [OK] ADR-035 — relaunch re-provisions uploads through `_reupload` (unchanged). The new body carries no inline inputs.
- [N/A] ADR-037, 042, 043, 045, 047, 049, 050, 051, 059–063, 065, 069, 071, 073–076, 078, 079, 083, 085, 086 — not touched by this diff.
- [OK] ADR-053 / ADR-054 — D25: consolidation never reads `run_resolve` sessions (`chat_read.py` SQL filter). memory.db is untouched.
- [OK] ADR-066 — node iterations are untouched, and the `_prompts/` reader still answers 200 (`test_the_file_routes_refuse_system_paths`).
- [OK] ADR-077 — no agent-system change.
- [OK] ADR-081 / ADR-082 / ADR-084 — the service refusals for test-execution, story-verification, setup-composer and action-capture come before the flag (`_new_run_refusal` order; `test_an_unflagged_workflow_is_not_relaunched_and_a_service_refusal_comes_first`). I agree with choice a below.
- [OK] ADR-087 — a scheduled run's row follows its replacement and stays a `scheduled_jobs` row (`scheduler._successor`; `test_55_08_a_relaunched_scheduled_run_is_followed_to_the_run_that_finishes`).

Lessons
- [N/A] L-001, L-002, L-009, L-016, L-017, L-019, L-020, L-021, L-023, L-024, L-026, L-031, L-041, L-042, L-044–L-048, L-050, L-051, L-058–L-062, L-065, L-068, L-069, L-073, L-086–L-088, L-097–L-101, L-104, L-105, L-113–L-119, L-125 — their areas are not touched by this diff.
- [OK] L-003 / L-018 — `streamNotifications` only became generic. The reader `readSse` is unchanged.
- [OK] L-004 — no JSON-file state was added.
- [OK] L-005 / L-122 — no new event kinds. `run.relaunched` and `file.written` were already canonical, and `events.ts` golden payloads are updated (choice h).
- [OK] L-007 — transcript folds are untouched.
- [OK] L-008 — no exit-path change.
- [OK] L-011 / L-083 — fixtures are recorded by `tests/test_phase55_api.py` (`contract_fixtures.record`, which compares unless `GENESIS_WRITE_CONTRACT_FIXTURES=1`). `phase55-contract.test.ts` parses each fixture through the real client with `Exact<T>` both ways. No host paths or memory text are in the fixtures (grep of `runs/*.json`, `resolve/*.json`).
- [OK] L-025 / L-027 — ruff stays pinned at 0.15.20.
- [OK] L-030 / L-056 / L-089 — `be3097b3` carries `web/static` (66 files), and the reviewer's out-of-tree build is identical.
- [N/A] L-033 — an uninstalled workflow answers 409 with the reason (`_action_errors` FileNotFoundError), not 500.
- [OK] L-039 — `_record`/`_trigger` serve the list and the single get alike.
- [OK] L-057 / L-112 — no pins change. CI is not run before release; that is the release agent's job.
- [OK] L-066 — `current_run` reads `eventlog.latest` once per hop (≤ 50 hops), with no full-log fold per tick.
- [OK] L-081 — `relaunchable` defaults to false (D23), so older or unflagged workflows stay as they were. The old route set gains routes only.
- [OK] L-091 — no check-then-write was added on the DB. Replacement stays inside `_replace_lock`, and the scheduler's `set_run` is a single write.
- [OK] L-092 — the new test module is `tests/test_phase55_api.py` with no new `__init__.py`.
- [OK] L-093 — `run.relaunched` is still logged after the old run's terminal store and `run.final`.
- [OK] L-094 — callers were checked. `respond`: the route, `ResolveService.confirm` (resolve.py:668) and `fix_and_accept` (manager.py:1195). The copilot MCP `respond_to_gate` checks the gate first (control_server.py:234–248). `_trigger` consumers: `ScheduledBadge` returns early on a non-`schedule` source, `RunsTable` and `RunDetailPage`. `sessions_since` consumers: `memory_jobs._has_new_sessions` and the `memory-consolidation` workflow's `_resolve_window`. `_artifact_path` readers are as listed in its docstring.
- [OK] L-096 — `test_no_run_route_is_shadowed_by_an_earlier_one` and `test_each_new_route_answers_with_its_own_handler` check route order by behaviour.
- [N/A] L-102 / L-103 — no migration.
- [OK] L-106 — the gate's `allowed` is re-read live in `gate_allowed` for the run-level actions, so the cards match what apply does. See n1 for the snapshot copy.
- [OK] L-107 — `_replacing` is popped in `finally` on every path of relaunch and restart.
- [OK] L-108 — replacement still cancels through `cancel` (stop intent, then CAS).
- [OK] L-109 — one reader: `parse_relaunch`, used by `RunManager._relaunch_policy` and `lint.check_relaunch`. Parity is proven by `test_the_manager_and_the_lint_share_one_reader`. One System-path list (`is_system_path`) serves the categorizer and the routes.
- [OK] L-110 — gates were re-run by the reviewer at `be3097b3` on a clean tree.
- [OK] L-111 — no live acceptance claimed; 55-11 owns it (see Not checked).
- [OK] L-120 — every mutating route answers the run to follow, and the scheduler follows `run.relaunched.to_run`.
- [OK] L-121 — `respond` now refuses a run that is not at a gate. Before, it logged `gate.resolved` and spawned a second resume worker on a running run.
- [OK] L-124 — the scheduler stores the successor on the row (`set_run`) and clears `gate_opened_at`, so a restart keeps the decision. The in-flight `_replacing` window only makes the tick wait; it decides nothing.

Gates
- [OK] all listed gates — see the table above.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **The write guard fails open on a scalar server list** (`genesis/runs/relaunch_policy.py` `_servers`). What: `{s for s in (meta.get("required_mcp") or []) if isinstance(s, str)}` and the same for `node.get("mcp")` iterate whatever value is there. Problem: `required_mcp: appian-dev-write` (a YAML scalar, not a list) or a graph node `mcp: appian-dev-write` iterates the string's characters. With `relaunchable: true`, `parse_relaunch` then gives `RelaunchPolicy(relaunchable=True, write_servers=())` and no lint error. Verified: `parse_relaunch({'relaunchable': True, 'graph': {'nodes': [{'id': 'a', 'mcp': 'appian-dev-write'}]}})` returns that policy with `[]` errors. This is the ADR-068 guard, and the module docstring promises fail-closed. Fix: in `_servers`, treat a `str` as a one-item list, and have `parse_relaunch` report a non-list value as a lint error. Add the two cases to `test_the_relaunch_policy_reader`. If skipped: a malformed library entry turns the Dev-write guard off silently.
- m2 **The guard sees only what `workflow.yaml` declares** (`relaunch_policy._servers`). What: the app reads `required_mcp` and the optional `graph:` topology (ADR-012). Problem: nothing in genesis or genesis-core makes a node's `kiro_node(mcp=[…])` a subset of `required_mcp` (grep of `required_mcp` in `packages/genesis-core` and `genesis/runs` finds no such check). A workflow that names `appian-dev-write` only in `graph.py` and declares `relaunchable: true` would be relaunchable. No library workflow does this today; `story-implementation` declares it in both places. Fix: in 55-10 or a backlog item, have a publish-time lint check each agent node's `mcp` against `required_mcp`. The reliability lint already walks the compiled graph's agent nodes. Record this as an accepted limit in As built. If skipped: the guard depends on the author's declaration.

### Nits
- n1 **Two copies of the run-level `allowed` can disagree** (`manager._enrich_gate` vs `gate_allowed`). The snapshot's and record's `gate.allowed.relaunch` / `restart_from` are the values from when the gate was raised. `/resolve/escalation` re-reads them live. After a library update of the flag, the manual menu (55-09) would offer what the route then refuses with 409, or the reverse. The apply-time check keeps it safe. Fix: say in the contract table which copy is live, and have 55-09 take the run-level keys from `/resolve/escalation` (or overlay `gate_allowed` in the snapshot).
- n2 `genesis/runs/documents.py` keeps literal status sets (`_TERMINAL`, the new `_WRITING`) rather than `store.TERMINAL` / `{store.PENDING, store.RUNNING}`. `_TERMINAL` was already like this, but the new set adds a second copy that must change with the store.
- n3 `POST /runs/{id}/fix-and-accept` on a run whose Resolve chat was never opened answers 400 "chat session 'resolve-r-…' does not exist". For the manual menu, "open Resolve first: the fixed file comes from its sandbox" would say what to do.

## The author's choices (a–h)

- a. **Agree.** A capture record bound to the run (`CaptureStore.bind_run` / `set_status(run_id=)`) is broken by a queue-skipping run in the same way an execution record is (the ADR-081 reason D23 names). List all four service refusals with this reason in As built, and have the spec agent note it against D23.
- b. **Agree.** 400 for an `allowed` refusal matches the respond row and D21's mapping. The spec table cell "409 not allowed" should be corrected by the spec or docs agent.
- c. **Agree.** It is a true record, and the ADR-033 posture is unchanged. D22 and the ADR-089 draft list `resolve | manual` and should add `copilot`.
- d. **Agree.** The caller cannot fix stored inputs in this body, so 409 with the details fits.
- e. **Agree, and it fixes a latent bug** (a second resume worker on a running run, the L-121 shape). It is tested. Both consumers already check for a gate first.
- f. **Agree.** It has the same effect as advancing past those chats, and the preflight skip is tested.
- g. **OK.** The text names the server and gives the hint. The lint error on `relaunchable: true` plus dev-write is what 55-10 needs.
- h. **OK.** The golden payloads match the audit shape the backend writes.

## For As built (not findings)
- The spec file has no As built yet. It should record choices a–h, the m2 limit, and the routes' consumers (L-094).
- The live effect: every library workflow is unflagged until 55-10, so on this code Rerun and Restart are refused for all of them, from Resolve and from the routes alike (D23 default).

## Not checked
- Live acceptance on a real escalated run (Resolve confirm of each action, manual routes from the UI). This belongs to 55-11 per the brief: no fleet restart, no Appian or credit-heavy runs.
- The 11 mutation probes in `/tmp/gr-55-08/probe.py` were not re-run. I re-ran the full suite and read the tests that cover each new branch instead.
- Following a replacement for followers other than the scheduler, such as a copilot chat's `chat_run_links` run notifications. The spec scopes the follow-up to the scheduler.
- On a crash between the cancel and the `run.relaunched` log, `_replacing` is lost, so the schedule row closes as cancelled. This is an accepted limit of an in-memory map and was not probed.

## Verdict: SHIP

No blockers and no majors, and every gate is green as re-run by the reviewer. m1 is small and should be fixed in this sub-spec's follow-up commit or 55-10, with its test. m2 should be recorded as a limit.
