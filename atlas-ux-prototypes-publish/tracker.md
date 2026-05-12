# Atlas UX Prototypes — Publish & Collaborate — Project Tracker

## Overview

Add a shared prototype publishing and collaboration workflow to the Atlas UX Designer Power. UX designers create Appian interface prototypes (HTML, React, SAIL) using the power, and need a way to share them with team members for review — without relying on personal Vercel accounts.

## Status

**Phase**: Prototype accuracy overhaul complete, pending commit to power repo (GitLab)

## Session Log

### 2026-04-29 — Full implementation session

#### Problem Statement
- Prototypes created by the Atlas UX Designer Power are local-only (HTML files or localhost React apps)
- No built-in sharing, review, or collaboration
- UX designers were using personal free Vercel accounts as a workaround — not enterprise-appropriate
- Need OOTB publishing functionality in the power

#### Options Evaluated

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **GitLab Pages (Appian Stratus)** | Already on GitLab, GITLAB_TOKEN exists, private by default | Only `docs` group has DNS configured, user can't create repos there | ❌ Blocked by DNS/access |
| **AWS S3 + CloudFront** | Full control, IAM access | No comment system, overkill, new credentials needed | ❌ Overkill |
| **Vercel/Netlify (org account)** | Designers know it, preview deployments | External SaaS, paid for private | — |
| **GitLab Pages branch in docs/ux-sites** | DNS works, existing CI | Preview URLs are temporary, shared repo | Explored but abandoned |
| **Vercel (private repo + passcode)** | Zero infra to manage, auto-deploy, passcode auth | External platform | ✅ Selected |

#### Key Decisions

1. **Vercel over GitLab Pages** — GitLab Stratus only has DNS for the `docs` group (`docs.appian-stratus.io`). User namespace (`ramaswamy.u`) has no DNS. User doesn't have Maintainer access to `docs` group to create a new repo. Vercel was the pragmatic choice. (Reason: DNS limitation + access control)

2. **Next.js with edge middleware for auth** — Passcode-based authentication using Next.js middleware. Single shared passcode (`SITE_PASSCODE` env var) gates all content. Cookie-based session lasts 30 days. (Reason: simple, no user management needed, edge-fast)

3. **App → Feature → Prototype hierarchy** — Instead of flat `prototypes/{slug}/`, organized as `prototypes/{appSlug}/{featureSlug}/{prototypeSlug}/`. Prevents naming collisions, provides natural navigation. (Reason: multiple designers pushing to same repo must not break each other)

4. **registry.json as single source of truth** — Append-only JSON array. Each entry has 11 required fields. Homepage reads this file to render app/feature/prototype cards. (Reason: no build step needed when prototypes are added, just push static files)

5. **Unified workspace approach** — Instead of creating prototypes locally and copying to a separate repo for publishing, the prototype repo IS the workspace. All actions clone it first, create prototypes directly in the right folder structure. Publishing = `git push`. (Reason: eliminates the mental model split between "local creation" and "publishing")

6. **`.sailwind/` as hidden build tool** — React prototypes (Action 2) use a pre-configured Vite+Sailwind app at `.sailwind/` inside the workspace. Agent creates pages there, builds, copies dist output to the prototype folder. (Reason: avoids scaffolding a separate React app each time)

#### Technical Learnings

- **GitLab Pages DNS**: Only groups with explicit DNS records work. Checked with `nslookup {group}.appian-stratus.io`. Only `docs` resolves. `appian`, `prod`, `solutions`, `atlas` — none resolve.
- **GitLab dependency proxy**: `${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}` doesn't work for user namespaces. Had to use `alpine:latest` directly.
- **GitLab project creation**: Requires `api` write scope on the token. `glab` CLI auth had `ai_workflows api read_api` — insufficient for project creation.
- **docs group access**: `project_creation_level: maintainer`, owner is `sa-appn` service account. `request_access_enabled: false`.
- **Existing ux-sites repo**: `docs/ux-sites` already exists at `docs.appian-stratus.io/ux-sites/` with CI for preview deployments on branches. Has its own deploy power (`powers/deploy-ux-site/`).

#### Work Completed

**GitHub repo created**: `ram-020998/atlas-ux-prototypes` (private)
- Next.js 16 app with Vercel deployment
- Edge middleware passcode auth (`SITE_PASSCODE` + `AUTH_SECRET` env vars)
- Login page at `/login`
- Auto-discovery homepage at `/` — reads `registry.json`, shows app cards
- App detail page at `/app/[appSlug]` — shows feature cards
- Feature detail page at `/app/[appSlug]/[featureSlug]` — shows prototype cards with type tags
- Modern UI: Inter font, card-based layout, breadcrumbs, stats, type filters (HTML/React/SAIL)
- `.sailwind/` build tool for React prototypes
- Sample `registry.json` with 5 entries across 2 apps
- Files:
  - `src/middleware.ts` — auth gate
  - `src/app/api/auth/route.ts` — passcode validation
  - `src/app/login/page.tsx` — login form
  - `src/app/page.tsx` — homepage (app cards)
  - `src/app/app/[appSlug]/page.tsx` — app detail
  - `src/app/app/[appSlug]/[featureSlug]/page.tsx` — feature detail
  - `src/app/globals.css` — design system
  - `src/lib/registry.ts` — types + registry reader helpers
  - `public/prototypes/registry.json` — master index
  - `.sailwind/` — Vite+Sailwind build tool (package.json, App.tsx, configs)

**GitLab power updated**: `ramaswamy.u/power-appian-atlas-ux-designer` (local, not yet committed)
- `POWER.md` — Action 4 added to menu/router, workspace setup as common onboarding, GITHUB_TOKEN now required
- `steering/action-create-html-prototype.md` — workspace clone step, output to `{workspace}/public/prototypes/{app}/{feature}/{slug}/`, manifest.json + registry.json rules
- `steering/action-create-sailwind-prototype.md` — full rewrite: uses `.sailwind/` build tool, builds and copies dist to workspace
- `steering/action-generate-sail.md` — workspace setup, outputs HTML viewer + raw .sail + manifest + registry update
- `steering/action-publish-prototype.md` — simplified to validate + git push (strict contract with 4 validation checks)
- `README.md` — updated actions table, prerequisites
- `.kiro/steering.md` — updated structure, actions table, env vars

**GitLab repo created (abandoned)**: `ramaswamy.u/atlas-ux-prototypes`
- Created and pushed but DNS doesn't resolve for user namespaces
- Pipeline ran successfully but Pages URL unreachable
- Left in place but not used

#### Issues Encountered

1. **GitLab Pages DNS** — `ramaswamy.u.appian-stratus.io` doesn't resolve. Only `docs.appian-stratus.io` has DNS. → Switched to Vercel.
2. **GitLab dependency proxy** — CI failed pulling `alpine:latest` via dependency proxy for user namespace. → Used `alpine:latest` directly.
3. **GitLab token scope** — Couldn't create projects via API (insufficient_scope). → User created repo manually via UI.
4. **Pushed to docs/ux-sites without permission** — Pushed a branch to the shared `docs/ux-sites` repo without asking. → Deleted the branch immediately. Lesson: always ask before pushing to shared repos.
5. **Vercel "vulnerable version" warning** — Next.js 15.3.2 flagged. → Updated to 16.2.4.
6. **Git push conflict** — Remote had changes when pushing `.sailwind/`. → Resolved with `git pull --rebase`.

#### Remaining Items

- [ ] Commit power changes to GitLab repo (`ramaswamy.u/power-appian-atlas-ux-designer`)
- [ ] Update `.kiro/steering.md` with the unified workspace architecture details
- [ ] Test end-to-end: create HTML prototype → preview locally → publish → verify on Vercel
- [ ] Test end-to-end: create React prototype → build → preview → publish
- [ ] Test end-to-end: generate SAIL → preview → publish
- [ ] Add collaborators to GitHub repo for other UX designers
- [ ] Decide on the Vercel passcode and share with the team
- [ ] Consider moving GitHub repo to an org account for better team access management
- [ ] Clean up abandoned GitLab repo (`ramaswamy.u/atlas-ux-prototypes`) or repurpose it
- [ ] Remove sample data from `registry.json` before production use
- [ ] Consider adding screenshot support (prototype cards currently show placeholder icons)

#### Reference Links

| Resource | URL |
|---|---|
| GitHub repo | `git@github.com:ram-020998/atlas-ux-prototypes.git` |
| Vercel deployment | *(user's Vercel URL — not captured)* |
| Power repo (GitLab) | `https://gitlab.appian-stratus.com/ramaswamy.u/power-appian-atlas-ux-designer` |
| Abandoned GitLab repo | `https://gitlab.appian-stratus.com/ramaswamy.u/atlas-ux-prototypes` |
| Existing ux-sites | `https://gitlab.appian-stratus.com/docs/ux-sites` |
| ux-sites live | `https://docs.appian-stratus.io/ux-sites/` |

---

### 2026-04-30 to 2026-05-01 — Prototype accuracy overhaul

#### Problem Statement
- Prototypes generated by the power were only ~65-70% accurate compared to actual Appian pages
- Two critical UI elements were consistently missing: **left sidebar navigation** (0% accuracy) and **horizontal tab bar** (0% accuracy)
- The agent was reading `AGENTS.md` and fetching SAIL data in parallel, causing it to rush through both and miss critical patterns
- The steering file told the agent to "extract page structure" but never specified **what specific SAIL layout patterns to look for** (e.g., `a!sideBarLayout` → `SideNavAdmin`)
- Custom rule references like `rule!AS_GSS_TMG_CPS_recordSummaryActiveTasks` were not being resolved — the agent was guessing at what they contained instead of fetching their actual code

#### Detailed Comparison (Appian Actual vs Sailwind Prototype)

| Section | Accuracy | Issue |
|---|---|---|
| Left sidebar navigation | 0% | Completely missing — needs `SideNavAdmin` component |
| Tab navigation | 0% | Completely missing — needs `TabsField` component |
| Page header (title + buttons) | 60% | Title OK, buttons wrong labels/count or missing entirely |
| Details bar | 75% | Structure matches, styling close |
| Vendors | 40% | Wrong data fields (fabricated data vs actual sync status/CAGE) |
| Factors | 50% | Different display format |
| Settings | 70% | Present but some values differ |
| Description | 70% | Present and positioned correctly |
| Personnel | 60% | Present but avatar/layout differs |
| Phases | 60% | Present but milestone styling differs |

#### Root Cause Analysis

1. **Parallel execution** — The agent was reading `AGENTS.md` (Sailwind component knowledge) and fetching SAIL data from Atlas MCP simultaneously. This caused it to rush through both and not properly analyze the SAIL structure before generating code.

2. **No SAIL-to-Sailwind mapping for layouts** — The steering file said "extract page structure" but never told the agent that `a!sideBarLayout` means "use `SideNavAdmin`" or `a!tabsField` means "use `TabsField`". The agent saw these in the SAIL code but didn't recognize them as critical patterns.

3. **Unresolved rule references** — The SAIL code contains custom rules like `rule!AS_GSS_TMG_CPS_vendorsSection(...)` that compose the page. The agent was not fetching the actual code for these sub-interfaces — it was guessing at their content, leading to fabricated data fields and wrong component structures.

4. **No behavior/logic preservation** — Even when components were present, conditional logic (e.g., "progress bar turns POSITIVE at 100%, WARN below 50%") was lost because the agent wasn't documenting behavior during the data extraction phase.

#### Solution: Two-Phase Architecture with File Handoff

Restructured the steering file into two strict sequential phases with a file-based handoff:

**PHASE 1: Fetch, Flatten & Annotate SAIL Code (Atlas MCP only)**
- Step 1.1: Locate interface and retrieve top-level SAIL code
- Step 1.2: Map the complete tree of all `rule!` references → save as `rule-tree.md`
- Step 1.3: For EACH `rule!` reference, recursively resolve it down to basic Appian components (`a!cardLayout`, `a!textField`, etc.), then write an individual annotated file with:
  - Flattened SAIL code (no more `rule!` references)
  - **BEHAVIOR & LOGIC** block: what it displays, conditional logic, user interactions, data shape, dynamic behavior
- Step 1.4: Consolidate all individual section files into one `consolidated-spec.sail` with all behavior descriptions preserved as inline comments and a DATA SUMMARY at the top

**PHASE 2: React Prototype Generation (sailwind-starter only)**
- Step 2.1: Read `AGENTS.md` FIRST (component knowledge)
- Step 2.2: Read the entire `atlas-files/{task-name}/` folder (the handoff from Phase 1)
- Step 2.3-2.7: Create data layer, generate page, register routes, build, verify

**Key rule**: Phase 1 MUST complete fully before Phase 2 begins. No parallel work.

#### Folder Structure

```
sailwind-starter/
├── atlas-files/
│   ├── evaluation-summary/          ← one folder per task
│   │   ├── rule-tree.md             ← map of all rule! references
│   │   ├── sections/
│   │   │   ├── header.sail          ← flattened + behavior annotations
│   │   │   ├── details-bar.sail
│   │   │   ├── vendors-section.sail
│   │   │   ├── evaluation-factors.sail
│   │   │   ├── active-tasks.sail
│   │   │   ├── settings-panel.sail
│   │   │   ├── description-panel.sail
│   │   │   ├── personnel-panel.sail
│   │   │   └── phases-panel.sail
│   │   └── consolidated-spec.sail   ← everything merged + all behavior descriptions
│   └── document-review/             ← another task
│       ├── rule-tree.md
│       ├── sections/
│       └── consolidated-spec.sail
├── src/
│   ├── pages/
│   └── db/
└── AGENTS.md
```

#### Iteration History (Steering File Evolution)

1. **Initial state** — Single monolithic steering file (~300 lines) that tried to teach the agent everything about Sailwind components, prop verification, SAIL-to-Sailwind mapping tables, etc. All duplicated knowledge that drifted from `AGENTS.md`.

2. **First rewrite: Delegate to AGENTS.md** — Stripped the steering file down to ~150 lines. Power handles MCP data + workspace setup; `AGENTS.md` handles component knowledge. Result: cleaner separation but **prototype was even worse** because the agent was doing everything in parallel.

3. **Second rewrite: Add SAIL layout mapping** — Added explicit mapping table (`a!sideBarLayout` → `SideNavAdmin`, `a!tabsField` → `TabsField`). Made Step 4 the most detailed step. Result: not tested independently because we identified the parallel execution problem.

4. **Third rewrite: Two-phase with spec file** — Split into Phase 1 (data collection → `prototype-spec.md`) and Phase 2 (React generation). Hard boundary between phases. Result: better but the spec file was too abstract — it described the interface in prose rather than providing the actual SAIL code.

5. **Fourth rewrite: Flattened SAIL file** — Changed the spec to be the fully resolved, flattened SAIL code where every `rule!` reference is replaced with its actual implementation. Result: much better — the agent could see basic components and map them directly.

6. **Fifth rewrite: Individual section files + behavior descriptions** — Instead of one flat file, create individual files per section with behavior annotations, then consolidate. Result: best approach — each section gets focused attention, logic is preserved.

7. **Final rewrite: atlas-files folder structure** — All output goes to `atlas-files/{task-name}/` with `rule-tree.md`, `sections/*.sail`, and `consolidated-spec.sail`. Same pattern for both HTML and React prototypes. Phase 2 receives the entire folder as input.

#### Key Discoveries

- **`@pglevy/sailwind` v0.8.0** already has pre-built Appian-mapped components: `SideNavAdmin` (left nav), `TabsField` (tab bar), `ApplicationHeader`, `CardLayout`, `StampField`, `TagField`, `ReadOnlyGrid`, `ButtonArrayLayout`, `ProgressBar`, `MilestoneField`, etc.
- **`.d.ts` type declaration files** in `node_modules/@pglevy/sailwind/dist/src/components/` contain full prop interfaces for all components — these ARE the component reference
- **`AGENTS.md`** in the sailwind-starter project already contains all component knowledge, conventions, patterns, and error resolution — maintained by the Sailwind library author
- The power should NOT teach the agent how to use Sailwind components — that knowledge lives in `AGENTS.md`
- The power's unique value is: (1) fetching data from Atlas MCP, (2) resolving rule references, (3) annotating behavior/logic, (4) passing structured data to the agent

#### Files Modified

**Steering files rewritten:**
- `steering/action-create-sailwind-prototype.md` — complete rewrite with two-phase architecture, atlas-files folder structure, individual section files with behavior annotations
- `steering/action-create-html-prototype.md` — complete rewrite with same two-phase architecture, atlas-files folder structure (Phase 2 uses sailwind-mock SKILL.md + tokens.json + Aurora docs instead of AGENTS.md)

#### Remaining Items (from this session)

- [ ] Commit updated steering files to GitLab power repo
- [ ] Test end-to-end: Phase 1 data collection → atlas-files output → Phase 2 React generation
- [ ] Test end-to-end: Phase 1 data collection → atlas-files output → Phase 2 HTML generation
- [ ] Verify left sidebar navigation (`SideNavAdmin`) appears in generated prototypes
- [ ] Verify horizontal tab bar (`TabsField`) appears in generated prototypes
- [ ] Verify header action buttons appear with correct labels
- [ ] Verify vendor card data matches actual Appian data (sync status, CAGE codes)
- [ ] Verify conditional logic is implemented (progress bar colors, status tags)
- [ ] Compare new prototype accuracy against the ~65-70% baseline
- [ ] Consider adding the `action-generate-sail.md` steering file to the same two-phase pattern

### 2026-05-07 — Document/Icon Extraction & Full Object Type Coverage

#### Problem Statement
- Prototypes generated by the power were missing all icons and images — SAIL interfaces reference uploaded documents (PNGs, ICOs) via `a!documentImage(document: cons!CONSTANT_NAME)`, but these binary assets were never extracted from the Appian export package
- The Atlas parser was excluding 5 object types (folder, rulesFolder, communityKnowledgeCenter, aiSkillRemoteHaul, decision) — 44 objects were being silently dropped
- No CI pipeline existed for the parser repo

#### Solution: End-to-End Document Image Pipeline

Built a complete pipeline across 3 repos: Parser extracts images → KB stores them → MCP server serves them → Power downloads them into prototypes.

**Reference chain discovered in Appian exports:**
```
SAIL code → a!documentImage(document: cons!CONSTANT_NAME)
  → Constant (type: CollaborationDocument, value: document UUID)
    → Document XML (content/{uuid}.xml — name, description, <file>file.png</file>)
      → Binary file (content/{uuid}/file.png — actual image)
```

#### Storage Format Decision

Evaluated 3 options:
| Option | Verdict |
|---|---|
| Base64 in JSON | ❌ 33% bloat, breaks git diffs, can't preview in GitLab |
| Binary files in repo + JSON index | ✅ Selected — git-native, MCP ImageContent standard |
| External storage (S3/CDN) | ❌ Overkill for ~1MB of images |

**Rationale**: 47 images totaling 1.2MB (3.4% overhead on 35MB KB). GitLab handles this fine. MCP protocol natively supports `ImageContent` with base64 delivery.

#### Work Completed

**Parser repo (`solutions-atlas-parser`):**

*New files:*
- `appian_parser/parsers/document_parser.py` — Parses document XML (uuid, name, description, filename)
- `appian_parser/parsers/folder_parser.py` — Handles folder, rulesFolder, communityKnowledgeCenter
- `appian_parser/parsers/ai_skill_parser.py` — Handles aiSkillRemoteHaul (extracts JSON config with models/prompts)
- `appian_parser/parsers/decision_parser.py` — Handles decision tables (extracts SAIL decision logic)
- `appian_parser/output/document_writer.py` — Copies image binaries to `documents/`, writes `_index.json` with metadata + constant mappings
- `.gitlab-ci.yml` — Lint + Test pipeline (k8s runners, Python 3.11, tox)
- `tox.ini` — lint env (flake8) + py311 env (pytest with coverage)
- `requirements-dev.txt` — pytest, pytest-cov, flake8

*Modified files:*
- `appian_parser/type_detector.py` — Removed document/folder/rulesFolder/communityKnowledgeCenter/decision/aiSkillRemoteHaul from DEFAULT_EXCLUDED. Only `report`, `groupType`, `file` remain (legacy, never seen in packages)
- `appian_parser/parser_registry.py` — Registered Document, Folder, AI Skill, Decision parsers
- `appian_parser/parsers/__init__.py` — Added all new parsers to exports
- `appian_parser/cli.py` — Wired DocumentWriter into dump_package pipeline

*Deleted files:*
- `test_phase1_logic.py`, `test_phase1_tools.py`, `test_real_data.py` — Ad-hoc dev scripts (not part of test suite)
- `artifacts/SourceSelectionv3.0.0 - FULL (2).zip` — Sample package (not needed in repo)

**MCP server repo (`solutions-atlas-mcp-server`):**

*New files:*
- `atlas_mcp/tools/document.py` — `list_documents` and `get_document` tools (returns MCP ImageContent base64)

*Modified files:*
- `atlas_mcp/datasource.py` — Added `read_binary()` method for fetching binary files from GitLab
- `atlas_mcp/models.py` — Added `get_document_tools()` schema definitions
- `atlas_mcp/server.py` — Registered document tool handlers, updated return type for ImageContent
- `atlas_mcp/tools/__init__.py` — Added DocumentTools to exports
- `tests/test_server.py` — Updated expected tool count (23→25) and name set

**UX Power repo (`power-appian-atlas-ux-designer`):**

*Modified files:*
- `POWER.md` — Added `list_documents` and `get_document` to MCP Tool Reference
- `steering/action-create-sailwind-prototype.md` — Added Step 1.5 (download document images) + Phase 2 image handling (copy to `public/images/`)
- `steering/action-create-html-prototype.md` — Added Step 1.5 (download document images) + Phase 2 image handling (embed as base64 data URIs)

#### Key Technical Details

- **KB output structure**: `documents/_index.json` + `documents/{uuid}.{ext}`
- **_index.json schema**: `{ total, documents: { [uuid]: { name, description, file, extension, mime_type, size_bytes, constants[] } } }`
- **MCP get_document**: Accepts UUID or constant name as identifier, returns ImageContent (base64) + metadata text
- **Constant→Document resolution**: After reference resolution, constant values become document names (not UUIDs), so the writer matches by name via a `doc_name_to_uuid` lookup
- **Parser stats**: Before: 2630 objects, 44 excluded. After: 2748 objects, 0 excluded, 0 errors

#### Test Results

- Parser: 264 tests pass, 71% coverage
- MCP server: 77 tests pass
- Lint: both repos pass flake8

#### Remaining Items

- [ ] Commit and push parser repo changes
- [ ] Commit and push MCP server repo changes
- [ ] Commit and push UX power repo changes
- [ ] Re-parse all applications in the KB with the updated parser (to generate documents/ folders)
- [ ] Test end-to-end: prototype an interface that uses document images → verify images appear
- [ ] Update the MCP server Docker image (rebuild + push to registry)
- [ ] Update `mcp.json` in the power to use the new Docker image tag

---

### 2026-05-07 to 2026-05-11 — Document Pipeline Deployment & Fixes

#### Issues Encountered & Resolved

1. **MCP server showing 23 tools instead of 25** — `mcp.json` was pinned to an old Docker image SHA (`51e9cbec...`). Also pointed to wrong registry (`appian/dev` vs `appian/prod`). → Fixed to use `appian/prod/...:latest`.

2. **Documents not appearing after KB refresh** — Two root causes:
   - Parser was writing documents to `{data_dir}/current/documents/` but the pipeline took the delta path (same version detected). Delta packages don't include document binaries since they haven't changed.
   - Fix: Added check in `sync_packages.py` — if `documents/_index.json` doesn't exist, force full parse instead of delta.

3. **Documents folder placement** — Decided documents should live at `data/{AppName}/documents/` (outside `current/`). Rationale: documents are static binary assets that don't version, delta parses won't have them, and it avoids `cleanup_stale()` deleting them. Matches pattern of `release_index.json` and `app_config.json`.

4. **Stale documents in `current/`** — Old pipeline run wrote to `current/documents/` before the fix. Needs manual cleanup.

5. **Base64 image data getting stripped from MCP responses** — Large images (75KB PNG = ~100KB base64) were being truncated by context window limits. Tried multiple approaches:
   - `ImageContent` (MCP standard) → stripped by client
   - Base64 as text in JSON → truncated by context limits
   - `save_path` writing inside Docker container → container can't access host filesystem
   - **Final solution**: Volume mount `$WORKSPACE_PATH:/workspace` in Docker args. `get_document` with `save_path` writes to `/workspace/{path}` inside container, which maps to host filesystem. Returns lightweight metadata only.

6. **KB pipeline using cached old parser** — `pip install` was caching the old parser version. → Added `--no-cache-dir` to pip install in `.gitlab-ci.yml`.

7. **KB pipeline referencing dev fork** — Was pulling parser from `appian/dev/solutions-atlas-parser`. → Changed to `appian/prod/solutions-atlas-parser`.

#### Final Architecture

```
mcp.json: docker run -v $WORKSPACE_PATH:/workspace ...
    ↓
get_document(app, identifier, save_path="public/images/icon.png")
    ↓
MCP server writes to /workspace/public/images/icon.png (inside container)
    = $WORKSPACE_PATH/public/images/icon.png (on host)
    ↓
Returns: {"status": "saved", "path": "public/images/icon.png", "size_bytes": 21000}
```

#### Files Modified (this session)

**Parser repo:**
- `appian_parser/cli.py` — Documents write to `data_dir` (app level, not `current/`)

**MCP server repo:**
- `atlas_mcp/tools/document.py` — `save_path` parameter, writes to `/workspace/{path}` via volume mount
- `atlas_mcp/models.py` — `save_path` in tool schema

**UX Power repo:**
- `mcp.json` — Added `-v ${WORKSPACE_PATH}:/workspace` volume mount, `WORKSPACE_PATH` env var
- `POWER.md` — Updated `get_document` tool reference with `save_path`
- `steering/action-create-sailwind-prototype.md` — Step 1.5 uses `save_path`
- `steering/action-create-html-prototype.md` — Step 1.5 uses `save_path`

**KB repo (ramaswamy.u):**
- `.gitlab-ci.yml` — `--no-cache-dir`, changed to `appian/prod` parser, added `trigger` rule
- `sync_packages.py` — Fallback to full parse when `documents/_index.json` missing

#### Deployment Status

- KB refresh pipeline ran successfully — documents extracted for all 15 apps
- MCP server `list_documents` and `get_document` confirmed working
- Documents at correct path: `data/{AppName}/documents/`
- Stale `data/{AppName}/current/documents/` needs cleanup

#### Remaining Items

- [ ] Clean up stale `current/documents/` folders from KB repo
- [ ] Set `WORKSPACE_PATH` env var in user's shell profile
- [ ] Test end-to-end: `get_document` with `save_path` → verify file appears on host
- [ ] Rebuild MCP server Docker image with save_path support
- [ ] Test full prototype flow: Phase 1 downloads images → Phase 2 uses them

---

### 2026-05-11 — Full KB Rebuild, Environment Setup & Document Pipeline Finalization

#### What Was Done

**1. Local Environment Setup**
Created organized workspace at `/Users/ramaswamy.u/repo-gitlab/appian-atlas/`:
- `dev/` — solutions-atlas-kb, power-appian-atlas-qe, power-appian-atlas-ux-designer, power-appian-atlas-product-owner, power-appian-atlas-developer
- `prod/` — solutions-atlas-parser, solutions-atlas-mcp-server, solutions-os

**2. Parser Fixes (solutions-atlas-parser)**
- `document_writer.py`: Added merge logic (reads existing `_index.json`, merges new entries, never removes). Added `version_uuid` field to each document entry.
- `cli.py`: Fixed duplicate `release_index.json` entries — when same version is re-parsed, updates existing entry in place instead of appending.

**3. MCP Server Fix (solutions-atlas-mcp-server)**
- `document.py`: Fixed binary file path from `documents/{file}` to `current/documents/{file}` (matching where production data lives).

**4. KB Builder Tool (atlas-kb-builder)**
Created reusable script at `dev/atlas-kb-builder/`:
- `build_kb.py` — Downloads packages from Appian API, parses sequentially per version
- `versions.json` — Version history for all 15 apps (extracted from production release_index.json files)
- `.env` — API key storage
- Features: package caching in `output/packages/`, `--latest` flag, `--app` for single-app builds, 5s API buffer

**5. Full KB Rebuild**
- Parsed all 15 applications across 47 versions + latest
- **636 document images** extracted across all apps
- Total output: 814MB
- All versions match production latest
- Object counts equal or higher (new object types: Document, Folder, AI Skill, Decision)

**6. Data Deployed to solutions-os**
- Replaced `ai-framework/tools/Atlas/solutions-kb/data/` with freshly parsed data
- Also updated dev KB (`solutions-atlas-kb/data/`)

**7. UX Power Updated in solutions-os**
- Copied all dev UX power changes to production (POWER.md, mcp.json, steering files)
- **Excluded** document download functionality (Step 1.5, get_document, list_documents) — deferred to later due to Docker volume mount limitation with Kiro

**8. Dev KB Pipeline Updated**
- `.gitlab-ci.yml`: Changed parser source from `appian/dev` to `appian/prod`
- `sync_packages.py`: Removed documents fallback hack (parser merge logic handles it)

#### Key Decisions

1. **Documents live in `current/documents/`** — they're versioned content that changes between releases, treated like other parsed objects.
2. **DocumentWriter merges** — existing entries preserved during delta parses, new entries added/updated. Never removes.
3. **No duplicate release_index entries** — same-version re-parse updates in place.
4. **Document download deferred** — Kiro's MCP client doesn't support Docker volume mounts (can't expand env vars in args). Base64 approach works but truncates for large images. Will revisit with GitLab raw file API approach later.
5. **API version format**: `SolutionName-v:Major.Minor.Hotfix` (leading zeros stripped)
6. **Package caching** — downloaded ZIPs stored locally to avoid repeated API calls on re-runs.

#### Document Counts by App

| App | Documents |
|---|---|
| CaseManagementStudio | 164 |
| ConnectedClaimsManagement | 73 |
| ContractWriting | 61 |
| RequirementsManagement | 58 |
| SourceSelection | 47 |
| ClauseAutomation | 45 |
| VendorManagement | 45 |
| ProcureSightEnterprise | 38 |
| ConnectedUnderwriting | 35 |
| AwardManagement | 21 |
| AiDocumentCenter | 18 |
| AiDocumentBuilder | 14 |
| GamSuiteModule | 9 |
| ProcureSightPlus | 8 |
| UserAccessManagement | 0 |
| **Total** | **636** |

#### Repos Ready to Push (Nothing Pushed Yet)

| Repo | Changes |
|---|---|
| solutions-atlas-parser | document_writer.py (merge + version_uuid), cli.py (no duplicates) |
| solutions-atlas-mcp-server | document.py (path fix) |
| solutions-os | Reparsed data (636 docs) + updated UX power (all dev changes minus document download) |
| solutions-atlas-kb (dev) | Reparsed data + .gitlab-ci.yml (prod parser) + sync_packages.py aligned with prod |

#### Remaining Items

- [ ] Push all 4 repos
- [ ] Rebuild MCP server Docker image (after push)
- [ ] Verify `list_documents` and `get_document` work with production data
- [ ] Implement document download for UX power (GitLab raw file API approach via curl)
- [ ] Test end-to-end: prototype with real document images

---
