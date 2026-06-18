# 04 — Tools Built on Atlas

Everything in this document sits **on top of** the Atlas knowledge base and MCP layer. None of them re-parse Appian XML — they consume Atlas intelligence through MCP. This is the "N tools on one foundation" story.

---

## A. Knowledge Search + Version History
**Type:** Native Atlas MCP capability (no extra tooling)

Search any feature, read its SAIL/logic, trace dependencies, and compare behavior across releases.

**Powered by:** Atlas MCP discovery + bundle + object + version tools.

**Representative use case (PO point of view):**
> *"When I create a new evaluation in SourceSelection, I'm now asked to choose an 'Award Instrument Type' (IDIQ, FSS, GWAC…). That option didn't used to be there. What changed, in which release, how did it work before — and how does the Select Awardees action depend on it?"*

Atlas answers by diffing the *Create Evaluation* bundle across releases and tracing the Single/Multiple award-type value into the *Select Awardees* flow.

**Value:** onboarding, regression triage, impact analysis, PO-friendly release explanations.

---

## B. ERD Generation — `erd-gen`
**Type:** CLI tool + Atlas schema data · **Status:** Complete

Generates professional ERD diagrams in Lucidchart from Atlas schema files.

- Domain-grouped containers (Evaluation, Task Management, Consensus, …)
- Crow's-foot notation, PK/FK column indicators, zero crossing lines
- Automatic upload via the Lucid REST API; update existing ERDs, export, create share links

**Powered by:** Atlas MCP schema tools (`get_app_schema`, `get_schema_relationships`, `record_type_map`).

**Use case:**
> *"Generate an ERD for SourceSelection grouped by domain."*

**Value:** instantly visualize and communicate the data architecture — no manual diagramming.

---

## C. Atlas SQL Forge — `atlas-sql-forge`
**Type:** Kiro power · **Status:** Dev complete (records mode); bulk SQL partial

Generates realistic, **workflow-aware** test data. Two output modes:
- **Records mode** — creates data live via the Data Generator MCP (1–50 records, verified)
- **SQL mode** — bulk INSERT scripts for 100+ rows / performance testing (`LAST_INSERT_ID()` + `@variables`)

### The 6-Step Workflow (sub-agent orchestrated)
| Step | Output | Purpose |
|------|--------|---------|
| 0 Initialize | folder + PENDING files | workspace + tracker |
| 1 Workflow Analysis | `analysis.md` | trace PMs, rules, writes (Prerequisites → Action Work → Triggers) |
| 2 Exemplar Discovery | `exemplar.md` | study a real record in target status |
| 3 Data Architecture | `data-architecture.md` | field maps, ref data (live), insertion order, coverage checklist |
| 4 Data Payloads | `payloads/*.json` | exact JSON with field reasoning (≥80% coverage) |
| 5 Validation | `validation-report.md` | 4 checks: coverage, FK integrity, exemplar diff, ref IDs |
| 6 Execute / Generate | `execution-log.md` or `bulk-data.sql` | create records OR emit SQL |

**Powered by:** Atlas MCP (schema, workflows, bundles) + Data Generator MCP (CRUD, session, rollback).

**Use case (QE):**
> *"Create an evaluation in Complete status with 3 vendors and the LPTA method."*

**Value:** QE gets correct, complete, workflow-valid test data on demand, with one-command rollback.

**Also includes:** ERD generation action (delegates to `erd-gen`).

---

## D. Atlas Locust Forge — `atlas-locust-forge`
**Type:** Kiro power · **Status:** Foundation complete; full workflow pending

Generates production-quality `appian-locust` performance-test scripts from Atlas workflow knowledge.

1. Trace the full status lifecycle from Atlas KB process models
2. Map each workflow step → appian-locust API calls (via Locust MCP)
3. Generate a complete, runnable multi-role Locust script
4. Validate the script

**Output:** `locust-tests/<workflow>.py`, `config.json`, `resources/`, `README.md`.

**Powered by:** Atlas MCP + Locust MCP + Data Generator MCP (perf-env setup).

**Use case:**
> *"Generate a locust script for GSS Source Selection that creates an evaluation and drives it to Awarded status."*

---

## E. Atlas Demo Driver — `atlas-demo-driver`
**Type:** Kiro power (records-only)

Live-environment data creation specialized for demo/test environments. Shares SQL Forge's 6-step workflow DNA but is records-only with a focused UX (no SQL output).

**Powered by:** Atlas MCP + Data Generator MCP.

---

## F. Role-Specific Powers (in `solutions-os`)
Documented in `ai-framework/tools/Atlas/README.md`. Each is a thin intent layer on the same Atlas KB.

| Power | Role | Example |
|-------|------|---------|
| `atlas-developer` | Engineering — code, dependencies, UUIDs | *"How does the Add Vendors action work? Show me the SAIL and dependencies."* |
| `sail-reference` | Engineering — SAIL grammar & best practices | SAIL syntax guidance |
| `atlas-product-owner` | Product — features, releases, business language | *"What changed in the last release of SourceSelection? Summarize for stakeholders."* |
| `atlas-ux-designer` | Product — interfaces, prototypes, flows | *"Create an HTML prototype of the vendor management dashboard."* |

---

## G. Documentation Generation
**Type:** Prompt-driven (parser `prompts/` + agent)

The parser ships documentation-generation prompts (`prompts/00–05`, `business_documentation_generator.md`) for actions, pages, processes, sites, web APIs, and business docs — enabling agents to produce release notes and business documentation from bundle data.

---

## Possible Future Tools (the "N" in N tools)
Migration/upgrade impact assistants · automated release-note generators · cross-app dependency analyzers · test-coverage gap finders · architecture-drift detectors · any agent that needs to *understand* an Appian app. Each reuses the same Atlas KB without re-solving parsing.

---

## Summary Map

| Tool | Repo | Atlas MCP | DG MCP | Locust MCP | Status |
|------|------|:--------:|:------:|:----------:|--------|
| Knowledge Search + History | (native) | ✅ | | | Live |
| ERD Generation | `erd-gen` | ✅ | | | Complete |
| SQL Forge | `atlas-sql-forge` | ✅ | ✅ | | Dev complete / bulk partial |
| Locust Forge | `atlas-locust-forge` | ✅ | ✅ | ✅ | Foundation complete |
| Demo Driver | `atlas-demo-driver` | ✅ | ✅ | | Live |
| Role Powers | `solutions-os` | ✅ | | | Live |
