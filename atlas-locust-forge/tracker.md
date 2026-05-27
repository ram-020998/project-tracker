# Atlas Locust Forge — Project Tracker

**Last Updated:** 2026-05-27
**Status:** Planning
**Power Location:** `appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-locust-forge/`
**MCP Server Repo:** `ramaswamy.u/solutions-atlas-locust-mcp-server` (to be created)
**Reference MCP:** `ramaswamy.u/solutions-atlas-dg-mcp-server` (same pattern)

---

## Vision

An org-level Kiro power that automates generation of production-quality `appian-locust` performance test scripts for any Appian application. Uses Atlas KB knowledge (workflows, SAIL forms, record types, process models) to trace full user journeys through status transitions, and emits runnable Locust scripts that drive the application end-to-end.

**Key differentiator from Brian Breeden's appian-locust-agent:** Static discovery via Atlas KB (no runtime UI crawling), full workflow lifecycle coverage (not single-form tests), and integration with SQL Forge for pre-seeding test data at scale.

---

## Problem Statement

Today, teams write appian-locust scripts manually by:
1. Navigating the live app to understand the workflow
2. Identifying form fields, buttons, dropdowns, and their labels
3. Figuring out the correct sequence of steps to reach a target status
4. Writing Python code with the right appian-locust method calls
5. Debugging failures iteratively (wrong labels, missing steps, role issues)

This is time-consuming, error-prone, and doesn't scale across 10+ solutions.

**Atlas already knows all of this** — the process models, form definitions, SAIL components, user roles, and status transitions are in the KB. The agent should generate the script directly from that knowledge.

---

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  atlas-locust-forge (power)                                    │
│  ├── POWER.md (action router)                                  │
│  ├── mcp.json (Atlas + Locust + Data Gen MCP servers)          │
│  └── steering/                                                 │
│       ├── action-generate-locust.md (main orchestrator)        │
│       ├── step-1-workflow-analysis.md (trace lifecycle)         │
│       ├── step-2-interaction-mapping.md (forms → locust calls) │
│       ├── step-3-generate-script.md (emit Python)              │
│       ├── step-4-validate.md (syntax + optional dry-run)       │
│       └── tool-reference-locust-mcp.md                         │
└────────────┬──────────────────┬───────────────────┬────────────┘
             │                  │                   │
             ▼                  ▼                   ▼
┌────────────────────┐ ┌────────────────────┐ ┌──────────────────────┐
│ Atlas MCP Server   │ │ Locust MCP Server  │ │ Data Generator MCP   │
│ (app intelligence) │ │ (NEW — API ref,    │ │ (test data setup)    │
│                    │ │  mappings, patterns)│ │                      │
│ Tools:             │ │ Tools:             │ │ Tools:               │
│ - get_process_models│ │ - get_methods      │ │ - create_record      │
│ - get_sail_forms   │ │ - get_mapping      │ │ - query_records      │
│ - get_record_types │ │ - get_template     │ │ - bulk SQL generation│
│ - get_workflow_nodes│ │ - get_examples     │ │                      │
│ - get_field_map    │ │ - validate_script  │ │                      │
└────────────────────┘ └────────────────────┘ └──────────────────────┘
```

---

## Components

### 1. Locust MCP Server (`solutions-atlas-locust-mcp-server`)

A read-only MCP server that provides appian-locust API intelligence to any agent.

**Data Sources:**
- Cloned `appian-locust` source (parsed at build time for method signatures)
- Maintained `component_mapping.json` (SAIL type → locust method)
- Existing test repos (patterns/examples)

**Tools:**

| Tool | Input | Output |
|------|-------|--------|
| `get_interaction_methods` | category (optional) | All methods with signatures, grouped by: navigation, form, grid, document |
| `get_method_signature` | method_name | Full signature, parameter types, defaults, usage example, gotchas |
| `get_component_mapping` | sail_component_type | Locust method name + parameter mapping + example |
| `get_navigation_patterns` | nav_type (site/record/action/report) | How to navigate + code example |
| `get_test_template` | template_type (sequential/multi_role/parameterized) | Complete boilerplate code |
| `get_existing_tests` | app_name | Fetch real tests from team repos as reference |
| `get_config_template` | — | Standard config.json structure |
| `validate_script` | python_code | Syntax check + verify all method calls are valid appian-locust APIs |

**Component Mapping (core of the server):**

| Atlas SAIL Component | Locust Method | Key Params |
|---------------------|---------------|------------|
| `a!textField` | `fill_text_field` | label, value |
| `a!paragraphField` | `fill_paragraph_field` | label, value |
| `a!dateField` | `fill_date_field` | label, date_input (date object) |
| `a!dateTimeField` | `fill_date_field` | label, date_input |
| `a!dropdownField` | `select_dropdown_item` | label, choice_label |
| `a!radioButtonField` | `select_radio_button_by_label` | label, index |
| `a!pickerField` / `a!recordPickerField` | `fill_picker_field` | label, value, identifier="#v" |
| `a!buttonWidget` | `click_button` / `click` | label |
| `a!linkField` | `click_link` | label |
| `a!recordLink` | `click_record_link` | label |
| `a!fileUploadField` | `upload_documents_to_multiple_file_upload_field` | label, file_paths |
| `a!checkboxField` | `check_checkbox_by_label` | label, indices |
| `a!gridField` (with search) | `filter_records_using_searchbox` | term |
| Related Action link | `click_related_action` | label |
| Record View tab | `click_record_view_link` | label |

### 2. Power: `atlas-locust-forge`

**Steering Workflow (mirrors SQL Forge's 6-step pattern):**

| Step | Name | What it does |
|------|------|-------------|
| 1 | Workflow Analysis | Trace process models in Atlas KB to extract the full status lifecycle (e.g., Draft → In Progress → Evaluated → Awarded). Identify which actions trigger each transition, which roles perform them, and what data is required. |
| 2 | Interaction Mapping | For each workflow step, query Atlas for the SAIL form definition. Map each component to its locust method call using the Locust MCP. Identify required field values (from reference data, user input patterns, or SQL Forge output). |
| 3 | Script Generation | Emit a complete Python locust script with proper structure: imports, config loading, functions per workflow step, role-specific TaskSets, UserActor class. Use Locust MCP templates for boilerplate. |
| 4 | Validation | Syntax check via `python -c "import ast; ast.parse(code)"`. Optionally validate method calls via Locust MCP `validate_script`. If a perf env is available, offer dry-run. |

**Input to the power:**
```
"Generate a locust script for [APP_NAME] that drives [RECORD_TYPE] from [START_STATUS] to [TARGET_STATUS]"
```

Example:
```
"Generate a locust script for GSS Source Selection that drives an Evaluation from creation to Awarded status"
```

**Output:**
```
generated_tests/
├── gss_evaluation_to_awarded.py    # The locust script
├── config.json                      # Environment config (host, auth per role)
├── resources/                       # Any test files (uploads, etc.)
└── README.md                        # Run instructions
```

### 3. Integration with SQL Forge

| SQL Forge provides | Locust Forge consumes |
|-------------------|----------------------|
| Bulk reference data (vendors, users, lookups) | Scripts reference this pre-seeded data |
| Record type map (UUIDs, relationships) | Understands data model for valid values |
| Field map (column → camelCase) | Correct field labels |
| Workflow analysis pattern (step-1) | Reuses same Atlas querying approach |

**Workflow:**
1. SQL Forge generates 1M rows of reference data (vendors, evaluators, etc.)
2. Locust Forge generates scripts that create evaluations and drive them through the workflow
3. Scripts parameterize per virtual user (unique PIID, random vendor selection from pre-seeded pool)
4. Run with N concurrent users = realistic load test

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goal:** Locust MCP server running with core tools, power skeleton in solutions-os.

| Task | Details |
|------|---------|
| Clone & parse appian-locust source | Extract all public methods from `SailUiForm`, `AppianTaskSet`, `visitor` classes |
| Build component_mapping.json | The SAIL → locust translation table (15 mappings) |
| Locust MCP server | Python, same pattern as Atlas MCP. Tools: `get_interaction_methods`, `get_method_signature`, `get_component_mapping`, `get_navigation_patterns`, `get_test_template` |
| Dockerize + CI pipeline | Same pattern as solutions-atlas-dg-mcp-server (lint + test + kaniko build) |
| Create power skeleton | `POWER.md`, `mcp.json` (3 servers), steering stubs |
| Index existing GSS tests | `get_existing_tests` returns real team-written scripts as examples |

**Deliverable:** Agent can query "how do I fill a picker field?" and get the correct appian-locust code.

### Phase 2: Workflow Analysis (Week 2-3)

**Goal:** Agent can trace a full workflow lifecycle from Atlas KB.

| Task | Details |
|------|---------|
| Build `step-1-workflow-analysis.md` | Reuse SQL Forge pattern: query process models, extract nodes, trace status transitions |
| Map transitions to actions | Each status change → which related action or form submission triggers it |
| Identify role requirements | Which user role (persona) performs each step |
| Output format | Structured workflow plan: ordered steps with role, action, form, required fields |

**Deliverable:** Given "Evaluation → Awarded", agent outputs:
```
Step 1: [Contracting Officer] Create Evaluation via "Create new evaluation" button
Step 2: [Contracting Officer] Add Vendors via "Add Vendors" related action
Step 3: [Contracting Officer] Add Phases via "Add Phases" related action
Step 4: [Contracting Officer] Start Evaluation via "Start Evaluation" related action
Step 5: [Evaluator] Complete evaluation tasks
Step 6: [Contracting Officer] Award vendor via "Award Vendor" related action
```

### Phase 3: Script Generation (Week 3-4)

**Goal:** Agent generates a runnable locust script from the workflow analysis.

| Task | Details |
|------|---------|
| Build `step-2-interaction-mapping.md` | For each workflow step, query Atlas SAIL forms → get component list → map to locust methods |
| Build `step-3-generate-script.md` | Emit Python: imports, config, task functions, role-based TaskSets, UserActor |
| Handle multi-role scripts | Sequential steps with role switches (multiple UserActor classes or task sequencing) |
| Parameterization | Unique IDs per virtual user (timestamps, random strings), reference data selection |
| Template system | Standard patterns for: create-record, search-click, related-action, upload-doc |

**Deliverable:** Generated `gss_evaluation_to_awarded.py` that runs against the perf env.

### Phase 4: Validation & Self-Healing (Week 4-5)

**Goal:** Generated scripts are verified and self-correcting.

| Task | Details |
|------|---------|
| Syntax validation | `ast.parse()` check |
| Method validation | Verify all locust calls are valid via MCP `validate_script` |
| Optional dry-run | Run against perf env with 1 user, 1 iteration |
| Self-healing loop | If dry-run fails, diagnose error, fix script, retry (max 3 attempts) |
| Failure patterns KB | Common issues: wrong label, missing field, timing issues, role mismatch |

**Deliverable:** Agent generates → validates → fixes → delivers working script.

### Phase 5: Org Rollout (Week 5-6)

**Goal:** Power available to all Solutions teams with documentation.

| Task | Details |
|------|---------|
| Docs + README | How to use the power, what inputs it needs, what it produces |
| Multi-app validation | Test with GSS, ProcureSight, Case Management Studio |
| Integration with SQL Forge | Pre-seeded data referenced in generated scripts |
| CI for Locust MCP | Auto-update when appian-locust releases new version |
| Team onboarding | Demonstrate to GAM, CMS, PS teams |

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Separate MCP for locust reference | Yes | Org-level reuse, single source of truth, decoupled from power |
| Static discovery via Atlas KB | Yes | No runtime dependency on live app for script generation |
| Reuse SQL Forge workflow analysis | Yes | Same pattern, proven, already understands process models |
| Multi-role support | Sequential steps with role annotation | Locust supports multiple UserActor classes |
| Output format | Complete .py file + config.json | Ready to run, no manual assembly |
| Self-healing | Optional (Phase 4) | Not all teams have perf envs accessible from agent |
| appian-locust version tracking | MCP server re-parses source on update | New methods automatically available |

---

## Dependencies

| Dependency | Status | Notes |
|-----------|--------|-------|
| Atlas MCP Server | ✅ Running | 32 tools, process model + SAIL form queries |
| Atlas KB with app data | ✅ Available | GSS, ProcureSight, CMS all parsed |
| appian-locust library | ✅ Stable | v2.0+, 46 releases, PyPI package |
| Data Generator MCP | ✅ Running | For SQL Forge integration |
| Perf environments | ✅ Available | `eng-test-gss-16-perf-2xl.appianpreview.com` |
| Brian's appian-locust-agent | ℹ️ Reference | Pattern reference, potential convergence later |
| solutions-gam-gss-tests | ℹ️ Reference | Existing hand-written tests as examples |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Atlas KB missing SAIL form details | Can't map components → locust methods | Fall back to runtime discovery (Brian's approach) for specific pages |
| appian-locust API changes | Generated scripts break | MCP server pins to known version, validates before output |
| Complex multi-step workflows | Script generation becomes unreliable | Break into smaller sub-workflows, user confirms plan before generation |
| Role switching in Locust | Technical complexity | Use sequential TaskSet pattern (proven in GSS tests) |
| Perf env not accessible | Can't validate scripts | Syntax-only validation, mark as "unverified" |
| Label mismatches (Atlas vs runtime) | Scripts fail on wrong labels | Self-healing loop (Phase 4) corrects via error messages |

---

## Success Criteria

1. **Generate a working GSS evaluation-to-awarded script** from just the natural language prompt — no manual code writing
2. **Script runs successfully** against perf env with zero manual fixes
3. **Time to create a perf test** drops from 2-3 days → 15 minutes
4. **Works for 3+ applications** (GSS, ProcureSight, CMS) without power changes
5. **Org adoption** — at least 2 teams actively using it

---

## Reference: Existing Patterns

### Brian's appian-locust-agent workflow:
1. verify_credentials → 2. discover_elements → 3. generate_test → 4. run_test → 5. self-heal

### SQL Forge workflow (reusable):
1. Workflow Analysis → 2. Exemplar Discovery → 3. Data Architecture → 4. Data Payloads → 5. Validation → 6. Execute

### GSS existing test patterns:
- `gss_create_eval.py` — simple single-action test (create evaluation)
- `gss_lpta_task.py` — multi-step workflow (create → add vendors → add line items)
- Both use `config.json` for host + auth, `SailUiForm` method chaining

---

## Open Questions

1. ~~Should the Locust MCP server also serve as Brian's agent's backend?~~ — Future consideration after v1
2. ~~Do we need the MCP to store test execution history?~~ — No, test results live in the test repo
3. Should generated scripts include performance assertions (response time thresholds)?
4. How do we handle workflows that require external triggers (emails, scheduled processes)?
5. Should the power support generating scripts for specific load profiles (ramp-up, spike, soak)?

---

## Resolved Decisions (2026-05-27)

| Question | Answer |
|----------|--------|
| Does Atlas KB have SAIL form details? | Yes — full SAIL code with component labels, types, choices |
| Multi-role handling? | Switch roles as needed within script (config-based auth per role) |
| Where do generated scripts output? | Directly into `solutions-gam-gss-tests/locust-tests/` |
| Perf environment for validation? | Always available — user provides env details configured in MCP server |
| First target application? | GSS Source Selection (existing hand-written tests for comparison) |
| Locust MCP server config? | Includes perf environment connection details (host, auth per role) |
