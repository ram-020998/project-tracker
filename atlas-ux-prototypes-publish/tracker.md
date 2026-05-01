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
