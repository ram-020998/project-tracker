# 55-08 — HTTP API: the contract table, Resolve session storage, web types and fixtures

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/api/`, `genesis/db/`, `web/src/types/`,
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
