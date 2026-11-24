# 55-08 — HTTP API: the contract table, Resolve session storage, web types and fixtures

> **Status:** BUILT 2026-11-23 (genesis `bd9873c6`, `be3097b3`, `1f8fd8b5`; review SHIP; D26; no migration; shipped in v0.84.0). SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/api/`, `genesis/db/`, `web/src/types/`,
> `web/src/lib/api/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. 55-03..55-07 add their
> own routes; this sub-spec owns the table, adds what is left, and makes every shape a typed, fixture-tested contract
> (L-011, L-109). All under `/api`, the client prepends it centrally (ADR-028, L-010).

## 1. Contract table

| Method + path | From | Body / query | Answer | Errors |
|---|---|---|---|---|
| `GET /runs/{id}/snapshot` | 55-03 (built) | — (`?since_version` not built: a pause writes no event, so an equal seq cannot prove the snapshot unchanged; the client keeps an equal version and drops a lower one) | `RunSnapshot`, nodes also carrying `tool_calls`, `messages`, `entered_from` | 404 |
| `GET /runs/{id}/live` (SSE) | 55-03 (built) | `Last-Event-ID` / `?after=` | lifecycle hint frames with `id:`; `run.final` frames carry `status` (the client closes only on a terminal one); a reconnect that missed hints gets one `resync` frame, never a replay; `ping` every 15 s; read with `fetch` + `readSse`, not `EventSource` | 404 |
| `GET /runs/{id}/documents` | 55-05 (built) | — | `RunDocuments` as built (55-05 As built decisions 9–15: `writes` = record count, 0 = unknown; `writing`, `legacy`, `roles_declared`, `status`, `version`; steps with `label`, `description`, `kind`; `tool_outputs`). **Two fixes here:** `legacy` = "the run finished with no write records" (review N4; a new run that has not written yet is not legacy); `writing` only while the run is `pending`/`running` (review m5: a paused or gated run must not show "being written"). `execution` counts distinct task ids (a gate resumed with the same id is one execution), which can differ from the snapshot's ↻; 55-09 labels it so. `file.written` is **not** a `/live` hint: Documents re-reads on `node.completed` (the files are diffed at the same task finish) and the 3 s poll | 404 |
| `POST /runs/{id}/respond` (extended) | 55-06 | a legacy decision **or** `{action: retry\|accept\|stop\|<extra>, guidance?, reason?, ...extra}` | as today | 400 action not allowed (`allowed[action]` is a reason), 409 not at a gate |
| `POST /runs/{id}/fix-and-accept` | 55-06 | `{path, proposal_id?, source_file}` | `{run_id, status}` | 400 path refused, 409 not allowed |
| `POST /runs/{id}/relaunch` | 55-06 | `{instructions}` (D13; the inputs are reused unchanged, no multipart) | `{run_id, from_run}` | 400 instructions too long, 409 run still running (not at a gate), 409 a queue-managed workflow (55-06 decision 8, with its reason) |
| `POST /runs/{id}/restart-from` | 55-06 | `{from_step, values?}` (D15, D21: the step the user restarts **from**; the server resolves it to a checkpoint — the latest one whose `next` holds that step — and forks there, so the caller never deals with `as_node`'s "continue after" meaning) | `{run_id, from_run, from_step}` | 400 unknown step / no checkpoint before it / invalid values, 409 run running (not at a gate), 409 a queue-managed workflow (55-06 decision 8, with its reason) |
| `POST /runs/{id}/fork` | exists | unchanged (ADR-009 mode 3: no cancel, no rebind) | unchanged | — |
| `POST /runs/{id}/resolve` | 55-07 | — | `{session_id, created}` (idempotent: returns the existing session) | 409 run never escalated |
| `GET /runs/{id}/resolve` | 55-07 | — | `{session_id?, proposals: [...], credits}` | 404 |
| `POST /runs/{id}/resolve/proposals/{pid}/confirm` | 55-07 | optional edited params (guidance text, instructions, reason) | `{outcome}` (new run id where relevant) | 409 stale, 400 invalid |
| `POST /runs/{id}/resolve/proposals/{pid}/dismiss` | 55-07 | — | `{ok}` | 404 |
| chat messages / stream of the Resolve session | exists | the existing `/chat/sessions/{sid}/…` routes | + the `resolve.proposal` event | — |

Every mutating route writes its `copilot_actions` row (55-06 §3). Register specific routes before any generic path
route that also matches them and prove the order by behaviour (L-096). Each route is listed with its consumers (web,
copilot control MCP, tests) before an existing one changes (L-094).

**System files (D20):** `GET /runs/{id}/artifacts/{name:path}` and its `/download` refuse (403) a path under `_kiro/`,
`.kiro/`, `.pids/` or `checkout/` — the run's Kiro home is not confirmed free of secrets — so the "not previewable"
rule of 55-09 is enforced on the server, not only hidden in the page; list the routes' other readers first (L-094).

**From 55-06's As built (D21):** the routes for respond (action dicts), fix-and-accept, relaunch and restart-from are
added here (55-06 built the `RunManager` methods only). Error mapping: `RunActionError` and `GateResponseError` → 400;
`RunStateError` → 409; an unknown workflow (`FileNotFoundError`) → 409. Each mutating route returns the new run id and
the caller follows it (L-120). Contract rows for the enriched gate payload (`history`, `files`, `allowed` with the six
keys + one per extra option, `extra_options [{id, label, hint}]`) and `run.relaunched {to_run, source}`. **Scheduler
follow-up (55-06 m2):** a scheduled run that is relaunched or restarted must not leave its schedule's history on the
cancelled run — the scheduler follows `run.relaunched.to_run` to the run that finishes (L-120). **Audit (D22):** no
audit migration; every action route makes sure the run's event (`gate.resolved`, `run.relaunched`, the `_resolve`
`file.written`) carries `actor`, `source` (`resolve` | `manual`), `action`, the parameters and the `proposal_id` when
there is one (55-06 records `source` today — add the rest), and the contract rows list those fields.

**Relaunchable flag (D23), built here:** one reader for `META.relaunchable` (bool, default `false`) and
`META.relaunch_hint` (str), used by `RunManager` (it computes `allowed.relaunch` / `allowed.restart_from` when it
enriches the gate payload, and `relaunch` / `restart_from` re-check at apply time) and by the parity lint
(`genesis/lint/contract.py`, both keys mirrored in `workflow.yaml`; L-109, a parity test). When false the reason is
the hint, else "This workflow can't be started again from Resolve; start it from where you launched it". **Guard:**
whatever the flag says, refuse (409) a workflow whose `required_mcp` or any node's MCP includes `appian-dev-write`
(ADR-068). The 55-06 service refusals stay where a run that skips the queue would break an execution record
(ADR-081) and for a test-design top-up (per run); list each with its reason in As built.

**From 55-07's As built (D24):** 55-07 already built the Resolve routes (open, read, escalation, proposals confirm /
dismiss), an internal token-checked route its MCP server uses to store a proposal, and `POST /runs/{id}/restart-from
{from_step, values?}` → `RunManager.restart_from(run_id, from_step=…)`. Here: contract rows and **recorded** fixtures
for those routes and the session-stream events (`resolve.proposal {proposal}`, `resolve.note {kind, text, gate_seq |
proposal_id}`, Genesis-turn events carrying `turn: "genesis"`); the `ResolveProposal` type `{id, action, params,
rationale, status: proposed | applying | confirmed | failed | dismissed | stale | superseded, gate_seq, proposed_at,
resolved_at, run_id, result_run_id, error}`; **replace `ResolveService._allowed`'s interim `WRITE_SERVERS` guard with
the D23 reader and guard**, and apply the same guard to the manual relaunch and restart routes. A proposal too long to
store whole is refused with guidance to shorten it (55-07); keep that answer in the contract.

**Memory consolidation skips Resolve chats (D25), built here:** `genesis/memory/chat_read.py` leaves out
`run_resolve` sessions (a mode filter, tested with a Resolve session beside a normal chat; the consolidation cursor
still advances past them).

## 2. Resolve session storage (F15; settled by 55-07, D24)

**No migration.** 55-07 names the Resolve session `resolve-<run_id>`, so the run → session link is the session id
itself; `chat_run_links` keeps its one copilot session per run. Drop the planned m0031 `run_resolve_sessions` table;
add a migration only if this sub-spec finds a need, recorded as a decision in 55-01 §9 first. DB stays v30.

## 3. Web types and fixtures

`web/src/types/`: `RunSnapshot` (built in 55-03 as `types/snapshot.ts`, with `active_edges` and the extra node fields; its fixtures `web/src/test/fixtures/runs/{snapshot-gate,snapshot-done,live-frames,graph-states}.json` are real), `LiveHint`, `RunDocuments`, `RunDocument`, `EscalationPayload`
(the F6 fields under the approved mockup's names, D12 item 10: `failed_node`, `validator_messages`, `history`,
`last_error`, `files`, `allowed`), `ActionKey` (`retry | accept | fix_accept | relaunch | restart_from | stop`),
`ResolveProposal`, the run `trigger` shape (`source`, `from_run`, `instructions?`, `as_node?`), the new event kinds
(`node.started`, `memory.brief`, `file.written`, `run.relaunched`) in the one web list tested against the backend list
both ways (L-122). Move the mockup's types from `web/src/dev/mockups/phase55/fixtures.ts` into `web/src/types/` rather
than redefining them, and point the mockup at the real types. `web/src/lib/api/runs.ts` (and
a `resolve.ts`): one client function per route. Golden fixtures captured from real responses of a real run on the
local build (L-011, L-083), not hand-written.

## 4. Tests

Route tests for each row (happy path + each error); route order (L-096); migration up from v30 on a copy of real data;
fixture parity tests.

## 5. Gates

genesis pytest + ruff; web lint, typecheck, test.

## Context manifest

```toml
areas    = ["api", "runs-worker", "chat", "db"]
adrs     = ["ADR-025", "ADR-026", "ADR-028", "ADR-030", "ADR-033", "ADR-035"]
lessons  = ["L-010", "L-011", "L-083", "L-091", "L-094", "L-096", "L-102", "L-109", "L-122"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md"]
code     = ["genesis/genesis/api/run_routes.py", "genesis/genesis/runs/documents.py", "genesis/genesis/runs/manager.py", "genesis/genesis/lint/contract.py", "genesis/genesis/memory/chat_read.py", "genesis/genesis/db/migrations/**", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
upstream = ["55-03", "55-05", "55-06", "55-07"]
```

## As built

**Status:** BUILT 2026-11-23, review **SHIP** (round 1; `reviews/55-08-review.md`). Repo genesis, branch master, base
`0a4acd0c`, head `1f8fd8b5`, 3 local commits (not pushed, not tagged). **No migration** (DB stays v30, D24); no
genesis-core or kiro-agent-sdk change (`CORE_MAJOR` 1).

### Commits (genesis)

| sha | what |
|---|---|
| `bd9873c6` | source, tests, web types and client, recorded fixtures |
| `be3097b3` | `web/static` for bd9873c6 (66 files) |
| `1f8fd8b5` | review fixes m1, n2, n3 (backend and tests only; no web file, so no bundle) |

Bundle proof (L-089): `git show --stat be3097b3 -- web/static` in its own call after the build exited; a second build in
a later call left `git status --short --untracked-files=all` empty. The reviewer's out-of-tree build was identical.

### The contract table as built (every Phase 55 route; all under `/api`)

Error mapping for the run-action routes (`run_routes._action_errors`): `RunActionError`, `GateResponseError`,
`StateEditError` → **400**; `RunStateError`, `FileNotFoundError` (workflow not installed), `InputValidationError` (the
old inputs fail the installed schema) → **409**; unknown run → **404**. Error bodies are `{detail: str}` (fixtures
`runs/error-400.json`, `runs/error-409.json`).

| Method + path | Body | Answer | Errors | Consumers (L-094) | Fixture |
|---|---|---|---|---|---|
| `GET /runs/{id}/snapshot` | — | `RunSnapshot` (55-03) | 404 | web `useRunSnapshot` | `runs/snapshot-{gate,done}.json` |
| `GET /runs/{id}/live` (SSE) | `Last-Event-ID` / `?after=` | hint frames (55-03), no `?since_version` (D16) | 404 | web `useRunLive` | `runs/live-frames.json` |
| `GET /runs/{id}/documents` | — | `RunDocuments`; `legacy` = finished with no write record; `writing` only while pending/running | 404 | web `runsApi.documents` (55-09), genesis-resolve `get_run_documents` | `runs/documents-done.json` |
| `GET /runs/{id}/artifacts/{name:path}` and `…/download` | `?mode=` | as before | **403** System file (`_kiro/ .kiro/ .pids/ checkout/`, judged on the resolved path and the requested name, case-insensitive), 404, 413, 415 | DocumentViewer, DocumentsTab, NodeIterationsDialog (`_prompts/`), documents `useArtifactContent`; no MCP server | — |
| `POST /runs/{id}/respond` | `{decision}`: legacy string / `{feedback}` / action dict `{action, guidance?, reason?, …}` | `{ok, run_id}` (same run) | 400 not allowed (the `allowed` reason) or a run operation; **409 not at a gate** (also a running or paused run) or terminal | web `hitl-hooks`, copilot `respond_to_gate` (recorded `source: "copilot"`) | `runs/respond.json` |
| `POST /runs/{id}/fix-and-accept` | `{path, source_file, proposal_id?}` (`source_file` in the run's Resolve sandbox `resolve-<run_id>`) | `{run_id, status}` (same run, resumed) | 400 Resolve never opened / path refused / not a sandbox file / `allowed.fix_accept` reason / proposal not of this run; 409 not at a standard gate | web (55-09 manual menu) | `runs/fix-and-accept.json` |
| `POST /runs/{id}/relaunch` | `{instructions}` (≤ 4,000) | `{run_id: new, from_run}` | 400 too long / an upload gone; 409 running or paused, replaced already, write guard, a service refusal, not relaunchable, bound object moved, workflow unreadable, inputs refused | web (55-09) | `runs/relaunch.json` |
| `POST /runs/{id}/restart-from` | `{from_step, values?}` | `{run_id: new, from_run, from_step}` | 400 unknown / first / fan-in step, invalid `values`; 409 as relaunch (plus done) | web (55-09) | `runs/restart-from.json` |
| `POST /runs/{id}/fork` | unchanged | unchanged | — | web state editor | — |
| `GET /runs/{id}` | — | as before; `trigger` is now a union: schedule `{source, schedule_id, schedule_name, slot}` or `{source: relaunch \| restart_from \| fork, from_run, instructions?, from_step?, as_node?}` | 404 | Runs list, Run Detail, `ScheduledBadge` | `runs/run-{relaunched,restarted}.json`, `runs/escalation-gate.json` (the `gate`) |
| `POST /runs/{id}/resolve` | — | `{session_id, created}` | 404, 409 never escalated | web `resolveApi.open` | `resolve/open.json` |
| `GET /runs/{id}/resolve` | — | `{session_id \| null, proposals: ResolveProposal[], credits: {total, provenance}}` | 404 | `resolveApi.summary` | `resolve/summary.json` |
| `GET /runs/{id}/resolve/escalation` | — | `{run_id, workflow_id, status, gate_seq, gate, allowed (live), steps}` or `{…, gate: null, note}` | 404 | `resolveApi.escalation`, genesis-resolve `get_escalation` | `resolve/escalation.json` |
| `POST /runs/{id}/resolve/proposals` (internal) | `{action, params, rationale}` + `X-Genesis-Resolve-Token` | `{ok, proposal_id, superseded, note}` | 400 invalid / too long to store whole ("shorten the rationale or the text params"), 403, 409 | genesis-resolve MCP only (not in the web client) | — |
| `POST /runs/{id}/resolve/proposals/{pid}/confirm` | optional `{guidance \| instructions \| reason}` | `{proposal_id, action, status, new_run_id?}` | 400, 403, 404, 409 stale | `resolveApi.confirm` | `resolve/confirm-{retry,relaunch}.json` |
| `POST /runs/{id}/resolve/proposals/{pid}/dismiss` | — | `{ok}` | 404, 409 | `resolveApi.dismiss` | `resolve/dismiss.json` |
| session stream `GET /chat/sessions/{sid}/notifications/stream` | — | + `resolve.proposal {proposal}`, `resolve.note {kind: resolve.escalation \| resolve.outcome, text, gate_seq? \| proposal_id?, status?, new_run_id?}`, Genesis-turn chat events with `turn: "genesis"` | — | `chatApi.streamNotifications<ResolveStreamEvent>` | `resolve/stream-{proposal,note,genesis-turn}.json` |

**Event audit (D22)**, fixtures `runs/action-events.json`, `runs/fix-events.json`: `gate.resolved {decision, source,
actor: "user", action, params, proposal_id?}`; `run.relaunched {to_run, from_step? | as_node?, source, actor, action:
relaunch | restart_from, params, proposal_id?}`; the `_resolve` `file.written {path, node: "_resolve", bytes, mtime,
source, actor, action: "fix_accept", params: {path, source_file, bytes}, proposal_id?}`. `source` is `manual`,
`resolve` or `copilot`. `copilot_actions` gets rows only for Resolve-sourced actions.

**Enriched gate payload** (`EscalationPayload`): `node, kind: "escalation", prompt, options, context_refs, raised_at,
failed_node, validator_messages, history [{at, kind, text, ok?}], last_error, files [{path, role, bytes, writes,
check?}], allowed {retry, accept, fix_accept, relaunch, restart_from, stop, <extra ids>}, extra_options [{id, label,
hint}]`.

### Changed

- `genesis/runs/relaunch_policy.py` (new): `parse_relaunch` (the one D23 reader), `relaunch_policy`, `RelaunchPolicy`
  (`write_refusal`, `flag_refusal`, `refusal`), `WRITE_SERVERS`, `DEFAULT_REFUSAL`, `HINT_MAX`.
- `genesis/runs/manager.py`: `_relaunch_policy`, `_new_run_refusal` (order: status → replaced → write guard → service
  refusal → flag → bound object), `_relaunch_refusal` / `_restart_refusal` on it; `gate_allowed` re-reads `relaunch` /
  `restart_from` live for a standard gate; `respond` refuses a run not at a gate and logs the audit
  (`_action_of`, `_audit_fields`, `ACTOR_USER`); `_audit` only for `source == "resolve"`; `fix_and_accept` logs the
  audit, passes `proposal_id` to its accept, writes `mtime` in the worker's ISO form; `relaunch` / `restart_from` log
  the audit and set `_replacing` before the cancel; `replaced_by`, `current_run`, `_FOLLOW_MAX`.
- `genesis/api/run_routes.py`: `_action_errors`; routes `fix-and-accept`, `relaunch`, `restart-from`; `respond` with
  the copilot source and `{ok, run_id}`; `_artifact_path` 403 for System paths. `genesis/api/_shared.py`:
  `FixAndAccept`, `Relaunch`, `RestartFrom` body models (module level, L-096); `_trigger` for run-made triggers,
  `RUN_TRIGGER_SOURCES`.
- `genesis/runs/documents.py`: `is_system_path`, `_SYSTEM_FOLDED`, `_WRITING`; `legacy` / `writing` rules; status sets
  from `runs.store`.
- `genesis/lint/contract.py`: `check_relaunch` (through `parse_relaunch`).
- `genesis/chat/resolve.py`: `_allowed` = `RunManager.gate_allowed`; `WRITE_SERVERS` / `WRITE_REFUSAL` removed.
- `genesis/runtime/scheduler.py`: `_successor`; `_follow` switches the row to the replacement (`set_run`, gate wait
  cleared) and waits while the replacement's record does not exist.
- `genesis/memory/chat_read.py`: `sessions_since` leaves out `RUN_CHAT_MODES` in the query.
- Web: `types/escalation.ts`, `types/resolve.ts`, `types/runDocuments.ts` (new); `types/run.ts` `RunTrigger` =
  `ScheduleTrigger | RunActionTrigger`; `lib/api/runs.ts` `documents`, `fixAndAccept`, `relaunch`, `restartFrom`,
  `GateDecision` with `ActionAnswer`, typed `respond`; `lib/api/resolve.ts` `resolveApi` (new, exported);
  `chatApi.streamNotifications<T>`; `dev/mockups/phase55/fixtures.ts` imports `ActionKey`, `HistoryEntry`,
  `EscalationPayload`, `RunDocCategory` (and `resolve.tsx` `GateFile`); golden `events.ts` payloads for `gate.resolved`
  and `run.relaunched` in the audit shape; `phase54-contract.test.ts` uses `ScheduleTrigger`.

### Tests

- `tests/test_phase55_api.py` (46, real subprocess workers on the 55-06 `esc` fixtures, the real app through
  `TestClient`, records the fixtures above): the reader (12 cases incl. review m1's string/non-list forms), the write
  refusal with a hint, the parity lint (9 cases), **one reader** (patching `parse_relaunch` changes both the lint and
  the manager, L-109), unflagged workflow refused and a service refusal first, an unreadable workflow refused; respond
  (404, 409 terminal, 400 not allowed, 400 run operation, the audit, copilot source) and 409 for a running run; fix-and-
  accept (Resolve not opened, four 400s, the audit on `file.written` and `gate.resolved`, ISO mtime, 409 after) and the
  `allowed` 400; relaunch (404, 400, the audit, the trigger, 409 replaced / running / service / flag / Dev write, nothing
  cancelled by a refusal); restart-from (400 unknown step, 400 values, the audit, the trigger, 409 done, 409 flag); the
  Resolve routes and their audit; the session-stream events; `/documents` writing and legacy per status (7); System
  paths 403 on both routes (8 names incl. `..`, upper case, a symlink, `%2F`), `_prompts/` still 200; `is_system_path`;
  `current_run` with the in-flight successor seen at the cancel; the consolidation filter (Resolve chat before and
  after normal ones, limit, cursor); route order over the whole `/runs` table and one behaviour check per new route
  (L-096).
- `tests/test_scheduler.py` (+2): a relaunched scheduled run followed to the new run (stored, a new engine keeps it,
  closes `ok`, history row on the new run); a replacement still being made keeps the row open, and closes on the old
  run when it fails.
- Updated: `test_run_actions.py` (fixtures declare `relaunchable: true`; audit fields), `test_resolve.py` (the D23 guard
  through `required_mcp` and a node's `mcp`, also refusing the manual operations; audit fields).
- Web: `src/test/fixtures/phase55-contract.test.ts` (8): every recorded fixture through its client function with
  `Exact<T>` keys both ways; the mockup's `ESC_GATE` and action list match the recorded gate (D12 item 10); refusals keep
  status and words; trigger shapes; audit keys on every recorded action event and the golden events; documents; Resolve
  routes; stream events. Negative control: a fixture with a key dropped and one added fails it (restored).
- **Mutation probes** (`/tmp/gr-55-08/probe.py`, 11, each killed, files restored): scheduler not following; Resolve
  chats read; writing while paused; System files served; only the requested name checked; no write guard; flag
  ignored; no in-flight successor; respond resuming a running run; no audit fields; the lint with its own reader.
- **Gates:** genesis full pytest **2379 passed, 4 skipped** at `1f8fd8b5`'s tree (scratch
  `GENESIS_STATE_DIR=/tmp/gr-55-08/full2/state`; 2376 at bd9873c6, reproduced by the reviewer; 2331 at 55-07);
  `ruff check genesis` clean. Web: typecheck clean, lint 0 errors / 20 warnings (baseline), vitest 84 files / **971
  passed** (963 before). genesis-workflows `validate_library`: the same 56 F8 violations as at 55-06, none about
  relaunch.

### Review

`reviews/55-08-review.md`, round 1 **SHIP**, choices a–h agreed. m1 (the write guard failed open on a string server
list), n2, n3 fixed in `1f8fd8b5` with tests (not re-reviewed; full suite re-run green). m2 and n1 recorded below.

### Decisions / deviations

No ADR deviation. No migration. Choices the spec did not cover:
1. **Service refusals kept (D23, ADR-081):** test-execution ("started again from Testing") and story-verification
   ("started again by moving the card into Verification") keep an execution record; setup-composer and action-capture
   ("started again from Testing") keep a capture record bound to the run (`CaptureStore.bind_run` / `set_status(run_id=)`),
   which a run that skips their queue breaks the same way; a test-design top-up stays refused per run (its `Binding.refusal`).
   They come before the flag, so their reason shows. D23's text kept them "only where … an execution record": for the
   spec agent to note.
2. **fix-and-accept's `allowed` refusal is 400**, by the D21 mapping, not the table's "409 not allowed"; 409 is "not at
   a standard gate". The spec row should be corrected.
3. **`source: "copilot"`** for a respond carrying a chat control token (ADR-033: confirmed in chat first). D22 and the
   ADR-089 draft should list it beside `resolve | manual`.
4. **Relaunch's `InputValidationError` is 409** (the body has no inputs to fix), with the details.
5. **respond refuses a run that does not wait at a gate (409).** Before, it logged `gate.resolved` and spawned a second
   resume worker on a running run (L-121 shape).
6. **The consolidation filter is in the query**: Resolve chats never count toward `limit` and never hold the cursor;
   the cursor moves to the newest normal session, past any Resolve chat before it; one after it is never returned, so
   the preflight skips a Resolve-only window (no run, no credits).
7. **Write-guard text** "This workflow writes to the Dev environment (appian-dev-write), so Genesis never starts it
   again from a run. <hint, else 'Start it again from where you launched it.'>"; the lint reports `relaunchable: true`
   on a workflow that uses appian-dev-write, and (m1) a server list given as a string or another non-list. An unreadable
   workflow is refused ("Genesis cannot read this workflow (<error>)…").
8. **`gate_allowed` re-reads `relaunch` / `restart_from` live** for a standard gate (a library update of the flag, or a
   gate raised by an older server, gets the D23 rules); the methods re-check at apply time as before.
9. **The scheduler follows a replacement being made**: the relaunch names its new run before it cancels (`_replacing`,
   popped in `finally`), so a tick never closes the row on the cancel; the row switches only once the new run's record
   exists.
10. **The manual fix route's sandbox** is the run's Resolve session (`resolve-<run_id>`); `proposal_id`, when given,
    must be that session's and is audit only (the proposal then goes stale with its gate, not "confirmed").
11. **Bug fixed:** the `_resolve` `file.written` `mtime` was a float; it is ISO like the worker's.
12. **Web types:** the mockup's `ActionKey`, `HistoryEntry` and the payload names moved to `types/escalation.ts`; the
    mockup's `DocRow` stays mockup-local (55-05 built different names: `execution`/`iteration`/`attempt`), but its
    `DocCategory` is `RunDocCategory | "tool"`. `ChatSessionMode` is not extended with `run_resolve` (55-09 if needed).
    The internal proposals route has no web client function. The Genesis-turn events are recorded from the chat manager
    over the fake v3 engine (the same chat event shapes plus `turn`), not a live turn (no credit-heavy runs asked).
13. The golden `events.ts` payloads for `gate.resolved` and `run.relaunched` now carry the audit fields.

**Limits (recorded, not fixed):**
- m2: the guard sees only what `workflow.yaml` declares (`required_mcp`, graph `mcp`); nothing checks that a
  `kiro_node(mcp=…)` server is in `required_mcp`. No library workflow differs today. A publish-time lint for 55-10 or
  the backlog.
- n1: the snapshot's (and `GET /runs/{id}`'s) `gate.allowed.relaunch` / `restart_from` are the values from when the gate
  was raised; `/resolve/escalation`'s `allowed` is live. Safe (apply re-checks). 55-09 should read the live map.
- A crash between the cancel and the `run.relaunched` log loses `_replacing`: the schedule row then closes as cancelled.
- Followers other than the scheduler (a copilot chat's run links) do not follow a replacement (not in scope).

### Live effect before the release (the fleet runs from the editable dev venv)

Nothing in the routes, the manager, the scheduler or the memory reader reaches the fleet until a server restart (the
servers hold v0.83.0 in memory). New fleet workers import HEAD, but this sub-spec changes no worker code. The CLI from
the dev venv gets the new parity lint (`check_relaunch`): no installed workflow declares the keys, so nothing changes.
After a restart onto this code: every library workflow is unflagged until 55-10, so Rerun and Restart are refused for
all of them, from Resolve and the routes (the D23 default), and the D23 write guard replaces the interim one, so the
55-07 "do not restart before 55-08" note is cleared. Nothing was restarted and no live run was made.

### Lesson candidates

1. **A guard that iterates a declared list must not accept a string**: `for s in "appian-dev-write"` yields its
   characters, so a YAML scalar turned the ADR-068 guard off silently (review m1). Read lists through one helper that
   treats a string as one item and reports it.
2. **An action route on a non-waiting run must refuse, not resume**: `respond` on a running run spawned a second resume
   worker because the gate check returned None and the answer passed through unchecked.
3. **A follower of a replaced run needs the successor before the cancel**: naming the new run first (an in-flight map)
   closes the window in which a level-triggered loop sees only the cancel.

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runs/relaunch_policy.py` (new) as listed. `runs/manager.py`: `_new_run_refusal`, `_relaunch_policy`,
  `replaced_by`, `current_run`, `_replacing`, `_action_of`, `_audit_fields`, `ACTOR_USER`. `runs/documents.py`:
  `is_system_path`. `lint/contract.py`: `check_relaunch`. `runtime/scheduler.py`: `_successor`.
- `api/run_routes.py`: `fix-and-accept`, `relaunch`, `restart-from`, `_action_errors`, the System-path 403.
  `api/_shared.py`: `FixAndAccept`, `Relaunch`, `RestartFrom`, `RUN_TRIGGER_SOURCES`.
- `chat/resolve.py`: interim guard removed. `memory/chat_read.py`: the `RUN_CHAT_MODES` filter.
- Web: `types/{escalation,resolve,runDocuments}.ts`, `lib/api/resolve.ts`, fixtures `test/fixtures/resolve/*`,
  `test/fixtures/runs/{action-events,fix-events,escalation-gate,respond,fix-and-accept,relaunch,restart-from,
  run-relaunched,run-restarted,error-400,error-409}.json`, `test/fixtures/phase55-contract.test.ts`.
- Docs: D22 (`copilot` source), the ADR-089 draft (sources, the guard text), ADR-088 draft (D25 as built), the
  `docs/architecture` runs-and-workers page (the routes, the relaunch policy, the System-path refusal).

### For 55-09+

- **55-09:** Documents from `runsApi.documents` (`writes` 0 = unknown; System rows listed, never previewed: the routes
  answer 403). Resolve: `resolveApi.open` → `chatApi.streamNotifications<ResolveStreamEvent>(session_id, …)` and
  `chatApi` messages; cards and the manual menu from `/resolve/escalation`'s live `allowed` (n1), not the snapshot's;
  restart names a step from `steps`; follow `run_id` / `new_run_id` (L-120). Manual actions: `runsApi.respond` (action
  dicts), `fixAndAccept` (needs Resolve opened), `relaunch`, `restartFrom`. Show the 409 reasons as is (they say where
  to start the run instead). The relaunch confirm for a done `story-implementation` is moot: it is always refused (D23).
- **55-10:** set `relaunchable` / `relaunch_hint` per workflow in META and `workflow.yaml` (the lint checks both; a
  server list must be a list); `story-implementation` `relaunchable: false` + "Re-run it from the Implementation lane"
  (the guard refuses it anyway); consider the m2 lint (agent node `mcp` ⊆ `required_mcp`).
- **55-11:** a live Confirm and a manual run of each action; a scheduled run relaunched from its gate (the row follows);
  a Resolve chat present at consolidation time; the System 403 from the real page.
- **Spec/docs corrections:** §1's fix-and-accept "409 not allowed" → 400 (decision 2); D22's sources + `copilot`
  (decision 3); D23's service-refusal list (decision 1).
- Cleanup for the user: `/tmp/gr-55-08/` (scratch states, logs, the probe) and the reviewer's `/tmp/gr-55-08-review/`.
