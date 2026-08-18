# Phase 25 — Architectural Foundation Hardening — PARTIAL RELEASE (25-01..25-08)

**Released 2026-08-18: genesis v0.49.0 + genesis-core v0.9.4 (CI green — core #6600462, genesis #6600502).**

A partial-phase release of the Phase-25 hardening built so far. The phase was implemented incrementally with the
version held (genesis 0.48.7 / core 0.9.3), then 25-01..25-08 were shipped together (release order core → genesis,
ADR-019). The remainder (25-09 DocumentProvider, 25-10 reliable_agent_step, 25-12 AI-cost pass, 25-13 observability,
25-14 closeout; 25-11 per-story execution is backlog) ships in a later release.

## What shipped
| Sub-phase | Review | Summary | Key commits |
|---|---|---|---|
| 25-01 | B-1 | Typed SDLC `genesis/domain/` + single-authority `LifecycleService` + **m0013** `lifecycle_transitions` audit + spec action API (illegal/precondition → 409) + web allowed-action buttons. **ADR-050 Accepted.** | `d70bd20`, `0b90392` |
| 25-02 | E-2 | Zero-dep structured logging + `contextvars` correlation IDs (`runtime/logging.py`); wired into create_app/worker/CLI. | `c8ec7d6` |
| 25-03 | E-5/D-1 | Shared `genesis_core/util/atomic_json.py`; atomic + per-path-locked JSON writes (environments/secrets/dist + custom MCP/CLI). | `bc06930` (core), `105c538` |
| 25-04 | D-2 | Network-exposure guardrail: `serve`/`up` refuse a non-loopback bind without `--i-understand-no-auth` / `GENESIS_ALLOW_NON_LOOPBACK=1`. | `0a8f13f` |
| 25-05 | — | `AgentProvider` Protocol + `KiroAcpProvider` (`genesis_core/agents/`). **ADR-051 Accepted.** | `a2a0ee1` (core) |
| 25-06 | C-3/C-5 | God-module decomposition — `KbStore` 1373→652 (four read mixins; SCD-2 write path kept) + `api/app.py` 841→189 (composition root: `register_config/run/catalog_routes` + `api/_shared.py`) + `ApplicationSyncService` de-dups API↔scheduler. | `e143c5e`,`57f0704`,`07a12f2`,`579317b`,`8a80398`,`715fb1b`,`73c34ea`,`d1f66d1`,`85f6ae9` |
| 25-07 | C-4 | `ChatModeProfile` composes read_only/copilot/feature_spec (branch-free session methods; posture pinned). | `4cfb3fe` |
| 25-08 | D-1/§17 | Optimistic concurrency — **m0014** `row_version` CAS on features/specs + `StaleWriteError`→409 + `LifecycleService` state-CAS + run-start idempotency key. | `09826e7` |

## Release mechanics
- **genesis-core 0.9.3 → 0.9.4** (additive; `CORE_MAJOR` still 1), tag `v0.9.4` pushed → pipeline #6600462 success.
- **genesis 0.48.7 → 0.49.0** (pins core `v0.9.4`; FastAPI app version bumped), tag `v0.49.0` pushed → pipeline #6600502.
- genesis-workflows / kiro-agent-sdk / genesis-appian-parser: **no changes → not released**.

## Gate (all green)
genesis **561** pytest + ruff · genesis-core **76** pytest + ruff · web **163** vitest + eslint (0 errors) + tsc strict + `npm run build` + stale-bundle guard.

## Deviations (flagged, goal preserved)
1. **KbStore split via mixins**, not the spec's facade + 3-module (`sync_writer`/`query`/`releases`) design — verbatim, zero call-site churn, deadlock-sensitive write path untouched.
2. **`FeatureService` skipped** — 25-01 already established the single-authority `LifecycleService` in `api/features.py`.

## ADRs
- **ADR-050** (typed domain + LifecycleService) → **Accepted** (shipped 25-01).
- **ADR-051** (AgentProvider) → **Accepted** (shipped 25-05).
- **ADR-052** (DocumentProvider) → still **Proposed** (25-09 not built).
