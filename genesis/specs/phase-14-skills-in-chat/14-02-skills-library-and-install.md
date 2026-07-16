# Phase 14-02 — Skills library & install-from-repo

> **Status:** DRAFT (planning) · **Repos:** genesis-workflows + genesis · **Depends on:** 14-01
> **Goal:** Give Genesis a **supply of installable skills**: a `skills/` library in the `genesis-workflows` repo with a
> skills registry + CI validation, and a Genesis-side installer that pulls a selected skill from the library at a
> pinned ref and installs it into the managed skills workspace (`~/.genesis/.kiro/skills/`) — mirroring the existing
> workflow install/lockfile path.

---

## 1. Current state (grounded)
- `genesis-workflows` holds `registry.json` (`{version, genesis_core_major, workflows:[{id,name,version,roles,summary,
  path,required_mcp,required_cli}]}`), `workflows/<id>/**`, shared registries, `schemas/`, `steering/`, and
  `ci/validate_library.py` (a 7-gate publish runner).
- genesis `dist/`: `Installer.install_selection(ids, ref)` fetches `workflows/<id>/**` + `SHARED_FILES` via the GitLab
  client (`get_raw_file`, `list_tree(ref, path, recursive)`) into `~/.genesis/library/` and records an
  `installed.lock.json` (`Lockfile.workflows{id: InstalledWorkflow(version, ref, files)}` + a genesis_core pin).
  `Catalog.from_client(client, ref)` reads `registry.json`. `Loader` reads installed workflows.
- API: `/catalog`, `/catalog/available`, `/library/install`, `/library/update`, `DELETE /library/{id}`.

## 2. Design

### 2.1 Library layout (`genesis-workflows`)
```
skills/
  <skill-id>/
    SKILL.md            # required (open Agent Skills standard)
    scripts/  refs/  assets/   # optional
skills-registry.json    # NEW — the skills catalog (separate file; see Q2 in the umbrella)
```
- **`skills-registry.json`**: `{ "version": 1, "skills": [ {id, name, description, version, roles, path, summary,
  tags} ] }`. A **separate** file from `registry.json` (independent validation + clean concept separation; ADR-034).
- **CI validation** (`ci/validate_skills.py`, or extend `validate_library.py`): each registry skill exists at `path`;
  `SKILL.md` present + valid frontmatter (name==dir, `^[a-z0-9-]{1,64}$`, description ≤1024); no path traversal; size
  caps; registry ↔ folder parity. Wire into the repo's CI as a publish gate (like the workflow 7-gate).
- Seed with 1–2 real skills (e.g. a `release-checklist` and a `gam` skill) to exercise the path end-to-end.

### 2.2 Genesis installer (`dist/`)
- `SkillCatalog.from_client(client, ref)` — read `skills-registry.json` from the library at a ref (mirror `Catalog`).
- `SkillInstaller` — `install_selection(ids, ref)` fetches `skills/<id>/**` (via `list_tree` + `get_raw_file`) and
  writes them into **`settings.skills_dir/<id>/`** (the 14-01 managed workspace, NOT `library/`), writing the
  `.genesis-source.json` marker (`source="library", ref, version`). `remove(id)` deletes the skill dir.
- **Lockfile**: extend `installed.lock.json` with a `skills: {id: InstalledSkill(version, ref, files)}` map (additive;
  keep back-compat with existing lockfiles). This records what library skills are installed + their ref for
  update/uninstall — the parallel of `Lockfile.workflows`.
- Reuse the same GitLab source/token (`_default_source_factory`) — no new auth.

### 2.3 API (extend `genesis/api/skills.py` from 14-01)
- `GET /api/skills/available` → library skills not yet installed (needs the GitLab token; non-fatal 400 like
  `/catalog/available`).
- `POST /api/skills/install {id, ref?}` → `SkillInstaller.install_selection` → into the workspace → reload → return
  `{id, version, ref}`.
- `POST /api/skills/update {id}` (optional v1) → reinstall at latest compatible ref.
- `DELETE /api/skills/{id}` (from 14-01) now also drops the lockfile entry for library skills.
- `GET /api/skills` (14-01) returns installed skills with their `source` (library vs local) so the UI can badge them.

### 2.4 CLI (optional, mirrors `genesis install`)
- `genesis skills install <id>` / `genesis skills list` / `genesis skills remove <id>` — thin CLI over the same
  service (nice-to-have; the app UI is the primary surface).

## 3. Files & tests
- `genesis-workflows`: `skills/<id>/SKILL.md` (seed), `skills-registry.json`, `ci/validate_skills.py` + CI wiring,
  README note. Its own release (a library tag).
- genesis: `dist/skill_catalog.py` + `dist/skill_install.py` (or fold into existing modules), `Lockfile.skills`,
  `Settings.skills_dir` (from 14-01), API additions.
- Tests: `tests/test_skill_install.py` (LocalSource-backed, fully offline — mirror the workflow install tests: install
  writes `SKILL.md` + scripts into `skills_dir/<id>`, lockfile records it, remove cleans up, back-compat with a
  workflow-only lockfile); `genesis-workflows` `ci/validate_skills.py` self-test on the seed + a noncompliant fixture.

## 4. Acceptance criteria
1. `genesis-workflows` has a validated `skills/` library + `skills-registry.json`; CI fails on an invalid skill.
2. `POST /api/skills/install` pulls a library skill at a ref into `~/.genesis/.kiro/skills/<id>/` and records it in the
   lockfile; `GET /api/skills/available` lists uninstalled library skills; remove cleans up + delocks.
3. Installed library skills are discoverable in chat (14-01 wiring) and badged `library` in `GET /api/skills`.
4. Lockfile change is additive/back-compatible; full genesis suite + ruff green; genesis-workflows CI green.

## 5. Out of scope
- The Catalog Skills tab + author UI (14-03), chat palette (14-04), safety/exec (14-05).
