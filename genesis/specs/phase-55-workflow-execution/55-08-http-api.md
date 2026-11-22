# 55-08 — HTTP API: the contract table, Resolve session storage, web types and fixtures

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/api/`, `genesis/db/`, `web/src/types/`,
> `web/src/lib/api/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. 55-03..55-07 add their
> own routes; this sub-spec owns the table, adds what is left, and makes every shape a typed, fixture-tested contract
> (L-011, L-109). All under `/api`, the client prepends it centrally (ADR-028, L-010).

## 1. Contract table

| Method + path | From | Body / query | Answer | Errors |
|---|---|---|---|---|
| `GET /runs/{id}/snapshot` | 55-03 | `?since_version=N` | `RunSnapshot` or `{unchanged: true, version}` | 404 |
| `GET /runs/{id}/live` (SSE) | 55-03 | `Last-Event-ID` / `?after=` | lifecycle frames with `id:`; `resync`; `ping` | 404 |
| `GET /runs/{id}/documents` | 55-05 | — | `RunDocuments` | 404 |
| `POST /runs/{id}/respond` (extended) | 55-06 | a legacy decision **or** `{action, guidance? , reason?, ...extra}` | as today | 400 unavailable action, 409 not at a gate |
| `POST /runs/{id}/fix-and-accept` | 55-06 | `{path, proposal_id? , source_file}` | `{run_id, status}` | 400 path refused, 409 not available |
| `POST /runs/{id}/relaunch` | 55-06 | `{inputs}` (multipart when files change, as `/runs/upload`) | `{run_id, from_run}` | 400 invalid inputs / binding key edited, 409 run still running (not at a gate) |
| `POST /runs/{id}/fork` | exists | unchanged | unchanged | — |
| `POST /runs/{id}/resolve` | 55-07 | — | `{session_id, created}` (idempotent: returns the existing session) | 409 run never escalated |
| `GET /runs/{id}/resolve` | 55-07 | — | `{session_id?, proposals: [...], credits}` | 404 |
| `POST /runs/{id}/resolve/proposals/{pid}/confirm` | 55-07 | optional edited params (guidance text, inputs) | `{outcome}` (new run id where relevant) | 409 stale, 400 invalid |
| `POST /runs/{id}/resolve/proposals/{pid}/dismiss` | 55-07 | — | `{ok}` | 404 |
| chat messages / stream of the Resolve session | exists | the existing `/chat/sessions/{sid}/…` routes | + the `resolve.proposal` event | — |

Every mutating route writes its `copilot_actions` row (55-06 §3). Register specific routes before any generic path
route that also matches them and prove the order by behaviour (L-096). Each route is listed with its consumers (web,
copilot control MCP, tests) before an existing one changes (L-094).

## 2. Resolve session storage (F15)

`chat_run_links(run_id PK, session_id)` keeps one copilot session per run, so the Resolve session gets its own table:
**m0031** `run_resolve_sessions(run_id TEXT PRIMARY KEY REFERENCES runs ON DELETE CASCADE, session_id TEXT NOT NULL
REFERENCES chat_sessions ON DELETE CASCADE, created_at)`. Forward-only, through the migration runner (L-102). If the
build finds a cleaner home that needs no migration (e.g. a column already present), record it as a decision in
55-01 §9 before choosing it. No fleet restart on an unreleased migration (risk table).

## 3. Web types and fixtures

`web/src/types/`: `RunSnapshot`, `LiveHint`, `RunDocuments`, `RunDocument`, `EscalationPayload` (the `escalation`
block), `EscalationAction`, `ResolveProposal`, the new event kinds (`node.started`, `memory.brief`, `file.written`,
`run.relaunched`) in the one web list tested against the backend list both ways (L-122). `web/src/lib/api/runs.ts` (and
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
code     = ["genesis/genesis/api/run_routes.py", "genesis/genesis/db/migrations/**", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
upstream = ["55-03", "55-05", "55-06", "55-07"]
```
