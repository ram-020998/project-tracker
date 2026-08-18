# 25-02 — Structured Logging & Correlation IDs

- **Status:** 📝 DRAFTED · **Review items:** E-2, §22 · **Roadmap:** Phase 0 · **Repos:** genesis, genesis-core · **Depends on:** nothing (parallelizable)

## 1. Goal
Give the backend **structured, correlated, level-based logging** so the review's observability questions ("what happened? which agent? which run? what failed?") are answerable outside a single run's `run_events` timeline — without adding heavy infra.

## 2. Why (review evidence)
- Only **4 `getLogger` uses** and **22 `print()`** calls across the backend (verified grep). No correlation/request IDs, no structured logs, no tracing.
- Domain observability (the `run_events` log, credits provenance, `copilot_actions` audit) is strong; **ops-layer** logging is near-absent.
- For a **local single-user** app (ADR-026), full OpenTelemetry tracing/metrics is over-engineering — so this sub-phase deliberately stays at **structured logging + correlation IDs**, not distributed tracing.

## 3. Current state (cited)
- Scattered `print(...)` in non-CLI modules (22 sites), e.g. best-effort warnings in sync/updater/supervisor paths.
- No central logging config; FastAPI/uvicorn defaults only.
- IDs that already exist and can serve as correlation keys: `run_id`, chat `session_id`, `tool_call_id` (ACP permission correlation id), workflow node names.

## 4. Design
### 4.1 Central config (`genesis/runtime/logging.py` — NEW)
- One `configure_logging(level, json: bool)` called in `create_app` + the CLI + the subprocess worker entrypoint.
- **Dev:** human-readable console handler. **Managed install (`~/.genesis/dist.json` present):** JSON lines to `~/.genesis/run/genesis.log` (rotating), so `genesis logs` (launcher) already surfaces them.
- Adopt **`structlog`** (single dependency; standard, mature) bound over stdlib `logging` — or, if the team prefers zero new deps, a stdlib `logging.Filter` that injects context. **Recommendation:** `structlog` (review §G "introduce structured logging").

### 4.2 Correlation context
- A `contextvars.ContextVar` bag (`run_id`, `session_id`, `tool_call_id`, `request_id`) bound by: a FastAPI middleware (per-request `request_id`), `RunManager`/worker (per-run `run_id`), `ChatManager` (per-session), the permission bridge (`tool_call_id`).
- Every log line automatically carries whatever context is bound — no manual threading.

### 4.3 Replace `print()`
- Replace all 22 non-CLI `print()`s with `log.info/warning/error(...)`; CLI user-facing output stays `print()` (or `click.echo`) — logs are for diagnostics, stdout is the CLI UX.
- `except Exception` graceful-fallback sites (already `# noqa: BLE001`) log at `warning`/`exception` with the bound context instead of silently continuing.

### 4.4 Secrets discipline
- A redaction processor drops known secret keys (never log `LCP_PASSWORD`/tokens); reference by key name only (coding-standards §2).

## 5. Files touched
- **New:** `runtime/logging.py`, `tests/test_logging_context.py`.
- **Edit:** `api/app.py` (middleware + `configure_logging`), `runs/worker.py` + `runs/manager.py` (bind `run_id`), `chat/manager.py` (bind `session_id`/`tool_call_id`), the 22 `print()` sites, `cli/main.py` (configure for CLI), `pyproject.toml` (add `structlog` pin if adopted).

## 6. Tests
- Context propagation: a log emitted inside a bound `run_id`/`session_id` scope carries those fields (capture via a test handler).
- Redaction: a secret value never appears in an emitted record.
- No `print(` remains in non-CLI backend modules (a guard test / ruff rule).

## 7. Risks & mitigations
- **Risk:** new dependency. **Mitigation:** `structlog` is small, pure-Python, widely used; pin it (bible §7 ruff-pin discipline applies to the new dep too).
- **Risk:** log volume. **Mitigation:** level-gated; JSON file rotates; default INFO.

## 8. Out of scope
Distributed tracing (OpenTelemetry), metrics endpoint (that's 25-13), log shipping.

## 9. Definition of Done
`configure_logging` wired in app/CLI/worker; correlation context auto-attached; all non-CLI `print()`s replaced; redaction verified; tests green; genesis (+ genesis-core if a logger is added there) release CI-green; bible/tracker/progress updated.
