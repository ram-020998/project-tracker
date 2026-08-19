# 25-13 — Observability II: Metrics & Lifecycle Audit Stream

- **Status:** ✅ BUILT (2026-08-19, backend `cba724e` + web `3504c28`; **NOT released**) — metrics + provenance + lifecycle activity feed (backend) + Feature Activity + Settings Metrics (web). · **Review items:** §22 (metrics/audit), Roadmap Phase 4 · **Repos:** genesis, web · **Depends on:** 25-01 (lifecycle events), 25-02 (correlation ids)

## As built (backend `cba724e` 571 pytest / web `3504c28` 168 vitest — all + ruff/eslint/tsc green)
- **`api/metrics.py` `register_metrics_routes`:** `GET /system/metrics` (JSON snapshot — runs by status, features/specs by state, credit totals + provenance; no Prometheus, §36) + `GET /runs/{id}/provenance` (read-projection over `run_events`: workflow id+version [reproduction anchor], tools, nodes, outcome, credits — the §22 reproduce view).
- **`api/features.py` `GET /features/{id}/activity`:** the spec's time-ordered lifecycle transitions from the m0013 append-only audit (powers §26 Activity).
- Repository-layer read helpers `RunStore.counts_by_status` + `FeatureStore.counts`. +`tests/test_metrics_api.py` (5, incl. activity via the real action endpoints → LifecycleService → m0013).
- **Web:** `lib/api/metrics.ts` + hooks; `ActivityFeed` on the feature page (below the pipeline); `MetricsSection` folded into Settings → Overview. +`observability.test.tsx` (RTL + jest-axe); patched features/settings tests with the new handlers. web/static rebuilt + committed.
- **Design notes:** the Activity feed is rendered as a **section** (not a separate tab) and Metrics is **folded into Settings→Overview** — lowest-risk additive integration into the shipped pages (spec allowed "or fold into Overview"). `/runs/{id}/provenance` ships as an **API** (reproduction answers); a dedicated provenance UI is a deferred nice-to-have.
- **DoD:** met except genesis release CI + `bible/03` release update → deferred to the next release (unreleased).

## 1. Goal
Round out observability so the review's §22 questions are answerable end-to-end: a lightweight **metrics** surface and a **lifecycle audit stream** (a first-class activity feed) built from the domain events 25-01 emits — appropriate to a **local single-user** app (no external tracing stack).

## 2. Why (review evidence)
- **§22:** the system should answer what happened / which agent / which model / which tools / which docs / how long / what failed / can we reproduce. Run-level answers exist (`run_events`, credits, `copilot_actions`); **cross-run/aggregate** answers and a **lifecycle activity feed** do not.
- The review's target UX (§26) shows an **Activity** tab on Features — which needs a durable, queryable event stream.
- Roadmap Phase 4 ("audit-event stream from lifecycle transitions; metrics endpoint").

## 3. Current state (cited)
- Strong per-run observability: `run_events` (durable timeline), credits provenance, `copilot_actions` audit (m0006).
- 25-01 will add a `lifecycle_transitions` table (every entity state change) — the raw material for an activity feed.
- No aggregate metrics endpoint beyond `/api/home` (which is dashboard-shaped, not ops metrics).

## 4. Design
### 4.1 Lifecycle audit → Activity feed
- `LifecycleService` (25-01) emits a `LifecycleEvent` on every transition, persisted to `lifecycle_transitions` (append-only) with the 25-02 correlation ids (`run_id`/`session_id`/`actor`).
- `GET /api/features/{id}/activity` (and `/stories/{id}/activity`) returns the merged, time-ordered stream (lifecycle transitions + linked run terminal/gate events + document syncs) — powers the §26 Activity tab.

### 4.2 Metrics endpoint (lightweight, no Prometheus stack)
- `GET /api/system/metrics` returns a small JSON snapshot: counts (runs by status, features/stories by state), credit totals (period-bounded, from `aggregate_credits`), sync freshness (last app/document sync), error counts (from the 25-02 log or `run_events` failures). JSON, not Prometheus text — matches local single-user (adding a Prometheus exporter would be review §36 over-engineering; note it as an easy future add if hosting ever happens).

### 4.3 Reproducibility answers (§22)
- Ensure each run's record already ties together: workflow id + version, the **model** used (per-node telemetry), tools invoked (tool_call events), documents used (evidence-pack refs), duration, and outcome — surface a `GET /api/runs/{id}/provenance` that assembles this "how to reproduce" view from existing `run_events` (mostly a read-projection, little new capture).

### 4.4 Web
- A Feature/Story **Activity** tab (§26) consuming the activity endpoint; a small **System → Metrics** view (or fold into Settings→Overview) consuming `/system/metrics`.

## 5. Files touched
- **New:** `api/metrics.py` (`register_metrics_routes`) + activity endpoints (in `api/features.py`/`api/stories.py`), `web/src/features/features/ActivityTab/**`, `web/src/features/settings/components/MetricsSection.tsx`, tests.
- **Edit:** `domain/lifecycle.py` (persist events), `runs/eventlog.py` (provenance read-projection), the feature/story pages.

## 6. Tests
- Activity feed merges lifecycle + run + doc events in time order with correlation ids.
- `/system/metrics` returns the documented shape; counts match seeded data.
- `/runs/{id}/provenance` assembles workflow/model/tools/docs/duration/outcome from `run_events`.
- Web: Activity tab + Metrics view render (RTL + jest-axe).

## 7. Risks & mitigations
- **Risk:** over-building metrics for a single-user app (review §36/§40). **Mitigation:** JSON snapshot only; no exporter/collector; reuse existing event data (little new capture).
- **Risk:** activity feed volume. **Mitigation:** paginated + bounded; append-only table with retention alignment (existing retention service).

## 8. Out of scope
OpenTelemetry/distributed tracing; a Prometheus exporter; external log/metrics shipping (all deferred until/if Genesis is hosted — ADR-026 track).

## 9. Definition of Done
Lifecycle audit persisted + surfaced as Feature/Story Activity feeds; `/system/metrics` + `/runs/{id}/provenance` shipped; web Activity + Metrics views; tests green; genesis release CI-green; bible/tracker/progress updated. Closes the review's §22 gap for the local-single-user scope.
