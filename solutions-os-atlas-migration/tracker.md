# Atlas KB Migration to solutions-os — Project Tracker

## Project Overview

**Objective:** Consolidate 6 Atlas repos from personal namespaces (`ramaswamy.u/`) into `appian/prod/solutions-os`, the shared production repository.

**Start Date:** April 27, 2026
**Status:** In Progress — Pipeline debugging (API key issue)

---

## Repos Migrated

| Original Repo | New Location in solutions-os | New Name |
|---|---|---|
| `ramaswamy.u/solutions-atlas-kb` | `ai-framework/tools/Atlas/solutions-kb/` | — |
| `ramaswamy.u/appian-atlas` (docs) | `ai-framework/tools/Atlas/README.md` | — |
| `ramaswamy.u/power-appian-atlas-developer` | `ai-framework/Engineering/.kiro/powers/atlas-developer/` | `atlas-developer` |
| `ramaswamy.u/power-appian-reference` | `ai-framework/Engineering/.kiro/powers/sail-reference/` | `sail-reference` |
| `ramaswamy.u/power-appian-atlas-product-owner` | `ai-framework/Product/.kiro/powers/atlas-product-owner/` | `atlas-product-owner` |
| `ramaswamy.u/power-appian-atlas-ux-designer` | `ai-framework/Product/.kiro/powers/atlas-ux-designer/` | `atlas-ux-designer` |

## Repos Staying Separate

| Repo | Location | Reason |
|---|---|---|
| `solutions-atlas-parser` | `appian/prod/solutions-atlas-parser` | Pip-installable library. Pipeline installs it via `CI_JOB_TOKEN`. |
| `solutions-atlas-mcp-server` | `appian/prod/solutions-atlas-mcp-server` | Standalone Docker service. Updated separately (MR-C). |

---

## Key Decisions Made

### 1. KB Location
- **Original plan:** `solutions-os/atlas-kb/` (root level)
- **Final decision:** `ai-framework/tools/Atlas/solutions-kb/` (inside existing `ai-framework/tools/Atlas/` directory)
- **Reason:** `solutions-os` already had `ai-framework/tools/Atlas/solutions-kb/` with a `.gitkeep` placeholder

### 2. Power Naming
- Removed `power-` prefix from all power folder names
- Removed `appian-` from atlas powers (kept for `appian-reference` initially, then renamed to `sail-reference`)
- Final names: `atlas-developer`, `sail-reference`, `atlas-product-owner`, `atlas-ux-designer`

### 3. Power Keywords
- Atlas powers: `["atlas", "atlas-kb", "appian atlas"]` — only triggered when "atlas" is mentioned
- SAIL reference: `["sail", "sail reference", "appian reference"]` — triggered for SAIL language queries

### 4. Pipeline Push Strategy
- **Original plan:** Create MR branches, auto-merge with path-scoped approval rules
- **Reviewer feedback:** Approval rules are branch-based (not path-based) in Stratus GitLab. Setting 0 approvals on `main` would apply to ALL MRs. Prod fork only has `main` branch.
- **Final decision:** Direct push to `main` using `writeRepoProjectAccessToken`
- **How it works:** Stratus creates a project access token with `write_repository` scope, auto-configures branch protection to allow the bot to push, stores token in AWS Secrets Manager, rotates every 30 days

### 5. Token Strategy (Final)

| Token | Purpose | How Configured | How Accessed |
|---|---|---|---|
| Write repository token | Push to `main` | `writeRepoProjectAccessToken: true` in `gitlab-configuration` | `stratus secrets read .../write-repository` at runtime |
| `CI_JOB_TOKEN` | `pip install` parser from `appian/prod/solutions-atlas-parser` | Add `solutions-os` to parser's job token allowlist (Settings → CI/CD) | Automatic in every CI job |
| `REPO_API_KEY` | Download packages from Appian packager API | Stored in `solutions-shared` shared secret | `stratus secrets read solutions-shared --field REPO_API_KEY` |
| `STRATUS_MANAGED_ATLAS_PIPELINE_TRIGGER` | MCP server triggers sync pipeline | `prodTokens` type `trigger` in `gitlab-configuration` | CI variable in `solutions-atlas-mcp-server` |

### 6. API Key Storage
- **Original plan:** Store in project-specific secret via VDI (AWS Console)
- **Problem:** Requires VDI access, `SecretsMaintainer` role, Cloud Training completion
- **Final decision:** Use `solutions-shared` shared secret (already has `REPO_API_KEY`)
- **How:** Added `appian/prod/solutions-os` and `appian/dev/solutions-os` to the shared list in `gitlab-configuration/configuration/shared-secrets.yml`

### 7. Pipeline Schedule
- **Original plan:** `cronJobs` in `gitlab-configuration` (Stratus recommended)
- **Final decision:** GitLab UI (same approach as `solutions-ci` and `solutions-pipelines`)
- **Reason:** Existing solutions team repos all use UI-based schedules
- **Schedule:** Daily at 04:30 UTC (10:00 AM IST)

### 8. MCP Server Data Path
- Data moved from repo root (`data/`) to nested path (`ai-framework/tools/Atlas/solutions-kb/data/`)
- MCP server already supports `ATLAS_DATA_PREFIX` env var (defaults to `data`)
- All `mcp.json` files updated with `ATLAS_DATA_PREFIX: "ai-framework/tools/Atlas/solutions-kb/data"`
- Project ID updated from `13671`/`13478` to `13490` (solutions-os)

### 9. Pipeline Trigger Token
- Users run MCP server locally via Docker — can't distribute secrets to them
- Token baked into Docker image at build time via `ARG`/`ENV` in Dockerfile
- Image is on private registry — only authenticated GitLab users can pull
- `ATLAS_PIPELINE_TRIGGER_TOKEN` removed from user-facing `mcp.json` env vars

### 10. Pipeline YAML Syntax
- **Problem:** GitLab YAML parser rejects `$()` subshell syntax in `script`/`before_script` — error: "config should be a string or a nested array of strings up to 10 levels deep"
- **Solution:** Move all shell logic to a separate `sync_pipeline.sh` script, call functions from YAML
- **Pattern:** Same as `ci-cli` (`pipeline_functions.sh`) and `solutions-pipeline-extensions` (`shell_scripts/pipeline_functions.sh`)

---

## Stratus Platform Learnings

### gitlab-configuration
- Central repo for all GitLab project configuration: `appian/prod/gitlab-configuration`
- Project configs in `configuration/projects/<name>.yml`
- Group tokens in `configuration/group-tokens.yml`
- Shared secrets in `configuration/shared-secrets.yml`
- Changes are applied by scheduled pipelines (runs every 30 minutes)

### writeRepoProjectAccessToken
- Set `writeRepoProjectAccessToken: true` in project config
- Stratus auto-creates token with `write_repository` + `read_repository` scopes
- Auto-updates branch protection on `main` to allow the bot to push
- Token stored in Secrets Manager at: `gitlab.appian-stratus.com/project-access-tokens/projects/appian/prod/<project>/write-repository`
- Rotated every 30 days
- **Only created for prod fork** — not available on dev fork
- 20+ repos use this: `ci-cli`, `crossplane`, `owl-mcp-server`, `kafka-broker`, etc.
- Terraform source: `terraform/modules/write_repository_project_access_tokens/secrets.tf`

### Stratus CLI
- Download requires `Private-Token: $SA_APPIAN_GUEST_ACCESS_TOKEN` header
- Must call `eval $(/tmp/stratus login)` before reading secrets
- Requires `id_tokens.STRATUS_JWT` with `aud: $CI_SERVER_URL` for OIDC auth
- Read secrets: `/tmp/stratus secrets read <path> [--field <key>]`

### Shared Secrets
- Path format: just the secret name (e.g., `solutions-shared`)
- Projects must be listed in `shared-secrets.yml` under the secret's `shared` list
- Read with: `stratus secrets read solutions-shared --field REPO_API_KEY`
- Maintained by groups listed in `maintainerGroups`

### Project Secrets
- Enabled with `secrets: enabled: true` in project config
- Path format: `gitlab.appian-stratus.com/projects/appian/prod/<project>`
- Edited via VDI → AWS Console → Secrets Manager (requires `SecretsMaintainer` role)
- Cannot be edited via Stratus CLI (read-only)

### CI Job Token
- Automatic in every GitLab CI job
- Can access other repos if target repo adds source project to allowlist
- Configure: target repo → Settings → CI/CD → Job token permissions → Add project
- Used for `pip install` from private repos: `git+https://gitlab-ci-token:${CI_JOB_TOKEN}@...`

### Pipeline Schedules
- Stratus recommends `cronJobs` in `gitlab-configuration` (owned by service account)
- Solutions team uses GitLab UI instead (tied to individual user)
- Both approaches work; `cronJobs` is more durable

### Branch Protection on Prod
- Prod forks only have `main` branch
- Approval rules are branch-based, not path-based
- Cannot set 0 approvals for specific file paths
- Any MR to `main` requires approval — no way around it
- Standard pattern for automated changes: push directly to `main` with `writeRepoProjectAccessToken`

### prodTokens
- Defined in project config under `prodTokens`
- Types: `access`, `deploy`, `trigger`
- `storeInProjects` creates masked CI variable `STRATUS_MANAGED_<TOKEN_NAME>` in target project
- `trigger` type tokens are project-specific — must be defined on the project whose pipeline is triggered
- Auto-rotated weekly

### Group Tokens
- Defined in `configuration/group-tokens.yml`
- Service account inherits group's access to repos
- Can store in projects via `storeInProjects` or in secrets via `storeInStratusSecrets`
- Good for cross-project access (e.g., reading from another repo)

---

## MRs and Changes

### MR-A: gitlab-configuration (MERGED)
**File:** `configuration/projects/solutions-os.yml`
- Added `writeRepoProjectAccessToken: true`
- Added `prodTokens` with `atlas-pipeline-trigger` (trigger type, stored in `solutions-atlas-mcp-server`)
- Added `secrets: enabled: true`
- Group changes: `solutions-combined` moved to `developerGroups`, `government-acquisition-management` moved to `ownerGroups`, `testing-experience` removed

### Shared Secrets MR: gitlab-configuration (MERGED)
**File:** `configuration/shared-secrets.yml`
- Added `appian/prod/solutions-os` and `appian/dev/solutions-os` to `solutions-shared` shared list

### Parser Allowlist (DONE)
- Added `appian/prod/solutions-os` to `solutions-atlas-parser` job token allowlist
- Settings → CI/CD → Job token permissions

### MR-B: solutions-os (PENDING REVIEW)
**Branch:** `atlas-migration` on `appian/dev/solutions-os`
**Files:**
- `.gitlab-ci.yml` — replaced default template with include
- `ai-framework/tools/Atlas/solutions-kb/.gitlab-ci-sync.yml` — sync pipeline
- `ai-framework/tools/Atlas/solutions-kb/sync_pipeline.sh` — shell functions for pipeline
- `ai-framework/tools/Atlas/solutions-kb/sync_packages.py` — copied from source
- `ai-framework/tools/Atlas/solutions-kb/releases.json` — copied from source
- `ai-framework/tools/Atlas/solutions-kb/data/` — 15 app directories
- `ai-framework/tools/Atlas/README.md` — Atlas overview and install guide
- `ai-framework/Engineering/.kiro/powers/atlas-developer/` — 10 files
- `ai-framework/Engineering/.kiro/powers/sail-reference/` — 7 files
- `ai-framework/Product/.kiro/powers/atlas-product-owner/` — 14 files
- `ai-framework/Product/.kiro/powers/atlas-ux-designer/` — 8 files

### MR-C: solutions-atlas-mcp-server (READY, NOT PUSHED)
**Branch:** `atlas-migration` on local
**Files:**
- `Dockerfile` — added `ARG/ENV ATLAS_PIPELINE_TRIGGER_TOKEN`
- `.gitlab-ci.yml` — added `DOCKER_BUILD_ARGS` for trigger token
- `mcp.json` — project ID `13490`, `ATLAS_DATA_PREFIX`, `autoApprove`
- `docker-compose.yml` — project ID `13490`, `ATLAS_DATA_PREFIX`
- `.env.example` — project ID `13490`
- `README.md` — all examples updated

---

## Execution Checklist

| # | Action | Status |
|---|--------|--------|
| 1 | Merge MR-A to `gitlab-configuration` | ✅ Merged |
| 2 | Configure parser repo job token allowlist | ✅ Done |
| 3 | Wait for Stratus to provision tokens + secrets | ✅ Done |
| 4 | Add solutions-os to `solutions-shared` secret list | ✅ Merged |
| 5 | Merge MR-B to `solutions-os` | ⬜ Pending review |
| 6 | Create pipeline schedule in GitLab UI | ⬜ After MR-B |
| 7 | Trigger manual pipeline run and verify | ⬜ After #5, #6 |
| 8 | Merge MR-C to `solutions-atlas-mcp-server` | ⬜ After #7 |
| 9 | Archive old repos | ⬜ After #7 |

---

## Issues Encountered

### 1. GitLab YAML Nested Array Error
- **Error:** `jobs:atlas-kb:sync:script config should be a string or a nested array of strings up to 10 levels deep`
- **Cause:** `$()` subshell syntax in YAML `script` entries parsed as nested arrays
- **Fix:** Moved all shell logic to `sync_pipeline.sh`, YAML only calls `source` and function names
- **Pattern:** Same as `ci-cli` and `solutions-pipeline-extensions`

### 2. Approval Rules Are Branch-Based
- **Expected:** Path-scoped approval rules (0 approvals for `solutions-kb/**`)
- **Reality:** GitLab approval rules are branch-based. Target branch is always `main`. Setting 0 approvals on `main` would apply to ALL MRs.
- **Fix:** Switched from MR-based flow to direct push to `main`

### 3. Stratus CLI Download Requires Auth
- **Expected:** `curl $STRATUS_CLI_LINUX_DOWNLOAD_URL`
- **Reality:** Requires `Private-Token: $SA_APPIAN_GUEST_ACCESS_TOKEN` header
- **Found by:** Cross-referencing with `ci-cli` and `solutions-pipeline-extensions` implementations

### 4. writeRepoProjectAccessToken Only on Prod
- Token only created for prod fork, not dev fork
- Dev fork push would need separate `devTokens` or `CI_JOB_TOKEN` (if user is Maintainer)
- **Decision:** Left as prod-only for now

### 5. Parser Repo Access
- `writeRepoProjectAccessToken` only has `write_repository` + `read_repository` on solutions-os itself
- Cannot access `solutions-atlas-parser` (private repo)
- **Fix:** Use `CI_JOB_TOKEN` with allowlist — simplest approach, no extra tokens

### 6. API Key Storage
- Original plan required VDI access to edit project secrets
- Team doesn't have VDI access / `SecretsMaintainer` role
- **Fix:** Use existing `solutions-shared` shared secret which already has `REPO_API_KEY`

---

## Reference Repos

| Repo | What We Learned From It |
|---|---|
| `ci-cli` | `writeRepoProjectAccessToken` pattern, `stratus login` → `secrets read` → `git push`, shell script pattern for YAML |
| `solutions-pipeline-extensions` | `retrieve_secret_by_key` pattern, `SA_APPIAN_GUEST_ACCESS_TOKEN` for CLI download |
| `solutions-ci` | `PACKAGE_REPO_API_KEY` storage in project secrets, UI-based pipeline schedules |
| `crossplane` | `writeRepoProjectAccessToken: true` usage |
| `owl-mcp-server` | Same pattern, owned by `testing-experience` squad |
| `example-kubernetes-service` | `prodTokens` trigger type with `storeInProjects` |
| `maverick-app-import` | `prodTokens` with `read_api` + `read_repository` scopes |

---

## Documents

| Document | Location |
|---|---|
| Original migration plan | `/Users/ramaswamy.u/repo-gitlab/appian/atlas-kb-migration-plan.md` |
| Execution plan (updated) | `/Users/ramaswamy.u/repo-gitlab/appian/atlas-migration-execution.md` |
| This tracker | `/Users/ramaswamy.u/repo/project-tracker/solutions-os-atlas-migration/tracker.md` |

---

## Session Log

### April 30, 2026 — MR-B merged, pipeline debugging begins

#### Completed
- MR-A to `gitlab-configuration` confirmed merged — `writeRepoProjectAccessToken`, `prodTokens`, `secrets` all provisioned
- Parser job token allowlist confirmed done
- Shared secrets MR merged — `solutions-os` added to `solutions-shared` access list
- MR-B pushed to `appian/dev/solutions-os` on `atlas-migration` branch
- MR-B merged to prod after review

#### Pipeline YAML Issues Encountered

**Issue 1: GitLab YAML nested array error**
- Error: `jobs:atlas-kb:sync:before_script config should be a string or a nested array of strings up to 10 levels deep`
- Cause: `$()` subshell syntax in `before_script` entries
- First fix attempt: Moved commands from `before_script` to `script` — still failed
- Second fix attempt: Converted multi-line `|` blocks to single-line commands — still failed
- Third fix attempt: Wrapped all script entries in single quotes — worked for YAML validation but fragile
- **Final fix:** Created `sync_pipeline.sh` with shell functions, YAML only calls `source` and function names
- Pattern matches `ci-cli` (`pipeline_functions.sh`) and `solutions-pipeline-extensions` (`shell_scripts/pipeline_functions.sh`)

**Issue 2: Branch recreation**
- Needed to recreate the `atlas-migration` branch from updated main (new Jarvis tool was added)
- Accidentally deleted branch without preserving changes — had to re-copy and re-apply all changes
- Lesson: Always create a patch first (`git diff main..branch > patch`) before deleting branches

#### Files in sync_pipeline.sh
```
setup_stratus()    — downloads Stratus CLI, logs in, reads API key and write token
sync_apps()        — runs sync_packages.py with --app or --parallel
commit_and_push()  — git add, commit, push to main
```

#### Pipeline Files (Final State)
- `.gitlab-ci.yml` — single `include: local:` pointing to sync YAML
- `ai-framework/tools/Atlas/solutions-kb/.gitlab-ci-sync.yml` — job definition, sources shell script
- `ai-framework/tools/Atlas/solutions-kb/sync_pipeline.sh` — all shell logic with `$()` subshells

#### MCP Server Changes (on local `atlas-migration` branch)
- `Dockerfile` — added `ARG/ENV ATLAS_PIPELINE_TRIGGER_TOKEN`
- `.gitlab-ci.yml` — added `DOCKER_BUILD_ARGS` for trigger token
- `mcp.json` — project ID `13490`, `ATLAS_DATA_PREFIX`, `autoApprove`
- `docker-compose.yml` — project ID `13490`, `ATLAS_DATA_PREFIX`
- `.env.example` — project ID `13490`
- `README.md` — all examples updated with new config

#### Project Tracker Agent Created
- Created global Kiro custom agent at `~/.kiro/agents/project-tracker.json`
- Prompt file at `~/.kiro/agents/project-tracker-prompt.md`
- Keyboard shortcut: `Ctrl+T`
- Purpose: Capture session progress, decisions, learnings into project tracker repo
- Write-restricted to `/Users/ramaswamy.u/repo/project-tracker/` only

---

### May 1, 2026 — Pipeline testing and API key debugging

#### Pipeline Run 1: Prod fork (job 59225775)
- **Status:** Failed
- **Runner:** `internal-shared-blue-deployment-4-us-east-1b` (docker-autoscaler, no tags)
- **Result:** All 15 apps failed with `401 Client Error` from packager API
- **Observation:** Pipeline infrastructure worked — Stratus CLI, secrets read, parser install all succeeded
- **Root cause investigation began**

#### Pipeline Run 2: Dev fork with debug code (job 59250230)
- Added debug output: `echo "API key length: ${#APPIAN_API_KEY}"` and `echo "API key first 4 chars: ${APPIAN_API_KEY:0:4}"`
- **Result:** API key length: 143, starts with `eyJ0` (JWT format)
- Confirmed key matches what's used locally
- Both auth methods (Basic Auth and Appian-Api-Key header) return 200 locally

#### Auth Method Investigation
- **solutions-ci** uses `HTTPBasicAuth(PACKAGE_REPO_API_KEY, '')` with `requests.post()` in `solutions-pipeline-extensions/python_scripts/download_releases/release_handler.py`
- **Our sync_packages.py** used `headers={"Appian-Api-Key": api_key}` with `requests.get()`
- Changed `sync_packages.py` to use `HTTPBasicAuth` — added `from requests.auth import HTTPBasicAuth`
- Created `test_api_auth.py` to test both methods locally — both returned 200

#### Runner Investigation
- Old KB pipeline (`ramaswamy.u/solutions-atlas-kb`, pipeline 5806715) runs successfully on `Shared docker ec2 runners in internal OU` (no tags)
- Our pipeline with `k8s-executor` tag runs on `Generic runner for all projects using kubernetes executors`
- Tried removing `k8s-executor` tag to match old KB — still failed

#### Critical Bug Found: `set -euo pipefail` killing API key read
- `sync_pipeline.sh` has `set -euo pipefail` at the top
- `setup_stratus()` reads write token from prod Secrets Manager
- On dev fork, write token read fails with `AccessDeniedException` (expected — prod-only token)
- `set -e` causes the function to exit immediately on the write token error
- **`APPIAN_API_KEY` was never exported** because it was read BEFORE the write token in the original code... wait, actually it was read AFTER in some versions
- **Fix:** Reordered to read API key first, made write token read non-fatal: `2>/dev/null || echo ""`

#### Pipeline Run 3: Dev fork with fix (job 59251078)
- **Runner:** `Shared docker ec2 runners in internal OU green deployment` (no tags)
- Write token warning displayed correctly: `WARNING: Could not read write token (expected on dev fork)`
- API key was read successfully (no error on that line)
- **Still failed with 401** — confirmed it's not the write token issue

#### Pipeline Run 4: Dev fork with k8s-executor (job 59251433)
- Same result — 401 from packager API
- Write token handled gracefully
- API key confirmed populated

#### Pipeline Run 5: Dev fork with debug (API key length check)
- **Result: API key is wrong**
- The `REPO_API_KEY` field in `solutions-shared` is NOT the correct Appian packager API key
- It's a different key/token stored under that field name

#### Root Cause Confirmed
- `REPO_API_KEY` in `solutions-shared` is not the Appian packager API key
- The correct key needs to be stored somewhere the pipeline can access
- Options: project secret (VDI), new field in shared secret, or CI variable

#### Changes Made to sync_packages.py
- Added `from requests.auth import HTTPBasicAuth`
- Changed `download_package()` and `download_delta_package()` from `headers={"Appian-Api-Key": api_key}` to `auth=HTTPBasicAuth(api_key, '')`
- These changes should be kept — matches how `solutions-ci` authenticates

#### Current State of sync_pipeline.sh
```bash
setup_stratus() {
  curl -Ss --fail --header "Private-Token: $SA_APPIAN_GUEST_ACCESS_TOKEN" "$STRATUS_CLI_LINUX_DOWNLOAD_URL" -o /tmp/stratus && chmod 755 /tmp/stratus
  eval $(/tmp/stratus login)
  export APPIAN_API_KEY=$(/tmp/stratus secrets read solutions-shared --field REPO_API_KEY)
  echo "API key length: ${#APPIAN_API_KEY}"  # DEBUG - remove later
  export WRITE_TOKEN=$(/tmp/stratus secrets read gitlab.appian-stratus.com/project-access-tokens/projects/appian/prod/solutions-os/write-repository 2>/dev/null || echo "")
  if [ -z "$WRITE_TOKEN" ]; then
    echo "WARNING: Could not read write token (expected on dev fork). Push to main will be skipped."
  fi
}
```

#### Remaining Items
- [ ] **BLOCKER:** Store the correct Appian packager API key where the pipeline can read it
  - Option 1: Store in `solutions-os` project secret via VDI (`SecretsMaintainer` role needed)
  - Option 2: Add correct key as new field in `solutions-shared` (needs Maintainer on that secret)
  - Option 3: Add as CI variable on `solutions-os` (needs Maintainer access)
- [ ] Remove debug code from `sync_pipeline.sh` once API key issue is resolved
- [ ] Decide on `k8s-executor` tag vs no tag (both failed due to wrong key, need to retest)
- [ ] Revert `sync_packages.py` auth change if Basic Auth doesn't work (test after correct key is set)
- [ ] Test full pipeline end-to-end on prod fork
- [ ] Create pipeline schedule in GitLab UI
- [ ] Merge MR-C to `solutions-atlas-mcp-server`
- [ ] Archive old repos

---

## Updated Execution Checklist

| # | Action | Status |
|---|--------|--------|
| 1 | Merge MR-A to `gitlab-configuration` | ✅ Merged |
| 2 | Configure parser repo job token allowlist | ✅ Done |
| 3 | Wait for Stratus to provision tokens + secrets | ✅ Done |
| 4 | Add solutions-os to `solutions-shared` secret list | ✅ Merged |
| 5 | Merge MR-B to `solutions-os` | ✅ Merged to prod |
| 6 | Store correct API key for pipeline | ⬜ **BLOCKER** — `REPO_API_KEY` in `solutions-shared` is wrong key |
| 7 | Create pipeline schedule in GitLab UI | ⬜ After #6 |
| 8 | Trigger manual pipeline run and verify | ⬜ After #6 |
| 9 | Merge MR-C to `solutions-atlas-mcp-server` | ⬜ After #8 |
| 10 | Archive old repos | ⬜ After #8 |

### May 5, 2026 — MCP server build fix, power mcp.json creation, refresh verified

#### Completed
- Created `mcp.json` files for all three atlas powers in `solutions-os`:
  - `ai-framework/Engineering/.kiro/powers/atlas-developer/mcp.json`
  - `ai-framework/Product/.kiro/powers/atlas-product-owner/mcp.json`
  - `ai-framework/Product/.kiro/powers/atlas-ux-designer/mcp.json`
- All configured with project ID `13490`, `ATLAS_DATA_PREFIX`, and `autoApprove: ["*"]`
- Fixed MCP server Docker image build — trigger token was not being baked in
- Updated `solutions-atlas-mcp-server/.gitlab-ci.yml`: added `buildargs` input, removed unused `DOCKER_BUILD_ARGS` variable
- Verified token is present in the built image (`glptt-...`)
- Restarted MCP server in Kiro — `refresh_knowledge_base` tool now works end-to-end ✅

#### Decisions Made
- Use `buildargs` component input (not `DOCKER_BUILD_ARGS` variable) to pass build args to kaniko — standard stratus-service pattern used by 10+ repos

#### Issues Encountered
- **Power mcp.json files missing** → Were deferred during migration ("update when structure finalized") but never added back. Created from MCP server repo's updated config.
- **`refresh_knowledge_base` tool failing — token empty in image**
  - Root cause: `DOCKER_BUILD_ARGS` variable in `.gitlab-ci.yml` was never consumed by the stratus-service kaniko template
  - The template uses `$[[ inputs.buildargs ]]` appended to the kaniko executor command
  - Fix: Added `buildargs: "--build-arg ATLAS_PIPELINE_TRIGGER_TOKEN=$STRATUS_MANAGED_ATLAS_PIPELINE_TRIGGER"` to the component inputs
  - Reference: `templates/stratus-service/template.yml` and `templates/image-build/template.yml` in `appian/prod/stratus-pipeline-tools`
  - Other repos using same pattern: maverick-deployment-tools (2363), virustotal (2396), elixir (794), aws-s3-proxy (1023)
- **Token in image but tool still failing** → Stale container. Restarting MCP server in Kiro resolved it.

#### Learnings
- Stratus `stratus-service` component accepts `buildargs` input for custom Docker build args
- `ADDITIONAL_ARGS` in the template is reserved for image signing, not user build args
- `DOCKER_BUILD_ARGS` is NOT a recognized variable by the template — it's a no-op
- When Docker image has `ENV` baked in, `--env VARNAME` without a value from host overrides with empty if host doesn't have it
- After pulling a new image, must restart/reconnect the MCP server in Kiro to use it

#### Remaining Items
- [ ] Push mcp.json changes to `solutions-os` (3 power files)
- [ ] Continue end-to-end testing of all atlas power features

---

### May 6, 2026 — MCP configs, docgenie power push, gitignore issue

#### Completed
- Created `ai-framework/mcp-configs/atlas-mcp.json` — shared Atlas MCP config for standalone use without powers
- Created `ai-framework/mcp-configs/README.md` — explains what it is, 3 usage options (project-level, user-level, custom agent), prerequisites, tool list
- Removed `.gitkeep` placeholder (folder now has real content)
- Created `atlas-dev-documentation` power (12 files) — moved from Product to Engineering
- Pushed all changes to `dev-documentation-power` branch on `appian/dev/solutions-os`
- Fixed MCP server `.gitlab-ci.yml` — `buildargs` input for trigger token (confirmed working, token baked in image)

#### Issues Encountered
- **mcp.json files not in commit** — `.gitignore` line 16 has blanket `mcp.json` rule ignoring all mcp.json files repo-wide
  - Fix: `git add -f` to force-add the power mcp.json files
  - Alternative: add `!**/powers/**/mcp.json` exception to `.gitignore`
- **Git rebase squash error** — user changed wrong line (first instead of second), got "cannot squash without a previous commit"
  - Fix: `git rebase --abort` → `git reset --soft HEAD~2` → `git commit`
- **Push rejected after squash** — needed `git push --force-with-lease`

#### Decisions Made
- `mcp-configs/` folder used for shared MCP configs (as per README intent) — Atlas MCP is the first entry
- Data folder LFS discussion deferred — Stratus docs don't mention LFS, need to confirm with Stratus team before implementing

#### Remaining Items
- [ ] Fix `.gitignore` to allow `mcp.json` in powers (either force-add or add exception rule)
- [ ] Investigate LFS or alternative for `solutions-kb/data/` (565MB) — pending Stratus team confirmation
- [ ] Test `atlas-dev-documentation` power end-to-end
- [ ] Push mcp.json for atlas-developer, atlas-product-owner, atlas-ux-designer powers

---
