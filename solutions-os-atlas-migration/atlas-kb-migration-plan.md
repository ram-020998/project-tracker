# Atlas Migration Plan

Consolidate Atlas repos from personal namespaces into `solutions-os`, the shared production repository.

## Repos to Migrate

| Repo | Current location | Target in solutions-os |
|------|-----------------|----------------------|
| solutions-atlas-kb | `ramaswamy.u/solutions-atlas-kb` | `atlas-kb/` |
| appian-atlas (docs) | `ramaswamy.u/appian-atlas` | `atlas-kb/docs/` + root README |
| power-appian-atlas-developer | `ramaswamy.u/power-appian-atlas-developer` | `ai-framework/Engineering/.kiro/powers/power-appian-atlas-developer/` |
| power-appian-reference | `ramaswamy.u/power-appian-reference` | `ai-framework/Engineering/.kiro/powers/power-appian-reference/` |
| power-appian-atlas-product-owner | `ramaswamy.u/power-appian-atlas-product-owner` | `ai-framework/product/.kiro/powers/power-appian-atlas-product-owner/` |
| power-appian-atlas-ux-designer | `ramaswamy.u/power-appian-atlas-ux-designer` | `ai-framework/product/.kiro/powers/power-appian-atlas-ux-designer/` |

## Repos staying separate

| Repo | Location | Reason |
|------|----------|--------|
| solutions-atlas-parser | `appian/dev/solutions-atlas-parser` | Pip-installable library consumed by the sync pipeline. Already properly housed in `appian/dev`. |
| solutions-atlas-mcp-server | `appian/prod/solutions-atlas-mcp-server` | Already in org namespace under `appian/prod`. Stays as a standalone service. |

## Target Structure

```
solutions-os/
├── ai-framework/
│   ├── Engineering/.kiro/powers/
│   │   ├── power-appian-atlas-developer/
│   │   └── power-appian-reference/
│   └── product/.kiro/powers/
│       ├── power-appian-atlas-product-owner/
│       └── power-appian-atlas-ux-designer/
├── atlas-kb/
│   ├── .gitlab-ci-sync.yml
│   ├── sync_packages.py
│   ├── docs/
│   │   ├── MIGRATION_GUIDE_V3.md
│   │   └── ...
│   ├── README.md
│   └── data/
│       ├── AppA/
│       ├── AppB/
│       └── ...
└── ...
```

---

## 1. solutions-atlas-kb

### What moves
- `data/` directory (all 12 apps with release history)
- `sync_packages.py`

### Target path
`solutions-os/atlas-kb/`

### Pipeline changes

The sync pipeline moves from `solutions-atlas-kb/.gitlab-ci.yml` to `solutions-os/atlas-kb/.gitlab-ci-sync.yml`. The root CI includes it:

**`solutions-os/.gitlab-ci.yml`** — add:

```yaml
include:
  - local: atlas-kb/.gitlab-ci-sync.yml
```

**`solutions-os/atlas-kb/.gitlab-ci-sync.yml`:**

```yaml
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
    - apt-get update && apt-get install -y --no-install-recommends git
  script:
    - pip install "git+https://oauth2:${GITLAB_PUSH_TOKEN}@gitlab.appian-stratus.com/appian/dev/solutions-atlas-parser.git@main" requests
    - |
      if [ -n "$APP_NAME" ]; then
        echo "Syncing single app: $APP_NAME"
        python atlas-kb/sync_packages.py --api-key "${APPIAN_API_KEY}" --app "$APP_NAME"
      else
        echo "Syncing all apps (parallel)"
        python atlas-kb/sync_packages.py --api-key "${APPIAN_API_KEY}" --parallel
      fi
    - git config user.name "gitlab-ci[bot]"
    - git config user.email "gitlab-ci[bot]@gitlab.appian-stratus.com"
    - git add atlas-kb/data/ -f
    - git reset HEAD -- 'atlas-kb/**/parsed_state.json'
    - |
      if git diff --cached --quiet; then
        echo "No changes to commit"
      else
        APPS_CHANGED=$(git diff --cached --name-only | grep -oP 'atlas-kb/data/\K[^/]+' | sort -u | tr '\n' ', ' | sed 's/,$//')
        BRANCH="atlas-kb/sync-$(date -u +%Y%m%d-%H%M%S)"
        git checkout -b "$BRANCH"
        git commit -m "chore: sync atlas-kb ${APPS_CHANGED} $(date -u +%Y-%m-%d)"
        git push "https://oauth2:${GITLAB_PUSH_TOKEN}@gitlab.appian-stratus.com/appian/prod/solutions-os.git" "$BRANCH"
        pip install python-gitlab
        python -c "
import gitlab, os
gl = gitlab.Gitlab('https://gitlab.appian-stratus.com', private_token=os.environ['GITLAB_PUSH_TOKEN'])
project = gl.projects.get(os.environ['CI_PROJECT_ID'])
mr = project.mergerequests.create({
    'source_branch': '$BRANCH',
    'target_branch': 'main',
    'title': 'chore: sync atlas-kb ${APPS_CHANGED}',
    'remove_source_branch': True,
    'squash': True,
})
print(f'MR created: {mr.web_url}')
        "
      fi
  cache:
    key: atlas-kb-parsed-state
    paths:
      - atlas-kb/data/*/current/parsed_state.json
```

### Other changes triggered
- `GITLAB_PUSH_TOKEN` needs write access to `solutions-os`
- CI schedule needs to be recreated in `solutions-os`
- `solutions-atlas-mcp-server` needs its data source updated from `solutions-atlas-kb` repo to `solutions-os/atlas-kb/` (config change in the MCP server repo)

---

## 2. appian-atlas (docs)

### What moves
- `README.md` (project overview, install guide, example queries, troubleshooting)
- `docs/` directory (migration guide, any other docs)

### Target path
- `solutions-os/atlas-kb/README.md`
- `solutions-os/atlas-kb/docs/`

### What changes
- All repo URLs in the README update to point to `solutions-os` subdirectories instead of standalone repos
- Install instructions change: users clone `solutions-os` and point Kiro at the appropriate powers subfolder instead of cloning individual power repos
- The Repositories table simplifies — most entries become paths within `solutions-os`

### Updated Repositories table

| Component | Location |
|-----------|----------|
| Project overview and docs | `solutions-os/atlas-kb/` |
| Appian application parser | `appian/dev/solutions-atlas-parser` (separate repo) |
| Knowledge base data | `solutions-os/atlas-kb/data/` |
| MCP server | `appian/prod/solutions-atlas-mcp-server` (separate repo) |
| Developer power | `solutions-os/ai-framework/Engineering/.kiro/powers/power-appian-atlas-developer/` |
| Product Owner power | `solutions-os/ai-framework/product/.kiro/powers/power-appian-atlas-product-owner/` |
| UX Designer power | `solutions-os/ai-framework/product/.kiro/powers/power-appian-atlas-ux-designer/` |
| SAIL reference power | `solutions-os/ai-framework/Engineering/.kiro/powers/power-appian-reference/` |

---

## 3. power-appian-atlas-developer

### What moves
- Entire power contents (MCP config, prompts, skill definitions)

### Target path
`solutions-os/ai-framework/Engineering/.kiro/powers/power-appian-atlas-developer/`

### What changes
- Install instructions: users point Kiro at the subfolder within their `solutions-os` clone instead of cloning a standalone repo
- Any hardcoded references to the KB repo need updating to `solutions-os/atlas-kb/`
- Updates via `git pull` on `solutions-os` instead of per-power pulls

---

## 4. power-appian-reference

### What moves
- Entire power contents (SAIL reference data, MCP config)

### Target path
`solutions-os/ai-framework/Engineering/.kiro/powers/power-appian-reference/`

### What changes
- Same install flow change as the developer power
- Any references to other Atlas repos update to `solutions-os` paths

---

## 5. power-appian-atlas-product-owner

### What moves
- Entire power contents

### Target path
`solutions-os/ai-framework/product/.kiro/powers/power-appian-atlas-product-owner/`

### What changes
- Same install flow change
- Any references to other Atlas repos update to `solutions-os` paths

---

## 6. power-appian-atlas-ux-designer

### What moves
- Entire power contents

### Target path
`solutions-os/ai-framework/product/.kiro/powers/power-appian-atlas-ux-designer/`

### What changes
- Same install flow change
- Any references to other Atlas repos update to `solutions-os` paths

---

## 7. Archive Old Repos

After migration is verified:

1. Add a deprecation notice to each old repo's README pointing to the new location in `solutions-os`
2. Archive each repo in GitLab (Settings → General → Advanced → Archive project)

Repos to archive:
- `ramaswamy.u/solutions-atlas-kb`
- `ramaswamy.u/appian-atlas`
- `ramaswamy.u/power-appian-atlas-developer`
- `ramaswamy.u/power-appian-atlas-product-owner`
- `ramaswamy.u/power-appian-atlas-ux-designer`
- `ramaswamy.u/power-appian-reference`

---

## Auto-Merge Options for Sync Pipeline

The sync pipeline creates MRs instead of pushing directly to `main`. Options to reduce manual approval overhead:

### Option A: Path-scoped approval rule (requires Maintainer access)

Zero approvals for changes under `atlas-kb/`. Cleanest solution.

1. Go to `solutions-os` → Settings → Merge Requests → Approval Rules
2. Add rule:
   - Name: `Atlas KB Sync (auto)`
   - Approvals required: `0`
   - File path pattern: `atlas-kb/**`
3. Add `merge_when_pipeline_succeeds: True` to the MR creation in the pipeline

### Option B: CODEOWNERS (requires Maintainer to enable)

Assign the bot as code owner of `atlas-kb/`.

**`solutions-os/CODEOWNERS`:**

```
/atlas-kb/ @<bot-username>
```

Requires a Maintainer to enable "Require approval from code owners" and "Allow author to approve" in Settings.

### Option C: Manual approval (no Settings access needed)

The pipeline creates the MR and someone with Maintainer access approves it. Add a notification to reduce lag:

```python
import requests as req
req.post(CHAT_WEBHOOK_URL, json={
    "text": f"Atlas KB sync MR ready for approval: {mr.web_url}"
})
```

### Recommendation

Option A if a Maintainer can add the rule. Option C as a no-dependency fallback.
