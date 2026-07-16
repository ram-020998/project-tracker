# Phase 14-01 — Skills foundation & chat discovery

> **Status:** DRAFT (planning) · **Repo:** genesis · **Depends on:** the skills-in-ACP spike (proven)
> **Goal:** Establish the managed skills workspace, the skill domain model + local store/service, the read/create/
> remove API, and the wiring that makes an installed skill **usable in a Chat session** — plus a "reload skills"
> affordance. This is the load-bearing foundation: after 14-01, dropping a `SKILL.md` into the workspace (by any means)
> makes it available in chat.

---

## 1. Current state (grounded)
- `ChatManager` runs each session **in-process** with a persistent `KiroACPClient`; `_ensure_started` sets
  `cwd = str(settings.state_dir)` (`~/.genesis`) for **both** `read_only` and `copilot` modes.
- `Settings` (runtime/settings.py) already exposes `state_dir` + derived paths (`library_dir`, `secrets_path`, …).
- kiro-cli auto-discovers **workspace** skills at `<cwd>/.kiro/skills/` and **global** skills at `~/.kiro/skills/`
  (spike-proven). No CLI flag, no ACP param.
- `set_session_mode` already **closes the live client** so the next turn rebuilds the ACP session — the exact hook a
  "reload skills" needs.

## 2. Design

### 2.1 The managed skills workspace
- Add `Settings.skills_dir` → **`state_dir / ".kiro" / "skills"`** (created on load, like `library_dir`). Because the
  chat `cwd` is `state_dir`, kiro-cli discovers these as **workspace skills** automatically — no `KIRO_HOME`, no cwd
  change (keeps the user's personal `~/.kiro` agents/sessions/settings untouched; their global `~/.kiro/skills/` stays
  active, workspace-wins on conflict).
- Each installed/authored skill is a directory `skills_dir/<id>/` with `SKILL.md` (required) + optional `scripts/`,
  `references/`, `assets/`.

### 2.2 Skill domain model (`genesis/skills/model.py`)
- `SkillManifest` = parsed `SKILL.md` frontmatter: `name` (== dir, `^[a-z0-9-]{1,64}$`), `description` (≤1024),
  optional `license`, `compatibility`, `metadata`, plus derived `body` (markdown after frontmatter) and
  `source` (`"library" | "local"`).
- `parse_skill_md(text) -> SkillManifest` + `validate(...)` (frontmatter present, name/description rules, size caps).
  Reuse a minimal YAML-frontmatter parse (pyyaml already a dep).
- `SkillInfo` (for listing): `{id, name, description, source, has_scripts, has_references, has_assets, bytes, path}`.

### 2.3 Store / service (`genesis/skills/store.py` + `service.py`)
`SkillStore` (filesystem repository over `skills_dir`; **no DB** — skills are files, mirroring how the workflow library
is files not DB):
- `list() -> [SkillInfo]` — scan `skills_dir/*/SKILL.md`, parse, tolerate malformed (skip + note).
- `get(id) -> {manifest, body, files}`.
- `create(id, skill_md, files={scripts,references,assets})` — path-traversal-safe writes; validates before writing;
  rejects a name/dir mismatch; overwrite-guard (409 unless replace).
- `remove(id)` — delete the skill dir (managed workspace only; never touches `~/.kiro`).
- A `source` marker file (e.g. `.genesis-source.json` = `{"source":"library|local","ref":...,"version":...}`) so the
  UI can distinguish library vs authored skills and 14-02 can record installs.

### 2.4 Chat wiring (discovery + reload)
- **Discovery**: nothing to inject — confirm (test) that a skill in `skills_dir` is discovered by a chat session
  (cwd=state_dir). Add a one-line note in `chat/mcp.py`/`manager.py` documenting that skills come from `state_dir/.kiro/skills`.
- **Reload**: `ChatManager.reload_skills(session_id)` (or reuse `set_session_mode`'s client-close) → closes the live
  client so the next turn re-discovers skills. A session-agnostic `reload_all_skill_clients()` for a global "skills
  changed" event (after install/author/remove) so *open* sessions pick up the change on their next turn.

### 2.5 API (`genesis/api/skills.py`, registered on `/api`)
- `GET /api/skills` → installed skills (`SkillInfo[]`).
- `GET /api/skills/{id}` → manifest + body + file list.
- `POST /api/skills` → **author/create** (multipart: `skill_md` text + optional `scripts[]`/`references[]`/`assets[]`
  file uploads; or a JSON body for md-only). Validates, writes, triggers reload. (Library install is 14-02.)
- `DELETE /api/skills/{id}` → remove + reload.
- All local/managed-workspace only.

## 3. Files & tests
- New: `genesis/skills/{__init__,model,store,service}.py`, `genesis/api/skills.py`; `Settings.skills_dir`; register
  routes + a skills service on `app.state` in `app.py`; a doc note in `chat/`.
- Tests: `tests/test_skills_store.py` (parse/validate SKILL.md incl. bad frontmatter, name-rule, size cap;
  create/list/get/remove; path-traversal rejected; overwrite guard); `tests/test_skills_api.py` (CRUD via TestClient,
  multipart create with a script/reference/asset, delete); a chat-reload test (client rebuilt on reload). Optionally a
  **live** discovery check (manual, real kiro-cli) recorded in progress/ — the spike already covers the core.

## 4. Acceptance criteria
1. `Settings.skills_dir = ~/.genesis/.kiro/skills` exists; a skill written there is discovered by a chat session
   (documented + spike-backed; a manual live check recorded).
2. `SKILL.md` is parsed + validated (name==dir, name/description rules, size caps); malformed skills are skipped, not
   fatal.
3. `GET/POST(create)/DELETE /api/skills` work; create accepts scripts/references/assets; writes are
   path-traversal-safe and managed-workspace-scoped.
4. Installing/authoring/removing a skill triggers a client reload so open sessions pick it up on the next turn.
5. Full genesis suite + ruff green.

## 5. Out of scope
- Library install (14-02), the Catalog UI + author form (14-03), chat palette (14-04), script execution/file output +
  final validation hardening (14-05).
