# Phase 15 — Appian Design-Document Workflow (as-built)

> **Status:** SHIPPED · **Date:** 2026-07-17
> **Releases:** genesis-workflows **v0.7.0**, genesis **v0.27.0** (genesis-core + kiro-agent-sdk
> **unchanged**). Spec: `specs/phase-15-design-doc-workflow.md`. ADR: **ADR-035** (run input file
> attachments).

## What shipped

A new **`design-doc`** workflow (genesis-workflows) that turns a JIRA ticket into an Appian
implementation **design document (Markdown)** using **dual-source research** — the live **Jarvis**
environment/KB *and* the release-aware **Atlas** KB — reconciled into one release-aware implementation
plan. Plus a small **genesis platform** capability (15-01): **run-launch file attachments** so the
optional mockup can be uploaded.

The Jarvis original's "🛑 STOP / execution tracker / BLOCKING RULES" enforcement scaffolding is
**deleted** — LangGraph enforces order structurally; program nodes do the deterministic work; each
agent step is validated + retried + escalatable.

## Sub-phases (built together, released once)

- **15-01 — Run-launch file upload (genesis).** `format:"file"` inputs; new multipart
  `POST /api/runs/upload`; `RunManager.start(..., files=)` + `_provision_files` writes the file into
  the run blackboard under `uploads/<safe>` and rewrites the input to that relative path *before*
  schema validation; guards size (10 MB) / extension allowlist / target / traversal (`FileUploadError`
  → 400). Web launch form renders a `FileDropList` for file inputs and submits multipart. **ADR-035.**
- **15-02 — MVP workflow.** `resolve_inputs → fetch_ticket → parse_ticket → fetch_config → match_app
  (+app_gate) → freshness (+freshness_gate) → research_jarvis → research_atlas → reconcile →
  fetch_app_info → validate_naming → design_notes → build_design → present`.
- **15-03 — Open-questions.** `open_questions` agent + `v_questions`; the section is included only when
  the agent surfaces genuine questions (decided by the deterministic `plan_sections` node).
- **15-04 — Package creation.** `pre_mutation_gate` (ADR-021) → `create_package` (the one write, jarvis
  `create_package_for_ticket`) → `v_package` → `record_package`; conditional on the `create_package`
  input; Deployment section links the package or notes "no package".
- **15-05 — Mockup i18n.** `i18n_branch` (conditional on an uploaded mockup) → `extract_i18n`
  (reads the upload, generates prefixed keys, duplicate-detects via `query_sql`/`jarvis_get_translation`,
  marks NEW vs REUSE) → `v_i18n`; the Internationalization section lists **NEW keys only**.

## Determinism / safety highlights

- **Dual research, one plan:** two independently-validated agent nodes; `v_ratlas` **requires** a
  `## Release Context` section so the Atlas source earns its place; `reconcile` merges with an explicit
  rule (Jarvis = live/KB primary, Atlas = release authority).
- **Read-only by construction:** every jarvis node carries an explicit `@jarvis/…` read-only allowlist
  (jarvis has no registry cap); Atlas is registry read-only + allowlisted. The **only** mutation
  (`create_package`) is behind a `pre_mutation` gate.
- **Dynamic structure validator:** `v_design` computes the exact expected section set from
  `has_i18n`/`has_questions`, enforces order, forbids extra sections, checks the JIRA-linked title +
  naming convention.

## Verification (cited)

- **genesis-workflows:** `workflows/design-doc/tests` — **16 passed** (pure fns, all validators, and
  stubbed-graph tests for every flag combination: minimal/questions/mockup-i18n/package-gate-resume,
  stale-KB gate, forced-escalation). `ruff` clean. `ci/validate_library.py` **PASSED (4 workflows)** —
  contract parity + reliability lint green.
- **genesis:** full suite **227 passed** (was 222; +5 run-launch upload tests in `test_runs.py` +
  `test_api.py::test_api_run_upload`). `ruff check genesis` clean. Web: `tsc` clean, **119** Vitest
  pass, `npm run build` rebuilt + committed `web/static/`.
- **CI:** genesis `v0.27.0` + genesis-workflows `v0.7.0` pipelines (see tracker §6 for the green
  confirmation).

## Deferred / follow-ups

- **Live acceptance vs real kiro-cli** (jarvis + jira + atlas creds): confirm the two research passes,
  the release-aware reconciliation, naming validation, the gated package creation, and the conditional
  i18n/questions sections against a real GAMS ticket. Headless-undrivable.
- **R3 mockup formats:** v1 accepts text-extractable + images; binary Office (.pptx/.pdf) needs a CLI
  pre-extraction node (future).
- **Exact jarvis/atlas tool names** (R2) verified at first live run; adjust allowlists if they differ
  from the source doc.
