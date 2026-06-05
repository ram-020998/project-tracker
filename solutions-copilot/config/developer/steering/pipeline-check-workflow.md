---
inclusion: auto
---

# Daily Pipeline Check Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** — Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** — Don't skip ahead
3. ✅ **VERIFY BLOCKING RULES** — Check that previous steps are complete before proceeding

## 🛑 WORKFLOW VIOLATION RULES — SELF-CHECK ON EVERY RESPONSE

**Rule V1: DATA COLLECTION INVENTORY GATE**
If you call `get_job_log` without first presenting a complete DATA COLLECTION INVENTORY (as defined in Step 4a) in the current or a previous response in this conversation, the workflow is VIOLATED. You must stop, go back to Step 4a, collect all job data, present the inventory, and only then proceed.

**Rule V2: NO DOWNSTREAM PIPELINE LEFT BEHIND**
If `get_pipeline_bridges` returned any downstream pipelines and you did NOT call `get_concise_pipeline_jobs` for each of them, the workflow is VIOLATED. Check your tool call history before proceeding past Step 4a.

**Rule V3: SELF-AUDIT BEFORE STEP 4b**
Before making any `get_job_log` call, ask yourself: "Have I presented the DATA COLLECTION INVENTORY with every downstream pipeline's jobs listed?" If the answer is no, STOP and complete Step 4a first.

**Common Triggers That Activate This Workflow:**
- "Check pipeline alerts"
- "Daily pipeline check"
- "Why did the pipeline fail?"
- "Check today's test results"
- "Pipeline status for VM"
- User selects option 9 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker.**

---

## Overview

Investigates daily CI/CD pipeline results for Appian applications. Uses the orchestrator repo to discover pipeline structure from YML files, fetches failed pipelines from GitLab, reads job logs, classifies failures, traces them back to Appian objects, and generates an actionable report.

## CRITICAL RULES - MANDATORY COMPLIANCE

- ⚠️ Follow steps in order. No skipping.
- ⚠️ Show the execution tracker in EVERY response.
- ⚠️ Call `get_jarvis_config` for pipeline configuration.
- ⚠️ This workflow is READ-ONLY — it investigates failures, it does NOT fix code or create objects.

## WORKFLOW ISOLATION

**What This Workflow Does:**
1. Lists applications with pipeline config
2. Discovers pipeline structure from orchestrator YML files
3. Gets today's pipelines from the orchestrator
4. Follows bridges to downstream test pipelines, reads logs
5. Classifies failures (regression vs flaky vs external)
6. Traces failures to Appian objects (in dev environment)
7. Generates actionable report

**What This Workflow Does NOT Do:**
- ❌ Fix code or modify tests
- ❌ Deploy anything
- ❌ Access test/automation environments (JARVIS only connects to dev)
- ❌ Create JIRA tickets automatically (suggests them)
- ❌ Retry pipelines

---

## MANDATORY EXECUTION TRACKER

```
PIPELINE CHECK EXECUTION TRACKER — {APP_NAME}
===============================================
Step 1: Select Application              [ ] ❌ NOT STARTED
Step 2: Discover Pipeline Structure     [ ] ❌ NOT STARTED
Step 3: Get Today's Pipelines           [ ] ❌ NOT STARTED
Step 4: Get Failed Jobs & Read Logs     [ ] ❌ NOT STARTED
Step 5: Failure Trend Analysis          [ ] ❌ NOT STARTED
Step 6: Trace to Appian Objects         [ ] ❌ NOT STARTED
Step 7: Generate Report                 [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅
- Cannot proceed to Step 5 until Step 4 shows ✅
- Cannot proceed to Step 6 until Step 5 shows ✅
- Cannot proceed to Step 7 until Step 6 shows ✅

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
```

---

## Workflow Steps

### Step 1: Select Application

⚠️ **BEFORE STARTING:** Show the execution tracker with Step 1 as IN PROGRESS

1. Call `get_jarvis_config`
2. List applications that have a `pipelineFolder` configured (non-empty)
3. Show the user a numbered list:
   ```
   Available applications with pipeline config:
   1. SourceSelection (AS_GSS) — pipeline folder: gam-gss
   2. VendorManagement (AS_VM) — pipeline folder: gam-vm
   ```
4. Ask user to select an application (or "all")
5. If user provides an app name directly in the trigger (e.g., "check VM pipeline"), auto-select it
6. Store: `orchestratorRepoId`, `pipelineFolder`, `appPrefix`

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 1 as ✅ COMPLETED

---

### Step 2: Discover Pipeline Structure

⚠️ **BLOCKING CHECK:** Verify Step 1 shows ✅

Read the YML files from the orchestrator repo to understand what pipelines and test types exist for this application. This runs once and gives the agent full context.

1. Get the file tree for the pipeline folder:
   ```
   Tool: mcp_gitlab_get_file_tree
   Input: repo_id={orchestratorRepoId}, sha=main
   ```
   Filter for files in `pipelines/{pipelineFolder}/` that end in `.yml` (exclude `base.yml` and `configs/`)

2. Read the daily pipeline YML (the primary one):
   ```
   Tool: mcp_gitlab_get_file_content
   Input: repo_id={orchestratorRepoId}, file_path=pipelines/{pipelineFolder}/{app}-daily.yml, ref=main
   ```

3. Parse the YML to extract for each job:
   - **Job name** (e.g., "Run Expression Tests", "Run Integration Tests")
   - **Test type** from `TEST_TYPES` variable (EXPRESSION, INTEGRATION, DYN_FITNESSE, OWL, LOCUST)
   - **Downstream repo** from `trigger.project` (e.g., `appian/prod/solutions-gam-gss-tests`)
   - **Downstream branch** from `trigger.branch` (default: main)
   - **allow_failure** flag (true/false)
   - **SITE_URL** — which environment the tests run against
   - **CHAT_ROOM** — from the Report Results job
   - **PIPELINE_NAME** — human-readable name (e.g., "GSS Daily")

4. Read ALL pipeline YMLs found in the file tree — not just the daily one. This includes deployment, upgrade, security, SDX, OWL, and performance pipelines:
   ```
   Pipeline Map for {app_name}:
   - gam-gss-daily.yml → "GSS Daily" (Object Scans + Expression + Integration + FitNesse)
   - gam-gss-owl-smoke.yml → "GSS OWL Smoke Tests" (Owl UI tests)
   - gam-gss-owl-daily.yml → "GSS OWL Daily" (Owl extended UI tests)
   - gam-gss-owl-security.yml → "GSS OWL Security Tests" (Owl security tests)
   - gam-gss-perf.yml → "GSS performance weekly" (Locust performance)
   - gam-gss-sdx.yml → "GAM GSS SDX" (SDX deployment + tests)
   - gam-gss-deployment.yml → "GSS Oracle Deployment" (Oracle deploy + OWL validation)
   - gam-gss-upgrade.yml → "GSS Maria Upgrade" (Maria upgrade + OWL validation)
   ```
   ⚠️ **Read EVERY `.yml` file in the folder.** If you skip a YML, you will miss an entire pipeline category.

5. For each YML, record:
   - **Pipeline name** (from `PIPELINE_NAME` variable)
   - **Trigger type**: Does this pipeline trigger a downstream test repo? Or does it run jobs directly / trigger other repos (e.g., solutions-ci for deployment)?
   - **Downstream repos**: ALL `trigger.project` values — some YMLs trigger multiple repos (e.g., deployment triggers solutions-ci first, then test repo for OWL validation)
   - **Where pipelines appear**: Test repo only? Orchestrator only? Both?

6. Classify each pipeline by where its runs will be visible:
   - **Test repo pipelines**: Triggered into the test repo (e.g., daily, owl-smoke, owl-daily, owl-security, perf). These show up when listing pipelines from the test repo.
   - **Orchestrator-only pipelines**: Run from the orchestrator and trigger other repos like solutions-ci (e.g., SDX, deployment, upgrade). These do NOT appear in the test repo — they must be found by listing pipelines from the orchestrator repo.

   Store this classification — Step 3 needs it to know where to look.

7. Store the complete pipeline map for use in subsequent steps.

**Budget:** 4-10 API calls (file tree + 3-9 YML reads)

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 2 as ✅ COMPLETED, show pipeline map

---

### Step 3: Get Today's Pipelines (ALL Sources)

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅

Collect today's pipelines from ALL sources identified in Step 2. Some pipelines appear in the downstream test repo, others only appear in the orchestrator repo.

**Step 3a: Get pipelines from the downstream test repo**

1. Get today's date in ISO-8601 format (start of day UTC)
2. Extract the downstream test repo project path from the YML (e.g., `appian/prod/solutions-gam-gss-tests`)
3. Resolve the test repo ID:
   ```
   Tool: mcp_gitlab_find_repositories
   Input: name_pattern={test_repo_name}
   ```
   Match the prod repo (path contains `appian/prod/`). Store the repo ID.

4. List all pipelines from the test repo for today:
   ```
   Tool: mcp_gitlab_list_pipelines
   Input: repo_id={test_repo_id}, created_after={today_start_UTC}
   ```

**Step 3b: Find orchestrator pipelines via ID proximity (with batch chaining)**

⚠️ **This step finds orchestrator parent pipelines for ALL pipeline types — including deploy-then-test pipelines.**

**Key insight:** ALL orchestrator pipelines (daily, regression, SDX, deployment, upgrade, OWL) are created in hourly batches (22:03, 00:03, 01:03, etc.). Even deploy-then-test pipelines like SDX and Upgrade have their orchestrator pipeline created at batch time — only the downstream test repo pipeline is delayed by hours. This means we can find ALL orchestrator pipelines by scanning batches, not by scanning from test repo anchors.

**How it works:**
1. Use test repo pipelines as anchors to find the first batch
2. Scan downward to find all orchestrator pipelines in that batch
3. If expected pipelines are still missing, chain to the next hourly batch (~100-150 IDs higher)
4. Repeat until all expected pipelines are found or 3 batches have been scanned

5. **Group test repo pipelines by creation time** to identify the first batch anchor. Pipelines created within ~5 seconds of each other are from the same orchestrator hourly batch.

6. **Scan the first batch** using the lowest test repo pipeline ID as anchor:
   Starting from `anchor_id - 1`, call `get_pipeline` on the orchestrator repo, decrementing by 1. Skip 404s.
   ```
   Tool: mcp_gitlab_get_pipeline
   Input: repo_id={orchestratorRepoId}, pipeline_id={anchor_id - N}
   ```

   ⚠️ **Keep scanning past each hit.** A single batch contains multiple app pipelines (daily + regression + upgrade + deployment all in the same batch). When you find one pipeline matching `pipelines/{pipelineFolder}/`, record it and keep going. Stop only when you've gone 15 IDs past the last hit for this app, OR you hit a pipeline from a clearly earlier batch (different `created_at` hour).

   **Budget per batch:** 5-15 API calls

7. **Check for missing pipelines after each batch.** Compare found orchestrator pipelines against the expected YML map from Step 2. If any expected pipelines are still missing (e.g., SDX not found in the 00:03 batch):

   **Chain to the next batch:** Take the highest orchestrator pipeline ID found in the current batch and add ~120-150 IDs to estimate the next hourly batch. Scan from there:
   ```
   Tool: mcp_gitlab_get_pipeline
   Input: repo_id={orchestratorRepoId}, pipeline_id={last_found_id + 130}
   ```
   If 404, try ±5 IDs. Once you hit an orchestrator pipeline, scan downward and upward within that batch to find all app pipelines.

   **Stop chaining when:** all expected pipelines are found, OR you've scanned 3 batches, OR the batch timestamps are past the current time.

   **Budget for chaining:** 5-10 API calls per additional batch

8. **For each orchestrator pipeline found, follow its bridges:**
   ```
   Tool: mcp_gitlab_get_pipeline_bridges
   Input: repo_id={orchestratorRepoId}, pipeline_id={orchestrator_pipeline_id}
   ```
   - **Daily pipeline bridges** → Object Scans downstream in solutions-ci (record for Step 4)
   - **Deploy-then-test pipeline bridges** → Deploy step status in solutions-ci + test pipeline in test repo
   - **Test-only pipeline bridges** → confirm downstream matches test repo pipeline from Step 3a

   **Total budget for Step 3b:** 15-40 API calls (2-3 batch scans + bridge follows)

**Step 3c: Detect missing pipelines (gap detection)**

9. Compare the **expected pipeline types** from Step 2's YML map against what was actually found (test repo pipelines from Step 3a + orchestrator pipelines from Step 3b).

   For each YML in the pipeline map:
   - If orchestrator pipeline found + test repo pipeline found → full coverage ✅
   - If orchestrator pipeline found but no test repo pipeline → pipeline ran but tests didn't trigger (deploy may have failed) ⚠️ — check orchestrator pipeline status and bridges for deploy step results
   - If test repo pipeline found but no orchestrator pipeline → test ran but orchestrator not found (batch scan missed it) ⚠️ — test results still available
   - If neither found → flag as missing:
     ```
     ⚠️ Expected pipeline "{pipeline_name}" (from {yml_file}) not detected today.
     Possible reasons: not scheduled today, deploy step failed, or still running.
     Manual check: {orchestrator_web_url}
     ```

   **This costs zero API calls** — purely logic comparing Step 2 map against Steps 3a+3b results.

**Step 3d: Deduplicate, merge, and report**

10. Merge pipelines from both sources. Some pipelines discovered via orchestrator bridges may also appear in the test repo listing — deduplicate by pipeline ID.

11. Group all pipelines by status:
   - ✅ Passed (status: "success")
   - ❌ Failed (status: "failed")
   - 🔄 Running (status: "running" or "pending")

12. **Report ALL runs — do not deduplicate or discard older runs.**
   Pipelines can be re-triggered during the day (e.g., SDX fails at 3am, re-runs at 8am and passes). Both runs matter:
   - The daily/scheduled run is the PRIMARY result — this is what the team cares about
   - Re-triggers are SECONDARY — note them but don't let them override the daily results

   **How to identify the primary run:**
   - The earliest run per test type on a given day is typically the scheduled daily run
   - Later runs with the same test type are re-triggers

   **Report format for multiple runs:**
   ```
   Integration: ❌ 5 fail, 43 pass (Daily run, 1:03 AM) ← PRIMARY
     ↳ Re-run at 8:03 AM: ✅ Passed (re-trigger, may be partial)
   SDX: ❌ Failed (3:02 AM) ← PRIMARY
     ↳ Re-run at 8:34 AM: ✅ Passed (6/6)
   ```

   This ensures no information is lost — the developer sees the original failures AND whether a re-run fixed them.

13. Present summary — include the source for each pipeline:
   ```
   Pipeline Summary for {app_name} — {today}
   Test Repo: {test_repo_name} (ID: {test_repo_id})
   Orchestrator Repo: solutions-pipelines (ID: {orchestratorRepoId})

   | Pipeline Type | Pipeline ID | Source | Status | Test Type |
   |--------------|-------------|--------|--------|-----------|
   | Daily — Expression | 5664190 | test repo | ✅ Passed | EXPRESSION |
   | Daily — Integration | 5664189 | test repo | ✅ Passed | INTEGRATION |
   | Daily — FitNesse | 5664188 | test repo | ❌ Failed | DYN_FITNESSE |
   | OWL Smoke | 5664302 | test repo | ❌ Failed | OWL |
   | OWL Security | 5690474 | test repo | ✅ Passed | OWL |
   | SDX | 5690834 | orchestrator | ✅ Passed | SDX |
   | Oracle Deployment | 5690678 | orchestrator | ❌ Failed | DEPLOY+OWL |
   | Maria Upgrade | 5690683 | orchestrator | ❌ Failed | UPGRADE+OWL |
   ```

14. If no failed pipelines AND no "success" pipelines with potential hidden failures → report "All green" and skip to Step 7
15. Otherwise → continue to Step 4 (which inspects ALL pipelines regardless of status)

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 3 as ✅ COMPLETED, show pipeline summary

---

### Step 4: Get Failed Jobs & Read Logs

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅

### Step 4: Inspect ALL Pipelines & Read Logs

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅

⚠️ **CRITICAL: Inspect EVERY pipeline from Step 3 — not just failed ones.**
⚠️ A pipeline with status "success" can contain bridge jobs whose downstream child pipelines have test failures.
⚠️ The only way to know the real test results is to follow bridges and read the actual test jobs.
⚠️ **`allow_failure: true` TRAP:** GitLab reports a pipeline as "success" when ALL failed jobs have `allow_failure: true`. A "success" downstream pipeline can have 33 out of 35 jobs failed. You MUST call `get_concise_pipeline_jobs` on every downstream pipeline and count actual failed jobs — never stop at the pipeline-level status.

For EACH pipeline from Step 3 (regardless of status or source):

**Step 4a: Collect raw job data for ALL pipelines (MANDATORY BEFORE ANY ANALYSIS)**

⚠️ **DO NOT analyze, classify, or skip any pipeline during this step.**
⚠️ **The ONLY output of Step 4a is the DATA COLLECTION INVENTORY below.**
⚠️ **You CANNOT proceed to Step 4b until the inventory is complete and shown.**

For each pipeline from Step 3:

1. Get jobs:
   ```
   Tool: mcp_gitlab_get_concise_pipeline_jobs
   Input: repo_id={source_repo_id}, pipeline_id={pipeline_id}
   ```

2. Get bridges (ALWAYS — no exceptions):
   ```
   Tool: mcp_gitlab_get_pipeline_bridges
   Input: repo_id={source_repo_id}, pipeline_id={pipeline_id}
   ```

3. For EACH bridge with a downstream pipeline, get that downstream pipeline's jobs:
   ```
   Tool: mcp_gitlab_get_concise_pipeline_jobs
   Input: repo_id={bridge.downstream_pipeline.project_id}, pipeline_id={bridge.downstream_pipeline.id}
   ```
   ⚠️ Use the `project_id` from the bridge response — the downstream pipeline may live in a DIFFERENT repo.

**MANDATORY OUTPUT — DATA COLLECTION INVENTORY:**

After completing all API calls above, you MUST present this inventory before proceeding. Every row must have actual job data from API calls — no "assumed passed" or "see above."

```
DATA COLLECTION INVENTORY — Step 4a
====================================

Pipeline: {pipeline_id} ({pipeline_name})
  Direct jobs:
    - {job_name}: {status} (allow_failure: {true/false})
  Bridges found: {count}
  Downstream pipeline: {downstream_id} (repo: {project_id}, status: {status})
    Downstream jobs:  ← 🛑 REQUIRED even if downstream status is "success"
      - {job_name}: {status} (allow_failure: {true/false})
      - {job_name}: {status} (allow_failure: {true/false})
      - ...

Pipeline: {pipeline_id} ({pipeline_name})
  Direct jobs:
    - {job_name}: {status} (allow_failure: {true/false})
  Bridges found: 0
  No downstream pipelines.

... (repeat for ALL pipelines from Step 3)

INVENTORY COMPLETENESS CHECK:
  Total pipelines inspected: {X}
  Total bridge calls made: {X}
  Total downstream pipelines with jobs fetched: {X}
  Any downstream pipeline where jobs were NOT fetched: {list or "NONE"}
```

🛑 **BLOCKING: If "Any downstream pipeline where jobs were NOT fetched" is not "NONE", go back and fetch those jobs before proceeding.**

**Step 4b: Read failure logs**

Only after the DATA COLLECTION INVENTORY is complete and shown:

For each job in the inventory with `status: "failed"` (regardless of `allow_failure`):

   **pytest (Integration Tests):**
   - Look for `FAILURES` section and `short test summary info`
   - Extract: test file name, test method, error type, error message
   - Extract: X passed, Y failed, Z skipped counts

   **Owl (UI Tests):**
   - Look for `TestSmoke.test_*: Failed` or `TestSmoke.test_*: Passed` lines
   - Look for `FAILURE at call of` lines with JIRA ID
   - Extract: Selenium error (NoSuchElementException, TimeoutException, etc.)
   - Check for `script timeout: context deadline exceeded` (job timeout)

   **FitNesse:**
   - Look for test result summary lines
   - Extract: pass/fail/skip counts

   **Expression Tests:**
   - Look for assertion failures in expression evaluation results

3. Extract Appian object name from test:
   - Integration: test file `AS_VM_INT_GET_SolicitationDetailsFromCW_test.py` → object `AS_VM_INT_GET_SolicitationDetailsFromCW`
   - Owl: JIRA ID from `@jira_id("GAM-13664")` + test method name

4. Classify each failure:

   | Error Pattern | Classification | Priority |
   |--------------|----------------|----------|
   | HTTP 429 | 🌐 External — Rate Limited | Low (retry) |
   | HTTP 503, 502, timeout | 🌐 External — Service Down | Low (wait) |
   | NoSuchElementException (Owl) | 🐛 UI Element Missing | Medium |
   | AttributeError, TypeError | 🐛 Code Bug — Type Mismatch | High |
   | AssertionError on fields | 🐛 Code Bug — Schema Change | High |
   | AssertionError on values | 🐛 Code Bug — Logic Change | High |
   | script timeout exceeded | ⏱️ Timeout — test hung | Medium |
   | Pod scheduling errors | 🏗️ Infrastructure | Low |

5. Note `allow_failure` from the YML: if the job has `allow_failure: true`, mark it as "non-blocking" in the report.

6. Note `SITE_URL` from the YML: include the target environment in the report for manual verification.

**Budget:** 3-15 API calls (jobs for each pipeline + bridges + downstream jobs + logs for failures)

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 4 as ✅ COMPLETED, show classified failures

---

### Step 5: Failure Trend Analysis

⚠️ **BLOCKING CHECK:** Verify Step 4 shows ✅

For failures classified as 🐛 Code Bug or 🐛 UI Element Missing:

1. Get the last 7 days of pipelines from the test repo:
   ```
   Tool: mcp_gitlab_list_pipelines
   Input: repo_id={test_repo_id}, created_after={7_days_ago_UTC}, limit=20
   ```

2. **Same commit SHA check:** If all recent pipelines have the same SHA, no code changed in the test repo. Failures are environmental or flaky — not caused by test code changes.

3. For each code bug failure, check the same job in recent pipelines:
   ```
   Tool: mcp_gitlab_get_pipeline_job
   Input: repo_id={test_repo_id}, pipeline_id={recent_pipeline_id}, job_name={job_name}
   ```

4. Classify the trend:

   | Pattern (last 7 runs) | Classification | Priority |
   |----------------------|----------------|----------|
   | ✅✅✅✅✅✅❌ (just failed) | 🆕 New Regression | HIGH |
   | ❌❌❌❌❌❌❌ (failing for days) | 📌 Persistent Failure | MEDIUM |
   | ✅❌✅❌✅❌❌ (alternating) | 🔄 Intermittent/Flaky | LOW |

5. For 🆕 New Regressions:
   a. Check recent commits in the test repo:
      ```
      Tool: mcp_gitlab_list_commits
      Input: repo_id={test_repo_id}, branch=main
      ```
   b. Check recent merged MRs:
      ```
      Tool: mcp_gitlab_list_merge_requests
      Input: repo_id={test_repo_id}, state=merged
      ```

6. For 📌 Persistent Failures — find first failure date by walking back through history.

**Budget:** 5-15 API calls

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 5 as ✅ COMPLETED, show trend classifications

---

### Step 6: Trace to Appian Objects

⚠️ **BLOCKING CHECK:** Verify Step 5 shows ✅

For failures classified as 🆕 New Regression or 🐛 Code Bug (not UI/Owl tests):

1. Search for the Appian object in the dev environment:
   ```
   Tool: mcp_jarvis_search_objects_semantic
   Input: searchTerm={appian_object_name}, appPrefix={appPrefix}
   ```

2. If found, check version history:
   ```
   Tool: mcp_jarvis_get_version_context
   Input: uuid={uuid}, typeId={typeId}, dateTime={2_days_ago}
   ```
   Check if someone modified the object recently.

3. For Owl/UI test failures — read the test source code instead:
   ```
   Tool: mcp_gitlab_get_file_content
   Input: repo_id={test_repo_id}, file_path={test_file_path}, ref=main
   ```
   Understand what the test does and what UI element it's looking for.

4. For each traced failure, produce:
   - Object name and UUID (if found in dev)
   - Last modified date and author
   - Whether the object was recently changed
   - Target environment from YML (for manual verification — JARVIS cannot access test environments)

**⚠️ ENVIRONMENT NOTE:** JARVIS only connects to the dev environment. The tests run against different environments (test, automation). The agent traces changes in dev (where code originates) but cannot verify behavior in the test environment. Include the `SITE_URL` in the report so the developer knows where to check manually.

**Skip this step for:** 🌐 External dependency failures and 🏗️ Infrastructure failures.

**Budget:** 2-6 API calls

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 6 as ✅ COMPLETED

---

### Step 7: Generate Report

⚠️ **BLOCKING CHECK:** Verify Step 6 shows ✅

Present the complete report in chat, grouped by pipeline type:

```markdown
# Daily Pipeline Report — {App Name} ({date})

## Pipeline Overview
| Pipeline | Source | Status | Test Types |
|----------|--------|--------|------------|
| GSS Daily | test repo | ❌ Failed | Obj Scans, Expression, Integration, FitNesse |
| GSS OWL Smoke | test repo | ❌ Failed | Owl UI Tests |
| GSS OWL Security | test repo | ✅ Passed | Owl Security Tests |
| GAM GSS SDX | orchestrator | ✅ Passed | SDX Deployment |
| GSS Oracle Deployment | orchestrator | ❌ Failed | Deploy + OWL Validation |
| GSS Maria Upgrade | orchestrator | ❌ Failed | Upgrade + OWL Validation |

## GSS Daily — Failures
⚠️ MANDATORY: List EVERY job from EVERY downstream pipeline with its actual status.
Do NOT summarize as "passed" — list each job individually.

### Object Scans (solutions-ci pipeline #{id})
| Job Name | Status | allow_failure |
|----------|--------|---------------|
| Download Releases | ✅ passed | No |
| Prep Artifacts | ✅ passed | No |
| Dependency Scanning | ✅ passed | Yes |
| SAST Scanning | ✅ passed | Yes |
| Secret Scanning | ✅ passed | Yes |
| Plugin Replacement Scanning | ✅ passed | Yes |
| Hardcoded Objects Scanning | ❌ failed | Yes |
| A11y Config Scanning | ✅ passed | Yes |
| System Object Scanning | ✅ passed | Yes |

### Expression Tests
| Passed | Failed | Skipped |
|--------|--------|---------|
| 1836 | 0 | 0 |

### Integration Tests
| Passed | Failed | Skipped |
|--------|--------|---------|
| 4 | 0 | 0 |

### FitNesse (downstream pipeline #{id})
| Job Name | Status | allow_failure |
|----------|--------|---------------|
| R05_Verify_Settings_site | ✅ passed | Yes |
| R13_Submit_Document | ✅ passed | Yes |
| R14_Task_Actions | ❌ failed | Yes |

### FitNesse Failures
1. **{Test Name}**
   - Classification: 📌 Persistent Failure (since Apr 3)
   - Error: {error message}
   - Environment: {SITE_URL from YML}
   - Recommendation: {action}

## GSS OWL Smoke — Failures
### TestSmoke.test_deployment_without_OTS_consensus (GAM-13664)
- Classification: 🔄 Intermittent/Flaky
- Error: NoSuchElementException — consensus confirmation modal not found
- Trend: ❌✅❌✅❌ (50% failure rate over 7 days)
- Environment: eng-test-gam-automation-site
- Recommendation: Increase wait timeout for modal dialog

## New Regressions (Action Required)
{List any 🆕 New Regression failures with full trace}

## Summary
| Category | Count |
|----------|-------|
| 🆕 New Regression | 0 |
| 📌 Persistent Failure | 1 |
| 🔄 Intermittent/Flaky | 1 |
| 🌐 External Dependency | 0 |
| 🏗️ Infrastructure | 0 |
```

If all pipelines passed:
```markdown
# Daily Pipeline Report — {App Name} ({date})
✅ All pipelines passed. No action required.
```

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 7 as ✅ COMPLETED

---

## API Budget

| Step | Calls |
|------|-------|
| Step 2: Discover structure (file tree + YML reads from orchestrator) | 4-10 |
| Step 3: Test repo + orchestrator batch scanning + bridge follows + gap detection | 15-45 |
| Step 4: Get jobs for ALL pipelines + follow bridges + read logs | 5-20 |
| Step 5: Trend analysis (pipeline history + job checks + commits/MRs) | 5-15 |
| Step 6: Trace to Appian objects + read test files | 2-6 |
| **Total** | **36-96** |

---

## Configuration

Pipeline config from `get_jarvis_config` per application:

- `pipelineFolder`: Folder name under `pipelines/` in the orchestrator repo (e.g., `gam-gss`, `gam-vm`, `gam-rm`)
- `pipelineRepoId`: From `globalSettings` — GitLab project ID for the orchestrator repo (e.g., 1805)

The agent reads YML files from `pipelines/{pipelineFolder}/` to discover test types, downstream repos, environments, and chat rooms dynamically. No hardcoding needed.

Applications without a `pipelineFolder` are skipped in Step 1.
