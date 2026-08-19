# 25-14 — Phase Release & Closeout (tag, ship, document)

- **Status:** ✅ DONE (2026-08-19) — Phase 25 released in two coordinated releases (v0.49.0/core v0.9.4 + v0.50.0/core v0.9.5), CI green; ADR-050/051/052 Accepted + ADR-026 amended; bible/tracker/progress + review-delta current. **PHASE 25 COMPLETE** (25-11 + 25-12 backlog). · **Review items:** process (Definition of Done for all of Phase 25) · **Roadmap:** final · **Repos:** genesis, genesis-core, genesis-workflows (as touched) + project-tracker · **Depends on:** all other active sub-phases (25-01..25-10, 25-12, 25-13)

## 1. Goal
The capstone that turns the individually-shipped sub-phases into a **cleanly released, fully documented Phase 25**: cross-repo version/pin alignment, ADRs flipped to Accepted, the bible + tracker + progress brought current, CI green everywhere, and a closing **review-delta** note that re-scores the codebase against the review's §A targets.

## 2. Why this is its own sub-phase
Each sub-phase ships its own release (ADR-019: bump + tag + push + dependent pins + CI green; frontend-only still ships a genesis release with committed `web/static`). But a multi-sub-phase program needs a **single explicit closeout** so nothing is left half-documented, no ADR stays "Proposed", and no dependent pin is stale. This sub-phase is the one place that asserts *Phase 25 as a whole is done and consistent* — it owns no new feature code.

## 3. Scope (checklist-driven)

### 3.1 Release-integrity sweep (across every repo Phase 25 touched)
- Confirm each shipped sub-phase followed the ADR-019 protocol: `[project].version` bumped, `vX.Y.Z` tag pushed, **dependent pins updated** (genesis→genesis-core→kiro-agent-sdk; genesis-workflows→both), CI green (genesis `genesis` + `frontend` [+ `clean-install`], genesis-core, genesis-workflows `validate_library`/`validate_skills`).
- Verify the **release order** held (core → genesis → genesis-workflows) so no tag references a not-yet-pushed tag.
- Confirm any schema bumps (25-01 m0013, 25-08 m0014) updated every `current_version==N` test (bible §7) and `db upgrade` runs clean on a fresh DB.
- Confirm each `web/src` change rebuilt + committed `web/static` (stale-bundle guard green).

### 3.2 Final cross-repo pin alignment + phase tag
- Ensure genesis's pins point at the final Phase-25 core/sdk/parser tags; genesis-workflows pins the final genesis/core.
- Cut the **final genesis release** of the phase (whatever the last shipping sub-phase produced) and record it as the Phase-25 baseline version in the bible.
- (Optional) an annotated marker/tag note "Phase 25 complete" on the final genesis tag for traceability — no separate tag scheme, just a documented pointer.

### 3.3 ADRs → Accepted
- Flip **ADR-050** (typed domain + LifecycleService), **ADR-051** (AgentProvider), **ADR-052** (DocumentProvider) from *Proposed* → *Accepted (shipped — genesis vX.Y.Z, CI green)* in `reference/decision-log.md` **and** mirror them into `bible/04-adrs-and-constraints.md` (they currently live only in the umbrella).
- Amend **ADR-026** with the 25-04 localhost-bind guardrail note (in decision-log + bible/04).

### 3.4 Bible refresh (per the index's keep-current routing)
- `bible/00` + `bible/01`: new shipped versions, **test counts** (backend/core/sdk/workflows/web all re-tallied), "what works today" additions (typed lifecycle, structured logging, provider seams, metrics/activity).
- `bible/03` codebase map: new modules (`genesis/domain/`, `genesis/services/`, `genesis-core/agents/`, `runtime/logging.py`, `integrations/documents/`, `kb/{sync_writer,query,releases}.py`, `chat/mode_profile.py`, `api/metrics.py`, migrations m0013/m0014).
- `bible/04`: ADR-050/051/052 + the ADR-026 amendment.
- `bible/08`: Phase 25 block → **COMPLETE (12 sub-phases shipped; former 25-11 in backlog)**.
- `AGENT_ONBOARDING.md` index: "Last refreshed" + latest-shipped version line.

### 3.5 Tracker + progress
- `tracker.md` §3 (Phase 25 → SHIPPED + COMPLETE) + a §6 shipped entry per the closeout.
- A rollup `progress/phase-25-architectural-foundation-hardening.md` linking each sub-phase's own progress doc + the final versions/CI pipeline ids.

### 3.6 Review-delta closeout
- Append a short **"Phase 25 outcome"** section to `code-review/genesis-production-readiness-review-2026-08-18.md` (or a sibling `…-followup.md`) re-scoring the six §A ratings against the targets and noting which findings are now Resolved / Partially-Resolved (e.g. §22 story-activity partial pending backlog 25-11) / Deferred (25-11, auth, Salesforce, Postgres).

## 4. Files touched
- `reference/decision-log.md` (ADR flips + ADR-026 amendment), `bible/00,01,03,04,08` + `AGENT_ONBOARDING.md`, `tracker.md`, `progress/phase-25-architectural-foundation-hardening.md` (new), `code-review/…` (closeout note). No product code — this is release + documentation only (any version bump was done by the individual sub-phases).

## 5. Tests / verification
- No new tests; this sub-phase **verifies** the aggregate gate: full backend `pytest` + `ruff`, genesis-core suite, genesis-workflows `validate_library`/`pytest`, web `lint`+`tsc`+`vitest`+`build` all green at the final tags; `glab ci list` shows green pipelines for every Phase-25 release; a fresh `genesis db upgrade` reaches the latest `current_version`.

## 6. Risks & mitigations
- **Risk:** a stale dependent pin (a sub-phase bumped core but genesis didn't re-pin). **Mitigation:** the §3.1 sweep diffs each repo's pins against the latest tags before closing.
- **Risk:** the `frontend` CI job's `changes: [web/**]` guard skipped the stale-bundle check on a non-web tag (bible §7). **Mitigation:** confirm the guard actually ran on each web-touching tag; re-trigger with a real `web/**` touch if a transient infra failure skipped it.

## 7. Out of scope
Any new feature code; the backlog 25-11.

## 8. Definition of Done
All Phase-25 releases verified consistent + CI-green; ADR-050/051/052 Accepted + mirrored to the bible; ADR-026 amended; bible/tracker/progress current; the review-delta closeout re-scores the §A ratings; project-tracker pushed. **Phase 25 declared COMPLETE.**
