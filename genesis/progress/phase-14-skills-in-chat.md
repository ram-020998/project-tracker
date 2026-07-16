# Phase 14 — Skills in Chat (as-built)

**Status:** ✅ COMPLETE (14-01..14-05 shipped). **ADR-034 Accepted.**
**Release:** kiro-agent-sdk **v0.6.0** → genesis-workflows **v0.6.0** → genesis-core **v0.8.2** → genesis **v0.26.1**.

The plan lives in `specs/phase-14-skills-in-chat.md` (+ `phase-14-skills-in-chat/14-01..14-05`). This is the
as-built record.

## What shipped

**Concept (ADR-034).** A **Skill** = a single *standalone activity* (draft a document, apply a body of knowledge like
GAM) owned by the **Kiro agent** via its `SKILL.md` — no stages, no run. A **Workflow** = a *staged/orchestrated*
activity owned by **LangGraph** (ADR-001 preserved: a skill never starts a run). Skills are **filesystem-discovered**
(NOT an ACP wire param like MCP) — proven by the spike (`spike/2026-07-16-kiro-skills-in-acp-and-chat.md`).

### 14-01 — Foundation & chat discovery (genesis)
- `Settings.skills_dir` = `~/.genesis/.kiro/skills` (created on load; = the chat `cwd`, so kiro-cli auto-discovers it
  as a workspace skill). `Settings.skill_output_dir` = `~/.genesis/skill-output`.
- `genesis/skills/`: `model.py` (`parse_skill_md`/`validate` — frontmatter, `name==dir` `^[a-z0-9-]{1,64}$`,
  description ≤1024, size caps; `SkillInfo`), `store.py` (`SkillStore` filesystem repo: path-traversal-safe
  create/list/get/remove, atomic temp-swap, `.genesis-source.json` provenance marker, malformed skills skipped not
  fatal), `service.py` facade.
- `/api/skills` CRUD (`GET`, `GET/{id}`, `POST` author [multipart or JSON], `DELETE`); `ChatManager.reload_skills` /
  `reload_all_skill_clients` (close live client → next turn re-discovers). Added `python-multipart` dep.

### 14-02 — Skills library & install-from-repo (genesis-workflows + genesis)
- `genesis-workflows`: `skills/gam/` (SKILL.md + references/) + `skills-registry.json` (separate from `registry.json`)
  + `ci/validate_skills.py` (self-contained pyyaml validator: registry+manifest+parity+fixture gate) + a
  `skills-validate` CI job + `skills/_fixtures/noncompliant/`. Seed skill = **`gam`** (Government Acquisition Management).
- genesis: `dist/skill_catalog.py` (`SkillCatalog.from_client`), `dist/skill_install.py` (`SkillInstaller` — pull
  `skills/<id>/**` at a pinned ref into the workspace, reuse `SkillStore` for validation, record `Lockfile.skills`);
  `Lockfile.skills` map (additive/back-compat). `/api/skills/available|install|update`; `DELETE` also delocks.

### 14-03 — Catalog Skills tab & authoring (genesis web)
- `CatalogPage` → `Tabs` shell (**Workflows | Skills**); `WorkflowsTab` extracted unchanged; static `catalog/skills`
  route registered ahead of `catalog/:workflowId` to avoid the dynamic-route collision.
- `SkillsTab` (filter bar + merged grid + source badges + New skill), `SkillCard`, `SkillAuthorDialog` (name +
  description + SKILL.md body + scripts/references/assets uploads; zod validation; dup→replace; assembles the final
  `SKILL.md`), reusable `FileDropList`, `postForm` multipart helper.

### 14-04 — Chat skills invocation (genesis web + minor backend)
- Unified Composer `/` palette: **Workflows** section (copilot-only, prereq-aware) + **Skills** section (both modes);
  picking a skill sends `/<name>`. Skills usable in read-only chat too. Reload affordance.
- Per-session **skill-output** surfacing: `GET /api/chat/sessions/{id}/outputs` (+ `/{name}` content + `/download`)
  reading the sandbox; `SessionOutputs` panel reuses the shared `DocumentPreview` renderer. `POST .../reload` endpoint.

### 14-05 — Safety, lifecycle & release
- **kiro-agent-sdk `fs_write_root`** (additive option): `fs/write_text_file` rejects any write whose resolved target
  escapes the root (traversal + symlink-safe). Chat runs `allow_fs_write=True` **scoped to**
  `skill_output_dir/<session_id>` in **both** modes — a skill can save documents but cannot touch config/secrets/
  registry/workflow files/arbitrary paths. **Bounded refinement of ADR-031/033.**
- **Executing bundled `scripts/` stays deferred** (a separate future ADR). Imported/authored content is untrusted.
- Dedup: `SkillInfo.shadows_personal` flags when a managed skill shadows a same-named `~/.kiro/skills` one (surfaced
  in `SkillCard`). Uninstall/update never touch the user's personal `~/.kiro`.

## Verification (at release)
- genesis **222** pytest + ruff clean; kiro-agent-sdk **82** (incl. 7 `test_fs_write_sandbox`) + ruff clean;
  genesis-workflows `validate_skills` PASS (+rejects the fixture) + `validate_library` PASS; web **119** Vitest + lint
  (0 errors) + tsc clean + `web/static` rebuilt.
- Key suites: `tests/test_skills_store.py`, `test_skills_api.py`, `test_skill_install.py`, `test_chat_api.py` (outputs +
  reload), `test_chat_manager.py`/`test_copilot_mode.py` (sandbox options); web `skills.test.tsx`, `skills-chat.test.tsx`.

## Remaining (manual)
- **Live acceptance vs. real kiro-cli** (headless-undrivable): install/author `gam`, then in Chat **auto-activate** it
  (describe an acquisition task) and **explicitly** `/gam`, and confirm the reply reflects the skill + a document lands
  in the session skill-output sandbox. The spike already proved the discovery/activation mechanism; this validates the
  full Genesis-provisioned path. Record the transcript here when run.
