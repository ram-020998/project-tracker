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
cancelled run — the scheduler follows `run.relaunched.to_run` to the run that finishes (L-120). **Audit:** see D22.

## 2. Resolve session storage (F15)

`chat_run_links(run_id PK, session_id)` keeps one copilot session per run, so the Resolve session gets its own table:
**m0031** `run_resolve_sessions(run_id TEXT PRIMARY KEY REFERENCES runs ON DELETE CASCADE, session_id TEXT NOT NULL
REFERENCES chat_sessions ON DELETE CASCADE, created_at)`. Forward-only, through the migration runner (L-102). If the
build finds a cleaner home that needs no migration (e.g. a column already present), record it as a decision in
55-01 §9 before choosing it. No fleet restart on an unreleased migration (risk table).

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
code     = ["genesis/genesis/api/run_routes.py", "genesis/genesis/runs/documents.py", "genesis/genesis/db/migrations/**", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
upstream = ["55-03", "55-05", "55-06", "55-07"]
```
