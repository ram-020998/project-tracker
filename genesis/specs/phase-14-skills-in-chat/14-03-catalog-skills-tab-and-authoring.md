# Phase 14-03 — Catalog "Skills" tab & in-flight authoring

> **Status:** DRAFT (planning) · **Repo:** genesis (web) · **Depends on:** 14-01, 14-02
> **Goal:** Split the Catalog page into **Workflows | Skills** sub-tabs (standard pattern), and in the Skills tab let
> the user **browse/install/remove** library skills **and author a new skill in-flight** (name + description +
> `SKILL.md` body + optional `scripts/`/`references/`/`assets/` uploads). Consistency with existing UX is paramount.

---

## 1. Current state (grounded)
- `CatalogPage.tsx` is **flat**: a filter bar (search, `SegmentedControl` status All|Installed|Available, role select)
  over a merged `useInstalled()`+`useAvailable()` list rendered as a `WorkflowCard` grid, with an install/remove
  `Dialog`. Hooks: `useInstalled` (GET `/catalog`), `useAvailable` (GET `/catalog/available`), `useConfiguredSets`,
  `prereqFor`, `useInstall` (POST `/library/install`), `useRemove` (DELETE `/library/{id}`).
- The app already uses the **`Tabs`** primitive for sub-tabs (Settings `SettingsPage`, the new Run Detail Flow|Documents),
  and the **`ResourceManager`/`ResourceFormDialog`** + `CodeMirror` JSON editor + `Dialog` patterns for create/edit.
- Skills API (14-01/02): `GET /api/skills`, `GET /api/skills/available`, `POST /api/skills/install`,
  `POST /api/skills` (author, multipart), `DELETE /api/skills/{id}`.

## 2. Design

### 2.1 Catalog sub-tabs (standard)
- Wrap `CatalogPage` body in **`Tabs`** with `Workflows` (the existing content, refactored into a `WorkflowsTab`) and
  `Skills` (new `SkillsTab`). Route-driven like Settings/Run-Detail (`/catalog/:tab?`) so deep links + back/forward
  work; default `workflows`. Keep the page title/`Page` shell; move the filter bar inside each tab (each has its own
  search/status filters). **No behavioural change to Workflows** — pure refactor into a tab.

### 2.2 Skills tab (`features/catalog/skills/SkillsTab.tsx`)
- Filter bar: search + status `All | Installed | Available` (reuse the `SegmentedControl` pattern). No prereqs/roles
  needed (skills have no MCP/CLI prereqs), but support optional `tags`.
- A `SkillCard` (mirror `WorkflowCard`): icon, name, description (clamped), a **source badge** (`Library`/`Authored`),
  size, and Install / Remove actions (reuse the confirm `Dialog`). Installed + available merged like Workflows.
- Hooks (`features/catalog/skills/hooks.ts`): `useInstalledSkills` (GET `/api/skills`), `useAvailableSkills` (GET
  `/api/skills/available`), `useInstallSkill` (POST `/api/skills/install`), `useRemoveSkill` (DELETE), `useCreateSkill`
  (POST multipart). `skillsApi` in `lib/api/skills.ts`; query keys in `lib/query/keys.ts`.
- A **"New skill"** primary button (top-right of the Skills tab) → opens the author flow (2.3).

### 2.3 In-flight authoring (`features/catalog/skills/SkillAuthorDialog.tsx`)
A `Dialog`-based form (mirroring `ResourceFormDialog`) with:
- **Name** (`^[a-z0-9-]{1,64}$`, becomes the folder id) + **Description** (≤1024, the activation trigger — with a hint
  that Kiro matches requests against it).
- **`SKILL.md` body** — a Markdown editor (reuse the `CodeMirror` editor used for JSON, in markdown mode, or a
  `Textarea` for v1). The dialog assembles the final `SKILL.md` = frontmatter (`name`,`description`,optional metadata)
  + body, so the user edits the body, not raw frontmatter. Show a live "this is what will be written" affordance.
- **Uploads** (optional): three drop/upload zones — **Scripts** (`scripts/`), **References** (`references/`), **Assets**
  (`assets/`) — a small reusable `FileDropList` (multi-file, shows name+size, remove). (No existing upload component →
  create a minimal accessible one.)
- **Validation** inline (zod): name pattern, description length, unique-id (not already installed → else offer replace).
- **Submit** → `useCreateSkill` (multipart: `skill_md` + files) → toast + refresh installed list + close. The new skill
  is immediately installed in the workspace and available in chat (14-01 reload).
- Client-side guardrails: file-size/type caps, count caps, a note that scripts are stored but not auto-executed (14-05).

### 2.4 Empty / error / a11y
- Empty state ("No skills yet — install one from the library or create your own"). Available-section error is non-fatal
  (needs GitLab token) — same hint as Workflows. `jest-axe` on the tab, cards, and author dialog.

## 3. Files & tests
- New: `features/catalog/skills/{SkillsTab,SkillCard,SkillAuthorDialog,hooks}.tsx/ts`, `lib/api/skills.ts`,
  `types/skill.ts`, `shared/…/FileDropList.tsx`; refactor `CatalogPage` → `Tabs` + extract `WorkflowsTab`.
- Tests (Vitest + MSW, mirror `catalog.test.tsx`): sub-tab switch + default; Skills list installed/available + source
  badge; install → POST + refetch; remove → confirm → DELETE; **author flow** — fill name/description/body + attach a
  script → POST multipart with the right fields → success; validation errors (bad name, long description, dup id);
  jest-axe. Contract fixtures for the skill shapes.

## 4. Acceptance criteria
1. Catalog shows **Workflows | Skills** sub-tabs; Workflows tab is behaviourally unchanged; deep-link/route works.
2. Skills tab browses installed + available skills with a source badge and install/remove.
3. "New skill" authors a skill (name + description + `SKILL.md` body + optional scripts/references/assets) that is
   written to the workspace and appears in the installed list.
4. web lint + tsc + tests + jest-axe green; `web/static` rebuilt.

## 5. Out of scope
- Chat invocation/palette (14-04); library CI/registry (14-02); script execution + final validation hardening (14-05).
