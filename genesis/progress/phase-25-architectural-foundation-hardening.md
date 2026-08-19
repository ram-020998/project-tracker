# Phase 25 — Architectural Foundation Hardening — COMPLETE (rollup)

**Remediation of the 2026-08-18 production-readiness review. Shipped in two coordinated releases; CI green.**

| Release | Repos | Sub-phases | CI |
|---|---|---|---|
| **v0.49.0** (2026-08-18) | genesis v0.49.0 + genesis-core v0.9.4 | 25-01..25-08 | core #6600462, genesis #6600502 |
| **v0.50.0** (2026-08-19) | genesis v0.50.0 + genesis-core v0.9.5 | 25-09, 25-10-core, 25-13 (+ Overview trim) | core #6607186, genesis #6607193 |

genesis-workflows / kiro-agent-sdk / genesis-appian-parser: unchanged (not released).

## Sub-phases
| # | Review | Outcome | Commits |
|---|---|---|---|
| 25-01 | B-1 | Typed SDLC `genesis/domain/` + single-authority `LifecycleService` + **m0013** audit + spec action API (→409) + web action buttons. **ADR-050.** | `d70bd20`,`0b90392` |
| 25-02 | E-2 | Structured logging + correlation IDs (`runtime/logging.py`). | `c8ec7d6` |
| 25-03 | E-5/D-1 | Shared `genesis_core/util/atomic_json.py`; atomic+locked JSON writes. | `bc06930`,`105c538` |
| 25-04 | D-2 | Network-exposure guardrail (serve/up refuse non-loopback bind). **ADR-026 amended.** | `0a8f13f` |
| 25-05 | E-3 | `AgentProvider` + `KiroAcpProvider` (`genesis_core/agents/`). **ADR-051.** | `a2a0ee1` |
| 25-06 | C-3/C-5 | God-module decomposition: `KbStore` 1373→652 (4 read mixins), `api/app.py` 841→189 (route modules + `_shared.py`), `ApplicationSyncService`. | `e143c5e`,`57f0704`,`07a12f2`,`579317b`,`8a80398`,`715fb1b`,`73c34ea`,`d1f66d1`,`85f6ae9` |
| 25-07 | C-4 | `ChatModeProfile` — compose chat modes. | `4cfb3fe` |
| 25-08 | D-1/§17 | Optimistic concurrency — **m0014** `row_version` CAS + `StaleWriteError`→409 + run-start idempotency. | `09826e7` |
| 25-09 | F/§19/§20 | `DocumentProvider` interface + `GoogleDriveProvider` (`integrations/documents/`). **ADR-052.** | `cd9abc8` |
| 25-10 (core) | §F/§28/§31 | `reliable_agent_step()` helper in genesis-core (+4 tests). Workflow adoption deferred/opportunistic. | `679ee73` |
| 25-13 | §22 | Observability: `/system/metrics` + `/runs/{id}/provenance` + feature Activity feed (m0013) + web Activity/Metrics; Overview trimmed. | `cba724e`,`3504c28`,`97a0570` |
| 25-14 | process | This closeout: release-integrity sweep, ADR flips, bible/tracker/progress + review-delta. | (docs) |

## ADRs
ADR-050 (typed domain + LifecycleService), ADR-051 (AgentProvider), ADR-052 (DocumentProvider) → **Accepted**. ADR-026 **amended** (25-04 localhost-bind guardrail).

## Backlog (deferred)
- **25-11 per-story execution** — gated on Breakdown→Stories + per-stage workflows.
- **25-12 AI cost & performance pass** — data-driven; its measured-reduction core needs **real run telemetry** (headless-undrivable) + benefits from the 25-13 metrics substrate. Moved to backlog 2026-08-19.
- **25-10 workflow adoption** — `reliable_agent_step()` adoption in a workflow (recommend hello-appian, not the branch-heavy design-doc) — opportunistic; release-gated behind core v0.9.5.

## Deviations (flagged during the phase, goals preserved)
1. **KbStore split via mixins**, not the spec's facade+3-module design — verbatim, zero call-site churn, deadlock-sensitive SCD-2 write path untouched.
2. **`FeatureService` skipped** (25-06) — 25-01 already put the single-authority `LifecycleService` in `api/features.py`.
3. **25-13** Activity rendered as a **section** + Metrics **folded into Settings→Overview** (spec-allowed) rather than new page-tabs; `provenance` shipped as API (UI deferred).

## Gate (final, v0.50.0 / core v0.9.5)
genesis **571** pytest + ruff · genesis-core **80** + ruff · web **166** vitest + eslint(0)/tsc/build + stale-bundle guard — all green.

Per-sub-phase specs: `specs/phase-25-architectural-foundation-hardening/25-01..25-10, 25-13, 25-14`; backlog: `specs/backlog/phase-25-11-*`, `phase-25-12-*`.
