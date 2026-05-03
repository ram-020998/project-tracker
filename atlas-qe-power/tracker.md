# Atlas QE Power — Project Tracker

## Overview
Building a Kiro Power for QE Engineers that generates executable Playwright test scripts for Appian applications. Uses Atlas MCP for application knowledge (SAIL code, interfaces, dependencies) and Playwright MCP for live site verification. Part of the Atlas ecosystem (Developer, Product Owner, UX Designer powers already exist).

## Status
Active development — Power is functional, action library converted, steering documents comprehensive. Currently debugging action reliability against live site.

## Session Log

### 2026-05-01 — Initial Research, Architecture, Power Creation, Action Library, and Testing

#### Completed
- Read complete Owl documentation (https://docs.appian-stratus.io/owl/)
- Analyzed Owl's component locator patterns from `owl-appian-element` source code (owl-pages repo)
- Analyzed Appian's `sail-client` source code to understand how components render HTML/ARIA attributes
- Validated Playwright accessibility-based locators against live Appian site (https://eng-test-fed-aq-dev2.appianpreview.com)
- Created the QE Power repo at `~/repo-gitlab/ramaswamy.u/power-appian-atlas-qe/`
- Created comprehensive steering documents:
  - `POWER.md` (126 lines) — Minimal router with environment checks at session start
  - `appian-component-map.md` (~580 lines) — Complete SAIL→Accessibility→Playwright mapping for all Appian components
  - `action-test-script-generation.md` (~700 lines) — 6-phase strict workflow with 8 rules
  - `tool-reference.md` (68 lines) — Atlas MCP tools for QE
  - `.kiro/steering.md` (~110 lines) — Architecture decisions and patterns
- Set up Playwright test repo at `/Users/ramaswamy.u/Documents/gss-tests/playwright-tests/`
  - `playwright.config.ts`, `package.json`, `.env`, `.gitignore`, `README.md`
  - Installed `@playwright/test`, `dotenv`, `typescript`, `@types/node`
- Converted ALL Owl page objects to Playwright action files (23 files, ~2,100 lines):
  - `auth/login.ts`
  - `common/common-page.ts`, `wait-for-appian.ts`, `solutions-hub.ts`
  - `evaluation/create-evaluation.ts`, `evaluation-summary.ts`, `update-evaluation.ts`, `delete-evaluation.ts`, `eval-history.ts`, `lpta-task-form.ts`
  - `vendor/add-vendor.ts`, `vendor-site.ts`, `vendor-analysis.ts`, `vendors-tab.ts`
  - `factor/continue-setup.ts`, `factors-tab.ts`
  - `consensus/consensus-reports.ts`
  - `document/documents-tab.ts`
  - `task/add-custom-task.ts`, `tasks-tab.ts`
  - `award/create-awards.ts`, `select-awardees.ts`
  - `navigation/evaluation-site.ts`, `my-workspace-site.ts`
- Created `action-registry.json` (551 lines) — Structured registry with categories, composites, preconditions/postconditions, and chain validation rules
- Ran initial test suite (10 tests for Create Evaluation) — all 10 passed
- Ran smoke tests on action library — 6/7 passed
- All action files compile cleanly (zero TypeScript errors)

#### Decisions Made
- **Playwright over Owl** (reason: Appian renders rich accessibility attributes — `getByRole`/`getByLabel` work natively without custom adapters. Validated on live site. Playwright is AI-friendly with massive training data.)
- **Option B: AI writes scripts, execution is deterministic** (reason: scripts run in CI without AI tokens. AI cost is one-time generation, not per-execution.)
- **Actions library pattern over Playwright fixtures** (reason: explicit, easier for AI to generate, easier for QE to review)
- **`waitForAppian()` over `networkidle`** (reason: Appian's progress bar `appianNProgress---nprogress_custom_parent` is the reliable signal. `networkidle` is unreliable with SAIL.)
- **`selectDropdownOption()` helper** (reason: Appian dropdowns are custom `<div role="combobox">`, NOT native `<select>`. `.selectOption()` throws errors.)
- **Never use `getByText()` for interactive elements** (reason: Appian renders duplicate spans for buttons and nav links. Always use `getByRole('button'|'link', { name })`)
- **6-phase workflow with user checkpoints** (reason: prevents hallucinated tests, ensures QE reviews before promotion)
- **Action registry JSON** (reason: agent needs precondition/postcondition chain to avoid missing intermediate steps like closing confirmation dialogs)
- **Research folder isolation** (reason: draft tests never touch the main suite until explicitly promoted)

#### Learnings
- Appian components render proper ARIA roles: `textbox`, `button`, `combobox`, `table`, `checkbox`, `region`, `heading`, `link`, `radio`, `progressbar`, `dialog`
- Appian's `<label htmlFor={_cId}>` connects labels to inputs — Playwright's `getByRole('textbox', { name: 'label' })` works
- `data-owl-test-label` and `data-owl-icon-name` attributes are in the DOM (from sail-client source)
- Radio buttons: `<label>` intercepts clicks on `<input>` — must use `{ force: true }` with `.check()`
- Radio options with shared text ("Required"/"Not Required") — must use `getByLabel('Required', { exact: true })`
- After form submission, Appian shows confirmation — must call `close()` then navigate to the record
- Owl's `create_with_only_mandatory_values` fills form but does NOT submit — `create_btn_click` is separate
- The `waitForAppian` utility watches for `appianNProgress---nprogress_custom_parent` class to disappear

#### Issues Encountered
- `getByText('Create new evaluation')` matched 2 elements (visible span + hidden accessibility span) → Fix: use `getByRole('button', { name: /Create new evaluation/ })`
- `.selectOption('D - Requirements')` threw "Element is not a `<select>` element" → Fix: created `selectDropdownOption()` helper that clicks combobox then clicks option
- `getByText('Evaluations')` matched nav link AND page content → Fix: use `getByRole('link', { name: 'Evaluations' })`
- After `clickCreateButton`, test tried `addVendorClick` but page was on confirmation, not summary → Root cause: missing `close()` + navigation steps between create and add vendor
- Agent generated placeholder comments without implementation code → Fix: added Rule 8 forbidding placeholders
- Actions converted from Owl used `waitForLoadState('networkidle')` which is unreliable → Fix: bulk-replaced with `waitForAppian(page)` across all 19 action files
- Action library needs live verification — some locators from Owl conversion use CSS class selectors marked with `// TODO: needs live verification`

#### Remaining Items
- [ ] Verify all action files against live site (many have `// TODO: needs live verification` comments)
- [ ] Fix the full evaluation creation flow (create → close confirmation → navigate → open record)
- [ ] Convert `evaluation_summary.py` contract_writing subfolder
- [ ] Test the complete 6-phase workflow with a real Jira ticket end-to-end
- [ ] Add Jira MCP integration for automatic ticket pulling
- [ ] Build `action-regression-analysis` steering (Phase 2 of the power)
- [ ] Build `action-failure-diagnosis` steering (Phase 3 of the power)
- [ ] Set up CI pipeline for the playwright-tests repo
- [ ] Add more composites to `action-registry.json` as workflows are validated
- [ ] Create the `suite/` folder structure with promoted tests

#### Key File Paths
- Power repo: `~/repo-gitlab/ramaswamy.u/power-appian-atlas-qe/`
- Test repo: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/gss-playwright-tests`
- Owl tests (reference): `/Users/ramaswamy.u/Documents/gss-tests/owl-tests/`
- Owl pages source: `~/repo/owl-pages/owl-appian-element/`
- Sail client source: `~/repo/ae/appian-libraries/sail-client/src/components/`
- Atlas overview: `~/Downloads/Atlas - Overview.txt`

---

### 2026-05-01 (Evening) / 2026-05-02 (Early Morning) — Action Verification, Component Library, Repo Standardization

#### Completed
- Verified ALL action files against live Appian site (Tier 1, 2, 3)
  - Tier 1: common-page.ts, navigation files — 6 functions fixed
  - Tier 2: create-evaluation.ts (21 field locators verified), evaluation-summary.ts — 9 functions fixed
  - Tier 3: vendor-site.ts, add-vendor.ts, continue-setup.ts — 5 functions fixed
  - Total: 20 functions fixed, 45+ verified working
- Eliminated 31 CSS class-based locators (from ~60 down to 29 irreducible)
  - Modal close → `getByRole('button', { name: 'Close modal' })`
  - Modal unfocus → `page.keyboard.press('Tab')`
  - Kebab menu → `getByRole('button', { name: 'Actions' })`
  - Menu items → `getByRole('menuitem')`
  - Cards → `getByRole('link')` within section
  - All modal containers → `getByRole('dialog')`
- Built complete `playwright-appian` component library (30 components, full Owl parity)
  - 33 files, 1,575 lines, all compile cleanly
  - Published to GitLab: `git@gitlab.appian-stratus.com:ramaswamy.u/playwright-appian.git`
  - GSS test repo installs via git URL
  - Library integration test: 11/11 passing against live site
- Standardized test repo structure (mirrors Owl conventions)
  - `actions/` → `pages/`, `suite/` → `tests/regression/` etc.
  - `tests/config/default.env` for environment config
- Revamped ALL 22 page files to use the library
  - 142 uses of `createAppianPage`, 20% code reduction (2,200 → 1,749 lines)
  - Deleted login.ts and wait-for-appian.ts (replaced by library)
- Updated ALL 6 steering documents
  - Three-layer architecture: Library → Pages → Tests
  - All imports reference `'playwright-appian'`
  - 8 strict rules including library-first mandate

#### Decisions Made
- npm package for library (shared across all Appian app test repos)
- Git URL install (no registry setup needed)
- `pages/` not `actions/` (matches Owl convention)
- Three-layer architecture (Library → Pages → Tests)
- 29 CSS locators are irreducible (Owl uses same CSS — no accessible alternative)

#### Remaining Items
- [ ] Test GAMS-7882 script with revamped pages
- [ ] Investigate `isTabVisible` edge case for multi-word tab names
- [ ] Run full regression of all page actions against live site
- [ ] Build remaining QE Power actions (regression-analysis, failure-diagnosis)
- [ ] Set up CI pipeline for playwright-tests repo
- [ ] Publish playwright-appian to GitLab npm registry (when ready for team)

#### Key Repos
| Repo | Location | Purpose |
|---|---|---|
| QE Power | `~/repo-gitlab/ramaswamy.u/power-appian-atlas-qe/` | Kiro Power steering documents |
| Component Library | `git@gitlab.appian-stratus.com:ramaswamy.u/playwright-appian.git` | Shared Appian Playwright library |
| GSS Tests | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/gss-playwright-tests` | GSS Source Selection test suite |

### 2026-05-03 — Test Impact Analysis, Regression Analysis, Failure Diagnosis, Coverage Analysis, Steering Hardening

#### Completed
- Designed Test Impact Analysis system
  - Per-test `*.spec.map.json` files (modular, no merge conflicts)
  - Three object categories: direct (🔴), setup (🟡), data (🟢)
  - Auto-generated reverse index `tests/index.map.json`
  - Integrated into Phase 6 (Promotion) — maps generated automatically from Phase 3 findings
  - Created `tests/TEST-IMPACT-ANALYSIS.md` documentation
- Built Regression Analysis action (`action-regression-analysis.md`)
  - Queries Atlas for changed objects → expands transitive dependencies → matches against test maps
  - Reports HIGH/MEDIUM/LOW priority tests to run
- Built Failure Diagnosis action (`action-failure-diagnosis.md`)
  - Classifies failures (element not found, assertion, setup, environment)
  - Cross-references Atlas object history to find recent changes
  - Can use Playwright MCP for live diagnosis
- Built Coverage Analysis action (`action-coverage-analysis.md`)
  - Maps test coverage against Atlas bundles/features
  - Reports: directly tested, indirectly tested, not tested
  - Prioritizes gaps by object type (Interface > Process Model > Expression Rule > CDT)
- Updated POWER.md — all 4 actions now ✅ Active
- Updated Phase 6 — now includes map generation + index rebuild
- Updated test naming convention — promoted tests named by Jira ticket (GAMS-7089.spec.ts)
- Hardened progress reporting — Rule 0 (highest priority), NON-NEGOTIABLE, must be FIRST in response
- Wrote comprehensive README for GSS test repo (395 lines)

#### Decisions Made
- Per-test map files over monolithic JSON (reason: modular, no merge conflicts, scales to hundreds of tests)
- Three impact categories: direct/setup/data (reason: different severity levels for regression prioritization)
- Test files named by Jira ticket (reason: instant traceability, simple naming)
- Progress tracker as Rule 0 (reason: agent was skipping it — made it highest priority and non-negotiable)

#### QE Power — Final State (4 Actions)
| Action | Steering File | Status |
|---|---|---|
| Test Script Generation | action-test-script-generation.md | ✅ Active |
| Regression Analysis | action-regression-analysis.md | ✅ Active |
| Failure Diagnosis | action-failure-diagnosis.md | ✅ Active |
| Coverage Analysis | action-coverage-analysis.md | ✅ Active |

#### Remaining Items
- [ ] Test full workflow end-to-end with a real ticket
- [ ] Fix and run GAMS-7882 with revamped pages
- [ ] Validate revamped pages against live site
- [ ] Add Jira MCP integration
- [ ] Set up CI pipeline
- [ ] Publish playwright-appian to npm registry
