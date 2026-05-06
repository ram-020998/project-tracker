# Atlas Migration Execution Plan

Consolidate Atlas repos from personal namespaces into `solutions-os`.

## Decisions

| Decision | Choice |
|----------|--------|
| KB location | `ai-framework/tools/Atlas/solutions-kb/` |
| Atlas docs | Single `README.md` at `ai-framework/tools/Atlas/README.md` |
| Power READMEs | Description only, no install steps |
| Power steering | Keep internal `.kiro/steering.md` as-is |
| Power icons | Skip `icon.png` for all powers |
| Directory casing | `Engineering/` and `Product/` (match existing) |
| CI config | Replace default template entirely, Atlas sync only |
| Job isolation | Rules-based (option 1) — future jobs must include own `rules:` |
| Schedule | Daily at 10:00 AM IST (04:30 UTC), via GitLab UI (same approach as `solutions-ci` and `solutions-pipelines`) |
| Auto-merge | ~~Path-scoped approval rule~~ — not possible, approval rules are branch-based. Pipeline pushes directly to `main`. |
| Push token | `writeRepoProjectAccessToken: true` — standard Stratus mechanism, auto-configures branch protection |
| Read token | `CI_JOB_TOKEN` — add `solutions-os` to `solutions-atlas-parser` job token allowlist |
| API key | Reuse `PACKAGE_REPO_API_KEY` from Stratus Secrets Manager (same as `solutions-ci`) |
| Branch protection | Handled automatically by `writeRepoProjectAccessToken` — no manual config needed |
| Archival | Last step, after everything is verified |

## Open Items

| Item | Status |
|------|--------|
| `mcp.json` structure for powers | ⬜ Not finalized — `autoApprove` and trigger token removal are decided, but full structure TBD |
| MCP server Dockerfile update | ⬜ Update `solutions-atlas-mcp-server` to bake in trigger token at build time |
| How to store `PACKAGE_REPO_API_KEY` in project secret | ⬜ Confirm VDI access / `SecretsMaintainer` role, or find alternative approach |

---

## Task 1: Migrate solutions-atlas-kb

**Source:** `ramaswamy.u/solutions-atlas-kb`
**Target:** `solutions-os/ai-framework/tools/Atlas/solutions-kb/`

### Files to copy

| Source | Target |
|--------|--------|
| `data/` (12 app directories) | `ai-framework/tools/Atlas/solutions-kb/data/` |
| `sync_packages.py` | `ai-framework/tools/Atlas/solutions-kb/sync_packages.py` |
| `releases.json` | `ai-framework/tools/Atlas/solutions-kb/releases.json` |

### Files to skip
- `.gitlab-ci.yml` (replaced by new sync pipeline)
- `.kiro/` (repo-specific steering)
- `README.md` (replaced by Atlas-level README in Task 2)
- `.gitignore` (handled at solutions-os level)

### Path handling
`sync_packages.py` uses `SCRIPT_DIR` to resolve `releases.json` and `data/`. This works as-is since the files stay alongside the script. No code changes needed.

### Pipeline
Create `ai-framework/tools/Atlas/solutions-kb/.gitlab-ci-sync.yml`:

```yaml
default:
  id_tokens:
    STRATUS_JWT:
      aud: $CI_SERVER_URL

stages:
  - sync

atlas-kb:sync:
  stage: sync
  image: python:3.12-slim
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
    - if: $CI_PIPELINE_SOURCE == "trigger"
  before_script:
    - apt-get update && apt-get install -y --no-install-recommends git curl
    - curl -Ss --fail --header "Private-Token: $SA_APPIAN_GUEST_ACCESS_TOKEN" "$STRATUS_CLI_LINUX_DOWNLOAD_URL" -o /tmp/stratus && chmod 755 /tmp/stratus
    - eval $(/tmp/stratus login)
    - export APPIAN_API_KEY=$(/tmp/stratus secrets read solutions-shared --field REPO_API_KEY)
    - export WRITE_TOKEN=$(/tmp/stratus secrets read gitlab.appian-stratus.com/project-access-tokens/projects/appian/prod/solutions-os/write-repository)
  script:
    - pip install "git+https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.appian-stratus.com/appian/prod/solutions-atlas-parser.git@main" requests
    - |
      if [ -n "$APP_NAME" ]; then
        echo "Syncing single app: $APP_NAME"
        python ai-framework/tools/Atlas/solutions-kb/sync_packages.py --api-key "${APPIAN_API_KEY}" --app "$APP_NAME"
      else
        echo "Syncing all apps (parallel)"
        python ai-framework/tools/Atlas/solutions-kb/sync_packages.py --api-key "${APPIAN_API_KEY}" --parallel
      fi
    - git config user.name "gitlab-ci[bot]"
    - git config user.email "gitlab-ci[bot]@gitlab.appian-stratus.com"
    - git add ai-framework/tools/Atlas/solutions-kb/data/ -f
    - git reset HEAD -- 'ai-framework/tools/Atlas/solutions-kb/**/parsed_state.json'
    - |
      if git diff --cached --quiet; then
        echo "No changes to commit"
      else
        APPS_CHANGED=$(git diff --cached --name-only | grep -oP 'solutions-kb/data/\K[^/]+' | sort -u | tr '\n' ', ' | sed 's/,$//')
        git commit -m "chore: sync atlas-kb ${APPS_CHANGED} $(date -u +%Y-%m-%d)"
        git push "https://oauth2:${WRITE_TOKEN}@gitlab.appian-stratus.com/appian/prod/solutions-os.git" HEAD:main
      fi
  cache:
    key: atlas-kb-parsed-state
    paths:
      - ai-framework/tools/Atlas/solutions-kb/data/*/current/parsed_state.json
```

### Dependent changes
- `solutions-atlas-mcp-server` needs its repo ID parameter updated to point to `solutions-os` (runtime config change, no downtime)

---

## Task 2: Create Atlas README

**Target:** `solutions-os/ai-framework/tools/Atlas/README.md`

### Content
Single document covering:
- What Atlas is
- Architecture overview (parser, KB, MCP server, powers)
- How to install and use
- Component locations table (updated paths within `solutions-os`)
- Links to repos that stay separate (`solutions-atlas-parser`, `solutions-atlas-mcp-server`)

### Updated component locations

| Component | Location |
|-----------|----------|
| Knowledge base data | `ai-framework/tools/Atlas/solutions-kb/data/` |
| Sync pipeline | `ai-framework/tools/Atlas/solutions-kb/sync_packages.py` |
| Developer power | `ai-framework/Engineering/.kiro/powers/atlas-developer/` |
| SAIL reference power | `ai-framework/Engineering/.kiro/powers/appian-reference/` |
| Product Owner power | `ai-framework/Product/.kiro/powers/atlas-product-owner/` |
| UX Designer power | `ai-framework/Product/.kiro/powers/atlas-ux-designer/` |
| Appian parser | `appian/prod/solutions-atlas-parser` (separate repo) |
| MCP server | `appian/prod/solutions-atlas-mcp-server` (separate repo) |

---

## Task 3: Migrate power-appian-atlas-developer

**Source:** `ramaswamy.u/power-appian-atlas-developer`
**Target:** `solutions-os/ai-framework/Engineering/.kiro/powers/atlas-developer/`

### Files to copy

| Source | Target |
|--------|--------|
| `POWER.md` | `POWER.md` |
| `mcp.json` | `mcp.json` (⬜ update when structure finalized) |
| `README.md` | `README.md` (simplify to description only) |
| `steering/` (6 files) | `steering/` |
| `.kiro/steering.md` | `.kiro/steering.md` |

### Files to skip
- `icon.png`
- `.git/`

### Changes needed
- `README.md`: remove install steps, keep description of what the power does
- `mcp.json`: update when structure is finalized, add `"autoApprove": ["*"]` to all MCP server entries
- `POWER.md`: change keywords to `["atlas", "atlas-kb", "appian atlas"]`
- Any hardcoded repo references in steering files: update to `solutions-os` paths

---

## Task 4: Migrate power-appian-reference

**Source:** `ramaswamy.u/power-appian-reference`
**Target:** `solutions-os/ai-framework/Engineering/.kiro/powers/appian-reference/`

### Files to copy

| Source | Target |
|--------|--------|
| `POWER.md` | `POWER.md` |
| `README.md` | `README.md` (simplify to description only) |
| `steering/` | `steering/` |

### Files to skip
- `.git/`

### Notes
- No `mcp.json` or `icon.png` in source — nothing to skip beyond `.git/`
- Same README treatment: description only
- `POWER.md`: change keywords to `["sail", "sail reference", "appian reference"]`

---

## Task 5: Migrate power-appian-atlas-product-owner

**Source:** `ramaswamy.u/power-appian-atlas-product-owner`
**Target:** `solutions-os/ai-framework/Product/.kiro/powers/atlas-product-owner/`

### Files to copy

| Source | Target |
|--------|--------|
| `POWER.md` | `POWER.md` |
| `mcp.json` | `mcp.json` (⬜ update when structure finalized) |
| `README.md` | `README.md` (simplify to description only) |
| `steering/` (10 files) | `steering/` |
| `.kiro/steering.md` | `.kiro/steering.md` |

### Files to skip
- `icon.png`
- `.git/`

### Changes needed
- Same as Task 3: simplify README, update `mcp.json` later, update hardcoded repo references
- `mcp.json`: add `"autoApprove": ["*"]` to all MCP server entries
- `POWER.md`: change keywords to `["atlas", "atlas-kb", "appian atlas"]`

---

## Task 6: Migrate power-appian-atlas-ux-designer

**Source:** `ramaswamy.u/power-appian-atlas-ux-designer`
**Target:** `solutions-os/ai-framework/Product/.kiro/powers/atlas-ux-designer/`

### Files to copy

| Source | Target |
|--------|--------|
| `POWER.md` | `POWER.md` |
| `mcp.json` | `mcp.json` (⬜ update when structure finalized) |
| `README.md` | `README.md` (simplify to description only) |
| `steering/` (3 files) | `steering/` |
| `.kiro/steering.md` | `.kiro/steering.md` |

### Files to skip
- `icon.png`
- `.gitignore`
- `.git/`

### Changes needed
- Same as Task 3: simplify README, update `mcp.json` later, update hardcoded repo references
- `mcp.json`: add `"autoApprove": ["*"]` to all MCP server entries
- `POWER.md`: change keywords to `["atlas", "atlas-kb", "appian atlas"]`

---

## Task 7: Replace solutions-os CI config

**Target:** `solutions-os/.gitlab-ci.yml`

The current file is the default GitLab template (echo statements, sleep commands). Replace it entirely with:

```yaml
include:
  - local: ai-framework/tools/Atlas/solutions-kb/.gitlab-ci-sync.yml
```

This is the only content needed. The sync job definition lives in the included file.

**Important for future contributors:** The sync job's `rules:` ensure it only runs on `schedule`, `web`, or `trigger` sources. Any future jobs added to this file (or included from other files) **must include their own `rules:`** to avoid running on the Atlas sync schedule.

---

## Task 8: Infrastructure setup

This task covers all infrastructure configuration needed before the sync pipeline can run. Steps are organized in execution order.

---

### MR-A: Update `gitlab-configuration`

Submit a single MR to [`appian/prod/gitlab-configuration`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration) with the following changes to `configuration/projects/solutions-os.yml`.

**Current config:**
```yaml
- name: solutions-os
  description: Framework for acclerating solution devs designing features from research to release.
  ownerGroups:
    - squads/financial-services-solutions
    - squads/insurance-solutions
    - squads/solutions-development-acceleration
    - squads/solutions-combined
    - squads/testing-experience
  developerGroups:
    - squads/government-acquisition-management
  reporterGroups:
    - squads/ecosystem-sbu-contractors
```

**Add the following three blocks:**

**1. `writeRepoProjectAccessToken: true`** — enables the pipeline to push directly to `main`

```yaml
  writeRepoProjectAccessToken: true
```

What this does automatically:
- Creates a project access token with `write_repository` and `read_repository` scopes
- Updates the branch protection on `main` to allow this token's bot user to push directly
- Stores the token in AWS Secrets Manager at: `gitlab.appian-stratus.com/project-access-tokens/projects/appian/prod/solutions-os/write-repository`
- Rotates the token every 30 days

Reference implementations:
- [`ci-cli`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/configuration/projects/ci-cli.yml) — reads the token via `stratus secrets read` and pushes to prod main
- [`crossplane`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/configuration/projects/crossplane.yml) — uses `writeRepoProjectAccessToken: true`
- [`owl-mcp-server`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/configuration/projects/owl-mcp-server.yml) — same pattern, owned by `testing-experience` squad

Terraform source: [`terraform/modules/write_repository_project_access_tokens/secrets.tf`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/terraform/modules/write_repository_project_access_tokens/secrets.tf)

Reference: https://docs.appian-stratus.io/stratus/secrets-management/other-provided-secrets.html

**2. `prodTokens`** — trigger token for MCP server to start the sync pipeline on demand

```yaml
  prodTokens:
    - name: atlas-pipeline-trigger
      description: Trigger token for MCP server to start Atlas KB sync pipeline
      type: trigger
      storeInProjects:
        - appian/prod/solutions-atlas-mcp-server
```

Creates a CI variable `STRATUS_MANAGED_ATLAS_PIPELINE_TRIGGER` in the `solutions-atlas-mcp-server` project, available during its Docker image build.

**3. `secrets: enabled: true`** — enables project-specific secrets in AWS Secrets Manager

```yaml
  secrets:
    enabled: true
```

Creates an empty secret at: `gitlab.appian-stratus.com/projects/appian/prod/solutions-os`

Reference: [`ci-cli`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/configuration/projects/ci-cli.yml), [`solutions-ci`](https://gitlab.appian-stratus.com/appian/prod/gitlab-configuration/-/blob/main/configuration/projects/solutions-ci.yml)

**Complete updated `solutions-os.yml`:**

```yaml
- name: solutions-os
  description: Framework for acclerating solution devs designing features from research to release.
  ownerGroups:
    - squads/financial-services-solutions
    - squads/insurance-solutions
    - squads/solutions-development-acceleration
    - squads/solutions-combined
    - squads/testing-experience
  developerGroups:
    - squads/government-acquisition-management
  reporterGroups:
    - squads/ecosystem-sbu-contractors
  writeRepoProjectAccessToken: true
  prodTokens:
    - name: atlas-pipeline-trigger
      description: Trigger token for MCP server to start Atlas KB sync pipeline
      type: trigger
      storeInProjects:
        - appian/prod/solutions-atlas-mcp-server
  secrets:
    enabled: true
```

**After MR-A is merged**, wait for Stratus to provision the tokens and secrets.

---

### Manual: Configure parser repo job token access

*Can be done in parallel with MR-A.*

Go to [`appian/prod/solutions-atlas-parser`](https://gitlab.appian-stratus.com/appian/prod/solutions-atlas-parser) → Settings → CI/CD → Job token permissions → **Add `appian/prod/solutions-os` to the allowlist**.

This allows `solutions-os` pipelines to use the automatic `CI_JOB_TOKEN` to `pip install` the parser. No extra tokens needed.

```bash
pip install "git+https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.appian-stratus.com/appian/prod/solutions-atlas-parser.git@main" requests
```

Since you own both repos, this is a settings change — no MR needed.

Reference: https://docs.gitlab.com/ee/ci/jobs/ci_job_token.html

---

### Manual: Store the API key in project secret

*After MR-A is merged and the secret is provisioned.*

**⬜ Open question:** The exact process needs to be confirmed. Per Stratus docs, secrets are edited via the AWS Console inside the VDI under the `secrets-prod` account with `SecretsMaintainer` role. We need to confirm:
- Whether we have VDI access and the `SecretsMaintainer` role
- Whether there's an alternative way (e.g., asking the Stratus Delivery Systems team)

Secret path: `gitlab.appian-stratus.com/projects/appian/prod/solutions-os`

Value to store:
```json
{
  "PACKAGE_REPO_API_KEY": "<your-api-key-value>"
}
```

Reference: https://docs.appian-stratus.io/stratus/secrets-management/editing-secrets.html

---

### MR-B: Migrate files to `solutions-os`

*After MR-A is merged and tokens are provisioned.*

This is a single MR containing all file migrations from Tasks 1-7:
- KB data, sync script, releases.json, `.gitlab-ci-sync.yml` (Task 1)
- Atlas README (Task 2)
- 4 powers with renamed folders (Tasks 3-6)
- Replace `.gitlab-ci.yml` (Task 7)

The pipeline YAML uses three secrets:
- **`CI_JOB_TOKEN`** (automatic) — `pip install` from `solutions-atlas-parser`
- **Write repository token** (from Secrets Manager) — `git push` to `main`
- **`PACKAGE_REPO_API_KEY`** (from project secret) — download packages from Appian packager

Pipeline `before_script`:
```yaml
  before_script:
    - apt-get update && apt-get install -y --no-install-recommends git curl
    - curl -Ss --fail --header "Private-Token: $SA_APPIAN_GUEST_ACCESS_TOKEN" "$STRATUS_CLI_LINUX_DOWNLOAD_URL" -o /tmp/stratus && chmod 755 /tmp/stratus
    - eval $(/tmp/stratus login)
    - export APPIAN_API_KEY=$(/tmp/stratus secrets read solutions-shared --field REPO_API_KEY)
    - export WRITE_TOKEN=$(/tmp/stratus secrets read gitlab.appian-stratus.com/project-access-tokens/projects/appian/prod/solutions-os/write-repository)
```

Reference: [`ci-cli` pipeline](https://gitlab.appian-stratus.com/appian/prod/ci-cli) — uses the same `stratus login` → `stratus secrets read` → `git push` pattern.

---

### Manual: Create pipeline schedule

*After MR-B is merged.*

`solutions-os` → Settings → CI/CD → Schedules → **New schedule**:

| Setting | Value |
|---------|-------|
| Description | `Atlas KB daily sync` |
| Interval pattern | Custom: `30 4 * * *` |
| Cron timezone | `UTC` (10:00 AM IST) |
| Target branch | `main` |
| Active | ✅ |

Same approach used by [`solutions-ci`](https://gitlab.appian-stratus.com/appian/prod/solutions-ci) and [`solutions-pipelines`](https://gitlab.appian-stratus.com/appian/prod/solutions-pipelines).

---

### Verify end-to-end (Task 9)

Trigger a manual pipeline run and verify everything works. See Task 9 for details.

---

### MR-C: Update MCP server

*After the sync pipeline is verified working.*

Submit MR to [`solutions-atlas-mcp-server`](https://gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server):

**a. Update Dockerfile to bake in trigger token:**

```dockerfile
ARG ATLAS_PIPELINE_TRIGGER_TOKEN
ENV ATLAS_PIPELINE_TRIGGER_TOKEN=$ATLAS_PIPELINE_TRIGGER_TOKEN
```

**b. Update CI build job:**

```yaml
build:
  script:
    - docker build --build-arg ATLAS_PIPELINE_TRIGGER_TOKEN=$STRATUS_MANAGED_ATLAS_PIPELINE_TRIGGER ...
```

The token is embedded in the image. Since the image is on the private registry (`registry.gitlab.appian-stratus.com`), only authenticated GitLab users can pull it.

**c. mcp.json changes** (already done in Tasks 3-6):

| Field | Before | After |
|-------|--------|-------|
| `ATLAS_KB_PROJECT_ID` | `13671` | `13490` (solutions-os) |
| `ATLAS_DATA_PREFIX` | not set (defaulted to `data`) | `ai-framework/tools/Atlas/solutions-kb/data` |
| `ATLAS_PIPELINE_TRIGGER_TOKEN` | User-provided env var | Removed (baked into image) |

---

### Complete execution checklist

| # | Action | Type | Depends on |
|---|--------|------|------------|
| 1 | Merge MR-A to `gitlab-configuration` | MR | — |
| 2 | Configure parser repo job token allowlist | Manual (settings) | — |
| 3 | Wait for Stratus to provision tokens + secrets | Wait | #1 |
| 4 | Store `PACKAGE_REPO_API_KEY` in project secret | Manual (⬜ process TBD) | #3 |
| 5 | Merge MR-B to `solutions-os` (all file migrations) | MR | #3 |
| 6 | Create pipeline schedule in GitLab UI | Manual | #5 |
| 7 | Trigger manual pipeline run and verify (Task 9) | Manual | #2, #4, #5, #6 |
| 8 | Merge MR-C to `solutions-atlas-mcp-server` | MR | #7 |
| 9 | Archive old repos (Task 10) | Manual | #7 |

---

## Task 9: Verify pipeline end-to-end

After Tasks 1-8 are complete:

1. **Verify tokens exist** — check that `STRATUS_MANAGED_ATLAS_PIPELINE_TRIGGER` appears in `solutions-os` → Settings → CI/CD → Variables
2. **Verify the schedule exists** — check `solutions-os` → Settings → CI/CD → Schedules for the `Atlas KB daily sync` schedule
3. **Verify secrets access** — confirm the pipeline can read `PACKAGE_REPO_API_KEY` from Secrets Manager and the write-repository token
4. **Trigger a manual run** — go to `solutions-os` → CI/CD → Pipelines → Run pipeline (source: `web`) to test the sync pipeline
5. **Verify direct push** — confirm the pipeline commits and pushes changes directly to `main` (check the commit history for a `chore: sync atlas-kb` commit by `gitlab-ci[bot]`)

---

## Task 10: Archive old repos

After all tasks above are verified working:

1. Add deprecation notice to each old repo's README pointing to `solutions-os`
2. Archive each repo: Settings → General → Advanced → Archive project

**Repos to archive:**
- `ramaswamy.u/solutions-atlas-kb`
- `ramaswamy.u/appian-atlas`
- `ramaswamy.u/power-appian-atlas-developer`
- `ramaswamy.u/power-appian-atlas-product-owner`
- `ramaswamy.u/power-appian-atlas-ux-designer`
- `ramaswamy.u/power-appian-reference`

---

## Target structure after migration

```
solutions-os/
├── .gitlab-ci.yml                          # includes sync pipeline
├── ai-framework/
│   ├── Engineering/
│   │   ├── .kiro/powers/
│   │   │   ├── atlas-developer/
│   │   │   │   ├── POWER.md
│   │   │   │   ├── README.md
│   │   │   │   ├── mcp.json
│   │   │   │   ├── .kiro/steering.md
│   │   │   │   └── steering/
│   │   │   └── appian-reference/
│   │   │       ├── POWER.md
│   │   │       ├── README.md
│   │   │       └── steering/
│   │   └── ...
│   ├── Product/
│   │   ├── .kiro/powers/
│   │   │   ├── atlas-product-owner/
│   │   │   │   ├── POWER.md
│   │   │   │   ├── README.md
│   │   │   │   ├── mcp.json
│   │   │   │   ├── .kiro/steering.md
│   │   │   │   └── steering/
│   │   │   └── atlas-ux-designer/
│   │   │       ├── POWER.md
│   │   │       ├── README.md
│   │   │       ├── mcp.json
│   │   │       ├── .kiro/steering.md
│   │   │       └── steering/
│   │   └── ...
│   └── tools/
│       └── Atlas/
│           ├── README.md                   # Atlas overview + install guide
│           └── solutions-kb/
│               ├── .gitlab-ci-sync.yml
│               ├── sync_packages.py
│               ├── releases.json
│               └── data/
│                   ├── AiDocumentCenter/
│                   ├── AwardManagement/
│                   ├── CaseManagementStudio/
│                   ├── ClauseAutomation/
│                   ├── ConnectedClaimsManagement/
│                   ├── ConnectedUnderwriting/
│                   ├── ContractWriting/
│                   ├── GamSuiteModule/
│                   ├── ProcureSightEnterprise/
│                   ├── RequirementsManagement/
│                   ├── SourceSelection/
│                   └── VendorManagement/
└── ...
```
